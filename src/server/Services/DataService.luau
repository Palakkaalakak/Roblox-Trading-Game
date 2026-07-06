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

local SCHEMA_VERSION = 1

local DataService = {}

DataService.ProfileLoaded = Signal.new() -- (player, profileData)
DataService.ProfileReleased = Signal.new() -- (player)

local profileStore: any -- SessionStore
local mailboxStore: any -- raw adapter datastore
local seenStore: any -- directory of every player who ever joined (for search)
local sessions: { [number]: any } = {} -- userId -> Session
local loadedPlayers: { [number]: boolean } = {}
local seenCache: { [string]: any } = {} -- userId(string) -> {name, lastSeen}

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
	}
end

-- Forward migrations, run on load. [fromVersion] = function(data) -> data
local migrations: { [number]: (any) -> any } = {
	-- [1] = function(data) ... data.SchemaVersion = 2; return data end,
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
	seenCache[key] = { name = player.Name, lastSeen = os.time() }
	task.spawn(function()
		pcall(function()
			seenStore:UpdateAsync("all", function(old)
				old = old or {}
				old[key] = { name = player.Name, lastSeen = os.time() }
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
			table.insert(results, { userId = tonumber(key), name = info.name, lastSeen = info.lastSeen })
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

local function onPlayerAdded(player: Player)
	recordSeen(player)
	local session, reason = profileStore:load(profileKey(player.UserId))
	if session == nil then
		AnalyticsService.log("profile_load_failed", { userId = player.UserId, reason = reason })
		player:Kick("Your data is loading on another server or unavailable. Rejoin in a minute.")
		return
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
	local session = sessions[player.UserId]
	if session then
		sessions[player.UserId] = nil
		loadedPlayers[player.UserId] = nil
		DataService.ProfileReleased:Fire(player)
		session:release()
		AnalyticsService.log("profile_released", { userId = player.UserId })
	end
end

function DataService.Init()
	StoreAdapters.init()
	profileStore = SessionStore.new("PlayerProfiles_v1", template)
	mailboxStore = StoreAdapters.dataStore("Mailbox_v1")
	seenStore = StoreAdapters.dataStore("SeenPlayers_v1")
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
	local RateLimitService = require(script.Parent.RateLimitService) :: any
	Net.bindFunction("SearchPlayers", function(player, query)
		if not RateLimitService.check(player, "SearchPlayers") then
			return { ok = false, err = "rate_limited" }
		end
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

function DataService.saveNow(player: Player): boolean
	local session = sessions[player.UserId]
	if session then
		return session:save()
	end
	return false
end

function DataService.newId(): string
	return HttpService:GenerateGUID(false)
end

return DataService
