--!strict
-- Runtime UI helpers. The GUI itself lives in StarterGui (built once by
-- Shared/GuiBuilder, edited visually in Studio) — code here only fills in
-- data: icons, stat text, tile contents, tooltip. No layout, no styling
-- beyond state colors (rarity tints, ready-green etc).

local Theme = require(script.Parent.Theme)

local Components = {}

local PLACEHOLDER_IMAGE = "rbxasset://textures/ui/GuiImagePlaceholder.png"

-- "N/A" for missing data, k-formatting for big numbers.
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

-- Point an ImageLabel at a snapshot's art: real imageId as-is, placeholder
-- rarity-tinted. Single swap point for future art.
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

function Components.rarityColor(rarity: string?): Color3
	return (rarity and Theme.Rarity[rarity]) or Theme.Rarity.Common
end

-- Fill an ItemTile (template clone) from a snapshot + owned count.
function Components.fillItemTile(tile: Instance, snapshot: any?, count: number?)
	local t = tile :: any
	if snapshot then
		t.ItemName.Text = snapshot.name or "?"
		t.Rarity.Text = snapshot.rarity or ""
		t.Rarity.TextColor3 = Components.rarityColor(snapshot.rarity)
		t.Stripe.BackgroundColor3 = Components.rarityColor(snapshot.rarity)
		Components.setIcon(t.Icon, snapshot)
		local supply = snapshot.supply
		if supply and supply.state == "Known" and supply.value ~= nil then
			t.Existence.Text = tostring(supply.value) .. " in existence"
		else
			t.Existence.Text = "N/A in existence"
		end
		t.Stats.ValueRow.Text = "Value: " .. statText(snapshot.value)
		t.Stats.DemandRow.Text = "Demand: " .. statText(snapshot.demand)
		t.Stats.RapRow.Text = "RAP: " .. statText(snapshot.rap)
	end
	t.CountBadge.Text = (count and count > 1) and ("x" .. tostring(count)) or ""
end

-- Wire the shared Tooltip frame (from StarterGui) to hover events.
-- Returns attach(guiObject, getSnapshot).
function Components.wireTooltip(gui: ScreenGui)
	local card = gui:WaitForChild("Tooltip") :: Frame
	local title = card:WaitForChild("Title") :: TextLabel
	local sub = card:WaitForChild("Sub") :: TextLabel
	local body = card:WaitForChild("Body") :: TextLabel

	local function show(snapshot: any?, count: number?, anchor: GuiObject)
		if snapshot == nil then
			return
		end
		title.Text = snapshot.name or "?"
		title.TextColor3 = Components.rarityColor(snapshot.rarity)
		sub.Text = (snapshot.rarity or "?") .. " · " .. statText(snapshot.supply) .. " in existence"
			.. ((count and count > 1) and (" · x" .. count) or "")
		body.Text = ("Value: %s\nDemand: %s\nRAP: %s"):format(
			statText(snapshot.value),
			statText(snapshot.demand),
			statText(snapshot.rap)
		)
		local pos = anchor.AbsolutePosition
		local size = anchor.AbsoluteSize
		local guiWidth = gui.AbsoluteSize.X
		local x = math.clamp(pos.X + size.X + 8, 0, math.max(0, guiWidth - card.AbsoluteSize.X - 8))
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
