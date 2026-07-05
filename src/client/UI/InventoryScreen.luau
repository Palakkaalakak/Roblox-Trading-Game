--!strict
-- Inventory browse wiring: clones the editable ItemTile template per owned
-- item and keeps it live. Panel + template live in StarterGui.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local Components = require(script.Parent.Components)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)

local InventoryScreen = {}

function InventoryScreen.wire(gui: ScreenGui, tooltip: any)
	local panel = gui:WaitForChild("InventoryPanel") :: Frame
	local grid = panel:WaitForChild("ItemGrid") :: ScrollingFrame
	local template = grid:WaitForChild("ItemTile") :: Frame

	local closeButton = panel:WaitForChild("CloseButton") :: TextButton
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)

	local tiles: { [string]: Frame } = {}

	local function refresh()
		local inventory = InventoryController.inventory:get()
		local stats = EconomyController.stats:get()

		for itemId, tile in tiles do
			if inventory[itemId] == nil then
				tile:Destroy()
				tiles[itemId] = nil
			end
		end

		local wanted = {}
		for itemId, count in inventory do
			table.insert(wanted, itemId)
			local tile = tiles[itemId]
			if tile == nil then
				tile = template:Clone()
				tile.Name = itemId
				tile.Visible = true
				tile.Parent = grid
				tiles[itemId] = tile
				tooltip.attach(tile, function()
					return EconomyController.get(itemId), InventoryController.inventory:get()[itemId]
				end)
			end
			Components.fillItemTile(tile, stats[itemId], count)
		end
		EconomyController.ensure(wanted)
	end

	State.Observe(InventoryController.inventory, refresh)
	State.Observe(EconomyController.stats, refresh)

	function InventoryScreen.toggle()
		panel.Visible = not panel.Visible
	end
end

return InventoryScreen
