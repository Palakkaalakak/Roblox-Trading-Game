--!strict
-- AdConfig: the Free Gems screen — rewarded video ads, framed as a community goal.
--
-- WHY A COMMUNITY GOAL: Roblox only serves rewarded video to games that are
-- public, made by a 13+ ID-verified creator, and past 2,000 monthly visitors.
-- That's a hard gate we can't code around, so instead of hiding a broken button
-- we show the requirement as a shared target everyone is contributing to just by
-- playing. When the game qualifies the goal view disappears for good and the
-- panel becomes the watch-an-ad screen.
--
-- The reward is granted through ProcessReceipt like every other purchase (see
-- ProductService's receipt registry), so it is idempotent for free — a replayed
-- receipt can never pay twice.

local AdConfig = {
	-- Unique players who must have ever joined before free gems unlock. This
	-- mirrors Roblox's own 2,000-monthly-visitor eligibility bar.
	CommunityGoalTarget = 2000,

	-- Gems paid per completed ad view.
	RewardGems = 50,

	-- Most ads a player may be paid for per day. Resets on the UTC day, so it
	-- needs no scheduler — the stored day stamp simply stops matching.
	DailyCap = 5,

	-- Minimum seconds between two paid views, so the cap can't be burned in one
	-- rapid-fire burst.
	CooldownSeconds = 120,

	-- The dev product the ad reward is attached to. Roblox mints the reward from
	-- a dev product id via CreateAdRewardFromDevProductId; the player is never
	-- charged for it. 0 = not created yet, which makes the screen report itself
	-- as unavailable rather than erroring.
	RewardProductId = 0,

	-- ── Referrals ────────────────────────────────────────────────────────
	-- Invite friends and the goal arrives sooner for everybody. Land this many
	-- joins and the inviter AND everyone they brought get a bonus on their
	-- first watches once the goal is met.
	ReferralsNeeded = 3,
	ReferralBonusPercent = 20,
	ReferralBonusWatches = 15,
}

-- Gems paid for one watch. The referral bonus applies only to the first
-- ReferralBonusWatches views, so it's a real head start rather than a
-- permanent multiplier. Pure — the server pays exactly what this returns.
function AdConfig.rewardFor(bonusEligible: boolean, bonusUsed: number): number
	if not bonusEligible or bonusUsed >= AdConfig.ReferralBonusWatches then
		return AdConfig.RewardGems
	end
	return math.floor(AdConfig.RewardGems * (1 + AdConfig.ReferralBonusPercent / 100))
end

-- Has this player brought enough friends to earn the bonus?
function AdConfig.referralBonusEarned(referrals: number): boolean
	return referrals >= AdConfig.ReferralsNeeded
end

-- Has the community unlocked free gems? Pure, so the goal bar and the server
-- gate can't disagree about where the line is.
function AdConfig.goalMet(uniquePlayers: number): boolean
	return uniquePlayers >= AdConfig.CommunityGoalTarget
end

-- Fraction of the way to the goal, clamped to 0..1 for the progress bar.
function AdConfig.goalProgress(uniquePlayers: number): number
	if AdConfig.CommunityGoalTarget <= 0 then
		return 1
	end
	return math.clamp(uniquePlayers / AdConfig.CommunityGoalTarget, 0, 1)
end

return AdConfig
