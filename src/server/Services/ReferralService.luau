--!strict
-- ReferralService: "invite your friends, reach the goal sooner".
--
-- HOW A REFERRAL IS ACTUALLY DETECTED. The client opens Roblox's own invite
-- prompt (SocialService:PromptGameInvite) carrying launch data that names the
-- inviter — "ref_<userId>". When a friend accepts, they join with that string
-- on their join data, and this service reads it once, on their first ever join.
--
-- RULES, all enforced here and not on the client:
--   * you cannot refer yourself
--   * a player can only ever be referred ONCE, and only on the join where they
--     were also brand new — so leaving and rejoining never re-credits anyone
--   * an inviter's referral ids are a SET, so re-inviting the same friend can't
--     farm the bonus
--
-- THE BONUS. At ReferralsNeeded joins the inviter earns a bonus on their first
-- watches, and so does everyone they brought — that's the "all 4 of you" part.
-- The inviter is credited the moment the threshold is crossed. The people they
-- invited are credited when they next join, by reading the inviter's public
-- referral record; that record lives in its own DataStore so it can be read for
-- a player who isn't in the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdConfig = require(ReplicatedStorage.Shared.Config.AdConfig)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local DataService = require(script.Parent.DataService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ReferralService = {}

local refStore: any -- userId -> { count = n } — readable while the player is offline

local function refKey(userId: number): string
	return "r_" .. tostring(userId)
end

-- The inviter's referral count, readable whether or not they're in this server.
local function referralCount(userId: number): number
	local n = 0
	pcall(function()
		local rec = refStore:GetAsync(refKey(userId))
		if typeof(rec) == "table" and typeof(rec.count) == "number" then
			n = rec.count
		end
	end)
	return n
end

-- Parse "ref_<userId>" out of the join data. Returns nil for anything else, so
-- a malformed or absent value simply means "no referrer".
--
-- A syndicate recruitment link appends "~syn_<syndicateId>"; the referrer part
-- is read the same either way, so older links keep working unchanged.
function ReferralService.parseReferrer(launchData: any): number?
	if typeof(launchData) ~= "string" then
		return nil
	end
	local id = launchData:match("^ref_(%d+)$") or launchData:match("^ref_(%d+)~")
	if id == nil then
		return nil
	end
	local userId = tonumber(id)
	if userId == nil or userId <= 0 then
		return nil
	end
	return userId
end

-- The syndicate a recruitment link points at, or nil for a plain invite.
function ReferralService.parseSyndicate(launchData: any): string?
	if typeof(launchData) ~= "string" then
		return nil
	end
	local id = launchData:match("~syn_([%w_]+)$")
	if id == nil or #id > 64 then
		return nil
	end
	return id
end

-- The launch data a client should attach to its invite. Passing a syndicate id
-- turns a plain "come play with me" into clan recruitment: the friend lands
-- with the invite already pending.
function ReferralService.launchDataFor(userId: number, syndicateId: string?): string
	local base = "ref_" .. tostring(userId)
	if syndicateId and syndicateId ~= "" then
		return base .. "~syn_" .. syndicateId
	end
	return base
end

-- Credit `inviterId` for bringing `joiner`. Idempotent per (inviter, joiner).
local function creditInviter(inviterId: number, joinerId: number)
	local crossed = false
	local ok = pcall(function()
		refStore:UpdateAsync(refKey(inviterId), function(old)
			old = old or { count = 0, ids = {} }
			old.ids = old.ids or {}
			if old.ids[tostring(joinerId)] then
				return nil -- already counted; leave the record untouched
			end
			old.ids[tostring(joinerId)] = true
			old.count = (old.count or 0) + 1
			crossed = old.count == AdConfig.ReferralsNeeded
			return old
		end)
	end)
	if not ok then
		return
	end

	-- mirror onto the inviter's live profile when they're in this server
	local inviter = Players:GetPlayerByUserId(inviterId)
	if inviter and DataService.isLoaded(inviter) then
		local profile = DataService.getProfile(inviter)
		if profile then
			profile.Referrals = profile.Referrals or { count = 0, ids = {} }
			if not profile.Referrals.ids[tostring(joinerId)] then
				profile.Referrals.ids[tostring(joinerId)] = true
				profile.Referrals.count += 1
			end
			if AdConfig.referralBonusEarned(profile.Referrals.count) then
				profile.ReferralBonus = true
			end
			task.spawn(function()
				DataService.saveNow(inviter)
			end)
		end
	end
	AnalyticsService.log("referral", { inviter = inviterId, joiner = joinerId, crossed = crossed })
end

-- Runs once per join, after the profile is loaded.
local function onProfileLoaded(player: Player, profile: any)
	if profile == nil then
		return
	end
	profile.Referrals = profile.Referrals or { count = 0, ids = {} }

	-- 1. brand-new player arriving from someone's invite?
	if profile.ReferredBy == 0 then
		local joinData
		pcall(function()
			joinData = player:GetJoinData()
		end)

		local inviterId = ReferralService.parseReferrer(joinData and joinData.LaunchData)
		-- never self-refer; Meta.joins is 1 on a first-ever join, which is what
		-- stops an existing player from being "referred" later on
		if inviterId and inviterId ~= player.UserId and (profile.Meta == nil or profile.Meta.joins <= 1) then
			profile.ReferredBy = inviterId
			task.spawn(creditInviter, inviterId, player.UserId)
		end

		-- came in on a syndicate recruitment link? hand them the invite now, so
		-- the clan is waiting on their first screen rather than something they
		-- have to go and find. Lazy require: SyndicateService requires DataService
		-- which this service also uses, and a top-level require would cycle.
		local syndicateId = ReferralService.parseSyndicate(joinData and joinData.LaunchData)
		if syndicateId then
			task.spawn(function()
				local SyndicateService = require(script.Parent.SyndicateService)
				if SyndicateService.linkInvite(profile, syndicateId) then
					DataService.saveNow(player)
				end
			end)
		end
	end

	-- 2. did the person who invited me hit the threshold while I was away?
	if not profile.ReferralBonus then
		if AdConfig.referralBonusEarned(profile.Referrals.count) then
			profile.ReferralBonus = true
		elseif profile.ReferredBy ~= 0 then
			task.spawn(function()
				if AdConfig.referralBonusEarned(referralCount(profile.ReferredBy)) then
					profile.ReferralBonus = true
					DataService.saveNow(player)
				end
			end)
		end
	end
end

function ReferralService.Init()
	refStore = StoreAdapters.dataStore("Referrals_v1")
end

function ReferralService.Start()
	DataService.ProfileLoaded:Connect(onProfileLoaded)
end

return ReferralService
