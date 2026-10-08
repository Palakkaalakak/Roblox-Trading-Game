--!strict
-- QuestController: current quest + rank + feature unlocks for the Quests
-- panel and for gating rank-locked entry points client-side (server still
-- re-checks everything -- this is UX, not the security boundary).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local Net = require(script.Parent.Parent.Net)

local RankConfig = require(game:GetService("ReplicatedStorage").Shared.Config.RankConfig)
local QuestController = {}

QuestController.status = State.Value(nil :: any)

function QuestController.refresh(): boolean
	local result = Net.invoke("GetQuestStatus")
	if result.ok then
		QuestController.status:set(result.status)
		return true
	end
	return false
end

function QuestController.hasUnlock(key: string): boolean
	local status = QuestController.status:get()
	return status ~= nil and RankConfig.unlocked(status.completed, key)
end

function QuestController.Init() end

function QuestController.Start()
	task.spawn(function()
		for _ = 1, 60 do
			if QuestController.refresh() then
				break
			end
			task.wait(0.5)
		end
		-- No push event for "a quest completed" (most completions don't cross a
		-- rank/title boundary, so the Notify toast doesn't fire for them) --
		-- poll slowly so progress doesn't go stale for a whole session. Cheap:
		-- one small remote call every 20s.
		while true do
			task.wait(20)
			QuestController.refresh()
		end
	end)
end

return QuestController
