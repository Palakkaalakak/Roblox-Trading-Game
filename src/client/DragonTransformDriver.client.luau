--!strict
-- West Transform button. Plays ReplicatedStorage.DragonWestVFXCore forward to become the dragon
-- (swap at the blast beat) and BACKWARDS (t = DURATION - elapsed) to revert.
-- Replaces the Studio-only StarterPlayerScripts.DragonWestTransformVFX driver: disable that one.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dragon"):WaitForChild("DragonConfig"))
local Core = require(ReplicatedStorage:WaitForChild("DragonWestVFXCore")) :: any
local transformR = ReplicatedStorage:WaitForChild("DragonRemotes"):WaitForChild("Transform") :: RemoteEvent

local player = Players.LocalPlayer
local DURATION: number = Core.DURATION
local SWAP_T: number = Config.SWAP_T
local busy = false

local gui = Instance.new("ScreenGui")
gui.Name = "DragonTransformGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -90)
button.Size = UDim2.fromOffset(190, 46)
button.BackgroundColor3 = Color3.fromRGB(255, 118, 0)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBlack
button.TextSize = 20
button.Text = "West Transform"
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke")
stroke.Thickness, stroke.Color = 3, Color3.fromRGB(20, 20, 24)
stroke.Parent = button

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 100
flash.Parent = gui

local function isDragon(): boolean
	local c = player.Character
	return c ~= nil and c:GetAttribute("DragonForm") == true
end

local function refreshText()
	button.Text = if isDragon() then "Revert" else "West Transform"
end

-- Camera / flash curves are pure functions of VFX time u so reverse just mirrors them.
local function smooth(x: number, a: number, b: number): number
	return math.clamp((x - a) / (b - a), 0, 1)
end

local function play(forward: boolean)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and hum and hrp and hrp:IsA("BasePart")) or hum.Health <= 0 then
		return
	end
	busy = true
	-- End any flight, then freeze the player in place for the whole animation.
	player:SetAttribute("DragonCancelFlight", os.clock())
	local prevSpeed, prevJumpP, prevJumpH, prevAnchored = hum.WalkSpeed, hum.JumpPower, hum.JumpHeight, hrp.Anchored
	hum.PlatformStand = false
	hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = 0, 0, 0
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.Anchored = true
	button.Active = false
	button.AutoButtonColor = false

	local groundPos = hrp.Position - Vector3.new(0, hum.HipHeight + hrp.Size.Y / 2, 0)
	local folder = Instance.new("Folder")
	folder.Name = "DragonVFX"
	folder.Parent = workspace
	local state = Core.build(folder, groundPos)
	local cam = workspace.CurrentCamera
	local baseFov = cam.FieldOfView
	local start = os.clock()
	local swapped = false
	local swapAt = if forward then SWAP_T else DURATION - SWAP_T
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local e = os.clock() - start
		local u = if forward then e else DURATION - e
		Core.step(state, math.clamp(u, 0, DURATION), cam.CFrame.Position)

		-- FOV punch-in at the start of the effect, release after the blast.
		local fov = baseFov - 14 * smooth(u, 0, 0.5) + 14 * smooth(u, SWAP_T, DURATION)
		cam.FieldOfView = fov
		-- White flash peaking at the blast.
		flash.BackgroundTransparency = 1 - math.min(smooth(u, SWAP_T - 0.25, SWAP_T), 1 - smooth(u, SWAP_T, SWAP_T + 0.7))
		-- Shake around the blast.
		local amp = 0.5 * math.max(0, 1 - math.abs(u - SWAP_T) / 0.8)
		if amp > 0 then
			cam.CFrame *= CFrame.Angles(math.random() * amp * 0.02, math.random() * amp * 0.02, 0)
		end

		if not swapped and e >= swapAt then
			swapped = true
			transformR:FireServer(forward)
		end
		if e >= DURATION then
			conn:Disconnect()
			Core.destroy(state)
			folder:Destroy()
			cam.FieldOfView = baseFov
			flash.BackgroundTransparency = 1
			if not swapped then
				transformR:FireServer(forward)
			end
			if hrp.Parent then
				hrp.Anchored = prevAnchored
				hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = prevSpeed, prevJumpP, prevJumpH
			end
			if hrp.Parent then
				hrp.Anchored = prevAnchored
				hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = prevSpeed, prevJumpP, prevJumpH
			end
			task.delay(0.3, function()
				busy = false
				button.Active = true
				button.AutoButtonColor = true
				refreshText()
			end)
		end
	end)
end

button.Activated:Connect(function()
	if busy then
		return
	end
	play(not isDragon())
end)

player.CharacterAdded:Connect(function(c)
	busy = false
	c:GetAttributeChangedSignal("DragonForm"):Connect(refreshText)
	refreshText()
end)
refreshText()
