--!strict
-- Events screen wiring (crafting / sacrifices / rotating recipes). Panel +
-- templates live in StarterGui. Renders one section per active event, one row
-- per recipe: inputs (with owned/required counts) → output (with stock).
-- CRAFT / SACRIFICE button per row; "Fully crafted!" overlay when output
-- stock hits 0. Cache-first paint so the first open isn't blank.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Net = require(script.Parent.Parent.Net)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)

local EventsScreen = {}

local function timeText(untilUnix: number?): string
	if untilUnix == nil then
		return ""
	end
	local remaining = math.max(0, untilUnix - workspace:GetServerTimeNow())
	local h = math.floor(remaining / 3600)
	local m = math.ceil((remaining % 3600) / 60)
	return h > 0 and ("%dh %dm"):format(h, m) or ("%dm"):format(m)
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

	local spawned: { Instance } = {} -- cloned rows/headers (cleared each render)
	local lastEvents: { any }? = nil
	local crafting = false
	local refresh -- fwd decl

	local function clearRendered()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
	end

	local function renderChip(chip: Frame, input: any)
		Components.setIcon(chip:WaitForChild("Icon") :: ImageLabel, input)
		local countLabel = chip:WaitForChild("CountLabel") :: TextLabel
		local enough = input.owned >= input.count
		countLabel.Text = ("%d/%d"):format(input.owned, input.count)
		countLabel.TextColor3 = enough and Theme.Good or Theme.Bad
		EconomyController.ensure({ input.itemId })
		tooltip.attach(chip, function()
			-- full item data on hover (falls back to name/icon before stats load)
			return EconomyController.get(input.itemId) or { name = input.name, imageId = input.imageId }, input.owned
		end)
	end

	local function renderRow(row: Frame, event: any, recipe: any, order: number)
		row.LayoutOrder = order
		row.Visible = true

		-- inputs (item chips only — the gem cost shows as the Cost: line below,
		-- never as a fake "item" card)
		local holder = row:WaitForChild("InputsHolder") :: Frame
		local gemInput = recipe.gems and recipe.gems > 0
		local chipOrder = 0
		local canAfford = true
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
			if input.owned < input.count then
				canAfford = false
			end
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

		local soldOut = recipe.output.remaining <= 0
		;(row:WaitForChild("DoneOverlay") :: Frame).Visible = soldOut

		local btn = row:WaitForChild("ActionButton") :: TextButton
		btn.Text = event.kind == "sacrifice" and "SACRIFICE" or "CRAFT"
		btn.Visible = not soldOut
		btn.BackgroundColor3 = canAfford and Theme.Good or Theme.BgLight
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

	local function renderEvents(events: { any })
		clearRendered()
		local order = 0
		if #events == 0 then
			local none = headerTemplate:Clone()
			none.Visible = true
			;(none:WaitForChild("EventName") :: TextLabel).Text = "No events right now, come back later!"
			;(none:WaitForChild("TimeLabel") :: TextLabel).Text = ""
			none.Parent = list
			table.insert(spawned, none)
			return
		end
		for _, event in events do
			order += 1
			local header = headerTemplate:Clone()
			header.Name = "header_" .. event.id
			header.Visible = true
			header.LayoutOrder = order
			;(header:WaitForChild("EventName") :: TextLabel).Text = event.name
			local suffix = event.kind == "sacrifice" and "  (sacrifice)" or ""
			;(header:WaitForChild("EventName") :: TextLabel).Text = event.name .. suffix
			local tl = header:WaitForChild("TimeLabel") :: TextLabel
			if event.rotatesAt then
				tl.Text = "rotates in " .. timeText(event.rotatesAt)
			elseif event.endsAt then
				tl.Text = "ends in " .. timeText(event.endsAt)
			else
				tl.Text = ""
			end
			header.Parent = list
			table.insert(spawned, header)

			for _, recipe in event.recipes do
				order += 1
				local row = rowTemplate:Clone()
				row.Name = "row_" .. event.id .. "_" .. recipe.rid
				row.Parent = list
				table.insert(spawned, row)
				renderRow(row, event, recipe, order)
			end
		end
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
