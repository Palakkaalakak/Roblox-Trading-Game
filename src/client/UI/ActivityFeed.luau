--!strict
-- ActivityFeed: an always-on bottom-left ticker of live board settlements
-- (bot-to-bot AND player trades) so the economy is visibly alive at a glance.
-- Server broadcasts one line per completed fill/swap via the BoardActivity
-- RemoteEvent (see TradeBoardService.announce). Self-contained: builds its own
-- ScreenGui, no dependency on the programmatic GuiBuilder.

local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)

local ActivityFeed = {}

local MAX_LINES = 9

function ActivityFeed.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "ActivityTicker"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, 12, 1, -12)
	root.Size = UDim2.fromOffset(340, 190)
	root.BackgroundColor3 = Theme.Bg
	root.BackgroundTransparency = 0.25
	root.BorderSizePixel = 0
	root.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerSmall
	corner.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Stroke
	stroke.Transparency = 0.3
	stroke.Parent = root
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = root

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 16)
	title.Font = Theme.Font
	title.TextSize = 12
	title.TextColor3 = Theme.Gem
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "📈 Market activity"
	title.Parent = root

	local listHolder = Instance.new("Frame")
	listHolder.BackgroundTransparency = 1
	listHolder.Position = UDim2.fromOffset(0, 20)
	listHolder.Size = UDim2.new(1, 0, 1, -20)
	listHolder.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = listHolder

	local seq = 0
	local rows: { TextLabel } = {}

	local function addLine(text: string)
		seq += 1
		local row = Instance.new("TextLabel")
		row.LayoutOrder = -seq -- newest on top
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 16)
		row.Font = Theme.FontLight
		row.TextSize = 11
		row.TextColor3 = Theme.TextPrimary
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.Text = text
		row.Parent = listHolder
		table.insert(rows, 1, row)
		while #rows > MAX_LINES do
			local old = table.remove(rows)
			if old then
				old:Destroy()
			end
		end
		-- fade older lines toward dim
		for i, r in rows do
			r.TextTransparency = math.clamp((i - 1) / MAX_LINES, 0, 0.75)
		end
	end

	Net.on("BoardActivity", function(payload)
		if type(payload) == "table" and type(payload.text) == "string" then
			addLine(payload.text)
		end
	end)
end

return ActivityFeed
