--!strict
-- EventProgressService: the two things that make crafting worth coming back to
-- — a personal milestone track, and a server-wide communal goal.
--
-- WHY THIS EXISTS. Crafting already creates value, but on its own it has no
-- shape: the hundredth craft looks exactly like the first, and nothing tells a
-- player they are getting anywhere. Milestones give the activity a spine, and
-- the communal goal gives it other people.
--
-- WHERE THE STATE LIVES.
--   * personal progress is on the profile (Crafting.count / .claimed), so it
--     saves with everything else and needs no store of its own
--   * the communal counter is ONE DataStore key per window, incremented with
--     UpdateAsync, because every server must add into the same number
--
-- WHY THE COMMUNAL COUNTER NEEDS NO RESET JOB: the key is derived from the
-- window index (Rotation.windowIndex), so when the window turns, the key name
-- stops matching and the next goal starts at zero on its own. Same trick the
-- weekly leaderboards use.
--
-- BATCHED WRITES. A craft is a hot path — one UpdateAsync per craft would blow
-- the request budget on a busy server. Crafts are accumulated in memory and
-- flushed on a timer, so the shared counter costs a fixed number of writes per
-- minute no matter how many people are crafting.
--
-- REWARDS ARE ITEMS, NEVER GEMS. Gems only enter the game through ads and
-- Robux; paying them out here would turn crafting into a gem faucet. Item
-- rewards come out of the shared reserve, so a payout is redistribution.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Rotation = require(ReplicatedStorage.Shared.Util.Rotation)
local Enums = require(ReplicatedStorage.Shared.Enums)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local NotificationService = require(script.Parent.NotificationService)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local AnalyticsService = require(script.Parent.AnalyticsService)

local FLUSH_SECONDS = 20
local READ_CACHE_TTL = 10

local EventProgressService = {}

local store: any -- "CommunalGoal_v1": window key -> { total = n }
local pending = 0 -- crafts counted here but not yet pushed to the shared key
local cachedTotal = { at = -math.huge, window = -1, total = 0 }

local function goalWindow(now: number): number
	return Rotation.windowIndex(now, EventConfig.CommunalGoal.WindowSeconds)
end

local function goalKey(window: number): string
	return "g_" .. tostring(window)
end

--------------------------------------------------------------------------------
-- Profile shape
--------------------------------------------------------------------------------

-- Everything this service keeps on a profile, created on demand so old saves
-- migrate simply by being read.
local function craftingOf(profile: any): any
	profile.Crafting = profile.Crafting or { count = 0, claimed = {}, goal = { window = -1, crafts = 0, claimed = false } }
	profile.Crafting.claimed = profile.Crafting.claimed or {}
	profile.Crafting.goal = profile.Crafting.goal or { window = -1, crafts = 0, claimed = false }
	return profile.Crafting
end

-- Roll the per-window contribution over when the window turns, so a player who
-- was away wakes up on the current goal rather than a stale one.
local function syncGoalWindow(crafting: any, window: number)
	if crafting.goal.window ~= window then
		crafting.goal = { window = window, crafts = 0, claimed = false }
	end
end

--------------------------------------------------------------------------------
-- Communal counter
--------------------------------------------------------------------------------

local function flush()
	if pending <= 0 then
		return
	end
	local amount = pending
	pending = 0
	local window = goalWindow(os.time())
	local ok = pcall(function()
		store:UpdateAsync(goalKey(window), function(old)
			old = old or { total = 0 }
			old.total = (old.total or 0) + amount
			return old
		end)
	end)
	if not ok then
		pending += amount -- put it back; the next flush retries
	else
		cachedTotal.at = -math.huge -- force a re-read so the bar moves promptly
	end
end

-- Combined progress: what the shared key holds, plus what this server has
-- counted but not yet flushed, so the bar never appears to stall.
local function communalTotal(): number
	local window = goalWindow(os.time())
	if cachedTotal.window ~= window then
		cachedTotal = { at = -math.huge, window = window, total = 0 }
	end
	if (os.clock() - cachedTotal.at) >= READ_CACHE_TTL then
		local total = 0
		local ok = pcall(function()
			local rec = store:GetAsync(goalKey(window))
			if typeof(rec) == "table" and typeof(rec.total) == "number" then
				total = rec.total
			end
		end)
		if ok then
			cachedTotal = { at = os.clock(), window = window, total = total }
		end
	end
	return cachedTotal.total + pending
end

--------------------------------------------------------------------------------
-- Recording a craft
--------------------------------------------------------------------------------

-- Called by CraftingService after a craft settles. Bots are excluded by the
-- caller: a communal goal that bots can finish isn't a communal goal.
function EventProgressService.recordCraft(player: Player)
	local profile = DataService.getProfile(player)
	if profile == nil then
		return
	end
	local crafting = craftingOf(profile)
	crafting.count += 1

	if EventConfig.CommunalGoal.enabled then
		syncGoalWindow(crafting, goalWindow(os.time()))
		crafting.goal.crafts += 1
		pending += 1
	end

	-- tell them the moment a milestone opens up, rather than making them go and
	-- check the panel for it
	if EventConfig.Milestones.enabled then
		for _, tier in EventConfig.Milestones.Tiers do
			if crafting.count == tier.crafts then
				NotificationService.notify(
					player.UserId,
					("%s reached — claim your reward in Events."):format(tier.name)
				)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Views + claims
--------------------------------------------------------------------------------

function EventProgressService.progressFor(player: Player): any
	local profile = DataService.getProfile(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local crafting = craftingOf(profile)
	local window = goalWindow(os.time())
	syncGoalWindow(crafting, window)

	local reached, nextTier = EventConfig.milestoneAt(crafting.count)
	local tiers = {}
	for i, tier in EventConfig.Milestones.Tiers do
		local item = EconomyService.getItem(tier.reward.itemId)
		table.insert(tiers, {
			index = i,
			name = tier.name,
			crafts = tier.crafts,
			rewardName = item and item.name or tier.reward.itemId,
			rewardCount = tier.reward.count,
			rewardImage = item and item.imageId or nil,
			reached = crafting.count >= tier.crafts,
			claimed = crafting.claimed[tostring(i)] == true,
		})
	end

	local goalCfg = EventConfig.CommunalGoal
	local goalItem = EconomyService.getItem(goalCfg.Reward.itemId)
	local total = communalTotal()
	return {
		ok = true,
		crafts = crafting.count,
		milestoneReached = reached,
		nextMilestone = nextTier and { name = nextTier.name, crafts = nextTier.crafts } or nil,
		tiers = tiers,
		goal = {
			enabled = goalCfg.enabled,
			name = goalCfg.Name,
			blurb = goalCfg.Blurb,
			total = total,
			target = goalCfg.Target,
			yourCrafts = crafting.goal.crafts,
			claimed = crafting.goal.claimed == true,
			complete = total >= goalCfg.Target,
			canClaim = total >= goalCfg.Target
				and crafting.goal.crafts >= goalCfg.MinContribution
				and crafting.goal.claimed ~= true,
			rewardName = goalItem and goalItem.name or goalCfg.Reward.itemId,
			rewardCount = goalCfg.Reward.count,
			endsAt = Rotation.windowEndsAt(os.time(), goalCfg.WindowSeconds),
		},
	}
end

-- Hand over a reward from the shared reserve. Reserving BEFORE granting means a
-- reward can never mint copies past an item's cap; if the reserve is dry the
-- claim stays unclaimed so it can be retried later rather than being burnt.
local function payReward(player: Player, itemId: string, count: number): boolean
	local taken = 0
	for _ = 1, count do
		if not EconomyService.reserveOne(itemId) then
			break
		end
		taken += 1
	end
	if taken == 0 then
		return false
	end
	local ok = InventoryService.applyDelta(player, { items = { [itemId] = taken } }, Enums.GrantSource.Craft)
	if not ok then
		EconomyService.restockCopies(itemId, taken)
		return false
	end
	task.spawn(function()
		DataService.saveNow(player)
	end)
	return true
end

function EventProgressService.claimMilestone(player: Player, index: any): any
	local profile = DataService.getProfile(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	if typeof(index) ~= "number" then
		return { ok = false, err = "bad_args" }
	end
	local tier = EventConfig.Milestones.Tiers[index]
	if tier == nil then
		return { ok = false, err = "unknown_milestone" }
	end
	local crafting = craftingOf(profile)
	if crafting.count < tier.crafts then
		return { ok = false, err = "not_reached" }
	end
	local key = tostring(index)
	if crafting.claimed[key] then
		return { ok = false, err = "already_claimed" }
	end

	-- mark first so two clicks can't double-pay, then undo if the payout fails
	crafting.claimed[key] = true
	if not payReward(player, tier.reward.itemId, tier.reward.count) then
		crafting.claimed[key] = nil
		return { ok = false, err = "reward_unavailable" }
	end
	AnalyticsService.log("milestone_claimed", { userId = player.UserId, tier = index })
	return { ok = true, name = tier.name }
end

function EventProgressService.claimGoal(player: Player): any
	local profile = DataService.getProfile(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local goalCfg = EventConfig.CommunalGoal
	if not goalCfg.enabled then
		return { ok = false, err = "goal_off" }
	end
	local crafting = craftingOf(profile)
	syncGoalWindow(crafting, goalWindow(os.time()))
	if crafting.goal.claimed then
		return { ok = false, err = "already_claimed" }
	end
	if crafting.goal.crafts < goalCfg.MinContribution then
		return { ok = false, err = "did_not_help" }
	end
	if communalTotal() < goalCfg.Target then
		return { ok = false, err = "goal_incomplete" }
	end

	crafting.goal.claimed = true
	if not payReward(player, goalCfg.Reward.itemId, goalCfg.Reward.count) then
		crafting.goal.claimed = false
		return { ok = false, err = "reward_unavailable" }
	end
	AnalyticsService.log("goal_claimed", { userId = player.UserId, window = crafting.goal.window })
	return { ok = true }
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function EventProgressService.Init()
	store = StoreAdapters.dataStore("CommunalGoal_v1")
end

function EventProgressService.Start()
	Net.bindFunction("GetCraftProgress", function(player)
		return EventProgressService.progressFor(player)
	end)
	Net.bindFunction("ClaimMilestone", function(player, index)
		return EventProgressService.claimMilestone(player, index)
	end)
	Net.bindFunction("ClaimCommunalGoal", function(player)
		return EventProgressService.claimGoal(player)
	end)

	task.spawn(function()
		while true do
			task.wait(FLUSH_SECONDS)
			flush()
		end
	end)

	-- don't lose the tail of a window's crafts when a server shuts down
	game:BindToClose(function()
		flush()
	end)

	-- announce completion once per server, so the room finds out together
	task.spawn(function()
		local announced = -1
		while true do
			task.wait(30)
			if EventConfig.CommunalGoal.enabled then
				local window = goalWindow(os.time())
				if announced ~= window and communalTotal() >= EventConfig.CommunalGoal.Target then
					announced = window
					for _, player in Players:GetPlayers() do
						NotificationService.notify(
							player.UserId,
							("%s complete! Everyone who helped can claim their reward in Events."):format(
								EventConfig.CommunalGoal.Name)
						)
					end
				end
			end
		end
	end)
end

return EventProgressService
