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
		TextSize = 14,
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
		TextSize = 14,
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

	iconButton("InventoryButton", ICONS.Inventory, "INVENTORY", UDim2.fromScale(0.955, 0.77))
	iconButton("TradeButton", ICONS.Trade, "TRADE", UDim2.fromScale(0.955, 0.57))
	iconButton("DebugGemsButton", ICONS.Gem, "+100 (DEBUG)", UDim2.fromScale(0.955, 0.37))

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
	for i, statName in { "ValueRow", "DemandRow", "RapRow" } do
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

	-- 9 real, editable slots (one item COPY each)
	for i = 1, GRID * GRID do
		local slot = new(mine and "ImageButton" or "ImageLabel", {
			Name = "Slot" .. i,
			BackgroundColor3 = C.BgLight,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Image = "",
			AutoButtonColor = mine or nil,
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

	label("Title", {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -360, 0, 24),
		Text = "Trading",
		TextSize = 18,
	}, tradePanel)
	label("Hint", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 14),
		Size = UDim2.fromOffset(320, 16),
		Text = "changing an offer resets both READYs",
		Font = FONT_LIGHT,
		TextSize = 11,
		TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, tradePanel)

	buildSide("YourSide", true, UDim2.fromOffset(14, 64), tradePanel)
	buildSide("TheirSide", false, UDim2.new(1, -(SIDE_W + 14), 0, 64), tradePanel)

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

	-- item picker: opens when an empty slot is clicked; PickerTile cloned per item
	local picker = panel("ItemPicker", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(380, 320),
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
	local pickerGrid = new("ScrollingFrame", {
		Name = "PickerGrid",
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 1, -52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
	}, picker)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(80, 96),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.Name,
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
-- Modals (inventory, invite, search, tooltip)
--------------------------------------------------------------------------------

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
	button("ResultTemplate", {
		Size = UDim2.new(1, 0, 0, 32),
		Text = "PlayerName (123)",
		TextSize = 12,
		BackgroundColor3 = C.BgLight,
		Visible = false, -- template
	}, results)
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
