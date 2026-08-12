--!strict
-- SyndicateService: trading clans — create, join, roles, XP and perks.
--
-- WHERE THE DATA LIVES. One DataStore record per syndicate holds the whole
-- roster; a player's profile stores only `SyndicateId`. That direction matters:
-- renaming a syndicate, promoting someone, or levelling up writes ONE key
-- instead of one per member, and a 100-member syndicate is still a single
-- UpdateAsync. The cost is that reading "who am I with" needs a second fetch,
-- which is cached per server.
--
-- EVERY MUTATION IS A CAS TRANSFORM on that one key, so two servers acting on
-- the same syndicate at once (two people accepting the last slot) can't both
-- win — the capacity check happens INSIDE the transform, not before it.
--
-- XP comes from things members already do (trades, board fills, crafts), so
-- being in a syndicate never asks anyone to play differently. Levels raise the
-- member cap and unlock perks that plug into systems that already exist.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SyndicateConfig = require(ReplicatedStorage.Shared.Config.SyndicateConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)
local Enums = require(ReplicatedStorage.Shared.Enums)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local EconomyService = require(script.Parent.EconomyService)
local NotificationService = require(script.Parent.NotificationService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local SyndicateService = {}

local store: any -- DataStore "Syndicates_v1": syndicateId -> record
local dirStore: any -- DataStore "SyndicateDir_v1": key "all" -> {id -> {name, tag, level, members}}
local cache: { [string]: { at: number, record: any } } = {}
local CACHE_TTL = 15
local SYNC_TOPIC = "syndicate_changed"

local ensureRoles -- fwd decl: readRecord migrates old records through it

local function now(): number
	return os.time()
end

-- Tell the OTHER servers their copy is stale. Deliberately does NOT drop this
-- server's entry: the caller has just written the authoritative record and
-- cached it, and clearing it here forced a full GetAsync round-trip on the very
-- next read — which is the read that renders the screen the player is looking
-- at right after pressing the button. The payload carries this server's JobId
-- so the subscriber can ignore its own echo for the same reason.
local function invalidate(syndicateId: string)
	StoreAdapters.publish(SYNC_TOPIC, { id = syndicateId, from = game.JobId })
end

local function readRecord(syndicateId: string, force: boolean?): any?
	local cached = cache[syndicateId]
	if not force and cached and (os.clock() - cached.at) < CACHE_TTL then
		return cached.record
	end
	local record
	pcall(function()
		record = store:GetAsync(syndicateId)
	end)
	if record then
		-- groups made before roles were editable carry no role table and
		-- store role NAMES on members; bring them forward on read so every
		-- caller sees one shape. The next mutate persists it.
		ensureRoles(record)
		cache[syndicateId] = { at = os.clock(), record = record }
	end
	return record
end

-- Every write goes through here: CAS on the one key, then invalidate every
-- server's cache. `transform` returns nil to abort (and may set `reason`).
local function mutate(syndicateId: string, transform: (any) -> any?): (any?, string?)
	local reason: string? = nil
	local committed
	local ok = pcall(function()
		committed = store:UpdateAsync(syndicateId, function(old)
			if old == nil then
				reason = "not_found"
				return nil
			end
			local result, why = transform(old)
			if result == nil then
				reason = why or reason or "rejected"
				return nil
			end
			result.updatedAt = now()
			return result
		end)
	end)
	if not ok then
		return nil, "store_error"
	end
	if committed == nil then
		return nil, reason or "rejected"
	end
	cache[syndicateId] = { at = os.clock(), record = committed }
	invalidate(syndicateId)
	return committed, nil
end

--------------------------------------------------------------------------------
-- Pure helpers (unit-testable)
--------------------------------------------------------------------------------

-- A member's role, or nil when they aren't in the syndicate.
function SyndicateService.roleOf(record: any, userId: number): string?
	local entry = record and record.members and record.members[tostring(userId)]
	return entry and entry.role or nil
end

function SyndicateService.memberCount(record: any): number
	local n = 0
	for _ in (record and record.members or {}) do
		n += 1
	end
	return n
end

-- Can `actorId` do `action` to `targetId`? Encodes the two rules that actually
-- matter: you need the permission, AND you may only act on someone you outrank
-- (which is what stops an Officer kicking the Owner, or demoting a peer).
function SyndicateService.mayActOn(record: any, actorId: number, targetId: number, action: string): (boolean, string?)
	local actorRole = SyndicateService.roleOf(record, actorId)
	if actorRole == nil then
		return false, "not_a_member"
	end
	if not SyndicateConfig.can(record, actorRole, action) then
		return false, "no_permission"
	end
	if targetId ~= 0 then
		local targetRole = SyndicateService.roleOf(record, targetId)
		if targetRole == nil then
			return false, "target_not_a_member"
		end
		if actorId == targetId then
			return false, "cannot_target_self"
		end
		if not SyndicateConfig.outranks(record, actorRole, targetRole) then
			return false, "target_outranks_you"
		end
	end
	return true, nil
end

-- Public view of a syndicate, safe to hand to any client.
local function describe(record: any, viewerId: number): any
	local level = SyndicateConfig.levelFor(record.xp or 0)
	local nextLvl, toNext = SyndicateConfig.nextLevel(record.xp or 0)
	local members = {}
	for key, entry in (record.members or {}) do
		local userId = tonumber(key) or 0
		table.insert(members, {
			userId = userId,
			name = DataService.nameFor(userId) or ("User " .. key),
			role = entry.role,
			joinedAt = entry.joinedAt,
			xpContributed = entry.xp or 0,
			donated = entry.donated or 0,
		})
	end
	local rankOf: { [string]: number } = {}
	for _, role in SyndicateConfig.rolesOf(record) do
		rankOf[role.id] = role.rank or 99
	end
	table.sort(members, function(a, b)
		local ra = rankOf[a.role] or 99
		local rb = rankOf[b.role] or 99
		if ra ~= rb then
			return ra < rb
		end
		return a.xpContributed > b.xpContributed
	end)
	return {
		id = record.id,
		name = record.name,
		tag = record.tag,
		policy = record.policy,
		xp = record.xp or 0,
		level = level,
		nextLevel = nextLvl,
		xpToNext = toNext,
		memberCap = SyndicateConfig.memberCap(level),
		perks = SyndicateConfig.perksFor(level),
		members = members,
		requests = SyndicateService.liveRequests(record, os.time()),
		roles = SyndicateConfig.rolesOf(record),
		goals = SyndicateConfig.goalProgress(record.stats, record.goalsClaimed),
		yourRole = SyndicateService.roleOf(record, viewerId),
	}
end

--------------------------------------------------------------------------------
-- Directory (browse/search) — a small summary row per syndicate
--------------------------------------------------------------------------------

-- The browse directory is a CONVENIENCE INDEX, not a source of truth: every
-- row in it is re-derived from the syndicate records themselves. So this must
-- never sit in the response path of a player's action — a directory write is a
-- ~0.5s UpdateAsync on a single globally-shared key, and having it inline made
-- founding a syndicate or flipping a join setting feel broken.
--
-- Writes are queued and flushed on a timer instead. Coalescing also fixes the
-- worse scaling problem: every syndicate in the game shares the "all" key, so
-- inline writes meant unrelated players' actions queued behind each other.
local dirtyDirectory: { [string]: any } = {}
local REMOVED = newproxy() -- sentinel: this id must be deleted, not written

local function updateDirectory(record: any)
	dirtyDirectory[record.id] = {
		name = record.name,
		tag = record.tag,
		level = SyndicateConfig.levelFor(record.xp or 0),
		members = SyndicateService.memberCount(record),
		policy = record.policy,
		xp = record.xp or 0,
		trades = (record.stats and record.stats.trade) or 0,
		crafts = (record.stats and record.stats.craft) or 0,
	}
end

local function flushDirectory()
	if next(dirtyDirectory) == nil then
		return
	end
	local pending = dirtyDirectory
	dirtyDirectory = {}
	local ok = pcall(function()
		dirStore:UpdateAsync("all", function(old)
			old = old or {}
			for id, row in pending do
				old[id] = (row ~= REMOVED) and row or nil
			end
			return old
		end)
	end)
	if not ok then
		-- put them back so the next tick retries, without clobbering anything
		-- that was queued while this attempt was in flight
		for id, row in pending do
			if dirtyDirectory[id] == nil then
				dirtyDirectory[id] = row
			end
		end
	end
end

-- Queued like updates, for the same reason: disbanding shouldn't make the
-- player wait on a write to a shared index. A removal always beats a queued
-- update for the same id, so a syndicate that dies in the same tick it changed
-- can't come back.
local function removeFromDirectory(syndicateId: string)
	dirtyDirectory[syndicateId] = REMOVED
end

--------------------------------------------------------------------------------
-- XP
--------------------------------------------------------------------------------

-- Award XP for something a member did. Fire-and-forget: a failed XP write must
-- never fail the trade/craft that earned it, so this is spawned and swallowed.
-- Pay out any goal the group has just finished. Runs inside its own CAS so two
-- servers crossing the same threshold at once can't both award it: the claim
-- flag and the XP move together, or neither does.
local function awardGoals(syndicateId: string)
	local record = readRecord(syndicateId)
	if record == nil then
		return
	end
	local pending = {}
	for _, goal in SyndicateConfig.goalProgress(record.stats, record.goalsClaimed) do
		if goal.ready then
			table.insert(pending, goal)
		end
	end
	if #pending == 0 then
		return
	end
	local committed = mutate(syndicateId, function(rec)
		rec.goalsClaimed = rec.goalsClaimed or {}
		local awarded = false
		for _, goal in SyndicateConfig.goalProgress(rec.stats, rec.goalsClaimed) do
			if goal.ready then
				rec.goalsClaimed[goal.id] = true
				rec.xp = (rec.xp or 0) + goal.xp
				awarded = true
			end
		end
		if not awarded then
			return nil, "nothing_ready"
		end
		return rec
	end)
	if committed then
		updateDirectory(committed)
		for memberKey in committed.members do
			local uid = tonumber(memberKey)
			if uid then
				for _, goal in pending do
					NotificationService.notify(uid,
						("Group goal complete: %s  (+%d XP)"):format(goal.name, goal.xp))
				end
			end
		end
	end
end

function SyndicateService.addXp(userId: number, source: string)
	local amount = SyndicateConfig.XpSources[source]
	if amount == nil or amount <= 0 then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	if player == nil or not DataService.isLoaded(player) then
		return
	end
	local profile = DataService.getProfile(player)
	local syndicateId = profile and profile.SyndicateId or ""
	if syndicateId == "" then
		return
	end
	task.spawn(function()
		local key = tostring(userId)
		local before = readRecord(syndicateId)
		local levelBefore = before and SyndicateConfig.levelFor(before.xp or 0) or 1
		local committed = mutate(syndicateId, function(record)
			if record.members[key] == nil then
				return nil, "not_a_member"
			end
			record.xp = (record.xp or 0) + amount
			record.members[key].xp = (record.members[key].xp or 0) + amount
			-- per-source tallies: cheap here (we're already inside the CAS) and
			-- they give the browse list real numbers to compare groups on
			record.stats = record.stats or {}
			record.stats[source] = (record.stats[source] or 0) + 1
			return record
		end)
		if committed then
			local levelAfter = SyndicateConfig.levelFor(committed.xp or 0)
			-- refresh the browse row on every XP gain, not just level-ups: the
			-- row now shows XP and activity counts, and the write is queued and
			-- coalesced so doing it often costs nothing
			updateDirectory(committed)
			if levelAfter > levelBefore then
				AnalyticsService.log("syndicate_levelup", {
					id = syndicateId, level = levelAfter, xp = committed.xp,
				})
			end
			-- every tallied stat changes here, so this is the one place a goal
			-- can newly become complete
			awardGoals(syndicateId)
		end
	end)
end

-- Perks currently active for a player, for the systems that consume them
-- (board slots, market fee, roll luck). Zeroed when they're in no syndicate,
-- so callers never branch on membership.
function SyndicateService.perksFor(userId: number): { [string]: number }
	local player = Players:GetPlayerByUserId(userId)
	if player == nil or not DataService.isLoaded(player) then
		return SyndicateConfig.perksFor(0)
	end
	local profile = DataService.getProfile(player)
	local syndicateId = profile and profile.SyndicateId or ""
	if syndicateId == "" then
		return SyndicateConfig.perksFor(0)
	end
	local record = readRecord(syndicateId)
	if record == nil then
		return SyndicateConfig.perksFor(0)
	end
	return SyndicateConfig.perksFor(SyndicateConfig.levelFor(record.xp or 0))
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local function profileOf(player: Player): any?
	return DataService.isLoaded(player) and DataService.getProfile(player) or nil
end

local function setMembership(player: Player, syndicateId: string)
	local profile = profileOf(player)
	if profile then
		profile.SyndicateId = syndicateId
		task.spawn(function()
			DataService.saveNow(player)
		end)
	end
end

local function newSyndicateId(): string
	return ("s_%d_%s"):format(now(), DataService.newId():sub(1, 8))
end

-- Name/tag rules, checked before anything is charged or written.
local function validateIdentity(name: any, tag: any): (boolean, string?)
	if not Guard.isString(name, SyndicateConfig.NameMaxLength) then
		return false, "bad_name"
	end
	if not Guard.isString(tag, SyndicateConfig.TagMaxLength) then
		return false, "bad_tag"
	end
	local n, t = name :: string, tag :: string
	if #n < SyndicateConfig.NameMinLength then
		return false, "name_too_short"
	end
	if #t < SyndicateConfig.TagMinLength then
		return false, "tag_too_short"
	end
	if not t:match("^%w+$") then
		return false, "tag_not_alphanumeric"
	end
	return true, nil
end

function SyndicateService.create(player: Player, name: any, tag: any): any
	local profile = profileOf(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	if profile.SyndicateId ~= "" then
		return { ok = false, err = "already_in_syndicate" }
	end
	local valid, why = validateIdentity(name, tag)
	if not valid then
		return { ok = false, err = why }
	end
	-- charge first; if the write then fails the gems are refunded below
	local cost = SyndicateConfig.CreateCostGems
	local paid = InventoryService.applyDelta(player, { gems = -cost }, "syndicate_create")
	if not paid then
		return { ok = false, err = "insufficient_gems" }
	end

	local id = newSyndicateId()
	local record = {
		id = id,
		name = name,
		tag = (tag :: string):upper(),
		policy = "Request",
		xp = 0,
		createdAt = now(),
		updatedAt = now(),
		roles = (function()
			local seed = {}
			for _, role in SyndicateConfig.DefaultRoles do
				table.insert(seed, {
					id = role.id, name = role.name, rank = role.rank,
					permissions = table.clone(role.permissions),
				})
			end
			return seed
		end)(),
		members = {
			[tostring(player.UserId)] = { role = SyndicateConfig.OwnerRoleId, joinedAt = now(), xp = 0 },
		},
	}
	local ok = pcall(function()
		store:SetAsync(id, record)
	end)
	if not ok then
		InventoryService.applyDelta(player, { gems = cost }, "refund")
		return { ok = false, err = "store_error" }
	end
	cache[id] = { at = os.clock(), record = record }
	updateDirectory(record)
	setMembership(player, id)
	AnalyticsService.log("syndicate_created", { id = id, by = player.UserId, name = name })
	return { ok = true, syndicate = describe(record, player.UserId) }
end

function SyndicateService.join(player: Player, syndicateId: any): any
	local profile = profileOf(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	if profile.SyndicateId ~= "" then
		return { ok = false, err = "already_in_syndicate" }
	end
	if not Guard.isString(syndicateId, 64) then
		return { ok = false, err = "bad_args" }
	end
	local id = syndicateId :: string
	local key = tostring(player.UserId)
	local invited = profile.SyndicateInvites and profile.SyndicateInvites[id] ~= nil

	-- capacity and policy are checked INSIDE the transform: two people taking
	-- the last slot on different servers must not both succeed
	local committed, err = mutate(id, function(record)
		if record.members[key] then
			return nil, "already_a_member"
		end
		local level = SyndicateConfig.levelFor(record.xp or 0)
		if SyndicateService.memberCount(record) >= SyndicateConfig.memberCap(level) then
			return nil, "syndicate_full"
		end
		if record.policy == "Invite" and not invited then
			return nil, "invite_only"
		end
		if record.policy == "Request" and not invited then
			return nil, "request_required"
		end
		record.members[key] = { role = "Member", joinedAt = now(), xp = 0 }
		return record
	end)
	if committed == nil then
		return { ok = false, err = err }
	end
	if profile.SyndicateInvites then
		profile.SyndicateInvites[id] = nil
	end
	setMembership(player, id)
	updateDirectory(committed)
	AnalyticsService.log("syndicate_joined", { id = id, by = player.UserId })
	return { ok = true, syndicate = describe(committed, player.UserId) }
end

function SyndicateService.leave(player: Player): any
	local profile = profileOf(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local id = profile.SyndicateId
	if id == "" then
		return { ok = false, err = "not_in_syndicate" }
	end
	local key = tostring(player.UserId)
	local record = readRecord(id)
	-- an Owner must hand over or disband; leaving would orphan the syndicate
	if record and SyndicateService.roleOf(record, player.UserId) == "Owner" then
		if SyndicateService.memberCount(record) > 1 then
			return { ok = false, err = "owner_must_transfer" }
		end
		pcall(function()
			store:RemoveAsync(id)
		end)
		removeFromDirectory(id)
		cache[id] = nil
		setMembership(player, "")
		AnalyticsService.log("syndicate_disbanded", { id = id, by = player.UserId })
		return { ok = true, disbanded = true }
	end
	local committed = mutate(id, function(rec)
		if rec.members[key] == nil then
			return nil, "not_a_member"
		end
		rec.members[key] = nil
		return rec
	end)
	setMembership(player, "")
	if committed then
		updateDirectory(committed)
	end
	AnalyticsService.log("syndicate_left", { id = id, by = player.UserId })
	return { ok = true }
end

-- kick / promote / demote share the same permission shape, so they share a path
local function moderate(player: Player, targetUserId: any, action: string): any
	local profile = profileOf(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local id = profile.SyndicateId
	if id == "" then
		return { ok = false, err = "not_in_syndicate" }
	end
	if typeof(targetUserId) ~= "number" then
		return { ok = false, err = "bad_args" }
	end
	local targetKey = tostring(targetUserId)

	local committed, err = mutate(id, function(record)
		local allowed, why = SyndicateService.mayActOn(record, player.UserId, targetUserId, action)
		if not allowed then
			return nil, why
		end
		if action == "kick" then
			record.members[targetKey] = nil
		elseif action == "promote" or action == "demote" then
			-- step one rung along the group's OWN ladder, whatever shape it is
			local ladder = SyndicateConfig.rolesOf(record)
			local current = record.members[targetKey].role
			local at = nil
			for i, role in ladder do
				if role.id == current then
					at = i
				end
			end
			local step = (action == "promote") and -1 or 1
			local target = ladder[(at or 1) + step]
			-- never step INTO the owner role: ownership transfers deliberately
			if target and target.id ~= SyndicateConfig.OwnerRoleId then
				record.members[targetKey].role = target.id
			end
		end
		return record
	end)
	if committed == nil then
		return { ok = false, err = err }
	end
	if action == "kick" then
		local target = Players:GetPlayerByUserId(targetUserId)
		if target then
			setMembership(target, "")
		end
		updateDirectory(committed)
	end
	AnalyticsService.log("syndicate_" .. action, { id = id, by = player.UserId, target = targetUserId })
	return { ok = true, syndicate = describe(committed, player.UserId) }
end

-- Move a member straight to a named rank ("Promote to > Veteran"), rather than
-- clicking promote repeatedly. Still bounded by the same rule as promote: you
-- may only assign a rank strictly below your own, to someone you outrank.
function SyndicateService.setRole(player: Player, targetUserId: any, role: any): any
	local profile = profileOf(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local id = profile.SyndicateId
	if id == "" then
		return { ok = false, err = "not_in_syndicate" }
	end
	if typeof(targetUserId) ~= "number" or not Guard.isString(role, 24) then
		return { ok = false, err = "bad_args" }
	end
	local targetKey = tostring(targetUserId)

	local committed, err = mutate(id, function(record)
		local allowed, why = SyndicateService.mayActOn(record, player.UserId, targetUserId, "promote")
		if not allowed then
			return nil, why
		end
		local actorRole = SyndicateService.roleOf(record, player.UserId)
		local permitted = false
		for _, r in SyndicateConfig.assignableRoles(record, actorRole :: string) do
			if r.id == role then
				permitted = true
			end
		end
		if not permitted then
			return nil, "role_not_assignable"
		end
		record.members[targetKey].role = role
		return record
	end)
	if committed == nil then
		return { ok = false, err = err }
	end
	AnalyticsService.log("syndicate_setrole", {
		id = id, by = player.UserId, target = targetUserId, role = role,
	})
	return { ok = true, syndicate = describe(committed, player.UserId) }
end

-- Groups created before roles were editable have neither a role table nor role
-- IDs on their members. Seed both from the default template, mapping the old
-- preset NAMES onto the matching ids, so nobody loses their rank.
function ensureRoles(record: any): any
	if record.roles == nil or #record.roles == 0 then
		record.roles = {}
		for _, role in SyndicateConfig.DefaultRoles do
			table.insert(record.roles, {
				id = role.id,
				name = role.name,
				rank = role.rank,
				permissions = table.clone(role.permissions),
			})
		end
	end
	local known: { [string]: boolean } = {}
	for _, role in record.roles do
		known[role.id] = true
	end
	local fallback = SyndicateConfig.defaultMemberRoleId(record)
	for _, entry in (record.members or {}) do
		if entry.role == nil or not known[entry.role] then
			-- old records stored the display NAME ("Officer"); map it back
			local mapped = fallback
			for _, role in record.roles do
				if role.name == entry.role then
					mapped = role.id
				end
			end
			entry.role = mapped
		end
	end
	return record
end

SyndicateService.ensureRoles = ensureRoles

-- Owner-only, all of them: the rulebook is not something a group votes on.
local function ownerOnly(player: Player, apply: (any) -> (any?, string?)): any
	local profile = profileOf(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local id = profile.SyndicateId
	if id == "" then
		return { ok = false, err = "not_in_syndicate" }
	end
	local committed, err = mutate(id, function(record)
		ensureRoles(record)
		if SyndicateService.roleOf(record, player.UserId) ~= SyndicateConfig.OwnerRoleId then
			return nil, "no_permission"
		end
		return apply(record)
	end)
	if committed == nil then
		return { ok = false, err = err }
	end
	return { ok = true, syndicate = describe(committed, player.UserId) }
end

-- Add a role at the bottom of the ladder. It starts with nothing granted; the
-- owner turns permissions on afterwards.
function SyndicateService.createRole(player: Player, name: any): any
	if not Guard.isString(name, SyndicateConfig.RoleNameMaxLength) then
		return { ok = false, err = "bad_name" }
	end
	local clean = (name :: string):gsub("^%s+", ""):gsub("%s+$", "")
	if #clean < 2 then
		return { ok = false, err = "name_too_short" }
	end
	return ownerOnly(player, function(record)
		if #record.roles >= SyndicateConfig.MaxRoles then
			return nil, "too_many_roles"
		end
		local lowest = 1
		for _, role in record.roles do
			lowest = math.max(lowest, role.rank or 1)
		end
		table.insert(record.roles, {
			id = ("r_%d_%s"):format(now(), DataService.newId():sub(1, 6)),
			name = clean,
			rank = lowest + 1,
			permissions = {},
		})
		return record
	end)
end

function SyndicateService.renameRole(player: Player, roleId: any, name: any): any
	if not Guard.isString(roleId, 64) or not Guard.isString(name, SyndicateConfig.RoleNameMaxLength) then
		return { ok = false, err = "bad_args" }
	end
	local clean = (name :: string):gsub("^%s+", ""):gsub("%s+$", "")
	if #clean < 2 then
		return { ok = false, err = "name_too_short" }
	end
	return ownerOnly(player, function(record)
		for _, role in record.roles do
			if role.id == roleId then
				role.name = clean
				return record
			end
		end
		return nil, "unknown_role"
	end)
end

-- Delete a role; anyone holding it drops to the most junior role. The owner
-- role can never go, or the group loses the only rank that can administer it.
function SyndicateService.deleteRole(player: Player, roleId: any): any
	if not Guard.isString(roleId, 64) then
		return { ok = false, err = "bad_args" }
	end
	if roleId == SyndicateConfig.OwnerRoleId then
		return { ok = false, err = "role_locked" }
	end
	return ownerOnly(player, function(record)
		if #record.roles <= 2 then
			return nil, "need_two_roles" -- owner + something to be
		end
		local kept = {}
		local found = false
		for _, role in record.roles do
			if role.id == roleId then
				found = true
			else
				table.insert(kept, role)
			end
		end
		if not found then
			return nil, "unknown_role"
		end
		record.roles = kept
		local fallback = SyndicateConfig.defaultMemberRoleId(record)
		for _, entry in (record.members or {}) do
			if entry.role == roleId then
				entry.role = fallback
			end
		end
		return record
	end)
end

-- Move a role one step up or down the ladder. Owner stays pinned at the top.
function SyndicateService.moveRole(player: Player, roleId: any, direction: any): any
	if not Guard.isString(roleId, 64) or typeof(direction) ~= "number" then
		return { ok = false, err = "bad_args" }
	end
	if roleId == SyndicateConfig.OwnerRoleId then
		return { ok = false, err = "role_locked" }
	end
	return ownerOnly(player, function(record)
		local ladder = SyndicateConfig.rolesOf(record)
		local at = nil
		for i, role in ladder do
			if role.id == roleId then
				at = i
			end
		end
		local step = direction < 0 and -1 or 1
		local swapWith = ladder[(at or 0) + step]
		-- index 1 is always the owner, so never swap into it
		if at == nil or swapWith == nil or swapWith.id == SyndicateConfig.OwnerRoleId then
			return nil, "cannot_move"
		end
		local a, b = ladder[at], swapWith
		a.rank, b.rank = b.rank, a.rank
		record.roles = ladder
		return record
	end)
end

-- Grant or revoke one permission on one role.
function SyndicateService.setRolePermission(player: Player, roleId: any, action: any, allowed: any): any
	if not Guard.isString(roleId, 64) or not Guard.isString(action, 32) or typeof(allowed) ~= "boolean" then
		return { ok = false, err = "bad_args" }
	end
	if roleId == SyndicateConfig.OwnerRoleId then
		return { ok = false, err = "role_locked" }
	end
	if not SyndicateConfig.isGrantablePermission(action :: string) then
		return { ok = false, err = "permission_locked" }
	end
	return ownerOnly(player, function(record)
		for _, role in record.roles do
			if role.id == roleId then
				role.permissions = role.permissions or {}
				role.permissions[action] = allowed or nil
				return record
			end
		end
		return nil, "unknown_role"
	end)
end

function SyndicateService.invite(player: Player, targetUserId: any): any
	local profile = profileOf(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local id = profile.SyndicateId
	if id == "" then
		return { ok = false, err = "not_in_syndicate" }
	end
	if typeof(targetUserId) ~= "number" then
		return { ok = false, err = "bad_args" }
	end
	local record = readRecord(id)
	if record == nil then
		return { ok = false, err = "not_found" }
	end
	-- targetId 0 => permission-only check (invite has no rank requirement)
	local allowed, why = SyndicateService.mayActOn(record, player.UserId, 0, "invite")
	if not allowed then
		return { ok = false, err = why }
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if target == nil or not DataService.isLoaded(target) then
		return { ok = false, err = "player_not_here" }
	end
	local targetProfile = DataService.getProfile(target)
	if targetProfile.SyndicateId ~= "" then
		return { ok = false, err = "already_in_syndicate" }
	end
	targetProfile.SyndicateInvites = targetProfile.SyndicateInvites or {}
	targetProfile.SyndicateInvites[id] = { name = record.name, tag = record.tag, at = now() }
	task.spawn(function()
		DataService.saveNow(target)
	end)
	AnalyticsService.log("syndicate_invited", { id = id, by = player.UserId, target = targetUserId })
	return { ok = true }
end

-- An invite that arrived through a Roblox game invite link rather than from
-- someone clicking "Invite" in-game. This is the growth loop: a member shares
-- their syndicate, the friend installs and joins, and the syndicate is already
-- waiting for them on the first screen instead of being something they'd have
-- to go find. Called by ReferralService while the joiner's profile is loading,
-- so it takes the profile directly — the Player may not be ready for remotes.
--
-- Everything is still validated here: a link cannot put someone into a full or
-- invite-only syndicate, only offer them the same pending invite a member could
-- have sent by hand.
function SyndicateService.linkInvite(profile: any, syndicateId: string): boolean
	if profile == nil or profile.SyndicateId ~= "" then
		return false
	end
	local record = readRecord(syndicateId)
	if record == nil then
		return false
	end
	local level = SyndicateConfig.levelFor(record.xp or 0)
	if SyndicateService.memberCount(record) >= SyndicateConfig.memberCap(level) then
		return false
	end
	if record.policy == "Invite" then
		return false -- an invite-only syndicate must invite deliberately
	end
	profile.SyndicateInvites = profile.SyndicateInvites or {}
	profile.SyndicateInvites[syndicateId] = {
		name = record.name,
		tag = record.tag,
		at = now(),
		viaLink = true,
	}
	AnalyticsService.log("syndicate_link_invite", { id = syndicateId, target = profile.UserId })
	return true
end

function SyndicateService.setPolicy(player: Player, policy: any): any
	local profile = profileOf(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local id = profile.SyndicateId
	if id == "" then
		return { ok = false, err = "not_in_syndicate" }
	end
	local valid = false
	for _, p in SyndicateConfig.JoinPolicies do
		if p == policy then
			valid = true
		end
	end
	if not valid then
		return { ok = false, err = "bad_policy" }
	end
	local committed, err = mutate(id, function(record)
		local allowed, why = SyndicateService.mayActOn(record, player.UserId, 0, "setPolicy")
		if not allowed then
			return nil, why
		end
		record.policy = policy
		return record
	end)
	if committed == nil then
		return { ok = false, err = err }
	end
	updateDirectory(committed)
	return { ok = true, syndicate = describe(committed, player.UserId) }
end

--------------------------------------------------------------------------------
-- Requests — the reciprocity loop (see SyndicateConfig)
--------------------------------------------------------------------------------

-- Live requests on a record, oldest first, with expired ones dropped. Pure.
function SyndicateService.liveRequests(record: any, atTime: number): { any }
	local out = {}
	for _, req in (record and record.requests or {}) do
		if (req.remaining or 0) > 0 and (req.expiresAt or 0) > atTime then
			table.insert(out, req)
		end
	end
	table.sort(out, function(a, b)
		return (a.createdAt or 0) < (b.createdAt or 0)
	end)
	return out
end

function SyndicateService.postRequest(player: Player, itemId: any, count: any): any
	local profile = profileOf(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local id = profile.SyndicateId
	if id == "" then
		return { ok = false, err = "not_in_syndicate" }
	end
	if not Guard.isString(itemId, 64) or not Guard.isPositiveInt(count) then
		return { ok = false, err = "bad_args" }
	end
	if (count :: number) > SyndicateConfig.MaxRequestCount then
		return { ok = false, err = "count_too_high" }
	end
	if EconomyService.getItem(itemId :: string) == nil then
		return { ok = false, err = "unknown_item" }
	end

	local key = tostring(player.UserId)
	local at = now()
	local committed, err = mutate(id, function(record)
		if record.members[key] == nil then
			return nil, "not_a_member"
		end
		record.requests = record.requests or {}
		-- prune expired/filled here so the list can't grow without bound
		local kept = {}
		local mine = 0
		for _, req in record.requests do
			if (req.remaining or 0) > 0 and (req.expiresAt or 0) > at then
				table.insert(kept, req)
				if req.userId == player.UserId then
					mine += 1
				end
			end
		end
		if mine >= SyndicateConfig.MaxOpenRequestsPerMember then
			return nil, "too_many_requests"
		end
		table.insert(kept, {
			reqId = ("r_%d_%s"):format(at, DataService.newId():sub(1, 6)),
			userId = player.UserId,
			itemId = itemId,
			count = count,
			remaining = count,
			createdAt = at,
			expiresAt = at + SyndicateConfig.RequestTtlSeconds,
		})
		record.requests = kept
		return record
	end)
	if committed == nil then
		return { ok = false, err = err }
	end
	-- tell the syndicate someone needs something; this is the nudge that makes
	-- the loop social rather than a silent list
	local item = EconomyService.getItem(itemId :: string)
	for memberKey in committed.members do
		local uid = tonumber(memberKey)
		if uid and uid ~= player.UserId then
			NotificationService.notify(uid, ("🤝 %s needs %d× %s — help them out!")
				:format(player.Name, count, item and item.name or itemId))
		end
	end
	AnalyticsService.log("syndicate_request", { id = id, by = player.UserId, itemId = itemId, count = count })
	return { ok = true }
end

-- Give some of what a clanmate asked for, out of your own inventory.
function SyndicateService.fillRequest(player: Player, reqId: any, count: any): any
	local profile = profileOf(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local id = profile.SyndicateId
	if id == "" then
		return { ok = false, err = "not_in_syndicate" }
	end
	if not Guard.isString(reqId, 64) or not Guard.isPositiveInt(count) then
		return { ok = false, err = "bad_args" }
	end

	-- Reserve the units on the record FIRST (CAS), so two donors filling the
	-- last of a request can't both succeed; then charge the donor and refund
	-- the reservation if that fails.
	local taken, target, itemId, fillSeq = 0, 0, nil, 0
	local committed, err = mutate(id, function(record)
		local at = now()
		for _, req in (record.requests or {}) do
			if req.reqId == reqId and (req.remaining or 0) > 0 and (req.expiresAt or 0) > at then
				if req.userId == player.UserId then
					return nil, "own_request"
				end
				taken = math.min(count :: number, req.remaining)
				req.remaining -= taken
				-- Per-request fill counter, incremented inside the transform so
				-- it advances exactly once per COMMITTED write. It makes each
				-- delivery's claimId unique, which matters because both the
				-- mailbox and applyDelta dedupe on claimId: without it, one donor
				-- filling the same request twice would have the second delivery
				-- silently swallowed as a duplicate while still being charged.
				req.fills = (req.fills or 0) + 1
				fillSeq = req.fills
				target, itemId = req.userId, req.itemId
				return record
			end
		end
		return nil, "request_gone"
	end)
	if committed == nil then
		return { ok = false, err = err }
	end

	local charged = InventoryService.applyDelta(
		player,
		{ items = { [itemId :: string] = -taken } },
		Enums.GrantSource.Trade
	)
	if not charged then
		mutate(id, function(record)
			for _, req in (record.requests or {}) do
				if req.reqId == reqId then
					req.remaining += taken
				end
			end
			return record
		end)
		return { ok = false, err = "insufficient_items" }
	end

	-- deliver to the asker (mailbox when they're away, so it always lands)
	local delivered = false
	local targetPlayer = Players:GetPlayerByUserId(target)
	if targetPlayer and DataService.isLoaded(targetPlayer) then
		delivered = InventoryService.applyDelta(
			targetPlayer,
			{ items = { [itemId :: string] = taken } },
			Enums.GrantSource.Trade,
			("syn_fill_%s_%d_%d"):format(reqId, player.UserId, fillSeq)
		)
		if delivered then
			task.spawn(function()
				DataService.saveNow(targetPlayer)
			end)
		end
	end
	if not delivered then
		DataService.mailboxAppend(target, {
			claimId = ("syn_fill_%s_%d_%d"):format(reqId, player.UserId, fillSeq),
			items = { [itemId :: string] = taken },
			gems = 0,
			source = Enums.GrantSource.Trade,
			createdAt = now(),
		})
	end
	task.spawn(function()
		DataService.saveNow(player)
	end)

	-- credit the donor: syndicate XP plus a visible donation tally, which is
	-- what turns generosity into standing inside the clan
	mutate(id, function(record)
		local key = tostring(player.UserId)
		if record.members[key] then
			record.members[key].donated = (record.members[key].donated or 0) + taken
			record.members[key].xp = (record.members[key].xp or 0) + SyndicateConfig.DonationXp
		end
		record.xp = (record.xp or 0) + SyndicateConfig.DonationXp
		record.stats = record.stats or {}
		record.stats.donation = (record.stats.donation or 0) + 1
		return record
	end)

	local item = EconomyService.getItem(itemId :: string)
	NotificationService.notify(target, ("🎁 %s sent you %d× %s"):format(
		player.Name, taken, item and item.name or tostring(itemId)))
	AnalyticsService.log("syndicate_donation", {
		id = id, by = player.UserId, to = target, itemId = itemId, count = taken,
	})
	return { ok = true, count = taken }
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function SyndicateService.Init()
	store = StoreAdapters.dataStore("Syndicates_v1")
	dirStore = StoreAdapters.dataStore("SyndicateDir_v1")
end

function SyndicateService.Start()
	-- another server changed a syndicate: drop our cached copy
	StoreAdapters.subscribe(SYNC_TOPIC, function(payload)
		-- ignore our own echo: this server already holds the record it wrote,
		-- and dropping it here would undo the point of keeping it (see invalidate)
		if payload and payload.id and payload.from ~= game.JobId then
			cache[payload.id] = nil
		end
	end)

	-- Directory writes are batched off the action path (see updateDirectory).
	task.spawn(function()
		while true do
			task.wait(DIRECTORY_FLUSH_SECONDS)
			flushDirectory()
		end
	end)
	game:BindToClose(flushDirectory)

	Net.bindFunction("GetSyndicate", function(player)
		local profile = profileOf(player)
		if profile == nil then
			return { ok = false, err = "loading" }
		end
		local invites = {}
		for id, info in (profile.SyndicateInvites or {}) do
			table.insert(invites, { id = id, name = info.name, tag = info.tag })
		end
		if profile.SyndicateId == "" then
			return { ok = true, syndicate = nil, invites = invites }
		end
		local record = readRecord(profile.SyndicateId)
		if record == nil then
			-- the syndicate was disbanded elsewhere; clear the stale link
			setMembership(player, "")
			return { ok = true, syndicate = nil, invites = invites }
		end
		return { ok = true, syndicate = describe(record, player.UserId), invites = invites }
	end)

	Net.bindFunction("BrowseSyndicates", function()
		local all
		pcall(function()
			all = dirStore:GetAsync("all")
		end)
		local rows = {}
		for id, info in (all or {}) do
			-- invite-only groups are unlisted: you can't join one from here, so
			-- showing it is a row that exists only to be refused
			if info.policy ~= "Invite" then
				table.insert(rows, {
					id = id, name = info.name, tag = info.tag,
					level = info.level, members = info.members, policy = info.policy,
					xp = info.xp or 0,
					netWorth = info.netWorth or 0,
					trades = info.trades or 0,
				})
			end
		end
		table.sort(rows, function(a, b)
			if a.level ~= b.level then
				return a.level > b.level
			end
			return (a.members or 0) > (b.members or 0)
		end)
		return { ok = true, syndicates = rows }
	end)

	Net.bindFunction("CreateSyndicate", function(player, name, tag)
		return SyndicateService.create(player, name, tag)
	end)
	Net.bindFunction("JoinSyndicate", function(player, id)
		return SyndicateService.join(player, id)
	end)
	Net.bindFunction("LeaveSyndicate", function(player)
		return SyndicateService.leave(player)
	end)
	Net.bindFunction("InviteToSyndicate", function(player, targetUserId)
		return SyndicateService.invite(player, targetUserId)
	end)
	Net.bindFunction("SyndicateSetRole", function(player, targetUserId, role)
		return SyndicateService.setRole(player, targetUserId, role)
	end)
	Net.bindFunction("SyndicateSetPermission", function(player, roleId, action, allowed)
		return SyndicateService.setRolePermission(player, roleId, action, allowed)
	end)
	Net.bindFunction("SyndicateCreateRole", function(player, name)
		return SyndicateService.createRole(player, name)
	end)
	Net.bindFunction("SyndicateRenameRole", function(player, roleId, name)
		return SyndicateService.renameRole(player, roleId, name)
	end)
	Net.bindFunction("SyndicateDeleteRole", function(player, roleId)
		return SyndicateService.deleteRole(player, roleId)
	end)
	Net.bindFunction("SyndicateMoveRole", function(player, roleId, direction)
		return SyndicateService.moveRole(player, roleId, direction)
	end)
	Net.bindFunction("SyndicateModerate", function(player, targetUserId, action)
		if action ~= "kick" and action ~= "promote" and action ~= "demote" then
			return { ok = false, err = "bad_args" }
		end
		return moderate(player, targetUserId, action)
	end)
	Net.bindFunction("SetSyndicatePolicy", function(player, policy)
		return SyndicateService.setPolicy(player, policy)
	end)
	Net.bindFunction("PostSyndicateRequest", function(player, itemId, count)
		return SyndicateService.postRequest(player, itemId, count)
	end)
	Net.bindFunction("FillSyndicateRequest", function(player, reqId, count)
		return SyndicateService.fillRequest(player, reqId, count)
	end)

	AnalyticsService.log("syndicate_service_started", {})
end

return SyndicateService
