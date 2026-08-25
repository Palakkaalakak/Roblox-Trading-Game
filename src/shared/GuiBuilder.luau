--!strict
-- GuiBuilder: one-shot EDIT-TIME tool. Materializes the whole trading GUI as
-- real instances under StarterGui so it can be edited visually in Studio.
-- Runtime scripts only FIND these nodes by name, clone templates, and wire
-- events — they never rebuild or restyle the layout.
--
-- Run from the command bar (or MCP) in Edit mode:
--   require(game.ReplicatedStorage.Shared.GuiBuilder).build()
-- Destroys + recreates StarterGui.TradingHUD / StarterGui.TradingModals.
-- WARNING: rebuilding discards manual edits to those two ScreenGuis.
--
-- Naming is the contract with the wiring code — keep instance NAMES stable
-- when editing visually; everything else (colors, sizes, fonts) is yours.

local GuiBuilder = {}

-- palette (copied from UI Theme so this module has no runtime deps)
local C = {
	Bg = Color3.fromRGB(32, 34, 42),
	BgLight = Color3.fromRGB(44, 47, 58),
	Panel = Color3.fromRGB(38, 41, 51),
	Stroke = Color3.fromRGB(70, 74, 90),
	Text = Color3.fromRGB(240, 242, 248),
	TextDim = Color3.fromRGB(160, 165, 180),
	Accent = Color3.fromRGB(88, 166, 255),
	Good = Color3.fromRGB(87, 217, 130),
	Bad = Color3.fromRGB(240, 95, 95),
	Warn = Color3.fromRGB(250, 190, 80),
	Gem = Color3.fromRGB(120, 220, 232),
	Gold = Color3.fromRGB(253, 179, 30),
	Info = Color3.fromRGB(126, 190, 255), -- light blue: settings toggles, not actions
}
local ICONS = {
	Gem = "rbxassetid://17368064384",
	Trade = "rbxassetid://15403064919",
	Inventory = "rbxassetid://15402958715",
	Player = "rbxassetid://92109681457452",
	Star = "rbxassetid://17368097932",
	Trophy = "rbxassetid://16912465495", -- crown (ranking / leaderboards)
	Shop = "rbxassetid://15402855334", -- coin chest
	Friends = "rbxassetid://17368071983", -- Simulator Icon Pack / Menus / Friends (syndicates)
	Robux = "rbxassetid://15403000023", -- Bobux (Robux) icon for price buttons
}
local FONT = Enum.Font.GothamBold
local FONT_LIGHT = Enum.Font.Gotham

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className) :: any
	for k, v in props do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent: Instance, radius: number?)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function stroke(parent: Instance, color: Color3?, thickness: number?)
	new("UIStroke", {
		Color = color or C.Stroke,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function panel(name: string, props: { [string]: any }, parent: Instance): Frame
	local merged: { [string]: any } = {
		Name = name,
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
	}
	for k, v in props do
		merged[k] = v
	end
	local f = new("Frame", merged, parent)
	corner(f)
	stroke(f)
	return f
end

local function label(name: string, props: { [string]: any }, parent: Instance): TextLabel
	local merged: { [string]: any } = {
		Name = name,
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = C.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in props do
		merged[k] = v
	end
	return new("TextLabel", merged, parent)
end

local function button(name: string, props: { [string]: any }, parent: Instance): TextButton
	local merged: { [string]: any } = {
		Name = name,
		BackgroundColor3 = C.Accent,
		Font = FONT,
		TextColor3 = C.Text,
		TextSize = 16,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}
	for k, v in props do
		merged[k] = v
	end
	local b = new("TextButton", merged, parent)
	corner(b, 6)
	return b
end

--------------------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------------------

local function buildHud(parent: Instance)
	local gui = new("ScreenGui", {
		Name = "TradingHUD",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Enabled = true,
	}, parent)

	-- currency readout
	local pill = panel("GemPill", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(140, 36),
	}, gui)
	new("ImageLabel", {
		Name = "Icon",
		Image = ICONS.Gem,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(24, 24),
		ScaleType = Enum.ScaleType.Fit,
	}, pill)
	label("Amount", {
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -46, 1, 0),
		Text = "0",
		TextSize = 16,
		TextColor3 = C.Gem,
	}, pill)

	-- icon button in the style of the user's StarterGui example
	local function iconButton(name: string, image: string, caption: string, position: UDim2)
		local btn = new("ImageButton", {
			Name = name,
			Image = image,
			BackgroundTransparency = 1,
			AutoButtonColor = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Size = UDim2.fromScale(0.074, 0.106),
			ScaleType = Enum.ScaleType.Fit,
		}, gui)
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, btn)
		new("UICorner", { CornerRadius = UDim.new(0.22, 0) }, btn)
		local cap = new("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1.28, 0),
			Size = UDim2.new(1.4, 0, 0.66, 0),
			Font = FONT,
			Text = caption,
			TextColor3 = C.Gold,
			TextScaled = true,
		}, btn)
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2.5 }, cap)
		return btn
	end

	-- events + trade board have NO HUD buttons: their world NPCs/pillar are
	-- the way in (EventPrompt / BoardPrompt proximity prompts)
	iconButton("InventoryButton", ICONS.Inventory, "INVENTORY", UDim2.fromScale(0.955, 0.77))
	iconButton("TradeButton", ICONS.Trade, "TRADE", UDim2.fromScale(0.955, 0.57))
	iconButton("ProfileButton", ICONS.Player, "PLAYERS", UDim2.fromScale(0.955, 0.47))
	-- Robux shop and the (deliberately separate) free-gems screen
	iconButton("ShopButton", ICONS.Shop, "SHOP", UDim2.fromScale(0.955, 0.37))
	iconButton("FreeGemsButton", ICONS.Star, "FREE GEMS", UDim2.fromScale(0.955, 0.27))
	-- no RANKS button: leaderboards are the physical boards in the world
	iconButton("SyndicateButton", ICONS.Friends, "GROUP", UDim2.fromScale(0.955, 0.17))
	iconButton("DebugGemsButton", ICONS.Gem, "+100 (DEBUG)", UDim2.fromScale(0.06, 0.93))

	-- toast area (bottom center); ToastTemplate cloned at runtime
	local toastArea = new("Frame", {
		Name = "ToastArea",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(420, 120),
		BackgroundTransparency = 1,
	}, gui)
	new("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
	}, toastArea)
	local toast = panel("ToastTemplate", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = C.Bg,
		Visible = false,
	}, toastArea)
	label("Text", {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		Text = "toast",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, toast)

	return gui
end

--------------------------------------------------------------------------------
-- Item tile template (inventory browse grid)
--------------------------------------------------------------------------------

local function buildItemTile(parent: Instance)
	local tile = new("Frame", {
		Name = "ItemTile",
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(126, 168),
		Visible = false, -- template
	}, parent)
	corner(tile, 6)
	stroke(tile)

	new("Frame", {
		Name = "Stripe",
		BackgroundColor3 = C.TextDim,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 5),
	}, tile)
	local icon = new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, -23, 0, 11),
		Size = UDim2.fromOffset(46, 46),
		ScaleType = Enum.ScaleType.Fit,
	}, tile)
	corner(icon, 6)
	label("CountBadge", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 8),
		Size = UDim2.fromOffset(34, 16),
		Text = "",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Warn,
	}, tile)
	label("ItemName", {
		Position = UDim2.fromOffset(6, 60),
		Size = UDim2.new(1, -12, 0, 15),
		Text = "Item",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, tile)
	label("Existence", {
		Position = UDim2.fromOffset(6, 76),
		Size = UDim2.new(1, -12, 0, 12),
		Text = "? in existence",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.TextDim,
	}, tile)
	label("Rarity", {
		Position = UDim2.fromOffset(6, 89),
		Size = UDim2.new(1, -12, 0, 12),
		Text = "Common",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.TextDim,
	}, tile)

	local stats = new("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 106),
		Size = UDim2.new(1, -16, 0, 56),
	}, tile)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, stats)
	for i, statName in { "ValueRow", "StoreCostRow", "RapRow" } do
		label(statName, {
			Size = UDim2.new(1, 0, 0, 14),
			Text = "…",
			Font = FONT_LIGHT,
			TextSize = 12,
			TextColor3 = C.TextDim,
			LayoutOrder = i,
		}, stats)
	end
	return tile
end

--------------------------------------------------------------------------------
-- Trade panel
--------------------------------------------------------------------------------

local GRID = 3
local SLOT = 92
local SLOT_PAD = 8
local SIDE_W = GRID * SLOT + (GRID - 1) * SLOT_PAD + 24 -- 316

local function buildSide(name: string, mine: boolean, x: UDim2, parent: Instance)
	local side = panel(name, {
		Position = x,
		Size = UDim2.fromOffset(SIDE_W, GRID * SLOT + (GRID - 1) * SLOT_PAD + 96),
		BackgroundColor3 = C.Bg,
	}, parent)

	label("Header", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -120, 0, 20),
		Text = mine and "You" or "Them",
		TextSize = 15,
	}, side)
	label("ReadyPill", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(96, 20),
		Text = "not ready",
		TextSize = 11,
		Font = FONT_LIGHT,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.TextDim,
	}, side)

	local grid = new("Frame", {
		Name = "SlotGrid",
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.fromOffset(GRID * SLOT + (GRID - 1) * SLOT_PAD, GRID * SLOT + (GRID - 1) * SLOT_PAD),
		BackgroundTransparency = 1,
	}, side)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(SLOT, SLOT),
		CellPadding = UDim2.fromOffset(SLOT_PAD, SLOT_PAD),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)

	-- 9 real, editable slots (one item COPY each). Both sides are buttons:
	-- the partner side is inert in live trades but clickable in board-compose
	-- mode (building the WANT offer).
	for i = 1, GRID * GRID do
		local slot = new("ImageButton", {
			Name = "Slot" .. i,
			BackgroundColor3 = C.BgLight,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Image = "",
			AutoButtonColor = mine,
		}, grid)
		corner(slot, 6)
		stroke(slot, C.Stroke, 1)
		label("Plus", {
			Size = UDim2.new(1, 0, 1, 0),
			Text = mine and "+" or "",
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.Stroke,
		}, slot)
		local icon = new("ImageLabel", {
			Name = "Icon",
			Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(11, 11),
			Size = UDim2.new(1, -22, 1, -22),
			ScaleType = Enum.ScaleType.Fit,
			Visible = false,
			ZIndex = 2,
		}, slot)
		corner(icon, 6)
	end

	-- gems row: dead simple — type amount, click OK (yours); label (theirs)
	local gemsRow = new("Frame", {
		Name = "GemsRow",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.new(1, -24, 0, 40),
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
	}, side)
	corner(gemsRow, 6)
	new("ImageLabel", {
		Name = "Icon",
		Image = ICONS.Gem,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(24, 24),
		ScaleType = Enum.ScaleType.Fit,
	}, gemsRow)

	if mine then
		local box = new("TextBox", {
			Name = "AmountBox",
			Position = UDim2.fromOffset(40, 7),
			Size = UDim2.new(1, -100, 0, 26),
			BackgroundColor3 = C.Bg,
			BorderSizePixel = 0,
			Font = FONT,
			TextColor3 = C.Text,
			TextSize = 14,
			Text = "0",
			PlaceholderText = "gems",
			ClearTextOnFocus = false,
		}, gemsRow)
		corner(box, 6)
		button("OkButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 7),
			Size = UDim2.fromOffset(46, 26),
			Text = "OK",
			TextSize = 12,
			BackgroundColor3 = C.Good,
		}, gemsRow)
	else
		label("Amount", {
			Position = UDim2.fromOffset(40, 0),
			Size = UDim2.new(1, -48, 1, 0),
			Text = "0",
			TextSize = 16,
			TextColor3 = C.Gem,
		}, gemsRow)
		-- hidden edit controls for board-compose mode (building the WANT side)
		local wbox = new("TextBox", {
			Name = "WantBox",
			Position = UDim2.fromOffset(40, 7),
			Size = UDim2.new(1, -100, 0, 26),
			BackgroundColor3 = C.Bg,
			BorderSizePixel = 0,
			Font = FONT,
			TextColor3 = C.Text,
			TextSize = 14,
			Text = "0",
			PlaceholderText = "gems",
			ClearTextOnFocus = false,
			Visible = false,
		}, gemsRow)
		corner(wbox, 6)
	end
	return side
end

local function buildTradePanel(parent: Instance)
	local W = SIDE_W * 2 + 42
	local tradePanel = panel("TradePanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(W, 640),
		Visible = false,
	}, parent)
	-- FitScale is added generically to every modal panel in buildModals.

	label("Title", {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -360, 0, 24),
		Text = "Trading",
		TextSize = 18,
	}, tradePanel)
	buildSide("YourSide", true, UDim2.fromOffset(14, 64), tradePanel)
	buildSide("TheirSide", false, UDim2.new(1, -(SIDE_W + 14), 0, 64), tradePanel)

	-- per-side overall trade stats (total estimated value of items + gems)
	local sideBottom = 64 + GRID * SLOT + (GRID - 1) * SLOT_PAD + 96
	label("YourTotal", {
		Position = UDim2.fromOffset(14, sideBottom + 4),
		Size = UDim2.fromOffset(SIDE_W, 18),
		Text = "Total: —",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Gem,
	}, tradePanel)
	label("TheirTotal", {
		Position = UDim2.new(1, -(SIDE_W + 14), 0, sideBottom + 4),
		Size = UDim2.fromOffset(SIDE_W, 18),
		Text = "Total: —",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Gem,
	}, tradePanel)

	-- countdown banner (grace window)
	local countdown = panel("CountdownBar", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 36),
		Size = UDim2.fromOffset(360, 26),
		BackgroundColor3 = C.Bg,
		Visible = false,
	}, tradePanel)
	label("Text", {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		Text = "",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Warn,
	}, countdown)

	label("StatusLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -64),
		Size = UDim2.fromOffset(420, 20),
		Text = "",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Warn,
	}, tradePanel)

	button("AcceptButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -12),
		Size = UDim2.fromOffset(190, 42),
		Text = "ACCEPT ✔",
		TextSize = 16,
		BackgroundColor3 = C.Good,
	}, tradePanel)
	button("CancelButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -12),
		Size = UDim2.fromOffset(120, 42),
		Text = "Cancel",
		TextSize = 14,
		BackgroundColor3 = C.Bad,
	}, tradePanel)
	-- board-compose only: auto-trade toggle (hidden during live trades)
	button("AutoToggle", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 144, 1, -12),
		Size = UDim2.fromOffset(170, 42),
		Text = "Auto-trade: ON",
		TextSize = 13,
		BackgroundColor3 = C.Good,
		Visible = false,
	}, tradePanel)

	-- item picker: opens when an empty slot is clicked; PickerTile cloned per item
	local picker = panel("ItemPicker", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(380, 360),
		Visible = false,
		ZIndex = 10,
		BackgroundColor3 = C.Panel,
	}, tradePanel)
	label("Title", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -50, 0, 20),
		Text = "Add an item",
		TextSize = 15,
		ZIndex = 11,
	}, picker)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "X",
		BackgroundColor3 = C.Bad,
		ZIndex = 11,
	}, picker)
	local pickerSearch = new("TextBox", {
		Name = "SearchBox",
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 28),
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Font = FONT_LIGHT,
		TextColor3 = C.Text,
		TextSize = 13,
		PlaceholderText = "Search by name…",
		Text = "",
		ClearTextOnFocus = false,
		ZIndex = 11,
	}, picker)
	corner(pickerSearch, 6)
	local pickerGrid = new("ScrollingFrame", {
		Name = "PickerGrid",
		Position = UDim2.fromOffset(12, 74),
		Size = UDim2.new(1, -24, 1, -86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
	}, picker)
	-- LayoutOrder (assigned by TradeScreen), not Name: trade-ad tokens pin to
	-- the front of the want-side picker, ahead of the alphabetical items
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(80, 96),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, pickerGrid)
	local pickerTile = new("ImageButton", {
		Name = "PickerTile",
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Image = "",
		Visible = false, -- template
		ZIndex = 11,
	}, pickerGrid)
	corner(pickerTile, 6)
	stroke(pickerTile, C.Stroke, 1)
	local ptIcon = new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, -22, 0, 6),
		Size = UDim2.fromOffset(44, 44),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 12,
	}, pickerTile)
	corner(ptIcon, 6)
	label("ItemName", {
		Position = UDim2.fromOffset(4, 52),
		Size = UDim2.new(1, -8, 0, 26),
		Text = "Item",
		TextSize = 10,
		Font = FONT_LIGHT,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		ZIndex = 12,
	}, pickerTile)
	label("CountLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromOffset(30, 12),
		Text = "x1",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Warn,
		ZIndex = 12,
	}, pickerTile)

	return tradePanel
end

--------------------------------------------------------------------------------
-- NPC limited store panel
--------------------------------------------------------------------------------

local function buildStorePanel(parent: Instance)
	local store = panel("StorePanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(660, 520),
		Visible = false,
	}, parent)

	label("Title", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -60, 0, 24),
		Text = "✨ Limited Store",
		TextSize = 18,
	}, store)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "X",
		BackgroundColor3 = C.Bad,
	}, store)

	-- shown only when EVERY item is sold out
	label("OutOfStockBanner", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.new(1, -28, 0, 22),
		Text = "Out of stock!",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Bad,
		Visible = false,
	}, store)

	local grid = new("ScrollingFrame", {
		Name = "StoreGrid",
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(1, -24, 1, -72),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, store)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 192),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)

	-- template tile
	local tile = new("Frame", {
		Name = "StoreTile",
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Visible = false,
	}, grid)
	corner(tile, 6)
	stroke(tile, C.Stroke, 1)
	local icon = new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, -22, 0, 8),
		Size = UDim2.fromOffset(44, 44),
		ScaleType = Enum.ScaleType.Fit,
	}, tile)
	corner(icon, 6)
	label("ItemName", {
		Position = UDim2.fromOffset(6, 54),
		Size = UDim2.new(1, -12, 0, 15),
		Text = "Item",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, tile)
	label("StockLabel", {
		Position = UDim2.fromOffset(6, 70),
		Size = UDim2.new(1, -12, 0, 13),
		Text = "?/? left",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.TextDim,
	}, tile)
	label("PriceLabel", {
		Position = UDim2.fromOffset(6, 86),
		Size = UDim2.new(1, -12, 0, 18),
		Text = "?",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Gem,
	}, tile)
	label("LimitLabel", {
		Position = UDim2.fromOffset(6, 106),
		Size = UDim2.new(1, -12, 0, 13),
		Text = "Can buy 1 max",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.TextDim,
	}, tile)
	button("BuyButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 30),
		Text = "Buy",
		TextSize = 13,
		BackgroundColor3 = C.Good,
	}, tile)

	-- overlays (shown by StoreScreen). Two lines each.
	local function overlay(name: string, titleText: string, titleColor: Color3)
		local ov = new("Frame", {
			Name = name,
			BackgroundColor3 = C.Bg,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Visible = false,
			ZIndex = 5,
		}, tile)
		corner(ov, 6)
		label("Text", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.5, 4),
			Size = UDim2.new(1, -8, 0, 40),
			Text = titleText,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			TextColor3 = titleColor,
			ZIndex = 6,
		}, ov)
		label("Sub", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.5, 8),
			Size = UDim2.new(1, -8, 0, 16),
			Text = "",
			Font = FONT_LIGHT,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.TextDim,
			ZIndex = 6,
		}, ov)
		return ov
	end

	overlay("SoldOutOverlay", "SOLD OUT", C.Bad)
	overlay("MaxReachedOverlay", "Max buy limit reached!", C.Warn)

	return store
end

--------------------------------------------------------------------------------
-- Trade board panel (the pillar)
--------------------------------------------------------------------------------

local function buildBoardPanel(parent: Instance)
	-- Scale-native panel. Root and every descendant are sized in SCALE, so the
	-- board stretches from phone to ultrawide with no FitScale (wireFitScales
	-- skips scale-rooted panels because their Size.X.Offset is 0). Offsets
	-- survive only for hairlines, strokes, corner radii and touch minimums.
	local boardPanel = panel("BoardPanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		-- Sized to match the rest of the game's panels rather than to fill the
		-- screen. Measured peers: Shop 66% wide, Rolls 70%, Store 53%, Events
		-- 56%. At 0.95 the board was 95% x 85% -- an obvious outlier that read
		-- as "something is wrong with this window" even when its contents were
		-- laid out correctly. Consistency across panels matters more than any
		-- one panel's internal balance.
		-- Taller than its peers on purpose: the board carries a paid shelf AND a
		-- feed, and at 0.82 there was not enough vertical room for both -- the
		-- featured cards' labels collapsed to 7px trying to fit. Width still
		-- matches the family (Shop 66%, Rolls 70%); only height buys the room.
		Size = UDim2.fromScale(0.68, 0.84),
		Visible = false,
	}, parent)
	-- MinSize must never exceed a real phone viewport. The old 760 floor was set
	-- for the Market tab's offset-positioned column table, but a phone about 640
	-- wide would then be handed a panel WIDER THAN THE SCREEN -- the board would
	-- hang off both edges with no way to reach the far side. A panel that cannot
	-- fit is worse than a table that has to scroll, so the floor comes down and
	-- the Market table scrolls horizontally on small screens instead.
	new("UISizeConstraint", { MaxSize = Vector2.new(1100, 860), MinSize = Vector2.new(440, 300) }, boardPanel)

	-- Text grows with its box and stops at a cap, which is what makes the same
	-- layout readable on a 5" phone and sane on a 27" monitor.
	local function capText(inst: Instance, maxSize: number)
		new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8 }, inst)
	end
	-- Touch floor: a control may shrink with the panel, but never below the
	-- ~44px a thumb needs.
	local function minTouch(inst: Instance, w: number, h: number)
		new("UISizeConstraint", { MinSize = Vector2.new(w, h) }, inst)
	end
	-- Square-by-height. FitWithinMaxSize shrinks the size given to it, so the
	-- caller must seed a WIDTH the constraint can shrink from — a zero-width
	-- scale collapses the element to a dot instead of squaring it.
	local function square(inst: Instance)
		new("UIAspectRatioConstraint", {
			AspectRatio = 1,
			DominantAxis = Enum.DominantAxis.Height,
			AspectType = Enum.AspectType.FitWithinMaxSize,
		}, inst)
	end

	local title = label("Title", {
		Position = UDim2.fromScale(0.014, 0.014),
		Size = UDim2.fromScale(0.34, 0.062),
		Text = "📌 Trade Board",
		TextScaled = true,
	}, boardPanel)
	capText(title, 24)
	local closeBtn = button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.986, 0.014),
		Size = UDim2.fromScale(0.09, 0.062),
		Text = "X",
		TextScaled = true,
		BackgroundColor3 = C.Bad,
	}, boardPanel)
	square(closeBtn)
	minTouch(closeBtn, 34, 34)
	capText(closeBtn, 20)
	-- context-aware post: label + action depend on the active tab
	local postBtn = button("PostButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.928, 0.014),
		Size = UDim2.fromScale(0.20, 0.062),
		Text = "+ Post trade",
		TextScaled = true,
		BackgroundColor3 = C.Good,
	}, boardPanel)
	minTouch(postBtn, 0, 36)
	capText(postBtn, 17)

	-- two tabs: Trades (item-for-item swaps) · Market (per-item order book —
	-- every buy order and sell listing, priced in gems)
	local tabRow = new("Frame", {
		Name = "TabRow",
		BackgroundTransparency = 1,
		-- Navigation chrome, not content. These were as tall as a listing row's
		-- item chip, which made the top of the board shout louder than the ads
		-- it exists to show. Roughly half height, and only as wide as the labels
		-- need.
		-- Only as wide as the two tabs. Spanning the full panel width made this
		-- an invisible bar across the header that overlapped Post trade, Close
		-- and the boost slots -- nothing looked wrong, but every hit test in
		-- that band had to fight it.
		Position = UDim2.fromScale(0.014, 0.100),
		Size = UDim2.fromScale(0.262, 0.062),
	}, boardPanel)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.008, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabRow)
	local function tab(name: string, text: string, order: number, width: number)
		local b = button(name, {
			Size = UDim2.fromScale(width, 1),
			Text = text,
			TextScaled = true,
			BackgroundColor3 = C.BgLight,
			LayoutOrder = order,
		}, tabRow)
		-- The floor has to stay under the band's own height at the smallest
		-- panel the size constraint allows, or the button spills out of TabRow.
		minTouch(b, 0, 34)
		capText(b, 17)
		return b
	end
	tab("TabTrades", "🔁 Trade Ads", 1, 0.50)
	tab("TabMarket", "📈 Market", 2, 0.42)

	-- scope filter: server-only vs game-wide feed. Defaults to "server" at
	-- runtime (BoardScreen) so a low-pop server's first look at the board
	-- isn't an empty global feed.
	local scopeRow = new("Frame", {
		Name = "ScopeRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.014, 0.172),
		Size = UDim2.fromScale(0.215, 0.056),
	}, boardPanel)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.02, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, scopeRow)
	local function scopeBtn(name: string, text: string, colour: Color3, order: number)
		local b = button(name, {
			Size = UDim2.fromScale(0.49, 1),
			Text = text,
			TextScaled = true,
			BackgroundColor3 = colour,
			LayoutOrder = order,
		}, scopeRow)
		minTouch(b, 0, 30)
		capText(b, 15)
	end
	scopeBtn("ScopeServer", "THIS SERVER", C.Accent, 1)
	scopeBtn("ScopeGlobal", "GLOBAL", C.BgLight, 2)

	-- Banked boost credits as SLOTS, not a sentence. Right-ALIGNED and
	-- transparent: the old bordered shell hugged its slots with AutomaticSize,
	-- which under a scale layout left a wide empty box with one tile pinned to
	-- the far left. Aligning right against the panel edge means an empty
	-- inventory shows only the "+" tile with nothing framing it.
	local boostStrip = new("Frame", {
		Name = "BoostSlotRow",
		-- Sits BESIDE the tabs, spanning the same band the tab and scope rows
		-- occupy on the left. Parked below them it owned a whole strip of its
		-- own, which left the left half of that strip empty and pushed the feed
		-- down for nothing -- a visible dead gap between the chrome and the ads.
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.986, 0.100),
		Size = UDim2.fromScale(0.42, 0.128),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, boardPanel)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0.014, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, boostStrip)

	-- one owned boost. A TextButton, not a Frame: tapping a slot is how you
	-- spend it, which is the same apply path the boost sheet uses.
	local function boostSlotBody(slot: Instance, iconImage: string, tileColor: Color3)
		local icon = new("ImageLabel", {
			Name = "Icon",
			Image = iconImage,
			BackgroundColor3 = tileColor,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(1, 0.70),
			ScaleType = Enum.ScaleType.Fit,
		}, slot)
		square(icon)
		corner(icon, 8)
		stroke(icon, C.Stroke, 1)
		local badge = label("CountBadge", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(0.94, 0.70),
			Size = UDim2.fromScale(0.44, 0.24),
			BackgroundColor3 = C.Gold,
			BackgroundTransparency = 0,
			Text = "x2",
			TextScaled = true,
			TextColor3 = C.Bg,
			TextXAlignment = Enum.TextXAlignment.Center,
		}, slot)
		corner(badge, 4)
		capText(badge, 13)
		local nameLbl = label("NameLabel", {
			Position = UDim2.fromScale(0, 0.74),
			Size = UDim2.fromScale(1, 0.24),
			Text = "Boost 24h",
			Font = FONT_LIGHT,
			TextScaled = true,
			TextColor3 = C.TextDim,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Center,
		}, slot)
		capText(nameLbl, 12)
	end

	local boostSlot = new("TextButton", {
		Name = "BoostSlot",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(0.13, 1),
		LayoutOrder = 1,
		Visible = false,
	}, boostStrip)
	minTouch(boostSlot, 52, 0)
	boostSlotBody(boostSlot, ICONS.Trade, C.BgLight)

	-- always last, always present: the buy path is a slot too. With nothing
	-- owned this is the entire row, so an empty inventory reserves no block.
	local addSlot = new("TextButton", {
		Name = "AddSlot",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(0.13, 1),
		LayoutOrder = 999,
	}, boostStrip)
	minTouch(addSlot, 52, 0)
	local addTile = new("Frame", {
		Name = "Tile",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1, 0.70),
	}, addSlot)
	square(addTile)
	corner(addTile, 8)
	stroke(addTile, C.Gold, 1.5)
	local plus = label("PlusLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = "+",
		TextScaled = true,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, addTile)
	capText(plus, 30)
	local addName = label("NameLabel", {
		Position = UDim2.fromScale(0, 0.74),
		Size = UDim2.fromScale(1, 0.24),
		Text = "Get boosts",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, addSlot)
	capText(addName, 12)

	-- Featured placement: a gold header above a horizontal rail of cards.
	-- Header AND strip collapse together (Visible=false) when the active scope
	-- has no boostTier>=2 listings, so a quiet board shows no dead rail.
	-- Gold is a BORDER treatment here, not a fill. A warm tinted background
	-- turned the shelf muddy brown and fought the item art it was meant to
	-- frame; the stroke alone marks paid placement cleanly and keeps the cards
	-- reading as the same UI family as the free rows.

	local featHeader = label("FeaturedHeader", {
		Position = UDim2.fromScale(0.014, 0.248),
		Size = UDim2.fromScale(0.5, 0.046),
		Text = "⭐ FEATURED · PAID PLACEMENT",
		TextScaled = true,
		TextColor3 = C.Gold,
		Visible = false,
	}, boardPanel)
	capText(featHeader, 16)

	-- The featured block is a GOLD-BORDERED RECTANGLE holding up to
	-- FeaturedSlotsPerScope (6) cards in a 3-wide grid, each card gold-bordered
	-- in turn. Both borders are deliberate: the outer frame says "this whole
	-- band is the paid shelf", the inner ones say "each of these is a bought
	-- placement". It is the same treatment limited/unique content gets, which
	-- is the association we want a buyer to make.
	--
	-- Height is set by BoardScreen from the LIVE count, not fixed: one row when
	-- three or fewer are featured, two when more. A fixed two-row block would
	-- reserve half the panel for empty gold on a board with one featured ad,
	-- and the feed underneath is what most players came for.
	local featuredStrip = new("Frame", {
		Name = "FeaturedStrip",
		Position = UDim2.fromScale(0.014, 0.302),
		Size = UDim2.fromScale(0.972, 0.290),
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Visible = false,
	}, boardPanel)
	corner(featuredStrip, 14)
	stroke(featuredStrip, C.Gold, 2)
	new("UIGridLayout", {
		-- 3 across; the row count is whatever the card total needs.
		-- THREE across, one row. Each card has to carry two items with a name and
		-- a value apiece, and six across gives each only ~146px -- at that width
		-- the labels resolve to 7px, which is present in the tree and invisible
		-- on screen. Two rows of three was worse still (47px cards, 4px text) and
		-- crushed the feed underneath. Three keeps every card readable; the pool
		-- is still six, so the strip scrolls to reach the rest.
		CellSize = UDim2.fromScale(0.315, 0.88),
		CellPadding = UDim2.fromScale(0.018, 0.04),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		FillDirectionMaxCells = 3,
	}, featuredStrip)
	new("UIPadding", {
		PaddingLeft = UDim.new(0.014, 0),
		PaddingRight = UDim.new(0.014, 0),
		PaddingTop = UDim.new(0.05, 0),
		PaddingBottom = UDim.new(0.05, 0),
	}, featuredStrip)

	-- One featured card. Every pixel of it has to buy INFORMATION: a trader
	-- decides on three things -- what is on offer, how much it is worth, and
	-- whether the swap is fair -- so the card carries icon + name + value per
	-- side and the same verdict wording the rows use.
	--
	-- Width is a third of the rail so three cards fill it with a sliver of a
	-- fourth showing, which is what makes the horizontal scroll discoverable
	-- on a touch screen.
	--
	local featuredCard = new("Frame", {
		Name = "FeaturedCard",
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.42, 1),
		Visible = false,
	}, featuredStrip)
	corner(featuredCard, 12)
	stroke(featuredCard, C.Gold, 2.5)
	-- gold spine: reads as "paid placement" at a glance even in a screenshot
	local featuredSpine = new("Frame", {
		Name = "AccentBar",
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.new(0, 6, 1, 0),
	}, featuredCard)
	corner(featuredSpine, 2)

	-- Line 1: who + how long left. Both small and dim -- context, not the
	-- decision, and they used to compete with the art for attention.
	local featPoster = label("PosterLabel", {
		Position = UDim2.fromScale(0.05, 0.05),
		Size = UDim2.fromScale(0.50, 0.11),
		Text = "PosterName",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = C.TextDim,
	}, featuredCard)
	capText(featPoster, 14)
	local featTier = label("TierLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.96, 0.05),
		Size = UDim2.fromScale(0.36, 0.11),
		Text = "2d left",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, featuredCard)
	capText(featTier, 14)

	-- Line 2 (dominant): GIVE (icon + name + value) -- gold arrow -- WANT.
	local featGive = new("Frame", {
		Name = "GiveHolder",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.05, 0.19),
		Size = UDim2.fromScale(0.38, 0.58),
	}, featuredCard)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, featGive)
	local featArrow = label("ArrowLabel", {
		Position = UDim2.fromScale(0.45, 0.40),
		Size = UDim2.fromScale(0.10, 0.16),
		Text = "⇄",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Gold,
	}, featuredCard)
	capText(featArrow, 28)
	local featWant = new("Frame", {
		Name = "WantHolder",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.57, 0.19),
		Size = UDim2.fromScale(0.38, 0.58),
	}, featuredCard)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, featWant)

	-- Per-side item card: art on top, then NAME, then count + value. Lives
	-- under GiveHolder; BoardScreen clones it into both sides.
	local miniChip = new("Frame", {
		Name = "MiniChip",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.80),
		Visible = false,
	}, featGive)
	-- The art sits in a recessed dark well rather than floating on the card.
	-- A well gives the icon an edge to read against on a warm background and
	-- makes the item feel like an object you could pick up.
	local miniIcon = new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundColor3 = C.Bg,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.01),
		Size = UDim2.fromScale(1, 0.64),
		ScaleType = Enum.ScaleType.Fit,
	}, miniChip)
	square(miniIcon)
	corner(miniIcon, 10)
	stroke(miniIcon, C.Gold:Lerp(C.Bg, 0.55), 1.5)
	local miniName = label("NameLabel", {
		Position = UDim2.fromScale(0, 0.59),
		Size = UDim2.fromScale(1, 0.22),
		Text = "Item Name",
		TextScaled = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, miniChip)
	capText(miniName, 16)
	local miniCount = label("CountLabel", {
		Position = UDim2.fromScale(0, 0.81),
		Size = UDim2.fromScale(1, 0.19),
		Text = "x1",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.Gem,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, miniChip)
	capText(miniCount, 14)
	-- per-side "+N more", stacked under that side's item card
	local function featMore(parent: Instance)
		local m = label("MoreLabel", {
			Name = "MoreLabel",
			Size = UDim2.fromScale(1, 0.18),
			Text = "",
			Font = FONT_LIGHT,
			TextScaled = true,
			TextColor3 = C.TextDim,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 99,
			Visible = false,
		}, parent)
		capText(m, 12)
	end
	featMore(featGive)
	featMore(featWant)

	-- Line 3: the verdict, same wording and colouring the feed rows use, so a
	-- trader reads one line and knows whether to care.
	local featVerdict = label("VerdictLabel", {
		Position = UDim2.fromScale(0.05, 0.79),
		Size = UDim2.fromScale(0.90, 0.15),
		Text = "Fair",
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, featuredCard)
	capText(featVerdict, 18)

	-- hard edge between the paid band and the free feed, so the two never read
	-- as one continuous list. Hidden with the strip.
	new("Frame", {
		Name = "FeaturedDivider",
		BackgroundColor3 = C.Gold,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.014, 0.606),
		Size = UDim2.new(0.972, 0, 0, 2),
		Visible = false,
	}, boardPanel)

	-- Default geometry assumes the featured strip is hidden (the common case).
	-- BoardScreen shifts this down when the strip is populated and restores it
	-- when the strip empties back out — see FEED_TOP_* there.
	local list = new("ScrollingFrame", {
		Name = "ListingList",
		Position = UDim2.fromScale(0.014, 0.250),
		Size = UDim2.fromScale(0.972, 0.730),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, boardPanel)
	new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local emptyLbl = label("EmptyLabel", {
		Position = UDim2.fromScale(0.014, 0.30),
		Size = UDim2.fromScale(0.972, 0.06),
		Text = "Nothing here yet — be the first!",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.TextDim,
		Visible = false,
	}, boardPanel)
	capText(emptyLbl, 18)

	-- One listing row. Full-width, with HEIGHT derived from width by aspect
	-- ratio rather than a pixel constant: the row keeps its proportions on
	-- every screen, and a phone gets a genuinely large card instead of a
	-- shrunk desktop one. 5.6:1 is deliberately taller than the 9:1 it
	-- replaced — the owner would rather scroll than squint.
	local row = new("Frame", {
		Name = "ListingRow",
		-- LIGHTER than the panel behind it: rows are objects sitting ON the
		-- board. They used to be darker than their own container, which made
		-- the feed read as holes cut in a sheet rather than as a stack of cards.
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		-- Height is a FRACTION of the feed viewport, not a pixel constant: a
		-- taller screen gets taller rows rather than more of the same small
		-- ones. The pixel constraint is a guard rail on both ends — a row is
		-- never too short to read, never so tall it wastes a phone screen.
		-- 0.42 of the viewport gave 144px rows, so barely two fitted and the
		-- feed felt crammed rather than scannable. A third of the viewport shows
		-- three at a time with room between them, which is what makes a feed
		-- read as a list instead of a stack of slabs.
		Size = UDim2.new(1, -12, 0.410, 0),
		Visible = false,
	}, list)
	new("UISizeConstraint", {
		MinSize = Vector2.new(0, 138),
		MaxSize = Vector2.new(math.huge, 205),
	}, row)
	corner(row, 10)
	stroke(row, C.Stroke, 1)

	-- Verdict spine. BoardScreen paints this with the same colour it gives the
	-- verdict text, so "is this trade good for me" is answerable from the left
	-- edge of the feed alone, before reading a single word.
	local rowSpine = new("Frame", {
		Name = "AccentBar",
		BackgroundColor3 = C.Stroke,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.new(0, 5, 1, 0),
	}, row)
	corner(rowSpine, 2)

	local rowPoster = label("PosterLabel", {
		Position = UDim2.fromScale(0.016, 0.05),
		Size = UDim2.fromScale(0.20, 0.15),
		Text = "PosterName",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = C.TextDim,
	}, row)
	capText(rowPoster, 14)
	local rowBadge = label("Badge", {
		-- Sits DIRECTLY UNDER THE ACTION BUTTON, as its caption. This flag
		-- describes one thing: what pressing that button does. Floating loose in
		-- the middle of the row it had nothing to attach to -- a reader could not
		-- tell whether it described the give side, the want side or the whole ad.
		-- Anchored to the button, it reads as the button's own small print.
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(0.984, 0.96),
		Size = UDim2.fromScale(0.235, 0.17),
		Text = "Trades instantly",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Warn,
	}, row)
	capText(rowBadge, 14)

	-- Persistent proof that a paid boost is working: without this the only
	-- evidence of a purchase was the ad's position, which a player cannot read
	-- as "my boost is live". Counts the boost's own clock down, not the ad's.
	local rowBoostBadge = label("BoostBadge", {
		Position = UDim2.fromScale(0.240, 0.05),
		Size = UDim2.fromScale(0.22, 0.15),
		Text = "⚡ BOOSTED · 23h left",
		TextScaled = true,
		TextColor3 = C.Gold,
		Visible = false,
	}, row)
	capText(rowBoostBadge, 14)

	local giveHolder = new("Frame", {
		Name = "GiveHolder",
		BackgroundTransparency = 1,
		-- Narrower and shorter than before: at 0.295 x 0.62 the two item wells
		-- plus the verdict filled the row edge to edge with no gutters, which is
		-- what made the feed feel cramped rather than dense.
		Position = UDim2.fromScale(0.022, 0.22),
		Size = UDim2.fromScale(0.140, 0.66),
	}, row)
	-- square block: a 112x100 holder made every "square" tile 52x47, and the
	-- row gap between tiles differed from the column gap
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, giveHolder)
	-- swap gems: never a fake item card, just an icon + "+N gems (after tax)"
	local giveGemsIcon = new("ImageLabel", {
		Name = "GiveGemsIcon",
		Image = ICONS.Gem,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.016, 0.855),
		Size = UDim2.fromScale(1, 0.11),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	}, row)
	square(giveGemsIcon)
	local giveGemsLbl = label("GiveGemsLabel", {
		Position = UDim2.fromScale(0.048, 0.85),
		Size = UDim2.fromScale(0.263, 0.12),
		Text = "",
		TextScaled = true,
		TextColor3 = C.Gem,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	capText(giveGemsLbl, 14)
	-- Horizontal: a side shows up to FOUR item tiles side by side. One wide
	-- named chip could only ever describe the first item, so a four-item offer
	-- read as "one thing, +3 more" -- which is not what is being traded. The
	-- per-item name moves to the hover tooltip and the side's worth is printed
	-- underneath as a total, so the row still answers "what is this worth".
	-- 2x2, not a line: four tiles in a row stretched a side across a third of
	-- the row and left the two sides visibly unaligned. A square block keeps both
	-- sides the same shape and the same height whatever they hold.
	new("UIGridLayout", {
		-- FillDirection MUST be explicit. Left unset the second tile dropped to
		-- a new line, so a two-item side stacked into a column while a
		-- four-item side laid out 2x2 -- the two sides of one trade came out
		-- different shapes.
		FillDirection = Enum.FillDirection.Horizontal,
		CellSize = UDim2.fromScale(0.47, 0.47),
		CellPadding = UDim2.fromScale(0.06, 0.06),
		FillDirectionMaxCells = 2,
		SortOrder = Enum.SortOrder.LayoutOrder,
		-- TOP-LEFT, never centred. Centring re-positions the tiles for every
		-- different item count, so a one-item ad put its tile in the middle of
		-- the block while a four-item ad started at the edge -- the first item
		-- of one row did not line up with the first item of the next, and the
		-- two sides of the same trade read as different shapes.
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, giveHolder)

	-- Chip template: icon + NAME + VALUE, the three things every real trade-ad
	-- board shows per item. Cloned into both holders by BoardScreen.
	local chip = new("Frame", {
		Name = "Chip",
		-- Recessed relative to the row that holds it (row is BgLight, the item
		-- well is the darker Bg): the item reads as something set INTO the
		-- card, which is how every inventory grid in the genre reads.
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.47, 0.47), -- grid overrides; kept for clarity
		Visible = false,
	}, giveHolder)
	corner(chip, 8)
	stroke(chip, C.Stroke, 1)
	local chipIcon = new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.08, 0.08),
		Size = UDim2.fromScale(0.84, 0.84),
		ScaleType = Enum.ScaleType.Fit,
	}, chip)
	square(chipIcon)
	corner(chipIcon, 6)
	local chipName = label("NameLabel", {
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.01),
		Text = "Item Name",
		TextScaled = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = false, -- tile is too small for a name; the tooltip carries it
	}, chip)
	capText(chipName, 18)
	-- count and value on one line: "x2 · 1.2k". Gem-coloured because value is
	-- denominated in the same currency the rest of the UI prices things in.
	local chipCount = label("CountLabel", {
		-- Count only, white and heavy, in the TOP-RIGHT corner like an inventory
		-- stack badge. The gem value used to live here too and was unreadable at
		-- tile size; hovering the tile still shows name and live value.
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.93, 0.07),
		Size = UDim2.fromScale(0.40, 0.24),
		Text = "x1",
		Font = Enum.Font.LuckiestGuy,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, chip)
	capText(chipCount, 15)
	-- "+2 more" when a side holds items the single chip cannot show
	local giveMore = label("MoreLabel", {
		Name = "MoreLabel",
		Size = UDim2.fromScale(1, 0.20),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		LayoutOrder = 99,
		Visible = false,
	}, giveHolder)
	capText(giveMore, 13)

	local rowArrow = label("ArrowLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.183, 0.55),
		Size = UDim2.fromScale(0.038, 0.20),
		Text = "⇄",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.TextDim,
	}, row)
	capText(rowArrow, 26)

	local wantHolder = new("Frame", {
		Name = "WantHolder",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.212, 0.22),
		Size = UDim2.fromScale(0.140, 0.66),
	}, row)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, wantHolder)
	local wantGemsIcon = new("ImageLabel", {
		Name = "WantGemsIcon",
		Image = ICONS.Gem,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.378, 0.855),
		Size = UDim2.fromScale(1, 0.11),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	}, row)
	square(wantGemsIcon)
	local wantGemsLbl = label("WantGemsLabel", {
		Position = UDim2.fromScale(0.410, 0.85),
		Size = UDim2.fromScale(0.263, 0.12),
		Text = "",
		TextScaled = true,
		TextColor3 = C.Gem,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	capText(wantGemsLbl, 14)
	-- IDENTICAL to the give side's grid. This holder kept the old vertical list
	-- long after the give side became a 2x2 grid, so the two halves of every
	-- trade were laid out by different rules -- give went 2x2 while want ran
	-- down a column and a third tile fell out of the block entirely.
	new("UIGridLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		CellSize = UDim2.fromScale(0.47, 0.47),
		CellPadding = UDim2.fromScale(0.06, 0.06),
		FillDirectionMaxCells = 2,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, wantHolder)
	local wantMore = label("MoreLabel", {
		Name = "MoreLabel",
		Size = UDim2.fromScale(1, 0.20),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		LayoutOrder = 99,
		Visible = false,
	}, wantHolder)
	capText(wantMore, 13)

	-- "Interested: ..." on ask-first swap rows the poster owns. One truncated
	-- line under the verdict rather than a wrapped block: it is the least
	-- important thing in the row and used to reserve the most space.
	local infoLbl = label("InfoLabel", {
		-- Width stops short of 0.849, where the button column begins. At 0.19 this
		-- ran to 0.878 and the buttons sat on top of it, truncating the verdict
		-- mid-word. Nothing escaped its parent, so the bounds scan passed it.
		Position = UDim2.fromScale(0.545, 0.62),
		Size = UDim2.fromScale(0.205, 0.14),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, row)
	capText(infoLbl, 13)

	-- bulk-buy quantity, bottom-left of the action column
	local countBox = new("TextBox", {
		Name = "CountBox",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(0.83, 0.92),
		Size = UDim2.fromScale(0.055, 0.24),
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Font = FONT,
		TextColor3 = C.Text,
		TextScaled = true,
		Text = "1",
		Visible = false, -- bulk rows only
		ClearTextOnFocus = false,
	}, row)
	corner(countBox, 6)
	capText(countBox, 15)

	-- Primary action is vertically CENTRED in the row and always in the same
	-- place, so a scanner's thumb lands in one column all the way down.
	local actionBtn = button("ActionButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.984, 0.56),
		Size = UDim2.fromScale(0.092, 0.24),
		Text = "Accept",
		TextScaled = true,
		BackgroundColor3 = C.Good,
	}, row)
	minTouch(actionBtn, 0, 44)
	capText(actionBtn, 18)

	-- value-delta chip: "Fair" at 0, else "You gain N%"/"You lose N%" (other's
	-- ads) or "You're asking +N%" (your own — describes the ad, doesn't judge
	-- it). The verdict sits immediately AFTER the want side, on the same line
	-- as the trade it judges, and is the LARGEST text in the row because it is
	-- the single most decision-relevant string in it.
	local valueChip = label("ValueChip", {
		-- Ends at 0.750, before the button column starts at 0.767. The buttons sit
		-- side by side now, which widened that column -- at 0.688..0.840 the
		-- verdict ran underneath Cancel and was unreadable.
		Position = UDim2.fromScale(0.545, 0.32),
		Size = UDim2.fromScale(0.205, 0.24),
		Text = "Fair",
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	capText(valueChip, 24)

	-- time-left pill: makes the presence-tied lifetime mechanic visible —
	-- "Live · you're in game" while the poster is present, else a countdown.
	-- Lifetime is metadata, so it rides the header line with the poster and the
	-- badges rather than taking a slot in the action column.
	local timePill = label("TimePill", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.984, 0.05),
		Size = UDim2.fromScale(0.23, 0.15),
		Text = "2h left",
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)
	capText(timePill, 14)

	-- Opens the boost sheet; visible only on the poster's own listing, so it
	-- STACKS above the primary action rather than sitting beside it. Placed
	-- side by side it ate the verdict column, which every row has, to make room
	-- for a button that only your own handful of ads ever show.
	-- BoardScreen drops ActionButton into the lower slot when this is shown.
	local boostBtn = button("BoostButton", {
		AnchorPoint = Vector2.new(1, 0),
		-- Starts below the header line (which ends at 0.20). At 0.16 it overlapped
		-- TimePill and clipped "Live · you're in game".
		Position = UDim2.fromScale(0.984, 0.24),
		Size = UDim2.fromScale(0.092, 0.22),
		Text = "⏱ Boost",
		TextScaled = true,
		BackgroundColor3 = C.Gold,
		Visible = false,
	}, row)
	minTouch(boostBtn, 0, 40)
	capText(boostBtn, 16)

	--------------------------------------------------------------------------
	-- Market tab, view 1: the DIRECTORY. Search any item, scan its live
	-- stats and best prices at a glance, click through to its order book.
	--------------------------------------------------------------------------
	local home = new("Frame", {
		Name = "MarketHome",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 78),
		Size = UDim2.new(1, -24, 1, -90),
		Visible = false,
	}, boardPanel)
	local homeSearch = new("TextBox", {
		Name = "SearchBox",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Font = FONT_LIGHT,
		TextColor3 = C.Text,
		TextSize = 13,
		PlaceholderText = "Search items by name…",
		Text = "",
		ClearTextOnFocus = false,
	}, home)
	corner(homeSearch, 6)

	-- column headers (offsets mirror MarketRow's fields)
	local COL = { name = 50, value = 330, rap = 430, buy = 530, sell = 630 }
	local header = new("Frame", {
		Name = "ColumnHeader",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 16),
	}, home)
	local function colLabel(name: string, text: string, x: number)
		label(name, {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(96, 16),
			Text = text,
			Font = FONT_LIGHT,
			TextSize = 11,
			TextColor3 = C.TextDim,
		}, header)
	end
	colLabel("ItemCol", "ITEM", COL.name)
	colLabel("ValueCol", "VALUE", COL.value)
	colLabel("RapCol", "RAP", COL.rap)
	colLabel("BuyCol", "BUY FOR", COL.buy)
	colLabel("SellCol", "SELL FOR", COL.sell)

	local marketList = new("ScrollingFrame", {
		Name = "MarketList",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, home)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, marketList)

	-- one directory row (whole row clicks through to the item's book)
	local mrow = new("TextButton", {
		Name = "MarketRow",
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, 48),
		Visible = false,
	}, marketList)
	corner(mrow, 6)
	stroke(mrow, C.Stroke, 1)
	new("Frame", {
		Name = "Stripe",
		BackgroundColor3 = C.TextDim,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 4, 1, 0),
	}, mrow)
	local mrowIcon = new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.fromOffset(36, 36),
		ScaleType = Enum.ScaleType.Fit,
	}, mrow)
	corner(mrowIcon, 6)
	label("ItemName", {
		Position = UDim2.fromOffset(COL.name, 6),
		Size = UDim2.fromOffset(270, 18),
		Text = "Item",
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, mrow)
	label("Rarity", {
		Position = UDim2.fromOffset(COL.name, 26),
		Size = UDim2.fromOffset(270, 13),
		Text = "Common",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextColor3 = C.TextDim,
	}, mrow)
	local function numLabel(name: string, x: number, color: Color3)
		label(name, {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.new(0, 96, 1, 0),
			Text = "—",
			TextSize = 13,
			TextColor3 = color,
		}, mrow)
	end
	numLabel("ValueLabel", COL.value, C.Text)
	numLabel("RapLabel", COL.rap, C.TextDim)
	numLabel("BuyLabel", COL.buy, C.Gem)
	numLabel("SellLabel", COL.sell, C.Gem)

	label("HomeEmptyLabel", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "No items match that search.",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.TextDim,
		Visible = false,
	}, home)

	--------------------------------------------------------------------------
	-- Market tab, view 2: one item's ORDER BOOK. Sellers left (buy from
	-- them), buyers right (sell to them), post buttons top-right.
	--------------------------------------------------------------------------
	local book = new("Frame", {
		Name = "MarketBook",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 78),
		Size = UDim2.new(1, -24, 1, -90),
		Visible = false,
	}, boardPanel)
	button("BackButton", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(90, 26),
		Text = "← Market",
		TextSize = 12,
		BackgroundColor3 = C.BgLight,
	}, book)
	local bookIcon = new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.fromOffset(44, 44),
		ScaleType = Enum.ScaleType.Fit,
	}, book)
	corner(bookIcon, 6)
	label("ItemName", {
		Position = UDim2.fromOffset(54, 34),
		Size = UDim2.fromOffset(330, 22),
		Text = "Item",
		TextSize = 17,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, book)
	label("StatsLine", {
		Position = UDim2.fromOffset(54, 58),
		Size = UDim2.fromOffset(400, 15),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextColor3 = C.TextDim,
	}, book)
	button("PostSellButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -160, 0, 44),
		Size = UDim2.fromOffset(150, 30),
		Text = "+ Sell yours",
		TextSize = 12,
		BackgroundColor3 = C.Good,
	}, book)
	button("PostBuyButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 44),
		Size = UDim2.fromOffset(150, 30),
		Text = "+ Post buy order",
		TextSize = 12,
		BackgroundColor3 = C.Accent,
	}, book)

	-- mid price: the midpoint of the best bid and best ask, centred over both
	-- columns. It's the number traders actually quote an item at — halfway
	-- between what you can buy for and what you can sell for.
	label("MidLabel", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		TextSize = 14,
		TextColor3 = C.Gem,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, book)

	-- two half-width panels: sellers (asks) and buyers (bids)
	local function bookSide(name: string, headerText: string, x: UDim2)
		local sidePanel = new("Frame", {
			Name = name,
			BackgroundColor3 = C.Bg,
			BorderSizePixel = 0,
			Position = x,
			Size = UDim2.new(0.5, -6, 1, -104),
		}, book)
		corner(sidePanel, 6)
		stroke(sidePanel, C.Stroke, 1)
		label("Header", {
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 18),
			Text = headerText,
			TextSize = 12,
			TextColor3 = C.TextDim,
		}, sidePanel)
		local sideList = new("ScrollingFrame", {
			Name = "BookList",
			Position = UDim2.fromOffset(8, 30),
			Size = UDim2.new(1, -16, 1, -38),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, sidePanel)
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, sideList)
		label("EmptyLabel", {
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 0, 20),
			Text = "None yet.",
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.TextDim,
			Visible = false,
		}, sidePanel)

		-- one order row
		local brow = new("Frame", {
			Name = "BookRow",
			BackgroundColor3 = C.BgLight,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -6, 0, 62),
			Visible = false,
		}, sideList)
		corner(brow, 6)
		label("PosterLabel", {
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 14),
			Text = "Poster",
			Font = FONT_LIGHT,
			TextSize = 10,
			TextColor3 = C.TextDim,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, brow)
		label("PriceLabel", {
			Position = UDim2.fromOffset(8, 19),
			Size = UDim2.new(1, -16, 0, 18),
			Text = "? gems each",
			TextSize = 14,
			TextColor3 = C.Gem,
		}, brow)
		label("StockLabel", {
			Position = UDim2.fromOffset(8, 40),
			Size = UDim2.new(1, -150, 0, 14),
			Text = "? available",
			Font = FONT_LIGHT,
			TextSize = 11,
			TextColor3 = C.TextDim,
		}, brow)
		local bcount = new("TextBox", {
			Name = "CountBox",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -92, 1, -6),
			Size = UDim2.fromOffset(44, 26),
			BackgroundColor3 = C.Bg,
			BorderSizePixel = 0,
			Font = FONT,
			TextColor3 = C.Text,
			TextSize = 12,
			Text = "1",
			ClearTextOnFocus = false,
		}, brow)
		corner(bcount, 6)
		button("ActionButton", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -6, 1, -6),
			Size = UDim2.fromOffset(80, 28),
			Text = "Buy",
			TextSize = 12,
			BackgroundColor3 = C.Good,
		}, brow)
		return sidePanel
	end
	bookSide("SellersPanel", "FOR SALE — cheapest first", UDim2.fromOffset(0, 104))
	bookSide("BuyersPanel", "BUY ORDERS — best price first", UDim2.new(0.5, 6, 0, 104))

	--------------------------------------------------------------------------
	-- Post modal (Market only: sell listing / buy order for ONE known item —
	-- opened from an item's book with the item prefilled)
	--------------------------------------------------------------------------
	local post = panel("PostPanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(500, 240),
		Visible = false,
		ZIndex = 10,
		BackgroundColor3 = C.Panel,
	}, boardPanel)
	label("Title", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(320, 22),
		Text = "Post a trade",
		TextSize = 16,
		ZIndex = 11,
	}, post)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "X",
		BackgroundColor3 = C.Bad,
		ZIndex = 11,
	}, post)

	-- one row builder: [pick item button][count box]  + gems box
	local function offerRow(name: string, y: number, headerText: string)
		local holder = new("Frame", {
			Name = name,
			BackgroundColor3 = C.Bg,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, y),
			Size = UDim2.new(1, -24, 0, 110),
			ZIndex = 11,
		}, post)
		corner(holder, 6)
		label("Header", {
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 16),
			Text = headerText,
			TextSize = 12,
			TextColor3 = C.TextDim,
			ZIndex = 12,
		}, holder)
		local itemBtn = new("ImageButton", {
			Name = "ItemButton",
			Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
			BackgroundColor3 = C.BgLight,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 26),
			Size = UDim2.fromOffset(56, 56),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 12,
		}, holder)
		corner(itemBtn, 6)
		label("ItemName", {
			Position = UDim2.fromOffset(72, 26),
			Size = UDim2.fromOffset(150, 16),
			Text = "click icon to pick",
			Font = FONT_LIGHT,
			TextSize = 11,
			TextColor3 = C.TextDim,
			ZIndex = 12,
		}, holder)
		label("CountHeader", {
			Position = UDim2.fromOffset(72, 48),
			Size = UDim2.fromOffset(60, 14),
			Text = "count",
			Font = FONT_LIGHT,
			TextSize = 10,
			TextColor3 = C.TextDim,
			ZIndex = 12,
		}, holder)
		local cbox = new("TextBox", {
			Name = "CountBox",
			Position = UDim2.fromOffset(72, 64),
			Size = UDim2.fromOffset(60, 26),
			BackgroundColor3 = C.BgLight,
			BorderSizePixel = 0,
			Font = FONT,
			TextColor3 = C.Text,
			TextSize = 13,
			Text = "1",
			ClearTextOnFocus = false,
			ZIndex = 12,
		}, holder)
		corner(cbox, 6)
		label("GemsHeader", {
			Position = UDim2.fromOffset(150, 48),
			Size = UDim2.fromOffset(80, 14),
			Text = "+ gems",
			Font = FONT_LIGHT,
			TextSize = 10,
			TextColor3 = C.TextDim,
			ZIndex = 12,
		}, holder)
		local gbox = new("TextBox", {
			Name = "GemsBox",
			Position = UDim2.fromOffset(150, 64),
			Size = UDim2.fromOffset(80, 26),
			BackgroundColor3 = C.BgLight,
			BorderSizePixel = 0,
			Font = FONT,
			TextColor3 = C.Gem,
			TextSize = 13,
			Text = "0",
			ClearTextOnFocus = false,
			ZIndex = 12,
		}, holder)
		corner(gbox, 6)
		return holder
	end

	offerRow("WantRow", 44, "YOU WANT")

	button("SubmitButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(200, 38),
		Text = "POST",
		TextSize = 15,
		BackgroundColor3 = C.Good,
		ZIndex = 11,
	}, post)

	--------------------------------------------------------------------------
	-- Boost sheet (Trade Ads only: spend a banked credit, or buy one, on the
	-- ad whose "⏱ Boost" button opened this). Same nested-modal pattern as
	-- the Market's PostPanel above — centered over BoardPanel, own ZIndex.
	--------------------------------------------------------------------------
	local sheet = panel("BoostSheet", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(640, 424),
		Visible = false,
		ZIndex = 10,
		BackgroundColor3 = C.Panel,
	}, boardPanel)
	label("Title", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(320, 22),
		Text = "Boost This Ad",
		TextSize = 16,
		ZIndex = 11,
	}, sheet)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "X",
		BackgroundColor3 = C.Bad,
		ZIndex = 11,
	}, sheet)

	-- your banked credits for this ad's scope — click one to apply it now
	label("CreditsHeader", {
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.fromOffset(300, 18),
		Text = "Your banked boosts",
		TextSize = 13,
		ZIndex = 11,
	}, sheet)
	local sheetCredits = new("ScrollingFrame", {
		Name = "CreditsList",
		Position = UDim2.fromOffset(14, 56),
		Size = UDim2.new(1, -28, 0, 70),
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
	}, sheet)
	corner(sheetCredits, 6)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, sheetCredits)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 6) }, sheetCredits)
	label("EmptyLabel", {
		Position = UDim2.fromOffset(14, 56),
		Size = UDim2.new(1, -28, 0, 70),
		Text = "No banked boosts for this scope yet — buy one below.",
		TextSize = 11,
		TextWrapped = true,
		TextColor3 = C.TextDim,
		Visible = false,
		ZIndex = 11,
	}, sheet)
	local creditButton = new("TextButton", {
		Name = "CreditButton",
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(140, 58),
		Font = FONT,
		TextColor3 = C.Text,
		TextSize = 12,
		TextWrapped = true,
		AutoButtonColor = true,
		Text = "Boost 24h\n(tap to apply)",
		Visible = false,
		ZIndex = 12,
	}, sheetCredits)
	corner(creditButton, 6)

	-- buy section: three shelf cards (low / best / high), the "best" shelf
	-- visually emphasised with a ribbon, matching ShopScreen's hero-card look
	label("BuyHeader", {
		Position = UDim2.fromOffset(14, 134),
		Size = UDim2.fromOffset(300, 18),
		Text = "Buy more",
		TextSize = 13,
		ZIndex = 11,
	}, sheet)
	-- The shelves below are a convenience copy; the real storefront is
	-- ShopScreen, and this is the door to it so there is one place to browse
	-- everything the game sells.
	button("OpenShopButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 132),
		Size = UDim2.fromOffset(160, 22),
		Text = "See all in Shop →",
		TextSize = 11,
		BackgroundColor3 = C.Gold,
		ZIndex = 12,
	}, sheet)
	local skuRow = new("Frame", {
		Name = "SkuRow",
		Position = UDim2.fromOffset(14, 156),
		Size = UDim2.new(1, -28, 0, 210),
		BackgroundTransparency = 1,
		ZIndex = 11,
	}, sheet)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, skuRow)

	local skuCard = new("Frame", {
		Name = "SkuCard",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(194, 210),
		Visible = false,
		ZIndex = 11,
	}, skuRow)
	corner(skuCard, 8)
	stroke(skuCard, C.Stroke, 1.5)
	local ribbon = new("Frame", {
		Name = "Ribbon",
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 20),
		Visible = false,
		ZIndex = 12,
	}, skuCard)
	label("RibbonText", {
		Size = UDim2.new(1, 0, 1, 0),
		Text = "BEST VALUE",
		TextSize = 11,
		TextColor3 = C.Bg,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 13,
	}, ribbon)
	-- Shop cards need ART. Name + blurb + price over a dead band is the same
	-- informational emptiness the featured cards had; the icon is what makes a
	-- card scannable, and it is the SAME art the shop section and the
	-- inventory slot use for this tier (set per-SKU at runtime).
	local skuIcon = new("ImageLabel", {
		Name = "Icon",
		Image = ICONS.Trade,
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.fromOffset(44, 44),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 12,
	}, skuCard)
	corner(skuIcon, 8)
	label("NameLabel", {
		Position = UDim2.fromOffset(10, 74),
		Size = UDim2.new(1, -20, 0, 18),
		Text = "Boost 24 hours",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 12,
	}, skuCard)
	-- ends at y=128, exactly where the "high" shelf's second price button
	-- starts, so a two-SKU card never overlaps its own copy
	label("BlurbLabel", {
		Position = UDim2.fromOffset(10, 92),
		Size = UDim2.new(1, -20, 0, 36),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 11,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 12,
	}, skuCard)
	label("NoSlotsLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.new(1, -20, 0, 40),
		Text = "NO SLOTS FREE",
		TextSize = 11,
		TextColor3 = C.Bad,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Visible = false,
		ZIndex = 12,
	}, skuCard)
	-- second price button: hidden unless the shelf holds two SKUs (only the
	-- "high"/Featured shelf does today), stacked above BuyButton
	local buyButton2 = button("BuyButton2", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -46),
		Size = UDim2.fromOffset(170, 32),
		Text = "99 R$",
		TextSize = 13,
		BackgroundColor3 = C.Good,
		Visible = false,
		ZIndex = 12,
	}, skuCard)
	local buyButton = button("BuyButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(170, 32),
		Text = "25 R$",
		TextSize = 13,
		BackgroundColor3 = C.Good,
		ZIndex = 12,
	}, skuCard)

	-- auto-renew: featured-only, shown beside the featured (high-shelf) card
	local autoRenew = new("Frame", {
		Name = "AutoRenew",
		Position = UDim2.fromOffset(14, 378),
		Size = UDim2.new(1, -28, 0, 26),
		BackgroundTransparency = 1,
		ZIndex = 11,
	}, sheet)
	local autoRenewBox = new("TextButton", {
		Name = "Checkbox",
		Size = UDim2.fromOffset(22, 22),
		Text = "",
		BackgroundColor3 = C.BgLight,
		AutoButtonColor = true,
		ZIndex = 12,
	}, autoRenew)
	corner(autoRenewBox, 4)
	label("Label", {
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.fromOffset(300, 22),
		Text = "Auto-renew Featured when it expires",
		TextSize = 12,
		ZIndex = 11,
	}, autoRenew)

	--------------------------------------------------------------------------
	-- Post-time boost picker. Shown once the compose window returns a trade and
	-- before the ad goes up, so the choice is part of POSTING rather than a
	-- thing you discover afterwards by finding your own ad in the feed. It only
	-- ever spends an already-banked credit — buying still happens in the shop.
	--------------------------------------------------------------------------
	local postBoost = panel("PostBoostPanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(460, 320),
		Visible = false,
		ZIndex = 10,
		BackgroundColor3 = C.Panel,
	}, boardPanel)
	label("Title", {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.fromOffset(320, 22),
		Text = "Boost this ad?",
		TextSize = 16,
		ZIndex = 11,
	}, postBoost)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "X",
		BackgroundColor3 = C.Bad,
		ZIndex = 11,
	}, postBoost)
	label("Blurb", {
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -28, 0, 30),
		Text = "Pick a banked boost to apply the moment your ad goes up. Posting is free either way.",
		Font = FONT_LIGHT,
		TextSize = 11,
		TextWrapped = true,
		TextColor3 = C.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 11,
	}, postBoost)

	local postBoostOptions = new("ScrollingFrame", {
		Name = "OptionsList",
		Position = UDim2.fromOffset(14, 68),
		Size = UDim2.new(1, -28, 0, 156),
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
	}, postBoost)
	corner(postBoostOptions, 6)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, postBoostOptions)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	}, postBoostOptions)

	local postBoostOption = new("TextButton", {
		Name = "OptionButton",
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 38),
		Font = FONT,
		TextColor3 = C.Text,
		TextSize = 12,
		Text = "No boost — post for free",
		AutoButtonColor = true,
		Visible = false,
		ZIndex = 12,
	}, postBoostOptions)
	corner(postBoostOption, 6)

	-- zero credits is exactly the player who needs the shop, so the empty state
	-- keeps the picker visible and offers a route there rather than vanishing
	label("EmptyLabel", {
		Position = UDim2.fromOffset(14, 230),
		Size = UDim2.new(1, -28, 0, 28),
		Text = "You have no boosts banked for this feed yet.",
		Font = FONT_LIGHT,
		TextSize = 11,
		TextWrapped = true,
		TextColor3 = C.TextDim,
		Visible = false,
		ZIndex = 11,
	}, postBoost)
	button("GetBoostsButton", {
		Position = UDim2.fromOffset(14, 268),
		Size = UDim2.fromOffset(200, 34),
		Text = "+ Get boosts",
		TextSize = 13,
		BackgroundColor3 = C.Gold,
		ZIndex = 11,
	}, postBoost)
	button("PostButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 268),
		Size = UDim2.fromOffset(200, 34),
		Text = "Post without a boost",
		TextSize = 13,
		BackgroundColor3 = C.Good,
		ZIndex = 11,
	}, postBoost)

	return boardPanel
end

-- Non-destructive: add just the board panel to an existing TradingModals.
function GuiBuilder.addBoardPanel()
	local modals = game:GetService("StarterGui"):FindFirstChild("TradingModals")
	if modals == nil then
		return "TradingModals missing — run GuiBuilder.build() first"
	end
	if modals:FindFirstChild("BoardPanel") then
		return "BoardPanel already present"
	end
	buildBoardPanel(modals)
	return "BoardPanel added"
end

--------------------------------------------------------------------------------
-- Shop panel (Robux) — sectioned scroll of offer cards.
--
-- Every product the shop will ever sell renders through ONE card template:
-- gem packs, gamepasses, subscriptions, bundles. Adding a product is a
-- MonetizationConfig entry — this builder never changes. Scale-native (like
-- RollsPanel) so it fits phones without a FitScale.
--------------------------------------------------------------------------------

-- ── shop-specific "juice" helpers (gradients / gloss / text stroke) ─────────
-- These give the store its premium, shiny feel — Blox-Fruits-style — instead of
-- the flat panels the rest of the UI uses. Kept local to the shop so nothing
-- else changes.
local function grad(inst: Instance, top: Color3, bottom: Color3, rot: number?)
	return new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rot or 90,
	}, inst)
end
-- Premium gold — warm YELLOW-gold (never orange); reads best on the dark panels.
local GOLD_HI = Color3.fromRGB(255, 235, 150)
local GOLD_LO = Color3.fromRGB(245, 212, 90)
local GOLD_EDGE = Color3.fromRGB(168, 126, 30) -- dark gold, for stroke definition
local GOLD_TEXT = Color3.fromRGB(52, 36, 8) -- near-black-brown text on gold
-- Blox-Fruits shop palette, matched from the reference: flat dark grey panel,
-- light art cards, a saturated green price bar, blue name banners, and the
-- magenta the reference uses for every "sub-line" (bonus / best value).
local BF_PANEL = Color3.fromRGB(58, 58, 60)
local BF_BANNER = Color3.fromRGB(45, 125, 245)
local BF_GREEN = Color3.fromRGB(47, 224, 74)
local BF_INK = Color3.fromRGB(24, 26, 34) -- dark text on the light art panel
local BF_HOT = Color3.fromRGB(226, 30, 170)
-- glossy metallic gold fill: bright top, a highlight band mid, deep gold bottom
local function goldFill(inst: Instance)
	return new("UIGradient", {
		-- stays in YELLOW-gold the whole way down; the old low stops slid into
		-- orange, which fought everything else on the screen
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 200)),
			ColorSequenceKeypoint.new(0.48, Color3.fromRGB(253, 231, 118)),
			ColorSequenceKeypoint.new(0.52, Color3.fromRGB(255, 241, 148)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(246, 216, 96)),
		}),
		Rotation = 90,
	}, inst)
end
-- glossy highlight across the top of a card — a white gradient that fades out
local function sheen(cardFrame: Instance, radius: number)
	local s = new("Frame", {
		Name = "Sheen",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.46),
		ZIndex = 1,
	}, cardFrame)
	corner(s, radius)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.58),
			NumberSequenceKeypoint.new(0.7, 0.9),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, s)
	return s
end
local function textStroke(lbl: Instance, thickness: number?, transparency: number?)
	new("UIStroke", {
		Color = Color3.fromRGB(15, 16, 22),
		Thickness = thickness or 1.6,
		Transparency = transparency or 0.25,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, lbl)
end
-- shiny bevel edge: a UIStroke tinted by a gradient (light top → dark bottom)
local function gradStroke(inst: Instance, top: Color3, bottom: Color3, thickness: number?)
	local s = new("UIStroke", {
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, inst)
	new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 }, s)
	return s
end
-- soft dark drop shadow behind a card, for depth. ZIndex 0 keeps it under the
-- card body (Global ZIndexBehavior), so only the offset halo shows.
local function dropShadow(cardFrame: Instance, radius: number)
	local sh = new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 5),
		Size = UDim2.new(1, 10, 1, 10),
		ZIndex = 0,
	}, cardFrame)
	corner(sh, radius + 3)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(1, 0.35),
		}),
	}, sh)
	return sh
end

-- Shop panel, modelled directly on the Blox Fruits shop.
--
-- Their card is a three-band vertical stack and that is the whole look:
--   1. a solid COLOURED NAME BANNER across the top, white uppercase text
--   2. a LIGHT art panel (near-white gradient) with the art centred on a soft
--      halo, and any sub-line ("+40% BONUS", "BEST VALUE!") as coloured text
--      overlaid at the bottom of that panel — not a pill, not a corner ribbon
--   3. a FULL-WIDTH BRIGHT GREEN price bar flush to the card's bottom edge,
--      carrying the Robux icon and the price
-- Thin coloured stroke matching the banner, barely-rounded corners, no drop
-- shadow. The panel itself is flat dark grey inside a thin gold frame with a
-- black title bar — so the light cards read as the bright thing on the screen.
local function buildShopPanel(parent: Instance)
	local shop = panel("ShopPanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.66, 0.84),
		BackgroundColor3 = BF_PANEL,
		Visible = false,
	}, parent)
	new("UISizeConstraint", { MaxSize = Vector2.new(900, 700) }, shop)
	corner(shop, 6)
	stroke(shop, GOLD_HI, 2.5) -- thin gold frame, exactly like the reference

	local function capText(inst: Instance, maxSize: number)
		new("UITextSizeConstraint", { MaxTextSize = maxSize }, inst)
	end

	-- title bar: flat black, big white centred SHOP, gold underline, red X
	local titleBar = new("Frame", {
		Name = "TitleBar",
		BackgroundColor3 = Color3.fromRGB(14, 14, 16),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.095),
	}, shop)
	corner(titleBar, 6)
	stroke(titleBar, GOLD_HI, 2)
	local title = label("Title", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.66),
		Text = "SHOP",
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	}, titleBar)
	capText(title, 30)
	local close = button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		Text = "X",
		TextScaled = true,
		BackgroundColor3 = C.Bad,
	}, titleBar)
	corner(close, 5)
	capText(close, 18)

	-- scrolling body: SectionTemplate cloned per section
	local body = new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromScale(0.022, 0.115),
		Size = UDim2.fromScale(0.956, 0.868),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, shop)
	new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, body)

	local section = new("Frame", {
		Name = "SectionTemplate",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, body)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, section)

	-- section header: plain white uppercase text on the dark body with a gold
	-- rule under it — the reference uses exactly this, not a filled ribbon
	local header = new("Frame", {
		Name = "SectionHeader",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 1,
	}, section)
	local headerLbl = label("Label", {
		Position = UDim2.fromScale(0.012, 0),
		Size = UDim2.fromScale(0.97, 0.8),
		Text = "SECTION",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 19,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, header)
	textStroke(headerLbl, 1.6, 0.3)
	new("Frame", {
		Name = "Rule",
		BackgroundColor3 = GOLD_LO,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0.012, 1),
		Size = UDim2.new(0.976, 0, 0, 2),
	}, header)

	-- feature-card column (wide hero cards)
	local features = new("Frame", {
		Name = "Features",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, section)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, features)

	local grid = new("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
	}, section)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(164, 202),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)

	--------------------------------------------------------------------------
	-- MEDIUM CARD: banner / light art panel / green price bar
	--------------------------------------------------------------------------
	local card = new("Frame", {
		Name = "OfferCard",
		BackgroundColor3 = Color3.fromRGB(238, 240, 245),
		BorderSizePixel = 0,
		Visible = false,
	}, grid)
	corner(card, 5)
	-- the light art panel: near-white at the top fading to a cool grey
	grad(card, Color3.fromRGB(252, 252, 254), Color3.fromRGB(206, 209, 218), 90)
	stroke(card, BF_BANNER, 2) -- recoloured per offer by the renderer

	-- 1. coloured name banner
	local banner = new("Frame", {
		Name = "NameBanner",
		BackgroundColor3 = BF_BANNER,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.19),
		ZIndex = 2,
	}, card)
	corner(banner, 5)
	grad(banner, Color3.fromRGB(255, 255, 255), Color3.fromRGB(196, 208, 232), 90)
	local cardName = label("OfferName", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.86),
		Text = "Offer",
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, banner)
	textStroke(cardName, 1.6, 0.25)
	capText(cardName, 16)

	-- 2. art on a soft halo
	local glow = new("Frame", {
		Name = "IconGlow",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.6, 0.32),
		ZIndex = 2,
	}, card)
	corner(glow, 100)
	grad(glow, Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 220, 234), 90)
	new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.54, 0.34),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, card)

	-- 3. sub-lines overlaid on the art panel, as coloured text (reference style)
	local contents = label("Contents", {
		Position = UDim2.fromScale(0.03, 0.585),
		Size = UDim2.fromScale(0.94, 0.09),
		Text = "",
		TextScaled = true,
		TextColor3 = BF_INK,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, card)
	capText(contents, 19)
	local bonus = label("Bonus", {
		Position = UDim2.fromScale(0.03, 0.678),
		Size = UDim2.fromScale(0.94, 0.068),
		Text = "",
		Font = FONT,
		BackgroundTransparency = 1,
		TextScaled = true,
		TextColor3 = BF_HOT, -- magenta, exactly how the reference prints its sub-lines
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 3,
	}, card)
	capText(bonus, 13)
	local badge = label("Badge", {
		Position = UDim2.fromScale(0.03, 0.745),
		Size = UDim2.fromScale(0.94, 0.065),
		Text = "",
		Font = FONT,
		BackgroundTransparency = 1,
		TextScaled = true,
		TextColor3 = BF_HOT,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 3,
	}, card)
	capText(badge, 13)
	local timeLeft = label("TimeLeft", {
		Position = UDim2.fromScale(0.03, 0.2),
		Size = UDim2.fromScale(0.94, 0.07),
		Text = "",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(40, 44, 54),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, card)
	capText(timeLeft, 11)

	-- 4. full-width green price bar, flush to the bottom edge
	local buyBtn = button("BuyButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.185),
		Text = "",
		BackgroundColor3 = BF_GREEN,
		ZIndex = 3,
	}, card)
	corner(buyBtn, 5)
	grad(buyBtn, Color3.fromRGB(96, 246, 122), Color3.fromRGB(28, 198, 62), 90)
	stroke(buyBtn, Color3.fromRGB(20, 140, 46), 1.5)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.03, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, buyBtn)
	local rbx = new("ImageLabel", {
		Name = "RobuxIcon",
		Image = ICONS.Robux,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.66, 0.66),
		LayoutOrder = 1,
		ZIndex = 4,
	}, buyBtn)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, rbx)
	local wasPrice = label("WasPrice", {
		Size = UDim2.fromScale(0.26, 0.66),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(232, 240, 234),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 3,
		ZIndex = 4,
	}, buyBtn)
	capText(wasPrice, 12)
	new("Frame", {
		Name = "Strike",
		BackgroundColor3 = Color3.fromRGB(232, 240, 234),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 2, 0, 1),
		Visible = false,
		ZIndex = 5,
	}, wasPrice)
	local price = label("PriceLabel", {
		Size = UDim2.fromScale(0.5, 0.84),
		Text = "BUY",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		ZIndex = 4,
	}, buyBtn)
	textStroke(price, 1.6, 0.15)
	capText(price, 20)

	--------------------------------------------------------------------------
	-- FEATURE CARD: same three bands, wide, with the badge as the banner
	--------------------------------------------------------------------------
	local feat = new("Frame", {
		Name = "FeatureCard",
		BackgroundColor3 = Color3.fromRGB(238, 240, 245),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 186),
		Visible = false,
	}, features)
	corner(feat, 5)
	grad(feat, Color3.fromRGB(252, 252, 254), Color3.fromRGB(206, 209, 218), 90)
	stroke(feat, GOLD_LO, 2.5)

	-- banner carries the badge headline (BEST VALUE), gold for the hero card
	local ribbon = new("Frame", {
		Name = "Ribbon",
		BackgroundColor3 = GOLD_LO,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.17),
		ZIndex = 2,
	}, feat)
	corner(ribbon, 5)
	goldFill(ribbon)
	local ribbonLbl = label("RibbonText", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.84),
		Text = "FEATURED",
		TextColor3 = GOLD_TEXT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, ribbon)
	capText(ribbonLbl, 18)

	-- big art left, on a halo
	local fglow = new("Frame", {
		Name = "IconGlow",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		-- centred in the gap between the ribbon and the price bar; any bigger and
		-- the art clips into the green bar
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.17, 0.49),
		Size = UDim2.fromOffset(104, 104),
		ZIndex = 2,
	}, feat)
	corner(fglow, 100)
	grad(fglow, Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 220, 234), 90)
	new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.17, 0.49),
		Size = UDim2.fromOffset(92, 92),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, feat)

	-- text block right, coloured sub-lines like the reference
	local fName = label("OfferName", {
		Position = UDim2.fromScale(0.34, 0.24),
		Size = UDim2.fromScale(0.62, 0.14),
		Text = "Offer",
		TextScaled = true,
		TextColor3 = BF_INK,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, feat)
	capText(fName, 24)
	local fContents = label("Contents", {
		Position = UDim2.fromScale(0.34, 0.4),
		Size = UDim2.fromScale(0.62, 0.15),
		Text = "",
		TextScaled = true,
		TextColor3 = BF_INK,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, feat)
	capText(fContents, 28)
	local fBonus = label("Bonus", {
		Position = UDim2.fromScale(0.34, 0.57),
		Size = UDim2.fromScale(0.62, 0.12),
		Text = "",
		Font = FONT,
		BackgroundTransparency = 1,
		TextScaled = true,
		TextColor3 = BF_HOT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		ZIndex = 3,
	}, feat)
	capText(fBonus, 18)
	local fTime = label("TimeLeft", {
		Position = UDim2.fromScale(0.34, 0.69),
		Size = UDim2.fromScale(0.62, 0.09),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(52, 56, 66),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, feat)
	capText(fTime, 13)

	-- full-width green price bar, flush to the bottom edge
	local fBuy = button("BuyButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.18),
		Text = "",
		BackgroundColor3 = BF_GREEN,
		ZIndex = 3,
	}, feat)
	corner(fBuy, 5)
	grad(fBuy, Color3.fromRGB(96, 246, 122), Color3.fromRGB(28, 198, 62), 90)
	stroke(fBuy, Color3.fromRGB(20, 140, 46), 1.5)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.02, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, fBuy)
	local fRbx = new("ImageLabel", {
		Name = "RobuxIcon",
		Image = ICONS.Robux,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.7, 0.7),
		LayoutOrder = 1,
		ZIndex = 4,
	}, fBuy)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, fRbx)
	local fPrice = label("PriceLabel", {
		Size = UDim2.fromScale(0.22, 0.86),
		Text = "BUY",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		ZIndex = 4,
	}, fBuy)
	textStroke(fPrice, 1.6, 0.15)
	capText(fPrice, 24)
	local fWas = label("WasPrice", {
		Size = UDim2.fromScale(0.14, 0.66),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(232, 240, 234),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 3,
		ZIndex = 4,
	}, fBuy)
	capText(fWas, 15)
	new("Frame", {
		Name = "Strike",
		BackgroundColor3 = Color3.fromRGB(232, 240, 234),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 2, 0, 1),
		Visible = false,
		ZIndex = 5,
	}, fWas)

	label("EmptyLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.2),
		Text = "The shop is being stocked — check back soon!",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Visible = false,
	}, shop)

	return shop
end

--------------------------------------------------------------------------------
-- Free Gems panel — deliberately its own screen, unrelated to the Robux shop.
-- Before the community goal is met it shows the progress bar; after, the
-- watch-an-ad reward UI.
--------------------------------------------------------------------------------

local function buildFreeGemsPanel(parent: Instance)
	local free = panel("FreeGemsPanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.46, 0.6),
		Visible = false,
	}, parent)
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 500) }, free)
	stroke(free, C.Gem, 2.5) -- cyan frame: visually its own thing

	local function capText(inst: Instance, maxSize: number)
		new("UITextSizeConstraint", { MaxTextSize = maxSize }, inst)
	end

	local title = label("Title", {
		Position = UDim2.fromScale(0.05, 0.04),
		Size = UDim2.fromScale(0.7, 0.1),
		Text = "FREE GEMS",
		TextScaled = true,
		TextColor3 = C.Gem,
	}, free)
	capText(title, 22)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(30, 30),
		Text = "X",
		BackgroundColor3 = C.Bad,
	}, free)
	-- DEBUG ONLY — remove this button + FreeGemsScreen's wiring for it, and
	-- DebugConfig.ForceGoalMetEnabled, before release. Previews the unlocked
	-- (watch-ad) view without needing 2,000 real players.
	local debugForceBtn = button("DebugForceGoalButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -44, 0, 8),
		Size = UDim2.fromOffset(30, 30),
		Text = "🐞",
		TextScaled = true,
		BackgroundColor3 = C.Warn,
	}, free)
	capText(debugForceBtn, 16)

	-- ── community goal state ─────────────────────────────────────────────
	local goal = new("Frame", {
		Name = "GoalView",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.06, 0.18),
		Size = UDim2.fromScale(0.88, 0.74),
	}, free)
	local goalTitle = label("GoalTitle", {
		Size = UDim2.fromScale(1, 0.14),
		Text = "🌍 COMMUNITY GOAL",
		TextScaled = true,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, goal)
	capText(goalTitle, 18)
	local track = new("Frame", {
		Name = "BarTrack",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.17),
		Size = UDim2.fromScale(1, 0.12),
	}, goal)
	corner(track, 8)
	stroke(track, C.Stroke, 1)
	local fill = new("Frame", {
		Name = "BarFill",
		BackgroundColor3 = C.Gem,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, track)
	corner(fill, 8)
	local progress = label("ProgressLabel", {
		Position = UDim2.fromScale(0, 0.31),
		Size = UDim2.fromScale(1, 0.1),
		Text = "0 / 2,000 players",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, goal)
	capText(progress, 16)
	local blurb = label("GoalBlurb", {
		Position = UDim2.fromScale(0, 0.43),
		Size = UDim2.fromScale(1, 0.15),
		Text = "When we reach 2000 players ANYONE will be able to get gems with just a few ads!",
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, goal)
	capText(blurb, 14)
	-- invite: the one thing a player can actually DO to move the bar
	local inviteBtn = button("InviteButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.75),
		Size = UDim2.fromScale(0.72, 0.14),
		Text = "INVITE FRIENDS",
		TextScaled = true,
		BackgroundColor3 = C.Gem,
	}, goal)
	capText(inviteBtn, 17)
	local inviteBlurb = label("InviteBlurb", {
		Position = UDim2.fromScale(0, 0.905),
		Size = UDim2.fromScale(1, 0.095),
		Text = "Invite your friends to get to the goal faster!",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, goal)
	capText(inviteBlurb, 12)
	local bonusBlurb = label("BonusBlurb", {
		Position = UDim2.fromScale(0, 0.59),
		Size = UDim2.fromScale(1, 0.14),
		Text = "",
		TextScaled = true,
		TextColor3 = C.Gold,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, goal)
	capText(bonusBlurb, 12)

	-- ── unlocked (watch-ad) state ────────────────────────────────────────
	local watch = new("Frame", {
		Name = "WatchView",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.06, 0.18),
		Size = UDim2.fromScale(0.88, 0.74),
		Visible = false,
	}, free)
	-- big gem art so the view isn't a wall of text with one button floating in it
	local rewardArt = new("ImageLabel", {
		Name = "RewardArt",
		Image = ICONS.Gem,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.3, 0.26),
		ScaleType = Enum.ScaleType.Fit,
	}, watch)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, rewardArt)
	local reward = label("RewardLabel", {
		Position = UDim2.fromScale(0, 0.31),
		Size = UDim2.fromScale(1, 0.13),
		Text = "Watch a short ad for +50 gems",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
	}, watch)
	capText(reward, 19)
	local watchBtn = button("WatchButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.78, 0.17),
		Text = "▶  WATCH AD",
		TextScaled = true,
		BackgroundColor3 = C.Good,
	}, watch)
	capText(watchBtn, 22)
	local remaining = label("RemainingLabel", {
		Position = UDim2.fromScale(0, 0.67),
		Size = UDim2.fromScale(1, 0.1),
		Text = "",
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, watch)
	capText(remaining, 14)
	local status = label("StatusLabel", {
		Position = UDim2.fromScale(0, 0.79),
		Size = UDim2.fromScale(1, 0.2),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, watch)
	capText(status, 13)

	return free
end

--------------------------------------------------------------------------------
-- Syndicates panel — three views the client swaps between: create (when you're
-- in none), your syndicate (banner, XP bar, perks, roster), and browse/invites.
-- Row templates live here; the screen clones them.
--------------------------------------------------------------------------------

local function buildSyndicatePanel(parent: Instance)
	local syn = panel("SyndicatePanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(660, 580),
		Visible = false,
	}, parent)

	label("Title", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -60, 0, 24),
		Text = "Groups",
		TextSize = 18,
	}, syn)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "X",
		BackgroundColor3 = C.Bad,
	}, syn)

	local tabRow = new("Frame", {
		Name = "TabRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.new(1, -24, 0, 30),
	}, syn)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabRow)

	local body = new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 80),
		Size = UDim2.new(1, -24, 1, -92),
	}, syn)

	----------------------------------------------------------------------
	-- CREATE view (shown when the player is in no syndicate)
	----------------------------------------------------------------------
	local createView = new("Frame", {
		Name = "CreateView",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, body)
	label("Heading", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 26),
		Text = "Start your own group",
		TextSize = 17,
	}, createView)
	label("Blurb", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "Every trade, board fill and craft your members make earns the group XP. Levelling raises the member cap and unlocks perks for everyone.",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, createView)
	local nameBox = new("TextBox", {
		Name = "NameBox",
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.fromOffset(320, 32),
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 14,
		TextColor3 = C.Text,
		PlaceholderText = "Group name",
		Text = "",
		ClearTextOnFocus = false,
	}, createView)
	corner(nameBox, 6)
	local tagBox = new("TextBox", {
		Name = "TagBox",
		Position = UDim2.fromOffset(330, 84),
		Size = UDim2.fromOffset(110, 32),
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 14,
		TextColor3 = C.Text,
		PlaceholderText = "Tag",
		Text = "",
		ClearTextOnFocus = false,
	}, createView)
	corner(tagBox, 6)
	local createBtn = button("CreateButton", {
		Position = UDim2.fromOffset(450, 84),
		Size = UDim2.fromOffset(150, 32),
		Text = "CREATE",
		TextSize = 14,
		BackgroundColor3 = C.Good,
	}, createView)
	corner(createBtn, 6)
	label("CostLabel", {
		Position = UDim2.fromOffset(0, 122),
		Size = UDim2.new(1, 0, 0, 36),
		TextWrapped = true,
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextColor3 = C.TextDim,
	}, createView)
	label("ErrorLabel", {
		Position = UDim2.fromOffset(0, 144),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		TextSize = 12,
		TextColor3 = C.Bad,
	}, createView)

	----------------------------------------------------------------------
	-- MINE view
	----------------------------------------------------------------------
	local mineView = new("Frame", {
		Name = "MineView",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, body)
	local banner = new("Frame", {
		Name = "Banner",
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 76),
	}, mineView)
	corner(banner, 8)
	label("SynName", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(0.7, 0, 0, 26),
		Text = "Group",
		TextSize = 18,
	}, banner)
	label("SynMeta", {
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.new(0.7, 0, 0, 18),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextColor3 = C.TextDim,
	}, banner)
	local xpTrack = new("Frame", {
		Name = "XpTrack",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 58),
		Size = UDim2.new(1, -28, 0, 10),
	}, banner)
	corner(xpTrack, 5)
	local xpFill = new("Frame", {
		Name = "XpFill",
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, xpTrack)
	corner(xpFill, 5)
	label("PerksLabel", {
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		TextSize = 12,
		TextColor3 = C.Gold,
	}, mineView)

	local memberList = new("ScrollingFrame", {
		Name = "MemberList",
		Position = UDim2.fromOffset(0, 110),
		Size = UDim2.new(1, 0, 1, -158),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, mineView)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, memberList)

	local memberRow = new("Frame", {
		Name = "MemberRow",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, 38),
		Visible = false,
	}, memberList)
	corner(memberRow, 6)
	label("MemberName", {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.42, 0, 1, 0),
		Text = "Player",
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, memberRow)
	label("MemberRole", {
		Position = UDim2.fromScale(0.44, 0),
		Size = UDim2.fromOffset(80, 38),
		Text = "Member",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextColor3 = C.TextDim,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, memberRow)
	label("MemberXp", {
		Position = UDim2.fromScale(0.56, 0),
		Size = UDim2.fromOffset(160, 38),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextColor3 = C.Gem,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, memberRow)
	local modRow = new("Frame", {
		Name = "ModButtons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(190, 26),
	}, memberRow)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, modRow)
	for i, spec in { { "PromoteButton", "Promote", C.Accent }, { "DemoteButton", "Demote", C.BgLight }, { "KickButton", "Kick", C.Bad } } do
		local b = button(spec[1], {
			LayoutOrder = i,
			Size = UDim2.fromOffset(60, 24),
			Text = spec[2],
			TextSize = 11,
			BackgroundColor3 = spec[3],
			Visible = false,
		}, modRow)
		corner(b, 5)
	end

	local actionRow = new("Frame", {
		Name = "ActionRow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 34),
	}, mineView)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, actionRow)
	-- Recruit is the growth button, so it leads and wears the gold.
	for i, spec in
		{
			{ "RecruitButton", "Recruit Friends", C.Gold, 150 },
			{ "PolicyButton", "Who can join: Anyone can join", C.BgLight, 230 },
			{ "LeaveButton", "Leave", C.Bad, 110 },
		}
	do
		local b = button(spec[1], {
			LayoutOrder = i,
			Size = UDim2.fromOffset(spec[4] :: number, 30),
			Text = spec[2],
			TextSize = 13,
			BackgroundColor3 = spec[3],
			TextColor3 = spec[1] == "RecruitButton" and C.Bg or C.TextPrimary,
		}, actionRow)
		corner(b, 6)
	end

	----------------------------------------------------------------------
	-- REQUESTS — the give-and-take board (see SyndicateConfig)
	--
	-- Each row has to answer three things at a glance: WHO needs help, WHAT they
	-- need (with the item's own art, so it's recognisable without reading), and
	-- HOW CLOSE they are. The give button carries the number, so pressing it is
	-- never a guess about how much leaves your inventory.
	----------------------------------------------------------------------
	local reqView = new("Frame", {
		Name = "RequestsView",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, body)

	local composer = new("Frame", {
		Name = "Composer",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 46),
	}, reqView)
	corner(composer, 8)
	grad(composer, Color3.fromRGB(48, 50, 62), Color3.fromRGB(32, 33, 42))
	gradStroke(composer, Color3.fromRGB(70, 74, 92), Color3.fromRGB(38, 40, 50), 1.5)

	label("ComposerHint", {
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 13),
		Text = "SHORT OF SOMETHING? ASK — GROUP MEMBERS CAN SEND IT FROM THEIR OWN STASH",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextColor3 = C.TextDim,
	}, composer)

	local function field(name: string, placeholder: string, pos: UDim2, size: UDim2): TextBox
		local box = new("TextBox", {
			Name = name,
			Position = pos,
			Size = size,
			BackgroundColor3 = Color3.fromRGB(22, 23, 30),
			BorderSizePixel = 0,
			Font = FONT_LIGHT,
			PlaceholderText = placeholder,
			PlaceholderColor3 = Color3.fromRGB(110, 114, 130),
			Text = "",
			TextColor3 = C.TextPrimary,
			TextSize = 13,
			ClearTextOnFocus = false,
		}, composer)
		corner(box, 6)
		stroke(box, Color3.fromRGB(58, 61, 76), 1)
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, box)
		return box
	end
	-- a button, not a text field: the item is chosen from the card picker,
	-- so there is nothing here to type
	local chooseBtn = button("ChooseItemButton", {
		Position = UDim2.fromOffset(12, 18),
		Size = UDim2.new(0.52, -20, 0, 24),
		Text = "Choose item...",
		TextSize = 12,
		BackgroundColor3 = C.BgLight,
		TextColor3 = C.Text,
	}, composer)
	corner(chooseBtn, 6)
	stroke(chooseBtn, C.Stroke, 1)
	field("CountBox", "How many", UDim2.new(0.52, 0, 0, 18), UDim2.fromOffset(90, 24))

	local askBtn = button("AskButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 18),
		Size = UDim2.fromOffset(140, 24),
		Text = "ASK GROUP",
		TextSize = 12,
		BackgroundColor3 = C.Accent,
	}, composer)
	corner(askBtn, 6)
	gradStroke(askBtn, Color3.fromRGB(140, 165, 255), Color3.fromRGB(35, 50, 130), 1.5)

	local reqList = new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, reqView)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, reqList)

	local reqRow = new("Frame", {
		Name = "RequestRow",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, 58),
		Visible = false,
	}, reqList)
	corner(reqRow, 8)
	grad(reqRow, Color3.fromRGB(46, 48, 60), Color3.fromRGB(31, 32, 41))
	gradStroke(reqRow, Color3.fromRGB(66, 70, 88), Color3.fromRGB(36, 38, 48), 1.5)

	-- the item's own art, so a request is recognisable before it's read
	local artHolder = new("Frame", {
		Name = "ArtHolder",
		BackgroundColor3 = Color3.fromRGB(22, 23, 30),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(9, 9),
		Size = UDim2.fromOffset(40, 40),
	}, reqRow)
	corner(artHolder, 8)
	stroke(artHolder, Color3.fromRGB(58, 61, 76), 1)
	new("ImageLabel", {
		Name = "ReqIcon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		Image = "",
		ScaleType = Enum.ScaleType.Fit,
	}, artHolder)

	label("ReqWho", {
		Position = UDim2.fromOffset(58, 6),
		Size = UDim2.new(1, -230, 0, 17),
		Text = "",
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, reqRow)
	label("ReqWhat", {
		Position = UDim2.fromOffset(58, 23),
		Size = UDim2.new(1, -230, 0, 15),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 11,
		TextColor3 = C.TextDim,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, reqRow)

	local reqTrack = new("Frame", {
		Name = "ReqTrack",
		BackgroundColor3 = Color3.fromRGB(20, 21, 28),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(58, 41),
		Size = UDim2.new(1, -230, 0, 9),
	}, reqRow)
	corner(reqTrack, 5)
	stroke(reqTrack, Color3.fromRGB(14, 15, 20), 1)
	local reqFill = new("Frame", {
		Name = "ReqFill",
		BackgroundColor3 = C.Good,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, reqTrack)
	corner(reqFill, 5)
	grad(reqFill, Color3.fromRGB(130, 245, 160), Color3.fromRGB(30, 165, 80))

	local giveBtn = button("GiveButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(150, 34),
		Text = "GIVE",
		TextSize = 13,
		BackgroundColor3 = C.Good,
		TextColor3 = C.Bg,
	}, reqRow)
	corner(giveBtn, 7)
	gradStroke(giveBtn, Color3.fromRGB(140, 250, 170), Color3.fromRGB(20, 110, 50), 1.5)

	label("EmptyLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.82, 0.3),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	}, reqView)

	----------------------------------------------------------------------
	-- BROWSE + INVITES (share a row shape)
	----------------------------------------------------------------------
	local function listView(name: string, rowName: string, actionText: string)
		local view = new("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
		}, body)
		local list = new("ScrollingFrame", {
			Name = "List",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, view)
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
		local row = new("Frame", {
			Name = rowName,
			BackgroundColor3 = C.Bg,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -8, 0, 44),
			Visible = false,
		}, list)
		corner(row, 6)
		label("SynName", {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			Text = "Group",
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, row)
		label("SynMeta", {
			Position = UDim2.fromOffset(12, 24),
			Size = UDim2.new(0.38, 0, 0, 16),
			Text = "",
			Font = FONT_LIGHT,
			TextSize = 11,
			TextColor3 = C.TextDim,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, row)

		-- Three stat columns so groups can actually be compared at a glance,
		-- rather than the row repeating a join setting the button already states.
		for i, spec in { { "StatA", "MEMBERS" }, { "StatB", "TRADES" }, { "StatC", "CRAFTS" } } do
			local col = new("Frame", {
				Name = spec[1],
				BackgroundTransparency = 1,
				Position = UDim2.new(0.4 + (i - 1) * 0.13, 0, 0, 4),
				Size = UDim2.new(0.12, 0, 1, -8),
			}, row)
			label("Caption", {
				Size = UDim2.new(1, 0, 0, 13),
				Text = spec[2],
				Font = FONT_LIGHT,
				TextSize = 9,
				TextColor3 = C.TextDim,
				TextXAlignment = Enum.TextXAlignment.Center,
			}, col)
			label("Value", {
				Position = UDim2.fromOffset(0, 13),
				Size = UDim2.new(1, 0, 0, 18),
				Text = "0",
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Center,
			}, col)
		end

		-- shown in place of the join button when the viewer is already in a group
		label("PolicyText", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(120, 28),
			Text = "",
			Font = FONT_LIGHT,
			TextSize = 12,
			TextColor3 = C.TextDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
			Visible = false,
		}, row)
		local act = button("ActionButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(100, 28),
			Text = actionText,
			TextSize = 12,
			BackgroundColor3 = C.Good,
		}, row)
		corner(act, 6)
		label("EmptyLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromScale(0.9, 0.2),
			Text = "",
			Font = FONT_LIGHT,
			TextScaled = true,
			TextColor3 = C.TextDim,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Visible = false,
		}, view)
		return view
	end
	listView("BrowseView", "BrowseRow", "JOIN")
	listView("InvitesView", "InviteRow", "ACCEPT")

	return syn
end

local function buildRollsPanel(parent: Instance)
	-- Scale-native panel: the root and every child are sized in SCALE units,
	-- so the layout stretches to any screen — phone to ultrawide — with no
	-- FitScale needed (wireFitScales skips scale-rooted panels). Key text is
	-- TextScaled with a max, so it grows on phones and stays sane on desktop.
	local rolls = panel("RollsPanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.86),
		Visible = false,
	}, parent)
	new("UISizeConstraint", { MaxSize = Vector2.new(960, 660) }, rolls)

	local function capText(inst: Instance, maxSize: number)
		new("UITextSizeConstraint", { MaxTextSize = maxSize }, inst)
	end

	local title = label("Title", {
		Position = UDim2.fromScale(0.02, 0.015),
		Size = UDim2.fromScale(0.5, 0.05),
		Text = "🎲 Lucky Rolls",
		TextScaled = true,
	}, rolls)
	capText(title, 20)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(30, 30),
		Text = "X",
		BackgroundColor3 = C.Bad,
	}, rolls)
	local hint = label("Hint", {
		Position = UDim2.fromScale(0.02, 0.068),
		Size = UDim2.fromScale(0.96, 0.032),
		Text = "Pricier rolls, better odds. Every prize is a real limited item from the reserve.",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
	}, rolls)
	capText(hint, 12)

	-- five tier cards, side by side, filling the row edge to edge
	local tierRow = new("Frame", {
		Name = "TierRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.016, 0.115),
		Size = UDim2.fromScale(0.968, 0.385),
	}, rolls)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0.01, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tierRow)
	local card = new("TextButton", {
		Name = "TierCard",
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.192, 1),
		Visible = false, -- template
	}, tierRow)
	corner(card, 8)
	stroke(card, C.Stroke, 1.5)
	local tierName = label("TierName", {
		Position = UDim2.fromScale(0.05, 0.025),
		Size = UDim2.fromScale(0.9, 0.085),
		Text = "Roll",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, card)
	capText(tierName, 16)
	local price = label("Price", {
		Position = UDim2.fromScale(0.05, 0.115),
		Size = UDim2.fromScale(0.9, 0.1),
		Text = "? gems",
		TextScaled = true,
		TextColor3 = C.Gem,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, card)
	capText(price, 20)
	-- the value floor this tier guarantees (filled live by RollsScreen)
	local guarantee = label("Guarantee", {
		Position = UDim2.fromScale(0.05, 0.215),
		Size = UDim2.fromScale(0.9, 0.05),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.Good,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, card)
	capText(guarantee, 12)

	-- the odds ARE the product: centered, big, one row per rarity in that
	-- rarity's color (filled live by RollsScreen)
	local oddsList = new("Frame", {
		Name = "OddsList",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.03, 0.28),
		Size = UDim2.fromScale(0.94, 0.52),
	}, card)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.015, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, oddsList)
	local RARITY_COLORS = {
		{ "Common", Color3.fromRGB(154, 160, 166) },
		{ "Rare", Color3.fromRGB(79, 195, 247) },
		{ "Legendary", Color3.fromRGB(255, 183, 77) },
		{ "Mythical", Color3.fromRGB(186, 104, 200) },
		{ "Godly", Color3.fromRGB(255, 95, 130) },
		{ "Celestial", Color3.fromRGB(120, 245, 235) },
	}
	for i, spec in RARITY_COLORS do
		-- six rows must fit the box: 6 x 0.15 + 5 x 0.02 padding < 1
		local oddsRow = label("Odds" .. spec[1], {
			Size = UDim2.fromScale(1, 0.15),
			Text = "",
			TextScaled = true,
			TextColor3 = spec[2],
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = i,
		}, oddsList)
		capText(oddsRow, 16)
	end

	local blurb = label("Blurb", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.fromScale(1, 0.14),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, card)
	capText(blurb, 11)
	new("UIPadding", {
		PaddingLeft = UDim.new(0.05, 0),
		PaddingRight = UDim.new(0.05, 0),
	}, blurb)

	-- payment bar: gems on the left, items on the right
	local payBar = new("Frame", {
		Name = "PayBar",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.016, 0.515),
		Size = UDim2.fromScale(0.968, 0.068),
	}, rolls)
	local gemsBtn = button("GemsButton", {
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(0.49, 1),
		Text = "Roll — ? gems",
		TextScaled = true,
		BackgroundColor3 = C.Good,
	}, payBar)
	capText(gemsBtn, 17)
	local itemsBtn = button("ItemsButton", {
		Position = UDim2.fromScale(0.51, 0),
		Size = UDim2.fromScale(0.49, 1),
		Text = "Pay with items instead…",
		TextScaled = true,
		BackgroundColor3 = C.Accent,
	}, payBar)
	capText(itemsBtn, 15)

	-- item tray: pick inventory items until their value covers the price.
	-- Tiles carry −/+ steppers, sized for thumbs.
	local tray = new("Frame", {
		Name = "ItemTray",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.016, 0.6),
		Size = UDim2.fromScale(0.968, 0.385),
		Visible = false,
	}, rolls)
	corner(tray, 6)
	stroke(tray, C.Stroke, 1)
	local trayHint = label("TrayHint", {
		Position = UDim2.fromScale(0.015, 0.02),
		Size = UDim2.fromScale(0.58, 0.13),
		Text = "Traded-in items go back into the roll pool for others to win — they aren't destroyed.",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
	}, tray)
	capText(trayHint, 12)
	local totalLabel = label("TotalLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.985, 0.02),
		Size = UDim2.fromScale(0.38, 0.13),
		Text = "Selected: 0 / ? value",
		TextScaled = true,
		TextColor3 = C.Gem,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, tray)
	capText(totalLabel, 14)
	local trayGrid = new("ScrollingFrame", {
		Name = "TrayGrid",
		Position = UDim2.fromScale(0.015, 0.17),
		Size = UDim2.fromScale(0.97, 0.62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, tray)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(112, 104),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, trayGrid)
	local trayTile = new("Frame", {
		Name = "TrayTile",
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Visible = false, -- template
	}, trayGrid)
	corner(trayTile, 6)
	stroke(trayTile, C.Stroke, 1)
	local ttIcon = new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 6, 0, 4),
		Size = UDim2.fromOffset(30, 30),
		ScaleType = Enum.ScaleType.Fit,
	}, trayTile)
	corner(ttIcon, 6)
	label("ItemName", {
		Position = UDim2.fromOffset(40, 6),
		Size = UDim2.new(1, -44, 0, 14),
		Text = "Item",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, trayTile)
	label("ValueLabel", {
		Position = UDim2.fromOffset(40, 21),
		Size = UDim2.new(1, -44, 0, 13),
		Text = "? each",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextColor3 = C.Gem,
	}, trayTile)
	-- thumb-sized stepper: − [N] + (40px-class targets per mobile guidance)
	button("MinusButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -4),
		Size = UDim2.fromOffset(38, 40),
		Text = "−",
		TextSize = 22,
		BackgroundColor3 = C.Bg,
	}, trayTile)
	label("UseLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(28, 40),
		Text = "0",
		TextSize = 15,
		TextColor3 = C.Warn,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, trayTile)
	button("PlusButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -4),
		Size = UDim2.fromOffset(38, 40),
		Text = "+",
		TextSize = 22,
		BackgroundColor3 = C.Bg,
	}, trayTile)
	local confirmBtn = button("ConfirmButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.new(0.5, 0, 0.16, 0),
		Text = "Roll with these items",
		TextScaled = true,
		BackgroundColor3 = C.BgLight,
	}, tray)
	capText(confirmBtn, 15)

	-- reveal overlay: what you won, big and unmissable
	local reveal = new("Frame", {
		Name = "Reveal",
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
	}, rolls)
	corner(reveal)
	-- crescendo flash: RollsScreen pops this to near-opaque then fades it at
	-- the exact moment the true prize lands (the "flash of light" beat real
	-- gacha reveals use to punctuate the payoff). Sits above everything else.
	local flash = new("Frame", {
		Name = "Flash",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
	}, reveal)
	corner(flash)
	local wonLabel = label("WonLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromScale(0.8, 0.05),
		Text = "You rolled…",
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 31,
	}, reveal)
	capText(wonLabel, 16)
	-- The REEL: a horizontal, clipped strip of item icons that scrolls past a
	-- fixed center marker and decelerates to a stop with the prize under the
	-- marker. The tiles either side of it stay visible — the "item before and
	-- the item after" — so every pull ends on a near-miss (you SEE the icons
	-- that slid past, and the one that almost stopped). RollsScreen clones
	-- ReelTile into Strip and animates Strip.Position.
	local reel = new("Frame", {
		Name = "Reel",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.15),
		Size = UDim2.fromScale(0.94, 0.36),
		ZIndex = 31,
	}, reveal)
	corner(reel, 10)
	stroke(reel, C.Stroke, 1)
	local strip = new("Frame", {
		Name = "Strip",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(0, 0.86),
		ZIndex = 31,
	}, reel)
	-- one reel cell: square art, sized to the strip's height (RollsScreen sets
	-- explicit X offsets, so no layout — landing math stays exact)
	local reelTile = new("ImageLabel", {
		Name = "ReelTile",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundColor3 = C.BgLight,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ScaleType = Enum.ScaleType.Fit,
		Visible = false, -- template
		ZIndex = 31,
	}, strip)
	corner(reelTile, 8)
	-- Name caption. An icon alone does not tell a player WHAT just went past,
	-- which is most of the tension while the reel spins. Laid on a dark band
	-- rather than straight onto the art: item icons are bright and busy, and
	-- bare text over them reads as smudge however heavy the stroke is.
	local nameBar = new("Frame", {
		Name = "NameBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.19),
		BackgroundColor3 = Color3.fromRGB(10, 11, 16),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 32,
	}, reelTile)
	corner(nameBar, 8)
	-- the band is rounded on all four corners but only the bottom two should
	-- show; this square-off patch covers the top pair so it sits flush
	new("Frame", {
		Name = "Squareoff",
		BackgroundColor3 = Color3.fromRGB(10, 11, 16),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.5),
		ZIndex = 32,
	}, nameBar)

	local reelName = label("ReelName", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextScaled = true,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 33,
	}, nameBar)
	capText(reelName, 11)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	}, reelName)
	-- center marker: the fixed "you get this" window, on top of the strip, with
	-- the rarity-colored glow RollsScreen recolors as the reel lands
	local marker = new("Frame", {
		Name = "CenterMarker",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 0.94),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ZIndex = 33,
	}, reel)
	corner(marker, 8)
	new("UIStroke", {
		Name = "Glow",
		Color = C.Gold,
		Thickness = 4,
		Transparency = 0.15,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, marker)
	local rName = label("ItemName", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.85, 0.08),
		Text = "?",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 31,
	}, reveal)
	capText(rName, 26)
	local rSub = label("SubLine", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.64),
		Size = UDim2.fromScale(0.85, 0.045),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 31,
	}, reveal)
	capText(rSub, 14)
	local againBtn = button("AgainButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -8, 0.74, 0),
		Size = UDim2.fromScale(0.26, 0.075),
		Text = "Roll again",
		TextScaled = true,
		BackgroundColor3 = C.Good,
		ZIndex = 31,
	}, reveal)
	capText(againBtn, 15)
	local doneBtn = button("DoneButton", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0.5, 8, 0.74, 0),
		Size = UDim2.fromScale(0.26, 0.075),
		Text = "Done",
		TextScaled = true,
		BackgroundColor3 = C.BgLight,
		ZIndex = 31,
	}, reveal)
	capText(doneBtn, 15)

	return rolls
end

--------------------------------------------------------------------------------
-- Events panel (crafting / sacrifices / rotating recipes)
--------------------------------------------------------------------------------

local function buildEventsPanel(parent: Instance)
	local events = panel("EventsPanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(700, 560),
		Visible = false,
	}, parent)

	label("Title", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -60, 0, 24),
		Text = "Crafting",
		TextSize = 18,
	}, events)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "X",
		BackgroundColor3 = C.Bad,
	}, events)

	-- PROGRESS STRIP — two cards above the recipe list, so the first thing a
	-- player sees on opening Crafting is "here's what everyone is building" and
	-- "here's what you're building toward", not a wall of recipes.
	--
	-- Styled with the shop's gloss helpers (goldFill / sheen / gradStroke)
	-- rather than the flat panels the rest of the UI uses: these two cards are
	-- the reward surface, so they should read as the shiniest thing on screen.
	local strip = new("Frame", {
		Name = "ProgressStrip",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 96),
	}, events)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, strip)

	-- One card shape, built twice: a titled panel with a glossy progress bar,
	-- a meta line under it, and a claim button that only appears when there is
	-- something to take.
	local function progressCard(cardName: string, order: number, titleText: string, accent: Color3, gold: boolean)
		local card = new("Frame", {
			Name = cardName,
			LayoutOrder = order,
			BackgroundColor3 = C.Bg,
			BorderSizePixel = 0,
			Size = UDim2.new(0.5, -5, 1, 0),
		}, strip)
		-- Flat panel + plain stroke, matching the recipe rows this sits above.
		-- These first wore the shop's gloss treatment (gradient body, sheen,
		-- metallic gold), which made them look pasted in from a different game:
		-- the shop is deliberately the shiniest screen and nothing else should
		-- compete with it.
		corner(card, 6)
		stroke(card, C.Stroke, 1)

		label("Title", {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -24, 0, 18),
			Text = titleText,
			TextSize = 14,
			TextColor3 = accent,
			ZIndex = 2,
		}, card)

		-- the bar: recessed track, glossy fill, and a percentage sitting on it
		local track = new("Frame", {
			Name = "Track",
			BackgroundColor3 = C.BgLight,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -24, 0, 14),
			ZIndex = 2,
		}, card)
		corner(track, 7)
		local fill = new("Frame", {
			Name = "Fill",
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
			ZIndex = 2,
		}, track)
		corner(fill, 7)
		local pct = label("Pct", {
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextSize = 11,
			TextColor3 = C.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 3,
		}, track)

		local meta = label("Meta", {
			Position = UDim2.fromOffset(12, 50),
			Size = UDim2.new(1, -24, 0, 15),
			Text = "",
			Font = FONT_LIGHT,
			TextSize = 11,
			TextColor3 = C.TextDim,
			ZIndex = 2,
		}, card)
		local sub = label("Sub", {
			Position = UDim2.fromOffset(12, 66),
			Size = UDim2.new(1, -24, 0, 24),
			Text = "",
			Font = FONT_LIGHT,
			TextSize = 11,
			TextColor3 = C.TextDim,
			TextWrapped = true,
			ZIndex = 2,
		}, card)

		-- Claim replaces the sub-line when it appears, so a card never grows and
		-- the two cards stay the same height as each other.
		local claim = button("Claim", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -8),
			Size = UDim2.fromOffset(150, 26),
			Text = "CLAIM",
			TextSize = 12,
			BackgroundColor3 = C.Good,
			TextColor3 = C.Bg,
			Visible = false,
			ZIndex = 3,
		}, card)
		corner(claim, 6)
		return card, fill, pct, meta, sub, claim
	end

	progressCard("GoalCard", 1, "SERVER GOAL", C.Gold, true)
	progressCard("MilestoneCard", 2, "YOUR MILESTONES", C.Gem, false)

	local list = new("ScrollingFrame", {
		Name = "EventList",
		Position = UDim2.fromOffset(12, 126),
		Size = UDim2.new(1, -24, 1, -138),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, events)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	-- section header template (one per event)
	local header = new("Frame", {
		Name = "HeaderRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 30),
		Visible = false,
	}, list)
	label("EventName", {
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(0.6, 0, 0, 22),
		Text = "Event",
		TextSize = 16,
	}, header)
	label("TimeLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 8),
		Size = UDim2.new(0.4, 0, 0, 16),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Warn,
	}, header)

	-- recipe row template
	local row = new("Frame", {
		Name = "RecipeRow",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, 92),
		Visible = false,
	}, list)
	corner(row, 6)
	stroke(row, C.Stroke, 1)

	local inputsHolder = new("Frame", {
		Name = "InputsHolder",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(220, 72),
	}, row)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, inputsHolder)

	-- input chip template (one per distinct input item)
	local chip = new("Frame", {
		Name = "InputChip",
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(52, 72),
		Visible = false,
	}, inputsHolder)
	corner(chip, 6)
	local chipIcon = new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, -18, 0, 6),
		Size = UDim2.fromOffset(36, 36),
		ScaleType = Enum.ScaleType.Fit,
	}, chip)
	corner(chipIcon, 6)
	label("CountLabel", {
		Position = UDim2.fromOffset(2, 46),
		Size = UDim2.new(1, -4, 0, 14),
		Text = "0/1",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, chip)
	label("GemChip", { -- shown when the recipe also costs gems
		Name = "GemChip",
		Position = UDim2.fromOffset(2, 60),
		Size = UDim2.new(1, -4, 0, 12),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Gem,
	}, chip)

	label("ArrowLabel", {
		Position = UDim2.fromOffset(238, 30),
		Size = UDim2.fromOffset(28, 30),
		Text = "→",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.TextDim,
	}, row)

	local outIcon = new("ImageLabel", {
		Name = "OutputIcon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(274, 18),
		Size = UDim2.fromOffset(56, 56),
		ScaleType = Enum.ScaleType.Fit,
	}, row)
	corner(outIcon, 6)
	label("OutputName", {
		Position = UDim2.fromOffset(340, 16),
		Size = UDim2.fromOffset(180, 20),
		Text = "Output",
		TextSize = 15,
	}, row)
	label("OutputStock", {
		Position = UDim2.fromOffset(340, 38),
		Size = UDim2.fromOffset(180, 14),
		Text = "?/? left",
		Font = FONT_LIGHT,
		TextSize = 11,
		TextColor3 = C.TextDim,
	}, row)
	new("ImageLabel", {
		Name = "CostIcon",
		Image = ICONS.Gem,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(340, 53),
		Size = UDim2.fromOffset(16, 16),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	}, row)
	label("CostLabel", {
		Position = UDim2.fromOffset(360, 54),
		Size = UDim2.fromOffset(160, 16),
		Text = "",
		TextSize = 13,
		TextColor3 = C.Gem,
	}, row)
	button("ActionButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(120, 40),
		Text = "CRAFT",
		TextSize = 14,
		BackgroundColor3 = C.Good,
	}, row)

	local done = new("Frame", {
		Name = "DoneOverlay",
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		ZIndex = 5,
	}, row)
	corner(done, 6)
	label("Text", {
		Size = UDim2.new(1, 0, 1, 0),
		Text = "Fully crafted!",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Warn,
		ZIndex = 6,
	}, done)

	return events
end

-- Non-destructive: add just the events panel to an existing TradingModals.
function GuiBuilder.addEventsPanel()
	local modals = game:GetService("StarterGui"):FindFirstChild("TradingModals")
	if modals == nil then
		return "TradingModals missing — run GuiBuilder.build() first"
	end
	if modals:FindFirstChild("EventsPanel") then
		return "EventsPanel already present"
	end
	buildEventsPanel(modals)
	return "EventsPanel added"
end

-- Non-destructive: add just the store panel to an existing TradingModals
-- (preserves manual edits elsewhere). No-op if it already exists.
function GuiBuilder.addStorePanel()
	local modals = game:GetService("StarterGui"):FindFirstChild("TradingModals")
	if modals == nil then
		return "TradingModals missing — run GuiBuilder.build() first"
	end
	if modals:FindFirstChild("StorePanel") then
		return "StorePanel already present"
	end
	buildStorePanel(modals)
	return "StorePanel added"
end

--------------------------------------------------------------------------------
-- Modals (inventory, invite, search, tooltip)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Player profile (browser + view + self-edit)
--------------------------------------------------------------------------------

local function buildProfilePanel(parent: Instance)
	local root = panel("ProfilePanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(420, 470),
		Visible = false,
	}, parent)
	label("Title", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -60, 0, 24),
		Text = "Players",
		TextSize = 18,
	}, root)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "X",
		BackgroundColor3 = C.Bad,
	}, root)

	-- ============ BROWSER (Server / Global tabs -> player list) ============
	local browser = new("Frame", {
		Name = "Browser",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(1, -24, 1, -56),
	}, root)
	button("ServerTab", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(120, 30),
		Text = "Server",
	}, browser)
	button("GlobalTab", {
		Position = UDim2.fromOffset(128, 0),
		Size = UDim2.fromOffset(120, 30),
		Text = "Global",
		BackgroundColor3 = C.BgLight,
	}, browser)
	local searchBox = new("TextBox", {
		Name = "SearchBox",
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Font = FONT_LIGHT,
		TextColor3 = C.Text,
		TextSize = 13,
		PlaceholderText = "Search username or UserId…",
		Text = "",
		ClearTextOnFocus = false,
		Visible = false, -- shown on the Global tab
	}, browser)
	corner(searchBox, 6)
	local plist = new("ScrollingFrame", {
		Name = "PlayerList",
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, browser)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, plist)
	local row = new("TextButton", {
		Name = "RowTemplate",
		Size = UDim2.new(1, 0, 0, 52),
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Visible = false,
	}, plist)
	corner(row, 6)
	local rowAvatar = new("ImageLabel", {
		Name = "Avatar",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(40, 40),
		ScaleType = Enum.ScaleType.Fit,
		Image = "",
	}, row)
	corner(rowAvatar, 20)
	label("DisplayName", {
		Position = UDim2.fromOffset(56, 8),
		Size = UDim2.new(1, -66, 0, 18),
		Text = "Display Name",
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
	label("Username", {
		Position = UDim2.fromOffset(56, 27),
		Size = UDim2.new(1, -66, 0, 15),
		Text = "@username",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextColor3 = C.TextDim,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
	label("Notice", {
		Name = "Notice",
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextSize = 12,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	}, plist)

	-- ============ VIEW (a single profile) ============
	local viewF = new("Frame", {
		Name = "View",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(1, -24, 1, -56),
		Visible = false,
	}, root)
	button("BackButton", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(70, 26),
		Text = "← Back",
		BackgroundColor3 = C.BgLight,
	}, viewF)
	local vAvatar = new("ImageLabel", {
		Name = "Avatar",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.fromOffset(64, 64),
		ScaleType = Enum.ScaleType.Fit,
		Image = "",
	}, viewF)
	corner(vAvatar, 12)
	label("DisplayName", {
		Position = UDim2.fromOffset(76, 38),
		Size = UDim2.new(1, -160, 0, 22),
		Text = "Display Name",
		TextSize = 18,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, viewF)
	label("Username", {
		Position = UDim2.fromOffset(76, 62),
		Size = UDim2.new(1, -160, 0, 16),
		Text = "@username",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextColor3 = C.TextDim,
	}, viewF)
	label("JoinDate", {
		Position = UDim2.fromOffset(76, 80),
		Size = UDim2.new(1, -160, 0, 15),
		Text = "Joined —",
		Font = FONT_LIGHT,
		TextSize = 11,
		TextColor3 = C.TextDim,
	}, viewF)
	button("TradeButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 34),
		Size = UDim2.fromOffset(84, 30),
		Text = "Trade",
		BackgroundColor3 = C.Good,
		Visible = false,
	}, viewF)
	button("EditButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 34),
		Size = UDim2.fromOffset(84, 30),
		Text = "Edit",
		BackgroundColor3 = C.Accent,
		Visible = false,
	}, viewF)
	label("Status", {
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 0, 32),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 13,
		TextColor3 = C.Text,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, viewF)

	-- showcase grid (up to 6, 3 cols x 2 rows, fills the width evenly via
	-- scale-based cells: 3*0.313 + 2*0.0305 = 1.0 exactly)
	local showcase = new("Frame", {
		Name = "Showcase",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 140),
		Size = UDim2.new(1, 0, 0, 190),
	}, viewF)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.313, 0, 0, 86),
		CellPadding = UDim2.new(0.0305, 0, 0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, showcase)
	local slot = new("Frame", {
		Name = "SlotTemplate",
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Visible = false,
	}, showcase)
	corner(slot, 6)
	new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 5),
		Size = UDim2.fromOffset(44, 44),
		ScaleType = Enum.ScaleType.Fit,
	}, slot)
	label("ItemName", {
		Position = UDim2.fromOffset(4, 51),
		Size = UDim2.new(1, -8, 0, 14),
		Text = "Item",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, slot)
	label("Rarity", {
		Position = UDim2.fromOffset(4, 66),
		Size = UDim2.new(0.5, -6, 0, 14),
		Text = "Common",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, slot)
	label("ItemValue", {
		Position = UDim2.new(0.5, 2, 0, 66),
		Size = UDim2.new(0.5, -6, 0, 14),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, slot)
	label("ShowcaseEmpty", {
		Name = "ShowcaseEmpty",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 140),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "",
		TextSize = 12,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false,
	}, viewF)

	-- stat chips: inverse-pyramid layout (2 wide on top, 1 centered below),
	-- max 3 stats — fixed slots, no clone/destroy needed.
	local chips = new("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 338),
		Size = UDim2.new(1, 0, 0, 76),
	}, viewF)
	local function chipSlot(name: string, position: UDim2, size: UDim2)
		local c = new("Frame", {
			Name = name,
			BackgroundColor3 = C.BgLight,
			BorderSizePixel = 0,
			Position = position,
			Size = size,
			Visible = false,
		}, chips)
		corner(c, 6)
		new("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(6, 5),
			Size = UDim2.fromOffset(26, 26),
			ScaleType = Enum.ScaleType.Fit,
			Image = "",
		}, c)
		label("ChipValue", {
			Position = UDim2.fromOffset(38, 2),
			Size = UDim2.new(1, -44, 0, 17),
			Text = "0",
			TextSize = 14,
		}, c)
		label("ChipLabel", {
			Position = UDim2.fromOffset(38, 19),
			Size = UDim2.new(1, -44, 0, 13),
			Text = "Stat",
			Font = FONT_LIGHT,
			TextSize = 10,
			TextColor3 = C.TextDim,
		}, c)
		return c
	end
	chipSlot("Chip1", UDim2.new(0, 0, 0, 0), UDim2.new(0.485, 0, 0, 34))
	chipSlot("Chip2", UDim2.new(0.515, 0, 0, 0), UDim2.new(0.485, 0, 0, 34))
	chipSlot("Chip3", UDim2.new(0.25, 0, 0, 42), UDim2.new(0.5, 0, 0, 34))

	-- ============ EDIT (self only) ============
	local edit = new("Frame", {
		Name = "Edit",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 106),
		Size = UDim2.new(1, 0, 1, -106),
		Visible = false,
	}, viewF)
	local statusInput = new("TextBox", {
		Name = "StatusInput",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Font = FONT_LIGHT,
		TextColor3 = C.Text,
		TextSize = 13,
		PlaceholderText = "Looking for… (status)",
		Text = "",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, edit)
	corner(statusInput, 6)
	button("HideValueToggle", {
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(0.5, -4, 0, 30),
		Text = "Value: Shown",
		BackgroundColor3 = C.BgLight,
	}, edit)
	button("HideShowcaseToggle", {
		Position = UDim2.new(0.5, 4, 0, 38),
		Size = UDim2.new(0.5, -4, 0, 30),
		Text = "Showcase: Shown",
		BackgroundColor3 = C.BgLight,
	}, edit)
	label("ChipHint", {
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "Pin up to 3 stats:",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextColor3 = C.TextDim,
	}, edit)
	local chipPick = new("Frame", {
		Name = "ChipPicker",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 62),
	}, edit)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(92, 26),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, chipPick)
	local chipOption = button("ChipOption", {
		Size = UDim2.fromOffset(92, 26),
		Text = "Stat",
		TextSize = 11,
		BackgroundColor3 = C.BgLight,
		Visible = false,
	}, chipPick)

	label("EditHint", {
		Position = UDim2.fromOffset(0, 160),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "Pick up to 6 items to showcase:",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextColor3 = C.TextDim,
	}, edit)
	local pick = new("ScrollingFrame", {
		Name = "ShowcasePicker",
		Position = UDim2.fromOffset(0, 180),
		Size = UDim2.new(1, 0, 1, -222),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, edit)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(70, 70),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, pick)
	local pickTile = new("TextButton", {
		Name = "PickTile",
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Visible = false,
	}, pick)
	corner(pickTile, 6)
	stroke(pickTile) -- client recolors the stroke when selected
	new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(58, 44),
		ScaleType = Enum.ScaleType.Fit,
	}, pickTile)
	label("CountBadge", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(28, 14),
		Text = "",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Warn,
	}, pickTile)
	label("PickName", {
		Position = UDim2.fromOffset(4, 52),
		Size = UDim2.new(1, -8, 0, 14),
		Text = "Item",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextColor3 = C.TextDim,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, pickTile)
	button("SaveButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(160, 32),
		Text = "Save",
		BackgroundColor3 = C.Good,
	}, edit)

	return root
end

local function buildModals(parent: Instance)
	local gui = new("ScreenGui", {
		Name = "TradingModals",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Enabled = true,
	}, parent)

	-- inventory browse panel
	local inv = panel("InventoryPanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(600, 420),
		Visible = false,
	}, gui)
	label("Title", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -60, 0, 24),
		Text = "Inventory",
		TextSize = 18,
	}, inv)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "X",
		BackgroundColor3 = C.Bad,
	}, inv)
	local grid = new("ScrollingFrame", {
		Name = "ItemGrid",
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(1, -24, 1, -56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, inv)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(126, 168),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.Name,
	}, grid)
	buildItemTile(grid)

	buildTradePanel(gui)
	buildStorePanel(gui)
	buildEventsPanel(gui)
	buildBoardPanel(gui)
	buildProfilePanel(gui)
	buildRollsPanel(gui)
	buildShopPanel(gui)
	buildFreeGemsPanel(gui)
	buildSyndicatePanel(gui)

	-- invite popup
	local invite = panel("InvitePanel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.fromOffset(340, 88),
		Visible = false,
	}, gui)
	label("Text", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 20),
		Text = "Someone wants to trade!",
		TextSize = 14,
	}, invite)
	button("AcceptButton", {
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.fromOffset(150, 32),
		Text = "Accept",
		BackgroundColor3 = C.Good,
	}, invite)
	button("DeclineButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 42),
		Size = UDim2.fromOffset(150, 32),
		Text = "Decline",
		BackgroundColor3 = C.Bad,
	}, invite)

	-- partner search
	local search = panel("SearchPanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(320, 360),
		Visible = false,
	}, gui)
	label("Title", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -50, 0, 22),
		Text = "Trade with…",
		TextSize = 16,
	}, search)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "X",
		BackgroundColor3 = C.Bad,
	}, search)
	local searchBox = new("TextBox", {
		Name = "SearchBox",
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 30),
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Font = FONT_LIGHT,
		TextColor3 = C.Text,
		TextSize = 13,
		PlaceholderText = "Search by username or UserId…",
		Text = "",
		ClearTextOnFocus = false,
	}, search)
	corner(searchBox, 6)
	local results = new("ScrollingFrame", {
		Name = "ResultsList",
		Position = UDim2.fromOffset(12, 78),
		Size = UDim2.new(1, -24, 1, -90),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, search)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, results)
	-- player result row: avatar headshot left, display name + @username right
	local resultRow = new("TextButton", {
		Name = "ResultTemplate",
		Size = UDim2.new(1, 0, 0, 52),
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Visible = false, -- template
	}, results)
	corner(resultRow, 6)
	local avatar = new("ImageLabel", {
		Name = "Avatar",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(40, 40),
		ScaleType = Enum.ScaleType.Fit,
		Image = "",
	}, resultRow)
	corner(avatar, 20)
	label("DisplayName", {
		Position = UDim2.fromOffset(56, 8),
		Size = UDim2.new(1, -100, 0, 18),
		Text = "Display Name",
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, resultRow)
	label("Username", {
		Position = UDim2.fromOffset(56, 27),
		Size = UDim2.new(1, -100, 0, 15),
		Text = "@username",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextColor3 = C.TextDim,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, resultRow)
	label("OnlineTag", {
		Name = "OnlineTag",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(80, 16),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Good,
	}, resultRow)
	label("NoticeTemplate", {
		Size = UDim2.new(1, 0, 0, 24),
		Text = "No matches",
		TextSize = 12,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false, -- template
	}, results)

	-- hover tooltip
	local tip = panel("Tooltip", {
		Size = UDim2.fromOffset(190, 118),
		Visible = false,
		ZIndex = 50,
		BackgroundColor3 = C.Bg,
	}, gui)
	label("Title", {
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 16),
		Text = "",
		TextSize = 14,
		ZIndex = 51,
	}, tip)
	label("Sub", {
		Position = UDim2.fromOffset(10, 24),
		Size = UDim2.new(1, -20, 0, 13),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 11,
		TextColor3 = C.TextDim,
		ZIndex = 51,
	}, tip)
	label("Body", {
		Position = UDim2.fromOffset(10, 42),
		Size = UDim2.new(1, -20, 1, -50),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 12,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 51,
	}, tip)

	-- Device fit: every top-level modal panel gets a UIScale ("FitScale").
	-- Panels are designed in fixed offsets against a large reference screen;
	-- Components.wireFitScales shrinks each proportionally to the live
	-- viewport so the WHOLE panel (buttons included) fits any device without
	-- distorting layout or text. Tooltip excluded: positioned in raw mouse
	-- pixels at runtime, scaling would desync it from the cursor.
	for _, child in gui:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "Tooltip" and child:FindFirstChild("FitScale") == nil then
			new("UIScale", { Name = "FitScale", Scale = 1 }, child)
		end
	end

	return gui
end

--------------------------------------------------------------------------------

function GuiBuilder.build()
	local starterGui = game:GetService("StarterGui")
	for _, name in { "TradingHUD", "TradingModals" } do
		local old = starterGui:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	buildHud(starterGui)
	buildModals(starterGui)

	-- A ScrollingFrame clips its descendants, and a UIStroke straddles the
	-- edge it is drawn on. Rows are sized (1, -8) and left-aligned, so they
	-- sit flush at x=0 and the OUTER half of their left border was being cut
	-- off while the right kept its 8px gutter -- a visibly lopsided box. The
	-- first row loses its TOP border to the same clip, so both edges get a
	-- gutter (the gem store shows this most clearly).
	-- Giving every list a left gutter fixes it everywhere at once, including
	-- any list added later.
	for _, gui in { starterGui:FindFirstChild("TradingHUD"), starterGui:FindFirstChild("TradingModals") } do
		if gui then
			for _, scroll in gui:GetDescendants() do
				if scroll:IsA("ScrollingFrame") and scroll:FindFirstChildWhichIsA("UIPadding") == nil then
					new("UIPadding", {
						PaddingLeft = UDim.new(0, 6),
						PaddingTop = UDim.new(0, 6),
					}, scroll)
				end
			end
		end
	end
	return "GUI built into StarterGui (TradingHUD + TradingModals)"
end

return GuiBuilder
