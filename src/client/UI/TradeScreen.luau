--!strict
-- TradeScreen: two-panel trade UI (yours vs theirs) modeled on Roblox native /
-- Pet-Sim trading. Item slots, gem field, per-side confirm lights, cancel.
-- Includes the invite prompt and the trade-partner picker.
-- Pure render-from-view: every frame of state comes from TradeController.trade.

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

--------------------------------------------------------------------------------
-- One offer panel (a side)
--------------------------------------------------------------------------------

local SLOTS = TradeConfig.MaxSlotsPerSide -- 8 -> 4x2 grid

local function buildSidePanel(parent: Instance, xOffset: number, mine: boolean)
	local panel = Components.panel({
		Position = UDim2.new(0, xOffset, 0, 40),
		Size = UDim2.new(0.5, -18, 1, -150),
		BackgroundColor3 = Theme.Bg,
	})
	panel.Parent = parent

	local header = Components.label({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -40, 0, 20),
		Text = mine and "You" or "Them",
		TextSize = 15,
	})
	header.Parent = panel

	local confirmDot = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Theme.TextDim,
		BorderSizePixel = 0,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0) }).Parent = confirmDot
	confirmDot.Parent = panel

	local grid = create("Frame", {
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.new(1, -20, 1, -104),
		BackgroundTransparency = 1,
	})
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(118, 64),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = grid
	grid.Parent = panel

	local slots = {}
	for i = 1, SLOTS do
		local slot = create(mine and "TextButton" or "Frame", {
			BackgroundColor3 = Theme.BgLight,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Text = mine and "" or nil,
			AutoButtonColor = mine and true or nil,
		})
		Components.corner(Theme.CornerSmall).Parent = slot
		Components.stroke(Theme.Stroke, 1).Parent = slot

		local nameLabel = Components.label({
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.new(1, -12, 0, 15),
			Text = "",
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		nameLabel.Parent = slot

		local metaLabel = Components.label({
			Position = UDim2.fromOffset(6, 21),
			Size = UDim2.new(1, -12, 0, 13),
			Text = "",
			Font = Theme.FontLight,
			TextSize = 11,
			TextColor3 = Theme.TextDim,
		})
		metaLabel.Parent = slot

		local statLabel = Components.label({
			Position = UDim2.fromOffset(6, 36),
			Size = UDim2.new(1, -12, 0, 24),
			Text = "",
			Font = Theme.FontLight,
			TextSize = 10,
			TextColor3 = Theme.TextDim,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		statLabel.Parent = slot

		slot.Parent = grid
		slots[i] = { frame = slot, name = nameLabel, meta = metaLabel, stat = statLabel, itemId = nil :: string? }

		if mine then
			(slot :: any).Activated:Connect(function()
				local itemId = slots[i].itemId
				if itemId then
					TradeController.removeItem(itemId)
				end
			end)
		end
	end

	-- gems row
	local gemsRow = Components.panel({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(1, -20, 0, 50),
		BackgroundColor3 = Theme.BgLight,
	})
	gemsRow.Parent = panel

	local gemsTitle = Components.label({
		Position = UDim2.fromOffset(8, 2),
		Size = UDim2.new(1, -16, 0, 16),
		Text = "💎 Gems",
		TextSize = 12,
		TextColor3 = Theme.Gem,
	})
	gemsTitle.Parent = gemsRow

	local gemsValue: TextLabel | TextBox
	if mine then
		gemsValue = create("TextBox", {
			Position = UDim2.fromOffset(8, 20),
			Size = UDim2.new(1, -70, 0, 24),
			BackgroundColor3 = Theme.Bg,
			BorderSizePixel = 0,
			Font = Theme.Font,
			TextColor3 = Theme.TextPrimary,
			TextSize = 14,
			Text = "0",
			ClearTextOnFocus = false,
		})
		Components.corner(Theme.CornerSmall).Parent = gemsValue
		local setBtn = Components.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 20),
			Size = UDim2.fromOffset(52, 24),
			Text = "Set",
			TextSize = 12,
		}, function()
			local n = tonumber((gemsValue :: TextBox).Text)
			if n then
				TradeController.setGems(n)
			end
		end)
		setBtn.Parent = gemsRow
	else
		gemsValue = Components.label({
			Position = UDim2.fromOffset(8, 20),
			Size = UDim2.new(1, -16, 0, 24),
			Text = "0",
			TextSize = 15,
		})
	end
	gemsValue.Parent = gemsRow

	return {
		panel = panel,
		header = header,
		confirmDot = confirmDot,
		slots = slots,
		gemsValue = gemsValue,
		mine = mine,
	}
end

local function renderSide(side: any, offer: any, confirmed: boolean, stats: { [string]: any })
	-- slots
	local i = 1
	local sortedIds = {}
	for itemId in offer.items do
		table.insert(sortedIds, itemId)
	end
	table.sort(sortedIds)
	for _, itemId in sortedIds do
		if i > SLOTS then
			break
		end
		local count = offer.items[itemId]
		local slot = side.slots[i]
		local snap = stats[itemId]
		slot.itemId = itemId
		slot.name.Text = (snap and snap.name or itemId) .. (count > 1 and (" x" .. count) or "")
		slot.name.TextColor3 = snap and (Theme.Rarity[snap.rarity] or Theme.TextPrimary) or Theme.TextPrimary
		slot.meta.Text = snap and (snap.rarity .. " · " .. Components.statText(snap.supply) .. " in existence") or ""
		slot.stat.Text = snap
				and ("Value: %s · Demand: %s · RAP: %s"):format(
					Components.statText(snap.value),
					Components.statText(snap.demand),
					Components.statText(snap.rap)
				)
			or ""
		i += 1
	end
	for j = i, SLOTS do
		local slot = side.slots[j]
		slot.itemId = nil
		slot.name.Text = ""
		slot.meta.Text = ""
		slot.stat.Text = ""
	end

	-- gems
	if side.mine then
		if not (side.gemsValue :: TextBox):IsFocused() then
			(side.gemsValue :: TextBox).Text = tostring(offer.gems)
		end
	else
		(side.gemsValue :: TextLabel).Text = tostring(offer.gems)
	end

	-- confirm light
	side.confirmDot.BackgroundColor3 = confirmed and Theme.Good or Theme.TextDim
end

--------------------------------------------------------------------------------
-- Screen
--------------------------------------------------------------------------------

function TradeScreen.build(gui: ScreenGui)
	local panel = Components.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(860, 560),
		Visible = false,
	})
	panel.Parent = gui

	local title = Components.label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 24),
		Text = "🔁 Trade",
		TextSize = 18,
	})
	title.Parent = panel

	local hint = Components.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.fromOffset(360, 16),
		Text = "Any offer change resets both confirms",
		Font = Theme.FontLight,
		TextSize = 11,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	hint.Parent = panel

	local yourSide = buildSidePanel(panel, 12, true)
	local theirSide = buildSidePanel(panel, 0, false)
	theirSide.panel.Position = UDim2.new(0.5, 6, 0, 40)

	-- pick strip: your inventory, click to add
	local strip = Components.panel({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -52),
		Size = UDim2.new(1, -24, 0, 46),
		BackgroundColor3 = Theme.Bg,
	})
	strip.Parent = panel
	local stripScroll = create("ScrollingFrame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.Name,
	}).Parent = stripScroll
	stripScroll.Parent = strip

	-- bottom buttons
	local confirmBtn = Components.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(150, 34),
		Text = "Confirm ✔",
		BackgroundColor3 = Theme.Good,
	}, function()
		local view = TradeController.trade:get()
		if view then
			TradeController.setConfirm(not view.you.confirmed)
		end
	end)
	confirmBtn.Parent = panel

	local cancelBtn = Components.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.fromOffset(110, 34),
		Text = "Cancel",
		BackgroundColor3 = Theme.Bad,
	}, function()
		TradeController.cancel()
	end)
	cancelBtn.Parent = panel

	local statusLabel = Components.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(380, 22),
		Text = "",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Warn,
	})
	statusLabel.Parent = panel

	-- strip tiles rebuilt from inventory
	local stripTiles: { [string]: TextButton } = {}
	local function refreshStrip()
		local inventory = InventoryController.inventory:get()
		local stats = EconomyController.stats:get()
		for itemId, btn in stripTiles do
			if inventory[itemId] == nil then
				btn:Destroy()
				stripTiles[itemId] = nil
			end
		end
		for itemId, count in inventory do
			local btn = stripTiles[itemId]
			if btn == nil then
				btn = Components.button({
					Size = UDim2.fromOffset(150, 30),
					Text = itemId,
					TextSize = 11,
					BackgroundColor3 = Theme.BgLight,
					Name = itemId,
				}, function()
					TradeController.addItem(itemId)
				end)
				btn.Parent = stripScroll
				stripTiles[itemId] = btn
			end
			local snap = stats[itemId]
			btn.Text = ("%s x%d"):format(snap and snap.name or itemId, count)
			btn.TextColor3 = snap and (Theme.Rarity[snap.rarity] or Theme.TextPrimary) or Theme.TextPrimary
		end
	end

	-- render loop from view
	local function render(view: any)
		if view == nil then
			panel.Visible = false
			return
		end
		panel.Visible = true
		local stats = EconomyController.stats:get()

		-- make sure we have stats for everything on screen
		local wanted = {}
		for itemId in view.you.offer.items do
			table.insert(wanted, itemId)
		end
		for itemId in view.them.offer.items do
			table.insert(wanted, itemId)
		end
		EconomyController.ensure(wanted)

		theirSide.header.Text = view.them.name or ("User " .. tostring(view.them.userId))
		yourSide.header.Text = localPlayer.Name .. " (you)"

		renderSide(yourSide, view.you.offer, view.you.confirmed, stats)
		renderSide(theirSide, view.them.offer, view.them.confirmed, stats)

		confirmBtn.Text = view.you.confirmed and "Unconfirm" or "Confirm ✔"
		confirmBtn.BackgroundColor3 = view.you.confirmed and Theme.Warn or Theme.Good

		if view.state == "Confirmed" or view.state == "Settling" then
			statusLabel.Text = "Both confirmed — settling…"
		elseif view.you.confirmed and not view.them.confirmed then
			statusLabel.Text = "Waiting for " .. (view.them.name or "partner") .. "…"
		elseif view.them.confirmed and not view.you.confirmed then
			statusLabel.Text = (view.them.name or "Partner") .. " confirmed — your move"
		else
			statusLabel.Text = ""
		end

		refreshStrip()
	end

	State.Observe(TradeController.trade, render)
	State.Observe(InventoryController.inventory, function()
		if panel.Visible then
			refreshStrip()
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

	local acceptBtn = Components.button({
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.fromOffset(150, 32),
		Text = "Accept",
		BackgroundColor3 = Theme.Good,
	}, function()
		TradeController.respond(true)
	end)
	acceptBtn.Parent = invitePanel

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
	-- Partner picker
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

	-- search box: username OR userId, matches anyone who has ever joined
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

	-- empty query -> players in this server; otherwise server-side directory search
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
				return -- stale response
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
