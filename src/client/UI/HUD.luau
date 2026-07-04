--!strict
-- HUD: gem pill (live), Inventory/Trade buttons, starter-pool banner, toasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local TradeController = require(script.Parent.Parent.Controllers.TradeController)

local create = Components.create

local HUD = {}

function HUD.build(gui: ScreenGui, toggles: { inventory: () -> (), picker: () -> () })
	-- gem pill
	local gemPill = Components.panel({
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(140, 36),
	})
	local gemLabel = Components.label({
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Text = "💎 0",
		TextSize = 16,
		TextColor3 = Theme.Gem,
	})
	gemLabel.Parent = gemPill
	gemPill.Parent = gui

	State.Observe(InventoryController.gems, function(gems)
		gemLabel.Text = "💎 " .. tostring(gems)
	end)

	-- buttons
	local invButton = Components.button({
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.fromOffset(140, 34),
		Text = "🎒 Inventory",
		BackgroundColor3 = Theme.BgLight,
	}, toggles.inventory)
	invButton.Parent = gui

	local tradeButton = Components.button({
		Position = UDim2.fromOffset(12, 96),
		Size = UDim2.fromOffset(140, 34),
		Text = "🔁 Trade",
	}, toggles.picker)
	tradeButton.Parent = gui

	-- pool banner (top center)
	local banner = Components.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(620, 30),
	})
	local bannerLabel = Components.label({
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = "Starter pool: loading…",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.TextDim,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	bannerLabel.Parent = banner
	banner.Parent = gui

	State.Observe(EconomyController.pool, function(pool)
		if pool == nil then
			return
		end
		local names = {}
		for _, snap in pool.items do
			table.insert(names, snap.name)
		end
		bannerLabel.Text = ("Starter pool #%d: %s"):format(pool.seq, table.concat(names, " · "))
	end)

	-- toasts (settle/abort/errors)
	local toastHolder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(420, 120),
		BackgroundTransparency = 1,
	})
	create("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
	}).Parent = toastHolder
	toastHolder.Parent = gui

	local function toast(text: string, color: Color3)
		local t = Components.panel({ Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Bg })
		local l = Components.label({
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.fromOffset(8, 0),
			Text = text,
			TextSize = 13,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		l.Parent = t
		t.Parent = toastHolder
		task.delay(4, function()
			t:Destroy()
		end)
	end
	HUD.toast = toast

	TradeController.settled:Connect(function(_tradeId, items, gems)
		local parts = {}
		for itemId, count in items do
			table.insert(parts, ("%dx %s"):format(count, EconomyController.nameFor(itemId)))
		end
		if gems > 0 then
			table.insert(parts, gems .. " gems")
		end
		toast("Trade complete! Received: " .. (#parts > 0 and table.concat(parts, ", ") or "nothing"), Theme.Good)
	end)

	TradeController.aborted:Connect(function(_tradeId, reason)
		toast("Trade ended: " .. tostring(reason), Theme.Warn)
	end)

	TradeController.actionError:Connect(function(code)
		toast("Action failed: " .. tostring(code), Theme.Bad)
	end)
end

return HUD
