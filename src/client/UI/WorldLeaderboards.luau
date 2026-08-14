--!strict
-- WorldLeaderboards: fills the physical leaderboard models standing in the
-- world from the same data the Leaderboards panel uses.
--
-- The models are built in the place (geometry only — no scripts of their own).
-- Each carries a `BoardId` attribute naming which board it shows, so this binds
-- by attribute rather than by model name: boards can be moved, renamed or
-- duplicated in Studio without touching code.
--
-- Rendered CLIENT-side on purpose. The rows differ per viewer (your own row is
-- highlighted) and a SurfaceGui full of frames replicated from the server would
-- cost bandwidth for something every client can draw itself from one remote
-- call. Refreshes on a slow timer — a leaderboard changing every few minutes is
-- fine, and the server already caches reads per board.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)
local Format = require(game:GetService("ReplicatedStorage").Shared.Util.Format)

local WorldLeaderboards = {}

-- Boards are a live scoreboard, so they tick rather than sitting stale for the
-- best part of a minute. Reads are served from the service's per-board cache,
-- so a shorter interval costs almost nothing.
local REFRESH_SECONDS = 8
local ROW_HEIGHT = 44
local MAX_ROWS = 25 -- what physically fits on the board face
-- Column budget. The board face renders at 50 px/stud, so the scroll is ~478 px
-- wide — every fixed column here is taken straight out of the name's space,
-- which is why the score column is kept tight now that scores are abbreviated
-- ("1.2M" needs nowhere near the room "1,234,567" did).
local RANK_W = 46
local AVATAR_W = ROW_HEIGHT - 10
local SCORE_W = 120

-- Abbreviated: a board is read from across the room, and a top portfolio runs
-- into the millions. Rarest is a synthetic scarcity score, so it carries no
-- unit rather than a misleading one.
local function formatScore(score: number, unit: string): string
	if unit == "gems" then
		return Format.abbrev(score) .. " gems"
	elseif unit == "trades" then
		return Format.abbrev(score) .. (score == 1 and " trade" or " trades")
	elseif unit == "scarcity" then
		-- The stored score is 1000000/totalSupply, an ordering key for the
		-- OrderedDataStore — printing it raw showed "20.8k" next to a name and
		-- read as a gem value nobody could find on any item. Invert it back to
		-- the number the player actually recognises: how many exist.
		if score <= 0 then
			return "—"
		end
		return Format.comma(math.floor(1000000 / score + 0.5)) .. " in existence"
	end
	return Format.abbrev(score)
end

local function findBoards(): { { model: Instance, boardId: string, scroll: ScrollingFrame, title: TextLabel? } }
	local out = {}
	for _, model in workspace:GetChildren() do
		local boardId = model:GetAttribute("BoardId")
		if typeof(boardId) == "string" then
			local displayer = model:FindFirstChild("LeaderboardDisplayer")
			local sg = displayer and displayer:FindFirstChildOfClass("SurfaceGui")
			local frame = sg and sg:FindFirstChild("Frame")
			local scroll = frame and frame:FindFirstChild("Frame")
			if scroll and scroll:IsA("ScrollingFrame") then
				table.insert(out, {
					model = model,
					boardId = boardId,
					scroll = scroll,
					title = frame:FindFirstChild("Display") :: TextLabel?,
				})
			end
		end
	end
	return out
end

-- Avatar headshots, fetched once per userId and cached for the session. The
-- call yields, so rows render immediately with an empty image and the portrait
-- fills in when it arrives — a slow thumbnail must never stall the board.
local avatarCache: { [number]: string } = {}

local function applyAvatar(image: ImageLabel, userId: number)
	local cached = avatarCache[userId]
	if cached then
		image.Image = cached
		return
	end
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)
		if ok and url then
			avatarCache[userId] = url
			if image.Parent then
				image.Image = url
			end
		end
	end)
end

local function makeRow(rank: number, name: string, score: string, isYou: boolean, userId: number): Frame
	local row = Instance.new("Frame")
	row.Name = "row_" .. rank
	row.LayoutOrder = rank
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = isYou and Theme.Accent or Theme.Bg
	row.BackgroundTransparency = isYou and 0.15 or 0.45
	row.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = row

	local rankLbl = Instance.new("TextLabel")
	rankLbl.Name = "Rank"
	rankLbl.BackgroundTransparency = 1
	rankLbl.Position = UDim2.fromOffset(8, 0)
	rankLbl.Size = UDim2.fromOffset(RANK_W, ROW_HEIGHT)
	rankLbl.Font = Theme.Font
	rankLbl.TextSize = 26
	-- top three get the podium colours everyone already reads at a glance
	rankLbl.TextColor3 = rank == 1 and Color3.fromRGB(255, 215, 90)
		or rank == 2 and Color3.fromRGB(205, 210, 220)
		or rank == 3 and Color3.fromRGB(215, 145, 85)
		or Theme.TextDim
	rankLbl.TextXAlignment = Enum.TextXAlignment.Left
	rankLbl.Text = "#" .. rank
	rankLbl.Parent = row

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundColor3 = Theme.BgLight
	avatar.BorderSizePixel = 0
	avatar.Position = UDim2.fromOffset(8 + RANK_W + 4, 5)
	avatar.Size = UDim2.fromOffset(AVATAR_W, AVATAR_W)
	avatar.Image = ""
	avatar.Parent = row
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0) -- round portrait
	avatarCorner.Parent = avatar
	applyAvatar(avatar, userId)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "Name"
	nameLbl.BackgroundTransparency = 1
	-- name gets everything left over between the avatar and the score column,
	-- so a full-length username fits instead of being truncated early
	local nameX = 8 + RANK_W + 4 + AVATAR_W + 8
	nameLbl.Position = UDim2.fromOffset(nameX, 0)
	nameLbl.Size = UDim2.new(1, -(nameX + SCORE_W + 12), 0, ROW_HEIGHT)
	nameLbl.Font = Theme.Font
	nameLbl.TextSize = 24
	nameLbl.TextColor3 = Theme.TextPrimary
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.Text = name
	nameLbl.Parent = row

	local scoreLbl = Instance.new("TextLabel")
	scoreLbl.Name = "Score"
	scoreLbl.BackgroundTransparency = 1
	scoreLbl.AnchorPoint = Vector2.new(1, 0)
	scoreLbl.Position = UDim2.new(1, -12, 0, 0)
	scoreLbl.Size = UDim2.fromOffset(SCORE_W, ROW_HEIGHT)
	scoreLbl.Font = Theme.Font
	scoreLbl.TextSize = 24
	scoreLbl.TextColor3 = Theme.Gem
	scoreLbl.TextXAlignment = Enum.TextXAlignment.Right
	scoreLbl.Text = score
	scoreLbl.Parent = row

	return row
end

local function renderBoard(board: any, payload: any)
	local scroll = board.scroll
	for _, c in scroll:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end

	if board.title and payload.name then
		board.title.Text = payload.name
	end

	local myId = Players.LocalPlayer.UserId
	local shown = 0
	for _, entry in payload.rows do
		if shown >= MAX_ROWS then
			break
		end
		shown += 1
		local row = makeRow(
			entry.rank,
			entry.name or ("User " .. tostring(entry.userId)),
			formatScore(entry.score, payload.unit),
			entry.userId == myId,
			entry.userId
		)
		row.Parent = scroll
	end

	if shown == 0 then
		local empty = Instance.new("TextLabel")
		empty.Name = "Empty"
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
		empty.Font = Theme.FontLight
		empty.TextSize = 22
		empty.TextColor3 = Theme.TextDim
		empty.Text = "No scores yet — be the first!"
		empty.Parent = scroll
	end

	scroll.CanvasSize = UDim2.fromOffset(0, shown * (ROW_HEIGHT + 4) + 8)
end

function WorldLeaderboards.start()
	task.spawn(function()
		-- The boards are ordinary workspace models, so on a fresh join they may
		-- not have replicated yet when this runs. Re-scan until they show up
		-- rather than giving up on the first empty look, which left the boards
		-- permanently blank for anyone whose client started before replication.
		local boards = findBoards()
		local waited = 0
		while #boards == 0 and waited < 30 do
			task.wait(1)
			waited += 1
			boards = findBoards()
		end
		if #boards == 0 then
			return -- no physical boards in this place; the panel still works
		end

		while true do
			for _, board in boards do
				task.spawn(function()
					local result = Net.invoke("GetLeaderboard", board.boardId, "alltime")
					if result and result.ok then
						renderBoard(board, result)
					end
				end)
			end
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return WorldLeaderboards
