--!strict
-- ProfileController: fetch/cache the viewed profile + drive own-profile edits.
-- Server is authoritative; this only requests + reflects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local Net = require(script.Parent.Parent.Net)

local ProfileController = {}
ProfileController.viewed = State.Value(nil :: any) -- PublicProfile or nil (loading)
ProfileController.viewingUserId = State.Value(0)

local localUserId = Players.LocalPlayer.UserId
ProfileController.localUserId = localUserId

local function fetch(userId: number)
	task.spawn(function()
		local res = Net.invoke("GetProfile", userId)
		if ProfileController.viewingUserId:get() ~= userId then
			return -- user navigated away
		end
		ProfileController.viewed:set(res.ok and res.profile or false, true)
	end)
end

function ProfileController.openUser(userId: number)
	ProfileController.viewingUserId:set(userId)
	ProfileController.viewed:set(nil)
	fetch(userId)
end

function ProfileController.refresh()
	fetch(ProfileController.viewingUserId:get())
end

function ProfileController.setShowcase(itemIds: { string })
	task.spawn(function()
		Net.invoke("SetShowcase", itemIds)
		ProfileController.refresh()
	end)
end

function ProfileController.setStatus(text: string)
	task.spawn(function()
		Net.invoke("SetStatus", text)
		ProfileController.refresh()
	end)
end

function ProfileController.setStatChips(keys: { string })
	task.spawn(function()
		Net.invoke("SetStatChips", keys)
		ProfileController.refresh()
	end)
end

function ProfileController.setPrivacy(hideValue: boolean, hideShowcase: boolean)
	task.spawn(function()
		Net.invoke("SetPrivacy", { hideValue = hideValue, hideShowcase = hideShowcase })
		ProfileController.refresh()
	end)
end

function ProfileController.Init() end
function ProfileController.Start() end

return ProfileController
