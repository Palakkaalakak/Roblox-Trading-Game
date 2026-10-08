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

-- VFX scale-up. Each frame: restore the raw (unscaled) values Core.step last produced, let it
-- step, then record the new raw values and write scaled ones (about the ground point). Restoring
-- first matters: step may derive one element from another (e.g. rays from the ball's CFrame), so
-- it must never read already-scaled state (that double-scaled the rays off the ball).
local K: number = Config.VFX_SCALE -- recalculated per play so the black sphere always swallows the dragon

local function vmul(v: any): any
	return v * K
end
local function scaleNS(ns: NumberSequence): NumberSequence
	local kps = {}
	for i, kp in ipairs(ns.Keypoints) do
		kps[i] = NumberSequenceKeypoint.new(kp.Time, kp.Value * K, kp.Envelope * K)
	end
	return NumberSequence.new(kps)
end

type Prop = { name: string, scale: (any, Instance, Vector3) -> any }
local PROPS: { { cls: string, props: { Prop } } } = {
	{ cls = "BasePart", props = {
		{ name = "Size", scale = vmul },
		{ name = "CFrame", scale = function(cf: any, _, g: Vector3): any
			return cf.Rotation + (g + (cf.Position - g) * K)
		end },
	} },
	{ cls = "Attachment", props = {
		{ name = "Position", scale = function(p: any, d: Instance, g: Vector3): any
			return if d.Parent and d.Parent:IsA("Terrain") then g + (p - g) * K else p * K
		end },
	} },
	{ cls = "Beam", props = {
		{ name = "Width0", scale = vmul },
		{ name = "Width1", scale = vmul },
		{ name = "CurveSize0", scale = vmul },
		{ name = "CurveSize1", scale = vmul },
	} },
	{ cls = "ParticleEmitter", props = {
		{ name = "Size", scale = scaleNS },
		{ name = "Speed", scale = function(r: any): any
			return NumberRange.new(r.Min * K, r.Max * K)
		end },
		{ name = "Acceleration", scale = vmul },
	} },
	{ cls = "BillboardGui", props = {
		{ name = "Size", scale = function(sz: any): any
			return UDim2.new(sz.X.Scale * K, sz.X.Offset, sz.Y.Scale * K, sz.Y.Offset)
		end },
		{ name = "StudsOffset", scale = vmul },
		{ name = "StudsOffsetWorldSpace", scale = vmul },
	} },
	{ cls = "Light", props = {
		{ name = "Range", scale = function(r: any): any
			return math.min(r * K, 60)
		end },
	} },
}

local raw: { [Instance]: { [string]: any } } = setmetatable({}, { __mode = "k" }) :: any

local function restore()
	for d, props in pairs(raw) do
		if d.Parent then
			for name, v in pairs(props) do
				(d :: any)[name] = v
			end
		end
	end
end

local function rescale(root: Instance, g: Vector3)
	if K == 1 then
		return
	end
	for _, d in ipairs(root:GetDescendants()) do
		for _, entry in ipairs(PROPS) do
			if d:IsA(entry.cls) then
				local r = raw[d]
				if not r then
					r = {}
					raw[d] = r
				end
				for _, pr in ipairs(entry.props) do
					local v = (d :: any)[pr.name]
					r[pr.name] = v;
					(d :: any)[pr.name] = pr.scale(v, d, g)
				end
				break
			end
		end
	end
end

-- Camera zoom: pulled far out for the 5x effect, dragon distance after, original after reverting.
local ORIG_MIN, ORIG_MAX = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
local function setZoom(dist: number?)
	if dist then
		player.CameraMaxZoomDistance = math.max(ORIG_MAX, dist * 2, 500)
		player.CameraMinZoomDistance = dist
	else
		player.CameraMinZoomDistance = ORIG_MIN
		player.CameraMaxZoomDistance = ORIG_MAX
	end
end
local function settleZoom(dragon: boolean)
	if dragon then
		setZoom(Config.DRAGON_ZOOM)
		task.delay(0.15, function()
			player.CameraMinZoomDistance = ORIG_MIN
		end)
	else
		player.CameraMinZoomDistance = ORIG_MIN
		task.delay(0.15, function()
			player.CameraMaxZoomDistance = ORIG_MAX
		end)
	end
end

-- Measures the black sphere at the blast (t = SWAP_T) on an unscaled throwaway build.
local rawSphereR: number? = nil
local function sphereRadius(groundPos: Vector3): number
	if rawSphereR then
		return rawSphereR
	end
	local tmp = Instance.new("Folder")
	tmp.Name = "DragonVFXCalibrate"
	tmp.Parent = workspace
	local r = 25.5 -- module's documented ball radius, used if nothing dark is found
	local ok = pcall(function()
		local st = Core.build(tmp, groundPos)
		Core.step(st, SWAP_T, workspace.CurrentCamera.CFrame.Position)
		local best = 0
		for _, d in ipairs(tmp:GetDescendants()) do
			if d:IsA("BasePart") then
				local c = d.Color
				if (c.R + c.G + c.B) / 3 < 0.12 and d.Transparency < 0.95 then
					best = math.max(best, math.max(d.Size.X, d.Size.Y, d.Size.Z) / 2)
				end
			end
		end
		if best > 4 and best < 200 then
			r = best
		end
		Core.destroy(st)
	end)
	tmp:Destroy()
	if not ok then
		warn("[DragonTransformDriver] sphere calibration failed; assuming radius " .. r)
	end
	rawSphereR = r
	return r
end

local walkSpeed: number? = nil -- the character's normal speed, captured before the first transform

local function play(forward: boolean)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and hum and hrp and hrp:IsA("BasePart")) or hum.Health <= 0 then
		return
	end
	busy = true
	if forward and not walkSpeed then
		walkSpeed = hum.WalkSpeed
	end
	-- End any flight, then freeze the player in place for the whole animation.
	player:SetAttribute("DragonCancelFlight", os.clock())
	local prevJumpP, prevJumpH, prevAnchored = hum.JumpPower, hum.JumpHeight, hrp.Anchored
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
	-- Dragon reach from the torso (design units * scale) must sit inside the sphere with margin.
	local need = Config.DRAGON_EXTENT * Config.SCALE * Config.SPHERE_MARGIN
	K = math.max(Config.VFX_SCALE, need / sphereRadius(groundPos))
	setZoom(math.max(Config.TRANSFORM_ZOOM, sphereRadius(groundPos) * K * 2.4))
	if RunService:IsStudio() then
		print(string.format("[DragonTransformDriver] sphere raw r=%.1f K=%.2f -> sphere r=%.1f, dragon reach=%.1f", sphereRadius(groundPos), K, sphereRadius(groundPos) * K, Config.DRAGON_EXTENT * Config.SCALE))
	end
	local state = Core.build(folder, groundPos)
	rescale(folder, groundPos)
	local cam = workspace.CurrentCamera
	local baseFov = cam.FieldOfView

	-- Reverse: the post-blast part plays back at normal speed, then the sphere part (module time
	-- SWAP_T..0) runs REVERSE_SPHERE_SPEED times faster so the ball collapses quickly.
	local fast: number = Config.REVERSE_SPHERE_SPEED
	local tail = DURATION - SWAP_T
	local total = if forward then DURATION else tail + SWAP_T / fast
	local function uAt(e: number): number
		if forward then
			return e
		elseif e <= tail then
			return DURATION - e
		end
		return SWAP_T - (e - tail) * fast
	end

	local start = os.clock()
	local swapped = false
	local warned = false
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local e = os.clock() - start
		local u = math.clamp(uAt(e), 0, DURATION)
		-- A VFX/rescale error must never stop the swap or the cleanup below, so isolate it.
		local ok, err = pcall(function()
			restore()
			Core.step(state, u, cam.CFrame.Position)
			rescale(folder, groundPos)
		end)
		if not ok and not warned then
			warned = true
			warn("[DragonTransformDriver] VFX step error (swap/cleanup unaffected): " .. tostring(err))
		end

		-- FOV punch-in at the start of the effect, release after the blast.
		cam.FieldOfView = baseFov - 14 * smooth(u, 0, 0.5) + 14 * smooth(u, SWAP_T, DURATION)
		-- White flash peaking at the blast.
		flash.BackgroundTransparency = 1 - math.min(smooth(u, SWAP_T - 0.25, SWAP_T), 1 - smooth(u, SWAP_T, SWAP_T + 0.7))
		-- Shake around the blast.
		local amp = 0.5 * math.max(0, 1 - math.abs(u - SWAP_T) / 0.8)
		if amp > 0 then
			cam.CFrame *= CFrame.Angles(math.random() * amp * 0.02, math.random() * amp * 0.02, 0)
		end

		if not swapped and (if forward then u >= SWAP_T else u <= SWAP_T) then
			swapped = true
			transformR:FireServer(forward)
		end
		if e >= total then
			conn:Disconnect()
			pcall(Core.destroy, state)
			folder:Destroy()
			cam.FieldOfView = baseFov
			flash.BackgroundTransparency = 1
			if not swapped then
				transformR:FireServer(forward)
			end
			if hrp.Parent then
				hrp.Anchored = prevAnchored
				hum.JumpPower, hum.JumpHeight = prevJumpP, prevJumpH
				hum.WalkSpeed = if forward then Config.DRAGON_WALKSPEED else (walkSpeed or 16)
			end
			settleZoom(forward)
			-- Verify the server actually swapped; retry once if the form flag did not flip.
			task.delay(0.6, function()
				if isDragon() ~= forward and player.Character == char then
					warn("[DragonTransformDriver] server did not change form, retrying")
					transformR:FireServer(forward)
				end
			end)
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
	setZoom(nil)
	c:GetAttributeChangedSignal("DragonForm"):Connect(refreshText)
	refreshText()
end)
refreshText()
