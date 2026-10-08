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
local transformR, flightR, transformFxR = mk("Transform"), mk("Flight"), mk("TransformFX")
local chargeR, fireballR, fxR = mk("Charge"), mk("Fireball"), mk("FireballFX")
remotes.Parent = ReplicatedStorage

local dragonFolder = Instance.new("Folder")
dragonFolder.Name = "DragonModels"
dragonFolder.Parent = workspace

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

local lastFire: { [Player]: { [string]: number } } = {}

-- One place for all damage rules:
--  * players in dragon form take (1 - DRAGON_RESIST) of the damage and cannot be one-shot;
--  * a normal (non-dragon) player hit by a FULLY charged shot is killed outright.
local function hurt(h: Humanoid, targetChar: Model, amount: number, fullCharge: boolean)
	if targetChar:GetAttribute("DragonForm") then
		h:TakeDamage(amount * (1 - Config.DRAGON_RESIST))
	elseif fullCharge then
		h:TakeDamage(h.MaxHealth + 1)
	else
		h:TakeDamage(amount)
	end
end

local function setCharacterHidden(char: Model, hidden: boolean)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BillboardGui") then
			-- Name/rank tags float where the hidden character was; hide them with it.
			if hidden then
				if d:GetAttribute("DragonOrigEnabled") == nil then
					d:SetAttribute("DragonOrigEnabled", d.Enabled)
				end
				d.Enabled = false
			else
				local o = d:GetAttribute("DragonOrigEnabled")
				if o ~= nil then
					d.Enabled = o
					d:SetAttribute("DragonOrigEnabled", nil)
				end
			end
		elseif (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
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

local function dbg(...)
	if Config.DEBUG then
		print("[DragonDbg][server]", ...)
	end
end

local function clearForm(char: Model)
	setCharacterHidden(char, false)
	char:SetAttribute("DragonForm", nil)
	char:SetAttribute("DragonFlying", nil)
	char:SetAttribute("DragonChargeStart", nil)
	char:SetAttribute("DragonChargeMove", nil)
	local ref = char:FindFirstChild("WestDragonRef")
	if ref then
		ref:Destroy()
	end
end

local function setForm(player: Player, on: boolean)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and hum and hrp and hrp:IsA("BasePart")) then
		warn("[DragonDbg][server] setForm REJECTED for " .. player.Name .. ": character/humanoid/root missing")
		return
	end
	if hum.Health <= 0 then
		warn("[DragonDbg][server] setForm REJECTED for " .. player.Name .. ": dead")
		return
	end
	local existing = DragonRig.dragonOf(char)
	dbg(player.Name, "setForm on=" .. tostring(on), "existing=" .. tostring(existing ~= nil), "attr=" .. tostring(char:GetAttribute("DragonForm")))
	if on then
		if existing then
			-- Already a dragon: make sure the flag agrees (a stale/missing flag used to strand players).
			char:SetAttribute("DragonForm", true)
			dbg(player.Name, "already a dragon; flag re-synced")
			return
		end
		local src = DragonRig.findSource()
		dbg(player.Name, "building from", if src then src:GetFullName() else "NO SOURCE (placeholders)")
		local ok, rig = pcall(DragonRig.build, src, hrp, hum.HipHeight + hrp.Size.Y / 2, Config.SCALE, Config.TEXTURE_ID)
		if not ok then
			warn("[DragonDbg][server] BUILD FAILED for " .. player.Name .. ": " .. tostring(rig))
			char:SetAttribute("DragonForm", nil)
			return
		end
		rig.model.Name = "WestDragon_" .. player.Name
		rig.model.Parent = dragonFolder
		local ref = char:FindFirstChild("WestDragonRef") or Instance.new("ObjectValue")
		ref.Name = "WestDragonRef"
		ref.Value = rig.model
		ref.Parent = char
		-- Dragon is outside the character, so clean it up with the character.
		local conn: RBXScriptConnection
		conn = char.AncestryChanged:Connect(function(_, parent)
			if not parent then
				conn:Disconnect()
				dbg(player.Name, "character removed -> dragon destroyed")
				rig.model:Destroy()
			end
		end)
		hum.Died:Once(function()
			dbg(player.Name, "died -> dragon destroyed")
			rig.model:Destroy()
		end)
		-- Transformation blast: everyone caught in it loses 15% of max health (bypasses dragon resistance).
		for _, other in ipairs(Players:GetPlayers()) do
			local oc = other.Character
			local oh = oc and oc:FindFirstChildOfClass("Humanoid")
			local orr = oc and oc:FindFirstChild("HumanoidRootPart")
			if other ~= player and oc and oh and orr and orr:IsA("BasePart") and oh.Health > 0 and (orr.Position - hrp.Position).Magnitude <= Config.TRANSFORM_BLAST_RADIUS then
				local dmg = oh.MaxHealth * Config.TRANSFORM_DAMAGE_PCT
				oh:TakeDamage(dmg) -- bypasses dragon resistance
				dbg(other.Name, "caught in transformation blast:", string.format("%.0f dmg", dmg))
			end
		end
		setCharacterHidden(char, true)
		char:SetAttribute("DragonForm", true)
		local n = 0
		for _, d in ipairs(rig.model:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		dbg(player.Name, "TRANSFORMED: parts=" .. n .. " model=" .. rig.model:GetFullName())
	else
		if existing then
			existing:Destroy()
		end
		-- Always clear the flag/visibility, even if the model was already gone.
		clearForm(char)
		dbg(player.Name, "REVERTED (model existed=" .. tostring(existing ~= nil) .. ")")
	end
end

-- Server-side hook (used by DragonSelfTest and other server scripts).
local setFormB = Instance.new("BindableEvent")
setFormB.Name = "SetForm"
setFormB.Parent = remotes
setFormB.Event:Connect(setForm)

-- Relay a player's transformation VFX to everyone else, so bystanders see it too.
transformFxR.OnServerEvent:Connect(function(player: Player, groundPos: any, forward: any)
	if typeof(groundPos) ~= "Vector3" or typeof(forward) ~= "boolean" then
		return
	end
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not (r and r:IsA("BasePart")) or (r.Position - groundPos).Magnitude > 20 then
		return -- the effect must be at the sender's character
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			transformFxR:FireClient(other, groundPos, forward, workspace:GetServerTimeNow())
		end
	end
end)

transformR.OnServerEvent:Connect(function(player: Player, on: any)
	dbg(player.Name, "Transform request on=" .. tostring(on))
	local ok, err = pcall(setForm, player, on == true)
	if not ok then
		warn("[DragonDbg][server] setForm ERROR: " .. tostring(err))
	end
end)

flightR.OnServerEvent:Connect(function(player: Player, on: any)
	local char = player.Character
	if char and char:GetAttribute("DragonForm") then
		char:SetAttribute("DragonFlying", if on == true then true else nil)
	end
end)

-- Fireball -------------------------------------------------------------------------------------
local function dragonOf(char: Model?): Model?
	return DragonRig.dragonOf(char)
end

local function moveOf(m: any): string?
	return if typeof(m) == "string" and Config.MOVES[m] then m else nil
end

local function coolingDown(player: Player, move: string): boolean
	local t = lastFire[player] and lastFire[player][move]
	return t ~= nil and os.clock() - t < Config.MOVES[move].cooldown
end

-- Start charging: the attribute replicates so every client renders the charge orb.
chargeR.OnServerEvent:Connect(function(player: Player, moveArg: any)
	local move = moveOf(moveArg)
	local char = player.Character
	if not (move and char and dragonOf(char)) or coolingDown(player, move) then
		return
	end
	if char:GetAttribute("DragonChargeStart") == nil then
		char:SetAttribute("DragonChargeMove", move)
		char:SetAttribute("DragonChargeStart", workspace:GetServerTimeNow())
	end
end)

local function damageAround(caster: Player, pos: Vector3, radius: number, damage: number, fullCharge: boolean)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= caster then
			local c = p.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if c and h and r and r:IsA("BasePart") and h.Health > 0 then
				local reach = radius + (if c:GetAttribute("DragonForm") then Config.DRAGON_HIT_BODY else 0)
				if (r.Position - pos).Magnitude <= reach then
					hurt(h, c, damage, fullCharge)
				end
			end
		end
	end
end

local nextId = 0

fireballR.OnServerEvent:Connect(function(player: Player, dirArg: any, moveArg: any)
	local move = moveOf(moveArg)
	local char = player.Character
	local dragon = dragonOf(char)
	local mouth = dragon and DragonRig.mouthCFrame(dragon)
	if not (move and char and mouth and typeof(dirArg) == "Vector3" and dirArg.Magnitude > 0.1) or coolingDown(player, move) then
		return
	end
	local mv = Config.MOVES[move]
	lastFire[player] = lastFire[player] or {}
	lastFire[player][move] = os.clock()
	local now = workspace:GetServerTimeNow()
	-- Only a charge started for this same move counts.
	local start = if char:GetAttribute("DragonChargeMove") == move then char:GetAttribute("DragonChargeStart") else nil
	char:SetAttribute("DragonChargeStart", nil)
	char:SetAttribute("DragonChargeMove", nil)
	char:SetAttribute("DragonFireTime", now)

	-- Charge 0..1: size eases from MIN_SIZE to 1 fast; speed x1..x1.5 and damage x1..x3 linear.
	local c = if typeof(start) == "number" then math.clamp((now - start) / FB.MAX_CHARGE, 0, 1) else 0
	local speed = FB.SPEED * mv.speed * (1 + 0.5 * c)
	local damage = FB.DAMAGE * mv.damage * (1 + 2 * c)
	local D = DragonRig.fireballMaxD(dragon :: Model, FB.MAX_D_HEAD) * mv.size * DragonRig.sizeFactor(c, FB.MIN_SIZE)
	local radius = D * FB.BLAST_PER_D
	local dir = dirArg.Unit
	local origin = mouth.Position + dir * D * 0.6

	nextId += 1
	local id = nextId
	-- Clients draw the ball VISUAL_SIZE smaller; hitbox (D) and blast radius stay as computed.
	fxR:FireAllClients("launch", id, move, origin, dir, speed, D * FB.VISUAL_SIZE, now, FB.RANGE, c)

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
			fxR:FireAllClients("explode", id, move, at, normal, radius, grounded, c)
			damageAround(player, at, radius, damage, c >= 0.99)
			-- Self-hit: caught in your own blast -> stack a speed boost (no damage to self).
			local myRoot = char:FindFirstChild("HumanoidRootPart")
			if myRoot and myRoot:IsA("BasePart") and (myRoot.Position - at).Magnitude <= radius + Config.DRAGON_HIT_BODY then
				local SB = Config.SELF_BOOST
				local nowT = workspace:GetServerTimeNow()
				local untilT = char:GetAttribute("DragonBoostUntil")
				local cur = char:GetAttribute("DragonBoost")
				local active = if typeof(untilT) == "number" and typeof(cur) == "number" and nowT < untilT + SB.FADE then cur else 0
				local boost = math.min(active + SB.PER_HIT * (1 + c), SB.MAX)
				char:SetAttribute("DragonBoost", boost)
				char:SetAttribute("DragonBoostUntil", nowT + SB.DURATION)
				if Config.DEBUG then
					print("[DragonDbg][server]", player.Name, "self-hit boost ->", string.format("+%d%%", boost * 100))
				end
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	lastFire[p] = nil
end)
