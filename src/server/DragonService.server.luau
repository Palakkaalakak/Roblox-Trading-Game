--!strict
-- Dragon form (build/weld the rig onto the character), flight flag, and the chargeable fireball.
-- Fireball: the server simulates the projectile (spherecast) and applies damage to other players;
-- every client renders the VFX from FireballFX "launch"/"explode" events (DragonFX).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

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
local transformR, flightR = mk("Transform"), mk("Flight")
local chargeR, fireballR, fxR = mk("Charge"), mk("Fireball"), mk("FireballFX")
remotes.Parent = ReplicatedStorage

-- The imported dragon ("Full Model") sits unanchored in Workspace: anchor it and park it in
-- ServerStorage so it neither falls nor shows. The rig clones its MeshParts per transform.
do
	local src = DragonRig.findSource()
	if src and src:IsDescendantOf(workspace) then
		for _, d in ipairs(src:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		src.Parent = ServerStorage
	end
end

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
	if not (char and hum and hrp and hrp:IsA("BasePart")) then
		warn("[DragonService] setForm: character not ready for " .. player.Name)
		return
	end
	if hum.Health <= 0 then
		return
	end
	local existing = char:FindFirstChild("WestDragon")
	if on and not existing then
		local ok, rig = pcall(DragonRig.build, DragonRig.findSource(), hrp, hum.HipHeight + hrp.Size.Y / 2, Config.SCALE, Config.TEXTURE_ID)
		if not ok then
			warn("[DragonService] dragon build failed: " .. tostring(rig))
			return
		end
		rig.model.Parent = char
		setCharacterHidden(char, true)
		char:SetAttribute("DragonForm", true)
	elseif not on and existing then
		existing:Destroy()
		setCharacterHidden(char, false)
		char:SetAttribute("DragonForm", nil)
		char:SetAttribute("DragonFlying", nil)
		char:SetAttribute("DragonChargeStart", nil)
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

-- Fireball -------------------------------------------------------------------------------------
local function dragonOf(char: Model?): Model?
	local d = char and char:FindFirstChild("WestDragon")
	return if d and d:IsA("Model") then d else nil
end

local function coolingDown(player: Player): boolean
	return os.clock() - (lastFire[player] or -math.huge) < FB.COOLDOWN
end

-- Start charging: the attribute replicates so every client renders the charge orb.
chargeR.OnServerEvent:Connect(function(player: Player)
	local char = player.Character
	if not (char and dragonOf(char)) or coolingDown(player) then
		return
	end
	if char:GetAttribute("DragonChargeStart") == nil then
		char:SetAttribute("DragonChargeStart", workspace:GetServerTimeNow())
	end
end)

local function damageAround(caster: Player, pos: Vector3, radius: number, damage: number)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= caster then
			local c = p.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if c and h and r and r:IsA("BasePart") and h.Health > 0 then
				local reach = radius + (if c:GetAttribute("DragonForm") then Config.DRAGON_HIT_BODY else 0)
				if (r.Position - pos).Magnitude <= reach then
					h:TakeDamage(damage)
				end
			end
		end
	end
end

local nextId = 0

fireballR.OnServerEvent:Connect(function(player: Player, dirArg: any)
	local char = player.Character
	local dragon = dragonOf(char)
	local mouth = dragon and DragonRig.mouthCFrame(dragon)
	if not (char and mouth and typeof(dirArg) == "Vector3" and dirArg.Magnitude > 0.1) or coolingDown(player) then
		return
	end
	lastFire[player] = os.clock()
	local now = workspace:GetServerTimeNow()
	local start = char:GetAttribute("DragonChargeStart")
	char:SetAttribute("DragonChargeStart", nil)
	char:SetAttribute("DragonFireTime", now)

	-- Charge 0..1 scales size x1..x2, speed x1..x1.5, damage x1..x3.
	local c = if typeof(start) == "number" then math.clamp((now - start) / FB.MAX_CHARGE, 0, 1) else 0
	local size = 1 + c
	local speed = FB.SPEED * (1 + 0.5 * c)
	local damage = FB.DAMAGE * (1 + 2 * c)
	local D = DragonRig.fireballBaseD(dragon :: Model, FB.MAX_D_HEAD) * size
	local radius = D * FB.BLAST_PER_D
	local dir = dirArg.Unit
	local origin = mouth.Position + dir * D * 0.6

	nextId += 1
	local id = nextId
	fxR:FireAllClients("launch", id, origin, dir, speed, D, now, FB.RANGE, c)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local pos = origin
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local dist = math.min(speed * (workspace:GetServerTimeNow() - now), FB.RANGE)
		local target = origin + dir * dist
		local delta = target - pos
		local hitPos: Vector3? = nil
		local normal = -dir
		local grounded = false
		if delta.Magnitude > 0.01 then
			local hit = workspace:Spherecast(pos, D * 0.45, delta, params)
			if hit then
				hitPos = hit.Position + hit.Normal * D * 0.3
				normal = hit.Normal
				grounded = hit.Normal.Y > 0.6
			else
				-- Direct hit on another player (dragons are non-collidable, so test by distance).
				local step = delta.Unit
				for _, p in ipairs(Players:GetPlayers()) do
					local pc = p.Character
					local r = pc and pc:FindFirstChild("HumanoidRootPart")
					if p ~= player and pc and r and r:IsA("BasePart") then
						local along = math.clamp((r.Position - pos):Dot(step), 0, delta.Magnitude)
						local closest = pos + step * along
						local reach = D * 0.5 + (if pc:GetAttribute("DragonForm") then Config.DRAGON_HIT_BODY else 2.5)
						if (closest - r.Position).Magnitude <= reach then
							hitPos = closest
							break
						end
					end
				end
			end
		end
		pos = target
		if hitPos or dist >= FB.RANGE then
			conn:Disconnect()
			local at = hitPos or pos
			fxR:FireAllClients("explode", id, at, normal, radius, grounded, c)
			damageAround(player, at, radius, damage)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	lastFire[p] = nil
end)
