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
	local len = math.max(head.Size.X, head.Size.Z) * 0.5
	return CFrame.lookAt(head.Position + fwd * len - Vector3.new(0, head.Size.Y * 0.12, 0), head.Position + fwd * (len + 1))
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

-- speed: horizontal studs/s (walk cycle); flying: wings beat + legs tucked; pitch: nose-down rad.
function DragonRig.animate(rig: Rig, t: number, speed: number, flying: boolean, pitch: number)
	local m = rig.motors
	local hz = if flying then WING_FLAP_HZ_FLY + math.clamp(speed / 60, 0, 1) * 1.4 else WING_FLAP_HZ_IDLE
	local amp = if flying then 0.55 else 0.12
	local flap = math.sin(t * hz * math.pi * 2) * amp
	for _, side in ipairs({ "L", "R" }) do
		local s = if side == "R" then 1 else -1
		s *= rig.flip
		rot(m[side .. "_Wing_UpperArm"], 0, 0, s * flap)
		rot(m[side .. "_Wing_Forearm"], 0, 0, s * flap * 0.6)
		rot(m[side .. "_Wing_Hand"], 0, 0, s * flap * 0.35)
	end

	-- Legs: alternate walk cycle on ground, tucked while flying.
	local walk = if flying then 0 else math.clamp(speed / 16, 0, 1)
	local w = math.sin(t * 7) * 0.6 * walk
	for i, side in ipairs({ "L", "R" }) do
		local ph = if i == 1 then w else -w
		local tuck = if flying then 0.7 else 0
		local f = rig.flip
		rot(m[side .. "_Leg_Thigh"], (ph + tuck) * f, 0, 0)
		rot(m[side .. "_Leg_Shin"], (-math.max(ph, 0) * 0.8 - tuck * 0.6) * f, 0, 0)
		rot(m[side .. "_Foot"], 0, 0, 0)
	end

	-- Tail sway travels down the chain; neck counter-bobs.
	local sway = if flying then 0.1 else 0.07 + walk * 0.05
	for i = 1, 10 do
		rot(m[string.format("Tail_%02d", i)], math.sin(t * 2.2 - i * 0.4) * 0.03 * rig.flip, math.sin(t * 2 - i * 0.5) * sway, 0)
	end
	for i = 1, 4 do
		rot(m[string.format("Neck_%02d", i)], math.sin(t * 1.6 - i * 0.3) * 0.04 * rig.flip, 0, 0)
	end
	rot(m.Head, 0, 0, 0)

	local bob = (if flying then math.sin(t * hz * math.pi * 2) * 0.35 else math.sin(t * 7) * 0.12 * walk) * rig.scale
	rig.weld.C0 = rig.baseC0 * CFrame.new(0, bob, 0) * CFrame.Angles(pitch * rig.flip, 0, 0)
end

function DragonRig.setJaw(rig: Rig, open: number)
	rot(rig.motors.Jaw, open * rig.flip, 0, 0)
end

return DragonRig
