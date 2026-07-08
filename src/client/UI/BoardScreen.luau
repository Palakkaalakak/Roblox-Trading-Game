--!strict
-- Trade board wiring (the pillar). Panel + templates live in StarterGui.
--   * lists swap listings (AUTO = instant accept, ASK = register interest)
--     and bulk buy orders (contribute copies for gems, minus the house tax)
--   * Post modal: swap (give item+gems ⇄ want item+gems, auto-trade toggle)
--     or bulk (item + count + total gems). Give side escrows on post.
--   * own listings show Cancel; ask-listings you posted show who's interested
--     — clicking Invite sends them a normal trade request.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Net = require(script.Parent.Parent.Net)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local TradeController = require(script.Parent.Parent.Controllers.TradeController)

local BoardScreen = {}

function BoardScreen.wire(gui: ScreenGui, tooltip: any, toast: (text: string, color: Color3) -> ())
	local panel = gui:WaitForChild("BoardPanel") :: Frame
	local list = panel:WaitForChild("ListingList") :: ScrollingFrame
	local rowTemplate = list:WaitForChild("ListingRow") :: Frame
	local chipTemplate = (rowTemplate:WaitForChild("GiveHolder") :: Frame):WaitForChild("Chip") :: Frame
	local emptyLabel = panel:WaitForChild("EmptyLabel") :: TextLabel

	local closeBtn = panel:WaitForChild("CloseButton") :: TextButton
	closeBtn.Activated:Connect(function()
		panel.Visible = false
	end)

	local spawned: { Instance } = {}
	local lastListings: { any }? = nil
	local busy = false
	local refresh

	local function clearRendered()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
	end

	local function addChip(holder: Frame, imageId: string?, name: string, countText: string, order: number)
		local chip = chipTemplate:Clone()
		chip.Visible = true
		chip.LayoutOrder = order
		Components.setIcon(chip:WaitForChild("Icon") :: ImageLabel, { imageId = imageId, name = name })
		;(chip:WaitForChild("CountLabel") :: TextLabel).Text = countText
		chip.Parent = holder
		table.insert(spawned, chip)
		tooltip.attach(chip, function()
			return { name = name, imageId = imageId }, nil
		end)
	end

	local function fillOfferChips(holder: Frame, offer: any)
		local order = 0
		for _, entry in offer.items do
			order += 1
			addChip(holder, entry.imageId, entry.name, "x" .. entry.count, order)
		end
		if offer.gems > 0 then
			order += 1
			addChip(holder, Theme.Icons.Gem, "Gems", tostring(offer.gems), order)
		end
	end

	local function invokeAction(fn: () -> any): any
		if busy then
			return nil
		end
		busy = true
		local result = fn()
		busy = false
		return result
	end

	local function renderListing(listing: any, order: number)
		local row = rowTemplate:Clone()
		row.Name = "listing_" .. listing.id
		row.Visible = true
		row.LayoutOrder = order
		row.Parent = list
		table.insert(spawned, row)

		local giveHolder = row:WaitForChild("GiveHolder") :: Frame
		local wantHolder = row:WaitForChild("WantHolder") :: Frame
		local info = row:WaitForChild("InfoLabel") :: TextLabel
		local badge = row:WaitForChild("Badge") :: TextLabel
		local countBox = row:WaitForChild("CountBox") :: TextBox
		local action = row:WaitForChild("ActionButton") :: TextButton
		;(row:WaitForChild("PosterLabel") :: TextLabel).Text = listing.posterName
			.. (listing.mine and " (you)" or "")

		if listing.kind == "swap" then
			badge.Text = listing.autoTrade and "AUTO-TRADE" or "ASK FIRST"
			badge.TextColor3 = listing.autoTrade and Theme.Good or Theme.Warn
			fillOfferChips(giveHolder, listing.give) -- what the poster GIVES you
			fillOfferChips(wantHolder, listing.want) -- what they WANT from you
			if listing.mine and #listing.interested > 0 then
				local names = {}
				for _, e in listing.interested do
					table.insert(names, e.name)
				end
				info.Text = "Interested: " .. table.concat(names, ", ")
			end

			if listing.mine then
				if #listing.interested > 0 then
					action.Text = "Invite: " .. listing.interested[1].name
					action.BackgroundColor3 = Theme.Accent
					action.Activated:Connect(function()
						TradeController.requestTrade(listing.interested[1].userId)
						toast("Trade request sent to " .. listing.interested[1].name, Theme.Good)
					end)
					-- cancel still possible via a second small button? keep: long-press
					-- alternative — the badge doubles as cancel for own listings
					badge.Text ..= "  (yours)"
				else
					action.Text = "Cancel"
					action.BackgroundColor3 = Theme.Bad
					action.Activated:Connect(function()
						local result = invokeAction(function()
							return Net.invoke("CancelListing", listing.id)
						end)
						if result and result.ok then
							toast("Listing cancelled — escrow returned.", Theme.Warn)
						end
						refresh()
					end)
				end
			elseif listing.autoTrade then
				action.Text = "Accept"
				action.BackgroundColor3 = Theme.Good
				action.Activated:Connect(function()
					local result = invokeAction(function()
						return Net.invoke("AcceptListing", listing.id)
					end)
					if result then
						if result.ok then
							toast("Trade complete!", Theme.Good)
						elseif result.err == "gone" then
							toast("Too late — that listing is gone.", Theme.Warn)
						else
							toast("Couldn't accept: " .. tostring(result.err), Theme.Bad)
						end
					end
					refresh()
				end)
			else
				action.Text = "I'm interested"
				action.BackgroundColor3 = Theme.Accent
				action.Activated:Connect(function()
					local result = invokeAction(function()
						return Net.invoke("RegisterInterest", listing.id)
					end)
					if result then
						if result.ok then
							toast("The poster has been notified!", Theme.Good)
						elseif result.err == "already_interested" then
							toast("You already pinged this one.", Theme.Warn)
						else
							toast("Failed: " .. tostring(result.err), Theme.Bad)
						end
					end
				end)
			end
		else -- bulk
			badge.Text = "BULK BUY"
			badge.TextColor3 = Theme.Gem
			addChip(giveHolder, Theme.Icons.Gem, "Gems", tostring(listing.gemsPerCopy) .. "/copy", 1)
			addChip(wantHolder, listing.imageId, listing.itemName, "x" .. listing.remainingCount, 1)
			info.Text = ("wants %d more of %d · pays %d💎 per copy (before tax)"):format(
				listing.remainingCount,
				listing.wantedCount,
				listing.gemsPerCopy
			)
			if listing.mine then
				action.Text = "Cancel"
				action.BackgroundColor3 = Theme.Bad
				action.Activated:Connect(function()
					local result = invokeAction(function()
						return Net.invoke("CancelListing", listing.id)
					end)
					if result and result.ok then
						toast("Order cancelled — remaining gems returned.", Theme.Warn)
					end
					refresh()
				end)
			else
				countBox.Visible = true
				local owned = InventoryController.inventory:get()[listing.itemId] or 0
				countBox.Text = tostring(math.min(owned, listing.remainingCount))
				action.Text = "Contribute"
				action.BackgroundColor3 = Theme.Good
				action.Activated:Connect(function()
					local n = tonumber(countBox.Text)
					if n == nil or n < 1 then
						toast("Enter how many to contribute.", Theme.Bad)
						return
					end
					local result = invokeAction(function()
						return Net.invoke("ContributeBulk", listing.id, math.floor(n))
					end)
					if result then
						if result.ok then
							toast(("Contributed %d — earned %d 💎 (after tax)!"):format(result.count, result.payout), Theme.Good)
						else
							toast("Couldn't contribute: " .. tostring(result.err), Theme.Bad)
						end
					end
					refresh()
				end)
			end
		end
	end

	local function renderBoard(listings: { any })
		clearRendered()
		emptyLabel.Visible = #listings == 0
		for order, listing in listings do
			renderListing(listing, order)
		end
	end

	refresh = function()
		task.spawn(function()
			local result = Net.invoke("GetBoard")
			if result.ok then
				lastListings = result.listings
				if panel.Visible then
					renderBoard(result.listings)
				end
			end
		end)
	end

	function BoardScreen.open()
		panel.Visible = true
		if lastListings then
			renderBoard(lastListings)
		end
		refresh()
	end

	function BoardScreen.toggle()
		if panel.Visible then
			panel.Visible = false
		else
			BoardScreen.open()
		end
	end

	--------------------------------------------------------------------------
	-- Post modal
	--------------------------------------------------------------------------

	local post = panel:WaitForChild("PostPanel") :: Frame
	local picker = panel:WaitForChild("BoardItemPicker") :: Frame
	local pickGrid = picker:WaitForChild("PickGrid") :: ScrollingFrame
	local pickTile = pickGrid:WaitForChild("PickTile") :: ImageButton
	local giveRow = post:WaitForChild("GiveRow") :: Frame
	local wantRow = post:WaitForChild("WantRow") :: Frame
	local modeBtn = post:WaitForChild("ModeButton") :: TextButton
	local autoBtn = post:WaitForChild("AutoButton") :: TextButton
	local submitBtn = post:WaitForChild("SubmitButton") :: TextButton

	local postCloseBtn = post:WaitForChild("CloseButton") :: TextButton
	postCloseBtn.Activated:Connect(function()
		post.Visible = false
		picker.Visible = false
	end)
	local pickerCloseBtn = picker:WaitForChild("CloseButton") :: TextButton
	pickerCloseBtn.Activated:Connect(function()
		picker.Visible = false
	end)

	local mode: "swap" | "bulk" = "swap"
	local autoTrade = true
	local giveItemId: string? = nil
	local wantItemId: string? = nil
	local catalog: { any }? = nil
	local pickSpawned: { Instance } = {}

	local function rowSet(row: Frame, itemId: string?, name: string?, imageId: string?)
		Components.setIcon(row:WaitForChild("ItemButton") :: any, { imageId = imageId })
		;(row:WaitForChild("ItemName") :: TextLabel).Text = name or "click icon to pick"
	end

	-- picker source: "inventory" (give) or "catalog" (want/bulk)
	local function openPicker(source: string, onPick: (itemId: string, name: string, imageId: string?) -> ())
		for _, inst in pickSpawned do
			inst:Destroy()
		end
		table.clear(pickSpawned)

		local entries = {}
		if source == "inventory" then
			local stats = EconomyController.stats:get()
			for itemId, count in InventoryController.inventory:get() do
				local snap = stats[itemId]
				table.insert(entries, {
					itemId = itemId,
					name = snap and snap.name or itemId,
					imageId = snap and snap.imageId or nil,
					count = count,
				})
			end
		elseif catalog then
			for _, entry in catalog do
				table.insert(entries, entry)
			end
		end
		table.sort(entries, function(a, b)
			return a.name < b.name
		end)

		for _, entry in entries do
			local tile = pickTile:Clone()
			tile.Name = entry.itemId
			tile.Visible = true
			Components.setIcon(tile:WaitForChild("Icon") :: ImageLabel, entry)
			;(tile:WaitForChild("ItemName") :: TextLabel).Text = entry.name
			;(tile:WaitForChild("CountLabel") :: TextLabel).Text = entry.count and ("x" .. entry.count) or ""
			tile.Activated:Connect(function()
				picker.Visible = false
				onPick(entry.itemId, entry.name, entry.imageId)
			end)
			tile.Parent = pickGrid
			table.insert(pickSpawned, tile)
		end
		picker.Visible = true
	end

	local giveItemBtn = giveRow:WaitForChild("ItemButton") :: ImageButton
	giveItemBtn.Activated:Connect(function()
		openPicker("inventory", function(itemId, name, imageId)
			giveItemId = itemId
			rowSet(giveRow, itemId, name, imageId)
		end)
	end)
	local wantItemBtn = wantRow:WaitForChild("ItemButton") :: ImageButton
	wantItemBtn.Activated:Connect(function()
		openPicker("catalog", function(itemId, name, imageId)
			wantItemId = itemId
			rowSet(wantRow, itemId, name, imageId)
		end)
	end)

	local function applyMode()
		modeBtn.Text = mode == "swap" and "Mode: Swap" or "Mode: Bulk buy"
		autoBtn.Visible = mode == "swap"
		local giveHeader = giveRow:WaitForChild("Header") :: TextLabel
		local wantHeader = wantRow:WaitForChild("Header") :: TextLabel
		if mode == "swap" then
			giveHeader.Text = "YOU GIVE (escrowed when you post)"
			wantHeader.Text = "YOU WANT"
			giveRow.Visible = true
		else
			-- bulk: only the want row matters (item + count) + gems box on want row
			giveHeader.Text = ""
			wantHeader.Text = "YOU BUY (count) FOR (total gems, escrowed)"
			giveRow.Visible = false
		end
	end
	modeBtn.Activated:Connect(function()
		mode = mode == "swap" and "bulk" or "swap"
		applyMode()
	end)
	autoBtn.Activated:Connect(function()
		autoTrade = not autoTrade
		autoBtn.Text = autoTrade and "Auto-trade: ON" or "Auto-trade: OFF"
		autoBtn.BackgroundColor3 = autoTrade and Theme.Good or Theme.Warn
	end)

	local postBtn = panel:WaitForChild("PostButton") :: TextButton
	postBtn.Activated:Connect(function()
		giveItemId, wantItemId = nil, nil
		rowSet(giveRow, nil, nil, nil)
		rowSet(wantRow, nil, nil, nil)
		applyMode()
		post.Visible = true
		if catalog == nil then
			task.spawn(function()
				local result = Net.invoke("GetCatalog")
				if result.ok then
					catalog = result.items
				end
			end)
		end
	end)

	local function readOffer(row: Frame, itemId: string?): any
		local count = tonumber((row:WaitForChild("CountBox") :: TextBox).Text) or 0
		local gems = tonumber((row:WaitForChild("GemsBox") :: TextBox).Text) or 0
		local items = {}
		if itemId and count >= 1 then
			items[itemId] = math.floor(count)
		end
		return { items = items, gems = math.max(0, math.floor(gems)) }
	end

	submitBtn.Activated:Connect(function()
		local payload: any
		if mode == "swap" then
			payload = {
				kind = "swap",
				give = readOffer(giveRow, giveItemId),
				want = readOffer(wantRow, wantItemId),
				autoTrade = autoTrade,
			}
		else
			local count = tonumber((wantRow:WaitForChild("CountBox") :: TextBox).Text) or 0
			local gems = tonumber((wantRow:WaitForChild("GemsBox") :: TextBox).Text) or 0
			payload = {
				kind = "bulk",
				itemId = wantItemId,
				count = math.floor(count),
				gems = math.floor(gems),
			}
			if payload.itemId == nil then
				toast("Pick the item you want to buy.", Theme.Bad)
				return
			end
		end
		local result = invokeAction(function()
			return Net.invoke("PostListing", payload)
		end)
		if result then
			if result.ok then
				toast("Posted to the board!", Theme.Good)
				post.Visible = false
				refresh()
			else
				toast("Couldn't post: " .. tostring(result.err), Theme.Bad)
			end
		end
	end)
end

return BoardScreen
