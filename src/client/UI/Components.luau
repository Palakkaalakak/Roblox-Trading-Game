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
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Components = {}

local PLACEHOLDER_IMAGE = "rbxasset://textures/ui/GuiImagePlaceholder.png"

-- "N/A" for missing data, abbreviated for big numbers.
--
-- This used to carry its own "%.1fk" formatter, which disagreed with
-- Format.abbrev everywhere else: 1300 read "1.3k" here and "1.3K" elsewhere,
-- and 1000 read "1.0k" instead of "1K". One formatter now.
local function statText(stat: any): string
	if stat == nil or stat.state ~= "Known" or stat.value == nil then
		return "N/A"
	end
	return Format.abbrev(stat.value)
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
		-- abbrev, matching Est. Value and RAP on the same card. It used to print
		-- the raw number, so one card read "Est. Value: 1.3K / Store Cost: 1300"
		-- and the two looked like different quantities.
		return Format.abbrev(snapshot.storeCost)
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
	return Format.abbrev(snapshot.totalSupply) .. " in existence"
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
	RewardsPanel = true,
	ConversionPanel = true,
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

	-- A touch-only device has no pointer to hover with, so this whole loop can
	-- never produce a tooltip there -- it would only burn frames on exactly the
	-- hardware that can least afford it. Devices with both (emulator, tablet
	-- with a mouse) keep it.
	local hoverCapable = UserInputService.MouseEnabled or not UserInputService.TouchEnabled

	local acc = 0
	local lastPoint = Vector2.zero
	local idleAcc = 0
	if hoverCapable then
		RunService.Heartbeat:Connect(function(dt)
			acc += dt
			if acc < 0.05 then -- 20Hz is plenty for a tooltip
				return
			end
			acc = 0
			local p = mousePoint()
			local moved = p ~= lastPoint
			lastPoint = p

			-- still on the same thing? keep it up, and keep it FRESH (values move
			-- constantly, so a held tooltip should track them rather than go stale)
			-- contains() is two property reads; alive() walks every ancestor up to
			-- the ScreenGui, so the cheap test gates the expensive one.
			if current and contains(current, p) and alive(current) and registry[current] then
				local snapshot, count = registry[current]()
				show(snapshot, count, current)
				return
			end

			-- A full registry sweep is O(number of attached tiles), and with a
			-- board open that is hundreds. At rest the answer almost never
			-- changes, so sweep every tick only while the pointer is actually
			-- moving and drop to ~4Hz when it is parked. The parked sweep is what
			-- still catches a row rebuilt under a stationary cursor.
			if not moved then
				idleAcc += 0.05
				if idleAcc < 0.25 then
					return
				end
				idleAcc = 0
			else
				idleAcc = 0
			end

			-- otherwise find whatever is under the pointer now (this is what
			-- survives a rebuild under a still cursor)
			for obj, get in registry do
				if contains(obj, p) and alive(obj) then
					current = obj
					local snapshot, count = get()
					show(snapshot, count, obj)
					return
				end
			end
			current = nil
			hide()
		end)
	end

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


-- A ScrollingFrame clips its descendants, and a UIStroke straddles the edge it
-- is drawn on. Rows sized (1, -8) sit flush at x=0 and y=0, so the OUTER half
-- of their left and top borders gets cut off while the other sides keep their
-- gutter -- a visibly lopsided box.
--
-- Giving every list a gutter at BUILD time was not enough: any ScrollingFrame
-- created at runtime (the group screen builds its Goals and Settings lists that
-- way) missed the pass entirely and the clipping came straight back. So this
-- watches instead of sweeping once -- every list gets a gutter whenever and
-- wherever it is created.
local GUTTER = 6

local function applyGutter(scroll: ScrollingFrame)
	local pad = scroll:FindFirstChildWhichIsA("UIPadding")
	if pad == nil then
		pad = Instance.new("UIPadding")
		pad.Parent = scroll
	end
	-- All FOUR sides. A UIStroke straddles the edge it draws on and a
	-- ScrollingFrame clips its descendants, so a row flush against any edge
	-- loses the outer half of its border. Padding only left/top fixed lists
	-- (which are full-width, so only those two edges touch) but left grids
	-- clipped down the right-hand column and along the bottom row — which is
	-- what the booth's rarity-coloured cell borders were hitting.
	-- Only widen; never shrink a gutter a caller set deliberately.
	if pad.PaddingLeft.Offset < GUTTER then
		pad.PaddingLeft = UDim.new(0, GUTTER)
	end
	if pad.PaddingTop.Offset < GUTTER then
		pad.PaddingTop = UDim.new(0, GUTTER)
	end
	if pad.PaddingRight.Offset < GUTTER then
		pad.PaddingRight = UDim.new(0, GUTTER)
	end
	if pad.PaddingBottom.Offset < GUTTER then
		pad.PaddingBottom = UDim.new(0, GUTTER)
	end
end

function Components.autoGutter(gui: ScreenGui)
	for _, d in gui:GetDescendants() do
		if d:IsA("ScrollingFrame") then
			applyGutter(d)
		end
	end
	gui.DescendantAdded:Connect(function(d)
		if d:IsA("ScrollingFrame") then
			applyGutter(d)
		end
	end)
end

-- A quantity picker: [−] [ N ] [+], where N is also typeable.
--
-- Same shape as the recipe-chain zoom stepper (28px square buttons, BgLight,
-- CornerSmall) so "pick a number" looks the same everywhere it appears —
-- crafting a batch, buying several copies off a booth.
--
-- Clamped to [min, max] on every path: the buttons, typing, and set(). Callers
-- pass the real ceiling (how many you can afford, how many are left in stock),
-- so the widget can never offer a quantity the action would reject.
--
-- Returns the frame plus get/set/setMax, so a caller can re-clamp when the
-- underlying limit moves (stock sold while the dialog is open).
export type Stepper = {
	frame: Frame,
	get: () -> number,
	set: (n: number) -> (),
	setMax: (n: number) -> (),
}

function Components.quantityStepper(parent: Instance, opts: {
	min: number?,
	max: number,
	value: number?,
	width: number?,
	height: number?,
	zIndex: number?,
	onChanged: ((n: number) -> ())?,
}): Stepper
	local minN = opts.min or 1
	local maxN = math.max(minN, opts.max)
	local z = opts.zIndex or 1
	local boxW = opts.width or 56
	-- rows are tight; a caller with less vertical room can shrink the whole
	-- control rather than have it hang over the row below
	local h = opts.height or 28

	local frame = Instance.new("Frame")
	frame.Name = "QuantityStepper"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(h + 4 + boxW + 4 + h, h)
	frame.ZIndex = z
	frame.Parent = parent

	local function squareBtn(text: string, x: number): TextButton
		local b = Instance.new("TextButton")
		b.Position = UDim2.fromOffset(x, 0)
		b.Size = UDim2.fromOffset(h, h)
		b.BackgroundColor3 = Theme.BgLight
		b.Font = Theme.Font
		b.TextSize = math.max(14, h - 10)
		b.TextColor3 = Theme.TextPrimary
		b.AutoButtonColor = true
		b.Text = text
		b.ZIndex = z
		b.Parent = frame
		local c = Instance.new("UICorner")
		c.CornerRadius = Theme.CornerSmall
		c.Parent = b
		return b
	end

	local minus = squareBtn("−", 0)
	minus.Name = "Minus"

	local box = Instance.new("TextBox")
	box.Name = "Amount"
	box.Position = UDim2.fromOffset(h + 4, 0)
	box.Size = UDim2.fromOffset(boxW, h)
	box.BackgroundColor3 = Theme.BgLight
	box.Font = Theme.Font
	box.TextSize = 14
	box.TextColor3 = Theme.TextPrimary
	box.ClearTextOnFocus = false
	box.Text = tostring(math.clamp(opts.value or minN, minN, maxN))
	box.ZIndex = z
	box.Parent = frame
	local bc = Instance.new("UICorner")
	bc.CornerRadius = Theme.CornerSmall
	bc.Parent = box

	local plus = squareBtn("+", h + 4 + boxW + 4)
	plus.Name = "Plus"

	local current = math.clamp(opts.value or minN, minN, maxN)

	local function apply(n: number, fromTyping: boolean?)
		current = math.clamp(math.floor(n), minN, maxN)
		-- don't fight the caret while they are mid-word; the value is still
		-- clamped, it just isn't rewritten under them until they finish
		if not (fromTyping and box:IsFocused()) then
			box.Text = tostring(current)
		end
		minus.AutoButtonColor = current > minN
		plus.AutoButtonColor = current < maxN
		minus.TextColor3 = current > minN and Theme.TextPrimary or Theme.TextDim
		plus.TextColor3 = current < maxN and Theme.TextPrimary or Theme.TextDim
		if opts.onChanged then
			opts.onChanged(current)
		end
	end

	minus.Activated:Connect(function()
		apply(current - 1)
	end)
	plus.Activated:Connect(function()
		apply(current + 1)
	end)
	box.FocusLost:Connect(function()
		apply(Format.parseAmount(box.Text) or current)
	end)

	apply(current)

	return {
		frame = frame,
		get = function()
			return current
		end,
		set = function(n: number)
			apply(n)
		end,
		setMax = function(n: number)
			maxN = math.max(minN, math.floor(n))
			apply(current)
		end,
	}
end

return Components
