--!strict
-- Runtime UI helpers. The GUI itself lives in StarterGui (built once by
-- Shared/GuiBuilder, edited visually in Studio) — code here only fills in
-- data: icons, stat text, tile contents, tooltip. No layout, no styling
-- beyond state colors (rarity tints, ready-green etc).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
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

-- "Store Cost: N gems", or "N/A (Event Item)" for items with no store cost
-- (future event-only items — none exist yet).
function Components.storeCostText(snapshot: any?): string
	if snapshot and snapshot.storeCost then
		return tostring(snapshot.storeCost)
	end
	return "N/A (Event Item)"
end

-- "N in existence" — N is totalSupply: how many of this item can EVER exist.
-- That fixed cap is the rarity signal a trader actually cares about ("only 90
-- exist"), and it never moves. We deliberately do NOT show the live circulating
-- count: it churns constantly and means little on its own.
function Components.existenceText(snapshot: any?): string
	if snapshot == nil or snapshot.totalSupply == nil then
		return "? in existence"
	end
	return tostring(snapshot.totalSupply) .. " in existence"
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
		t.Existence.Text = Components.existenceText(snapshot)
		t.Stats.ValueRow.Text = "Est. Value: " .. statText(snapshot.value)
		t.Stats.StoreCostRow.Text = "Store Cost: " .. Components.storeCostText(snapshot)
		t.Stats.RapRow.Text = "RAP: " .. statText(snapshot.rap)
	end
	t.CountBadge.Text = (count and count > 1) and ("x" .. tostring(count)) or ""
end

-- Device fit: every top-level panel carries a "FitScale" UIScale (built by
-- GuiBuilder). One camera listener scales each panel proportionally to the
-- live viewport so the whole panel — bottom buttons included — always fits,
-- on any screen size / window / OS scaling. Since offsets multiply by the
-- UIScale, this makes offset-designed panels behave like scale-based ones.
--
-- Desktop: never grows past design size (cap 1). Phones/tablets (touch +
-- short viewport): the panel FILLS the screen instead — letting it upscale
-- past 1 where the aspect allows — so text and touch targets stay big.
-- Panels with scale-based roots (no offset size) manage themselves.
function Components.wireFitScales(gui: ScreenGui)
	local camera = workspace.CurrentCamera
	local panels: { { scale: UIScale, w: number, h: number } } = {}
	for _, child in gui:GetChildren() do
		local fit = child:FindFirstChild("FitScale")
		if child:IsA("Frame") and fit and fit:IsA("UIScale") then
			table.insert(panels, {
				scale = fit,
				w = child.Size.X.Offset,
				h = child.Size.Y.Offset,
			})
		end
	end
	local function refit()
		local vp = camera.ViewportSize
		local touchSmall = UserInputService.TouchEnabled and vp.Y < 600
		local marginX = touchSmall and 16 or 40
		local marginY = touchSmall and 24 or 90
		local cap = touchSmall and 1.75 or 1
		for _, p in panels do
			if p.w > 0 and p.h > 0 then
				p.scale.Scale = math.min(cap, (vp.Y - marginY) / p.h, (vp.X - marginX) / p.w)
			end
		end
	end
	refit()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
end

-- Top-level modal panels that are mutually exclusive: opening one closes the
-- rest so they never clip/overlay. Popups (Invite) and templates are excluded.
local EXCLUSIVE_PANELS = {
	InventoryPanel = true,
	TradePanel = true,
	StorePanel = true,
	EventsPanel = true,
	BoardPanel = true,
	ProfilePanel = true,
	SearchPanel = true,
	RollsPanel = true,
	ShopPanel = true,
	FreeGemsPanel = true,
	SyndicatePanel = true,
}

-- Hide every other exclusive panel (call at the start of a panel's open()).
function Components.closeOtherPanels(panel: Instance)
	local gui = panel.Parent
	if gui == nil then
		return
	end
	for _, sibling in gui:GetChildren() do
		if sibling ~= panel and sibling:IsA("Frame") and EXCLUSIVE_PANELS[sibling.Name] then
			sibling.Visible = false
		end
	end
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
		if snapshot.isWildcard then
			-- trade-ad token: no rarity, no stats — explain what it stands for
			title.TextColor3 = Theme.Warn
			sub.Text = "Trade-ad token"
			body.Text = snapshot.blurb or "Stands for a kind of offer, not a specific item."
		else
			title.TextColor3 = Components.rarityColor(snapshot.rarity)
			sub.Text = (snapshot.rarity or "?") .. " · " .. Components.existenceText(snapshot)
				.. ((count and count > 1) and (" · x" .. count) or "")
			body.Text = ("Est. Value: %s\nStore Cost: %s\nRAP: %s"):format(
				statText(snapshot.value),
				Components.storeCostText(snapshot),
				statText(snapshot.rap)
			)
		end
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

	-- The tooltip is driven by a real hit test, NOT by MouseEnter/MouseLeave.
	-- Why: every screen rebuilds its rows wholesale on refresh (board refresh,
	-- a stats push, an event re-pull — and with 500 bots trading those fire
	-- constantly). The hovered row gets destroyed and its replacement is created
	-- UNDER a stationary cursor, and Roblox only fires MouseEnter on actual
	-- movement — so the tooltip vanished mid-hover and could not come back until
	-- you moved off and on again. Hit-testing each tick is immune to that: the
	-- new row registers itself and is found straight away.
	local registry: { [GuiObject]: () -> (any?, number?) } = {}
	local current: GuiObject? = nil

	-- Mouse in the same space as GuiObject.AbsolutePosition.
	local function mousePoint(): Vector2
		local m = UserInputService:GetMouseLocation()
		if gui.IgnoreGuiInset then
			return Vector2.new(m.X, m.Y)
		end
		local inset = GuiService:GetGuiInset()
		return Vector2.new(m.X - inset.X, m.Y - inset.Y)
	end

	-- Visible AND every ancestor visible — a row inside a closed panel keeps its
	-- own Visible = true and its absolute rect, so checking the object alone
	-- would keep showing tooltips for a panel you closed.
	local function isShown(obj: Instance): boolean
		local node: Instance? = obj
		while node and node ~= gui do
			if node:IsA("GuiObject") and not node.Visible then
				return false
			end
			node = node.Parent
		end
		return node == gui and gui.Enabled
	end

	local function contains(obj: GuiObject, p: Vector2): boolean
		local pos, size = obj.AbsolutePosition, obj.AbsoluteSize
		return p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
	end

	local function alive(obj: GuiObject): boolean
		return obj.Parent ~= nil and isShown(obj)
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 then -- 20Hz is plenty for a tooltip
			return
		end
		acc = 0
		local p = mousePoint()

		-- still on the same thing? keep it up, and keep it FRESH (values move
		-- constantly, so a held tooltip should track them rather than go stale)
		if current and alive(current) and contains(current, p) and registry[current] then
			local snapshot, count = registry[current]()
			show(snapshot, count, current)
			return
		end

		-- otherwise find whatever is under the pointer now (this is what
		-- survives a rebuild under a still cursor)
		for obj, get in registry do
			if alive(obj) and contains(obj, p) then
				current = obj
				local snapshot, count = get()
				show(snapshot, count, obj)
				return
			end
		end
		current = nil
		hide()
	end)

	return {
		attach = function(obj: GuiObject, getSnapshot: () -> (any?, number?))
			registry[obj] = getSnapshot
			obj.Destroying:Connect(function()
				registry[obj] = nil
				if current == obj then
					current = nil -- next tick re-resolves; don't hide, the row may be replaced
				end
			end)
		end,
		hide = hide,
	}
end

return Components
