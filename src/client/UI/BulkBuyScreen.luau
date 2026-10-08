--!strict
-- BulkBuyScreen: the third board tab. Standing item-for-item orders anyone can
-- partly fill: "I want 20 Swords, paying 2 Shields per Sword".
--
-- Built entirely in code, parented to the board panel, so it needs no
-- GuiBuilder/StarterGui splice. Posting reuses the trade compose window:
-- WANT = the one item (and how many copies make one unit), GIVE = what a single
-- unit pays out. The player then only answers "how many units?".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local State = require(ReplicatedStorage.Shared.Util.State)
local TradeAdConfig = require(ReplicatedStorage.Shared.Config.TradeAdConfig)
local Net = require(script.Parent.Parent.Net)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local TradeScreen = require(script.Parent.TradeScreen)

local BulkBuyScreen = {}

local CARD_HEIGHT = 102
local MAX_PAYOUT_SHOWN = 2

local ERRORS: { [string]: string } = {
	own_listing = "That's your own order.",
	gone = "That order is already gone.",
	filled = "That order was just filled.",
	poster_cannot_pay = "The poster can't cover the payout any more — the order was removed.",
	poster_busy = "The poster is busy on another server — try again in a moment.",
	insufficient = "You don't have enough of that item.",
	not_holding = "You don't hold enough of that.",
	loading = "Your data is still loading — try again in a second.",
	bad_payout = "Payout isn't valid — put at least one item or some gems in GIVE.",
	bad_count = "That amount isn't valid.",
	rank_locked = "Reach Regular rank to unlock Bulk Buy.",
	ad_slots_full = "You've used all your trade ad slots. Cancel one first.",
	board_full = "The board is full right now. Try again shortly.",
}
local function errText(err: any): string
	return (type(err) == "string" and ERRORS[err]) or ("Couldn't do that: " .. tostring(err))
end

local function payoutText(listing: any): string
	local parts = {}
	for i, entry in listing.payout.items do
		if i > MAX_PAYOUT_SHOWN then
			table.insert(parts, ("+%d more"):format(#listing.payout.items - MAX_PAYOUT_SHOWN))
			break
		end
		table.insert(parts, ("%s %s"):format(Format.abbrev(entry.count), entry.name))
	end
	if (listing.payout.gems or 0) > 0 then
		table.insert(parts, Format.abbrev(listing.payout.gems) .. " gems")
	end
	return table.concat(parts, " + ")
end

local function rateText(listing: any): string
	-- from the contributor's side: what do I hand in, what do I get
	return ("Hand in %d → get %s"):format(listing.unitIn, payoutText(listing))
end

function BulkBuyScreen.wire(modalGui: ScreenGui, panel: Frame, list: ScrollingFrame, tooltip: any, toast: (string, Color3) -> (), onChanged: () -> ())
	local frame = Instance.new("ScrollingFrame")
	frame.Name = "BulkBuyList"
	frame.AnchorPoint = list.AnchorPoint
	-- the scope row and boost strip are hidden on this tab, so start higher
	local top = 0.172
	frame.Position = UDim2.new(list.Position.X.Scale, list.Position.X.Offset, top, list.Position.Y.Offset)
	frame.Size = UDim2.new(list.Size.X.Scale, list.Size.X.Offset, list.Size.Y.Scale + (list.Position.Y.Scale - top), list.Size.Y.Offset)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.Visible = false
	frame.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingTop, pad.PaddingRight, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4), UDim.new(0, 6), UDim.new(0, 4)
	pad.Parent = frame

	local empty = Instance.new("TextLabel")
	empty.BackgroundTransparency = 1
	empty.Size = UDim2.new(1, 0, 0, 60)
	empty.Font = Theme.Font
	empty.TextSize = 18
	empty.TextColor3 = Theme.TextDim
	empty.Text = "No bulk orders right now — post one and let others fill it."
	empty.TextWrapped = true
	empty.Visible = false
	empty.Parent = frame

	local spawned: { Instance } = {}
	local lastSig: string? = nil
	local amounts: { [string]: number } = {}
	local busy = false

	local function clear()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
		lastSig = nil
	end

	local function label(parent: Instance, text: string, pos: UDim2, size: UDim2, textSize: number, color: Color3, align: Enum.TextXAlignment?): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = pos
		l.Size = size
		l.Font = Theme.Font
		l.TextSize = textSize
		l.TextColor3 = color
		l.Text = text
		l.TextXAlignment = align or Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = parent
		return l
	end

	local function button(parent: Instance, text: string, pos: UDim2, size: UDim2, color: Color3): TextButton
		local b = Instance.new("TextButton")
		b.Position = pos
		b.Size = size
		b.BackgroundColor3 = color
		b.Font = Theme.Font
		b.TextSize = 15
		b.TextColor3 = Theme.TextPrimary
		b.Text = text
		b.AutoButtonColor = true
		b.Parent = parent
		local c = Instance.new("UICorner")
		c.CornerRadius = Theme.CornerSmall
		c.Parent = b
		return b
	end

	local function renderCard(listing: any, order: number)
		local unitsLeft = math.floor(listing.remainingCount / listing.unitIn)
		-- how many payouts THIS player can actually fill from what they hold
		local held = InventoryController.inventory:get()[listing.itemId] or 0
		local fillable = math.min(unitsLeft, math.floor(held / listing.unitIn))
		local card = Instance.new("Frame")
		card.Name = "Card_" .. listing.id
		card.LayoutOrder = order
		card.Size = UDim2.new(1, -8, 0, CARD_HEIGHT)
		card.BackgroundColor3 = Theme.BgLight
		card.BorderSizePixel = 0
		card.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = Theme.Corner
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Theme.Stroke
		stroke.Parent = card
		table.insert(spawned, card)

		local icon = Instance.new("ImageLabel")
		icon.BackgroundColor3 = Theme.Bg
		icon.Position = UDim2.fromOffset(8, 8)
		icon.Size = UDim2.fromOffset(58, 58)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = card
		local ic = Instance.new("UICorner")
		ic.CornerRadius = Theme.CornerSmall
		ic.Parent = icon
		Components.setIcon(icon, { imageId = listing.imageId, name = listing.itemName })
		EconomyController.ensure({ listing.itemId })
		tooltip.attach(icon, function()
			return EconomyController.get(listing.itemId) or { name = listing.itemName, imageId = listing.imageId }, nil
		end)

		label(card, ("WANTS %s × %s"):format(Format.comma(listing.wantedCount), listing.itemName), UDim2.fromOffset(74, 6), UDim2.new(0.5, -80, 0, 22), 16, Theme.TextPrimary)
		label(card, rateText(listing), UDim2.fromOffset(74, 30), UDim2.new(0.5, -80, 0, 20), 14, Theme.Gold)
		local market = ""
		if (listing.wantValue or 0) > 0 and (listing.payoutValue or 0) > 0 then
			market = ("%+d%% vs market"):format(math.floor((listing.payoutValue / listing.wantValue - 1) * 100 + 0.5))
		end
		label(card, ("by %s%s"):format(listing.posterName, market ~= "" and " · " .. market or ""), UDim2.fromOffset(74, 52), UDim2.new(0.5, -80, 0, 18), 12, Theme.TextDim)

		-- progress: reuses the plain track+fill idiom of the rewards bar
		local track = Instance.new("Frame")
		track.Position = UDim2.new(0, 8, 1, -16)
		track.Size = UDim2.new(0.5, -16, 0, 8)
		track.BackgroundColor3 = Theme.Bg
		track.BorderSizePixel = 0
		track.Parent = card
		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(1, 0)
		tc.Parent = track
		local done = listing.wantedCount - listing.remainingCount
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(done / math.max(1, listing.wantedCount), 0, 1), 1)
		fill.BackgroundColor3 = unitsLeft <= 3 and Theme.Good or Theme.Accent
		fill.BorderSizePixel = 0
		fill.Parent = track
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(1, 0)
		fc.Parent = fill
		label(card, ("%s / %s filled"):format(Format.abbrev(done), Format.abbrev(listing.wantedCount)), UDim2.new(0.5, -60, 1, -20), UDim2.fromOffset(120, 16), 11, Theme.TextDim)

		-- right side
		local right = Instance.new("Frame")
		right.BackgroundTransparency = 1
		right.AnchorPoint = Vector2.new(1, 0)
		right.Position = UDim2.new(1, -8, 0, 6)
		right.Size = UDim2.new(0.44, 0, 1, -12)
		right.Parent = card

		if listing.mine then
			local cancel = button(right, "CANCEL REMAINDER", UDim2.new(0, 0, 0.5, -18), UDim2.new(1, 0, 0, 36), Theme.Bad)
			cancel.Activated:Connect(function()
				if busy then
					return
				end
				busy = true
				task.spawn(function()
					local res = Net.invoke("CancelListing", listing.id)
					toast(res.ok and "Order cancelled." or errText(res.err), res.ok and Theme.Warn or Theme.Bad)
					busy = false
					onChanged()
				end)
			end)
			return
		end

		local amount = math.clamp(amounts[listing.id] or 1, 1, math.max(1, fillable))
		amounts[listing.id] = amount
		local minus = button(right, "-", UDim2.fromOffset(0, 0), UDim2.fromOffset(32, 30), Theme.Bg)
		local amountBox = label(right, tostring(amount), UDim2.fromOffset(34, 0), UDim2.fromOffset(56, 30), 18, Theme.TextPrimary, Enum.TextXAlignment.Center)
		amountBox.BackgroundTransparency = 0
		amountBox.BackgroundColor3 = Theme.Bg
		local amountCorner = Instance.new("UICorner")
		amountCorner.CornerRadius = Theme.CornerSmall
		amountCorner.Parent = amountBox
		local plus = button(right, "+", UDim2.fromOffset(92, 0), UDim2.fromOffset(32, 30), Theme.Bg)
		local preview = label(right, "", UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 16), 11, Theme.TextDim)
		local goText = unitsLeft <= 0 and "DONE" or (fillable < 1 and ("NEED %d MORE"):format(listing.unitIn - held) or "CONTRIBUTE")
		local go = button(right, goText, UDim2.new(0, 0, 1, -32), UDim2.new(1, 0, 0, 32), fillable >= 1 and Theme.Good or Theme.Bg)
		-- greyed, not green-then-error, when this player can't fill even one payout
		go.AutoButtonColor = fillable >= 1
		go.TextColor3 = fillable >= 1 and Theme.TextPrimary or Theme.TextDim

		local refreshPreview: () -> ()
		-- payout scales with units: recompute the visible text from real numbers
		local function previewText(): string
			local n = amounts[listing.id]
			local parts = {}
			for i, entry in listing.payout.items do
				if i > MAX_PAYOUT_SHOWN then
					table.insert(parts, ("+%d more"):format(#listing.payout.items - MAX_PAYOUT_SHOWN))
					break
				end
				table.insert(parts, ("%s %s"):format(Format.abbrev(entry.count * n), entry.name))
			end
			if (listing.payout.gems or 0) > 0 then
				table.insert(parts, Format.abbrev(listing.payout.gems * n) .. " gems")
			end
			return ("give %s × %s → get %s"):format(Format.abbrev(n * listing.unitIn), listing.itemName, table.concat(parts, " + "))
		end
		refreshPreview = function()
			amountBox.Text = tostring(amounts[listing.id])
			preview.Text = previewText()
		end
		refreshPreview()

		minus.Activated:Connect(function()
			amounts[listing.id] = math.max(1, amounts[listing.id] - 1)
			refreshPreview()
		end)
		plus.Activated:Connect(function()
			amounts[listing.id] = math.min(math.max(1, fillable), amounts[listing.id] + 1)
			refreshPreview()
		end)
		go.Activated:Connect(function()
			if busy or fillable < 1 then
				return
			end
			busy = true
			task.spawn(function()
				local res = Net.invoke("ContributeBulkBuy", listing.id, amounts[listing.id])
				if res.ok then
					toast(("Filled %d × %s!"):format(res.count, listing.itemName), Theme.Good)
				else
					toast(errText(res.err), Theme.Bad)
				end
				busy = false
				onChanged()
			end)
		end)
	end

	local lastListings: { any }? = nil
	function BulkBuyScreen.render(listings: { any })
		lastListings = listings
		local rows = {}
		for _, l in listings do
			if l.kind == "bulkbuy" then
				table.insert(rows, l)
			end
		end
		-- closest to completion first: those are the ones a contribution finishes
		table.sort(rows, function(a, b)
			local fa, fb = a.remainingCount / a.wantedCount, b.remainingCount / b.wantedCount
			if fa ~= fb then
				return fa < fb
			end
			return a.id < b.id
		end)
		local parts = {}
		for _, l in rows do
			table.insert(parts, ("%s,%d,%s,%d,%d"):format(l.id, l.remainingCount, tostring(l.mine), l.expiresAt or 0, InventoryController.inventory:get()[l.itemId] or 0))
		end
		local sig = table.concat(parts, ";")
		if sig == lastSig then
			return
		end
		clear()
		lastSig = sig
		empty.Visible = #rows == 0
		for i, l in rows do
			renderCard(l, i)
		end
	end

	State.Observe(InventoryController.inventory, function()
		if frame.Visible and lastListings then
			BulkBuyScreen.render(lastListings)
		end
	end)

	function BulkBuyScreen.show()
		frame.Visible = true
	end

	function BulkBuyScreen.hide()
		frame.Visible = false
		clear()
	end


	----------------------------------------------------------------------------
	-- Posting: a dedicated order builder (not the trade window)
	--
	-- A bulk order is "collect N of ONE item, paying X for each copy". So the
	-- builder asks exactly that: which item, how many in total, what each copy
	-- pays. It also shows what the poster must be able to cover and how the
	-- price compares with the market, since that decides whether anyone fills it.
	----------------------------------------------------------------------------

	local MAX_TOTAL = 1000
	local MAX_PAY_ITEMS = 3

	local draft: { item: any?, total: number, per: number, gems: number, pay: { [string]: any } } =
		{ item = nil, total = 10, per = 1, gems = 0, pay = {} }

	local function unitValue(itemId: string): number?
		local snap = EconomyController.get(itemId)
		if snap and snap.value and snap.value.value then
			return snap.value.value
		end
		return nil
	end

	local function corner(inst: Instance, radius: UDim?)
		local c = Instance.new("UICorner")
		c.CornerRadius = radius or Theme.CornerSmall
		c.Parent = inst
	end

	local builder = Instance.new("Frame")
	builder.Name = "BulkOrderBuilder"
	builder.AnchorPoint = Vector2.new(0.5, 0.5)
	builder.Position = UDim2.fromScale(0.5, 0.5)
	builder.Size = UDim2.fromScale(0.4, 0.82)
	builder.BackgroundColor3 = Theme.Panel
	builder.Visible = false
	builder.ZIndex = 50
	builder.Parent = modalGui
	corner(builder, Theme.Corner)
	local bLimit = Instance.new("UISizeConstraint")
	bLimit.MinSize = Vector2.new(340, 420)
	bLimit.MaxSize = Vector2.new(500, 660)
	bLimit.Parent = builder
	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Theme.Stroke
	bStroke.Parent = builder

	local bTitle = label(builder, "NEW BULK ORDER", UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 28), 20, Theme.TextPrimary)
	bTitle.ZIndex = 51
	local bSub = label(builder, "Collect many copies of one item, paying a set price for each.", UDim2.fromOffset(14, 34), UDim2.new(1, -28, 0, 18), 12, Theme.TextDim)
	bSub.ZIndex = 51

	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(10, 58)
	body.Size = UDim2.new(1, -20, 1, -124)
	body.ScrollBarThickness = 5
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ZIndex = 51
	body.Parent = builder
	local bl = Instance.new("UIListLayout")
	bl.Padding = UDim.new(0, 8)
	bl.SortOrder = Enum.SortOrder.LayoutOrder
	bl.Parent = body
	local bp = Instance.new("UIPadding")
	bp.PaddingLeft, bp.PaddingRight, bp.PaddingTop = UDim.new(0, 4), UDim.new(0, 8), UDim.new(0, 2)
	bp.Parent = body

	local order = 0
	local function row(height: number): Frame
		order += 1
		local f = Instance.new("Frame")
		f.LayoutOrder = order
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, height)
		f.ZIndex = 52
		f.Parent = body
		return f
	end
	local function heading(text: string)
		local r = row(20)
		local l = label(r, text, UDim2.new(), UDim2.fromScale(1, 1), 13, Theme.Accent)
		l.ZIndex = 52
	end
	local function inputBox(parent: Instance, pos: UDim2, size: UDim2, text: string, placeholder: string): TextBox
		local t = Instance.new("TextBox")
		t.Position = pos
		t.Size = size
		t.BackgroundColor3 = Theme.BgLight
		t.Font = Theme.Font
		t.TextSize = 18
		t.TextColor3 = Theme.TextPrimary
		t.PlaceholderText = placeholder
		t.PlaceholderColor3 = Theme.TextDim
		t.Text = text
		t.ClearTextOnFocus = false
		t.ZIndex = 52
		t.Parent = parent
		corner(t)
		return t
	end

	-- ── I WANT ──────────────────────────────────────────────────────────────
	heading("I WANT")
	local wantRow = row(52)
	local wantBtn = button(wantRow, "Choose an item…", UDim2.new(), UDim2.new(1, -108, 1, 0), Theme.BgLight)
	wantBtn.ZIndex = 52
	wantBtn.TextXAlignment = Enum.TextXAlignment.Left
	wantBtn.TextSize = 16
	local wantPad = Instance.new("UIPadding")
	wantPad.PaddingLeft = UDim.new(0, 58)
	wantPad.Parent = wantBtn
	local wantIcon = Instance.new("ImageLabel")
	wantIcon.BackgroundColor3 = Theme.Bg
	wantIcon.Position = UDim2.fromOffset(-52, 4)
	wantIcon.Size = UDim2.fromOffset(44, 44)
	wantIcon.ScaleType = Enum.ScaleType.Fit
	wantIcon.Visible = false
	wantIcon.ZIndex = 53
	wantIcon.Parent = wantBtn
	corner(wantIcon)
	local totalBox = inputBox(wantRow, UDim2.new(1, -100, 0, 0), UDim2.new(0, 100, 1, 0), "10", "how many")
	totalBox.TextXAlignment = Enum.TextXAlignment.Center

	-- ── EACH COPY PAYS ─────────────────────────────────────────────────────
	heading("FOR EVERY")
	local perRow = row(40)
	local perBox = inputBox(perRow, UDim2.new(), UDim2.fromOffset(70, 40), "1", "1")
	perBox.TextXAlignment = Enum.TextXAlignment.Center
	local perLabel = label(perRow, "copy", UDim2.fromOffset(80, 0), UDim2.new(1, -80, 1, 0), 15, Theme.TextDim)
	perLabel.ZIndex = 52

	heading("I PAY")
	local gemsRow = row(40)
	local gemsBox = inputBox(gemsRow, UDim2.new(), UDim2.fromOffset(110, 40), "0", "0")
	gemsBox.TextXAlignment = Enum.TextXAlignment.Center
	local gemsLabel = label(gemsRow, "gems", UDim2.fromOffset(120, 0), UDim2.new(1, -120, 1, 0), 15, Theme.Gem)
	gemsLabel.ZIndex = 52

	local payHolder = row(0)
	payHolder.AutomaticSize = Enum.AutomaticSize.Y
	local payLayout = Instance.new("UIListLayout")
	payLayout.Padding = UDim.new(0, 6)
	payLayout.SortOrder = Enum.SortOrder.LayoutOrder
	payLayout.Parent = payHolder

	local addPayRow = row(38)
	local addPay = button(addPayRow, "+ Add an item as payment", UDim2.new(), UDim2.fromScale(1, 1), Theme.BgLight)
	addPay.ZIndex = 52

	local summary = row(0)
	summary.AutomaticSize = Enum.AutomaticSize.Y
	local summaryText = Instance.new("TextLabel")
	summaryText.BackgroundTransparency = 1
	summaryText.AutomaticSize = Enum.AutomaticSize.Y
	summaryText.Size = UDim2.fromScale(1, 0)
	summaryText.Font = Theme.FontLight
	summaryText.TextSize = 14
	summaryText.TextColor3 = Theme.TextPrimary
	summaryText.TextWrapped = true
	summaryText.RichText = true
	summaryText.TextXAlignment = Enum.TextXAlignment.Left
	summaryText.ZIndex = 52
	summaryText.Parent = summary

	local postGo = button(builder, "POST ORDER", UDim2.new(0, 14, 1, -54), UDim2.new(0.5, -20, 0, 42), Theme.Good)
	local postNo = button(builder, "CANCEL", UDim2.new(0.5, 6, 1, -54), UDim2.new(0.5, -20, 0, 42), Theme.Bad)
	postGo.ZIndex, postNo.ZIndex = 51, 51
	postGo.TextSize, postNo.TextSize = 17, 17

	-- ── draft -> UI ────────────────────────────────────────────────────────
	local refreshDraft: () -> ()
	local payRows: { Instance } = {}

	local function readInt(box: TextBox, lo: number, hi: number, fallback: number): number
		local n = tonumber((box.Text:gsub(",", "")))
		if n == nil then
			return fallback
		end
		return math.clamp(math.floor(n), lo, hi)
	end

	local function renderPayRows()
		for _, r in payRows do
			r:Destroy()
		end
		table.clear(payRows)
		local i = 0
		for itemId, p in draft.pay do
			i += 1
			local r = Instance.new("Frame")
			r.LayoutOrder = i
			r.Size = UDim2.new(1, 0, 0, 40)
			r.BackgroundColor3 = Theme.BgLight
			r.ZIndex = 52
			r.Parent = payHolder
			corner(r)
			table.insert(payRows, r)
			local ic = Instance.new("ImageLabel")
			ic.BackgroundColor3 = Theme.Bg
			ic.Position = UDim2.fromOffset(4, 4)
			ic.Size = UDim2.fromOffset(32, 32)
			ic.ScaleType = Enum.ScaleType.Fit
			ic.ZIndex = 53
			ic.Parent = r
			corner(ic)
			Components.setIcon(ic, { imageId = p.imageId, name = p.name })
			local nm = label(r, p.name, UDim2.fromOffset(42, 0), UDim2.new(1, -230, 1, 0), 14, Theme.TextPrimary)
			nm.ZIndex = 53
			local minus = button(r, "-", UDim2.new(1, -170, 0.5, -14), UDim2.fromOffset(28, 28), Theme.Bg)
			local qty = label(r, "x" .. p.count, UDim2.new(1, -140, 0, 0), UDim2.fromOffset(50, 40), 16, Theme.TextPrimary, Enum.TextXAlignment.Center)
			local plus = button(r, "+", UDim2.new(1, -88, 0.5, -14), UDim2.fromOffset(28, 28), Theme.Bg)
			local rm = button(r, "X", UDim2.new(1, -50, 0.5, -14), UDim2.fromOffset(40, 28), Theme.Bad)
			minus.ZIndex, qty.ZIndex, plus.ZIndex, rm.ZIndex = 53, 53, 53, 53
			minus.Activated:Connect(function()
				p.count = math.max(1, p.count - 1)
				qty.Text = "x" .. p.count
				refreshDraft()
			end)
			plus.Activated:Connect(function()
				p.count = math.min(MAX_TOTAL, p.count + 1)
				qty.Text = "x" .. p.count
				refreshDraft()
			end)
			rm.Activated:Connect(function()
				draft.pay[itemId] = nil
				renderPayRows()
				refreshDraft()
			end)
		end
	end

	local function payCount(): number
		local n = 0
		for _ in draft.pay do
			n += 1
		end
		return n
	end

	-- Everything the order needs, recomputed on every change.
	local canPost = false
	refreshDraft = function()
		draft.total = readInt(totalBox, 1, MAX_TOTAL, 1)
		draft.per = readInt(perBox, 1, MAX_TOTAL, 1)
		draft.gems = readInt(gemsBox, 0, 10000000, 0)
		local item = draft.item
		local name = item and item.name or "the item"
		perLabel.Text = draft.per == 1 and "copy of " .. name or "copies of " .. name
		local units = math.floor(draft.total / draft.per)
		local lines = {}
		canPost = true
		if item == nil then
			table.insert(lines, "<font color='#f05f5f'>Choose the item you want.</font>")
			canPost = false
		end
		if units < 1 then
			table.insert(lines, "<font color='#f05f5f'>Total must be at least one payout's worth of copies.</font>")
			canPost = false
		end
		if draft.gems <= 0 and payCount() == 0 then
			table.insert(lines, "<font color='#f05f5f'>Add a payment: gems, an item, or both.</font>")
			canPost = false
		end
		if canPost and item then
			local pieces = {}
			if draft.gems > 0 then
				table.insert(pieces, Format.comma(draft.gems) .. " gems")
			end
			local payValue = draft.gems
			local needItems: { [string]: number } = {}
			for itemId, p in draft.pay do
				table.insert(pieces, ("%d × %s"):format(p.count, p.name))
				needItems[itemId] = p.count * units
				payValue += p.count * (unitValue(itemId) or 0)
			end
			local totalCopies = units * draft.per
			table.insert(lines, ("Wants <b>%s × %s</b>. Each %d %s handed in earns <b>%s</b>."):format(
				Format.comma(totalCopies), name, draft.per, draft.per == 1 and "copy" or "copies", table.concat(pieces, " + ")))
			if totalCopies ~= draft.total then
				table.insert(lines, ("<font color='#8a93a8'>(Total rounded to %s so payouts stay whole.)</font>"):format(Format.comma(totalCopies)))
			end
			-- what the poster must be able to cover when it fills
			local held = InventoryController.inventory:get()
			local gemsHeld = InventoryController.gems:get()
			local short = {}
			if draft.gems * units > gemsHeld then
				table.insert(short, ("%s gems (you have %s)"):format(Format.comma(draft.gems * units), Format.comma(gemsHeld)))
			end
			for itemId, n in needItems do
				if (held[itemId] or 0) < n then
					table.insert(short, ("%d × %s (you have %d)"):format(n, draft.pay[itemId].name, held[itemId] or 0))
				end
			end
			if #short > 0 then
				table.insert(lines, "<font color='#f05f5f'>To fill the whole order you'd need " .. table.concat(short, ", ") .. ".</font>")
				canPost = false
			else
				table.insert(lines, ("Nothing is taken now. Payouts come out of your inventory as copies arrive; at most <b>%s gems</b> and <b>%d item%s</b> in total."):format(
					Format.comma(draft.gems * units), payCount(), payCount() == 1 and "" or "s"))
			end
			-- price vs market: decides whether anyone will fill it
			local wv = unitValue(item.itemId)
			if wv and wv > 0 and payValue > 0 then
				local pct = math.floor((payValue / (wv * draft.per) - 1) * 100 + 0.5)
				local color = pct >= 0 and "#57d982" or (pct > -20 and "#fabe50" or "#f05f5f")
				local hint = pct >= 0 and "should fill fast" or (pct > -20 and "may fill slowly" or "few will take this")
				table.insert(lines, ("Price vs market: <font color='%s'><b>%+d%%</b> — %s</font>"):format(color, pct, hint))
			end
		end
		summaryText.Text = table.concat(lines, "<br/>")
		postGo.BackgroundColor3 = canPost and Theme.Good or Theme.BgLight
		postGo.AutoButtonColor = canPost
	end

	local function setWantItem(e: any)
		draft.item = e
		wantBtn.Text = e.name
		wantIcon.Visible = true
		Components.setIcon(wantIcon, { imageId = e.imageId, name = e.name })
		EconomyController.ensure({ e.itemId })
		-- a payout item equal to the wanted one makes no sense; drop it
		if draft.pay[e.itemId] then
			draft.pay[e.itemId] = nil
			renderPayRows()
		end
		refreshDraft()
	end

	-- Both buttons borrow the trade window's own item picker, so choosing an item
	-- looks and behaves exactly as it does there. The builder steps aside while
	-- it is open and comes back when a pick is made or the picker is closed.
	local function pickFromTrade(source: string, onPick: (string, number?) -> ())
		builder.Visible = false
		local done = false
		local function restore()
			if not done then
				done = true
				builder.Visible = true
			end
		end
		TradeScreen.pickItem(source, function(itemId, count)
			onPick(itemId, count)
			restore()
		end)
		-- pickItem lifts the picker out to this screen, so it can be found here now;
		-- closing it with the X (no pick) must bring the builder back
		local picker = modalGui:FindFirstChild("ItemPicker") :: GuiObject?
		if picker then
			local conn: RBXScriptConnection
			conn = picker:GetPropertyChangedSignal("Visible"):Connect(function()
				if not picker.Visible then
					conn:Disconnect()
					task.defer(restore)
				end
			end)
		end
	end

	-- name/art may not have reached the client yet for a catalog pick
	local function itemEntry(itemId: string): any
		local snap = EconomyController.get(itemId)
		return { itemId = itemId, name = snap and snap.name or EconomyController.nameFor(itemId), imageId = snap and snap.imageId or nil }
	end

	wantBtn.Activated:Connect(function()
		pickFromTrade("catalog", function(itemId)
			EconomyController.ensure({ itemId })
			setWantItem(itemEntry(itemId))
			task.spawn(function()
				for _ = 1, 20 do
					if EconomyController.get(itemId) then
						break
					end
					task.wait(0.1)
				end
				if draft.item and draft.item.itemId == itemId then
					setWantItem(itemEntry(itemId))
				end
			end)
		end)
	end)

	addPay.Activated:Connect(function()
		pickFromTrade("inventory", function(itemId, count)
			if draft.item and draft.item.itemId == itemId then
				toast("That's the item you're collecting.", Theme.Warn)
				return
			end
			if draft.pay[itemId] == nil and payCount() >= MAX_PAY_ITEMS then
				toast(("At most %d different payment items."):format(MAX_PAY_ITEMS), Theme.Warn)
				return
			end
			EconomyController.ensure({ itemId })
			local e = itemEntry(itemId)
			local existing = draft.pay[itemId]
			draft.pay[itemId] = { name = e.name, imageId = e.imageId, count = (existing and existing.count or 0) + (count or 1) }
			renderPayRows()
			refreshDraft()
		end)
	end)

	for _, box in { totalBox, perBox, gemsBox } do
		box.FocusLost:Connect(function()
			box.Text = tostring(readInt(box, box == gemsBox and 0 or 1, box == gemsBox and 10000000 or MAX_TOTAL, box == gemsBox and 0 or 1))
			refreshDraft()
		end)
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if box:IsFocused() then
				refreshDraft()
			end
		end)
	end

	postNo.Activated:Connect(function()
		builder.Visible = false
	end)
	postGo.Activated:Connect(function()
		if busy then
			return
		end
		refreshDraft()
		if not canPost or draft.item == nil then
			toast("Finish the order first — see the red lines.", Theme.Warn)
			return
		end
		local units = math.floor(draft.total / draft.per)
		local payItems: { [string]: number } = {}
		for itemId, p in draft.pay do
			payItems[itemId] = p.count
		end
		busy = true
		builder.Visible = false
		task.spawn(function()
			local res = Net.invoke("PostListing", {
				kind = "bulkbuy",
				itemId = draft.item.itemId,
				unitIn = draft.per,
				count = units * draft.per,
				payout = { items = payItems, gems = draft.gems > 0 and draft.gems or nil },
				scope = TradeAdConfig.Scopes.Global,
			})
			toast(res.ok and "Bulk order posted!" or errText(res.err), res.ok and Theme.Good or Theme.Bad)
			busy = false
			onChanged()
		end)
	end)

	function BulkBuyScreen.openBuilder()
		draft.item, draft.total, draft.per, draft.gems = nil, 10, 1, 0
		table.clear(draft.pay)
		wantBtn.Text = "Choose an item…"
		wantIcon.Visible = false
		totalBox.Text, perBox.Text, gemsBox.Text = "10", "1", "0"
		renderPayRows()
		refreshDraft()
		builder.Visible = true
	end

end

return BulkBuyScreen
