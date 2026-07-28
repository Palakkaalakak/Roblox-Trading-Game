--!strict
-- Crafting screen (stations / rotating recipes / seasonal events) — the value
-- engine's front end. Panel + row templates live in StarterGui (GuiBuilder);
-- the tab bar and the per-row extras (tier badge, blurb, chain-view button)
-- are built here so the shared builder stays untouched.
--
-- Three tabs, in the order a player actually thinks — no "Stations" jargon; a
-- player doesn't care whether something is a permanent fixture or this week's
-- rotation, only whether it's something to make right now or a one-off:
--   ⚡ Can Craft — only what I can make RIGHT NOW (the default; no hunting)
--   📜 Recipes   — everything craftable in general (permanent + rotating)
--   🎉 Limited   — temporary/seasonal events, each with its end countdown
--
-- Every row states the deal plainly: what it eats -> what it mints, how much
-- stock is left. A "How to make" button opens that output's recipe LADDER (see
-- GetRecipeGraph): the item itself at the top, highlighted, then bracket
-- connectors down to what it's made of, recursing into any ingredient that is
-- itself crafted — so a player can trace a grail all the way to base commons
-- instead of staring at an ingredient with no idea where it comes from.

local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Net = require(script.Parent.Parent.Net)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)

local EventsScreen = {}

local TIER_COLOR: { [number]: Color3 } = {
	[1] = Color3.fromRGB(154, 160, 166), -- refine (material)
	[2] = Color3.fromRGB(79, 195, 247), -- artisan
	[3] = Color3.fromRGB(255, 183, 77), -- grail
}
local TIER_NAME: { [number]: string } = { [1] = "REFINE", [2] = "CRAFT", [3] = "GRAIL" }

local function timeText(untilUnix: number?): string
	if untilUnix == nil then
		return ""
	end
	local remaining = math.max(0, untilUnix - workspace:GetServerTimeNow())
	local h = math.floor(remaining / 3600)
	local m = math.floor((remaining % 3600) / 60)
	local s = math.floor(remaining % 60)
	if h > 0 then
		return ("%dh %dm"):format(h, m)
	elseif m > 0 then
		return ("%dm %02ds"):format(m, s)
	end
	return ("%ds"):format(s)
end

function EventsScreen.wire(gui: ScreenGui, tooltip: any, toast: (text: string, color: Color3) -> ())
	local panel = gui:WaitForChild("EventsPanel") :: Frame
	local list = panel:WaitForChild("EventList") :: ScrollingFrame
	local headerTemplate = list:WaitForChild("HeaderRow") :: Frame
	local rowTemplate = list:WaitForChild("RecipeRow") :: Frame
	local chipTemplate = (rowTemplate:WaitForChild("InputsHolder") :: Frame):WaitForChild("InputChip") :: Frame

	local closeButton = panel:WaitForChild("CloseButton") :: TextButton
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)

	----------------------------------------------------------------------
	-- Tab bar (built here; make room by pushing the list down)
	----------------------------------------------------------------------
	list.Position = UDim2.fromOffset(12, 80)
	list.Size = UDim2.new(1, -24, 1, -92)

	local tabRow = Instance.new("Frame")
	tabRow.Name = "TabRow"
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(12, 42)
	tabRow.Size = UDim2.new(1, -24, 0, 30)
	tabRow.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabRow

	local TABS = {
		{ id = "craft", text = "⚡ Can Craft" },
		{ id = "recipes", text = "📜 Recipes" },
		{ id = "limited", text = "🎉 Limited" },
	}
	local activeTab = "craft"
	local tabButtons: { [string]: TextButton } = {}
	for i, spec in TABS do
		local b = Instance.new("TextButton")
		b.Name = "Tab_" .. spec.id
		b.LayoutOrder = i
		b.Size = UDim2.fromOffset(150, 30)
		b.BackgroundColor3 = Theme.BgLight
		b.Font = Theme.Font
		b.TextSize = 13
		b.TextColor3 = Theme.TextPrimary
		b.Text = spec.text
		b.Parent = tabRow
		local c = Instance.new("UICorner")
		c.CornerRadius = Theme.CornerSmall
		c.Parent = b
		tabButtons[spec.id] = b
	end

	local spawned: { Instance } = {}
	local lastEvents: { any }? = nil
	local crafting = false
	local refresh -- fwd decl
	local renderEvents -- fwd decl
	local openChain -- fwd decl
	-- headers whose countdown ticks live: { label, untilUnix, prefix }
	local ticking: { { label: TextLabel, at: number, prefix: string } } = {}

	local function clearRendered()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
		table.clear(ticking)
	end

	----------------------------------------------------------------------
	-- Recipe chain view: the full static ladder for one output, so a player
	-- can see what a grail eats all the way down to base commons — even for
	-- tiers that aren't this rotation's active picks (GetRecipeGraph ignores
	-- the rotation window entirely; GetEvents only ever shows what's live).
	-- Built once per open, destroyed on close — bounded depth (the ladder is
	-- at most 3 tiers), so this is a handful of frames, never a per-frame cost.
	----------------------------------------------------------------------
	local recipeGraph: { any }? = nil
	local fetchingGraph = false

	local function ensureRecipeGraph(onReady: () -> ())
		if recipeGraph then
			onReady()
			return
		end
		if fetchingGraph then
			return
		end
		fetchingGraph = true
		task.spawn(function()
			local result = Net.invoke("GetRecipeGraph")
			fetchingGraph = false
			if result and result.ok then
				recipeGraph = result.recipes
				onReady()
			end
		end)
	end

	-- First recipe in the graph that makes this output (one representative
	-- route — the rotating refinery deliberately has several, e.g. 4 recipes
	-- all producing Refined Essence; showing all of them would turn a linear
	-- ladder into a wide, confusing fan for no benefit to reading the chain).
	local function findRecipeForOutput(outItemId: string): (any?, number)
		if recipeGraph == nil then
			return nil, 0
		end
		local found, altCount = nil, 0
		for _, entry in recipeGraph do
			if entry.recipe.output.itemId == outItemId then
				altCount += 1
				if found == nil then
					found = entry
				end
			end
		end
		return found, altCount
	end

	local chainOverlay = Instance.new("Frame")
	chainOverlay.Name = "ChainOverlay"
	chainOverlay.BackgroundColor3 = Theme.Bg
	chainOverlay.BorderSizePixel = 0
	-- covers the same content area as the main list, below the tab row
	chainOverlay.Position = UDim2.fromOffset(12, 80)
	chainOverlay.Size = UDim2.new(1, -24, 1, -92)
	chainOverlay.Visible = false
	chainOverlay.ZIndex = 10
	chainOverlay.Parent = panel

	local chainHeader = Instance.new("Frame")
	chainHeader.Name = "ChainHeader"
	chainHeader.BackgroundTransparency = 1
	chainHeader.Size = UDim2.new(1, 0, 0, 30)
	chainHeader.ZIndex = 10
	chainHeader.Parent = chainOverlay
	local chainTitle = Instance.new("TextLabel")
	chainTitle.Name = "ChainTitle"
	chainTitle.BackgroundTransparency = 1
	chainTitle.Position = UDim2.fromOffset(4, 0)
	chainTitle.Size = UDim2.new(1, -100, 1, 0)
	chainTitle.Font = Theme.Font
	chainTitle.TextSize = 16
	chainTitle.TextColor3 = Theme.TextPrimary
	chainTitle.TextXAlignment = Enum.TextXAlignment.Left
	chainTitle.Text = "Recipe Ladder"
	chainTitle.ZIndex = 10
	chainTitle.Parent = chainHeader
	local chainClose = Instance.new("TextButton")
	chainClose.Name = "ChainClose"
	chainClose.AnchorPoint = Vector2.new(1, 0)
	chainClose.Position = UDim2.new(1, 0, 0, 0)
	chainClose.Size = UDim2.fromOffset(90, 28)
	chainClose.BackgroundColor3 = Theme.BgLight
	chainClose.Font = Theme.Font
	chainClose.TextSize = 13
	chainClose.TextColor3 = Theme.TextPrimary
	chainClose.Text = "← Back"
	chainClose.ZIndex = 10
	chainClose.Parent = chainHeader
	local chainCloseCorner = Instance.new("UICorner")
	chainCloseCorner.CornerRadius = Theme.CornerSmall
	chainCloseCorner.Parent = chainClose
	chainClose.Activated:Connect(function()
		chainOverlay.Visible = false
	end)

	local chainList = Instance.new("ScrollingFrame")
	chainList.Name = "ChainList"
	chainList.Position = UDim2.fromOffset(0, 36)
	chainList.Size = UDim2.new(1, 0, 1, -36)
	chainList.BackgroundTransparency = 1
	chainList.BorderSizePixel = 0
	chainList.ScrollBarThickness = 6
	chainList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chainList.CanvasSize = UDim2.new()
	chainList.ZIndex = 10
	chainList.Parent = chainOverlay
	local chainListLayout = Instance.new("UIListLayout")
	chainListLayout.Padding = UDim.new(0, 10)
	chainListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	chainListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chainListLayout.Parent = chainList

	-- Node geometry is fixed so the bracket connectors below can compute exactly
	-- where each node's centre sits without measuring anything at runtime.
	local NODE_W, NODE_H, NODE_GAP = 96, 96, 8

	-- one tier's node: icon + name + owned/needed, used for both the output
	-- being explained and each of its inputs. `highlight` marks the item whose
	-- ladder this is, so it reads as the goal rather than just another rung.
	local function chainNode(parentFrame: Instance, order: number, itemId: string, name: string, imageId: string?, owned: number?, count: number?, highlight: boolean?): Frame
		local node = Instance.new("Frame")
		node.Name = "node_" .. itemId
		node.LayoutOrder = order
		node.BackgroundColor3 = highlight and Theme.Accent or Theme.BgLight
		node.BorderSizePixel = 0
		node.Size = UDim2.fromOffset(NODE_W, NODE_H)
		node.ZIndex = 10
		node.Parent = parentFrame
		local nodeCorner = Instance.new("UICorner")
		nodeCorner.CornerRadius = Theme.CornerSmall
		nodeCorner.Parent = node
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Position = UDim2.fromOffset(16, 6)
		icon.Size = UDim2.fromOffset(64, 48)
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 10
		icon.Parent = node
		EconomyController.ensure({ itemId })
		Components.setIcon(icon, { imageId = imageId, name = name })
		tooltip.attach(icon, function()
			return EconomyController.get(itemId) or { name = name, imageId = imageId }, owned
		end)
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "NameLabel"
		nameLbl.BackgroundTransparency = 1
		nameLbl.Position = UDim2.fromOffset(2, 56)
		nameLbl.Size = UDim2.new(1, -4, 0, 26)
		nameLbl.Font = Theme.FontLight
		nameLbl.TextSize = 10
		nameLbl.TextWrapped = true
		nameLbl.TextColor3 = Theme.TextPrimary
		nameLbl.TextXAlignment = Enum.TextXAlignment.Center
		nameLbl.Text = name
		nameLbl.ZIndex = 10
		nameLbl.Parent = node
		if count then
			local countLbl = Instance.new("TextLabel")
			countLbl.Name = "CountLabel"
			countLbl.BackgroundTransparency = 1
			countLbl.Position = UDim2.fromOffset(2, 80)
			countLbl.Size = UDim2.new(1, -4, 0, 14)
			countLbl.Font = Theme.Font
			countLbl.TextSize = 11
			countLbl.TextXAlignment = Enum.TextXAlignment.Center
			countLbl.Text = ("%d/%d"):format(owned or 0, count)
			countLbl.TextColor3 = (owned or 0) >= count and Theme.Good or Theme.Bad
			countLbl.ZIndex = 10
			countLbl.Parent = node
		end
		return node
	end

	-- a plain filled line — the building block of the bracket connectors
	local function chainLine(parentFrame: Instance, x: number, y: number, w: number, h: number)
		local seg = Instance.new("Frame")
		seg.BackgroundColor3 = Theme.TextDim
		seg.BorderSizePixel = 0
		seg.Position = UDim2.fromOffset(x, y)
		seg.Size = UDim2.fromOffset(w, h)
		seg.ZIndex = 10
		seg.Parent = parentFrame
	end

	-- The connector between a row of inputs and the single item they make: a
	-- proper bracket, drawn as one horizontal bar spanning the inputs with a
	-- stub dropping to each of them and one rising to the item above, plus an
	-- arrowhead so the direction (these MAKE that) is unambiguous. Every
	-- coordinate is derived from the fixed node geometry, so the bars line up
	-- exactly with the node centres instead of being eyeballed.
	local ARROW_H = 32
	local function chainConnector(order: number, inputCount: number)
		local row = Instance.new("Frame")
		row.Name = "connector_" .. order
		row.LayoutOrder = order
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, ARROW_H)
		row.Parent = chainList

		local totalW = inputCount * NODE_W + math.max(inputCount - 1, 0) * NODE_GAP
		local holder = Instance.new("Frame")
		holder.Name = "Holder"
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.fromScale(0.5, 0)
		holder.Size = UDim2.fromOffset(totalW, ARROW_H)
		holder.BackgroundTransparency = 1
		holder.ZIndex = 10
		holder.Parent = row

		local midY = math.floor(ARROW_H / 2)
		local centreX = math.floor(totalW / 2)

		-- stub rising from the bar to the item above, starting below the
		-- arrowhead so the glyph never sits on top of the line
		chainLine(holder, centreX - 1, 10, 2, midY - 10)
		-- arrowhead on that stub, pointing up at what gets made
		local head = Instance.new("TextLabel")
		head.Name = "Arrow"
		head.BackgroundTransparency = 1
		head.AnchorPoint = Vector2.new(0.5, 0)
		head.Position = UDim2.fromOffset(centreX, 0)
		head.Size = UDim2.fromOffset(16, 12)
		head.Font = Theme.Font
		head.TextSize = 12
		head.TextColor3 = Theme.TextDim
		head.Text = "▲"
		head.ZIndex = 10
		head.Parent = holder

		local firstCentre = math.floor(NODE_W / 2)
		local lastCentre = totalW - math.floor(NODE_W / 2)
		if inputCount > 1 then
			-- the spanning bar, exactly from first node centre to last
			chainLine(holder, firstCentre, midY - 1, lastCentre - firstCentre, 2)
		end
		-- a stub dropping onto each input
		for i = 1, inputCount do
			local c = (i - 1) * (NODE_W + NODE_GAP) + firstCentre
			chainLine(holder, c - 1, midY, 2, ARROW_H - midY)
		end
	end

	-- a caption between branches, naming which item is being broken down next
	local function chainCaption(order: number, text: string)
		local lbl = Instance.new("TextLabel")
		lbl.Name = "caption_" .. order
		lbl.LayoutOrder = order
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 0, 20)
		lbl.Font = Theme.FontLight
		lbl.TextSize = 12
		lbl.TextColor3 = Theme.TextDim
		lbl.Text = text
		lbl.ZIndex = 10
		lbl.Parent = chainList
	end

	-- one row of nodes, centred
	local function chainRow(order: number, build: (Frame) -> ()): Frame
		local tierRow = Instance.new("Frame")
		tierRow.Name = "tier_" .. order
		tierRow.LayoutOrder = order
		tierRow.BackgroundTransparency = 1
		tierRow.Size = UDim2.new(1, 0, 0, NODE_H)
		tierRow.Parent = chainList
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.Padding = UDim.new(0, NODE_GAP)
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = tierRow
		build(tierRow)
		return tierRow
	end

	-- Reads top-down: the item you asked about sits at the very top, then the
	-- bracket, then what it's made of; any ingredient that is itself crafted is
	-- broken down below under its own caption. Recursion is bounded by depth
	-- (the ladder is only ever 3 tiers) so a config mistake can't loop forever.
	local function buildChain(rootOutId: string, rootName: string, rootImage: string?)
		local order = 0
		local rootEntry = findRecipeForOutput(rootOutId)

		-- the goal, highlighted, so the ladder visibly LEADS to something
		order += 1
		chainRow(order, function(parentFrame)
			chainNode(parentFrame, 1, rootOutId, rootName, rootImage, nil, nil, true)
		end)

		if rootEntry == nil then
			order += 1
			chainCaption(order, "This one isn't crafted — roll for it, buy it, or trade for it.")
			return
		end

		local function expand(outId: string, depth: number)
			if depth > 4 then
				return
			end
			local entry = findRecipeForOutput(outId)
			if entry == nil then
				return -- base item: a leaf, nothing feeds it
			end
			local inputs = entry.recipe.inputs
			order += 1
			chainConnector(order, #inputs)
			order += 1
			chainRow(order, function(parentFrame)
				for i, input in inputs do
					chainNode(parentFrame, i, input.itemId, input.name, input.imageId, input.owned, input.count)
				end
			end)
			-- then break down any ingredient that is itself crafted
			for _, input in inputs do
				if input.itemId:sub(1, 4) == "evt_" and findRecipeForOutput(input.itemId) then
					order += 1
					chainCaption(order, "…and " .. input.name .. " is made from:")
					expand(input.itemId, depth + 1)
				end
			end
		end
		expand(rootOutId, 1)
	end

	openChain = function(itemId: string, name: string, imageId: string?)
		ensureRecipeGraph(function()
			-- captions are TextLabels, not Frames — clear everything but the layout
			for _, inst in chainList:GetChildren() do
				if not inst:IsA("UIListLayout") then
					inst:Destroy()
				end
			end
			chainTitle.Text = "How to make: " .. name
			buildChain(itemId, name, imageId)
			chainOverlay.Visible = true
		end)
	end

	local function renderChip(chip: Frame, input: any)
		Components.setIcon(chip:WaitForChild("Icon") :: ImageLabel, input)
		local countLabel = chip:WaitForChild("CountLabel") :: TextLabel
		local enough = input.owned >= input.count
		countLabel.Text = ("%d/%d"):format(input.owned, input.count)
		countLabel.TextColor3 = enough and Theme.Good or Theme.Bad
		EconomyController.ensure({ input.itemId })
		tooltip.attach(chip, function()
			return EconomyController.get(input.itemId) or { name = input.name, imageId = input.imageId }, input.owned
		end)
	end

	local function renderRow(row: Frame, event: any, recipe: any, order: number)
		row.LayoutOrder = order
		row.Visible = true
		row.Size = UDim2.new(1, -8, 0, 112) -- taller than the template: room for the blurb

		-- inputs (item chips only — gems show on the Cost line, never as a fake item)
		local holder = row:WaitForChild("InputsHolder") :: Frame
		local gemInput = recipe.gems and recipe.gems > 0
		local chipOrder = 0
		for _, input in recipe.inputs do
			chipOrder += 1
			local chip = chipTemplate:Clone()
			chip.Name = "chip_" .. input.itemId
			chip.Visible = true
			chip.LayoutOrder = chipOrder
			;(chip:WaitForChild("GemChip") :: TextLabel).Text = ""
			renderChip(chip, input)
			chip.Parent = holder
			table.insert(spawned, chip)
		end

		-- output
		Components.setIcon(row:WaitForChild("OutputIcon") :: ImageLabel, {
			name = recipe.output.name,
			imageId = recipe.output.imageId,
		})
		;(row:WaitForChild("OutputName") :: TextLabel).Text = recipe.output.name
		;(row:WaitForChild("OutputStock") :: TextLabel).Text =
			("%d/%d left"):format(recipe.output.remaining, recipe.output.total)
		;(row:WaitForChild("CostIcon") :: ImageLabel).Visible = gemInput
		;(row:WaitForChild("CostLabel") :: TextLabel).Text = gemInput and ("Cost: %d"):format(recipe.gems) or ""

		-- tier badge, under the output icon
		local badge = Instance.new("TextLabel")
		badge.Name = "TierBadge"
		badge.BackgroundTransparency = 1
		badge.Position = UDim2.fromOffset(274, 76)
		badge.Size = UDim2.fromOffset(56, 14)
		badge.Font = Theme.Font
		badge.TextSize = 10
		badge.TextColor3 = TIER_COLOR[recipe.tier] or Theme.TextDim
		badge.Text = TIER_NAME[recipe.tier] or ""
		badge.Parent = row

		-- "How to make" button: top-right, clear of the output/action area below
		-- it. Labelled in words rather than an icon — a casual player shouldn't
		-- have to guess what a symbol means to find the recipe ladder.
		local chainBtn = Instance.new("TextButton")
		chainBtn.Name = "ChainButton"
		chainBtn.AnchorPoint = Vector2.new(1, 0)
		chainBtn.Position = UDim2.new(1, -8, 0, 4)
		chainBtn.Size = UDim2.fromOffset(96, 22)
		chainBtn.BackgroundColor3 = Theme.BgLight
		chainBtn.Font = Theme.Font
		chainBtn.TextSize = 11
		chainBtn.TextColor3 = Theme.TextPrimary
		chainBtn.Text = "How to make"
		chainBtn.Parent = row
		local chainCorner = Instance.new("UICorner")
		chainCorner.CornerRadius = Theme.CornerSmall
		chainCorner.Parent = chainBtn
		chainBtn.Activated:Connect(function()
			openChain(recipe.output.itemId, recipe.output.name, recipe.output.imageId)
		end)

		-- bottom line: normally the blurb, but a missing event-item input takes
		-- priority — point the player at WHERE that input is crafted, and
		-- whether that's actually open THIS rotation (see CraftingService.
		-- liveProducerOf) instead of sending them to a station that's closed
		local bottomText = recipe.blurb
		local bottomColor = Theme.TextDim
		for _, input in recipe.inputs do
			if input.from and input.owned < input.count then
				if input.from.availableNow then
					bottomText = ("Need %s? Craft it at %s."):format(input.name, input.from.name)
				else
					bottomText = ("Need %s? %s makes it — not this rotation, back in %s.")
						:format(input.name, input.from.name, timeText(input.from.rotatesAt))
				end
				bottomColor = Theme.Warn
				break
			end
		end
		if bottomText then
			local blurb = Instance.new("TextLabel")
			blurb.Name = "Blurb"
			blurb.BackgroundTransparency = 1
			blurb.Position = UDim2.fromOffset(10, 90)
			blurb.Size = UDim2.new(1, -150, 0, 16)
			blurb.Font = Theme.FontLight
			blurb.TextSize = 11
			blurb.TextXAlignment = Enum.TextXAlignment.Left
			blurb.TextTruncate = Enum.TextTruncate.AtEnd
			blurb.TextColor3 = bottomColor
			blurb.Text = bottomText
			blurb.Parent = row
		end

		local soldOut = recipe.output.remaining <= 0
		;(row:WaitForChild("DoneOverlay") :: Frame).Visible = soldOut

		local btn = row:WaitForChild("ActionButton") :: TextButton
		btn.Text = event.kind == "sacrifice" and "SACRIFICE" or "CRAFT"
		btn.Visible = not soldOut
		btn.BackgroundColor3 = recipe.craftable and Theme.Good or Theme.BgLight
		btn.AutoButtonColor = recipe.craftable
		btn.Activated:Connect(function()
			if crafting then
				return
			end
			crafting = true
			btn.Text = "…"
			local result = Net.invoke("CraftItem", event.id, recipe.rid)
			crafting = false
			if result.ok then
				toast(("Made %s!"):format(result.output.name), Theme.Good)
			elseif result.err == "recipe_soldout" then
				toast(recipe.output.name .. " is fully crafted!", Theme.Warn)
			elseif result.err == "recipe_not_active" then
				toast("That recipe just rotated out!", Theme.Warn)
			elseif result.err and result.err:match("^insufficient") then
				toast("You don't have the required items!", Theme.Bad)
			else
				toast("Craft failed: " .. tostring(result.err), Theme.Bad)
			end
			refresh()
		end)

		EconomyController.ensure({ recipe.output.itemId })
		tooltip.attach(row:WaitForChild("OutputIcon") :: ImageLabel, function()
			return EconomyController.get(recipe.output.itemId)
				or { name = recipe.output.name, imageId = recipe.output.imageId }, nil
		end)
	end

	-- which recipes survive the active tab (events carry a server-side
	-- category: permanent station / rotating window / limited-time)
	local function visibleRecipes(event: any): { any }
		local out = {}
		for _, recipe in event.recipes do
			local keep
			if activeTab == "craft" then
				keep = recipe.craftable and recipe.output.remaining > 0
			elseif activeTab == "recipes" then
				keep = event.category == "permanent" or event.category == "rotating"
			else -- limited
				keep = event.category == "limited"
			end
			if keep then
				table.insert(out, recipe)
			end
		end
		return out
	end

	local function emptyMessage(): string
		if activeTab == "craft" then
			return "Nothing you can craft yet — trade for the inputs, then come back!"
		elseif activeTab == "recipes" then
			return "No recipes available right now, check back soon!"
		end
		return "No limited events running — new seasons land here!"
	end

	renderEvents = function(events: { any })
		clearRendered()
		local order = 0
		local shown = 0
		for _, event in events do
			local recipes = visibleRecipes(event)
			if #recipes > 0 then
				order += 1
				local header = headerTemplate:Clone()
				header.Name = "header_" .. event.id
				header.Visible = true
				header.LayoutOrder = order
				local suffix = event.kind == "sacrifice" and "  (sacrifice)" or ""
				;(header:WaitForChild("EventName") :: TextLabel).Text = event.name .. suffix
				local tl = header:WaitForChild("TimeLabel") :: TextLabel
				if event.rotatesAt then
					tl.Text = "rotates in " .. timeText(event.rotatesAt)
					table.insert(ticking, { label = tl, at = event.rotatesAt, prefix = "rotates in " })
				elseif event.endsAt then
					tl.Text = "ends in " .. timeText(event.endsAt)
					table.insert(ticking, { label = tl, at = event.endsAt, prefix = "ends in " })
				else
					tl.Text = ""
				end
				header.Parent = list
				table.insert(spawned, header)

				for _, recipe in recipes do
					order += 1
					shown += 1
					local row = rowTemplate:Clone()
					row.Name = "row_" .. event.id .. "_" .. recipe.rid
					row.Parent = list
					table.insert(spawned, row)
					renderRow(row, event, recipe, order)
				end
			end
		end
		if shown == 0 then
			local none = headerTemplate:Clone()
			none.Visible = true
			;(none:WaitForChild("EventName") :: TextLabel).Text = emptyMessage()
			;(none:WaitForChild("EventName") :: TextLabel).TextColor3 = Theme.TextDim
			;(none:WaitForChild("TimeLabel") :: TextLabel).Text = ""
			none.Parent = list
			table.insert(spawned, none)
		end
	end

	local function selectTab(tab: string)
		activeTab = tab
		for id, b in tabButtons do
			b.BackgroundColor3 = (id == tab) and Theme.Accent or Theme.BgLight
		end
		if lastEvents then
			renderEvents(lastEvents)
		end
	end
	for _, spec in TABS do
		tabButtons[spec.id].Activated:Connect(function()
			selectTab(spec.id)
		end)
	end

	refresh = function()
		task.spawn(function()
			local result = Net.invoke("GetEvents")
			if result.ok then
				lastEvents = result.events
				if panel.Visible then
					renderEvents(result.events)
				end
			end
		end)
	end

	-- live countdowns; also re-pull when a rotation window lapses so the new
	-- set appears without the player reopening the panel
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if not panel.Visible then
			return
		end
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		local lapsed = false
		for _, t in ticking do
			if t.label.Parent then
				t.label.Text = t.prefix .. timeText(t.at)
				if workspace:GetServerTimeNow() >= t.at then
					lapsed = true
				end
			end
		end
		if lapsed then
			refresh()
		end
	end)

	function EventsScreen.open()
		Components.closeOtherPanels(panel)
		panel.Visible = true
		if lastEvents then
			renderEvents(lastEvents)
		end
		refresh()
	end

	function EventsScreen.toggle()
		if panel.Visible then
			panel.Visible = false
		else
			EventsScreen.open()
		end
	end

	selectTab("craft")

	-- prefetch after join so first open paints instantly
	task.spawn(function()
		task.wait(2)
		if lastEvents == nil then
			local result = Net.invoke("GetEvents")
			if result.ok then
				lastEvents = result.events
			end
		end
	end)
end

return EventsScreen
