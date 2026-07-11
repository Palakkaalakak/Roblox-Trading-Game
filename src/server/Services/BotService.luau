--!strict
-- BotService: profit-seeking market bots that behave like real players.
--
-- Each bot has durable state (inventory + gems) in its own DataStore key,
-- mutated with the same validate-all-then-apply + idempotency semantics as
-- real profiles. All trading goes through TradeBoardService's REAL flows
-- (escrow, gem tax, RAP recording), via the bot* internal entry points —
-- so every bot deal is indistinguishable from a player deal to the economy.
--
-- Multi-server safety: exactly ONE server runs the brains (MemoryStore
-- leader lease); state writes are UpdateAsync CAS so any server can still
-- credit a bot when a player trades against its listing.
--
-- Strategy per tick (one action max — feels human):
--   1. buy underpriced sell listings   (price <= value * (1 - margin))
--   2. sell into overpaying bulk orders (net >= value * (1 + margin/2))
--   3. accept profitable auto swaps     (receive - pay >= margin * pay)
--   4. list own items for sale at value * (1 + margin)
--   5. post a bulk buy order at value * (1 - margin)
--   6. reprice: cancel own stale listings
--
-- BotConfig.Enabled = false -> brains never start AND leftover bot listings
-- are cancelled at boot (refunds land back in bot state, not the world).

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
	return { gems = 0, inventory = {}, claimed = {}, seeded = false, lifetime = { earned = 0, spent = 0 } }
end

-- Atomic validate-then-apply, same semantics as InventoryService.applyDelta.
-- Returns (ok, err).
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
	local ok = BotService.applyDelta(botId, { items = items, gems = gems }, "board", claimId)
	return ok
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
	-- draw from live pool items (assignmentWeight > 0 = starter pool member)
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
			-- reserve empty: drop this candidate
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
-- Brain
--------------------------------------------------------------------------------

-- One decision pass for one bot. Returns a short action tag (analytics).
local function think(bot: any): string?
	local TradeBoardService = require(script.Parent.TradeBoardService) :: any
	local state = getState(bot.userId)
	local margin = bot.margin
	local spendable = state.gems - BotConfig.MinGemsKept

	-- imperfect information: this bot's per-decision estimate of an item's
	-- worth. The noise is what lets two bots disagree enough to trade with
	-- each other (seeding RAP) instead of quoting forever-non-crossing spreads.
	local function pv(itemId: string): number
		local noise = 1 + (math.random() * 2 - 1) * BotConfig.ValueNoise
		return EconomyService.valueOf(itemId) * noise
	end

	local listings = TradeBoardService.rawOpenListings()
	local ownCount = 0
	local now = os.time()

	-- pass 0: reprice stale own listings (cancel; next ticks relist)
	for _, l in listings do
		if l.posterId == bot.userId then
			ownCount += 1
			if now - l.createdAt > BotConfig.RepriceSeconds then
				TradeBoardService.botCancel(bot.userId, l.id)
				return "reprice_cancel"
			end
		end
	end

	-- pass 1: buy underpriced sell listings (flip material)
	for _, l in listings do
		if l.kind == "sell" and l.posterId ~= bot.userId then
			local value = pv(l.itemId)
			if l.gemsPerCopy <= value * (1 - margin) and l.gemsPerCopy <= spendable then
				local affordable = math.floor(spendable / l.gemsPerCopy)
				local count = math.min(l.remainingCount, affordable, 3)
				if count >= 1 then
					local res = TradeBoardService.botBuy(bot.userId, bot.name, l.id, count)
					if res.ok then
						return "buy_sell_listing"
					end
				end
			end
		end
	end

	-- pass 2: sell into overpaying bulk orders
	for _, l in listings do
		if l.kind == "bulk" and l.posterId ~= bot.userId then
			local owned = state.inventory[l.itemId] or 0
			if owned >= 1 then
				local value = pv(l.itemId)
				local net = Tax.split(l.gemsPerCopy)
				if net >= value * (1 + margin / 2) then
					local count = math.min(owned, l.remainingCount)
					local res = TradeBoardService.botContribute(bot.userId, bot.name, l.id, count)
					if res.ok then
						return "fill_bulk"
					end
				end
			end
		end
	end

	-- pass 3: accept profitable auto-trade swaps
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
				local res = TradeBoardService.botAccept(bot.userId, bot.name, l.id)
				if res.ok then
					return "accept_swap"
				end
			end
		end
	end

	if ownCount >= BotConfig.MaxListingsPerBot then
		return nil
	end

	-- pass 4: list an owned item for sale above value
	local sellables = {}
	for itemId, count in state.inventory do
		if count >= 1 then
			table.insert(sellables, itemId)
		end
	end
	if #sellables > 0 and math.random() < 0.7 then
		local itemId = sellables[math.random(#sellables)]
		local value = pv(itemId)
		local price = math.max(1, math.floor(value * (1 + margin) + 0.5))
		local count = math.min(state.inventory[itemId], 2)
		local res = TradeBoardService.botPost(bot.userId, bot.name, {
			kind = "sell",
			itemId = itemId,
			count = count,
			gemsPerCopy = price,
		})
		if res.ok then
			return "post_sell"
		end
	end

	-- pass 5: post a bulk buy order below value (accumulate cheap copies)
	local pool = {}
	for itemId, item in EconomyService.allItems() do
		if (item.assignmentWeight or 0) > 0 then
			table.insert(pool, itemId)
		end
	end
	if #pool > 0 then
		local itemId = pool[math.random(#pool)]
		local value = pv(itemId)
		local perCopy = math.max(1, math.floor(value * (1 - margin) + 0.5))
		local count = 2
		local total = perCopy * count
		if total <= spendable then
			local res = TradeBoardService.botPost(bot.userId, bot.name, {
				kind = "bulk",
				itemId = itemId,
				count = count,
				gems = total,
			})
			if res.ok then
				return "post_bulk"
			end
		end
	end
	return nil
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
				-- we are the bot server until the lease lapses
				for _, bot in BotConfig.Bots do
					seedBot(bot)
				end
				while tryAcquireLease() do
					for _, bot in BotConfig.Bots do
						local ok, action = pcall(think, bot)
						if ok and action then
							AnalyticsService.log("bot_action", { botId = bot.userId, action = action })
						elseif not ok then
							warn("[Bots] think failed for " .. bot.name .. ": " .. tostring(action))
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
