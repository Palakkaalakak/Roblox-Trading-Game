--!strict
-- ProfileService: writes each player's lock-free PUBLIC snapshot and serves
-- profile reads for anyone (online or offline). The snapshot holds only public
-- data; privacy toggles are applied at WRITE time so private data never enters
-- the public key. Reads are a plain GetAsync + a short cache — no session lock,
-- so an offline (or cross-server) player's profile is still viewable.

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local ProfileProjection = require(ReplicatedStorage.Shared.Util.ProfileProjection)

local STATUS_MAX = 60
local READ_CACHE_TTL = 30 -- seconds
local WRITE_DEBOUNCE = 4 -- seconds after an inventory/gems change

local ALLOWED_CHIPS = ProfileProjection.AllowedChips

local ProfileService = {}
local publicStore: any
local readCache: { [number]: { at: number, profile: any } } = {}
local dirty: { [number]: boolean } = {}

-- Build an ItemView resolver from live economy state.
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

-- Project a loaded player's private profile into the public snapshot.
local function build(player: Player): any?
	local profile = DataService.getProfile(player)
	if profile == nil then
		return nil
	end
	return ProfileProjection.project({
		userId = player.UserId,
		name = player.Name,
		displayName = player.DisplayName,
		firstJoin = profile.Meta.firstJoin,
		now = os.time(),
		inventory = profile.Inventory,
		gems = profile.Gems,
		showcase = profile.Showcase,
		statChips = profile.StatChips,
		status = profile.Status,
		privacy = profile.Privacy,
		lifetime = profile.Lifetime,
		resolve = resolver,
	})
end

-- Write a player's snapshot now (own key only — lock-free, single-writer).
local function writeNow(player: Player)
	local snap = build(player)
	if snap == nil then
		return
	end
	local userId = player.UserId
	readCache[userId] = { at = os.clock(), profile = snap }
	task.spawn(function()
		pcall(function()
			publicStore:SetAsync(tostring(userId), snap)
		end)
	end)
end

-- Mark dirty; a single debounced writer coalesces bursts (trades mutate the
-- inventory rapidly — never write per mutation).
function ProfileService.markDirty(player: Player)
	local userId = player.UserId
	if dirty[userId] then
		return
	end
	dirty[userId] = true
	task.delay(WRITE_DEBOUNCE, function()
		dirty[userId] = nil
		local p = Players:GetPlayerByUserId(userId)
		if p and DataService.isLoaded(p) then
			writeNow(p)
		end
	end)
end

-- Read anyone's public snapshot (online or offline). Cached briefly.
local function readProfile(userId: number): any?
	local p = Players:GetPlayerByUserId(userId)
	if p and DataService.isLoaded(p) then
		local snap = build(p) -- freshest for an online, loaded target
		if snap then
			return snap
		end
	end
	local cached = readCache[userId]
	if cached and os.clock() - cached.at < READ_CACHE_TTL then
		return cached.profile
	end
	local ok, data = pcall(function()
		return publicStore:GetAsync(tostring(userId))
	end)
	if ok and data then
		readCache[userId] = { at = os.clock(), profile = data }
		return data
	end
	return nil
end

function ProfileService.Init()
	publicStore = StoreAdapters.dataStore("PublicProfile_v2")
end

function ProfileService.Start()
	DataService.ProfileLoaded:Connect(function(player)
		writeNow(player)
	end)
	DataService.ProfileReleased:Connect(function(player)
		writeNow(player) -- final flush of the freshest state
	end)

	Net.bindFunction("GetProfile", function(player, userId)
		if type(userId) ~= "number" then
			return { ok = false, err = "bad_userId" }
		end
		local snap = readProfile(userId)
		-- TEMP diagnostic: confirms the requested userId matches the userId
		-- baked into the returned snapshot. Remove once the "shows my stats
		-- under another player's name" report is root-caused.
		print(("[ProfileDebug] GetProfile requested=%s by=%s -> snap.userId=%s snap.name=%s"):format(
			tostring(userId), tostring(player.UserId), tostring(snap and snap.userId), tostring(snap and snap.name)))
		return { ok = true, profile = snap }
	end)

	Net.bindFunction("SetShowcase", function(player, itemIds)
		local profile = DataService.getProfile(player)
		if profile == nil then
			return { ok = false, err = "loading" }
		end
		if type(itemIds) ~= "table" then
			return { ok = false, err = "bad_input" }
		end
		local clean = {}
		for _, itemId in itemIds do
			if type(itemId) == "string" and (profile.Inventory[itemId] or 0) >= 1 then
				table.insert(clean, itemId)
				if #clean >= 6 then
					break
				end
			end
		end
		profile.Showcase = clean
		writeNow(player)
		return { ok = true }
	end)

	Net.bindFunction("SetStatus", function(player, text)
		local profile = DataService.getProfile(player)
		if profile == nil then
			return { ok = false, err = "loading" }
		end
		if type(text) ~= "string" then
			return { ok = false, err = "bad_input" }
		end
		text = text:sub(1, STATUS_MAX)
		local ok, filtered = pcall(function()
			local res = TextService:FilterStringAsync(text, player.UserId)
			return res:GetNonChatStringForBroadcastAsync()
		end)
		profile.Status = ok and filtered or ""
		writeNow(player)
		return { ok = ok, err = (not ok) and "filter_failed" or nil }
	end)

	Net.bindFunction("SetStatChips", function(player, keys)
		local profile = DataService.getProfile(player)
		if profile == nil then
			return { ok = false, err = "loading" }
		end
		if type(keys) ~= "table" then
			return { ok = false, err = "bad_input" }
		end
		local clean = {}
		for _, key in keys do
			if type(key) == "string" and ALLOWED_CHIPS[key] then
				table.insert(clean, key)
				if #clean >= 3 then
					break
				end
			end
		end
		profile.StatChips = clean
		writeNow(player)
		return { ok = true }
	end)

	Net.bindFunction("SetPrivacy", function(player, toggles)
		local profile = DataService.getProfile(player)
		if profile == nil then
			return { ok = false, err = "loading" }
		end
		if type(toggles) ~= "table" then
			return { ok = false, err = "bad_input" }
		end
		profile.Privacy = {
			hideValue = toggles.hideValue == true,
			hideShowcase = toggles.hideShowcase == true,
		}
		writeNow(player)
		return { ok = true }
	end)

	AnalyticsService.log("profile_service_started", {})
end

return ProfileService
