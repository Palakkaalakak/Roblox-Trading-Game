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

	-- hydrate (retry fast while profile loads server-side). The server no
	-- longer kicks on a contended/slow load — it waits out the lock and
	-- keeps trying — so this keeps trying too instead of giving up: fast for
	-- the first ~18s (covers the overwhelming majority of joins), then a
	-- slow indefinite fallback so a legitimately delayed load (contended
	-- lock, brief DataStore trouble) still hydrates the moment it succeeds.
	task.spawn(function()
		local function hydrateOnce(): boolean
			local result = Net.invoke("GetInventory")
			if result.ok then
				InventoryController.inventory:set(result.inventory, true)
				InventoryController.gems:set(result.gems)
				return true
			end
			return false
		end

		local hydrated = false
		for _ = 1, 60 do
			hydrated = hydrateOnce()
			if hydrated then
				break
			end
			task.wait(0.3)
		end
		if not hydrated then
			warn("[Inventory] still waiting on profile load — retrying slowly")
			repeat
				task.wait(3)
				hydrated = hydrateOnce()
			until hydrated
		end
		task.wait(1)
		hydrateOnce()
	end)
end

return InventoryController
