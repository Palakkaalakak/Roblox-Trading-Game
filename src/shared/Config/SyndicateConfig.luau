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
	Roles = { "Owner", "Officer", "Member" },

	-- What each role may do. Checked server-side on every action.
	Permissions = {
		Owner = { invite = true, kick = true, promote = true, demote = true, disband = true, setPolicy = true },
		Officer = { invite = true, kick = true, promote = false, demote = false, disband = false, setPolicy = false },
		Member = { invite = false, kick = false, promote = false, demote = false, disband = false, setPolicy = false },
	},

	-- How a syndicate accepts new members. The ids are internal; JoinPolicyLabel
	-- is what a player actually reads — "Policy: Request" means nothing to a
	-- 12-year-old, "Anyone can join" does.
	JoinPolicies = { "Open", "Request", "Invite" },
	JoinPolicyLabels = {
		Open = "Anyone can join",
		Request = "Ask to join",
		Invite = "Invite only",
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
function SyndicateConfig.can(actorRole: string, action: string): boolean
	local perms = SyndicateConfig.Permissions[actorRole]
	return perms ~= nil and perms[action] == true
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

return SyndicateConfig
