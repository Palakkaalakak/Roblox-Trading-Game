--!strict
-- SyndicateConfig: trading clans. Everything tunable lives here — the XP curve,
-- how many members a level holds, and which perks unlock when.
--
-- WHY XP COMES FROM WHAT PLAYERS ALREADY DO: a syndicate levels up from trades
-- settling, board orders filling and crafts completing. There is no separate
-- grind, so joining one never asks a member to play differently — it just makes
-- what they already do count for something shared.
--
-- PERKS PLUG INTO EXISTING SYSTEMS rather than adding new ones: more board
-- listing slots, a cut of the market fee, a small roll-luck bonus. Each is read
-- by the service that already owns that number, so a perk is a lookup, not a
-- new code path.

local SyndicateConfig = {
	-- Creation + identity
	NameMinLength = 3,
	NameMaxLength = 24,
	TagMinLength = 2,
	TagMaxLength = 5, -- shows next to a player's name, so it must stay short
	CreateCostGems = 500,

	-- Roles, most privileged first. Index is the rank: lower index outranks.
	-- Four tiers rather than three, so there is a rung between "just joined"
	-- and "can kick people" — the same shape Clash of Clans uses, and the
	-- reason promotion feels like progress rather than a single on/off switch.
	Roles = { "Owner", "Officer", "Veteran", "Member" },
	RoleLabels = {
		Owner = "Owner",
		Officer = "Officer",
		Veteran = "Veteran",
		Member = "Member",
	},

	-- DEFAULT permissions per role. The owner can override these per group
	-- (see SyndicateService.setPermission), which is why they are read through
	-- SyndicateConfig.can(role, action, overrides) rather than looked up direct.
	Permissions = {
		Owner = { invite = true, kick = true, promote = true, demote = true, disband = true, setPolicy = true, request = true, recruit = true },
		Officer = { invite = true, kick = true, promote = false, demote = false, disband = false, setPolicy = false, request = true, recruit = true },
		Veteran = { invite = true, kick = false, promote = false, demote = false, disband = false, setPolicy = false, request = true, recruit = true },
		Member = { invite = false, kick = false, promote = false, demote = false, disband = false, setPolicy = false, request = true, recruit = false },
	},

	-- Which permissions the owner may hand out, and how each reads to a player.
	-- Only these are editable: disband/promote/demote stay owner-only, because a
	-- group that can vote its owner out is a griefing tool, not a feature.
	EditablePermissions = {
		{ key = "invite", label = "Invite players to the group" },
		{ key = "recruit", label = "Recruit friends from outside the game" },
		{ key = "kick", label = "Remove members" },
		{ key = "request", label = "Ask the group for items" },
		{ key = "setPolicy", label = "Change who can join" },
	},

	-- Roles the owner can configure. The Owner row is never editable.
	ConfigurableRoles = { "Officer", "Veteran", "Member" },

	-- How a syndicate accepts new members. The ids are internal; JoinPolicyLabel
	-- is what a player actually reads — "Policy: Request" means nothing to a
	-- 12-year-old, "Anyone can join" does.
	JoinPolicies = { "Request", "Open", "Invite" },
	JoinPolicyLabels = {
		Request = "Ask to join",
		Open = "Anyone can join",
		Invite = "Invite-only",
	},

	-- ── REQUESTS (the reciprocity loop) ──────────────────────────────────
	-- Modelled on Clash of Clans troop donations, which are the single
	-- strongest retention mechanic in that game: a clanmate gives you
	-- something OUT OF THEIR OWN POCKET, which creates a real debt and a
	-- reason to come back and repay it. Ours uses items, which is what this
	-- game is already about — and it feeds the crafting ladder directly, since
	-- a capstone needs hundreds of commons nobody farms alone.
	MaxOpenRequestsPerMember = 2, -- stops one member flooding the board
	MaxRequestCount = 500, -- ceiling on a single ask
	RequestTtlSeconds = 24 * 3600,
	MaxRequestsShown = 40,

	-- Filling someone's request is worth more XP than a trade: it is the
	-- behaviour the whole system exists to encourage.
	DonationXp = 12,

	-- XP awarded for things members already do. Deliberately small and additive:
	-- a syndicate levels through sustained activity by several people, not one
	-- whale doing something enormous once.
	XpSources = {
		trade = 10, -- a trade settles (both sides earn it)
		boardFill = 6, -- a sell/bulk order fills
		craft = 15, -- a craft completes (the value engine, so it pays most)
	},

	-- ── GOALS ────────────────────────────────────────────────────────────
	-- XP on its own is a number that goes up. Goals are what give it somewhere
	-- to GO: concrete targets the whole group contributes to, each one visibly
	-- feeding the level that unlocks the perks below.
	--
	-- Deliberately built from the tallies the group ALREADY keeps (record.stats
	-- and record.xp), so a goal costs no new tracking and can never disagree
	-- with what the group screen shows. Each completed goal pays XP once.
	Goals = {
		{ id = "first_trades", stat = "trade", target = 25, xp = 400,
			name = "Open for business", blurb = "Settle 25 trades between your members." },
		{ id = "first_crafts", stat = "craft", target = 15, xp = 500,
			name = "Fire up the forge", blurb = "Complete 15 crafts as a group." },
		{ id = "generous", stat = "donation", target = 20, xp = 600,
			name = "Look after each other", blurb = "Fill 20 item requests for your own members." },
		{ id = "market_makers", stat = "boardFill", target = 50, xp = 800,
			name = "Market makers", blurb = "Fill 50 orders on the trade board." },
		{ id = "veteran_traders", stat = "trade", target = 250, xp = 2500,
			name = "Veteran traders", blurb = "Settle 250 trades between your members." },
		{ id = "master_forge", stat = "craft", target = 200, xp = 4000,
			name = "Master forge", blurb = "Complete 200 crafts as a group." },
	},

	-- Cumulative XP needed to REACH each level. Index = level; level 1 is free.
	-- Gaps widen so early levels feel quick and later ones are a real project.
	LevelCurve = { 0, 500, 1500, 3500, 7000, 12000, 20000, 32000, 50000, 75000 },

	-- Member cap by level, so growth is itself a reward.
	MemberCapByLevel = { 10, 15, 20, 25, 30, 40, 50, 60, 75, 100 },

	-- Perks unlocked AT each level, cumulative — a level-5 syndicate has every
	-- perk listed at 5 and below.
	--   boardSlots     extra trade-board listing slots per member
	--   marketFeeCut   fraction off the house gem tax on settlements
	--   rollLuck       additive luck bonus on gacha pulls
	Perks = {
		[2] = { boardSlots = 1 },
		[3] = { marketFeeCut = 0.05 },
		[4] = { rollLuck = 0.02 },
		[5] = { boardSlots = 2 },
		[6] = { marketFeeCut = 0.10 },
		[7] = { rollLuck = 0.05 },
		[8] = { boardSlots = 3 },
		[9] = { marketFeeCut = 0.15 },
		[10] = { rollLuck = 0.08 },
	},
}

-- Level for a given total XP. Always at least 1, capped at the curve's length.
function SyndicateConfig.levelFor(xp: number): number
	local level = 1
	for i, needed in SyndicateConfig.LevelCurve do
		if xp >= needed then
			level = i
		else
			break
		end
	end
	return level
end

-- XP still needed to reach the next level, and what that next level is.
-- Returns (nil, nil) at max level so callers can render "MAX" rather than a
-- meaningless countdown.
function SyndicateConfig.nextLevel(xp: number): (number?, number?)
	local level = SyndicateConfig.levelFor(xp)
	local nextLvl = level + 1
	local needed = SyndicateConfig.LevelCurve[nextLvl]
	if needed == nil then
		return nil, nil
	end
	return nextLvl, needed - xp
end

-- Member cap at a level (clamped to the table's ends).
function SyndicateConfig.memberCap(level: number): number
	local caps = SyndicateConfig.MemberCapByLevel
	return caps[math.clamp(level, 1, #caps)] or caps[1]
end

-- Every perk active at a level, accumulated from level 1 upward. Later levels
-- REPLACE an earlier value for the same key rather than stacking, so the table
-- reads as "what you have now", not "what to add up".
function SyndicateConfig.perksFor(level: number): { [string]: number }
	local out: { [string]: number } = { boardSlots = 0, marketFeeCut = 0, rollLuck = 0 }
	for lvl = 1, level do
		local perks = SyndicateConfig.Perks[lvl]
		if perks then
			for key, value in perks do
				out[key] = value
			end
		end
	end
	return out
end

-- Can `actorRole` perform `action`? Unknown roles and actions are denied.
--
-- `overrides` is the group's own permission table (role -> action -> bool),
-- set by its owner. Anything it doesn't mention falls through to the defaults,
-- so a group created before a new permission existed still behaves sensibly.
function SyndicateConfig.can(actorRole: string, action: string, overrides: any?): boolean
	if overrides and overrides[actorRole] ~= nil then
		local value = overrides[actorRole][action]
		if value ~= nil then
			return value == true
		end
	end
	local perms = SyndicateConfig.Permissions[actorRole]
	return perms ~= nil and perms[action] == true
end

-- Is this permission one the owner is allowed to hand out at all?
function SyndicateConfig.isEditablePermission(action: string): boolean
	for _, entry in SyndicateConfig.EditablePermissions do
		if entry.key == action then
			return true
		end
	end
	return false
end

function SyndicateConfig.isConfigurableRole(role: string): boolean
	for _, r in SyndicateConfig.ConfigurableRoles do
		if r == role then
			return true
		end
	end
	return false
end

-- Every role `actorRole` may move someone to: strictly below the actor, and
-- never Owner (transferring ownership is its own deliberate action).
function SyndicateConfig.assignableRoles(actorRole: string): { string }
	local out = {}
	local actorRank = nil
	for i, role in SyndicateConfig.Roles do
		if role == actorRole then
			actorRank = i
		end
	end
	if actorRank == nil then
		return out
	end
	for i, role in SyndicateConfig.Roles do
		if i > actorRank then
			table.insert(out, role)
		end
	end
	return out
end

-- Does `actorRole` outrank `targetRole`? Used for kick/promote: you may only
-- act on someone below you, which is what stops an Officer kicking the Owner.
function SyndicateConfig.outranks(actorRole: string, targetRole: string): boolean
	local a, b = nil, nil
	for i, role in SyndicateConfig.Roles do
		if role == actorRole then
			a = i
		end
		if role == targetRole then
			b = i
		end
	end
	return a ~= nil and b ~= nil and a < b
end


-- Goal progress for a record's stats: how far along each goal is, whether it
-- is done, and what it pays. Pure, so the client renders exactly what the
-- server awards.
function SyndicateConfig.goalProgress(stats: any, claimed: any): { any }
	stats = stats or {}
	claimed = claimed or {}
	local out = {}
	for _, goal in SyndicateConfig.Goals do
		local have = stats[goal.stat] or 0
		table.insert(out, {
			id = goal.id,
			name = goal.name,
			blurb = goal.blurb,
			have = math.min(have, goal.target),
			target = goal.target,
			xp = goal.xp,
			done = claimed[goal.id] == true,
			ready = have >= goal.target and claimed[goal.id] ~= true,
		})
	end
	return out
end

return SyndicateConfig
