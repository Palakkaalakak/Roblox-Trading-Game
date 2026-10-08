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
local testFailR = remotes:WaitForChild("TestFail") :: RemoteEvent
local aimR = remotes:WaitForChild("Aim") :: RemoteEvent
local fxR = remotes:WaitForChild("FireballFX") :: RemoteEvent
local DragonFX = require(Dragon:WaitForChild("DragonFX"))
local FB = Config.FIREBALL

local player = Players.LocalPlayer
local rigs: { [Model]: DragonRig.Rig } = setmetatable({}, { __mode = "k" }) :: any
local pitches: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

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
local lastFire: { [string]: number } = {}
local MOVE_KEYS: { [Enum.KeyCode]: string } = { [Enum.KeyCode.R] = "R", [Enum.KeyCode.Q] = "Q", [Enum.KeyCode.F] = "F" }
local chargingMove: string? = nil
local charging = false
local localAim: Vector3? = nil
local lastSentAim: Vector3? = nil
local aimAcc = 0
local cameraOnHead = false
local chargeStart = 0
local charges: { [Model]: { stop: () -> () } } = {}

-- Self-hit speed boost (server sets DragonBoost / DragonBoostUntil); fades out after it expires.
local function currentBoost(char: Instance?): number
	if not char then
		return 0
	end
	local b, u = char:GetAttribute("DragonBoost"), char:GetAttribute("DragonBoostUntil")
	if typeof(b) ~= "number" or typeof(u) ~= "number" then
		return 0
	end
	local over = workspace:GetServerTimeNow() - u
	if over <= 0 then
		return b
	end
	return b * math.max(0, 1 - over / Config.SELF_BOOST.FADE)
end

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
	a.Responsiveness = 9
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
	local move = chargingMove or "R"
	chargingMove = nil
	local char = dragonChar()
	local dragon = DragonRig.dragonOf(char)
	local mouth = dragon and DragonRig.mouthCFrame(dragon)
	if char and mouth then
		lastFire[move] = os.clock()
		fireballR:FireServer(aimDir(char, mouth.Position), move)
	end
end

UserInputService.InputEnded:Connect(function(input)
	if chargingMove and MOVE_KEYS[input.KeyCode] == chargingMove then
		releaseCharge()
	end
end)

-- Fireball VFX for every shot in the server (launch -> projectile, explode -> impact).
local shots: { [number]: DragonFX.Shot } = {}
fxR.OnClientEvent:Connect(function(kind: string, id: number, move: string, ...: any)
	local a, b, c, d, e, f, g = ...
	if kind == "launch" then
		local origin, dir, speed, D, t0, range, power = a, b, c, d, e, f, g
		DragonFX.muzzle(origin, dir, D, power, move)
		shots[id] = DragonFX.projectile(move, origin, dir, speed, D, t0, range, power)
		local cam = workspace.CurrentCamera
		if (cam.CFrame.Position - origin).Magnitude < 250 then
			DragonFX.shake(0.25 + 0.6 * power)
		end
	elseif kind == "explode" then
		local pos, normal, R, grounded, power, failed = a, b, c, d, e, f
		local s = shots[id]
		if s then
			s.stop()
			shots[id] = nil
		end
		DragonFX.explode(move, pos, normal, R, grounded, power, failed == true)
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
	elseif input.KeyCode == Enum.KeyCode.J then
		-- TESTING: trigger a failure event on yourself (server checks Config.TEST_J_FAIL).
		if Config.TEST_J_FAIL then
			testFailR:FireServer()
		end
	elseif MOVE_KEYS[input.KeyCode] then
		local move = MOVE_KEYS[input.KeyCode]
		local last = lastFire[move]
		if dragonChar() and not charging and (last == nil or os.clock() - last >= Config.MOVES[move].cooldown) then
			charging = true
			chargingMove = move
			chargeStart = os.clock()
			chargeR:FireServer(move)
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
			local vel = if move.Magnitude > 0.01 then move.Unit * Config.FLY_SPEED * (1 + currentBoost(char)) else Vector3.zero
			if U:IsKeyDown(Enum.KeyCode.Space) then vel += Vector3.new(0, Config.FLY_VERTICAL, 0) end
			if U:IsKeyDown(Enum.KeyCode.LeftShift) then vel -= Vector3.new(0, Config.FLY_VERTICAL, 0) end
			lv.VectorVelocity = lv.VectorVelocity:Lerp(vel, math.clamp(dt * 6, 0, 1))
			ao.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
			-- Turn rate scales with the self-hit speed boost (+150% boost -> 2.5x turning).
			ao.Responsiveness = 9 * (1 + currentBoost(char))

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
			-- Holds at max charge until released (no auto-fire).
			local held = math.min((os.clock() - chargeStart) / FB.MAX_CHARGE, 1)
			DragonFX.shake(0.03 + 0.12 * held)
		end
	end

	-- Camera follows the dragon's head (not the hidden character's root/name tag).
	local cam = workspace.CurrentCamera
	local myChar, _, myHum = dragonChar()
	if myChar and myHum then
		local dm = DragonRig.dragonOf(myChar)
		local head = dm and dm:FindFirstChild("Head")
		if head and head:IsA("BasePart") and cam.CameraSubject ~= head then
			cam.CameraSubject = head
			cameraOnHead = true
		end
	elseif cameraOnHead then
		cameraOnHead = false
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if h then
			cam.CameraSubject = h
		end
	end

	-- Ground speed follows the self-hit boost (skipped while frozen for the transform).
	do
		local bc, bhrp, bhum = dragonChar()
		if bc and bhrp and bhum and not bhrp.Anchored and not flying then
			local want = Config.DRAGON_WALKSPEED * (1 + currentBoost(bc))
			if math.abs(bhum.WalkSpeed - want) > 0.05 then
				bhum.WalkSpeed = want
			end
		end
	end

	-- Where the local cursor points (from the mouth); drives the head turn and is shared with others.
	localAim = nil
	do
		local ac = dragonChar()
		local adragon = ac and DragonRig.dragonOf(ac)
		local amouth = adragon and DragonRig.mouthCFrame(adragon)
		if ac and amouth then
			localAim = aimDir(ac, amouth.Position)
			aimAcc += dt
			if aimAcc > 0.12 and (not lastSentAim or lastSentAim:Dot(localAim) < 0.9995) then
				aimAcc = 0
				lastSentAim = localAim
				aimR:FireServer(localAim)
			end
		end
	end

	-- Charge orbs for every charging dragon (DragonChargeStart replicates from the server).
	for ch, h in pairs(charges) do
		if not ch.Parent or ch:GetAttribute("DragonChargeStart") == nil or not DragonRig.dragonOf(ch) then
			h.stop()
			charges[ch] = nil
		end
	end

	-- Animate all dragons (replicated models, local time).
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local model = DragonRig.dragonOf(char)
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if model and model:IsA("Model") and hrp and hrp:IsA("BasePart") then
			local rig = getRig(model)
			if rig then
				local v = hrp.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				local isFlying = char:GetAttribute("DragonFlying") == true
				local target = 0
				if isFlying then
					-- Pitch follows the real flight angle: dives point steeply down (up to ~75deg), climbs tilt up.
					local ang = math.atan2(-v.Y, math.max(speed, 14))
					target = math.clamp(ang * 1.05, -0.75, 1.3) + math.clamp(speed / Config.FLY_SPEED, 0, 1) * 0.1
				end
				local cur = pitches[model] or 0
				cur += (target - cur) * math.clamp(dt * 5, 0, 1)
				pitches[model] = cur
				local aim: Vector3? = nil
				if p == player then
					aim = localAim
				else
					local av = char:GetAttribute("DragonAim")
					aim = if typeof(av) == "Vector3" then av else nil
				end
				DragonRig.animate(rig, t, speed, isFlying, cur, char, v.Y, aim)
				local cs = char:GetAttribute("DragonChargeStart")
				local ft = char:GetAttribute("DragonFireTime")
				local since = if typeof(ft) == "number" then now - ft else 99
				if typeof(cs) == "number" then
					local cm = char:GetAttribute("DragonChargeMove")
					local chMove = if typeof(cm) == "string" and Config.MOVES[cm] then cm else "R"
					local mvSize = Config.MOVES[chMove].size
					if not charges[char] then
						local m = model
						charges[char] = DragonFX.charge(function()
							return if m.Parent then DragonRig.mouthCFrame(m) else nil
						end, cs, FB.MAX_CHARGE, DragonRig.fireballMaxD(m, FB.MAX_D_HEAD) * mvSize * FB.VISUAL_SIZE, chMove)
					end
					DragonRig.setJaw(rig, 0.2 + 0.4 * math.clamp((now - cs) / FB.MAX_CHARGE, 0, 1))
				else
					DragonRig.setJaw(rig, if since >= 0 and since < 0.4 then math.sin(since / 0.4 * math.pi) * 0.6 else 0)
				end
			end
		end
	end
end)
