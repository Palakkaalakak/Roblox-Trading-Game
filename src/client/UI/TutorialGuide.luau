--!strict
-- TutorialGuide: attention cue pointing the player at the Crafts NPC
-- (Workspace model "CrafterNPC", formerly "EventNPC" -- the name is a
-- manual Studio job the user does separately; this reads the name as a
-- constant so the rename is a one-line change here too).
--
-- Two interchangeable styles, flip STYLE below to compare in Studio:
--   "billboard" -- Highlight (AlwaysOnTop, renders through walls) + a
--                  pulsing BillboardGui arrow above the NPC's head.
--   "compass"   -- a 2D screen-space arrow that rotates to always point
--                  from the player toward the NPC, like a quest compass.
-- Both are genuinely through-wall: Highlight's DepthMode does that natively
-- for 3D, and the compass arrow is pure screen-space UI so occlusion never
-- applies to it at all.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TutorialGuide = {}

-- Readable by other screens (EventsScreen) to know whether to also point at
-- the Unique Crafts tab/button once the player gets there -- this module owns
-- "is the tutorial still on," everyone else just reads it.
TutorialGuide.active = false
-- Fires when the tutorial ends, so screens can drop their own pointers.
local stoppedEvent = Instance.new("BindableEvent")
TutorialGuide.Stopped = stoppedEvent.Event

local NPC_NAME = "CrafterNPC"
local STYLE: "billboard" | "compass" = "billboard" -- flip this to "compass" to compare

local ARROW_COLOR = Color3.fromRGB(63, 232, 95) -- matches the takeover's green accent

local function findNpc(): Model?
	return Workspace:FindFirstChild(NPC_NAME) :: Model?
end

local function npcAnchor(npc: Model): BasePart?
	return npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")
end

-- Style A: Highlight + pulsing billboard arrow directly over the NPC.
local function startBillboard(npc: Model, anchor: BasePart): () -> ()
	local highlight = Instance.new("Highlight")
	highlight.Name = "TutorialHighlight"
	highlight.FillColor = ARROW_COLOR
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = ARROW_COLOR
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- renders through walls
	highlight.Parent = npc

	-- A BillboardGui unconditionally faces the camera -- that's what
	-- "billboard" means, and Roblox exposes no way to lock it. Circling the
	-- NPC therefore visibly reorients it, which read as "rotating around the
	-- NPC." Fix: paint the same glyph onto a SurfaceGui on a real, invisible,
	-- fixed-orientation Part instead -- genuinely stationary in world space,
	-- facing whichever way the NPC itself faces (same as its "EVENTS" sign).
	local markerPart = Instance.new("Part")
	markerPart.Name = "TutorialMarkerPart"
	markerPart.Anchored = true
	markerPart.CanCollide = false
	markerPart.CanQuery = false
	markerPart.CanTouch = false
	markerPart.Transparency = 1
	-- World-space size, not pixel resolution, is what sets apparent size on
	-- screen -- SurfaceGui's CanvasSize/FixedSize only controls glyph crispness
	-- within this footprint. 2.6 studs read as a speck from normal walk-up
	-- distance; the guide needs to read from across the plaza.
	markerPart.Size = Vector3.new(12, 12, 0.2)
	markerPart.CFrame = anchor.CFrame + Vector3.new(0, 8, 0)
	markerPart.Parent = workspace

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "TutorialArrow"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.AlwaysOnTop = true -- through walls, same as Highlight
	surfaceGui.LightInfluence = 0
	-- Default SurfaceGui canvas is tiny (32px/stud * 2.6-stud part = ~83px),
	-- so the glyph rendered as a speck. Fix canvas size directly instead of
	-- deriving from part size, decoupling glyph scale from the part's bulk.
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize = Vector2.new(200, 200)
	surfaceGui.MaxDistance = 0 -- 0 = unlimited (Roblox convention), but pin it explicitly rather than trust the instance default
	surfaceGui.Parent = markerPart

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = "▼"
	-- TextScaled against a FixedSize SurfaceGui canvas rendered a near-invisible
	-- 8px glyph on a 200px canvas instead of filling it -- the two features
	-- don't compose the way they do on a ScreenGui. Pin an explicit size
	-- instead of trusting TextScaled to fill the canvas here.
	arrow.TextScaled = false
	arrow.TextSize = 160
	arrow.TextColor3 = Color3.fromRGB(255, 215, 60) -- gold, not the highlight's green -- must not blend in
	arrow.TextStrokeTransparency = 0 -- default black stroke -- legible against sky or green alike
	arrow.TextStrokeColor3 = Color3.new(0, 0, 0)
	arrow.Parent = surfaceGui

	-- Bob up and down (Position only) -- no rotation, so no reorientation
	-- feedback as the player moves, just a gentle vertical pulse for attention.
	local baseCFrame = markerPart.CFrame
	local pulse = TweenService:Create(
		markerPart,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = baseCFrame + Vector3.new(0, 1.6, 0) }
	)
	pulse:Play()

	return function()
		pulse:Cancel()
		highlight:Destroy()
		markerPart:Destroy()
	end
end

-- Style B: screen-space compass arrow that rotates toward the NPC's
-- direction every frame. Pure 2D UI -- never occluded, no matter what's
-- between the player and the NPC.
local function startCompass(anchor: BasePart): () -> ()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialCompassGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 90
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Text-glyph arrow, not an image asset -- see startBillboard's comment:
	-- the placeholder icon reads as a barely-visible speck regardless of
	-- container size. A glyph stays crisp and legible at any scale.
	local arrow = Instance.new("TextLabel")
	arrow.Name = "CompassArrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(64, 64)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = "▲"
	arrow.TextScaled = true
	arrow.TextColor3 = ARROW_COLOR
	arrow.TextStrokeTransparency = 0
	arrow.TextStrokeColor3 = Color3.new(0, 0, 0)
	arrow.Parent = gui

	local conn = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local character = player.Character
		if not (camera and character) then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end

		-- Flatten to the camera's horizontal plane so the arrow only ever
		-- shows heading, not pitch -- pointing "through the floor" would be
		-- meaningless on a screen-space compass.
		local toNpc = (anchor.Position - root.Position)
		toNpc = Vector3.new(toNpc.X, 0, toNpc.Z)
		if toNpc.Magnitude < 0.01 then
			return
		end
		local camLook = camera.CFrame.LookVector
		camLook = Vector3.new(camLook.X, 0, camLook.Z)
		if camLook.Magnitude < 0.01 then
			return
		end

		local angle = math.atan2(toNpc.X, toNpc.Z) - math.atan2(camLook.X, camLook.Z)
		arrow.Rotation = math.deg(angle)
	end)

	return function()
		conn:Disconnect()
		gui:Destroy()
	end
end

local stop: (() -> ())? = nil

-- Starts the cue and returns a stop() function. Caller decides when it's
-- done (tutorial-craft completed) -- this module only draws the cue, it
-- doesn't know what "done" means.
function TutorialGuide.start()
	TutorialGuide.stop()
	local npc = findNpc()
	if npc == nil then
		return
	end
	local anchor = npcAnchor(npc)
	if anchor == nil then
		return
	end
	stop = (STYLE == "billboard") and startBillboard(npc, anchor) or startCompass(anchor)
	TutorialGuide.active = true
end

function TutorialGuide.stop()
	if stop then
		stop()
		stop = nil
	end
	local was = TutorialGuide.active
	TutorialGuide.active = false
	if was then
		stoppedEvent:Fire()
	end
end

return TutorialGuide
