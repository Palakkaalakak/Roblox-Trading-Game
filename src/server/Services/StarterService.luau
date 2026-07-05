--!strict
-- StarterService: one-time starter bundle on first join.
--
-- Draw algorithm (per plan §6):
--   K weighted draws (duplicates allowed) against the current pool.
--   Weight = item.assignmentWeight, candidates limited to reserve > 0.
--   Each pick is committed via EconomyService.reserveOne (MemoryStore CAS) —
--   the atomic decrement is what makes the draw correct across servers.
--   A failed CAS (raced to zero elsewhere) re-picks from fresh candidates.
--   If the whole pool drains mid-bundle, wait briefly for rotation, then
--   continue against the new pool; grant whatever was secured on timeout.
--
-- Idempotency: StarterGranted flag + grant applied to the same in-memory
-- profile, then saved. Known accepted risk (documented in plan): a crash in
-- the window between reserveOne and save leaks reserved copies (never enter
-- circulation). Tiny window, logged, tolerable for core.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Config.Items)
local WeightedDraw = require(ReplicatedStorage.Shared.Util.WeightedDraw)
local Enums = require(ReplicatedStorage.Shared.Enums)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local PoolService = require(script.Parent.PoolService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ROTATION_WAIT_SECONDS = 10

local StarterService = {}

-- ONE shared RNG stream for all draws on this server. Per-draw Random.new()
-- can seed identically for players joining the same instant -> identical
-- bundles; a single advancing stream guarantees each player's roll differs.
local sharedRng = Random.new(os.time() * 1000 + math.floor(os.clock() * 1e6) % 1000)

-- Build weighted candidate list from a pool: items with reserve > 0.
local function candidatesFrom(pool: any): { any }
	local out = {}
	for _, itemId in pool.itemIds do
		local item = EconomyService.getItem(itemId)
		local snap = EconomyService.snapshot(itemId)
		if item and snap and (snap.reserveRemaining or 0) > 0 then
			table.insert(out, { id = itemId, weight = item.assignmentWeight })
		end
	end
	return out
end

-- Draw + reserve K copies. Returns grant map itemId->count (may be partial).
function StarterService.drawBundle(k: number): { [string]: number }
	local grant: { [string]: number } = {}
	local secured = 0
	local rng = sharedRng

	while secured < k do
		local pool = PoolService.getCurrentPool()
		if pool == nil then
			pool = PoolService.waitForPoolBeyond(nil, ROTATION_WAIT_SECONDS)
			if pool == nil then
				break -- no pool at all; grant what we have
			end
		end

		local candidates = candidatesFrom(pool)
		if #candidates == 0 then
			-- pool looks drained: trigger rotation check and wait for the next pool
			PoolService.checkRotation()
			local newPool = PoolService.waitForPoolBeyond(pool.seq, ROTATION_WAIT_SECONDS)
			if newPool == nil or newPool.seq == pool.seq then
				break -- rotation didn't land in time; partial grant
			end
			continue
		end

		local itemId = WeightedDraw.draw(candidates, rng)
		if itemId == nil then
			break
		end

		local reserved, remaining = EconomyService.reserveOne(itemId)
		if reserved then
			grant[itemId] = (grant[itemId] or 0) + 1
			secured += 1
			if remaining <= 0 then
				PoolService.checkRotation() -- this decrement may have been the last of all 5
			end
		end
		-- CAS miss: loop re-picks from refreshed candidates
	end

	return grant
end

local function onProfileLoaded(player: Player, profile: any)
	if profile.StarterGranted then
		return
	end

	local grant = StarterService.drawBundle(Items.StarterBundleSize)

	local grantId = DataService.newId()
	profile.StarterGranted = true
	profile.StarterGrantId = grantId

	local delta = { items = grant, gems = Items.StarterGems }
	local ok, err = InventoryService.applyDelta(player, delta, Enums.GrantSource.Starter, "starter_" .. grantId)
	if not ok then
		warn("[Starter] grant apply failed for " .. player.Name .. ": " .. tostring(err))
	end
	DataService.saveNow(player)

	local count = 0
	for _, n in grant do
		count += n
	end
	AnalyticsService.log("starter_granted", {
		userId = player.UserId,
		items = grant,
		gems = Items.StarterGems,
		copies = count,
		grantId = grantId,
	})
end

function StarterService.Init() end

function StarterService.Start()
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	-- profiles that finished loading before this connection existed
	for _, player in DataService.getLoadedPlayers() do
		local profile = DataService.getProfile(player)
		if profile then
			task.spawn(onProfileLoaded, player, profile)
		end
	end
end

return StarterService
