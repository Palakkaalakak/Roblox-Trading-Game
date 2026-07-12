--!strict
-- BotService v3: 100 deterministic profit-seeking trading agents.
--
-- Zero randomness. Each bot's behavior is a pure function of:
--   * market state: order book (shared snapshot per sweep), fair values
--     (Value blended with demand tilt), NPC store stock, active recipes
--   * its own durable position: gems + inventory + escrow locked in its
--     open quotes (net worth INCLUDES escrow — a bot with 10 open bids is
--     not "poor", a mistake that made v2 bots spiral into bulk spam)
--   * its index-derived parameters (edge, inventory aversion gamma, target
--     gem fraction, quote specialization) — fixed formulas, no dice.
--
-- Strategy per pass (see BotConfig header for the finance background):
--   TAKE  — score every executable deal by expected profit vs the bot's
--           reservation price; run the best TakesPerPass:
--           lift cheap asks / fill rich bids / accept +EV swaps /
--           buy underpriced store stock / craft +EV recipes.
--   NEED  — if a +EV recipe lacks inputs, bid for the missing inputs at a
--           price justified by the recipe's profit (need-based pricing).
--   QUOTE — maintain ask+bid on the bot's specialization items around its
--           inventory-skewed reservation price, undercutting/outbidding
--           the book inside hard value-tethered guard rails; requote when
--           price drifts or goes stale.
--
-- Ops notes: one leader server runs brains (MemoryStore lease); the order
-- book is fetched ONCE per sweep and shared by all 100 bots (with local
-- decrements as deals execute, so later bots don't chase filled listings).
-- Bot state is CAS in DataStore (any server can settle against a bot) with
-- a leader-side cache refreshed from every CAS result.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotConfig = require(ReplicatedStorage.Shared.Config.BotConfig)
local Tax = require(ReplicatedStorage.Shared.Util.Tax)

local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local BotService = {}

local botStore: any -- DataStore "BotEconomy_v2", key "bot_<-id>"
local lockMap: any -- MemoryStore map: leader lease

--------------------------------------------------------------------------------
-- Deterministic bot roster (index-derived names + parameters)
--------------------------------------------------------------------------------

local FIRST = { "Ada", "Brutus", "Cleo", "Dot", "Edgar", "Fern", "Gus", "Hazel", "Igor", "June" }
local LAST = { "Byte", "Copper", "Drift", "Ember", "Flux", "Gale", "Ash", "Pip", "Quill", "Sable" }

local bots: { any } = {}
local botsById: { [number]: any } = {}
do
	local n = BotConfig.Count
	for i = 1, n do
		local denom = math.max(n - 1, 1)
		local bot = {
			userId = -(100 + i),
			name = ("%s %s [bot]"):format(FIRST[((i - 1) % #FIRST) + 1], LAST[(math.floor((i - 1) / #FIRST) % #LAST) + 1]),
			edge = BotConfig.EdgeMin + BotConfig.EdgeSpan * ((i * 7) % n) / denom,
			gamma = BotConfig.GammaMin + BotConfig.GammaSpan * ((i * 13) % n) / denom,
			targetGemFrac = BotConfig.TargetGemFracMin + BotConfig.TargetGemFracSpan * ((i * 29) % n) / denom,
			index = i,
		}
		table.insert(bots, bot)
		botsById[bot.userId] = bot
	end
end

function BotService.isBot(userId: number): boolean
	return botsById[userId] ~= nil
end

local function stateKey(botId: number): string
	return "bot_" .. tostring(-botId)
end

--------------------------------------------------------------------------------
-- Durable state (CAS; any server may credit) + leader-side cache
--------------------------------------------------------------------------------

local function freshState()
	return {
		gems = 0,
		inventory = {},
		claimed = {},
		seeded = false,
		storePurchases = {},
		lifetime = { earned = 0, spent = 0 },
	}
end

local stateCache: { [number]: { state: any, at: number } } = {}
local CACHE_TTL = 30

function BotService.applyDelta(botId: number, delta: { items: { [string]: number }?, gems: number? }, source: string, idempotencyKey: string?): (boolean, string?)
	local errOut: string? = nil
	local newState: any = nil
	local ok = pcall(function()
		newState = botStore:UpdateAsync(stateKey(botId), function(state)
			state = state or freshState()
			if idempotencyKey and state.claimed[idempotencyKey] then
				errOut = nil
				return state
			end
			local gems = delta.gems or 0
			if state.gems + gems < 0 then
				errOut = "insufficient_gems"
				return nil
			end
			if delta.items then
				for itemId, count in delta.items do
					if (state.inventory[itemId] or 0) + count < 0 then
						errOut = "insufficient_items:" .. itemId
						return nil
					end
				end
			end
			state.gems += gems
			if gems > 0 then
				state.lifetime.earned += gems
			elseif gems < 0 then
				state.lifetime.spent -= gems
			end
			if delta.items then
				for itemId, count in delta.items do
					local newCount = (state.inventory[itemId] or 0) + count
					state.inventory[itemId] = newCount ~= 0 and newCount or nil
				end
			end
			if idempotencyKey then
				state.claimed[idempotencyKey] = true
			end
			errOut = nil
			return state
		end)
	end)
	if not ok then
		return false, "store_error"
	end
	if errOut == nil and newState ~= nil then
		stateCache[botId] = { state = newState, at = os.clock() }
	end
	return errOut == nil, errOut
end

function BotService.credit(botId: number, items: { [string]: number }, gems: number, claimId: string): boolean
	return (BotService.applyDelta(botId, { items = items, gems = gems }, "board", claimId))
end

function BotService.storeCount(botId: number, itemId: string): number
	local cached = stateCache[botId]
	local s = cached and cached.state
	if s == nil then
		pcall(function()
			s = botStore:GetAsync(stateKey(botId))
		end)
	end
	return s and s.storePurchases and s.storePurchases[itemId] or 0
end

function BotService.bumpStoreCount(botId: number, itemId: string)
	pcall(function()
		local newState = botStore:UpdateAsync(stateKey(botId), function(s)
			s = s or freshState()
			s.storePurchases = s.storePurchases or {}
			s.storePurchases[itemId] = (s.storePurchases[itemId] or 0) + 1
			return s
		end)
		if newState then
			stateCache[botId] = { state = newState, at = os.clock() }
		end
	end)
end

local function getState(botId: number): any
	local cached = stateCache[botId]
	if cached and os.clock() - cached.at < CACHE_TTL then
		return cached.state
	end
	local state
	pcall(function()
		state = botStore:GetAsync(stateKey(botId))
	end)
	state = state or freshState()
	stateCache[botId] = { state = state, at = os.clock() }
	return state
end

--------------------------------------------------------------------------------
-- Seeding: deterministic round-robin reserve draws
--------------------------------------------------------------------------------

local function seedBot(bot: any)
	local state = getState(bot.userId)
	if state.seeded then
		return
	end
	local candidates = {}
	for itemId, item in EconomyService.allItems() do
		if (item.assignmentWeight or 0) > 0 then
			table.insert(candidates, itemId)
		end
	end
	table.sort(candidates) -- stable order -> deterministic draws
	local granted: { [string]: number } = {}
	if #candidates > 0 then
		for d = 1, BotConfig.StarterDraws do
			local itemId = candidates[((bot.index + d * 3) % #candidates) + 1]
			if EconomyService.reserveOne(itemId) then -- broadcast is coalesced centrally now
				granted[itemId] = (granted[itemId] or 0) + 1
			end
		end
	end
	pcall(function()
		local newState = botStore:UpdateAsync(stateKey(bot.userId), function(s)
			s = s or freshState()
			if s.seeded then
				return s
			end
			s.seeded = true
			s.gems += BotConfig.StartGems
			for itemId, count in granted do
				s.inventory[itemId] = (s.inventory[itemId] or 0) + count
			end
			return s
		end)
		if newState then
			stateCache[bot.userId] = { state = newState, at = os.clock() }
		end
	end)
end

--------------------------------------------------------------------------------
-- Market model (shared per sweep)
--------------------------------------------------------------------------------

-- Fair value: market Value (RAP-blended) tilted by normalized demand.
-- Deterministic from the economy snapshot.
local fairCache: { [string]: number } = {}
local function fair(itemId: string): number
	local cached = fairCache[itemId]
	if cached then
		return cached
	end
	local snap = EconomyService.snapshot(itemId)
	local value = snap and snap.value and snap.value.value or EconomyService.valueOf(itemId)
	local demand = 0
	if snap and snap.demand and snap.demand.state == "Known" then
		demand = snap.demand.value or 0
	end
	local tilt = 1 + BotConfig.DemandTilt * math.min(demand / BotConfig.DemandRef, 1)
	local f = math.max(1, value * tilt)
	fairCache[itemId] = f
	return f
end

-- Reservation price: fair value skewed against the bot's position.
local function reservation(bot: any, itemId: string, position: number): number
	local excess = (position - BotConfig.TargetHoldPerItem) / BotConfig.SkewScale
	return fair(itemId) * (1 - bot.gamma * excess)
end

-- Book view built once per sweep from rawOpenListings: best ask/bid per
-- item + the raw lists (locally decremented as deals execute).
local function buildBook(listings: { any })
	local book = {
		sells = {} :: { any }, -- open sell listings
		bulks = {} :: { any }, -- open bulk bids
		swaps = {} :: { any },
		bestAsk = {} :: { [string]: number },
		bestBid = {} :: { [string]: number },
		ownOpen = {} :: { [number]: { any } }, -- posterId -> listings
	}
	for _, l in listings do
		if l.kind == "sell" then
			table.insert(book.sells, l)
			local a = book.bestAsk[l.itemId]
			if a == nil or l.gemsPerCopy < a then
				book.bestAsk[l.itemId] = l.gemsPerCopy
			end
		elseif l.kind == "bulk" then
			table.insert(book.bulks, l)
			local b = book.bestBid[l.itemId]
			if b == nil or l.gemsPerCopy > b then
				book.bestBid[l.itemId] = l.gemsPerCopy
			end
		elseif l.kind == "swap" and l.autoTrade then
			table.insert(book.swaps, l)
		end
		local own = book.ownOpen[l.posterId]
		if own == nil then
			own = {}
			book.ownOpen[l.posterId] = own
		end
		table.insert(own, l)
	end
	return book
end

--------------------------------------------------------------------------------
-- One bot pass (pure decisions -> real board/store/craft calls)
--------------------------------------------------------------------------------

local function pass(bot: any, book: any, itemIds: { string }): { string }
	local TradeBoardService = require(script.Parent.TradeBoardService) :: any
	local StoreService = require(script.Parent.StoreService) :: any
	local CraftingService = require(script.Parent.CraftingService) :: any

	local state = getState(bot.userId)
	local actions: { string } = {}

	-- position value + escrow-inclusive net worth (v2 bug fix)
	local invValue = 0
	for itemId, count in state.inventory do
		invValue += fair(itemId) * count
	end
	local escrowValue = 0
	for _, l in book.ownOpen[bot.userId] or {} do
		if l.kind == "sell" then
			escrowValue += fair(l.itemId) * l.remainingCount
		elseif l.kind == "bulk" then
			escrowValue += l.gemsPerCopy * l.remainingCount
		elseif l.kind == "swap" then
			escrowValue += l.give.gems
			for itemId, count in l.give.items do
				escrowValue += fair(itemId) * count
			end
		end
	end
	local worth = state.gems + invValue + escrowValue
	local gemFrac = worth > 0 and (state.gems / worth) or 1
	local spendable = state.gems - BotConfig.MinGemsKept

	----------------------------------------------------------------------
	-- TAKE: expected-profit-ranked executable deals
	----------------------------------------------------------------------
	local candidates: { { profit: number, tag: string, run: () -> boolean } } = {}

	-- lift underpriced asks (only while not starved for gems)
	if gemFrac > bot.targetGemFrac * 0.5 then
		for _, l in book.sells do
			if l.posterId ~= bot.userId and l.remainingCount > 0 then
				local pos = state.inventory[l.itemId] or 0
				local r = reservation(bot, l.itemId, pos)
				if l.gemsPerCopy <= r * (1 - bot.edge) and pos < BotConfig.MaxHoldPerItem and l.gemsPerCopy <= spendable then
					local count = math.min(l.remainingCount, math.floor(spendable / l.gemsPerCopy), BotConfig.QuoteCopies)
					if count >= 1 then
						table.insert(candidates, {
							profit = (r - l.gemsPerCopy) * count,
							tag = "buy_sell_listing",
							run = function()
								local res = TradeBoardService.botBuy(bot.userId, bot.name, l.id, count)
								if res.ok then
									l.remainingCount -= count -- local book decrement
								end
								return res.ok == true
							end,
						})
					end
				end
			end
		end
	end
	-- fill overpaying bids
	for _, l in book.bulks do
		if l.posterId ~= bot.userId and l.remainingCount > 0 then
			local owned = state.inventory[l.itemId] or 0
			if owned >= 1 then
				local r = reservation(bot, l.itemId, owned)
				local net = Tax.split(l.gemsPerCopy)
				if net >= r * (1 + bot.edge) then
					local count = math.min(owned, l.remainingCount)
					table.insert(candidates, {
						profit = (net - r) * count,
						tag = "fill_bulk",
						run = function()
							local res = TradeBoardService.botContribute(bot.userId, bot.name, l.id, count)
							if res.ok then
								l.remainingCount -= count
							end
							return res.ok == true
						end,
					})
				end
			end
		end
	end
	-- accept +EV auto swaps
	for _, l in book.swaps do
		if l.posterId ~= bot.userId and l.status == "open" then
			local receive = Tax.split(l.give.gems)
			for itemId, count in l.give.items do
				receive += fair(itemId) * count
			end
			local pay = l.want.gems
			local canPay = l.want.gems <= spendable
			for itemId, count in l.want.items do
				pay += reservation(bot, itemId, state.inventory[itemId] or 0) * count
				if (state.inventory[itemId] or 0) < count then
					canPay = false
				end
			end
			if canPay and pay > 0 and receive - pay >= bot.edge * pay then
				table.insert(candidates, {
					profit = receive - pay,
					tag = "accept_swap",
					run = function()
						local res = TradeBoardService.botAccept(bot.userId, bot.name, l.id)
						if res.ok then
							l.status = "claimed"
						end
						return res.ok == true
					end,
				})
			end
		end
	end
	-- primary-market arb: NPC store stock under fair value
	if gemFrac > bot.targetGemFrac * 0.5 then
		for _, s in StoreService.shelfForBots() do
			local pos = state.inventory[s.itemId] or 0
			local r = reservation(bot, s.itemId, pos)
			if s.price <= r * (1 - bot.edge) and s.price <= spendable and pos < BotConfig.MaxHoldPerItem then
				table.insert(candidates, {
					profit = r - s.price,
					tag = "store_buy",
					run = function()
						return StoreService.botBuy(bot.userId, s.itemId).ok == true
					end,
				})
			end
		end
	end
	-- production arb: craft when output beats input cost; remember missing
	-- inputs so the QUOTE phase can bid for them (need-based pricing)
	local neededInputs: { [string]: number } = {} -- itemId -> justified bid price
	local now = os.time()
	for _, event in CraftingService.activeEvents(now) do
		for _, recipe in event.recipes do
			local outId = CraftingService.outputIdFor(recipe.output.sku)
			local outSnap = EconomyService.snapshot(outId)
			if outSnap and (outSnap.reserveRemaining or 0) > 0 then
				local cost = recipe.gems or 0
				local haveAll = (recipe.gems or 0) <= spendable
				for itemId, count in recipe.inputs do
					cost += fair(itemId) * count
					if (state.inventory[itemId] or 0) < count then
						haveAll = false
					end
				end
				local outFair = fair(outId)
				if outFair >= cost * (1 + bot.edge) then
					if haveAll then
						table.insert(candidates, {
							profit = outFair - cost,
							tag = "craft",
							run = function()
								return CraftingService.botCraft(bot.userId, event.id, recipe.rid).ok == true
							end,
						})
					else
						-- the recipe justifies paying up to fair for inputs
						for itemId, count in recipe.inputs do
							if (state.inventory[itemId] or 0) < count then
								neededInputs[itemId] = math.floor(fair(itemId) + 0.5)
							end
						end
					end
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		if a.profit ~= b.profit then
			return a.profit > b.profit
		end
		return a.tag < b.tag -- deterministic tiebreak
	end)
	local taken = 0
	for _, c in candidates do
		if taken >= BotConfig.TakesPerPass then
			break
		end
		if c.run() then
			taken += 1
			table.insert(actions, c.tag)
			state = getState(bot.userId)
			spendable = state.gems - BotConfig.MinGemsKept
		end
	end

	----------------------------------------------------------------------
	-- QUOTE: maintain ask+bid on specialization items (+ needed inputs)
	----------------------------------------------------------------------
	-- specialization: fixed slice of the item universe by bot index
	local focus: { [string]: boolean } = {}
	if #itemIds > 0 then
		for k = 0, BotConfig.QuoteItemsPerBot - 1 do
			focus[itemIds[((bot.index * 3 + k * 41) % #itemIds) + 1]] = true
		end
	end
	for itemId in neededInputs do
		focus[itemId] = true
	end
	-- items the bot is overweight in are always quotable for selling
	for itemId, count in state.inventory do
		if count > BotConfig.MaxHoldPerItem then
			focus[itemId] = true
		end
	end

	-- index own open quotes by item
	local ownSell: { [string]: any } = {}
	local ownBulk: { [string]: any } = {}
	for _, l in book.ownOpen[bot.userId] or {} do
		if l.kind == "sell" then
			ownSell[l.itemId] = l
		elseif l.kind == "bulk" then
			ownBulk[l.itemId] = l
		end
	end

	local quoted = 0
	for itemId in focus do
		if quoted >= 2 then
			break -- bounded board churn per pass
		end
		local value = EconomyService.valueOf(itemId)
		local pos = state.inventory[itemId] or 0
		local r = reservation(bot, itemId, pos)

		-- ASK side: own a copy -> keep a sell quote near r*(1+edge)
		if pos >= 1 then
			local floorPrice = math.max(1, math.floor(math.max(r * (1 + bot.edge / 2), value * BotConfig.MinSellVsValue) + 0.5))
			local target = math.floor(r * (1 + bot.edge) + 0.5)
			local ask = book.bestAsk[itemId]
			if ask and ask - 1 >= floorPrice and ask - 1 < target then
				target = ask - 1 -- undercut inside our floor
			end
			target = math.max(target, floorPrice)
			local existing = ownSell[itemId]
			local stale = existing
				and (now - existing.createdAt > BotConfig.RepriceSeconds
					or math.abs(existing.gemsPerCopy - target) > target * BotConfig.RepriceFrac)
			if existing and stale then
				if TradeBoardService.botCancel(bot.userId, existing.id).ok then
					table.insert(actions, "reprice_cancel")
					existing = nil
					state = getState(bot.userId)
					pos = state.inventory[itemId] or 0
				end
			end
			if existing == nil and pos >= 1 then
				local count = math.min(pos, BotConfig.QuoteCopies)
				if TradeBoardService.botPost(bot.userId, bot.name, {
					kind = "sell",
					itemId = itemId,
					count = count,
					gemsPerCopy = target,
				}).ok then
					table.insert(actions, "post_sell")
					quoted += 1
					state = getState(bot.userId)
				end
			end
		end

		-- BID side: below target gem fraction we don't bid (shedding mode)
		if gemFrac >= bot.targetGemFrac * 0.6 and pos < BotConfig.MaxHoldPerItem then
			local ceiling = math.floor(math.min(r * (1 - bot.edge / 2), value * BotConfig.MaxBidVsValue) + 0.5)
			local target = math.floor(r * (1 - bot.edge) + 0.5)
			local need = neededInputs[itemId]
			if need then
				target = math.min(need, ceiling) -- recipe-justified bid
			end
			local bid = book.bestBid[itemId]
			if bid and bid + 1 <= ceiling and bid + 1 > target then
				target = bid + 1 -- outbid inside our ceiling
			end
			target = math.min(math.max(1, target), ceiling)
			local count = BotConfig.QuoteCopies
			local existing = ownBulk[itemId]
			local stale = existing
				and (now - existing.createdAt > BotConfig.RepriceSeconds
					or math.abs(existing.gemsPerCopy - target) > math.max(1, target * BotConfig.RepriceFrac))
			if existing and stale then
				if TradeBoardService.botCancel(bot.userId, existing.id).ok then
					table.insert(actions, "reprice_cancel")
					existing = nil
					state = getState(bot.userId)
					spendable = state.gems - BotConfig.MinGemsKept
				end
			end
			if existing == nil and target >= 1 and target * count <= spendable then
				if TradeBoardService.botPost(bot.userId, bot.name, {
					kind = "bulk",
					itemId = itemId,
					count = count,
					gems = target * count,
				}).ok then
					table.insert(actions, "post_bulk")
					quoted += 1
					state = getState(bot.userId)
				end
			end
		end
	end

	return actions
end

--------------------------------------------------------------------------------
-- Leader election + sweep loop
--------------------------------------------------------------------------------

local LEASE_KEY = "bots_leader"
local LEASE_SECONDS = 90
local serverId = game.JobId ~= "" and game.JobId or "studio"

local function tryAcquireLease(): boolean
	local won = false
	pcall(function()
		lockMap:UpdateAsync(LEASE_KEY, function(old)
			local now = os.time()
			if old and old.owner ~= serverId and old.expiry > now then
				return nil
			end
			won = true
			return { owner = serverId, expiry = now + LEASE_SECONDS }
		end, LEASE_SECONDS * 2)
	end)
	return won
end

local function cleanupBotListings()
	local TradeBoardService = require(script.Parent.TradeBoardService) :: any
	local n = 0
	for _, l in TradeBoardService.rawOpenListings() do
		if BotService.isBot(l.posterId) then
			TradeBoardService.botCancel(l.posterId, l.id)
			n += 1
		end
	end
	if n > 0 then
		AnalyticsService.log("bot_listings_cleaned", { count = n })
	end
end

function BotService.Init()
	StoreAdapters.init()
	botStore = StoreAdapters.dataStore("BotEconomy_v2")
	lockMap = StoreAdapters.sortedMap("BotLeader_v1")
end

function BotService.Start()
	if not BotConfig.Enabled then
		task.spawn(function()
			task.wait(5)
			cleanupBotListings()
		end)
		return
	end

	task.spawn(function()
		task.wait(3)
		local sweep = 0
		while true do
			if tryAcquireLease() then
				-- staggered seeding: spreads the CAS burst (StarterDraws+1
				-- writes per bot) across real wall-clock time so DataStore's
				-- write budget queues gracefully instead of erroring. The
				-- MessagingService side is handled centrally now —
				-- EconomyService.broadcastStats coalesces bursts on its own.
				for idx, bot in bots do
					seedBot(bot)
					if idx % 5 == 0 then
						task.wait(0.3)
					end
				end
				while tryAcquireLease() do
					sweep += 1
					local sweepStart = os.clock()
					table.clear(fairCache) -- fresh fair values each sweep

					local TradeBoardService = require(script.Parent.TradeBoardService) :: any
					local book = buildBook(TradeBoardService.rawOpenListings())

					local itemIds = {}
					for itemId, item in EconomyService.allItems() do
						if (item.assignmentWeight or 0) > 0 then
							table.insert(itemIds, itemId)
						end
					end
					table.sort(itemIds)

					local sweepActions = 0
					for idx, bot in bots do
						local ok, actions = pcall(pass, bot, book, itemIds)
						if ok then
							sweepActions += #actions
						else
							warn("[Bots] pass failed for " .. bot.name .. ": " .. tostring(actions))
						end
						if idx % 5 == 0 then
							task.wait(0.1) -- yield; spreads board ops across the sweep
						end
					end

					if sweep % BotConfig.NetworthLogEvery == 0 then
						local totalGems, richest, richestId = 0, -1, 0
						for _, bot in bots do
							local s = getState(bot.userId)
							totalGems += s.gems
							if s.gems > richest then
								richest = s.gems
								richestId = bot.userId
							end
						end
						AnalyticsService.log("bot_sweep", {
							sweep = sweep,
							actions = sweepActions,
							totalGems = totalGems,
							richestId = richestId,
							richestGems = richest,
						})
					end

					local elapsed = os.clock() - sweepStart
					task.wait(math.max(BotConfig.SweepSeconds - elapsed, 5))
				end
			end
			task.wait(LEASE_SECONDS / 2)
		end
	end)
end

return BotService
