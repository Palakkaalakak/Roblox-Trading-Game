--!strict
-- AdminPanel: a standalone floating admin control, not nested inside any
-- other screen. Fires the EXISTING AdminResetEconomy (every item reserve
-- back to full, every player's copies destroyed -- online AND offline,
-- reached via DataService.allSeenUserIds/wipeOfflineProfile -- leaderboard
-- rows cleared, generation bumped for other servers -- see EconomyService).
-- This panel is a UI front end for that remote, not a new reset mechanism.
--
-- Visible only to DebugConfig.AdminUserNames (presentation -- a client can't
-- be trusted about who it is); the remote itself is gated server-side on
-- DebugConfig.AdminUserIds regardless, same as every other admin tool.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)

local AdminPanel = {}

-- A blind click on something that resets every online player's economy is
-- worth one extra step. Arms on the first click, fires on a second click
-- within this window; anything after the window re-arms instead of firing.
local CONFIRM_WINDOW_SECONDS = 4

function AdminPanel.wire()
	if not (DebugConfig.AdminUserNames and DebugConfig.AdminUserNames[Players.LocalPlayer.Name]) then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanel"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local btn = Instance.new("TextButton")
	btn.Name = "ResetEconomyButton"
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.Position = UDim2.new(1, -16, 1, -16)
	btn.Size = UDim2.fromOffset(220, 40)
	btn.BackgroundColor3 = Theme.Bad
	btn.Font = Theme.Font
	btn.TextSize = 13
	btn.TextColor3 = Theme.TextPrimary
	btn.AutoButtonColor = true
	btn.ZIndex = 50
	btn.Text = "ADMIN: RESET ECONOMY"
	btn.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerSmall
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Stroke
	stroke.Thickness = 1
	stroke.Parent = btn

	local result = Instance.new("TextLabel")
	result.Name = "Result"
	result.AnchorPoint = Vector2.new(1, 1)
	result.Position = UDim2.new(1, -16, 1, -60)
	result.Size = UDim2.fromOffset(280, 18)
	result.BackgroundTransparency = 1
	result.Font = Theme.FontLight
	result.TextSize = 11
	result.TextColor3 = Theme.TextDim
	result.TextXAlignment = Enum.TextXAlignment.Right
	result.TextTruncate = Enum.TextTruncate.AtEnd
	result.ZIndex = 50
	result.Text = ""
	result.Parent = gui

	local armedAt: number? = nil

	local function reset()
		btn.Text = "RESETTING…"
		btn.BackgroundColor3 = Theme.BgLight
		result.Text = ""
		task.spawn(function()
			local res = Net.invoke("AdminResetEconomy")
			btn.Text = "ADMIN: RESET ECONOMY"
			btn.BackgroundColor3 = Theme.Bad
			if res and res.ok then
				result.Text = ("Reset %d items, wiped %d player(s)."):format(res.reset or 0, res.wiped or 0)
				result.TextColor3 = Theme.Good
			else
				result.Text = ({
					not_admin = "Admin only.",
				})[res and res.err] or ("Failed: " .. tostring(res and res.err))
				result.TextColor3 = Theme.Bad
			end
		end)
	end

	btn.Activated:Connect(function()
		local now = os.clock()
		if armedAt and (now - armedAt) < CONFIRM_WINDOW_SECONDS then
			armedAt = nil
			reset()
			return
		end
		armedAt = now
		btn.Text = "CLICK AGAIN TO CONFIRM"
		result.Text = "Resets the ENTIRE economy for every player, online or not."
		result.TextColor3 = Theme.Warn
		task.spawn(function()
			task.wait(CONFIRM_WINDOW_SECONDS)
			if armedAt == now then
				armedAt = nil
				btn.Text = "ADMIN: RESET ECONOMY"
				result.Text = ""
			end
		end)
	end)
end

return AdminPanel
