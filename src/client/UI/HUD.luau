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
		freeGems: (() -> ())?,
		syndicate: (() -> ())?,
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

	-- free gems is its own screen, not a shop tab
	local freeGemsButton = gui:WaitForChild("FreeGemsButton") :: ImageButton
	if toggles.freeGems then
		freeGemsButton.Activated:Connect(toggles.freeGems)
	end

	local syndicateButton = gui:WaitForChild("SyndicateButton") :: ImageButton
	if toggles.syndicate then
		syndicateButton.Activated:Connect(toggles.syndicate)
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

	local function toast(text: string, color: Color3)
		local t = toastTemplate:Clone()
		t.Name = "Toast"
		t.Visible = true
		local textLabel = t:WaitForChild("Text") :: TextLabel
		textLabel.Text = text
		textLabel.TextColor3 = color
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
