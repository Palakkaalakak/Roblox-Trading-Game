--!strict
-- AdRewardService: free gems for watching a rewarded video.
--
-- Deliberately its own screen and its own service — nothing about it is wired
-- into the Robux shop, because a player who won't spend money should never feel
-- like they're being funnelled at one.
--
-- FLOW (all four steps are Roblox's, not ours):
--   1. the client asks AdService whether a rewarded video is available right
--      now; that answer is good for a SINGLE play, so it is re-checked before
--      every watch
--   2. the server builds a reward from a dev product id
--      (CreateAdRewardFromDevProductId) and calls ShowRewardedVideoAdAsync
--   3. Roblox plays the ad and, if the player actually watched it, fires the
--      normal purchase pipeline for that dev product — the player is NOT charged
--   4. the gems land in ProcessReceipt, through ProductService's receipt
--      registry, exactly like a bought gem pack
--
-- Step 4 is the important one: the payout shares the shop's idempotency, so a
-- replayed receipt can never pay twice, and there is no second grant path to
-- keep in sync.
--
-- ELIGIBILITY: Roblox only fills rewarded video for a public game by a 13+
-- ID-verified creator with 2,000+ monthly visitors. Until then every
-- availability check simply returns false, which is why the screen leads with
-- the community goal instead of a button that would do nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Enums)
local AdConfig = require(ReplicatedStorage.Shared.Config.AdConfig)
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local ProductService = require(script.Parent.ProductService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local AdRewardService = {}

-- DEBUG ONLY — remove this table and every reference to it for release. Lets a
-- dev preview the post-goal (watch-ad) UI without 2,000 real players. In-memory
-- per-session, never persisted, and gated behind DebugConfig.ForceGoalMetEnabled.
local debugForcedGoal: { [number]: boolean } = {}

-- AdService doesn't exist in older clients / some Studio builds, and calling a
-- missing service would break the whole screen. Resolve it defensively once.
local adService: any = nil
do
	local ok, svc = pcall(function()
		return game:GetService("AdService")
	end)
	if ok then
		adService = svc
	end
end

-- UTC day stamp; the daily cap resets when this stops matching what's stored.
local function today(): string
	return os.date("!%Y-%m-%d") :: string
end

-- The player's ad counters, rolled over to today if the stored day is stale.
local function counters(player: Player): any?
	local profile = DataService.getProfile(player)
	if profile == nil then
		return nil
	end
	profile.Ads = profile.Ads or { day = "", count = 0, lastAt = 0, bonusUsed = 0 }
	profile.Ads.bonusUsed = profile.Ads.bonusUsed or 0
	local stamp = today()
	if profile.Ads.day ~= stamp then
		profile.Ads.day = stamp
		profile.Ads.count = 0
	end
	return profile.Ads
end

-- Is a rewarded video actually fillable right now? False whenever the game
-- isn't ads-eligible yet, which is the normal case during development.
local function adAvailable(player: Player): boolean
	if adService == nil or AdConfig.RewardProductId == 0 then
		return false
	end
	local ok, available = pcall(function()
		return adService:GetAdAvailabilityNowAsync(player, Enum.AdFormat.RewardedVideo)
	end)
	return ok and available == true
end

-- What the Free Gems screen needs to render itself, in one payload.
function AdRewardService.snapshot(player: Player): any
	local players = DataService.uniquePlayerCount()
	local unlocked = AdConfig.goalMet(players) or debugForcedGoal[player.UserId] == true
	local ads = counters(player)
	local used = ads and ads.count or 0
	local lastAt = ads and ads.lastAt or 0
	local cooldown = math.max(0, (lastAt + AdConfig.CooldownSeconds) - os.time())
	local profile = DataService.getProfile(player)
	local bonusEligible = profile ~= nil and profile.ReferralBonus == true
	local bonusUsed = ads and ads.bonusUsed or 0
	local referrals = (profile and profile.Referrals and profile.Referrals.count) or 0
	return {
		ok = true,
		unlocked = unlocked,
		players = players,
		target = AdConfig.CommunityGoalTarget,
		progress = AdConfig.goalProgress(players),
		reward = AdConfig.rewardFor(bonusEligible, bonusUsed),
		baseReward = AdConfig.RewardGems,
		referrals = referrals,
		referralsNeeded = AdConfig.ReferralsNeeded,
		bonusPercent = AdConfig.ReferralBonusPercent,
		bonusEligible = bonusEligible,
		bonusLeft = bonusEligible and math.max(0, AdConfig.ReferralBonusWatches - bonusUsed) or 0,
		used = used,
		cap = AdConfig.DailyCap,
		remaining = math.max(0, AdConfig.DailyCap - used),
		cooldown = cooldown,
		-- only true when Roblox will really serve an ad; the client hides the
		-- button on false rather than showing one that fails
		available = unlocked and adAvailable(player),
	}
end

-- Pay for one completed view. Called from ProcessReceipt via the registry, so
-- `claimId` carries the receipt's PurchaseId and the delta is idempotent.
local function grantReward(player: Player, claimId: string): boolean
	local ads = counters(player)
	local profile = DataService.getProfile(player)
	local bonusEligible = profile ~= nil and profile.ReferralBonus == true
	local bonusUsed = ads and ads.bonusUsed or 0
	local payout = AdConfig.rewardFor(bonusEligible, bonusUsed)

	local ok = InventoryService.applyDelta(player, { gems = payout }, Enums.GrantSource.Purchase, claimId)
	if not ok then
		return false
	end
	if ads then
		ads.count += 1
		ads.lastAt = os.time()
		-- only burn a bonus watch when the bonus actually paid extra
		if payout > AdConfig.RewardGems then
			ads.bonusUsed = bonusUsed + 1
		end
	end
	task.spawn(function()
		DataService.saveNow(player)
	end)
	AnalyticsService.log("ad_reward", { userId = player.UserId, gems = payout, bonus = payout > AdConfig.RewardGems, claimId = claimId })
	return true
end

function AdRewardService.Init()
	-- the payout rides the shop's single ProcessReceipt handler
	ProductService.registerDevProduct(AdConfig.RewardProductId, "ad_reward", grantReward)
end

function AdRewardService.Start()
	Net.bindFunction("GetFreeGems", function(player)
		return AdRewardService.snapshot(player)
	end)

	-- DEBUG ONLY — remove this bindFunction for release, alongside the button
	-- that calls it and DebugConfig.ForceGoalMetEnabled.
	Net.bindFunction("DebugForceGoal", function(player)
		if not DebugConfig.ForceGoalMetEnabled then
			return { ok = false, err = "disabled" }
		end
		local forced = not debugForcedGoal[player.UserId]
		debugForcedGoal[player.UserId] = forced or nil
		return { ok = true, forced = forced }
	end)

	Players.PlayerRemoving:Connect(function(player)
		debugForcedGoal[player.UserId] = nil
	end)

	Net.bindFunction("WatchAd", function(player)
		local snap = AdRewardService.snapshot(player)
		-- re-check every gate server-side; the client's copy is only for display
		if not snap.unlocked then
			return { ok = false, err = "locked" }
		end
		if snap.remaining <= 0 then
			return { ok = false, err = "daily_cap" }
		end
		if snap.cooldown > 0 then
			return { ok = false, err = "cooldown" }
		end
		if not snap.available then
			return { ok = false, err = "no_ad" }
		end

		local reward
		local built = pcall(function()
			reward = adService:CreateAdRewardFromDevProductId(AdConfig.RewardProductId)
		end)
		if not built or reward == nil then
			return { ok = false, err = "no_ad" }
		end

		local shown, result = pcall(function()
			return adService:ShowRewardedVideoAdAsync(player, reward, "free_gems")
		end)
		if not shown then
			return { ok = false, err = "ad_failed" }
		end
		-- Roblox reports how the view ended. Only a completed view pays, and the
		-- payment itself arrives through ProcessReceipt — we never grant here.
		-- The result enum has been renamed across engine versions, so compare by
		-- name rather than naming an enum member that may not exist.
		if result ~= nil and tostring(result):find("Success") then
			AnalyticsService.log("ad_watched", { userId = player.UserId })
			return { ok = true }
		end
		AnalyticsService.log("ad_incomplete", { userId = player.UserId, result = tostring(result) })
		return { ok = false, err = "not_completed" }
	end)
end

return AdRewardService
