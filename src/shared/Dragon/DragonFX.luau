--!strict
-- Client-only VFX for the West dragon fireball: charge orb, launch flash, projectile, explosion.
-- Blox Fruits cel look (same language as the West transform): flat saturated Neon geometry,
-- black/orange Highlight outlines, solid untextured trails, yellow cone rays, black smoke,
-- navy debris cubes, lava cracks and a fire ring. No stock sprites/textures.
-- Everything is driven from one RenderStepped job list; nothing here touches gameplay.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FX = {}

local YEL = Color3.fromRGB(255, 214, 20)
local ORG = Color3.fromRGB(255, 118, 0)
local RED = Color3.fromRGB(225, 35, 15)
local PINK = Color3.fromRGB(255, 40, 190)
local WHITE = Color3.fromRGB(255, 250, 225)
local BLK = Color3.fromRGB(18, 16, 20)
local SMOKE = Color3.fromRGB(45, 40, 48)
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

-- Trail on a carrier part. FaceCamera=false so the ribbon spans the two attachments.
local FIRE_SEQ = ColorSequence.new({
	ColorSequenceKeypoint.new(0, WHITE),
	ColorSequenceKeypoint.new(0.15, YEL),
	ColorSequenceKeypoint.new(0.5, ORG),
	ColorSequenceKeypoint.new(1, RED),
})
local function trail(carrier: BasePart, p0: Vector3, p1: Vector3, colors: ColorSequence, lifetime: number)
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
	tr.Brightness = 2.5
	tr.FaceCamera = false
	tr.MinLength = 0
	tr.Parent = carrier
end

-- Public effects ----------------------------------------------------------------------------

-- Charge orb in front of the mouth. getMouth returns a CFrame facing forward (-Z), or nil to end.
function FX.charge(getMouth: () -> CFrame?, t0: number, maxT: number, baseD: number)
	local g = group(BLK)
	local core, mid, shell = ball(WHITE, g), ball(YEL, g), ball(ORG, g)
	local light = Instance.new("PointLight")
	light.Color = ORG
	light.Parent = core
	local ringA, ringB = segs(18, ORG, g), segs(18, YEL, g)
	local center = Vector3.zero
	local curD = baseD * 0.5
	local fwd = Vector3.zAxis
	local alive, maxed = true, false
	local streakAcc, zapAcc, pulseAcc = 0, 0, 0

	local function streak()
		local dir = randUnit()
		local roll = rng:NextNumber()
		local p = newPart(if roll < 0.15 then PINK elseif roll < 0.55 then YEL else ORG)
		local r0 = curD * rng:NextNumber(2.4, 3.8)
		local L0 = curD * rng:NextNumber(0.8, 1.4)
		local w = curD * 0.07
		job(rng:NextNumber(0.18, 0.28), function(k)
			local e = k * k
			local r = r0 * (1 - e) + curD * 0.45 * e
			local L = L0 * (1 - k) + 0.05
			local a = center + dir * r
			p.Size = Vector3.new(w, w, L)
			p.CFrame = CFrame.lookAt(a + dir * L / 2, a)
			return
		end, function()
			p:Destroy()
		end)
	end

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
		curD = baseD * (1 + c) * 0.8 * outBack(math.min(t / 0.18, 1))
		fwd = mcf.LookVector
		local jit = if c >= 1 then randUnit() * curD * 0.05 else Vector3.zero
		center = mcf.Position + fwd * curD * 0.6 + jit
		local pul = 1 + (0.04 + 0.08 * c) * math.sin(t * (18 + 30 * c))
		core.Size = Vector3.one * curD * 0.45 * pul
		mid.Size = Vector3.one * curD * 0.72 * pul
		shell.Size = Vector3.one * curD * pul
		core.Position, mid.Position, shell.Position = center, center, center
		shell.Color = ORG:Lerp(RED, 0.4 * math.sin(t * 9) ^ 2)
		light.Range = math.min(60, curD * 4)
		light.Brightness = 2 + 5 * c

		local rA = CFrame.Angles(t * 3.1, t * 1.7, 0)
		local rB = CFrame.Angles(-t * 2.3, 0, t * 2.9)
		placeRing(ringA, center, rA.LookVector, curD * (0.85 + 0.08 * math.sin(t * 7)), curD * (0.07 + 0.1 * c))
		placeRing(ringB, center, rB.UpVector, curD * 1.02, curD * (0.05 + 0.08 * c))

		streakAcc += dt * (22 + 70 * c)
		while streakAcc >= 1 do
			streakAcc -= 1
			streak()
		end
		zapAcc += dt * (3 + 24 * c)
		while zapAcc >= 1 do
			zapAcc -= 1
			zap(center, curD * 0.6, if c >= 1 and rng:NextNumber() < 0.5 then PINK else WHITE)
		end
		if c >= 1 then
			if not maxed then
				maxed = true
				ring(center, fwd, 0.35, function(k)
					return curD * lerp(0.6, 2.8, outQuart(k))
				end, function(k)
					return curD * 0.22 * (1 - k)
				end, PINK, 26)
				puff(center, Vector3.zero, curD * 0.6, curD * 1.9, WHITE, PINK, 0.2, nil, 0.2)
			end
			pulseAcc += dt
			if pulseAcc > 0.28 then
				pulseAcc = 0
				local at = center
				ring(at, fwd, 0.25, function(k)
					return curD * lerp(0.7, 1.7, k)
				end, function(k)
					return curD * 0.08 * (1 - k)
				end, PINK, 20)
			end
		end
		return
	end, function()
		g:Destroy()
	end)

	return {
		stop = function()
			alive = false
		end,
	}
end

-- Launch flash at the mouth: star shards, white pop, recoil ring.
function FX.muzzle(pos: Vector3, dir: Vector3, D: number, power: number)
	local g = group(ORG)
	for i = 1, 8 + math.floor(power * 4) do
		local ws = spikeParts(if i % 3 == 0 then WHITE else YEL, g)
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
	puff(pos, Vector3.zero, D * 0.5, D * 2.4, WHITE, YEL, 0.16, nil, 0.2)
	ring(pos, dir, 0.3, function(k)
		return D * lerp(0.6, 3.2, outQuart(k))
	end, function(k)
		return D * 0.35 * (1 - k)
	end, YEL, 20)
	ring(pos, dir, 0.36, function(k)
		return D * lerp(0.4, 2.4, outQuart(k))
	end, function(k)
		return D * 0.18 * (1 - k)
	end, if power > 0.5 then PINK else ORG, 18, 0.05)
	for _ = 1, 3 do
		puff(pos - dir * D * 0.5, randUnit() * D + Vector3.new(0, D, 0), D * 0.4, D * 1.1, BLK, SMOKE, 0.7, FLAT, 0.3)
	end
end

export type Shot = { stop: () -> (), pos: Vector3 }

-- Projectile visuals. Position is derived from server time so all clients agree.
function FX.projectile(origin: Vector3, dir: Vector3, speed: number, D: number, t0: number, range: number, power: number): Shot
	local g = group(BLK)
	local shell = ball(ORG, g)
	local mid = ball(YEL, g)
	local core = ball(WHITE, g)
	local tail = blob(RED, g)
	local tongues: { Part } = {}
	for i = 1, 7 do
		tongues[i] = blob(if i % 2 == 0 then YEL else ORG, g)
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
	trail(carrier, Vector3.new(0, D * 0.5, 0), Vector3.new(0, -D * 0.5, 0), FIRE_SEQ, life)
	trail(carrier, Vector3.new(D * 0.5, 0, 0), Vector3.new(-D * 0.5, 0, 0), FIRE_SEQ, life)
	local helix = 3 + (if power > 0.5 then 1 else 0)
	for i = 1, helix do
		local a = i / helix * math.pi * 2
		local r0, r1 = D * 0.55, D * 0.78
		local cs = if i == 4 then ColorSequence.new(PINK, RED) else ColorSequence.new(YEL, ORG)
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
		while emberAcc > 0.018 do
			emberAcc -= 0.018
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
				chunk(pos + randUnit() * D * 0.6, randUnit() * D * 3, Vector3.new(D * 0.06, D * 0.06, D * 0.4), PINK, 0.3, 0)
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
function FX.explode(pos: Vector3, normal: Vector3, R: number, grounded: boolean, power: number)
	local n = if normal.Magnitude > 0.01 then normal.Unit else Vector3.yAxis
	local u, v = basis(n)

	-- 1. White-out core pop.
	puff(pos, Vector3.zero, R * 0.3, R * 1.15, WHITE, YEL, 0.22, nil, 0.35)

	-- 2. Cel fireball: cluster of balls that pop (outBack), drift out/up, shift yellow->orange->red, shrink out.
	local fire = group(BLK)
	for _ = 1, 11 + math.floor(power * 7) do
		local off = hemi(n, 0.6) * R * rng:NextNumber(0, 0.45)
		local size = R * rng:NextNumber(0.38, 0.62)
		local inner = off.Magnitude < R * 0.2
		local c0 = if inner then WHITE else YEL
		local c1 = if inner then YEL elseif rng:NextNumber() < 0.5 then ORG else RED
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
			b.Color = c0:Lerp(c1, math.min(k * 2.2, 1)):Lerp(RED, math.max(0, (k - 0.6) / 0.4))
			return
		end)
	end
	task.delay(1.25, function()
		fire:Destroy()
	end)

	-- 3. Thick yellow cone rays with orange outlines.
	local rays = group(ORG)
	for _ = 1, 9 + math.floor(power * 6) do
		local d = hemi(n, 0.35)
		local ws = spikeParts(YEL, rays)
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
	end, YEL, 32)
	ring(pos, n, 0.5, function(k)
		return R * lerp(0.2, 1.45, outQuart(k))
	end, function(k)
		return R * 0.13 * (1 - k)
	end, ORG, 28, 0.06)
	ring(pos + n * R * 0.05, n, 0.55, function(k)
		return R * lerp(0.3, 2.3, outQuart(k))
	end, function(k)
		return R * 0.05 * (1 - k)
	end, PINK, 32, 0.1)

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
	for _ = 1, 26 do
		chunk(pos, hemi(n, 0.2) * R * rng:NextNumber(2, 3.6), Vector3.one * R * rng:NextNumber(0.02, 0.045), if rng:NextNumber() < 0.5 then YEL else ORG, rng:NextNumber(0.5, 0.9), R * 3)
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
				local p = newPart(ORG)
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
				cr.p.Color = YEL:Lerp(RED, k)
			end
			return
		end, function()
			for _, cr in ipairs(cracks) do
				cr.p:Destroy()
			end
		end)

		local flames = group(RED)
		for i = 1, 16 do
			local a = i / 16 * math.pi * 2
			local base = pos + (u * math.cos(a) + v * math.sin(a)) * R * 0.95
			local tan = -u * math.sin(a) + v * math.cos(a)
			local outer, inner = blob(ORG, flames), blob(YEL, flames)
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
	local lp = newPart(ORG)
	lp.Transparency = 1
	lp.Position = pos
	local L = Instance.new("PointLight")
	L.Color = ORG
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
		FX.flash(0.55 * i, 0.25)
	end
end

return FX
