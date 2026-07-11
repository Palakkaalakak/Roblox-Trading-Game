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
	local title = panel:WaitForChild("Title") :: TextLabel

	local function rotationText(rotatesAt: number?): string
		if rotatesAt == nil then
			return "✨ Limited Store"
		end
		local remaining = math.max(0, rotatesAt - workspace:GetServerTimeNow())
		local h = math.floor(remaining / 3600)
		local m = math.ceil((remaining % 3600) / 60)
		local when = h > 0 and ("%dh %dm"):format(h, m) or ("%dm"):format(m)
		return "✨ Limited Store — new stock in " .. when
	end

	local closeButton = panel:WaitForChild("CloseButton") :: TextButton
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)

	local tiles: { [string]: any } = {}
	local storeItemIds: { [string]: boolean } = {}
	local buying = false
	local lastItems: { any }? = nil -- last listing; rendered instantly on open

	local function renderEntry(tile: any, entry: any)
		local frame = tile.frame
		local limit = entry.limit or 1
		local purchased = entry.purchased or 0
		local maxed = purchased >= limit
		local soldOut = entry.remaining <= 0

		frame.LayoutOrder = entry.order
		local limitText = "Can buy " .. tostring(limit) .. " max";
		(frame:WaitForChild("ItemName") :: TextLabel).Text = entry.name;
		(frame:WaitForChild("StockLabel") :: TextLabel).Text = ("%d/%d left"):format(entry.remaining, entry.totalSupply);
		(frame:WaitForChild("PriceLabel") :: TextLabel).Text = "💎 " .. tostring(entry.price);
		(frame:WaitForChild("LimitLabel") :: TextLabel).Text = limitText
		Components.setIcon(frame:WaitForChild("Icon") :: ImageLabel, entry)

		-- max-reached takes visual priority over sold-out (it's the player's wall)
		local maxOverlay = frame:WaitForChild("MaxReachedOverlay") :: Frame
		local soldOverlay = frame:WaitForChild("SoldOutOverlay") :: Frame
		maxOverlay.Visible = maxed;
		(maxOverlay:WaitForChild("Sub") :: TextLabel).Text = limitText
		soldOverlay.Visible = soldOut and not maxed

		local buyBtn = frame:WaitForChild("BuyButton") :: TextButton
		buyBtn.Visible = not soldOut and not maxed
	end

	local refresh -- forward decl (buy handler refreshes)

	local function renderList(items: { any }, rotatesAt: number?)
		title.Text = rotationText(rotatesAt)
		-- hide tiles for items that rotated off the shelf
		local listed: { [string]: boolean } = {}
		for _, entry in items do
			listed[entry.itemId] = true
		end
		for itemId, tile in tiles do
			tile.frame.Visible = listed[itemId] == true
		end

		local allSoldOut = true
		for order, entry in items do
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
					elseif buyResult.err == "buy_limit" then
						toast(("Max buy limit reached! Can buy %d max."):format(buyResult.limit or 1), Theme.Warn)
					elseif buyResult.err == "out_of_stock" then
						toast(entry.name .. " is sold out!", Theme.Warn)
					elseif buyResult.err == "insufficient_gems" then
						toast("Not enough gems!", Theme.Bad)
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
	end

	local lastRotatesAt: number? = nil

	-- one GetStore in flight at a time; bursts collapse into one trailing call
	-- (buying fast used to trip the rate limit and blank the shelf)
	local fetching = false
	local fetchQueued = false
	refresh = function()
		if fetching then
			fetchQueued = true
			return
		end
		fetching = true
		task.spawn(function()
			repeat
				fetchQueued = false
				local result = Net.invoke("GetStore")
				if result.ok then
					lastItems = result.items
					lastRotatesAt = result.rotatesAt
					renderList(result.items, result.rotatesAt)
				end
				if fetchQueued then
					task.wait(0.4)
				end
			until not fetchQueued
			fetching = false
		end)
	end

	function StoreScreen.open()
		Components.closeOtherPanels(panel)
		panel.Visible = true
		if lastItems then
			renderList(lastItems, lastRotatesAt) -- instant paint from cache
		end
		refresh()
	end

	function StoreScreen.toggle()
		if panel.Visible then
			panel.Visible = false
		else
			StoreScreen.open()
		end
	end

	-- pre-fetch the listing shortly after join so the FIRST open paints instantly
	task.spawn(function()
		task.wait(2)
		if lastItems == nil then
			local result = Net.invoke("GetStore")
			if result.ok then
				lastItems = result.items
				lastRotatesAt = result.rotatesAt
			end
		end
	end)

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
