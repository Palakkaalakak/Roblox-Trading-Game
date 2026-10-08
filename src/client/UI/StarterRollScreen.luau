--!strict
-- StarterRollScreen: the first-join welcome + starter-roll reveal takeover.
--
-- Nothing here decides WHAT a player gets — StarterService already rolled and
-- granted the items server-side, before this screen ever opens (see
-- StarterService.buildReveal). This is purely a REPLAY of an already-final
-- result: the reel spin is cosmetic, not a source of randomness, so there is
-- nothing to leave-scum by closing early. Un-closable and un-skippable is a
-- product choice (hook design), not an anti-cheat one.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Net = require(script.Parent.Parent.Net)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local TutorialGuide = require(script.Parent.TutorialGuide)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local StarterRollScreen = {}

local SCROLL_TIME = 4.2 -- longer than the main Rolls panel on purpose: dopamine peaks
-- DURING anticipation, not at reveal (loot-box design literature) -- N bands running
-- at once already reads as busy, so the per-band time can sit near the top of the
-- useful anticipation window (~3-5s) without the whole sequence feeling padded.
-- LUCKY's own banner (showVariantCallout, below) is a SEPARATE phase before this
-- and is not roll/spin time -- its own duration is tuned independently.
local WINNER_INDEX = 18
local TRAILING = 3
local MAX_BANDS = 6 -- mirrors GuiBuilder.STARTER_MAX_ITEMS
local BAND_GAP_PX = 14
local MAX_BAND_PX = 200 -- the normal Rolls-NPC reel's own max height (RollsPanel MaxSize
-- 960x660, reel = 0.36 of that = ~238px) -- a low item count must NOT grow bands past
-- this just because a full-screen holder happens to have the room
local SUPER_PURPLE = Color3.fromRGB(186, 104, 200)
local MULTI_GOLD = Color3.fromRGB(253, 179, 30)
local NEUTRAL_STROKE = Color3.fromRGB(70, 74, 90)
local MARKER_PAD = 10 -- px of border around the tile the marker frames

function StarterRollScreen.wire(gui: ScreenGui, toast: (text: string, color: Color3) -> ())
	local root = gui:WaitForChild("Root") :: Frame
	local welcome = root:WaitForChild("Welcome") :: Frame
	local welcomeStack = welcome:WaitForChild("Stack") :: Frame
	local rollBtn = (welcomeStack:WaitForChild("RollButtonHolder") :: Frame):WaitForChild(
		"RollButton"
	) :: TextButton
	local rolling = root:WaitForChild("Rolling") :: Frame
	local bandsHolder = rolling:WaitForChild("Bands") :: Frame
	local variantState = root:WaitForChild("Variant") :: Frame
	local callout = variantState:WaitForChild("Callout") :: Frame
	local calloutTitle = callout:WaitForChild("Title") :: TextLabel
	local calloutSub = callout:WaitForChild("Subtitle") :: TextLabel
	local calloutStroke = callout:FindFirstChildOfClass("UIStroke") :: UIStroke
	local revealState = root:WaitForChild("Reveal") :: Frame
	local revealStack = revealState:WaitForChild("Stack") :: Frame
	local itemsGrid = revealStack:WaitForChild("ItemsGrid") :: Frame
	local cardTemplate = itemsGrid:WaitForChild("ItemTile") :: Frame
	local worthLine = (revealStack:WaitForChild("WorthBox") :: Frame):WaitForChild("WorthLine") :: TextLabel
	local continueBtn = (revealStack:WaitForChild("ContinueHolder") :: Frame):WaitForChild(
		"ContinueButton"
	) :: TextButton
	local flash = root:WaitForChild("Flash") :: Frame

	local pending: any = nil
	local generation = 0 -- bumped by activate(); guards deferred timers against a stale re-arm

	local function showOnly(state: Frame?)
		for _, child in root:GetChildren() do
			if child:IsA("Frame") and child ~= flash then
				child.Visible = (child == state)
			end
		end
	end

	-- Spin one band's strip so it lands on `item`, offset by `delay` seconds
	-- and a slightly different duration so the bands don't land in lockstep —
	-- "different offsets so it looks more random" per the design brief.
	local function spinBand(band: Frame, item: any, fillerPool: { any }, delay: number, duration: number)
		local strip = band:WaitForChild("Strip") :: Frame
		local tileTemplate = strip:WaitForChild("ReelTile") :: ImageLabel
		local marker = band:WaitForChild("CenterMarker") :: Frame
		local markerGlow = marker:FindFirstChild("Glow") :: UIStroke?

		for _, child in strip:GetChildren() do
			if child:IsA("ImageLabel") and child ~= tileTemplate then
				child:Destroy()
			end
		end
		strip.Position = UDim2.fromScale(0, 0.5)

		task.spawn(function()
			-- Always yield at least one frame: layoutBands has just resized this
			-- band, and AbsoluteSize does not reflect that until the next layout
			-- pass. Measuring first would build the strip against the old height.
			task.wait(delay)
			if band.Parent == nil then
				return
			end

			local bandH = band.AbsoluteSize.Y
			local tileW = bandH * 0.86
			local stride = tileW * 1.14
			local bandW = band.AbsoluteSize.X

			-- Extra buffer tiles before 0 and after TRAILING: tile positions are
			-- absolute (i*stride), so this is the only change needed to stop the
			-- strip's true start/end edges from ever being visible -- without it
			-- tile 0 sits centered at t=0 (a visible "start") and nothing exists
			-- past the last trailing tile (a visible "end" right after landing).
			local LEAD = 8
			local lastIndex = WINNER_INDEX + TRAILING
			for i = -LEAD, lastIndex + LEAD do
				local tile = tileTemplate:Clone()
				tile.Visible = true
				tile.Position = UDim2.new(0, i * stride, 0.5, 0)
				tile.Size = UDim2.fromOffset(tileW, tileW)
				local entry
				if i == WINNER_INDEX then
					entry = item
				elseif #fillerPool > 0 then
					entry = fillerPool[math.random(1, #fillerPool)]
				else
					entry = item
				end
				Components.setIcon(tile, entry)
				local nameLabel = tile:FindFirstChild("ReelName", true)
				if nameLabel then
					nameLabel.Text = (entry and entry.name) or ""
					nameLabel.TextColor3 = Components.rarityColor(entry and entry.rarity)
				end
				tile.Parent = strip
			end

			if markerGlow then
				markerGlow.Color = Theme.Warn
				markerGlow.Transparency = 0.35
			end

			-- Marker sized directly off the ACTUAL tile size (+ fixed padding),
			-- not an independently-guessed fraction of band height -- that drift
			-- is exactly what left a loose, uneven gap around the winning tile.
			marker.Size = UDim2.fromOffset(tileW + MARKER_PAD, tileW + MARKER_PAD)

			local startX = bandW / 2 - tileW / 2
			local targetX = bandW / 2 - (WINNER_INDEX * stride + tileW / 2)
			strip.Position = UDim2.new(0, startX, 0.5, 0)

			-- ONE continuous tween, not two stitched together: a Linear-cruise
			-- then a Quint/Out-snap has a real velocity discontinuity at the
			-- join (Quint/Out's INITIAL speed is higher than the cruise's
			-- constant speed, so motion visibly speeds up right before it
			-- decelerates -- "slow, then fast, then slow"). Still want it snappy
			-- though, not gentle -- Quint's t^5 curve is basically stationary for
			-- over a second at this duration (too long a dead crawl); Quart is
			-- one power lower, still a firm decisive stop, much shorter crawl.
			local tween = TweenService:Create(
				strip,
				TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0, targetX, 0.5, 0) }
			)
			tween:Play()
			task.wait(duration)
			if band.Parent and markerGlow then
				markerGlow.Color = Components.rarityColor(item.rarity)
				markerGlow.Transparency = 0.1
			end
		end)
	end

	-- Stack only the bands this bundle actually needs, filling the holder --
	-- but capped at MAX_BAND_PX each: a 3-item super-roll gets three bands
	-- sized like the normal Rolls-NPC reel, not three bands ballooned up to
	-- fill a full-screen holder just because there's room. When the capped
	-- stack is shorter than the holder, it's centered rather than pinned top.
	-- Also colors each band's own outer stroke per variant -- purple for a
	-- super-roll, the game's normal neutral stroke otherwise -- per the design
	-- brief ("colours the outline of their roll strips purple").
	local function layoutBands(count: number, isSuper: boolean): { Frame }
		local shown = math.clamp(count, 1, MAX_BANDS)
		local holderH = bandsHolder.AbsoluteSize.Y
		local rawHeight = (holderH - BAND_GAP_PX * (shown - 1)) / shown
		local bandH = math.min(rawHeight, MAX_BAND_PX)
		local totalH = bandH * shown + BAND_GAP_PX * (shown - 1)
		local topOffset = (holderH - totalH) / 2
		local strokeColor = isSuper and SUPER_PURPLE or NEUTRAL_STROKE

		local bands: { Frame } = {}
		for i = 1, MAX_BANDS do
			local band = bandsHolder:FindFirstChild("Reel" .. tostring(i)) :: Frame?
			if band then
				band.Visible = i <= shown
				if band.Visible then
					band.Size = UDim2.new(1, 0, 0, bandH)
					band.Position = UDim2.new(0.5, 0, 0, topOffset + (i - 1) * (bandH + BAND_GAP_PX))
					local outerStroke = band:FindFirstChildOfClass("UIStroke")
					if outerStroke then
						outerStroke.Color = strokeColor
						outerStroke.Thickness = isSuper and 3 or 1
					end
					table.insert(bands, band)
				end
			end
		end
		return bands
	end

	-- Shown BEFORE the spin, so the player learns the roll is lucky before
	-- watching it happen. The reel bands are NOT on screen for this -- showing
	-- them frozen behind the banner reads as a stall, not a callout. This is
	-- its own full screen (Variant is the only Visible child of Root), same as
	-- Welcome or Reveal.
	--
	-- `myGen` guards the deferred continuation: if the takeover gets re-armed
	-- (activate() called again -- debug re-trigger, a second GetStarterReveal
	-- reconcile) while this 1.5s timer is still pending, the stale timer must
	-- NOT fire and stomp whatever the new arm is showing. Checking
	-- variantState.Visible alone isn't enough -- a coincidentally-matching
	-- visibility state from the NEW arm would let the stale callback through
	-- anyway. This was a real bug: click Roll, see LUCKY, then get thrown back
	-- to Welcome when a stale timer fired.
	local function showVariantCallout(isSuper: boolean, myGen: number, onDone: () -> ())
		calloutSub.Text = isSuper and "YOU GOT A SUPER-ROLL" or "YOU GOT A MULTIROLL"
		calloutTitle.TextColor3 = isSuper and SUPER_PURPLE or MULTI_GOLD
		calloutStroke.Color = isSuper and SUPER_PURPLE or NEUTRAL_STROKE
		showOnly(variantState)

		-- popIn: overshoot slightly, settle. Back/Out on a scale tween is the
		-- closest thing to the design's keyframed pop.
		local target = callout.Size
		callout.Size = UDim2.new(target.X.Scale, math.floor(target.X.Offset * 0.8), target.Y.Scale, math.floor(target.Y.Offset * 0.8))
		TweenService:Create(
			callout,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = target }
		):Play()

		task.delay(1.125, function() -- LUCKY banner hold, cut 25% per feedback
			if generation == myGen and variantState.Visible then
				onDone()
			end
		end)
	end

	-- Exactly the InventoryScreen pattern (InventoryScreen.luau:50): a card per
	-- item, filled by the SAME Components.fillItemTile every other ItemTile in
	-- the game uses -- Est. Value / Store Cost / RAP included, not hidden. A
	-- fresh roll has no trade history yet, so RAP legitimately reads "N/A"
	-- until the item has actually traded -- the same "N/A" any other
	-- untraded item shows, not a bug to paper over.
	--
	-- EconomyController.ensure is fired in activate(), as soon as the reveal
	-- payload arrives -- by the time the spin animation finishes (several
	-- seconds later) the real snapshot has almost always already landed.
	local function populateReveal(result: any)
		for _, child in itemsGrid:GetChildren() do
			if child:IsA("Frame") and child ~= cardTemplate then
				child:Destroy()
			end
		end
		for i, item in result.items do
			local card = cardTemplate:Clone()
			card.Name = "card_" .. tostring(i)
			card.Visible = true
			card.LayoutOrder = i
			local snapshot = EconomyController.get(item.itemId) or item
			Components.fillItemTile(card, snapshot, item.count)
			card.Parent = itemsGrid
		end
		worthLine.Text = ("≈%s ROBUX"):format(Format.comma(math.floor(result.worthRobux)))
		showOnly(revealState)
	end

	-- Rolling -> Reveal is a flash-cut, not a hard jump: pop the mask
	-- near-opaque, swap the state frame underneath while hidden behind it,
	-- then fade the mask out -- same beat the normal Rolls-NPC reveal uses.
	local function cutToReveal(result: any)
		flash.BackgroundTransparency = 0.08
		populateReveal(result)
		TweenService:Create(
			flash,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		):Play()
	end

	local function spinAll(result: any, isSuper: boolean, myGen: number)
		showOnly(rolling)
		local bandFrames = layoutBands(#result.items, isSuper)

		local maxFinish = 0
		for i, band in bandFrames do
			local item = result.items[i]
			local delay = (i - 1) * 0.22
			local duration = SCROLL_TIME + (i % 3) * 0.25 -- staggered, not identical
			spinBand(band, item, result.items, delay, duration)
			maxFinish = math.max(maxFinish, delay + duration)
		end

		-- Extra pause after the last band settles (beyond the 0.45s landing
		-- buffer) so the player actually registers the landed items before
		-- the cut, instead of the reveal snapping in the instant spinning stops.
		task.delay(maxFinish + 0.9, function()
			if generation == myGen and rolling.Visible then
				cutToReveal(result)
			end
		end)
	end

	-- welcome -> LUCKY callout -> spin -> reveal. The callout leads because the
	-- player should already know the roll is a lucky one while they watch it.
	local function runReveal(result: any, myGen: number)
		local isSuper = result.variant == "super"
		showVariantCallout(isSuper, myGen, function()
			spinAll(result, isSuper, myGen)
		end)
	end

	-- Arms a result and opens the takeover on State 1 (Welcome) -- the exact
	-- same entry point whether this came from the real first-join fetch below
	-- or a debug re-trigger (AdminPanel's reset button replays the whole
	-- welcome -> roll -> reveal -> continue flow, not just the data).
	-- Bumping `generation` invalidates any in-flight timers from a PREVIOUS
	-- arm (see showVariantCallout/spinAll's generation checks).
	local function activate(result: any)
		generation += 1
		pending = result
		local itemIds = {}
		for _, item in result.items do
			table.insert(itemIds, item.itemId)
		end
		EconomyController.ensure(itemIds) -- fire now, land long before Reveal needs it
		flash.BackgroundTransparency = 1
		showOnly(welcome)
		root.Visible = true
	end

	rollBtn.Activated:Connect(function()
		-- Consume pending atomically: a double-fire on the same click (or a
		-- fast double-click) must not schedule two overlapping reveal timers
		-- for the same arm.
		local result = pending
		pending = nil
		if result then
			runReveal(result, generation)
		end
	end)

	continueBtn.Activated:Connect(function()
		root.Visible = false
		task.spawn(function()
			Net.invoke("AckStarterReveal")
		end)
		TutorialGuide.start() -- point the player at the Crafts NPC next
	end)

	task.spawn(function()
		local result = Net.invoke("GetStarterReveal")
		if result and result.ok and result.items and #result.items > 0 then
			activate(result)
		end
	end)

	return { trigger = activate }
end

return StarterRollScreen
