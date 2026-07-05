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
	-- Icon button in the style of the StarterGui example: bare pack icon as
	-- an ImageButton (square, scale-sized), caps caption below in golden
	-- yellow with a black stroke.
	local CAPTION_GOLD = Color3.fromRGB(253, 179, 30)
	local function iconButton(image: string, caption: string, position: UDim2, onClick: () -> ())
		local btn = create("ImageButton", {
			Image = image,
			BackgroundTransparency = 1,
			AutoButtonColor = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Size = UDim2.fromScale(0.074, 0.106),
			ScaleType = Enum.ScaleType.Fit,
		})
		create("UIAspectRatioConstraint", { AspectRatio = 1 }).Parent = btn
		create("UICorner", { CornerRadius = UDim.new(0.22, 0) }).Parent = btn

		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1.28, 0),
			Size = UDim2.new(1.4, 0, 0.66, 0),
			Font = Theme.Font,
			Text = caption,
			TextColor3 = CAPTION_GOLD,
			TextScaled = true,
		})
		create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2.5 }).Parent = label
		label.Parent = btn

		btn.Activated:Connect(onClick)
		btn.Parent = gui
		return btn
	end

	-- gem pill (top-left currency readout)
	local gemPill = Components.panel({
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(140, 36),
	})
	local gemPillIcon = create("ImageLabel", {
		Image = Theme.Icons.Gem,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(8, 6),
		ScaleType = Enum.ScaleType.Fit,
	})
	gemPillIcon.Parent = gemPill
	local gemLabel = Components.label({
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -46, 1, 0),
		Text = "0",
		TextSize = 16,
		TextColor3 = Theme.Gem,
	})
	gemLabel.Parent = gemPill
	gemPill.Parent = gui

	State.Observe(InventoryController.gems, function(gems)
		gemLabel.Text = tostring(gems)
	end)

	-- right-edge icon button stack (per the StarterGui example)
	iconButton(Theme.Icons.Inventory, "INVENTORY", UDim2.fromScale(0.955, 0.77), toggles.inventory)
	iconButton(Theme.Icons.Trade, "TRADE", UDim2.fromScale(0.955, 0.57), toggles.picker)

	-- DEBUG ONLY: gem faucet button (remove with DebugConfig for release)
	local DebugConfig = require(game:GetService("ReplicatedStorage").Shared.Config.DebugConfig)
	if DebugConfig.GiveGemsEnabled then
		local Net = require(script.Parent.Parent.Net)
		iconButton(Theme.Icons.Gem, ("+%d (DEBUG)"):format(DebugConfig.GiveGemsAmount), UDim2.fromScale(0.955, 0.37), function()
			task.spawn(function()
				Net.invoke("DebugGiveGems")
			end)
		end)
	end

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
