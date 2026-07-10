--!strict
-- ProfileScreen: wires the StarterGui-built ProfilePanel (browser + view +
-- self-edit). Layout/styling lives in the instances; this only finds nodes by
-- name and drives them from ProfileController state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = require(ReplicatedStorage.Shared.Util.State)
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)
local ProfileController = require(script.Parent.Parent.Controllers.ProfileController)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local TradeController = require(script.Parent.Parent.Controllers.TradeController)
local ProfileProjection = require(ReplicatedStorage.Shared.Util.ProfileProjection)

-- stable display order for the pinnable stat chips (keys -> labels in Shared)
local CHIP_ORDER = { "portfolioValue", "trades", "gemsEarned", "mythicals", "distinctItems", "gems" }
local CHIP_MAX = 3

local ProfileScreen = {}
local localUserId = Players.LocalPlayer.UserId

-- avatar headshots (async, cached)
local avatarCache: { [number]: string } = {}
local function loadAvatar(userId: number, into: ImageLabel)
	local cached = avatarCache[userId]
	if cached then
		into.Image = cached
		return
	end
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
		if ok and content then
			avatarCache[userId] = content
			if into and into.Parent then
				into.Image = content
			end
		end
	end)
end

function ProfileScreen.wire(gui: ScreenGui, _tooltip: any)
	local panel = gui:WaitForChild("ProfilePanel") :: Frame
	local closeBtn = panel:WaitForChild("CloseButton") :: TextButton

	local browser = panel:WaitForChild("Browser") :: Frame
	local serverTab = browser:WaitForChild("ServerTab") :: TextButton
	local globalTab = browser:WaitForChild("GlobalTab") :: TextButton
	local searchBox = browser:WaitForChild("SearchBox") :: TextBox
	local plist = browser:WaitForChild("PlayerList") :: ScrollingFrame
	local rowTemplate = plist:WaitForChild("RowTemplate") :: TextButton
	local noticeTemplate = plist:WaitForChild("Notice") :: TextLabel

	local viewF = panel:WaitForChild("View") :: Frame
	local backBtn = viewF:WaitForChild("BackButton") :: TextButton
	local vAvatar = viewF:WaitForChild("Avatar") :: ImageLabel
	local vName = viewF:WaitForChild("DisplayName") :: TextLabel
	local vUser = viewF:WaitForChild("Username") :: TextLabel
	local vJoin = viewF:WaitForChild("JoinDate") :: TextLabel
	local tradeBtn = viewF:WaitForChild("TradeButton") :: TextButton
	local editBtn = viewF:WaitForChild("EditButton") :: TextButton
	local showcase = viewF:WaitForChild("Showcase") :: Frame
	local slotTemplate = showcase:WaitForChild("SlotTemplate") :: Frame
	local showcaseEmpty = viewF:WaitForChild("ShowcaseEmpty") :: TextLabel
	local chips = viewF:WaitForChild("Chips") :: Frame
	local chipSlots = { chips:WaitForChild("Chip1"), chips:WaitForChild("Chip2"), chips:WaitForChild("Chip3") }
	local vStatus = viewF:WaitForChild("Status") :: TextLabel

	local edit = viewF:WaitForChild("Edit") :: Frame
	local statusInput = edit:WaitForChild("StatusInput") :: TextBox
	local hideValueToggle = edit:WaitForChild("HideValueToggle") :: TextButton
	local hideShowcaseToggle = edit:WaitForChild("HideShowcaseToggle") :: TextButton
	local pick = edit:WaitForChild("ShowcasePicker") :: ScrollingFrame
	local pickTemplate = pick:WaitForChild("PickTile") :: TextButton
	local chipPick = edit:WaitForChild("ChipPicker") :: Frame
	local chipOptTemplate = chipPick:WaitForChild("ChipOption") :: TextButton
	local saveBtn = edit:WaitForChild("SaveButton") :: TextButton

	--------------------------------------------------------------------------
	-- mode switching
	--------------------------------------------------------------------------
	local function showBrowser()
		browser.Visible = true
		viewF.Visible = false
	end
	local function showView()
		browser.Visible = false
		viewF.Visible = true
		edit.Visible = false
	end

	--------------------------------------------------------------------------
	-- browser: list rows
	--------------------------------------------------------------------------
	local function clearList()
		for _, c in plist:GetChildren() do
			if c ~= rowTemplate and c ~= noticeTemplate and c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end
	local function notice(text: string)
		local n = noticeTemplate:Clone()
		n.Visible = true
		n.Text = text
		n.Parent = plist
	end
	local function addRow(userId: number, displayName: string, username: string, order: number)
		local row = rowTemplate:Clone()
		row.Visible = true
		row.Name = "Row_" .. userId
		row.LayoutOrder = order
		;(row:WaitForChild("DisplayName") :: TextLabel).Text = displayName
		;(row:WaitForChild("Username") :: TextLabel).Text = "@" .. username
		loadAvatar(userId, row:WaitForChild("Avatar") :: ImageLabel)
		;(row :: TextButton).Activated:Connect(function()
			ProfileScreen.openUser(userId)
		end)
		row.Parent = plist
	end

	local function listServer()
		clearList()
		local order = 0
		local me = Players.LocalPlayer
		addRow(me.UserId, me.DisplayName, me.Name, 1) -- you're always first, so editing your own profile is one click
		order = 1
		for _, p in Players:GetPlayers() do
			if p ~= me then
				order += 1
				addRow(p.UserId, p.DisplayName, p.Name, order)
			end
		end
	end

	local searchSeq = 0
	local function runSearch()
		local query = searchBox.Text
		searchSeq += 1
		local seq = searchSeq
		clearList()
		if query:gsub("%s", "") == "" then
			notice("Type a username or UserId")
			return
		end
		task.spawn(function()
			local res = Net.invoke("SearchPlayers", query)
			if seq ~= searchSeq or not panel.Visible then
				return
			end
			clearList()
			if not res.ok then
				notice("Search failed")
				return
			end
			local order = 0
			for _, e in res.results do
				order += 1
				local username = e.name or ("User " .. e.userId)
				addRow(e.userId, e.displayName or username, username, order)
			end
			if order == 0 then
				notice("No matches")
			end
		end)
	end

	local function selectTab(isGlobal: boolean)
		serverTab.BackgroundColor3 = isGlobal and Theme.BgLight or Theme.Accent
		globalTab.BackgroundColor3 = isGlobal and Theme.Accent or Theme.BgLight
		searchBox.Visible = isGlobal
		if isGlobal then
			searchBox.Text = ""
			clearList()
			notice("Type a username or UserId")
		else
			listServer()
		end
	end

	serverTab.Activated:Connect(function()
		selectTab(false)
	end)
	globalTab.Activated:Connect(function()
		selectTab(true)
	end)
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

	--------------------------------------------------------------------------
	-- edit mode (self)
	--------------------------------------------------------------------------
	local editState = { hideValue = false, hideShowcase = false, selected = {} :: { string }, chips = {} :: { string } }

	local function refreshToggleText()
		hideValueToggle.Text = editState.hideValue and "Value: Hidden" or "Value: Shown"
		hideShowcaseToggle.Text = editState.hideShowcase and "Showcase: Hidden" or "Showcase: Shown"
	end
	local function isSelected(itemId: string): number?
		for i, id in editState.selected do
			if id == itemId then
				return i
			end
		end
		return nil
	end
	local function paintTile(tile: TextButton, itemId: string)
		local uistroke = tile:FindFirstChildOfClass("UIStroke")
		if uistroke then
			uistroke.Color = isSelected(itemId) and Theme.Good or Theme.Stroke
			uistroke.Thickness = isSelected(itemId) and 2.5 or 1.5
		end
	end
	local function buildPicker()
		for _, c in pick:GetChildren() do
			if c ~= pickTemplate and c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local inv = InventoryController.inventory:get()
		local ids = {}
		for itemId, count in inv do
			if count >= 1 then
				table.insert(ids, itemId)
			end
		end
		EconomyController.ensure(ids)
		local order = 0
		for _, itemId in ids do
			order += 1
			local snap = EconomyController.get(itemId)
			local tile = pickTemplate:Clone()
			tile.Visible = true
			tile.Name = "Pick_" .. itemId
			tile.LayoutOrder = order
			;(tile:WaitForChild("Icon") :: ImageLabel).Image = (snap and snap.imageId) or ""
			;(tile:WaitForChild("PickName") :: TextLabel).Text = (snap and snap.name) or itemId
			;(tile:WaitForChild("CountBadge") :: TextLabel).Text = "x" .. tostring(inv[itemId])
			paintTile(tile, itemId)
			tile.Activated:Connect(function()
				local idx = isSelected(itemId)
				if idx then
					table.remove(editState.selected, idx)
				elseif #editState.selected < 6 then
					table.insert(editState.selected, itemId)
				end
				paintTile(tile, itemId)
			end)
			tile.Parent = pick
		end
	end

	local function chipSelected(key: string): number?
		for i, k in editState.chips do
			if k == key then
				return i
			end
		end
		return nil
	end
	local function buildChipPicker()
		for _, c in chipPick:GetChildren() do
			if c ~= chipOptTemplate and c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local order = 0
		for _, key in CHIP_ORDER do
			local labelText = ProfileProjection.AllowedChips[key]
			if labelText then
				order += 1
				local opt = chipOptTemplate:Clone()
				opt.Visible = true
				opt.Name = "Opt_" .. key
				opt.LayoutOrder = order
				opt.Text = labelText
				opt.BackgroundColor3 = chipSelected(key) and Theme.Accent or Theme.BgLight
				opt.Activated:Connect(function()
					local idx = chipSelected(key)
					if idx then
						table.remove(editState.chips, idx)
					elseif #editState.chips < CHIP_MAX then
						table.insert(editState.chips, key)
					end
					opt.BackgroundColor3 = chipSelected(key) and Theme.Accent or Theme.BgLight
				end)
				opt.Parent = chipPick
			end
		end
	end

	local function enterEdit(profile: any)
		editState.hideValue = profile and profile.portfolioValue == nil or false
		editState.hideShowcase = profile and profile.showcase == nil or false
		editState.selected = {}
		if profile and profile.showcase then
			for _, item in profile.showcase do
				table.insert(editState.selected, item.itemId)
			end
		end
		editState.chips = {}
		if profile and profile.statChips then
			for _, ch in profile.statChips do
				table.insert(editState.chips, ch.key)
			end
		end
		statusInput.Text = (profile and profile.status) or ""
		refreshToggleText()
		buildChipPicker()
		buildPicker()
		showcase.Visible = false
		chips.Visible = false
		vStatus.Visible = false
		showcaseEmpty.Visible = false
		editBtn.Visible = false
		edit.Visible = true
	end
	local function exitEdit()
		edit.Visible = false
		showcase.Visible = true
		chips.Visible = true
		vStatus.Visible = true
	end

	editBtn.Activated:Connect(function()
		enterEdit(ProfileController.viewed:get())
	end)
	hideValueToggle.Activated:Connect(function()
		editState.hideValue = not editState.hideValue
		refreshToggleText()
	end)
	hideShowcaseToggle.Activated:Connect(function()
		editState.hideShowcase = not editState.hideShowcase
		refreshToggleText()
	end)
	saveBtn.Activated:Connect(function()
		ProfileController.setStatus(statusInput.Text)
		ProfileController.setShowcase(editState.selected)
		ProfileController.setStatChips(editState.chips)
		ProfileController.setPrivacy(editState.hideValue, editState.hideShowcase)
		exitEdit()
	end)

	--------------------------------------------------------------------------
	-- view render
	--------------------------------------------------------------------------
	local function clearClones(parent: Instance, template: Instance)
		for _, c in parent:GetChildren() do
			if c ~= template and c:IsA("GuiObject") and not c:IsA("UILayout") then
				c:Destroy()
			end
		end
	end

	local function render(profile: any)
		local userId = ProfileController.viewingUserId:get()
		local isSelf = userId == localUserId
		loadAvatar(userId, vAvatar)

		if profile == nil then
			vName.Text = "Loading…"
			vUser.Text = ""
			vJoin.Text = ""
			tradeBtn.Visible = false
			editBtn.Visible = false
			return
		end
		if profile == false then
			vName.Text = "Unavailable"
			vUser.Text = "no profile yet"
			vJoin.Text = ""
			tradeBtn.Visible = false
			editBtn.Visible = false
			return
		end

		vName.Text = profile.displayName or profile.name or "Player"
		vUser.Text = "@" .. (profile.name or "")
		vJoin.Text = profile.firstJoin and ("Joined " .. os.date("%b %d, %Y", profile.firstJoin)) or ""

		-- self sees Edit; others see Trade (only when online)
		editBtn.Visible = isSelf and not edit.Visible
		tradeBtn.Visible = (not isSelf) and Players:GetPlayerByUserId(userId) ~= nil

		-- showcase
		clearClones(showcase, slotTemplate)
		if profile.showcase == nil then
			showcaseEmpty.Visible = true
			showcaseEmpty.Text = "Showcase hidden"
			showcase.Visible = false
		elseif #profile.showcase == 0 then
			showcaseEmpty.Visible = true
			showcaseEmpty.Text = "No items showcased"
			showcase.Visible = false
		else
			showcaseEmpty.Visible = false
			showcase.Visible = true
			local order = 0
			for _, item in profile.showcase do
				order += 1
				local slot = slotTemplate:Clone()
				slot.Visible = true
				slot.Name = "Slot_" .. item.itemId
				slot.LayoutOrder = order
				;(slot:WaitForChild("Icon") :: ImageLabel).Image = item.imageId or ""
				;(slot:WaitForChild("ItemName") :: TextLabel).Text = item.name or item.itemId
				local rarityLabel = slot:WaitForChild("Rarity") :: TextLabel
				rarityLabel.Text = item.rarity or ""
				rarityLabel.TextColor3 = (Theme.Rarity and Theme.Rarity[item.rarity]) or Theme.TextDim
				;(slot:WaitForChild("ItemValue") :: TextLabel).Text = item.estValue and (tostring(item.estValue) .. " gems") or ""
				slot.Parent = showcase
			end
		end

		-- stat chips: fixed Chip1/Chip2/Chip3 slots (inverse pyramid), each
		-- shown or hidden — no clone/destroy since the count is capped at 3
		local statChips = profile.statChips or {}
		for i, slotUI in chipSlots do
			local c = statChips[i]
			if c then
				slotUI.Visible = true
				;(slotUI:WaitForChild("Icon") :: ImageLabel).Image = c.icon or ""
				;(slotUI:WaitForChild("ChipValue") :: TextLabel).Text = tostring(c.value)
				;(slotUI:WaitForChild("ChipLabel") :: TextLabel).Text = c.label
			else
				slotUI.Visible = false
			end
		end

		-- status
		vStatus.Text = (profile.status ~= nil and profile.status ~= "") and profile.status or ""
	end

	State.Observe(ProfileController.viewed, render)

	tradeBtn.Activated:Connect(function()
		local userId = ProfileController.viewingUserId:get()
		panel.Visible = false
		TradeController.requestTrade(userId)
	end)
	backBtn.Activated:Connect(function()
		showBrowser()
		selectTab(false)
	end)
	closeBtn.Activated:Connect(function()
		panel.Visible = false
	end)

	--------------------------------------------------------------------------
	-- public entry points
	--------------------------------------------------------------------------
	function ProfileScreen.openUser(userId: number)
		panel.Visible = true
		showView()
		ProfileController.openUser(userId)
	end

	function ProfileScreen.openBrowser()
		panel.Visible = true
		showBrowser()
		selectTab(false)
	end
end

return ProfileScreen
