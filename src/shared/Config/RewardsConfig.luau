--!strict
-- Community Rewards: once a player's gem balance reaches the threshold they can
-- request a Robux conversion. The HUD bar shows how close they are.
--
-- Shared so the client computes the bar from its live gem balance with no round
-- trip; the server only supplies the context (playtime) that rate modifiers read.

local RewardsConfig = {
	Threshold = 100_000, -- gems needed before a conversion can be requested
	BaseGemsPerRobux = 100, -- gems per 1 Robux paid out, before modifiers

	-- The bar does NOT show gems / threshold raw -- it shows a 10% head start
	-- (a small, honest endowed-progress nudge, not a lie) plus real progress
	-- scaled to fill the rest. Near-linear on purpose: the old curve claimed
	-- 30% shown for 1% real progress, which reads as a lie the moment a
	-- player does the math. displayFraction is driven by PEAK portfolio worth
	-- ever reached (server-persisted, see RewardsService), not current worth --
	-- a dip (a bad trade, a burned item) never drains the bar; it just pauses
	-- until worth climbs back past the old peak.
	-- 0% until the tutorial craft is done, then a 7% earned head start.
	-- Rest of the bar: each 10% band of real progress moves the bar by a
	-- weight that eases down (fast early, slower late, never stalling).
	-- Weights are normalised so the bar lands exactly on 100% at threshold.
	TutorialHeadStart = 0.07,
	BandWeights = { 1.7, 1.5, 1.3, 1.2, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5 },
	NotEligibleCap = 0.99,

	-- Conversion-rate bonuses. Each active modifier multiplies BaseGemsPerRobux
	-- (below 1 = fewer gems per Robux = better rate); they stack multiplicatively
	-- and are floored at MinGemsPerRobux. Conditions are plain data so a status
	-- table built from them can cross a remote. None ship yet, e.g.:
	--   { id = "playtime_10h", label = "10 hours played", minPlaySeconds = 36_000, rateMultiplier = 0.95 },
	RateModifiers = {} :: { any },
	MinGemsPerRobux = 50,
}

-- Fraction of the bar to paint for PEAK worth ever reached (never the raw
-- current gems -- see RewardsService for the ratchet). 10% head start, then
-- linear: honest, no claim that 1% of the grind is 30% of the bar.
function RewardsConfig.displayFraction(peakWorth: number, tutorialDone: boolean?): number
	if peakWorth >= RewardsConfig.Threshold then
		return 1
	end
	local real = math.clamp(peakWorth / RewardsConfig.Threshold, 0, 1)
	local head = tutorialDone and RewardsConfig.TutorialHeadStart or 0
	local weights = RewardsConfig.BandWeights
	local n = #weights
	local total = 0
	for _, w in weights do
		total += w
	end
	local shown = head
	local pos = real * n
	for i = 1, n do
		local part = math.clamp(pos - (i - 1), 0, 1)
		if part <= 0 then
			break
		end
		shown += part * weights[i] / total * (1 - head)
	end
	return math.min(shown, RewardsConfig.NotEligibleCap)
end

local function modifierApplies(modifier: any, context: any): boolean
	if modifier.minPlaySeconds and (context.playSeconds or 0) < modifier.minPlaySeconds then
		return false
	end
	return true
end

function RewardsConfig.activeModifiers(context: any): { any }
	local out = {}
	for _, modifier in RewardsConfig.RateModifiers do
		if modifierApplies(modifier, context) then
			table.insert(out, modifier)
		end
	end
	return out
end

function RewardsConfig.gemsPerRobux(context: any): number
	local rate = RewardsConfig.BaseGemsPerRobux
	for _, modifier in RewardsConfig.activeModifiers(context) do
		rate *= modifier.rateMultiplier or 1
	end
	return math.max(RewardsConfig.MinGemsPerRobux, rate)
end

-- `gems` gates real eligibility (the actual convertible balance); `peakWorth`
-- (gems + item value, ratcheted, never current-only) drives the bar so a
-- dip in item value can't drain progress the player already earned.
function RewardsConfig.status(gems: number, peakWorth: number, context: any): any
	local threshold = RewardsConfig.Threshold
	local rate = RewardsConfig.gemsPerRobux(context)
	local modifiers = {}
	for _, modifier in RewardsConfig.activeModifiers(context) do
		table.insert(modifiers, { id = modifier.id, label = modifier.label, rateMultiplier = modifier.rateMultiplier })
	end
	return {
		gems = gems,
		threshold = threshold,
		remaining = math.max(0, threshold - gems),
		fraction = math.clamp(gems / threshold, 0, 1),
		displayFraction = RewardsConfig.displayFraction(peakWorth, context.tutorialDone),
		eligible = gems >= threshold,
		baseGemsPerRobux = RewardsConfig.BaseGemsPerRobux,
		gemsPerRobux = rate,
		robuxNow = math.floor(gems / rate),
		robuxAtThreshold = math.floor(threshold / rate),
		playSeconds = context.playSeconds or 0,
		tutorialDone = context.tutorialDone == true,
		peakWorth = peakWorth,
		modifiers = modifiers,
	}
end

return RewardsConfig
