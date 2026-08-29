--!strict
-- AFK zones: stand on a pad, stop playing, still earn.
--
-- A zone is a green pad in the workspace named AfkZone_1, AfkZone_2, ... Each
-- holds up to Capacity players; when one fills the next takes the overflow, so
-- adding a zone is a build-time act with no code change.
--
-- The reward LADDER is the whole point: leaving early is the mistake. Each
-- payout is bigger than the last, so a player who sits through eight ticks has
-- earned far more than eight players who each sat through one. It caps so an
-- overnight session cannot print an unbounded amount.

local AfkConfig = {
	Enabled = true,

	-- Pads are found by name prefix so the builder can clone as many as they
	-- like without touching config. AfkZone_1, AfkZone_2, ...
	ZoneNamePrefix = "AfkZone_",
	-- Tagged too, so a pad parked anywhere in the workspace is still found.
	Tag = "AfkZone",

	Capacity = 6, -- players per zone before the next one takes the overflow

	-- One payout every ten minutes. The first tick is deliberately a full
	-- interval away: AFK income should never beat simply playing for ten
	-- minutes, it should only beat leaving the game.
	TickSeconds = 600,

	-- REWARD LADDER -- deliberately not decided yet.
	--
	-- A rung is a grant spec: { kind = ..., ... }. The service looks the kind up
	-- in its granter registry, so choosing what AFK actually pays is a config
	-- edit, not a code change. Supported kinds:
	--
	--   { kind = "items", items = { itm_x = 1 } }   -- straight into inventory
	--   { kind = "boost", sku = "ad_boost_server_1h" } -- banks a trade-ad credit
	--   { kind = "gems",  amount = 50 }             -- mints currency; inflates
	--   { kind = "rolls", count = 1 }               -- NOT WIRED: needs a roll
	--                                                  credit on the profile
	--   { kind = "tbd" }                            -- pays nothing, says so
	--
	-- Everything below is "tbd" on purpose: the ladder shape is real (each rung
	-- is meant to beat the last), the payload is not chosen. Swap the specs and
	-- the whole feature starts paying with no other edit.
	Rewards = {
		{ kind = "tbd" },
		{ kind = "tbd" },
		{ kind = "tbd" },
		{ kind = "tbd" },
		{ kind = "tbd" },
		{ kind = "tbd" },
		{ kind = "tbd" },
		{ kind = "tbd" },
	},

	-- Standing back up loses the ladder. Without this a player could hop out
	-- and back in to farm the top rung forever.
	ResetLadderOnLeave = true,

	-- STAYING CONNECTED.
	--
	-- Roblox's idle kick watches for INPUT -- mouse, keyboard, touch, gamepad --
	-- and nothing else. Sitting on a pad earning rewards counts for nothing, and
	-- there is no API to switch the kick off. Player.Idled is the only signal we
	-- get: it fires two minutes after the client goes quiet, then every thirty
	-- seconds, until the disconnect at roughly twenty.
	--
	-- Two things were tried and rejected before this one:
	--   * VirtualUser synthesising a click -- undocumented, marked Not
	--     Replicated, historically scoped to Roblox's own testing. Not
	--     something to hang a monetised feature on.
	--   * TeleportAsync back into "the same place" -- without a reserved
	--     server this lands on a DIFFERENT server instance, which resets the
	--     session-length clock Roblox uses for discovery/rating. Fixing the
	--     kick by quietly damaging the game's own numbers is not a fix.
	--
	-- So there is no automatic save here. Idled fires, the client tells the
	-- player to press the on-screen button themselves, and pressing it is
	-- real input -- the same thing Roblox already accepts from a mouse click
	-- anywhere else on screen. Honest: the player knows they have to act, and
	-- nothing about the game's own metrics is touched to make that happen.
	NudgeOnIdle = true,
	-- Roblox re-fires Idled every 30s once a client goes quiet; reminding on
	-- every one of those would be a toast twice a minute. Space real reminders
	-- out to this, comfortably inside the ~20 minute kick.
	IdleNudgeSeconds = 600,

	-- A pad the player is not actually standing on is not an AFK session. The
	-- server re-checks this every tick and drops anyone who has wandered off,
	-- which is what stops a spoofed "I am AFK" from paying out.
	MaxDistanceFromPad = 18,
}

-- The grant spec for the Nth completed tick (1-based). Clamps to the last rung,
-- so an overnight session repeats the top rung rather than growing forever.
function AfkConfig.rewardFor(tickIndex: number): any
	local n = math.max(1, math.floor(tickIndex))
	local rewards = AfkConfig.Rewards
	return rewards[math.min(n, #rewards)]
end

-- What the next tick pays, for the UI to promise before it lands.
function AfkConfig.nextReward(ticksDone: number): any
	return AfkConfig.rewardFor(ticksDone + 1)
end

-- One line a player can read. Kept here so the server and the panel cannot
-- describe the same rung differently.
function AfkConfig.describe(spec: any): string
	if type(spec) ~= "table" then
		return "Reward not set yet"
	end
	if spec.kind == "gems" then
		return ("+%d gems"):format(spec.amount or 0)
	elseif spec.kind == "rolls" then
		return ("+%d free roll%s"):format(spec.count or 1, (spec.count or 1) == 1 and "" or "s")
	elseif spec.kind == "boost" then
		return "+1 trade ad boost"
	elseif spec.kind == "items" then
		local n = 0
		for _, count in spec.items or {} do
			n += count
		end
		return ("+%d item%s"):format(n, n == 1 and "" or "s")
	end
	return "Reward not set yet"
end

return AfkConfig
