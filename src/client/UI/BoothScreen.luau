--!strict
-- BoothScreen: the storefront face painted onto every placed booth.
--
-- Builds one SurfaceGui per booth the server reports, and repaints it whenever
-- the server pushes new state. Nothing here decides anything: claims, slots,
-- listings and skins are all server-owned, and this module only draws them.
--
-- The grid is BoothConfig.GridColumns x GridRows visible and scrolls past that.
-- Slots you own but haven't stocked are dashed outlines; the next one you could
-- buy is a white square with a +, and anything past that isn't drawn.
--
-- Also dims players standing near a booth. PS99 had to add that after people
-- worked out they could body-block a display and hide what was for sale.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local BoothConfig = require(ReplicatedStorage.Shared.Config.BoothConfig)
local Net = require(script.Parent.Parent.Net)

local BoothScreen = {}

local SURFACE_PIXELS_PER_STUD = 40

-- boothId -> { gui, header, tagline, grid, empty, cells = {} }
local faces: { [string]: any } = {}
local latest: { [string]: any } = {} -- boothId -> last describe() payload

local function anchorOf(model: Instance): BasePart?
	local a = model:FindFirstChild(BoothConfig.AnchorName, true)
	return (a and a:IsA("BasePart")) and a or nil
end

--------------------------------------------------------------------------------
-- Face construction (once per booth)
--------------------------------------------------------------------------------

local function buildFace(boothId: string, anchor: BasePart): any
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoothFace"
	gui.Adornee = anchor
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = SURFACE_PIXELS_PER_STUD
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = anchor

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.Panel
	root.BorderSizePixel = 0
	root.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.04, 0)
	pad.PaddingBottom = UDim.new(0.04, 0)
	pad.PaddingLeft = UDim.new(0.035, 0)
	pad.PaddingRight = UDim.new(0.035, 0)
	pad.Parent = root

	local owner = Instance.new("TextLabel")
	owner.Name = "Owner"
	owner.BackgroundTransparency = 1
	owner.Size = UDim2.fromScale(0.72, 0.11)
	owner.Font = Theme.Font
	owner.TextScaled = true
	owner.TextColor3 = Theme.TextPrimary
	owner.TextXAlignment = Enum.TextXAlignment.Left
	owner.Text = ""
	owner.Parent = root

	local flex = Instance.new("TextLabel")
	flex.Name = "Flex"
	flex.BackgroundTransparency = 1
	flex.AnchorPoint = Vector2.new(1, 0)
	flex.Position = UDim2.fromScale(1, 0)
	flex.Size = UDim2.fromScale(0.28, 0.1)
	flex.Font = Theme.FontLight
	flex.TextScaled = true
	flex.TextColor3 = Theme.Gem
	flex.TextXAlignment = Enum.TextXAlignment.Right
	flex.Text = ""
	flex.Parent = root

	local tagline = Instance.new("TextLabel")
	tagline.Name = "Tagline"
	tagline.BackgroundTransparency = 1
	tagline.Position = UDim2.fromScale(0, 0.125)
	tagline.Size = UDim2.fromScale(1, 0.075)
	tagline.Font = Theme.FontLight
	tagline.TextScaled = true
	tagline.TextColor3 = Theme.TextDim
	tagline.TextXAlignment = Enum.TextXAlignment.Left
	tagline.Text = ""
	tagline.Parent = root

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromScale(0, 0.23)
	grid.Size = UDim2.fromScale(1, 0.77)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.ScrollBarImageColor3 = Theme.Stroke
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.Parent = root
	-- This grid lives on a SurfaceGui in the world, so Components.autoGutter
	-- (which walks the ScreenGuis) never reaches it. Pad it here or the cells'
	-- rarity strokes clip against the scroll edge.
	local gutter = Instance.new("UIPadding")
	gutter.PaddingLeft = UDim.new(0, 3)
	gutter.PaddingTop = UDim.new(0, 3)
	gutter.PaddingRight = UDim.new(0, 3)
	gutter.PaddingBottom = UDim.new(0, 3)
	gutter.Parent = grid

	-- SQUARE cells, in pixels. Scale cells inherit the board's aspect ratio and
	-- come out as rectangles on any board that isn't square, so the size comes
	-- from the board's real pixel dimensions instead.
	--
	-- Sized to fit BOTH axes: a cell derived from width alone overflows the grid
	-- band on a wide, short board and the ScrollingFrame clips the bottom row
	-- off. Whichever axis is tighter wins, so the requested columns AND rows
	-- always fit whatever shape board the model brings.
	local boardW = anchor.Size.X * SURFACE_PIXELS_PER_STUD * 0.93 -- minus L/R padding
	local boardH = anchor.Size.Y * SURFACE_PIXELS_PER_STUD * 0.77 * 0.92 -- grid band, minus T/B padding
	local gap = math.max(2, math.floor(boardW * 0.014))
	local byWidth = (boardW - gap * (BoothConfig.GridColumns - 1)) / BoothConfig.GridColumns
	local byHeight = (boardH - gap * (BoothConfig.GridRows - 1)) / BoothConfig.GridRows
	local cell = math.max(24, math.floor(math.min(byWidth, byHeight)))

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(cell, cell)
	layout.CellPadding = UDim2.fromOffset(gap, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local empty = Instance.new("TextLabel")
	empty.Name = "EmptyLabel"
	empty.BackgroundTransparency = 1
	empty.Position = UDim2.fromScale(0, 0.3)
	empty.Size = UDim2.fromScale(1, 0.2)
	empty.Font = Theme.Font
	empty.TextScaled = true
	empty.TextColor3 = Theme.TextDim
	empty.Text = "Unclaimed booth — hold E to set up shop"
	empty.Visible = true
	empty.Parent = root
	Instance.new("UITextSizeConstraint", empty).MaxTextSize = 34

	local face = {
		gui = gui,
		owner = owner,
		flex = flex,
		tagline = tagline,
		grid = grid,
		empty = empty,
		cells = {} :: { Frame },
	}
	faces[boothId] = face
	return face
end

--------------------------------------------------------------------------------
-- Cells
--------------------------------------------------------------------------------

local function makeCell(face: any, order: number): Frame
	local cell = Instance.new("Frame")
	cell.Name = "Slot" .. order
	cell.LayoutOrder = order
	cell.BackgroundColor3 = Theme.BgLight
	cell.BorderSizePixel = 0
	cell.Parent = face.grid
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = cell
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Edge"
	stroke.Color = Theme.Stroke
	stroke.Thickness = 2
	stroke.Parent = cell

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0.06)
	icon.Size = UDim2.fromScale(0.62, 0.5)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = cell

	local plus = Instance.new("TextLabel")
	plus.Name = "Plus"
	plus.BackgroundTransparency = 1
	plus.Size = UDim2.fromScale(1, 1)
	plus.Font = Theme.Font
	plus.TextScaled = true
	plus.Text = "+"
	plus.TextColor3 = Theme.TextDim
	plus.Visible = false
	plus.Parent = cell
	Instance.new("UITextSizeConstraint", plus).MaxTextSize = 44

	local name = Instance.new("TextLabel")
	name.Name = "ItemName"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0.05, 0.58)
	name.Size = UDim2.fromScale(0.9, 0.18)
	name.Font = Theme.Font
	name.TextScaled = true
	name.TextColor3 = Theme.TextPrimary
	name.Text = ""
	name.Parent = cell
	Instance.new("UITextSizeConstraint", name).MaxTextSize = 18

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.BackgroundTransparency = 1
	price.Position = UDim2.fromScale(0.05, 0.77)
	price.Size = UDim2.fromScale(0.9, 0.17)
	price.Font = Theme.Font
	price.TextScaled = true
	price.TextColor3 = Theme.Gem
	price.Text = ""
	price.Parent = cell
	Instance.new("UITextSizeConstraint", price).MaxTextSize = 18

	table.insert(face.cells, cell)
	return cell
end

local function cellAt(face: any, order: number): Frame
	return face.cells[order] or makeCell(face, order)
end

--------------------------------------------------------------------------------
-- Painting
--------------------------------------------------------------------------------

local function paint(face: any, data: any)
	if not data.claimed then
		face.owner.Text = ""
		face.flex.Text = ""
		face.tagline.Text = ""
		face.empty.Visible = true
		for _, cell in face.cells do
			cell.Visible = false
		end
		return
	end

	face.empty.Visible = false
	face.owner.Text = data.groupTag ~= "" and ("[%s] %s"):format(data.groupTag, data.ownerName) or data.ownerName
	face.tagline.Text = data.tagline ~= "" and data.tagline or "Open for trades."

	local stocked = #data.listings
	face.flex.Text = stocked > 0 and ("%d for sale"):format(stocked) or ""
	if stocked == 0 then
		-- claimed but nothing out yet: say so rather than showing a bare board
		face.empty.Visible = true
		face.empty.Text = "Nothing for sale yet"
	end

	-- ONLY what's actually for sale. A booth face is a shop window, not an
	-- inventory screen: empty shelves and a buy-a-slot button are the owner's
	-- business and live in the booth panel, not on the front of the stall where
	-- every passer-by reads them.
	local total = #data.listings

	for i = 1, total do
		local cell = cellAt(face, i)
		local icon = cell:FindFirstChild("Icon") :: ImageLabel
		local plus = cell:FindFirstChild("Plus") :: TextLabel
		local name = cell:FindFirstChild("ItemName") :: TextLabel
		local price = cell:FindFirstChild("Price") :: TextLabel
		local edge = cell:FindFirstChild("Edge") :: UIStroke
		cell.Visible = true

		local row = data.listings[i]
		icon.Visible = true
		plus.Visible = false
		Components.setIcon(icon, row)
		name.Text = row.name
		price.Text = ("%d gems  x%d"):format(row.gemsPerCopy, row.remaining)
		cell.BackgroundColor3 = Theme.BgLight
		cell.BackgroundTransparency = 0
		edge.Color = Components.rarityColor(row.rarity)
		edge.Transparency = 0
	end
	for i = total + 1, #face.cells do
		face.cells[i].Visible = false
	end
end

--------------------------------------------------------------------------------
-- Transparency near booths (anti body-block)
--------------------------------------------------------------------------------

local function nearAnyBooth(position: Vector3): boolean
	for _, model in CollectionService:GetTagged(BoothConfig.Tag) do
		local anchor = anchorOf(model)
		if anchor and (anchor.Position - position).Magnitude <= BoothConfig.TransparencyRadius then
			return true
		end
	end
	return false
end

local function startTransparencySweep()
	-- Every 0.4s, not per frame: this is a cosmetic courtesy, and a per-frame
	-- sweep over every booth for every player is real cost for no gain.
	--
	-- Three things keep this cheap enough for a low-end phone:
	--   * the booth anchors are gathered ONCE per sweep, not once per player.
	--     GetTagged allocates a fresh table every call, so doing it inside the
	--     player loop meant one throwaway table per player per sweep -- pure GC
	--     pressure on the device least able to absorb it.
	--   * distances compare squared, so no sqrt per booth per player.
	--   * players far from the camera are skipped outright. Fading someone you
	--     cannot see buys nothing, and their state is left untouched so it
	--     applies correctly the moment they come back into range.
	task.spawn(function()
		local faded: { [Player]: boolean } = {}
		local anchors: { Vector3 } = {}
		local nearSq = BoothConfig.TransparencyRadius * BoothConfig.TransparencyRadius
		local CULL_SQ = 250 * 250
		while true do
			task.wait(0.4)

			table.clear(anchors)
			for _, model in CollectionService:GetTagged(BoothConfig.Tag) do
				local anchor = anchorOf(model)
				if anchor then
					table.insert(anchors, anchor.Position)
				end
			end

			local camera = workspace.CurrentCamera
			local eye = camera and camera.CFrame.Position or Vector3.zero

			for _, player in Players:GetPlayers() do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root == nil then
					continue
				end
				local pos = root.Position
				local toEye = pos - eye
				if toEye.X * toEye.X + toEye.Y * toEye.Y + toEye.Z * toEye.Z > CULL_SQ then
					continue -- off-screen distance: nobody can see this fade
				end
				local near = false
				for _, a in anchors do
					local d = a - pos
					if d.X * d.X + d.Y * d.Y + d.Z * d.Z <= nearSq then
						near = true
						break
					end
				end
				if near == faded[player] then
					continue -- already in the right state
				end
				faded[player] = near
				for _, d in char:GetDescendants() do
					if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
						d.LocalTransparencyModifier = near and BoothConfig.NearBoothTransparency or 0
					end
				end
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

function BoothScreen.start()
	if not BoothConfig.Enabled then
		return
	end

	local function faceFor(boothId: string): any?
		local existing = faces[boothId]
		if existing and existing.gui.Parent then
			return existing
		end
		for _, model in CollectionService:GetTagged(BoothConfig.Tag) do
			if model:GetAttribute(BoothConfig.IdAttribute) == boothId then
				local anchor = anchorOf(model)
				if anchor then
					return buildFace(boothId, anchor)
				end
			end
		end
		return nil
	end

	local function apply(list: { any })
		for _, data in list do
			latest[data.boothId] = data
			local face = faceFor(data.boothId)
			if face then
				paint(face, data)
			end
		end
	end

	Net.on("BoothsChanged", apply)

	task.spawn(function()
		local result = Net.invoke("GetBooths")
		if result and result.ok then
			apply(result.booths)
		end
	end)

	startTransparencySweep()
end

-- What the server last said about a booth, for other screens (the claim/stock
-- panel) that need to know whose booth this is.
function BoothScreen.stateOf(boothId: string): any?
	return latest[boothId]
end

-- Pressing E on a booth. Three cases, and the server re-checks all of them:
--   unclaimed        -> claim it
--   yours            -> open the Market so you can stock a slot
--   someone else's   -> open the Market at their stock, so you can buy it
-- `onBrowse` is supplied by the bootstrap so this module doesn't have to know
-- about BoardScreen (which would be a UI-to-UI dependency for no gain).
local browseHandler: ((data: any?) -> ())? = nil

function BoothScreen.setBrowseHandler(fn: (data: any?) -> ())
	browseHandler = fn
end

function BoothScreen.interact(prompt: ProximityPrompt)
	local model = prompt:FindFirstAncestorOfClass("Model")
	while model and not CollectionService:HasTag(model, BoothConfig.Tag) do
		model = model:FindFirstAncestorOfClass("Model")
	end
	if model == nil then
		return
	end
	local boothId = model:GetAttribute(BoothConfig.IdAttribute)
	if type(boothId) ~= "string" then
		return
	end
	local data = latest[boothId]

	if data == nil or not data.claimed then
		task.spawn(function()
			local result = Net.invoke("ClaimBooth", boothId)
			if result and result.ok then
				BoothScreen.toast("Booth claimed — stock it from the Market.", Theme.Good)
			elseif result then
				BoothScreen.toast(({
					taken = "Someone just took that booth.",
					disabled = "Booths are switched off right now.",
					loading = "Still loading your profile.",
					no_such_booth = "That booth isn't set up yet.",
				})[result.err] or "Couldn't claim that booth.", Theme.Bad)
			end
		end)
		return
	end

	-- claimed: open the booth's OWN panel. Yours = manage it, theirs = shop it.
	-- Never the Trade Board: that is a different surface for a different job.
	if browseHandler then
		browseHandler(data)
	end
end

-- Set by the bootstrap so booth feedback uses the same toast as everything else.
BoothScreen.toast = function(_text: string, _color: Color3) end

return BoothScreen
