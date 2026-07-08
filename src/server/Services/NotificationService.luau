--!strict
-- NotificationService: player notifications that survive being offline.
--   * notify(userId, text): online on this server -> instant toast;
--     online elsewhere -> cross-server ping; offline -> durable queue
--     (own DataStore, append-only like the mailbox) replayed at next login.
--   * Out-of-experience push notifications need Open Cloud (external API
--     key) — out of scope here; the client-side opt-in prompt is wired in
--     init.client so the audience is ready when that ships.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

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

function NotificationService.notify(userId: number, text: string)
	if pushLocal(userId, text) then
		return
	end
	-- try other servers, and queue durably in case they're fully offline
	StoreAdapters.publish(EconomyConfig.NotifyBroadcastTopic, { userId = userId, text = text })
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
	queueStore = StoreAdapters.dataStore("Notifications_v1")
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
