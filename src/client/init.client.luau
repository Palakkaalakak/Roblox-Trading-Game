--!strict
-- Client bootstrap: controllers first (state + remote wiring), then wire the
-- StarterGui-built GUI (TradingHUD / TradingModals — built by GuiBuilder,
-- editable in Studio).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local State = require(game:GetService("ReplicatedStorage").Shared.Util.State)

local Controllers = script.Controllers
local InventoryController = require(Controllers.InventoryController)
local EconomyController = require(Controllers.EconomyController)
local TradeController = require(Controllers.TradeController)
local ProfileController = require(Controllers.ProfileController)
local NotificationController = require(Controllers.NotificationController)
local RewardsController = require(Controllers.RewardsController)
local QuestController = require(Controllers.QuestController)
local RankTitleController = require(Controllers.RankTitleController)

InventoryController.Init()
EconomyController.Init()
TradeController.Init()
ProfileController.Init()
NotificationController.Init()
RewardsController.Init()
QuestController.Init()
RankTitleController.Init()

InventoryController.Start()
EconomyController.Start()
TradeController.Start()
ProfileController.Start()
NotificationController.Start()
RewardsController.Start()
QuestController.Start()
RankTitleController.Start()

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
local QuestsScreen = require(UI.QuestsScreen)
local ActivityFeed = require(UI.ActivityFeed)
local BoothScreen = require(UI.BoothScreen)
local BoothPanel = require(UI.BoothPanel)
local FreeGemsScreen = require(UI.FreeGemsScreen)
local WorldLeaderboards = require(UI.WorldLeaderboards)
local SyndicateScreen = require(UI.SyndicateScreen)
local AdminPanel = require(UI.AdminPanel)
local MonitorPanel = require(UI.MonitorPanel)
local AfkScreen = require(UI.AfkScreen)
local RewardsBar = require(UI.RewardsBar)
local DigScreen = require(UI.DigScreen)
local StarterRollScreen = require(UI.StarterRollScreen)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local GuiBuilder = require(game:GetService("ReplicatedStorage").Shared.GuiBuilder)
local hudGui = playerGui:WaitForChild("TradingHUD") :: ScreenGui
local modalGui = playerGui:WaitForChild("TradingModals") :: ScreenGui
-- separate ScreenGui, IgnoreGuiInset = true: RewardsBar must sit top-centre
-- regardless of Roblox's top inset. GuiBuilder.build() already creates this
-- in StarterGui; ensureTopOverlay only covers a place that hasn't rebuilt yet.
-- WaitForChild, not FindFirstChild: this script can run before StarterGui has
-- cloned TradingHUDTop in. FindFirstChild then built an EMPTY fallback, the
-- real copy arrived beside it, and WaitForChild("FreeGemsButton") below hung
-- forever on the empty one -- freezing every UI wired after it.
local topGui = (playerGui:WaitForChild("TradingHUDTop", 5) :: ScreenGui?)
	or GuiBuilder.ensureTopOverlay(playerGui)

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

-- "1200" -> "1,200"
local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

InventoryScreen.wire(modalGui, tooltip)
TradeScreen.wire(modalGui, tooltip)
StoreScreen.wire(modalGui, tooltip, toast)
EventsScreen.wire(modalGui, tooltip, toast)
BoardScreen.wire(modalGui, tooltip, toast)
ProfileScreen.wire(modalGui, tooltip)
FreeGemsScreen.wire(modalGui, toast)
AfkScreen.wire(modalGui, toast)

-- First-join welcome + starter-roll reveal. Own top-level ScreenGui (built
-- straight into StarterGui, not nested under hud/modal/top), so it can sit
-- above absolutely everything else. Wires itself and no-ops if the server
-- says there's nothing pending (already shown, or an existing account).
local starterRollGui = playerGui:WaitForChild("StarterRollGui") :: ScreenGui
local starterRollHandle = StarterRollScreen.wire(starterRollGui, toast)

-- Rolls, Shop and Syndicate are wired on FIRST OPEN, not at join. Their panels
-- are deliberately absent from StarterGui (see GuiBuilder.ensurePanel), so
-- wiring them here would WaitForChild forever. Every entry point below goes
-- through ensureLazy, which builds the panel into the live PlayerGui and wires
-- the screen exactly once.
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
-- Relic Dig plays the rolls reel for its prize (same design as every roll)
DigScreen.setRevealer(function(item: any, pool: { any }, opts: any)
	ensureRolls()
	RollsScreen.playReveal(item, pool, opts)
end)
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

-- Rewards panel: now the Quests panel (see QuestController). Distinct from
-- the Community Rewards gem-conversion detail (ConversionPanel, below), which
-- is a completely separate concept/panel.
local rewardsPanel = modalGui:WaitForChild("RewardsPanel") :: Frame
;(rewardsPanel:WaitForChild("Title") :: TextLabel).Text = "QUESTS"
;(rewardsPanel:WaitForChild("CloseButton") :: TextButton).Activated:Connect(function()
	rewardsPanel.Visible = false
end)

-- Built in code (UI/QuestsScreen); GuiBuilder only supplies the shell.
local renderQuests = QuestsScreen.wire(rewardsPanel, {
	QuestController = QuestController,
	State = State,
	skip = function()
		-- straight to the purchase prompt: no detour through the shop
		task.spawn(function()
			require(script.Net).invoke("PromptPurchase", "quest_skip")
		end)
	end,
})

local function toggleRewardsPanel()
	if rewardsPanel.Visible then
		rewardsPanel.Visible = false
	else
		Components.closeOtherPanels(rewardsPanel)
		rewardsPanel.Visible = true
		renderQuests()
	end
end

-- Conversion panel: the Community Rewards gem->Robux detail. Opened by the
-- top RewardsBar (bar click + info button), not by the RewardsButton. Same
-- content/footprint the old Shop Rewards tab (Layout3) had, just standalone.
local FILL_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local conversionPanel = modalGui:WaitForChild("ConversionPanel") :: Frame
local convBody = conversionPanel:WaitForChild("Body") :: Frame
local convLeft = convBody:WaitForChild("Left") :: Frame
local convBar = convLeft:WaitForChild("Bar") :: Frame
local convTrack = convBar:WaitForChild("Track") :: Frame
local convFill = convTrack:WaitForChild("Fill") :: Frame
local convPercent = convTrack:WaitForChild("Percent") :: TextLabel
local convRateLine = convLeft:WaitForChild("RateLine") :: TextLabel
local convThresholdLine = convLeft:WaitForChild("ThresholdLine") :: TextLabel
local convNowLine = convLeft:WaitForChild("RobuxNowLine") :: TextLabel

-- The bar now tracks total portfolio worth (gems + every held item's live
-- value), not just spendable gems -- this tells the player what to do about
-- the item half of that. Parented to the PANEL, not convLeft, and anchored
-- from the panel's own bottom edge: convLeft's height is driven by its other
-- children, so anchoring to ITS bottom clipped past the panel's real edge.
local convLiquidityNote = Instance.new("TextLabel")
convLiquidityNote.Name = "LiquidityNote"
convLiquidityNote.BackgroundTransparency = 1
convLiquidityNote.AnchorPoint = Vector2.new(0, 1)
convLiquidityNote.Position = UDim2.new(0, 0, 1, -10)
convLiquidityNote.Size = UDim2.new(0.5, -16, 0, 40)
convLiquidityNote.Font = Enum.Font.Gotham
convLiquidityNote.TextSize = 13
convLiquidityNote.TextColor3 = Color3.fromRGB(180, 185, 200)
convLiquidityNote.TextWrapped = true
convLiquidityNote.TextXAlignment = Enum.TextXAlignment.Left
convLiquidityNote.TextYAlignment = Enum.TextYAlignment.Bottom
convLiquidityNote.Text = "Cash out your items and get ready to convert your gems into some Robux!"
convLiquidityNote.Parent = conversionPanel

;(conversionPanel:WaitForChild("CloseButton") :: TextButton).Activated:Connect(function()
	conversionPanel.Visible = false
end)
local function openConversionPanel()
	Components.closeOtherPanels(conversionPanel)
	conversionPanel.Visible = true
end

local convPainted = false
local latestGemsPerRobux = 100
State.Observe(RewardsController.status, function(status)
	-- deliberately no raw gem count (X/Y) anywhere near the % -- the fill is
	-- front-loaded on purpose and a literal count would let a player do the
	-- math and notice it isn't linear.
	convPercent.Text = ("%d%%"):format(math.floor(status.displayFraction * 100))
	convRateLine.Text = ("Conversion rate: %d gems / Robux"):format(status.gemsPerRobux)
	convThresholdLine.Text = ("Goal: %s gems"):format(comma(status.threshold))
	convNowLine.Text = ("You'd get ≈%s Robux right now"):format(comma(status.robuxNow))
	latestGemsPerRobux = status.gemsPerRobux
	local size = UDim2.fromScale(status.displayFraction, 1)
	if convPainted then
		TweenService:Create(convFill, FILL_TWEEN, { Size = size }):Play()
	else
		convFill.Size = size
		convPainted = true
	end
end)

-- Exchange calculator: type gems, get Robux (and back). A `syncing` guard
-- stops the two boxes' FocusLost handlers from fighting each other -- setting
-- one box's .Text fires the OTHER box's own listener too since both are just
-- Text property writes, not user input.
local calc = convLeft:WaitForChild("Calculator") :: Frame
local gemsBox = calc:WaitForChild("GemsBox") :: TextBox
local robuxBox = calc:WaitForChild("RobuxBox") :: TextBox
-- Robux side keeps 2 decimals (1 gem at a 100:1 rate is really 0.01 Robux --
-- flooring that to "0" made small amounts look like the exchange was broken).
-- Gems stay whole numbers; there's no such thing as a fractional gem.
local function formatRobux(n: number): string
	local whole = math.floor(n)
	local frac = n - whole
	if frac < 0.005 then
		return comma(whole)
	end
	return comma(whole) .. ("%.2f"):format(frac):sub(2)
end

local syncingCalc = false
gemsBox.FocusLost:Connect(function()
	if syncingCalc then
		return
	end
	local gems = tonumber(gemsBox.Text) or 0
	syncingCalc = true
	robuxBox.Text = formatRobux(gems / latestGemsPerRobux)
	syncingCalc = false
end)
robuxBox.FocusLost:Connect(function()
	if syncingCalc then
		return
	end
	local robux = tonumber((robuxBox.Text:gsub(",", ""))) or 0
	syncingCalc = true
	gemsBox.Text = comma(math.floor(robux * latestGemsPerRobux))
	syncingCalc = false
end)

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
MonitorPanel.wire()
AdminPanel.wire(starterRollHandle.trigger) -- own standalone ScreenGui, not nested in modalGui/hudGui
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
	rewardsPanel = toggleRewardsPanel,
	syndicate = function()
		if not QuestController.hasUnlock("syndicate") then
			toast("Reach Trader rank to unlock Syndicates.", Theme.Warn)
			return
		end
		ensureSyndicate()
		SyndicateScreen.toggle()
	end,
})
-- FreeGemsButton lives in topGui (ignore-inset overlay), not hudGui, so it's
-- wired directly here rather than through HUD.wire's toggles table.
;(topGui:WaitForChild("FreeGemsButton") :: ImageButton).Activated:Connect(function()
	FreeGemsScreen.toggle()
end)
RewardsBar.wire(topGui, openConversionPanel, toast)
-- fetch immediately on a settled trade so the 10%->20% first-trade jump
-- lands right away instead of waiting for RewardsController's slow poll
-- tutorial craft done -> the 7% head start lands on the bar right away
require(script.UI.TutorialGuide).Stopped:Connect(function()
	task.spawn(RewardsController.refresh)
end)
TradeController.settled:Connect(function()
	task.spawn(RewardsController.refresh)
end)

-- world prompts: store NPC / event NPC / rolls NPC / trade board pillar
local ProximityPromptService = game:GetService("ProximityPromptService")
local StoreConfig = require(game:GetService("ReplicatedStorage").Shared.Config.StoreConfig)
local RollConfig = require(game:GetService("ReplicatedStorage").Shared.Config.RollConfig)
local BoothConfig = require(game:GetService("ReplicatedStorage").Shared.Config.BoothConfig)
local DigConfig = require(game:GetService("ReplicatedStorage").Shared.Config.DigConfig)
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
	elseif prompt.Name == DigConfig.PromptName then
		DigScreen.open(prompt)
	elseif prompt.Name == "AfkPrompt" then
		AfkScreen.toggle()
	elseif prompt.Name == BoothConfig.PromptName then
		BoothScreen.interact(prompt)
	end
end)

-- DEV ONLY: lets Studio tooling open the Relic Dig screen (set Workspace attribute DigDebugOpen)
workspace:GetAttributeChangedSignal("DigDebugOpen"):Connect(function()
	if workspace:GetAttribute("DigDebugOpen") then
		DigScreen.open()
	end
end)

-- always-on market ticker (live bot + player trades)
-- TEMPORARILY DISABLED per request -- re-enable by uncommenting.
-- ActivityFeed.start()
-- plaza storefronts: paints a face on every placed booth
BoothPanel.build(modalGui, toast, tooltip)
BoothScreen.toast = toast
BoothScreen.setBrowseHandler(BoothPanel.open)
BoothScreen.start()

-- generic notifications (board pings, event news) as toasts
local Net = require(script.Net)
Net.on("Notify", function(text, color)
	task.spawn(QuestController.refresh)
	if type(text) == "string" and HUD.toast then
		HUD.toast(text, typeof(color) == "Color3" and color or Color3.fromRGB(250, 190, 80))
	end
end)

-- generic fallback: ask players who never post a board listing (the more
-- contextual trigger, in BoardScreen) to opt into notifications anyway
task.spawn(function()
	task.wait(15)
	NotificationController.promptOptIn("Enable notifications to hear about trade board activity while you're away!", toast)
end)

print("[Client] trading UI ready")
