--!strict
-- InventoryScreen: scrolling grid of owned items, each tile with live
-- value/demand/supply/RAP (N/A-aware). Rebuilds reactively from controller state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)

local create = Components.create

local InventoryScreen = {}

function InventoryScreen.build(gui: ScreenGui)
	local panel = Components.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(600, 420),
		Visible = false,
	})
	panel.Parent = gui

	local title = Components.label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -60, 0, 24),
		Text = "🎒 Inventory",
		TextSize = 18,
	})
	title.Parent = panel

	local closeBtn = Components.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "✕",
		BackgroundColor3 = Theme.Bad,
	}, function()
		panel.Visible = false
	end)
	closeBtn.Parent = panel

	local scroll = create("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(1, -24, 1, -56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	})
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(126, 132),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.Name,
	}).Parent = scroll
	scroll.Parent = panel

	local tiles: { [string]: { frame: Frame, update: (any?, number?) -> () } } = {}

	local function refresh()
		local inventory = InventoryController.inventory:get()
		local stats = EconomyController.stats:get()

		-- remove tiles for items no longer owned
		for itemId, tile in tiles do
			if inventory[itemId] == nil then
				tile.frame:Destroy()
				tiles[itemId] = nil
			end
		end
		-- add/update tiles
		local wanted = {}
		for itemId, count in inventory do
			table.insert(wanted, itemId)
			local tile = tiles[itemId]
			if tile == nil then
				local frame, update = Components.itemTile(itemId)
				frame.Parent = scroll
				tile = { frame = frame, update = update }
				tiles[itemId] = tile
			end
			tile.update(stats[itemId], count)
		end
		EconomyController.ensure(wanted)
	end

	State.Observe(InventoryController.inventory, refresh)
	State.Observe(EconomyController.stats, refresh)

	function InventoryScreen.toggle()
		panel.Visible = not panel.Visible
	end

	return panel
end

return InventoryScreen
