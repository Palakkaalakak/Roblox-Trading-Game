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
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local PoolService = require(script.Parent.PoolService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local UniqueCraftService = require(script.Parent.UniqueCraftService)
local Net = require(script.Parent.Parent.Net)

local ROTATION_WAIT_SECONDS = 10

local StarterService = {}

-- ONE shared RNG stream for all draws on this server. Per-draw Random.new()
-- can seed identically for players joining the same instant -> identical
-- bundles; a single advancing stream guarantees each player's roll differs.
local sharedRng = Random.new(os.time() * 1000 + math.floor(os.clock() * 1e6) % 1000)

-- Rank of a rarity name in the ladder (higher = rarer). Built from
-- RarityThresholds' order (Common..Godly) plus the implicit Celestial floor,
-- so "at or above Legendary" is just an index compare.
local RARITY_RANK: { [string]: number } = (function()
	local out = {}
	for i, entry in Items.RarityThresholds do
		out[entry.tier] = i
	end
	out.Celestial = #Items.RarityThresholds + 1
	return out
end)()

-- Build weighted candidate list from a pool: items with reserve > 0, optionally
-- floored to a minimum rarity (for the "super" starter-roll variant).
local function candidatesFrom(pool: any, minRarity: string?): { any }
	local minRank = minRarity and RARITY_RANK[minRarity] or nil
	local out = {}
	for _, itemId in pool.itemIds do
		local item = EconomyService.getItem(itemId)
		local snap = EconomyService.snapshot(itemId)
		if item and snap and (snap.reserveRemaining or 0) > 0 then
			if minRank == nil or (RARITY_RANK[item.rarity] or 0) >= minRank then
				table.insert(out, { id = itemId, weight = item.assignmentWeight })
			end
		end
	end
	return out
end

-- Draw + reserve K copies. Returns grant map itemId->count (may be partial).
function StarterService.drawBundle(k: number, minRarity: string?): { [string]: number }
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

		local candidates = candidatesFrom(pool, minRarity)
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

	-- Variant is decided once here, server-side, before the player has any UI
	-- open to react to — nothing about it is influenced by client timing. The
	-- takeover UI later just replays what was already committed.
	local variants = Items.StarterVariants
	local isSuper = sharedRng:NextNumber() < variants.SuperChance
	local shape = if isSuper then variants.Super else variants.Multi
	local grant = StarterService.drawBundle(shape.count, isSuper and shape.minRarity or nil)

	local grantId = DataService.newId()
	profile.StarterGranted = true
	profile.StarterGrantId = grantId
	profile.StarterVariant = if isSuper then "super" else "multi"
	profile.StarterGrantItems = grant
	profile.StarterRevealShown = false

	local delta = { items = grant, gems = Items.StarterGems }
	local ok, err = InventoryService.applyDelta(player, delta, Enums.GrantSource.Starter, "starter_" .. grantId)
	if not ok then
		warn("[Starter] grant apply failed for " .. player.Name .. ": " .. tostring(err))
	end

	-- The tutorial sends the player straight to Unique Craft slot 1 -- that
	-- only works as a real, completable step if the offer sitting there is
	-- buildable from exactly what they just rolled, zero trading required.
	-- Forced here (not left to UniqueCraftService's normal random fill) so
	-- slot 1 is never anything else on a fresh account.
	local starterOffer = UniqueCraftService.buildStarterOffer(grant, os.time(), player.UserId * 7919 + grantId:len())
	if starterOffer then
		profile.UniqueCrafts = profile.UniqueCrafts or {}
		profile.UniqueCraftNextAt = profile.UniqueCraftNextAt or {}
		profile.UniqueCrafts[1] = starterOffer
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
		variant = profile.StarterVariant,
	})
end

-- What the first-join takeover shows: the already-granted items (name,
-- rarity, imageId, value) plus their aggregate worth converted to an
-- approximate Robux figure at the same rate the Community Rewards conversion
-- panel uses. Nothing here re-rolls or re-grants anything — it reads back a
-- decision StarterService already made and saved.
local function buildReveal(profile: any): any
	local items = {}
	local totalGems = 0
	for itemId, count in profile.StarterGrantItems or {} do
		local snap = EconomyService.snapshot(itemId)
		local value = EconomyService.valueOf(itemId)
		totalGems += value * count
		table.insert(items, {
			itemId = itemId,
			name = snap and snap.name or itemId,
			rarity = snap and snap.rarity or "Common",
			imageId = snap and snap.imageId or "",
			count = count,
			value = value,
		})
	end
	local worthRobux = totalGems / RewardsConfig.BaseGemsPerRobux
	return {
		ok = true,
		variant = profile.StarterVariant or "multi",
		items = items,
		worthRobux = worthRobux,
	}
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

	-- The client asks once on join whether the takeover should show at all
	-- (covers reconnects/rejoins after the grant already happened). Returns
	-- ok=false once the reveal has been acknowledged, so it never reappears.
	Net.bindFunction("GetStarterReveal", function(player)
		if not DataService.isLoaded(player) then
			return { ok = false, err = "loading" }
		end
		local profile = DataService.getProfile(player)
		if profile == nil or profile.StarterRevealShown then
			return { ok = false }
		end
		return buildReveal(profile)
	end)

	Net.bindFunction("AckStarterReveal", function(player)
		local profile = DataService.getProfile(player)
		if profile == nil then
			return { ok = false, err = "loading" }
		end
		profile.StarterRevealShown = true
		DataService.saveNow(player)
		require(script.Parent.QuestService).notify(player.UserId, "starter")
		return { ok = true }
	end)

	-- DEBUG ONLY (admin-gated), removed for release. Re-rolls the caller's own
	-- starter bundle from scratch and hands back a fresh reveal so AdminPanel
	-- can replay the ENTIRE welcome -> roll -> reveal -> continue flow on
	-- demand, instead of a slow reconnect-and-hope-the-profile-resets cycle.
	Net.bindFunction("DebugResetStarter", function(player)
		if not (DebugConfig.AdminUserIds and DebugConfig.AdminUserIds[player.UserId]) then
			return { ok = false, err = "not_admin" }
		end
		local profile = DataService.getProfile(player)
		if profile == nil then
			return { ok = false, err = "loading" }
		end
		profile.StarterGranted = false
		profile.StarterVariant = ""
		profile.StarterGrantItems = {}
		profile.StarterRevealShown = false
		-- Revert to a true fresh account for testing -- as if the player never
		-- bought any extra Unique Craft slots either, not just re-rolled the
		-- starter grant. Otherwise every repeat test after the first starts
		-- with slots already unlocked and the purchase-strip UI never shows.
		profile.UniqueCraftSlots = 1
		-- onProfileLoaded only OVERWRITES slot 1 when buildStarterOffer
		-- succeeds -- a nil result (all viable outputs exhausted, or a
		-- transient catalog gap) silently left the PREVIOUS test's offer
		-- sitting there, still built from the prior roll's items instead of
		-- this one's. Clearing first means a debug reset always either gets a
		-- fresh, correctly-rigged offer or an honestly empty slot, never a
		-- stale one that looks rigged but isn't.
		profile.UniqueCrafts = {}
		profile.UniqueCraftNextAt = {}
		onProfileLoaded(player, profile)
		return buildReveal(profile)
	end)
end

return StarterService
