--!strict
-- DigScreen: Relic Dig, v8 (client side of the dig field).
--
-- The field is built once on the server (DigFieldService) and is shared and
-- static. Everything about a DIG is local to the player doing it: the plot's
-- sand layers shrink only on their own screen, the buried chest is a local
-- model, and the camera, lighting, particles and sounds are all local. So any
-- number of players can dig the same plot at once and nothing is claimed or
-- replicated. When a player finishes (or leaves) the plot is put back.
--
-- The goal: uncover the WHOLE chest in as few taps as possible. Each tap
-- lowers the sand (layers go away top first); tapping nearer the middle of the
-- green zone lowers it more. There is no tap limit: the moment the chest is
-- fully out it opens, then the reel plays full-screen. The server turns the
-- tap count into the reward level; chance only picks the item inside it.

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local DigConfig = require(ReplicatedStorage.Shared.Config.DigConfig)
local Net = require(script.Parent.Parent.Net)
local Theme = require(script.Parent.Theme)

local DigScreen = {}

local S = DigConfig.Site

-- PLACEHOLDERS: no published numbers; tune in playtests
local GAIN_MIN, GAIN_MAX, GAIN_OUT = 0.07, 0.24, 0 -- fraction of the dig depth per tap (zone edge / centre / miss: a miss digs nothing)
local ZONE_END_FRAC = 0.7 -- the green zone shrinks to this fraction of its width as the chest comes out
local SPEED_START, SPEED_END = 0.75, 1.3 -- marker sweeps (bar lengths) per second
local BASE_FOV = 55
local END_ABOVE_FLOOR = 0.06 -- the sand ends this far above the pit floor (the chest base is clear)

-- chest, in studs (long axis along X, lock faces the camera)
local CHEST_L, CHEST_W, CHEST_H = 4.0, 3.0, 0.85
local CHEST_TINTS = {
	{ wood = Color3.fromRGB(128, 84, 50), groove = Color3.fromRGB(88, 56, 34), metal = Color3.fromRGB(226, 172, 62) },
	{ wood = Color3.fromRGB(104, 66, 40), groove = Color3.fromRGB(70, 44, 28), metal = Color3.fromRGB(214, 160, 56) },
	{ wood = Color3.fromRGB(150, 100, 58), groove = Color3.fromRGB(104, 68, 38), metal = Color3.fromRGB(232, 180, 70) },
}
local ZONE_EDGE, ZONE_CENTRE = Color3.fromRGB(48, 138, 66), Color3.fromRGB(122, 232, 118)
local DUST = Color3.fromRGB(226, 196, 144)
local TIER_COLOR = { Perfect = Color3.fromRGB(255, 205, 90), Great = Color3.fromRGB(122, 232, 118), Good = Color3.fromRGB(120, 190, 255), Floor = Color3.fromRGB(160, 168, 180) }

--------------------------------------------------------------------------------
-- small helpers
--------------------------------------------------------------------------------

local revealer: ((item: any, pool: { any }, opts: any) -> ())? = nil
function DigScreen.setRevealer(fn: (item: any, pool: { any }, opts: any) -> ())
	revealer = fn
end

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function part(props: { [string]: any }, parent: Instance): Part
	local p = new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}, nil)
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- sounds: real library effects, with a built-in fallback if one fails to load
local FALLBACK: { [string]: string? } = { Strike = "rbxasset://sounds/snap.mp3", Ping = "rbxasset://sounds/electronicpingshort.wav" }
local soundOk: { [string]: boolean } = {}

local function preloadSounds()
	task.spawn(function()
		for key, id in DigConfig.Sounds do
			local s = Instance.new("Sound")
			s.SoundId = id
			pcall(function()
				ContentProvider:PreloadAsync({ s })
			end)
			soundOk[key] = s.IsLoaded and s.TimeLength > 0
			s:Destroy()
		end
	end)
end

local function sfx(key: string, volume: number, speed: number)
	local id: string? = DigConfig.Sounds[key]
	if soundOk[key] == false then
		id = FALLBACK[key]
	end
	if not id then
		return
	end
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local s = new("Sound", { SoundId = id, Volume = volume, PlaybackSpeed = speed, RollOffMaxDistance = 0 }, pg)
	s:Play()
	task.delay(4, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

--------------------------------------------------------------------------------
-- state
--------------------------------------------------------------------------------

local hud: ScreenGui? = nil
local ui: { [string]: any } = {}
local conn: RBXScriptConnection? = nil
local inputConn: RBXScriptConnection? = nil
local active = false
local runGen = 0 -- bumps on every run / close so stale delayed callbacks do nothing

local plot: Model? = nil
local pit: BasePart? = nil
local localFolder: Folder? = nil
type LayerInfo = { part: BasePart, y0: number, h: number, cf: CFrame, size: Vector3, collide: boolean }
local layers: { LayerInfo } = {} -- sand layers, bottom to top
local tweens: { Tween } = {}
local savedCamera: { type: Enum.CameraType, fov: number }? = nil
local savedWalk: { speed: number, jump: number }? = nil
local lookFx: { dof: DepthOfFieldEffect, cc: ColorCorrectionEffect }? = nil

-- camera
local baseCF, closeCF, startCF = CFrame.new(), CFrame.new(), CFrame.new()
local blendT, camPush, camPushTarget = 1, 0, 0
local shakeLeft, kick = 0, 0

local chestLight: PointLight? = nil
local lidParts: { Part } = {}
local lidHinge = CFrame.new()
local chestBase = CFrame.new()
local brush: Part? = nil
local brushDust: ParticleEmitter? = nil
local coins: { { part: Part, vel: Vector3, spin: Vector3, t: number } } = {}

local zonePerk = 0.26
local digXp = 0
local pendingResult: any = nil

local run = {
	progress = 0, -- 0..1 of the way down to the chest
	taps = 0,
	marker = 0,
	dir = 1,
	zoneCenter = 0.5,
	zoneWidth = 0.26,
	locked = true,
}

--------------------------------------------------------------------------------
-- the plot's sand, lowered locally
--------------------------------------------------------------------------------

local function floorTopY(): number
	local p = pit :: BasePart
	return p.Position.Y + p.Size.Y / 2
end

local function groundTopY(): number
	return floorTopY() + DigConfig.blockH()
end

local function stopTweens()
	for _, tw in tweens do
		tw:Cancel()
	end
	table.clear(tweens)
end

-- put the sand back exactly as the server built it
local function restoreSand()
	stopTweens()
	for _, l in layers do
		if l.part.Parent then
			l.part.CFrame = l.cf
			l.part.Size = l.size
			l.part.Transparency = 0
			l.part.CanCollide = l.collide
		end
	end
end

local function clearLocal()
	if localFolder then
		localFolder:Destroy()
		localFolder = nil
	end
	table.clear(lidParts)
	table.clear(coins)
	chestLight = nil
	brush = nil
	brushDust = nil
end

local function scanPlot()
	local model = plot :: Model
	table.clear(layers)
	local folder = model:FindFirstChild("Layers")
	if not folder then
		return
	end
	local list = {}
	for _, b in folder:GetChildren() do
		if b:IsA("BasePart") then
			table.insert(list, b)
		end
	end
	table.sort(list, function(a, b)
		return a.Position.Y < b.Position.Y
	end)
	for _, b in list do
		table.insert(layers, { part = b, y0 = b.Position.Y - b.Size.Y / 2, h = b.Size.Y, cf = b.CFrame, size = b.Size, collide = b.CanCollide })
	end
end

-- the sand surface at progress p (0 = ground level, 1 = down to the chest base)
local function levelAt(p: number): number
	local top = groundTopY()
	return top - math.clamp(p, 0, 1) * (top - (floorTopY() + END_ABOVE_FLOOR))
end

-- set every layer to the given sand level, with a short tween
local function setSandLevel(level: number, time: number)
	for _, l in layers do
		local h = math.clamp(level - l.y0, 0, l.h)
		local gone = h < 0.03
		local hh = if gone then 0.03 else h
		local cf = l.cf - Vector3.new(0, l.cf.Position.Y, 0) + Vector3.new(0, l.y0 + hh / 2, 0)
		l.part.CanCollide = false
		local tw = TweenService:Create(l.part, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(l.size.X, hh, l.size.Z),
			CFrame = cf,
			Transparency = if gone then 1 else 0,
		})
		table.insert(tweens, tw)
		tw:Play()
	end
end

-- A treasure chest built from parts, in plot space: wood body with plank
-- grooves, metal corner posts and bands, an arched vault lid with rings, a lock
-- plate, and a hoard of coins and gems hidden under the lid until it opens.
local function buildChest(folder: Folder, base: CFrame, tint: { wood: Color3, groove: Color3, metal: Color3 })
	local L, W, H = CHEST_L, CHEST_W, CHEST_H
	local yb = 0.12
	local top = yb + H -- top of the body
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end
	part({ Name = "Plinth", Size = Vector3.new(L + 0.24, 0.12, W + 0.24), CFrame = at(0, 0.06, 0), Color = Color3.fromRGB(58, 52, 48), Material = Enum.Material.Metal }, folder)
	part({ Name = "Body", Size = Vector3.new(L, H, W), CFrame = at(0, yb + H / 2, 0), Color = tint.wood, Material = Enum.Material.WoodPlanks }, folder)
	for _, f in { 0.33, 0.66 } do
		part({ Name = "Groove", Size = Vector3.new(L + 0.04, 0.05, W + 0.04), CFrame = at(0, yb + H * f, 0), Color = tint.groove, Material = Enum.Material.Wood }, folder)
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part({ Name = "Post", Size = Vector3.new(0.3, H + 0.05, 0.3), CFrame = at(x * (L / 2 - 0.04), yb + H / 2, z * (W / 2 - 0.04)), Color = tint.metal, Material = Enum.Material.Metal }, folder)
		end
	end
	for _, x in { -L * 0.3, L * 0.3 } do
		part({ Name = "Band", Size = Vector3.new(0.34, H + 0.05, W + 0.07), CFrame = at(x, yb + H / 2, 0), Color = tint.metal, Material = Enum.Material.Metal }, folder)
		for _, yy in { 0.2, 0.8 } do
			part({ Name = "Rivet", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.15, CFrame = at(x, yb + H * yy, W / 2 + 0.05), Color = tint.metal, Material = Enum.Material.Metal }, folder)
		end
	end
	part({ Name = "LockPlate", Size = Vector3.new(0.72, 0.62, 0.12), CFrame = at(0, yb + H * 0.72, W / 2 + 0.08), Color = tint.metal, Material = Enum.Material.Metal }, folder)
	part({ Name = "Keyhole", Size = Vector3.new(0.1, 0.24, 0.14), CFrame = at(0, yb + H * 0.7, W / 2 + 0.1), Color = Color3.fromRGB(24, 20, 18), Material = Enum.Material.Metal }, folder)

	-- the inside of the chest (empty: the real prize comes from the reel)
	local hoard = part({ Name = "Inside", Size = Vector3.new(L - 0.5, 0.05, W - 0.5), CFrame = at(0, top - 0.03, 0), Color = Color3.fromRGB(52, 34, 26), Material = Enum.Material.Wood }, folder)
	chestLight = new("PointLight", { Color = Color3.fromRGB(255, 214, 120), Range = 14, Brightness = 0, Shadows = false }, hoard)

	-- the lid: an arched vault made of five curved planks (so it swings open as a
	-- light, hollow lid) with metal rings and a hasp, hinged on the back edge
	local R = 2.6
	local cy = top - R * math.cos(math.rad(35)) -- arch circle centre: the lid edges meet the body top
	for _, deg in { -28, -14, 0, 14, 28 } do
		local a = math.rad(deg)
		table.insert(lidParts, part({
			Name = "LidPlank",
			Size = Vector3.new(L, 0.14, 0.74),
			CFrame = at(0, cy + R * math.cos(a), R * math.sin(a)) * CFrame.Angles(a, 0, 0),
			Color = tint.wood,
			Material = Enum.Material.WoodPlanks,
		}, folder))
		for _, x in { -L * 0.3, L * 0.3 } do
			table.insert(lidParts, part({
				Name = "LidRing",
				Size = Vector3.new(0.34, 0.2, 0.78),
				CFrame = at(x, cy + (R + 0.04) * math.cos(a), (R + 0.04) * math.sin(a)) * CFrame.Angles(a, 0, 0),
				Color = tint.metal,
				Material = Enum.Material.Metal,
			}, folder))
		end
	end
	table.insert(lidParts, part({ Name = "Hasp", Size = Vector3.new(0.5, 0.42, 0.1), CFrame = at(0, top + 0.08, W / 2 + 0.03), Color = tint.metal, Material = Enum.Material.Metal }, folder))
	lidHinge = at(0, top, -W / 2)
end

local function buildWorld()
	clearLocal()
	local p = pit :: BasePart
	local folder = new("Folder", { Name = "DigLocal" }, workspace)
	localFolder = folder

	scanPlot()

	-- chest position: anywhere inside the plot with room around it
	local wC, hC = math.floor(CHEST_L / S.tile), math.floor(CHEST_W / S.tile)
	local c0 = math.random(math.ceil(wC / 2) + 1, S.cols - math.ceil(wC / 2))
	local r0 = math.random(math.ceil(hC / 2) + 1, S.rows - math.ceil(hC / 2))
	local cx = if wC % 2 == 1 then c0 else c0 + 0.5
	local cy = if hC % 2 == 1 then r0 else r0 + 0.5
	local off = DigConfig.cellOffset(cx, cy)
	chestBase = p.CFrame * CFrame.new(off.X, p.Size.Y / 2, off.Z)
	buildChest(folder, chestBase, CHEST_TINTS[math.random(1, #CHEST_TINTS)])

	-- the brush: wooden handle, brass ferrule and soft bristles, with a dust trail
	local b = part({ Name = "Brush", Size = Vector3.new(1.0, 0.22, 0.46), Color = Color3.fromRGB(232, 202, 150), Material = Enum.Material.Fabric, Transparency = 1 }, folder)
	brush = b
	for _, spec in {
		{ "Ferrule", Vector3.new(0.5, 0.2, 0.36), CFrame.new(0, 0.1, -0.38), Color3.fromRGB(190, 160, 70), Enum.Material.Metal },
		{ "Handle", Vector3.new(0.17, 0.17, 1.7), CFrame.new(0, 0.14, -1.28), Color3.fromRGB(120, 78, 44), Enum.Material.Wood },
	} do
		local sub = part({ Name = spec[1], Size = spec[2], CFrame = b.CFrame * spec[3], Color = spec[4], Material = spec[5], Transparency = 1, Anchored = false, Massless = true }, b)
		new("WeldConstraint", { Part0 = b, Part1 = sub }, b)
	end
	local att = new("Attachment", {}, b)
	brushDust = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(DUST),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(60, 60),
		Rate = 0,
		Enabled = false,
	}, att)
end

--------------------------------------------------------------------------------
-- effects
--------------------------------------------------------------------------------

local function burst(pos: Vector3, count: number, color: Color3, size: number, speedMax: number)
	local f = localFolder
	if not f then
		return
	end
	local ep = part({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos }, f)
	local att = new("Attachment", {}, ep)
	local pe = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size * 1.5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(speedMax * 0.4, speedMax),
		SpreadAngle = Vector2.new(75, 75),
		Rate = 0,
		Acceleration = Vector3.new(0, -7, 0),
	}, att)
	pe:Emit(count)
	task.delay(1.6, function()
		ep:Destroy()
	end)
end

-- flying chips of sand
local function chips(pos: Vector3, n: number)
	local f = localFolder
	if not f then
		return
	end
	for _ = 1, n do
		local s = math.random() * 0.14 + 0.08
		local c = part({
			Size = Vector3.one * s,
			CFrame = CFrame.new(pos + Vector3.new((math.random() - 0.5) * 1.6, 0.2, (math.random() - 0.5) * 1.6)) * CFrame.Angles(math.random() * 3, math.random() * 3, 0),
			Color = DUST:Lerp(Color3.fromRGB(160, 120, 76), math.random()),
			Material = Enum.Material.Sand,
		}, f)
		local rise = pos + Vector3.new((math.random() - 0.5) * 3.2, 0.6 + math.random() * 1.4, (math.random() - 0.5) * 3.2)
		local tw = TweenService:Create(c, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = rise, Transparency = 1 })
		table.insert(tweens, tw)
		tw:Play()
		task.delay(0.6, function()
			c:Destroy()
		end)
	end
end

-- the brush sweeps across the plot at the current sand level
local function sweepBrush(level: number)
	local b = brush
	if not b then
		return
	end
	local function show(v: number)
		b.Transparency = v
		for _, d in b:GetChildren() do
			if d:IsA("BasePart") then
				d.Transparency = v
			end
		end
	end
	local p = pit :: BasePart
	local zOff = (math.random() - 0.5) * 3
	local a = p.CFrame * CFrame.new(-5.2, 0, zOff)
	local z = p.CFrame * CFrame.new(5.2, 0, zOff + (math.random() - 0.5))
	local y = level + 0.55
	local cfA = CFrame.new(a.Position.X, y, a.Position.Z) * CFrame.Angles(math.rad(-14), math.rad(90), 0)
	local cfZ = CFrame.new(z.Position.X, y, z.Position.Z) * CFrame.Angles(math.rad(-14), math.rad(90), 0)
	show(0)
	b.CFrame = cfA
	if brushDust then
		brushDust.Enabled = true
	end
	local tw = TweenService:Create(b, TweenInfo.new(0.34, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = cfZ })
	table.insert(tweens, tw)
	tw:Play()
	-- sand spray along the sweep
	local gen = runGen
	for i = 0, 3 do
		task.delay(i * 0.09, function()
			if gen ~= runGen then
				return
			end
			local t = i / 3
			local pos = cfA.Position:Lerp(cfZ.Position, t) - Vector3.new(0, 0.3, 0)
			burst(pos, 8, DUST, 0.9, 6)
			chips(pos, 2)
		end)
	end
	task.delay(0.4, function()
		if gen == runGen and b.Parent then
			show(1)
			if brushDust then
				brushDust.Enabled = false
			end
		end
	end)
end

-- the chest lid swings open on its back edge; light, sparkles and coins burst out
local function openChest()
	for _, lp in lidParts do
		local rel = lidHinge:ToObjectSpace(lp.CFrame)
		local tw = TweenService:Create(lp, TweenInfo.new(0.85, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = lidHinge * CFrame.Angles(math.rad(-112), 0, 0) * rel })
		table.insert(tweens, tw)
		tw:Play()
	end
	if chestLight then
		local tw = TweenService:Create(chestLight, TweenInfo.new(0.8), { Brightness = 2.4, Range = 18 })
		table.insert(tweens, tw)
		tw:Play()
	end
	local f = localFolder
	if not f then
		return
	end
	local top = chestBase.Position + Vector3.new(0, CHEST_H + 0.3, 0)
	-- a soft beam of light out of the chest
	local beam = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 1.4, 1.4), CFrame = CFrame.new(top + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 226, 140), Material = Enum.Material.Neon, Transparency = 0.86, CastShadow = false }, f)
	local tb = TweenService:Create(beam, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1, Size = Vector3.new(8, 2.6, 2.6) })
	table.insert(tweens, tb)
	tb:Play()
	local att = new("Attachment", {}, part({ Transparency = 1, Size = Vector3.one * 0.2, Position = top }, f))
	local sp = new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 232, 150)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.9, 1.6),
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(40, 40),
		LightEmission = 1,
		Rate = 0,
		Acceleration = Vector3.new(0, -3, 0),
	}, att)
	sp:Emit(46)
	burst(top, 20, Color3.fromRGB(255, 232, 170), 1.2, 7)
	sfx("Creak", 0.7, 1)
	sfx("Ping", 0.7, 1.7)
	kick = 4
	shakeLeft = 0.3
end

local function stepCoins(dt: number)
	local floorY = floorTopY() + 0.3
	for i = #coins, 1, -1 do
		local c = coins[i]
		c.t += dt
		c.vel += Vector3.new(0, -24 * dt, 0)
		local pos = c.part.Position + c.vel * dt
		if pos.Y < floorY and c.vel.Y < 0 then
			pos = Vector3.new(pos.X, floorY, pos.Z)
			c.vel = Vector3.new(c.vel.X * 0.5, -c.vel.Y * 0.4, c.vel.Z * 0.5)
		end
		c.part.CFrame = CFrame.new(pos) * (c.part.CFrame - c.part.Position) * CFrame.Angles(c.spin.X * dt, c.spin.Y * dt, c.spin.Z * dt)
		if c.t > 1.5 then
			c.part.Transparency = math.min((c.t - 1.5) * 3, 1)
		end
		if c.t > 2 then
			c.part:Destroy()
			table.remove(coins, i)
		end
	end
end

--------------------------------------------------------------------------------
-- camera, lighting and the player
--------------------------------------------------------------------------------

local function plotCentreTop(): Vector3
	local p = pit :: BasePart
	return p.Position + Vector3.new(0, p.Size.Y / 2 + DigConfig.blockH(), 0)
end

local function aimCamera()
	local cam = workspace.CurrentCamera
	local aspect = cam.ViewportSize.X / math.max(cam.ViewportSize.Y, 1)
	local back = 9.5 * math.max(1, 1.55 / aspect) -- leaves a margin so the front corners are not on the screen edge
	local centre = plotCentreTop()
	local p = pit :: BasePart
	local fwd = p.CFrame.LookVector * -1 -- +Z of the plot: the camera side
	baseCF = CFrame.lookAt(centre + Vector3.new(0, back * 0.9, 0) + fwd * back * 0.62, centre)
	closeCF = baseCF * CFrame.new(0, 0, -back * 0.28)
	startCF = cam.CFrame
	blendT = 0
	camPush, camPushTarget = 0, 0
	cam.CameraType = Enum.CameraType.Scriptable
end

-- depth of field and a warm grade, local to this player, while digging
local function setLookFx(on: boolean)
	if on then
		if lookFx then
			return
		end
		local dof = new("DepthOfFieldEffect", { Name = "DigDOF", FarIntensity = 0, NearIntensity = 0, FocusDistance = 12, InFocusRadius = 22 }, Lighting)
		local cc = new("ColorCorrectionEffect", { Name = "DigCC", Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }, Lighting)
		lookFx = { dof = dof, cc = cc }
		TweenService:Create(dof, TweenInfo.new(0.8), { FarIntensity = 0.42 }):Play()
		TweenService:Create(cc, TweenInfo.new(0.8), { Brightness = 0.02, Contrast = 0.1, Saturation = 0.14, TintColor = Color3.fromRGB(255, 244, 226) }):Play()
	elseif lookFx then
		local fx = lookFx
		lookFx = nil
		TweenService:Create(fx.dof, TweenInfo.new(0.4), { FarIntensity = 0 }):Play()
		TweenService:Create(fx.cc, TweenInfo.new(0.4), { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		task.delay(0.5, function()
			fx.dof:Destroy()
			fx.cc:Destroy()
		end)
	end
end

local function lockPlayer(lock: boolean)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if lock then
		savedWalk = { speed = hum.WalkSpeed, jump = hum.JumpHeight }
		hum.WalkSpeed = 0
		hum.JumpHeight = 0
	elseif savedWalk then
		hum.WalkSpeed = savedWalk.speed
		hum.JumpHeight = savedWalk.jump
		savedWalk = nil
	end
end

--------------------------------------------------------------------------------
-- HUD (all scale-based)
--------------------------------------------------------------------------------

local function refreshHud()
	ui.barFill.Size = UDim2.fromScale(math.min(run.progress, 1), 1)
	ui.tapsLabel.Text = ("TAPS %d"):format(run.taps)
	-- the pace: which reward level this tap count is still on track for
	local tier = DigConfig.levelForTaps(run.taps)
	ui.paceLabel.Text = if tier == "Floor" then "SLOW" else string.upper(tier)
	ui.paceLabel.TextColor3 = TIER_COLOR[tier]
	local lvl, _, nextXp = DigConfig.progressionFor(digXp)
	ui.levelLabel.Text = ("DIG LV %d"):format(lvl)
	ui.xpLabel.Text = if nextXp then ("%d / %d XP"):format(digXp, nextXp) else "MAX"
end

local function floatText(text: string, color: Color3)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.3, 0.07),
		ZIndex = 20,
	}, hud)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }, l)
	-- hold fully visible for a beat, then drift up and fade
	TweenService:Create(l, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.46) }):Play()
	task.delay(0.9, function()
		TweenService:Create(l, TweenInfo.new(0.7), { TextTransparency = 1 }):Play()
		TweenService:Create(l:FindFirstChildOfClass("UIStroke") :: UIStroke, TweenInfo.new(0.7), { Transparency = 1 }):Play()
	end)
	task.delay(1.65, function()
		l:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- run flow
--------------------------------------------------------------------------------

local function newZone()
	local w = run.zoneWidth
	run.zoneCenter = w / 2 + math.random() * (1 - w)
	ui.zone.Size = UDim2.fromScale(w, 1)
	ui.zone.Position = UDim2.fromScale(run.zoneCenter - w / 2, 0)
end

local function startRun()
	runGen += 1
	restoreSand()
	pendingResult = nil
	local _, entry = DigConfig.progressionFor(digXp)
	zonePerk = entry.zone
	run.progress = 0
	run.taps = 0
	run.marker = 0
	run.dir = 1
	run.locked = false
	run.zoneWidth = zonePerk
	buildWorld()
	camPush, camPushTarget = 0, 0
	ui.root.Visible = true
	ui.leave.Visible = true
	ui.hint.Visible = true
	newZone()
	refreshHud()
end

function DigScreen.close()
	if not active and not plot then
		return
	end
	active = false
	runGen += 1
	run.locked = true
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if inputConn then
		inputConn:Disconnect()
		inputConn = nil
	end
	restoreSand()
	table.clear(layers)
	clearLocal()
	setLookFx(false)
	if hud then
		hud.Enabled = false
	end
	local cam = workspace.CurrentCamera
	if savedCamera then
		cam.CameraType = savedCamera.type
		cam.FieldOfView = savedCamera.fov
		savedCamera = nil
	else
		cam.CameraType = Enum.CameraType.Custom
	end
	lockPlayer(false)
	ProximityPromptService.Enabled = true
	plot, pit = nil, nil
end

-- the chest is fully out: it rattles, the lid opens, THEN the full-screen reel
local function finishRun()
	run.locked = true
	local gen = runGen
	local taps = run.taps
	task.spawn(function()
		pendingResult = Net.invoke("FinishDig", taps, false, 0)
	end)
	local function live(): boolean
		return active and gen == runGen
	end
	task.delay(0.5, function()
		if not live() then
			return
		end
		ui.root.Visible = false
		ui.leave.Visible = false
		camPushTarget = 1 -- ease in on the chest
	end)
	task.delay(1.3, function()
		if live() then
			shakeLeft = 0.25 -- the chest rattles before it opens
			sfx("Strike", 0.4, 0.7)
		end
	end)
	task.delay(1.7, function()
		if live() then
			openChest()
		end
	end)
	task.delay(3.2, function()
		if not live() then
			return
		end
		task.spawn(function()
			local waited = 0
			while pendingResult == nil and waited < 8 do
				task.wait(0.1)
				waited += 0.1
			end
			if not live() then
				return
			end
			local result = pendingResult
			if not result or not result.ok then
				ui.root.Visible = true
				ui.hint.Text = "The site is restocking. Try again in a moment."
				ui.hint.Visible = true
				task.delay(2.5, function()
					if active then
						DigScreen.close()
					end
				end)
				return
			end
			digXp = result.digXp or digXp
					if revealer then
				revealer(result.item, result.reel, {
					fullscreen = true,
					againText = "Again",
					doneText = "Leave",
					wonText = "You dug up…",
					onAgain = function()
						if active then
							startRun()
							if result.levelUp then
								floatText("LEVEL UP! Wider green zone", Theme.Gold)
							end
						end
					end,
					onDone = function()
						DigScreen.close()
					end,
				})
			else
				DigScreen.close()
			end
		end)
	end)
end

local function strike()
	if run.locked or not active then
		return
	end
	ui.hint.Visible = false
	-- the greener (closer to the centre), the more sand comes off
	local half = run.zoneWidth / 2
	local dist = math.abs(run.marker - run.zoneCenter)
	local closeness = if dist <= half then 1 - dist / half else 0
	local gain = if dist <= half then GAIN_MIN + (GAIN_MAX - GAIN_MIN) * closeness ^ 1.3 else GAIN_OUT
	run.taps += 1
	run.progress = math.min(run.progress + gain, 1)

	local level = levelAt(run.progress)
	sweepBrush(levelAt(run.progress - gain))
	setSandLevel(level, 0.45)
	if chestLight then
		chestLight.Brightness = 2.2 * math.min(run.progress, 1)
	end
	sfx("Brush", 0.45, 1 + closeness * 0.15)

	local pct = ("+%d%%"):format(math.floor(gain * 100 + 0.5))
	if dist > half then
		floatText("MISS", Color3.fromRGB(200, 205, 215))
		sfx("Strike", 0.35, 0.8)
	elseif closeness >= 0.85 then
		floatText("PERFECT  " .. pct, ZONE_CENTRE)
		sfx("Strike", 0.85, 1.15)
		sfx("Ping", 0.55, 1.7)
		shakeLeft = 0.24
		kick = 3
	else
		floatText(pct, ZONE_EDGE:Lerp(ZONE_CENTRE, closeness))
		sfx("Strike", 0.55 + closeness * 0.25, 0.95 + closeness * 0.2)
		shakeLeft = 0.08 + closeness * 0.1
		kick = 1 + closeness
	end

	-- the green zone shrinks and the marker speeds up as the chest comes out
	run.zoneWidth = zonePerk * (1 - (1 - ZONE_END_FRAC) * math.min(run.progress, 1))
	newZone()
	refreshHud()

	if run.progress >= 0.999 then
		finishRun()
	end
end

local function step(dt: number)
	if not active then
		return
	end
	local cam = workspace.CurrentCamera

	-- camera: blend in, idle sway, push-in on the finale, strike shake and FOV kick
	if blendT < 1 then
		blendT = math.min(blendT + dt / 0.8, 1)
	end
	camPush += (camPushTarget - camPush) * math.min(1, dt * 2.2)
	local e = 1 - (1 - blendT) ^ 3
	local target = baseCF:Lerp(closeCF, camPush)
	local t = os.clock()
	local sway = CFrame.new(math.sin(t * 0.7) * 0.06, math.cos(t * 0.5) * 0.04, 0) * CFrame.Angles(0, math.sin(t * 0.4) * 0.003, 0)
	local shake = CFrame.identity
	if shakeLeft > 0 then
		shakeLeft -= dt
		local m = 0.07 * math.clamp(shakeLeft / 0.25, 0, 1)
		shake = CFrame.new((math.random() - 0.5) * m * 2, (math.random() - 0.5) * m * 2, 0)
	end
	cam.CFrame = startCF:Lerp(target, e) * sway * shake
	kick = math.max(kick - dt * 9, 0)
	cam.FieldOfView = BASE_FOV - kick

	if #coins > 0 then
		stepCoins(dt)
	end
	if run.locked then
		return
	end
	local speed = SPEED_START + (SPEED_END - SPEED_START) * math.min(run.progress, 1)
	run.marker += run.dir * speed * dt
	if run.marker >= 1 then
		run.marker = 1
		run.dir = -1
	elseif run.marker <= 0 then
		run.marker = 0
		run.dir = 1
	end
	ui.marker.Position = UDim2.fromScale(run.marker, 0.5)
	local inside = math.abs(run.marker - run.zoneCenter) <= run.zoneWidth / 2
	ui.markerGlow.Transparency = if inside then 0 else 0.7
end

--------------------------------------------------------------------------------
-- build HUD + open
--------------------------------------------------------------------------------

local function label(parent: Instance, text: string, props: { [string]: any }): TextLabel
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(205, 214, 228),
		BorderSizePixel = 0,
	}, nil)
	for k, v in props do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function buildHud()
	local g = new("ScreenGui", {
		Name = "DigHud",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	hud = g

	-- one scaled box with a fixed shape: flat, square-edged and technical
	local root = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.965),
		Size = UDim2.fromScale(0.5, 0.2),
		BackgroundTransparency = 1,
	}, g)
	new("UIAspectRatioConstraint", { AspectRatio = 5.2, AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Width }, root)
	ui.root = root

	ui.hint = label(root, "Uncover the whole chest in as few taps as you can. Closer to the middle takes off more sand!", {
		Position = UDim2.fromScale(0, -0.2),
		Size = UDim2.fromScale(1, 0.17),
		TextColor3 = Color3.new(1, 1, 1),
	})
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2 }, ui.hint)

	-- dark strip behind the top row so the text reads over bright sand
	new("Frame", { Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.185), BackgroundColor3 = Color3.fromRGB(22, 24, 28), BackgroundTransparency = 0.12, BorderSizePixel = 0 }, root)
	ui.levelLabel = label(root, "DIG LV 1", { Position = UDim2.fromScale(0.01, 0.015), Size = UDim2.fromScale(0.2, 0.15), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 })
	ui.xpLabel = label(root, "0 / 12 XP", { Position = UDim2.fromScale(0.79, 0.015), Size = UDim2.fromScale(0.2, 0.15), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2 })
	ui.tapsLabel = label(root, "TAPS 0", { Position = UDim2.fromScale(0.3, 0.015), Size = UDim2.fromScale(0.2, 0.15), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.new(1, 1, 1), ZIndex = 2 })
	ui.paceLabel = label(root, "PERFECT", { Position = UDim2.fromScale(0.52, 0.015), Size = UDim2.fromScale(0.2, 0.15), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TIER_COLOR.Perfect, ZIndex = 2 })

	-- the timing strip: flat dark bar, a solid green zone, a thin marker
	local track = new("Frame", {
		Position = UDim2.fromScale(0, 0.2),
		Size = UDim2.fromScale(1, 0.4),
		BackgroundColor3 = Color3.fromRGB(26, 28, 32),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, root)
	new("UIStroke", { Color = Color3.fromRGB(10, 10, 12), Thickness = 2 }, track)
	ui.zone = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, track)
	new("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, ZONE_EDGE), ColorSequenceKeypoint.new(0.5, ZONE_CENTRE), ColorSequenceKeypoint.new(1, ZONE_EDGE) }),
	}, ui.zone)
	new("UIStroke", { Color = Color3.fromRGB(190, 255, 190), Thickness = 1, Transparency = 0.55 }, ui.zone)
	ui.marker = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.006, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, track)
	ui.markerGlow = new("UIStroke", { Color = Color3.fromRGB(190, 255, 190), Thickness = 2, Transparency = 0.8 }, ui.marker)

	-- how far down to the chest, under the strip: a slim green fill
	local bar = new("Frame", {
		Position = UDim2.fromScale(0, 0.62),
		Size = UDim2.fromScale(1, 0.11),
		BackgroundColor3 = Color3.fromRGB(14, 20, 14),
		BorderSizePixel = 0,
	}, root)
	new("UIStroke", { Color = Color3.fromRGB(10, 10, 12), Thickness = 2 }, bar)
	ui.barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, bar)
	new("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 255, 130)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(52, 170, 56)), ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 120, 42)) }),
		Rotation = 90,
	}, ui.barFill)
	new("Frame", { Position = UDim2.fromScale(0, 0.74), Size = UDim2.fromScale(1, 0.16), BackgroundColor3 = Color3.fromRGB(22, 24, 28), BackgroundTransparency = 0.12, BorderSizePixel = 0 }, root)
	label(root, "CHEST UNCOVERED", { Position = UDim2.fromScale(0.01, 0.755), Size = UDim2.fromScale(0.3, 0.13), TextXAlignment = Enum.TextXAlignment.Left, Font = Theme.FontLight, TextColor3 = Color3.fromRGB(200, 208, 220), ZIndex = 2 })

	-- leave: small, square, beside the strip
	local leave = new("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0.765, 0.965),
		Size = UDim2.fromScale(0.04, 0.04),
		BackgroundColor3 = Color3.fromRGB(26, 28, 32),
		Text = "X",
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(225, 228, 235),
		BorderSizePixel = 0,
		ZIndex = 30,
	}, g)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, leave)
	new("UIStroke", { Color = Color3.fromRGB(10, 10, 12), Thickness = 2 }, leave)
	ui.leave = leave
	leave.Activated:Connect(function()
		DigScreen.close()
	end)
end

-- the plot a prompt belongs to, or the nearest one (dev switch / no prompt)
local function findPlot(prompt: ProximityPrompt?): Model?
	if prompt then
		local m = prompt:FindFirstAncestorOfClass("Model")
		if m and m.PrimaryPart then
			return m
		end
	end
	local field = workspace:FindFirstChild("DigField")
	local plots = field and field:FindFirstChild("Plots")
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not plots or not hrp then
		return nil
	end
	local best, bestD: Model?, number = nil, math.huge
	for _, m in plots:GetChildren() do
		if m:IsA("Model") and m.PrimaryPart then
			local d = (m.PrimaryPart.Position - hrp.Position).Magnitude
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

function DigScreen.open(prompt: ProximityPrompt?)
	if active then
		return
	end
	local m = findPlot(prompt)
	if not m then
		return
	end
	plot, pit = m, m.PrimaryPart
	if hud == nil then
		buildHud()
		preloadSounds()
	end
	local status = Net.invoke("GetDigStatus")
	if status and status.ok then
		digXp = status.xp or 0
	end
	active = true
	ProximityPromptService.Enabled = false -- hide the E prompts while digging
	;(hud :: ScreenGui).Enabled = true
	local cam = workspace.CurrentCamera
	savedCamera = { type = cam.CameraType, fov = cam.FieldOfView }
	lockPlayer(true)
	setLookFx(true)
	aimCamera()
	startRun()
	conn = RunService.RenderStepped:Connect(step)
	-- tap anywhere (not on a button) or press Space to strike
	inputConn = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.Space then
			strike()
		end
	end)
end

function DigScreen.wire() end

return DigScreen
