--!strict
-- AFK panel + the client half of going AFK.
--
-- The server owns the session, the pad and every gem paid. This file owns two
-- things only: showing the countdown, and holding the camera still while the
-- session lasts.
--
-- GUI stays live on purpose. The body is anchored and the camera is parked, but
-- every panel still opens -- a player parked on a pad can read their inventory,
-- browse the board and answer a trade. Freezing input would make the reward a
-- punishment.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AfkConfig = require(ReplicatedStorage.Shared.Config.AfkConfig)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Net = require(script.Parent.Parent.Net)

local AfkScreen = {}

local player = Players.LocalPlayer
local state: any = { afk = false, nextReward = AfkConfig.rewardFor(1), tickSeconds = AfkConfig.TickSeconds }
local panel: Frame
local status: TextLabel
local timer: TextLabel
local nextReward: TextLabel
local earned: TextLabel
local goBtn: TextButton
local toast: (text: string, color: Color3) -> ()

-- Locally predicted countdown. The server pushes the authoritative number on
-- every tick; between pushes this just counts down so the display does not sit
-- frozen for ten minutes.
local localSecondsLeft = 0
local savedCameraType: Enum.CameraType? = nil
local savedCameraCFrame: CFrame? = nil
local cameraConn: RBXScriptConnection? = nil

local function mmss(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

--------------------------------------------------------------------------------
-- Camera
--------------------------------------------------------------------------------

-- Park the camera where it already is, looking at the player. Not attached to
-- the character: the body is anchored, so a Custom camera would still swing
-- around with the mouse and the scene would read as "controllable but stuck",
-- which is worse than clearly parked.
local function holdCamera()
	local camera = workspace.CurrentCamera
	if camera == nil or cameraConn then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	savedCameraType = camera.CameraType
	savedCameraCFrame = camera.CFrame
	local parked = root and CFrame.lookAt(root.Position + Vector3.new(0, 6, 14), root.Position + Vector3.new(0, 2, 0))
		or camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = parked
	-- Re-assert every frame: something else (a respawn, another screen) can and
	-- will reach for the camera, and a half-held camera is the worst outcome.
	cameraConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = parked
		end
	end)
end

local function releaseCamera()
	if cameraConn then
		cameraConn:Disconnect()
		cameraConn = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = savedCameraType or Enum.CameraType.Custom
		if savedCameraCFrame then
			camera.CFrame = savedCameraCFrame
		end
		camera.CameraSubject = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
	end
	savedCameraType = nil
	savedCameraCFrame = nil
end

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------

local function render()
	if panel == nil then
		return
	end
	if state.afk then
		status.Text = ("Parked on %s. Your rewards keep coming while you are away."):format(
			tostring(state.zoneId or "an AFK pad")
		)
		timer.Text = mmss(localSecondsLeft)
		-- The server describes the rung; the panel never guesses at it, so a
		-- ladder that has not been chosen yet says so instead of promising gems.
		nextReward.Text = ("Next payout: %s"):format(tostring(state.nextReward))
		earned.Text = ("%d payout%s so far"):format(state.ticks or 0, (state.ticks or 0) == 1 and "" or "s")
		goBtn.Text = "Stop being AFK"
		goBtn.BackgroundColor3 = Theme.Bad
	else
		status.Text = ("Park on an AFK pad and collect a reward every %d minutes. Each payout beats the last."):format(
			math.floor(AfkConfig.TickSeconds / 60)
		)
		timer.Text = ""
		nextReward.Text = ("First payout: %s"):format(AfkConfig.describe(AfkConfig.rewardFor(1)))
		earned.Text = ""
		goBtn.Text = "Go AFK"
		goBtn.BackgroundColor3 = Theme.Good
	end
end

local function applyState(next: any)
	local wasAfk = state.afk
	state = next
	localSecondsLeft = next.secondsToNext or 0
	if next.afk and not wasAfk then
		holdCamera()
	elseif wasAfk and not next.afk then
		releaseCamera()
	end
	render()
end

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

function AfkScreen.wire(gui: ScreenGui, toastFn: (text: string, color: Color3) -> ())
	toast = toastFn
	panel = gui:WaitForChild("AfkPanel") :: Frame
	status = panel:WaitForChild("Status") :: TextLabel
	timer = panel:WaitForChild("Timer") :: TextLabel
	nextReward = panel:WaitForChild("NextReward") :: TextLabel
	earned = panel:WaitForChild("Earned") :: TextLabel
	goBtn = panel:WaitForChild("GoButton") :: TextButton
	local closeBtn = panel:WaitForChild("CloseButton") :: TextButton

	closeBtn.Activated:Connect(function()
		panel.Visible = false
	end)

	goBtn.Activated:Connect(function()
		if state.afk then
			local result = Net.invoke("LeaveAfk")
			if result then
				applyState(result)
			end
			return
		end
		local result = Net.invoke("EnterAfk")
		if result == nil then
			return
		end
		if result.ok then
			applyState(result)
			toast("You are AFK. Rewards will keep arriving.", Theme.Good)
		else
			toast(({
				zones_full = "Every AFK pad is full right now — try again shortly.",
				no_zones = "No AFK pads are set up in this place yet.",
				already_afk = "You are already AFK.",
				no_character = "Wait until you have spawned in.",
				loading = "Still loading your profile.",
				disabled = "AFK zones are switched off right now.",
			})[result.err] or ("Couldn't go AFK: " .. tostring(result.err)), Theme.Bad)
		end
	end)

	Net.on("AfkStateChanged", function(next: any)
		if next and next.afk == false and state.afk then
			toast("You are no longer AFK.", Theme.Warn)
		end
		applyState(next)
	end)

	task.spawn(function()
		local result = Net.invoke("GetAfkState")
		if result then
			applyState(result)
		end
	end)

	-- Local countdown between server pushes. One second, and only while the
	-- panel is actually on screen: an unopened panel has nothing to animate.
	task.spawn(function()
		while true do
			task.wait(1)
			if state.afk and localSecondsLeft > 0 then
				localSecondsLeft -= 1
				if panel.Visible then
					render()
				end
			end
		end
	end)

	render()
end

function AfkScreen.open()
	if panel == nil then
		return
	end
	Components.closeOtherPanels(panel)
	panel.Visible = true
	task.spawn(function()
		local result = Net.invoke("GetAfkState")
		if result then
			applyState(result)
		end
	end)
end

function AfkScreen.toggle()
	if panel and panel.Visible then
		panel.Visible = false
		return
	end
	AfkScreen.open()
end

return AfkScreen
