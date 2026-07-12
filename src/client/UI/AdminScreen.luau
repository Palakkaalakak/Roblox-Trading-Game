--!strict
-- AdminScreen: TEMPORARY admin-only bot inspector. Press F8 to toggle. Pulls
-- per-bot data from the server (GetBotData, gated to DebugConfig.AdminUserIds)
-- and shows an aggregate header + a sortable-by-worth table of every bot:
-- archetype, gems, inventory value, net worth, and what it currently desires.
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
	panel.Size = UDim2.fromOffset(640, 560)
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
	title.Size = UDim2.fromOffset(400, 22)
	title.Font = Theme.Font
	title.TextSize = 16
	title.TextColor3 = Theme.TextPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "🤖 Bot Inspector (admin)"
	title.Parent = panel

	local agg = Instance.new("TextLabel")
	agg.BackgroundTransparency = 1
	agg.Position = UDim2.fromOffset(14, 34)
	agg.Size = UDim2.new(1, -28, 0, 32)
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

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(14, 70)
	header.Size = UDim2.new(1, -28, 0, 16)
	header.Font = Theme.Font
	header.TextSize = 11
	header.TextColor3 = Theme.TextDim
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "  BOT            ARCH         GEMS   INVVAL   WORTH   WANTS"
	header.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(10, 90)
	list.Size = UDim2.new(1, -20, 1, -100)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local ll = Instance.new("UIListLayout")
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Padding = UDim.new(0, 2)
	ll.Parent = list

	local rowsHolder: { Instance } = {}

	local function render(data: any)
		local archParts = {}
		for arch, n in data.archCounts do
			table.insert(archParts, ("%s %d"):format(arch, n))
		end
		table.sort(archParts)
		agg.Text = ("%d bots · total gems %d · total net worth %d\n%s"):format(
			data.count, data.totalGems, data.totalWorth, table.concat(archParts, "  ·  "))

		for _, inst in rowsHolder do
			inst:Destroy()
		end
		table.clear(rowsHolder)

		for i, b in data.bots do
			local row = Instance.new("TextLabel")
			row.LayoutOrder = i
			row.BackgroundColor3 = (i % 2 == 0) and Theme.Bg or Theme.BgLight
			row.BackgroundTransparency = 0.3
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, 0, 0, 18)
			row.Font = Theme.FontLight
			row.TextSize = 11
			row.TextColor3 = ARCH_COLOR[b.archetype] or Theme.TextPrimary
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextTruncate = Enum.TextTruncate.AtEnd
			local shortName = b.name:gsub(" %[bot%]", "")
			local wants = #b.desired > 0 and table.concat(b.desired, ", ") or "—"
			row.Text = ("  %-14s %-12s %5d  %6d  %6d   %s"):format(
				shortName:sub(1, 14), b.archetype, b.gems, b.invValue, b.worth, wants)
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

	-- auto-refresh while open
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
