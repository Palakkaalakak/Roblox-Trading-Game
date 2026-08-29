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
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
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
	role_locked = "The Owner role can't be changed.",
	too_many_roles = "You already have the maximum number of roles.",
	need_two_roles = "A group needs at least one role besides Owner.",
	permission_locked = "That permission is Owner-only.",
	unknown_role = "That role no longer exists.",
	cannot_move = "That role can't move any further.",
	role_not_assignable = "You can't assign that role.",
}

local function explain(err: string?): string
	return (err and ERRORS[err]) or ("Something went wrong" .. (err and (" (" .. err .. ")") or "") .. ".")
end

function SyndicateScreen.wire(gui: ScreenGui, toast: (text: string, color: Color3) -> (), tooltip: any)
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
			{ id = "browse", text = "Browse" },
			{ id = "invites", text = ("Invites (%d)"):format(latest and #(latest.invites or {}) or 0) },
		}
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
	-- My Group sections. Members / Goals / Requests / Settings are all "my
	-- group", so they are sections of one tab rather than four top-level
	-- tabs competing with Browse and Invites.
	----------------------------------------------------------------------
	local mineSection = "members"
	local chatPrimed = false -- flips once history has actually arrived, not on the attempt
	local chatPriming = false
	local subTabRow = Instance.new("Frame")
	subTabRow.Name = "SectionRow"
	subTabRow.BackgroundTransparency = 1
	subTabRow.Size = UDim2.new(1, 0, 0, 26)
	subTabRow.Visible = false
	subTabRow.Parent = body
	local subLayout = Instance.new("UIListLayout")
	subLayout.FillDirection = Enum.FillDirection.Horizontal
	subLayout.Padding = UDim.new(0, 6)
	subLayout.SortOrder = Enum.SortOrder.LayoutOrder
	subLayout.Parent = subTabRow

	local SECTIONS = {
		-- day-to-day first, administration last: Roles then Settings sit at the
		-- end because most members never need either
		{ id = "members", text = "Members" },
		{ id = "goals", text = "Goals" },
		{ id = "requests", text = "Requests" },
		{ id = "chat", text = "Chat" },
		{ id = "roles", text = "Roles" },
		{ id = "settings", text = "Settings" },
	}
	local sectionButtons: { [string]: TextButton } = {}
	for i, spec in SECTIONS do
		local b = Instance.new("TextButton")
		b.Name = "Section_" .. spec.id
		b.LayoutOrder = i
		b.Size = UDim2.new(1 / #SECTIONS, -(6 * (#SECTIONS - 1)) / #SECTIONS, 0, 26)
		b.BackgroundColor3 = Theme.BgLight
		b.Font = Theme.Font
		b.TextSize = 12
		b.TextColor3 = Theme.TextDim
		b.Text = spec.text
		b.Parent = subTabRow
		local c = Instance.new("UICorner")
		c.CornerRadius = Theme.CornerSmall
		c.Parent = b
		b.Activated:Connect(function()
			mineSection = spec.id
			if latest then
				SyndicateScreen._render(latest)
			end
		end)
		sectionButtons[spec.id] = b
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
		-- "Who can join" lives in Settings now, with the other settings
		policyBtn.Visible = false

		local myId = Players.LocalPlayer.UserId
		for i, member in s.members do
			local row = memberTemplate:Clone()
			row.Name = "member_" .. member.userId
			row.LayoutOrder = i
			row.Visible = true
			;(row:WaitForChild("MemberName") :: TextLabel).Text = member.name
				.. (member.userId == myId and "  (you)" or "")
			local roleName = member.role
			for _, r in (s.roles or {}) do
				if r.id == member.role then
					roleName = r.name
				end
			end
			;(row:WaitForChild("MemberRole") :: TextLabel).Text = roleName
			-- donations sit next to XP because generosity IS the standing here:
			-- a member who gives is worth more to the clan than one who idles
			;(row:WaitForChild("MemberXp") :: TextLabel).Text = member.donated > 0
					and ("%s XP  ·  %s given"):format(Format.abbrev(member.xpContributed), Format.abbrev(member.donated))
				or (Format.abbrev(member.xpContributed) .. " XP")

			-- moderation buttons appear only where the server would allow the
			-- action anyway, so the UI never offers something that will fail
			local mods = row:WaitForChild("ModButtons") :: Frame
			local canModerate = member.userId ~= myId
				and SyndicateConfig.outranks(s, s.yourRole or "", member.role)
			local function wireMod(btnName: string, action: string, permission: string, label: string)
				local btn = mods:WaitForChild(btnName) :: TextButton
				btn.Visible = canModerate and SyndicateConfig.can(s, s.yourRole or "", permission)
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
			local assignable = SyndicateConfig.assignableRoles(s, s.yourRole or "")
			local canPromote = canModerate
				and SyndicateConfig.can(s, s.yourRole or "", "promote")
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
					for ri, roleDef in assignable do
						local opt = Instance.new("TextButton")
						opt.LayoutOrder = ri
						opt.Size = UDim2.new(1, 0, 0, 24)
						opt.Font = Theme.Font
						opt.TextSize = 12
						opt.Text = roleDef.name
						opt.BackgroundColor3 = (roleDef.id == member.role) and Theme.Accent or Theme.Bg
						opt.TextColor3 = Theme.TextPrimary
						opt.ZIndex = 31
						opt.Parent = menu
						local oc = Instance.new("UICorner")
						oc.CornerRadius = Theme.CornerSmall
						oc.Parent = opt
						opt.Activated:Connect(function()
							menu:Destroy()
							if roleDef.id == member.role then
								return
							end
							act(function()
								return Net.invoke("SyndicateSetRole", member.userId, roleDef.id)
							end, ("%s is now %s."):format(member.name, roleDef.name))
						end)
					end
				end)
			end
			wireMod("DemoteButton", "demote", "demote", member.name .. " demoted.")
			wireMod("KickButton", "kick", "kick", member.name .. " removed.")
			-- demote only makes sense for someone who isn't already the bottom rank
			local ladder = s.roles or {}
			;(mods:WaitForChild("DemoteButton") :: TextButton).Visible =
				(mods:WaitForChild("DemoteButton") :: TextButton).Visible
				and ladder[#ladder] ~= nil and member.role ~= ladder[#ladder].id

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
	-- Invite someone already here
	--
	-- Recruit above opens Roblox's prompt, which only reaches people OUTSIDE
	-- the game. There was no way at all to invite the player standing next to
	-- you — the InviteToSyndicate remote existed but nothing ever called it.
	----------------------------------------------------------------------
	local invitePanel = Instance.new("Frame")
	invitePanel.Name = "InviteHerePanel"
	invitePanel.AnchorPoint = Vector2.new(0.5, 0.5)
	invitePanel.Position = UDim2.fromScale(0.5, 0.5)
	invitePanel.Size = UDim2.fromOffset(340, 380)
	invitePanel.BackgroundColor3 = Theme.Panel
	invitePanel.BorderSizePixel = 0
	invitePanel.Visible = false
	invitePanel.ZIndex = 40
	invitePanel.Parent = gui
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = Theme.Corner
		c.Parent = invitePanel
		local st = Instance.new("UIStroke")
		st.Color = Theme.Stroke
		st.Parent = invitePanel
	end

	local inviteTitle = Instance.new("TextLabel")
	inviteTitle.BackgroundTransparency = 1
	inviteTitle.Position = UDim2.fromOffset(14, 10)
	inviteTitle.Size = UDim2.fromOffset(240, 22)
	inviteTitle.Font = Theme.Font
	inviteTitle.TextSize = 15
	inviteTitle.TextColor3 = Theme.TextPrimary
	inviteTitle.TextXAlignment = Enum.TextXAlignment.Left
	inviteTitle.Text = "Invite someone in this server"
	inviteTitle.ZIndex = 41
	inviteTitle.Parent = invitePanel

	local inviteClose = Instance.new("TextButton")
	inviteClose.AnchorPoint = Vector2.new(1, 0)
	inviteClose.Position = UDim2.new(1, -10, 0, 10)
	inviteClose.Size = UDim2.fromOffset(26, 26)
	inviteClose.Font = Theme.Font
	inviteClose.TextSize = 14
	inviteClose.Text = "X"
	inviteClose.TextColor3 = Theme.TextPrimary
	inviteClose.BackgroundColor3 = Theme.Bad
	inviteClose.ZIndex = 41
	inviteClose.Parent = invitePanel
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = Theme.CornerSmall
		c.Parent = inviteClose
	end
	inviteClose.Activated:Connect(function()
		invitePanel.Visible = false
	end)

	local inviteList = Instance.new("ScrollingFrame")
	inviteList.Position = UDim2.fromOffset(12, 44)
	inviteList.Size = UDim2.new(1, -24, 1, -56)
	inviteList.BackgroundTransparency = 1
	inviteList.BorderSizePixel = 0
	inviteList.ScrollBarThickness = 5
	inviteList.CanvasSize = UDim2.new()
	inviteList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	inviteList.ZIndex = 41
	inviteList.Parent = invitePanel
	do
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, 6)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = inviteList
	end

	local function fillInviteList()
		for _, c in inviteList:GetChildren() do
			if c:IsA("TextButton") or c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local others = {}
		for _, other in Players:GetPlayers() do
			if other ~= Players.LocalPlayer then
				table.insert(others, other)
			end
		end
		if #others == 0 then
			local empty = Instance.new("TextLabel")
			empty.BackgroundTransparency = 1
			empty.Size = UDim2.new(1, 0, 0, 40)
			empty.Font = Theme.FontLight
			empty.TextSize = 13
			empty.TextColor3 = Theme.TextDim
			empty.Text = "Nobody else is in this server yet."
			empty.ZIndex = 41
			empty.Parent = inviteList
			return
		end
		for order, other in others do
			local row = Instance.new("TextButton")
			row.LayoutOrder = order
			row.Size = UDim2.new(1, 0, 0, 40)
			row.BackgroundColor3 = Theme.BgLight
			row.BorderSizePixel = 0
			row.Font = Theme.Font
			row.TextSize = 13
			row.TextColor3 = Theme.TextPrimary
			row.Text = "  " .. other.DisplayName .. "        INVITE"
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.ZIndex = 41
			row.Parent = inviteList
			local c = Instance.new("UICorner")
			c.CornerRadius = Theme.CornerSmall
			c.Parent = row
			row.Activated:Connect(function()
				task.spawn(function()
					local res = Net.invoke("InviteToSyndicate", other.UserId)
					if res and res.ok then
						toast(("Invited %s."):format(other.DisplayName), Theme.Good)
						invitePanel.Visible = false
					else
						toast(explain(res and res.err), Theme.Bad)
					end
				end)
			end)
		end
	end

	-- sits in ActionRow beside Recruit, which is the row of things you DO to
	-- your group; ActionRow has a horizontal list layout, so it just flows in
	local inviteHereBtn = Instance.new("TextButton")
	inviteHereBtn.Name = "InviteHereButton"
	inviteHereBtn.LayoutOrder = 5
	inviteHereBtn.Size = UDim2.fromOffset(150, 26)
	inviteHereBtn.Font = Theme.Font
	inviteHereBtn.TextSize = 12
	inviteHereBtn.Text = "INVITE FROM SERVER"
	inviteHereBtn.BackgroundColor3 = Theme.Accent
	inviteHereBtn.TextColor3 = Theme.TextPrimary
	inviteHereBtn.ZIndex = 3
	inviteHereBtn.Parent = actionRow
	do
		local c = Instance.new("UICorner")
		c.CornerRadius = Theme.CornerSmall
		c.Parent = inviteHereBtn
	end
	inviteHereBtn.Activated:Connect(function()
		fillInviteList()
		invitePanel.Visible = true
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

		-- The catalog is normally fetched when the panel opens, but opening the
		-- picker before that lands left an empty grid with nothing to retry it.
		-- Fetch on demand and repaint when it arrives.
		if catalog == nil then
			task.spawn(function()
				local result = Net.invoke("GetCatalog")
				if result and result.ok then
					catalog = result.items
					if picker.Visible then
						fillPicker(pickerSearch.Text)
					end
				end
			end)
			return
		end

		-- pull stats for what is on screen so the hover card has real
		-- numbers rather than "N/A" the first time you look at an item
		local ids = {}
		for _, item in catalog do
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
		local count = Format.parseAmount(countBox.Text)
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
	local rolesView = makeListView("RolesView")

	-- CHAT. A scrolling log with the input pinned to the bottom, which is the
	-- shape every player already knows. Messages arrive already filtered FOR
	-- THIS READER (see ChatService), so the client only ever renders what the
	-- server decided this particular person may see.
	local chatView = Instance.new("Frame")
	chatView.Name = "ChatView"
	chatView.BackgroundTransparency = 1
	chatView.Size = UDim2.fromScale(1, 1)
	chatView.Visible = false
	chatView.Parent = body

	local chatLog = Instance.new("ScrollingFrame")
	chatLog.Name = "Log"
	chatLog.BackgroundTransparency = 1
	chatLog.BorderSizePixel = 0
	chatLog.Position = UDim2.fromOffset(0, 0)
	chatLog.Size = UDim2.new(1, 0, 1, -42)
	chatLog.ScrollBarThickness = 6
	chatLog.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chatLog.CanvasSize = UDim2.new()
	chatLog.Parent = chatView
	local chatLayout = Instance.new("UIListLayout")
	chatLayout.Padding = UDim.new(0, 3)
	chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chatLayout.Parent = chatLog

	local chatBar = Instance.new("Frame")
	chatBar.Name = "ChatBar"
	chatBar.AnchorPoint = Vector2.new(0, 1)
	chatBar.Position = UDim2.new(0, 0, 1, 0)
	chatBar.Size = UDim2.new(1, 0, 0, 34)
	chatBar.BackgroundColor3 = Theme.Bg
	chatBar.BorderSizePixel = 0
	chatBar.Parent = chatView
	local cbc = Instance.new("UICorner")
	cbc.CornerRadius = Theme.CornerSmall
	cbc.Parent = chatBar

	local chatBox = Instance.new("TextBox")
	chatBox.Position = UDim2.fromOffset(10, 5)
	chatBox.Size = UDim2.new(1, -110, 0, 24)
	chatBox.BackgroundColor3 = Theme.BgLight
	chatBox.BorderSizePixel = 0
	chatBox.Font = Enum.Font.Gotham
	chatBox.PlaceholderText = "Message your group..."
	chatBox.Text = ""
	chatBox.TextColor3 = Theme.TextPrimary
	chatBox.TextSize = 13
	chatBox.TextXAlignment = Enum.TextXAlignment.Left
	chatBox.ClearTextOnFocus = false
	chatBox.Parent = chatBar
	local cbx = Instance.new("UICorner")
	cbx.CornerRadius = Theme.CornerSmall
	cbx.Parent = chatBox
	local cbp = Instance.new("UIPadding")
	cbp.PaddingLeft = UDim.new(0, 8)
	cbp.PaddingRight = UDim.new(0, 8)
	cbp.Parent = chatBox

	local sendBtn = Instance.new("TextButton")
	sendBtn.AnchorPoint = Vector2.new(1, 0.5)
	sendBtn.Position = UDim2.new(1, -10, 0.5, 0)
	sendBtn.Size = UDim2.fromOffset(84, 24)
	sendBtn.Font = Theme.Font
	sendBtn.TextSize = 12
	sendBtn.Text = "SEND"
	sendBtn.BackgroundColor3 = Theme.Accent
	sendBtn.TextColor3 = Theme.TextPrimary
	sendBtn.Parent = chatBar
	local sbc = Instance.new("UICorner")
	sbc.CornerRadius = Theme.CornerSmall
	sbc.Parent = sendBtn

	local chatOrder = 0
	local seenChat: { [string]: boolean } = {}
	local chatEmpty = Instance.new("TextLabel")
	chatEmpty.Name = "ChatEmpty"
	chatEmpty.BackgroundTransparency = 1
	chatEmpty.Size = UDim2.new(1, -12, 0, 40)
	chatEmpty.Font = Enum.Font.Gotham
	chatEmpty.TextSize = 13
	chatEmpty.TextColor3 = Theme.TextDim
	chatEmpty.Text = "No messages yet — say something to your group."
	chatEmpty.Parent = chatLog

	local function appendChat(payload: any)
		-- the same message legitimately arrives twice: once live, once when
		-- history replays. Drop the second copy rather than render it.
		local id = payload.id
		if id ~= nil then
			if seenChat[id] then
				return
			end
			seenChat[id] = true
		end
		chatEmpty.Visible = false
		chatOrder += 1
		local row = Instance.new("TextLabel")
		row.Name = "msg_" .. chatOrder
		row.LayoutOrder = chatOrder
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -12, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Font = Enum.Font.Gotham
		row.TextSize = 13
		row.TextColor3 = Theme.TextPrimary
		row.TextWrapped = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.RichText = false
		row.Text = ("%s:  %s"):format(tostring(payload.name), tostring(payload.text))
		row.Parent = chatLog
		-- keep the newest line in view, the way any chat window behaves
		task.defer(function()
			chatLog.CanvasPosition = Vector2.new(0, math.max(0, chatLog.AbsoluteCanvasSize.Y))
		end)
	end

	local function sendChat()
		local text = chatBox.Text
		if text:gsub("%s", "") == "" then
			return
		end
		chatBox.Text = ""
		task.spawn(function()
			local result = Net.invoke("SendGroupChat", text)
			if not (result and result.ok) then
				toast(explain(result and result.err), Theme.Bad)
			end
		end)
	end
	sendBtn.Activated:Connect(sendChat)
	chatBox.FocusLost:Connect(function(enter)
		if enter then
			sendChat()
		end
	end)

	Net.on("GroupChat", function(payload)
		if payload then
			appendChat(payload)
		end
	end)


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

	-- SETTINGS: the knobs the owner controls about the group itself.
	local function renderSettings(s: any)
		local order = 0
		local isOwner = s.yourRole == SyndicateConfig.OwnerRoleId
		local function addRow(height: number): Frame
			order += 1
			return makeRow(settingsView, order, height)
		end

		-- Who can join is a SETTING, so it belongs here rather than on the
		-- members screen beside Leave, where it read as an action.
		local joinRow = addRow(38)
		makeLabel(joinRow, "Who can join", UDim2.fromOffset(12, 0), UDim2.new(1, -230, 1, 0), 13, Theme.TextPrimary)
		local joinBtn = Instance.new("TextButton")
		joinBtn.AnchorPoint = Vector2.new(1, 0.5)
		joinBtn.Position = UDim2.new(1, -10, 0.5, 0)
		joinBtn.Size = UDim2.fromOffset(200, 26)
		joinBtn.Font = Theme.Font
		joinBtn.TextSize = 12
		joinBtn.Text = SyndicateConfig.JoinPolicyLabels[s.policy] or tostring(s.policy)
		joinBtn.BackgroundColor3 = Theme.Info
		joinBtn.TextColor3 = Theme.Bg
		joinBtn.AutoButtonColor = isOwner
		joinBtn.Parent = joinRow
		local jc = Instance.new("UICorner")
		jc.CornerRadius = Theme.CornerSmall
		jc.Parent = joinBtn
		if isOwner then
			joinBtn.Activated:Connect(function()
				local policies = SyndicateConfig.JoinPolicies
				local index = 1
				for i, pol in policies do
					if pol == s.policy then
						index = i
					end
				end
				local nextPolicy = policies[(index % #policies) + 1]
				act(function()
					return Net.invoke("SetSyndicatePolicy", nextPolicy)
				end, nil)
			end)
		end

		local infoRow = addRow(34)
		makeLabel(infoRow, ("Members: %d of %d  |  Level %d  |  %s XP"):format(
			#s.members, s.memberCap, s.level, Format.abbrev(s.xp)),
			UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 12, Theme.TextDim)

		if not isOwner then
			local note = addRow(34)
			makeLabel(note, "Only the Owner can change these.",
				UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 12, Theme.TextDim)
		end
	end

	-- ROLES: the ladder itself. Its own section because editing ranks is a
	-- different job from setting the group options, and a much longer list.
	local function renderRoles(s: any)
		local order = 0
		local isOwner = s.yourRole == SyndicateConfig.OwnerRoleId
		local function addRow(height: number): Frame
			order += 1
			return makeRow(rolesView, order, height)
		end

		if not isOwner then
			local note = addRow(34)
			makeLabel(note, "Only the Owner can edit roles.",
				UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 12, Theme.TextDim)
			return
		end

		local header = addRow(30)
		header.BackgroundTransparency = 1
		makeLabel(header, "Owner always has every permission, so it is not listed.",
			UDim2.fromOffset(4, 0), UDim2.new(1, -150, 1, 0), 11, Theme.TextDim)
		local addBtn = Instance.new("TextButton")
		addBtn.AnchorPoint = Vector2.new(1, 0.5)
		addBtn.Position = UDim2.new(1, -10, 0.5, 0)
		addBtn.Size = UDim2.fromOffset(130, 24)
		addBtn.Font = Theme.Font
		addBtn.TextSize = 12
		addBtn.Text = "+ NEW ROLE"
		addBtn.BackgroundColor3 = Theme.Good
		addBtn.TextColor3 = Theme.Bg
		addBtn.Parent = header
		local ac = Instance.new("UICorner")
		ac.CornerRadius = Theme.CornerSmall
		ac.Parent = addBtn
		addBtn.Activated:Connect(function()
			act(function()
				return Net.invoke("SyndicateCreateRole", "New Role")
			end, "Role created - rename it below.")
		end)

		for _, role in (s.roles or {}) do
			-- Owner is skipped: it always has everything and none of it is
			-- editable, so listing it is a screen of locked rows saying nothing.
			if role.id ~= SyndicateConfig.OwnerRoleId then
				local permanent = SyndicateConfig.isPermanentRole(role.id)
				local roleRow = addRow(36)
				local nameBox = Instance.new("TextBox")
				nameBox.Position = UDim2.fromOffset(12, 5)
				nameBox.Size = UDim2.fromOffset(170, 26)
				nameBox.BackgroundColor3 = Theme.BgLight
				nameBox.BorderSizePixel = 0
				nameBox.Font = Theme.Font
				nameBox.TextSize = 13
				nameBox.TextColor3 = Theme.TextPrimary
				nameBox.Text = role.name
				nameBox.ClearTextOnFocus = false
				nameBox.Parent = roleRow
				local nc = Instance.new("UICorner")
				nc.CornerRadius = Theme.CornerSmall
				nc.Parent = nameBox
				-- Commit on ANY blur, not just Enter. Clicking away used to throw
				-- the typed name out, and because the row is rebuilt from group
				-- state on the next render the box visibly snapped back to
				-- "New Role" — which reads as the game refusing the rename.
				nameBox.FocusLost:Connect(function()
					local typed = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
					if typed == "" then
						nameBox.Text = role.name -- empty isn't a rename, put it back
						return
					end
					if typed ~= role.name then
						act(function()
							return Net.invoke("SyndicateRenameRole", role.id, typed)
						end, nil)
					end
				end)

				local function smallBtn(text: string, x: number, colour: Color3, onClick: () -> ())
					local b = Instance.new("TextButton")
					b.AnchorPoint = Vector2.new(1, 0.5)
					b.Position = UDim2.new(1, x, 0.5, 0)
					b.Size = UDim2.fromOffset(30, 24)
					b.Font = Theme.Font
					b.TextSize = 12
					b.Text = text
					b.BackgroundColor3 = colour
					b.TextColor3 = Theme.TextPrimary
					b.Parent = roleRow
					local c = Instance.new("UICorner")
					c.CornerRadius = Theme.CornerSmall
					c.Parent = b
					b.Activated:Connect(onClick)
				end
				smallBtn("^", -78, Theme.BgLight, function()
					act(function()
						return Net.invoke("SyndicateMoveRole", role.id, -1)
					end, nil)
				end)
				smallBtn("v", -44, Theme.BgLight, function()
					act(function()
						return Net.invoke("SyndicateMoveRole", role.id, 1)
					end, nil)
				end)
				if not permanent then
					smallBtn("X", -10, Theme.Bad, function()
						act(function()
							return Net.invoke("SyndicateDeleteRole", role.id)
						end, ("%s deleted."):format(role.name))
					end)
				end

				for _, perm in SyndicateConfig.PermissionCatalogue do
					if perm.ownerOnly ~= true then
						local permRow = addRow(30)
						makeLabel(permRow, "    " .. perm.label, UDim2.fromOffset(12, 0),
							UDim2.new(1, -140, 1, 0), 12, Theme.TextDim)
						local on = SyndicateConfig.roleCan(role, perm.key)
						local toggle = Instance.new("TextButton")
						toggle.AnchorPoint = Vector2.new(1, 0.5)
						toggle.Position = UDim2.new(1, -10, 0.5, 0)
						toggle.Size = UDim2.fromOffset(90, 22)
						toggle.Font = Theme.Font
						toggle.TextSize = 11
						toggle.Text = on and "ALLOWED" or "BLOCKED"
						toggle.BackgroundColor3 = on and Theme.Good or Theme.BgLight
						toggle.TextColor3 = on and Theme.Bg or Theme.TextDim
						toggle.Parent = permRow
						local tc = Instance.new("UICorner")
						tc.CornerRadius = Theme.CornerSmall
						tc.Parent = toggle
						toggle.Activated:Connect(function()
							act(function()
								return Net.invoke("SyndicateSetPermission", role.id, perm.key, not on)
							end, nil)
						end)
					end
				end
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
		local inMine = activeTab == "mine" and inSyndicate
		subTabRow.Visible = inMine
		for id, b in sectionButtons do
			b.BackgroundColor3 = (mineSection == id) and Theme.Accent or Theme.BgLight
			b.TextColor3 = (mineSection == id) and Theme.TextPrimary or Theme.TextDim
		end

		createView.Visible = activeTab == "mine" and not inSyndicate
		mineView.Visible = inMine and mineSection == "members"
		requestsView.Visible = inMine and mineSection == "requests"
		goalsView.Visible = inMine and mineSection == "goals"
		settingsView.Visible = inMine and mineSection == "settings"
		rolesView.Visible = inMine and mineSection == "roles"
		chatView.Visible = inMine and mineSection == "chat"
		browseView.Visible = activeTab == "browse"
		invitesView.Visible = activeTab == "invites"

		-- the section row sits above whichever section is showing
		for _, view in { mineView, requestsView, goalsView, settingsView, rolesView, chatView } do
			if view.Visible then
				view.Position = UDim2.fromOffset(0, 32)
				view.Size = UDim2.new(1, 0, 1, -32)
			end
		end

		if mineView.Visible then
			renderMine(s)
		elseif requestsView.Visible then
			renderRequests(s)
		elseif goalsView.Visible then
			renderGoals(s)
		elseif settingsView.Visible then
			renderSettings(s)
		elseif rolesView.Visible then
			renderRoles(s)
		elseif chatView.Visible then
			-- history replays through the same filtered path as live
			-- messages, so it arrives via the GroupChat event too
			-- Ask on every open, not once per session. The first ask can fail
			-- for a reason that later stops being true -- the profile is still
			-- loading, or you had not joined a group yet -- and marking it
			-- primed regardless meant one badly-timed open left the log empty
			-- for the rest of the session. Replayed lines are deduped by id,
			-- so re-asking costs nothing but an in-memory read.
			if not chatPrimed and not chatPriming then
				chatPriming = true
				task.spawn(function()
					local result = Net.invoke("GetGroupChat")
					chatPrimed = result ~= nil and result.ok == true
					chatPriming = false
				end)
			end
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
