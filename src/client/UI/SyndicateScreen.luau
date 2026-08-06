--!strict
-- Syndicate screen: your clan, the public directory, and pending invites.
--
-- Three views the tabs swap between. Which tabs exist depends on membership —
-- someone in no syndicate sees Create/Browse/Invites, a member sees their
-- syndicate instead of the create form. The server decides everything that
-- matters (permissions, capacity, cost); this only renders what it returns and
-- re-fetches after every action, so the UI can never drift from the truth.

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Net = require(script.Parent.Parent.Net)
local Format = require(game:GetService("ReplicatedStorage").Shared.Util.Format)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local SyndicateConfig = require(game:GetService("ReplicatedStorage").Shared.Config.SyndicateConfig)

local SyndicateScreen = {}

-- server error code -> something a player can act on
local ERRORS = {
	already_in_syndicate = "You're already in a group.",
	not_in_syndicate = "You're not in a group.",
	insufficient_gems = "You don't have enough gems.",
	name_too_short = "That name is too short.",
	tag_too_short = "That tag is too short.",
	bad_name = "That name isn't allowed.",
	bad_tag = "That tag isn't allowed.",
	tag_not_alphanumeric = "Tags can only use letters and numbers.",
	syndicate_full = "That group is full.",
	invite_only = "That group is invite-only.",
	request_required = "That group only takes invited members.",
	owner_must_transfer = "Promote someone else before you leave.",
	no_permission = "You don't have permission to do that.",
	target_outranks_you = "You can't do that to someone ranked above you.",
	cannot_target_self = "You can't do that to yourself.",
	player_not_here = "That player isn't in this server.",
	loading = "Still loading — try again in a moment.",
	too_many_requests = "You already have two open requests. Wait for one to fill.",
	count_too_high = "That's more than you can ask for at once.",
	unknown_item = "No item by that name.",
	own_request = "You can't fill your own request.",
	request_gone = "That request is already filled or expired.",
	insufficient_items = "You don't have that many to give.",
}

local function explain(err: string?): string
	return (err and ERRORS[err]) or ("Something went wrong" .. (err and (" (" .. err .. ")") or "") .. ".")
end

function SyndicateScreen.wire(gui: ScreenGui, toast: (text: string, color: Color3) -> ())
	local panel = gui:WaitForChild("SyndicatePanel") :: Frame
	local body = panel:WaitForChild("Body") :: Frame
	local createView = body:WaitForChild("CreateView") :: Frame
	local mineView = body:WaitForChild("MineView") :: Frame
	local browseView = body:WaitForChild("BrowseView") :: Frame
	local invitesView = body:WaitForChild("InvitesView") :: Frame
	local requestsView = body:WaitForChild("RequestsView") :: Frame

	;(panel:WaitForChild("CloseButton") :: TextButton).Activated:Connect(function()
		panel.Visible = false
	end)

	local tabRow = panel:WaitForChild("TabRow") :: Frame
	local spawned: { Instance } = {}
	local activeTab = "mine"
	local latest: any = nil
	local busy = false
	local refresh -- fwd decl

	local function clearSpawned()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
	end

	-- one shared call wrapper: block re-entry, surface the error, re-fetch
	-- Most syndicate remotes already return the updated syndicate, so re-fetching
	-- it afterwards was a second round-trip for data we were holding — that
	-- doubled the wait on every button. When the result carries one we render it
	-- straight away and only re-fetch in the background, off the click path.
	local function act(fn: () -> any, successText: string?)
		if busy then
			return
		end
		busy = true
		local wasTab = activeTab
		task.spawn(function()
			local result = fn()
			busy = false
			if result and result.ok then
				if successText then
					toast(successText, Theme.Good)
				end
			else
				toast(explain(result and result.err), Theme.Bad)
			end

			if result and result.ok and result.syndicate ~= nil then
				-- paint from what the server just told us
				latest = latest or {}
				latest.syndicate = result.syndicate
				if wasTab == activeTab then
					SyndicateScreen._render(latest)
				end
				task.spawn(refresh) -- reconcile invites/etc. without blocking
			else
				refresh()
			end
		end)
	end

	----------------------------------------------------------------------
	-- Tabs
	----------------------------------------------------------------------
	local tabButtons: { [string]: TextButton } = {}
	local function buildTabs()
		for _, c in tabRow:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		table.clear(tabButtons)
		local inSyn = latest and latest.syndicate ~= nil
		local specs = {
			{ id = "mine", text = inSyn and "My Group" or "Create" },
		}
		if inSyn then
			-- the count is the hook: an open request is a job waiting for you
			local syn = latest.syndicate :: any
			local open = #(syn.requests or {})
			table.insert(specs, { id = "requests", text = open > 0 and ("Requests (%d)"):format(open) or "Requests" })
			local readyGoals = 0
			for _, g in (syn.goals or {}) do
				if g.done then
					readyGoals += 1
				end
			end
			table.insert(specs, { id = "goals", text = ("Goals (%d/%d)"):format(readyGoals, #(syn.goals or {})) })
			if syn.yourRole == "Owner" then
				table.insert(specs, { id = "settings", text = "Settings" })
			end
		end
		for _, extra in {
			{ id = "browse", text = "Browse" },
			{ id = "invites", text = ("Invites (%d)"):format(latest and #(latest.invites or {}) or 0) },
		} do
			table.insert(specs, extra)
		end
		for i, spec in specs do
			local b = Instance.new("TextButton")
			b.Name = "Tab_" .. spec.id
			b.LayoutOrder = i
			-- share the row instead of assuming a width: at four tabs a fixed
			-- 160 overflowed the panel by 22px
			b.Size = UDim2.new(1 / #specs, -(6 * (#specs - 1)) / #specs, 0, 30)
			b.BackgroundColor3 = (activeTab == spec.id) and Theme.Accent or Theme.BgLight
			b.Font = Theme.Font
			b.TextSize = 13
			b.TextColor3 = Theme.TextPrimary
			b.Text = spec.text
			b.Parent = tabRow
			local corner = Instance.new("UICorner")
			corner.CornerRadius = Theme.CornerSmall
			corner.Parent = b
			b.Activated:Connect(function()
				activeTab = spec.id
				if latest then
					SyndicateScreen._render(latest)
				end
			end)
			tabButtons[spec.id] = b
		end
	end

	----------------------------------------------------------------------
	-- Create
	----------------------------------------------------------------------
	local nameBox = createView:WaitForChild("NameBox") :: TextBox
	local tagBox = createView:WaitForChild("TagBox") :: TextBox
	local createBtn = createView:WaitForChild("CreateButton") :: TextButton
	-- "Tag" means nothing on its own, so the helper line says what it is for
	;(createView:WaitForChild("CostLabel") :: TextLabel).Text =
		("The tag is a %d–%d letter short name shown next to your members' names, like [IRON].  ·  Costs %s gems — you'll be the Owner.")
			:format(SyndicateConfig.TagMinLength, SyndicateConfig.TagMaxLength, Format.comma(SyndicateConfig.CreateCostGems))
	createBtn.Activated:Connect(function()
		local name, tag = nameBox.Text, tagBox.Text
		act(function()
			return Net.invoke("CreateSyndicate", name, tag)
		end, "Group created!")
	end)

	----------------------------------------------------------------------
	-- Mine
	----------------------------------------------------------------------
	local banner = mineView:WaitForChild("Banner") :: Frame
	local memberList = mineView:WaitForChild("MemberList") :: ScrollingFrame
	local memberTemplate = memberList:WaitForChild("MemberRow") :: Frame
	local actionRow = mineView:WaitForChild("ActionRow") :: Frame
	local policyBtn = actionRow:WaitForChild("PolicyButton") :: TextButton
	local leaveBtn = actionRow:WaitForChild("LeaveButton") :: TextButton

	leaveBtn.Activated:Connect(function()
		local s = latest and latest.syndicate
		local lastOneHere = s ~= nil and #s.members <= 1
		act(function()
			return Net.invoke("LeaveSyndicate")
		end, lastOneHere and "Group disbanded." or "You left the group.")
	end)
	policyBtn.Activated:Connect(function()
		local s = latest and latest.syndicate
		if s == nil then
			return
		end
		-- cycle through the policies rather than adding a dropdown
		local policies = SyndicateConfig.JoinPolicies
		local index = 1
		for i, p in policies do
			if p == s.policy then
				index = i
			end
		end
		local nextPolicy = policies[(index % #policies) + 1]
		act(function()
			return Net.invoke("SetSyndicatePolicy", nextPolicy)
		end, "Now: " .. (SyndicateConfig.JoinPolicyLabels[nextPolicy] or nextPolicy) .. ".")
	end)

	local function renderMine(s: any)
		(banner:WaitForChild("SynName") :: TextLabel).Text = ("[%s] %s"):format(s.tag, s.name)
		local nextText = s.nextLevel and ("%s XP to level %d"):format(Format.abbrev(s.xpToNext or 0), s.nextLevel)
			or "Max level"
		;(banner:WaitForChild("SynMeta") :: TextLabel).Text =
			("Level %d  ·  %d/%d members  ·  %s XP  ·  %s"):format(
				s.level, #s.members, s.memberCap, Format.abbrev(s.xp), nextText)

		-- XP bar spans only the CURRENT level's band, so it reads as progress
		-- toward the next level rather than progress through all of history
		local track = banner:WaitForChild("XpTrack") :: Frame
		local fill = track:WaitForChild("XpFill") :: Frame
		local curve = SyndicateConfig.LevelCurve
		local base = curve[s.level] or 0
		local target = curve[s.level + 1]
		local frac = 1
		if target then
			frac = math.clamp((s.xp - base) / math.max(target - base, 1), 0, 1)
		end
		fill.Size = UDim2.fromScale(frac, 1)

		local perkParts = {}
		if s.perks.boardSlots > 0 then
			table.insert(perkParts, ("+%d board slots"):format(s.perks.boardSlots))
		end
		if s.perks.marketFeeCut > 0 then
			table.insert(perkParts, ("-%d%% market fee"):format(math.floor(s.perks.marketFeeCut * 100 + 0.5)))
		end
		if s.perks.rollLuck > 0 then
			table.insert(perkParts, ("+%d%% roll luck"):format(math.floor(s.perks.rollLuck * 100 + 0.5)))
		end
		;(mineView:WaitForChild("PerksLabel") :: TextLabel).Text = #perkParts > 0
				and ("Perks: " .. table.concat(perkParts, "  ·  "))
			or "Perks: none yet — level up to unlock"

		-- the last member out takes the syndicate with them, so this must not
		-- quietly read "Leave" when it actually means "delete this"
		local lastOneHere = #s.members <= 1
		leaveBtn.Text = lastOneHere and "Leave & Delete" or "Leave"
		leaveBtn.Size = UDim2.fromOffset(lastOneHere and 150 or 110, 30)

		-- Sitting between "Recruit Friends" and "Leave & Delete", a bare
		-- "Ask to join" reads like an action you press to join something. It's a
		-- setting, so it has to say which setting it is.
		policyBtn.Text = SyndicateConfig.JoinPolicyLabels[s.policy] or tostring(s.policy)
		policyBtn.Visible = SyndicateConfig.can(s.yourRole or "Member", "setPolicy")

		local myId = Players.LocalPlayer.UserId
		for i, member in s.members do
			local row = memberTemplate:Clone()
			row.Name = "member_" .. member.userId
			row.LayoutOrder = i
			row.Visible = true
			;(row:WaitForChild("MemberName") :: TextLabel).Text = member.name
				.. (member.userId == myId and "  (you)" or "")
			;(row:WaitForChild("MemberRole") :: TextLabel).Text = member.role
			-- donations sit next to XP because generosity IS the standing here:
			-- a member who gives is worth more to the clan than one who idles
			;(row:WaitForChild("MemberXp") :: TextLabel).Text = member.donated > 0
					and ("%s XP  ·  %s given"):format(Format.abbrev(member.xpContributed), Format.abbrev(member.donated))
				or (Format.abbrev(member.xpContributed) .. " XP")

			-- moderation buttons appear only where the server would allow the
			-- action anyway, so the UI never offers something that will fail
			local mods = row:WaitForChild("ModButtons") :: Frame
			local canModerate = member.userId ~= myId
				and SyndicateConfig.outranks(s.yourRole or "Member", member.role)
			local function wireMod(btnName: string, action: string, permission: string, label: string)
				local btn = mods:WaitForChild(btnName) :: TextButton
				btn.Visible = canModerate and SyndicateConfig.can(s.yourRole or "Member", permission)
				if btn.Visible then
					btn.Activated:Connect(function()
						act(function()
							return Net.invoke("SyndicateModerate", member.userId, action)
						end, label)
					end)
				end
			end
			-- "Promote to" opens the ladder rather than nudging one rank at a
			-- time: with four roles, a single button hides where someone can go.
			local promoteBtn = mods:WaitForChild("PromoteButton") :: TextButton
			local assignable = SyndicateConfig.assignableRoles(s.yourRole or "Member")
			local canPromote = canModerate
				and SyndicateConfig.can(s.yourRole or "Member", "promote", s.permissions)
				and #assignable > 0
			promoteBtn.Visible = canPromote
			if canPromote then
				promoteBtn.Text = "Promote to"
				promoteBtn.Activated:Connect(function()
					-- a tiny inline menu; rebuilt each press so it always shows
					-- the ranks this actor may actually assign right now
					local existing = row:FindFirstChild("RankMenu")
					if existing then
						existing:Destroy()
						return
					end
					local menu = Instance.new("Frame")
					menu.Name = "RankMenu"
					menu.BackgroundColor3 = Theme.BgLight
					menu.BorderSizePixel = 0
					menu.Position = UDim2.new(1, -200, 0, 30)
					menu.Size = UDim2.fromOffset(130, #assignable * 26 + 8)
					menu.ZIndex = 30
					menu.Parent = row
					local mc = Instance.new("UICorner")
					mc.CornerRadius = Theme.CornerSmall
					mc.Parent = menu
					local ml = Instance.new("UIListLayout")
					ml.Padding = UDim.new(0, 2)
					ml.SortOrder = Enum.SortOrder.LayoutOrder
					ml.Parent = menu
					local pad = Instance.new("UIPadding")
					pad.PaddingTop = UDim.new(0, 4)
					pad.PaddingLeft = UDim.new(0, 4)
					pad.PaddingRight = UDim.new(0, 4)
					pad.Parent = menu
					for ri, roleName in assignable do
						local opt = Instance.new("TextButton")
						opt.LayoutOrder = ri
						opt.Size = UDim2.new(1, 0, 0, 24)
						opt.Font = Theme.Font
						opt.TextSize = 12
						opt.Text = SyndicateConfig.RoleLabels[roleName] or roleName
						opt.BackgroundColor3 = (roleName == member.role) and Theme.Accent or Theme.Bg
						opt.TextColor3 = Theme.TextPrimary
						opt.ZIndex = 31
						opt.Parent = menu
						local oc = Instance.new("UICorner")
						oc.CornerRadius = Theme.CornerSmall
						oc.Parent = opt
						opt.Activated:Connect(function()
							menu:Destroy()
							if roleName == member.role then
								return
							end
							act(function()
								return Net.invoke("SyndicateSetRole", member.userId, roleName)
							end, ("%s is now %s."):format(member.name, SyndicateConfig.RoleLabels[roleName] or roleName))
						end)
					end
				end)
			end
			wireMod("DemoteButton", "demote", "demote", member.name .. " demoted.")
			wireMod("KickButton", "kick", "kick", member.name .. " removed.")
			-- demote only makes sense for someone who isn't already the bottom rank
			local roles = SyndicateConfig.Roles
			;(mods:WaitForChild("DemoteButton") :: TextButton).Visible =
				(mods:WaitForChild("DemoteButton") :: TextButton).Visible
				and member.role ~= roles[#roles]

			row.Parent = memberList
			table.insert(spawned, row)
		end
	end

	----------------------------------------------------------------------
	-- Recruit — the growth loop
	--
	-- Opens Roblox's own invite prompt carrying "who invited me AND which
	-- syndicate", so a friend who accepts arrives with the invite already
	-- pending instead of having to find the clan themselves. Same launch data
	-- the free-gems referral uses, so a recruit still counts as a referral.
	----------------------------------------------------------------------
	local recruitBtn = actionRow:WaitForChild("RecruitButton") :: TextButton

	-- CanSendGameInviteAsync is a blocking web call. Asking it on click made the
	-- Recruit button hang for seconds before anything happened, so it's resolved
	-- once in the background and the click just reads the answer.
	local canInvite: boolean? = nil
	task.spawn(function()
		local ok, result = pcall(function()
			return SocialService:CanSendGameInviteAsync(Players.LocalPlayer)
		end)
		canInvite = ok and result or false
	end)

	recruitBtn.Activated:Connect(function()
		local s = latest and latest.syndicate
		if s == nil then
			return
		end
		local player = Players.LocalPlayer
		if canInvite == false then
			toast("Invites aren't available on this device.", Theme.Bad)
			return
		end
		local ok = pcall(function()
			local options = Instance.new("ExperienceInviteOptions")
			options.PromptMessage = ("Join [%s] %s with me!"):format(s.tag, s.name)
			options.LaunchData = ("ref_%d~syn_%s"):format(player.UserId, s.id)
			SocialService:PromptGameInvite(player, options)
		end)
		if not ok then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		end
	end)

	----------------------------------------------------------------------
	-- Requests
	----------------------------------------------------------------------
	local composer = requestsView:WaitForChild("Composer") :: Frame
	local chooseBtn = composer:WaitForChild("ChooseItemButton") :: TextButton
	local countBox = composer:WaitForChild("CountBox") :: TextBox
	local askBtn = composer:WaitForChild("AskButton") :: TextButton

	local catalog: { any }? = nil
	local chosenId: string? = nil

	-- THE SAME item picker the trade screen uses -- a searchable grid of item
	-- cards -- rather than a second, different way to name an item. Cloned from
	-- the trade panel so there is one widget to maintain and picking an item
	-- looks identical wherever a player does it.
	local pickerSource = gui:WaitForChild("TradePanel"):WaitForChild("ItemPicker") :: Frame
	local picker = pickerSource:Clone()
	picker.Name = "RequestItemPicker"
	picker.Visible = false
	picker.Parent = panel
	local pickerSearch = picker:WaitForChild("SearchBox") :: TextBox
	local pickerGrid = picker:WaitForChild("PickerGrid") :: ScrollingFrame
	local tileTemplate = pickerGrid:WaitForChild("PickerTile") :: ImageButton
	;(picker:WaitForChild("Title") :: TextLabel).Text = "What do you need?"
	;(picker:WaitForChild("CloseButton") :: TextButton).Activated:Connect(function()
		picker.Visible = false
	end)

	local tiles: { Instance } = {}
	local function fillPicker(query: string)
		for _, t in tiles do
			t:Destroy()
		end
		table.clear(tiles)
		local q = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
		local order = 0
		for _, item in (catalog or {}) do
			local name = tostring(item.name)
			if q == "" or name:lower():find(q, 1, true) then
				order += 1
				local tile = tileTemplate:Clone()
				tile.Name = "pick_" .. item.itemId
				tile.LayoutOrder = order
				tile.Visible = true
				;(tile:WaitForChild("Icon") :: ImageLabel).Image = item.imageId or ""
				;(tile:WaitForChild("ItemName") :: TextLabel).Text = name
				-- the count badge is a trade-screen concept (how many you hold);
				-- a request is about what you DON'T have, so it has no place here
				local badge = tile:FindFirstChild("CountLabel")
				if badge then
					badge.Visible = false
				end
				-- an item card ALWAYS shows its stats on hover, wherever it
				-- appears -- picker, request row, anywhere
				tooltip.attach(tile, function()
					return EconomyController.get(item.itemId),
						(InventoryController.inventory:get() or {})[item.itemId]
				end)
				tile.Activated:Connect(function()
					chosenId = item.itemId
					chooseBtn.Text = name
					picker.Visible = false
				end)
				tile.Parent = pickerGrid
				table.insert(tiles, tile)
			end
		end
	end

	pickerSearch:GetPropertyChangedSignal("Text"):Connect(function()
		fillPicker(pickerSearch.Text)
	end)

	local function openPicker()
		pickerSearch.Text = ""
		fillPicker("")
		picker.Visible = true
		-- pull stats for what is on screen so the hover card has real
		-- numbers rather than "N/A" the first time you look at an item
		local ids = {}
		for _, item in (catalog or {}) do
			table.insert(ids, item.itemId)
		end
		EconomyController.ensure(ids)
	end
	chooseBtn.Activated:Connect(openPicker)

	askBtn.Activated:Connect(function()
		local itemId = chosenId
		if itemId == nil then
			toast("Pick an item first.", Theme.Bad)
			openPicker()
			return
		end
		local count = tonumber(countBox.Text)
		if count == nil or count < 1 then
			toast("Enter how many you need.", Theme.Bad)
			return
		end
		act(function()
			return Net.invoke("PostSyndicateRequest", itemId, math.floor(count))
		end, "Your group has been asked.")
		chooseBtn.Text, countBox.Text, chosenId = "Choose item...", "", nil
	end)

	local function renderRequests(s: any)
		local list = requestsView:WaitForChild("List") :: ScrollingFrame
		local template = list:WaitForChild("RequestRow") :: Frame
		local empty = requestsView:WaitForChild("EmptyLabel") :: TextLabel
		local requests = s.requests or {}
		empty.Text = "No one needs anything right now."
			.. "\n\nAsk for what you're short of — a group member can send it straight"
			.. " from their inventory, and they earn group XP for doing it."
		empty.Visible = #requests == 0

		local myId = Players.LocalPlayer.UserId
		local byId: { [number]: string } = {}
		for _, m in s.members do
			byId[m.userId] = m.name
		end

		for i, req in requests do
			local row = template:Clone()
			row.Name = "req_" .. tostring(req.reqId)
			row.LayoutOrder = i
			row.Visible = true
			local mine = req.userId == myId
			local given = req.count - req.remaining

			;(row:WaitForChild("ReqWho") :: TextLabel).Text = mine and "Your request"
				or ((byId[req.userId] or "A member") .. " needs this")
			local itemName, itemImage = req.itemId, ""
			for _, item in (catalog or {}) do
				if item.itemId == req.itemId then
					itemName, itemImage = item.name, item.imageId or ""
					break
				end
			end
			local art = row:WaitForChild("ArtHolder") :: Frame
			;(art:WaitForChild("ReqIcon") :: ImageLabel).Image = itemImage
			tooltip.attach(art, function()
				return EconomyController.get(req.itemId),
					(InventoryController.inventory:get() or {})[req.itemId]
			end)
			;(row:WaitForChild("ReqWhat") :: TextLabel).Text =
				("%s× %s  ·  %s of %s sent"):format(
					Format.abbrev(req.remaining), itemName, Format.abbrev(given), Format.abbrev(req.count))

			local track = row:WaitForChild("ReqTrack") :: Frame
			;(track:WaitForChild("ReqFill") :: Frame).Size =
				UDim2.fromScale(math.clamp(given / math.max(req.count, 1), 0, 1), 1)

			-- you can't fill your own ask, so that row shows progress only
			-- Offer only what the player can actually cover, so the button never
			-- promises a donation the server will refuse. Falls back to the full
			-- remainder when the inventory hasn't arrived yet.
			local held = (InventoryController.inventory:get() or {})[req.itemId] or 0
			local offer = math.min(held, req.remaining)
			local btn = row:WaitForChild("GiveButton") :: TextButton
			btn.Visible = not mine
			if btn.Visible then
				if offer > 0 then
					btn.Text = ("GIVE %s"):format(Format.abbrev(offer))
					btn.BackgroundColor3 = Theme.Good
					btn.AutoButtonColor = true
					btn.Activated:Connect(function()
						act(function()
							return Net.invoke("FillSyndicateRequest", req.reqId, offer)
						end, "Sent — your group owes you one.")
					end)
				else
					btn.Text = "NONE TO GIVE"
					btn.BackgroundColor3 = Theme.BgLight
					btn.AutoButtonColor = false
				end
			end

			row.Parent = list
			table.insert(spawned, row)
		end
	end

	----------------------------------------------------------------------
	-- Goals + Settings
	--
	-- Both are built here rather than in GuiBuilder: they are plain lists of
	-- rows over data the server already returns, so a runtime build keeps the
	-- shared builder (and every other panel that reads from it) untouched.
	----------------------------------------------------------------------
	local function makeListView(name: string): ScrollingFrame
		local view = Instance.new("ScrollingFrame")
		view.Name = name
		view.BackgroundTransparency = 1
		view.BorderSizePixel = 0
		view.Size = UDim2.fromScale(1, 1)
		view.ScrollBarThickness = 6
		view.AutomaticCanvasSize = Enum.AutomaticSize.Y
		view.CanvasSize = UDim2.new()
		view.Visible = false
		view.Parent = body
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = view
		return view
	end
	local goalsView = makeListView("GoalsView")
	local settingsView = makeListView("SettingsView")

	local function makeRow(parent: Instance, order: number, height: number): Frame
		local row = Instance.new("Frame")
		row.Name = "Row" .. order
		row.LayoutOrder = order
		row.BackgroundColor3 = Theme.Bg
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, -8, 0, height)
		row.Parent = parent
		local c = Instance.new("UICorner")
		c.CornerRadius = Theme.CornerSmall
		c.Parent = row
		local st = Instance.new("UIStroke")
		st.Color = Theme.Stroke
		st.Thickness = 1
		st.Parent = row
		table.insert(spawned, row)
		return row
	end

	local function makeLabel(parent: Instance, text: string, pos: UDim2, size: UDim2,
		textSize: number, colour: Color3, bold: boolean?): TextLabel
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Position = pos
		lbl.Size = size
		lbl.Font = bold and Theme.Font or Enum.Font.Gotham
		lbl.Text = text
		lbl.TextSize = textSize
		lbl.TextColor3 = colour
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextYAlignment = Enum.TextYAlignment.Center
		lbl.Parent = parent
		return lbl
	end

	local function renderGoals(s: any)
		for i, goal in (s.goals or {}) do
			local row = makeRow(goalsView, i, 58)
			makeLabel(row, goal.name, UDim2.fromOffset(12, 6), UDim2.new(0.6, 0, 0, 18), 14,
				goal.done and Theme.Good or Theme.TextPrimary, true)
			makeLabel(row, goal.blurb, UDim2.fromOffset(12, 24), UDim2.new(0.62, 0, 0, 15), 11, Theme.TextDim)

			-- progress bar: the whole point is seeing the group inch toward it
			local track = Instance.new("Frame")
			track.BackgroundColor3 = Theme.BgLight
			track.BorderSizePixel = 0
			track.Position = UDim2.fromOffset(12, 42)
			track.Size = UDim2.new(0.62, 0, 0, 8)
			track.Parent = row
			local tc = Instance.new("UICorner")
			tc.CornerRadius = UDim.new(0, 4)
			tc.Parent = track
			local fill = Instance.new("Frame")
			fill.BackgroundColor3 = goal.done and Theme.Good or Theme.Accent
			fill.BorderSizePixel = 0
			fill.Size = UDim2.fromScale(math.clamp(goal.have / math.max(goal.target, 1), 0, 1), 1)
			fill.Parent = track
			local fc = Instance.new("UICorner")
			fc.CornerRadius = UDim.new(0, 4)
			fc.Parent = fill

			local right = makeLabel(row,
				goal.done and "COMPLETE" or ("%s / %s"):format(Format.abbrev(goal.have), Format.abbrev(goal.target)),
				UDim2.new(1, -190, 0, 8), UDim2.fromOffset(120, 18), 13,
				goal.done and Theme.Good or Theme.TextPrimary, true)
			right.TextXAlignment = Enum.TextXAlignment.Right
			local reward = makeLabel(row, ("+%s group XP"):format(Format.abbrev(goal.xp)),
				UDim2.new(1, -190, 0, 28), UDim2.fromOffset(120, 16), 11, Theme.Gem)
			reward.TextXAlignment = Enum.TextXAlignment.Right
		end
		if #(s.goals or {}) == 0 then
			local row = makeRow(goalsView, 1, 44)
			makeLabel(row, "No goals available.", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 13, Theme.TextDim)
		end
	end

	local function renderSettings(s: any)
		local order = 0
		for _, role in SyndicateConfig.ConfigurableRoles do
			order += 1
			local header = makeRow(settingsView, order, 30)
			header.BackgroundTransparency = 1
			makeLabel(header, (SyndicateConfig.RoleLabels[role] or role):upper() .. " CAN:",
				UDim2.fromOffset(4, 0), UDim2.new(1, -8, 1, 0), 12, Theme.Gold, true)

			for _, perm in SyndicateConfig.EditablePermissions do
				order += 1
				local row = makeRow(settingsView, order, 34)
				makeLabel(row, perm.label, UDim2.fromOffset(12, 0), UDim2.new(1, -140, 1, 0), 13, Theme.TextPrimary)

				local allowed = SyndicateConfig.can(role, perm.key, s.permissions)
				local toggle = Instance.new("TextButton")
				toggle.AnchorPoint = Vector2.new(1, 0.5)
				toggle.Position = UDim2.new(1, -10, 0.5, 0)
				toggle.Size = UDim2.fromOffset(96, 24)
				toggle.Font = Theme.Font
				toggle.TextSize = 12
				toggle.Text = allowed and "ALLOWED" or "BLOCKED"
				toggle.BackgroundColor3 = allowed and Theme.Good or Theme.BgLight
				toggle.TextColor3 = allowed and Theme.Bg or Theme.TextDim
				toggle.Parent = row
				local tc = Instance.new("UICorner")
				tc.CornerRadius = Theme.CornerSmall
				tc.Parent = toggle
				toggle.Activated:Connect(function()
					act(function()
						return Net.invoke("SyndicateSetPermission", role, perm.key, not allowed)
					end, nil)
				end)
			end
		end
	end

	----------------------------------------------------------------------
	-- Browse / Invites
	----------------------------------------------------------------------
	local function renderList(view: Frame, rowName: string, entries: { any }, emptyText: string, build: (Frame, any) -> ())
		local list = view:WaitForChild("List") :: ScrollingFrame
		local template = list:WaitForChild(rowName) :: Frame
		local empty = view:WaitForChild("EmptyLabel") :: TextLabel
		empty.Text = emptyText
		empty.Visible = #entries == 0
		for i, entry in entries do
			local row = template:Clone()
			row.Name = rowName .. "_" .. i
			row.LayoutOrder = i
			row.Visible = true
			build(row, entry)
			row.Parent = list
			table.insert(spawned, row)
		end
	end

	----------------------------------------------------------------------
	-- Render
	----------------------------------------------------------------------
	function SyndicateScreen._render(payload: any)
		latest = payload
		clearSpawned()
		buildTabs()

		local s = payload.syndicate
		local inSyndicate = s ~= nil
		createView.Visible = activeTab == "mine" and not inSyndicate
		mineView.Visible = activeTab == "mine" and inSyndicate
		browseView.Visible = activeTab == "browse"
		invitesView.Visible = activeTab == "invites"
		requestsView.Visible = activeTab == "requests" and inSyndicate
		goalsView.Visible = activeTab == "goals" and inSyndicate
		settingsView.Visible = activeTab == "settings" and inSyndicate

		if mineView.Visible then
			renderMine(s)
		elseif requestsView.Visible then
			renderRequests(s)
		elseif goalsView.Visible then
			renderGoals(s)
		elseif settingsView.Visible then
			renderSettings(s)
		elseif browseView.Visible then
			task.spawn(function()
				local dir = Net.invoke("BrowseSyndicates")
				if not (dir and dir.ok) or not browseView.Visible then
					return
				end
				renderList(browseView, "BrowseRow", dir.syndicates, "No groups yet — make the first one!", function(row, entry)
					(row:WaitForChild("SynName") :: TextLabel).Text = ("[%s] %s"):format(entry.tag, entry.name)
					;(row:WaitForChild("SynMeta") :: TextLabel).Text = ("Level %d"):format(entry.level or 1)

					local function column(name: string, value: number)
						local col = row:WaitForChild(name) :: Frame
						col.Visible = true
						;(col:WaitForChild("Value") :: TextLabel).Text = Format.abbrev(value)
					end
					column("StatA", entry.members or 0)
					column("StatB", entry.trades or 0)
					column("StatC", entry.crafts or 0)

					-- Invite-only groups are never listed, so the only cases here
					-- are "walk in" and "apply". A member of a group already can't
					-- join another, so they see the setting instead of a button
					-- that would only be refused.
					local btn = row:WaitForChild("ActionButton") :: TextButton
					local policyText = row:WaitForChild("PolicyText") :: TextLabel
					btn.Visible = not inSyndicate
					policyText.Visible = inSyndicate
					if inSyndicate then
						policyText.Text = SyndicateConfig.JoinPolicyLabels[entry.policy] or ""
					else
						local asks = entry.policy == "Request"
						btn.Text = asks and "ASK TO JOIN" or "JOIN"
						btn.BackgroundColor3 = asks and Theme.Accent or Theme.Good
						btn.AutoButtonColor = true
						btn.Activated:Connect(function()
							act(function()
								return Net.invoke("JoinSyndicate", entry.id)
							end, asks and ("Asked to join " .. entry.name .. ".")
								or ("Joined " .. entry.name .. "!"))
						end)
					end
				end)
			end)
		elseif invitesView.Visible then
			renderList(invitesView, "InviteRow", payload.invites or {}, "No pending invites.", function(row, entry)
				(row:WaitForChild("SynName") :: TextLabel).Text = ("[%s] %s"):format(entry.tag, entry.name)
				;(row:WaitForChild("SynMeta") :: TextLabel).Text = "invited you"
				-- same row template as Browse; an invite has no stats to compare
				for _, name in { "StatA", "StatB", "StatC" } do
					local col = row:FindFirstChild(name)
					if col then
						col.Visible = false
					end
				end
				local btn = row:WaitForChild("ActionButton") :: TextButton
				btn.Visible = not inSyndicate
				btn.Activated:Connect(function()
					act(function()
						return Net.invoke("JoinSyndicate", entry.id)
					end, "Joined " .. entry.name .. "!")
				end)
			end)
		end
	end

	refresh = function()
		task.spawn(function()
			local result = Net.invoke("GetSyndicate")
			if result and result.ok and panel.Visible then
				SyndicateScreen._render(result)
			end
		end)
	end

	-- GIVE amounts are derived from what the player is holding, so a trade or a
	-- roll landing while the board is open would otherwise leave stale numbers on
	-- buttons that then fail server-side.
	InventoryController.inventory.Changed:Connect(function()
		if panel.Visible and activeTab == "requests" and latest and latest.syndicate then
			SyndicateScreen._render(latest)
		end
	end)

	-- Keep the open panel live. Group state changes from OTHER people --
	-- someone joins, a request gets filled, XP ticks up -- so a screen that
	-- only updated when you switched tabs was showing stale data most of
	-- the time. Cheap: GetSyndicate is a cached read (~50ms).
	task.spawn(function()
		while true do
			task.wait(6)
			if panel.Visible and not busy then
				refresh()
			end
		end
	end)

	function SyndicateScreen.open()
		if catalog == nil then
			task.spawn(function()
				local result = Net.invoke("GetCatalog")
				if result and result.ok then
					catalog = result.items
				end
			end)
		end
		Components.closeOtherPanels(panel)
		panel.Visible = true
		refresh()
	end

	function SyndicateScreen.toggle()
		if panel.Visible then
			panel.Visible = false
		else
			SyndicateScreen.open()
		end
	end
end

return SyndicateScreen
