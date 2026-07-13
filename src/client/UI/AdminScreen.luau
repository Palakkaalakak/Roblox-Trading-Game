--!strict
-- AdminScreen: TEMPORARY admin-only bot inspector. Press F8 to toggle. Pulls
-- per-bot data from the server (GetBotData, gated to DebugConfig.AdminUserIds)
-- and renders a real SPREADSHEET: a monospace grid with a fixed header, per-
-- column auto-sized widths, and vertical dividers, sorted by net worth.
-- Self-contained (builds its own ScreenGui); delete with the bot tooling for
-- release.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)

local AdminScreen = {}

local ARCH_COLOR: { [string]: Color3 } = {
	maker = Theme.Gem,
	fundamentalist = Theme.Good,
	momentum = Theme.Warn,
	speculator = Theme.Bad,
	crafter = Theme.Accent,
	collector = Color3.fromRGB(186, 104, 200),
}

-- monospace grid metrics
local MONO = Enum.Font.Code
local CELL_SIZE = 13
local CHAR_W = 7.8 -- px per glyph at CELL_SIZE for Code font (approx)
local ROW_H = 18
local WANTS_CAP = 34

-- column spec: title, key, right-aligned?
local COLUMNS = {
	{ title = "#", align = "r" },
	{ title = "Bot", align = "l" },
	{ title = "Archetype", align = "l" },
	{ title = "Gems", align = "r" },
	{ title = "InvVal", align = "r" },
	{ title = "Worth", align = "r" },
	{ title = "Wants", align = "l" },
}

local function pad(s: string, w: number, right: boolean): string
	local n = w - #s
	if n <= 0 then
		return s
	end
	local fill = string.rep(" ", n)
	return right and (fill .. s) or (s .. fill)
end

function AdminScreen.start(toast: ((text: string, color: Color3) -> ())?)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminBotPanel"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Enabled = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(760, 580)
	panel.BackgroundColor3 = Theme.Panel
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Stroke
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 10)
	title.Size = UDim2.fromOffset(420, 22)
	title.Font = Theme.Font
	title.TextSize = 16
	title.TextColor3 = Theme.TextPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "🤖 Bot Inspector (admin · F8)"
	title.Parent = panel

	local agg = Instance.new("TextLabel")
	agg.BackgroundTransparency = 1
	agg.Position = UDim2.fromOffset(14, 34)
	agg.Size = UDim2.new(1, -28, 0, 30)
	agg.Font = Theme.FontLight
	agg.TextSize = 12
	agg.TextColor3 = Theme.TextDim
	agg.TextXAlignment = Enum.TextXAlignment.Left
	agg.TextYAlignment = Enum.TextYAlignment.Top
	agg.TextWrapped = true
	agg.Text = "Loading…"
	agg.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -8, 0, 8)
	closeBtn.Size = UDim2.fromOffset(26, 26)
	closeBtn.BackgroundColor3 = Theme.Bad
	closeBtn.Font = Theme.Font
	closeBtn.TextSize = 14
	closeBtn.TextColor3 = Theme.TextPrimary
	closeBtn.Text = "✕"
	closeBtn.Parent = panel
	local cc = Instance.new("UICorner")
	cc.CornerRadius = Theme.CornerSmall
	cc.Parent = closeBtn

	local refreshBtn = Instance.new("TextButton")
	refreshBtn.AnchorPoint = Vector2.new(1, 0)
	refreshBtn.Position = UDim2.new(1, -40, 0, 8)
	refreshBtn.Size = UDim2.fromOffset(90, 26)
	refreshBtn.BackgroundColor3 = Theme.Accent
	refreshBtn.Font = Theme.Font
	refreshBtn.TextSize = 12
	refreshBtn.TextColor3 = Theme.TextPrimary
	refreshBtn.Text = "Refresh"
	refreshBtn.Parent = panel
	local rc = Instance.new("UICorner")
	rc.CornerRadius = Theme.CornerSmall
	rc.Parent = refreshBtn

	-- header (monospace, fixed) + a horizontal rule under it
	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(14, 66)
	header.Size = UDim2.new(1, -28, 0, ROW_H)
	header.Font = MONO
	header.TextSize = CELL_SIZE
	header.TextColor3 = Theme.TextPrimary
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = ""
	header.Parent = panel

	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = Theme.Stroke
	rule.BorderSizePixel = 0
	rule.Position = UDim2.fromOffset(14, 66 + ROW_H)
	rule.Size = UDim2.new(1, -28, 0, 1)
	rule.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(14, 66 + ROW_H + 3)
	list.Size = UDim2.new(1, -28, 1, -(66 + ROW_H + 12))
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.XY
	list.ScrollingDirection = Enum.ScrollingDirection.XY
	list.Parent = panel
	local ll = Instance.new("UIListLayout")
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Padding = UDim.new(0, 1)
	ll.Parent = list

	local rowsHolder: { Instance } = {}

	local function render(data: any)
		local archParts = {}
		for arch, n in data.archCounts do
			table.insert(archParts, ("%s %d"):format(arch, n))
		end
		table.sort(archParts)
		agg.Text = ("%d bots · total gems %d · total net worth %d\n%s"):format(
			data.count, data.totalGems, data.totalWorth, table.concat(archParts, "   "))

		-- build cell strings for every row, then size each column to its widest
		local grid = {}
		for i, b in data.bots do
			local shortName = (b.name:gsub(" %[bot%]", ""))
			local wants = #b.desired > 0 and table.concat(b.desired, ", ") or "—"
			if #wants > WANTS_CAP then
				wants = wants:sub(1, WANTS_CAP - 1) .. "…"
			end
			grid[i] = {
				tostring(i), shortName, b.archetype,
				tostring(b.gems), tostring(b.invValue), tostring(b.worth), wants,
				_color = ARCH_COLOR[b.archetype] or Theme.TextPrimary,
			}
		end

		local widths = {}
		for c, col in COLUMNS do
			widths[c] = #col.title
		end
		for _, cells in grid do
			for c = 1, #COLUMNS do
				widths[c] = math.max(widths[c], #cells[c])
			end
		end

		local function line(cells: { string }): string
			local parts = {}
			for c, col in COLUMNS do
				parts[c] = pad(cells[c], widths[c], col.align == "r")
			end
			return table.concat(parts, " │ ")
		end

		local headerCells = {}
		for c, col in COLUMNS do
			headerCells[c] = col.title
		end
		header.Text = line(headerCells)
		local totalChars = #header.Text
		local rowWidthPx = math.ceil(totalChars * CHAR_W) + 8

		for _, inst in rowsHolder do
			inst:Destroy()
		end
		table.clear(rowsHolder)

		for i, cells in grid do
			local row = Instance.new("TextLabel")
			row.LayoutOrder = i
			row.BackgroundColor3 = (i % 2 == 0) and Theme.Bg or Theme.BgLight
			row.BackgroundTransparency = 0.35
			row.BorderSizePixel = 0
			row.Size = UDim2.fromOffset(rowWidthPx, ROW_H)
			row.Font = MONO
			row.TextSize = CELL_SIZE
			row.TextColor3 = cells._color
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Text = line(cells)
			row.Parent = list
			table.insert(rowsHolder, row)
		end
	end

	local function refresh()
		task.spawn(function()
			local result = Net.invoke("GetBotData")
			if result.ok then
				render(result.data)
			else
				agg.Text = "Not authorized (admin only)."
				if toast then
					toast("Bot inspector is admin-only.", Theme.Bad)
				end
			end
		end)
	end

	closeBtn.Activated:Connect(function()
		gui.Enabled = false
	end)
	refreshBtn.Activated:Connect(refresh)

	task.spawn(function()
		while true do
			task.wait(5)
			if gui.Enabled then
				refresh()
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end
		if input.KeyCode == Enum.KeyCode.F8 then
			gui.Enabled = not gui.Enabled
			if gui.Enabled then
				refresh()
			end
		end
	end)
end

return AdminScreen
