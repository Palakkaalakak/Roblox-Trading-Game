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

	-- events + trade board have NO HUD buttons: their world NPCs/pillar are
	-- the way in (EventPrompt / BoardPrompt proximity prompts)
	iconButton("InventoryButton", ICONS.Inventory, "INVENTORY", UDim2.fromScale(0.955, 0.77))
	iconButton("TradeButton", ICONS.Trade, "TRADE", UDim2.fromScale(0.955, 0.57))
	iconButton("ProfileButton", ICONS.Player, "PLAYERS", UDim2.fromScale(0.955, 0.47))
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
		Text = "💎 ?",
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

	-- three tabs: Normal (swaps) · Bulk (buy orders) · Gem-Only (item shop)
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
	tab("TabNormal", "🔁 Normal", 1)
	tab("TabBulk", "📦 Bulk buy", 2)
	tab("TabGem", "💎 Gem shop", 3)

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
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, wantHolder)

	-- stats/payout block: per-unit + total Value/RAP/Store Cost for bulk rows,
	-- "Interested: ..." for ask-first swap rows the poster owns. Sits below
	-- the chips, full width minus the bottom-right controls' reserved column.
	label("InfoLabel", {
		Position = UDim2.fromOffset(10, 92),
		Size = UDim2.new(1, -178, 0, 56),
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
	-- Post modal
	--------------------------------------------------------------------------
	local post = panel("PostPanel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(500, 420),
		Visible = false,
		ZIndex = 10,
		BackgroundColor3 = C.Panel,
	}, boardPanel)
	label("Title", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(200, 22),
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
	button("ModeButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -44, 0, 8),
		Size = UDim2.fromOffset(130, 26),
		Text = "Mode: Swap",
		TextSize = 12,
		BackgroundColor3 = C.Accent,
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

	offerRow("GiveRow", 44, "YOU GIVE (escrowed when you post)")
	offerRow("WantRow", 162, "YOU WANT")

	button("AutoButton", {
		Position = UDim2.fromOffset(12, 284),
		Size = UDim2.fromOffset(230, 30),
		Text = "Auto-trade: ON",
		TextSize = 12,
		BackgroundColor3 = C.Good,
		ZIndex = 11,
	}, post)
	label("AutoHint", {
		Position = UDim2.fromOffset(12, 318),
		Size = UDim2.new(1, -24, 0, 30),
		Text = "ON: anyone can accept instantly, even while you're offline. OFF: you get notified and trade them yourself.",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextColor3 = C.TextDim,
		TextWrapped = true,
		ZIndex = 11,
	}, post)
	button("SubmitButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(200, 38),
		Text = "POST",
		TextSize = 15,
		BackgroundColor3 = C.Good,
		ZIndex = 11,
	}, post)

	-- item picker popup (shared by give/want rows)
	local picker = panel("BoardItemPicker", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(380, 300),
		Visible = false,
		ZIndex = 20,
		BackgroundColor3 = C.Panel,
	}, boardPanel)
	label("Title", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -50, 0, 20),
		Text = "Pick an item",
		TextSize = 14,
		ZIndex = 21,
	}, picker)
	button("CloseButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "✕",
		BackgroundColor3 = C.Bad,
		ZIndex = 21,
	}, picker)
	local pickGrid = new("ScrollingFrame", {
		Name = "PickGrid",
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
	}, picker)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(76, 92),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.Name,
	}, pickGrid)
	local pickTile = new("ImageButton", {
		Name = "PickTile",
		BackgroundColor3 = C.BgLight,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Image = "",
		Visible = false,
		ZIndex = 21,
	}, pickGrid)
	corner(pickTile, 6)
	local ptIcon2 = new("ImageLabel", {
		Name = "Icon",
		Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, -20, 0, 6),
		Size = UDim2.fromOffset(40, 40),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 22,
	}, pickTile)
	corner(ptIcon2, 6)
	label("ItemName", {
		Position = UDim2.fromOffset(4, 50),
		Size = UDim2.new(1, -8, 0, 26),
		Text = "Item",
		Font = FONT_LIGHT,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		ZIndex = 22,
	}, pickTile)
	label("CountLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromOffset(30, 12),
		Text = "",
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Warn,
		ZIndex = 22,
	}, pickTile)

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
	label("CostLabel", {
		Position = UDim2.fromOffset(340, 54),
		Size = UDim2.fromOffset(180, 16),
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
