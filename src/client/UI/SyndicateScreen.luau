--!strict
-- Syndicate screen: your clan, the public directory, and pending invites.
--
-- Three views the tabs swap between. Which tabs exist depends on membership —
-- someone in no syndicate sees Create/Browse/Invites, a member sees their
-- syndicate instead of the create form. The server decides everything that
-- matters (permissions, capacity, cost); this only renders what it returns and
-- re-fetches after every action, so the UI can never drift from the truth.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Net = require(script.Parent.Parent.Net)
local Format = require(game:GetService("ReplicatedStorage").Shared.Util.Format)
local SyndicateConfig = require(game:GetService("ReplicatedStorage").Shared.Config.SyndicateConfig)

local SyndicateScreen = {}

-- server error code -> something a player can act on
local ERRORS = {
	already_in_syndicate = "You're already in a syndicate.",
	not_in_syndicate = "You're not in a syndicate.",
	insufficient_gems = "You don't have enough gems.",
	name_too_short = "That name is too short.",
	tag_too_short = "That tag is too short.",
	bad_name = "That name isn't allowed.",
	bad_tag = "That tag isn't allowed.",
	tag_not_alphanumeric = "Tags can only use letters and numbers.",
	syndicate_full = "That syndicate is full.",
	invite_only = "That syndicate is invite-only.",
	request_required = "That syndicate only takes invited members.",
	owner_must_transfer = "Promote someone else before you leave.",
	no_permission = "You don't have permission to do that.",
	target_outranks_you = "You can't do that to someone ranked above you.",
	cannot_target_self = "You can't do that to yourself.",
	player_not_here = "That player isn't in this server.",
	loading = "Still loading — try again in a moment.",
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
	local function act(fn: () -> any, successText: string?)
		if busy then
			return
		end
		busy = true
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
			refresh()
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
		local specs = {
			{ id = "mine", text = latest and latest.syndicate and "My Syndicate" or "Create" },
			{ id = "browse", text = "Browse" },
			{ id = "invites", text = ("Invites (%d)"):format(latest and #(latest.invites or {}) or 0) },
		}
		for i, spec in specs do
			local b = Instance.new("TextButton")
			b.Name = "Tab_" .. spec.id
			b.LayoutOrder = i
			b.Size = UDim2.fromOffset(160, 30)
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
	;(createView:WaitForChild("CostLabel") :: TextLabel).Text =
		("Costs %s gems. You'll be the Owner."):format(Format.comma(SyndicateConfig.CreateCostGems))
	createBtn.Activated:Connect(function()
		local name, tag = nameBox.Text, tagBox.Text
		act(function()
			return Net.invoke("CreateSyndicate", name, tag)
		end, "Syndicate founded!")
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
		act(function()
			return Net.invoke("LeaveSyndicate")
		end, "You left the syndicate.")
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
		end, "Join policy is now " .. nextPolicy .. ".")
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

		policyBtn.Text = "Policy: " .. tostring(s.policy)
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
			;(row:WaitForChild("MemberXp") :: TextLabel).Text = Format.abbrev(member.xpContributed) .. " XP"

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
			wireMod("PromoteButton", "promote", "promote", member.name .. " promoted.")
			wireMod("DemoteButton", "demote", "demote", member.name .. " demoted.")
			wireMod("KickButton", "kick", "kick", member.name .. " removed.")
			-- promote/demote only make sense in one direction each
			;(mods:WaitForChild("PromoteButton") :: TextButton).Visible =
				(mods:WaitForChild("PromoteButton") :: TextButton).Visible and member.role == "Member"
			;(mods:WaitForChild("DemoteButton") :: TextButton).Visible =
				(mods:WaitForChild("DemoteButton") :: TextButton).Visible and member.role == "Officer"

			row.Parent = memberList
			table.insert(spawned, row)
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

		if mineView.Visible then
			renderMine(s)
		elseif browseView.Visible then
			task.spawn(function()
				local dir = Net.invoke("BrowseSyndicates")
				if not (dir and dir.ok) or not browseView.Visible then
					return
				end
				renderList(browseView, "BrowseRow", dir.syndicates, "No syndicates yet — found the first one!", function(row, entry)
					(row:WaitForChild("SynName") :: TextLabel).Text = ("[%s] %s"):format(entry.tag, entry.name)
					;(row:WaitForChild("SynMeta") :: TextLabel).Text =
						("Level %d  ·  %d members  ·  %s"):format(entry.level or 1, entry.members or 0, entry.policy or "")
					local btn = row:WaitForChild("ActionButton") :: TextButton
					btn.Visible = not inSyndicate
					btn.Activated:Connect(function()
						act(function()
							return Net.invoke("JoinSyndicate", entry.id)
						end, "Joined " .. entry.name .. "!")
					end)
				end)
			end)
		elseif invitesView.Visible then
			renderList(invitesView, "InviteRow", payload.invites or {}, "No pending invites.", function(row, entry)
				(row:WaitForChild("SynName") :: TextLabel).Text = ("[%s] %s"):format(entry.tag, entry.name)
				;(row:WaitForChild("SynMeta") :: TextLabel).Text = "invited you"
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

	function SyndicateScreen.open()
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
