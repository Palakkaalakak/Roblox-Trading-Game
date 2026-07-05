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

-- Item tile: rarity-striped card with name, count badge, stat block.
-- Returns (frame, updateFn(snapshot, count)).
function Components.itemTile(itemId: string, onClick: (() -> ())?): (Frame, (snapshot: any?, count: number?) -> ())
	local tile = create(onClick and "TextButton" or "Frame", {
		BackgroundColor3 = Theme.BgLight,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(126, 132),
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

	local nameLabel = Components.label({
		Position = UDim2.fromOffset(8, 9),
		Size = UDim2.new(1, -40, 0, 16),
		Text = itemId,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	nameLabel.Parent = tile

	local countBadge = Components.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 9),
		Size = UDim2.fromOffset(30, 16),
		Text = "",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Warn,
	})
	countBadge.Parent = tile

	-- supply subtitle: "X in existence"
	local existenceLabel = Components.label({
		Position = UDim2.fromOffset(8, 26),
		Size = UDim2.new(1, -16, 0, 13),
		Text = "",
		Font = Theme.FontLight,
		TextSize = 11,
		TextColor3 = Theme.TextDim,
	})
	existenceLabel.Parent = tile

	local rarityLabel = Components.label({
		Position = UDim2.fromOffset(8, 40),
		Size = UDim2.new(1, -16, 0, 13),
		Text = "",
		Font = Theme.FontLight,
		TextSize = 11,
		TextColor3 = Theme.TextDim,
	})
	rarityLabel.Parent = tile

	local statsHolder = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 58),
		Size = UDim2.new(1, -16, 0, 66),
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

return Components
