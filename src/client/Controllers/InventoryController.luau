--!strict
-- InventoryController: client mirror of the player's inventory + gem balance.
-- Server is authoritative; this only reflects InventoryChanged pushes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local Net = require(script.Parent.Parent.Net)

local InventoryController = {}

InventoryController.inventory = State.Value({} :: { [string]: number })
InventoryController.gems = State.Value(0)

function InventoryController.Init() end

function InventoryController.Start()
	Net.on("InventoryChanged", function(inventory, gems)
		InventoryController.inventory:set(inventory, true) -- table identity may repeat
		InventoryController.gems:set(gems)
	end)

	-- hydrate (retry while profile loads server-side). A second pass a few
	-- seconds later covers the join-time race where the starter grant's push
	-- fires before this client's listeners are live.
	task.spawn(function()
		local hydrated = false
		for _ = 1, 30 do
			local result = Net.invoke("GetInventory")
			if result.ok then
				InventoryController.inventory:set(result.inventory, true)
				InventoryController.gems:set(result.gems)
				hydrated = true
				break
			end
			task.wait(1)
		end
		if not hydrated then
			warn("[Inventory] hydrate failed")
			return
		end
		task.wait(3)
		local result = Net.invoke("GetInventory")
		if result.ok then
			InventoryController.inventory:set(result.inventory, true)
			InventoryController.gems:set(result.gems)
		end
	end)
end

return InventoryController
