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
}
local ICONS = {
	Gem = "rbxassetid://17368064384",
	Trade = "rbxassetid://15403064919",
	Inventory = "rbxassetid://15402958715",
	Player = "rbxassetid://92109681457452",
	Star = "rbxassetid://17368097932",
	Shop = "rbxassetid://15402855334", -- coin chest
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
		Text = "✕",
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
		Text = "✕",
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
	local boardPanel = panel("BoardPanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(760, 560),
		Visible = false,
	}, parent)

	label("Title", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(300, 24),
		Text = "📌 Trade Board",
		TextSize = 18,
	}, boardPanel)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "✕",
		BackgroundColor3 = C.Bad,
	}, boardPanel)
	-- context-aware post: label + action depend on the active tab
	button("PostButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -44, 0, 8),
		Size = UDim2.fromOffset(150, 26),
		Text = "+ Post trade",
		TextSize = 13,
		BackgroundColor3 = C.Good,
	}, boardPanel)

	-- two tabs: Trades (item-for-item swaps) · Market (per-item order book —
	-- every buy order and sell listing, priced in gems)
	local tabRow = new("Frame", {
		Name = "TabRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 30),
	}, boardPanel)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabRow)
	local function tab(name: string, text: string, order: number)
		local b = button(name, {
			Size = UDim2.fromOffset(150, 30),
			Text = text,
			TextSize = 13,
			BackgroundColor3 = C.BgLight,
			LayoutOrder = order,
		}, tabRow)
		return b
	end
	tab("TabTrades", "🔁 Trades", 1)
	tab("TabMarket", "📈 Market", 2)

	local list = new("ScrollingFrame", {
		Name = "ListingList",
		Position = UDim2.fromOffset(12, 78),
		Size = UDim2.new(1, -24, 1, -90),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, boardPanel)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	label("EmptyLabel", {
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "Nothing here yet — be the first!",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.TextDim,
		Visible = false,
	}, boardPanel)

	-- listing row template (tall enough for chips + a multi-line stats/payout block)
	local row = new("Frame", {
		Name = "ListingRow",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, 156),
		Visible = false,
	}, list)
	corner(row, 6)
	stroke(row, C.Stroke, 1)

	label("PosterLabel", {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.fromOffset(240, 16),
		Text = "PosterName",
		Font = FONT_LIGHT,
		TextSize = 11,
		TextColor3 = C.TextDim,
	}, row)
	label("Badge", {
		Position = UDim2.fromOffset(250, 4),
		Size = UDim2.fromOffset(120, 16),
		Text = "AUTO",
		TextSize = 11,
		TextColor3 = C.Warn,
	}, row)

	local giveHolder = new("Frame", {
		Name = "GiveHolder",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 24),
		Size = UDim2.fromOffset(200, 64),
	}, row)
	-- swap gems: never a fake item card, just an icon + "+N gems (after tax)"
	new("ImageLabel", {
		Name = "GiveGemsIcon",
		Image = ICONS.Gem,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 88),
		Size = UDim2.fromOffset(14, 14),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	}, row)
	label("GiveGemsLabel", {
		Position = UDim2.fromOffset(28, 88),
		Size = UDim2.fromOffset(182, 14),
		Text = "",
		TextSize = 12,
		TextColor3 = C.Gem,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, giveHolder)

	-- chip template (shared look for items + gems)
	local chip = new("Frame", {
		Name = "Chip",
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(46, 62),
		Visible = false,
	}, giveHolder)
	corner(chip, 6)
	local chipIcon = new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, -16, 0, 6),
		Size = UDim2.fromOffset(32, 32),
		ScaleType = Enum.ScaleType.Fit,
	}, chip)
	corner(chipIcon, 6)
	label("CountLabel", {
		Position = UDim2.fromOffset(2, 42),
		Size = UDim2.new(1, -4, 0, 16),
		Text = "x1",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, chip)

	label("ArrowLabel", {
		Position = UDim2.fromOffset(216, 40),
		Size = UDim2.fromOffset(26, 26),
		Text = "⇄",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.TextDim,
	}, row)

	local wantHolder = new("Frame", {
		Name = "WantHolder",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(248, 24),
		Size = UDim2.fromOffset(200, 64),
	}, row)
	new("ImageLabel", {
		Name = "WantGemsIcon",
		Image = ICONS.Gem,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(248, 88),
		Size = UDim2.fromOffset(14, 14),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	}, row)
	label("WantGemsLabel", {
		Position = UDim2.fromOffset(266, 88),
		Size = UDim2.fromOffset(182, 14),
		Text = "",
		TextSize = 12,
		TextColor3 = C.Gem,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, wantHolder)

	-- stats/payout block: per-unit + total Value/RAP/Store Cost for bulk rows,
	-- "Interested: ..." for ask-first swap rows the poster owns. Sits below
	-- the chips, full width minus the bottom-right controls' reserved column.
	label("InfoLabel", {
		Position = UDim2.fromOffset(10, 104),
		Size = UDim2.new(1, -178, 0, 44),
		Text = "",
		Font = FONT_LIGHT,
		TextSize = 11,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, row)

	-- bottom-right controls, pinned to the row's bottom edge regardless of
	-- how tall the row grows (stats block above can vary in line count)
	local countBox = new("TextBox", {
		Name = "CountBox",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -136, 1, -8),
		Size = UDim2.fromOffset(52, 30),
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		Font = FONT,
		TextColor3 = C.Text,
		TextSize = 13,
		Text = "1",
		Visible = false, -- bulk rows only
		ClearTextOnFocus = false,
	}, row)
	corner(countBox, 6)

	button("ActionButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -8),
		Size = UDim2.fromOffset(118, 36),
		Text = "Accept",
		TextSize = 13,
		BackgroundColor3 = C.Good,
	}, row)

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

	-- two half-width panels: sellers (asks) and buyers (bids)
	local function bookSide(name: string, headerText: string, x: UDim2)
		local sidePanel = new("Frame", {
			Name = name,
			BackgroundColor3 = C.Bg,
			BorderSizePixel = 0,
			Position = x,
			Size = UDim2.new(0.5, -6, 1, -86),
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
	bookSide("SellersPanel", "FOR SALE — cheapest first", UDim2.fromOffset(0, 86))
	bookSide("BuyersPanel", "BUY ORDERS — best price first", UDim2.new(0.5, 6, 0, 86))

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
		Text = "✕",
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

local function buildShopPanel(parent: Instance)
	local shop = panel("ShopPanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.66, 0.84),
		BackgroundColor3 = C.Bg,
		Visible = false,
	}, parent)
	new("UISizeConstraint", { MaxSize = Vector2.new(900, 700) }, shop)
	corner(shop, 14)
	-- thick gold frame + a subtle vertical gradient: reads as the premium screen
	stroke(shop, C.Gold, 3)
	grad(shop, Color3.fromRGB(40, 42, 54), Color3.fromRGB(22, 23, 30), 90)

	local function capText(inst: Instance, maxSize: number)
		new("UITextSizeConstraint", { MaxTextSize = maxSize }, inst)
	end

	-- title bar (gradient, gold title with a dark stroke, red X)
	local titleBar = new("Frame", {
		Name = "TitleBar",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.082),
	}, shop)
	corner(titleBar, 12)
	grad(titleBar, Color3.fromRGB(46, 48, 60), Color3.fromRGB(28, 29, 38), 90)
	local title = label("Title", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.7),
		Text = "SHOP",
		TextScaled = true,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, titleBar)
	textStroke(title, 2, 0.15)
	capText(title, 26)
	local close = button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		Text = "✕",
		TextScaled = true,
		BackgroundColor3 = C.Bad,
	}, titleBar)
	textStroke(close, 1.5, 0.2)
	capText(close, 18)

	-- scrolling body: SectionTemplate cloned per section
	local body = new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromScale(0.025, 0.1),
		Size = UDim2.fromScale(0.95, 0.88),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, shop)
	new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, body)

	-- SectionTemplate: gold ribbon header, then a column of feature cards, then a
	-- grid of the smaller packs. Renderer fills whichever it needs and hides the rest.
	local section = new("Frame", {
		Name = "SectionTemplate",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, body)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, section)

	-- gold ribbon header
	local header = new("Frame", {
		Name = "SectionHeader",
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 1,
	}, section)
	corner(header, 8)
	grad(header, Color3.fromRGB(255, 208, 92), Color3.fromRGB(238, 150, 24), 90)
	local headerLbl = label("Label", {
		Position = UDim2.fromScale(0.02, 0),
		Size = UDim2.fromScale(0.96, 1),
		Text = "SECTION",
		TextColor3 = Color3.fromRGB(40, 28, 6),
		TextSize = 16,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, header)
	textStroke(headerLbl, 1, 0.7)

	-- feature-card column (wide hero cards)
	local features = new("Frame", {
		Name = "Features",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, section)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, features)

	-- grid of medium cards
	local grid = new("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
	}, section)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 196),
		CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)

	--------------------------------------------------------------------------
	-- MEDIUM CARD template (art on top, name/price below) — one per small pack
	--------------------------------------------------------------------------
	local card = new("Frame", {
		Name = "OfferCard",
		BackgroundColor3 = Color3.fromRGB(46, 50, 63),
		BorderSizePixel = 0,
		Visible = false,
	}, grid)
	corner(card, 14)
	dropShadow(card, 14)
	-- neutral dark blue-grey (the game's palette) so the cyan/gold/green accents
	-- pop as one system instead of fighting a purple card
	grad(card, Color3.fromRGB(60, 65, 82), Color3.fromRGB(30, 32, 41), 115)
	gradStroke(card, Color3.fromRGB(120, 210, 224), Color3.fromRGB(54, 120, 140), 2)
	sheen(card, 14)
	-- dark glossy medallion behind the icon (neutral, so the gem art pops)
	local glow = new("Frame", {
		Name = "IconGlow",
		BackgroundColor3 = Color3.fromRGB(44, 48, 60),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.26),
		Size = UDim2.fromScale(0.6, 0.33),
		ZIndex = 2,
	}, card)
	corner(glow, 100)
	grad(glow, Color3.fromRGB(66, 74, 94), Color3.fromRGB(32, 35, 45), 90)
	new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.26),
		Size = UDim2.fromScale(0.5, 0.34),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, card)
	local cardName = label("OfferName", {
		Position = UDim2.fromScale(0.05, 0.46),
		Size = UDim2.fromScale(0.9, 0.09),
		Text = "Offer",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, card)
	textStroke(cardName)
	capText(cardName, 15)
	local contents = label("Contents", {
		Position = UDim2.fromScale(0.05, 0.55),
		Size = UDim2.fromScale(0.9, 0.1),
		Text = "",
		TextScaled = true,
		TextColor3 = C.Gem,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, card)
	textStroke(contents)
	capText(contents, 19)
	-- gold "+N% BONUS" pill
	local bonus = label("Bonus", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromScale(0.66, 0.08),
		Text = "",
		Font = FONT,
		BackgroundColor3 = C.Gold,
		BackgroundTransparency = 0,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(40, 28, 6),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 3,
	}, card)
	corner(bonus, 6)
	grad(bonus, Color3.fromRGB(255, 208, 92), Color3.fromRGB(240, 160, 30), 90)
	capText(bonus, 12)
	local timeLeft = label("TimeLeft", {
		Position = UDim2.fromScale(0.05, 0.745),
		Size = UDim2.fromScale(0.9, 0.06),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, card)
	capText(timeLeft, 10)
	local wasPrice = label("WasPrice", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.fromScale(0.28, 0.06),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	}, card)
	capText(wasPrice, 11)
	new("Frame", {
		Name = "Strike",
		BackgroundColor3 = C.TextDim,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 2, 0, 1),
		Visible = false,
	}, wasPrice)
	-- green gradient BUY CTA: [Robux icon] [price], centered as a group
	local buyBtn = button("BuyButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromScale(0.86, 0.16),
		Text = "",
		BackgroundColor3 = C.Good,
		ZIndex = 3,
	}, card)
	grad(buyBtn, Color3.fromRGB(120, 232, 158), Color3.fromRGB(58, 178, 104), 90)
	stroke(buyBtn, Color3.fromRGB(36, 130, 74), 1.5)
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
		Size = UDim2.fromScale(0.7, 0.7),
		LayoutOrder = 1,
		ZIndex = 4,
	}, buyBtn)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, rbx)
	local price = label("PriceLabel", {
		Size = UDim2.fromScale(0.62, 0.82),
		Text = "BUY",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		ZIndex = 4,
	}, buyBtn)
	textStroke(price, 1.4, 0.2)
	capText(price, 15)
	local badge = label("Badge", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1.01, 0.03),
		Size = UDim2.fromScale(0.56, 0.11),
		Text = "",
		BackgroundColor3 = C.Warn,
		BackgroundTransparency = 0,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(40, 28, 6),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 4,
	}, card)
	corner(badge, 6)
	grad(badge, Color3.fromRGB(255, 208, 92), Color3.fromRGB(240, 150, 24), 90)
	stroke(badge, Color3.fromRGB(180, 110, 10), 1)
	capText(badge, 11)

	--------------------------------------------------------------------------
	-- FEATURE CARD template (wide hero: ribbon, big art left, text right)
	--------------------------------------------------------------------------
	local feat = new("Frame", {
		Name = "FeatureCard",
		BackgroundColor3 = Color3.fromRGB(48, 52, 66),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 166),
		Visible = false,
	}, features)
	corner(feat, 16)
	dropShadow(feat, 16)
	grad(feat, Color3.fromRGB(64, 69, 88), Color3.fromRGB(32, 34, 44), 115)
	gradStroke(feat, Color3.fromRGB(255, 226, 132), Color3.fromRGB(212, 132, 22), 2.6)
	sheen(feat, 16)
	-- corner tag (BEST VALUE / LIMITED / the offer's badge) — a compact gold
	-- pill in the top-right, so it doesn't restate the section header bar
	local ribbon = new("Frame", {
		Name = "Ribbon",
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.99, 0.08),
		Size = UDim2.fromScale(0.26, 0.16),
		ZIndex = 3,
	}, feat)
	corner(ribbon, 8)
	grad(ribbon, Color3.fromRGB(255, 208, 92), Color3.fromRGB(238, 150, 24), 90)
	stroke(ribbon, Color3.fromRGB(180, 110, 10), 1)
	local ribbonLbl = label("RibbonText", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.82),
		Text = "FEATURED",
		TextColor3 = Color3.fromRGB(40, 28, 6),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4, -- Global ZIndexBehavior: must beat the ribbon frame (3)
	}, ribbon)
	capText(ribbonLbl, 14)
	-- big art on the left, with a dark glossy medallion halo
	local fglow = new("Frame", {
		Name = "IconGlow",
		BackgroundColor3 = Color3.fromRGB(44, 48, 60),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.18, 0.62),
		Size = UDim2.fromOffset(108, 108),
		ZIndex = 2,
	}, feat)
	corner(fglow, 100)
	grad(fglow, Color3.fromRGB(66, 74, 94), Color3.fromRGB(32, 35, 45), 90)
	new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.18, 0.62),
		Size = UDim2.fromOffset(96, 96),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, feat)
	-- text block on the right
	local fName = label("OfferName", {
		Position = UDim2.fromScale(0.36, 0.28),
		Size = UDim2.fromScale(0.6, 0.16),
		Text = "Offer",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, feat)
	textStroke(fName)
	capText(fName, 22)
	local fContents = label("Contents", {
		Position = UDim2.fromScale(0.36, 0.46),
		Size = UDim2.fromScale(0.6, 0.15),
		Text = "",
		TextScaled = true,
		TextColor3 = C.Gem,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, feat)
	textStroke(fContents)
	capText(fContents, 24)
	local fBonus = label("Bonus", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0.36, 0.63),
		Size = UDim2.fromScale(0.26, 0.15),
		Text = "",
		Font = FONT,
		BackgroundColor3 = C.Gold,
		BackgroundTransparency = 0,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(40, 28, 6),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 3,
	}, feat)
	corner(fBonus, 6)
	grad(fBonus, Color3.fromRGB(255, 208, 92), Color3.fromRGB(240, 160, 30), 90)
	capText(fBonus, 13)
	local fWas = label("WasPrice", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.7, 0.87),
		Size = UDim2.fromScale(0.16, 0.1),
		Text = "",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	}, feat)
	capText(fWas, 13)
	new("Frame", {
		Name = "Strike",
		BackgroundColor3 = C.TextDim,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 2, 0, 1),
		Visible = false,
	}, fWas)
	local fBuy = button("BuyButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromScale(0.34, 0.2),
		Text = "",
		BackgroundColor3 = C.Good,
		ZIndex = 3,
	}, feat)
	grad(fBuy, Color3.fromRGB(120, 232, 158), Color3.fromRGB(58, 178, 104), 90)
	stroke(fBuy, Color3.fromRGB(36, 130, 74), 1.5)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.04, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, fBuy)
	local fRbx = new("ImageLabel", {
		Name = "RobuxIcon",
		Image = ICONS.Robux,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.72, 0.72),
		LayoutOrder = 1,
		ZIndex = 4,
	}, fBuy)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, fRbx)
	local fPrice = label("PriceLabel", {
		Size = UDim2.fromScale(0.6, 0.82),
		Text = "BUY",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		ZIndex = 4,
	}, fBuy)
	textStroke(fPrice, 1.4, 0.2)
	capText(fPrice, 18)

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
		Size = UDim2.fromScale(0.46, 0.5),
		Visible = false,
	}, parent)
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 420) }, free)
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
		Text = "✕",
		BackgroundColor3 = C.Bad,
	}, free)

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
		Position = UDim2.fromScale(0, 0.24),
		Size = UDim2.fromScale(1, 0.14),
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
		Position = UDim2.fromScale(0, 0.42),
		Size = UDim2.fromScale(1, 0.12),
		Text = "0 / 2,000 players",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, goal)
	capText(progress, 16)
	local blurb = label("GoalBlurb", {
		Position = UDim2.fromScale(0, 0.58),
		Size = UDim2.fromScale(1, 0.34),
		Text = "When we reach 2,000 players, free gems unlock for everyone — watch a short ad, get gems.",
		Font = FONT_LIGHT,
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, goal)
	capText(blurb, 13)

	-- ── unlocked (watch-ad) state ────────────────────────────────────────
	local watch = new("Frame", {
		Name = "WatchView",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.06, 0.18),
		Size = UDim2.fromScale(0.88, 0.74),
		Visible = false,
	}, free)
	local reward = label("RewardLabel", {
		Size = UDim2.fromScale(1, 0.2),
		Text = "Watch a short ad for +50 gems",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
	}, watch)
	capText(reward, 17)
	local watchBtn = button("WatchButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.fromScale(0.8, 0.24),
		Text = "WATCH AD",
		TextScaled = true,
		BackgroundColor3 = C.Good,
	}, watch)
	capText(watchBtn, 20)
	local remaining = label("RemainingLabel", {
		Position = UDim2.fromScale(0, 0.58),
		Size = UDim2.fromScale(1, 0.12),
		Text = "",
		TextScaled = true,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, watch)
	capText(remaining, 14)
	local status = label("StatusLabel", {
		Position = UDim2.fromScale(0, 0.72),
		Size = UDim2.fromScale(1, 0.22),
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
-- Rolls panel (the gacha NPC) — 5 tier cards, pay with gems OR items
--------------------------------------------------------------------------------

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
		Text = "✕",
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
		Text = "🎉 Events",
		TextSize = 18,
	}, events)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "✕",
		BackgroundColor3 = C.Bad,
	}, events)

	local list = new("ScrollingFrame", {
		Name = "EventList",
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(1, -24, 1, -56),
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
		Text = "✕",
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
		Text = "✕",
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
		Text = "✕",
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
	return "GUI built into StarterGui (TradingHUD + TradingModals)"
end

return GuiBuilder
