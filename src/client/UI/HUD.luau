--!strict
-- HUD wiring: finds StarterGui-built nodes (TradingHUD) and connects them.
-- Layout/styling belongs to the instances in StarterGui — edit there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local TradeController = require(script.Parent.Parent.Controllers.TradeController)

local HUD = {}

function HUD.wire(
	gui: ScreenGui,
	toggles: {
		inventory: () -> (),
		picker: () -> (),
		profile: (() -> ())?,
		shop: (() -> ())?,
		syndicate: (() -> ())?,
		rewardsPanel: (() -> ())?,
	}
)
	local gemPill = gui:WaitForChild("GemPill") :: Frame
	local gemAmount = gemPill:WaitForChild("Amount") :: TextLabel
	State.Observe(InventoryController.gems, function(gems)
		gemAmount.Text = tostring(gems)
	end)

	local invButton = gui:WaitForChild("InventoryButton") :: ImageButton
	invButton.Activated:Connect(toggles.inventory)
	local tradeButton = gui:WaitForChild("TradeButton") :: ImageButton
	tradeButton.Activated:Connect(toggles.picker)

	local profileButton = gui:WaitForChild("ProfileButton") :: ImageButton
	if toggles.profile then
		profileButton.Activated:Connect(toggles.profile)
	end

	local shopButton = gui:WaitForChild("ShopButton") :: ImageButton
	if toggles.shop then
		shopButton.Activated:Connect(toggles.shop)
	end

	-- FreeGemsButton lives in the ignore-inset overlay now, not this
	-- ScreenGui -- wired directly in init.client.luau instead.

	local syndicateButton = gui:WaitForChild("SyndicateButton") :: ImageButton
	if toggles.syndicate then
		syndicateButton.Activated:Connect(toggles.syndicate)
	end

	local rewardsButton = gui:WaitForChild("RewardsButton") :: ImageButton
	if toggles.rewardsPanel then
		rewardsButton.Activated:Connect(toggles.rewardsPanel)
	end

	-- AFK has no sidebar button: the sign standing in the plaza (AfkPrompt)
	-- opens it, same as the trade board pillar and event NPC.

	local debugBtn = gui:WaitForChild("DebugGemsButton") :: ImageButton
	if DebugConfig.GiveGemsEnabled then
		debugBtn.Activated:Connect(function()
			task.spawn(function()
				Net.invoke("DebugGiveGems")
			end)
		end)
	else
		debugBtn.Visible = false
	end

	-- toasts: clone the editable template
	local toastArea = gui:WaitForChild("ToastArea") :: Frame
	local toastTemplate = toastArea:WaitForChild("ToastTemplate") :: Frame

	-- Toasts must sit ABOVE every panel a player might have open (Board, Shop,
	-- Conversion, etc.), which all live in ScreenGuis with a higher DisplayOrder
	-- than this HUD gui (10 vs their 20+) -- so a toast fired while any panel was
	-- open rendered BEHIND it. Lift the toast area into its own top ScreenGui
	-- instead of touching every panel's order.
	local toastOverlay = Instance.new("ScreenGui")
	toastOverlay.Name = "ToastOverlay"
	toastOverlay.ResetOnSpawn = false
	toastOverlay.IgnoreGuiInset = true
	toastOverlay.DisplayOrder = 150 -- above every panel (20s) and the first-join takeover (100)
	toastOverlay.Parent = gui.Parent
	toastArea.Parent = toastOverlay

	local function toast(text: string, color: Color3)
		local t = toastTemplate:Clone()
		t.Name = "Toast"
		t.Visible = true
		-- flat colored text, no card: a background competes with whatever panel
		-- is behind it, and a toast is meant to be read at a glance, not framed.
		t.BackgroundTransparency = 1
		for _, d in t:GetDescendants() do
			if d:IsA("UIStroke") then
				d.Transparency = 1
			elseif d:IsA("ImageLabel") or d:IsA("Frame") then
				d.BackgroundTransparency = 1
			end
		end
		local textLabel = t:WaitForChild("Text") :: TextLabel
		textLabel.Text = text
		textLabel.TextColor3 = color
		-- a plain color can wash out against a bright background with no card
		-- behind it -- a dark outline keeps it readable over anything.
		local outline = textLabel:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
		outline.Color = Color3.new(0, 0, 0)
		outline.Thickness = 1.5
		outline.Transparency = 0
		outline.Parent = textLabel
		t.Parent = toastArea
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
