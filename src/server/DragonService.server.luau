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
			DragonRig.findSource(),
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

-- Server-side hook (used by DragonSelfTest and other server scripts).
local setFormB = Instance.new("BindableEvent")
setFormB.Name = "SetForm"
setFormB.Parent = remotes
setFormB.Event:Connect(setForm)

transformR.OnServerEvent:Connect(function(player: Player, on: any)
	setForm(player, on == true)
end)

flightR.OnServerEvent:Connect(function(player: Player, on: any)
	local char = player.Character
	if char and char:GetAttribute("DragonForm") then
		char:SetAttribute("DragonFlying", if on == true then true else nil)
	end
end)

local function puff(pos: Vector3, size: number, c0: Color3, c1: Color3, life: number, rise: number, neon: boolean)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = c0
	p.Size = Vector3.one * size
	p.Position = pos
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size * (if neon then 0.15 else 1.8),
		Color = c1,
		Transparency = 1,
		Position = pos + Vector3.new(0, rise, 0),
	}):Play()
	Debris:AddItem(p, life + 0.1)
end

local YEL, ORG, RED = Color3.fromRGB(255, 214, 20), Color3.fromRGB(255, 118, 0), Color3.fromRGB(225, 35, 15)
local BLK = Color3.fromRGB(20, 20, 24)

local function explode(caster: Player, pos: Vector3)
	-- Flash core + expanding fireball + shockwave ring (cel-shaded solid shapes).
	puff(pos, 10, Color3.new(1, 1, 0.8), YEL, 0.25, 0, true)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
	ball.Material = Enum.Material.Neon
	ball.Color = ORG
	ball.Size = Vector3.one * 5
	ball.Position = pos
	ball.Parent = workspace
	local hl = Instance.new("Highlight")
	hl.FillTransparency, hl.OutlineColor, hl.OutlineTransparency = 1, BLK, 0
	hl.Parent = ball
	TweenService:Create(ball, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.one * FB.RADIUS * 1.8,
		Color = RED,
		Transparency = 0.85,
	}):Play()
	Debris:AddItem(ball, 0.6)

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = YEL
	ring.Size = Vector3.new(0.6, 4, 4)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.6, FB.RADIUS * 2.6, FB.RADIUS * 2.6),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.6)

	-- Flame puffs, black smoke, and debris cubes flying outward.
	local rng = Random.new()
	for _ = 1, 8 do
		local o = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1), rng:NextNumber(-1, 1)) * FB.RADIUS * 0.5
		puff(pos + o, rng:NextNumber(5, 8), YEL, RED, 0.6, 5, true)
	end
	for _ = 1, 6 do
		local o = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1), rng:NextNumber(-1, 1)) * FB.RADIUS * 0.4
		task.delay(0.15, puff, pos + o, rng:NextNumber(6, 9), BLK, BLK, 1.2, 10, false)
	end
	for _ = 1, 10 do
		local c = Instance.new("Part")
		c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
		c.Material = Enum.Material.SmoothPlastic
		c.Color = Color3.fromRGB(35, 40, 70)
		c.Size = Vector3.one * rng:NextNumber(0.8, 1.6)
		c.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		c.Parent = workspace
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.3, 1.2), rng:NextNumber(-1, 1)).Unit
		TweenService:Create(c, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = c.CFrame + dir * rng:NextNumber(10, FB.RADIUS * 1.4) * 1,
			Transparency = 1,
		}):Play()
		Debris:AddItem(c, 0.8)
	end

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
	local pos = head.Position + dir * 5
	-- Layered cel-style ball: black-outlined orange shell with a yellow core.
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 5
	ball.Material = Enum.Material.Neon
	ball.Color = ORG
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
	ball.Position = pos
	local hl = Instance.new("Highlight")
	hl.FillTransparency, hl.OutlineColor, hl.OutlineTransparency = 1, BLK, 0
	hl.Parent = ball
	local core = Instance.new("Part")
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * 2.8
	core.Material = Enum.Material.Neon
	core.Color = YEL
	core.Anchored, core.CanCollide, core.CanQuery, core.CanTouch = true, false, false, false
	core.Position = pos
	core.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = ORG, 26, 3
	light.Parent = ball
	ball.Parent = workspace

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char, ball, core }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local travelled, acc = 0, 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		local step = FB.SPEED * dt
		local hit = workspace:Raycast(pos, dir * step, params)
		travelled += step
		pos = if hit then hit.Position else pos + dir * step
		ball.Position, core.Position = pos, pos
		acc += dt
		if acc > 0.03 then
			acc = 0
			-- tapered tail of flame puffs behind the ball, plus the odd black smoke wisp
			puff(pos - dir * 1.5, 4, ORG, RED, 0.35, 1, true)
			if math.random() < 0.25 then
				puff(pos - dir * 3, 3, BLK, BLK, 0.7, 3, false)
			end
		end
		if hit or travelled >= FB.RANGE then
			conn:Disconnect()
			ball:Destroy()
			core:Destroy()
			explode(player, pos)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	lastFire[p] = nil
end)
