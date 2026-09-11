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
-- seq 2+ = procedural from PoolTemplate, which spans all six tiers.
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

	local slots = Items.PoolTemplate

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
	local iconOrder = #freshIcons >= #slots and freshIcons or Items.IconPool
	iconOrder = table.clone(iconOrder)
	for i = #iconOrder, 2, -1 do
		local j = rng:NextInteger(1, i)
		iconOrder[i], iconOrder[j] = iconOrder[j], iconOrder[i]
	end

	for i, slot in slots do
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

-- fwd decl: commitNewPool consults this, but it lives down in the rotation
-- section next to the rest of the exhaustion logic
local findRevivablePool: () -> (string?, any)

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
-- Commit pool `seq`. Prefers REVIVING a retired pool that has refilled past
-- RevivalStockFraction over minting a fresh one — consumed copies come back to
-- the pool they left, so an old lineup returning is the system working, and it
-- keeps the registry from growing a new pool on every single rotation.
--
-- `seq` always advances even on a revival: it is the version of the pool
-- POINTER, not an identity. adoptPool only moves forward on seq, so a revived
-- pool_2 landing as seq 9 is how every other server learns to switch to it.
local function commitNewPool(seq: number)
	local revivedId, revived = findRevivablePool()

	local pool
	if revivedId and revived then
		pool = {
			poolId = revivedId,
			seq = seq,
			itemIds = revived.itemIds,
			createdAt = os.time(),
			revived = true,
		}
		AnalyticsService.log("pool_revived", {
			poolId = revivedId,
			seq = seq,
			recovery = math.floor(revived.recovery * 100),
			reserve = revived.reserve,
		})
	else
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
		pool = {
			poolId = "pool_" .. tostring(seq),
			seq = seq,
			itemIds = itemIds,
			createdAt = os.time(),
			seed = seed,
		}
	end
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
-- Exhausted item -> rotation
--------------------------------------------------------------------------------
-- A pool used to retire only once EVERY item in it hit zero reserve, which is
-- far too late. A roll picks a rarity by the tier's authored odds, then an item
-- inside that rarity by assignment weight. While every item still has at least
-- one copy, that split is exactly what the odds card claims, and it stays exact
-- however lopsided the remaining COUNTS get -- counts are not weights, so an
-- item down to its last copy is still drawn at its full advertised rate.
--
-- An item at ZERO is the break. It drops out of its rarity's weight split and
-- its share is silently absorbed by whatever else sits in that rarity, so every
-- surviving item in that tier gets likelier than advertised. That is both a lie
-- and a farm: drain the item you don't want and the rest improve.
--
-- Hence the whole rule: replace the pool as soon as ANY of its items is
-- exhausted.
--
-- Items from already-retired pools keep whatever reserve they had and stay
-- rollable until drained, which is what keeps redistribution honest: copies
-- handed back by crafting or roll-payments (EconomyService.restockCopies) go to
-- their own item, hence their own pool, and can be drawn again.

-- ROLL pools only. EconomyService.registerItems is shared: CraftingService
-- registers every event/recipe output through it too, and those carry a poolId
-- of their own ("evt_alchemist" and friends). Those are minted by recipes, not
-- by rolls, and must never be adopted as the roll lineup — an early version of
-- the revival scan did exactly that and handed the gacha an event's item list.
-- PoolService mints under "pool_<seq>" and nothing else does.
local function isRollPoolId(poolId: string): boolean
	return poolId:match("^pool_%d+$") ~= nil
end

-- Every roll pool that has ever been minted, reconstructed from the item
-- registry. No extra storage: each item already carries the poolId it was
-- minted under, and totalSupply never changes, so a pool's original size is
-- recoverable by summing it. `complete` = every item still holds a copy.
local function poolGroups(): { [string]: any }
	local groups: { [string]: any } = {}
	for itemId, item in EconomyService.allItems() do
		local pid = item.poolId
		if pid and isRollPoolId(pid) then
			local g = groups[pid]
			if g == nil then
				g = { itemIds = {}, supply = 0, reserve = 0, complete = true }
				groups[pid] = g
			end
			table.insert(g.itemIds, itemId)
			g.supply += item.totalSupply or 0
			local snap = EconomyService.snapshot(itemId)
			local left = snap and (snap.reserveRemaining or 0) or 0
			g.reserve += left
			if left <= 0 then
				g.complete = false
			end
		end
	end
	return groups
end

-- A retired pool that has refilled enough to take over again, or nil.
-- Best = furthest recovered, so the pool most able to survive a while wins;
-- ties break on poolId so every server picks the same one.
function findRevivablePool(): (string?, any)
	local minFraction = Items.RollPoolRotation.RevivalStockFraction
	local activeId = currentPool and currentPool.poolId or nil
	local bestId, bestGroup, bestRecovery = nil, nil, -1
	for pid, g in poolGroups() do
		if pid ~= activeId and g.complete and g.supply > 0 then
			local recovery = g.reserve / g.supply
			if recovery >= minFraction then
				if recovery > bestRecovery or (recovery == bestRecovery and bestId and pid < bestId) then
					bestId, bestGroup, bestRecovery = pid, g, recovery
				end
			end
		end
	end
	if bestGroup then
		table.sort(bestGroup.itemIds) -- deterministic across servers
		bestGroup.recovery = bestRecovery
	end
	return bestId, bestGroup
end

-- The items in the ACTIVE pool that have nothing left to give.
local function exhaustedItems(): { string }
	local out: { string } = {}
	if currentPool == nil then
		return out
	end
	for _, itemId in currentPool.itemIds do
		local snap = EconomyService.snapshot(itemId)
		if snap == nil or (snap.reserveRemaining or 0) <= 0 then
			table.insert(out, itemId)
		end
	end
	return out
end

-- Called opportunistically: after a roll, after a starter draw, and on the
-- periodic sweep. Cheap when there is nothing to do.
function PoolService.checkRotation()
	if rotating or currentPool == nil then
		return
	end
	local spent = exhaustedItems()
	-- Self-heal: the stored pointer must name a ROLL pool. It can only be
	-- otherwise through a bug (an early revival scan adopted an event's item
	-- group), but the pointer is durable, so a bad one would stick forever and
	-- serve recipe outputs as the gacha lineup. Treat it as a rotation trigger.
	local wrongNamespace = not isRollPoolId(currentPool.poolId)
	if #spent == 0 and not wrongNamespace then
		return
	end
	if wrongNamespace then
		warn(("[Pool] active pool %q is not a roll pool — rotating away from it"):format(currentPool.poolId))
	end

	rotating = true
	task.spawn(function()
		local done = false
		if tryAcquireLock() then
			-- re-verify under the lock (another server may have just rotated)
			local latest = readPool()
			adoptPool(latest)
			local fresh = exhaustedItems()
			if latest and latest.seq == currentPool.seq and (#fresh > 0 or wrongNamespace) then
				AnalyticsService.log("pool_exhausted_item", {
					seq = currentPool.seq,
					exhausted = #fresh,
					first = fresh[1],
				})
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
	-- v6 alongside ItemRegistry_v6/EconomyStore_v6: these three MUST move in
	-- lockstep — a stale pool record against a fresh registry means pool_1 is
	-- never re-registered and every item lookup misses (which is a read storm).
	poolStore = StoreAdapters.dataStore("PoolStore_v6")
	lockMap = StoreAdapters.sortedMap("PoolLocks_v6")
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

	-- Backstop sweep. The roll and starter-draw paths already poke
	-- checkRotation the moment they spend a copy, so this only catches copies
	-- that left by some other route.
	task.spawn(function()
		while true do
			task.wait(Items.RollPoolRotation.CheckIntervalSeconds)
			PoolService.checkRotation()
		end
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
