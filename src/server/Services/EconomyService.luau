--!strict
-- EconomyService: authoritative shared economy state.
--   * Global Item Registry (durable; any server resolves any itemId ever made)
--   * Per-item EconomyRecord: reserve/circulating/demand/RAP
--     - hot copy in MemoryStore sorted map (cross-server, atomic CAS)
--     - durable copy in DataStore (source of truth on cold start)
--   * value/demand/supply/RAP snapshots with explicit N/A (StatState)
--   * MessagingService invalidation pings -> every server refreshes + pushes
--     StatsUpdated to its clients.
--
-- Stat DAG: supply<-counts, demand<-events, value<-g(demand,supply), RAP<-trades.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Enums)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local RollingAverage = require(ReplicatedStorage.Shared.Util.RollingAverage)
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local Net = require(script.Parent.Parent.Net)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local AnalyticsService = require(script.Parent.AnalyticsService)

local EconomyService = {}

local registryStore: any -- DataStore "ItemRegistry_v1", key "all" -> {itemId -> Item}
local econStore: any -- DataStore "EconomyStore_v1", key itemId -> EconomyRecord
local hotMap: any -- MemoryStore map "EconomyHot_v1", key itemId -> EconomyRecord

local registry: { [string]: any } = {} -- itemId -> Item (local cache)
local hotCache: { [string]: any } = {} -- itemId -> EconomyRecord (local cache)
local dirty: { [string]: boolean } = {} -- itemIds needing durable flush

--------------------------------------------------------------------------------
-- Pure-ish math
--------------------------------------------------------------------------------

local demandDecayPerSecond = 0.5 ^ (1 / EconomyConfig.DemandHalfLifeSeconds)

local function decayedDemand(record: any, now: number): number
	local dt = math.max(0, now - (record.demandT or now))
	return (record.demandEMA or 0) * demandDecayPerSecond ^ dt
end

-- Est. Value is GEM-DENOMINATED and ALWAYS DEFINED (never N/A) — every player
-- sees the same number for the same item, everywhere. It is a SMOOTHED,
-- market-anchored version of RAP:
--   * seed: the item's fixed store cost; event items (no store cost) seed
--     from supply scarcity instead
--   * as real sales accumulate, the seed anchor DECAYS and Value converges
--     onto RAP — so Value is smooth/stable early (sticker-anchored, immune to
--     one lucky trade) and grows precise as genuine gem-priced sales build
--     up. Gem-only shop sales feed RAP directly (exact prices), so this
--     converges fast and true once the shop is used.
-- Deterministic from (registry, economy record): no per-client divergence.

-- seed price in gems for an item with no store cost (event items)
function EconomyService.scarcitySeed(totalSupply: number): number
	local scarcity = (EconomyConfig.ReferenceSupply / math.max(totalSupply, 1)) ^ EconomyConfig.SupplyExponent
	return math.max(1, math.floor(EconomyConfig.ValueBase * scarcity + 0.5))
end

function EconomyService.computeValue(seedGems: number, rapValue: number, rapCount: number): number
	local blendAt = EconomyConfig.MinSamples.ValueRapBlend
	if rapCount < blendAt then
		return math.max(1, math.floor(seedGems + 0.5)) -- not enough data: sticker price
	end
	-- seed weight decays with sample count: w = w0 * H/(H + extraSamples),
	-- floored so Value never fully abandons the anchor. Early trades barely
	-- move Value (smooth); a well-traded item's Value ≈ its RAP (precise).
	local extra = rapCount - blendAt
	local w = EconomyConfig.ValueSeedWeight * EconomyConfig.ValueSeedHalfLife
		/ (EconomyConfig.ValueSeedHalfLife + extra)
	w = math.max(w, EconomyConfig.ValueSeedFloor)
	return math.max(1, math.floor(w * seedGems + (1 - w) * rapValue + 0.5))
end

-- Live rarity->gems lookup against the CURRENT config — never frozen into
-- storage, so a balance change in Items.StoreCostByRarity takes effect for
-- every already-registered item immediately, no data migration required.
local function rarityFallbackCost(rarity: string?): number?
	return rarity and Items.StoreCostByRarity[rarity] or nil
end

-- The gem number shown as "Store Cost" and used to seed Est. Value: explicit
-- price if the item has one (NPC store / product token), else the live
-- rarity price, else nil for event items (displayed "N/A (Event Item)").
function EconomyService.displayStoreCost(item: any): number?
	if item.eventItem then
		return nil
	end
	return item.storeCost or rarityFallbackCost(item.rarity)
end

-- Event/crafted items have no store cost. Seed their Est. Value from what it
-- COST to make one: sum of input item values + input gems, +5% (the crafting
-- premium). Built once from EventConfig; falls back to scarcity if a recipe
-- is missing. `evt_<sku>` matches CraftingService.outputItemId.
local eventRecipeIndex: { [string]: { inputs: { [string]: number }, gems: number } }? = nil
local function buildEventRecipeIndex()
	local index: { [string]: any } = {}
	local function add(recipe: any)
		index["evt_" .. recipe.output.sku] = { inputs = recipe.inputs, gems = recipe.gems or 0 }
	end
	for _, event in EventConfig.Events do
		for _, recipe in event.recipes do
			add(recipe)
		end
	end
	if EventConfig.RotatingRecipes then
		for _, recipe in EventConfig.RotatingRecipes.Pool do
			add(recipe)
		end
	end
	eventRecipeIndex = index
end

local function eventSeed(itemId: string): number?
	if eventRecipeIndex == nil then
		buildEventRecipeIndex()
	end
	local recipe = (eventRecipeIndex :: any)[itemId]
	if recipe == nil then
		return nil
	end
	local total = recipe.gems
	for inId, count in recipe.inputs do
		total += EconomyService.valueOf(inId) * count
	end
	return math.max(1, math.floor(total * 1.05 + 0.5))
end

local function seedFor(item: any, itemId: string?): number
	if item.eventItem and itemId then
		local es = eventSeed(itemId)
		if es then
			return es
		end
	end
	return EconomyService.displayStoreCost(item) or EconomyService.scarcitySeed(item.totalSupply)
end

local function freshRecord(itemId: string, totalSupply: number, now: number)
	return {
		itemId = itemId,
		reserveRemaining = totalSupply,
		circulating = 0,
		demandEMA = 0,
		demandT = now,
		demandSamples = 0,
		rapValue = 0,
		rapCount = 0,
		updatedAt = now,
	}
end

--------------------------------------------------------------------------------
-- Registry
--------------------------------------------------------------------------------

function EconomyService.loadRegistry()
	local stored
	pcall(function()
		stored = registryStore:GetAsync("all")
	end)
	registry = stored or {}
end

-- Register new items (rotation / seed). Item defs: {itemId, poolId, name,
-- totalSupply, assignmentWeight}. Rarity derived here — never passed in.
--
-- FAST on reboot: when every def is already registered and needs no backfill,
-- this is zero store calls (boot used to burn ~1s per item re-seeding records
-- that already existed). Economy records are NOT written here — getRecord
-- lazy-seeds them from the registry on first touch.
function EconomyService.registerItems(defs: { any })
	local now = os.time()

	-- diff against the in-memory registry first. storeCost is only ever
	-- diffed/written when a def carries an EXPLICIT price (NPC store /
	-- product tokens) — rarity-derived cost is never frozen into storage
	-- (see rarityFallbackCost), so a nil storeCost on a non-event item is
	-- the correct steady state, not something to "fix".
	local dirtyDefs = {}
	local reasons = {}
	for _, def in defs do
		local existing = registry[def.itemId]
		if existing == nil then
			table.insert(dirtyDefs, def)
			if #reasons < 3 then
				table.insert(reasons, def.itemId .. ":missing")
			end
		elseif (existing.imageId == nil and def.imageId ~= nil)
			or (def.eventItem and (not existing.eventItem or existing.storeCost ~= nil))
			or (def.storeCost ~= nil and existing.storeCost ~= def.storeCost)
		then
			table.insert(dirtyDefs, def) -- needs a backfill / explicit-price resync
			if #reasons < 3 then
				table.insert(reasons, def.itemId .. ":backfill")
			end
		end
	end
	if #dirtyDefs == 0 then
		return -- everything already registered; boot stays instant
	end

	registryStore:UpdateAsync("all", function(old)
		old = old or {}
		for _, def in dirtyDefs do
			local rarity = Rarity.tierFor(def.totalSupply)
			if old[def.itemId] == nil then
				old[def.itemId] = {
					itemId = def.itemId,
					poolId = def.poolId,
					name = def.name,
					totalSupply = def.totalSupply,
					assignmentWeight = def.assignmentWeight,
					rarity = rarity,
					imageId = def.imageId,
					-- ONLY explicit fixed prices are stored. Event items: no
					-- store cost (UI: "N/A (Event Item)"). Everything else:
					-- nil, resolved live from current config every read.
					storeCost = if def.eventItem then nil else def.storeCost,
					eventItem = def.eventItem,
					-- Robux product tokens (tradeable stand-ins for passes/products)
					productType = def.productType,
					productId = def.productId,
					createdAt = now,
				}
			else
				-- backfill fields added after the entry was written
				if old[def.itemId].imageId == nil and def.imageId ~= nil then
					old[def.itemId].imageId = def.imageId
				end
				if def.eventItem then
					old[def.itemId].eventItem = true
					old[def.itemId].storeCost = nil
				elseif def.storeCost ~= nil then
					old[def.itemId].storeCost = def.storeCost -- explicit price changed in config
				end
			end
		end
		registry = old
		return old
	end)
	AnalyticsService.log("items_registered", { count = #dirtyDefs, why = table.concat(reasons, ",") })
end

function EconomyService.getItem(itemId: string): any?
	if registry[itemId] == nil then
		EconomyService.loadRegistry() -- maybe another server registered it
	end
	return registry[itemId]
end

function EconomyService.allItems(): { [string]: any }
	return registry
end

--------------------------------------------------------------------------------
-- Hot record access + mutation
--------------------------------------------------------------------------------

-- Read-through: local cache -> MemoryStore -> durable -> fresh.
local function getRecord(itemId: string): any?
	if hotCache[itemId] then
		return hotCache[itemId]
	end
	local rec
	pcall(function()
		rec = hotMap:GetAsync(itemId)
	end)
	if rec == nil then
		pcall(function()
			rec = econStore:GetAsync(itemId)
		end)
		if rec ~= nil then
			-- repopulate hot from durable, but never clobber a newer hot copy
			pcall(function()
				hotMap:UpdateAsync(itemId, function(old)
					return old or rec
				end)
			end)
		end
	end
	if rec == nil then
		local item = EconomyService.getItem(itemId)
		if item == nil then
			return nil
		end
		rec = freshRecord(itemId, item.totalSupply, os.time())
		pcall(function()
			hotMap:UpdateAsync(itemId, function(old)
				return old or rec
			end)
		end)
	end
	hotCache[itemId] = rec
	return rec
end

-- Atomic transform of the hot record (MemoryStore CAS). Marks dirty + caches.
-- CRITICAL: the transform passed to UpdateAsync must be PURE — no yields, no
-- store reads. MemoryStore may invoke it multiple times, and yielding inside
-- it double-applies mutations (this exact bug inflated circulating counts).
-- Missing records are seeded BEFORE the CAS, outside the transform.
local function mutateRecord(itemId: string, transform: (any) -> any?): any?
	if getRecord(itemId) == nil then
		return nil -- unknown item; getRecord already tried durable + fresh seed
	end
	local result
	local ok = pcall(function()
		result = hotMap:UpdateAsync(itemId, function(old)
			if old == nil then
				return nil -- key expired between seed and CAS; caller may retry
			end
			return transform(old)
		end)
	end)
	if not ok or result == nil then
		return nil
	end
	hotCache[itemId] = result
	dirty[itemId] = true
	return result
end

--------------------------------------------------------------------------------
-- Public mutations
--------------------------------------------------------------------------------

-- Reserve one undistributed copy (starter draw). Atomic cross-server.
-- Returns (reserved, remainingAfter). Success derived from the committed CAS
-- result (transform may retry under contention; never trust closure flags).
function EconomyService.reserveOne(itemId: string): (boolean, number)
	local rec = mutateRecord(itemId, function(old)
		if (old.reserveRemaining or 0) <= 0 then
			return nil -- abort: nothing left to reserve
		end
		old.reserveRemaining -= 1
		old.circulating += 1
		old.updatedAt = os.time()
		return old
	end)
	if rec == nil then
		return false, 0
	end
	EconomyService.broadcastStats({ itemId })
	return true, rec.reserveRemaining
end

-- Demand bump (offer inclusion or trade completion).
function EconomyService.bumpDemand(itemId: string, amount: number, countAsSample: boolean)
	mutateRecord(itemId, function(old)
		local now = os.time()
		old.demandEMA = decayedDemand(old, now) + amount
		old.demandT = now
		if countAsSample then
			old.demandSamples = (old.demandSamples or 0) + 1
		end
		old.updatedAt = now
		return old
	end)
end

-- Retire copies from circulation (crafting/sacrifice sink: the consumed
-- items are destroyed). totalSupply is untouched — "X/Y in existence" shows
-- X dropping while Y stays the historical cap. Atomic cross-server.
function EconomyService.retireCopies(itemId: string, count: number)
	if count <= 0 then
		return
	end
	mutateRecord(itemId, function(old)
		old.circulating = math.max(0, (old.circulating or 0) - count)
		old.updatedAt = os.time()
		return old
	end)
	EconomyService.broadcastStats({ itemId })
end

-- Record a closed-trade imputed price into RAP (+ demand sample).
function EconomyService.recordTradePrice(itemId: string, imputedPrice: number)
	mutateRecord(itemId, function(old)
		local now = os.time()
		old.rapValue, old.rapCount = RollingAverage.push(old.rapValue or 0, old.rapCount or 0, imputedPrice)
		old.demandEMA = decayedDemand(old, now) + EconomyConfig.DemandBumpOnTrade
		old.demandT = now
		old.demandSamples = (old.demandSamples or 0) + 1
		old.updatedAt = now
		return old
	end)
	AnalyticsService.log("rap_update", { itemId = itemId, price = imputedPrice })
end

-- Record a gem-only SALE: an exact per-copy gem price, `count` copies. This
-- is the cleanest possible signal (no barter imputation), so each copy is a
-- full RAP sample. One CAS pushes them all (RollingAverage.push is pure, so
-- looping inside the transform is safe). Sample count capped to bound work.
function EconomyService.recordSale(itemId: string, pricePerCopy: number, count: number)
	local samples = math.clamp(count, 1, 50)
	mutateRecord(itemId, function(old)
		local now = os.time()
		local avg, n = old.rapValue or 0, old.rapCount or 0
		for _ = 1, samples do
			avg, n = RollingAverage.push(avg, n, pricePerCopy)
		end
		old.rapValue, old.rapCount = avg, n
		old.demandEMA = decayedDemand(old, now) + EconomyConfig.DemandBumpOnTrade
		old.demandT = now
		old.demandSamples = (old.demandSamples or 0) + 1
		old.updatedAt = now
		return old
	end)
	EconomyService.broadcastStats({ itemId })
	AnalyticsService.log("sale_price", { itemId = itemId, price = pricePerCopy, copies = count })
end

--------------------------------------------------------------------------------
-- Snapshots (client-facing, N/A-aware)
--------------------------------------------------------------------------------

local function stat(known: boolean, value: number?): any
	if known and value ~= nil then
		return { state = Enums.StatState.Known, value = value }
	end
	return { state = Enums.StatState.NA }
end

function EconomyService.snapshot(itemId: string): any?
	local item = EconomyService.getItem(itemId)
	local rec = getRecord(itemId)
	if item == nil or rec == nil then
		return nil
	end
	local now = os.time()
	local demand = decayedDemand(rec, now)
	local circulating = rec.circulating or 0
	local value = EconomyService.computeValue(seedFor(item, itemId), rec.rapValue or 0, rec.rapCount or 0)

	return {
		itemId = itemId,
		name = item.name,
		rarity = item.rarity,
		imageId = item.imageId,
		totalSupply = item.totalSupply, -- fixed cap (the Y in "X/Y in existence")
		storeCost = EconomyService.displayStoreCost(item), -- gems; nil = event item (same number that seeds Value)
		-- supply is always known (authoritative count; 0 is a real value)
		supply = stat(true, circulating),
		demand = stat((rec.demandSamples or 0) >= EconomyConfig.MinSamples.Demand, math.floor(demand * 100 + 0.5) / 100),
		value = stat(true, value), -- always defined: same number for every player
		rap = stat((rec.rapCount or 0) >= EconomyConfig.MinSamples.RAP, math.floor((rec.rapValue or 0) + 0.5)),
		reserveRemaining = rec.reserveRemaining or 0,
	}
end

-- Gem value used inside RAP imputation + trade totals (always defined).
function EconomyService.valueOf(itemId: string): number
	local item = EconomyService.getItem(itemId)
	local rec = getRecord(itemId)
	if item == nil then
		return 1
	end
	return EconomyService.computeValue(seedFor(item, itemId), rec and rec.rapValue or 0, rec and rec.rapCount or 0)
end

--------------------------------------------------------------------------------
-- Sync: broadcast + flush + subscribe
--------------------------------------------------------------------------------

-- Invalidation ping: other servers drop caches + everyone pushes fresh
-- snapshots to clients. Payload = item ids only (MessagingService ~1KB cap).
function EconomyService.broadcastStats(itemIds: { string })
	StoreAdapters.publish(EconomyConfig.StatsBroadcastTopic, { items = itemIds })
	-- local push (publisher's own clients)
	EconomyService.pushStats(itemIds)
end

function EconomyService.pushStats(itemIds: { string })
	local snapshots = {}
	for _, itemId in itemIds do
		local snap = EconomyService.snapshot(itemId)
		if snap then
			table.insert(snapshots, snap)
		end
	end
	if #snapshots > 0 then
		Net.fireAllClients("StatsUpdated", snapshots)
	end
end

local function flushDirty()
	for itemId in dirty do
		dirty[itemId] = nil
		local rec = hotCache[itemId]
		if rec then
			pcall(function()
				econStore:UpdateAsync(itemId, function(old)
					-- last-writer-wins by updatedAt; hot is newer in practice
					if old and old.updatedAt and rec.updatedAt and old.updatedAt > rec.updatedAt then
						return old
					end
					return rec
				end)
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function EconomyService.Init()
	StoreAdapters.init()
	registryStore = StoreAdapters.dataStore("ItemRegistry_v2")
	econStore = StoreAdapters.dataStore("EconomyStore_v2")
	hotMap = StoreAdapters.sortedMap("EconomyHot_v2")
	EconomyService.loadRegistry()
	-- NOTE: registry.storeCost is only ever persisted for items with an
	-- EXPLICIT fixed price (NPC store catalog, product tokens). Everything
	-- else derives its cost live from item.rarity + the current
	-- Items.StoreCostByRarity table (see seedFor/rarityFallbackCost below) —
	-- do not add a backfill here that freezes a rarity price into storage;
	-- that is exactly the bug that let a stale pre-rebalance Common price
	-- (100) outlive the "cheap prices" config change silently.
end

function EconomyService.Start()
	-- remote: full item directory (board want-pickers etc)
	Net.bindFunction("GetCatalog", function(player)
		local items = {}
		for itemId, item in registry do
			table.insert(items, { itemId = itemId, name = item.name, imageId = item.imageId })
		end
		table.sort(items, function(a, b)
			return a.name < b.name
		end)
		return { ok = true, items = items }
	end)

	-- remote: batch stat fetch
	Net.bindFunction("GetStats", function(player, itemIds)
		local ok, err = Guard.checkItemIdList(itemIds, 64)
		if not ok then
			return { ok = false, err = err }
		end
		local snapshots = {}
		for _, itemId in itemIds :: { string } do
			local snap = EconomyService.snapshot(itemId)
			if snap then
				table.insert(snapshots, snap)
			end
		end
		return { ok = true, snapshots = snapshots }
	end)

	-- cross-server economy deltas: invalidate + push
	StoreAdapters.subscribe(EconomyConfig.StatsBroadcastTopic, function(payload)
		if type(payload) ~= "table" or type(payload.items) ~= "table" then
			return
		end
		for _, itemId in payload.items do
			if type(itemId) == "string" then
				hotCache[itemId] = nil -- refetch from MemoryStore on next read
			end
		end
		EconomyService.pushStats(payload.items)
	end)

	-- periodic durable flush
	task.spawn(function()
		while true do
			task.wait(EconomyConfig.HotFlushIntervalSeconds)
			flushDirty()
		end
	end)

	game:BindToClose(function()
		flushDirty()
	end)
end

return EconomyService
