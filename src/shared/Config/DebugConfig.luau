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

	-- "Force Goal" button on the Free Gems panel: pretends the community goal
	-- is already met so the unlocked (watch-ad) view can be eyeballed without
	-- 2,000 real players. Remove this flag + the button wiring for release.
	ForceGoalMetEnabled = true,
}

return DebugConfig
