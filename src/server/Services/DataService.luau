--!strict
-- DataService: player profile lifecycle (session-locked) + mailbox claim.
--
-- Mailbox lives in its OWN DataStore ("Mailbox_v5", key = "m_<userId>"), append-only
-- via detached UpdateAsync — never written from the owner's in-memory profile.
-- This kills the lost-update race where an offline settlement lands between the
-- owner's read and save. Claiming removes exactly the claimed ids, preserving
-- concurrent appends. profile.Data.ClaimedIds provides idempotency.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local SessionStore = require(script.Parent.Parent.Stores.SessionStore)
local AnalyticsService = require(script.Parent.AnalyticsService)

local SCHEMA_VERSION = 5

local DataService = {}

DataService.ProfileLoaded = Signal.new() -- (player, profileData)
DataService.ProfileReleased = Signal.new() -- (player)

local profileStore: any -- SessionStore
local mailboxStore: any -- raw adapter datastore
local seenStore: any -- directory of every player who ever joined (for search)
local sessions: { [number]: any } = {} -- userId -> Session
local loadedPlayers: { [number]: boolean } = {}
local seenCache: { [string]: any } = {} -- userId(string) -> {name, lastSeen}
local saveState: { [number]: { lastAt: number, pending: boolean } } = {} -- saveNow coalescing
local refreshSeenCache: (force: boolean?) -> () -- forward-declared: allSeenUserIds (below) calls this before its definition later in the file

local function template()
	return {
		SchemaVersion = SCHEMA_VERSION,
		Gems = 0,
		Inventory = {},
		StarterGranted = false,
		StarterGrantId = "",
		ClaimedIds = {},
		StorePurchases = {}, -- itemId -> lifetime count bought from the limited store
		Meta = { firstJoin = os.time(), lastLogin = os.time(), joins = 0 },
		-- v2: player profile
		Showcase = {},
		StatChips = {},
		Status = "",
		Privacy = { hideValue = false, hideShowcase = false },
		Lifetime = { gemsEarned = 0, trades = 0 },
		-- v3: rewarded-ad counters. `day` is a UTC day stamp, so the daily cap
		-- resets simply by no longer matching — no scheduled job needed.
		Ads = { day = "", count = 0, lastAt = 0, bonusUsed = 0 },
		-- v3: referrals. `ids` is the set of players this account brought in
		-- (deduped, so re-inviting the same friend can't farm the bonus);
		-- `referredBy` is who brought THIS account, set once on first join.
		Referrals = { count = 0, ids = {} },
		ReferredBy = 0,
		ReferralBonus = false, -- earned the +% on first watches
		-- v4: syndicate membership. SyndicateId is the only durable link — the
		-- roster itself lives on the syndicate record, so a rename or a role
		-- change never needs a write to every member's profile.
		SyndicateId = "",
		SyndicateInvites = {}, -- syndicateId -> { name, tag, at }
		-- v5: trade booth. The CLAIM is server-local and in-memory (a booth is a
		-- spot in one server), so nothing about which booth you hold is durable —
		-- only what you bought and what you wrote on it.
		Booth = {
			skinId = "default",
			extraSlots = 0, -- purchased; slots = BoothConfig.BaseSlots + this
			tagline = "",
		},
	}
end

-- Forward migrations, run on load. [fromVersion] = function(data) -> data
local migrations: { [number]: (any) -> any } = {
	[1] = function(data)
		data.Showcase = data.Showcase or {}
		data.StatChips = data.StatChips or {}
		data.Status = data.Status or ""
		data.Privacy = data.Privacy or { hideValue = false, hideShowcase = false }
		data.Lifetime = data.Lifetime or { gemsEarned = 0, trades = 0 }
		data.SchemaVersion = 2
		return data
	end,
	[2] = function(data)
		data.Ads = data.Ads or { day = "", count = 0, lastAt = 0, bonusUsed = 0 }
		data.Ads.bonusUsed = data.Ads.bonusUsed or 0
		data.Referrals = data.Referrals or { count = 0, ids = {} }
		data.ReferredBy = data.ReferredBy or 0
		data.ReferralBonus = data.ReferralBonus or false
		data.SchemaVersion = 3
		return data
	end,
	[3] = function(data)
		data.SyndicateId = data.SyndicateId or ""
		data.SyndicateInvites = data.SyndicateInvites or {}
		data.SchemaVersion = 4
		return data
	end,
	[4] = function(data)
		data.Booth = data.Booth or { skinId = "default", extraSlots = 0, tagline = "" }
		data.SchemaVersion = 5
		return data
	end,
}

local function migrate(data: any): any
	while migrations[data.SchemaVersion] do
		data = migrations[data.SchemaVersion](data)
	end
	return data
end

local function profileKey(userId: number): string
	return "p_" .. tostring(userId)
end

local function mailboxKey(userId: number): string
	return "m_" .. tostring(userId)
end

--------------------------------------------------------------------------------
-- Offline debit
--------------------------------------------------------------------------------

-- Take goods/gems from a player who is NOT in this server.
--
-- The mailbox can credit an absent player, but a debit has to be conditional —
-- it must fail if they no longer hold the goods — so it goes straight at the
-- profile key with a CAS transform. That is safe precisely because the profile
-- is session-locked: a live lock owned by another server means that server has
-- the profile in memory and would clobber our write on its next save, so we
-- refuse ("busy") and the caller retries later. No lock (or an expired one)
-- means nobody owns it and the detached write is authoritative.
--
-- `claimId` is recorded in ClaimedIds exactly like InventoryService.applyDelta,
-- so a retried debit is a no-op success rather than a double charge.
--
-- Returns (true) on success, or (false, reason) where reason is one of
-- "loaded_here" (use the normal path), "busy", "insufficient", "store_error".
function DataService.debitOffline(
	userId: number,
	items: { [string]: number },
	gems: number,
	claimId: string
): (boolean, string?)
	if loadedPlayers[userId] then
		return false, "loaded_here"
	end

	local key = profileKey(userId)
	local record = profileStore:peek(key)
	local now = os.time()
	if record and record.Lock and record.Lock.expiry and record.Lock.expiry > now then
		return false, "busy" -- live somewhere else; their save would overwrite us
	end
	if record == nil or record.Data == nil then
		return false, "insufficient" -- never played / nothing to take
	end

	local outcome: string? = nil
	local ok = profileStore:updateDetached(key, function(old)
		if old == nil or old.Data == nil then
			outcome = "insufficient"
			return nil
		end
		-- re-check the lock inside the transform: they may have joined a server
		-- between the peek above and this write
		if old.Lock and old.Lock.expiry and old.Lock.expiry > os.time() then
			outcome = "busy"
			return nil
		end
		local data = migrate(old.Data)
		data.ClaimedIds = data.ClaimedIds or {}
		if data.ClaimedIds[claimId] then
			outcome = nil -- already taken; treat as success
			return nil
		end
		-- affordability, checked against the stored profile
		if gems > 0 and (data.Gems or 0) < gems then
			outcome = "insufficient"
			return nil
		end
		data.Inventory = data.Inventory or {}
		for itemId, count in items do
			if (data.Inventory[itemId] or 0) < count then
				outcome = "insufficient"
				return nil
			end
		end
		-- commit
		if gems > 0 then
			data.Gems -= gems
		end
		for itemId, count in items do
			local left = (data.Inventory[itemId] or 0) - count
			data.Inventory[itemId] = left ~= 0 and left or nil
		end
		data.ClaimedIds[claimId] = true
		old.Data = data
		return old
	end)

	if not ok then
		return false, "store_error"
	end
	if outcome ~= nil then
		return false, outcome
	end
	AnalyticsService.log("offline_debit", { userId = userId, gems = gems, items = items, claimId = claimId })
	return true, nil
end

-- Every userId that has EVER joined, from the seen directory -- the only
-- durable enumeration of "everyone" this service has. A player who joined
-- once and never came back still has a profile record; this is what makes
-- them reachable for something like an admin reset without waiting for them
-- to log back in.
function DataService.allSeenUserIds(): { number }
	refreshSeenCache(true)
	local ids = {}
	for key in seenCache do
		local id = tonumber(key)
		if id then
			table.insert(ids, id)
		end
	end
	return ids
end

-- Mutate a profile that is NOT loaded on this server, in place, durably --
-- same shape and same safety as debitOffline (peek, then re-check the lock
-- INSIDE the CAS transform, because they may have joined a server between
-- the peek and the write). `transform` receives the migrated Data table and
-- edits it directly; returning false from it aborts the write (used when the
-- transform decides there's nothing to do).
--
-- Returns (true) on a write, (false, "loaded_here") if this server already
-- holds their session (use the normal in-memory path instead), (false,
-- "busy") if locked by another server, (false, "no_profile") if the seen
-- directory named someone who was never actually saved, or (false,
-- "store_error").
function DataService.wipeOfflineProfile(userId: number, transform: (data: any) -> boolean?): (boolean, string?)
	if loadedPlayers[userId] then
		return false, "loaded_here"
	end
	local key = profileKey(userId)
	local record = profileStore:peek(key)
	local now = os.time()
	if record and record.Lock and record.Lock.expiry and record.Lock.expiry > now then
		return false, "busy"
	end
	if record == nil or record.Data == nil then
		return false, "no_profile"
	end

	local outcome: string? = nil
	local ok = profileStore:updateDetached(key, function(old)
		if old == nil or old.Data == nil then
			outcome = "no_profile"
			return nil
		end
		if old.Lock and old.Lock.expiry and old.Lock.expiry > os.time() then
			outcome = "busy"
			return nil
		end
		local data = migrate(old.Data)
		if transform(data) == false then
			outcome = nil -- transform declined; not an error, just nothing to write
			return nil
		end
		old.Data = data
		return old
	end)

	if not ok then
		return false, "store_error"
	end
	if outcome ~= nil then
		return false, outcome
	end
	return true, nil
end

--------------------------------------------------------------------------------
-- Mailbox
--------------------------------------------------------------------------------

-- Append an entry for any user (online anywhere, offline, doesn't matter).
function DataService.mailboxAppend(userId: number, entry: any): boolean
	local ok = pcall(function()
		mailboxStore:UpdateAsync(mailboxKey(userId), function(old)
			old = old or {}
			-- dedupe on claimId (idempotent retries)
			for _, existing in old do
				if existing.claimId == entry.claimId then
					return old
				end
			end
			table.insert(old, entry)
			return old
		end)
	end)
	if ok then
		-- ping all servers: whoever has this player claims immediately
		StoreAdapters.publish(EconomyConfig.MailboxBroadcastTopic, { userId = userId })
	end
	return ok
end

-- Claim all pending entries into the (loaded) profile. Returns applied entries.
function DataService.mailboxClaim(player: Player): { any }
	local session = sessions[player.UserId]
	if session == nil then
		return {}
	end
	local data = session.Data

	local pending: { any } = {}
	local ok = pcall(function()
		local box = mailboxStore:GetAsync(mailboxKey(player.UserId))
		if box then
			pending = box
		end
	end)
	if not ok or #pending == 0 then
		return {}
	end

	local applied: { any } = {}
	local claimedNow: { [string]: boolean } = {}
	for _, entry in pending do
		if not data.ClaimedIds[entry.claimId] then
			for itemId, count in entry.items or {} do
				data.Inventory[itemId] = (data.Inventory[itemId] or 0) + count
			end
			data.Gems += entry.gems or 0
			data.ClaimedIds[entry.claimId] = true
			-- Lifetime counters for goods received while offline (this path
			-- bypasses InventoryService.applyDelta, so count them here).
			if data.Lifetime then
				local gain = entry.gems or 0
				if gain > 0 and (entry.source == "trade" or entry.source == "board") then
					data.Lifetime.gemsEarned += gain
				end
				if entry.source == "trade" then
					data.Lifetime.trades += 1
				end
			end
			table.insert(applied, entry)
		end
		claimedNow[entry.claimId] = true
	end

	if #applied > 0 then
		session:save() -- persist credit BEFORE removing from mailbox (crash-safe order)
	end

	-- remove exactly what we processed; concurrent appends survive
	pcall(function()
		mailboxStore:UpdateAsync(mailboxKey(player.UserId), function(old)
			old = old or {}
			local kept = {}
			for _, entry in old do
				if not claimedNow[entry.claimId] then
					table.insert(kept, entry)
				end
			end
			return kept
		end)
	end)

	if #applied > 0 then
		AnalyticsService.log("mailbox_claimed", { userId = player.UserId, count = #applied })
	end
	return applied
end

--------------------------------------------------------------------------------
-- Seen-players directory (search by name or userId)
--------------------------------------------------------------------------------

local function recordSeen(player: Player)
	local key = tostring(player.UserId)
	local entry = { name = player.Name, displayName = player.DisplayName, lastSeen = os.time() }
	seenCache[key] = entry
	task.spawn(function()
		pcall(function()
			seenStore:UpdateAsync("all", function(old)
				old = old or {}
				old[key] = { name = player.Name, displayName = player.DisplayName, lastSeen = os.time() }
				return old
			end)
		end)
	end)
end

local seenCacheAt = 0
local SEEN_CACHE_TTL = 10

function refreshSeenCache(force: boolean?)
	if not force and os.clock() - seenCacheAt < SEEN_CACHE_TTL then
		return -- fresh enough; keeps SearchPlayers off the DataStore hot path
	end
	seenCacheAt = os.clock()
	pcall(function()
		local all = seenStore:GetAsync("all")
		if all then
			seenCache = all
		end
	end)
end

-- How many DISTINCT players have ever joined. The seen directory is already a
-- userId-keyed table kept warm by refreshSeenCache, so this is a count of keys,
-- not a new DataStore read. Drives the community goal on the Free Gems screen.
function DataService.uniquePlayerCount(): number
	refreshSeenCache()
	local n = 0
	for _ in seenCache do
		n += 1
	end
	return n
end

-- Display name for any userId that has ever joined, from the already-warm seen
-- cache (no extra store read). Leaderboards resolve ranked rows through this;
-- nil for an id we've never seen, and the caller falls back to the raw id.
function DataService.nameFor(userId: number): string?
	refreshSeenCache()
	local entry = seenCache[tostring(userId)]
	if entry == nil then
		return nil
	end
	return entry.displayName or entry.name
end

-- Search every player that has EVER joined the game: userId exact/prefix or
-- case-insensitive name substring. Returns up to `limit` {userId, name}.
function DataService.searchPlayers(query: string, limit: number): { any }
	local q = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
	if #q == 0 then
		return {}
	end
	local isNumeric = q:match("^%-?%d+$") ~= nil
	local results = {}
	for key, info in seenCache do
		local match = false
		if isNumeric and (key == q or key:sub(1, #q) == q) then
			match = true
		elseif info.name and info.name:lower():find(q, 1, true) then
			match = true
		end
		if match then
			table.insert(results, {
				userId = tonumber(key),
				name = info.name,
				displayName = info.displayName or info.name,
				lastSeen = info.lastSeen,
			})
			if #results >= limit then
				break
			end
		end
	end
	table.sort(results, function(a, b)
		return (a.lastSeen or 0) > (b.lastSeen or 0)
	end)
	return results
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

-- userId -> still waiting on a load; cleared on success or on leave so the
-- retry loop below stops promptly instead of spinning for a gone player.
local pendingLoads: { [number]: boolean } = {}
local LOAD_RETRY_INTERVAL = 5

-- Kicking on a failed/contended load is unnecessary — every remote already
-- gates on DataService.isLoaded(player), so an unloaded player simply can't
-- touch the economy yet. Retrying in place (instead of disconnecting) also
-- sidesteps a confirmed, currently open Roblox Studio bug where Kick()
-- disconnects the player server-side but the client never shows the kick
-- screen and just freezes (hit this via Team Test: a contended lock ->
-- Kick -> frozen teammate). A stuck lock nearly always resolves within its
-- TTL, so we just wait it out; if the whole DataStore is down, the player
-- stays connected-but-unloaded until it recovers rather than being booted.
local function onPlayerAdded(player: Player)
	recordSeen(player)
	pendingLoads[player.UserId] = true

	local session, reason
	local attempt = 0
	while pendingLoads[player.UserId] and player.Parent do
		attempt += 1
		session, reason = profileStore:load(profileKey(player.UserId))
		if session then
			break
		end
		if reason == "shutting_down" then
			break
		end
		if attempt == 1 or attempt % 6 == 0 then -- log first try + every ~30s after
			AnalyticsService.log("profile_load_retry", { userId = player.UserId, reason = reason, attempt = attempt })
		end
		task.wait(LOAD_RETRY_INTERVAL)
	end
	pendingLoads[player.UserId] = nil

	if session == nil then
		return -- player left while waiting, or server is shutting down
	end

	session.Data = migrate(session.Data)
	session.Data.Meta.lastLogin = os.time()
	session.Data.Meta.joins += 1

	sessions[player.UserId] = session

	-- If they vanished while we were loading, clean up.
	if player.Parent == nil then
		sessions[player.UserId] = nil
		session:release()
		return
	end

	loadedPlayers[player.UserId] = true
	DataService.ProfileLoaded:Fire(player, session.Data)
	AnalyticsService.log("profile_loaded", { userId = player.UserId, joins = session.Data.Meta.joins })

	DataService.mailboxClaim(player)
end

local function onPlayerRemoving(player: Player)
	pendingLoads[player.UserId] = nil -- stop any in-flight load retry loop
	local session = sessions[player.UserId]
	if session then
		sessions[player.UserId] = nil
		loadedPlayers[player.UserId] = nil
		saveState[player.UserId] = nil
		DataService.ProfileReleased:Fire(player)
		session:release()
		AnalyticsService.log("profile_released", { userId = player.UserId })
	end
end

function DataService.Init()
	StoreAdapters.init()
	-- v4: full economy regen (new item catalog + wider rarity) — old profiles
	-- hold now-nonexistent itemIds, so start players fresh.
	profileStore = SessionStore.new("PlayerProfiles_v5", template)
	mailboxStore = StoreAdapters.dataStore("Mailbox_v5")
	seenStore = StoreAdapters.dataStore("SeenPlayers_v2")
	refreshSeenCache()
end

function DataService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- another server delivered mail for someone; claim if they're here
	StoreAdapters.subscribe(EconomyConfig.MailboxBroadcastTopic, function(payload)
		if type(payload) ~= "table" or type(payload.userId) ~= "number" then
			return
		end
		local player = Players:GetPlayerByUserId(payload.userId)
		if player and sessions[payload.userId] then
			local applied = DataService.mailboxClaim(player)
			if #applied > 0 then
				-- InventoryService pushes the refreshed state to the client
				local InventoryService = require(script.Parent.InventoryService) :: any
				InventoryService.pushState(player)
				for _, entry in applied do
					if entry.fromTradeId then
						local Net = require(script.Parent.Parent.Net) :: any
						Net.fireClient("TradeSettled", player, entry.fromTradeId, entry.items or {}, entry.gems or 0)
					end
				end
			end
		end
	end)

	-- player directory search (name or userId, anyone who ever joined)
	local Net = require(script.Parent.Parent.Net) :: any
	Net.bindFunction("SearchPlayers", function(player, query)
		if type(query) ~= "string" or #query > 50 then
			return { ok = false, err = "bad_query" }
		end
		refreshSeenCache() -- pick up joins on other servers
		return { ok = true, results = DataService.searchPlayers(query, 20) }
	end)

	game:BindToClose(function()
		profileStore:releaseAll()
	end)
end

--------------------------------------------------------------------------------
-- Accessors
--------------------------------------------------------------------------------

function DataService.getProfile(player: Player): any?
	local session = sessions[player.UserId]
	return session and session.Data or nil
end

-- Players whose profiles are already loaded (for late-connecting listeners
-- that must not miss the ProfileLoaded signal).
function DataService.getLoadedPlayers(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		if loadedPlayers[player.UserId] then
			table.insert(out, player)
		end
	end
	return out
end

function DataService.isLoaded(player: Player): boolean
	return loadedPlayers[player.UserId] == true
end

-- Coalesced save: same-key DataStore writes throttle at ~6s, so hammering
-- session:save() after every mutation just fills the request queue ("request
-- was added to queue" warnings). Rapid calls collapse into one trailing save.
local SAVE_MIN_INTERVAL = 6

function DataService.saveNow(player: Player): boolean
	local session = sessions[player.UserId]
	if session == nil then
		return false
	end
	local state = saveState[player.UserId]
	if state == nil then
		state = { lastAt = 0, pending = false }
		saveState[player.UserId] = state
	end

	local now = os.clock()
	if now - state.lastAt >= SAVE_MIN_INTERVAL then
		state.lastAt = now
		return session:save()
	end
	if state.pending then
		return true -- trailing save already scheduled; it will pick up this change
	end
	state.pending = true
	task.delay(SAVE_MIN_INTERVAL - (now - state.lastAt), function()
		state.pending = false
		state.lastAt = os.clock()
		local live = sessions[player.UserId]
		if live then
			live:save()
		end
	end)
	return true
end

function DataService.newId(): string
	return HttpService:GenerateGUID(false)
end

return DataService
