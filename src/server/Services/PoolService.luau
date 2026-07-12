--!strict
-- PoolService: current starter pool state, exhaustion detection, rotation.
--
-- Pool record (DataStore "PoolStore_v1", key "current"):
--   { poolId, seq, itemIds = {5}, createdAt, seed }
--
-- Rotation: when all 5 reserves hit 0, exactly one server generates the next
-- pool. Election = MemoryStore lock key CAS ("rotation_lock", owner+expiry).
-- Winner re-verifies exhaustion, generates 5 new items (enforced rarity
-- spread), registers them, swaps the pool record, releases lock, broadcasts.
-- Losers (and every other server) adopt on the broadcast.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Items = require(ReplicatedStorage.Shared.Config.Items)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Net = require(script.Parent.Parent.Net)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ROTATION_LOCK_TTL = 30

local PoolService = {}
PoolService.PoolChanged = Signal.new() -- (pool)

local poolStore: any
local lockMap: any
local currentPool: any = nil
local rotating = false

local ownerId = game.JobId ~= "" and game.JobId or "studio-" .. tostring(math.floor(os.clock() * 1000))

--------------------------------------------------------------------------------
-- Generation
--------------------------------------------------------------------------------

local function slugify(name: string): string
	return (name:lower():gsub("%s+", "_"):gsub("[^%w_]", ""))
end

-- Build item defs for a new pool. seq 1 = fixed placeholder set from config;
-- seq 2+ = procedural from PoolTemplate (structurally enforces the rarity
-- spread: 2 Common / 1 Rare / 1 Legendary / 1 Mythical slots).
function PoolService.generateDefs(seq: number, seed: number, existingNames: { [string]: boolean }): { any }
	local poolId = "pool_" .. tostring(seq)
	local defs = {}

	if seq == 1 then
		for i, row in Items.InitialPool do
			table.insert(defs, {
				itemId = ("itm_%d_%d_%s"):format(seq, i, slugify(row.name)),
				poolId = poolId,
				name = row.name,
				totalSupply = row.totalSupply,
				assignmentWeight = Rarity.defaultWeightFor(row.totalSupply),
				imageId = row.imageId,
			})
		end
		return defs
	end

	local rng = Random.new(seed)
	local usedNames = {}

	-- icons: shuffle the candidate pool, avoid ones already used by existing
	-- items where possible (recycle when exhausted)
	local usedIcons = {}
	for _, item in EconomyService.allItems() do
		if item.imageId then
			usedIcons[item.imageId] = true
		end
	end
	local freshIcons, recycledIcons = {}, {}
	for _, imageId in Items.IconPool do
		table.insert(usedIcons[imageId] and recycledIcons or freshIcons, imageId)
	end
	local iconOrder = #freshIcons >= #Items.PoolTemplate and freshIcons or Items.IconPool
	iconOrder = table.clone(iconOrder)
	for i = #iconOrder, 2, -1 do
		local j = rng:NextInteger(1, i)
		iconOrder[i], iconOrder[j] = iconOrder[j], iconOrder[i]
	end

	for i, slot in Items.PoolTemplate do
		local name
		for _ = 1, 200 do
			local adj = Items.NameAdjectives[rng:NextInteger(1, #Items.NameAdjectives)]
			local noun = Items.NameNouns[rng:NextInteger(1, #Items.NameNouns)]
			local candidate = adj .. " " .. noun
			if not usedNames[candidate] and not existingNames[candidate] then
				name = candidate
				break
			end
		end
		name = name or ("Relic %d-%d"):format(seq, i) -- collision fallback
		usedNames[name] = true

		local supply = rng:NextInteger(slot.min, slot.max)
		table.insert(defs, {
			itemId = ("itm_%d_%d_%s"):format(seq, i, slugify(name)),
			poolId = poolId,
			name = name,
			totalSupply = supply,
			assignmentWeight = Rarity.defaultWeightFor(supply),
			imageId = iconOrder[i],
		})
	end
	return defs
end

--------------------------------------------------------------------------------
-- Pool record
--------------------------------------------------------------------------------

local function readPool(): any
	local pool
	pcall(function()
		pool = poolStore:GetAsync("current")
	end)
	return pool
end

local function adoptPool(pool: any)
	if pool == nil then
		return
	end
	if currentPool == nil or pool.seq > currentPool.seq then
		currentPool = pool
		PoolService.PoolChanged:Fire(pool)
		AnalyticsService.log("pool_adopted", { poolId = pool.poolId, seq = pool.seq })
	end
end

-- Generate + commit pool `seq` (caller must hold the rotation lock, or be the
-- guarded seeder). Registers items first, then swaps the pool pointer — a
-- crash in between leaves orphan registry items (harmless) but never a pool
-- pointing at unregistered items.
local function commitNewPool(seq: number)
	local seed = os.time() + seq * 7919
	local existingNames = {}
	for _, item in EconomyService.allItems() do
		existingNames[item.name] = true
	end
	local defs = PoolService.generateDefs(seq, seed, existingNames)
	EconomyService.registerItems(defs)

	local itemIds = {}
	for _, def in defs do
		table.insert(itemIds, def.itemId)
	end
	local pool = {
		poolId = "pool_" .. tostring(seq),
		seq = seq,
		itemIds = itemIds,
		createdAt = os.time(),
		seed = seed,
	}
	poolStore:UpdateAsync("current", function(old)
		if old and old.seq >= seq then
			return old -- someone beat us; keep theirs
		end
		return pool
	end)

	local committed = readPool()
	adoptPool(committed)
	StoreAdapters.publish(EconomyConfig.PoolBroadcastTopic, { seq = committed.seq })
	AnalyticsService.log("pool_rotated", { poolId = committed.poolId, seq = committed.seq })
end

--------------------------------------------------------------------------------
-- Lock election
--------------------------------------------------------------------------------

local function tryAcquireLock(): boolean
	local acquired = false
	pcall(function()
		local result = lockMap:UpdateAsync("rotation_lock", function(old)
			local now = os.time()
			if old and old.owner ~= ownerId and (old.expiry or 0) > now then
				return nil -- someone else holds it
			end
			return { owner = ownerId, expiry = now + ROTATION_LOCK_TTL }
		end, ROTATION_LOCK_TTL * 2)
		acquired = result ~= nil
	end)
	return acquired
end

local function releaseLock()
	pcall(function()
		lockMap:UpdateAsync("rotation_lock", function(old)
			if old and old.owner == ownerId then
				return { owner = "", expiry = 0 }
			end
			return nil
		end, 60)
	end)
end

--------------------------------------------------------------------------------
-- Exhaustion -> rotation
--------------------------------------------------------------------------------

-- Authoritative check: every item in the current pool has reserveRemaining 0.
local function poolExhausted(): boolean
	if currentPool == nil then
		return false
	end
	for _, itemId in currentPool.itemIds do
		local snap = EconomyService.snapshot(itemId)
		if snap == nil or (snap.reserveRemaining or 0) > 0 then
			return false
		end
	end
	return true
end

-- Called by StarterService after a reserve decrement hits 0 (cheap trigger);
-- also safe to call opportunistically.
function PoolService.checkRotation()
	if rotating or currentPool == nil then
		return
	end
	if not poolExhausted() then
		return
	end
	rotating = true
	task.spawn(function()
		local done = false
		if tryAcquireLock() then
			-- re-verify under the lock (a racing starter draw may have been mid-flight)
			local latest = readPool()
			adoptPool(latest)
			if latest and latest.seq == currentPool.seq and poolExhausted() then
				local ok, err = pcall(commitNewPool, currentPool.seq + 1)
				if not ok then
					warn("[Pool] rotation failed: " .. tostring(err))
				end
				done = true
			end
			releaseLock()
		end
		if not done then
			-- lock lost or state moved: adopt whatever the winner committed
			task.wait(2)
			adoptPool(readPool())
		end
		rotating = false
	end)
end

--------------------------------------------------------------------------------
-- Lifecycle / accessors
--------------------------------------------------------------------------------

function PoolService.getCurrentPool(): any
	return currentPool
end

-- Wait briefly for a pool to exist / rotate past a known-exhausted seq
-- (used by starter draws racing a rotation).
function PoolService.waitForPoolBeyond(seq: number?, timeout: number): any
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if currentPool and (seq == nil or currentPool.seq > seq) then
			return currentPool
		end
		task.wait(0.25)
	end
	return currentPool
end

function PoolService.Init()
	StoreAdapters.init()
	poolStore = StoreAdapters.dataStore("PoolStore_v3")
	lockMap = StoreAdapters.sortedMap("PoolLocks_v3")
end

function PoolService.Start()
	-- adopt or seed pool #1
	local pool = readPool()
	if pool then
		adoptPool(pool)
		-- backfill: pool #1 items registered before icons existed get their
		-- imageIds patched (generateDefs(1) is deterministic, same itemIds)
		if pool.seq == 1 then
			for _, itemId in pool.itemIds do
				local item = EconomyService.getItem(itemId)
				if item and item.imageId == nil then
					EconomyService.registerItems(PoolService.generateDefs(1, pool.seed or 0, {}))
					break
				end
			end
		end
	else
		if tryAcquireLock() then
			-- re-check under lock, then seed
			pool = readPool()
			if pool then
				adoptPool(pool)
			else
				local ok, err = pcall(commitNewPool, 1)
				if not ok then
					warn("[Pool] seed failed: " .. tostring(err))
				end
			end
			releaseLock()
		else
			-- another server is seeding; poll until visible
			task.spawn(function()
				while currentPool == nil do
					task.wait(1)
					adoptPool(readPool())
				end
			end)
		end
	end

	StoreAdapters.subscribe(EconomyConfig.PoolBroadcastTopic, function(_payload)
		adoptPool(readPool())
	end)

	Net.bindFunction("GetCurrentPool", function(_player)
		if currentPool == nil then
			return { ok = false, err = "no_pool" }
		end
		local items = {}
		for _, itemId in currentPool.itemIds do
			local snap = EconomyService.snapshot(itemId)
			if snap then
				table.insert(items, snap)
			end
		end
		return { ok = true, poolId = currentPool.poolId, seq = currentPool.seq, items = items }
	end)
end

return PoolService
