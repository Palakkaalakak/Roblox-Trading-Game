--!strict
-- LeaderboardService: ranked boards over OrderedDataStore.
--
-- WRITES ARE ON A TIMER, NOT PER EVENT. Portfolio value changes on every trade,
-- craft and roll; pushing a score each time would blow OrderedDataStore's
-- per-key write budget within a minute of a busy server and starve real
-- profile/inventory calls. Each loaded player's scores are pushed at most once
-- per LeaderboardConfig.WriteIntervalSeconds, staggered so a full server
-- doesn't write in lockstep.
--
-- WEEKLY BOARDS need no reset job: the week's index (Rotation.windowIndex over
-- a 7-day window) is part of the store name, so when the week turns the name
-- stops matching and the next week starts empty. Every server derives the same
-- name from the clock alone.
--
-- Reads are cached briefly per (board, scope) — a board is the same for
-- everyone, so N players opening the screen must not become N store reads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local Rotation = require(ReplicatedStorage.Shared.Util.Rotation)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)
local ProfileProjection = require(ReplicatedStorage.Shared.Util.ProfileProjection)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local AnalyticsService = require(script.Parent.AnalyticsService)

local READ_CACHE_TTL = 20 -- seconds; a board is identical for every viewer

local LeaderboardService = {}

local stores: { [string]: any } = {} -- store name -> adapter
local readCache: { [string]: { at: number, rows: { any } } } = {}
local lastWrite: { [number]: number } = {} -- userId -> os.clock of last push

local function storeFor(name: string): any
	local s = stores[name]
	if s == nil then
		s = StoreAdapters.orderedStore(name)
		stores[name] = s
	end
	return s
end

local function currentWindow(now: number): number
	return Rotation.windowIndex(now, LeaderboardConfig.WeekSeconds)
end

--------------------------------------------------------------------------------
-- Scorers (pure given a profile + a resolver)
--------------------------------------------------------------------------------

local function resolver(itemId: string)
	local snap = EconomyService.snapshot(itemId)
	if snap == nil then
		return nil
	end
	return {
		itemId = itemId,
		name = snap.name,
		rarity = snap.rarity,
		imageId = snap.imageId,
		estValue = (snap.value and snap.value.value) or 0,
		circulating = (snap.supply and snap.supply.value) or 0,
	}
end

-- Rarest item held, scored so that SCARCER ranks higher. totalSupply is the
-- fixed cap, so the scarcest thing a player owns is the one with the smallest
-- cap; the score inverts that into "bigger is better" for OrderedDataStore,
-- which can only sort descending. Integer, because OrderedDataStore values must
-- be integers.
function LeaderboardService.scoreRarest(inventory: { [string]: number }, supplyOf: (string) -> number?): number
	local best = 0
	for itemId, count in inventory do
		if count >= 1 then
			local supply = supplyOf(itemId)
			if supply and supply > 0 then
				local score = math.floor(1000000 / supply)
				if score > best then
					best = score
				end
			end
		end
	end
	return best
end

local function scoreFor(boardId: string, profile: any): number
	if boardId == "portfolio" then
		return ProfileProjection.portfolioValue(profile.Inventory, resolver)
	elseif boardId == "trades" then
		return (profile.Lifetime and profile.Lifetime.trades) or 0
	elseif boardId == "rarest" then
		return LeaderboardService.scoreRarest(profile.Inventory, function(itemId)
			local item = EconomyService.getItem(itemId)
			return item and item.totalSupply or nil
		end)
	end
	return 0
end

--------------------------------------------------------------------------------
-- Writes
--------------------------------------------------------------------------------

local function pushScores(player: Player)
	local profile = DataService.getProfile(player)
	if profile == nil then
		return
	end
	local now = os.time()
	local window = currentWindow(now)
	local key = tostring(player.UserId)
	for _, board in LeaderboardConfig.Boards do
		local score = scoreFor(board.id, profile)
		if score > 0 then
			-- all-time and this week's board both get the same score; the
			-- weekly one lives under a window-suffixed name
			for _, scope in { "alltime", "weekly" } do
				local name = LeaderboardConfig.storeName(board, scope, window)
				pcall(function()
					storeFor(name):SetAsync(key, score)
				end)
			end
		end
	end
	lastWrite[player.UserId] = os.clock()
end

-- pushScores only ever writes a score > 0 (a fresh 0 is not worth a write),
-- which means a score that drops TO 0 -- the only way that happens today is
-- an economy reset wiping every inventory -- leaves the old durable entry
-- standing forever; nothing ever overwrites it, because nothing ever writes 0.
-- Called for every wiped player so "N in existence" style claims hold for
-- leaderboards too: portfolio value and rarest are both read from Inventory,
-- so both go; trades is lifetime activity, not current holdings, and survives.
function LeaderboardService.clearInventoryScoresFor(player: Player)
	local window = currentWindow(os.time())
	local key = tostring(player.UserId)
	for _, board in LeaderboardConfig.Boards do
		if board.id == "portfolio" or board.id == "rarest" then
			for _, scope in { "alltime", "weekly" } do
				local name = LeaderboardConfig.storeName(board, scope, window)
				pcall(function()
					storeFor(name):RemoveAsync(key)
				end)
				readCache[name] = nil
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Reads
--------------------------------------------------------------------------------

local function fetchBoard(boardId: string, scope: string, viewerId: number): any
	local board = LeaderboardConfig.byId(boardId)
	if board == nil then
		return { ok = false, err = "unknown_board" }
	end
	local window = currentWindow(os.time())
	local name = LeaderboardConfig.storeName(board, scope, window)

	local cached = readCache[name]
	local rows
	if cached and (os.clock() - cached.at) < READ_CACHE_TTL then
		rows = cached.rows
	else
		local raw = storeFor(name):GetTopAsync(LeaderboardConfig.TopCount)
		rows = {}
		for i, entry in raw do
			local userId = tonumber(entry.key) or 0
			rows[i] = {
				rank = i,
				userId = userId,
				name = DataService.nameFor and DataService.nameFor(userId) or nil,
				score = entry.value,
			}
		end
		readCache[name] = { at = os.clock(), rows = rows }
	end

	-- the viewer's own rank, pinned even when they're off the visible page, so
	-- there is always a personal number on screen
	local you = nil
	for _, row in rows do
		if row.userId == viewerId then
			you = { rank = row.rank, score = row.score, onBoard = true }
			break
		end
	end
	if you == nil then
		local own = storeFor(name):GetAsync(tostring(viewerId))
		you = { rank = nil, score = own or 0, onBoard = false }
	end

	return {
		ok = true,
		boardId = board.id,
		name = board.name,
		blurb = board.blurb,
		unit = board.unit,
		scope = scope,
		rows = rows,
		you = you,
		resetsAt = scope == "weekly" and Rotation.windowEndsAt(os.time(), LeaderboardConfig.WeekSeconds) or nil,
	}
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function LeaderboardService.Init() end

function LeaderboardService.Start()
	Net.bindFunction("GetLeaderboard", function(player, boardId, scope)
		if not Guard.isString(boardId, 32) then
			return { ok = false, err = "bad_args" }
		end
		local s = (scope == "weekly") and "weekly" or "alltime"
		return fetchBoard(boardId :: string, s, player.UserId)
	end)


	-- staggered writer: every player's scores get pushed on their own cadence,
	-- so a full server spreads its writes instead of spiking together
	task.spawn(function()
		while true do
			task.wait(15)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				if DataService.isLoaded(player) then
					local last = lastWrite[player.UserId]
					if last == nil or (now - last) >= LeaderboardConfig.WriteIntervalSeconds then
						pushScores(player)
						task.wait(0.2) -- spread the store calls within a tick
					end
				end
			end
		end
	end)

	-- final push on leave so a session's progress isn't lost to the interval
	Players.PlayerRemoving:Connect(function(player)
		if DataService.isLoaded(player) then
			pcall(pushScores, player)
		end
		lastWrite[player.UserId] = nil
	end)

	AnalyticsService.log("leaderboard_service_started", {})
end

return LeaderboardService
