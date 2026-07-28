--!strict
-- Leaderboards. Board tabs across the top, an all-time / this-week toggle
-- beneath, ranked rows, and the viewer's own rank pinned along the bottom.
--
-- The board list comes from the server (LeaderboardConfig), so adding a board
-- is a config entry — the tabs build themselves from whatever arrives.
--
-- The pinned "you" row is the point of the screen for most players: they will
-- never be in the top 50, and a board you're absent from is a board you ignore.
-- It shows a rank when they're on the board and their raw score when they
-- aren't, so there's always a number to improve.

local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Net = require(script.Parent.Parent.Net)

local LeaderboardScreen = {}

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function timeLeft(untilUnix: number?): string
	if untilUnix == nil then
		return ""
	end
	local remaining = math.max(0, untilUnix - os.time())
	local d = math.floor(remaining / 86400)
	local h = math.floor((remaining % 86400) / 3600)
	if d > 0 then
		return ("resets in %dd %dh"):format(d, h)
	end
	local m = math.floor((remaining % 3600) / 60)
	return ("resets in %dh %dm"):format(h, m)
end

function LeaderboardScreen.wire(gui: ScreenGui, toast: (text: string, color: Color3) -> ())
	local panel = gui:WaitForChild("LeaderboardPanel") :: Frame
	local tabRow = panel:WaitForChild("TabRow") :: Frame
	local tabTemplate = tabRow:WaitForChild("BoardTab") :: TextButton
	local list = panel:WaitForChild("RankList") :: ScrollingFrame
	local rowTemplate = list:WaitForChild("RankRow") :: Frame
	local emptyLabel = panel:WaitForChild("EmptyLabel") :: TextLabel
	local blurb = panel:WaitForChild("Blurb") :: TextLabel
	local youRow = panel:WaitForChild("YouRow") :: Frame
	local allTimeBtn = (panel:WaitForChild("ScopeRow") :: Frame):WaitForChild("ScopeAllTime") :: TextButton
	local weeklyBtn = (panel:WaitForChild("ScopeRow") :: Frame):WaitForChild("ScopeWeekly") :: TextButton

	;(panel:WaitForChild("CloseButton") :: TextButton).Activated:Connect(function()
		panel.Visible = false
	end)

	local spawned: { Instance } = {}
	local tabs: { [string]: TextButton } = {}
	local boards: { any } = {}
	local activeBoard: string? = nil
	local activeScope = "alltime"
	local busy = false
	local refresh -- fwd decl

	local function clearRows()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
	end

	local function paintScope()
		allTimeBtn.BackgroundColor3 = activeScope == "alltime" and Theme.Accent or Theme.BgLight
		weeklyBtn.BackgroundColor3 = activeScope == "weekly" and Theme.Accent or Theme.BgLight
	end

	local function paintTabs()
		for id, btn in tabs do
			btn.BackgroundColor3 = (id == activeBoard) and Theme.Accent or Theme.BgLight
		end
	end

	local function render(payload: any)
		clearRows()
		blurb.Text = payload.resetsAt and timeLeft(payload.resetsAt) or (payload.blurb or "")
		emptyLabel.Visible = #payload.rows == 0

		for i, row in payload.rows do
			local r = rowTemplate:Clone()
			r.Name = "rank_" .. tostring(row.userId)
			r.Visible = true
			r.LayoutOrder = i
			;(r:WaitForChild("RankLabel") :: TextLabel).Text = "#" .. tostring(row.rank)
			;(r:WaitForChild("NameLabel") :: TextLabel).Text = row.name or ("User " .. tostring(row.userId))
			;(r:WaitForChild("ScoreLabel") :: TextLabel).Text = comma(row.score)
			-- highlight the viewer's own row in the list
			if row.userId == Players.LocalPlayer.UserId then
				r.BackgroundColor3 = Theme.BgLight
			end
			local avatar = r:WaitForChild("Avatar") :: ImageLabel
			task.spawn(function()
				local ok, url = pcall(function()
					return Players:GetUserThumbnailAsync(
						row.userId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size48x48
					)
				end)
				if ok and avatar.Parent then
					avatar.Image = url
				end
			end)
			r.Parent = list
			table.insert(spawned, r)
		end

		-- the pinned own-rank row
		;(youRow:WaitForChild("RankLabel") :: TextLabel).Text = payload.you.rank and ("#" .. tostring(payload.you.rank))
			or "—"
		;(youRow:WaitForChild("NameLabel") :: TextLabel).Text = payload.you.onBoard and "You" or "You (unranked)"
		;(youRow:WaitForChild("ScoreLabel") :: TextLabel).Text = comma(payload.you.score or 0)
	end

	refresh = function()
		if activeBoard == nil or busy then
			return
		end
		busy = true
		local boardId, scope = activeBoard, activeScope
		task.spawn(function()
			local result = Net.invoke("GetLeaderboard", boardId, scope)
			busy = false
			-- a slow reply for a board the player already switched away from
			-- must not overwrite what's on screen
			if result and result.ok and panel.Visible and activeBoard == boardId and activeScope == scope then
				render(result)
			end
		end)
	end

	local function selectBoard(id: string)
		activeBoard = id
		paintTabs()
		refresh()
	end

	local function selectScope(scope: string)
		activeScope = scope
		paintScope()
		refresh()
	end
	allTimeBtn.Activated:Connect(function()
		selectScope("alltime")
	end)
	weeklyBtn.Activated:Connect(function()
		selectScope("weekly")
	end)

	local function buildTabs(list_: { any })
		boards = list_
		for i, board in list_ do
			local btn = tabTemplate:Clone()
			btn.Name = "tab_" .. board.id
			btn.Visible = true
			btn.LayoutOrder = i
			btn.Text = board.name
			btn.Parent = tabRow
			tabs[board.id] = btn
			btn.Activated:Connect(function()
				selectBoard(board.id)
			end)
		end
		if activeBoard == nil and #list_ > 0 then
			selectBoard(list_[1].id)
		end
	end

	function LeaderboardScreen.open()
		Components.closeOtherPanels(panel)
		panel.Visible = true
		paintScope()
		if #boards == 0 then
			task.spawn(function()
				local result = Net.invoke("GetLeaderboardList")
				if result and result.ok then
					buildTabs(result.boards)
				end
			end)
		else
			refresh()
		end
	end

	function LeaderboardScreen.toggle()
		if panel.Visible then
			panel.Visible = false
		else
			LeaderboardScreen.open()
		end
	end
end

return LeaderboardScreen
