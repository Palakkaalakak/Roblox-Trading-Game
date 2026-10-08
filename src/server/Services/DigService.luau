--!strict
-- DigService: Relic Dig reward. The client reports how much of the relic it
-- uncovered; the server turns that into a reward LEVEL, then picks an item
-- through the same draw + reserve + grant path rolls use. Pays items only,
-- never gems. Skill sets the level; chance only picks the item inside it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Enums)
local DigConfig = require(ReplicatedStorage.Shared.Config.DigConfig)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local RollService = require(script.Parent.RollService)

local DigService = {}

-- session-only state per player (proof of concept: not saved)
local runs: { [number]: number } = {}
local badRuns: { [number]: number } = {}

local function pseudoTier(level: string): any
	local def = DigConfig.Levels[level]
	return { id = "dig_" .. level, name = level, gems = 0, floorFrac = 0, window = def.window, odds = def.odds }
end

-- a spread of real items for the wheel to scroll past, winner at a fixed slot
local function buildReel(winnerId: string): { any }
	local ids = {}
	for itemId, item in EconomyService.allItems() do
		if (item.assignmentWeight or 0) > 0 then
			table.insert(ids, itemId)
		end
	end
	local tiles = {}
	for i = 1, DigConfig.ReelTiles do
		local itemId = if i == DigConfig.ReelWinnerIndex then winnerId else ids[math.random(1, math.max(#ids, 1))] or winnerId
		local item = EconomyService.getItem(itemId)
		tiles[i] = {
			itemId = itemId,
			name = item and item.name or itemId,
			imageId = item and item.imageId or nil,
			rarity = item and item.rarity or "Common",
		}
	end
	return tiles
end

function DigService.finish(player: Player, taps: any, deeper: any, _unused: any): any
	if not DataService.isLoaded(player) then
		return { ok = false, err = "loading" }
	end
	if type(taps) ~= "number" or taps ~= taps then
		return { ok = false, err = "bad_args" }
	end
	local userId = player.UserId
	taps = math.clamp(math.floor(taps :: number), 1, 500)
	local isDeeper = deeper == true

	local idx = DigConfig.levelIndex(DigConfig.levelForTaps(taps :: number))
	local rawIdx = idx

	-- guaranteed good first run
	local firstRun = (runs[userId] or 0) == 0
	if firstRun then
		idx = math.max(idx, DigConfig.levelIndex(DigConfig.FirstRunMinLevel))
	end
	-- bad-luck meter upgrades one level after enough weak runs
	local luckBump = false
	if (badRuns[userId] or 0) >= DigConfig.LuckRuns then
		idx += 1
		luckBump = true
	end
	-- deeper layer pays one level higher
	if isDeeper then
		idx += 1
	end
	idx = math.min(idx, #DigConfig.LevelOrder)
	local level = DigConfig.LevelOrder[idx]

	-- draw; if the rolled rarity is out of reserve, fall back one level at a time
	local itemId: string? = nil
	local tryIdx = idx
	while itemId == nil and tryIdx >= 1 do
		itemId = RollService.pick(pseudoTier(DigConfig.LevelOrder[tryIdx]))
		tryIdx -= 1
	end
	if itemId == nil then
		return { ok = false, err = "restocking" }
	end

	local reserved = EconomyService.reserveOne(itemId)
	if not reserved then
		return { ok = false, err = "nothing_left" }
	end
	local granted = InventoryService.applyDelta(player, { items = { [itemId] = 1 } }, Enums.GrantSource.Dig)
	if not granted then
		EconomyService.restockCopies(itemId, 1)
		return { ok = false, err = "grant_failed" }
	end

	runs[userId] = (runs[userId] or 0) + 1
	if luckBump then
		badRuns[userId] = 0
	elseif firstRun then
		badRuns[userId] = 0 -- the guaranteed-good first run never counts against the player
	elseif rawIdx < DigConfig.levelIndex("Good") then
		badRuns[userId] = (badRuns[userId] or 0) + 1
	else
		badRuns[userId] = 0
	end

	task.spawn(function()
		DataService.saveNow(player)
	end)
	EconomyService.broadcastStats({ itemId })

	-- dig mastery: xp banked in the profile's Lifetime table (no schema change)
	local profile = DataService.getProfile(player)
	local digXp, digLevel, levelUp = 0, 1, false
	if profile and profile.Lifetime then
		local before = DigConfig.progressionFor(profile.Lifetime.digXp or 0)
		profile.Lifetime.digXp = (profile.Lifetime.digXp or 0) + (DigConfig.XpFor[level] or 1)
		digXp = profile.Lifetime.digXp
		digLevel = DigConfig.progressionFor(digXp)
		levelUp = digLevel > before
	end

	local item = EconomyService.getItem(itemId)
	local rarity = item and item.rarity or "Common"
	if rarity == "Godly" or rarity == "Celestial" then
		Net.fireAllClients("Notify", ("%s dug up a %s %s!"):format(player.DisplayName, rarity, item and item.name or "relic"), nil)
	end

	return {
		ok = true,
		level = level,
		taps = taps,
		luckBump = luckBump,
		digXp = digXp,
		digLevel = digLevel,
		levelUp = levelUp,
		firstRun = firstRun,
		luck = math.min((badRuns[userId] or 0) / DigConfig.LuckRuns, 1),
		item = {
			itemId = itemId,
			name = item and item.name or itemId,
			imageId = item and item.imageId or nil,
			rarity = rarity,
			value = EconomyService.valueOf(itemId),
		},
		reel = buildReel(itemId),
	}
end

function DigService.Init() end

function DigService.Start()
	-- (score 0..1, deeper: boolean, cracks: number)
	Net.bindFunction("FinishDig", function(player, score, deeper, cracks)
		return DigService.finish(player, score, deeper, cracks)
	end)
	-- () -> {ok, xp}: the player's saved dig mastery (client derives brushes/zone)
	Net.bindFunction("GetDigStatus", function(player)
		local profile = DataService.getProfile(player)
		if not profile or not profile.Lifetime then
			return { ok = false, err = "loading" }
		end
		return { ok = true, xp = profile.Lifetime.digXp or 0 }
	end)
	Players.PlayerRemoving:Connect(function(p)
		runs[p.UserId] = nil
		badRuns[p.UserId] = nil
	end)
end

return DigService
