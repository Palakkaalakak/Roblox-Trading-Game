--!strict
-- Dragon client: animates every WestDragon, double-tap-Space flight, R fireball.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Dragon = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dragon")
local DragonRig = require(Dragon:WaitForChild("DragonRig"))
local Config = require(Dragon:WaitForChild("DragonConfig"))
local remotes = ReplicatedStorage:WaitForChild("DragonRemotes")
local flightR = remotes:WaitForChild("Flight") :: RemoteEvent
local fireballR = remotes:WaitForChild("Fireball") :: RemoteEvent

local player = Players.LocalPlayer
local rigs: { [Model]: DragonRig.Rig } = {}
local pitches: { [Model]: number } = {}

local function getRig(model: Model): DragonRig.Rig?
	local r = rigs[model]
	if not r then
		r = DragonRig.wrap(model)
		if r then
			rigs[model] = r
		end
	end
	return r
end

-- Flight state (local player only).
local flying = false
local lv: LinearVelocity? = nil
local ao: AlignOrientation? = nil
local lastTap = 0
local lastFire = 0

local function dragonChar(): (Model?, BasePart?, Humanoid?)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if char and char:GetAttribute("DragonForm") and hrp and hrp:IsA("BasePart") and hum then
		return char, hrp, hum
	end
	return nil, nil, nil
end

local function stopFlight()
	if not flying then
		return
	end
	flying = false
	if lv then
		lv:Destroy()
		lv = nil
	end
	if ao then
		ao:Destroy()
		ao = nil
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
	end
	flightR:FireServer(false)
end

local function startFlight()
	local _, hrp, hum = dragonChar()
	if not (hrp and hum) then
		return
	end
	flying = true
	hum.PlatformStand = true
	local att = Instance.new("Attachment")
	att.Name = "DragonFlightAtt"
	att.Parent = hrp
	local v = Instance.new("LinearVelocity")
	v.Attachment0 = att
	v.RelativeTo = Enum.ActuatorRelativeTo.World
	v.MaxForce = math.huge
	v.VectorVelocity = Vector3.new(0, 8, 0)
	v.Parent = hrp
	lv = v
	local a = Instance.new("AlignOrientation")
	a.Mode = Enum.OrientationAlignmentMode.OneAttachment
	a.Attachment0 = att
	a.RigidityEnabled = false
	a.MaxTorque = math.huge
	a.Responsiveness = 18
	a.CFrame = hrp.CFrame.Rotation
	a.Parent = hrp
	ao = a
	flightR:FireServer(true)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space then
		local now = os.clock()
		if now - lastTap <= Config.DOUBLE_TAP then
			lastTap = 0
			if flying then
				stopFlight()
			elseif dragonChar() then
				startFlight()
			end
		else
			lastTap = now
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		local char = dragonChar()
		local head = char and char:FindFirstChild("WestDragon") and char.WestDragon:FindFirstChild("Head")
		if not (char and head and head:IsA("BasePart")) or os.clock() - lastFire < Config.FIREBALL.COOLDOWN then
			return
		end
		lastFire = os.clock()
		local cam = workspace.CurrentCamera
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { char }
		params.FilterType = Enum.RaycastFilterType.Exclude
		local look = cam.CFrame.LookVector
		local hit = workspace:Raycast(cam.CFrame.Position, look * 500, params)
		local target = if hit then hit.Position else cam.CFrame.Position + look * 500
		fireballR:FireServer((target - head.Position).Unit)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local now = workspace:GetServerTimeNow()

	-- Local flight control.
	if flying then
		local char, hrp = dragonChar()
		if not (char and hrp and lv and ao) then
			stopFlight()
		else
			local cam = workspace.CurrentCamera.CFrame
			local flat = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
			if flat.Magnitude < 0.01 then
				flat = hrp.CFrame.LookVector
			end
			local move = Vector3.zero
			local U = UserInputService
			if U:IsKeyDown(Enum.KeyCode.W) then move += cam.LookVector end
			if U:IsKeyDown(Enum.KeyCode.S) then move -= cam.LookVector end
			if U:IsKeyDown(Enum.KeyCode.D) then move += cam.RightVector end
			if U:IsKeyDown(Enum.KeyCode.A) then move -= cam.RightVector end
			local vel = if move.Magnitude > 0.01 then move.Unit * Config.FLY_SPEED else Vector3.zero
			if U:IsKeyDown(Enum.KeyCode.Space) then vel += Vector3.new(0, Config.FLY_VERTICAL, 0) end
			if U:IsKeyDown(Enum.KeyCode.LeftShift) then vel -= Vector3.new(0, Config.FLY_VERTICAL, 0) end
			lv.VectorVelocity = lv.VectorVelocity:Lerp(vel, math.clamp(dt * 6, 0, 1))
			ao.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)

			-- Land when descending onto ground.
			if lv.VectorVelocity.Y < -1 then
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = { char }
				params.FilterType = Enum.RaycastFilterType.Exclude
				if workspace:Raycast(hrp.Position, Vector3.new(0, -7, 0), params) then
					stopFlight()
				end
			end
		end
	end

	-- Animate all dragons (replicated models, local time).
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local model = char and char:FindFirstChild("WestDragon")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if model and model:IsA("Model") and hrp and hrp:IsA("BasePart") then
			local rig = getRig(model)
			if rig then
				local v = hrp.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				local isFlying = char:GetAttribute("DragonFlying") == true
				local target = 0
				if isFlying then
					target = math.clamp(-v.Y / 90, -0.5, 0.6) + math.clamp(speed / Config.FLY_SPEED, 0, 1) * 0.3
				end
				local cur = pitches[model] or 0
				cur += (target - cur) * math.clamp(dt * 5, 0, 1)
				pitches[model] = cur
				DragonRig.animate(rig, t, speed, isFlying, cur)
				local ft = char:GetAttribute("DragonFireTime")
				local since = if typeof(ft) == "number" then now - ft else 99
				DragonRig.setJaw(rig, if since >= 0 and since < 0.4 then math.sin(since / 0.4 * math.pi) * 0.6 else 0)
			end
		end
	end
end)
