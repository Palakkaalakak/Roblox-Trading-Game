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
local LiquidityConfig = require(ReplicatedStorage.Shared.Config.LiquidityConfig)
local Theme = require(script.Parent.Theme)
local Net = require(script.Parent.Parent.Net)

local AdminPanel = {}

-- Wiping every player's economy deserves more than a reflex. THREE clicks, and
-- each one only counts once REQUIRED_GAP_SECONDS has passed since the last --
-- a triple-click, or any impatient burst, does not arm it. Clicking early is
-- not an error, it just does not advance the count; going quiet past the window
-- drops it back to zero.
local REQUIRED_CLICKS = 3
local REQUIRED_GAP_SECONDS = 3
-- Long enough to make three deliberate clicks comfortably, short enough that a
-- half-armed button does not sit waiting forever.
local ARM_WINDOW_SECONDS = 12

function AdminPanel.wire(triggerStarterReveal: ((result: any) -> ())?)
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

	-- Only ever touches the caller's OWN profile (re-rolls their own starter
	-- bundle), so this is a single click, not the 3-click arm the economy
	-- wipe needs. Replays the WHOLE takeover (welcome -> roll -> reveal ->
	-- continue), not just the underlying data, so a design/copy pass on that
	-- screen doesn't need a fresh account each time.
	if triggerStarterReveal then
		local starterBtn = Instance.new("TextButton")
		starterBtn.Name = "ResetStarterButton"
		starterBtn.AnchorPoint = Vector2.new(1, 1)
		starterBtn.Position = UDim2.new(1, -16, 1, -146) -- above the liquidity button (-104)
		starterBtn.Size = UDim2.fromOffset(220, 34)
		starterBtn.BackgroundColor3 = Theme.Accent
		starterBtn.Font = Theme.Font
		starterBtn.TextSize = 12
		starterBtn.TextColor3 = Theme.TextPrimary
		starterBtn.AutoButtonColor = true
		starterBtn.ZIndex = 50
		starterBtn.Text = "DEBUG: RESET STARTER ROLL"
		starterBtn.Parent = gui
		local starterCorner = Instance.new("UICorner")
		starterCorner.CornerRadius = Theme.CornerSmall
		starterCorner.Parent = starterBtn
		local starterStroke = Instance.new("UIStroke")
		starterStroke.Color = Theme.Stroke
		starterStroke.Thickness = 1
		starterStroke.Parent = starterBtn

		starterBtn.Activated:Connect(function()
			starterBtn.Text = "RESETTING…"
			task.spawn(function()
				local res = Net.invoke("DebugResetStarter")
				starterBtn.Text = "DEBUG: RESET STARTER ROLL"
				if res and res.ok then
					triggerStarterReveal(res)
				else
					result.Text = ({
						not_admin = "Admin only.",
					})[res and res.err] or ("Failed: " .. tostring(res and res.err))
					result.TextColor3 = Theme.Bad
				end
			end)
		end)
	end

	-- Liquidity facilitator level: OFF -> LOW -> MEDIUM -> HIGH -> OFF. Any
	-- level above OFF also switches the bot population on server-side. The
	-- server owns the state; this only asks it to move and shows what it says.
	do
		local levels = LiquidityConfig.Levels
		local liqBtn = Instance.new("TextButton")
		liqBtn.Name = "LiquidityButton"
		liqBtn.AnchorPoint = Vector2.new(1, 1)
		liqBtn.Position = UDim2.new(1, -16, 1, -104)
		liqBtn.Size = UDim2.fromOffset(220, 34)
		liqBtn.BackgroundColor3 = Theme.Good
		liqBtn.Font = Theme.Font
		liqBtn.TextSize = 12
		liqBtn.TextColor3 = Theme.Bg
		liqBtn.AutoButtonColor = true
		liqBtn.ZIndex = 50
		liqBtn.Text = "LIQUIDITY: …"
		liqBtn.Parent = gui
		local liqCorner = Instance.new("UICorner")
		liqCorner.CornerRadius = Theme.CornerSmall
		liqCorner.Parent = liqBtn
		local liqStroke = Instance.new("UIStroke")
		liqStroke.Color = Theme.Stroke
		liqStroke.Thickness = 1
		liqStroke.Parent = liqBtn

		local current = "OFF"
		local function paint(level: string)
			current = level
			liqBtn.Text = "LIQUIDITY: " .. level
			-- dim when off so an active level reads at a glance; light text on the
			-- dimmed fill (dark text vanished into it), dark text on the solid one
			local off = level == "OFF"
			liqBtn.BackgroundTransparency = off and 0.55 or 0
			liqBtn.TextColor3 = off and Theme.TextPrimary or Theme.Bg
		end

		local busy = false
		liqBtn.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local nextLevel = levels[1]
			for i, l in levels do
				if l == current then
					nextLevel = levels[(i % #levels) + 1]
					break
				end
			end
			task.spawn(function()
				local res = Net.invoke("DebugSetLiquidityLevel", nextLevel)
				busy = false
				if res and res.ok then
					paint(res.level)
				else
					result.Text = ({ not_admin = "Admin only." })[res and res.err]
						or ("Failed: " .. tostring(res and res.err))
					result.TextColor3 = Theme.Bad
				end
			end)
		end)

		-- sync the label with the server's real level on join
		task.spawn(function()
			local res = Net.invoke("DebugSetLiquidityLevel")
			if res and res.ok then
				paint(res.level)
			end
		end)
	end

	local clicks = 0
	local lastClickAt = 0

	local function disarm()
		clicks = 0
		lastClickAt = 0
		btn.Text = "ADMIN: RESET ECONOMY"
		btn.BackgroundColor3 = Theme.Bad
		result.Text = ""
	end

	local function reset()
		-- Fire and forget. The reset walks every item and every profile ever
		-- seen, so the round trip can take a while; blocking the button on it
		-- left the admin staring at "RESETTING…" with no idea whether anything
		-- was happening. The server does the work regardless of whether we wait,
		-- so report that it STARTED immediately and let the outcome land later.
		disarm()
		result.Text = "Reset started — running in the background."
		result.TextColor3 = Theme.Good
		task.spawn(function()
			local res = Net.invoke("AdminResetEconomy")
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
		local sinceLast = now - lastClickAt

		-- Gone quiet for too long: this is a fresh attempt, not a continuation.
		if clicks > 0 and sinceLast > ARM_WINDOW_SECONDS then
			clicks = 0
		end

		-- Too soon after the previous counted click. Deliberately NOT a reset of
		-- progress -- an admin double-tapping by accident should not have to
		-- start over, they just have to slow down.
		if clicks > 0 and sinceLast < REQUIRED_GAP_SECONDS then
			result.Text = ("Wait %.0fs, then click again (%d/%d)."):format(
				REQUIRED_GAP_SECONDS - sinceLast,
				clicks,
				REQUIRED_CLICKS
			)
			result.TextColor3 = Theme.Warn
			return
		end

		clicks += 1
		lastClickAt = now

		if clicks >= REQUIRED_CLICKS then
			reset()
			return
		end

		btn.Text = ("CLICK %d MORE TIME%s"):format(
			REQUIRED_CLICKS - clicks,
			(REQUIRED_CLICKS - clicks) == 1 and "" or "S"
		)
		result.Text = ("Wipes the ENTIRE economy AND every gem balance, online or not. (%d/%d)"):format(
			clicks,
			REQUIRED_CLICKS
		)
		result.TextColor3 = Theme.Warn

		task.spawn(function()
			task.wait(ARM_WINDOW_SECONDS)
			if clicks > 0 and clicks < REQUIRED_CLICKS and lastClickAt == now then
				disarm()
			end
		end)
	end)
end

return AdminPanel
