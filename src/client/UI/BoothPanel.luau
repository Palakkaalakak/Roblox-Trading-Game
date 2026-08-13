--!strict
-- BoothPanel: the booth's OWN window. Nothing here routes through the Trade
-- Board — pressing E on a booth opens this, not the Market tab.
--
-- Two modes off the same layout:
--   OWNER   — your slots. Empty slot -> pick from your inventory, name a price,
--             it goes up. Filled slot -> take it down. Plus your tagline, your
--             skin, and the buy-a-slot button.
--   VISITOR — their stock, with a Buy on each. Read-only otherwise.
--
-- Slots are SQUARE by construction: the grid uses offset cells, so the cell is
-- the same number of pixels in both directions whatever the panel is doing.
--
-- Built at runtime rather than in GuiBuilder because it is entirely dynamic —
-- the grid size depends on purchased slots and the skin row on what's owned.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local BoothConfig = require(ReplicatedStorage.Shared.Config.BoothConfig)
local Net = require(script.Parent.Parent.Net)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)

local BoothPanel = {}

local CELL = 104 -- square, in pixels
local GAP = 10

-- TradingModals uses ZIndexBehavior.Global, so a child does NOT inherit its
-- parent's stacking context — absolute ZIndex alone decides draw order. Every
-- layer here is therefore stamped explicitly; leaving a descendant at the
-- default 1 puts it UNDER its own panel background, which reads as the whole
-- thing being dimmed out.
local Z_PANEL = 10
local Z_PANEL_CONTENT = Z_PANEL + 1
local Z_CELL = Z_PANEL + 2
local Z_CELL_CONTENT = Z_PANEL + 3
local Z_COMPOSER = 20
local Z_COMPOSER_CONTENT = Z_COMPOSER + 1
local Z_TILE = Z_COMPOSER + 2
local Z_TILE_CONTENT = Z_COMPOSER + 3

-- stamp an instance and everything already under it
local function zi(inst: Instance, n: number)
	if inst:IsA("GuiObject") then
		inst.ZIndex = n
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = n
		end
	end
end

local panel: Frame
local stallHeading: TextLabel
local lookHeading: TextLabel
local signHeading: TextLabel
local divider: Frame
local titleLabel: TextLabel
local subLabel: TextLabel
local taglineBox: TextBox
local skinRow: ScrollingFrame
local grid: ScrollingFrame
local hintLabel: TextLabel
local composer: Frame
local toast: (text: string, color: Color3) -> ()
local tooltip: any

local current: any = nil -- last booth payload we opened
local cells: { TextButton } = {}
local skinChips: { [string]: TextButton } = {}

local function isMine(data: any): boolean
	return data ~= nil and data.ownerUserId == Players.LocalPlayer.UserId
end

--------------------------------------------------------------------------------
-- Small builders
--------------------------------------------------------------------------------

local function corner(inst: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = inst
	return c
end

local function stroke(inst: Instance, color: Color3, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1.5
	s.Parent = inst
	return s
end

local function button(name: string, text: string, color: Color3, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Font = Theme.Font
	b.TextSize = 14
	b.TextColor3 = Theme.TextPrimary
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b, 6)
	return b
end

--------------------------------------------------------------------------------
-- Composer: pick an item you own, name a price
--------------------------------------------------------------------------------

local composerState = { itemId = nil :: string?, count = 1, price = 0 }
local composerGrid: ScrollingFrame
local composerCount: TextBox
local composerPrice: TextBox
local composerPost: TextButton
local composerPick: TextLabel

local function refreshComposer()
	for _, c in composerGrid:GetChildren() do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	local inv = InventoryController.inventory:get()
	local ids = {}
	for itemId, n in inv do
		if n > 0 then
			table.insert(ids, itemId)
		end
	end
	table.sort(ids, function(a, b)
		local sa = EconomyController.get(a)
		local sb = EconomyController.get(b)
		local va = sa and sa.value and sa.value.value or 0
		local vb = sb and sb.value and sb.value.value or 0
		if va ~= vb then
			return va > vb
		end
		return a < b
	end)
	EconomyController.ensure(ids)

	for order, itemId in ids do
		local snap = EconomyController.get(itemId)
		local tile = Instance.new("TextButton")
		tile.Name = itemId
		tile.LayoutOrder = order
		tile.Text = ""
		tile.BackgroundColor3 = Theme.BgLight
		tile.BorderSizePixel = 0
		tile.AutoButtonColor = true
		tile.ZIndex = Z_TILE
		tile.Parent = composerGrid
		corner(tile, 6)
		local edge = stroke(tile, Components.rarityColor(snap and snap.rarity), 1.5)

		local icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.fromScale(0.5, 0.06)
		icon.Size = UDim2.fromScale(0.62, 0.56)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = Z_TILE_CONTENT
		icon.Parent = tile
		Components.setIcon(icon, snap or { itemId = itemId })

		local count = Instance.new("TextLabel")
		count.BackgroundTransparency = 1
		count.Position = UDim2.fromScale(0.05, 0.64)
		count.Size = UDim2.fromScale(0.9, 0.16)
		count.Font = Theme.Font
		count.TextSize = 12
		count.TextColor3 = Theme.TextPrimary
		count.Text = "x" .. tostring(inv[itemId])
		count.ZIndex = Z_TILE_CONTENT
		count.Parent = tile

		local val = Instance.new("TextLabel")
		val.BackgroundTransparency = 1
		val.Position = UDim2.fromScale(0.05, 0.8)
		val.Size = UDim2.fromScale(0.9, 0.16)
		val.Font = Theme.FontLight
		val.TextSize = 11
		val.TextColor3 = Theme.Gem
		val.Text = snap and snap.value and ("~" .. tostring(snap.value.value)) or ""
		val.ZIndex = Z_TILE_CONTENT
		val.Parent = tile

		if tooltip then
			tooltip.attach(tile, function()
				return EconomyController.get(itemId), inv[itemId]
			end)
		end

		tile.Activated:Connect(function()
			composerState.itemId = itemId
			composerPick.Text = (snap and snap.name or itemId) .. "  (you own " .. tostring(inv[itemId]) .. ")"
			composerPick.TextColor3 = Theme.TextPrimary
			-- default the price to the item's live value: a sane starting point
			-- beats an empty box, and it's the number the seller is pricing against
			if composerPrice.Text == "" and snap and snap.value then
				composerPrice.Text = tostring(snap.value.value)
			end
			for _, other in composerGrid:GetChildren() do
				if other:IsA("TextButton") then
					local st = other:FindFirstChildWhichIsA("UIStroke")
					if st then
						st.Thickness = other == tile and 3 or 1.5
					end
				end
			end
			edge.Thickness = 3
		end)
	end
end

local function openComposer()
	composerState.itemId = nil
	composerCount.Text = "1"
	composerPrice.Text = ""
	composerPick.Text = "Pick something you own"
	composerPick.TextColor3 = Theme.TextDim
	refreshComposer()
	composer.Visible = true
end

--------------------------------------------------------------------------------
-- Grid
--------------------------------------------------------------------------------

-- The cell IS the button. An empty slot or a buy-slot cell is clicked anywhere
-- on the square rather than on a strip along its bottom.
--
-- Activated is connected exactly ONCE, here, and dispatches through a `handler`
-- field that render() overwrites. Connecting inside render stacked a new
-- listener every refresh, so one click fired as many times as the panel had
-- repainted — which for a Buy is real money.
local handlers: { [TextButton]: (() -> ())? } = {}
-- setter per cell, so render swaps the action-button callback instead of
-- connecting a fresh listener each time
local actHandlers: { [TextButton]: ((() -> ())?) -> () } = {}

local function cellAt(i: number): TextButton
	if cells[i] then
		return cells[i]
	end
	local cell = Instance.new("TextButton")
	cell.Name = "Slot" .. i
	cell.LayoutOrder = i
	cell.Text = ""
	cell.AutoButtonColor = true
	cell.BackgroundColor3 = Theme.BgLight
	cell.BorderSizePixel = 0
	cell.ZIndex = Z_CELL
	cell.Parent = grid
	corner(cell, 8)
	stroke(cell, Theme.Stroke, 1.5).Name = "Edge"
	cell.Activated:Connect(function()
		local fn = handlers[cell]
		if fn then
			fn()
		end
	end)

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0.05)
	icon.Size = UDim2.fromScale(0.58, 0.44)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = Z_CELL_CONTENT
	icon.Parent = cell

	local plus = Instance.new("TextLabel")
	plus.Name = "Plus"
	plus.BackgroundTransparency = 1
	plus.Size = UDim2.fromScale(1, 0.62)
	plus.Font = Theme.Font
	plus.TextSize = 30
	plus.TextColor3 = Theme.TextDim
	plus.Text = "+"
	plus.ZIndex = Z_CELL_CONTENT
	plus.Parent = cell

	local name = Instance.new("TextLabel")
	name.Name = "ItemName"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0.05, 0.5)
	name.Size = UDim2.fromScale(0.9, 0.15)
	name.Font = Theme.Font
	name.TextSize = 12
	name.TextScaled = true
	name.TextColor3 = Theme.TextPrimary
	name.Text = ""
	name.ZIndex = Z_CELL_CONTENT
	name.Parent = cell
	Instance.new("UITextSizeConstraint", name).MaxTextSize = 12

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.BackgroundTransparency = 1
	price.Position = UDim2.fromScale(0.05, 0.64)
	price.Size = UDim2.fromScale(0.9, 0.14)
	price.Font = Theme.Font
	price.TextSize = 12
	price.TextColor3 = Theme.Gem
	price.Text = ""
	price.ZIndex = Z_CELL_CONTENT
	price.Parent = cell

	-- only a FILLED cell gets its own button: "take down" and "buy" are explicit
	-- actions that should not fire from a stray click anywhere on the tile
	local act = button("Action", "", Theme.Bad, cell)
	act.Position = UDim2.fromScale(0.08, 0.79)
	act.Size = UDim2.fromScale(0.84, 0.17)
	act.TextSize = 12
	act.Visible = false
	zi(act, Z_CELL_CONTENT)
	local actHandler: (() -> ())? = nil
	act.Activated:Connect(function()
		if actHandler then
			actHandler()
		end
	end)
	cell:SetAttribute("HasAction", true)
	actHandlers[cell] = function(fn: (() -> ())?)
		actHandler = fn
	end

	cells[i] = cell
	return cell
end

local function render(data: any)
	current = data
	local mine = isMine(data)
	local listings = data.listings or {}

	titleLabel.Text = mine and "🏪 Your Booth" or ("🏪 " .. tostring(data.ownerName) .. "'s Booth")
	subLabel.Text = mine and ("%d of %d slots stocked"):format(#listings, data.slots)
		or (data.tagline ~= "" and data.tagline or "Open for trades.")

	taglineBox.Visible = mine
	skinRow.Visible = mine
	lookHeading.Visible = mine
	signHeading.Visible = mine
	divider.Visible = mine
	stallHeading.Text = mine and "ON YOUR STALL" or "FOR SALE"
	-- a visitor has no skin picker or sign box, so the stock grid takes the room
	grid.Size = mine and UDim2.new(1, -32, 0, 236) or UDim2.new(1, -32, 1, -140)
	if mine and not taglineBox:IsFocused() then
		taglineBox.Text = data.tagline or ""
	end

	for id, chip in skinChips do
		local equipped = id == data.skinId
		local edge = chip:FindFirstChild("Edge") :: UIStroke
		edge.Color = equipped and Theme.Good or Theme.Stroke
		edge.Thickness = equipped and 3 or 1.5
		local state = chip:FindFirstChild("State") :: TextLabel
		if equipped then
			state.Text = "Equipped"
			state.TextColor3 = Theme.Good
		end
	end

	-- Owner sees every slot (so there is somewhere to add). A visitor sees only
	-- what's actually for sale — an empty shelf is not their business.
	local total = mine and data.slots or #listings
	local buyable = mine and data.slots < BoothConfig.MaxSlots

	for i = 1, total do
		local cell = cellAt(i)
		local icon = cell:FindFirstChild("Icon") :: ImageLabel
		local plus = cell:FindFirstChild("Plus") :: TextLabel
		local name = cell:FindFirstChild("ItemName") :: TextLabel
		local price = cell:FindFirstChild("Price") :: TextLabel
		local act = cell:FindFirstChild("Action") :: TextButton
		local edge = cell:FindFirstChild("Edge") :: UIStroke
		cell.Visible = true
		cell.BackgroundColor3 = Theme.BgLight

		local row = listings[i]
		if row then
			icon.Visible = true
			plus.Visible = false
			plus.Size = UDim2.fromScale(1, 0.62)
			Components.setIcon(icon, row)
			name.Text = row.name
			price.Text = ("%d gems  x%d"):format(row.gemsPerCopy, row.remaining)
			edge.Color = Components.rarityColor(row.rarity)
			act.Visible = true
			act.Text = mine and "Take down" or ("Buy 1 — " .. row.gemsPerCopy)
			act.BackgroundColor3 = mine and Theme.Bad or Theme.Good
			if tooltip then
				tooltip.attach(cell, function()
					return EconomyController.get(row.itemId), InventoryController.inventory:get()[row.itemId]
				end)
			end
			handlers[cell] = nil -- the tile itself does nothing when stocked
			actHandlers[cell](function()
				task.spawn(function()
					if mine then
						local res = Net.invoke("CancelListing", row.listingId)
						toast(res and res.ok and "Taken off your booth." or "Couldn't take that down.", res and res.ok and Theme.Warn or Theme.Bad)
					else
						local res = Net.invoke("BuyFromListing", row.listingId, 1)
						if res and res.ok then
							toast(("Bought %s for %d gems!"):format(row.name, res.spent), Theme.Good)
						elseif res then
							toast(({
								insufficient_gems = "Not enough gems!",
								gone = "Too late — that one just went.",
								sold_out = "Too late — that one just went.",
								own_listing = "That's your own listing.",
							})[res.err] or ("Failed: " .. tostring(res.err)), Theme.Bad)
						end
					end
					BoothPanel.refresh()
				end)
			end)
		else
			icon.Visible = false
			plus.Visible = true
			plus.Size = UDim2.fromScale(1, 1)
			plus.TextColor3 = Theme.TextDim
			name.Text = ""
			price.Text = ""
			edge.Color = Theme.Stroke
			act.Visible = false
			actHandlers[cell](nil)
			handlers[cell] = openComposer -- the square is the button
		end
	end

	-- the buy-a-slot cell, owner only, after every real slot
	if buyable then
		local cell = cellAt(total + 1)
		local icon = cell:FindFirstChild("Icon") :: ImageLabel
		local plus = cell:FindFirstChild("Plus") :: TextLabel
		local name = cell:FindFirstChild("ItemName") :: TextLabel
		local price = cell:FindFirstChild("Price") :: TextLabel
		local act = cell:FindFirstChild("Action") :: TextButton
		cell.Visible = true
		cell.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
		icon.Visible = false
		plus.Visible = true
		plus.TextColor3 = Theme.Bg
		name.Text = ""
		price.Text = ""
		plus.Size = UDim2.fromScale(1, 1)
		act.Visible = false
		actHandlers[cell](nil)
		handlers[cell] = function() -- the square is the button
			task.spawn(function()
				Net.invoke("PromptPurchase", "booth_slot")
			end)
		end
		total += 1
	end

	for i = total + 1, #cells do
		cells[i].Visible = false
	end

	hintLabel.Text = mine and "Anything you put up here also shows on the Market — one price, one pool."
		or "Walk-up prices. The same stock is on the Market if you'd rather browse there."
end

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

function BoothPanel.build(gui: ScreenGui, toastFn: (string, Color3) -> (), tip: any)
	toast = toastFn
	tooltip = tip

	panel = Instance.new("Frame")
	panel.Name = "BoothPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(620, 596)
	panel.BackgroundColor3 = Theme.Panel
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = Z_PANEL
	panel.Parent = gui
	corner(panel, 10)
	stroke(panel, Theme.Stroke)

	titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(16, 12)
	titleLabel.Size = UDim2.fromOffset(420, 24)
	titleLabel.Font = Theme.Font
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Theme.TextPrimary
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "🏪 Booth"
	titleLabel.ZIndex = Z_PANEL_CONTENT
	titleLabel.Parent = panel

	subLabel = Instance.new("TextLabel")
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.fromOffset(16, 36)
	subLabel.Size = UDim2.fromOffset(500, 18)
	subLabel.Font = Theme.FontLight
	subLabel.TextSize = 13
	subLabel.TextColor3 = Theme.TextDim
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.Text = ""
	subLabel.ZIndex = Z_PANEL_CONTENT
	subLabel.Parent = panel

	local close = button("CloseButton", "X", Theme.Bad, panel)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(28, 28)
	zi(close, Z_PANEL_CONTENT)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	taglineBox = Instance.new("TextBox")
	taglineBox.Name = "Tagline"
	taglineBox.Position = UDim2.fromOffset(16, 522)
	taglineBox.Size = UDim2.new(1, -32, 0, 30)
	taglineBox.BackgroundColor3 = Theme.BgLight
	taglineBox.Font = Theme.FontLight
	taglineBox.TextSize = 13
	taglineBox.TextColor3 = Theme.TextPrimary
	taglineBox.PlaceholderText = "Say something to shoppers…"
	taglineBox.ClearTextOnFocus = false
	taglineBox.TextXAlignment = Enum.TextXAlignment.Left
	taglineBox.Text = ""
	taglineBox.ZIndex = Z_PANEL_CONTENT
	taglineBox.Parent = panel
	corner(taglineBox, 6)
	local tPad = Instance.new("UIPadding")
	tPad.PaddingLeft = UDim.new(0, 10)
	tPad.Parent = taglineBox
	taglineBox.FocusLost:Connect(function()
		task.spawn(function()
			local res = Net.invoke("SetBoothTagline", taglineBox.Text)
			if res and res.ok then
				taglineBox.Text = res.tagline
			end
			BoothPanel.refresh()
		end)
	end)

	skinRow = Instance.new("ScrollingFrame")
	skinRow.Name = "SkinRow"
	skinRow.ScrollBarThickness = 3
	skinRow.CanvasSize = UDim2.new()
	skinRow.AutomaticCanvasSize = Enum.AutomaticSize.X
	skinRow.ScrollingDirection = Enum.ScrollingDirection.X
	skinRow.BorderSizePixel = 0
	skinRow.BackgroundTransparency = 1
	skinRow.Position = UDim2.fromOffset(16, 396)
	skinRow.Size = UDim2.new(1, -32, 0, 102)
	skinRow.ZIndex = Z_PANEL_CONTENT
	skinRow.Parent = panel
	local skinLayout = Instance.new("UIListLayout")
	skinLayout.FillDirection = Enum.FillDirection.Horizontal
	skinLayout.Padding = UDim.new(0, 8)
	skinLayout.Parent = skinRow

	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromOffset(16, 84)
	grid.Size = UDim2.new(1, -32, 0, 236) -- exactly two rows of cells
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 5
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ZIndex = Z_PANEL_CONTENT
	grid.Parent = panel
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(CELL, CELL) -- square, always
	gl.CellPadding = UDim2.fromOffset(GAP, GAP)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid

	-- Section headings. Without them the panel is three floating widgets and a
	-- player has to guess what the swatch strip even is.
	local function heading(text: string, y: number): TextLabel
		local h = Instance.new("TextLabel")
		h.BackgroundTransparency = 1
		h.Position = UDim2.fromOffset(16, y)
		h.Size = UDim2.new(1, -32, 0, 14)
		h.Font = Theme.Font
		h.TextSize = 11
		h.TextColor3 = Theme.TextDim
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.Text = text
		h.ZIndex = Z_PANEL_CONTENT
		h.Parent = panel
		return h
	end
	stallHeading = heading("ON YOUR STALL", 66)
	lookHeading = heading("HOW YOUR STALL LOOKS", 378)
	signHeading = heading("YOUR SIGN", 504)

	divider = Instance.new("Frame")
	divider.BackgroundColor3 = Theme.Stroke
	divider.BackgroundTransparency = 0.5
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromOffset(16, 362)
	divider.Size = UDim2.new(1, -32, 0, 1)
	divider.ZIndex = Z_PANEL_CONTENT
	divider.Parent = panel

	hintLabel = Instance.new("TextLabel")
	hintLabel.BackgroundTransparency = 1
	hintLabel.AnchorPoint = Vector2.new(0, 1)
	hintLabel.Position = UDim2.new(0, 16, 1, -12)
	hintLabel.Size = UDim2.new(1, -32, 0, 18)
	hintLabel.Font = Theme.FontLight
	hintLabel.TextSize = 12
	hintLabel.TextColor3 = Theme.TextDim
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Text = ""
	hintLabel.ZIndex = Z_PANEL_CONTENT
	hintLabel.Parent = panel

	----------------------------------------------------------------------------
	-- Composer overlay
	----------------------------------------------------------------------------

	composer = Instance.new("Frame")
	composer.Name = "Composer"
	composer.Size = UDim2.fromScale(1, 1)
	-- fully opaque: it covers the panel while you pick, so the grid behind must
	-- not bleed through it
	composer.BackgroundColor3 = Theme.Panel
	composer.BackgroundTransparency = 0
	composer.BorderSizePixel = 0
	composer.Visible = false
	composer.ZIndex = Z_COMPOSER
	composer.Parent = panel
	corner(composer, 10)

	local cTitle = Instance.new("TextLabel")
	cTitle.BackgroundTransparency = 1
	cTitle.Position = UDim2.fromOffset(16, 12)
	cTitle.Size = UDim2.fromOffset(400, 22)
	cTitle.Font = Theme.Font
	cTitle.TextSize = 16
	cTitle.TextColor3 = Theme.TextPrimary
	cTitle.TextXAlignment = Enum.TextXAlignment.Left
	cTitle.Text = "Put something up for sale"
	cTitle.ZIndex = Z_COMPOSER_CONTENT
	cTitle.Parent = composer

	composerPick = Instance.new("TextLabel")
	composerPick.BackgroundTransparency = 1
	composerPick.Position = UDim2.fromOffset(16, 34)
	composerPick.Size = UDim2.fromOffset(420, 18)
	composerPick.Font = Theme.FontLight
	composerPick.TextSize = 13
	composerPick.TextColor3 = Theme.TextDim
	composerPick.TextXAlignment = Enum.TextXAlignment.Left
	composerPick.Text = "Pick something you own"
	composerPick.ZIndex = Z_COMPOSER_CONTENT
	composerPick.Parent = composer

	composerGrid = Instance.new("ScrollingFrame")
	composerGrid.Position = UDim2.fromOffset(16, 58)
	composerGrid.Size = UDim2.new(1, -32, 1, -122)
	composerGrid.BackgroundTransparency = 1
	composerGrid.BorderSizePixel = 0
	composerGrid.ScrollBarThickness = 5
	composerGrid.CanvasSize = UDim2.new()
	composerGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	composerGrid.ScrollingDirection = Enum.ScrollingDirection.Y
	composerGrid.ZIndex = Z_COMPOSER_CONTENT
	composerGrid.Parent = composer
	local cgl = Instance.new("UIGridLayout")
	cgl.CellSize = UDim2.fromOffset(88, 88) -- square here too
	cgl.CellPadding = UDim2.fromOffset(8, 8)
	cgl.SortOrder = Enum.SortOrder.LayoutOrder
	cgl.Parent = composerGrid

	-- Each number box carries a standing label above it. Placeholder text alone
	-- vanishes the moment you type, so the moment it matters — checking what you
	-- entered before committing — there is nothing left saying which box is which.
	local function numberBox(x: number, width: number, label: string, default: string): TextBox
		local cap = Instance.new("TextLabel")
		cap.BackgroundTransparency = 1
		cap.AnchorPoint = Vector2.new(0, 1)
		cap.Position = UDim2.new(0, x + 2, 1, -46)
		cap.Size = UDim2.fromOffset(width, 14)
		cap.Font = Theme.FontLight
		cap.TextSize = 11
		cap.TextColor3 = Theme.TextDim
		cap.TextXAlignment = Enum.TextXAlignment.Left
		cap.Text = label
		cap.ZIndex = Z_COMPOSER_CONTENT
		cap.Parent = composer

		local b = Instance.new("TextBox")
		b.AnchorPoint = Vector2.new(0, 1)
		b.Position = UDim2.new(0, x, 1, -14)
		b.Size = UDim2.fromOffset(width, 30)
		b.BackgroundColor3 = Theme.BgLight
		b.Font = Theme.Font
		b.TextSize = 14
		b.TextColor3 = Theme.TextPrimary
		b.ClearTextOnFocus = false
		b.Text = default
		b.ZIndex = Z_COMPOSER_CONTENT
		b.Parent = composer
		corner(b, 6)
		return b
	end
	composerCount = numberBox(16, 92, "How many", "1")
	composerPrice = numberBox(118, 118, "Price (gems each)", "")
	zi(composerCount, Z_COMPOSER_CONTENT)
	zi(composerPrice, Z_COMPOSER_CONTENT)

	local cancel = button("Cancel", "Cancel", Theme.BgLight, composer)
	cancel.AnchorPoint = Vector2.new(1, 1)
	cancel.Position = UDim2.new(1, -112, 1, -14)
	cancel.Size = UDim2.fromOffset(96, 30)
	cancel.ZIndex = Z_COMPOSER_CONTENT
	zi(cancel, Z_COMPOSER_CONTENT)
	cancel.Activated:Connect(function()
		composer.Visible = false
	end)

	composerPost = button("Post", "Put up for sale", Theme.Good, composer)
	composerPost.AnchorPoint = Vector2.new(1, 1)
	composerPost.Position = UDim2.new(1, -10, 1, -14)
	composerPost.Size = UDim2.fromOffset(96, 30)
	zi(composerPost, Z_COMPOSER_CONTENT)
	composerPost.ZIndex = Z_COMPOSER_CONTENT
	composerPost.Activated:Connect(function()
		local itemId = composerState.itemId
		if itemId == nil then
			toast("Pick an item first.", Theme.Bad)
			return
		end
		local count = math.floor(tonumber(composerCount.Text) or 0)
		local gems = math.floor(tonumber(composerPrice.Text) or 0)
		if count < 1 or gems < 1 then
			toast("Set how many, and a price of at least 1 gem.", Theme.Bad)
			return
		end
		task.spawn(function()
			local res = Net.invoke("PostListing", { kind = "sell", itemId = itemId, count = count, gemsPerCopy = gems })
			if res and res.ok then
				composer.Visible = false
				toast("Up on your booth!", Theme.Good)
			elseif res then
				toast(({
					slot_cap = "Every slot is full — take something down, or buy a slot.",
					insufficient_items = "You don't own that many!",
					gems_too_low = "Price at least 1 gem per copy.",
				})[res.err] or ("Couldn't post: " .. tostring(res.err)), Theme.Bad)
			end
			BoothPanel.refresh()
		end)
	end)
end

--------------------------------------------------------------------------------
-- Open / refresh
--------------------------------------------------------------------------------

-- A booth skin is PURE APPEARANCE, so the chooser has to show the appearance.
-- Each swatch draws a tiny stall in that skin's own colours — striped awning
-- over a counter — so you can see what you'd be putting in the plaza without
-- equipping it and walking outside to look.
--
-- Locked ones are shown, not hidden: a swatch you can see is a reason to buy,
-- a swatch you can't see is nothing. They carry a price tag and clicking one
-- opens the purchase instead of refusing with an error.
-- The preview shows the REAL THING, not a drawing of it.
--
-- This is the standard Roblox cosmetic-preview pattern: a ViewportFrame holding
-- a WorldModel, a clone of the actual object, and a Camera framed on its
-- bounding box. Avatar editors, inventories and item shops all do this rather
-- than maintaining 2D art per cosmetic. It is also the only version that stays
-- honest here: the booth model is hand-placed and swappable, so hand-drawn art
-- would start lying the moment the model is replaced. This re-renders whatever
-- is actually standing in the plaza.
local function boothTemplate(): Model?
	for _, m in CollectionService:GetTagged(BoothConfig.Tag) do
		if m:IsA("Model") then
			return m
		end
	end
	return nil
end

-- Same naming rule the server paints with, so preview and world agree.
local function tintClone(model: Model, skin: any)
	local canopy = Color3.fromRGB(skin.canopy[1], skin.canopy[2], skin.canopy[3])
	local trim = Color3.fromRGB(skin.trim[1], skin.trim[2], skin.trim[3])
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Canopy" or d.Name == BoothConfig.SkinMountName then
				d.Color = canopy
			elseif d.Name == "Trim" then
				d.Color = trim
			end
		end
	end
end

-- Strip what costs performance or renders wrong in a viewport: prompts have no
-- camera to face, and the storefront SurfaceGui would draw a second copy of this
-- very panel inside the swatch.
local function stripForPreview(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("ProximityPrompt") or d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") and d.Name == BoothConfig.AnchorName then
			-- The display board is whoever's stock, not part of the look. Left in,
			-- it is a big dark slab facing the camera that swallows the frame and
			-- hides the very parts the skin colours.
			d:Destroy()
		end
	end
end

local function makePreview(skin: any, parent: Instance): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.BackgroundColor3 = Color3.fromRGB(24, 27, 34)
	vp.BorderSizePixel = 0
	vp.Position = UDim2.fromOffset(8, 8)
	vp.Size = UDim2.fromOffset(76, 52)
	vp.Ambient = Color3.fromRGB(225, 225, 225)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.ZIndex = Z_PANEL_CONTENT + 1
	vp.Parent = parent
	corner(vp, 5)

	local template = boothTemplate()
	if template == nil then
		return vp -- nothing placed yet; the swatch stays an empty tile
	end

	local world = Instance.new("WorldModel")
	world.Parent = vp

	local clone = template:Clone()
	stripForPreview(clone)
	tintClone(clone, skin)
	clone.Parent = world

	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam

	-- Frame the WIDTH, not the whole bounding box. A stall is much wider than it
	-- is deep, so fitting the largest extent pushes the camera far enough back
	-- that the awning — the only part the skin actually colours — ends up a few
	-- pixels tall. Aim slightly above centre for the same reason.
	local cf, size = clone:GetBoundingBox()
	local dist = (size.X / 2) / math.tan(math.rad(cam.FieldOfView / 2)) * 0.82
	local target = cf.Position + Vector3.new(0, size.Y * 0.12, 0)
	-- shallow three-quarter: reads as an object without hiding the stripes
	local dir = Vector3.new(0.42, 0.2, -1).Unit
	cam.CFrame = CFrame.lookAt(target + dir * dist, target)
	return vp
end

local function makeSwatch(skin: any, owned: boolean): TextButton
	local tile = Instance.new("TextButton")
	tile.Name = "Skin_" .. skin.id
	tile.Text = ""
	tile.AutoButtonColor = true
	tile.Size = UDim2.fromOffset(92, 96)
	tile.BackgroundColor3 = Theme.BgLight
	tile.BorderSizePixel = 0
	tile.ZIndex = Z_PANEL_CONTENT
	corner(tile, 8)
	local edge = stroke(tile, Theme.Stroke, 1.5)
	edge.Name = "Edge"

	local vp = makePreview(skin, tile)
	if not owned then
		vp.ImageTransparency = 0.55 -- locked: visibly there, visibly not yours
	end


	local name = Instance.new("TextLabel")
	name.Name = "SkinName"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(4, 62)
	name.Size = UDim2.fromOffset(84, 14)
	name.Font = Theme.Font
	name.TextSize = 10
	name.TextScaled = true
	name.TextColor3 = Theme.TextPrimary
	name.Text = skin.name
	name.ZIndex = Z_PANEL_CONTENT + 1
	name.Parent = tile
	Instance.new("UITextSizeConstraint", name).MaxTextSize = 10

	local state = Instance.new("TextLabel")
	state.Name = "State"
	state.BackgroundTransparency = 1
	state.Position = UDim2.fromOffset(4, 78)
	state.Size = UDim2.fromOffset(84, 14)
	state.Font = Theme.FontLight
	state.TextSize = 10
	state.TextColor3 = owned and Theme.Good or Theme.Gem
	state.Text = owned and "Owned" or "Robux"
	state.ZIndex = Z_PANEL_CONTENT + 1
	state.Parent = tile
	Instance.new("UITextSizeConstraint", state).MaxTextSize = 10

	return tile
end

local function buildSkinChips(skins: { any }, owned: { [string]: boolean })
	if next(skinChips) ~= nil then
		return
	end
	for _, skin in skins do
		local isOwned = owned[skin.id] == true or skin.id == BoothConfig.DefaultSkinId
		local tile = makeSwatch(skin, isOwned)
		tile.Parent = skinRow
		tile.Activated:Connect(function()
			task.spawn(function()
				if not isOwned then
					-- locked: take them to the purchase rather than a dead end
					if skin.offerId then
						Net.invoke("PromptPurchase", skin.offerId)
					else
						toast(skin.name .. " isn't for sale — it's earned.", Theme.Warn)
					end
					return
				end
				local res = Net.invoke("SetBoothSkin", skin.id)
				if res and not res.ok then
					toast("Couldn't equip that.", Theme.Warn)
				end
				BoothPanel.refresh()
			end)
		end)
		skinChips[skin.id] = tile
	end
end

function BoothPanel.refresh()
	if not panel.Visible or current == nil then
		return
	end
	task.spawn(function()
		local res = Net.invoke("GetBooths")
		if not (res and res.ok and panel.Visible) then
			return
		end
		buildSkinChips(res.skins or {}, res.owned or {})
		for _, b in res.booths do
			if b.boothId == current.boothId then
				if b.claimed then
					render(b)
				else
					panel.Visible = false
				end
				return
			end
		end
	end)
end

function BoothPanel.open(data: any)
	if data == nil or not data.claimed then
		return
	end
	Components.closeOtherPanels(panel)
	current = data
	panel.Visible = true
	composer.Visible = false
	render(data)
	BoothPanel.refresh() -- pull skins + the freshest listings
end

return BoothPanel
