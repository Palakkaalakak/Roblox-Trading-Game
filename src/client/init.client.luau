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
local Theme = require(UI.Theme)
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
local BoothScreen = require(UI.BoothScreen)
local BoothPanel = require(UI.BoothPanel)
local FreeGemsScreen = require(UI.FreeGemsScreen)
local WorldLeaderboards = require(UI.WorldLeaderboards)
local SyndicateScreen = require(UI.SyndicateScreen)
local AdminPanel = require(UI.AdminPanel)
local AfkScreen = require(UI.AfkScreen)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local hudGui = playerGui:WaitForChild("TradingHUD") :: ScreenGui
local modalGui = playerGui:WaitForChild("TradingModals") :: ScreenGui

local tooltip = Components.wireTooltip(modalGui)
Components.wireFitScales(modalGui) -- shrink every panel to fit this device's viewport
-- every scrolling list gets a left/top gutter, including ones built at
-- runtime -- without it a row's border is clipped against the scroll edge
Components.autoGutter(modalGui)
Components.autoGutter(hudGui)
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
FreeGemsScreen.wire(modalGui, toast)
AfkScreen.wire(modalGui, toast)

-- Rolls, Shop and Syndicate are wired on FIRST OPEN, not at join. Their panels
-- are deliberately absent from StarterGui (see GuiBuilder.ensurePanel), so
-- wiring them here would WaitForChild forever. Every entry point below goes
-- through ensureLazy, which builds the panel into the live PlayerGui and wires
-- the screen exactly once.
local GuiBuilder = require(game:GetService("ReplicatedStorage").Shared.GuiBuilder)
local lazyWired: { [string]: boolean } = {}
local function ensureLazy(panelName: string, wireScreen: () -> ())
	if lazyWired[panelName] then
		return
	end
	lazyWired[panelName] = true
	GuiBuilder.ensurePanel(modalGui, panelName)
	wireScreen()
end

local function ensureRolls()
	ensureLazy("RollsPanel", function()
		RollsScreen.wire(modalGui, tooltip, toast)
	end)
end
local function ensureShop()
	ensureLazy("ShopPanel", function()
		ShopScreen.wire(modalGui, tooltip, toast)
	end)
end
local function ensureSyndicate()
	ensureLazy("SyndicatePanel", function()
		SyndicateScreen.wire(modalGui, toast, tooltip)
	end)
end

-- "Get boosts" on the trade board has to build the shop before opening it --
-- ShopScreen.openAt only exists once wire() has run.
BoardScreen.shopOpener = function(section: string)
	ensureShop()
	local openAt = (ShopScreen :: any).openAt
	if openAt then
		openAt(section)
	end
end
WorldLeaderboards.start() -- fills the physical boards standing in the world
AdminPanel.wire() -- own standalone ScreenGui, not nested in modalGui/hudGui
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
		ensureShop()
		ShopScreen.toggle()
	end,
	freeGems = function()
		FreeGemsScreen.toggle()
	end,
	syndicate = function()
		ensureSyndicate()
		SyndicateScreen.toggle()
	end,
	afk = function()
		AfkScreen.toggle()
	end,
})

-- world prompts: store NPC / event NPC / rolls NPC / trade board pillar
local ProximityPromptService = game:GetService("ProximityPromptService")
local StoreConfig = require(game:GetService("ReplicatedStorage").Shared.Config.StoreConfig)
local RollConfig = require(game:GetService("ReplicatedStorage").Shared.Config.RollConfig)
local BoothConfig = require(game:GetService("ReplicatedStorage").Shared.Config.BoothConfig)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == StoreConfig.PromptName then
		StoreScreen.open()
	elseif prompt.Name == "EventPrompt" then
		EventsScreen.open()
	elseif prompt.Name == RollConfig.PromptName then
		ensureRolls()
		RollsScreen.open()
	elseif prompt.Name == "BoardPrompt" then
		BoardScreen.open()
	elseif prompt.Name == BoothConfig.PromptName then
		BoothScreen.interact(prompt)
	end
end)

-- always-on market ticker (live bot + player trades)
ActivityFeed.start()
-- plaza storefronts: paints a face on every placed booth
BoothPanel.build(modalGui, toast, tooltip)
BoothScreen.toast = toast
BoothScreen.setBrowseHandler(BoothPanel.open)
BoothScreen.start()

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
