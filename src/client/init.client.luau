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

print("[Client] trading UI ready")
