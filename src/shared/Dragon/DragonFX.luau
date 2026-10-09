--!strict
-- Client-only VFX for the West dragon fireballs (R / Q / F): charge, muzzle, projectile, explosion.
-- Built from the West transform's language: flat solid band/streak rings (untextured beams), thick
-- yellow cone rays with orange cel outline, shard starbursts, black ink spikes + white-out, glowing
-- jagged cracks, fire rings with flame tongues, navy debris cubes, curling pink/purple flares.
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

local YEL = Color3.fromRGB(255, 214, 20) -- transform palette
local ORG = Color3.fromRGB(255, 118, 0)
local RED = Color3.fromRGB(225, 35, 15)
local CRIMSON = Color3.fromRGB(200, 0, 45)
local VIOLET = Color3.fromRGB(150, 50, 230)
local ROCK = Color3.fromRGB(32, 22, 24)
local PINK = Color3.fromRGB(255, 40, 190) -- transform pink
local PURPLE = Color3.fromRGB(150, 50, 230) -- transform purple
local DEEP = Color3.fromRGB(90, 0, 210) -- deep purple core/edges
local WHITE = Color3.fromRGB(255, 250, 225)
local BLK = Color3.fromRGB(18, 16, 20)
local NAVY = Color3.fromRGB(30, 36, 72)
local NEON = Enum.Material.Neon
local FLAT = Enum.Material.SmoothPlastic

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

export type Shot = { stop: () -> (), pos: Vector3 }

-- Shared impact helpers (Q / F) ----------------------------------------------------------------

-- Speed-line streaks: thin neon slivers shooting radially outward, long then gone.
local function speedLines(pos: Vector3, n: Vector3, R: number, count: number, cols: { Color3 })
	for i = 1, count do
		local d = hemi(n, 0.15)
		local p = newPart(cols[(i - 1) % #cols + 1])
		local L = R * rng:NextNumber(0.8, 1.6)
		local w = R * rng:NextNumber(0.015, 0.035)
		local delay = rng:NextNumber(0, 0.05)
		p.Transparency = 1
		job(0.3 + delay, function(_, t)
			if t < delay then
				return
			end
			local k = math.clamp((t - delay) / 0.3, 0, 1)
			local head = R * (0.3 + 2.6 * outQuart(k))
			local len = L * (1 - k) + 0.05
			local a = pos + d * head
			p.Transparency = 0
			p.Size = Vector3.new(w, w, len)
			p.CFrame = CFrame.lookAt(a - d * len / 2, a)
			return
		end, function()
			p:Destroy()
		end)
	end
end

-- Shard starburst: cone spikes flashing out in every direction (the transform's opening punch).
local function starburst(pos: Vector3, R: number, cols: { Color3 }, outline: Color3, count: number)
	local g = group(outline)
	for i = 1, count do
		local ws = spikeParts(cols[(i - 1) % #cols + 1], g)
		local d = randUnit()
		local len = R * rng:NextNumber(0.9, 1.7)
		job(0.22, function(k)
			placeSpike(ws, pos + d * R * 0.1, d, len * outQuart(math.min(k / 0.35, 1)), R * 0.18 * (1 - k))
			return
		end)
	end
	task.delay(0.25, function()
		g:Destroy()
	end)
end

-- Swept flame ribbons: textured beams curving out from the blast and sweeping around it.
local function ribbons(pos: Vector3, n: Vector3, R: number, count: number, texName: string)
	local u, v = basis(n)
	for i = 1, count do
		local b = tbeam(texName, WHITE, R * 0.3, 2, false)
		if not b then
			return
		end
		local beam = b.beam
		local a0 = i / count * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local sweep = rng:NextNumber(0.8, 1.5) * (if i % 2 == 0 then 1 else -1)
		local lift = rng:NextNumber(0.1, 0.6)
		job(0.7, function(k)
			local a = a0 + sweep * outQuart(k)
			local d = (u * math.cos(a) + v * math.sin(a) + n * lift).Unit
			local reach = R * (0.4 + 1.9 * outQuart(k))
			b.set(pos + d * R * 0.2, pos + d * reach)
			beam.CurveSize0 = reach * 0.35 * (if sweep > 0 then 1 else -1)
			beam.CurveSize1 = -reach * 0.2
			local w = R * 0.32 * math.sin(math.min(k / 0.9, 1) * math.pi)
			beam.Width0, beam.Width1 = w * 0.4, w
			beam.Transparency = NumberSequence.new(if k > 0.6 then (k - 0.6) / 0.4 else 0)
			return
		end, b.destroy)
	end
end

-- Camera punch: FOV kicks in and eases back (the transform's punch-in), scaled by distance.
local fovKickBase: number? = nil
local function fovKick(pos: Vector3, R: number, amount: number)
	local cam = workspace.CurrentCamera
	local i = math.clamp(1 - (cam.CFrame.Position - pos).Magnitude / (R * 8), 0, 1)
	if i <= 0 then
		return
	end
	if not fovKickBase then
		fovKickBase = cam.FieldOfView
	end
	local base = fovKickBase :: number
	job(0.35, function(k)
		cam.FieldOfView = base - amount * i * math.sin(k * math.pi) * (1 - k * 0.3)
		return
	end, function()
		cam.FieldOfView = base
		fovKickBase = nil
	end)
end

-- Thick flat yellow cone rays with orange outline (the transform's signature rays).
local function bigRays(pos: Vector3, n: Vector3, R: number, count: number, color: Color3, outline: Color3)
	local g = group(outline)
	for _ = 1, count do
		local d = hemi(n, 0.5)
		local ws = spikeParts(color, g)
		local len = R * rng:NextNumber(1.8, 3)
		local hw = R * rng:NextNumber(0.2, 0.34)
		job(0.45, function(k)
			local grow = outQuart(math.min(k / 0.2, 1))
			placeSpike(ws, pos + d * R * 0.2, d, len * grow, hw * (if k < 0.3 then 1 else 1 - (k - 0.3) / 0.7))
			return
		end)
	end
	task.delay(0.5, function()
		g:Destroy()
	end)
end

-- Ground bullseye half-disc: red outer, yellow ring, black dot (the transform's ground mark).
local function bullseye(pos: Vector3, n: Vector3, R: number)
	local discs = {}
	for i, spec in ipairs({ { RED, 1 }, { YEL, 0.62 }, { BLK, 0.3 } }) do
		local p = newPart(spec[1], nil, if spec[1] == BLK then FLAT else NEON)
		p.Shape = Enum.PartType.Cylinder
		discs[i] = { p = p, f = spec[2] }
	end
	local cf = CFrame.lookAt(pos + n * 0.12, pos + n * 0.12 + n) * CFrame.Angles(0, math.pi / 2, 0)
	job(1.2, function(k)
		local grow = outQuart(math.min(k / 0.2, 1))
		local fade = if k > 0.6 then (k - 0.6) / 0.4 else 0
		for i, d in ipairs(discs) do
			local sz = R * 2.2 * d.f * grow
			d.p.Size = Vector3.new(0.15 + i * 0.03, sz, sz)
			d.p.CFrame = cf
			d.p.Transparency = fade
		end
		return
	end, function()
		for _, d in ipairs(discs) do
			d.p:Destroy()
		end
	end)
end

-- FAILED shot (backfire): a weak, sooty, sputtering blast. Dark/black palette, no rays or bright
-- rings: a dull pop, billowing black smoke, ash flakes, dim sparks dropping, inward black streaks,
-- a few cracked-ash plates and a dark screen flash.
local ASH = Color3.fromRGB(70, 66, 70)
local EMBER = Color3.fromRGB(150, 45, 15)
local function explodeFail(pos: Vector3, normal: Vector3, R: number, power: number)
	local n = if normal.Magnitude > 0.01 then normal.Unit else Vector3.yAxis
	puff(pos, Vector3.zero, R * 0.2, R * 0.75, EMBER, BLK, 0.35, nil, 0.3) -- dull pop, no bright flash
	for i = 1, 9 do
		local o = hemi(n, 0.4) * R * rng:NextNumber(0.1, 0.5)
		puff(pos + o, n * R * 0.8 + o * 0.5, R * 0.35, R * rng:NextNumber(0.7, 1.05), if i % 3 == 0 then ASH else BLK, BLK, rng:NextNumber(1.1, 1.7), nil, 0.4)
	end
	burstAt(pos, "smoke_2x2", 16, {
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(R * 0.3, R * 0.9),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(R * 0.6, R * 1.5),
		Color = ColorSequence.new(Color3.fromRGB(35, 32, 36)),
		Transparency = NumberSequence.new(0.1, 1),
		Acceleration = Vector3.new(0, R * 0.7, 0),
		Drag = 1.5,
		Rotation = NumberRange.new(0, 360),
	})
	speedLines(pos, n, R * 0.6, 12, { BLK, ASH, EMBER })
	starburst(pos, R * 0.55, { ASH, EMBER, ROCK }, BLK, 6)
	plate(pos + n * 0.3, n, "shock_ring", ASH, 0.5, R * 0.3, R * 1.7, 1, 0.3)
	plate(pos + n * 0.2, n, "crack_burst", ASH, 1.8, R * 1, R * 1.6, 0, 0.5)
	for i = 1, 18 do
		chunk(pos, hemi(n, 0.2) * R * rng:NextNumber(0.8, 1.8), Vector3.one * R * rng:NextNumber(0.02, 0.04), if i % 2 == 0 then EMBER else ASH, rng:NextNumber(0.7, 1.2), R * 2.5)
	end
	for _ = 1, 8 do
		chunk(pos, hemi(n, 0.5) * R * rng:NextNumber(0.8, 1.6), Vector3.one * R * rng:NextNumber(0.05, 0.1), ROCK, 1, R * 3, FLAT)
	end
	local lp = newPart(EMBER)
	lp.Transparency = 1
	lp.Position = pos
	local L = Instance.new("PointLight")
	L.Color, L.Range, L.Brightness = EMBER, math.min(40, R), 3
	L.Parent = lp
	job(0.5, function(k)
		L.Brightness = 3 * (1 - k)
		return
	end, function()
		lp:Destroy()
	end)
	-- "faileur!" popup: pops in with a bounce, wobbles, floats up and fades. Visible to everyone.
	do
		local anchor = newPart(WHITE)
		anchor.Transparency = 1
		anchor.Position = pos + Vector3.new(0, R * 0.9, 0)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(360, 110)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.MaxDistance = 400
		bb.Adornee = anchor
		bb.Parent = anchor
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(1, 1)
		label.Text = "faileur!"
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(235, 40, 20)
		label.Parent = bb
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = BLK
		stroke.Parent = label
		job(1.7, function(k, t)
			local pop = outBack(math.min(k / 0.12, 1))
			local fade = if k > 0.65 then (k - 0.65) / 0.35 else 0
			bb.Size = UDim2.fromOffset(360 * pop, 110 * pop)
			bb.StudsOffset = Vector3.new(0, R * 0.8 * outQuart(k), 0)
			label.Rotation = math.sin(t * 22) * 5 * (1 - k)
			label.TextTransparency = fade
			stroke.Transparency = fade
			return
		end, function()
			anchor:Destroy()
		end)
	end

	local cam = workspace.CurrentCamera
	local i = math.clamp(1 - (cam.CFrame.Position - pos).Magnitude / (R * 8), 0, 1)
	if i > 0 then
		FX.shake(i * (0.6 + power))
		FX.flash(0.4 * i, 0.5, BLK)
	end
end

-- =================================================================================================
-- WEST MOVES: R / Q / F (charge, muzzle, projectile, explosion).
-- Built only from the West transform's language: flat solid band/streak rings (untextured beams that
-- wrap or lie flat), thick yellow cone rays with orange cel outline, shard starbursts, black ink
-- spikes + white-out, a black dome with glowing jagged cracks, a fire ring with flame tongues, navy
-- debris cubes and curling pink/purple flares. Almost no coloured balls.
-- Public API: FX.charge / FX.muzzle / FX.projectile / FX.explode (failed shots use explodeFail).
-- =================================================================================================

type FB = { a0: Attachment, a1: Attachment, b: Beam }
local function fbeams(n: number, color: Color3, bright: number?): { FB }
	local t: { FB } = {}
	for i = 1, n do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = workspace.Terrain, workspace.Terrain
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Color = ColorSequence.new(color)
		b.LightEmission, b.LightInfluence, b.Brightness = 0, 0, bright or 2.2
		b.FaceCamera, b.Segments = false, 10
		b.Width0, b.Width1 = 0, 0
		b.Enabled = false
		b.Parent = workspace.Terrain
		t[i] = { a0 = a0, a1 = a1, b = b }
	end
	return t
end
local function killBeams(bs: { FB })
	for _, x in ipairs(bs) do
		x.b:Destroy()
		x.a0:Destroy()
		x.a1:Destroy()
	end
end

-- Arc of `span` rad around `center` in the plane with normal n. flat=false: the band stands along n
-- (wraps a sphere, like the transform bands); flat=true: lies in the plane (disc ring).
-- mode "tail": thick head, fading thinning tail (motion smear); "claw": pointed both ends (talon).
local function arc(bs: { FB }, center: Vector3, n: Vector3, rad: number, w: number, a0: number, span: number, flat: boolean, alpha: number, mode: string?)
	local u, v = basis(n)
	local N = #bs
	local th = span / N
	local k = 4 / 3 * math.tan(th / 4) * rad
	local base = 1 - alpha
	for i, x in ipairs(bs) do
		local s0, s1 = a0 - (i - 1) * th, a0 - i * th
		local r0 = u * math.cos(s0) + v * math.sin(s0)
		local r1 = u * math.cos(s1) + v * math.sin(s1)
		local d0 = u * math.sin(s0) - v * math.cos(s0)
		local d1 = u * math.sin(s1) - v * math.cos(s1)
		x.a0.WorldCFrame = CFrame.fromMatrix(center + r0 * rad, d0, if flat then r0 else n)
		x.a1.WorldCFrame = CFrame.fromMatrix(center + r1 * rad, d1, if flat then r1 else n)
		x.b.CurveSize0, x.b.CurveSize1 = k, k
		local f0, f1 = (i - 1) / N, i / N
		if mode == "claw" then
			x.b.Width0, x.b.Width1 = w * math.sin(f0 * math.pi) + 0.02, w * math.sin(f1 * math.pi) + 0.02
			x.b.Transparency = NumberSequence.new(base)
		else
			x.b.Width0, x.b.Width1 = w * (1 - 0.35 * f0), w * (1 - 0.35 * f1)
			x.b.Transparency = NumberSequence.new(math.min(base + f0 * f0 * (1 - base), 1), math.min(base + f1 * f1 * (1 - base), 1))
		end
		x.b.Enabled = w > 0.03 and rad > 0.03 and alpha > 0.01
	end
end

local function nearCam(pos: Vector3, R: number): number
	return math.clamp(1 - (workspace.CurrentCamera.CFrame.Position - pos).Magnitude / (R * 9), 0, 1)
end

-- Black ink splat: flat black spikes, wide at the centre, pointed outward (the transform's ink).
local function inkBurst(pos: Vector3, R: number, count: number, life: number)
	local g = group(nil)
	for _ = 1, count do
		local ws = spikeParts(BLK, g)
		for _, w in ipairs(ws) do
			w.Material = FLAT
		end
		local d = randUnit()
		local len = R * rng:NextNumber(0.6, 1.3)
		job(life, function(k)
			local L = len * outQuart(math.min(k / 0.25, 1))
			placeSpike(ws, pos + d * L, -d, L, R * 0.24 * (1 - k))
			return
		end)
	end
	task.delay(life + 0.05, function()
		g:Destroy()
	end)
end

-- Standing band rings snapping outward around n (the transform's three yellow bands, exploding).
local function bandSnap(pos: Vector3, n: Vector3, R: number, cols: { Color3 }, life: number)
	for i, c in ipairs(cols) do
		local bs = fbeams(6, c, 2.5)
		local h = (i - 0.6) * R * 0.3
		local s0, sp = rng:NextNumber(0, 6.3), rng:NextNumber(6, 10) * (if i % 2 == 0 then -1 else 1)
		job(life, function(k, t)
			local rad = R * lerp(0.2, 1.3, outQuart(k))
			arc(bs, pos + n * h * (1 - 0.4 * k), n, rad, R * 0.24 * (1 - k) ^ 0.7, s0 + t * sp, math.pi * 1.9, false, 1 - k * k)
			return
		end, function()
			killBeams(bs)
		end)
	end
end

-- Flat shock band: a solid disc ring racing outward along the ground/plane.
local function shockBand(pos: Vector3, n: Vector3, r0: number, r1: number, w: number, col: Color3, life: number, delay: number?)
	local bs = fbeams(8, col, 2.5)
	local d = delay or 0
	job(life + d, function(_, t)
		if t < d then
			return
		end
		local k = math.clamp((t - d) / life, 0, 1)
		arc(bs, pos + n * 0.2, n, lerp(r0, r1, outQuart(k)), w * (1 - k), t * 3, math.pi * 2, true, 1 - k)
		return
	end, function()
		killBeams(bs)
	end)
end

-- Curling flare ribbons (the transform's purple/pink flares).
local function flares(pos: Vector3, n: Vector3, R: number, count: number, cols: { Color3 }, life: number)
	for i = 1, count do
		local x = fbeams(1, cols[(i - 1) % #cols + 1], 2.4)[1]
		x.b.FaceCamera = true
		local d = hemi(n, 0.7)
		local curl = rng:NextNumber(0.5, 1) * (if i % 2 == 0 then 1 else -1)
		local L = R * rng:NextNumber(0.9, 1.6)
		local w = R * rng:NextNumber(0.1, 0.17)
		local dl = rng:NextNumber(0, 0.12)
		local roll = rng:NextNumber(0, 6.3)
		job(life + dl, function(_, t)
			if t < dl then
				return
			end
			local k = math.clamp((t - dl) / life, 0, 1)
			local len = L * outQuart(math.min(k / 0.35, 1))
			local p0 = pos + d * R * 0.15
			local tip = p0 + d * len + n * len * 0.3
			x.a0.WorldCFrame = CFrame.lookAt(p0, tip) * CFrame.Angles(0, 0, roll)
			x.a1.WorldCFrame = CFrame.lookAt(tip, tip + (tip - p0)) * CFrame.Angles(0, 0, roll)
			x.b.CurveSize0, x.b.CurveSize1 = len * 0.45 * curl, -len * 0.3 * curl
			x.b.Width0, x.b.Width1 = w * (1 - 0.5 * k), w * 0.08
			x.b.Transparency = NumberSequence.new(if k > 0.55 then (k - 0.55) / 0.45 else 0)
			x.b.Enabled = len > 0.05
			return
		end, function()
			killBeams({ x })
		end)
	end
end

-- Fire ring: red/orange lava band on the ground + flame-tongue flipbooks standing around it.
local function fireRing(pos: Vector3, n: Vector3, rad: number, flameTex: string, life: number, count: number)
	shockBand(pos, n, rad * 0.4, rad, rad * 0.16, RED, life)
	shockBand(pos, n, rad * 0.35, rad * 0.94, rad * 0.08, ORG, life)
	local u, v = basis(n)
	for i = 1, count do
		local a = i / count * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local p = pos + (u * math.cos(a) + v * math.sin(a)) * rad
		local s = rad * rng:NextNumber(0.3, 0.5)
		billboard(p + n * s * 0.4, s, flameTex, life * rng:NextNumber(0.55, 0.9), nil, rng:NextNumber(-12, 12), rng:NextNumber(0.05, 0.3))
	end
end

-- Navy debris cubes (transform aftermath).
local function cubes(pos: Vector3, n: Vector3, R: number, count: number)
	for _ = 1, count do
		chunk(pos + n * R * 0.2, hemi(n, 0.6) * R * rng:NextNumber(1.6, 3.2), Vector3.one * R * rng:NextNumber(0.06, 0.13), NAVY, rng:NextNumber(1.1, 1.7), R * 3, FLAT)
	end
end

-- Jagged crack network on a sphere (unit-space segments; placed per frame with any rotation).
type Crack = { a: Vector3, b: Vector3, o: Part, y: Part, t: number }
local function crackNet(clusters: number, steps: number, parent: Instance): { Crack }
	local out: { Crack } = {}
	for c = 1, clusters do
		local p = randUnit()
		local h = randUnit()
		h = (h - p * h:Dot(p)).Unit
		local function walk(up: Vector3, head: Vector3, n: number, depth: number)
			for s = 1, n do
				local tan = (head - up * head:Dot(up)).Unit
				head = (tan + up:Cross(tan) * rng:NextNumber(-0.9, 0.9)).Unit
				local st = rng:NextNumber(0.12, 0.24)
				local np = (up * math.cos(st) + head * math.sin(st)).Unit
				table.insert(out, { a = up, b = np, o = newPart(ORG, parent), y = newPart(YEL, parent), t = (c - 1) / clusters * 0.5 + s * 0.04 })
				up = np
				if depth == 0 and rng:NextNumber() < 0.3 then
					walk(up, (head + up:Cross(head) * rng:NextNumber(-1.5, 1.5)).Unit, 2, 1)
				end
			end
		end
		walk(p, h, steps, 0)
	end
	return out
end
local function placeCracks(cr: { Crack }, center: Vector3, r: number, rot: CFrame, reveal: number, alpha: number)
	for _, c in ipairs(cr) do
		local vis = reveal >= c.t and alpha > 0.02
		c.o.Transparency = if vis then 1 - alpha else 1
		c.y.Transparency = c.o.Transparency
		if vis then
			local wa, wb = rot:VectorToWorldSpace(c.a), rot:VectorToWorldSpace(c.b)
			local pa, pb = center + wa * r * 1.01, center + wb * r * 1.01
			local mid = (pa + pb) / 2
			local len = (pb - pa).Magnitude
			local cf = CFrame.lookAt(mid, pb, (mid - center).Unit)
			c.o.Size = Vector3.new(r * 0.075, r * 0.02, len + r * 0.03)
			c.o.CFrame = cf
			c.y.Size = Vector3.new(r * 0.035, r * 0.025, len + r * 0.015)
			c.y.CFrame = cf * CFrame.new(0, r * 0.004, 0)
		end
	end
end

-- Inward speed lines converging on a point (charge).
type InLine = { p: Part, d: Vector3, ph: number }
local function inLines(count: number, cols: { Color3 }, parent: Instance): { InLine }
	local t: { InLine } = {}
	for i = 1, count do
		t[i] = { p = newPart(cols[(i - 1) % #cols + 1], parent), d = randUnit(), ph = rng:NextNumber() }
	end
	return t
end
local function placeInLines(ls: { InLine }, pos: Vector3, D: number, t: number, rate: number)
	for _, l in ipairs(ls) do
		local f = (t * rate + l.ph) % 1
		local head = D * (0.35 + 2.6 * (1 - f))
		local len = D * 0.9 * (1 - f) + 0.05
		local a = pos + l.d * head
		l.p.Size = Vector3.new(D * 0.035, D * 0.035, len)
		l.p.CFrame = CFrame.lookAt(a + l.d * len / 2, a)
		l.p.Transparency = if f > 0.85 then (f - 0.85) / 0.15 else 0
	end
end

-- Raking comet rays behind a projectile.
local function placeRake(rays: { { WedgePart } }, pos: Vector3, dir: Vector3, D: number, t: number, spread: number)
	local u, v = basis(dir)
	for i, sp in ipairs(rays) do
		local a = i / #rays * math.pi * 2 + t * 2.2
		local radial = u * math.cos(a) + v * math.sin(a)
		local d2 = (-dir * 1.4 + radial * spread).Unit
		local L = D * (2 + 0.7 * math.sin(t * 17 + i * 2))
		placeSpike(sp, pos + radial * D * 0.25 + d2 * L, -d2, L, D * 0.26)
	end
end

-- Shared projectile skeleton: position from server time so every client agrees.
local function flight(origin: Vector3, dir: Vector3, speed: number, t0: number, range: number, D: number, frame: (Vector3, number, number) -> (), cleanup: () -> ()): Shot
	local shot = { pos = origin } :: any
	local stopped = false
	job(math.huge, function(_, t, dt)
		if stopped then
			return true
		end
		local dist = math.min(speed * math.max(workspace:GetServerTimeNow() - t0, 0), range)
		local pos = origin + dir * dist
		shot.pos = pos
		frame(pos, t, dt)
		return
	end, cleanup)
	shot.stop = function()
		stopped = true
	end
	return shot :: Shot
end

local function carrierPart(): Part
	local c = newPart(ORG)
	c.Transparency = 1
	return c
end

-- ---------------------------------------------------------------------------------- R: HEATWAVE LANCE
-- Charge: three yellow bands wrapping a white-hot diamond core, sun rays lengthening, streaks rushing in.
-- Shot: an outlined yellow lance (diamond) wrapped by spinning smear bands, raking rays, flame trail.
-- Blast: ink + white-out, bands snapping out, starburst, thick rays, shock band, fire ring, flares.
local function chargeR3(getMouth: () -> CFrame?, t0: number, maxT: number, maxD: number)
	local g = group(ORG)
	local core = diamondParts(YEL, g)
	local hot = diamondParts(WHITE, g)
	local rays = {}
	for i = 1, 6 do
		rays[i] = spikeParts(if i % 2 == 0 then YEL else ORG, g)
	end
	local bands = { fbeams(5, YEL, 2.5), fbeams(5, ORG, 2.5), fbeams(5, YEL, 2.5) }
	local lines = inLines(10, { YEL, ORG, WHITE }, root())
	local fl = fbeams(2, PINK, 2.4)
	for _, x in ipairs(fl) do
		x.b.FaceCamera = true
	end
	local tilt = { CFrame.Angles(0.35, 0, 0), CFrame.Angles(-0.2, 0, 0.5), CFrame.Angles(0, 0, -0.45) }
	return chargeBase(getMouth, t0, maxT, maxD, function(pos, fwd, D, c, t)
		local cf = CFrame.lookAt(pos, pos + fwd)
		placeDiamond(core, pos, fwd, D * (0.7 + 0.5 * c), D * 0.3)
		placeDiamond(hot, pos, fwd, D * (0.4 + 0.3 * c), D * 0.14)
		for i, bs in ipairs(bands) do
			local n = (cf * tilt[i]).LookVector
			arc(bs, pos, n, D * (0.75 - 0.15 * c), D * 0.16, t * (5 + i * 2) * (if i == 2 then -1 else 1), math.pi * (1.1 + 0.85 * c), false, 1)
		end
		local u, v = basis(fwd)
		for i, sp in ipairs(rays) do
			local a = i / #rays * math.pi * 2 + t * 1.5
			local d = (u * math.cos(a) + v * math.sin(a) + fwd * 0.15).Unit
			local L = D * (0.4 + 1.6 * c) * (1 + 0.15 * math.sin(t * 22 + i))
			placeSpike(sp, pos + d * (D * 0.4 + L), -d, L, D * 0.2)
		end
		placeInLines(lines, pos, D, t, 1.6)
		for i, x in ipairs(fl) do
			local on = c >= 0.99 and math.sin(t * 30 + i * 2) > -0.2
			x.b.Enabled = on
			if on then
				local d = (u * math.cos(t * 4 + i * 3) + v * math.sin(t * 4 + i * 3) + fwd * 0.3).Unit
				local tip = pos + d * D * 1.6
				x.a0.WorldCFrame = CFrame.lookAt(pos + d * D * 0.4, tip)
				x.a1.WorldCFrame = CFrame.lookAt(tip, tip + d)
				x.b.CurveSize0, x.b.CurveSize1 = D * 0.6, -D * 0.4
				x.b.Width0, x.b.Width1 = D * 0.22, D * 0.02
			end
		end
		if c >= 0.99 and rng:NextNumber() < 0.25 then
			zap(pos, D * 0.9, WHITE)
		end
	end, function()
		g:Destroy()
		for _, bs in ipairs(bands) do
			killBeams(bs)
		end
		killBeams(fl)
		for _, l in ipairs(lines) do
			l.p:Destroy()
		end
	end)
end

local function projectileR3(origin: Vector3, dir: Vector3, speed: number, D: number, t0: number, range: number, power: number): Shot
	local g = group(ORG)
	local lance = diamondParts(YEL, g)
	local hot = diamondParts(WHITE, g)
	local rays = {}
	for i = 1, 4 do
		rays[i] = spikeParts(if i % 2 == 0 then YEL else ORG, g)
	end
	local bands = { fbeams(5, YEL, 2.5), fbeams(5, ORG, 2.5), fbeams(4, YEL, 2.5) }
	local streak = fbeams(4, PINK, 2.4)
	local carrier = carrierPart()
	local life = math.clamp(7 * D / speed, 0.12, 0.45)
	trail(carrier, Vector3.new(0, D * 0.45, 0), Vector3.new(0, -D * 0.45, 0), FIRE_SEQ, life, "beam_flame_orange")
	trail(carrier, Vector3.new(D * 0.45, 0, 0), Vector3.new(-D * 0.45, 0, 0), FIRE_SEQ, life, "beam_flame_orange")
	emitter(carrier, "flame_orange_4x4", {
		Rate = 60,
		Lifetime = NumberRange.new(0.2, 0.35),
		Speed = NumberRange.new(D, D * 3),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(20, 20),
		Size = NumberSequence.new(D * 0.9, D * 0.2),
		Rotation = NumberRange.new(-30, 30),
	})
	local emberAcc = 0
	return flight(origin, dir, speed, t0, range, D, function(pos, t, dt)
		local cf = CFrame.lookAt(pos, pos + dir)
		carrier.CFrame = cf
		placeDiamond(lance, pos - dir * D * 0.2, dir, D * 1.9, D * 0.42)
		placeDiamond(hot, pos - dir * D * 0.1, dir, D * 1.1, D * 0.2)
		for i, bs in ipairs(bands) do
			arc(bs, pos - dir * D * (i - 1) * 0.35, dir, D * (0.62 - 0.08 * i), D * 0.2, t * 14 * (if i == 2 then -1 else 1) + i, math.pi * 1.5, false, 1)
		end
		local tiltN = (cf * CFrame.Angles(0.5, 0, 0)).LookVector
		arc(streak, pos - dir * D * 0.3, tiltN, D * 0.85, D * 0.08, -t * 16, math.pi * 1.2, true, 0.9)
		placeRake(rays, pos, dir, D, t, 0.45)
		emberAcc += dt
		while emberAcc > 0.03 do
			emberAcc -= 0.03
			chunk(pos + randUnit() * D * 0.4, -dir * speed * 0.06 + randUnit() * D * 3, Vector3.new(D * 0.06, D * 0.06, D * 0.3), if rng:NextNumber() < 0.5 then YEL else ORG, 0.3, 0)
		end
	end, function()
		g:Destroy()
		for _, bs in ipairs(bands) do
			killBeams(bs)
		end
		killBeams(streak)
		task.delay(0.6, function()
			carrier:Destroy()
		end)
	end)
end

local function explodeR3(pos: Vector3, n: Vector3, R: number, grounded: boolean, power: number, stage: number)
	local near = nearCam(pos, R)
	if near > 0 then
		FX.flash(0.55 * near, 0.25, WHITE)
		FX.shake(near * (0.5 + 0.6 * power))
	end
	fovKick(pos, R, 5 + 4 * stage)
	inkBurst(pos, R * 0.9, 10 + 4 * stage, 0.22)
	starburst(pos, R, { YEL, WHITE, ORG }, RED, 8 + 4 * stage)
	bandSnap(pos, n, R, if stage >= 2 then { YEL, ORG, YEL } else { YEL, ORG }, 0.42)
	bigRays(pos, n, R, 4 + 3 * stage, YEL, ORG)
	shockBand(pos, n, R * 0.3, R * 2.3, R * 0.2, YEL, 0.4)
	shockBand(pos, n, R * 0.2, R * 1.7, R * 0.12, ORG, 0.5, 0.05)
	speedLines(pos, n, R, 12 + 8 * stage, { YEL, ORG, WHITE })
	for i = 1, 2 + 2 * stage do
		billboard(pos + hemi(n, 0.6) * R * rng:NextNumber(0, 0.5), R * rng:NextNumber(1.1, 1.7), "explosion_orange_4x4", rng:NextNumber(0.5, 0.75), nil, rng:NextNumber(0, 360), (i - 1) * 0.04)
	end
	if grounded then
		bullseye(pos, n, R)
		fireRing(pos, n, R * 1.05, "flame_orange_4x4", 1.1 + 0.3 * stage, 10 + 4 * stage)
		plate(pos + n * 0.15, n, "crack_burst", ORG, 1.6, R * 1.2, R * 1.8, 0, 0.55)
	end
	if stage >= 2 then
		cubes(pos, n, R, 4 * stage)
		flares(pos, n, R, 2 * stage, { PINK, PURPLE }, 0.6)
	end
	if stage >= 3 then
		ribbons(pos, n, R, 6, "beam_flame_orange")
	end
	for i = 1, 6 * stage do
		chunk(pos + randUnit() * R * 0.3, hemi(n, 0.3) * R * rng:NextNumber(0.6, 1.6), Vector3.one * R * rng:NextNumber(0.025, 0.05), if i % 3 == 0 then YEL else ORG, rng:NextNumber(1, 1.8), -R * 0.8)
	end
end

-- -------------------------------------------------------------------------------- Q: VIOLET TALON
-- Charge: counter-rotating pink/violet claw crescents around a pink slit eye, flares licking off.
-- Shot: a spinning disc of claw crescents (a thrown talon wheel) with crossed slashes, violet flames.
-- Blast: black ink + pink flash, three giant claw-slash scars across the view, violet flares
-- curling up, violet shock band + sigil on the ground, diamond shards.
local function chargeQ3(getMouth: () -> CFrame?, t0: number, maxT: number, maxD: number)
	local g = group(DEEP)
	local eye = diamondParts(PINK, g)
	local claws = { fbeams(5, PINK, 2.4), fbeams(5, VIOLET, 2.4), fbeams(5, PINK, 2.4), fbeams(5, VIOLET, 2.4) }
	local lines = inLines(9, { PINK, VIOLET, WHITE }, root())
	local fl = fbeams(3, PURPLE, 2.4)
	for _, x in ipairs(fl) do
		x.b.FaceCamera = true
	end
	return chargeBase(getMouth, t0, maxT, maxD, function(pos, fwd, D, c, t)
		local u, v = basis(fwd)
		placeDiamond(eye, pos, v, D * (0.6 + 0.6 * c), D * 0.12)
		for i, bs in ipairs(claws) do
			local dirSign = if i % 2 == 0 then -1 else 1
			arc(bs, pos, fwd, D * (0.55 + 0.1 * i) * (1.1 - 0.25 * c), D * (0.12 + 0.1 * c), t * 6 * dirSign + i * 1.6, math.pi * (0.55 + 0.25 * c), true, 1, "claw")
		end
		placeInLines(lines, pos, D, t, 1.4)
		for i, x in ipairs(fl) do
			local on = c > 0.4 and math.sin(t * 18 + i * 2.1) > 0
			x.b.Enabled = on
			if on then
				local a = t * 3 + i * 2.1
				local d = (u * math.cos(a) + v * math.sin(a) + fwd * 0.2).Unit
				local L = D * (0.8 + 0.9 * c)
				local tip = pos + d * (D * 0.5 + L)
				x.a0.WorldCFrame = CFrame.lookAt(pos + d * D * 0.5, tip)
				x.a1.WorldCFrame = CFrame.lookAt(tip, tip + d)
				x.b.CurveSize0, x.b.CurveSize1 = L * 0.5, -L * 0.3
				x.b.Width0, x.b.Width1 = D * 0.2, D * 0.02
			end
		end
		if c >= 0.99 and rng:NextNumber() < 0.2 then
			zap(pos, D * 0.9, PINK)
		end
	end, function()
		g:Destroy()
		for _, bs in ipairs(claws) do
			killBeams(bs)
		end
		killBeams(fl)
		for _, l in ipairs(lines) do
			l.p:Destroy()
		end
	end)
end

local function projectileQ3(origin: Vector3, dir: Vector3, speed: number, D: number, t0: number, range: number, power: number): Shot
	local g = group(DEEP)
	local eye = diamondParts(PINK, g)
	local rays = {}
	for i = 1, 3 do
		rays[i] = spikeParts(if i % 2 == 0 then PINK else VIOLET, g)
	end
	local wheel = { fbeams(5, PINK, 2.4), fbeams(5, VIOLET, 2.4), fbeams(5, PINK, 2.4) }
	local cross = { fbeams(5, VIOLET, 2.4), fbeams(5, PINK, 2.4) }
	local carrier = carrierPart()
	local life = math.clamp(7 * D / speed, 0.12, 0.45)
	trail(carrier, Vector3.new(0, D * 0.6, 0), Vector3.new(0, -D * 0.6, 0), ColorSequence.new(PINK, DEEP), life * 1.2, "beam_flame_violet")
	emitter(carrier, "flame_violet_4x4", {
		Rate = 50,
		Lifetime = NumberRange.new(0.2, 0.35),
		Speed = NumberRange.new(D, D * 2.5),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(25, 25),
		Size = NumberSequence.new(D * 0.8, D * 0.2),
		Rotation = NumberRange.new(-40, 40),
	})
	local shardAcc = 0
	return flight(origin, dir, speed, t0, range, D, function(pos, t, dt)
		local cf = CFrame.lookAt(pos, pos + dir)
		carrier.CFrame = cf
		local u, v = basis(dir)
		placeDiamond(eye, pos, (u * math.cos(t * 9) + v * math.sin(t * 9)), D * 0.9, D * 0.14)
		for i, bs in ipairs(wheel) do
			arc(bs, pos, dir, D * 0.75, D * 0.32, t * 20 + i / 3 * math.pi * 2, math.pi * 0.6, true, 1, "claw")
		end
		for i, bs in ipairs(cross) do
			local n = (cf * CFrame.Angles(0, (if i == 1 then 1 else -1) * 1.1, 0)).LookVector
			arc(bs, pos, n, D * 0.95, D * 0.22, -t * 14 + i * 2, math.pi * 0.7, true, 1, "claw")
		end
		placeRake(rays, pos, dir, D * 0.8, t, 0.6)
		shardAcc += dt
		if shardAcc > 0.05 then
			shardAcc = 0
			chunk(pos + randUnit() * D * 0.6, randUnit() * D * 3 - dir * speed * 0.05, Vector3.new(D * 0.05, D * 0.22, D * 0.05), if rng:NextNumber() < 0.5 then BLK else PINK, 0.35, 0, if rng:NextNumber() < 0.5 then FLAT else NEON)
		end
	end, function()
		g:Destroy()
		for _, bs in ipairs(wheel) do
			killBeams(bs)
		end
		for _, bs in ipairs(cross) do
			killBeams(bs)
		end
		task.delay(0.6, function()
			carrier:Destroy()
		end)
	end)
end

local function explodeQ3(pos: Vector3, n: Vector3, R: number, grounded: boolean, power: number, stage: number)
	local near = nearCam(pos, R)
	if near > 0 then
		FX.flash(0.45 * near, 0.25, PINK)
		FX.shake(near * (0.45 + 0.6 * power))
	end
	fovKick(pos, R, 4 + 4 * stage)
	inkBurst(pos, R, 12 + 4 * stage, 0.25)
	starburst(pos, R * 0.9, { PINK, VIOLET, WHITE }, DEEP, 6 + 4 * stage)
	-- three claw-slash scars in the plane facing the camera
	local toCam = (workspace.CurrentCamera.CFrame.Position - pos).Unit
	local su, sv = basis(toCam)
	local count = 2 + stage
	for i = 1, count do
		local off = (i - (count + 1) / 2) * R * 0.38
		local center = pos + Vector3.yAxis * R * 1.25 + su * (off + R * 0.55) + sv * 0
		local back = fbeams(6, DEEP, 2)
		local front = fbeams(6, PINK, 2.6)
		local a0 = math.rad(250) + rng:NextNumber(-0.1, 0.1)
		local dl = (i - 1) * 0.05
		job(0.55 + dl, function(_, t)
			if t < dl then
				return
			end
			local k = math.clamp((t - dl) / 0.55, 0, 1)
			local sweep = math.pi * 0.75 * outQuart(math.min(k / 0.3, 1))
			local w = R * 0.32 * (1 - k)
			arc(back, center, toCam, R * 1.2, w * 1.35, a0, sweep, true, 1, "claw")
			arc(front, center + toCam * 0.2, toCam, R * 1.2, w, a0, sweep, true, 1, "claw")
			return
		end, function()
			killBeams(back)
			killBeams(front)
		end)
	end
	flares(pos, n, R, 4 + 2 * stage, { PURPLE, PINK, VIOLET }, 0.7)
	shockBand(pos, n, R * 0.3, R * 2.1, R * 0.18, VIOLET, 0.45)
	shockBand(pos, n, R * 0.2, R * 1.6, R * 0.1, PINK, 0.5, 0.05)
	speedLines(pos, n, R, 12 + 8 * stage, { PINK, VIOLET, WHITE })
	for i = 1, 2 + stage do
		billboard(pos + hemi(n, 0.6) * R * rng:NextNumber(0, 0.4), R * rng:NextNumber(1, 1.5), "explosion_violet_4x4", rng:NextNumber(0.5, 0.7), nil, rng:NextNumber(0, 360), (i - 1) * 0.05)
	end
	if grounded then
		plate(pos + n * 0.15, n, "sigil", PINK, 1.4, R * 0.6, R * 1.9, 1.5, 0.5)
	end
	if stage >= 2 then
		local g = group(DEEP)
		for _ = 1, 3 * stage do
			local d = diamondParts(if rng:NextNumber() < 0.5 then PINK else VIOLET, g)
			local dirv = hemi(n, 0.3)
			local L = R * rng:NextNumber(0.25, 0.45)
			job(0.7, function(k)
				placeDiamond(d, pos + dirv * R * (0.3 + 1.6 * outQuart(k)), dirv, L * (1 - k * 0.6), L * 0.22)
				return
			end)
		end
		task.delay(0.75, function()
			g:Destroy()
		end)
	end
	if stage >= 3 then
		ribbons(pos, n, R, 6, "beam_flame_violet")
	end
end

-- ------------------------------------------------------------------------------ F: INFERNO METEOR
-- Charge: the transform's black dome in miniature: a matte black orb with a yellow rim, three yellow
-- bands wrapping it, glowing cracks spreading as it charges, rays bursting through at max.
-- Shot: the cracked black orb tumbling inside spinning bands, twin flame ribbons, smoke, raking rays.
-- Blast: a mini West transform: the orb flashes yellow, ink + white-out, many thick rays, bands
-- snapping out, a lava fire ring with flame tongues, navy cubes, an explosion column.
local function blackOrb(parent: Instance): (Part, Highlight)
	local orb = ball(BLK, parent, FLAT)
	local h = Instance.new("Highlight")
	h.FillTransparency = 1
	h.OutlineColor = YEL
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = orb
	h.Parent = orb
	return orb, h
end

local function chargeF3(getMouth: () -> CFrame?, t0: number, maxT: number, maxD: number)
	local g = Instance.new("Model")
	g.Parent = root()
	local orb = blackOrb(g)
	local cracks = crackNet(6, 5, g)
	local bands = { fbeams(5, YEL, 2.5), fbeams(5, YEL, 2.5), fbeams(5, YEL, 2.5) }
	local rg = group(ORG)
	local rays = {}
	for i = 1, 7 do
		rays[i] = spikeParts(if i % 2 == 0 then YEL else ORG, rg)
	end
	local lines = inLines(8, { ORG, RED, YEL }, root())
	return chargeBase(getMouth, t0, maxT, maxD, function(pos, fwd, D, c, t)
		local r = D * 0.5
		orb.Size = Vector3.one * D
		orb.CFrame = CFrame.new(pos)
		local rot = CFrame.Angles(t * 0.7, t * 1.1, 0)
		placeCracks(cracks, pos, r, rot, (c - 0.35) / 0.65, 1)
		for i, bs in ipairs(bands) do
			local h = (i - 2) * r * 0.55
			local rad = math.sqrt(math.max(r * r - h * h, 0.01)) + r * 0.08
			arc(bs, pos + Vector3.new(0, h, 0), Vector3.yAxis, rad, r * 0.22, t * (4 + i) * (if i == 2 then -1 else 1), math.pi * 2, false, 1 - 0.85 * math.max(c - 0.75, 0) / 0.25)
		end
		for i, sp in ipairs(rays) do
			local d = (CFrame.Angles(0, i * 0.9, 0) * CFrame.Angles(0.4 + (i % 3) * 0.35, 0, 0)).LookVector
			local L = if c >= 0.85 then D * (0.6 + 1.6 * (c - 0.85) / 0.15) * (1 + 0.15 * math.sin(t * 25 + i)) else 0.05
			placeSpike(sp, pos + d * (r + L), -d, L, if c >= 0.85 then D * 0.16 else 0.05)
		end
		placeInLines(lines, pos, D, t, 1.2)
	end, function()
		g:Destroy()
		rg:Destroy()
		for _, bs in ipairs(bands) do
			killBeams(bs)
		end
		for _, l in ipairs(lines) do
			l.p:Destroy()
		end
	end)
end

local function projectileF3(origin: Vector3, dir: Vector3, speed: number, D: number, t0: number, range: number, power: number): Shot
	local g = Instance.new("Model")
	g.Parent = root()
	local orb = blackOrb(g)
	local cracks = crackNet(7, 5, g)
	local bands = { fbeams(5, YEL, 2.5), fbeams(5, ORG, 2.5) }
	local rg = group(ORG)
	local rays = {}
	for i = 1, 5 do
		rays[i] = spikeParts(if i % 2 == 0 then YEL else ORG, rg)
	end
	local carrier = carrierPart()
	local life = math.clamp(8 * D / speed, 0.15, 0.5)
	trail(carrier, Vector3.new(0, D * 0.5, 0), Vector3.new(0, -D * 0.5, 0), FIRE_SEQ, life, "beam_flame_orange")
	trail(carrier, Vector3.new(D * 0.5, 0, 0), Vector3.new(-D * 0.5, 0, 0), FIRE_SEQ, life, "beam_flame_orange")
	emitter(carrier, "flame_crimson_4x4", {
		Rate = 55,
		Lifetime = NumberRange.new(0.25, 0.4),
		Speed = NumberRange.new(D, D * 2.5),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(30, 30),
		Size = NumberSequence.new(D * 1.1, D * 0.3),
		Rotation = NumberRange.new(0, 360),
	})
	emitter(carrier, "smoke_2x2", {
		Rate = 14,
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(D * 0.3, D),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(30, 30),
		Size = NumberSequence.new(D * 0.8, D * 1.8),
		Color = ColorSequence.new(Color3.fromRGB(30, 26, 30)),
		Transparency = NumberSequence.new(0.2, 1),
		Rotation = NumberRange.new(0, 360),
	})
	return flight(origin, dir, speed, t0, range, D, function(pos, t)
		local r = D * 0.5
		carrier.CFrame = CFrame.lookAt(pos, pos + dir)
		orb.Size = Vector3.one * D
		orb.CFrame = CFrame.new(pos)
		placeCracks(cracks, pos, r, CFrame.Angles(t * 5, t * 3, 0), 1, 1)
		for i, bs in ipairs(bands) do
			local n = (CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, i * 1.3) * CFrame.Angles(0.5, 0, 0)).LookVector
			arc(bs, pos, n, r * 1.12, r * 0.28, t * 12 * (if i == 2 then -1 else 1), math.pi * 1.6, false, 1)
		end
		placeRake(rays, pos, dir, D, t, 0.55)
	end, function()
		g:Destroy()
		rg:Destroy()
		for _, bs in ipairs(bands) do
			killBeams(bs)
		end
		task.delay(0.8, function()
			carrier:Destroy()
		end)
	end)
end

local function explodeF3(pos: Vector3, n: Vector3, R: number, grounded: boolean, power: number, stage: number)
	local near = nearCam(pos, R)
	if near > 0 then
		FX.shake(near * (0.8 + 0.8 * power))
	end
	fovKick(pos, R, 7 + 5 * stage)
	-- dome pop: black orb swells (cracks blazing), flashes solid yellow, then everything detonates
	local g = Instance.new("Model")
	g.Parent = root()
	local orb = blackOrb(g)
	local cracks = crackNet(8, 5, g)
	job(0.2, function(k)
		local r = R * lerp(0.25, 0.6, outQuart(k))
		orb.Size = Vector3.one * r * 2
		orb.CFrame = CFrame.new(pos)
		if k > 0.6 then
			orb.Material = NEON
			orb.Color = YEL
		end
		placeCracks(cracks, pos, r, CFrame.new(), 1, if k > 0.6 then 0 else 1)
		return
	end, function()
		g:Destroy()
		if near > 0 then
			FX.flash(0.7 * near, 0.3, WHITE)
		end
		inkBurst(pos, R * 1.1, 12 + 4 * stage, 0.25)
		starburst(pos, R * 1.1, { YEL, WHITE, ORG }, RED, 10 + 4 * stage)
		bigRays(pos, n, R, 6 + 4 * stage, YEL, ORG)
		bandSnap(pos, n, R * 1.1, { YEL, ORG, YEL }, 0.5)
		shockBand(pos, n, R * 0.3, R * 2.6, R * 0.22, YEL, 0.45)
		shockBand(pos, n, R * 0.2, R * 2, R * 0.14, RED, 0.55, 0.06)
		speedLines(pos, n, R, 16 + 8 * stage, { ORG, RED, YEL })
		for i = 1, 3 + 2 * stage do
			billboard(pos + hemi(n, 0.5) * R * rng:NextNumber(0, 0.6), R * rng:NextNumber(1.2, 1.9), if i % 2 == 0 then "explosion_crimson_4x4" else "explosion_orange_4x4", rng:NextNumber(0.6, 0.85), nil, rng:NextNumber(0, 360), (i - 1) * 0.04)
		end
		fireRing(pos, n, R * 1.15, "flame_orange_4x4", 1.4 + 0.3 * stage, 12 + 4 * stage)
		cubes(pos, n, R, 6 + 5 * stage)
		if grounded then
			plate(pos + n * 0.15, n, "crack_burst", ORG, 2, R * 1.4, R * 2, 0, 0.6)
		end
		if stage >= 2 then
			flares(pos, n, R, 2 * stage, { PINK, PURPLE }, 0.7)
		end
		if stage >= 3 then
			ribbons(pos, n, R, 8, "beam_flame_orange")
			for i = 1, 4 do
				billboard(pos + n * R * 0.45 * i, R * (1.3 + 0.2 * i), "explosion_crimson_4x4", 0.9, nil, rng:NextNumber(0, 360), 0.1 + i * 0.07)
			end
		end
		for i = 1, 8 * stage do
			chunk(pos + randUnit() * R * 0.3, hemi(n, 0.3) * R * rng:NextNumber(0.6, 1.8), Vector3.one * R * rng:NextNumber(0.025, 0.05), if i % 3 == 0 then YEL else ORG, rng:NextNumber(1, 1.8), -R * 0.8)
		end
	end)
end

-- Muzzle: a short band snap + starburst + forward speed lines, in the move's colours.
local MUZ = {
	R = { cols = { YEL, ORG }, shards = { YEL, WHITE, ORG }, outline = RED },
	Q = { cols = { PINK, VIOLET }, shards = { PINK, VIOLET, WHITE }, outline = DEEP },
	F = { cols = { YEL, RED }, shards = { ORG, YEL, RED }, outline = CRIMSON },
}

FX.charge = function(getMouth: () -> CFrame?, t0: number, maxT: number, maxD: number, move: string?)
	if move == "Q" then
		return chargeQ3(getMouth, t0, maxT, maxD)
	elseif move == "F" then
		return chargeF3(getMouth, t0, maxT, maxD)
	end
	return chargeR3(getMouth, t0, maxT, maxD)
end

FX.muzzle = function(pos: Vector3, dir: Vector3, D: number, power: number, move: string?)
	local m = MUZ[move or "R"] or MUZ.R
	starburst(pos, D * 1.6, m.shards, m.outline, 6 + math.floor(power * 4))
	bandSnap(pos - dir * D * 0.3, dir, D * 1.2, m.cols, 0.28)
	speedLines(pos, dir, D * 1.5, 8 + math.floor(power * 6), { m.cols[1], m.cols[2], WHITE })
	shockBand(pos, dir, D * 0.4, D * 2.6, D * 0.18, m.cols[1], 0.3)
end

FX.projectile = function(move: string, origin: Vector3, dir: Vector3, speed: number, D: number, t0: number, range: number, power: number): Shot
	if move == "Q" then
		return projectileQ3(origin, dir, speed, D, t0, range, power)
	elseif move == "F" then
		return projectileF3(origin, dir, speed, D, t0, range, power)
	end
	return projectileR3(origin, dir, speed, D, t0, range, power)
end

FX.explode = function(move: string, pos: Vector3, normal: Vector3, R: number, grounded: boolean, power: number, failed: boolean?)
	R *= Config.FIREBALL.EXPLOSION_SCALE -- visual size only; the server damage radius is unchanged
	if failed then
		explodeFail(pos, normal, R, power)
		return
	end
	local n = if normal.Magnitude > 0.01 then normal.Unit else Vector3.yAxis
	local stage = if power >= 0.99 then 3 elseif power >= 0.34 then 2 else 1
	if move == "Q" then
		explodeQ3(pos, n, R, grounded, power, stage)
	elseif move == "F" then
		explodeF3(pos, n, R, grounded, power, stage)
	else
		explodeR3(pos, n, R, grounded, power, stage)
	end
end

return FX

