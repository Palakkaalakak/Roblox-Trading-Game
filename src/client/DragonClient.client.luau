--!strict
-- Dragon client: animates every WestDragon, double-tap-Space flight, hold-R charged fireball + its VFX.
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
local chargeR = remotes:WaitForChild("Charge") :: RemoteEvent
local fxR = remotes:WaitForChild("FireballFX") :: RemoteEvent
local DragonFX = require(Dragon:WaitForChild("DragonFX"))
local FB = Config.FIREBALL

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
local lastFire = -math.huge
local charging = false
local chargeStart = 0
local charges: { [Model]: { stop: () -> () } } = {}

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

player:GetAttributeChangedSignal("DragonCancelFlight"):Connect(stopFlight)

-- Fireball: tap R = base shot; hold R to charge (auto-fires at MAX_CHARGE). Server computes the
-- charge from its own DragonChargeStart attribute; this only sends start + aim direction.
local function aimDir(char: Model, from: Vector3): Vector3
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, DragonFX.root() }
	local m = UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(m.X, m.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
	local target = if hit then hit.Position else ray.Origin + ray.Direction * 1500
	local d = target - from
	return if d.Magnitude > 0.01 then d.Unit else ray.Direction
end

local function releaseCharge()
	if not charging then
		return
	end
	charging = false
	local char = dragonChar()
	local dragon = char and char:FindFirstChild("WestDragon")
	local mouth = dragon and DragonRig.mouthCFrame(dragon)
	if char and mouth then
		lastFire = os.clock()
		fireballR:FireServer(aimDir(char, mouth.Position))
	end
end

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.R then
		releaseCharge()
	end
end)

-- Fireball VFX for every shot in the server (launch -> projectile, explode -> impact).
local shots: { [number]: DragonFX.Shot } = {}
fxR.OnClientEvent:Connect(function(kind: string, id: number, ...: any)
	local a, b, c, d, e, f, g = ...
	if kind == "launch" then
		local origin, dir, speed, D, t0, range, power = a, b, c, d, e, f, g
		DragonFX.muzzle(origin, dir, D, power)
		shots[id] = DragonFX.projectile(origin, dir, speed, D, t0, range, power)
		local cam = workspace.CurrentCamera
		if (cam.CFrame.Position - origin).Magnitude < 250 then
			DragonFX.shake(0.25 + 0.6 * power)
		end
	elseif kind == "explode" then
		local pos, normal, R, grounded, power = a, b, c, d, e
		local s = shots[id]
		if s then
			s.stop()
			shots[id] = nil
		end
		DragonFX.explode(pos, normal, R, grounded, power)
	end
end)

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
		if dragonChar() and not charging and os.clock() - lastFire >= FB.COOLDOWN then
			charging = true
			chargeStart = os.clock()
			chargeR:FireServer()
		end
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

	-- Local charge: auto-fire at max, caster rumble while charging.
	if charging then
		if not dragonChar() then
			charging = false
		else
			local held = os.clock() - chargeStart
			if held >= FB.MAX_CHARGE then
				releaseCharge()
			else
				DragonFX.shake(0.03 + 0.12 * held / FB.MAX_CHARGE)
			end
		end
	end

	-- Camera rides higher while a dragon (it is ~5x a character).
	local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if myHum then
		local want = if dragonChar() then Vector3.new(0, Config.CAMERA_HEIGHT, 0) else Vector3.zero
		if myHum.CameraOffset ~= want then
			myHum.CameraOffset = want
		end
	end

	-- Charge orbs for every charging dragon (DragonChargeStart replicates from the server).
	for ch, h in pairs(charges) do
		if not ch.Parent or ch:GetAttribute("DragonChargeStart") == nil or not ch:FindFirstChild("WestDragon") then
			h.stop()
			charges[ch] = nil
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
				local cs = char:GetAttribute("DragonChargeStart")
				local ft = char:GetAttribute("DragonFireTime")
				local since = if typeof(ft) == "number" then now - ft else 99
				if typeof(cs) == "number" then
					if not charges[char] then
						local m = model
						charges[char] = DragonFX.charge(function()
							return if m.Parent then DragonRig.mouthCFrame(m) else nil
						end, cs, FB.MAX_CHARGE, FB.BALL_D)
					end
					DragonRig.setJaw(rig, 0.2 + 0.4 * math.clamp((now - cs) / FB.MAX_CHARGE, 0, 1))
				else
					DragonRig.setJaw(rig, if since >= 0 and since < 0.4 then math.sin(since / 0.4 * math.pi) * 0.6 else 0)
				end
			end
		end
	end
end)
