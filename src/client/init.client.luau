--!strict
-- Client bootstrap: controllers first (state + remote wiring), then wire the
-- StarterGui-built GUI (TradingHUD / TradingModals — built by GuiBuilder,
-- editable in Studio).

local Players = game:GetService("Players")

local Controllers = script.Controllers
local InventoryController = require(Controllers.InventoryController)
local EconomyController = require(Controllers.EconomyController)
local TradeController = require(Controllers.TradeController)
local ProfileController = require(Controllers.ProfileController)
local NotificationController = require(Controllers.NotificationController)

InventoryController.Init()
EconomyController.Init()
TradeController.Init()
ProfileController.Init()
NotificationController.Init()

InventoryController.Start()
EconomyController.Start()
TradeController.Start()
ProfileController.Start()
NotificationController.Start()

local UI = script.UI
local Components = require(UI.Components)
local HUD = require(UI.HUD)
local InventoryScreen = require(UI.InventoryScreen)
local TradeScreen = require(UI.TradeScreen)
local StoreScreen = require(UI.StoreScreen)
local EventsScreen = require(UI.EventsScreen)
local BoardScreen = require(UI.BoardScreen)
local ProfileScreen = require(UI.ProfileScreen)
local RollsScreen = require(UI.RollsScreen)
local ShopScreen = require(UI.ShopScreen)
local ActivityFeed = require(UI.ActivityFeed)
local AdminScreen = require(UI.AdminScreen)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local hudGui = playerGui:WaitForChild("TradingHUD") :: ScreenGui
local modalGui = playerGui:WaitForChild("TradingModals") :: ScreenGui

local tooltip = Components.wireTooltip(modalGui)
Components.wireFitScales(modalGui) -- shrink every panel to fit this device's viewport
local function toast(text: string, color: Color3)
	if HUD.toast then
		HUD.toast(text, color)
	end
end

InventoryScreen.wire(modalGui, tooltip)
TradeScreen.wire(modalGui, tooltip)
StoreScreen.wire(modalGui, tooltip, toast)
EventsScreen.wire(modalGui, tooltip, toast)
BoardScreen.wire(modalGui, tooltip, toast)
ProfileScreen.wire(modalGui, tooltip)
RollsScreen.wire(modalGui, tooltip, toast)
ShopScreen.wire(modalGui, tooltip, toast)
HUD.wire(hudGui, {
	inventory = function()
		InventoryScreen.toggle()
	end,
	picker = function()
		TradeScreen.togglePicker()
	end,
	profile = function()
		ProfileScreen.openBrowser()
	end,
	shop = function()
		ShopScreen.toggle()
	end,
})

-- world prompts: store NPC / event NPC / rolls NPC / trade board pillar
local ProximityPromptService = game:GetService("ProximityPromptService")
local StoreConfig = require(game:GetService("ReplicatedStorage").Shared.Config.StoreConfig)
local RollConfig = require(game:GetService("ReplicatedStorage").Shared.Config.RollConfig)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == StoreConfig.PromptName then
		StoreScreen.open()
	elseif prompt.Name == "EventPrompt" then
		EventsScreen.open()
	elseif prompt.Name == RollConfig.PromptName then
		RollsScreen.open()
	elseif prompt.Name == "BoardPrompt" then
		BoardScreen.open()
	end
end)

-- always-on market ticker (live bot + player trades) and admin bot inspector
ActivityFeed.start()
AdminScreen.start(toast)

-- generic notifications (board pings, event news) as toasts
local Net = require(script.Net)
Net.on("Notify", function(text)
	if type(text) == "string" and HUD.toast then
		HUD.toast(text, Color3.fromRGB(250, 190, 80))
	end
end)

-- generic fallback: ask players who never post a board listing (the more
-- contextual trigger, in BoardScreen) to opt into notifications anyway
task.spawn(function()
	task.wait(15)
	NotificationController.promptOptIn("Enable notifications to hear about trade board activity while you're away!", toast)
end)

print("[Client] trading UI ready")
