--!strict
-- Client-only VFX for the West dragon fireball: charge orb, launch flash, projectile, explosion.
-- Blox Fruits cel look (same language as the West transform): flat saturated Neon geometry,
-- black/orange Highlight outlines, solid untextured trails, yellow cone rays, black smoke,
-- navy debris cubes, lava cracks and a fire ring. No stock sprites/textures.
-- Everything is driven from one RenderStepped job list; nothing here touches gameplay.

local Players = game:GetService("Players")
local DragonRig = require(script.Parent.DragonRig)
local Config = require(script.Parent.DragonConfig)
local MIN_SIZE: number = Config.FIREBALL.MIN_SIZE

-- When the custom textures are uploaded, the flat coloured-ball layers are cut way back so the
-- textured flipbooks/beams/decals carry the look instead of being buried under spheres.
local function textured(): boolean
	local t = Config.TEXTURES
	return t ~= nil and t.flame_orange_4x4 ~= nil and t.flame_orange_4x4 ~= ""
end
local RunService = game:GetService("RunService")

local FX = {}

local YEL = Color3.fromRGB(255, 225, 0)
local ORG = Color3.fromRGB(255, 85, 0)
local RED = Color3.fromRGB(235, 15, 10)
local CRIMSON = Color3.fromRGB(200, 0, 45)
local VIOLET = Color3.fromRGB(140, 0, 255)
local VSMOKE = Color3.fromRGB(40, 0, 60)
local ROCK = Color3.fromRGB(32, 22, 24)
local PINK = Color3.fromRGB(255, 0, 200) -- hot magenta
local PURPLE = Color3.fromRGB(160, 0, 255) -- vivid violet
local DEEP = Color3.fromRGB(90, 0, 210) -- deep purple core/edges
local WHITE = Color3.fromRGB(255, 250, 225)
local BLK = Color3.fromRGB(18, 16, 20)
local SMOKE = Color3.fromRGB(45, 40, 48)
local NAVY = Color3.fromRGB(30, 36, 72)
local NEON = Enum.Material.Neon
local FLAT = Enum.Material.SmoothPlastic
local FIELD = Enum.Material.ForceField -- shimmering translucent shell

local rng = Random.new()

local folder: Folder? = nil
local function root(): Folder
	local f = folder
	if not f or not f.Parent then
		local nf = Instance.new("Folder")
		nf.Name = "DragonFX"
		nf.Parent = workspace
		folder = nf
		return nf
	end
	return f
end
FX.root = root

-- Job list ------------------------------------------------------------------------------
-- step(k, t, dt): k = t/life clamped to 0..1. Returning true ends the job early.
type Job = { t: number, life: number, step: (number, number, number) -> boolean?, done: (() -> ())? }
local jobs: { Job } = {}

local function job(life: number, step: (number, number, number) -> boolean?, done: (() -> ())?)
	table.insert(jobs, { t = 0, life = life, step = step, done = done })
end

RunService.RenderStepped:Connect(function(dt)
	for i = #jobs, 1, -1 do
		local j = jobs[i]
		j.t += dt
		local k = math.min(j.t / j.life, 1)
		local ok, stop = pcall(j.step, k, j.t, dt)
		if not ok or stop == true or k >= 1 then
			table.remove(jobs, i)
			if j.done then
				pcall(j.done)
			end
		end
	end
end)

-- Camera feedback ---------------------------------------------------------------------------
local shakeAmp = 0
RunService:BindToRenderStep("DragonFXShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shakeAmp > 0.002 then
		local a = shakeAmp
		local cam = workspace.CurrentCamera
		cam.CFrame *= CFrame.Angles(rng:NextNumber(-a, a) * 0.035, rng:NextNumber(-a, a) * 0.035, rng:NextNumber(-a, a) * 0.02)
		shakeAmp = math.max(0, a - dt * (a * 4 + 0.3))
	end
end)

function FX.shake(amount: number)
	shakeAmp = math.max(shakeAmp, amount)
end

local flashFrame: Frame? = nil
function FX.flash(alpha: number, life: number, color: Color3?)
	local f = flashFrame
	if not f or not f.Parent then
		local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not pg then
			return
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "DragonFXFlash"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 90
		gui.Parent = pg
		local nf = Instance.new("Frame")
		nf.Size = UDim2.fromScale(1, 1)
		nf.BorderSizePixel = 0
		nf.BackgroundTransparency = 1
		nf.Parent = gui
		flashFrame = nf
		f = nf
	end
	local frame = f :: Frame
	frame.BackgroundColor3 = color or WHITE
	job(life, function(k)
		frame.BackgroundTransparency = 1 - alpha * (1 - k) ^ 2
		return
	end, function()
		frame.BackgroundTransparency = 1
	end)
end

-- Building blocks -----------------------------------------------------------------------------
local function newPart(color: Color3, parent: Instance?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or NEON
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.one * 0.05
	p.Parent = parent or root()
	return p
end

local function ball(color: Color3, parent: Instance?, material: Enum.Material?): Part
	local p = newPart(color, parent, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Ellipsoid (block + sphere mesh follows Size on all three axes).
local function blob(color: Color3, parent: Instance?, material: Enum.Material?): Part
	local p = newPart(color, parent, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- A Model whose parts share one cel outline (one Highlight covers every descendant).
local function group(outline: Color3?): Model
	local m = Instance.new("Model")
	m.Parent = root()
	if outline then
		local h = Instance.new("Highlight")
		h.FillTransparency = 1
		h.OutlineColor = outline
		h.OutlineTransparency = 0
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = m
		h.Parent = m
	end
	return m
end

local function basis(n: Vector3): (Vector3, Vector3)
	local a = if math.abs(n.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local u = n:Cross(a).Unit
	return u, n:Cross(u).Unit
end

local function randUnit(): Vector3
	while true do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		local m = v.Magnitude
		if m > 0.05 and m <= 1 then
			return v / m
		end
	end
end

-- Random direction in the hemisphere around n, pushed towards n by bias.
local function hemi(n: Vector3, bias: number): Vector3
	local v = randUnit()
	if v:Dot(n) < 0 then
		v = -v
	end
	return (v + n * bias).Unit
end

local function outQuart(k: number): number
	return 1 - (1 - k) ^ 4
end

local function outBack(k: number): number
	local c = 1.9
	return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2
end

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- Flat ring made of N segments, lying in the plane with normal n.
local function segs(n: number, color: Color3, parent: Instance?): { Part }
	local t = {}
	for i = 1, n do
		local p = newPart(color, parent)
		p.Transparency = 1
		t[i] = p
	end
	return t
end

local function placeRing(ps: { Part }, center: Vector3, n: Vector3, rad: number, wid: number)
	local u, v = basis(n)
	local N = #ps
	local len = 2 * math.pi * rad / N * 1.12
	local visible = wid > 0.03 and rad > 0.03
	for i, p in ipairs(ps) do
		local a = (i / N) * 2 * math.pi
		local pos = center + (u * math.cos(a) + v * math.sin(a)) * rad
		local tan = -u * math.sin(a) + v * math.cos(a)
		p.Size = Vector3.new(math.max(wid, 0.05), math.max(wid * 0.3, 0.05), math.max(len, 0.05))
		p.CFrame = CFrame.lookAt(pos, pos + tan, n)
		p.Transparency = if visible then 0 else 1
	end
end

local function ring(center: Vector3, n: Vector3, life: number, r: (number) -> number, w: (number) -> number, color: Color3, count: number?, delay: number?)
	local ps = segs(count or 24, color)
	local d = delay or 0
	job(life + d, function(_, t)
		if t < d then
			return
		end
		local k = math.clamp((t - d) / life, 0, 1)
		placeRing(ps, center, n, r(k), w(k))
		return
	end, function()
		for _, p in ipairs(ps) do
			p:Destroy()
		end
	end)
end

-- Expanding/shrinking sphere puff; transparency ramps from fadeFrom..1.
local function puff(pos: Vector3, drift: Vector3, s0: number, s1: number, c0: Color3, c1: Color3, life: number, material: Enum.Material?, fadeFrom: number?)
	if material == FLAT and textured() then
		return
	end
	local p = ball(c0, nil, material)
	local ff = fadeFrom or 0.5
	job(life, function(k)
		local e = outQuart(k)
		p.Size = Vector3.one * math.max(lerp(s0, s1, e), 0.05)
		p.Position = pos + drift * e
		p.Color = c0:Lerp(c1, k)
		p.Transparency = if k > ff then (k - ff) / (1 - ff) else 0
		return
	end, function()
		p:Destroy()
	end)
end

-- Ballistic chunk with spin; shrinks out over the last 40% of its life.
local function chunk(pos: Vector3, vel: Vector3, size: Vector3, color: Color3, life: number, gravity: number, material: Enum.Material?)
	local p = newPart(color, nil, material)
	local spin = randUnit() * rng:NextNumber(6, 16)
	local rot = CFrame.Angles(rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3), 0)
	local v, x = vel, pos
	job(life, function(k, _, dt)
		v -= Vector3.new(0, gravity * dt, 0)
		v *= (1 - math.min(dt * 1.2, 0.5))
		x += v * dt
		rot *= CFrame.Angles(spin.X * dt, spin.Y * dt, spin.Z * dt)
		p.CFrame = CFrame.new(x) * rot
		local s = if k > 0.6 then 1 - (k - 0.6) / 0.4 else 1
		p.Size = size * math.max(s, 0.02)
		return
	end, function()
		p:Destroy()
	end)
end

-- Cone ray: two crossed flat triangles (4 wedges), apex at origin, wide at the far end.
local function spikeParts(color: Color3, parent: Instance): { WedgePart }
	local t = {}
	for i = 1, 4 do
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.CastShadow = false
		w.Material = NEON
		w.Color = color
		w.Size = Vector3.one * 0.05
		w.Parent = parent
		t[i] = w
	end
	return t
end

local function placeSpike(ws: { WedgePart }, origin: Vector3, dir: Vector3, len: number, hw: number)
	local u, v = basis(dir)
	local L = math.max(len, 0.05)
	local H = math.max(hw, 0.05)
	local center = origin + dir * L / 2
	for i, w in ipairs(ws) do
		local axis = if i <= 2 then u else v
		local side = if i % 2 == 1 then axis else -axis
		local at = center + side * H / 2
		w.Size = Vector3.new(math.max(H * 0.14, 0.05), H, L)
		w.CFrame = CFrame.lookAt(at, at - dir, side)
	end
end

-- Jagged lightning zap around a point.
local function zap(center: Vector3, r: number, color: Color3)
	local a = center + randUnit() * r
	for _ = 1, 3 do
		local b = a + randUnit() * r * 0.5
		local p = newPart(color)
		local L = (b - a).Magnitude
		p.Size = Vector3.new(r * 0.06, r * 0.06, math.max(L, 0.05))
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		job(0.08, function()
			return
		end, function()
			p:Destroy()
		end)
		a = b
	end
end

-- Diamond shard: two cone spikes meeting in the middle (8 wedges).
type Diamond = { a: { WedgePart }, b: { WedgePart } }
local function diamondParts(color: Color3, parent: Instance): Diamond
	return { a = spikeParts(color, parent), b = spikeParts(color, parent) }
end
local function placeDiamond(d: Diamond, center: Vector3, axis: Vector3, L: number, hw: number)
	placeSpike(d.a, center + axis * L / 2, -axis, L / 2, hw)
	placeSpike(d.b, center - axis * L / 2, axis, L / 2, hw)
end

-- Crescent slash: arc of segments in the plane with normal n, sweeping around while it grows.
local function crescent(center: Vector3, n: Vector3, a0: number, sweep: number, r0: number, r1: number, w0: number, life: number, color: Color3, spinRate: number)
	local u, v = basis(n)
	local N = 9
	local ps = segs(N, color)
	job(life, function(k)
		local r = lerp(r0, r1, outQuart(k))
		local w = w0 * (1 - k)
		local off = a0 + spinRate * k
		for i, p in ipairs(ps) do
			local f = (i - 1) / (N - 1)
			local a = off + sweep * f
			local taper = math.sin(f * math.pi) -- thick in the middle, pointed ends
			local pos = center + (u * math.cos(a) + v * math.sin(a)) * r
			local tan = -u * math.sin(a) + v * math.cos(a)
			local len = r * sweep / (N - 1) * 1.15
			p.Size = Vector3.new(math.max(w * taper, 0.05), math.max(w * 0.25, 0.05), math.max(len, 0.05))
			p.CFrame = CFrame.lookAt(pos, pos + tan, n)
			p.Transparency = if w * taper > 0.04 then 0 else 1
		end
		return
	end, function()
		for _, p in ipairs(ps) do
			p:Destroy()
		end
	end)
end

-- Trail on a carrier part. FaceCamera=false so the ribbon spans the two attachments.
local FIRE_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, WHITE),
	ColorSequenceKeypoint.new(0.15, YEL),
	ColorSequenceKeypoint.new(0.5, ORG),
	ColorSequenceKeypoint.new(1, RED),
})
local tex: (string) -> string?
local function trail(carrier: BasePart, p0: Vector3, p1: Vector3, colors: ColorSequence, lifetime: number, texName: string?)
	local a0 = Instance.new("Attachment")
	a0.Position = p0
	a0.Parent = carrier
	local a1 = Instance.new("Attachment")
	a1.Position = p1
	a1.Parent = carrier
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = lifetime
	tr.Color = colors
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.65, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	tr.WidthScale = NumberSequence.new(1, 0.1)
	tr.LightEmission = 0
	tr.Brightness = 4
	tr.FaceCamera = false
	tr.MinLength = 0
	local id = texName and tex(texName)
	if id then
		tr.Texture = id
		tr.TextureMode = Enum.TextureMode.Stretch
		tr.Color = ColorSequence.new(Color3.new(1, 1, 1))
		tr.WidthScale = NumberSequence.new(1, 0.35)
	end
	tr.Parent = carrier
end

-- Custom textures ----------------------------------------------------------------------------
-- Generated by tools/dragon_fx/make_textures.py (assets/dragon_fx/*.png). Upload them and paste the
-- ids into DragonConfig.TEXTURES; any missing texture just skips its layer (geometry still shows).
local TEX: { [string]: string } = Config.TEXTURES or {}
tex = function(name: string): string?
	local id = TEX[name]
	if id == nil or id == "" then
		return nil
	end
	return if string.find(id, "://") then id else "rbxassetid://" .. id
end

local function emitter(parent: Instance, texName: string, props: { [string]: any }): ParticleEmitter?
	local id = tex(texName)
	if not id then
		return nil
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = id
	e.LightEmission = 0
	e.LightInfluence = 0
	e.Brightness = 2.5
	e.Rate = 0
	if string.find(texName, "4x4") then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	elseif string.find(texName, "2x2") then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode.Random
	end
	for k, v in pairs(props) do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- One-shot particle burst at a point.
local function burstAt(pos: Vector3, texName: string, count: number, props: { [string]: any })
	local p = newPart(WHITE)
	p.Transparency = 1
	p.Position = pos
	local e = emitter(p, texName, props)
	if not e then
		p:Destroy()
		return
	end
	e:Emit(count)
	task.delay(3, function()
		p:Destroy()
	end)
end

-- Camera-facing image (4x4 flipbooks are stepped through over `life`), optional delay/rotation.
local function billboard(pos: Vector3, size: number, texName: string, life: number, color: Color3?, rot: number?, delay: number?, spin: number?, grow: number?)
	local id = tex(texName)
	if not id then
		return
	end
	local p = newPart(WHITE)
	p.Transparency = 1
	p.Position = pos
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size, size)
	bb.LightInfluence = 0
	bb.Adornee = p
	bb.Enabled = false
	bb.Parent = p
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = id
	img.ImageColor3 = color or WHITE
	img.Rotation = rot or 0
	img.Parent = bb
	local flip = string.find(texName, "4x4") ~= nil
	if flip then
		img.ImageRectSize = Vector2.new(256, 256)
	end
	local d = delay or 0
	job(life + d, function(_, t)
		if t < d then
			return
		end
		bb.Enabled = true
		local k = math.clamp((t - d) / life, 0, 1)
		if flip then
			local f = math.min(math.floor(k * 16), 15)
			img.ImageRectOffset = Vector2.new((f % 4) * 256, math.floor(f / 4) * 256)
		else
			img.ImageTransparency = if k > 0.5 then (k - 0.5) / 0.5 else 0
		end
		if spin then
			img.Rotation = (rot or 0) + spin * k
		end
		if grow then
			local s = size * lerp(1, grow, outQuart(k))
			bb.Size = UDim2.fromScale(s, s)
		end
		return
	end, function()
		p:Destroy()
	end)
end

-- Flat textured plate (double-sided decal) lying in the plane with normal n; grows s0 -> s1.
local function plate(pos: Vector3, n: Vector3, texName: string, color: Color3, life: number, s0: number, s1: number, spin: number?, fadeFrom: number?, delay: number?)
	local id = tex(texName)
	if not id then
		return
	end
	local p = newPart(WHITE)
	p.Transparency = 1
	local decals = {}
	for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
		local dc = Instance.new("Decal")
		dc.Texture = id
		dc.Face = face
		dc.Color3 = color
		dc.Transparency = 1
		dc.Parent = p
		table.insert(decals, dc)
	end
	local u = basis(n)
	local ff = fadeFrom or 0.5
	local d = delay or 0
	job(life + d, function(_, t)
		if t < d then
			return
		end
		local k = math.clamp((t - d) / life, 0, 1)
		local sz = lerp(s0, s1, outQuart(k))
		p.Size = Vector3.new(sz, 0.05, sz)
		p.CFrame = CFrame.lookAt(pos, pos + u, n) * CFrame.Angles(0, (spin or 0) * (t - d), 0)
		for _, dc in ipairs(decals) do
			dc.Transparency = if k > ff then (k - ff) / (1 - ff) else 0
		end
		return
	end, function()
		p:Destroy()
	end)
end

-- Textured beam between two world points (Terrain attachments). Returns setter + destroyer.
local function tbeam(texName: string, color: Color3, width: number, speed: number, faceCamera: boolean)
	local id = tex(texName)
	if not id then
		return nil
	end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = workspace.Terrain, workspace.Terrain
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Texture = id
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = width * 4
	b.TextureSpeed = speed
	b.Color = ColorSequence.new(color)
	b.LightEmission = 0
	b.LightInfluence = 0
	b.Brightness = 3
	b.FaceCamera = faceCamera
	b.Width0, b.Width1 = width, width
	b.Segments = 6
	b.Parent = workspace.Terrain
	return {
		beam = b,
		set = function(x: Vector3, y: Vector3)
			a0.WorldPosition, a1.WorldPosition = x, y
		end,
		destroy = function()
			b:Destroy()
			a0:Destroy()
			a1:Destroy()
		end,
	}
end

local FLAME_TEX = { R = "flame_orange_4x4", Q = "flame_violet_4x4", F = "flame_crimson_4x4" }

-- Per-move charge/muzzle palettes.
type Pal = { core: Color3, mid: Color3, shell: Color3, shell2: Color3, light: Color3, ringA: Color3, ringB: Color3, ringC: Color3, aura: Color3, orbitA: Color3, orbitB: Color3, streak: { Color3 }, zap: Color3, max: Color3 }
local PAL: { [string]: Pal } = {
	R = { core = WHITE, mid = YEL, shell = ORG, shell2 = RED, light = ORG, ringA = ORG, ringB = YEL, ringC = PURPLE, aura = PURPLE, orbitA = PINK, orbitB = PURPLE, streak = { PURPLE, PINK, YEL, ORG, ORG }, zap = WHITE, max = PINK },
	Q = { core = PINK, mid = VIOLET, shell = DEEP, shell2 = CRIMSON, light = VIOLET, ringA = VIOLET, ringB = CRIMSON, ringC = PINK, aura = VIOLET, orbitA = CRIMSON, orbitB = VIOLET, streak = { VIOLET, PINK, CRIMSON, DEEP }, zap = PINK, max = VIOLET },
	F = { core = ORG, mid = RED, shell = CRIMSON, shell2 = ROCK, light = RED, ringA = ORG, ringB = RED, ringC = CRIMSON, aura = RED, orbitA = ROCK, orbitB = ORG, streak = { ORG, RED, CRIMSON, YEL }, zap = ORG, max = RED },
}

-- Public effects ----------------------------------------------------------------------------

-- Charge orb in front of the mouth. getMouth returns a CFrame facing forward (-Z), or nil to end.
-- Charge visuals: a different design per move, sitting directly in front of the mouth.
local function chargeBase(getMouth: () -> CFrame?, t0: number, maxT: number, maxD: number, step: (Vector3, Vector3, number, number, number, number) -> (), cleanup: () -> ())
	local alive = true
	job(math.huge, function(_, t, dt)
		if not alive then
			return true
		end
		local mcf = getMouth()
		if not mcf then
			alive = false
			return true
		end
		local c = math.clamp((workspace:GetServerTimeNow() - t0) / maxT, 0, 1)
		local D = maxD * DragonRig.sizeFactor(c, MIN_SIZE) * outBack(math.min(t / 0.12, 1))
		local fwd = mcf.LookVector
		step(mcf.Position + fwd * D * 0.55, fwd, D, c, t, dt)
		return
	end, cleanup)
	return {
		stop = function()
			alive = false
		end,
	}
end

-- Invisible ball whose surface emits textured flames + stars inward (converging on the charge).
local function inwardField(flameTex: string, sparkColor: Color3, maxD: number): Part
	local f = newPart(WHITE)
	f.Shape = Enum.PartType.Ball
	f.Transparency = 1
	local function props()
		return {
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			Lifetime = NumberRange.new(0.2, 0.3),
			Speed = NumberRange.new(maxD * 1.2, maxD * 2),
		}
	end
	local e1 = emitter(f, flameTex, props())
	if e1 then
		e1.Rate = 40
		e1.Size = NumberSequence.new(maxD * 0.3, maxD * 0.08)
		e1.Rotation = NumberRange.new(0, 360)
	end
	local e2 = emitter(f, "spark_star", props())
	if e2 then
		e2.Rate = 25
		e2.Size = NumberSequence.new(maxD * 0.15, 0)
		e2.Color = ColorSequence.new(sparkColor)
		e2.RotSpeed = NumberRange.new(-300, 300)
	end
	return f
end

-- R: SOLAR CORE. Outlined white/yellow/orange sun with rotating cone sun-rays that lengthen with
-- charge, flame tongues licking off it, inward flames, white zaps. Flash at max.
local function chargeR(getMouth: () -> CFrame?, t0: number, maxT: number, maxD: number)
	local g = group(BLK)
	local shell, mid, core = ball(ORG, g), ball(YEL, g), ball(WHITE, g)
	local tongues = {}
	for i = 1, 6 do
		tongues[i] = blob(if i % 2 == 0 then ORG else RED, g)
	end
	local raysG = group(ORG)
	local rays = {}
	for i = 1, 8 do
		rays[i] = spikeParts(if i % 2 == 0 then YEL else WHITE, raysG)
	end
	local light = Instance.new("PointLight")
	light.Color = ORG
	light.Parent = core
	local field = inwardField("flame_orange_4x4", YEL, maxD)
	local maxed, zapAcc = false, 0
	return chargeBase(getMouth, t0, maxT, maxD, function(center, fwd, D, c, t, dt)
		local pul = 1 + (0.04 + 0.08 * c) * math.sin(t * (18 + 30 * c))
		shell.Size, mid.Size, core.Size = Vector3.one * D * pul, Vector3.one * D * 0.72 * pul, Vector3.one * D * 0.42 * pul
		shell.Position, mid.Position, core.Position = center, center, center
		shell.Color = ORG:Lerp(RED, 0.4 * math.sin(t * 9) ^ 2)
		local u, v = basis(fwd)
		for i, sp in ipairs(rays) do
			local a = i / #rays * math.pi * 2 + t * 1.5
			local d = u * math.cos(a) + v * math.sin(a)
			local L = D * (0.35 + 0.65 * c) * (0.8 + 0.25 * math.sin(t * 14 + i))
			placeSpike(sp, center + d * (D * 0.45 + L), -d, L, D * 0.13)
		end
		for i, b in ipairs(tongues) do
			local a = i / #tongues * math.pi * 2 + t * 3
			local radial = u * math.cos(a) + v * math.sin(a)
			local L = D * (0.45 + 0.25 * math.sin(t * 20 + i))
			local base = center + radial * D * 0.4
			b.Size = Vector3.new(D * 0.2, D * 0.2, L)
			b.CFrame = CFrame.lookAt(base, base + radial + Vector3.yAxis * 0.5) * CFrame.new(0, 0, -L / 2)
		end
		field.Size = Vector3.one * D * 3
		field.Position = center
		light.Range = math.min(60, D * 4)
		light.Brightness = 2 + 5 * c
		zapAcc += dt * (2 + 14 * c)
		while zapAcc >= 1 do
			zapAcc -= 1
			zap(center, D * 0.6, WHITE)
		end
		if c >= 1 and not maxed then
			maxed = true
			puff(center, Vector3.zero, D * 0.6, D * 1.9, WHITE, YEL, 0.2, nil, 0.2)
		end
	end, function()
		g:Destroy()
		raysG:Destroy()
		field:Destroy()
	end)
end

-- Q: VOID EYE. No ball: a dark violet eye with a glowing pink slit pupil, a double helix of
-- spinning violet/pink diamond shards and crackling lightning beams around it.
local function chargeQ(getMouth: () -> CFrame?, t0: number, maxT: number, maxD: number)
	local g = group(BLK)
	local eye = blob(DEEP, g)
	local pupil = blob(PINK, g)
	local shards: { Diamond } = {}
	for i = 1, 10 do
		shards[i] = diamondParts(if i % 2 == 0 then VIOLET else PINK, g)
	end
	local bolts = {}
	for i = 1, 4 do
		bolts[i] = tbeam("beam_lightning", if i % 2 == 0 then PINK else VIOLET, maxD * 0.1, 8, true)
	end
	local light = Instance.new("PointLight")
	light.Color = VIOLET
	light.Parent = eye
	local field = inwardField("flame_violet_4x4", PINK, maxD)
	local boltAcc, zapAcc = 1, 0
	return chargeBase(getMouth, t0, maxT, maxD, function(center, fwd, D, c, t, dt)
		local ecf = CFrame.lookAt(center, center + fwd)
		eye.Size = Vector3.new(D * 0.75, D * 0.75, D * 0.45) * (1 + 0.06 * math.sin(t * 20))
		eye.CFrame = ecf
		pupil.Size = Vector3.new(D * 0.1, D * 0.6 * (0.5 + 0.5 * c), D * 0.5)
		pupil.CFrame = ecf * CFrame.new(0, 0, -D * 0.04)
		local u, v = basis(fwd)
		for i, d in ipairs(shards) do
			local strand = if i % 2 == 0 then math.pi else 0
			local k = math.ceil(i / 2) / 5
			local a = t * (4 + 6 * c) + k * math.pi * 2 + strand
			local radial = u * math.cos(a) + v * math.sin(a)
			local p = center + radial * D * (0.6 + 0.15 * math.sin(t * 3 + i)) + fwd * (k - 0.5) * D * 0.9
			placeDiamond(d, p, radial:Cross(fwd).Unit, D * (0.25 + 0.2 * c), D * 0.08)
		end
		boltAcc += dt
		if boltAcc > 0.06 then
			boltAcc = 0
			for _, b in ipairs(bolts) do
				if b then
					b.set(center + randUnit() * D * 0.3, center + randUnit() * D * (0.9 + 0.6 * c))
				end
			end
		end
		field.Size = Vector3.one * D * 3
		field.Position = center
		light.Range = math.min(60, D * 4)
		light.Brightness = 2 + 5 * c
		zapAcc += dt * (2 + 12 * c)
		while zapAcc >= 1 do
			zapAcc -= 1
			zap(center, D * 0.55, PINK)
		end
	end, function()
		g:Destroy()
		field:Destroy()
		for _, b in ipairs(bolts) do
			if b then
				b.destroy()
			end
		end
	end)
end

-- F: MOLTEN FORGE. Lava-textured rock blocks orbit and close in as it charges, compacting into a
-- meteor around a small molten core; inward crimson flames, rising smoke.
local function chargeF(getMouth: () -> CFrame?, t0: number, maxT: number, maxD: number)
	local g = group(CRIMSON)
	local core, hot = ball(ORG, g), ball(YEL, g)
	local rockTex = tex("lava_rock")
	local rocks = {}
	for i = 1, 8 do
		local p = newPart(ROCK, g, FLAT)
		if rockTex then
			for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
				local tx = Instance.new("Texture")
				tx.Texture = rockTex
				tx.Face = face
				tx.StudsPerTileU, tx.StudsPerTileV = maxD * 0.5, maxD * 0.5
				tx.Parent = p
			end
		end
		local axis = randUnit()
		local o = axis:Cross(randUnit()).Unit
		rocks[i] = { p = p, axis = axis, o = o, ph = rng:NextNumber(0, 6.3), spin = rng:NextNumber(1.5, 3), r = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0) }
	end
	local light = Instance.new("PointLight")
	light.Color = RED
	light.Parent = core
	local field = inwardField("flame_crimson_4x4", ORG, maxD)
	local smoke = emitter(field, "smoke_2x2", {
		Rate = 8,
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(maxD * 0.2, maxD * 0.5),
		Size = NumberSequence.new(maxD * 0.4, maxD * 1),
		Transparency = NumberSequence.new(0.1, 1),
		Acceleration = Vector3.new(0, maxD * 1.5, 0),
		Rotation = NumberRange.new(0, 360),
	})
	local _ = smoke
	return chargeBase(getMouth, t0, maxT, maxD, function(center, _fwd, D, c, t, _dt)
		core.Size = Vector3.one * D * 0.55 * (1 + 0.08 * math.sin(t * 25))
		hot.Size = Vector3.one * D * 0.32
		core.Position, hot.Position = center, center
		local rad = D * (1.25 - 0.8 * c)
		for _, r in ipairs(rocks) do
			local off = CFrame.fromAxisAngle(r.axis, t * r.spin + r.ph):VectorToWorldSpace(r.o) * rad
			local sz = D * (0.25 + 0.2 * c)
			r.p.Size = Vector3.new(sz, sz * 0.8, sz * 0.9)
			r.p.CFrame = CFrame.new(center + off) * CFrame.Angles(t * 2, t * 1.4, 0) * r.r
		end
		field.Size = Vector3.one * D * 3
		field.Position = center
		light.Range = math.min(60, D * 4)
		light.Brightness = 3 + 5 * c
	end, function()
		g:Destroy()
		field:Destroy()
	end)
end

function FX.charge(getMouth: () -> CFrame?, t0: number, maxT: number, maxD: number, move: string?)
	if move == "Q" then
		return chargeQ(getMouth, t0, maxT, maxD)
	elseif move == "F" then
		return chargeF(getMouth, t0, maxT, maxD)
	end
	return chargeR(getMouth, t0, maxT, maxD)
end

-- Launch flash at the mouth: star shards, white pop, recoil ring.
function FX.muzzle(pos: Vector3, dir: Vector3, D: number, power: number, move: string?)
	local pal = PAL[move or "R"] or PAL.R
	local g = group(ORG)
	for i = 1, 8 + math.floor(power * 4) do
		local ws = spikeParts(if i % 3 == 0 then pal.core else pal.mid, g)
		local d = (dir * 0.8 + randUnit()).Unit
		local len = D * rng:NextNumber(2.2, 3.6)
		job(0.3, function(k)
			local L = len * outQuart(math.min(k / 0.3, 1))
			placeSpike(ws, pos, d, L, D * 0.5 * (1 - k))
			return
		end)
	end
	task.delay(0.35, function()
		g:Destroy()
	end)
	puff(pos, Vector3.zero, D * 0.5, D * 2.4, pal.core, pal.mid, 0.16, nil, 0.2)
	ring(pos, dir, 0.3, function(k)
		return D * lerp(0.6, 3.2, outQuart(k))
	end, function(k)
		return D * 0.35 * (1 - k)
	end, pal.ringB, 20)
	ring(pos, dir, 0.36, function(k)
		return D * lerp(0.4, 2.4, outQuart(k))
	end, function(k)
		return D * 0.18 * (1 - k)
	end, pal.ringA, 18, 0.05)
	ring(pos, dir, 0.42, function(k)
		return D * lerp(0.8, 4, outQuart(k))
	end, function(k)
		return D * 0.16 * (1 - k)
	end, pal.ringC, 22, 0.09)
	for _ = 1, 4 + math.floor(power * 4) do
		chunk(pos, (dir * 0.5 + randUnit()).Unit * D * rng:NextNumber(10, 18), Vector3.new(D * 0.12, D * 0.12, D * 0.6), if rng:NextNumber() < 0.5 then pal.orbitA else pal.orbitB, 0.35, 0)
	end
	for _ = 1, 3 do
		puff(pos - dir * D * 0.5, randUnit() * D + Vector3.new(0, D, 0), D * 0.4, D * 1.1, BLK, SMOKE, 0.7, FLAT, 0.3)
	end
end

export type Shot = { stop: () -> (), pos: Vector3 }

-- Projectile visuals. Position is derived from server time so all clients agree.
local function projectileR(origin: Vector3, dir: Vector3, speed: number, D: number, t0: number, range: number, power: number): Shot
	local g = group(BLK)
	local shell = ball(ORG, g)
	local mid = ball(YEL, g)
	local core = ball(WHITE, g)
	local tail = blob(RED, g)
	local tongues: { Part } = {}
	for i = 1, 7 do
		tongues[i] = blob(if i % 2 == 0 then YEL else ORG, g)
	end
	if textured() then
		tail.Transparency = 1
		for _, b in ipairs(tongues) do
			b.Transparency = 1
		end
	end
	local light = Instance.new("PointLight")
	light.Color = ORG
	light.Range = math.min(60, D * 5)
	light.Brightness = 4 + 4 * power
	light.Parent = core

	local carrier = newPart(ORG)
	carrier.Transparency = 1
	local spinner = newPart(ORG)
	spinner.Transparency = 1
	local life = math.clamp(7 * D / speed, 0.12, 0.45)
	trail(carrier, Vector3.new(0, D * 0.5, 0), Vector3.new(0, -D * 0.5, 0), FIRE_SEQ, life, "beam_flame_orange")
	trail(carrier, Vector3.new(D * 0.5, 0, 0), Vector3.new(-D * 0.5, 0, 0), FIRE_SEQ, life, "beam_flame_orange")
	carrier.Size = Vector3.one * D * 0.6
	emitter(carrier, "flame_orange_4x4", {
		Rate = 80,
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(D * 0.5, D * 2.5),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(25, 25),
		Size = NumberSequence.new(D * 0.95, D * 0.35),
		Rotation = NumberRange.new(-25, 25),
	})
	emitter(carrier, "spark_star", {
		Rate = 30,
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(D * 2, D * 5),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(D * 0.3, 0),
		Color = ColorSequence.new(YEL, ORG),
		RotSpeed = NumberRange.new(-300, 300),
	})
	local helix = 4 + (if power > 0.5 then 1 else 0)
	for i = 1, helix do
		local a = i / helix * math.pi * 2
		local r0, r1 = D * 0.55, D * 0.78
		local cs = if i == 4 then ColorSequence.new(PURPLE, DEEP) elseif i == 5 then ColorSequence.new(PINK, PURPLE) else ColorSequence.new(YEL, ORG)
		trail(spinner, Vector3.new(math.cos(a) * r0, math.sin(a) * r0, 0), Vector3.new(math.cos(a) * r1, math.sin(a) * r1, 0), cs, life * 1.4)
	end

	local shot = { pos = origin } :: any
	local stopped = false
	local spin, emberAcc, smokeAcc, shardAcc = 0, 0, 0, 0
	job(math.huge, function(_, t, dt)
		if stopped then
			return true
		end
		local dist = math.min(speed * math.max(workspace:GetServerTimeNow() - t0, 0), range)
		local pos = origin + dir * dist
		shot.pos = pos
		local cf = CFrame.lookAt(pos, pos + dir)
		local wob = 1 + 0.07 * math.sin(t * 32)
		shell.Size = Vector3.one * D * (1 + 0.05 * math.sin(t * 21))
		mid.Size = Vector3.one * D * 0.72 * wob
		core.Size = Vector3.one * D * 0.42 * wob
		shell.CFrame, mid.CFrame, core.CFrame = cf, cf, cf
		tail.Size = Vector3.new(D * 0.85, D * 0.85, D * 2.2)
		tail.CFrame = cf * CFrame.new(0, 0, D * 0.8)
		spin += dt * 9
		for i, b in ipairs(tongues) do
			local a = spin + i / #tongues * math.pi * 2
			local L = D * (1.1 + 0.6 * math.sin(t * 26 + i * 1.7))
			local r = D * 0.32
			b.Size = Vector3.new(D * 0.32, D * 0.32, L)
			b.CFrame = cf * CFrame.new(math.cos(a) * r, math.sin(a) * r, D * 0.3 + L / 2) * CFrame.Angles(math.sin(a) * 0.3, -math.cos(a) * 0.3, 0)
		end
		carrier.CFrame = cf
		spinner.CFrame = cf * CFrame.Angles(0, 0, spin * 1.6)

		emberAcc += dt
		local emberStep = if textured() then 0.08 else 0.018
		while emberAcc > emberStep do
			emberAcc -= emberStep
			chunk(pos + randUnit() * D * 0.4, -dir * speed * 0.08 + randUnit() * D * 4, Vector3.one * D * rng:NextNumber(0.07, 0.15), if rng:NextNumber() < 0.5 then YEL else ORG, rng:NextNumber(0.25, 0.45), 0)
		end
		smokeAcc += dt
		if smokeAcc > 0.045 then
			smokeAcc = 0
			puff(pos - dir * D * 1.3, Vector3.new(0, D * 0.8, 0) + randUnit() * D * 0.3, D * 0.45, D * 1.1, BLK, SMOKE, 0.55, FLAT, 0.3)
		end
		if power > 0.5 then
			shardAcc += dt
			if shardAcc > 0.06 then
				shardAcc = 0
				chunk(pos + randUnit() * D * 0.6, randUnit() * D * 3, Vector3.new(D * 0.06, D * 0.06, D * 0.4), if rng:NextNumber() < 0.5 then PINK else PURPLE, 0.3, 0)
			end
		end
		if dist >= range + D * 4 then
			stopped = true
			return true
		end
		return
	end, function()
		g:Destroy()
		task.delay(0.6, function()
			carrier:Destroy()
			spinner:Destroy()
		end)
	end)

	shot.stop = function()
		stopped = true
	end
	return shot :: Shot
end

-- Impact. R = damage radius (studs), grounded = hit a floor-like surface, power = charge 0..1.
local function explodeR(pos: Vector3, normal: Vector3, R: number, grounded: boolean, power: number)
	local n = if normal.Magnitude > 0.01 then normal.Unit else Vector3.yAxis
	local u, v = basis(n)

	-- 1. White-out core pop.
	puff(pos, Vector3.zero, R * 0.3, R * 1.15, ORG, ORG, 0.22, nil, 0.35)

	-- 2. Cel fireball: cluster of balls that pop (outBack), drift out/up, shift yellow->orange->red, shrink out.
	local fire = group(BLK)
	for _ = 1, (if textured() then 3 else 11 + math.floor(power * 7)) do
		local off = hemi(n, 0.6) * R * rng:NextNumber(0, 0.45)
		local size = R * rng:NextNumber(0.38, 0.62)
		local inner = off.Magnitude < R * 0.2
		local c0 = if inner then ORG else ORG
		local c1 = if inner then ORG elseif rng:NextNumber() < 0.5 then RED else CRIMSON
		local b = ball(c0, fire)
		b.Size = Vector3.one * 0.05
		b.Position = pos
		local delay = rng:NextNumber(0, 0.08)
		local life = rng:NextNumber(0.75, 1.05)
		job(life + delay, function(_, t)
			if t < delay then
				return
			end
			local k = math.clamp((t - delay) / life, 0, 1)
			local grow = outBack(math.min(k / 0.22, 1))
			local shrink = if k > 0.5 then 1 - ((k - 0.5) / 0.5) ^ 1.5 else 1
			b.Size = Vector3.one * math.max(size * grow * shrink, 0.05)
			b.Position = pos + off * (0.6 + 0.9 * outQuart(k)) + n * R * 0.35 * k
			b.Color = c0:Lerp(c1, math.min(k * 2.2, 1)):Lerp(CRIMSON, math.max(0, (k - 0.6) / 0.4))
			return
		end)
	end
	-- Deep-purple edge flames around the cluster (unique accent, outlined with the cluster).
	for i = 1, (if textured() then 0 else 5 + math.floor(power * 3)) do
		local d = hemi(n, 0.3)
		local b = ball(if i % 2 == 0 then PURPLE else DEEP, fire)
		b.Size = Vector3.one * 0.05
		local size = R * rng:NextNumber(0.2, 0.32)
		job(0.9, function(k)
			local env = outBack(math.min(k / 0.25, 1)) * (if k > 0.5 then 1 - (k - 0.5) / 0.5 else 1)
			b.Size = Vector3.one * math.max(size * env, 0.05)
			b.Position = pos + d * R * lerp(0.35, 0.95, outQuart(k)) + n * R * 0.25 * k
			b.Color = (if i % 2 == 0 then PURPLE else DEEP):Lerp(VIOLET, k)
			return
		end)
	end
	task.delay(1.25, function()
		fire:Destroy()
	end)

	-- Shimmering purple shock dome.
	local dome = ball(PURPLE, nil, FIELD)
	job(0.65, function(k)
		dome.Size = Vector3.one * R * lerp(0.4, 2.4, outQuart(k))
		dome.Position = pos
		dome.Transparency = if k > 0.5 then (k - 0.5) / 0.5 else 0
		return
	end, function()
		dome:Destroy()
	end)

	-- Crescent slashes spinning out in random planes.
	for i = 1, 6 + math.floor(power * 4) do
		local cn = randUnit()
		crescent(pos, cn, rng:NextNumber(0, 6.3), rng:NextNumber(1.2, 2.2), R * 0.3, R * rng:NextNumber(1.1, 1.6), R * 0.12, rng:NextNumber(0.35, 0.5), if i % 3 == 0 then ORG elseif i % 3 == 1 then PURPLE else VIOLET, rng:NextNumber(2, 4) * (if rng:NextNumber() < 0.5 then -1 else 1))
	end

	-- Charged shots: fire pillar erupting along the normal, outlined in deep purple.
	if power > 0.5 then
		local pillar = group(DEEP)
		local outer, inner = blob(RED, pillar), blob(ORG, pillar)
		local core = blob(ORG, pillar)
		local h = R * (2.2 + 1.6 * power)
		job(0.8, function(k, t)
			local grow = outBack(math.min(k / 0.25, 1))
			local fade = if k > 0.55 then 1 - (k - 0.55) / 0.45 else 1
			local w = R * 0.55 * fade * (1 + 0.06 * math.sin(t * 30))
			local H = h * grow
			local c = pos + n * H / 2
			outer.Size = Vector3.new(w, H, w)
			outer.CFrame = CFrame.lookAt(c, c + basis(n), n)
			inner.Size = Vector3.new(w * 0.62, H * 0.9, w * 0.62)
			inner.CFrame = outer.CFrame
			core.Size = Vector3.new(w * 0.28, H * 0.8, w * 0.28)
			core.CFrame = outer.CFrame
			return
		end)
		task.delay(0.85, function()
			pillar:Destroy()
		end)
	end

	-- 3. Thick yellow cone rays with orange outlines.
	local rays = group(RED)
	for _ = 1, 9 + math.floor(power * 6) do
		local d = hemi(n, 0.35)
		local ws = spikeParts(ORG, rays)
		local len = R * rng:NextNumber(1.3, 2.2)
		local hw = R * rng:NextNumber(0.16, 0.28)
		local delay = rng:NextNumber(0, 0.07)
		placeSpike(ws, pos, d, 0.05, 0.05)
		job(0.5 + delay, function(_, t)
			if t < delay then
				return
			end
			local k = math.clamp((t - delay) / 0.5, 0, 1)
			local L = len * outQuart(math.min(k / 0.25, 1))
			local w = hw * (if k < 0.25 then 1 else 1 - (k - 0.25) / 0.75)
			placeSpike(ws, pos + d * R * 0.15, d, L, w)
			return
		end)
	end
	task.delay(0.65, function()
		rays:Destroy()
	end)

	-- 4. Shock rings (yellow, orange, thin pink accent).
	ring(pos, n, 0.45, function(k)
		return R * lerp(0.25, 1.9, outQuart(k))
	end, function(k)
		return R * 0.2 * (1 - k)
	end, ORG, 32)
	ring(pos, n, 0.5, function(k)
		return R * lerp(0.2, 1.45, outQuart(k))
	end, function(k)
		return R * 0.13 * (1 - k)
	end, RED, 28, 0.06)
	ring(pos + n * R * 0.05, n, 0.55, function(k)
		return R * lerp(0.3, 2.3, outQuart(k))
	end, function(k)
		return R * 0.05 * (1 - k)
	end, VIOLET, 32, 0.1)
	ring(pos + n * R * 0.08, n, 0.6, function(k)
		return R * lerp(0.4, 2.7, outQuart(k))
	end, function(k)
		return R * 0.09 * (1 - k)
	end, PURPLE, 36, 0.16)

	-- 5. Black smoke billowing up after the fire.
	task.delay(0.12, function()
		for _ = 1, 8 + math.floor(power * 5) do
			local o = hemi(n, 0.4) * R * rng:NextNumber(0.2, 0.6)
			puff(pos + o, n * R * 0.7 + o * 0.6 + Vector3.new(0, R * 0.4, 0), R * 0.35, R * rng:NextNumber(0.7, 0.95), BLK, SMOKE, rng:NextNumber(1.1, 1.6), FLAT, 0.45)
		end
	end)

	-- 6. Navy debris cubes, embers, black shards.
	for _ = 1, 14 do
		chunk(pos + randUnit() * R * 0.2, hemi(n, 0.5) * R * rng:NextNumber(1.6, 2.8), Vector3.one * R * rng:NextNumber(0.05, 0.11), NAVY, rng:NextNumber(0.9, 1.3), R * 4, FLAT)
	end
	for i = 1, 34 do
		local col = if i % 4 == 0 then PURPLE elseif i % 4 == 1 then VIOLET elseif i % 2 == 0 then ORG else RED
		chunk(pos, hemi(n, 0.2) * R * rng:NextNumber(2, 3.6), Vector3.one * R * rng:NextNumber(0.02, 0.045), col, rng:NextNumber(0.5, 0.9), R * 3)
	end
	for _ = 1, 7 do
		chunk(pos, hemi(n, 0.3) * R * rng:NextNumber(2.5, 3.5), Vector3.new(R * 0.035, R * 0.035, R * 0.24), BLK, 0.5, R * 2, FLAT)
	end

	-- 7. Ground: scorch disc, glowing lava cracks, ring of flame tongues.
	if grounded then
		local sc = newPart(BLK, nil, FLAT)
		sc.Shape = Enum.PartType.Cylinder
		sc.Size = Vector3.new(0.2, R * 1.7, R * 1.7)
		sc.CFrame = CFrame.lookAt(pos, pos + n) * CFrame.Angles(0, math.pi / 2, 0)
		sc.Transparency = 0.25
		job(2.6, function(k)
			sc.Transparency = 0.25 + 0.75 * math.max(0, (k - 0.4) / 0.6)
			return
		end, function()
			sc:Destroy()
		end)

		local cracks: { { p: Part, i: number } } = {}
		for c = 1, 8 do
			local a = c / 8 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local d = u * math.cos(a) + v * math.sin(a)
			local x = pos + n * 0.15
			for i = 1, 5 do
				local ang = rng:NextNumber(-0.6, 0.6)
				local d2 = (d * math.cos(ang) + n:Cross(d) * math.sin(ang)).Unit
				local L = R * rng:NextNumber(0.16, 0.28)
				local y = x + d2 * L
				local p = newPart(RED)
				p.Size = Vector3.new(R * 0.04 * (1 - i * 0.12), 0.15, L)
				p.CFrame = CFrame.lookAt((x + y) / 2, y, n)
				p.Transparency = 1
				table.insert(cracks, { p = p, i = i })
				x, d = y, d2
			end
		end
		job(1.9, function(k)
			for _, cr in ipairs(cracks) do
				local reveal = k * 6 >= cr.i * 0.18
				cr.p.Transparency = if not reveal then 1 elseif k > 0.5 then (k - 0.5) / 0.5 else 0
				cr.p.Color = ORG:Lerp(CRIMSON, k)
			end
			return
		end, function()
			for _, cr in ipairs(cracks) do
				cr.p:Destroy()
			end
		end)

		local flames = group(CRIMSON)
		for i = 1, 16 do
			local a = i / 16 * math.pi * 2
			local base = pos + (u * math.cos(a) + v * math.sin(a)) * R * 0.95
			local tan = -u * math.sin(a) + v * math.cos(a)
			local outer, inner = blob(RED, flames), blob(ORG, flames)
			job(1.6, function(k, t)
				local env = outBack(math.min(k / 0.15, 1)) * (if k > 0.6 then 1 - (k - 0.6) / 0.4 else 1)
				local h = R * (0.32 + 0.14 * math.sin(t * 18 + i * 1.3)) * math.max(env, 0.01)
				local w = R * 0.17 * math.max(env, 0.01)
				local c = base + n * h / 2
				outer.Size = Vector3.new(w, h, w)
				outer.CFrame = CFrame.lookAt(c, c + tan, n)
				inner.Size = Vector3.new(w * 0.55, h * 0.7, w * 0.55)
				inner.CFrame = CFrame.lookAt(c - n * h * 0.12, c - n * h * 0.12 + tan, n)
				return
			end)
		end
		task.delay(1.7, function()
			flames:Destroy()
		end)
	end

	-- 8. Light burst.
	local lp = newPart(RED)
	lp.Transparency = 1
	lp.Position = pos
	local L = Instance.new("PointLight")
	L.Color = RED
	L.Range = math.min(60, R * 2)
	L.Brightness = 10
	L.Parent = lp
	job(0.8, function(k)
		L.Brightness = 10 * (1 - k)
		return
	end, function()
		lp:Destroy()
	end)

	-- 9. Local camera feedback, by distance.
	local cam = workspace.CurrentCamera
	local i = math.clamp(1 - (cam.CFrame.Position - pos).Magnitude / (R * 8), 0, 1)
	if i > 0 then
		FX.shake(i * (0.8 + 1.2 * power))
		FX.flash(0.45 * i, 0.25, ORG)
	end
end

-- Shared impact helpers (Q / F) ----------------------------------------------------------------

-- Outlined cel fire cluster: balls pop (outBack), drift out/up, shift c0 -> c1, shrink out.
local function fireCluster(pos: Vector3, n: Vector3, R: number, count: number, c0s: { Color3 }, c1s: { Color3 }, outline: Color3, sizeMul: number, life: number)
	local fire = group(outline)
	if textured() then
		count = math.max(2, math.floor(count * 0.25))
	end
	for _ = 1, count do
		local off = hemi(n, 0.6) * R * rng:NextNumber(0, 0.5)
		local size = R * rng:NextNumber(0.36, 0.62) * sizeMul
		local c0 = c0s[rng:NextInteger(1, #c0s)]
		local c1 = c1s[rng:NextInteger(1, #c1s)]
		local b = ball(c0, fire)
		b.Size = Vector3.one * 0.05
		b.Position = pos
		local delay = rng:NextNumber(0, 0.08)
		local l = life * rng:NextNumber(0.8, 1.1)
		job(l + delay, function(_, t)
			if t < delay then
				return
			end
			local k = math.clamp((t - delay) / l, 0, 1)
			local grow = outBack(math.min(k / 0.22, 1))
			local shrink = if k > 0.5 then 1 - ((k - 0.5) / 0.5) ^ 1.5 else 1
			b.Size = Vector3.one * math.max(size * grow * shrink, 0.05)
			b.Position = pos + off * (0.6 + 0.9 * outQuart(k)) + n * R * 0.35 * k
			b.Color = c0:Lerp(c1, math.min(k * 1.8, 1))
			return
		end)
	end
	task.delay(life * 1.2 + 0.1, function()
		fire:Destroy()
	end)
end

local function impulse(pos: Vector3, R: number, shake: number, flashA: number, color: Color3)
	local cam = workspace.CurrentCamera
	local i = math.clamp(1 - (cam.CFrame.Position - pos).Magnitude / (R * 8), 0, 1)
	if i > 0 then
		FX.shake(i * shake)
		FX.flash(flashA * i, 0.3, color)
	end
	local lp = newPart(color)
	lp.Transparency = 1
	lp.Position = pos
	local L = Instance.new("PointLight")
	L.Color = color
	L.Range = math.min(60, R * 2)
	L.Brightness = 10
	L.Parent = lp
	job(0.9, function(k)
		L.Brightness = 10 * (1 - k)
		return
	end, function()
		lp:Destroy()
	end)
end

-- Q: VIOLET SERPENT ------------------------------------------------------------------------------
-- A wedge-built crimson serpent skull (cone snout, crest, violet horns, jaw spikes, glowing eyes)
-- leading a ribbon body: textured violet flame beams + pink lightning beams strung through the
-- head's corkscrew path, shedding violet flames and stars. No balls. Without uploaded textures the
-- body falls back to outlined neon segments.
local function projectileQ(origin: Vector3, dir: Vector3, speed: number, D: number, t0: number, range: number, power: number): Shot
	local g = group(BLK)
	local snout, crest = spikeParts(CRIMSON, g), spikeParts(VIOLET, g)
	local horns = { spikeParts(VIOLET, g), spikeParts(VIOLET, g) }
	local jaw = { spikeParts(DEEP, g), spikeParts(DEEP, g) }
	local eyes = { ball(PINK, g), ball(PINK, g) }
	local N = 11
	local flames, bolts, segsF = {}, {}, {}
	for i = 1, N - 1 do
		local f = tbeam("beam_flame_violet", WHITE, D * (1.05 - i * 0.085), 1.5, true)
		if f then
			flames[i] = f
		else
			segsF[i] = newPart(if i % 2 == 0 then VIOLET else CRIMSON, g)
		end
		if i % 2 == 1 then
			bolts[i] = tbeam("beam_lightning", if i % 4 == 1 then PINK else VIOLET, D * 0.45, 6, true)
		end
	end
	local carrier = newPart(VIOLET)
	carrier.Transparency = 1
	carrier.Size = Vector3.one * D * 0.6
	emitter(carrier, "flame_violet_4x4", {
		Rate = 70,
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(D, D * 3),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(30, 30),
		Size = NumberSequence.new(D * 0.9, D * 0.3),
		Rotation = NumberRange.new(-20, 20),
	})
	emitter(carrier, "spark_star", {
		Rate = 25,
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(D * 2, D * 5),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(D * 0.35, 0),
		Color = ColorSequence.new(PINK, VIOLET),
		RotSpeed = NumberRange.new(-250, 250),
	})
	local light = Instance.new("PointLight")
	light.Color = VIOLET
	light.Range = math.min(60, D * 5)
	light.Brightness = 5 + 4 * power
	light.Parent = carrier

	local u, v = basis(dir)
	local hist: { Vector3 } = {}
	local shot = { pos = origin } :: any
	local stopped = false
	local shedAcc = 0
	job(math.huge, function(_, t, dt)
		if stopped then
			return true
		end
		local dist = math.min(speed * math.max(workspace:GetServerTimeNow() - t0, 0), range)
		local base = origin + dir * dist
		shot.pos = base
		local w = t * 10
		local hp = base + (u * math.cos(w) + v * math.sin(w)) * D * 0.6 * math.min(t / 0.15, 1)
		table.insert(hist, 1, hp)
		if #hist > N * 3 + 1 then
			table.remove(hist)
		end
		local function at(i: number): Vector3
			return hist[math.min((i - 1) * 3 + 1, #hist)]
		end
		for i = 1, N - 1 do
			local x, y = at(i), at(i + 1)
			if flames[i] then
				flames[i].set(x, y)
			elseif segsF[i] then
				local L = math.max((y - x).Magnitude, 0.05)
				local wd = D * (0.8 - i * 0.06)
				segsF[i].Size = Vector3.new(wd, wd, L + wd * 0.5)
				segsF[i].CFrame = if L > 0.06 then CFrame.lookAt((x + y) / 2, y) else CFrame.new(x)
			end
			if bolts[i] then
				bolts[i].set(x, at(math.min(i + 2, N)))
			end
		end

		local hcf = CFrame.lookAt(hp, hp + dir)
		local up, right = hcf.UpVector, hcf.RightVector
		local tip = hp + dir * D * 0.95
		placeSpike(snout, tip, -dir, D * 1.5, D * 0.5)
		local ct = hp + up * D * 0.6 - dir * D * 1.1
		placeSpike(crest, ct, (hp + up * D * 0.15 - ct).Unit, (hp + up * D * 0.15 - ct).Magnitude, D * 0.28)
		for i, hn in ipairs(horns) do
			local side = if i == 1 then 1 else -1
			local o = hp + right * side * D * 0.3 + up * D * 0.3
			local d2 = (right * side * 0.4 + up * 0.5 - dir).Unit
			placeSpike(hn, o + d2 * D * 1.0, -d2, D * 1.0, D * 0.2)
		end
		for i, jw in ipairs(jaw) do
			local side = if i == 1 then 1 else -1
			local jt = hp + right * side * D * 0.45 - up * D * 0.35 - dir * D * 0.8
			placeSpike(jw, jt, (hp - jt).Unit, (hp - jt).Magnitude, D * 0.18)
		end
		for i, e in ipairs(eyes) do
			local side = if i == 1 then 1 else -1
			e.Size = Vector3.one * D * 0.2 * (1 + 0.15 * math.sin(t * 25))
			e.Position = hp + dir * D * 0.25 + right * side * D * 0.27 + up * D * 0.18
		end
		carrier.CFrame = hcf

		shedAcc += dt
		while shedAcc > 0.03 do
			shedAcc -= 0.03
			chunk(at(rng:NextInteger(2, N)), randUnit() * D * 3 + Vector3.new(0, D * 2, 0), Vector3.new(D * 0.08, D * 0.08, D * 0.35), if rng:NextNumber() < 0.5 then VIOLET else CRIMSON, 0.35, -D * 4)
		end
		if dist >= range + D * 4 then
			stopped = true
			return true
		end
		return
	end, function()
		g:Destroy()
		for _, f in pairs(flames) do
			f.destroy()
		end
		for _, b in pairs(bolts) do
			if b then
				b.destroy()
			end
		end
		for _, e in ipairs(carrier:GetChildren()) do
			if e:IsA("ParticleEmitter") then
				e.Enabled = false
			end
		end
		task.delay(0.8, function()
			carrier:Destroy()
		end)
	end)
	shot.stop = function()
		stopped = true
	end
	return shot :: Shot
end

-- Implosion of violet streaks, then a violet/crimson burst, a 3-armed flame vortex twisting up,
-- crimson/violet crescent slashes and a burning pentagram on the ground.
local function explodeQ(pos: Vector3, normal: Vector3, R: number, grounded: boolean, power: number)
	local n = if normal.Magnitude > 0.01 then normal.Unit else Vector3.yAxis
	local u, v = basis(n)
	for i = 1, 26 do
		local d = randUnit()
		local p = newPart(if i % 3 == 0 then PINK else VIOLET)
		local r0 = R * rng:NextNumber(1.4, 2.2)
		job(0.16, function(k)
			local r = r0 * (1 - k * k)
			local L = R * 0.5 * (1 - k) + 0.05
			local a = pos + d * r
			p.Size = Vector3.new(R * 0.03, R * 0.03, L)
			p.CFrame = CFrame.lookAt(a + d * L / 2, a)
			return
		end, function()
			p:Destroy()
		end)
	end
	task.delay(0.14, function()
		puff(pos, Vector3.zero, R * 0.25, R * 1.05, PINK, VIOLET, 0.22, nil, 0.3)
		fireCluster(pos, n, R, 14 + math.floor(power * 6), { VIOLET, PINK, CRIMSON }, { CRIMSON, DEEP, DEEP }, BLK, 1, 0.95)

		local col = group(BLK)
		local arms = {}
		for a = 1, 3 do
			for j = 1, 9 do
				table.insert(arms, { a = a, j = j, p = blob(if j % 2 == 0 then VIOLET else CRIMSON, col) })
			end
		end
		local H = R * (2.2 + power)
		job(1.1, function(k, t)
			local rise = outQuart(math.min(k / 0.5, 1))
			local fade = if k > 0.6 then 1 - (k - 0.6) / 0.4 else 1
			for _, e in ipairs(arms) do
				local f = e.j / 9
				local ang = e.a / 3 * math.pi * 2 + f * 4 + t * 7
				local rad = R * (0.55 - 0.35 * f) * (0.6 + 0.4 * rise)
				local c = pos + n * H * f * rise + (u * math.cos(ang) + v * math.sin(ang)) * rad
				local sz = math.max(R * (0.34 - 0.18 * f) * fade, 0.05)
				e.p.Size = Vector3.new(sz, sz * 1.5, sz)
				e.p.CFrame = CFrame.lookAt(c, c + (-u * math.sin(ang) + v * math.cos(ang)), n)
				e.p.Color = (if e.j % 2 == 0 then VIOLET else CRIMSON):Lerp(PINK, k * 0.6)
			end
			return
		end)
		task.delay(1.15, function()
			col:Destroy()
		end)

		for i = 1, 8 + math.floor(power * 4) do
			crescent(pos, randUnit(), rng:NextNumber(0, 6.3), rng:NextNumber(1.3, 2.3), R * 0.25, R * rng:NextNumber(1.0, 1.5), R * 0.13, 0.45, if i % 2 == 0 then CRIMSON else VIOLET, rng:NextNumber(2, 4) * (if rng:NextNumber() < 0.5 then -1 else 1))
		end
		for i = 1, 30 do
			chunk(pos, hemi(n, 0.2) * R * rng:NextNumber(2, 3.4), Vector3.one * R * rng:NextNumber(0.02, 0.045), if i % 2 == 0 then VIOLET else CRIMSON, rng:NextNumber(0.5, 0.9), R * 3)
		end
		for _ = 1, 10 do
			local o = hemi(n, 0.4) * R * rng:NextNumber(0.2, 0.6)
			puff(pos + o, n * R * 0.7 + o * 0.5, R * 0.3, R * rng:NextNumber(0.6, 0.9), VSMOKE, BLK, rng:NextNumber(1.1, 1.5), FLAT, 0.45)
		end

		if grounded then
			local pts = {}
			for i = 0, 4 do
				local a = i / 5 * math.pi * 2 + math.pi / 2
				pts[i + 1] = pos + n * 0.2 + (u * math.cos(a) + v * math.sin(a)) * R * 1.15
			end
			local lines = {}
			for i = 1, 5 do
				local p = newPart(PINK)
				p.Transparency = 1
				table.insert(lines, { p = p, a = pts[i], b = pts[((i + 1) % 5) + 1] })
			end
			job(1.8, function(k)
				local grow = outQuart(math.min(k / 0.25, 1))
				for _, l in ipairs(lines) do
					local e = l.a:Lerp(l.b, grow)
					local L = (e - l.a).Magnitude
					l.p.Size = Vector3.new(R * 0.06, 0.2, math.max(L, 0.05))
					l.p.CFrame = CFrame.lookAt((l.a + e) / 2, e, n)
					l.p.Transparency = if k > 0.6 then (k - 0.6) / 0.4 else 0
					l.p.Color = PINK:Lerp(DEEP, k)
				end
				return
			end, function()
				for _, l in ipairs(lines) do
					l.p:Destroy()
				end
			end)
		end
		impulse(pos, R, 1 + 1.2 * power, 0.45, VIOLET)
	end)
end

-- F: INFERNO METEOR --------------------------------------------------------------------------------
-- A tumbling cluster of lava-cracked rock blocks (lava_rock texture) inside a roaring cel flame
-- flipbook stream, a crown of backward flame spikes, black smoke and falling rock debris.
-- No balls; without uploaded textures it falls back to neon cracks + flame shell blobs.
local function projectileF(origin: Vector3, dir: Vector3, speed: number, D: number, t0: number, range: number, power: number): Shot
	local g = group(CRIMSON)
	local rockTex = tex("lava_rock")
	local rocks = {}
	for i = 1, 8 do
		local p = newPart(ROCK, g, FLAT)
		if rockTex then
			for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
				local tx = Instance.new("Texture")
				tx.Texture = rockTex
				tx.Face = face
				tx.StudsPerTileU, tx.StudsPerTileV = D * 0.7, D * 0.7
				tx.Parent = p
			end
		end
		rocks[i] = {
			p = p,
			o = if i == 1 then Vector3.zero else randUnit(),
			s = if i == 1 then D * 0.62 else D * rng:NextNumber(0.3, 0.42),
			r = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
		}
	end
	local cracks = {}
	if not rockTex then
		for i = 1, 10 do
			cracks[i] = { p = newPart(ORG, g), o = randUnit(), d = randUnit() }
		end
	end
	local spikes = {}
	for i = 1, 6 do
		spikes[i] = spikeParts(if i % 2 == 0 then ORG else RED, g)
	end
	local carrier = newPart(RED)
	carrier.Transparency = 1
	carrier.Size = Vector3.one * D * 0.8
	local fire = emitter(carrier, "flame_crimson_4x4", {
		Rate = 110,
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(D * 0.5, D * 2),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(30, 30),
		Size = NumberSequence.new(D * 1.4, D * 0.5),
		Rotation = NumberRange.new(-25, 25),
	})
	emitter(carrier, "smoke_2x2", {
		Rate = 30,
		Lifetime = NumberRange.new(0.8, 1.2),
		Speed = NumberRange.new(D * 0.5, D),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(20, 20),
		Size = NumberSequence.new(D * 0.8, D * 2.2),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Acceleration = Vector3.new(0, D * 2, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
	emitter(carrier, "spark_star", {
		Rate = 30,
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(D * 3, D * 6),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(D * 0.4, 0),
		Color = ColorSequence.new(ORG, RED),
		RotSpeed = NumberRange.new(-300, 300),
	})
	local flame, flame2
	if not fire then
		flame, flame2 = blob(ORG, g), blob(RED, g)
	end
	local light = Instance.new("PointLight")
	light.Color = RED
	light.Range = math.min(60, D * 6)
	light.Brightness = 8
	light.Parent = carrier
	local tl = math.clamp(10 * D / speed, 0.2, 0.7)
	local seq = ColorSequence.new({
		ColorSequenceKeypoint.new(0, ORG),
		ColorSequenceKeypoint.new(0.4, RED),
		ColorSequenceKeypoint.new(1, CRIMSON),
	})
	trail(carrier, Vector3.new(0, D * 0.6, 0), Vector3.new(0, -D * 0.6, 0), seq, tl, "beam_flame_orange")
	trail(carrier, Vector3.new(D * 0.6, 0, 0), Vector3.new(-D * 0.6, 0, 0), seq, tl, "beam_flame_orange")

	local u, v = basis(dir)
	local shot = { pos = origin } :: any
	local stopped = false
	local puffAcc, rockAcc = 0, 0
	job(math.huge, function(_, t, dt)
		if stopped then
			return true
		end
		local dist = math.min(speed * math.max(workspace:GetServerTimeNow() - t0, 0), range)
		local pos = origin + dir * dist
		shot.pos = pos
		local cf = CFrame.lookAt(pos, pos + dir)
		local tumble = CFrame.Angles(t * 3, t * 2, 0)
		for _, r in ipairs(rocks) do
			local off = tumble:VectorToWorldSpace(r.o) * D * 0.36
			r.p.Size = Vector3.new(r.s, r.s * 0.75, r.s * 0.9)
			r.p.CFrame = CFrame.new(pos + off) * tumble * r.r
		end
		for _, c in ipairs(cracks) do
			local ow = tumble:VectorToWorldSpace(c.o)
			local dw = tumble:VectorToWorldSpace(c.d)
			local tan = dw - ow * dw:Dot(ow)
			tan = if tan.Magnitude > 0.01 then tan.Unit else u
			local at = pos + ow * D * 0.4
			c.p.Size = Vector3.new(D * 0.05, D * 0.05, D * 0.32)
			c.p.CFrame = CFrame.lookAt(at, at + tan)
		end
		for i, sp in ipairs(spikes) do
			local a = i / #spikes * math.pi * 2 + t * 2
			local radial = u * math.cos(a) + v * math.sin(a)
			local d2 = (-dir + radial * 0.5).Unit
			local L = D * (1.3 + 0.5 * math.sin(t * 22 + i))
			placeSpike(sp, pos + radial * D * 0.45 + d2 * L, -d2, L, D * 0.22)
		end
		carrier.CFrame = cf
		if flame and flame2 then
			local flick = 1 + 0.07 * math.sin(t * 28)
			flame.Size = Vector3.new(D * 1.15, D * 1.15, D * 2.4) * flick
			flame.CFrame = cf * CFrame.new(0, 0, D * 0.75)
			flame2.Size = Vector3.new(D * 1.5, D * 1.5, D * 3.4) * flick
			flame2.CFrame = cf * CFrame.new(0, 0, D * 1.2)
			puffAcc += dt
			while puffAcc > 0.03 do
				puffAcc -= 0.03
				puff(pos - dir * D * 1.5 + randUnit() * D * 0.3, -dir * D * 1.5 + Vector3.new(0, D * 0.6, 0), D * 0.9, D * 0.2, ORG, CRIMSON, 0.35, nil, 0.6)
			end
		end
		rockAcc += dt
		if rockAcc > 0.07 then
			rockAcc = 0
			chunk(pos + randUnit() * D * 0.4, -dir * D * 2 + randUnit() * D * 2, Vector3.one * D * rng:NextNumber(0.1, 0.2), if rng:NextNumber() < 0.5 then ROCK else ORG, 0.7, D * 8, FLAT)
		end
		if dist >= range + D * 4 then
			stopped = true
			return true
		end
		return
	end, function()
		g:Destroy()
		for _, e in ipairs(carrier:GetChildren()) do
			if e:IsA("ParticleEmitter") then
				e.Enabled = false
			end
		end
		task.delay(1.2, function()
			carrier:Destroy()
		end)
	end)
	shot.stop = function()
		stopped = true
	end
	return shot :: Shot
end

-- Double detonation, a mushroom column with a fire cap, flaming rocks arcing out, a burning field
-- of flame tongues and long lava cracks; heavy shake and a red flash.
local function explodeF(pos: Vector3, normal: Vector3, R: number, grounded: boolean, power: number)
	local n = if normal.Magnitude > 0.01 then normal.Unit else Vector3.yAxis
	local u, v = basis(n)
	local function burst(scale: number, delay: number)
		task.delay(delay, function()
			puff(pos, Vector3.zero, R * 0.3 * scale, R * 1.2 * scale, ORG, RED, 0.25, nil, 0.3)
			fireCluster(pos, n, R * scale, 16 + math.floor(power * 6), { ORG, RED, ORG }, { CRIMSON, CRIMSON, Color3.fromRGB(90, 0, 15) }, BLK, 1, 1)
			local rays = group(CRIMSON)
			for _ = 1, 12 do
				local d = hemi(n, 0.35)
				local ws = spikeParts(ORG, rays)
				local len = R * scale * rng:NextNumber(1.6, 2.6)
				local hw = R * scale * rng:NextNumber(0.16, 0.28)
				placeSpike(ws, pos, d, 0.05, 0.05)
				job(0.55, function(k)
					placeSpike(ws, pos + d * R * 0.15, d, len * outQuart(math.min(k / 0.25, 1)), hw * (if k < 0.25 then 1 else 1 - (k - 0.25) / 0.75))
					return
				end)
			end
			task.delay(0.6, function()
				rays:Destroy()
			end)
		end)
	end
	burst(1, 0)
	burst(1.35, 0.25)

	-- Mushroom: stem of stacked blobs + a cap of balls spreading at the top.
	local col = group(BLK)
	local stem, cap = {}, {}
	for i = 1, 7 do
		stem[i] = blob(if i % 2 == 0 then RED else ORG, col)
	end
	for i = 1, 11 do
		cap[i] = ball(if i % 3 == 0 then CRIMSON else RED, col)
	end
	local H = R * (2.4 + power)
	job(1.6, function(k, t)
		local rise = outQuart(math.min(k / 0.45, 1))
		local fade = if k > 0.6 then 1 - (k - 0.6) / 0.4 else 1
		local dark = math.max(0, (k - 0.45) / 0.55)
		for i, b in ipairs(stem) do
			local f = i / #stem
			local sz = math.max(R * 0.42 * fade * (1 - 0.3 * f), 0.05)
			b.Size = Vector3.new(sz, sz * 1.4, sz)
			b.CFrame = CFrame.lookAt(pos + n * H * f * rise, pos + n * H * f * rise + u, n)
			b.Color = (if i % 2 == 0 then RED else ORG):Lerp(SMOKE, dark)
		end
		local top = pos + n * H * rise
		for i, b in ipairs(cap) do
			local sz = math.max(R * 0.5 * fade, 0.05)
			b.Size = Vector3.one * sz
			if i == #cap then
				b.Position = top + n * R * 0.2
			else
				local a = i / (#cap - 1) * math.pi * 2 + t
				b.Position = top + (u * math.cos(a) + v * math.sin(a)) * R * 0.85 * rise
			end
			b.Color = (if i % 3 == 0 then CRIMSON else RED):Lerp(SMOKE, dark)
		end
		return
	end)
	task.delay(1.65, function()
		col:Destroy()
	end)

	ring(pos, n, 0.5, function(k)
		return R * lerp(0.3, 2.6, outQuart(k))
	end, function(k)
		return R * 0.22 * (1 - k)
	end, ORG, 36)
	ring(pos, n, 0.6, function(k)
		return R * lerp(0.3, 3.2, outQuart(k))
	end, function(k)
		return R * 0.12 * (1 - k)
	end, CRIMSON, 36, 0.25)
	local dome = ball(RED, nil, FIELD)
	job(0.7, function(k)
		dome.Size = Vector3.one * R * lerp(0.5, 2.8, outQuart(k))
		dome.Position = pos
		dome.Transparency = if k > 0.5 then (k - 0.5) / 0.5 else 0
		return
	end, function()
		dome:Destroy()
	end)

	-- Flaming rocks: dark chunks arcing out, each trailing fire puffs.
	for _ = 1, 12 do
		local p = newPart(ROCK, nil, FLAT)
		local s = R * rng:NextNumber(0.08, 0.15)
		local vel = hemi(n, 0.6) * R * rng:NextNumber(2, 3.2)
		local x = pos
		local acc = 0
		job(1.3, function(k, _, dt)
			vel -= Vector3.new(0, R * 4 * dt, 0)
			x += vel * dt
			p.Size = Vector3.one * s * (if k > 0.7 then 1 - (k - 0.7) / 0.3 else 1)
			p.CFrame = CFrame.new(x) * CFrame.Angles(k * 9, k * 7, 0)
			acc += dt
			if acc > 0.03 then
				acc = 0
				puff(x, Vector3.zero, s * 1.6, s * 0.3, ORG, CRIMSON, 0.3, nil, 0.6)
			end
			return
		end, function()
			p:Destroy()
		end)
	end
	for i = 1, 40 do
		chunk(pos, hemi(n, 0.2) * R * rng:NextNumber(2, 3.8), Vector3.one * R * rng:NextNumber(0.02, 0.05), if i % 3 == 0 then CRIMSON else ORG, rng:NextNumber(0.5, 1), R * 3)
	end
	task.delay(0.2, function()
		for _ = 1, 14 do
			local o = hemi(n, 0.4) * R * rng:NextNumber(0.3, 0.8)
			puff(pos + o, n * R * 1.1 + o * 0.6, R * 0.4, R * rng:NextNumber(0.8, 1.1), BLK, SMOKE, rng:NextNumber(1.4, 2), FLAT, 0.45)
		end
	end)

	if grounded then
		-- Burning field: two rings of flame tongues.
		local flames = group(CRIMSON)
		for ringI, radius in ipairs({ 0.65, 1.25 }) do
			local N = if ringI == 1 then 12 else 20
			for i = 1, N do
				local a = i / N * math.pi * 2 + ringI
				local base = pos + (u * math.cos(a) + v * math.sin(a)) * R * radius
				local tan = -u * math.sin(a) + v * math.cos(a)
				local outer, inner = blob(RED, flames), blob(ORG, flames)
				job(2.2, function(k, t)
					local env = outBack(math.min(k / 0.15, 1)) * (if k > 0.65 then 1 - (k - 0.65) / 0.35 else 1)
					local h = R * (0.38 + 0.16 * math.sin(t * 16 + i * 1.3)) * math.max(env, 0.01)
					local w = R * 0.18 * math.max(env, 0.01)
					local c = base + n * h / 2
					outer.Size = Vector3.new(w, h, w)
					outer.CFrame = CFrame.lookAt(c, c + tan, n)
					inner.Size = Vector3.new(w * 0.55, h * 0.7, w * 0.55)
					inner.CFrame = CFrame.lookAt(c - n * h * 0.12, c - n * h * 0.12 + tan, n)
					return
				end)
			end
		end
		task.delay(2.3, function()
			flames:Destroy()
		end)
		-- Long lava cracks.
		local cracks = {}
		for c = 1, 12 do
			local a = c / 12 * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
			local d = u * math.cos(a) + v * math.sin(a)
			local x = pos + n * 0.15
			for i = 1, 8 do
				local ang = rng:NextNumber(-0.5, 0.5)
				local d2 = (d * math.cos(ang) + n:Cross(d) * math.sin(ang)).Unit
				local L = R * rng:NextNumber(0.18, 0.3)
				local y = x + d2 * L
				local p = newPart(ORG)
				p.Size = Vector3.new(R * 0.05 * (1 - i * 0.08), 0.15, L)
				p.CFrame = CFrame.lookAt((x + y) / 2, y, n)
				p.Transparency = 1
				table.insert(cracks, { p = p, i = i })
				x, d = y, d2
			end
		end
		job(2.6, function(k)
			for _, cr in ipairs(cracks) do
				cr.p.Transparency = if k < cr.i * 0.025 then 1 elseif k > 0.55 then (k - 0.55) / 0.45 else 0
				cr.p.Color = ORG:Lerp(CRIMSON, k)
			end
			return
		end, function()
			for _, cr in ipairs(cracks) do
				cr.p:Destroy()
			end
		end)
	end
	impulse(pos, R, 2.2 + 1.5 * power, 0.6, RED)
end

-- Textured explosion layers (on top of the geometry layers above) ---------------------------------
local function texExplodeR(pos: Vector3, n: Vector3, R: number, grounded: boolean, power: number)
	billboard(pos, R * 2.6, "explosion_orange_4x4", 0.75)
	for i = 1, 4 + math.floor(power * 3) do
		billboard(pos + hemi(n, 0.5) * R * 0.6, R * rng:NextNumber(1, 1.5), "explosion_orange_4x4", rng:NextNumber(0.6, 0.85), nil, rng:NextNumber(0, 360), i * 0.04)
	end
	plate(pos + n * 0.3, n, "shock_ring", ORG, 0.5, R * 0.4, R * 4.2, 2, 0.4)
	plate(pos + n * 0.35, n, "shock_ring", CRIMSON, 0.6, R * 0.3, R * 3.2, -2, 0.4, 0.08)
	if grounded then
		plate(pos + n * 0.15, n, "crack_burst", WHITE, 2.6, R * 1.4, R * 2.6, 0, 0.6)
	end
	burstAt(pos, "spark_star", 30 + math.floor(power * 20), {
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(R * 2, R * 4),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(R * 0.22, 0),
		Color = ColorSequence.new(ORG, RED),
		Drag = 3,
		RotSpeed = NumberRange.new(-300, 300),
	})
	burstAt(pos, "smoke_2x2", 10, {
		Lifetime = NumberRange.new(1.2, 1.8),
		Speed = NumberRange.new(R * 0.4, R),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(R * 0.5, R * 1.2),
		Transparency = NumberSequence.new(0, 1),
		Acceleration = n * R * 0.5,
		Drag = 2,
		Rotation = NumberRange.new(0, 360),
	})
end

local function texExplodeQ(pos: Vector3, n: Vector3, R: number, grounded: boolean, power: number)
	task.delay(0.14, function()
		billboard(pos, R * 2.8, "explosion_violet_4x4", 0.8)
		for i = 1, 5 do
			billboard(pos + hemi(n, 0.4) * R * 0.7, R * rng:NextNumber(1, 1.6), "explosion_violet_4x4", rng:NextNumber(0.6, 0.9), nil, rng:NextNumber(0, 360), i * 0.05)
		end
		for i = 1, 6 + math.floor(power * 4) do
			billboard(pos + randUnit() * R * 0.3, R * rng:NextNumber(1.6, 2.6), "slash_arc", 0.45, if i % 2 == 0 then PINK else VIOLET, rng:NextNumber(0, 360), rng:NextNumber(0, 0.12), rng:NextNumber(-260, 260), 1.6)
		end
		plate(pos + n * 0.3, n, "shock_ring", VIOLET, 0.55, R * 0.4, R * 4, 2.5, 0.4)
		if grounded then
			plate(pos + n * 0.2, n, "sigil", PINK, 1.9, R * 2.2, R * 2.6, 1.2, 0.6)
		end
		for i = 1, 8 do
			local b = tbeam("beam_lightning", if i % 2 == 0 then PINK else VIOLET, R * 0.12, 8, true)
			if b then
				local d0 = randUnit()
				local acc = 1
				job(0.35, function(_, _, dt)
					acc += dt
					if acc > 0.05 then
						acc = 0
						d0 = (d0 + randUnit() * 0.6).Unit
						b.set(pos, pos + d0 * R * rng:NextNumber(1.2, 2))
					end
					return
				end, b.destroy)
			end
		end
		burstAt(pos, "spark_star", 40, {
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(R * 2, R * 4),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(R * 0.22, 0),
			Color = ColorSequence.new(PINK, VIOLET),
			Drag = 3,
			RotSpeed = NumberRange.new(-300, 300),
		})
		burstAt(pos, "smoke_2x2", 10, {
			Lifetime = NumberRange.new(1.1, 1.6),
			Speed = NumberRange.new(R * 0.4, R),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(R * 0.5, R * 1.2),
			Color = ColorSequence.new(Color3.fromRGB(200, 150, 255)),
			Transparency = NumberSequence.new(0, 1),
			Acceleration = n * R * 0.6,
			Drag = 2,
			Rotation = NumberRange.new(0, 360),
		})
	end)
end

local function texExplodeF(pos: Vector3, n: Vector3, R: number, grounded: boolean, power: number)
	for i = 1, 7 do
		billboard(pos + hemi(n, 0.6) * R * rng:NextNumber(0, 0.8), R * rng:NextNumber(1.6, 2.8), "explosion_crimson_4x4", rng:NextNumber(0.7, 1), nil, rng:NextNumber(0, 360), (i - 1) * 0.06)
	end
	billboard(pos + n * R * 2.2, R * 3, "explosion_crimson_4x4", 1.1, nil, 0, 0.35)
	plate(pos + n * 0.3, n, "shock_ring", ORG, 0.55, R * 0.5, R * 5, 2, 0.4)
	plate(pos + n * 0.35, n, "shock_ring", CRIMSON, 0.65, R * 0.5, R * 6, -1.5, 0.4, 0.25)
	if grounded then
		plate(pos + n * 0.15, n, "crack_burst", WHITE, 3, R * 2, R * 3.6, 0, 0.65)
		local u, v = basis(n)
		for _ = 1, 10 do
			local a = rng:NextNumber(0, math.pi * 2)
			local at = pos + (u * math.cos(a) + v * math.sin(a)) * R * rng:NextNumber(0.4, 1.3)
			local p = newPart(WHITE)
			p.Transparency = 1
			p.Size = Vector3.one * R * 0.3
			p.CFrame = CFrame.lookAt(at, at + u, n)
			local e = emitter(p, "flame_crimson_4x4", {
				Rate = 18,
				Lifetime = NumberRange.new(0.4, 0.7),
				Speed = NumberRange.new(R * 0.1, R * 0.3),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(10, 10),
				Size = NumberSequence.new(R * 0.55, R * 0.2),
			})
			if not e then
				p:Destroy()
				break
			end
			task.delay(1.8, function()
				e.Enabled = false
			end)
			task.delay(2.6, function()
				p:Destroy()
			end)
		end
	end
	burstAt(pos, "spark_star", 50, {
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(R * 2, R * 4.5),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(R * 0.25, 0),
		Color = ColorSequence.new(ORG, RED),
		Drag = 3,
		RotSpeed = NumberRange.new(-300, 300),
	})
	burstAt(pos, "smoke_2x2", 16, {
		Lifetime = NumberRange.new(1.6, 2.4),
		Speed = NumberRange.new(R * 0.5, R * 1.3),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(R * 0.7, R * 1.8),
		Transparency = NumberSequence.new(0, 1),
		Acceleration = n * R * 0.6,
		Drag = 2,
		Rotation = NumberRange.new(0, 360),
	})
end

-- Dispatch by move key ("R", "Q", "F").
function FX.projectile(move: string, origin: Vector3, dir: Vector3, speed: number, D: number, t0: number, range: number, power: number): Shot
	if move == "Q" then
		return projectileQ(origin, dir, speed, D, t0, range, power)
	elseif move == "F" then
		return projectileF(origin, dir, speed, D, t0, range, power)
	end
	return projectileR(origin, dir, speed, D, t0, range, power)
end

function FX.explode(move: string, pos: Vector3, normal: Vector3, R: number, grounded: boolean, power: number)
	local n = if normal.Magnitude > 0.01 then normal.Unit else Vector3.yAxis
	if move == "Q" then
		explodeQ(pos, normal, R, grounded, power)
		texExplodeQ(pos, n, R, grounded, power)
	elseif move == "F" then
		explodeF(pos, normal, R, grounded, power)
		texExplodeF(pos, n, R, grounded, power)
	else
		explodeR(pos, normal, R, grounded, power)
		texExplodeR(pos, n, R, grounded, power)
	end
end

return FX

