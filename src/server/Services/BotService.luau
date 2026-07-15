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
-- Strategy per pass — they trade like Roblox players, not market makers:
--   TRADE DOWN   accept an open upgrade offer: hand over the one high item,
--                take the bundle worth more. That Win is how worth compounds.
--   SNIPE        buy a gem listing priced under what the item is worth.
--   FILL BULK    supply copies to someone paying over the odds in gems.
--   STORE        buy fixed-price stock under market value (supply faucet).
--   CRAFT        burn cheap inputs -> mint an output worth +10% (VALUE faucet:
--                the only way aggregate wealth actually grows, since barter is
--                zero-sum minus tax; also a demand sink on the inputs).
--   TRADE UP     bundle my cheapest spare items + a gem sweetener and offer
--                them for ONE item I want, overpaying a premium — the premium
--                is what makes a holder willing to part with it.
--   LIQUIDATE    if gem-poor, list ONE spare item for gems (store/craft money).
-- Hunger tightens a starved bot's required margin so the book never freezes.

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
			-- trading-up premium this bot offers, and the minimum Win it demands
			-- before trading down. Trades clear where one bot's overpay exceeds
			-- another's acceptEdge.
			overpay = BotConfig.OverpayMin + BotConfig.OverpaySpan * ((i * 17) % n) / denom,
			acceptEdge = BotConfig.AcceptEdgeMin + BotConfig.AcceptEdgeSpan * ((i * 23) % n) / denom,
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
-- One bot pass: trade the way a Roblox player trades
--------------------------------------------------------------------------------

-- This bot's PRIVATE valuation of an item (taste-adjusted). Two bots wanting
-- different things is exactly what lets one swap be a Win on both their books.
local function myVal(bot: any, itemId: string): number
	return fair(itemId) * pref(bot, itemId)
end

-- Total value of one side of an offer, from this bot's perspective.
local function offerValue(bot: any, offer: any): number
	local v = offer.gems or 0
	for itemId, count in offer.items do
		v += myVal(bot, itemId) * count
	end
	return v
end

local function pass(bot: any, book: any, itemIds: { string }, ctx: any, sweep: number): { string }
	local TradeBoardService = require(script.Parent.TradeBoardService) :: any
	local StoreService = require(script.Parent.StoreService) :: any
	local CraftingService = require(script.Parent.CraftingService) :: any

	local state = getState(bot.userId)
	bot.desired = computeDesires(bot, itemIds, ctx, state)
	local edge = effectiveEdge(bot, sweep)
	-- hunger also relaxes how big a Win a starved bot holds out for
	local starved = sweep - (bot.lastFillSweep or 0)
	local acceptEdge = math.max(0, bot.acceptEdge / (1 + BotConfig.HungerEdgeDecay * starved))
	local actions: { string } = {}
	local spendable = state.gems - BotConfig.MinGemsKept

	local candidates: { { profit: number, tag: string, run: () -> boolean } } = {}

	----------------------------------------------------------------------
	-- TRADE DOWN: accept an upgrade offer — hand over the single high item,
	-- take the bundle worth more. This Win is how net worth compounds.
	----------------------------------------------------------------------
	for _, l in book.swaps do
		if l.posterId ~= bot.userId and l.status == "open" then
			local receive = offerValue(bot, l.give)
			local pay = offerValue(bot, l.want)
			local canPay = (l.want.gems or 0) <= spendable
			for itemId, count in l.want.items do
				if (state.inventory[itemId] or 0) < count then
					canPay = false
				end
			end
			if canPay and pay > 0 and receive >= pay * (1 + acceptEdge) then
				table.insert(candidates, {
					profit = receive - pay,
					tag = "trade_down",
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

	----------------------------------------------------------------------
	-- SNIPE: someone listed an item for gems well under what it's worth.
	----------------------------------------------------------------------
	for _, l in book.sells do
		if l.posterId ~= bot.userId and l.remainingCount > 0 then
			local pos = state.inventory[l.itemId] or 0
			local v = myVal(bot, l.itemId)
			if l.gemsPerCopy <= v * (1 - edge) and pos < BotConfig.MaxHoldPerItem and l.gemsPerCopy <= spendable then
				local count = math.min(l.remainingCount, math.floor(spendable / math.max(l.gemsPerCopy, 1)), 2)
				if count >= 1 then
					table.insert(candidates, {
						profit = (v - l.gemsPerCopy) * count,
						tag = "snipe_listing",
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

	----------------------------------------------------------------------
	-- SUPPLY a bulk order: someone is paying over the odds in gems for copies.
	----------------------------------------------------------------------
	for _, l in book.bulks do
		if l.posterId ~= bot.userId and l.remainingCount > 0 then
			local owned = state.inventory[l.itemId] or 0
			if owned >= 1 and not bot.desired[l.itemId] then
				local v = myVal(bot, l.itemId)
				local net = Tax.split(l.gemsPerCopy)
				if net >= v * (1 + edge) then
					local count = math.min(owned, l.remainingCount)
					table.insert(candidates, {
						profit = (net - v) * count,
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

	----------------------------------------------------------------------
	-- GEM STORE: fixed-price stock under market value is free profit, and it
	-- is what injects fresh supply into the economy.
	----------------------------------------------------------------------
	for _, s in StoreService.shelfForBots() do
		local pos = state.inventory[s.itemId] or 0
		if s.price <= spendable and pos < BotConfig.MaxHoldPerItem then
			local v = myVal(bot, s.itemId)
			if s.price <= v * (1 - edge) then
				table.insert(candidates, {
					profit = v - s.price,
					tag = "store_buy",
					run = function()
						return StoreService.botBuy(bot.userId, s.itemId).ok == true
					end,
				})
			end
		end
	end

	----------------------------------------------------------------------
	-- EVENT CRAFT: the value faucet. Burn cheap inputs, mint an output worth
	-- more than they were — real wealth creation, and a demand sink that
	-- drains the common inputs' supply (so their value rises).
	----------------------------------------------------------------------
	-- itemId -> how many copies a profitable recipe needs me to be holding.
	-- This is a COUNT, not a flag, because it has to raise my target hold for
	-- that item: a recipe wanting 4x Stone Relic is unreachable if I stop
	-- acquiring at TargetHoldPerItem (2), which is exactly why crafting was
	-- firing a handful of times a minute across 500 bots.
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
						-- a profitable recipe I'm short on: these inputs are now
						-- things I want (don't trade them away), and I need to
						-- stockpile up to the recipe's full count
						for itemId, count in recipe.inputs do
							if (state.inventory[itemId] or 0) < count then
								neededInputs[itemId] = math.max(neededInputs[itemId] or 0, count)
							end
						end
					end
				end
			end
		end
	end

	----------------------------------------------------------------------
	-- BUY THE MISSING PIECES: a craft I can't fire yet is worth paying up to
	-- ~value for the inputs I'm short of — the craft premium covers it. Without
	-- this, crafting starves: trading up always chases the most VALUABLE
	-- reachable item, so a bot needing 4 cheap Clay Totems goes after a Jade
	-- Serpent instead and the recipe never fires.
	----------------------------------------------------------------------
	for _, l in book.sells do
		if l.posterId ~= bot.userId and l.remainingCount > 0 then
			local need = neededInputs[l.itemId]
			if need then
				local have = state.inventory[l.itemId] or 0
				local short = need - have
				local price = math.max(l.gemsPerCopy, 1)
				if short > 0 and l.gemsPerCopy <= fair(l.itemId) * BotConfig.InputOverpayCap and price <= spendable then
					local count = math.min(l.remainingCount, short, math.floor(spendable / price))
					if count >= 1 then
						table.insert(candidates, {
							-- rank it by the craft it unlocks, not the item's own margin
							profit = fair(l.itemId) * count * 0.75,
							tag = "buy_input",
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
	-- TRADE UP: bundle my cheapest spare items (+ a gem sweetener) and offer
	-- them for ONE item I want, overpaying a premium — that premium is what
	-- makes a holder willing to give the item up.
	----------------------------------------------------------------------
	local myOpenSwaps: { any } = {}
	local myOpenSells: { any } = {}
	for _, l in book.ownOpen[bot.userId] or {} do
		if l.kind == "swap" then
			table.insert(myOpenSwaps, l)
		elseif l.kind == "sell" then
			table.insert(myOpenSells, l)
		end
	end

	-- keep exactly one live offer, and only for something I still want
	local liveSwap: any = nil
	for _, l in myOpenSwaps do
		local wantId = next(l.want.items)
		if wantId ~= nil and bot.desired[wantId] and liveSwap == nil then
			liveSwap = l
		elseif TradeBoardService.botCancel(bot.userId, l.id).ok then
			table.insert(actions, "offer_retire")
		end
	end

	if liveSwap == nil then
		-- What can I actually put on the table? My cheapest spare items (the
		-- chaff) plus spendable gems. Trading up is INCREMENTAL — you climb one
		-- rung at a time, you don't leap straight to the grail. So the target is
		-- the best rung this budget can genuinely reach, preferring what I want.
		local spare = {}
		for itemId, count in state.inventory do
			if not bot.desired[itemId] and not neededInputs[itemId] then
				table.insert(spare, { id = itemId, count = count, val = fair(itemId) })
			end
		end
		-- cheapest first: trade away the chaff, keep the good stuff
		table.sort(spare, function(a, b)
			if a.val ~= b.val then
				return a.val < b.val
			end
			return a.id < b.id
		end)

		local maxBundleVal, units = 0, 0
		for _, e in spare do
			if units >= BotConfig.MaxBundleItems then
				break
			end
			for _ = 1, e.count do
				if units >= BotConfig.MaxBundleItems then
					break
				end
				maxBundleVal += e.val
				units += 1
			end
		end
		local budgetCap = maxBundleVal + math.max(0, spendable)

		local targetId: string? = nil
		local targetVal = 0
		local targetScore = 0
		for _, itemId in itemIds do
			-- normally I only want a couple of any one thing, but if a
			-- profitable recipe needs 4 of it, chase all 4
			local wantUpTo = math.max(BotConfig.TargetHoldPerItem, neededInputs[itemId] or 0)
			if (state.inventory[itemId] or 0) < wantUpTo then
				local v = fair(itemId)
				if v > 0 and v * (1 + bot.overpay) <= budgetCap then
					-- reachable. Prefer what I want, but any rung up is progress.
					-- A recipe input I'm short of is the strongest pull there is:
					-- it unlocks a craft, which is where new value comes from.
					local score = v * (bot.desired[itemId] and 1.25 or 1.0) * (neededInputs[itemId] and 2.0 or 1.0)
					if score > targetScore then
						targetId, targetVal, targetScore = itemId, v, score
					end
				end
			end
		end

		if targetId then
			local budget = targetVal * (1 + bot.overpay)
			local giveItems: { [string]: number } = {}
			local giveVal = 0
			local n = 0
			for _, e in spare do
				-- only bundle things CHEAPER than the target — that's what makes
				-- this an upgrade rather than a sideways shuffle
				if e.val >= targetVal or n >= BotConfig.MaxBundleItems or giveVal >= budget then
					break
				end
				for _ = 1, e.count do
					if n >= BotConfig.MaxBundleItems or giveVal + e.val > budget then
						break
					end
					giveItems[e.id] = (giveItems[e.id] or 0) + 1
					giveVal += e.val
					n += 1
				end
			end

			-- top up with gems so the offer actually clears the target's value
			local wantTotal = targetVal * (1 + bot.overpay)
			local gemAdd = 0
			if giveVal < wantTotal then
				gemAdd = math.min(math.ceil(wantTotal - giveVal), math.max(0, spendable))
			end

			if n > 0 and (giveVal + gemAdd) >= targetVal * (1 + BotConfig.UpgradeMinPremium) then
				if TradeBoardService.botPost(bot.userId, bot.name, {
					kind = "swap",
					give = { items = giveItems, gems = gemAdd },
					want = { items = { [targetId] = 1 }, gems = 0 },
					autoTrade = true,
				}).ok then
					table.insert(actions, "trade_up_offer")
				end
			end
		end
	end

	----------------------------------------------------------------------
	-- LIQUIDATE: gem-poor -> list ONE spare item for gems. A real reason to
	-- sell (store + craft cost gems), not market-maker churn.
	----------------------------------------------------------------------
	if state.gems < BotConfig.GemPoorThreshold and #myOpenSells == 0 then
		local sellId: string? = nil
		local sellVal = 0
		for itemId, count in state.inventory do
			if count >= 1 and not bot.desired[itemId] and not neededInputs[itemId] then
				local v = fair(itemId)
				if v > sellVal then
					sellId, sellVal = itemId, v
				end
			end
		end
		if sellId then
			local price = math.max(1, math.floor(sellVal * BotConfig.MinSellVsValue + 0.5))
			if TradeBoardService.botPost(bot.userId, bot.name, {
				kind = "sell",
				itemId = sellId,
				count = 1,
				gemsPerCopy = price,
			}).ok then
				table.insert(actions, "liquidate")
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
