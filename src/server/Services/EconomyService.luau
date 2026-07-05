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
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local RollingAverage = require(ReplicatedStorage.Shared.Util.RollingAverage)
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local Net = require(script.Parent.Parent.Net)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local AnalyticsService = require(script.Parent.AnalyticsService)
local RateLimitService = require(script.Parent.RateLimitService)

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

-- value = max(1, round(Base * scarcity * demandFactor)); nil when N/A.
function EconomyService.computeValue(circulating: number, demandEMA: number): number?
	if circulating < EconomyConfig.MinSamples.ValueCirculating then
		return nil
	end
	local scarcity = (EconomyConfig.ReferenceSupply / math.max(circulating, 1)) ^ EconomyConfig.SupplyExponent
	local demandFactor = 1 + EconomyConfig.DemandCoefficient * math.log10(1 + math.max(demandEMA, 0))
	return math.max(1, math.floor(EconomyConfig.ValueBase * scarcity * demandFactor + 0.5))
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

-- Register new items (rotation / seed). Appends to the durable registry and
-- initializes economy records. Item defs: {itemId, poolId, name, totalSupply,
-- assignmentWeight}. Rarity derived here — never passed in.
function EconomyService.registerItems(defs: { any })
	local now = os.time()
	registryStore:UpdateAsync("all", function(old)
		old = old or {}
		for _, def in defs do
			if old[def.itemId] == nil then
				old[def.itemId] = {
					itemId = def.itemId,
					poolId = def.poolId,
					name = def.name,
					totalSupply = def.totalSupply,
					assignmentWeight = def.assignmentWeight,
					rarity = Rarity.tierFor(def.totalSupply),
					imageId = def.imageId,
					createdAt = now,
				}
			elseif old[def.itemId].imageId == nil and def.imageId ~= nil then
				old[def.itemId].imageId = def.imageId -- backfill icons on old entries
			end
		end
		registry = old
		return old
	end)

	for _, def in defs do
		-- durable first, then hot (hot rehydrates from durable on miss)
		pcall(function()
			econStore:UpdateAsync(def.itemId, function(old)
				return old or freshRecord(def.itemId, def.totalSupply, now)
			end)
		end)
		pcall(function()
			hotMap:UpdateAsync(def.itemId, function(old)
				return old or freshRecord(def.itemId, def.totalSupply, now)
			end)
		end)
		hotCache[def.itemId] = nil -- force refetch
	end
	AnalyticsService.log("items_registered", { count = #defs })
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
local function mutateRecord(itemId: string, transform: (any) -> any?): any?
	local result
	local ok = pcall(function()
		result = hotMap:UpdateAsync(itemId, function(old)
			if old == nil then
				-- seed from durable/fresh before mutating
				old = getRecord(itemId)
				if old == nil then
					return nil
				end
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
	local value = EconomyService.computeValue(circulating, demand)

	return {
		itemId = itemId,
		name = item.name,
		rarity = item.rarity,
		imageId = item.imageId,
		-- supply is always known (authoritative count; 0 is a real value)
		supply = stat(true, circulating),
		demand = stat((rec.demandSamples or 0) >= EconomyConfig.MinSamples.Demand, math.floor(demand * 100 + 0.5) / 100),
		value = stat(value ~= nil, value),
		rap = stat((rec.rapCount or 0) >= EconomyConfig.MinSamples.RAP, math.floor((rec.rapValue or 0) + 0.5)),
		reserveRemaining = rec.reserveRemaining or 0,
	}
end

-- Value used inside price imputation (server-side, nil-safe fallback 1).
function EconomyService.valueOf(itemId: string): number
	local rec = getRecord(itemId)
	if rec == nil then
		return 1
	end
	local v = EconomyService.computeValue(rec.circulating or 0, decayedDemand(rec, os.time()))
	return v or 1
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
	registryStore = StoreAdapters.dataStore("ItemRegistry_v1")
	econStore = StoreAdapters.dataStore("EconomyStore_v1")
	hotMap = StoreAdapters.sortedMap("EconomyHot_v1")
	EconomyService.loadRegistry()
end

function EconomyService.Start()
	-- remote: batch stat fetch
	Net.bindFunction("GetStats", function(player, itemIds)
		if not RateLimitService.check(player, "GetStats") then
			return { ok = false, err = "rate_limited" }
		end
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
