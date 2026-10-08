--!strict
-- DigFieldService: builds the Relic Dig field in Workspace at boot, from
-- DigConfig. A raised sandy excavation yard with a grid of dig plots sunk into
-- it, a gate, lanterns, tents, crates and rocks. Everything here is STATIC and
-- shared; digging itself never touches it on the server (each player digs a
-- local copy on their own client, see client DigScreen), so any number of
-- players can use the same plot at the same time.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DigConfig = require(ReplicatedStorage.Shared.Config.DigConfig)

local DigFieldService = {}

local SAND_TOP = Color3.fromRGB(232, 204, 150)
local SAND_WALL = Color3.fromRGB(190, 150, 98)
local STONE = Color3.fromRGB(128, 118, 106)
local STONE_DARK = Color3.fromRGB(78, 68, 58)
local WOOD = Color3.fromRGB(122, 84, 52)
local WOOD_DARK = Color3.fromRGB(86, 58, 38)
local CLOTH = { Color3.fromRGB(196, 92, 64), Color3.fromRGB(226, 178, 84), Color3.fromRGB(86, 140, 150), Color3.fromRGB(150, 82, 132) }
local GOLD = Color3.fromRGB(255, 205, 90)

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function part(parent: Instance, props: { [string]: any }): Part
	local p = make("Part", {
		Anchored = true,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		CastShadow = true,
	}, nil)
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

--------------------------------------------------------------------------------
-- props
--------------------------------------------------------------------------------

local function lanternPost(parent: Folder, pos: Vector3, withLight: boolean)
	part(parent, { Name = "Post", Size = Vector3.new(0.4, 5.2, 0.4), Position = pos + Vector3.new(0, 2.6, 0), Color = WOOD, Material = Enum.Material.Wood })
	part(parent, { Name = "Arm", Size = Vector3.new(1.1, 0.25, 0.25), Position = pos + Vector3.new(0.5, 5, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, CanCollide = false })
	local cage = part(parent, { Name = "LanternCage", Size = Vector3.new(0.7, 0.9, 0.7), Position = pos + Vector3.new(1, 4.4, 0), Color = Color3.fromRGB(40, 36, 32), Material = Enum.Material.Metal, CanCollide = false })
	local bulb = part(parent, { Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.55, 0.55), Position = cage.Position, Color = Color3.fromRGB(255, 196, 110), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	if withLight then
		make("PointLight", { Color = Color3.fromRGB(255, 190, 110), Range = 20, Brightness = 0.9, Shadows = false }, bulb)
	end
end

local function crate(parent: Folder, pos: Vector3, size: number, yaw: number)
	local cf = CFrame.new(pos + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, math.rad(yaw), 0)
	part(parent, { Name = "Crate", Size = Vector3.one * size, CFrame = cf, Color = Color3.fromRGB(150, 108, 66), Material = Enum.Material.WoodPlanks })
	for _, off in { -size * 0.34, size * 0.34 } do
		part(parent, { Name = "CrateBand", Size = Vector3.new(size * 1.04, size * 0.12, size * 1.04), CFrame = cf * CFrame.new(0, off, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, CanCollide = false })
	end
end

local function barrel(parent: Folder, pos: Vector3)
	part(parent, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 1.7, 1.7), CFrame = CFrame.new(pos + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(128, 88, 54), Material = Enum.Material.Wood })
	for _, off in { -0.65, 0.65 } do
		part(parent, { Name = "Hoop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 1.78, 1.78), CFrame = CFrame.new(pos + Vector3.new(0, 1.1 + off, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 56, 52), Material = Enum.Material.Metal, CanCollide = false })
	end
end

local function shovel(parent: Folder, pos: Vector3, lean: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(lean * 40), math.rad(lean * 8))
	part(parent, { Name = "ShovelHandle", Size = Vector3.new(0.18, 3.4, 0.18), CFrame = cf * CFrame.new(0, 1.5, 0), Color = WOOD, Material = Enum.Material.Wood, CanCollide = false })
	part(parent, { Name = "ShovelBlade", Size = Vector3.new(0.7, 0.9, 0.1), CFrame = cf * CFrame.new(0, 0.1, 0), Color = Color3.fromRGB(150, 156, 164), Material = Enum.Material.Metal, CanCollide = false })
end

local function rock(parent: Folder, pos: Vector3, s: number, seed: number)
	part(parent, {
		Name = "Rock",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(s * 1.4, s, s * 1.15),
		CFrame = CFrame.new(pos + Vector3.new(0, s * 0.25, 0)) * CFrame.Angles(seed, seed * 1.7, 0),
		Color = Color3.fromRGB(150 + (seed * 17) % 18, 132 + (seed * 11) % 14, 112),
		Material = Enum.Material.Slate,
	})
end

local function flag(parent: Folder, pos: Vector3, color: Color3)
	part(parent, { Name = "FlagPole", Size = Vector3.new(0.22, 8, 0.22), Position = pos + Vector3.new(0, 4, 0), Color = WOOD, Material = Enum.Material.Wood })
	part(parent, { Name = "Flag", Size = Vector3.new(0.08, 2, 3.2), Position = pos + Vector3.new(0, 6.9, 1.7), Color = color, Material = Enum.Material.Fabric, CanCollide = false })
	part(parent, { Name = "FlagTrim", Size = Vector3.new(0.1, 0.25, 3.2), Position = pos + Vector3.new(0, 5.95, 1.7), Color = GOLD, Material = Enum.Material.Fabric, CanCollide = false })
end

local function tent(parent: Folder, pos: Vector3, yaw: number, color: Color3)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0)
	for _, side in { -1, 1 } do
		part(parent, { Name = "TentCloth", Size = Vector3.new(6, 0.18, 4.2), CFrame = cf * CFrame.new(0, 2.15, side * 1.6) * CFrame.Angles(math.rad(side * 40), 0, 0), Color = color, Material = Enum.Material.Fabric })
	end
	for _, x in { -3, 3 } do
		part(parent, { Name = "TentPole", Size = Vector3.new(0.25, 4.4, 0.25), CFrame = cf * CFrame.new(x, 2.2, 0), Color = WOOD_DARK, Material = Enum.Material.Wood })
	end
	part(parent, { Name = "TentRidge", Size = Vector3.new(6.3, 0.25, 0.25), CFrame = cf * CFrame.new(0, 4.3, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, CanCollide = false })
end

--------------------------------------------------------------------------------
-- ground with holes for the plots
--------------------------------------------------------------------------------

local function buildGround(root: Folder, hx0: { number }, hx1: { number }, hz0: { number }, hz1: { number }, X0: number, X1: number, Z0: number, Z1: number)
	local S = DigConfig.Site
	local H = S.groundH
	local ground = make("Folder", { Name = "Ground" }, root)
	local function slab(x0: number, x1: number, z0: number, z1: number)
		if x1 - x0 < 0.01 or z1 - z0 < 0.01 then
			return
		end
		part(ground, {
			Name = "Ground",
			Size = Vector3.new(x1 - x0, H, z1 - z0),
			Position = Vector3.new((x0 + x1) / 2, H / 2, (z0 + z1) / 2),
			Color = SAND_TOP,
			Material = Enum.Material.Sand,
		})
	end
	local cursorZ = Z0
	for j = 1, #hz0 do
		slab(X0, X1, cursorZ, hz0[j]) -- band before this row of plots
		local cursorX = X0
		for i = 1, #hx0 do
			slab(cursorX, hx0[i], hz0[j], hz1[j])
			cursorX = hx1[i]
		end
		slab(cursorX, X1, hz0[j], hz1[j])
		cursorZ = hz1[j]
	end
	slab(X0, X1, cursorZ, Z1)

	-- ramps up onto the field, all four sides
	local R = DigConfig.Field.ramp
	local len = math.sqrt(R * R + H * H)
	local function ramp(cx: number, cz: number, width: number, dirX: number, dirZ: number)
		local mid = Vector3.new(cx + dirX * R / 2, H / 2 - 0.22, cz + dirZ * R / 2)
		local down = Vector3.new(dirX * R, -H, dirZ * R)
		-- a thin slab whose length runs down the slope (lookAt aims its Z axis)
		part(ground, { Name = "Ramp", Size = Vector3.new(width, 0.5, len), CFrame = CFrame.lookAt(mid, mid + down), Color = SAND_TOP, Material = Enum.Material.Sand })
	end
	local cx, cz = (X0 + X1) / 2, (Z0 + Z1) / 2
	ramp(cx, Z1, X1 - X0, 0, 1)
	ramp(cx, Z0, X1 - X0, 0, -1)
	ramp(X1, cz, Z1 - Z0, 1, 0)
	ramp(X0, cz, Z1 - Z0, -1, 0)
end

--------------------------------------------------------------------------------
-- one plot
--------------------------------------------------------------------------------

local function buildPlot(parent: Folder, index: number, centre: Vector3)
	local S = DigConfig.Site
	local W, D = S.cols * S.tile, S.rows * S.tile
	local model = make("Model", { Name = "DigPlot" .. index }, parent)
	model:SetAttribute("PlotIndex", index)

	-- pit floor: dark stone slab on the baseplate
	local pit = part(model, {
		Name = "Pit",
		Size = Vector3.new(W, S.floorH, D),
		Position = centre + Vector3.new(0, S.floorH / 2, 0),
		Color = STONE_DARK,
		Material = Enum.Material.Slate,
	})
	model.PrimaryPart = pit

	-- the sand: a few stacked layers, no gaps, flush with the ground. Digging
	-- lowers them top first (client side only).
	local layers = make("Folder", { Name = "Layers" }, model)
	local count = #S.layers
	local lh = DigConfig.blockH() / count
	for i, color in S.layers do
		part(layers, {
			Name = "Layer" .. i,
			Size = Vector3.new(W, lh, D),
			Position = centre + Vector3.new(0, S.floorH + (i - 0.5) * lh, 0),
			Color = color,
			Material = Enum.Material.Sand,
			CastShadow = false,
		})
	end

	-- stone trim framing the hole, standing a hair above the ground
	local top = S.groundH + 0.07
	local t = 0.45
	local function trim(sx: number, sz2: number, ox: number, oz: number)
		part(model, { Name = "Trim", Size = Vector3.new(sx, 0.14, sz2), Position = centre + Vector3.new(ox, top, oz), Color = STONE, Material = Enum.Material.Cobblestone, CastShadow = false })
	end
	trim(W + t * 2, t, 0, -(D / 2 + t / 2))
	trim(W + t * 2, t, 0, D / 2 + t / 2)
	trim(t, D, -(W / 2 + t / 2), 0)
	trim(t, D, W / 2 + t / 2, 0)

	-- corner stakes with a little cap, so the plot reads as an excavation square
	for _, sx in { -1, 1 } do
		for _, sz2 in { -1, 1 } do
			part(model, { Name = "Stake", Size = Vector3.new(0.3, 1.1, 0.3), Position = centre + Vector3.new(sx * (W / 2 + t), S.groundH + 0.55, sz2 * (D / 2 + t)), Color = WOOD, Material = Enum.Material.Wood })
		end
	end

	-- the prompt: invisible anchor above the middle of the plot
	local anchor = part(model, {
		Name = "PromptAnchor",
		Size = Vector3.new(1, 1, 1),
		Position = centre + Vector3.new(0, S.groundH + 0.9, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	make("ProximityPrompt", {
		Name = DigConfig.PromptName,
		ActionText = "Dig",
		ObjectText = "Relic Dig Plot " .. index,
		HoldDuration = 0,
		MaxActivationDistance = 15,
		RequiresLineOfSight = false,
		Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton,
	}, anchor)

	-- plot number floating above
	local bb = make("BillboardGui", {
		Size = UDim2.fromOffset(46, 46),
		StudsOffset = Vector3.new(0, 2.4, 0),
		AlwaysOnTop = false,
		MaxDistance = 70,
	}, anchor)
	local label = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = tostring(index),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = GOLD,
	}, bb)
	make("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0) }, label)
end

--------------------------------------------------------------------------------
-- field
--------------------------------------------------------------------------------

function DigFieldService.build()
	local S, F = DigConfig.Site, DigConfig.Field
	-- replace anything a previous manual version of the site left behind
	for _, name in { "DigField", "DigSite" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local root = make("Folder", { Name = "DigField" }, nil)
	local W, D = S.cols * S.tile, S.rows * S.tile
	local strideX, strideZ = W + F.gapX, D + F.gapZ

	-- ground slabs leave a hole for every plot
	local hx0, hx1, hz0, hz1 = {}, {}, {}, {}
	for i = 1, F.plotsX do
		local c = DigConfig.plotCenter(i, 1)
		hx0[i], hx1[i] = c.X - W / 2, c.X + W / 2
	end
	for j = 1, F.plotsZ do
		local c = DigConfig.plotCenter(1, j)
		hz0[j], hz1[j] = c.Z - D / 2, c.Z + D / 2
	end
	local X0, X1 = hx0[1] - F.margin, hx1[F.plotsX] + F.margin
	local Z0, Z1 = hz0[1] - F.margin, hz1[F.plotsZ] + F.margin
	buildGround(root, hx0, hx1, hz0, hz1, X0, X1, Z0, Z1)

	local plots = make("Folder", { Name = "Plots" }, root)
	local index = 0
	for j = 1, F.plotsZ do
		for i = 1, F.plotsX do
			index += 1
			buildPlot(plots, index, DigConfig.plotCenter(i, j))
		end
		task.wait() -- spread the instance creation over frames
	end

	-- dressing: lanterns at the walkway crossings and corners, props around the edge
	local props = make("Folder", { Name = "Props" }, root)
	local gy = S.groundH
	for i = 0, F.plotsX do
		for j = 0, F.plotsZ do
			local x = if i == 0 then X0 + 2 elseif i == F.plotsX then X1 - 2 else hx1[i] + F.gapX / 2
			local z = if j == 0 then Z0 + 2 elseif j == F.plotsZ then Z1 - 2 else hz1[j] + F.gapZ / 2
			local interior = i > 0 and i < F.plotsX and j > 0 and j < F.plotsZ
			local corner = (i == 0 or i == F.plotsX) and (j == 0 or j == F.plotsZ)
			if interior or corner then
				lanternPost(props, Vector3.new(x, gy, z), true)
			end
		end
	end

	local rng = Random.new(1337)
	for k = 1, 4 do -- tents along the back
		local x = X0 + (X1 - X0) * (k - 0.5) / 4
		tent(props, Vector3.new(x, gy, Z0 + 3.6), 0, CLOTH[(k - 1) % #CLOTH + 1])
		crate(props, Vector3.new(x + 4.2, gy, Z0 + 2.4), 1.8, rng:NextNumber(-30, 30))
		barrel(props, Vector3.new(x - 4.4, gy, Z0 + 2.8))
	end
	for k = 1, 5 do -- flags along the front edge
		flag(props, Vector3.new(X0 + (X1 - X0) * (k - 0.5) / 5, gy, Z1 - 1.2), CLOTH[(k - 1) % #CLOTH + 1])
	end
	for _ = 1, 26 do -- rocks, crates, shovels dotted around the walkways
		local x = rng:NextNumber(X0 + 2, X1 - 2)
		local z = rng:NextNumber(Z0 + 2, Z1 - 2)
		local onPlot = false
		for i = 1, F.plotsX do
			for j = 1, F.plotsZ do
				if x > hx0[i] - 1.5 and x < hx1[i] + 1.5 and z > hz0[j] - 1.5 and z < hz1[j] + 1.5 then
					onPlot = true
				end
			end
		end
		if not onPlot then
			local pick = rng:NextInteger(1, 3)
			if pick == 1 then
				rock(props, Vector3.new(x, gy, z), rng:NextNumber(0.8, 1.8), rng:NextNumber(0, 6))
			elseif pick == 2 then
				crate(props, Vector3.new(x, gy, z), rng:NextNumber(1.2, 1.7), rng:NextNumber(0, 90))
			else
				shovel(props, Vector3.new(x, gy - 0.1, z), rng:NextNumber(-1, 1))
			end
		end
	end

	-- entrance gate on the front, where the ramp meets the baseplate
	local gateZ = Z1 + F.ramp + 1.5
	local gx = (X0 + X1) / 2
	local gate = make("Folder", { Name = "Gate" }, root)
	for _, side in { -1, 1 } do
		part(gate, { Name = "GatePost", Size = Vector3.new(1.1, 11, 1.1), Position = Vector3.new(gx + side * 7.5, 5.5, gateZ), Color = WOOD, Material = Enum.Material.Wood })
		part(gate, { Name = "GateFoot", Size = Vector3.new(2, 0.8, 2), Position = Vector3.new(gx + side * 7.5, 0.4, gateZ), Color = STONE, Material = Enum.Material.Cobblestone })
	end
	part(gate, { Name = "GateBeam", Size = Vector3.new(17, 1.2, 1.3), Position = Vector3.new(gx, 11, gateZ), Color = WOOD_DARK, Material = Enum.Material.Wood })
	local board = part(gate, { Name = "GateSign", Size = Vector3.new(11, 3.2, 0.5), Position = Vector3.new(gx, 8.7, gateZ), Color = Color3.fromRGB(70, 48, 34), Material = Enum.Material.Wood })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = make("SurfaceGui", { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 60 }, board)
		local title = make("TextLabel", {
			Size = UDim2.fromScale(1, 0.62),
			BackgroundTransparency = 1,
			Text = "RELIC DIG SITE",
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			TextColor3 = GOLD,
		}, sg)
		make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(40, 24, 12) }, title)
		make("TextLabel", {
			Position = UDim2.fromScale(0, 0.6),
			Size = UDim2.fromScale(1, 0.34),
			BackgroundTransparency = 1,
			Text = "Dig up treasure. Find rare relics!",
			Font = Enum.Font.GothamMedium,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(240, 226, 196),
		}, sg)
	end
	for _, side in { -1, 1 } do
		part(gate, { Name = "Chain", Size = Vector3.new(0.12, 1.4, 0.12), Position = Vector3.new(gx + side * 5, 10, gateZ), Color = Color3.fromRGB(60, 56, 52), Material = Enum.Material.Metal, CanCollide = false })
	end
	lanternPost(gate, Vector3.new(gx - 9, 0, gateZ), true)
	lanternPost(gate, Vector3.new(gx + 9, 0, gateZ), true)

	-- drifting dust motes over the whole yard
	local motes = part(root, {
		Name = "DustMotes",
		Size = Vector3.new(X1 - X0, 6, Z1 - Z0),
		Position = Vector3.new((X0 + X1) / 2, gy + 4, (Z0 + Z1) / 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 232, 180)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(5, 8),
		Rate = 6,
		Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.6,
		Shape = Enum.ParticleEmitterShape.Box,
	}, motes)

	root.Parent = Workspace
end

function DigFieldService.Init() end

function DigFieldService.Start()
	task.spawn(DigFieldService.build)
end

return DigFieldService
