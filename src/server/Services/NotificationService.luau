--!strict
-- NotificationService: player notifications that survive being offline.
--   * notify(userId, text): online on this server -> instant toast;
--     online elsewhere -> cross-server ping; offline -> durable queue
--     (own DataStore, append-only like the mailbox) replayed at next login,
--     PLUS a real Roblox push (OS/app notification) via Open Cloud so an
--     opted-in player finds out even without opening the game.
--   * Push requires one-time setup outside this codebase: see PushConfig.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local PushConfig = require(ReplicatedStorage.Shared.Config.PushConfig)

local Net = require(script.Parent.Parent.Net)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local DataService = require(script.Parent.DataService)

local MAX_QUEUED = 20

local NotificationService = {}

local queueStore: any -- DataStore "Notifications_v1", key n_<userId> -> {text...}

local function queueKey(userId: number): string
	return "n_" .. tostring(userId)
end

local function pushLocal(userId: number, text: string): boolean
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Net.fireClient("Notify", player, text)
		return true
	end
	return false
end

-- Real Roblox push (OS/app notification) via Open Cloud. Best-effort: a
-- player who hasn't opted in via ExperienceNotificationService simply never
-- sees it (Roblox suppresses delivery on their end — we don't check opt-in
-- status ourselves). Silent no-op until PushConfig.Enabled + MessageId are set.
local function sendPush(userId: number, text: string)
	if not PushConfig.Enabled or PushConfig.MessageId == "" then
		return
	end
	task.spawn(function()
		local gotSecret, apiKey = pcall(function()
			return HttpService:GetSecret(PushConfig.SecretName)
		end)
		if not gotSecret or apiKey == nil then
			warn("[Notification] push skipped: secret '" .. PushConfig.SecretName .. "' not configured")
			return
		end
		local universeId = game.GameId
		local body = HttpService:JSONEncode({
			source = { universe = "universes/" .. tostring(universeId) },
			payload = {
				type = "MOMENT",
				message_id = PushConfig.MessageId,
				parameters = { message = { string_value = text:sub(1, 200) } },
			},
		})
		local ok, response = pcall(function()
			return HttpService:RequestAsync({
				Url = ("https://apis.roblox.com/cloud/v2/users/%d/notifications"):format(userId),
				Method = "POST",
				Headers = { ["x-api-key"] = apiKey, ["Content-Type"] = "application/json" },
				Body = body,
			})
		end)
		if not ok then
			warn("[Notification] push request failed: " .. tostring(response))
		elseif not response.Success then
			warn(("[Notification] push rejected (%s): %s"):format(tostring(response.StatusCode), tostring(response.Body)))
		end
	end)
end

function NotificationService.notify(userId: number, text: string)
	if userId < 0 then
		return -- market bot: no toasts, no queue, no push
	end
	if pushLocal(userId, text) then
		return
	end
	-- not on this server: try other servers, queue durably in case they're
	-- fully offline everywhere, AND fire a real push (harmless if they're
	-- actually online on another server — just an extra ping they can ignore).
	StoreAdapters.publish(EconomyConfig.NotifyBroadcastTopic, { userId = userId, text = text })
	sendPush(userId, text)
	task.spawn(function()
		pcall(function()
			queueStore:UpdateAsync(queueKey(userId), function(old)
				old = old or {}
				table.insert(old, { text = text, t = os.time() })
				while #old > MAX_QUEUED do
					table.remove(old, 1)
				end
				return old
			end)
		end)
	end)
end

function NotificationService.Init()
	StoreAdapters.init()
	queueStore = StoreAdapters.dataStore("Notifications_v2")
end

function NotificationService.Start()
	-- replay queued notifications at login, then clear
	DataService.ProfileLoaded:Connect(function(player, _profile)
		task.spawn(function()
			local queued
			pcall(function()
				queued = queueStore:GetAsync(queueKey(player.UserId))
			end)
			if queued and #queued > 0 then
				for _, entry in queued do
					Net.fireClient("Notify", player, entry.text)
				end
				pcall(function()
					queueStore:UpdateAsync(queueKey(player.UserId), function()
						return {}
					end)
				end)
			end
		end)
	end)

	-- notifications for players on OTHER servers
	StoreAdapters.subscribe(EconomyConfig.NotifyBroadcastTopic, function(payload)
		if type(payload) == "table" and type(payload.userId) == "number" and type(payload.text) == "string" then
			pushLocal(payload.userId, payload.text)
		end
	end)
end

return NotificationService
