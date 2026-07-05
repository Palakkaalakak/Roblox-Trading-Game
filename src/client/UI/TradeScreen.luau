--!strict
-- TradeScreen: PS99-style trade window.
--   * two 3x3 icon-slot offer grids side by side (you / them)
--   * gems chip per side (yours opens an inline amount editor)
--   * bottom sheet = your inventory as icon tiles, click to add
--   * click your offer slot to remove; hover any slot/tile for full stats
--   * big ACCEPT toggle per player with green state dots
--   * both accepted -> server-enforced countdown (cancel still allowed),
--     then the trade locks and settles
-- Pure render-from-view: TradeController.trade is the only state source.
-- Includes the invite popup and the player-search picker.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local TradeConfig = require(ReplicatedStorage.Shared.Config.TradeConfig)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local TradeController = require(script.Parent.Parent.Controllers.TradeController)
local Net = require(script.Parent.Parent.Net)

local create = Components.create
local localPlayer = Players.LocalPlayer

local TradeScreen = {}

local GRID = 3 -- 3x3 slots
local SLOT = 92
local SLOT_PAD = 8

--------------------------------------------------------------------------------
-- One offer side (grid of icon slots + gems chip + accept dot)
--------------------------------------------------------------------------------

local function buildSide(parent: Instance, mine: boolean, tooltip: any)
	local width = GRID * SLOT + (GRID - 1) * SLOT_PAD + 24
	local panel = Components.panel({
		Position = mine and UDim2.fromOffset(14, 64) or UDim2.new(1, -(width + 14), 0, 64),
		Size = UDim2.fromOffset(width, GRID * SLOT + (GRID - 1) * SLOT_PAD + 96),
		BackgroundColor3 = Theme.Bg,
	})
	panel.Parent = parent

	local header = Components.label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -60, 0, 20),
		Text = mine and "You" or "Them",
		TextSize = 15,
	})
	header.Parent = panel

	local acceptPill = Components.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(96, 20),
		Text = "not ready",
		TextSize = 11,
		Font = Theme.FontLight,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.TextDim,
	})
	acceptPill.Parent = panel

	local grid = create("Frame", {
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.fromOffset(GRID * SLOT + (GRID - 1) * SLOT_PAD, GRID * SLOT + (GRID - 1) * SLOT_PAD),
		BackgroundTransparency = 1,
	})
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(SLOT, SLOT),
		CellPadding = UDim2.fromOffset(SLOT_PAD, SLOT_PAD),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = grid
	grid.Parent = panel

	local slots = {}
	for i = 1, GRID * GRID do
		local slot = create(mine and "TextButton" or "Frame", {
			BackgroundColor3 = Theme.BgLight,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Text = mine and "" or nil,
			AutoButtonColor = mine and true or nil,
		})
		Components.corner(Theme.CornerSmall).Parent = slot
		local slotStroke = Components.stroke(Theme.Stroke, 1)
		slotStroke.Parent = slot

		local plus = Components.label({
			Size = UDim2.new(1, 0, 1, 0),
			Text = mine and "+" or "",
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Stroke,
		})
		plus.Parent = slot

		local icon = Components.itemIcon(slot, UDim2.new(1, -22, 1, -22), UDim2.fromOffset(11, 11))
		icon.Visible = false
		icon.ZIndex = 2

		local countBadge = Components.label({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -5, 1, -3),
			Size = UDim2.fromOffset(36, 14),
			Text = "",
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Theme.Warn,
			ZIndex = 3,
		})
		countBadge.Parent = slot

		slot.Parent = grid
		local entry = {
			frame = slot,
			icon = icon,
			plus = plus,
			count = countBadge,
			stroke = slotStroke,
			itemId = nil :: string?,
			itemCount = 0,
		}
		slots[i] = entry

		if mine then
			(slot :: any).Activated:Connect(function()
				if entry.itemId then
					TradeController.removeItem(entry.itemId)
				end
			end)
		end

		tooltip.attach(slot, function()
			local snap = entry.itemId and EconomyController.get(entry.itemId) or nil
			return snap, entry.itemCount
		end)
	end

	-- gems chip
	local gemsChip = create(mine and "TextButton" or "Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.new(1, -24, 0, 40),
		BackgroundColor3 = Theme.BgLight,
		BorderSizePixel = 0,
		Text = mine and "" or nil,
		AutoButtonColor = mine and true or nil,
	})
	Components.corner(Theme.CornerSmall).Parent = gemsChip
	gemsChip.Parent = panel

	local gemIcon = create("ImageLabel", {
		Image = Theme.Icons.Gem,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(8, 8),
		ScaleType = Enum.ScaleType.Fit,
	})
	gemIcon.Parent = gemsChip

	local gemsLabel = Components.label({
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -48, 1, 0),
		Text = "0",
		TextSize = 16,
		TextColor3 = Theme.Gem,
	})
	gemsLabel.Parent = gemsChip

	local editHint = mine and Components.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(80, 40),
		Text = "edit ✎",
		TextSize = 11,
		Font = Theme.FontLight,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.TextDim,
	}) or nil
	if editHint then
		editHint.Parent = gemsChip
	end

	-- inline gem editor (yours only), swapped in over the chip
	local gemEditor
	if mine then
		gemEditor = create("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 12, 1, -10),
			Size = UDim2.new(1, -24, 0, 40),
			BackgroundColor3 = Theme.Bg,
			BorderSizePixel = 0,
			Visible = false,
		})
		Components.corner(Theme.CornerSmall).Parent = gemEditor
		Components.stroke(Theme.Accent, 1.5).Parent = gemEditor
		gemEditor.Parent = panel

		local box = create("TextBox", {
			Position = UDim2.fromOffset(8, 7),
			Size = UDim2.new(1, -100, 0, 26),
			BackgroundColor3 = Theme.BgLight,
			BorderSizePixel = 0,
			Font = Theme.Font,
			TextColor3 = Theme.TextPrimary,
			TextSize = 14,
			Text = "0",
			PlaceholderText = "gem amount",
			ClearTextOnFocus = false,
		})
		Components.corner(Theme.CornerSmall).Parent = box
		box.Parent = gemEditor

		local okBtn = Components.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -46, 0, 7),
			Size = UDim2.fromOffset(38, 26),
			Text = "OK",
			TextSize = 12,
			BackgroundColor3 = Theme.Good,
		}, function()
			local n = tonumber(box.Text)
			if n then
				TradeController.setGems(math.max(0, math.floor(n)))
			end
			gemEditor.Visible = false
			gemsChip.Visible = true
		end)
		okBtn.Parent = gemEditor

		local cancelEditBtn = Components.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 7),
			Size = UDim2.fromOffset(34, 26),
			Text = "✕",
			TextSize = 12,
			BackgroundColor3 = Theme.BgLight,
		}, function()
			gemEditor.Visible = false
			gemsChip.Visible = true
		end)
		cancelEditBtn.Parent = gemEditor;

		(gemsChip :: any).Activated:Connect(function()
			local view = TradeController.trade:get()
			box.Text = view and tostring(view.you.offer.gems) or "0"
			gemsChip.Visible = false
			gemEditor.Visible = true
			box:CaptureFocus()
		end)
	end

	return {
		panel = panel,
		header = header,
		acceptPill = acceptPill,
		slots = slots,
		gemsLabel = gemsLabel,
		gemsChip = gemsChip,
		gemEditor = gemEditor,
		mine = mine,
	}
end

local function renderSide(side: any, offer: any, confirmed: boolean, stats: { [string]: any })
	local sortedIds = {}
	for itemId in offer.items do
		table.insert(sortedIds, itemId)
	end
	table.sort(sortedIds)

	for i, entry in side.slots do
		local itemId = sortedIds[i]
		if itemId then
			local snap = stats[itemId]
			entry.itemId = itemId
			entry.itemCount = offer.items[itemId]
			entry.plus.Text = ""
			entry.icon.Visible = true
			Components.setIcon(entry.icon, snap)
			entry.count.Text = offer.items[itemId] > 1 and ("x" .. offer.items[itemId]) or ""
			entry.stroke.Color = snap and (Theme.Rarity[snap.rarity] or Theme.Stroke) or Theme.Stroke
			entry.stroke.Thickness = 1.5
		else
			entry.itemId = nil
			entry.itemCount = 0
			entry.plus.Text = side.mine and "+" or ""
			entry.icon.Visible = false
			entry.count.Text = ""
			entry.stroke.Color = Theme.Stroke
			entry.stroke.Thickness = 1
		end
	end

	side.gemsLabel.Text = tostring(offer.gems)
	side.acceptPill.Text = confirmed and "READY ✔" or "not ready"
	side.acceptPill.TextColor3 = confirmed and Theme.Good or Theme.TextDim
end

--------------------------------------------------------------------------------
-- Screen
--------------------------------------------------------------------------------

function TradeScreen.build(gui: ScreenGui)
	local tooltip = Components.makeTooltip(gui)

	local sideWidth = GRID * SLOT + (GRID - 1) * SLOT_PAD + 24
	local panelWidth = sideWidth * 2 + 42
	local panel = Components.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(panelWidth, 640),
		Visible = false,
	})
	panel.Parent = gui

	local title = Components.label({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 24),
		Text = "Trading",
		TextSize = 18,
	})
	title.Parent = panel

	local hint = Components.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 14),
		Size = UDim2.fromOffset(320, 16),
		Text = "changing an offer resets both READYs",
		Font = Theme.FontLight,
		TextSize = 11,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	hint.Parent = panel

	local yourSide = buildSide(panel, true, tooltip)
	local theirSide = buildSide(panel, false, tooltip)

	-- bottom sheet: your inventory as icon tiles
	local sheetY = 64 + GRID * SLOT + (GRID - 1) * SLOT_PAD + 96 + 8
	local sheet = Components.panel({
		Position = UDim2.fromOffset(14, sheetY),
		Size = UDim2.new(1, -28, 0, 128),
		BackgroundColor3 = Theme.Bg,
	})
	sheet.Parent = panel

	local sheetTitle = Components.label({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.fromOffset(200, 16),
		Text = "Your items — click to offer",
		TextSize = 11,
		Font = Theme.FontLight,
		TextColor3 = Theme.TextDim,
	})
	sheetTitle.Parent = sheet

	local sheetScroll = create("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 22),
		Size = UDim2.new(1, -16, 1, -30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.Name,
	}).Parent = sheetScroll
	sheetScroll.Parent = sheet

	local sheetTiles: { [string]: any } = {}

	local function refreshSheet()
		local inventory = InventoryController.inventory:get()
		local stats = EconomyController.stats:get()
		local view = TradeController.trade:get()
		local offered = view and view.you.offer.items or {}

		for itemId, tile in sheetTiles do
			if inventory[itemId] == nil then
				tile.frame:Destroy()
				sheetTiles[itemId] = nil
			end
		end
		for itemId, count in inventory do
			local tile = sheetTiles[itemId]
			if tile == nil then
				local frame = create("TextButton", {
					Size = UDim2.fromOffset(74, 88),
					BackgroundColor3 = Theme.BgLight,
					BorderSizePixel = 0,
					Text = "",
					AutoButtonColor = true,
					Name = itemId,
				})
				Components.corner(Theme.CornerSmall).Parent = frame
				local stroke = Components.stroke(Theme.Stroke, 1)
				stroke.Parent = frame

				local icon = Components.itemIcon(frame, UDim2.fromOffset(44, 44), UDim2.new(0.5, -22, 0, 6))
				local nameLabel = Components.label({
					Position = UDim2.fromOffset(4, 52),
					Size = UDim2.new(1, -8, 0, 22),
					Text = itemId,
					TextSize = 10,
					Font = Theme.FontLight,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextWrapped = true,
				})
				nameLabel.Parent = frame

				local countLabel = Components.label({
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -4, 0, 2),
					Size = UDim2.fromOffset(30, 12),
					Text = "",
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Right,
					TextColor3 = Theme.Warn,
					ZIndex = 3,
				})
				countLabel.Parent = frame

				frame.Activated:Connect(function()
					TradeController.addItem(itemId)
				end)
				tooltip.attach(frame, function()
					return EconomyController.get(itemId), InventoryController.inventory:get()[itemId]
				end)

				frame.Parent = sheetScroll
				tile = { frame = frame, icon = icon, name = nameLabel, count = countLabel, stroke = stroke }
				sheetTiles[itemId] = tile
			end
			local snap = stats[itemId]
			local remaining = count - (offered[itemId] or 0)
			tile.name.Text = snap and snap.name or itemId
			tile.count.Text = "x" .. remaining
			tile.frame.BackgroundTransparency = remaining <= 0 and 0.6 or 0
			Components.setIcon(tile.icon, snap)
			tile.stroke.Color = snap and (Theme.Rarity[snap.rarity] or Theme.Stroke) or Theme.Stroke
		end
	end

	-- bottom bar: accept / cancel / status
	local acceptBtn = Components.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -12),
		Size = UDim2.fromOffset(190, 42),
		Text = "ACCEPT ✔",
		TextSize = 16,
		BackgroundColor3 = Theme.Good,
	}, function()
		local view = TradeController.trade:get()
		if view then
			TradeController.setConfirm(not view.you.confirmed)
		end
	end)
	acceptBtn.Parent = panel

	local cancelBtn = Components.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -12),
		Size = UDim2.fromOffset(120, 42),
		Text = "Cancel",
		TextSize = 14,
		BackgroundColor3 = Theme.Bad,
	}, function()
		TradeController.cancel()
	end)
	cancelBtn.Parent = panel

	local statusLabel = Components.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(380, 20),
		Text = "",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Warn,
	})
	statusLabel.Parent = panel

	-- countdown overlay (server grace window after both accept)
	local countdownBar = Components.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 36),
		Size = UDim2.fromOffset(360, 26),
		BackgroundColor3 = Theme.Bg,
		Visible = false,
	})
	countdownBar.Parent = panel
	local countdownLabel = Components.label({
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Text = "",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Warn,
	})
	countdownLabel.Parent = countdownBar

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
					countdownLabel.Text = "Locking in — completing trade…"
					break
				end
				countdownLabel.Text = ("Both ready! Completing in %d… (Cancel to stop)"):format(math.ceil(remaining))
				task.wait(0.2)
			end
		end)
	end

	-- render from view
	local function render(view: any)
		if view == nil then
			panel.Visible = false
			stopCountdown()
			tooltip.hide()
			return
		end
		panel.Visible = true
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

		acceptBtn.Text = view.you.confirmed and "UNACCEPT" or "ACCEPT ✔"
		acceptBtn.BackgroundColor3 = view.you.confirmed and Theme.Warn or Theme.Good

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

		refreshSheet()
	end

	State.Observe(TradeController.trade, render)
	State.Observe(InventoryController.inventory, function()
		if panel.Visible then
			refreshSheet()
		end
	end)
	State.Observe(EconomyController.stats, function()
		render(TradeController.trade:get())
	end)

	--------------------------------------------------------------------------------
	-- Invite prompt
	--------------------------------------------------------------------------------

	local invitePanel = Components.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.fromOffset(340, 88),
		Visible = false,
	})
	invitePanel.Parent = gui

	local inviteText = Components.label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 20),
		Text = "",
		TextSize = 14,
	})
	inviteText.Parent = invitePanel

	local acceptInviteBtn = Components.button({
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.fromOffset(150, 32),
		Text = "Accept",
		BackgroundColor3 = Theme.Good,
	}, function()
		TradeController.respond(true)
	end)
	acceptInviteBtn.Parent = invitePanel

	local declineBtn = Components.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 42),
		Size = UDim2.fromOffset(150, 32),
		Text = "Decline",
		BackgroundColor3 = Theme.Bad,
	}, function()
		TradeController.respond(false)
	end)
	declineBtn.Parent = invitePanel

	State.Observe(TradeController.invite, function(invite)
		invitePanel.Visible = invite ~= nil
		if invite then
			inviteText.Text = ("🔁 %s wants to trade!"):format(invite.fromName or "Someone")
		end
	end)

	--------------------------------------------------------------------------------
	-- Partner picker (search anyone who has ever joined)
	--------------------------------------------------------------------------------

	local picker = Components.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(320, 360),
		Visible = false,
	})
	picker.Parent = gui

	local pickerTitle = Components.label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -50, 0, 22),
		Text = "Trade with…",
		TextSize = 16,
	})
	pickerTitle.Parent = picker

	local pickerClose = Components.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(26, 26),
		Text = "✕",
		BackgroundColor3 = Theme.Bad,
	}, function()
		picker.Visible = false
	end)
	pickerClose.Parent = picker

	local searchBox = create("TextBox", {
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 30),
		BackgroundColor3 = Theme.BgLight,
		BorderSizePixel = 0,
		Font = Theme.FontLight,
		TextColor3 = Theme.TextPrimary,
		TextSize = 13,
		PlaceholderText = "Search by username or UserId…",
		Text = "",
		ClearTextOnFocus = false,
	})
	Components.corner(Theme.CornerSmall).Parent = searchBox
	searchBox.Parent = picker

	local listScroll = create("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 78),
		Size = UDim2.new(1, -24, 1, -90),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	})
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = listScroll
	listScroll.Parent = picker

	local function clearResults()
		for _, child in listScroll:GetChildren() do
			if child:IsA("TextButton") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	-- never list the local player: you can't trade yourself
	local function addResult(userId: number, name: string, order: number): boolean
		if userId == localPlayer.UserId then
			return false
		end
		local online = Players:GetPlayerByUserId(userId) ~= nil
		local btn = Components.button({
			Size = UDim2.new(1, 0, 0, 32),
			Text = ("%s  (%d)%s"):format(name, userId, online and "  •in server" or ""),
			TextSize = 12,
			BackgroundColor3 = Theme.BgLight,
			LayoutOrder = order,
		}, function()
			picker.Visible = false
			TradeController.requestTrade(userId)
		end)
		btn.Parent = listScroll
		return true
	end

	local function showNotice(text: string)
		local notice = Components.label({
			Size = UDim2.new(1, 0, 0, 24),
			Text = text,
			TextSize = 12,
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		notice.Parent = listScroll
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
				if addResult(player.UserId, player.Name, added + 1) then
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
			if seq ~= searchSeq or not picker.Visible then
				return
			end
			clearResults()
			if not result.ok then
				showNotice("Search failed: " .. tostring(result.err))
				return
			end
			local added = 0
			for _, entry in result.results do
				if addResult(entry.userId, entry.name or ("User " .. entry.userId), added + 1) then
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
		picker.Visible = not picker.Visible
		if picker.Visible then
			searchBox.Text = ""
			runSearch()
		end
	end

	return panel
end

return TradeScreen
