--!strict
-- LiquidityConfig: dials for the liquidity facilitator (chain-trade bot).
--
-- The bot never holds items and never creates gems — every operation is a
-- chain trade settled atomically across all participants. These levels only
-- control HOW HARD it looks, never whether it may hold stock (it can't).
--
-- Levels are admin-set for now via the debug button. Auto-escalation from
-- churn metrics is deliberately deferred.
--
-- Order matters: the debug button cycles Levels in this order.

local LiquidityConfig = {
	-- Ordered cycle for the debug button. "OFF" is a real level, not a nil.
	Levels = { "OFF", "LOW", "MEDIUM", "HIGH" },

	-- Per-level dials, fed straight into LiquidityCore.solve. OFF has no
	-- entry on purpose: there is nothing to solve.
	Dials = {
		LOW = {
			maxParticipants = 4, -- listings per chain trade
			impliedEnabled = false, -- swap<->gem bridging (LiquidityCore.findImplied)
			maxOps = 1, -- chain trades executed per tick
			maxSeeds = 40,
			tickSeconds = 8,
		},
		MEDIUM = {
			maxParticipants = 10,
			impliedEnabled = true,
			maxOps = 3,
			maxSeeds = 80,
			tickSeconds = 4,
		},
		HIGH = {
			maxParticipants = 16,
			impliedEnabled = true,
			maxOps = 6,
			maxSeeds = 150,
			tickSeconds = 2,
		},
	},

	-- Master kill switch. Flip false to make the debug button inert without
	-- removing it.
	Enabled = true,

	-- DRY RUN: find and log chain trades, execute nothing. Stays true until the
	-- found chains have been inspected and look sane on a populated board.
	DryRun = true,

	-- Legs handed to the solver per pass, oldest listings first. Bounds the
	-- pass cost (seeding is roughly legs x participants x legs) and matches the
	-- priority anyway: the longest-waiting listings are the ones worth rescuing.
	MaxLegs = 400,

	-- Detail-log at most this many found chains per pass, and roll the summary
	-- up every N passes. A pass can find dozens; the console buffer evicts
	-- high-volume lines, so counters are also mirrored onto ReplicatedStorage.
	DetailLogPerPass = 2,
	SummaryEveryPasses = 5,
}

return LiquidityConfig
