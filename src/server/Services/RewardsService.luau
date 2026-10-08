--!strict
-- RewardsService: Community Rewards status for the HUD bar, plus the lifetime
-- playtime counter that conversion-rate modifiers read.
--
-- Playtime accrues in memory and is folded into Lifetime.playSeconds every
-- FLUSH_SECONDS, so at most that much is lost if a save lands before the
-- final flush on leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)

local FLUSH_SECONDS = 30

local RewardsService = {}

local sessionStart: { [number]: number } = {}

local function flush(player: Player)
	local started = sessionStart[player.UserId]
	local profile = DataService.getProfile(player)
	if started == nil or profile == nil then
		return
	end
	local whole = math.floor(os.clock() - started)
	profile.Lifetime.playSeconds = (profile.Lifetime.playSeconds or 0) + whole
	sessionStart[player.UserId] = started + whole -- keep the fractional remainder
end

function RewardsService.statusFor(player: Player, reportedWorth: any): any?
	local profile = DataService.getProfile(player)
	if profile == nil then
		return nil
	end
	flush(player)
	local gems = profile.Gems or 0
	-- Peak worth only ever rises: a dip pauses the bar until worth passes
	-- the old peak again. Worth is the client's gems+items estimate, never
	-- below real gems; it only drives the display, never eligibility.
	local worth = math.max(gems, type(reportedWorth) == "number" and reportedWorth == reportedWorth and reportedWorth or 0)
	worth = math.min(worth, RewardsConfig.Threshold * 10)
	profile.Lifetime.peakWorth = math.max(profile.Lifetime.peakWorth or 0, worth)
	return RewardsConfig.status(gems, profile.Lifetime.peakWorth, {
		playSeconds = profile.Lifetime.playSeconds or 0,
		tutorialDone = (profile.Progression and profile.Progression.completed or 0) >= 2,
	})
end

function RewardsService.Init() end

function RewardsService.Start()
	local function track(player: Player)
		sessionStart[player.UserId] = os.clock()
	end
	DataService.ProfileLoaded:Connect(track)
	for _, player in DataService.getLoadedPlayers() do
		if sessionStart[player.UserId] == nil then
			track(player)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		flush(player)
		sessionStart[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(FLUSH_SECONDS)
			for _, player in Players:GetPlayers() do
				flush(player)
			end
		end
	end)

	Net.bindFunction("GetRewardsStatus", function(player, worth)
		local status = RewardsService.statusFor(player, worth)
		if status == nil then
			return { ok = false, err = "loading" }
		end
		return { ok = true, status = status }
	end)
end

return RewardsService
