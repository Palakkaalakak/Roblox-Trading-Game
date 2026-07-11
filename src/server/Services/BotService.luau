--!strict
-- BotService: profit-seeking market bots that behave like real players.
--
-- Each bot has durable state (inventory + gems + store-buy caps) in its own
-- DataStore key, mutated with the same validate-all-then-apply + idempotency
-- semantics as real profiles. All acting goes through the REAL flows —
-- trade board (TradeBoardService bot* entries), the NPC gem store
-- (StoreService.botBuy) and event crafting (CraftingService.botCraft) — so
-- every bot deal is indistinguishable from a player deal to the economy.
--
-- Brain: each bot holds a persistent per-item price OPINION (bounded random
-- walk around market value). A pass scores every available deal — board
-- sells/bulks/swaps, store stock, craft recipes — by expected profit against
-- its own opinion, executes the best few, then places/refreshes one quote of
-- its own (undercutting the best competing ask / outbidding the best bid,
-- inside guard rails). Opinions disagreeing across bots is what makes them
-- trade with each other fast; the guard rails keep prices tethered.
--
-- Multi-server safety: one server runs the brains (MemoryStore leader
-- lease); state writes are CAS so any server can settle deals against bots.
--
-- BotConfig.Enabled = false -> brains never start AND leftover bot listings
-- are cancelled at boot (escrow refunds back into bot state).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotConfig = require(ReplicatedStorage.Shared.Config.BotConfig)
local Tax = require(ReplicatedStorage.Shared.Util.Tax)

local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local BotService = {}

local botStore: any -- DataStore "BotEconomy_v1", key "bot_<-id>"
local lockMap: any -- MemoryStore map: leader lease
local botsById: { [number]: any } = {}
for _, b in BotConfig.Bots do
	botsById[b.userId] = b
end

local LEASE_KEY = "bots_leader"
local LEASE_SECONDS = 60
local serverId = game.JobId ~= "" and game.JobId or "studio"

local function stateKey(botId: number): string
	return "bot_" .. tostring(-botId)
end

function BotService.isBot(userId: number): boolean
	return botsById[userId] ~= nil
end

--------------------------------------------------------------------------------
-- Durable state (CAS; any server may credit)
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

-- Atomic validate-then-apply, same semantics as InventoryService.applyDelta.
function BotService.applyDelta(botId: number, delta: { items: { [string]: number }?, gems: number? }, source: string, idempotencyKey: string?): (boolean, string?)
	local errOut: string? = nil
	local ok = pcall(function()
		botStore:UpdateAsync(stateKey(botId), function(state)
			state = state or freshState()
			if idempotencyKey and state.claimed[idempotencyKey] then
				errOut = nil
				return state -- already applied
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
	return errOut == nil, errOut
end

-- deliver() counterpart for bots: goods from a settled deal land here.
function BotService.credit(botId: number, items: { [string]: number }, gems: number, claimId: string): boolean
	return (BotService.applyDelta(botId, { items = items, gems = gems }, "board", claimId))
end

-- store buy-cap bookkeeping (bots respect the same per-buyer limits)
function BotService.storeCount(botId: number, itemId: string): number
	local n = 0
	pcall(function()
		local s = botStore:GetAsync(stateKey(botId))
		n = s and s.storePurchases and s.storePurchases[itemId] or 0
	end)
	return n
end

function BotService.bumpStoreCount(botId: number, itemId: string)
	pcall(function()
		botStore:UpdateAsync(stateKey(botId), function(s)
			s = s or freshState()
			s.storePurchases = s.storePurchases or {}
			s.storePurchases[itemId] = (s.storePurchases[itemId] or 0) + 1
			return s
		end)
	end)
end

local function getState(botId: number): any
	local state
	pcall(function()
		state = botStore:GetAsync(stateKey(botId))
	end)
	return state or freshState()
end

--------------------------------------------------------------------------------
-- Seeding: bots enter the economy exactly like players — reserve draws
--------------------------------------------------------------------------------

local function seedBot(bot: any)
	local state = getState(bot.userId)
	if state.seeded then
		return
	end
	local granted: { [string]: number } = {}
	local drawn = 0
	local candidates = {}
	for itemId, item in EconomyService.allItems() do
		if (item.assignmentWeight or 0) > 0 then
			table.insert(candidates, itemId)
		end
	end
	while drawn < BotConfig.StarterDraws and #candidates > 0 do
		local itemId = candidates[math.random(#candidates)]
		local ok = EconomyService.reserveOne(itemId)
		if ok then
			granted[itemId] = (granted[itemId] or 0) + 1
			drawn += 1
		else
			for i, id in candidates do
				if id == itemId then
					table.remove(candidates, i)
					break
				end
			end
		end
	end
	pcall(function()
		botStore:UpdateAsync(stateKey(bot.userId), function(s)
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
	end)
	AnalyticsService.log("bot_seeded", { botId = bot.userId, items = granted, gems = BotConfig.StartGems })
end

--------------------------------------------------------------------------------
-- Opinions (leader-local; per bot per item, bounded random walk)
--------------------------------------------------------------------------------

local opinions: { [number]: { [string]: number } } = {}

local function opinionOf(botId: number, itemId: string): number
	local mine = opinions[botId]
	if mine == nil then
		mine = {}
		opinions[botId] = mine
	end
	local o = mine[itemId]
	if o == nil then
		-- start spread out so bots disagree from the very first pass
		o = 1 + (math.random() * 2 - 1) * BotConfig.OpinionBound * 0.75
	end
	-- drift
	o += (math.random() * 2 - 1) * BotConfig.OpinionWalkStep
	o = math.clamp(o, 1 - BotConfig.OpinionBound, 1 + BotConfig.OpinionBound)
	mine[itemId] = o
	return o
end

--------------------------------------------------------------------------------
-- Brain
--------------------------------------------------------------------------------

local passCount: { [number]: number } = {}

local function think(bot: any): { string }
	local TradeBoardService = require(script.Parent.TradeBoardService) :: any
	local StoreService = require(script.Parent.StoreService) :: any
	local CraftingService = require(script.Parent.CraftingService) :: any

	local state = getState(bot.userId)
	local margin = bot.margin
	local actions: { string } = {}

	-- my perceived worth of an item right now
	local function pv(itemId: string): number
		local noise = 1 + (math.random() * 2 - 1) * BotConfig.DecisionNoise
		return EconomyService.valueOf(itemId) * opinionOf(bot.userId, itemId) * noise
	end

	-- net worth split -> portfolio pressure
	local invValue = 0
	for itemId, count in state.inventory do
		invValue += EconomyService.valueOf(itemId) * count
	end
	local worth = state.gems + invValue
	local gemFrac = worth > 0 and state.gems / worth or 1
	local mustSell = gemFrac < BotConfig.GemFractionLow
	local eagerBuy = gemFrac > BotConfig.GemFractionHigh

	local spendable = state.gems - BotConfig.MinGemsKept
	local listings = TradeBoardService.rawOpenListings()

	----------------------------------------------------------------------
	-- TAKE: score every available deal by expected profit, run the best few
	----------------------------------------------------------------------
	local candidates: { { profit: number, run: () -> boolean, tag: string } } = {}

	if not mustSell then
		-- board sell listings -> buy underpriced
		for _, l in listings do
			if l.kind == "sell" and l.posterId ~= bot.userId then
				local worthEach = pv(l.itemId)
				local owned = state.inventory[l.itemId] or 0
				if l.gemsPerCopy <= worthEach * (1 - margin) and owned < BotConfig.MaxHoldPerItem and l.gemsPerCopy <= spendable then
					local count = math.min(l.remainingCount, math.floor(spendable / l.gemsPerCopy), 3)
					if count >= 1 then
						table.insert(candidates, {
							profit = (worthEach - l.gemsPerCopy) * count,
							tag = "buy_sell_listing",
							run = function()
								return TradeBoardService.botBuy(bot.userId, bot.name, l.id, count).ok == true
							end,
						})
					end
				end
			end
		end
		-- store stock -> buy when my opinion beats the fixed price
		for _, s in StoreService.shelfForBots() do
			local worthEach = pv(s.itemId)
			local owned = state.inventory[s.itemId] or 0
			if s.price <= worthEach * (1 - margin) and s.price <= spendable and owned < BotConfig.MaxHoldPerItem then
				table.insert(candidates, {
					profit = worthEach - s.price,
					tag = "store_buy",
					run = function()
						return StoreService.botBuy(bot.userId, s.itemId).ok == true
					end,
				})
			end
		end
		-- craftable events -> craft when output beats total input cost
		local now = os.time()
		for _, event in CraftingService.activeEvents(now) do
			for _, recipe in event.recipes do
				local outId = CraftingService.outputIdFor(recipe.output.sku)
				local cost = recipe.gems or 0
				local affordable = cost <= spendable
				for itemId, count in recipe.inputs do
					cost += pv(itemId) * count
					if (state.inventory[itemId] or 0) < count then
						affordable = false
					end
				end
				local outWorth = pv(outId)
				if affordable and outWorth >= cost * (1 + margin) then
					table.insert(candidates, {
						profit = outWorth - cost,
						tag = "craft",
						run = function()
							return CraftingService.botCraft(bot.userId, event.id, recipe.rid).ok == true
						end,
					})
				end
			end
		end
		-- auto swaps -> accept profitable barters
		for _, l in listings do
			if l.kind == "swap" and l.autoTrade and l.posterId ~= bot.userId then
				local receive = Tax.split(l.give.gems)
				for itemId, count in l.give.items do
					receive += pv(itemId) * count
				end
				local pay = l.want.gems
				local canPay = l.want.gems <= spendable
				for itemId, count in l.want.items do
					pay += pv(itemId) * count
					if (state.inventory[itemId] or 0) < count then
						canPay = false
					end
				end
				if canPay and pay > 0 and receive - pay >= margin * pay then
					table.insert(candidates, {
						profit = receive - pay,
						tag = "accept_swap",
						run = function()
							return TradeBoardService.botAccept(bot.userId, bot.name, l.id).ok == true
						end,
					})
				end
			end
		end
	end
	-- bulk orders -> sell into overpayers (always allowed; this RAISES gems)
	for _, l in listings do
		if l.kind == "bulk" and l.posterId ~= bot.userId then
			local owned = state.inventory[l.itemId] or 0
			if owned >= 1 then
				local worthEach = pv(l.itemId)
				local net = Tax.split(l.gemsPerCopy)
				local threshold = mustSell and 1.0 or (1 + margin / 2)
				if net >= worthEach * threshold then
					local count = math.min(owned, l.remainingCount)
					table.insert(candidates, {
						profit = (net - worthEach) * count + (mustSell and 1 or 0),
						tag = "fill_bulk",
						run = function()
							return TradeBoardService.botContribute(bot.userId, bot.name, l.id, count).ok == true
						end,
					})
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.profit > b.profit
	end)
	for i = 1, math.min(#candidates, BotConfig.TakesPerTick) do
		if candidates[i].run() then
			table.insert(actions, candidates[i].tag)
			state = getState(bot.userId) -- refresh after each executed deal
			spendable = state.gems - BotConfig.MinGemsKept
		end
	end

	----------------------------------------------------------------------
	-- MAKE: refresh stale quotes, then place one new quote
	----------------------------------------------------------------------
	local ownCount = 0
	local now = os.time()
	for _, l in listings do
		if l.posterId == bot.userId then
			ownCount += 1
			if now - l.createdAt > BotConfig.RepriceSeconds then
				if TradeBoardService.botCancel(bot.userId, l.id).ok then
					table.insert(actions, "reprice_cancel")
					ownCount -= 1
					break -- one refresh per pass
				end
			end
		end
	end

	if ownCount < BotConfig.MaxListingsPerBot then
		-- competing quotes per item (to undercut / outbid)
		local bestAsk: { [string]: number } = {}
		local bestBid: { [string]: number } = {}
		for _, l in listings do
			if l.kind == "sell" then
				bestAsk[l.itemId] = math.min(bestAsk[l.itemId] or math.huge, l.gemsPerCopy)
			elseif l.kind == "bulk" then
				bestBid[l.itemId] = math.max(bestBid[l.itemId] or 0, l.gemsPerCopy)
			end
		end

		-- SELL: quote the item where the market looks most generous vs my
		-- own opinion (or where I'm overweight when under sell pressure)
		local sellItem: string? = nil
		local sellScore = -math.huge
		for itemId, count in state.inventory do
			if count >= 1 then
				local value = EconomyService.valueOf(itemId)
				local myWorth = pv(itemId)
				local floorPrice = math.max(1, math.floor(math.max(myWorth * (1 + margin / 2), value * BotConfig.MinSellVsValue) + 0.5))
				local ask = bestAsk[itemId]
				local price = if ask and ask - 1 >= floorPrice then ask - 1 else math.floor(myWorth * (1 + margin) + 0.5)
				price = math.max(price, floorPrice)
				local score = (price - myWorth) + (mustSell and count * 2 or 0)
				if score > sellScore then
					sellScore = score
					sellItem = itemId
				end
			end
		end
		local didMake = false
		if sellItem and (mustSell or math.random() < 0.75) then
			local value = EconomyService.valueOf(sellItem)
			local myWorth = pv(sellItem)
			local floorPrice = math.max(1, math.floor(math.max(myWorth * (1 + margin / 2), value * BotConfig.MinSellVsValue) + 0.5))
			local ask = bestAsk[sellItem]
			local price = if ask and ask - 1 >= floorPrice then ask - 1 else math.floor(myWorth * (1 + margin) + 0.5)
			price = math.max(price, floorPrice)
			local count = math.min(state.inventory[sellItem], 2)
			if TradeBoardService.botPost(bot.userId, bot.name, {
				kind = "sell",
				itemId = sellItem,
				count = count,
				gemsPerCopy = price,
			}).ok then
				table.insert(actions, "post_sell")
				didMake = true
			end
		end

		-- BID: post/raise a bulk order for something I want cheap
		if not didMake and not mustSell and (eagerBuy or math.random() < 0.5) then
			local pool = {}
			for itemId, item in EconomyService.allItems() do
				if (item.assignmentWeight or 0) > 0 and (state.inventory[itemId] or 0) < BotConfig.MaxHoldPerItem then
					table.insert(pool, itemId)
				end
			end
			if #pool > 0 then
				local itemId = pool[math.random(#pool)]
				local value = EconomyService.valueOf(itemId)
				local myWorth = pv(itemId)
				local ceiling = math.floor(math.min(myWorth * (1 - margin / 2), value * BotConfig.MaxBidVsValue) + 0.5)
				local bid = bestBid[itemId]
				local perCopy = if bid and bid + 1 <= ceiling then bid + 1 else math.floor(myWorth * (1 - margin) + 0.5)
				perCopy = math.min(math.max(1, perCopy), ceiling)
				local count = 2
				if perCopy >= 1 and perCopy * count <= spendable then
					if TradeBoardService.botPost(bot.userId, bot.name, {
						kind = "bulk",
						itemId = itemId,
						count = count,
						gems = perCopy * count,
					}).ok then
						table.insert(actions, "post_bulk")
					end
				end
			end
		end
	end

	-- periodic net-worth telemetry for the AFK run
	passCount[bot.userId] = (passCount[bot.userId] or 0) + 1
	if passCount[bot.userId] % BotConfig.NetworthLogEvery == 0 then
		AnalyticsService.log("bot_networth", {
			botId = bot.userId,
			gems = state.gems,
			invValue = math.floor(invValue + 0.5),
			worth = math.floor(worth + 0.5),
		})
	end

	return actions
end

--------------------------------------------------------------------------------
-- Leader election + loop
--------------------------------------------------------------------------------

local function tryAcquireLease(): boolean
	local won = false
	pcall(function()
		lockMap:UpdateAsync(LEASE_KEY, function(old)
			local now = os.time()
			if old and old.owner ~= serverId and old.expiry > now then
				return nil -- someone else holds it
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
	botStore = StoreAdapters.dataStore("BotEconomy_v1")
	lockMap = StoreAdapters.sortedMap("BotLeader_v1")
end

function BotService.Start()
	if not BotConfig.Enabled then
		-- kill switch: no brains, and sweep any listings bots left behind
		task.spawn(function()
			task.wait(5) -- let the board come up
			cleanupBotListings()
		end)
		return
	end

	task.spawn(function()
		task.wait(3) -- board + economy warm
		while true do
			if tryAcquireLease() then
				for _, bot in BotConfig.Bots do
					seedBot(bot)
				end
				while tryAcquireLease() do
					for _, bot in BotConfig.Bots do
						local ok, actions = pcall(think, bot)
						if ok and #actions > 0 then
							AnalyticsService.log("bot_action", { botId = bot.userId, actions = actions })
						elseif not ok then
							warn("[Bots] think failed for " .. bot.name .. ": " .. tostring(actions))
						end
						task.wait(BotConfig.TickSeconds * (0.5 + math.random()))
					end
				end
			end
			task.wait(LEASE_SECONDS / 2) -- not leader: check again later
		end
	end)
end

return BotService
