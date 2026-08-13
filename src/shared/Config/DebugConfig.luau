--!strict
-- Debug-only switches. EVERYTHING here is slated for removal before release.

local DebugConfig = {
	-- "+100 gems" HUD button + its remote. Remove for final product.
	GiveGemsEnabled = true,
	GiveGemsAmount = 100,

	-- Admin-only tooling (temporary): the bot inspector panel + its remote are
	-- gated to these userIds. Empty => nobody. Remove with the panel for release.
	AdminUserIds = {
		[2397876414] = true, -- ingap (owner)
	},

	-- Batch roll on the Lucky Rolls panel: roll N times at one chosen rarity,
	-- free. For filling a test inventory without clicking the gacha N times.
	-- The strip only appears for AdminUserNames; the remote behind it is gated
	-- server-side on AdminUserIds, because a client can't be trusted about who
	-- it is. Remove both with the rest of the dev tooling for release.
	BatchRollEnabled = true,
	BatchRollMaxCount = 100,
	AdminUserNames = {
		Palakkaalakak = true,
	},

	-- "Force Goal" button on the Free Gems panel: pretends the community goal
	-- is already met so the unlocked (watch-ad) view can be eyeballed without
	-- 2,000 real players. Remove this flag + the button wiring for release.
	ForceGoalMetEnabled = true,
}

return DebugConfig
