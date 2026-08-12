--!strict
-- Trade window wiring (GUI lives in StarterGui, edit visually there).
--   * one item COPY per slot: an offer of 2x Stone Relic fills two slots
--   * clicking one of your EMPTY (+) slots opens the ItemPicker menu
--   * clicking one of your FILLED slots removes that copy
--   * gems: type the amount, press OK — that's the whole interaction
--   * both accept -> server-enforced countdown, cancel still works
-- Server view (TradeController.trade) is the only source of truth.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local TradeConfig = require(ReplicatedStorage.Shared.Config.TradeConfig)
local WildcardConfig = require(ReplicatedStorage.Shared.Config.WildcardConfig)
local Tax = require(ReplicatedStorage.Shared.Util.Tax)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local TradeController = require(script.Parent.Parent.Controllers.TradeController)
local QuickChatConfig = require(game:GetService("ReplicatedStorage").Shared.Config.QuickChatConfig)
local Net = require(script.Parent.Parent.Net)

local localPlayer = Players.LocalPlayer

local TradeScreen = {}

-- offer {itemId->count} -> flat sorted copies list {itemId, itemId, ...}
local function offerToCopies(offer: any): { string }
	local ids = {}
	for itemId in offer.items do
		table.insert(ids, itemId)
	end
	table.sort(ids)
	local copies = {}
	for _, itemId in ids do
		for _ = 1, offer.items[itemId] do
			table.insert(copies, itemId)
		end
	end
	return copies
end

function TradeScreen.wire(gui: ScreenGui, tooltip: any)
	local panel = gui:WaitForChild("TradePanel") :: Frame

	----------------------------------------------------------------------
	-- QUICK CHAT
	--
	-- Roblox blocks text chat between accounts in different age groups, so
	-- for a large share of pairings the two people in a trade cannot type to
	-- each other at all. Canned phrases are server-authored, so they carry no
	-- such restriction: pressing one sends an ID and the server relays the
	-- wording. This is the only way those players can negotiate.
	--
	-- Built here rather than in GuiBuilder because it hangs off the trade
	-- panel and nothing else uses it.
	----------------------------------------------------------------------
	local chatPanel = Instance.new("Frame")
	chatPanel.Name = "QuickChat"
	chatPanel.AnchorPoint = Vector2.new(0, 0)
	chatPanel.Position = UDim2.new(1, 10, 0, 0)
	chatPanel.Size = UDim2.fromOffset(230, 640)
	chatPanel.BackgroundColor3 = Theme.Panel
	chatPanel.BorderSizePixel = 0
	chatPanel.Visible = false
	chatPanel.Parent = panel
	local qc = Instance.new("UICorner")
	qc.CornerRadius = Theme.Corner
	qc.Parent = chatPanel
	local qs = Instance.new("UIStroke")
	qs.Color = Theme.Stroke
	qs.Thickness = 1.5
	qs.Parent = chatPanel

	local qcTitle = Instance.new("TextLabel")
	qcTitle.BackgroundTransparency = 1
	qcTitle.Position = UDim2.fromOffset(12, 8)
	qcTitle.Size = UDim2.new(1, -24, 0, 20)
	qcTitle.Font = Theme.Font
	qcTitle.Text = "Quick Chat"
	qcTitle.TextSize = 15
	qcTitle.TextColor3 = Theme.TextPrimary
	qcTitle.TextXAlignment = Enum.TextXAlignment.Left
	qcTitle.Parent = chatPanel

	-- what has been said, newest last
	local qcLog = Instance.new("ScrollingFrame")
	qcLog.Name = "Log"
	qcLog.BackgroundColor3 = Theme.Bg
	qcLog.BorderSizePixel = 0
	qcLog.Position = UDim2.fromOffset(10, 32)
	qcLog.Size = UDim2.new(1, -20, 0, 150)
	qcLog.ScrollBarThickness = 5
	qcLog.AutomaticCanvasSize = Enum.AutomaticSize.Y
	qcLog.CanvasSize = UDim2.new()
	qcLog.Parent = chatPanel
	local lc = Instance.new("UICorner")
	lc.CornerRadius = Theme.CornerSmall
	lc.Parent = qcLog
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 2)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = qcLog

	-- the phrase buttons
	local qcPhrases = Instance.new("ScrollingFrame")
	qcPhrases.Name = "Phrases"
	qcPhrases.BackgroundTransparency = 1
	qcPhrases.BorderSizePixel = 0
	qcPhrases.Position = UDim2.fromOffset(10, 190)
	qcPhrases.Size = UDim2.new(1, -20, 1, -200)
	qcPhrases.ScrollBarThickness = 5
	qcPhrases.AutomaticCanvasSize = Enum.AutomaticSize.Y
	qcPhrases.CanvasSize = UDim2.new()
	qcPhrases.Parent = chatPanel
	local pl = Instance.new("UIListLayout")
	pl.Padding = UDim.new(0, 4)
	pl.SortOrder = Enum.SortOrder.LayoutOrder
	pl.Parent = qcPhrases

	local qcOrder = 0
	local function appendQuickChat(payload: any)
		qcOrder += 1
		local row = Instance.new("TextLabel")
		row.LayoutOrder = qcOrder
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -10, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Font = Enum.Font.Gotham
		row.TextSize = 12
		row.TextWrapped = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.RichText = false
		-- your own lines are dimmed so the partner's stand out
		local mine = payload.fromUserId == Players.LocalPlayer.UserId
		row.TextColor3 = mine and Theme.TextDim or Theme.TextPrimary
		row.Text = ("%s: %s"):format(mine and "You" or tostring(payload.fromName), tostring(payload.text))
		row.Parent = qcLog
		task.defer(function()
			qcLog.CanvasPosition = Vector2.new(0, math.max(0, qcLog.AbsoluteCanvasSize.Y))
		end)
	end

	-- An item-slot phrase ("I want your X") needs an item before it can be
	-- sent. Naming a specific thing is most of what negotiating is, and it is
	-- exactly what a fixed phrase list normally cannot express -- so it is
	-- worth the extra tap.
	local pendingSlotPhrase: string? = nil

	local function sendPhrase(phraseId: string, itemId: string?)
		local view = TradeController.trade:get()
		if view == nil or view.tradeId == nil then
			return
		end
		task.spawn(function()
			Net.invoke("TradeQuickChat", view.tradeId, phraseId, itemId)
		end)
	end

	local order = 0
	for _, groupId in QuickChatConfig.GroupOrder do
		order += 1
		local head = Instance.new("TextLabel")
		head.LayoutOrder = order
		head.BackgroundTransparency = 1
		head.Size = UDim2.new(1, -8, 0, 16)
		head.Font = Theme.Font
		head.Text = (QuickChatConfig.GroupLabels[groupId] or groupId):upper()
		head.TextSize = 10
		head.TextColor3 = Theme.TextDim
		head.TextXAlignment = Enum.TextXAlignment.Left
		head.Parent = qcPhrases

		for _, phrase in QuickChatConfig.TradePhrases do
			if phrase.group == groupId then
				order += 1
				local b = Instance.new("TextButton")
				b.LayoutOrder = order
				b.Size = UDim2.new(1, -8, 0, 26)
				b.BackgroundColor3 = Theme.BgLight
				b.Font = Enum.Font.Gotham
				b.TextSize = 12
				b.TextColor3 = Theme.TextPrimary
				b.TextXAlignment = Enum.TextXAlignment.Left
				-- show the slot phrases with a placeholder so it is obvious they
				-- will ask which item
				b.Text = "  " .. (phrase.slot == "item"
					and (phrase.text):format("...")
					or phrase.text)
				b.Parent = qcPhrases
				local bc = Instance.new("UICorner")
				bc.CornerRadius = Theme.CornerSmall
				bc.Parent = b
				b.Activated:Connect(function()
					if phrase.slot == "item" then
						pendingSlotPhrase = phrase.id
						TradeScreen.openPicker("inventory")
					else
						sendPhrase(phrase.id)
					end
				end)
			end
		end
	end

	-- consumed by the picker: when a slot phrase is waiting, the next item
	-- picked completes it instead of being added to the offer
	function TradeScreen._consumeSlotPick(itemId: string): boolean
		if pendingSlotPhrase == nil then
			return false
		end
		local phraseId = pendingSlotPhrase
		pendingSlotPhrase = nil
		sendPhrase(phraseId, itemId)
		return true
	end

	Net.on("TradeChat", function(payload)
		if payload then
			appendQuickChat(payload)
		end
	end)

	local title = panel:WaitForChild("Title") :: TextLabel
	local statusLabel = panel:WaitForChild("StatusLabel") :: TextLabel
	local acceptBtn = panel:WaitForChild("AcceptButton") :: TextButton
	local cancelBtn = panel:WaitForChild("CancelButton") :: TextButton
	local countdownBar = panel:WaitForChild("CountdownBar") :: Frame
	local countdownText = countdownBar:WaitForChild("Text") :: TextLabel
	local autoToggle = panel:FindFirstChild("AutoToggle") :: TextButton?

	-- Viewport fit is handled centrally: Components.wireFitScales (called
	-- from init.client) drives the FitScale on every modal panel.

	-- Board-compose mode: the same trade window, but BOTH sides are yours to
	-- edit (give = escrowed on post, want = what you're asking). Local state
	-- only — nothing touches the server until POST.
	local compose: any = nil -- { give = offer, want = offer, autoTrade, onPost }
	local renderCompose -- fwd decl

	--------------------------------------------------------------------------
	-- Sides
	--------------------------------------------------------------------------

	local function wireSide(sideName: string, mine: boolean)
		local side = panel:WaitForChild(sideName) :: Frame
		local grid = side:WaitForChild("SlotGrid") :: Frame
		local gemsRow = side:WaitForChild("GemsRow") :: Frame

		local slots = {}
		for i = 1, TradeConfig.MaxSlotsPerSide do
			local slot = grid:WaitForChild("Slot" .. i) :: GuiObject
			local entry = {
				frame = slot,
				icon = slot:WaitForChild("Icon") :: ImageLabel,
				plus = slot:WaitForChild("Plus") :: TextLabel,
				stroke = slot:FindFirstChildWhichIsA("UIStroke") :: UIStroke,
				itemId = nil :: string?,
			}
			slots[i] = entry

			local slotButton = slot :: any
			slotButton.Activated:Connect(function()
				if compose then
					-- compose mode: both grids editable, all local
					local offer = mine and compose.give or compose.want
					if entry.itemId then
						offer.items[entry.itemId] -= 1
						if offer.items[entry.itemId] <= 0 then
							offer.items[entry.itemId] = nil
						end
						renderCompose()
					else
						TradeScreen.openPicker(mine and "inventory" or "catalog")
					end
				elseif mine then
					-- Once you've accepted, your offer is locked — a stray
					-- click on your own slot (e.g. just looking at an item)
					-- used to silently drop your accept, because ANY offer
					-- edit resets both confirms server-side. Unaccept first.
					local view = TradeController.trade:get()
					if view and view.you.confirmed then
						return
					end
					if entry.itemId then
						TradeController.removeItem(entry.itemId)
					else
						TradeScreen.openPicker("inventory")
					end
				end
			end)
			tooltip.attach(slot, function()
				if entry.itemId == nil then
					return nil, nil
				end
				return EconomyController.get(entry.itemId) or WildcardConfig.snapshot(entry.itemId), 1
			end)
		end

		local api = {
			side = side,
			header = side:WaitForChild("Header") :: TextLabel,
			readyPill = side:WaitForChild("ReadyPill") :: TextLabel,
			slots = slots,
			mine = mine,
		}

		if mine then
			local box = gemsRow:WaitForChild("AmountBox") :: TextBox
			local ok = gemsRow:FindFirstChild("OkButton") :: TextButton?
			if ok then
				ok.Visible = false -- gems auto-confirm on type now; no OK click needed
			end
			api.gemsBox = box
			local function submit()
				local n = tonumber(box.Text)
				if n == nil then
					return
				end
				n = math.max(0, math.floor(n))
				if compose then
					compose.give.gems = n
					renderCompose()
					return
				end
				local view = TradeController.trade:get()
				if view and view.you.confirmed then
					box.Text = tostring(view.you.offer.gems) -- revert stray edit; already accepted
					return
				end
				TradeController.setGems(n)
			end
			-- Auto-confirm: debounce a touch so a burst of keystrokes sends one
			-- SetOffer, not one per digit. FocusLost still flushes immediately.
			local pending: thread? = nil
			box:GetPropertyChangedSignal("Text"):Connect(function()
				if not box:IsFocused() then
					return -- programmatic set from a render, not the user typing
				end
				if pending then
					task.cancel(pending)
				end
				pending = task.delay(0.4, function()
					pending = nil
					submit()
				end)
			end)
			box.FocusLost:Connect(function()
				if pending then
					task.cancel(pending)
					pending = nil
				end
				submit()
			end)
		else
			api.gemsLabel = gemsRow:WaitForChild("Amount") :: TextLabel
			-- compose-only editor for the WANT side's gems
			local wantBox = gemsRow:FindFirstChild("WantBox") :: TextBox?
			api.wantBox = wantBox
			if wantBox then
				wantBox.FocusLost:Connect(function()
					if compose then
						local n = tonumber(wantBox.Text)
						if n then
							compose.want.gems = math.max(0, math.floor(n))
						end
						renderCompose()
					end
				end)
			end
		end

		return api
	end

	local yourSide = wireSide("YourSide", true)
	local theirSide = wireSide("TheirSide", false)

	-- per-side overall stats (labels may be missing in an unrebuilt GUI)
	local yourTotal = panel:FindFirstChild("YourTotal") :: TextLabel?
	local theirTotal = panel:FindFirstChild("TheirTotal") :: TextLabel?

	-- Sum of estimated item values + offered gems, all POST-TAX (gems the
	-- recipient actually receives after the house cut). Items whose value is
	-- still N/A are counted at 0 and flagged with a '+?'.
	local function offerTotalText(offer: any, stats: { [string]: any }): string
		local netGems = Tax.split(offer.gems)
		local total = netGems
		local unknown = false
		local copies = 0
		local tokens = 0
		for itemId, count in offer.items do
			if WildcardConfig.isWildcard(itemId) then
				tokens += 1 -- trade-ad tokens carry no value of their own
			else
				copies += count
				local snap = stats[itemId]
				if snap and snap.value and snap.value.state == "Known" and snap.value.value then
					total += snap.value.value * count
				else
					unknown = true
				end
			end
		end
		return ("Total: ~%d gems%s  (%d item%s + %d gems after tax)%s"):format(
			total,
			unknown and " +?" or "",
			copies,
			copies == 1 and "" or "s",
			netGems,
			tokens > 0 and "  ·  trade ad" or ""
		)
	end

	local function renderSide(side: any, offer: any, confirmed: boolean, stats: { [string]: any })
		local copies = offerToCopies(offer)
		for i, entry in side.slots do
			local itemId = copies[i]
			if itemId then
				-- trade-ad tokens aren't in the stats push; resolve locally
				local snap = stats[itemId] or WildcardConfig.snapshot(itemId)
				entry.itemId = itemId
				entry.plus.Text = ""
				entry.icon.Visible = true
				Components.setIcon(entry.icon, snap)
				entry.stroke.Color = snap and Components.rarityColor(snap.rarity) or Theme.Stroke
				entry.stroke.Thickness = 1.5
			else
				entry.itemId = nil
				entry.plus.Text = side.mine and "+" or ""
				entry.icon.Visible = false
				entry.stroke.Color = Theme.Stroke
				entry.stroke.Thickness = 1
			end
		end

		if side.mine then
			-- your side: what you actually put in (gross) — you're editing it
			if not side.gemsBox:IsFocused() then
				side.gemsBox.Text = tostring(offer.gems)
			end
		else
			-- their side: what you'll RECEIVE after the 5% house cut
			local net = Tax.split(offer.gems)
			side.gemsLabel.Text = offer.gems > 0 and (tostring(net) .. " (after tax)") or "0"
		end

		side.readyPill.Text = confirmed and "READY ✔" or "not ready"
		side.readyPill.TextColor3 = confirmed and Theme.Good or Theme.TextDim

		-- your own grid dims once accepted — it's locked (unaccept to edit)
		if side.mine then
			local dim = confirmed and 0.5 or 0
			for _, entry in side.slots do
				entry.icon.ImageTransparency = dim
				entry.plus.TextTransparency = dim
			end
			side.gemsBox.TextEditable = not confirmed
		end
	end

	--------------------------------------------------------------------------
	-- Item picker (opens from an empty slot)
	--------------------------------------------------------------------------

	local picker = panel:WaitForChild("ItemPicker") :: Frame
	local pickerGrid = picker:WaitForChild("PickerGrid") :: ScrollingFrame
	local pickerTemplate = pickerGrid:WaitForChild("PickerTile") :: ImageButton

	local pickerClose = picker:WaitForChild("CloseButton") :: TextButton
	pickerClose.Activated:Connect(function()
		picker.Visible = false
	end)

	local pickerTiles: { [string]: ImageButton } = {}
	local catalogCache: { any }? = nil
	-- Which list the picker is currently showing. The trade view / inventory /
	-- stats observers all re-run refreshPicker() with no arg on background
	-- pushes; without remembering the source they'd fall through to the
	-- (maybe-empty) catalog branch and blank the grid mid-pick. This keeps it.
	local pickerSource: string = "inventory"

	-- what happens when a picker tile is clicked, by (compose, source)
	local function onPicked(itemId: string, source: string)
		-- a quick-chat phrase waiting on an item ("I want your ...") claims the
		-- pick instead of it going into the offer
		if TradeScreen._consumeSlotPick(itemId) then
			picker.Visible = false
			return
		end
		if compose then
			local offer = source == "inventory" and compose.give or compose.want
			if WildcardConfig.isWildcard(itemId) then
				offer.items[itemId] = 1 -- one token of a kind says it all
			else
				offer.items[itemId] = (offer.items[itemId] or 0) + 1
			end
			picker.Visible = false
			renderCompose()
		else
			TradeController.addItem(itemId)
			picker.Visible = false
		end
	end

	local function clearPicker()
		for itemId, tile in pickerTiles do
			tile:Destroy()
			pickerTiles[itemId] = nil
		end
	end

	-- SearchBox filters by name (FindFirst: tolerate an unrebuilt GUI)
	local pickerSearch = picker:FindFirstChild("SearchBox") :: TextBox?

	-- source "inventory": your items with available counts (give side / live trades)
	-- source "catalog": every registered item (compose WANT side), with the
	-- trade-ad tokens pinned ahead of the alphabetical items
	local function refreshPicker(source: string?)
		source = source or pickerSource
		clearPicker()
		local stats = EconomyController.stats:get()
		local query = pickerSearch and pickerSearch.Text:lower() or ""

		local entries: { { itemId: string, name: string?, imageId: string?, count: number?, wildcard: boolean? } } = {}
		if source == "inventory" then
			local inventory = InventoryController.inventory:get()
			local offered = compose and compose.give.items
				or (function()
					local view = TradeController.trade:get()
					return view and view.you.offer.items or {}
				end)()
			for itemId, count in inventory do
				local available = count - (offered[itemId] or 0)
				if available > 0 then
					local snap = stats[itemId]
					table.insert(entries, {
						itemId = itemId,
						name = snap and snap.name or nil,
						imageId = snap and snap.imageId or nil,
						count = available,
					})
				end
			end
		elseif catalogCache then
			for _, entry in catalogCache do
				table.insert(entries, { itemId = entry.itemId, name = entry.name, imageId = entry.imageId })
			end
		end
		table.sort(entries, function(a, b)
			return (a.name or a.itemId) < (b.name or b.itemId)
		end)

		-- compose want side: "no specific item in mind" tokens come first
		if compose and source == "catalog" then
			for i, token in WildcardConfig.Tokens do
				table.insert(entries, i, {
					itemId = token.id,
					name = token.label,
					imageId = token.imageId,
					wildcard = true,
				})
			end
		end

		local order = 0
		for _, entry in entries do
			local itemId = entry.itemId
			if query == "" or (entry.name or itemId):lower():find(query, 1, true) then
				order += 1
				local tile = pickerTemplate:Clone()
				tile.Name = itemId
				tile.Visible = true
				tile.LayoutOrder = order
				tile.Parent = pickerGrid
				pickerTiles[itemId] = tile
				tile.Activated:Connect(function()
					onPicked(itemId, source)
				end)
				tooltip.attach(tile, function()
					if entry.wildcard then
						return WildcardConfig.snapshot(itemId), nil
					end
					return EconomyController.get(itemId), InventoryController.inventory:get()[itemId]
				end)
				local nameLabel = tile:WaitForChild("ItemName") :: TextLabel
				nameLabel.Text = entry.name or itemId
				local countLabel = tile:WaitForChild("CountLabel") :: TextLabel
				countLabel.Text = entry.count and ("x" .. entry.count) or ""
				Components.setIcon(tile:WaitForChild("Icon") :: ImageLabel, entry)
			end
		end
	end

	if pickerSearch then
		pickerSearch:GetPropertyChangedSignal("Text"):Connect(function()
			if picker.Visible then
				refreshPicker()
			end
		end)
	end

	function TradeScreen.openPicker(source: string?)
		source = source or "inventory"
		pickerSource = source
		if pickerSearch and pickerSearch.Text ~= "" then
			pickerSearch.Text = "" -- fresh open, fresh search (fires refresh)
		end
		if source == "catalog" and catalogCache == nil then
			task.spawn(function()
				local result = Net.invoke("GetCatalog")
				if result.ok then
					catalogCache = result.items
					if picker.Visible then
						refreshPicker("catalog")
					end
				end
			end)
		end
		refreshPicker(source)
		picker.Visible = true
	end

	--------------------------------------------------------------------------
	-- Buttons / countdown / render
	--------------------------------------------------------------------------

	acceptBtn.Activated:Connect(function()
		if compose then
			local c = compose
			compose = nil
			panel.Visible = false
			chatPanel.Visible = false
			picker.Visible = false
			if autoToggle then
				autoToggle.Visible = false
			end
			c.onPost(c.give, c.want, c.autoTrade)
			return
		end
		local view = TradeController.trade:get()
		if view then
			TradeController.setConfirm(not view.you.confirmed)
		end
	end)
	cancelBtn.Activated:Connect(function()
		if compose then
			compose = nil
			panel.Visible = false
			chatPanel.Visible = false
			picker.Visible = false
			if autoToggle then
				autoToggle.Visible = false
			end
			return
		end
		TradeController.cancel()
	end)
	-- any trade-ad token on the want side pins the listing to ask-first
	local function composeWantHasToken(): boolean
		if compose == nil then
			return false
		end
		for itemId in compose.want.items do
			if WildcardConfig.isWildcard(itemId) then
				return true
			end
		end
		return false
	end

	if autoToggle then
		autoToggle.Activated:Connect(function()
			if compose and not composeWantHasToken() then
				compose.autoTrade = not compose.autoTrade
				renderCompose()
			end
		end)
	end

	local countdownThread: thread? = nil
	local function stopCountdown()
		if countdownThread then
			task.cancel(countdownThread)
			countdownThread = nil
		end
		countdownBar.Visible = false
	end
	local function startCountdown(confirmedAt: number)
		stopCountdown()
		countdownBar.Visible = true
		countdownThread = task.spawn(function()
			while true do
				local remaining = (confirmedAt + TradeConfig.ConfirmGraceSeconds) - workspace:GetServerTimeNow()
				if remaining <= 0 then
					countdownText.Text = "Locking in — completing trade…"
					break
				end
				countdownText.Text = ("Both ready! Completing in %d… (Cancel to stop)"):format(math.ceil(remaining))
				task.wait(0.2)
			end
		end)
	end

	-- Compose mode render: same panel, both sides local + editable.
	renderCompose = function()
		if compose == nil then
			return
		end
		local stats = EconomyController.stats:get()
		local wanted = {}
		for itemId in compose.give.items do
			table.insert(wanted, itemId)
		end
		for itemId in compose.want.items do
			if not WildcardConfig.isWildcard(itemId) then
				table.insert(wanted, itemId)
			end
		end
		EconomyController.ensure(wanted)

		local hasToken = composeWantHasToken()
		if hasToken then
			compose.autoTrade = false
		end

		Components.closeOtherPanels(panel)
		panel.Visible = true
		chatPanel.Visible = true
		title.Text = "📌 Post a board trade"
		yourSide.header.Text = "You give (escrowed on post)"
		theirSide.header.Text = "You want — click slots to add"
		renderSide(yourSide, compose.give, false, stats)
		renderSide(theirSide, compose.want, false, stats)
		-- want side is editable in compose: show + hints + gems box
		for _, entry in theirSide.slots do
			if entry.itemId == nil then
				entry.plus.Text = "+"
			end
		end
		yourSide.readyPill.Text = ""
		theirSide.readyPill.Text = ""
		if theirSide.wantBox then
			theirSide.wantBox.Visible = true
			theirSide.gemsLabel.Visible = false
			if not theirSide.wantBox:IsFocused() then
				theirSide.wantBox.Text = tostring(compose.want.gems)
			end
		end
		if yourTotal then
			yourTotal.Text = offerTotalText(compose.give, stats)
		end
		if theirTotal then
			theirTotal.Text = offerTotalText(compose.want, stats)
		end
		acceptBtn.Text = "POST TO BOARD"
		acceptBtn.BackgroundColor3 = Theme.Good
		if hasToken then
			statusLabel.Text = "Trade ad: interested traders ping you, and you pick the offer you like."
		elseif compose.autoTrade then
			statusLabel.Text = "Auto-trade: the first taker completes this trade instantly, even while you're offline."
		else
			statusLabel.Text = "Ask-first: you approve each interested trader before anything trades."
		end
		if autoToggle then
			autoToggle.Visible = true
			if hasToken then
				autoToggle.Text = "Ask-first (trade ad)"
				autoToggle.BackgroundColor3 = Theme.BgLight
			else
				autoToggle.Text = compose.autoTrade and "Auto-trade: ON" or "Auto-trade: OFF"
				autoToggle.BackgroundColor3 = compose.autoTrade and Theme.Good or Theme.Warn
			end
		end
	end

	-- Open the trade window in board-compose mode.
	function TradeScreen.openCompose(onPost: (give: any, want: any, autoTrade: boolean) -> ())
		compose = {
			give = { items = {}, gems = 0 },
			want = { items = {}, gems = 0 },
			autoTrade = true,
			onPost = onPost,
		}
		stopCountdown()
		renderCompose()
	end

	local function render(view: any)
		if compose then
			return -- board compose owns the panel right now
		end
		if view == nil then
			panel.Visible = false
			chatPanel.Visible = false
			picker.Visible = false
			stopCountdown()
			tooltip.hide()
			return
		end
		Components.closeOtherPanels(panel)
		panel.Visible = true
		chatPanel.Visible = true
		if theirSide.wantBox then
			theirSide.wantBox.Visible = false
			theirSide.gemsLabel.Visible = true
		end
		if autoToggle then
			autoToggle.Visible = false
		end
		local stats = EconomyController.stats:get()

		local wanted = {}
		for itemId in view.you.offer.items do
			table.insert(wanted, itemId)
		end
		for itemId in view.them.offer.items do
			table.insert(wanted, itemId)
		end
		EconomyController.ensure(wanted)

		title.Text = "Trading with " .. (view.them.name or ("User " .. tostring(view.them.userId)))
		yourSide.header.Text = localPlayer.Name .. " (you)"
		theirSide.header.Text = view.them.name or "Them"

		renderSide(yourSide, view.you.offer, view.you.confirmed, stats)
		renderSide(theirSide, view.them.offer, view.them.confirmed, stats)

		if yourTotal then
			yourTotal.Text = offerTotalText(view.you.offer, stats)
		end
		if theirTotal then
			theirTotal.Text = offerTotalText(view.them.offer, stats)
		end

		if TradeController.pendingConfirm:get() then
			acceptBtn.Text = "…"
			acceptBtn.BackgroundColor3 = Theme.BgLight
		else
			acceptBtn.Text = view.you.confirmed and "UNACCEPT" or "ACCEPT ✔"
			acceptBtn.BackgroundColor3 = view.you.confirmed and Theme.Warn or Theme.Good
		end

		if view.state == "Confirmed" and view.confirmedAt then
			startCountdown(view.confirmedAt)
			statusLabel.Text = ""
		elseif view.state == "Settling" then
			stopCountdown()
			statusLabel.Text = "Exchanging items…"
		else
			stopCountdown()
			if view.you.confirmed and not view.them.confirmed then
				statusLabel.Text = "Waiting for " .. (view.them.name or "partner") .. "…"
			elseif view.them.confirmed and not view.you.confirmed then
				statusLabel.Text = (view.them.name or "Partner") .. " is ready — accept to continue"
			else
				statusLabel.Text = ""
			end
		end

		if picker.Visible then
			refreshPicker()
		end
	end

	State.Observe(TradeController.trade, render)
	State.Observe(TradeController.pendingConfirm, function()
		render(TradeController.trade:get())
	end)
	State.Observe(InventoryController.inventory, function()
		if picker.Visible then
			refreshPicker()
		end
	end)
	State.Observe(EconomyController.stats, function()
		render(TradeController.trade:get())
	end)

	--------------------------------------------------------------------------
	-- Invite popup
	--------------------------------------------------------------------------

	local invite = gui:WaitForChild("InvitePanel") :: Frame
	local inviteText = invite:WaitForChild("Text") :: TextLabel

	local inviteAccept = invite:WaitForChild("AcceptButton") :: TextButton
	inviteAccept.Activated:Connect(function()
		TradeController.respond(true)
	end)
	local inviteDecline = invite:WaitForChild("DeclineButton") :: TextButton
	inviteDecline.Activated:Connect(function()
		TradeController.respond(false)
	end)

	State.Observe(TradeController.invite, function(inv)
		invite.Visible = inv ~= nil
		if inv then
			inviteText.Text = ("%s wants to trade!"):format(inv.fromName or "Someone")
		end
	end)

	--------------------------------------------------------------------------
	-- Partner search
	--------------------------------------------------------------------------

	local search = gui:WaitForChild("SearchPanel") :: Frame
	local searchBox = search:WaitForChild("SearchBox") :: TextBox
	local resultsList = search:WaitForChild("ResultsList") :: ScrollingFrame
	local resultTemplate = resultsList:WaitForChild("ResultTemplate") :: TextButton
	local noticeTemplate = resultsList:WaitForChild("NoticeTemplate") :: TextLabel

	local searchClose = search:WaitForChild("CloseButton") :: TextButton
	searchClose.Activated:Connect(function()
		search.Visible = false
	end)

	local function clearResults()
		for _, child in resultsList:GetChildren() do
			if (child:IsA("TextButton") or child:IsA("TextLabel")) and child.Visible then
				child:Destroy()
			end
		end
	end

	-- avatar headshots are fetched async + cached (thumbnails can yield)
	local avatarCache: { [number]: string } = {}
	local function loadAvatar(userId: number, into: ImageLabel)
		local cached = avatarCache[userId]
		if cached then
			into.Image = cached
			return
		end
		task.spawn(function()
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size48x48
				)
			end)
			if ok and content then
				avatarCache[userId] = content
				if into and into.Parent then
					into.Image = content
				end
			end
		end)
	end

	-- never lists yourself: you can't trade with yourself
	local function addResult(userId: number, displayName: string, username: string, order: number): boolean
		if userId == localPlayer.UserId then
			return false
		end
		local online = Players:GetPlayerByUserId(userId) ~= nil
		local row = resultTemplate:Clone()
		row.Visible = true
		row.Name = "Result_" .. userId
		row.LayoutOrder = order
		;(row:WaitForChild("DisplayName") :: TextLabel).Text = displayName
		;(row:WaitForChild("Username") :: TextLabel).Text = "@" .. username
		;(row:WaitForChild("OnlineTag") :: TextLabel).Text = online and "• in server" or ""
		loadAvatar(userId, row:WaitForChild("Avatar") :: ImageLabel)
		;(row :: TextButton).Activated:Connect(function()
			search.Visible = false
			TradeController.requestTrade(userId)
		end)
		row.Parent = resultsList
		return true
	end

	local function showNotice(text: string)
		local notice = noticeTemplate:Clone()
		notice.Visible = true
		notice.Name = "Notice"
		notice.Text = text
		notice.Parent = resultsList
	end

	local searchSeq = 0
	local function runSearch()
		local query = searchBox.Text
		searchSeq += 1
		local seq = searchSeq
		clearResults()
		if query:gsub("%s", "") == "" then
			local added = 0
			for _, player in Players:GetPlayers() do
				if addResult(player.UserId, player.DisplayName, player.Name, added + 1) then
					added += 1
				end
			end
			if added == 0 then
				showNotice("Nobody else in this server — search a name or UserId")
			end
			return
		end
		task.spawn(function()
			local result = Net.invoke("SearchPlayers", query)
			if seq ~= searchSeq or not search.Visible then
				return
			end
			clearResults()
			if not result.ok then
				showNotice("Search failed: " .. tostring(result.err))
				return
			end
			local added = 0
			for _, entry in result.results do
				local username = entry.name or ("User " .. entry.userId)
				if addResult(entry.userId, entry.displayName or username, username, added + 1) then
					added += 1
				end
			end
			if added == 0 then
				showNotice("No matches")
			end
		end)
	end

	local searchDebounce: thread? = nil
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		if searchDebounce then
			task.cancel(searchDebounce)
		end
		searchDebounce = task.delay(0.35, function()
			searchDebounce = nil
			runSearch()
		end)
	end)

	function TradeScreen.togglePicker()
		search.Visible = not search.Visible
		if search.Visible then
			searchBox.Text = ""
			runSearch()
		end
	end
end

return TradeScreen
