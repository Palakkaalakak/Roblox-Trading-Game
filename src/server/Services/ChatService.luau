--!strict
-- ChatService: trade quick-chat and group chat.
--
-- TWO DIFFERENT THINGS, ON PURPOSE.
--
-- 1. TRADE QUICK CHAT is canned phrases only. The client sends a phrase ID and
--    optionally an itemId; the server looks the wording up in QuickChatConfig
--    and relays it. No player-authored text ever crosses, so there is nothing
--    to filter and, critically, no age-group restriction — which is the whole
--    point. Roblox blocks text chat between different age groups, and a
--    trading game where half the pairings cannot negotiate is broken.
--
-- 2. GROUP CHAT is real typed text, so every message goes through
--    TextService:FilterStringAsync and is delivered per-recipient with
--    GetChatForUserAsync. That is not optional: the same string is legally and
--    practically a different string for different viewers, so it must be
--    filtered ONCE per reader, never broadcast pre-rendered.
--
-- WHERE GROUP MESSAGES LIVE. Nowhere durable. Chat is high-frequency and a
-- DataStore write is ~0.5s, so persisting every line would be both slow and
-- expensive for something nobody reads twice. Messages go out over
-- MessagingService for cross-server delivery and each server keeps a small
-- ring buffer so a player who opens the panel sees recent context. History
-- older than that is deliberately gone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local QuickChatConfig = require(ReplicatedStorage.Shared.Config.QuickChatConfig)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local AnalyticsService = require(script.Parent.AnalyticsService)

local GROUP_TOPIC = "group_chat"
local HISTORY_PER_GROUP = 40
local GROUP_MAX_LENGTH = 140

local ChatService = {}

-- groupId -> ring buffer of { userId, name, text, at }
local history: { [string]: { any } } = {}

-- Every message carries an id that is stable across deliveries, because the
-- SAME message reaches a client twice by design: once live, once when history
-- replays on open. Without an id the client cannot tell the replay from a new
-- line and renders both. The server's JobId is in there so ids minted on two
-- servers for the same group can never collide.
local seq = 0
local function nextChatId(): string
	seq += 1
	return ("%s:%d"):format(game.JobId ~= "" and game.JobId or "studio", seq)
end

local function push(groupId: string, entry: any)
	local buf = history[groupId]
	if buf == nil then
		buf = {}
		history[groupId] = buf
	end
	table.insert(buf, entry)
	while #buf > HISTORY_PER_GROUP do
		table.remove(buf, 1)
	end
end

--------------------------------------------------------------------------------
-- Trade quick chat
--------------------------------------------------------------------------------

local function tradeQuickChat(player: Player, tradeId: any, phraseId: any, itemId: any): any
	if not Guard.isString(tradeId, 64) or not Guard.isString(phraseId, 32) then
		return { ok = false, err = "bad_args" }
	end
	local phrase = QuickChatConfig.tradePhrase(phraseId :: string)
	if phrase == nil then
		return { ok = false, err = "unknown_phrase" } -- not in the file, not sent
	end

	-- only the two people in the trade may speak into it, and only they hear it
	local TradeService = require(script.Parent.TradeService)
	local other = TradeService.partnerOf(player, tradeId :: string)
	if other == nil then
		return { ok = false, err = "not_in_trade" }
	end

	local itemName = nil
	if phrase.slot == "item" then
		if not Guard.isString(itemId, 64) then
			return { ok = false, err = "item_required" }
		end
		local item = EconomyService.getItem(itemId :: string)
		if item == nil then
			return { ok = false, err = "unknown_item" }
		end
		itemName = item.name
	end

	-- rendered from config, never from anything the player typed
	local text = QuickChatConfig.render(phrase, itemName)
	local payload = {
		tradeId = tradeId,
		fromUserId = player.UserId,
		fromName = player.Name,
		text = text,
		at = os.time(),
	}
	Net.fireClient("TradeChat", player, payload)
	local partner = Players:GetPlayerByUserId(other)
	if partner then
		Net.fireClient("TradeChat", partner, payload)
	end
	return { ok = true }
end

--------------------------------------------------------------------------------
-- Group chat
--------------------------------------------------------------------------------

-- Filter ONCE per reader. The same message is legitimately different text for
-- different viewers (age, settings), so a single pre-rendered broadcast would
-- be wrong for somebody every time.
local function deliverToPlayer(reader: Player, groupId: string, entry: any)
	local text = entry.text
	if entry.userId ~= 0 then
		local ok, result = pcall(function()
			return TextService:FilterStringAsync(entry.rawText, entry.userId)
		end)
		if ok and result then
			local ok2, forReader = pcall(function()
				return result:GetChatForUserAsync(reader.UserId)
			end)
			-- an EMPTY result is not "allowed through": Lua treats "" as
			-- truthy, so `x or fallback` would happily deliver a blank line.
			-- Test the length, not the value.
			if ok2 and typeof(forReader) == "string" and #forReader > 0 then
				text = forReader
			elseif RunService:IsStudio() then
				-- STUDIO ONLY. The filter backend is not available for a local
				-- test player: FilterStringAsync succeeds but
				-- GetChatForUserAsync returns "", so every message would be
				-- silently dropped and group chat could not be tested at all.
				-- Gated on IsStudio so a live server can never take this path.
				text = entry.rawText
			else
				return -- nothing readable for this viewer; send them nothing
			end
		else
			-- filtering failed: drop it rather than deliver unfiltered text
			return
		end
	end
	Net.fireClient("GroupChat", reader, {
		id = entry.id,
		groupId = groupId,
		userId = entry.userId,
		name = entry.name,
		text = text,
		at = entry.at,
	})
end

local function membersHere(groupId: string): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		local profile = DataService.getProfile(player)
		if profile and profile.SyndicateId == groupId then
			table.insert(out, player)
		end
	end
	return out
end

local function sendGroupChat(player: Player, message: any): any
	local profile = DataService.getProfile(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local groupId = profile.SyndicateId
	if groupId == "" then
		return { ok = false, err = "not_in_syndicate" }
	end
	if not Guard.isString(message, GROUP_MAX_LENGTH) then
		return { ok = false, err = "bad_args" }
	end
	local clean = (message :: string):gsub("^%s+", ""):gsub("%s+$", "")
	if #clean == 0 then
		return { ok = false, err = "empty" }
	end
	local entry = {
		id = nextChatId(),
		userId = player.UserId,
		name = player.Name,
		rawText = clean,
		text = clean,
		at = os.time(),
	}
	push(groupId, entry)
	for _, reader in membersHere(groupId) do
		deliverToPlayer(reader, groupId, entry)
	end
	-- other servers get the raw text and filter it for their own readers
	StoreAdapters.publish(GROUP_TOPIC, {
		id = entry.id,
		groupId = groupId,
		userId = player.UserId,
		name = player.Name,
		rawText = clean,
		at = entry.at,
		from = game.JobId,
	})
	AnalyticsService.log("group_chat", { id = groupId, by = player.UserId })
	return { ok = true }
end

-- Recent context when the panel opens. Filtered for THIS reader, same as live
-- messages, so nothing bypasses the filter by arriving through history.
local function groupHistory(player: Player): any
	local profile = DataService.getProfile(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local groupId = profile.SyndicateId
	if groupId == "" then
		return { ok = false, err = "not_in_syndicate" }
	end
	for _, entry in (history[groupId] or {}) do
		deliverToPlayer(player, groupId, entry)
	end
	return { ok = true }
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function ChatService.Init() end

function ChatService.Start()
	Net.bindFunction("TradeQuickChat", function(player, tradeId, phraseId, itemId)
		return tradeQuickChat(player, tradeId, phraseId, itemId)
	end)
	Net.bindFunction("SendGroupChat", function(player, message)
		return sendGroupChat(player, message)
	end)
	Net.bindFunction("GetGroupChat", function(player)
		return groupHistory(player)
	end)

	StoreAdapters.subscribe(GROUP_TOPIC, function(payload)
		-- ignore our own echo: this server already delivered and buffered it
		if payload == nil or payload.from == game.JobId or payload.groupId == nil then
			return
		end
		local entry = {
			-- keep the publisher's id so the same message is the same message
			-- on every server; only mint one if an older server omitted it
			id = payload.id or nextChatId(),
			userId = payload.userId,
			name = payload.name,
			rawText = payload.rawText,
			text = payload.rawText,
			at = payload.at,
		}
		push(payload.groupId, entry)
		for _, reader in membersHere(payload.groupId) do
			deliverToPlayer(reader, payload.groupId, entry)
		end
	end)

end

return ChatService
