--!strict
-- NPC limited store wiring. Panel + tile template live in StarterGui.
-- Opens from the store NPC's ProximityPrompt. Refreshes on open, after every
-- purchase, and when stat pushes touch store items.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Net = require(script.Parent.Parent.Net)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)

local StoreScreen = {}

function StoreScreen.wire(gui: ScreenGui, tooltip: any, toast: (text: string, color: Color3) -> ())
	local panel = gui:WaitForChild("StorePanel") :: Frame
	local grid = panel:WaitForChild("StoreGrid") :: ScrollingFrame
	local template = grid:WaitForChild("StoreTile") :: Frame
	local banner = panel:WaitForChild("OutOfStockBanner") :: TextLabel

	local closeButton = panel:WaitForChild("CloseButton") :: TextButton
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)

	local tiles: { [string]: any } = {}
	local storeItemIds: { [string]: boolean } = {}
	local buying = false

	local function renderEntry(tile: any, entry: any)
		local soldOut = entry.remaining <= 0
		tile.frame.LayoutOrder = entry.order;
		(tile.frame:WaitForChild("ItemName") :: TextLabel).Text = entry.name;
		(tile.frame:WaitForChild("StockLabel") :: TextLabel).Text = ("%d/%d left"):format(entry.remaining, entry.totalSupply);
		(tile.frame:WaitForChild("PriceLabel") :: TextLabel).Text = "💎 " .. tostring(entry.price)
		Components.setIcon(tile.frame:WaitForChild("Icon") :: ImageLabel, entry);
		(tile.frame:WaitForChild("SoldOutOverlay") :: Frame).Visible = soldOut
		local buyBtn = tile.frame:WaitForChild("BuyButton") :: TextButton
		buyBtn.Visible = not soldOut
	end

	local function refresh()
		task.spawn(function()
			local result = Net.invoke("GetStore")
			if not result.ok then
				return
			end
			local allSoldOut = true
			for order, entry in result.items do
				storeItemIds[entry.itemId] = true
				if entry.remaining > 0 then
					allSoldOut = false
				end
				local tile = tiles[entry.itemId]
				if tile == nil then
					local frame = template:Clone()
					frame.Name = entry.itemId
					frame.Visible = true
					frame.Parent = grid
					tile = { frame = frame }
					tiles[entry.itemId] = tile

					local buyBtn = frame:WaitForChild("BuyButton") :: TextButton
					buyBtn.Activated:Connect(function()
						if buying then
							return
						end
						buying = true
						buyBtn.Text = "…"
						local buyResult = Net.invoke("BuyItem", entry.itemId)
						buying = false
						buyBtn.Text = "Buy"
						if buyResult.ok then
							toast(("Bought %s for %d 💎!"):format(entry.name, buyResult.price), Theme.Good)
						else
							toast("Purchase failed: " .. tostring(buyResult.err), Theme.Bad)
						end
						refresh()
					end)
					tooltip.attach(frame, function()
						return EconomyController.get(entry.itemId), InventoryController.inventory:get()[entry.itemId]
					end)
				end
				entry.order = order
				renderEntry(tile, entry)
			end
			banner.Visible = allSoldOut
		end)
	end

	function StoreScreen.open()
		panel.Visible = true
		refresh()
	end

	function StoreScreen.toggle()
		panel.Visible = not panel.Visible
		if panel.Visible then
			refresh()
		end
	end

	-- purchases elsewhere (other players/servers) push stats for store items;
	-- refresh live if we're looking at the shelf
	State.Observe(EconomyController.stats, function()
		if not panel.Visible then
			return
		end
		local snaps = EconomyController.stats:get()
		for itemId in storeItemIds do
			if snaps[itemId] then
				refresh()
				break
			end
		end
	end)
end

return StoreScreen
