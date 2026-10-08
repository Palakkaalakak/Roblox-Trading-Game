--!strict
-- Builds the Obsidian West rigid-part Motor6D rig from DragonJoints and animates it.
-- Source meshes: a Model/Folder of MeshParts named exactly like the joints (the imported
-- Obsidian_West_asset_pack/parts/*.obj). Missing parts fall back to green blocks so the
-- rig is testable before the meshes are imported/uploaded.
-- Design space is +Z forward; the weld flips it 180deg about Y so it faces Roblox -Z.

local Joints = require(script.Parent.DragonJoints)

local DragonRig = {}

local GREEN = Color3.fromRGB(46, 125, 50)
local WING_FLAP_HZ_IDLE, WING_FLAP_HZ_FLY = 1.2, 2.6

export type Rig = {
	model: Model,
	motors: { [string]: Motor6D },
	weld: Weld,
	baseC0: CFrame,
	scale: number, -- studs per design unit
	flip: number, -- +1 if the source model's forward is manifest +Z, -1 if it is imported mirrored (-Z)
}

-- Finds the imported dragon. Prefers a Model named "Full Model" (the user's import: MeshParts
-- nested in per-part "*_Node" models), then any container holding the joint MeshParts.
-- Ignores the old stripped "RPG Dragon" copy (DragonWestModel), which has none of them.
local cachedSource: Instance? = nil
function DragonRig.findSource(): Instance?
	if cachedSource and cachedSource.Parent then
		return cachedSource
	end
	local services = { game:GetService("ReplicatedStorage"), game:GetService("ServerStorage"), workspace }
	for _, svc in ipairs(services) do
		local full = svc:FindFirstChild("Full Model")
		if full and full:FindFirstChild("Torso", true) then
			cachedSource = full
			return full
		end
	end
	for _, svc in ipairs(services) do
		local m = svc:FindFirstChild("L_Wing_Membrane_4", true)
		if m and m:IsA("MeshPart") and m.Parent then
			local root: Instance = m.Parent
			while root.Parent and root.Parent ~= svc and not root:FindFirstChild("Torso", true) do
				root = root.Parent
			end
			cachedSource = root
			return root
		end
	end
	return nil
end

local function findMesh(root: Instance, name: string): MeshPart?
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == name and d:IsA("MeshPart") then
			return d
		end
	end
	return nil
end

-- The dragon model lives in Workspace.DragonModels, NOT inside the character: the character's
-- Animator owns every Motor6D under the character and would overwrite our joint Transforms
-- (and drive the dragon's "Head" joint with the walk animation). char.WestDragonRef -> model.
function DragonRig.dragonOf(char: Instance?): Model?
	local ref = char and char:FindFirstChild("WestDragonRef")
	local m = ref and ref:IsA("ObjectValue") and ref.Value
	return if m and m:IsA("Model") and m.Parent then m else nil
end

-- Mouth tip of a built dragon, facing forward (-Z = where the dragon looks).
-- Parts keep design axes (+Z = dragon forward), so the snout is at +Z of the Head part.
function DragonRig.mouthCFrame(model: Instance): CFrame?
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("Torso")
	if not (head and head:IsA("BasePart") and torso and torso:IsA("BasePart")) then
		return nil
	end
	-- Forward = away from the torso, flattened; tip of the snout is about half a head-length ahead.
	local d = head.Position - torso.Position
	local fwd = Vector3.new(d.X, 0, d.Z)
	fwd = if fwd.Magnitude > 0.01 then fwd.Unit else -torso.CFrame.LookVector
	-- Mouth height: between the head and jaw centres (the head part's centre sits above the mouth).
	local jaw = model:FindFirstChild("Jaw")
	local base = if jaw and jaw:IsA("BasePart") then head.Position:Lerp(jaw.Position, 0.7) else head.Position - Vector3.new(0, head.Size.Y * 0.25, 0)
	local len = math.max(head.Size.X, head.Size.Z) * 0.5
	local at = Vector3.new(head.Position.X, base.Y, head.Position.Z) + fwd * len
	return CFrame.lookAt(at, at + fwd)
end

-- Fully charged fireball diameter for this dragon (MAX_D_HEAD x the head's largest dimension).
function DragonRig.fireballMaxD(model: Instance, maxDHead: number): number
	local head = model:FindFirstChild("Head")
	local s = if head and head:IsA("BasePart") then math.max(head.Size.X, head.Size.Y, head.Size.Z) else 6
	return s * maxDHead
end

-- Charge 0..1 -> size fraction: starts small and grows fast (ease-out cubic), 1 at full charge.
function DragonRig.sizeFactor(c: number, minSize: number): number
	local k = math.clamp(c, 0, 1)
	return minSize + (1 - minSize) * (1 - (1 - k) ^ 3)
end

-- sourceRoot: where the imported MeshParts live (nil -> placeholder blocks).
-- groundDist: HRP center to feet distance (studs). scale: studs per design unit.
function DragonRig.build(sourceRoot: Instance?, hrp: BasePart, groundDist: number, scale: number, textureId: string?): Rig
	local model = Instance.new("Model")
	model.Name = "WestDragon"
	local parts: { [string]: BasePart } = {}
	local frames: { [string]: CFrame } = {}
	local jointFrames: { [string]: CFrame } = {}

		local mult = scale
	local srcTorso = sourceRoot and findMesh(sourceRoot, "Torso")
	local srcHead = sourceRoot and findMesh(sourceRoot, "Head")
	-- The import is often much larger than the manifest (e.g. 7x): sizes always come from the
	-- manifest * Config.SCALE (a MeshPart rescales its mesh to Size), only the ratio is needed
	-- to convert source offsets into rig units.
	local srcRatio = if srcTorso then srcTorso.Size.Y / Joints[1].size.Y else 1

	-- Facing: the import may be mirrored vs the manifest (Roblox importers flip Z). Compare the
	-- Torso->Head direction in the source with the manifest's; if opposite, work in the source's
	-- own frame (flip = -1): points map (x,y,z)->(-x,y,-z) and the part orientations come from the source.
	local flip = 1
	local function ctr(n: string): Vector3
		for _, j in ipairs(Joints) do
			if j.name == n then
				return j.pivot + j.center
			end
		end
		return Vector3.zero
	end
	if srcTorso and srcHead then
		local dSrc = srcHead.Position - srcTorso.Position
		local dMan = ctr("Head") - ctr("Torso")
		if Vector3.new(dSrc.X, 0, dSrc.Z):Dot(Vector3.new(dMan.X, 0, dMan.Z)) < 0 then
			flip = -1
		end
	end
	local function map(v: Vector3): Vector3
		return if flip == 1 then v else Vector3.new(-v.X, v.Y, -v.Z)
	end
	local torsoCenter = map(ctr("Torso")) * scale

	for _, j in ipairs(Joints) do
		local src = sourceRoot and findMesh(sourceRoot, j.name)
		local p: BasePart
		if src then
			p = src:Clone()
			for _, c in ipairs(p:GetChildren()) do
				if c:IsA("BaseScript") or c:IsA("JointInstance") or c:IsA("Constraint") or c:IsA("WeldConstraint") then
					c:Destroy()
				end
			end
			if textureId and textureId ~= "" then
				(p :: MeshPart).TextureID = textureId
			end
		else
			p = Instance.new("Part")
			p.Color = GREEN
			p.Material = Enum.Material.SmoothPlastic
		end
		p.Name = j.name
		p.Size = j.size * scale
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		if src and srcTorso and flip == -1 then
			-- Mirrored import: keep each part's own orientation/offset relative to the Torso part.
			local rel = srcTorso.CFrame:ToObjectSpace(src.CFrame)
			frames[j.name] = CFrame.new(torsoCenter + rel.Position * (mult / srcRatio)) * rel.Rotation
		else
			frames[j.name] = CFrame.new(map(j.pivot + j.center) * scale)
		end
		jointFrames[j.name] = CFrame.new(map(j.pivot) * scale)
		p.CFrame = frames[j.name]
		p.Parent = model
		parts[j.name] = p
	end

	local motors: { [string]: Motor6D } = {}
	for _, j in ipairs(Joints) do
		if j.parent then
			local m = Instance.new("Motor6D")
			m.Name = j.name .. "_Joint"
			m.Part0, m.Part1 = parts[j.parent], parts[j.name]
			m.C0 = frames[j.parent]:ToObjectSpace(jointFrames[j.name])
			m.C1 = frames[j.name]:ToObjectSpace(jointFrames[j.name])
			m.Parent = parts[j.parent]
			motors[j.name] = m
		end
	end

	local torso = parts.Torso
	model.PrimaryPart = torso
	local weld = Instance.new("Weld")
	weld.Name = "DragonWeld"
	-- Design (+Z forward) needs a 180deg yaw to face Roblox -Z; a mirrored (-Z) import already does.
	local base = CFrame.new(0, -groundDist, 0) * CFrame.Angles(0, if flip == 1 then math.pi else 0, 0) * frames.Torso
	weld.Part0, weld.Part1 = hrp, torso
	weld.C0 = base
	weld:SetAttribute("BaseC0", base)
	weld:SetAttribute("Flip", flip)
	weld.Parent = torso
	return { model = model, motors = motors, weld = weld, baseC0 = base, scale = scale, flip = flip }
end

-- Rebuild the lookup from an already-built dragon (clients animate replicated dragons).
function DragonRig.wrap(model: Model): Rig?
	local torso = model:FindFirstChild("Torso")
	local weld = torso and torso:FindFirstChild("DragonWeld")
	if not (torso and weld and weld:IsA("Weld")) then
		return nil
	end
	local motors: { [string]: Motor6D } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			motors[(d.Name:gsub("_Joint$", ""))] = d
		end
	end
	local base = weld:GetAttribute("BaseC0")
	local scale = (torso :: BasePart).Size.Y / Joints[1].size.Y
	return { model = model, motors = motors, weld = weld, baseC0 = if typeof(base) == "CFrame" then base else weld.C0, scale = scale, flip = if weld:GetAttribute("Flip") == -1 then -1 else 1 }
end

local function rot(m: Motor6D?, x: number, y: number, z: number)
	if m then
		m.Transform = CFrame.Angles(x, y, z)
	end
end

-- Smoothing helper: frame-rate independent exponential approach.
local function approach(cur: number, target: number, rate: number, dt: number): number
	return cur + (target - cur) * (1 - math.exp(-rate * dt))
end

-- speed: horizontal studs/s (walk cycle); flying: wings beat + legs tucked; pitch: nose-down rad.
-- Anti-jitter: speed/flying/pitch are low-pass filtered, and cycles advance by accumulated PHASE
-- (changing frequency never jumps the wings/legs), walk phase follows distance travelled
-- (feet don't skate), flight blends in/out over ~0.4 s, and the body banks into turns.
function DragonRig.animate(rig: Rig, t: number, speedRaw: number, flying: boolean, pitchRaw: number, owner: Instance?)
	local st = (rig :: any).st
	if not st then
		st = { last = t, spd = 0, fly = if flying then 1 else 0, pitch = 0, wing = 0, walk = 0, idle = 0, bank = 0, yaw = nil }
		;(rig :: any).st = st
	end
	local dt = math.clamp(t - st.last, 0, 0.1)
	st.last = t
	st.spd = approach(st.spd, speedRaw, 6, dt)
	st.fly = approach(st.fly, if flying then 1 else 0, 5, dt)
	st.pitch = approach(st.pitch, pitchRaw, 4, dt)
	local fly, spd, m, f = st.fly, st.spd, rig.motors, rig.flip

	-- Action layers (read from the character's replicated attributes):
	-- charge = rear back, breathe in; cast = head/neck thrust forward then settle;
	-- spawn = roar right after transforming (head up, wings flare).
	local char = owner
	local now = workspace:GetServerTimeNow()
	local cs = char and char:GetAttribute("DragonChargeStart")
	local ft = char and char:GetAttribute("DragonFireTime")
	if not st.born then
		st.born = t
	end
	st.charge = approach(st.charge or 0, if typeof(cs) == "number" then math.clamp((now - cs) / 1.5, 0, 1) else 0, 8, dt)
	local sinceFire = if typeof(ft) == "number" then now - ft else 99
	local cast = if sinceFire >= 0 and sinceFire < 0.6 then math.sin(math.min(sinceFire / 0.12, 1) * math.pi * 0.5) * (1 - math.clamp((sinceFire - 0.12) / 0.48, 0, 1)) else 0
	local roarT = t - st.born
	local roar = if roarT < 1.4 then math.sin(math.clamp(roarT / 1.4, 0, 1) * math.pi) else 0
	-- idle look-around on the ground
	st.lookT = (st.lookT or 0) - dt
	if st.lookT <= 0 then
		st.lookT = 2 + math.random() * 3
		st.lookTarget = (math.random() - 0.5) * 0.9
	end
	st.look = approach(st.look or 0, (st.lookTarget or 0) * (1 - fly) * (1 - math.clamp(spd / 8, 0, 1)), 2, dt)

	-- Wings: phase accumulates; downstroke faster than upstroke (sharper, more natural beat).
	local hz = WING_FLAP_HZ_IDLE + (WING_FLAP_HZ_FLY - WING_FLAP_HZ_IDLE + math.clamp(spd / 80, 0, 1) * 1.2) * fly
	st.wing += dt * hz * math.pi * 2
	local ph = st.wing % (math.pi * 2)
	local wave = if ph < math.pi * 0.8 then math.cos(ph / 0.8) else -math.cos((ph - math.pi * 0.8) / 1.2)
	local glide = fly * math.clamp((spd - 60) / 80, 0, 1) * 0.6 -- fast flight: shallower, gliding beats
	local amp = 0.1 + 0.5 * fly * (1 - glide)
	local flap = wave * amp + 0.15 * fly * glide
	for _, side in ipairs({ "L", "R" }) do
		local s = (if side == "R" then 1 else -1) * f
		-- grounded & idle: wings fold back along the body; roar/charge flares them open
		local fold = (1 - fly) * (1 - roar) * (1 - st.charge) * 0.55
		local flare = (roar * 0.5 + st.charge * 0.3) * (1 - fly)
		if m[side .. "_Wing_UpperArm"] then
			m[side .. "_Wing_UpperArm"].Transform = CFrame.Angles(0, -s * fold, s * (flap + flare - fold * 0.3))
		end
		-- forearm/hand lag behind the upper arm (follow-through)
		local lag = wave * amp
		rot(m[side .. "_Wing_Forearm"], 0, 0, s * (flap * 0.5 + lag * 0.15))
		rot(m[side .. "_Wing_Hand"], 0, 0, s * (flap * 0.25 + lag * 0.15))
	end

	-- Legs: phase driven by distance (stride ~ scale*6 studs), tucked while flying.
	local walkW = (1 - fly) * math.clamp(spd / 10, 0, 1)
	st.walk += dt * spd / math.max(rig.scale * 6, 1) * math.pi * 2
	st.idle += dt
	for i, side in ipairs({ "L", "R" }) do
		local p = st.walk + (if i == 1 then 0 else math.pi)
		local swing = math.sin(p) * 0.55 * walkW
		local lift = math.max(math.cos(p), 0) * 0.7 * walkW -- knee bends while the leg swings forward
		local tuck = fly * 0.75
		rot(m[side .. "_Leg_Thigh"], (swing + tuck) * f, 0, 0)
		rot(m[side .. "_Leg_Shin"], (-lift - tuck * 0.7) * f, 0, 0)
		rot(m[side .. "_Foot"], (lift * 0.5 - swing * 0.3 + tuck * 0.4) * f, 0, 0)
	end

	-- Banking from turn rate (smoothed), fed into tail/neck counter-motion.
	local hrp = rig.weld.Part0
	if hrp then
		local look = hrp.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local dy = if st.yaw then (yaw - st.yaw + math.pi) % (math.pi * 2) - math.pi else 0
		st.yaw = yaw
		local rate = if dt > 0 then dy / dt else 0
		-- deadzone + slow filter so small yaw wobble while walking never shakes the head
		local r = if math.abs(rate) < 0.4 then 0 else rate
		st.bank = approach(st.bank, math.clamp(r * 0.15, -0.45, 0.45) * (0.3 + 0.7 * fly), 2.5, dt)
	end

	-- Tail: travelling wave, swings opposite to banking; neck: gentle breathing + counter-bank.
	local sway = 0.06 + 0.05 * walkW + 0.04 * fly
	for i = 1, 10 do
		local k = i / 10
		rot(m[string.format("Tail_%02d", i)], math.sin(st.idle * 2.2 - i * 0.45) * 0.035 * f, math.sin(st.idle * 1.8 + st.walk * 0.5 - i * 0.5) * sway - st.bank * 0.25 * k, 0)
	end
	for i = 1, 4 do
		local rear = (-st.charge * 0.12 - roar * 0.14 + cast * 0.16) -- negative = head back/up
		rot(m[string.format("Neck_%02d", i)], (math.sin(st.idle * 1.5 - i * 0.3) * 0.03 - wave * amp * 0.04 + rear) * f, st.bank * 0.12 + st.look * 0.25, 0)
	end
	rot(m.Head, (-st.pitch * 0.3 - roar * 0.25 + cast * 0.2) * f, st.bank * 0.1 + st.look * 0.3, 0)

	-- Body: bob from wingbeat (lifts on downstroke) or footfalls, pitch and bank.
	local bob = (fly * -wave * amp * 0.5 + (1 - fly) * math.abs(math.sin(st.walk)) * 0.1 * walkW + math.sin(st.idle * 1.5) * 0.03) * rig.scale
	bob -= (st.charge * 0.25 * (1 - fly)) * rig.scale -- crouch while charging on the ground
	local recoil = -cast * 0.08 -- body rocks back as the fireball leaves
	rig.weld.C0 = rig.baseC0 * CFrame.new(0, bob, 0) * CFrame.Angles((st.pitch + recoil - roar * 0.1) * f, 0, st.bank * f)
end

function DragonRig.setJaw(rig: Rig, open: number)
	rot(rig.motors.Jaw, open * rig.flip, 0, 0)
end

return DragonRig
