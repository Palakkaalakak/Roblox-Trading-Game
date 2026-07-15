--!strict
-- DataService: player profile lifecycle (session-locked) + mailbox claim.
--
-- Mailbox lives in its OWN DataStore ("Mailbox_v1", key = userId), append-only
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

local SCHEMA_VERSION = 2

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

local function refreshSeenCache(force: boolean?)
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
