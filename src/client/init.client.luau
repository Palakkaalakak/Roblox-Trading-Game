--!strict
-- Client bootstrap: controllers first (state + remote wiring), then wire the
-- StarterGui-built GUI (TradingHUD / TradingModals — built by GuiBuilder,
-- editable in Studio).

local Players = game:GetService("Players")

local Controllers = script.Controllers
local InventoryController = require(Controllers.InventoryController)
local EconomyController = require(Controllers.EconomyController)
local TradeController = require(Controllers.TradeController)

InventoryController.Init()
EconomyController.Init()
TradeController.Init()

InventoryController.Start()
EconomyController.Start()
TradeController.Start()

local UI = script.UI
local Components = require(UI.Components)
local HUD = require(UI.HUD)
local InventoryScreen = require(UI.InventoryScreen)
local TradeScreen = require(UI.TradeScreen)
local StoreScreen = require(UI.StoreScreen)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local hudGui = playerGui:WaitForChild("TradingHUD") :: ScreenGui
local modalGui = playerGui:WaitForChild("TradingModals") :: ScreenGui

local tooltip = Components.wireTooltip(modalGui)
InventoryScreen.wire(modalGui, tooltip)
TradeScreen.wire(modalGui, tooltip)
HUD.wire(hudGui, {
	inventory = function()
		InventoryScreen.toggle()
	end,
	picker = function()
		TradeScreen.togglePicker()
	end,
})
StoreScreen.wire(modalGui, tooltip, function(text, color)
	if HUD.toast then
		HUD.toast(text, color)
	end
end)

-- store NPC: walking up + triggering its prompt opens the shop
local ProximityPromptService = game:GetService("ProximityPromptService")
local StoreConfig = require(game:GetService("ReplicatedStorage").Shared.Config.StoreConfig)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == StoreConfig.PromptName then
		StoreScreen.open()
	end
end)

print("[Client] trading UI ready")
