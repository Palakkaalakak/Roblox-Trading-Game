--!strict
-- Quests panel: hero-card layout (rank strip, one big current-quest card, a
-- 5-tile quest board, three dailies + streak). Built in code over the
-- RewardsPanel shell. Server truth comes from QuestController.status.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local RankConfig = require(ReplicatedStorage.Shared.Config.RankConfig)

local QuestsScreen = {}

local INK = Color3.fromRGB(20, 21, 27)
local CARD = Color3.fromRGB(32, 34, 42)
local TILE = Color3.fromRGB(44, 47, 58)
local TEXT = Color3.fromRGB(240, 242, 248)
local DIM = Color3.fromRGB(160, 165, 180)
local MUTED = Color3.fromRGB(107, 112, 128)
local BLUE = Color3.fromRGB(88, 166, 255)
local BLUE_TXT = Color3.fromRGB(143, 196, 255)
local GOLD = Color3.fromRGB(253, 179, 30)
local GREEN = Color3.fromRGB(87, 217, 130)
local CYAN = Color3.fromRGB(120, 220, 232)

local G_BLUE = { Color3.fromRGB(143, 208, 255), Color3.fromRGB(61, 143, 224) }
local G_GREEN = { Color3.fromRGB(125, 232, 160), Color3.fromRGB(63, 191, 106) }
local G_GOLD = { Color3.fromRGB(255, 211, 92), Color3.fromRGB(240, 160, 16) }

local UNLOCK_NAMES: { [string]: string } = { bulkbuy = "Bulk Buy", booth = "Booths", syndicate = "Syndicates" }

-- What finishing quest `id` gives: a rank-up (and its unlocks) or nothing.
-- Quests grant no currency; the milestone IS the reward.
local ICON_QUESTS = "rbxassetid://17368118782"
local KIND_ICON: { [string]: string } = {
	starter = "rbxassetid://15402958715", -- inventory
	craft = "rbxassetid://17368097932", -- star
	roll = "rbxassetid://17368064384", -- gem
	market_check = "rbxassetid://15403064919", -- trade arrows
	post_trade = "rbxassetid://15403064919",
	complete_trade = "rbxassetid://15403064919",
	sell = "rbxassetid://15402855334", -- coin chest
	bulk_contribute = "rbxassetid://15402855334",
}

local function milestoneText(id: number): string
	for _, r in RankConfig.Ranks do
		if r.questsRequired == id and id > 0 then
			local names = {}
			for key in r.unlocks do
				if UNLOCK_NAMES[key] then
					table.insert(names, UNLOCK_NAMES[key])
				end
			end
			return #names > 0 and ("Unlocks " .. table.concat(names, " + ")) or ("Rank up: " .. r.title)
		end
	end
	return ""
end

local function short(n: number): string
	if n >= 1e9 then
		return ("%.1fB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.1fM"):format(n / 1e6)
	elseif n >= 1e3 then
		return ("%.1fK"):format(n / 1e3)
	end
	return tostring(math.floor(n))
end

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function gradient(parent: Instance, g: { Color3 })
	local ug = Instance.new("UIGradient")
	ug.Color = ColorSequence.new(g[1], g[2])
	ug.Rotation = 90
	ug.Parent = parent
end

local function frame(parent: Instance, pos: UDim2, size: UDim2, color: Color3?, r: number?): Frame
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = size
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color or CARD
	f.BackgroundTransparency = color == nil and 1 or 0
	f.Parent = parent
	if r then
		corner(f, r)
	end
	return f
end

local function label(parent: Instance, pos: UDim2, size: UDim2, text: string, textSize: number, color: Color3, align: Enum.TextXAlignment?, outlined: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.GothamBlack
	l.Text = text
	l.TextSize = textSize
	l.TextColor3 = color
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Parent = parent
	if outlined then
		l.TextStrokeColor3 = INK
		l.TextStrokeTransparency = 0
	end
	return l
end

local function button(parent: Instance, pos: UDim2, size: UDim2, text: string, textSize: number): TextButton
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBlack
	b.Text = text
	b.TextSize = textSize
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeColor3 = INK
	b.TextStrokeTransparency = 0
	b.Parent = parent
	corner(b, 10)
	stroke(b, 3)
	return b
end

local function pill(parent: Instance, text: string, color: Color3, order: number): TextLabel
	local p = Instance.new("TextLabel")
	p.AutomaticSize = Enum.AutomaticSize.X
	p.Size = UDim2.new(0, 0, 1, 0)
	p.BackgroundColor3 = CARD
	p.BorderSizePixel = 0
	p.Font = Enum.Font.GothamBlack
	p.Text = text
	p.TextSize = 13
	p.TextColor3 = color
	p.LayoutOrder = order
	p.Parent = parent
	corner(p, 14)
	stroke(p, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = p
	return p
end

local function bar(parent: Instance, pos: UDim2, size: UDim2): (Frame, Frame, TextLabel)
	local track = frame(parent, pos, size, INK, 8)
	stroke(track, 3)
	local fill = frame(track, UDim2.new(), UDim2.fromScale(0, 1), BLUE, 6)
	gradient(fill, G_BLUE)
	local txt = label(track, UDim2.new(), UDim2.fromScale(1, 1), "", 15, Color3.new(1, 1, 1), Enum.TextXAlignment.Center, true)
	txt.ZIndex = 3
	return track, fill, txt
end

-- deps: { QuestController, State, skip = () -> () }
function QuestsScreen.wire(rewardsPanel: Frame, deps: any)
	local empty = rewardsPanel:WaitForChild("EmptyLabel") :: TextLabel
	local body = frame(rewardsPanel, UDim2.fromScale(0.035, 0.13), UDim2.fromScale(0.93, 0.85))
	body.Name = "QuestBody"
	body.Visible = false

	--------------------------------------------------------------------------
	-- Rank strip
	--------------------------------------------------------------------------
	local rankCard = frame(body, UDim2.new(), UDim2.fromScale(1, 0.15), CARD, 10)
	stroke(rankCard, 3)
	local rankBadge = frame(rankCard, UDim2.fromScale(0.02, 0.5), UDim2.fromOffset(50, 50), BLUE, 25)
	rankBadge.AnchorPoint = Vector2.new(0, 0.5)
	stroke(rankBadge, 4)
	gradient(rankBadge, G_BLUE)
	local rankBadgeText = label(rankBadge, UDim2.new(), UDim2.fromScale(1, 1), "1", 22, Color3.new(1, 1, 1), Enum.TextXAlignment.Center, true)
	label(rankCard, UDim2.fromScale(0.105, 0.14), UDim2.fromScale(0.2, 0.25), "YOUR RANK", 11, DIM)
	local rankName = label(rankCard, UDim2.fromScale(0.105, 0.36), UDim2.fromScale(0.2, 0.5), "", 24, BLUE_TXT, nil, true)
	local segHolder = frame(rankCard, UDim2.fromScale(0.32, 0.2), UDim2.fromScale(0.66, 0.62))
	local segLayout = Instance.new("UIListLayout")
	segLayout.FillDirection = Enum.FillDirection.Horizontal
	segLayout.Padding = UDim.new(0, 5)
	segLayout.Parent = segHolder
	local segs: { { bar: Frame, name: TextLabel } } = {}
	local nRanks = #RankConfig.Ranks
	for i, r in RankConfig.Ranks do
		local col = frame(segHolder, UDim2.new(), UDim2.new(1 / nRanks, -5, 1, 0))
		col.LayoutOrder = i
		local b = frame(col, UDim2.new(), UDim2.new(1, 0, 0, 14), TILE, 4)
		stroke(b, 3)
		local n = label(col, UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 16), string.upper(r.title), 10, MUTED, Enum.TextXAlignment.Center)
		segs[i] = { bar = b, name = n }
	end

	--------------------------------------------------------------------------
	-- Hero card: the ONE thing to do now
	--------------------------------------------------------------------------
	local hero = frame(body, UDim2.fromScale(0, 0.17), UDim2.fromScale(1, 0.41), TILE, 10)
	local heroStroke = Instance.new("UIStroke")
	heroStroke.Thickness = 4
	heroStroke.Color = INK
	heroStroke.Parent = hero
	local heroIcon = frame(hero, UDim2.fromScale(0.03, 0.12), UDim2.fromScale(0.17, 0.62), BLUE, 10)
	stroke(heroIcon, 4)
	gradient(heroIcon, { Color3.fromRGB(90, 169, 255), Color3.fromRGB(31, 79, 134) })
	local iconAspect = Instance.new("UIAspectRatioConstraint")
	iconAspect.Parent = heroIcon
	-- What the quest is about, at a glance (same icons as the HUD buttons).
	local heroImg = Instance.new("ImageLabel")
	heroImg.BackgroundTransparency = 1
	heroImg.AnchorPoint = Vector2.new(0.5, 0.5)
	heroImg.Position = UDim2.fromScale(0.5, 0.5)
	heroImg.Size = UDim2.fromScale(0.78, 0.78)
	heroImg.ScaleType = Enum.ScaleType.Fit
	heroImg.Parent = heroIcon
	local heroCount = label(hero, UDim2.fromScale(0.02, 0.78), UDim2.fromScale(0.19, 0.15), "", 11, BLUE_TXT, Enum.TextXAlignment.Center)
	local heroTitle = label(hero, UDim2.fromScale(0.24, 0.07), UDim2.fromScale(0.73, 0.28), "", 26, Color3.new(1, 1, 1), nil, true)
	heroTitle.TextTruncate = Enum.TextTruncate.AtEnd
	local heroTrack, heroFill, heroBarText = bar(hero, UDim2.fromScale(0.24, 0.37), UDim2.fromScale(0.73, 0.17))
	local chips = frame(hero, UDim2.fromScale(0.24, 0.58), UDim2.fromScale(0.73, 0.14))
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.Padding = UDim.new(0, 8)
	chipLayout.Parent = chips
	local cta = button(hero, UDim2.fromScale(0.24, 0.76), UDim2.fromScale(0.73, 0.19), "SKIP  (R$ 49)", 20)
	cta.BackgroundColor3 = Color3.new(1, 1, 1)
	gradient(cta, G_GREEN)
	cta.Activated:Connect(function()
		deps.skip()
	end)

	--------------------------------------------------------------------------
	-- Quest board: 5 tiles around the current quest
	--------------------------------------------------------------------------
	local tileRow = frame(body, UDim2.fromScale(0, 0.6), UDim2.fromScale(1, 0.13))
	local tiles: { { f: Frame, num: TextLabel, name: TextLabel, sub: TextLabel } } = {}
	for i = 1, 5 do
		local t = frame(tileRow, UDim2.fromScale((i - 1) * 0.2 + 0.005, 0), UDim2.fromScale(0.19, 1), CARD, 10)
		stroke(t, 3)
		local num = label(t, UDim2.fromScale(0.07, 0.06), UDim2.fromScale(0.86, 0.28), "", 11, MUTED)
		-- two lines: quest titles like "Check an item's value in the Market" are long
		local nm = label(t, UDim2.fromScale(0.07, 0.28), UDim2.fromScale(0.86, 0.4), "", 13, TEXT)
		nm.TextYAlignment = Enum.TextYAlignment.Center
		local sub = label(t, UDim2.fromScale(0.07, 0.68), UDim2.fromScale(0.86, 0.26), "", 11, CYAN)
		sub.TextTruncate = Enum.TextTruncate.AtEnd
		sub.TextWrapped = false
		tiles[i] = { f = t, num = num, name = nm, sub = sub }
	end

	--------------------------------------------------------------------------
	-- Dailies + streak
	--------------------------------------------------------------------------
	local tab = "daily"
	local tabBtns: { [string]: TextButton } = {}
	for i, name in { "daily", "weekly" } do
		local b = button(body, UDim2.fromScale(0.005 + (i - 1) * 0.15, 0.46), UDim2.fromScale(0.14, 0.07), string.upper(name), 14)
		tabBtns[name] = b
	end
	local resetText = label(body, UDim2.fromScale(0.31, 0.46), UDim2.fromScale(0.25, 0.07), "", 13, DIM)
	local streakText = label(body, UDim2.fromScale(0.5, 0.46), UDim2.fromScale(0.495, 0.07), "", 14, CYAN, Enum.TextXAlignment.Right)
	local dCards: { { f: Frame, title: TextLabel, fill: Frame, barText: TextLabel, btn: TextLabel } } = {}
	for i = 1, 3 do
		local c = frame(body, UDim2.fromScale((i - 1) / 3 + 0.005, 0.56), UDim2.fromScale(1 / 3 - 0.01, 0.42), CARD, 10)
		stroke(c, 3)
		local title = label(c, UDim2.fromScale(0.06, 0.07), UDim2.fromScale(0.88, 0.3), "", 17, TEXT)
		title.TextTruncate = Enum.TextTruncate.AtEnd
		local _, fill, barText = bar(c, UDim2.fromScale(0.06, 0.42), UDim2.fromScale(0.88, 0.16))
		local btn = label(c, UDim2.fromScale(0.06, 0.68), UDim2.fromScale(0.88, 0.235), "", 15, DIM, Enum.TextXAlignment.Center)
		dCards[i] = { f = c, title = title, fill = fill, barText = barText, btn = btn }
	end
	local renderFn: (() -> ())? = nil
	for name, b in tabBtns do
		b.Activated:Connect(function()
			tab = name
			if renderFn then
				renderFn()
			end
		end)
	end

	--------------------------------------------------------------------------
	-- Render
	--------------------------------------------------------------------------
	local function styleTile(t: any, state: string, quest: any?)
		if quest == nil then
			t.f.Visible = false
			return
		end
		t.f.Visible = true
		local locked = state == "locked"
		t.f.BackgroundColor3 = state == "done" and Color3.fromRGB(31, 58, 42) or state == "now" and Color3.fromRGB(29, 51, 80) or CARD
		t.f.BackgroundTransparency = locked and 0.45 or state == "next" and 0.2 or 0
		t.num.Text = state == "done" and "✓ DONE" or state == "now" and "NOW" or state == "next" and "NEXT" or "LOCKED"
		t.num.TextColor3 = state == "done" and GREEN or state == "now" and BLUE_TXT or MUTED
		t.name.Text = locked and "???" or quest.title
		t.sub.Text = locked and "???" or milestoneText(quest.id)
	end

	local function render()
		local status = deps.QuestController.status:get()
		if status == nil then
			return
		end
		empty.Visible = false
		body.Visible = true

		-- rank strip
		rankName.Text = status.rank.title
		rankBadgeText.Text = tostring(status.rank.id)
		local rankId = status.rank.id
		for i, seg in segs do
			local done = i < rankId
			local here = i == rankId
			seg.bar.BackgroundColor3 = (done or here) and Color3.new(1, 1, 1) or TILE
			local old = seg.bar:FindFirstChildOfClass("UIGradient")
			if old then
				old:Destroy()
			end
			if done then
				gradient(seg.bar, G_GREEN)
			elseif here then
				gradient(seg.bar, G_BLUE)
			end
			seg.name.TextColor3 = here and BLUE_TXT or done and DIM or MUTED
		end

		-- Two layouts. While the core chain runs: big hero + quest board.
		-- Once it is finished: compact title hero, and Daily/Weekly take the room.
		local coreDone = status.setsUnlocked == true
		hero.Visible = not coreDone
		hero.Size = UDim2.fromScale(1, 0.48)
		-- finished chain: no hero/title card, Daily & Weekly take the room
		for i, b in { tabBtns.daily, tabBtns.weekly } do
			b.Position = UDim2.fromScale(0.005 + (i - 1) * 0.15, 0.18)
		end
		resetText.Position = UDim2.fromScale(0.31, 0.18)
		streakText.Position = UDim2.fromScale(0.5, 0.18)
		for i, c in dCards do
			c.f.Position = UDim2.fromScale((i - 1) / 3 + 0.005, 0.28)
			c.f.Size = UDim2.fromScale(1 / 3 - 0.01, 0.56)
		end
		tileRow.Position = UDim2.fromScale(0, 0.68)
		tileRow.Size = UDim2.fromScale(1, 0.29)
		tileRow.Visible = not coreDone
		heroTitle.Position = UDim2.fromScale(0.24, coreDone and 0.14 or 0.07)
		heroTitle.Size = UDim2.fromScale(0.73, coreDone and 0.32 or 0.26)
		heroTrack.Position = UDim2.fromScale(0.24, coreDone and 0.54 or 0.37)
		heroTrack.Size = UDim2.fromScale(0.73, coreDone and 0.3 or 0.16)
		heroCount.Position = UDim2.fromScale(0.02, coreDone and 0.8 or 0.78)
		heroIcon.Position = UDim2.fromScale(0.03, coreDone and 0.1 or 0.1)
		heroIcon.Size = UDim2.fromScale(0.17, coreDone and 0.58 or 0.62)
		for _, b in tabBtns do
			b.Visible = coreDone
		end
		resetText.Visible = coreDone
		streakText.Visible = coreDone

		-- hero
		for _, c in chips:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local q = status.quest
		if q then
			heroTitle.Text = q.title
			heroCount.Text = ("QUEST %d OF %d"):format(q.id, status.totalQuests)
			heroFill.Size = UDim2.fromScale(math.clamp(q.progress / math.max(1, q.target), 0, 1), 1)
			heroBarText.Text = ("%d / %d"):format(q.progress, q.target)
			local order = 1
			-- rank this quest pushes you into, and what it opens
			for _, r in RankConfig.Ranks do
				if r.questsRequired == q.id then
					pill(chips, "Rank up to " .. string.upper(r.title), GOLD, order)
					order += 1
					for key in r.unlocks do
						if UNLOCK_NAMES[key] then
							pill(chips, "Unlocks " .. UNLOCK_NAMES[key], GREEN, order)
							order += 1
						end
					end
				end
			end
			local full = QuestConfig.byId(q.id)
			heroImg.Image = KIND_ICON[full and full.kind or ""] or ICON_QUESTS
			cta.Visible = true
			heroStroke.Color = INK
		else
			local pr = status.profit
			heroTitle.Text = pr and pr.nextTitle and ("NEXT TITLE: " .. string.upper(pr.nextTitle)) or "TOP TITLE REACHED!"
			heroCount.Text = pr and ("TITLE %d OF %d"):format(pr.reached, pr.count) or ""
			if pr and pr.nextThreshold then
				local span = math.max(1, pr.nextThreshold - pr.prevThreshold)
				heroFill.Size = UDim2.fromScale(math.clamp((pr.earned - pr.prevThreshold) / span, 0, 1), 1)
				heroBarText.Text = ("%s / %s profit"):format(short(pr.earned), short(pr.nextThreshold))
			else
				heroFill.Size = UDim2.fromScale(1, 1)
				heroBarText.Text = ""
			end
			cta.Visible = false
			heroStroke.Color = GOLD
		end

		-- quest board: 5 tiles around the current quest
		local total = status.totalQuests
		local start = math.clamp(status.completed, 1, math.max(1, total - 4))
		for i, t in tiles do
			local id = start + i - 1
			local quest = QuestConfig.byId(id)
			local state = id <= status.completed and "done" or id == status.completed + 1 and "now" or id == status.completed + 2 and "next" or "locked"
			styleTile(t, state, quest)
		end

		-- dailies / weeklies: only exist once the core chain is finished
		for _, c in dCards do
			c.f.Visible = coreDone
		end
		if not coreDone then
			return
		end
		for name, b in tabBtns do
			b.BackgroundColor3 = name == tab and BLUE or TILE
		end
		local resetAt = tab == "daily" and status.dailyResetsAt or status.weeklyResetsAt
		local left = math.max(0, (resetAt or 0) - os.time())
		resetText.Text = left >= 86400 and ("resets in %dd %dh"):format(left // 86400, (left % 86400) // 3600) or ("resets in %dh %dm"):format(left // 3600, (left % 3600) // 60)
		local st = status.streak
		streakText.Text = tab ~= "daily" and "" or st and (st.clearedToday and ("%d-day streak  ·  done today"):format(st.count) or ("%d-day streak  ·  finish all 3 to keep it"):format(st.count)) or ""
		local list = tab == "daily" and status.dailies or status.weeklies
		for i, c in dCards do
			local d = list and list[i]
			c.f.Visible = d ~= nil
			if d then
				c.title.Text = d.title
				c.fill.Size = UDim2.fromScale(math.clamp(d.progress / math.max(1, d.target), 0, 1), 1)
				c.barText.Text = ("%d / %d"):format(d.progress, d.target)
				c.btn.Text = d.done and "✓ DONE" or tab == "daily" and "Daily" or "Weekly"
				c.btn.TextColor3 = d.done and GREEN or DIM
			end
		end
	end
	renderFn = render

	deps.State.Observe(deps.QuestController.status, render)
	return render
end

return QuestsScreen
