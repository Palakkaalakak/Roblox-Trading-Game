--!strict
-- Rolls screen (the gacha NPC). Five tier cards, cheapest to priciest —
-- pricier rolls carry better luck, and every card shows its HONEST odds
-- rolled up by rarity (straight from the server's live pool).
--
-- Two ways to pay:
--   * gems — one click
--   * items — open the tray, click items from your inventory until their
--     combined live Value covers the price. Paid items are REDISTRIBUTED:
--     they go back into the roll pool for other players to win. Items that
--     can never be re-made (ended limited-event outputs) are refused — they
--     would be stuck in the reserve forever — and the tray shows them dimmed
--     with the reason.
-- The result lands as a full-panel reveal, not a toast.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local State = require(ReplicatedStorage.Shared.Util.State)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Net = require(script.Parent.Parent.Net)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)

local RollsScreen = {}

local RARITY_ORDER = { "Common", "Rare", "Legendary", "Mythical" }

function RollsScreen.wire(gui: ScreenGui, tooltip: any, toast: (text: string, color: Color3) -> ())
	local panel = gui:WaitForChild("RollsPanel") :: Frame
	local tierRow = panel:WaitForChild("TierRow") :: Frame
	local cardTemplate = tierRow:WaitForChild("TierCard") :: TextButton
	local payBar = panel:WaitForChild("PayBar") :: Frame
	local gemsBtn = payBar:WaitForChild("GemsButton") :: TextButton
	local itemsBtn = payBar:WaitForChild("ItemsButton") :: TextButton
	local tray = panel:WaitForChild("ItemTray") :: Frame
	local trayGrid = tray:WaitForChild("TrayGrid") :: ScrollingFrame
	local trayTile = trayGrid:WaitForChild("TrayTile") :: Frame
	local totalLabel = tray:WaitForChild("TotalLabel") :: TextLabel
	local confirmBtn = tray:WaitForChild("ConfirmButton") :: TextButton
	local reveal = panel:WaitForChild("Reveal") :: Frame

	local closeBtn = panel:WaitForChild("CloseButton") :: TextButton
	closeBtn.Activated:Connect(function()
		panel.Visible = false
	end)

	local tiers: { any }? = nil -- last GetRolls payload
	local selectedId: string? = nil
	local rolling = false
	local cards: { [string]: TextButton } = {}
	local traySelection: { [string]: number } = {} -- itemId -> copies offered
	local trayTiles: { [string]: Frame } = {}
	local refreshTray -- fwd decl

	local function selectedTier(): any?
		for _, tier in tiers or {} do
			if tier.id == selectedId then
				return tier
			end
		end
		return nil
	end

	----------------------------------------------------------------------
	-- Tier cards
	----------------------------------------------------------------------

	-- odds rolled up by rarity: one big centered row per rarity, in that
	-- rarity's color (the labels are pre-built + pre-colored by GuiBuilder)
	local function fillOdds(card: TextButton, odds: { any })
		local byRarity: { [string]: number } = {}
		for _, o in odds do
			if o.rarity then
				byRarity[o.rarity] = (byRarity[o.rarity] or 0) + o.pct
			end
		end
		local oddsList = card:WaitForChild("OddsList") :: Frame
		for _, rarity in RARITY_ORDER do
			local row = oddsList:WaitForChild("Odds" .. rarity) :: TextLabel
			local pct = byRarity[rarity]
			if pct and pct > 0 then
				local shown = pct >= 10 and ("%.0f%%"):format(pct)
					or pct >= 1 and ("%.1f%%"):format(pct)
					or ("%.2f%%"):format(pct)
				row.Text = ("%s  %s"):format(rarity, shown)
				row.Visible = true
			else
				row.Visible = false
			end
		end
	end

	local function updatePayBar()
		local tier = selectedTier()
		if tier == nil then
			gemsBtn.Text = "Pick a roll above"
			gemsBtn.BackgroundColor3 = Theme.BgLight
			return
		end
		gemsBtn.Text = ("Roll — %d gems"):format(tier.gems)
		gemsBtn.BackgroundColor3 = Theme.Good
		if tray.Visible then
			refreshTray()
		end
	end

	local function selectTier(id: string)
		selectedId = id
		for tid, card in cards do
			local cardStroke = card:FindFirstChildWhichIsA("UIStroke")
			if cardStroke then
				cardStroke.Color = (tid == id) and Theme.Accent or Theme.Stroke
				cardStroke.Thickness = (tid == id) and 2.5 or 1.5
			end
		end
		updatePayBar()
	end

	local function renderTiers()
		for _, card in cards do
			card:Destroy()
		end
		table.clear(cards)
		for order, tier in tiers :: { any } do
			local card = cardTemplate:Clone()
			card.Name = "tier_" .. tier.id
			card.Visible = true
			card.LayoutOrder = order
			;(card:WaitForChild("TierName") :: TextLabel).Text = tier.name
			;(card:WaitForChild("Price") :: TextLabel).Text = ("%d gems"):format(tier.gems)
			;(card:WaitForChild("Luck") :: TextLabel).Text = ("Luck ×%d"):format(tier.luck)
			fillOdds(card, tier.odds or {})
			;(card:WaitForChild("Blurb") :: TextLabel).Text = tier.blurb or ""
			card.Activated:Connect(function()
				selectTier(tier.id)
			end)
			card.Parent = tierRow
			cards[tier.id] = card
		end
		-- default to the cheapest so the pay bar always has a live price
		if selectedTier() == nil and (tiers :: { any })[1] then
			selectTier((tiers :: { any })[1].id)
		else
			selectTier(selectedId :: string)
		end
	end

	local function refresh()
		task.spawn(function()
			local result = Net.invoke("GetRolls")
			if result.ok then
				tiers = result.tiers
				if panel.Visible then
					renderTiers()
				end
			end
		end)
	end

	----------------------------------------------------------------------
	-- Reveal
	----------------------------------------------------------------------

	local function showReveal(item: any)
		Components.setIcon(reveal:WaitForChild("Icon") :: ImageLabel, item)
		local nameLabel = reveal:WaitForChild("ItemName") :: TextLabel
		nameLabel.Text = item.name or "?"
		nameLabel.TextColor3 = Components.rarityColor(item.rarity)
		;(reveal:WaitForChild("SubLine") :: TextLabel).Text =
			("%s  ·  worth about %d gems"):format(item.rarity or "?", item.value or 0)
		reveal.Visible = true
	end
	;(reveal:WaitForChild("DoneButton") :: TextButton).Activated:Connect(function()
		reveal.Visible = false
	end)

	----------------------------------------------------------------------
	-- Rolling
	----------------------------------------------------------------------

	local function doRoll(payment: any?)
		local tier = selectedTier()
		if tier == nil or rolling then
			return
		end
		rolling = true
		local result = Net.invoke("RollItem", tier.id, payment)
		rolling = false
		if result.ok then
			showReveal(result.item)
			table.clear(traySelection)
			tray.Visible = false
			refresh() -- odds move when reserves shrink
		elseif result.err == "insufficient_gems" then
			toast("Not enough gems!", Theme.Bad)
		elseif result.err == "insufficient_items" then
			toast("You don't own all of those anymore.", Theme.Bad)
		elseif result.err == "payment_too_low" then
			toast("Prices moved — add another item to cover the cost.", Theme.Warn)
			refreshTray()
		elseif result.err == "not_reobtainable" then
			toast("Limited event items can't be traded in — they can never be made again.", Theme.Warn)
			refreshTray()
		elseif result.err == "nothing_left" then
			toast("Every rollable item is fully distributed!", Theme.Warn)
		else
			toast("Roll failed: " .. tostring(result.err), Theme.Bad)
		end
	end

	gemsBtn.Activated:Connect(function()
		doRoll(nil)
	end)
	;(reveal:WaitForChild("AgainButton") :: TextButton).Activated:Connect(function()
		reveal.Visible = false
		doRoll(nil)
	end)

	----------------------------------------------------------------------
	-- Item payment tray
	----------------------------------------------------------------------

	local function selectionTotal(): number
		local total = 0
		local stats = EconomyController.stats:get()
		for itemId, count in traySelection do
			local snap = stats[itemId]
			local v = snap and snap.value and snap.value.value or 0
			total += v * count
		end
		return total
	end

	refreshTray = function()
		local tier = selectedTier()
		if tier == nil then
			return
		end
		local inventory = InventoryController.inventory:get()
		local stats = EconomyController.stats:get()

		-- drop tiles for items no longer owned
		for itemId, tile in trayTiles do
			if (inventory[itemId] or 0) <= 0 then
				tile:Destroy()
				trayTiles[itemId] = nil
				traySelection[itemId] = nil
			end
		end

		local wanted = {}
		for itemId, owned in inventory do
			table.insert(wanted, itemId)
			local snap = stats[itemId]
			local tile = trayTiles[itemId]
			local eligible = EventConfig.isReobtainable(itemId)
			if tile == nil then
				tile = trayTile:Clone()
				tile.Name = itemId
				tile.Visible = true
				tile.Parent = trayGrid
				trayTiles[itemId] = tile
				tooltip.attach(tile, function()
					return EconomyController.get(itemId), InventoryController.inventory:get()[itemId]
				end)
				-- thumb-friendly steppers: − / + adjust how many copies go in
				local function bump(delta: number)
					local own = InventoryController.inventory:get()[itemId] or 0
					local using = math.clamp((traySelection[itemId] or 0) + delta, 0, own)
					traySelection[itemId] = using > 0 and using or nil
					refreshTray()
				end
				;(tile:WaitForChild("PlusButton") :: TextButton).Activated:Connect(function()
					bump(1)
				end)
				;(tile:WaitForChild("MinusButton") :: TextButton).Activated:Connect(function()
					bump(-1)
				end)
			end
			Components.setIcon(tile:WaitForChild("Icon") :: ImageLabel, snap)
			;(tile:WaitForChild("ItemName") :: TextLabel).Text = snap and snap.name or itemId
			local v = snap and snap.value and snap.value.value
			local valueLabel = tile:WaitForChild("ValueLabel") :: TextLabel
			local useLabel = tile:WaitForChild("UseLabel") :: TextLabel
			local icon = tile:WaitForChild("Icon") :: ImageLabel
			local minus = tile:WaitForChild("MinusButton") :: TextButton
			local plus = tile:WaitForChild("PlusButton") :: TextButton
			local using = traySelection[itemId] or 0
			if eligible then
				icon.ImageTransparency = 0
				valueLabel.Text = v and (tostring(v) .. " each") or "…"
				minus.Visible = true
				plus.Visible = true
				useLabel.Text = tostring(using)
				useLabel.TextColor3 = using > 0 and Theme.Warn or Theme.TextDim
			else
				-- limited-event keepsake: visible so the player learns WHY it
				-- can't pay for a roll (it could never be won back out)
				icon.ImageTransparency = 0.55
				valueLabel.Text = "limited event"
				minus.Visible = false
				plus.Visible = false
				useLabel.Text = "—"
				useLabel.TextColor3 = Theme.TextDim
			end
			local tileStroke = tile:FindFirstChildWhichIsA("UIStroke")
			if tileStroke then
				tileStroke.Color = (eligible and using > 0) and Theme.Warn or Theme.Stroke
				tileStroke.Thickness = (eligible and using > 0) and 2 or 1
			end
		end
		EconomyController.ensure(wanted)

		local total = selectionTotal()
		local enough = total >= tier.gems
		totalLabel.Text = ("Selected: %d / %d value"):format(total, tier.gems)
		totalLabel.TextColor3 = enough and Theme.Good or Theme.Gem
		confirmBtn.Text = enough and ("Roll — trade in %d value"):format(total) or "Add more items…"
		confirmBtn.BackgroundColor3 = enough and Theme.Good or Theme.BgLight
		confirmBtn.AutoButtonColor = enough
	end

	itemsBtn.Activated:Connect(function()
		tray.Visible = not tray.Visible
		itemsBtn.Text = tray.Visible and "Hide the item tray" or "Pay with items instead…"
		if tray.Visible then
			refreshTray()
		end
	end)

	confirmBtn.Activated:Connect(function()
		local tier = selectedTier()
		if tier == nil then
			return
		end
		if selectionTotal() < tier.gems then
			toast("Pick items worth at least the roll price.", Theme.Bad)
			return
		end
		local items = {}
		for itemId, count in traySelection do
			items[itemId] = count
		end
		doRoll({ items = items })
	end)

	-- live updates while the tray is open (values move, items arrive/leave)
	State.Observe(InventoryController.inventory, function()
		if panel.Visible and tray.Visible then
			refreshTray()
		end
	end)
	State.Observe(EconomyController.stats, function()
		if panel.Visible and tray.Visible then
			refreshTray()
		end
	end)

	----------------------------------------------------------------------
	-- Open / toggle
	----------------------------------------------------------------------

	function RollsScreen.open()
		Components.closeOtherPanels(panel)
		panel.Visible = true
		reveal.Visible = false
		if tiers then
			renderTiers()
		end
		refresh()
	end

	function RollsScreen.toggle()
		if panel.Visible then
			panel.Visible = false
		else
			RollsScreen.open()
		end
	end
end

return RollsScreen
