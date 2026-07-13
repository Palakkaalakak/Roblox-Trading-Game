--!strict
-- BotService v5: 500 deterministic trading agents with REASONED demand.
--
-- Zero randomness. Each bot is a pure function of market state + its own
-- position + its index-derived numeric params (edge, gamma, target gem
-- fraction) + its ARCHETYPE. The archetype decides WHY the bot wants the
-- items it wants — demand is computed from live signals, never a hash:
--   fundamentalist -> items trading below Est. Value (mispricing)
--   momentum       -> items with rising demand (trend)
--   speculator     -> scarce items (corner supply)
--   crafter        -> inputs to a profitable active recipe (production)
--   collector      -> rare items it owns few of (completeness)
--   maker          -> no directional desire; quotes both sides tightly
-- See BotConfig for the finance background.
--
-- STATE IS IN-MEMORY. Bots run leader-local (one server holds the lease and
-- the order book), so their gems/inventory live in a plain server table — no
-- DataStore. This is deliberate and load-critical: v4 kept bot state in a
-- DataStore and every bot settlement did a synchronous UpdateAsync. With 100+
-- bots that saturated the shared DataStore request budget, which then stalled
-- PLAYER profile/inventory calls — the "my post/accept/contribute doesn't
-- register" bug. In-memory bot state is instant, never throttles players, and
-- scales to 500. Bots are simulation: a fresh server re-seeds them, no
-- durability needed.
--
-- Strategy per pass: TAKE (profit-ranked deals: lift cheap asks / fill rich
-- bids / accept +EV swaps / buy underpriced store stock / craft +EV recipes;
-- edge tightens with hunger) -> QUOTE (ask+bid on focus+desired items around
-- the inventory-skewed private reservation price) -> BARTER (one 1-for-1
-- auto-swap: give a non-desired item, want a desired one).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotConfig = require(ReplicatedStorage.Shared.Config.BotConfig)
local Tax = require(ReplicatedStorage.Shared.Util.Tax)

local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local BotService = {}

local lockMap: any -- MemoryStore map: leader lease

--------------------------------------------------------------------------------
-- Deterministic bot roster (index-derived names + params + archetype)
--------------------------------------------------------------------------------

local FIRST = { "Ada", "Brutus", "Cleo", "Dot", "Edgar", "Fern", "Gus", "Hazel", "Igor", "June" }
local LAST = { "Byte", "Copper", "Drift", "Ember", "Flux", "Gale", "Ash", "Pip", "Quill", "Sable" }

-- 100-entry bucket -> archetype id, built from BotConfig.Archetypes percentages.
-- Exact distribution; combined with a co-prime index stride it also spreads
-- archetypes evenly across the roster.
local BUCKET_ARCH: { string } = {}
do
	local b = 0
	for _, a in BotConfig.Archetypes do
		for _ = 1, a.pct do
			b += 1
			BUCKET_ARCH[b] = a.id
		end
	end
	-- pad any rounding remainder with the first archetype
	while b < 100 do
		b += 1
		BUCKET_ARCH[b] = BotConfig.Archetypes[1].id
	end
end

local bots: { any } = {}
local botsById: { [number]: any } = {}
do
	local n = BotConfig.Count
	for i = 1, n do
		local denom = math.max(n - 1, 1)
		local bot = {
			userId = -(100 + i),
			name = ("%s %s [bot]"):format(FIRST[((i - 1) % #FIRST) + 1], LAST[(math.floor((i - 1) / #FIRST) % #LAST) + 1]),
			archetype = BUCKET_ARCH[((i * 41) % 100) + 1],
			edge = BotConfig.EdgeMin + BotConfig.EdgeSpan * ((i * 7) % n) / denom,
			gamma = BotConfig.GammaMin + BotConfig.GammaSpan * ((i * 13) % n) / denom,
			targetGemFrac = BotConfig.TargetGemFracMin + BotConfig.TargetGemFracSpan * ((i * 29) % n) / denom,
			index = i,
			lastFillSweep = 0,
		}
		table.insert(bots, bot)
		botsById[bot.userId] = bot
	end
end

function BotService.isBot(userId: number): boolean
	return botsById[userId] ~= nil
end

--------------------------------------------------------------------------------
-- In-memory state (leader-local). Single Luau thread + no yields in these
-- functions => the mutations are atomic; no CAS needed.
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

local botState: { [number]: any } = {}

local function getState(botId: number): any
	local s = botState[botId]
	if s == nil then
		s = freshState()
		botState[botId] = s
	end
	return s
end

function BotService.applyDelta(botId: number, delta: { items: { [string]: number }?, gems: number? }, source: string, idempotencyKey: string?): (boolean, string?)
	local state = getState(botId)
	if idempotencyKey and state.claimed[idempotencyKey] then
		return true, nil -- already applied
	end
	local gems = delta.gems or 0
	if state.gems + gems < 0 then
		return false, "insufficient_gems"
	end
	if delta.items then
		for itemId, count in delta.items do
			if (state.inventory[itemId] or 0) + count < 0 then
				return false, "insufficient_items:" .. itemId
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
	return true, nil
end

function BotService.credit(botId: number, items: { [string]: number }, gems: number, claimId: string): boolean
	return (BotService.applyDelta(botId, { items = items, gems = gems }, "board", claimId))
end

function BotService.storeCount(botId: number, itemId: string): number
	local s = getState(botId)
	return s.storePurchases[itemId] or 0
end

function BotService.bumpStoreCount(botId: number, itemId: string)
	local s = getState(botId)
	s.storePurchases[itemId] = (s.storePurchases[itemId] or 0) + 1
end

--------------------------------------------------------------------------------
-- Seeding: deterministic round-robin draws (in-memory reserve, no DataStore)
--------------------------------------------------------------------------------

-- Per-SESSION mint tally for bot seeding. Bots are ephemeral (their state is
-- in-memory and resets each server start), so their seed inventory must NOT
-- draw from the DURABLE player economy reserve — doing that permanently
-- drained the reserve on the first run, and every run after, bots could no
-- longer draw the scarce items (their reserve was already 0), so they only
-- ever held cheap commons and net worth ceilinged. This tally resets with the
-- bots and just caps how many of each item the bot population can hold at once
-- to the item's real totalSupply, so supply scarcity is still respected.
local botMinted: { [string]: number } = {}

local function seedBot(bot: any)
	local state = getState(bot.userId)
	if state.seeded then
		return
	end
	state.seeded = true
	state.gems += BotConfig.StartGems

	local candidates = {}
	for itemId, item in EconomyService.allItems() do
		if (item.assignmentWeight or 0) > 0 then
			table.insert(candidates, itemId)
		end
	end
	table.sort(candidates) -- stable order -> deterministic draws
	if #candidates == 0 then
		return
	end
	for d = 1, BotConfig.StarterDraws do
		local itemId = candidates[((bot.index + d * 3) % #candidates) + 1]
		local item = EconomyService.getItem(itemId)
		local cap = item and item.totalSupply or 0
		if (botMinted[itemId] or 0) < cap then
			botMinted[itemId] = (botMinted[itemId] or 0) + 1
			state.inventory[itemId] = (state.inventory[itemId] or 0) + 1
		end
	end
end

--------------------------------------------------------------------------------
-- Market model (shared per sweep)
--------------------------------------------------------------------------------

-- Fair value: market Value (RAP-blended) tilted by normalized demand.
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

-- Per-sweep market signal context (computed once, shared by all bots). Every
-- number here is a real observable, which is what makes the demand "reasoned".
local RARITY_RANK = { Common = 0.15, Rare = 0.45, Legendary = 0.75, Mythical = 1.0 }
local function buildContext(itemIds: { string }, book: any)
	local ctx = {
		valueGap = {} :: { [string]: number }, -- (Value - bestAsk)/Value, underpricing
		demandNorm = {} :: { [string]: number }, -- demand EMA normalized 0..1
		scarcity = {} :: { [string]: number }, -- 1 - circulating/totalSupply
		rarity = {} :: { [string]: number }, -- rarity rank 0..1
		recipeInput = {} :: { [string]: number }, -- recipe profitability if an input
	}
	for _, itemId in itemIds do
		local snap = EconomyService.snapshot(itemId)
		local value = snap and snap.value and snap.value.value or fair(itemId)
		local ask = book.bestAsk[itemId]
		ctx.valueGap[itemId] = (ask and value > 0) and math.max(0, (value - ask) / value) or 0
		local demand = (snap and snap.demand and snap.demand.state == "Known") and (snap.demand.value or 0) or 0
		ctx.demandNorm[itemId] = math.min(demand / BotConfig.DemandRef, 1)
		local total = (snap and snap.totalSupply) or 1
		local circ = (snap and snap.supply and snap.supply.value) or 0
		ctx.scarcity[itemId] = math.clamp(1 - circ / math.max(total, 1), 0, 1)
		local item = EconomyService.getItem(itemId)
		ctx.rarity[itemId] = item and RARITY_RANK[item.rarity] or 0.3
	end

	-- recipe inputs: for each active recipe whose output beats input cost,
	-- score its inputs by the recipe's profitability margin
	local CraftingService = require(script.Parent.CraftingService) :: any
	local now = os.time()
	for _, event in CraftingService.activeEvents(now) do
		for _, recipe in event.recipes do
			local outId = CraftingService.outputIdFor(recipe.output.sku)
			local cost = recipe.gems or 0
			for inId, count in recipe.inputs do
				cost += fair(inId) * count
			end
			local margin = cost > 0 and (fair(outId) - cost) / cost or 0
			if margin > 0 then
				for inId in recipe.inputs do
					ctx.recipeInput[inId] = math.max(ctx.recipeInput[inId] or 0, margin)
				end
			end
		end
	end
	return ctx
end

-- Archetype desire score for one item (>0 means the bot wants to acquire it).
-- A small rarity floor keeps every non-maker bot expressing SOME reasoned
-- demand even when its primary signal is flat (e.g. a momentum bot before any
-- demand has built, or a fundamentalist when nothing is trading below Value):
-- absent a live signal it leans toward rarer items, which is still a real
-- reason (scarcer = more prized), never a coin flip. Its archetype signal —
-- scaled 0..1 — dominates the floor the moment it appears.
local function desireScore(bot: any, itemId: string, ctx: any, owned: number): number
	local a = bot.archetype
	local floor = (ctx.rarity[itemId] or 0.3) * 0.05
	if a == "fundamentalist" then
		return floor + (ctx.valueGap[itemId] or 0)
	elseif a == "momentum" then
		return floor + (ctx.demandNorm[itemId] or 0)
	elseif a == "speculator" then
		return floor + (ctx.scarcity[itemId] or 0)
	elseif a == "crafter" then
		return floor + (ctx.recipeInput[itemId] or 0)
	elseif a == "collector" then
		return floor + (ctx.rarity[itemId] or 0) / (1 + owned)
	end
	return 0 -- maker: no directional desire
end

-- The DesireCount items this bot most wants right now, by its archetype's
-- reasoned score. Deterministic (score desc, itemId tiebreak). Stashed as
-- bot.desired for the pass. Makers desire nothing (they quote both sides).
local function computeDesires(bot: any, itemIds: { string }, ctx: any, state: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if bot.archetype == "maker" then
		return set
	end
	local scored = {}
	for _, itemId in itemIds do
		local s = desireScore(bot, itemId, ctx, state.inventory[itemId] or 0)
		if s > 0 then
			table.insert(scored, { id = itemId, s = s })
		end
	end
	table.sort(scored, function(x, y)
		if x.s ~= y.s then
			return x.s > y.s
		end
		return x.id < y.id
	end)
	for k = 1, math.min(BotConfig.DesireCount, #scored) do
		set[scored[k].id] = true
	end
	return set
end

-- Private-value multiplier. Makers value everything at true fair (neutral —
-- they earn the spread, not a directional view). Others boost desired items
-- and trim the rest; the boosted-bid/trimmed-ask overlap is what clears.
local function pref(bot: any, itemId: string): number
	if bot.archetype == "maker" then
		return 1
	end
	if bot.desired and bot.desired[itemId] then
		return 1 + BotConfig.PrefBoost
	end
	return 1 - BotConfig.PrefTrim
end

-- Reservation price: PRIVATE value (fair x pref) skewed against position.
local function reservation(bot: any, itemId: string, position: number): number
	local excess = (position - BotConfig.TargetHoldPerItem) / BotConfig.SkewScale
	return fair(itemId) * pref(bot, itemId) * (1 - bot.gamma * excess)
end

-- Hunger: edge tightens every sweep without a fill, so a frozen book unfreezes.
local function effectiveEdge(bot: any, sweep: number): number
	local starved = sweep - (bot.lastFillSweep or 0)
	return math.max(BotConfig.MinEdge, bot.edge / (1 + BotConfig.HungerEdgeDecay * starved))
end

-- Book view built once per sweep: best ask/bid per item + raw lists.
local function buildBook(listings: { any })
	local book = {
		sells = {} :: { any },
		bulks = {} :: { any },
		swaps = {} :: { any },
		bestAsk = {} :: { [string]: number },
		bestBid = {} :: { [string]: number },
		ownOpen = {} :: { [number]: { any } },
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

local function pass(bot: any, book: any, itemIds: { string }, ctx: any, sweep: number): { string }
	local TradeBoardService = require(script.Parent.TradeBoardService) :: any
	local StoreService = require(script.Parent.StoreService) :: any
	local CraftingService = require(script.Parent.CraftingService) :: any

	local state = getState(bot.userId)
	bot.desired = computeDesires(bot, itemIds, ctx, state)
	local edge = effectiveEdge(bot, sweep)
	local actions: { string } = {}

	-- position value + escrow-inclusive net worth
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

	if gemFrac > bot.targetGemFrac * 0.5 then
		for _, l in book.sells do
			if l.posterId ~= bot.userId and l.remainingCount > 0 then
				local pos = state.inventory[l.itemId] or 0
				local r = reservation(bot, l.itemId, pos)
				if l.gemsPerCopy <= r * (1 - edge) and pos < BotConfig.MaxHoldPerItem and l.gemsPerCopy <= spendable then
					local count = math.min(l.remainingCount, math.floor(spendable / l.gemsPerCopy), BotConfig.QuoteCopies)
					if count >= 1 then
						table.insert(candidates, {
							profit = (r - l.gemsPerCopy) * count,
							tag = "buy_sell_listing",
							run = function()
								local res = TradeBoardService.botBuy(bot.userId, bot.name, l.id, count)
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
	end
	for _, l in book.bulks do
		if l.posterId ~= bot.userId and l.remainingCount > 0 then
			local owned = state.inventory[l.itemId] or 0
			if owned >= 1 then
				local r = reservation(bot, l.itemId, owned)
				local net = Tax.split(l.gemsPerCopy)
				if net >= r * (1 + edge) then
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
	for _, l in book.swaps do
		if l.posterId ~= bot.userId and l.status == "open" then
			local receive = Tax.split(l.give.gems)
			for itemId, count in l.give.items do
				receive += fair(itemId) * pref(bot, itemId) * count
			end
			local pay = l.want.gems
			local canPay = l.want.gems <= spendable
			for itemId, count in l.want.items do
				pay += reservation(bot, itemId, state.inventory[itemId] or 0) * count
				if (state.inventory[itemId] or 0) < count then
					canPay = false
				end
			end
			if canPay and pay > 0 and receive - pay >= edge * pay then
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
	if gemFrac > bot.targetGemFrac * 0.5 then
		for _, s in StoreService.shelfForBots() do
			local pos = state.inventory[s.itemId] or 0
			local r = reservation(bot, s.itemId, pos)
			if s.price <= r * (1 - edge) and s.price <= spendable and pos < BotConfig.MaxHoldPerItem then
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
	local neededInputs: { [string]: number } = {}
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
				if outFair >= cost * (1 + edge) then
					if haveAll then
						table.insert(candidates, {
							profit = outFair - cost,
							tag = "craft",
							run = function()
								return CraftingService.botCraft(bot.userId, event.id, recipe.rid).ok == true
							end,
						})
					else
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
		return a.tag < b.tag
	end)
	local taken = 0
	for _, c in candidates do
		if taken >= BotConfig.TakesPerPass then
			break
		end
		if c.run() then
			taken += 1
			table.insert(actions, c.tag)
			bot.lastFillSweep = sweep
			spendable = state.gems - BotConfig.MinGemsKept
		end
	end

	----------------------------------------------------------------------
	-- QUOTE: maintain ask+bid on focus + desired items (+ needed inputs)
	----------------------------------------------------------------------
	local focus: { [string]: boolean } = {}
	if #itemIds > 0 then
		for k = 0, BotConfig.QuoteItemsPerBot - 1 do
			focus[itemIds[((bot.index * 3 + k * 41) % #itemIds) + 1]] = true
		end
	end
	for itemId in bot.desired do
		focus[itemId] = true
	end
	for itemId in neededInputs do
		focus[itemId] = true
	end
	for itemId, count in state.inventory do
		if count > BotConfig.MaxHoldPerItem then
			focus[itemId] = true
		end
	end
	local focusList = {}
	for itemId in focus do
		table.insert(focusList, itemId)
	end
	table.sort(focusList)

	local ownSell: { [string]: any } = {}
	local ownBulk: { [string]: any } = {}
	local ownSwaps: { any } = {}
	for _, l in book.ownOpen[bot.userId] or {} do
		if l.kind == "sell" then
			ownSell[l.itemId] = l
		elseif l.kind == "bulk" then
			ownBulk[l.itemId] = l
		elseif l.kind == "swap" then
			table.insert(ownSwaps, l)
		end
	end

	local quoted = 0
	for _, itemId in focusList do
		if quoted >= 2 then
			break
		end
		local value = EconomyService.valueOf(itemId)
		local pos = state.inventory[itemId] or 0
		local r = reservation(bot, itemId, pos)

		if pos >= 1 then
			local floorPrice = math.max(1, math.floor(math.max(r * (1 + edge / 2), value * BotConfig.MinSellVsValue) + 0.5))
			local target = math.floor(r * (1 + edge) + 0.5)
			local ask = book.bestAsk[itemId]
			if ask and ask - 1 >= floorPrice and ask - 1 < target then
				target = ask - 1
			end
			target = math.max(target, floorPrice)
			local existing = ownSell[itemId]
			local drifted = existing
				and math.abs(existing.gemsPerCopy - target) > math.max(1, target * BotConfig.RepriceFrac)
			if existing and drifted then
				if TradeBoardService.botCancel(bot.userId, existing.id).ok then
					table.insert(actions, "reprice_cancel")
					existing = nil
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
				end
			end
		end

		if gemFrac >= bot.targetGemFrac * 0.6 and pos < BotConfig.MaxHoldPerItem then
			local ceiling = math.floor(math.min(r * (1 - edge / 2), value * BotConfig.MaxBidVsValue) + 0.5)
			local target = math.floor(r * (1 - edge) + 0.5)
			local need = neededInputs[itemId]
			if need then
				target = math.min(need, ceiling)
			end
			local bid = book.bestBid[itemId]
			if bid and bid + 1 <= ceiling and bid + 1 > target then
				target = bid + 1
			end
			target = math.min(math.max(1, target), ceiling)
			local count = BotConfig.QuoteCopies
			local existing = ownBulk[itemId]
			local drifted = existing
				and math.abs(existing.gemsPerCopy - target) > math.max(1, target * BotConfig.RepriceFrac)
			if existing and drifted then
				if TradeBoardService.botCancel(bot.userId, existing.id).ok then
					table.insert(actions, "reprice_cancel")
					existing = nil
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
				end
			end
		end
	end

	----------------------------------------------------------------------
	-- BARTER: keep one 1-for-1 auto-swap open (give non-desired, want
	-- desired, comparable fair value). Opposite-taste bots accept it.
	----------------------------------------------------------------------
	local openSwap: any = nil
	for _, l in ownSwaps do
		local wantId = next(l.want.items)
		if wantId == nil or not bot.desired[wantId] then
			if TradeBoardService.botCancel(bot.userId, l.id).ok then
				table.insert(actions, "swap_retire")
			end
		elseif openSwap == nil then
			openSwap = l
		end
	end
	if openSwap == nil and next(bot.desired) ~= nil then
		local giveId: string? = nil
		for itemId, count in state.inventory do
			if count >= 1 and not bot.desired[itemId] then
				if giveId == nil or fair(itemId) > fair(giveId) or (fair(itemId) == fair(giveId) and itemId < giveId) then
					giveId = itemId
				end
			end
		end
		if giveId then
			local giveFair = fair(giveId)
			local wantId: string? = nil
			local wantIds = {}
			for itemId in bot.desired do
				table.insert(wantIds, itemId)
			end
			table.sort(wantIds)
			for _, itemId in wantIds do
				if (state.inventory[itemId] or 0) < BotConfig.TargetHoldPerItem then
					local gap = math.abs(fair(itemId) - giveFair) / math.max(giveFair, 1)
					if gap <= BotConfig.SwapMaxValueGap then
						wantId = itemId
						break
					end
				end
			end
			if wantId then
				if TradeBoardService.botPost(bot.userId, bot.name, {
					kind = "swap",
					give = { items = { [giveId] = 1 }, gems = 0 },
					want = { items = { [wantId] = 1 }, gems = 0 },
					autoTrade = true,
				}).ok then
					table.insert(actions, "post_swap")
				end
			end
		end
	end

	return actions
end

--------------------------------------------------------------------------------
-- Admin inspector snapshot (temporary; gated remote in Start)
--------------------------------------------------------------------------------

function BotService.debugSnapshot(): any
	local rows = {}
	local totalGems, totalWorth = 0, 0
	local archCounts: { [string]: number } = {}

	-- ESCROW: gems/items locked in a bot's open listings have LEFT its
	-- inventory but are still its wealth. Sum per-poster escrow from the board
	-- so net worth is accurate — without this a bot with a 500-gem mythical
	-- sitting in an unsold sell listing looks 500 poorer than it is (that was
	-- the "net worth stuck at ~361" artifact).
	local escrowByBot: { [number]: number } = {}
	local escrowTotal = 0
	local listingsSeen = 0
	local okBoard, listings = pcall(function()
		return (require(script.Parent.TradeBoardService) :: any).rawOpenListings(20000)
	end)
	if okBoard and listings then
		listingsSeen = #listings
		for _, l in listings do
			if l.posterId < 0 then
				local e = escrowByBot[l.posterId] or 0
				if l.kind == "sell" then
					e += EconomyService.valueOf(l.itemId) * (l.remainingCount or 0)
				elseif l.kind == "bulk" then
					e += (l.gemsPerCopy or 0) * (l.remainingCount or 0)
				elseif l.kind == "swap" and l.give then
					e += (l.give.gems or 0)
					for itemId, count in l.give.items do
						e += EconomyService.valueOf(itemId) * count
					end
				end
				escrowByBot[l.posterId] = e
			end
		end
		for _, e in escrowByBot do
			escrowTotal += e
		end
	end

	-- use valueOf (not the shared per-sweep fairCache) so an admin fetch never
	-- clobbers an in-flight sweep's cached fair values
	local mythHold = 0
	for _, bot in bots do
		local s = getState(bot.userId)
		local invValue, invCount = 0, 0
		for itemId, count in s.inventory do
			invValue += EconomyService.valueOf(itemId) * count
			invCount += count
			if itemId == "itm_1_11_void_shard" or itemId == "itm_1_12_astral_prism" then
				mythHold += count
			end
		end
		invValue += escrowByBot[bot.userId] or 0
		local worth = s.gems + invValue
		totalGems += s.gems
		totalWorth += worth
		archCounts[bot.archetype] = (archCounts[bot.archetype] or 0) + 1
		local desired = {}
		if bot.desired then
			for itemId in bot.desired do
				local item = EconomyService.getItem(itemId)
				table.insert(desired, item and item.name or itemId)
			end
			table.sort(desired)
		end
		table.insert(rows, {
			name = bot.name,
			archetype = bot.archetype,
			gems = s.gems,
			invCount = invCount,
			invValue = math.floor(invValue + 0.5),
			worth = math.floor(worth + 0.5),
			earned = s.lifetime.earned,
			spent = s.lifetime.spent,
			desired = desired,
		})
	end
	table.sort(rows, function(a, b)
		return a.worth > b.worth
	end)
	return {
		count = #bots,
		totalGems = totalGems,
		totalWorth = math.floor(totalWorth + 0.5),
		archCounts = archCounts,
		bots = rows,
		_diag = {
			escrowOk = okBoard,
			listingsSeen = listingsSeen,
			escrowTotal = math.floor(escrowTotal + 0.5),
			mythicalHeldInInventory = mythHold,
		},
	}
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
	lockMap = StoreAdapters.sortedMap("BotLeader_v1")
end

function BotService.Start()
	-- admin-only inspector remote (temporary). Gated to DebugConfig.AdminUserIds.
	local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
	local Net = require(script.Parent.Parent.Net)
	Net.bindFunction("GetBotData", function(player)
		if not (DebugConfig.AdminUserIds and DebugConfig.AdminUserIds[player.UserId]) then
			return { ok = false, err = "not_admin" }
		end
		return { ok = true, data = BotService.debugSnapshot() }
	end)

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
				-- seeding is in-memory now (no DataStore) — fast; light yields
				-- only to avoid a single-frame hitch across 500 bots.
				for idx, bot in bots do
					seedBot(bot)
					if idx % 50 == 0 then
						task.wait()
					end
				end
				while tryAcquireLease() do
					sweep += 1
					local sweepStart = os.clock()
					table.clear(fairCache)

					local TradeBoardService = require(script.Parent.TradeBoardService) :: any
					local book = buildBook(TradeBoardService.rawOpenListings())

					local itemIds = {}
					for itemId, item in EconomyService.allItems() do
						if (item.assignmentWeight or 0) > 0 then
							table.insert(itemIds, itemId)
						end
					end
					table.sort(itemIds)

					local ctx = buildContext(itemIds, book)

					local sweepActions = 0
					for idx, bot in bots do
						local ok, actions = pcall(pass, bot, book, itemIds, ctx, sweep)
						if ok then
							sweepActions += #actions
						else
							warn("[Bots] pass failed for " .. bot.name .. ": " .. tostring(actions))
						end
						if idx % 60 == 0 then
							task.wait() -- yield sparingly; passes are in-memory + fast
						end
					end

					if sweep % BotConfig.StipendEvery == 0 then
						for _, bot in bots do
							local s = getState(bot.userId)
							if s.gems < BotConfig.StipendBelowGems then
								BotService.applyDelta(bot.userId, { gems = BotConfig.StipendGems }, "stipend")
							end
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
					task.wait(math.max(BotConfig.SweepSeconds - elapsed, 0.5))
				end
			end
			task.wait(LEASE_SECONDS / 2)
		end
	end)
end

return BotService
