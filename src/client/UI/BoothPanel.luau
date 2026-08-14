--!strict
-- BoothPanel: the booth's own window. Pressing E on a booth opens this, never
-- the Trade Board — that is a different surface for a different job.
--
-- Two tabs, built to the same spec as the Trade Board's tab row (150x30
-- buttons, BgLight idle / Accent active, 6px gap) so a booth reads as part of
-- this game rather than a bolted-on menu:
--   STALL      — your slots. Empty -> pick from inventory and name a price.
--                Filled -> take it down. A visitor sees only what is for sale,
--                with a Buy on each.
--   CUSTOMISE  — how the stall looks, and what the sign says. Owner only.
--
-- Skin previews are ViewportFrames holding a clone of the ACTUAL placed booth,
-- tinted per skin — the standard Roblox cosmetic-preview pattern. It cannot
-- drift from the world, and swapping the hand-placed model re-renders every
-- swatch for free.
--
-- LAYERING: TradingModals uses ZIndexBehavior.Global, so a child does NOT
-- inherit its parent's stacking context. Every layer is stamped explicitly;
-- one left at the default 1 renders under its own panel background.

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

local CELL = 104 -- slot square, px
local GAP = 10
local SWATCH_W, SWATCH_H = 116, 118

local Z_PANEL = 10
local Z_CONTENT = Z_PANEL + 1
local Z_CELL = Z_PANEL + 2
local Z_CELL_TOP = Z_PANEL + 3
local Z_COMPOSER = 20
local Z_COMPOSER_TOP = Z_COMPOSER + 1
local Z_TILE = Z_COMPOSER + 2
local Z_TILE_TOP = Z_COMPOSER + 3

local panel: Frame
local titleLabel: TextLabel
local subLabel: TextLabel
local tabRow: Frame
local tabButtons: { [string]: TextButton } = {}
local stallPage: Frame
local customisePage: Frame
local grid: ScrollingFrame
local hintLabel: TextLabel
local skinGrid: ScrollingFrame
local taglineBox: TextBox
local composer: Frame
local confirm: Frame
local openBuyConfirm: (row: any) -> ()
local toast: (text: string, color: Color3) -> ()
local tooltip: any

local current: any = nil
local cells: { TextButton } = {}
local skinChips: { [string]: TextButton } = {}
local handlers: { [TextButton]: (() -> ())? } = {}
local actHandlers: { [TextButton]: ((() -> ())?) -> () } = {}

local function isMine(data: any): boolean
	return data ~= nil and data.ownerUserId == Players.LocalPlayer.UserId
end

--------------------------------------------------------------------------------
-- Builders
--------------------------------------------------------------------------------

local function corner(inst: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = inst
end

local function stroke(inst: Instance, color: Color3, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1.5
	s.Parent = inst
	return s
end

local function button(name: string, text: string, color: Color3, parent: Instance, z: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Font = Theme.Font
	b.TextSize = 14
	b.TextColor3 = Theme.TextPrimary
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.ZIndex = z
	b.Parent = parent
	corner(b, 6)
	return b
end

local function heading(text: string, parent: Instance): TextLabel
	local h = Instance.new("TextLabel")
	h.BackgroundTransparency = 1
	h.Size = UDim2.new(1, 0, 0, 14)
	h.Font = Theme.Font
	h.TextSize = 11
	h.TextColor3 = Theme.TextDim
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.Text = text
	h.ZIndex = Z_CONTENT
	h.Parent = parent
	return h
end

--------------------------------------------------------------------------------
-- Skin previews: a ViewportFrame of the real model
--------------------------------------------------------------------------------

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

local function stripForPreview(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("ProximityPrompt") or d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") and d.Name == BoothConfig.AnchorName then
			-- the display board is whoever's stock, not part of the look, and
			-- left in it is a dark slab that swallows the frame
			d:Destroy()
		end
	end
end

local function makePreview(skin: any, parent: Instance, size: UDim2): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
	vp.BorderSizePixel = 0
	vp.Position = UDim2.fromOffset(6, 6)
	vp.Size = size
	vp.Ambient = Color3.fromRGB(235, 235, 235)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.ZIndex = Z_CONTENT + 1
	vp.Parent = parent
	corner(vp, 6)

	local template = boothTemplate()
	if template == nil then
		return vp -- nothing placed yet
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

	-- Frame the WIDTH: a stall is far wider than deep, so fitting the largest
	-- extent pushes the awning — the only part a skin colours — to a few pixels.
	local cf, msize = clone:GetBoundingBox()
	local dist = (msize.X / 2) / math.tan(math.rad(cam.FieldOfView / 2)) * 0.8
	local target = cf.Position + Vector3.new(0, msize.Y * 0.1, 0)
	local dir = Vector3.new(0.4, 0.2, -1).Unit
	cam.CFrame = CFrame.lookAt(target + dir * dist, target)
	return vp
end

--------------------------------------------------------------------------------
-- Composer
--------------------------------------------------------------------------------

local composerState = { itemId = nil :: string? }
local composerGrid: ScrollingFrame
local composerCount: TextBox
local composerPrice: TextBox
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
	EconomyController.ensure(ids)
	table.sort(ids, function(a, b)
		local sa, sb = EconomyController.get(a), EconomyController.get(b)
		local va = sa and sa.value and sa.value.value or 0
		local vb = sb and sb.value and sb.value.value or 0
		if va ~= vb then
			return va > vb
		end
		return a < b
	end)

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
		icon.Position = UDim2.fromScale(0.5, 0.07)
		icon.Size = UDim2.fromScale(0.6, 0.48)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = Z_TILE_TOP
		icon.Parent = tile
		Components.setIcon(icon, snap or { itemId = itemId })

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromScale(0.05, 0.57)
		name.Size = UDim2.fromScale(0.9, 0.17)
		name.Font = Theme.Font
		name.TextSize = 10
		name.TextScaled = true
		name.TextColor3 = Theme.TextPrimary
		name.Text = snap and snap.name or itemId
		name.ZIndex = Z_TILE_TOP
		name.Parent = tile
		Instance.new("UITextSizeConstraint", name).MaxTextSize = 10

		local count = Instance.new("TextLabel")
		count.BackgroundTransparency = 1
		count.Position = UDim2.fromScale(0.05, 0.76)
		count.Size = UDim2.fromScale(0.9, 0.18)
		count.Font = Theme.Font
		count.TextSize = 11
		count.TextColor3 = Theme.Gem
		count.Text = ("x%d  ~%s"):format(inv[itemId], snap and snap.value and tostring(snap.value.value) or "?")
		count.ZIndex = Z_TILE_TOP
		count.Parent = tile

		if tooltip then
			tooltip.attach(tile, function()
				return EconomyController.get(itemId), inv[itemId]
			end)
		end

		tile.Activated:Connect(function()
			composerState.itemId = itemId
			composerPick.Text = ("%s — you own %d"):format(snap and snap.name or itemId, inv[itemId])
			composerPick.TextColor3 = Theme.TextPrimary
			if composerPrice.Text == "" and snap and snap.value then
				composerPrice.Text = tostring(snap.value.value)
			end
			for _, other in composerGrid:GetChildren() do
				if other:IsA("TextButton") then
					local st = other:FindFirstChildWhichIsA("UIStroke")
					if st then
						st.Thickness = 1.5
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
-- Slot cells
--------------------------------------------------------------------------------

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
	-- connected ONCE: connecting inside render stacked listeners, so a click
	-- fired as many times as the panel had repainted
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
	icon.Size = UDim2.fromScale(0.56, 0.42)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = Z_CELL_TOP
	icon.Parent = cell

	local plus = Instance.new("TextLabel")
	plus.Name = "Plus"
	plus.BackgroundTransparency = 1
	plus.Size = UDim2.fromScale(1, 1)
	plus.Font = Theme.Font
	plus.TextSize = 30
	plus.TextColor3 = Theme.TextDim
	plus.Text = "+"
	plus.ZIndex = Z_CELL_TOP
	plus.Parent = cell

	local name = Instance.new("TextLabel")
	name.Name = "ItemName"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0.05, 0.48)
	name.Size = UDim2.fromScale(0.9, 0.15)
	name.Font = Theme.Font
	name.TextSize = 12
	name.TextScaled = true
	name.TextColor3 = Theme.TextPrimary
	name.Text = ""
	name.ZIndex = Z_CELL_TOP
	name.Parent = cell
	Instance.new("UITextSizeConstraint", name).MaxTextSize = 12

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.BackgroundTransparency = 1
	price.Position = UDim2.fromScale(0.05, 0.63)
	price.Size = UDim2.fromScale(0.9, 0.14)
	price.Font = Theme.Font
	price.TextSize = 12
	price.TextColor3 = Theme.Gem
	price.Text = ""
	price.ZIndex = Z_CELL_TOP
	price.Parent = cell

	local act = button("Action", "", Theme.Bad, cell, Z_CELL_TOP)
	act.Position = UDim2.fromScale(0.08, 0.79)
	act.Size = UDim2.fromScale(0.84, 0.17)
	act.TextSize = 12
	act.Visible = false
	local actHandler: (() -> ())? = nil
	act.Activated:Connect(function()
		if actHandler then
			actHandler()
		end
	end)
	actHandlers[cell] = function(fn)
		actHandler = fn
	end

	cells[i] = cell
	return cell
end

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------

local function selectTab(tab: string)
	for key, b in tabButtons do
		b.BackgroundColor3 = (key == tab) and Theme.Accent or Theme.BgLight
	end
	stallPage.Visible = tab == "stall"
	customisePage.Visible = tab == "customise"
end

local function renderSlots(data: any, mine: boolean)
	local listings = data.listings or {}
	-- Owner sees every slot, so there is somewhere to add. A visitor sees only
	-- what is for sale — an empty shelf is not their business.
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
			handlers[cell] = nil
			actHandlers[cell](function()
				task.spawn(function()
					if mine then
						local res = Net.invoke("CancelListing", row.listingId)
						toast(
							res and res.ok and "Taken off your booth." or "Couldn't take that down.",
							res and res.ok and Theme.Warn or Theme.Bad
						)
					else
						-- never spend straight off a click: confirm first, and let
						-- them pick how many
						openBuyConfirm(row)
						return
					end
					BoothPanel.refresh()
				end)
			end)
		else
			icon.Visible = false
			plus.Visible = true
			plus.TextColor3 = Theme.TextDim
			name.Text = ""
			price.Text = ""
			edge.Color = Theme.Stroke
			act.Visible = false
			actHandlers[cell](nil)
			handlers[cell] = openComposer -- the square is the button
		end
	end

	if buyable then
		local cell = cellAt(total + 1)
		local icon = cell:FindFirstChild("Icon") :: ImageLabel
		local plus = cell:FindFirstChild("Plus") :: TextLabel
		local act = cell:FindFirstChild("Action") :: TextButton
		;(cell:FindFirstChild("ItemName") :: TextLabel).Text = ""
		;(cell:FindFirstChild("Price") :: TextLabel).Text = ""
		cell.Visible = true
		cell.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
		icon.Visible = false
		plus.Visible = true
		plus.TextColor3 = Theme.Bg
		act.Visible = false
		actHandlers[cell](nil)
		handlers[cell] = function()
			task.spawn(function()
				Net.invoke("PromptPurchase", "booth_slot")
			end)
		end
		total += 1
	end

	for i = total + 1, #cells do
		cells[i].Visible = false
	end
end

local function render(data: any)
	current = data
	local mine = isMine(data)
	local listings = data.listings or {}

	titleLabel.Text = mine and "Your Booth" or (tostring(data.ownerName) .. "'s Booth")
	subLabel.Text = mine and ("%d of %d slots stocked"):format(#listings, data.slots)
		or (data.tagline ~= "" and data.tagline or "Open for trades.")

	-- a visitor has nothing to customise, so the tab row disappears entirely
	tabRow.Visible = mine
	if not mine then
		selectTab("stall")
	end
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

	renderSlots(data, mine)

	hintLabel.Text = mine and "Anything you put up here also shows on the Market — one price, one pool."
		or "Walk-up prices. The same stock is on the Market if you'd rather browse there."
end

--------------------------------------------------------------------------------
-- Skin swatches
--------------------------------------------------------------------------------

local function makeSwatch(skin: any, owned: boolean): TextButton
	local tile = Instance.new("TextButton")
	tile.Name = "Skin_" .. skin.id
	tile.Text = ""
	tile.AutoButtonColor = true
	tile.BackgroundColor3 = Theme.BgLight
	tile.BorderSizePixel = 0
	tile.ZIndex = Z_CONTENT
	corner(tile, 8)
	stroke(tile, Theme.Stroke, 1.5).Name = "Edge"

	local vp = makePreview(skin, tile, UDim2.fromOffset(SWATCH_W - 12, 62))
	if not owned then
		vp.ImageTransparency = 0.5 -- visibly there, visibly not yours
	end

	local name = Instance.new("TextLabel")
	name.Name = "SkinName"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(6, 72)
	name.Size = UDim2.fromOffset(SWATCH_W - 12, 16)
	name.Font = Theme.Font
	name.TextSize = 12
	name.TextScaled = true
	name.TextColor3 = Theme.TextPrimary
	name.Text = skin.name
	name.ZIndex = Z_CONTENT + 1
	name.Parent = tile
	Instance.new("UITextSizeConstraint", name).MaxTextSize = 12

	local state = Instance.new("TextLabel")
	state.Name = "State"
	state.BackgroundTransparency = 1
	state.Position = UDim2.fromOffset(6, 90)
	state.Size = UDim2.fromOffset(SWATCH_W - 12, 16)
	state.Font = Theme.Font
	state.TextSize = 12
	state.TextColor3 = owned and Theme.Good or Theme.Gem
	-- the actual number, not the word "Robux": a price nobody can see is a price
	-- nobody decides on. Falls back only while an offer has no real product id.
	state.Text = if owned then "Owned" elseif skin.robux then ("R$ %d"):format(skin.robux) else "Coming soon"
	state.ZIndex = Z_CONTENT + 1
	state.Parent = tile
	Instance.new("UITextSizeConstraint", state).MaxTextSize = 12

	return tile
end

local function buildSwatches(skins: { any }, owned: { [string]: boolean })
	if next(skinChips) ~= nil then
		return
	end
	for _, skin in skins do
		local isOwned = owned[skin.id] == true or skin.id == BoothConfig.DefaultSkinId
		local tile = makeSwatch(skin, isOwned)
		tile.Parent = skinGrid
		tile.Activated:Connect(function()
			task.spawn(function()
				if not isOwned then
					-- locked: go to the purchase, not a dead end
					if skin.offerId and skin.robux then
						Net.invoke("PromptPurchase", skin.offerId)
					elseif skin.offerId then
						toast(skin.name .. " isn't on sale yet.", Theme.Warn)
					else
						toast(skin.name .. " is earned, not sold.", Theme.Warn)
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
	panel.Size = UDim2.fromOffset(620, 500)
	panel.BackgroundColor3 = Theme.Panel
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = Z_PANEL
	panel.Parent = gui
	corner(panel, 10)
	stroke(panel, Theme.Stroke)

	titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(16, 10)
	titleLabel.Size = UDim2.fromOffset(420, 24)
	titleLabel.Font = Theme.Font
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Theme.TextPrimary
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "Booth"
	titleLabel.ZIndex = Z_CONTENT
	titleLabel.Parent = panel

	subLabel = Instance.new("TextLabel")
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.fromOffset(16, 33)
	subLabel.Size = UDim2.fromOffset(460, 16)
	subLabel.Font = Theme.FontLight
	subLabel.TextSize = 13
	subLabel.TextColor3 = Theme.TextDim
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.Text = ""
	subLabel.ZIndex = Z_CONTENT
	subLabel.Parent = panel

	local close = button("CloseButton", "X", Theme.Bad, panel, Z_CONTENT)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(28, 28)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	-- Tab row, to the same spec as the Trade Board's.
	tabRow = Instance.new("Frame")
	tabRow.Name = "TabRow"
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(12, 56)
	tabRow.Size = UDim2.new(1, -24, 0, 30)
	tabRow.ZIndex = Z_CONTENT
	tabRow.Parent = panel
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 6)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = tabRow

	local function tab(key: string, text: string, order: number)
		local b = button("Tab" .. key, text, Theme.BgLight, tabRow, Z_CONTENT)
		b.Size = UDim2.fromOffset(150, 30)
		b.TextSize = 13
		b.LayoutOrder = order
		b.Activated:Connect(function()
			selectTab(key)
		end)
		tabButtons[key] = b
	end
	tab("stall", "🏪 Stall", 1)
	tab("customise", "🎨 Customise", 2)

	local function page(name: string): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.Position = UDim2.fromOffset(16, 94)
		f.Size = UDim2.new(1, -32, 1, -110)
		f.ZIndex = Z_CONTENT
		f.Parent = panel
		return f
	end
	stallPage = page("StallPage")
	customisePage = page("CustomisePage")

	----------------------------------------------------------------------------
	-- STALL
	----------------------------------------------------------------------------

	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, 0, 1, -24)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 5
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ZIndex = Z_CONTENT
	grid.Parent = stallPage
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(CELL, CELL) -- square, always
	gl.CellPadding = UDim2.fromOffset(GAP, GAP)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid

	hintLabel = Instance.new("TextLabel")
	hintLabel.BackgroundTransparency = 1
	hintLabel.AnchorPoint = Vector2.new(0, 1)
	hintLabel.Position = UDim2.fromScale(0, 1)
	hintLabel.Size = UDim2.new(1, 0, 0, 18)
	hintLabel.Font = Theme.FontLight
	hintLabel.TextSize = 12
	hintLabel.TextColor3 = Theme.TextDim
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Text = ""
	hintLabel.ZIndex = Z_CONTENT
	hintLabel.Parent = stallPage

	----------------------------------------------------------------------------
	-- CUSTOMISE
	----------------------------------------------------------------------------

	heading("STALL LOOK", customisePage)

	skinGrid = Instance.new("ScrollingFrame")
	skinGrid.Name = "SkinGrid"
	skinGrid.Position = UDim2.fromOffset(0, 20)
	skinGrid.Size = UDim2.new(1, 0, 1, -100)
	skinGrid.BackgroundTransparency = 1
	skinGrid.BorderSizePixel = 0
	skinGrid.ScrollBarThickness = 5
	skinGrid.CanvasSize = UDim2.new()
	skinGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	skinGrid.ScrollingDirection = Enum.ScrollingDirection.Y
	skinGrid.ZIndex = Z_CONTENT
	skinGrid.Parent = customisePage
	local sl = Instance.new("UIGridLayout")
	sl.CellSize = UDim2.fromOffset(SWATCH_W, SWATCH_H)
	sl.CellPadding = UDim2.fromOffset(GAP, GAP)
	sl.SortOrder = Enum.SortOrder.LayoutOrder
	sl.Parent = skinGrid

	local signHead = heading("YOUR SIGN", customisePage)
	signHead.AnchorPoint = Vector2.new(0, 1)
	signHead.Position = UDim2.new(0, 0, 1, -38)

	taglineBox = Instance.new("TextBox")
	taglineBox.Name = "Tagline"
	taglineBox.AnchorPoint = Vector2.new(0, 1)
	taglineBox.Position = UDim2.fromScale(0, 1)
	taglineBox.Size = UDim2.new(1, 0, 0, 32)
	taglineBox.BackgroundColor3 = Theme.BgLight
	taglineBox.Font = Theme.FontLight
	taglineBox.TextSize = 13
	taglineBox.TextColor3 = Theme.TextPrimary
	taglineBox.PlaceholderText = "Say something to shoppers…"
	taglineBox.ClearTextOnFocus = false
	taglineBox.TextXAlignment = Enum.TextXAlignment.Left
	taglineBox.Text = ""
	taglineBox.ZIndex = Z_CONTENT
	taglineBox.Parent = customisePage
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

	----------------------------------------------------------------------------
	-- Composer overlay
	----------------------------------------------------------------------------

	composer = Instance.new("Frame")
	composer.Name = "Composer"
	composer.Size = UDim2.fromScale(1, 1)
	composer.BackgroundColor3 = Theme.Panel
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
	cTitle.ZIndex = Z_COMPOSER_TOP
	cTitle.Parent = composer

	composerPick = Instance.new("TextLabel")
	composerPick.BackgroundTransparency = 1
	composerPick.Position = UDim2.fromOffset(16, 34)
	composerPick.Size = UDim2.fromOffset(500, 18)
	composerPick.Font = Theme.FontLight
	composerPick.TextSize = 13
	composerPick.TextColor3 = Theme.TextDim
	composerPick.TextXAlignment = Enum.TextXAlignment.Left
	composerPick.Text = "Pick something you own"
	composerPick.ZIndex = Z_COMPOSER_TOP
	composerPick.Parent = composer

	composerGrid = Instance.new("ScrollingFrame")
	composerGrid.Position = UDim2.fromOffset(16, 58)
	composerGrid.Size = UDim2.new(1, -32, 1, -126)
	composerGrid.BackgroundTransparency = 1
	composerGrid.BorderSizePixel = 0
	composerGrid.ScrollBarThickness = 5
	composerGrid.CanvasSize = UDim2.new()
	composerGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	composerGrid.ScrollingDirection = Enum.ScrollingDirection.Y
	composerGrid.ZIndex = Z_COMPOSER_TOP
	composerGrid.Parent = composer
	local cgl = Instance.new("UIGridLayout")
	cgl.CellSize = UDim2.fromOffset(92, 92) -- square here too
	cgl.CellPadding = UDim2.fromOffset(8, 8)
	cgl.SortOrder = Enum.SortOrder.LayoutOrder
	cgl.Parent = composerGrid

	-- Standing labels, not placeholders: placeholder text vanishes exactly when
	-- you need it, which is while checking what you typed.
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
		cap.ZIndex = Z_COMPOSER_TOP
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
		b.ZIndex = Z_COMPOSER_TOP
		b.Parent = composer
		corner(b, 6)
		return b
	end
	composerCount = numberBox(16, 92, "How many", "1")
	composerPrice = numberBox(118, 118, "Price (gems each)", "")

	local cancel = button("Cancel", "Cancel", Theme.BgLight, composer, Z_COMPOSER_TOP)
	cancel.AnchorPoint = Vector2.new(1, 1)
	cancel.Position = UDim2.new(1, -120, 1, -14)
	cancel.Size = UDim2.fromOffset(100, 30)
	cancel.Activated:Connect(function()
		composer.Visible = false
	end)

	local post = button("Post", "Put up for sale", Theme.Good, composer, Z_COMPOSER_TOP)
	post.AnchorPoint = Vector2.new(1, 1)
	post.Position = UDim2.new(1, -10, 1, -14)
	post.Size = UDim2.fromOffset(104, 30)
	post.Activated:Connect(function()
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

	----------------------------------------------------------------------------
	-- Buy confirmation
	--
	-- Spending gems must never happen on a single click. Shows what you are
	-- buying, lets you pick how many (capped at what is actually in stock), and
	-- prices the whole lot before you commit. The item art carries the same
	-- hover card as everywhere else, so you can check what it is worth without
	-- leaving the dialog.
	----------------------------------------------------------------------------
	confirm = Instance.new("Frame")
	confirm.Name = "BuyConfirm"
	confirm.Size = UDim2.fromScale(1, 1)
	confirm.BackgroundColor3 = Theme.Panel
	confirm.BorderSizePixel = 0
	confirm.Visible = false
	confirm.ZIndex = Z_COMPOSER
	confirm.Parent = panel
	corner(confirm, 10)

	local confirmTitle = Instance.new("TextLabel")
	confirmTitle.BackgroundTransparency = 1
	confirmTitle.Position = UDim2.fromOffset(16, 14)
	confirmTitle.Size = UDim2.new(1, -32, 0, 24)
	confirmTitle.Font = Theme.Font
	confirmTitle.TextSize = 17
	confirmTitle.TextColor3 = Theme.TextPrimary
	confirmTitle.TextXAlignment = Enum.TextXAlignment.Left
	confirmTitle.Text = "Buy this?"
	confirmTitle.ZIndex = Z_COMPOSER_TOP
	confirmTitle.Parent = confirm

	local confirmIcon = Instance.new("ImageLabel")
	confirmIcon.BackgroundColor3 = Theme.BgLight
	confirmIcon.BorderSizePixel = 0
	confirmIcon.Position = UDim2.fromOffset(16, 50)
	confirmIcon.Size = UDim2.fromOffset(96, 96)
	confirmIcon.ScaleType = Enum.ScaleType.Fit
	confirmIcon.ZIndex = Z_COMPOSER_TOP
	confirmIcon.Parent = confirm
	corner(confirmIcon, 8)
	local confirmEdge = stroke(confirmIcon, Theme.Stroke, 2)

	local confirmName = Instance.new("TextLabel")
	confirmName.BackgroundTransparency = 1
	confirmName.Position = UDim2.fromOffset(126, 52)
	confirmName.Size = UDim2.new(1, -142, 0, 24)
	confirmName.Font = Theme.Font
	confirmName.TextSize = 18
	confirmName.TextColor3 = Theme.TextPrimary
	confirmName.TextXAlignment = Enum.TextXAlignment.Left
	confirmName.Text = ""
	confirmName.ZIndex = Z_COMPOSER_TOP
	confirmName.Parent = confirm

	local confirmMeta = Instance.new("TextLabel")
	confirmMeta.BackgroundTransparency = 1
	confirmMeta.Position = UDim2.fromOffset(126, 76)
	confirmMeta.Size = UDim2.new(1, -142, 0, 18)
	confirmMeta.Font = Theme.FontLight
	confirmMeta.TextSize = 13
	confirmMeta.TextColor3 = Theme.TextDim
	confirmMeta.TextXAlignment = Enum.TextXAlignment.Left
	confirmMeta.Text = ""
	confirmMeta.ZIndex = Z_COMPOSER_TOP
	confirmMeta.Parent = confirm

	local howManyLabel = Instance.new("TextLabel")
	howManyLabel.BackgroundTransparency = 1
	howManyLabel.Position = UDim2.fromOffset(126, 102)
	howManyLabel.Size = UDim2.fromOffset(120, 14)
	howManyLabel.Font = Theme.FontLight
	howManyLabel.TextSize = 11
	howManyLabel.TextColor3 = Theme.TextDim
	howManyLabel.TextXAlignment = Enum.TextXAlignment.Left
	howManyLabel.Text = "How many"
	howManyLabel.ZIndex = Z_COMPOSER_TOP
	howManyLabel.Parent = confirm

	local totalLabel = Instance.new("TextLabel")
	totalLabel.BackgroundTransparency = 1
	totalLabel.Position = UDim2.fromOffset(16, 166)
	totalLabel.Size = UDim2.new(1, -32, 0, 26)
	totalLabel.Font = Theme.Font
	totalLabel.TextSize = 18
	totalLabel.TextColor3 = Theme.Gem
	totalLabel.TextXAlignment = Enum.TextXAlignment.Left
	totalLabel.Text = ""
	totalLabel.ZIndex = Z_COMPOSER_TOP
	totalLabel.Parent = confirm

	local confirmCancel = button("Cancel", "Cancel", Theme.BgLight, confirm, Z_COMPOSER_TOP)
	confirmCancel.AnchorPoint = Vector2.new(1, 1)
	confirmCancel.Position = UDim2.new(1, -124, 1, -14)
	confirmCancel.Size = UDim2.fromOffset(104, 32)
	confirmCancel.Activated:Connect(function()
		confirm.Visible = false
	end)

	local confirmBuy = button("Buy", "Buy", Theme.Good, confirm, Z_COMPOSER_TOP)
	confirmBuy.AnchorPoint = Vector2.new(1, 1)
	confirmBuy.Position = UDim2.new(1, -10, 1, -14)
	confirmBuy.Size = UDim2.fromOffset(108, 32)

	local confirmStepper: any = nil
	local confirmRow: any = nil

	openBuyConfirm = function(row)
		confirmRow = row
		confirmTitle.Text = "Buy this?"
		confirmName.Text = row.name
		confirmEdge.Color = Components.rarityColor(row.rarity)
		Components.setIcon(confirmIcon, row)
		confirmMeta.Text = ("%s  ·  %d gems each  ·  %d in stock")
			:format(tostring(row.rarity or "?"), row.gemsPerCopy, row.remaining)
		if tooltip then
			tooltip.attach(confirmIcon, function()
				return EconomyController.get(row.itemId), InventoryController.inventory:get()[row.itemId]
			end)
		end

		local function paintTotal(n: number)
			totalLabel.Text = ("Total: %d gems"):format(n * row.gemsPerCopy)
			confirmBuy.Text = n > 1 and ("Buy %d"):format(n) or "Buy"
		end

		if confirmStepper then
			confirmStepper.frame:Destroy()
		end
		confirmStepper = Components.quantityStepper(confirm, {
			min = 1,
			max = math.max(1, row.remaining),
			value = 1,
			width = 52,
			zIndex = Z_COMPOSER_TOP,
			onChanged = paintTotal,
		})
		confirmStepper.frame.Position = UDim2.fromOffset(126, 120)
		paintTotal(1)
		confirm.Visible = true
	end

	confirmBuy.Activated:Connect(function()
		local row = confirmRow
		if row == nil then
			return
		end
		local n = confirmStepper and confirmStepper.get() or 1
		confirm.Visible = false
		task.spawn(function()
			local res = Net.invoke("BuyFromListing", row.listingId, n)
			if res and res.ok then
				toast(("Bought %d x %s for %d gems!"):format(res.count or n, row.name, res.spent), Theme.Good)
			elseif res then
				toast(({
					insufficient_gems = "Not enough gems!",
					gone = "Too late — that one just went.",
					sold_out = "Too late — that one just went.",
					own_listing = "That's your own listing.",
				})[res.err] or ("Failed: " .. tostring(res.err)), Theme.Bad)
			end
			BoothPanel.refresh()
		end)
	end)
	selectTab("stall")
end

--------------------------------------------------------------------------------
-- Open / refresh
--------------------------------------------------------------------------------

function BoothPanel.refresh()
	if not panel.Visible or current == nil then
		return
	end
	task.spawn(function()
		local res = Net.invoke("GetBooths")
		if not (res and res.ok and panel.Visible) then
			return
		end
		buildSwatches(res.skins or {}, res.owned or {})
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
	confirm.Visible = false
	selectTab("stall")
	render(data)
	BoothPanel.refresh()
end

return BoothPanel
