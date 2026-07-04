--!strict
-- Client bootstrap: controllers first (state + remote wiring), then UI.

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

-- UI
local UI = script.UI
local HUD = require(UI.HUD)
local InventoryScreen = require(UI.InventoryScreen)
local TradeScreen = require(UI.TradeScreen)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local hudGui = Instance.new("ScreenGui")
hudGui.Name = "TradingHUD"
hudGui.ResetOnSpawn = false
hudGui.DisplayOrder = 10
hudGui.Parent = playerGui

local modalGui = Instance.new("ScreenGui")
modalGui.Name = "TradingModals"
modalGui.ResetOnSpawn = false
modalGui.DisplayOrder = 20
modalGui.Parent = playerGui

InventoryScreen.build(modalGui)
TradeScreen.build(modalGui)
HUD.build(hudGui, {
	inventory = function()
		InventoryScreen.toggle()
	end,
	picker = function()
		TradeScreen.togglePicker()
	end,
})

print("[Client] trading UI ready")
