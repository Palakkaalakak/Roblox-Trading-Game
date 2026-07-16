--!strict
-- Events screen (crafting / sacrifices / rotating recipes) — the value engine's
-- front end. Panel + row templates live in StarterGui (GuiBuilder); the tab bar
-- and the per-row extras (tier badge, blurb, value-created line) are built here
-- so the shared builder stays untouched.
--
-- Three tabs, in the order a player actually thinks:
--   ⚡ Can Craft — only what I can make RIGHT NOW (the default; no hunting)
--   ⏳ Rotating — this window's recipes + a live countdown to the swap
--   📋 All      — everything, grouped by event
--
-- Every row states the deal plainly: what it eats -> what it mints, how much
-- stock is left, and the VALUE CREATED (output value minus everything it burns).
-- That gap is why crafting exists — it's the only thing in the game that makes
-- worth instead of moving it around.

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
		{ id = "rotating", text = "⏳ Rotating" },
		{ id = "all", text = "📋 All" },
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
	-- headers whose countdown ticks live: { label, untilUnix, prefix }
	local ticking: { { label: TextLabel, at: number, prefix: string } } = {}

	local function clearRendered()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
		table.clear(ticking)
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

		-- blurb along the bottom
		if recipe.blurb then
			local blurb = Instance.new("TextLabel")
			blurb.Name = "Blurb"
			blurb.BackgroundTransparency = 1
			blurb.Position = UDim2.fromOffset(10, 90)
			blurb.Size = UDim2.new(1, -150, 0, 16)
			blurb.Font = Theme.FontLight
			blurb.TextSize = 11
			blurb.TextXAlignment = Enum.TextXAlignment.Left
			blurb.TextTruncate = Enum.TextTruncate.AtEnd
			blurb.TextColor3 = Theme.TextDim
			blurb.Text = recipe.blurb
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

	-- which recipes survive the active tab
	local function visibleRecipes(event: any): { any }
		local out = {}
		for _, recipe in event.recipes do
			local keep
			if activeTab == "craft" then
				keep = recipe.craftable and recipe.output.remaining > 0
			elseif activeTab == "rotating" then
				keep = event.rotatesAt ~= nil
			else
				keep = true
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
		elseif activeTab == "rotating" then
			return "No rotating recipes right now, check back soon!"
		end
		return "No events right now, come back later!"
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
