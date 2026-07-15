--!strict
-- RollConfig: the gacha. Spend gems, get one item — the main REASONED way new
-- goods enter the world.
--
-- WHY THIS EXISTS: items must not just appear on a timer. Something has to be
-- given up for them. A roll costs gems, so every new item in the economy was
-- paid for by someone who earned those gems by selling something another trader
-- actually wanted. That's a reason.
--
-- LUCK: pay more, roll better. Each tier's `luck` flattens the draw curve:
--     weight_i = assignmentWeight_i ^ (1 / luck)
-- assignmentWeight is ~totalSupply^0.75, so at luck = 1 the Commons dominate
-- exactly like a starter draw. Raising luck compresses those weights toward
-- each other, so the scarce items climb from "basically never" to "a real
-- chance" — without ever guaranteeing anything.
--
-- HARD RULE: a roll can only ever produce an item with reserve left. Once the
-- last copy of something is distributed it can NEVER be rolled again — it only
-- exists in players' hands from then on, which is what makes a sold-out limited
-- actually limited.
--
-- Tiers are ordered cheapest-first. A bot/player rolls the best tier it can
-- afford and justify.

local RollConfig = {
	Enabled = true,

	Tiers = {
		{
			id = "basic",
			name = "Basic Roll",
			gems = 12,
			luck = 1, -- raw supply weighting: you're getting a Common
			blurb = "A cheap pull. Mostly junk, occasionally not.",
		},
		{
			id = "lucky",
			name = "Lucky Roll",
			gems = 55,
			luck = 4, -- flattens the curve hard: rares become genuinely likely
			blurb = "Better odds on the good stuff.",
		},
		{
			id = "mythic",
			name = "Mythic Roll",
			gems = 240,
			luck = 12, -- near-flat: this is how a grail actually gets pulled
			blurb = "Expensive. Worth it, if the Void is listening.",
		},
	},
}

return RollConfig
