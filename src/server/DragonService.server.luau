--!strict
-- Dragon form (build/weld the rig onto the character), flight flag, and fireball (server-side damage).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Dragon = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dragon")
local DragonRig = require(Dragon:WaitForChild("DragonRig"))
local Config = require(Dragon:WaitForChild("DragonConfig"))
local FB = Config.FIREBALL

local remotes = Instance.new("Folder")
remotes.Name = "DragonRemotes"
local function mk(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local transformR, flightR, fireballR = mk("Transform"), mk("Flight"), mk("Fireball")
remotes.Parent = ReplicatedStorage

local lastFire: { [Player]: number } = {}

local function setCharacterHidden(char: Model, hidden: boolean)
	for _, d in ipairs(char:GetDescendants()) do
		if d:FindFirstAncestor("WestDragon") then
			continue
		end
		if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
			local inst = d :: any
			if hidden then
				if inst:GetAttribute("DragonOrigT") == nil then
					inst:SetAttribute("DragonOrigT", inst.Transparency)
				end
				inst.Transparency = 1
			else
				local o = inst:GetAttribute("DragonOrigT")
				if o ~= nil then
					inst.Transparency = o
					inst:SetAttribute("DragonOrigT", nil)
				end
			end
		end
	end
end

local function setForm(player: Player, on: boolean)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and hum and hrp and hrp:IsA("BasePart")) or hum.Health <= 0 then
		return
	end
	local existing = char:FindFirstChild("WestDragon")
	if on and not existing then
		local rig = DragonRig.build(
			ReplicatedStorage:FindFirstChild(Config.SOURCE_MODEL_NAME) or ReplicatedStorage:FindFirstChild("Full Model"),
			hrp,
			hum.HipHeight + hrp.Size.Y / 2,
			Config.SCALE,
			Config.TEXTURE_ID
		)
		rig.model.Parent = char
		setCharacterHidden(char, true)
		char:SetAttribute("DragonForm", true)
	elseif not on and existing then
		existing:Destroy()
		setCharacterHidden(char, false)
		char:SetAttribute("DragonForm", nil)
		char:SetAttribute("DragonFlying", nil)
	end
end

transformR.OnServerEvent:Connect(function(player: Player, on: any)
	setForm(player, on == true)
end)

flightR.OnServerEvent:Connect(function(player: Player, on: any)
	local char = player.Character
	if char and char:GetAttribute("DragonForm") then
		char:SetAttribute("DragonFlying", if on == true then true else nil)
	end
end)

-- Hook the existing Studio VFX driver: its button fires DragonWestTransformEvent; toggle at the blast beat.
task.spawn(function()
	local ev = ReplicatedStorage:WaitForChild("DragonWestTransformEvent", 30)
	if ev and ev:IsA("RemoteEvent") then
		ev.OnServerEvent:Connect(function(player: Player)
			local char = player.Character
			local becoming = not (char and char:GetAttribute("DragonForm"))
			task.delay(if becoming then Config.TRANSFORM_DELAY else 0, function()
				setForm(player, becoming)
			end)
		end)
	end
end)

local function explode(caster: Player, pos: Vector3)
	local blast = Instance.new("Part")
	blast.Shape = Enum.PartType.Ball
	blast.Anchored, blast.CanCollide, blast.CanQuery, blast.CanTouch = true, false, false, false
	blast.Material = Enum.Material.Neon
	blast.Color = Color3.fromRGB(255, 150, 20)
	blast.Size = Vector3.one * 4
	blast.Position = pos
	blast.Parent = workspace
	TweenService:Create(blast, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * FB.RADIUS * 2,
		Transparency = 1,
		Color = Color3.fromRGB(225, 35, 15),
	}):Play()
	Debris:AddItem(blast, 0.6)

	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(255, 214, 20), Color3.fromRGB(255, 70, 0))
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(5, 0)
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(25, 50)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = blast
	e:Emit(40)

	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if p ~= caster and h and r and h.Health > 0 then
			if ((r :: BasePart).Position - pos).Magnitude <= FB.RADIUS then
				h:TakeDamage(FB.DAMAGE)
			end
		end
	end
end

fireballR.OnServerEvent:Connect(function(player: Player, dirArg: any)
	local char = player.Character
	local head = char and char:FindFirstChild("WestDragon") and char.WestDragon:FindFirstChild("Head")
	if not (char and head and head:IsA("BasePart") and typeof(dirArg) == "Vector3") then
		return
	end
	if dirArg.Magnitude < 0.1 then
		return
	end
	local now = os.clock()
	if now - (lastFire[player] or -math.huge) < FB.COOLDOWN then
		return
	end
	lastFire[player] = now
	char:SetAttribute("DragonFireTime", workspace:GetServerTimeNow())

	local dir = dirArg.Unit
	local pos = head.Position + dir * 4
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 4
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 160, 20)
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
	ball.Position = pos
	local core = Instance.new("Fire")
	core.Size, core.Heat = 12, 8
	core.Color, core.SecondaryColor = Color3.fromRGB(255, 214, 20), Color3.fromRGB(225, 35, 15)
	core.Parent = ball
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 140, 20), 24, 3
	light.Parent = ball
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 1.5, 0), Vector3.new(0, -1.5, 0)
	a0.Parent, a1.Parent = ball, ball
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.35
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 214, 20), Color3.fromRGB(225, 35, 15))
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.LightEmission = 0.5
	trail.Parent = ball
	ball.Parent = workspace

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char, ball }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local travelled = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		local step = FB.SPEED * dt
		local hit = workspace:Raycast(pos, dir * step, params)
		travelled += step
		if hit then
			pos = hit.Position
		else
			pos += dir * step
		end
		ball.Position = pos
		if hit or travelled >= FB.RANGE then
			conn:Disconnect()
			ball:Destroy()
			explode(player, pos)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	lastFire[p] = nil
end)
