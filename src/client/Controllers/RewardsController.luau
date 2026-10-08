--!strict
-- RewardsController: Community Rewards progress. Gems come live from
-- InventoryController; playtime (the context rate modifiers read) is fetched
-- from the server on join, on a slow timer, and whenever the panel opens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local RewardsConfig = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local Net = require(script.Parent.Parent.Net)
local InventoryController = require(script.Parent.InventoryController)
local EconomyController = require(script.Parent.EconomyController)

local REFRESH_SECONDS = 300

local RewardsController = {}

RewardsController.playSeconds = State.Value(0)
RewardsController.tutorialDone = State.Value(false)
RewardsController.peakWorth = State.Value(0) -- server-persisted high-water mark

-- Total portfolio worth: gems on hand PLUS every held item at its live Est.
-- Value. The bar tracks what a player has built, not just their spendable
-- gems -- a collector sitting on a vault of valuable items but few gems
-- should see real progress, same as someone who cashed everything in.
-- Items with no snapshot yet (not fetched client-side) simply don't count
-- until EconomyController.ensure resolves them -- it re-fires this Computed
-- when stats arrive, so the total catches up rather than staying wrong.
local function portfolioWorth(): number
	local total = InventoryController.gems:get()
	local inventory = InventoryController.inventory:get()
	local stats = EconomyController.stats:get()
	local missing = {}
	for itemId, count in inventory do
		local snap = stats[itemId]
		if snap and snap.value and snap.value.value then
			total += snap.value.value * count
		else
			table.insert(missing, itemId)
		end
	end
	if #missing > 0 then
		EconomyController.ensure(missing)
	end
	return total
end

RewardsController.status = State.Computed(function()
	local peak = math.max(RewardsController.peakWorth:get(), portfolioWorth())
	return RewardsConfig.status(InventoryController.gems:get(), peak, {
		playSeconds = RewardsController.playSeconds:get(),
		tutorialDone = RewardsController.tutorialDone:get(),
	})
end, {
	InventoryController.gems,
	InventoryController.inventory,
	EconomyController.stats,
	RewardsController.playSeconds,
	RewardsController.tutorialDone,
	RewardsController.peakWorth,
})

function RewardsController.refresh(): boolean
	local result = Net.invoke("GetRewardsStatus", portfolioWorth())
	if result.ok and result.status then
		RewardsController.playSeconds:set(result.status.playSeconds or 0)
		RewardsController.peakWorth:set(math.max(RewardsController.peakWorth:get(), result.status.peakWorth or 0))
		-- one-way latch: once true, a later fetch racing a settling trade must
		-- never flip it back to false and un-earn the milestone client-side
		if result.status.tutorialDone then
			RewardsController.tutorialDone:set(true)
		end
		return true
	end
	return false
end

function RewardsController.Init() end

function RewardsController.Start()
	task.spawn(function()
		for _ = 1, 60 do
			if RewardsController.refresh() then
				break
			end
			task.wait(0.5)
		end
		while true do
			task.wait(REFRESH_SECONDS)
			RewardsController.refresh()
		end
	end)
end

return RewardsController
