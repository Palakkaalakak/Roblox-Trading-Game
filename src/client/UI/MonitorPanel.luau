--!strict
-- MonitorPanel: rudimentary admin stats readout (NOT pretty, on purpose).
--
-- The server mirrors its counters onto ReplicatedStorage attributes because the
-- console buffer evicts high-volume lines. This just lists every Sim*/Liq*/Bot*/
-- Eco* attribute, grouped, so any new stat the server publishes shows up here
-- with no client change. Admin-only, toggled by a small STATS button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)

local MonitorPanel = {}

local GROUPS = {
	{ "LIQUIDITY", "Liq" },
	{ "SIM PLAYERS", "Sim" },
	{ "OLD BOTS", "Bot" },
	{ "ECONOMY", "Eco" },
}

function MonitorPanel.wire()
	if not (DebugConfig.AdminUserNames and DebugConfig.AdminUserNames[Players.LocalPlayer.Name]) then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "MonitorPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 0)
	toggle.Position = UDim2.new(1, -16, 0, 200)
	toggle.Size = UDim2.fromOffset(70, 26)
	toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.Font = Enum.Font.Code
	toggle.TextSize = 13
	toggle.Text = "STATS"
	toggle.Parent = gui

	local frame = Instance.new("ScrollingFrame")
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -16, 0, 232)
	frame.Size = UDim2.fromOffset(440, 460)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.Visible = false
	frame.Parent = gui

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -10, 0, 0)
	text.Position = UDim2.fromOffset(5, 5)
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Code
	text.TextSize = 12
	text.TextColor3 = Color3.fromRGB(210, 220, 230)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextWrapped = true
	text.RichText = true
	text.Parent = frame

	-- client frame times, so a stutter shows up next to the stats that may cause it
	local frames, worst, since = 0, 0, os.clock()
	local fps, worstMs = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		frames += 1
		worst = math.max(worst, dt)
		if os.clock() - since >= 2 then
			fps = math.floor(frames / (os.clock() - since))
			worstMs = math.floor(worst * 1000)
			frames, worst, since = 0, 0, os.clock()
		end
	end)

	local function render()
		local attrs = ReplicatedStorage:GetAttributes()
		local lines = { ("<b>CLIENT</b>\n  fps = %d   worst frame (2s) = %dms"):format(fps, worstMs) }
		for _, g in GROUPS do
			local keys = {}
			for k in attrs do
				if k:sub(1, #g[2]) == g[2] then
					table.insert(keys, k)
				end
			end
			table.sort(keys)
			if #keys > 0 then
				table.insert(lines, ("\n<b>%s</b>"):format(g[1]))
				for _, k in keys do
					table.insert(lines, ("  %s = %s"):format(k, tostring(attrs[k])))
				end
			end
		end
		-- derived: the number that decides whether the facilitator has a job
		local filled, expired = attrs.SimFilled or 0, attrs.SimExpired or 0
		if filled + expired > 0 then
			table.insert(lines, ("\n<b>DERIVED</b>\n  unfilled%% = %d  (target 40-60)"):format(math.floor(expired / (filled + expired) * 100)))
		end
		text.Text = table.concat(lines, "\n")
	end

	toggle.Activated:Connect(function()
		frame.Visible = not frame.Visible
		if frame.Visible then
			render()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if frame.Visible then
				render()
			end
		end
	end)
end

return MonitorPanel
