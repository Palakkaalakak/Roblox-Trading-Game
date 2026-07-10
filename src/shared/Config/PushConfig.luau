--!strict
-- Push notifications (Roblox's real OS/app push, via the Open Cloud
-- Notifications API) for players who are fully offline. Requires manual
-- one-time setup outside this codebase — see the two fields below.

local PushConfig = {
	-- Flip on once both setup steps are done. Stays off by default so a
	-- fresh install doesn't fire HTTP requests against an unconfigured key.
	Enabled = false,

	-- 1. Creator Dashboard > your experience > Engagement APIs > Notifications
	--    -> create a message template, paste its id here.
	MessageId = "",

	-- 2. Game Settings > Security > Secrets -> add a secret holding an Open
	--    Cloud API key scoped to this universe's Notifications API, name it
	--    to match here (HttpService:GetSecret reads it; the key never
	--    appears in source or in Output).
	SecretName = "OpenCloudApiKey",
}

return PushConfig
