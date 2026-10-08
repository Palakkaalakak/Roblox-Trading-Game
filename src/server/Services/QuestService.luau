--!strict
-- QuestService: the progression spine.
--   * CORE chain (QuestConfig.Quests): 9 ordered quests in 3 chapters. Each
--     chapter end is a rank-up (RankConfig) that unlocks a major feature
--     (bulk orders, booths, syndicates). Quests grant NO currency or items.
--   * After the chain: 3 DAILY + 3 WEEKLY quests. Finishing all 3 dailies in
--     a UTC day extends the STREAK; missing a day resets it.
--   * Past the chain, the overhead title climbs with lifetime trade profit
--     (ProfitTitleConfig), never demoted.
-- Other services call QuestService.notify(userId, kind) after their own
-- success check. Bots (negative ids) never progress.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local RankConfig = require(ReplicatedStorage.Shared.Config.RankConfig)
local ProfitTitleConfig = require(ReplicatedStorage.Shared.Config.ProfitTitleConfig)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local QuestService = {}

local MAX_RANK_ID = RankConfig.Ranks[#RankConfig.Ranks].id
local GOLD = Color3.fromRGB(255, 215, 0)

local function today(): number
	return math.floor(os.time() / 86400)
end

local function profileOf(userId: number): any?
	local player = Players:GetPlayerByUserId(userId)
	return player and DataService.getProfile(player) or nil
end

local function save(player: Player)
	task.spawn(function()
		DataService.saveNow(player)
	end)
end

--------------------------------------------------------------------------------
-- Titles
--------------------------------------------------------------------------------

local function profitEntry(profile: any): any?
	return ProfitTitleConfig.titleFor((profile.Lifetime and profile.Lifetime.gemsEarned) or 0)
end

local function currentTitle(profile: any): string
	local rank = RankConfig.rankFor(profile.Progression.completed)
	if rank.id < MAX_RANK_ID then
		return rank.title
	end
	local entry = profitEntry(profile)
	return entry and entry.title or rank.title
end

local titleCache: { [number]: string } = {}
local function publishRank(player: Player, profile: any)
	local rank = RankConfig.rankFor(profile.Progression.completed)
	player:SetAttribute("RankId", rank.id)
	local entry = rank.id >= MAX_RANK_ID and profitEntry(profile) or nil
	player:SetAttribute("RankTier", entry and entry.tier or 0)
	local title = currentTitle(profile)
	player:SetAttribute("RankTitle", title)
	if titleCache[player.UserId] ~= title then
		local wasKnown = titleCache[player.UserId] ~= nil
		titleCache[player.UserId] = title
		if wasKnown then
			Net.fireClient("Notify", player, ("New title: %s!"):format(title), GOLD)
		end
	end
end

--------------------------------------------------------------------------------
-- Dailies
--------------------------------------------------------------------------------

local function weekId(): number
	return math.floor((os.time() / 86400 + 3) / 7) -- weeks start Monday UTC
end

-- Dailies + weeklies are a reward for FINISHING the core chain.
local function setsUnlocked(prog: any): boolean
	return prog.completed >= #QuestConfig.Quests
end

-- Rolls a fresh set when the stored one is from another period. Deterministic
-- per (userId, period) so a rejoin shows the same three.
local function rollSet(userId: number, prog: any, field: string, id: number, pools: any, order: any, salt: number): any
	local cur = prog[field]
	if cur and cur.day == id then
		return cur
	end
	local rng = Random.new(userId * 7919 + id * salt)
	local picks, base = {}, {}
	for _, tier in order do
		local pool = pools[tier]
		local q = pool[rng:NextInteger(1, #pool)]
		table.insert(picks, { tier = tier, kind = q.kind, target = q.target, title = q.title })
		base[q.kind] = prog.counts[q.kind] or 0
	end
	cur = { day = id, picks = picks, base = base }
	prog[field] = cur
	return cur
end

local function ensureDaily(userId: number, prog: any): any
	local day = today()
	if not (prog.daily and prog.daily.day == day) and prog.streak.lastDay < day - 1 then
		prog.streak.count = 0 -- streak breaks if yesterday wasn't cleared
	end
	return rollSet(userId, prog, "daily", day, QuestConfig.Daily, QuestConfig.DailyOrder, 1)
end

local function ensureWeekly(userId: number, prog: any): any
	return rollSet(userId, prog, "weekly", weekId(), QuestConfig.Weekly, QuestConfig.WeeklyOrder, 104729)
end

local function dailyProgress(prog: any, d: any, pick: any): number
	return math.min((prog.counts[pick.kind] or 0) - (d.base[pick.kind] or 0), pick.target)
end

--------------------------------------------------------------------------------
-- Status (client-facing)
--------------------------------------------------------------------------------

-- Where the player sits on the profit-title ladder (post-core progression).
local function profitInfo(profile: any): any
	local earned = (profile.Lifetime and profile.Lifetime.gemsEarned) or 0
	local ladder = ProfitTitleConfig.Ladder
	local cur = ProfitTitleConfig.titleFor(earned)
	local nxt = nil
	for _, e in ladder do
		if e.threshold > earned then
			nxt = e
			break
		end
	end
	return {
		earned = earned,
		title = cur and cur.title or nil,
		tier = cur and cur.tier or 0,
		nextTitle = nxt and nxt.title or nil,
		nextThreshold = nxt and nxt.threshold or nil,
		prevThreshold = cur and cur.threshold or 0,
		count = #ladder,
		reached = cur and (function()
			for i, e in ladder do
				if e == cur then
					return i
				end
			end
			return 0
		end)() or 0,
	}
end

function QuestService.statusFor(player: Player): any?
	local profile = DataService.getProfile(player)
	if profile == nil then
		return nil
	end
	local prog = profile.Progression
	local unlocked = setsUnlocked(prog)
	local rank = RankConfig.rankFor(prog.completed)
	local nextRank = RankConfig.nextAfter(rank)
	local quest = QuestConfig.byId(prog.completed + 1)

	local function listSet(set: any): any
		local out = {}
		for i, pick in set.picks do
			local p = dailyProgress(prog, set, pick)
			table.insert(out, { index = i, tier = pick.tier, title = pick.title, target = pick.target, progress = p, done = p >= pick.target })
		end
		return out
	end
	local d = unlocked and ensureDaily(player.UserId, prog) or nil
	local w = unlocked and ensureWeekly(player.UserId, prog) or nil

	return {
		rank = { id = rank.id, title = currentTitle(profile) },
		nextRank = nextRank and { id = nextRank.id, title = nextRank.title, questsRequired = nextRank.questsRequired },
		completed = prog.completed,
		totalQuests = #QuestConfig.Quests,
		quest = quest and {
			id = quest.id,
			title = quest.title,
			target = quest.target,
			progress = math.min(prog.counts[quest.kind] or 0, quest.target),
		} or nil,
		setsUnlocked = unlocked,
		dailies = d and listSet(d) or {},
		dailyResetsAt = d and (d.day + 1) * 86400 or 0,
		weeklies = w and listSet(w) or {},
		weeklyResetsAt = w and (w.day * 7 + 4) * 86400 or 0,
		streak = { count = prog.streak.count, clearedToday = d ~= nil and prog.streak.lastDay == d.day },
	}
end

--------------------------------------------------------------------------------
-- Progress
--------------------------------------------------------------------------------

local UNLOCK_NAMES: { [string]: string } = {
	bulkbuy = "Bulk Buy",
	booth = "Booths",
	syndicate = "Syndicates",
}

local function completeMain(player: Player, profile: any, quest: any)
	local before = RankConfig.rankFor(profile.Progression.completed)
	profile.Progression.completed += 1
	local after = RankConfig.rankFor(profile.Progression.completed)
	publishRank(player, profile)
	save(player)
	if after.id ~= before.id then
		local names = {}
		for key in after.unlocks do
			table.insert(names, UNLOCK_NAMES[key] or key)
		end
		local msg = #names > 0 and ("Rank up: %s! Unlocked %s"):format(after.title, table.concat(names, " + ")) or ("Rank up: %s!"):format(after.title)
		Net.fireClient("Notify", player, msg, GOLD)
	else
		Net.fireClient("Notify", player, ("Quest complete: %s"):format(quest.title), GOLD)
	end
	AnalyticsService.log("quest_completed", { userId = player.UserId, questId = quest.id, rank = after.title })
end

-- All three of today's dailies done -> extend the streak (once per day).
local function checkStreak(player: Player, prog: any, d: any)
	if prog.streak.lastDay == d.day then
		return
	end
	for _, pick in d.picks do
		if dailyProgress(prog, d, pick) < pick.target then
			return
		end
	end
	prog.streak.count = (prog.streak.lastDay == d.day - 1) and prog.streak.count + 1 or 1
	prog.streak.lastDay = d.day
	Net.fireClient("Notify", player, ("%d-day streak!"):format(prog.streak.count), GOLD)
end

-- Completes every quest whose lifetime count is already met (a player who
-- rolled 10 times before reaching "Do 3 rolls" shouldn't have to roll again).
local function catchUp(player: Player, profile: any): boolean
	local prog = profile.Progression
	local advanced = false
	while true do
		local quest = QuestConfig.byId(prog.completed + 1)
		if quest == nil or (prog.counts[quest.kind] or 0) < quest.target then
			return advanced
		end
		completeMain(player, profile, quest)
		advanced = true
	end
end

function QuestService.notify(userId: number, kind: string, amount: number?)
	if userId < 0 then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return
	end
	local profile = DataService.getProfile(player)
	if profile == nil then
		return
	end
	local prog = profile.Progression
	local sets = {}
	if setsUnlocked(prog) then
		table.insert(sets, { set = ensureDaily(userId, prog), label = "Daily", daily = true })
		table.insert(sets, { set = ensureWeekly(userId, prog), label = "Weekly" })
	end
	local before: { [any]: boolean } = {}
	for _, e in sets do
		for _, pick in e.set.picks do
			before[pick] = dailyProgress(prog, e.set, pick) >= pick.target
		end
	end
	prog.counts[kind] = (prog.counts[kind] or 0) + (amount or 1)

	for _, e in sets do
		for _, pick in e.set.picks do
			if not before[pick] and pick.kind == kind and dailyProgress(prog, e.set, pick) >= pick.target then
				Net.fireClient("Notify", player, ("%s done: %s"):format(e.label, pick.title), GOLD)
				if e.daily then
					checkStreak(player, prog, e.set)
				end
			end
		end
	end

	if not catchUp(player, profile) then
		publishRank(player, profile) -- trade profit may have crossed a title threshold
	end
end

-- Robux skip: completes the current core quest outright.
function QuestService.skipCurrentQuest(player: Player): boolean
	local profile = DataService.getProfile(player)
	if profile == nil then
		return false
	end
	local quest = QuestConfig.byId(profile.Progression.completed + 1)
	if quest == nil then
		return false
	end
	completeMain(player, profile, quest)
	return true
end

function QuestService.hasUnlock(userId: number, key: string): boolean
	local profile = profileOf(userId)
	if profile == nil then
		return false
	end
	return RankConfig.unlocked(profile.Progression.completed, key)
end

function QuestService.Init() end

function QuestService.Start()
	Net.bindFunction("GetQuestStatus", function(player)
		local status = QuestService.statusFor(player)
		if status == nil then
			return { ok = false, err = "loading" }
		end
		return { ok = true, status = status }
	end)

	DataService.ProfileLoaded:Connect(function(player: Player, profile: any)
		local prog = profile.Progression
		-- The chain shrank from 25 to 9: anyone past the old list lands on the
		-- last rank with everything unlocked. Old claim/reward state is dropped.
		prog.completed = math.min(prog.completed, #QuestConfig.Quests)
		prog.unclaimed = {}
		prog.rep = nil
		if profile.StarterRevealShown and (prog.counts.starter or 0) < 1 then
			prog.counts.starter = 1 -- starter was opened before this quest existed
		end
		publishRank(player, profile)
		catchUp(player, profile)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		titleCache[player.UserId] = nil
	end)
end

return QuestService
