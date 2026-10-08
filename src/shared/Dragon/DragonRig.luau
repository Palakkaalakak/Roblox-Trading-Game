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
}

-- Finds the imported dragon wherever it lives by locating a MeshPart named like a joint
-- (ignores the old stripped "RPG Dragon" copy that has none of them).
local cachedSource: Instance? = nil
function DragonRig.findSource(): Instance?
	if cachedSource and cachedSource.Parent then
		return cachedSource
	end
	for _, svc in ipairs({ game:GetService("ReplicatedStorage"), game:GetService("ServerStorage"), workspace }) do
		local m = svc:FindFirstChild("L_Wing_Membrane_4", true)
		if m and m:IsA("MeshPart") and m.Parent then
			cachedSource = m.Parent
			return m.Parent
		end
	end
	return nil
end

-- sourceRoot: where the imported MeshParts live (nil -> placeholder blocks).
-- groundDist: HRP center to feet distance (studs). scale: studs per design unit.
function DragonRig.build(sourceRoot: Instance?, hrp: BasePart, groundDist: number, scale: number, textureId: string?): Rig
	local model = Instance.new("Model")
	model.Name = "WestDragon"
	local parts: { [string]: BasePart } = {}
	local frames: { [string]: CFrame } = {}
	local jointFrames: { [string]: CFrame } = {}

	-- Honour the imported size: scale = (imported Torso size / manifest Torso size) * scale.
	local srcTorso = sourceRoot and sourceRoot:FindFirstChild("Torso", true)
	if srcTorso and srcTorso:IsA("BasePart") then
		scale *= srcTorso.Size.Y / Joints[1].size.Y
	end

	for _, j in ipairs(Joints) do
		local src = sourceRoot and sourceRoot:FindFirstChild(j.name, true)
		local p: BasePart
		if src and src:IsA("MeshPart") then
			p = src:Clone()
			for _, c in ipairs(p:GetChildren()) do
				if c:IsA("Script") or c:IsA("LocalScript") or c:IsA("Weld") or c:IsA("Motor6D") then
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
		frames[j.name] = CFrame.new((j.pivot + j.center) * scale)
		jointFrames[j.name] = CFrame.new(j.pivot * scale)
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
	local base = CFrame.new(0, -groundDist, 0) * CFrame.Angles(0, math.pi, 0) * frames.Torso
	weld.Part0, weld.Part1 = hrp, torso
	weld.C0 = base
	weld:SetAttribute("BaseC0", base)
	weld.Parent = torso
	return { model = model, motors = motors, weld = weld, baseC0 = base }
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
	return { model = model, motors = motors, weld = weld, baseC0 = if typeof(base) == "CFrame" then base else weld.C0 }
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
		rot(m[side .. "_Leg_Thigh"], ph + tuck, 0, 0)
		rot(m[side .. "_Leg_Shin"], -math.max(ph, 0) * 0.8 - tuck * 0.6, 0, 0)
		rot(m[side .. "_Foot"], 0, 0, 0)
	end

	-- Tail sway travels down the chain; neck counter-bobs.
	local sway = if flying then 0.1 else 0.07 + walk * 0.05
	for i = 1, 10 do
		rot(m[string.format("Tail_%02d", i)], math.sin(t * 2.2 - i * 0.4) * 0.03, math.sin(t * 2 - i * 0.5) * sway, 0)
	end
	for i = 1, 4 do
		rot(m[string.format("Neck_%02d", i)], math.sin(t * 1.6 - i * 0.3) * 0.04, 0, 0)
	end
	rot(m.Head, 0, 0, 0)

	local bob = if flying then math.sin(t * hz * math.pi * 2) * 0.35 else math.sin(t * 7) * 0.12 * walk
	rig.weld.C0 = rig.baseC0 * CFrame.new(0, bob, 0) * CFrame.Angles(pitch, 0, 0)
end

function DragonRig.setJaw(rig: Rig, open: number)
	rot(rig.motors.Jaw, open, 0, 0)
end

return DragonRig
