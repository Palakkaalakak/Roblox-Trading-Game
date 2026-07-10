--!strict
-- Push notifications (Roblox's real OS/app push, via the Open Cloud
-- Notifications API) for players who are fully offline. Requires manual
-- one-time setup outside this codebase — see the two fields below.

local PushConfig = {
	-- Flip on once both setup steps are done. Stays off by default so a
	-- fresh install doesn't fire HTTP requests against an unconfigured key.
	Enabled = false,

	-- 1. dashboard.roblox.com (Creator Dashboard) > pick this game > left
	--    column "Engagement" > Notifications > "Create a Notification String".
	--    The string MUST contain the literal placeholder {message} somewhere,
	--    e.g. "{message}" or "Trade board: {message}" — the game's title is
	--    used as the notification title automatically. Paste the string's
	--    asset id here (max 99 chars in the template itself).
	MessageId = "",

	-- 2. Game Settings > Security > Secrets -> add a secret holding an Open
	--    Cloud API key (scoped to this universe, "Notifications" permission),
	--    name it to match here. HttpService:GetSecret reads it server-side;
	--    the raw value never appears in source or in Output.
	SecretName = "OpenCloudApiKey",

	-- Roblox throttles to 1 notification per user per day per experience,
	-- non-negotiable on their end — not something to tune here.
}

return PushConfig
