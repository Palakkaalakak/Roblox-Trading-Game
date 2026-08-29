--!strict
-- AFK zones.
--
-- A player asks to go AFK, the server picks a pad with room, plants them on it
-- and anchors them there. Every TickSeconds they are still standing on it, they
-- are paid the next rung of the reward ladder.
--
-- The server owns ALL of it: which pad you get, whether you are still on it,
-- how many ticks you have banked, and what each one pays. The client sends
-- "I want to go AFK" and "I am done" and nothing else -- there is no message
-- that says "pay me", so there is nothing to forge.
--
-- Sessions are in-memory and per-server by construction: a pad is a spot in one
-- server, and the reward ladder is a reward for sitting in THIS session. Leaving
-- drops the ladder (see AfkConfig.ResetLadderOnLeave), which is what stops
-- hopping out and back in to farm the top rung.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AfkConfig = require(ReplicatedStorage.Shared.Config.AfkConfig)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local AfkService = {}

type Session = {
	zoneId: string,
	since: number,
	nextTickAt: number,
	ticks: number,
	paid: number, -- rungs that actually granted something
	anchorWas: boolean,
	idleSince: number?, -- clock when Player.Idled first reached us
	refreshing: boolean?, -- a teleport is already in flight
}

local sessions: { [Player]: Session } = {}
-- zoneId -> pad. Rebuilt on demand so a pad cloned in at run time is picked up
-- without a restart, which is exactly how these get built.
local zones: { [string]: BasePart } = {}

--------------------------------------------------------------------------------
-- Zones
--------------------------------------------------------------------------------

local function padOf(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

-- Found by tag OR by name prefix: tagging is tidier, but a builder cloning a
-- pad in the explorer should not have to remember to tag it.
local function refreshZones()
	table.clear(zones)
	for _, inst in CollectionService:GetTagged(AfkConfig.Tag) do
		local pad = padOf(inst)
		if pad then
			zones[inst.Name] = pad
		end
	end
	for _, inst in workspace:GetDescendants() do
		if inst.Name:sub(1, #AfkConfig.ZoneNamePrefix) == AfkConfig.ZoneNamePrefix and zones[inst.Name] == nil then
			local pad = padOf(inst)
			if pad then
				zones[inst.Name] = pad
			end
		end
	end
end

local function occupancy(): { [string]: number }
	local counts: { [string]: number } = {}
	for _, session in sessions do
		counts[session.zoneId] = (counts[session.zoneId] or 0) + 1
	end
	return counts
end

-- Lowest-numbered zone with room. Sorting by name keeps the fill order stable
-- and readable ("everyone piles into 1, then 2"), rather than whichever pad the
-- workspace iteration happened to yield first.
local function firstFreeZone(): (string?, BasePart?)
	refreshZones()
	local ids = {}
	for id in zones do
		table.insert(ids, id)
	end
	table.sort(ids)
	local counts = occupancy()
	for _, id in ids do
		if (counts[id] or 0) < AfkConfig.Capacity then
			return id, zones[id]
		end
	end
	return nil, nil
end

-- A spot ON the pad, spread around its centre so six players do not stack into
-- one another. Deterministic from the slot index: no RNG, same layout every run.
local function standingSpot(pad: BasePart, slot: number): CFrame
	local ring = math.min(pad.Size.X, pad.Size.Z) * 0.30
	local angle = (slot - 1) * (math.pi * 2 / AfkConfig.Capacity)
	local offset = Vector3.new(math.cos(angle) * ring, pad.Size.Y / 2 + 3, math.sin(angle) * ring)
	return CFrame.new(pad.Position + offset)
end

--------------------------------------------------------------------------------
-- Freeze / release
--------------------------------------------------------------------------------

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Anchoring the root is the WHOLE freeze. Forcing the humanoid into Physics
-- state as well looked equivalent but is not: coming back out of it through
-- GettingUp let the humanoid re-seat itself, and the player was dumped back at
-- the spawn instead of stepping off the pad they were standing on.
local function freeze(player: Player, pad: BasePart, slot: number): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	root.CFrame = standingSpot(pad, slot)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	return true
end

-- Where a player lands when they stand up. AFK pads sit off to the side, so
-- dropping someone back on one after they said they were done leaves them
-- stranded next to a pad they just left; the plaza is where the game is.
local function returnPoint(): CFrame
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(0, 8, 0)
end

-- Unanchor, then put them back in the plaza. The placement is deferred so it
-- lands AFTER the unanchor has settled -- setting a CFrame on a part that is
-- still anchored is silently undone the moment physics takes it back.
local function unfreeze(player: Player, wasAnchored: boolean)
	local root = rootOf(player)
	if root == nil then
		return
	end
	root.Anchored = wasAnchored
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local target = returnPoint()
	task.defer(function()
		if root.Parent then
			root.CFrame = target
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

--------------------------------------------------------------------------------
-- Granters
--
-- A rung of the ladder is a spec; this table turns a spec into an actual grant.
-- Adding a reward kind means adding one function here, not touching the tick
-- loop, and choosing what AFK pays means editing AfkConfig.Rewards alone.
--
-- Each returns (paid, note). `paid = false` is not an error path -- "tbd" takes
-- it deliberately -- so a ladder nobody has filled in yet ticks along harmlessly
-- and says so instead of silently pretending to pay.
--------------------------------------------------------------------------------

local granters: { [string]: (Player, any, string) -> (boolean, string?) } = {}

granters.tbd = function()
	return false, "reward_not_configured"
end

granters.gems = function(player, spec, claimId)
	local amount = math.floor(tonumber(spec.amount) or 0)
	if amount <= 0 then
		return false, "bad_amount"
	end
	return InventoryService.applyDelta(player, { gems = amount }, "afk_tick", claimId), nil
end

granters.items = function(player, spec, claimId)
	if type(spec.items) ~= "table" or next(spec.items) == nil then
		return false, "bad_items"
	end
	return InventoryService.applyDelta(player, { items = spec.items }, "afk_tick", claimId), nil
end

granters.boost = function(player, spec)
	if not Guard.isString(spec.sku, 64) then
		return false, "bad_sku"
	end
	local profile = DataService.getProfile(player)
	if profile == nil then
		return false, "loading"
	end
	local board = require(script.Parent.TradeBoardService) :: any
	board.bankCredit(profile, spec.sku)
	return true, nil
end

-- Declared so the config can name it and the shape is settled, but there is no
-- roll credit on the profile yet. Wiring it is this function plus that field --
-- nothing else in AFK has to change.
granters.rolls = function()
	return false, "rolls_not_wired"
end

local function grant(player: Player, spec: any, claimId: string): (boolean, string?)
	if type(spec) ~= "table" then
		return false, "bad_spec"
	end
	local fn = granters[tostring(spec.kind)]
	if fn == nil then
		return false, "unknown_kind"
	end
	return fn(player, spec, claimId)
end

local function stateFor(player: Player): any
	local session = sessions[player]
	if session == nil then
		return {
			ok = true,
			afk = false,
			nextReward = AfkConfig.describe(AfkConfig.rewardFor(1)),
			tickSeconds = AfkConfig.TickSeconds,
		}
	end
	return {
		ok = true,
		afk = true,
		zoneId = session.zoneId,
		ticks = session.ticks,
		paid = session.paid,
		secondsToNext = math.max(0, math.floor(session.nextTickAt - os.clock())),
		nextReward = AfkConfig.describe(AfkConfig.nextReward(session.ticks)),
		tickSeconds = AfkConfig.TickSeconds,
	}
end

local function push(player: Player)
	Net.fireClient("AfkStateChanged", player, stateFor(player))
end

-- One exit for every way a session can end, so the anchor is never left on.
local function release(player: Player, reason: string)
	local session = sessions[player]
	if session == nil then
		return
	end
	sessions[player] = nil
	unfreeze(player, session.anchorWas)
	AnalyticsService.log("afk_left", {
		userId = player.UserId,
		zoneId = session.zoneId,
		ticks = session.ticks,
		paid = session.paid,
		reason = reason,
	})
	if player.Parent then
		push(player)
	end
end

AfkService.release = release

--------------------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Staying connected
--
-- Roblox disconnects an idle client at ~20 minutes and offers no way to turn
-- that off. Rather than asking the player to point an autoclicker at the screen,
-- an AFK player is teleported back into the same place before the kick lands: a
-- new client session gets a new idle timer, and the ladder rides along in the
-- teleport data so the round trip costs them nothing.
--------------------------------------------------------------------------------

local function refresh(player: Player, session: Session)
	if session.refreshing then
		return
	end
	session.refreshing = true
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		afk = true,
		ticks = session.ticks,
		paid = session.paid,
	})
	AnalyticsService.log("afk_refresh", {
		userId = player.UserId,
		zoneId = session.zoneId,
		ticks = session.ticks,
	})
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		-- Teleports fail in Studio and can fail live. Losing the session is
		-- worse than losing the refresh, so the player just keeps sitting there
		-- and takes the kick they would have taken anyway.
		session.refreshing = false
		warn(("[Afk] refresh teleport failed for %s: %s"):format(player.Name, tostring(err)))
	end
end

local function enter(player: Player, restore: any?): any
	if not AfkConfig.Enabled then
		return { ok = false, err = "disabled" }
	end
	if sessions[player] then
		return { ok = false, err = "already_afk" }
	end
	if DataService.getProfile(player) == nil then
		return { ok = false, err = "loading" }
	end
	if rootOf(player) == nil then
		return { ok = false, err = "no_character" }
	end
	local zoneId, pad = firstFreeZone()
	if zoneId == nil or pad == nil then
		-- every pad full, or the place has none built yet
		return { ok = false, err = next(zones) == nil and "no_zones" or "zones_full" }
	end
	local slot = (occupancy()[zoneId] or 0) + 1
	local root = rootOf(player) :: BasePart
	local wasAnchored = root.Anchored
	if not freeze(player, pad, slot) then
		return { ok = false, err = "no_character" }
	end
	sessions[player] = {
		zoneId = zoneId,
		since = os.clock(),
		nextTickAt = os.clock() + AfkConfig.TickSeconds,
		-- A refresh teleport hands the ladder back, so the trip is invisible to
		-- the player: they do not drop to rung one for staying put.
		ticks = (restore and tonumber(restore.ticks)) or 0,
		paid = (restore and tonumber(restore.paid)) or 0,
		anchorWas = wasAnchored,
	}
	AnalyticsService.log("afk_entered", { userId = player.UserId, zoneId = zoneId })
	push(player)
	return stateFor(player)
end

function AfkService.Init() end

function AfkService.Start()
	if not AfkConfig.Enabled then
		return
	end
	refreshZones()

	Net.bindFunction("EnterAfk", enter)
	Net.bindFunction("LeaveAfk", function(player)
		release(player, "player_left")
		return stateFor(player)
	end)
	Net.bindFunction("GetAfkState", function(player)
		return stateFor(player)
	end)
	-- Player.Idled only exists on the client, so the client reports it and the
	-- server decides. Nothing is granted here and nothing is trusted: the worst
	-- a forged ping can do is teleport the sender back into the same place.
	Net.bindFunction("AfkIdlePing", function(player)
		local session = sessions[player]
		if session == nil or not AfkConfig.RefreshOnIdle then
			return { ok = true }
		end
		local now = os.clock()
		session.idleSince = session.idleSince or now
		if now - session.idleSince >= AfkConfig.IdleRefreshSeconds then
			refresh(player, session)
		end
		return { ok = true }
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil -- nothing to unfreeze: the character is going too
	end)

	-- Coming back from a refresh teleport: put them straight back on a pad with
	-- the ladder they had. Without this the refresh would read as "the game
	-- randomly rejoined me and took my progress".
	local function resumeIfRefreshed(player: Player)
		local ok, join = pcall(function()
			return player:GetJoinData()
		end)
		local data = ok and join and join.TeleportData or nil
		if type(data) ~= "table" or data.afk ~= true then
			return
		end
		task.spawn(function()
			-- wait for a character and a loaded profile before claiming a slot
			for _ = 1, 60 do
				if rootOf(player) and DataService.getProfile(player) then
					break
				end
				task.wait(0.5)
			end
			if player.Parent and sessions[player] == nil then
				enter(player, data)
			end
		end)
	end
	Players.PlayerAdded:Connect(resumeIfRefreshed)
	for _, player in Players:GetPlayers() do
		resumeIfRefreshed(player)
	end

	-- Respawning breaks the session: the anchored body it belonged to is gone.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			release(player, "respawned")
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			release(player, "respawned")
		end)
	end

	-- The payout loop. One second of granularity is plenty for a ten minute
	-- timer and costs nothing: the body is a walk over however many players are
	-- actually AFK, which is bounded by zones times capacity.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, session in sessions do
				if player.Parent == nil then
					sessions[player] = nil
					continue
				end
				-- Still on the pad? A player who has been moved off it -- by a
				-- respawn, a teleport, anything -- stops earning immediately.
				local pad = zones[session.zoneId]
				local root = rootOf(player)
				if pad == nil or root == nil then
					release(player, "zone_gone")
					continue
				end
				if (root.Position - pad.Position).Magnitude > AfkConfig.MaxDistanceFromPad then
					release(player, "left_pad")
					continue
				end
				if now >= session.nextTickAt then
					session.ticks += 1
					session.nextTickAt = now + AfkConfig.TickSeconds
					local spec = AfkConfig.rewardFor(session.ticks)
					-- Keyed per player, per sitting, per rung: a retried or
					-- duplicated grant lands once.
					local claimId =
						("afk_%d_%d_%d"):format(player.UserId, math.floor(session.since), session.ticks)
					local paid, note = grant(player, spec, claimId)
					if paid then
						session.paid += 1
					end
					AnalyticsService.log("afk_tick", {
						userId = player.UserId,
						zoneId = session.zoneId,
						tick = session.ticks,
						kind = type(spec) == "table" and tostring(spec.kind) or "none",
						paid = paid,
						note = note,
					})
					push(player)
				end
			end
		end
	end)
end

return AfkService
