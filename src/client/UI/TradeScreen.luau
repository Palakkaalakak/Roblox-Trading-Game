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
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local TradeController = require(script.Parent.Parent.Controllers.TradeController)
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
	local title = panel:WaitForChild("Title") :: TextLabel
	local statusLabel = panel:WaitForChild("StatusLabel") :: TextLabel
	local acceptBtn = panel:WaitForChild("AcceptButton") :: TextButton
	local cancelBtn = panel:WaitForChild("CancelButton") :: TextButton
	local countdownBar = panel:WaitForChild("CountdownBar") :: Frame
	local countdownText = countdownBar:WaitForChild("Text") :: TextLabel

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

			if mine then
				(slot :: any).Activated:Connect(function()
					if entry.itemId then
						TradeController.removeItem(entry.itemId)
					else
						TradeScreen.openPicker()
					end
				end)
			end
			tooltip.attach(slot, function()
				return entry.itemId and EconomyController.get(entry.itemId) or nil, 1
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
			local ok = gemsRow:WaitForChild("OkButton") :: TextButton
			api.gemsBox = box
			local function submit()
				local n = tonumber(box.Text)
				if n then
					TradeController.setGems(math.max(0, math.floor(n)))
				end
			end
			ok.Activated:Connect(submit)
			box.FocusLost:Connect(function(enterPressed)
				if enterPressed then
					submit()
				end
			end)
		else
			api.gemsLabel = gemsRow:WaitForChild("Amount") :: TextLabel
		end

		return api
	end

	local yourSide = wireSide("YourSide", true)
	local theirSide = wireSide("TheirSide", false)

	local function renderSide(side: any, offer: any, confirmed: boolean, stats: { [string]: any })
		local copies = offerToCopies(offer)
		for i, entry in side.slots do
			local itemId = copies[i]
			if itemId then
				local snap = stats[itemId]
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
			if not side.gemsBox:IsFocused() then
				side.gemsBox.Text = tostring(offer.gems)
			end
		else
			side.gemsLabel.Text = tostring(offer.gems)
		end

		side.readyPill.Text = confirmed and "READY ✔" or "not ready"
		side.readyPill.TextColor3 = confirmed and Theme.Good or Theme.TextDim
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

	local function refreshPicker()
		local inventory = InventoryController.inventory:get()
		local stats = EconomyController.stats:get()
		local view = TradeController.trade:get()
		local offered = view and view.you.offer.items or {}

		for itemId, tile in pickerTiles do
			if inventory[itemId] == nil then
				tile:Destroy()
				pickerTiles[itemId] = nil
			end
		end
		for itemId, count in inventory do
			local available = count - (offered[itemId] or 0)
			local tile = pickerTiles[itemId]
			if tile == nil then
				tile = pickerTemplate:Clone()
				tile.Name = itemId
				tile.Visible = true
				tile.Parent = pickerGrid
				pickerTiles[itemId] = tile
				tile.Activated:Connect(function()
					TradeController.addItem(itemId)
					picker.Visible = false
				end)
				tooltip.attach(tile, function()
					return EconomyController.get(itemId), InventoryController.inventory:get()[itemId]
				end)
			end
			local snap = stats[itemId]
			local nameLabel = tile:WaitForChild("ItemName") :: TextLabel
			nameLabel.Text = snap and snap.name or itemId
			local countLabel = tile:WaitForChild("CountLabel") :: TextLabel
			countLabel.Text = "x" .. available
			Components.setIcon(tile:WaitForChild("Icon") :: ImageLabel, snap)
			tile.Visible = available > 0
		end
	end

	function TradeScreen.openPicker()
		refreshPicker()
		picker.Visible = true
	end

	--------------------------------------------------------------------------
	-- Buttons / countdown / render
	--------------------------------------------------------------------------

	acceptBtn.Activated:Connect(function()
		local view = TradeController.trade:get()
		if view then
			TradeController.setConfirm(not view.you.confirmed)
		end
	end)
	cancelBtn.Activated:Connect(function()
		TradeController.cancel()
	end)

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

	local function render(view: any)
		if view == nil then
			panel.Visible = false
			picker.Visible = false
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

	-- never lists yourself: you can't trade with yourself
	local function addResult(userId: number, name: string, order: number): boolean
		if userId == localPlayer.UserId then
			return false
		end
		local online = Players:GetPlayerByUserId(userId) ~= nil
		local btn = resultTemplate:Clone()
		btn.Visible = true
		btn.Name = "Result_" .. userId
		btn.LayoutOrder = order
		btn.Text = ("%s  (%d)%s"):format(name, userId, online and "  •in server" or "")
		btn.Activated:Connect(function()
			search.Visible = false
			TradeController.requestTrade(userId)
		end)
		btn.Parent = resultsList
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
		search.Visible = not search.Visible
		if search.Visible then
			searchBox.Text = ""
			runSearch()
		end
	end
end

return TradeScreen
