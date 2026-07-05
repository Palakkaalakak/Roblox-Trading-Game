--!strict
-- Components: small imperative UI builders shared by every screen.
-- create(className, props, children) + domain pieces (item tile, stat rows).

local Theme = require(script.Parent.Theme)

local Components = {}

function Components.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className) :: any
	if props then
		for k, v in props do
			inst[k] = v
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	return inst
end
local create = Components.create

function Components.corner(radius: UDim?): Instance
	return create("UICorner", { CornerRadius = radius or Theme.Corner })
end

function Components.stroke(color: Color3?, thickness: number?): Instance
	return create("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Components.panel(props: { [string]: any }?): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
	}
	for k, v in props or {} do
		merged[k] = v
	end
	local frame = create("Frame", merged)
	Components.corner().Parent = frame
	Components.stroke().Parent = frame
	return frame
end

function Components.label(props: { [string]: any }?): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.TextPrimary,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in props or {} do
		merged[k] = v
	end
	return create("TextLabel", merged)
end

function Components.button(props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local merged: { [string]: any } = {
		BackgroundColor3 = Theme.Accent,
		Font = Theme.Font,
		TextColor3 = Theme.TextPrimary,
		TextSize = 14,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}
	for k, v in props or {} do
		merged[k] = v
	end
	local btn = create("TextButton", merged)
	Components.corner(Theme.CornerSmall).Parent = btn
	if onClick then
		btn.Activated:Connect(onClick)
	end
	return btn
end

--------------------------------------------------------------------------------
-- Item icon (placeholder art)
--------------------------------------------------------------------------------

-- Every item display renders its art through here. Items carry an imageId
-- (Simulator Icon Pack decals for now); missing art falls back to a
-- rarity-tinted placeholder.
local PLACEHOLDER_IMAGE = "rbxasset://textures/ui/GuiImagePlaceholder.png"

-- Square icon: ImageLabel named "Icon".
function Components.itemIcon(parent: Instance, size: UDim2, position: UDim2?): ImageLabel
	local icon = create("ImageLabel", {
		Name = "Icon",
		Image = PLACEHOLDER_IMAGE,
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = size,
		Position = position or UDim2.new(),
		ScaleType = Enum.ScaleType.Fit,
		ImageColor3 = Theme.Rarity.Common,
	})
	create("UICorner", { CornerRadius = Theme.CornerSmall }).Parent = icon
	icon.Parent = parent
	return icon
end

-- Point an icon at a snapshot: real art unmodified, placeholder tinted.
function Components.setIcon(icon: ImageLabel, snapshot: any?)
	local imageId = snapshot and snapshot.imageId or nil
	if imageId then
		icon.Image = imageId
		icon.ImageColor3 = Color3.new(1, 1, 1)
	else
		icon.Image = PLACEHOLDER_IMAGE
		icon.ImageColor3 = (snapshot and Theme.Rarity[snapshot.rarity]) or Theme.Rarity.Common
	end
end

--------------------------------------------------------------------------------
-- Stats
--------------------------------------------------------------------------------

local function statText(stat: any): string
	if stat == nil or stat.state ~= "Known" or stat.value == nil then
		return "N/A"
	end
	local v = stat.value
	if v >= 1000 then
		return string.format("%.1fk", v / 1000)
	end
	return tostring(v)
end
Components.statText = statText

-- Stat block: Value / Demand / RAP, fully written out. Supply lives in the
-- tile subtitle ("X in existence"), not here. update(snapshot) refreshes.
function Components.statBlock(parent: Instance): (snapshot: any?) -> ()
	local rows = {}
	local defs = { { "Value", "value" }, { "Demand", "demand" }, { "RAP", "rap" } }
	local holder = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 42),
		Name = "Stats",
	})
	create("UIListLayout", { Padding = UDim.new(0, 0), FillDirection = Enum.FillDirection.Vertical }).Parent = holder
	for _, def in defs do
		local row = Components.label({
			Size = UDim2.new(1, 0, 0, 14),
			Font = Theme.FontLight,
			TextSize = 12,
			TextColor3 = Theme.TextDim,
			Text = def[1] .. ": …",
		})
		row.Parent = holder
		rows[def[2]] = { label = row, prefix = def[1] }
	end
	holder.Parent = parent

	return function(snapshot: any?)
		for key, row in rows do
			local stat = snapshot and snapshot[key] or nil
			local text = statText(stat)
			row.label.Text = row.prefix .. ": " .. text
			row.label.TextColor3 = text == "N/A" and Theme.TextDim or Theme.TextPrimary
		end
	end
end

-- Item tile: icon-dominant card (PS99-style) — stripe, big icon, name,
-- "X in existence", rarity, stat block. Returns (frame, updateFn).
function Components.itemTile(itemId: string, onClick: (() -> ())?): (Frame, (snapshot: any?, count: number?) -> ())
	local tile = create(onClick and "TextButton" or "Frame", {
		BackgroundColor3 = Theme.BgLight,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(126, 168),
		Text = onClick and "" or nil,
		AutoButtonColor = onClick and true or nil,
		Name = itemId,
	})
	Components.corner(Theme.CornerSmall).Parent = tile
	Components.stroke().Parent = tile

	local stripe = create("Frame", {
		BackgroundColor3 = Theme.Rarity.Common,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 5),
		Name = "Stripe",
	})
	create("UICorner", { CornerRadius = UDim.new(0, 3) }).Parent = stripe
	stripe.Parent = tile

	local icon = Components.itemIcon(tile, UDim2.fromOffset(46, 46), UDim2.new(0.5, -23, 0, 11))

	local countBadge = Components.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 8),
		Size = UDim2.fromOffset(34, 16),
		Text = "",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Warn,
	})
	countBadge.Parent = tile

	local nameLabel = Components.label({
		Position = UDim2.fromOffset(6, 60),
		Size = UDim2.new(1, -12, 0, 15),
		Text = itemId,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	nameLabel.Parent = tile

	-- supply subtitle: "X in existence"
	local existenceLabel = Components.label({
		Position = UDim2.fromOffset(6, 76),
		Size = UDim2.new(1, -12, 0, 12),
		Text = "",
		Font = Theme.FontLight,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.TextDim,
	})
	existenceLabel.Parent = tile

	local rarityLabel = Components.label({
		Position = UDim2.fromOffset(6, 89),
		Size = UDim2.new(1, -12, 0, 12),
		Text = "",
		Font = Theme.FontLight,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.TextDim,
	})
	rarityLabel.Parent = tile

	local statsHolder = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 106),
		Size = UDim2.new(1, -16, 0, 56),
	})
	statsHolder.Parent = tile
	local updateStats = Components.statBlock(statsHolder)

	if onClick then
		(tile :: any).Activated:Connect(onClick)
	end

	local update = function(snapshot: any?, count: number?)
		if snapshot then
			nameLabel.Text = snapshot.name or itemId
			rarityLabel.Text = snapshot.rarity or ""
			rarityLabel.TextColor3 = Theme.Rarity[snapshot.rarity] or Theme.TextDim
			stripe.BackgroundColor3 = Theme.Rarity[snapshot.rarity] or Theme.Rarity.Common
			Components.setIcon(icon, snapshot)
			local supply = snapshot.supply
			if supply and supply.state == "Known" and supply.value ~= nil then
				existenceLabel.Text = tostring(supply.value) .. " in existence"
			else
				existenceLabel.Text = "N/A in existence"
			end
		end
		countBadge.Text = (count and count > 1) and ("x" .. tostring(count)) or ""
		updateStats(snapshot)
	end
	return tile :: Frame, update
end

--------------------------------------------------------------------------------
-- Tooltip (hover info card)
--------------------------------------------------------------------------------

-- One floating card per ScreenGui. Returns {attach(guiObject, getSnapshot)}.
function Components.makeTooltip(gui: ScreenGui)
	local card = Components.panel({
		Size = UDim2.fromOffset(190, 118),
		Visible = false,
		ZIndex = 50,
		BackgroundColor3 = Theme.Bg,
	})
	card.Parent = gui

	local title = Components.label({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 16),
		Text = "",
		TextSize = 14,
		ZIndex = 51,
	})
	title.Parent = card

	local sub = Components.label({
		Position = UDim2.fromOffset(10, 24),
		Size = UDim2.new(1, -20, 0, 13),
		Text = "",
		Font = Theme.FontLight,
		TextSize = 11,
		TextColor3 = Theme.TextDim,
		ZIndex = 51,
	})
	sub.Parent = card

	local body = Components.label({
		Position = UDim2.fromOffset(10, 42),
		Size = UDim2.new(1, -20, 1, -50),
		Text = "",
		Font = Theme.FontLight,
		TextSize = 12,
		TextColor3 = Theme.TextPrimary,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 51,
	})
	body.Parent = card

	local function show(snapshot: any?, count: number?, anchor: GuiObject)
		if snapshot == nil then
			return
		end
		title.Text = snapshot.name or "?"
		title.TextColor3 = Theme.Rarity[snapshot.rarity] or Theme.TextPrimary
		local supplyText = statText(snapshot.supply)
		sub.Text = (snapshot.rarity or "?") .. " · " .. supplyText .. " in existence"
			.. ((count and count > 1) and (" · you offer x" .. count) or "")
		body.Text = ("Value: %s\nDemand: %s\nRAP: %s"):format(
			statText(snapshot.value),
			statText(snapshot.demand),
			statText(snapshot.rap)
		)
		local pos = anchor.AbsolutePosition
		local size = anchor.AbsoluteSize
		local guiWidth = gui.AbsoluteSize.X
		local x = math.clamp(pos.X + size.X + 8, 0, guiWidth - 198)
		local y = math.max(pos.Y - 10, 0)
		card.Position = UDim2.fromOffset(x, y)
		card.Visible = true
	end

	local function hide()
		card.Visible = false
	end

	return {
		attach = function(obj: GuiObject, getSnapshot: () -> (any?, number?))
			obj.MouseEnter:Connect(function()
				local snapshot, count = getSnapshot()
				show(snapshot, count, obj)
			end)
			obj.MouseLeave:Connect(hide)
			obj.Destroying:Connect(hide)
		end,
		hide = hide,
	}
end

return Components
