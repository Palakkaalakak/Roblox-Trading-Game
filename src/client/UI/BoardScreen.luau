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
local State = require(ReplicatedStorage.Shared.Util.State)
local Tax = require(ReplicatedStorage.Shared.Util.Tax)
local Net = require(script.Parent.Parent.Net)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local TradeController = require(script.Parent.Parent.Controllers.TradeController)
local NotificationController = require(script.Parent.Parent.Controllers.NotificationController)
local TradeScreen = require(script.Parent.TradeScreen)

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
	local activeTab: "swap" | "bulk" | "sell" = "swap"

	local function clearRendered()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
	end

	-- itemId (optional): when present, hovering shows the item's live stats
	-- (Value/RAP/existence). Gem chips pass nil and just show name/icon.
	local function addChip(holder: Frame, imageId: string?, name: string, countText: string, order: number, itemId: string?)
		local chip = chipTemplate:Clone()
		chip.Visible = true
		chip.LayoutOrder = order
		Components.setIcon(chip:WaitForChild("Icon") :: ImageLabel, { imageId = imageId, name = name })
		;(chip:WaitForChild("CountLabel") :: TextLabel).Text = countText
		chip.Parent = holder
		table.insert(spawned, chip)
		if itemId then
			EconomyController.ensure({ itemId })
		end
		tooltip.attach(chip, function()
			if itemId then
				return EconomyController.get(itemId) or { name = name, imageId = imageId }, nil
			end
			return { name = name, imageId = imageId }, nil
		end)
	end

	-- Item cards only in the chip row; gems are never a fake item card — just
	-- an icon + "+N gems (after tax)" line under the holder.
	local function fillOfferChips(holder: Frame, gemsIcon: ImageLabel, gemsLabel: TextLabel, offer: any)
		local order = 0
		for _, entry in offer.items do
			order += 1
			addChip(holder, entry.imageId, entry.name, "x" .. entry.count, order, entry.itemId)
		end
		local hasGems = offer.gems > 0
		gemsIcon.Visible = hasGems
		gemsLabel.Text = hasGems and ("+%d gems (after tax)"):format(Tax.split(offer.gems)) or ""
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
		local giveGemsIcon = row:WaitForChild("GiveGemsIcon") :: ImageLabel
		local giveGemsLabel = row:WaitForChild("GiveGemsLabel") :: TextLabel
		local wantGemsIcon = row:WaitForChild("WantGemsIcon") :: ImageLabel
		local wantGemsLabel = row:WaitForChild("WantGemsLabel") :: TextLabel
		local info = row:WaitForChild("InfoLabel") :: TextLabel
		local badge = row:WaitForChild("Badge") :: TextLabel
		local countBox = row:WaitForChild("CountBox") :: TextBox
		local action = row:WaitForChild("ActionButton") :: TextButton
		;(row:WaitForChild("PosterLabel") :: TextLabel).Text = listing.posterName
			.. (listing.mine and " (you)" or "")

		if listing.kind == "swap" then
			badge.Text = listing.autoTrade and "AUTO-TRADE" or "ASK FIRST"
			badge.TextColor3 = listing.autoTrade and Theme.Good or Theme.Warn
			fillOfferChips(giveHolder, giveGemsIcon, giveGemsLabel, listing.give) -- what the poster GIVES you
			fillOfferChips(wantHolder, wantGemsIcon, wantGemsLabel, listing.want) -- what they WANT from you
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
		elseif listing.kind == "bulk" then
			badge.Text = "BULK BUY"
			badge.TextColor3 = Theme.Gem
			addChip(giveHolder, Theme.Icons.Gem, "Gems", tostring(listing.gemsPerCopy) .. "/copy", 1)
			addChip(wantHolder, listing.imageId, listing.itemName, "x" .. listing.remainingCount, 1, listing.itemId)

			-- stats block: per-unit AND total (× what's still wanted) Est.
			-- Value / RAP / Store Cost, plus (for contributors) a live payout
			-- preview that updates as they type how many they're giving.
			EconomyController.ensure({ listing.itemId })
			local function updateInfo()
				local snap = EconomyController.get(listing.itemId)
				local remaining = listing.remainingCount
				local lines = {
					("Value: %s ea · %s total"):format(
						Components.statText(snap and snap.value),
						snap and snap.value and snap.value.state == "Known"
								and tostring(snap.value.value * remaining)
							or "N/A"
					),
					("RAP: %s ea · Store Cost: %s ea"):format(
						Components.statText(snap and snap.rap),
						Components.storeCostText(snap)
					),
				}
				if not listing.mine and countBox.Visible then
					local n = math.clamp(tonumber(countBox.Text) or 0, 0, remaining)
					local net = Tax.split(n * listing.gemsPerCopy)
					table.insert(lines, ("Give %d → you get %d gems (after tax)"):format(n, net))
				end
				info.Text = table.concat(lines, "\n")
			end
			-- Observe fires immediately + on every stat change; disconnect
			-- when this row is torn down (refresh() rebuilds all rows) so
			-- repeated board refreshes don't leak one connection per row.
			local statsConn = State.Observe(EconomyController.stats, updateInfo)
			row.Destroying:Connect(function()
				statsConn:Disconnect()
			end)

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
				countBox:GetPropertyChangedSignal("Text"):Connect(updateInfo)
				updateInfo()
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
							toast(("Contributed %d — earned %d gems (after tax)!"):format(result.count, result.payout), Theme.Good)
						else
							toast("Couldn't contribute: " .. tostring(result.err), Theme.Bad)
						end
					end
					refresh()
				end)
			end
		else -- sell (gem-only shop)
			badge.Text = "FOR SALE"
			badge.TextColor3 = Theme.Good
			addChip(giveHolder, listing.imageId, listing.itemName, "x" .. listing.remainingCount, 1, listing.itemId)
			addChip(wantHolder, Theme.Icons.Gem, "Gems", tostring(listing.gemsPerCopy) .. "/ea", 1)

			EconomyController.ensure({ listing.itemId })
			local function updateInfo()
				local snap = EconomyController.get(listing.itemId)
				local remaining = listing.remainingCount
				local lines = {
					("Value: %s ea · %s total"):format(
						Components.statText(snap and snap.value),
						snap and snap.value and snap.value.state == "Known"
								and tostring(snap.value.value * remaining)
							or "N/A"
					),
					("RAP: %s ea · Store Cost: %s ea"):format(
						Components.statText(snap and snap.rap),
						Components.storeCostText(snap)
					),
				}
				if not listing.mine and countBox.Visible then
					local n = math.clamp(tonumber(countBox.Text) or 0, 0, remaining)
					table.insert(lines, ("Buy %d → costs %d gems"):format(n, n * listing.gemsPerCopy))
				end
				info.Text = table.concat(lines, "\n")
			end
			local statsConn = State.Observe(EconomyController.stats, updateInfo)
			row.Destroying:Connect(function()
				statsConn:Disconnect()
			end)

			if listing.mine then
				action.Text = "Cancel"
				action.BackgroundColor3 = Theme.Bad
				action.Activated:Connect(function()
					local result = invokeAction(function()
						return Net.invoke("CancelListing", listing.id)
					end)
					if result and result.ok then
						toast("Sale cancelled — items returned.", Theme.Warn)
					end
					refresh()
				end)
			else
				countBox.Visible = true
				countBox.Text = "1"
				countBox:GetPropertyChangedSignal("Text"):Connect(updateInfo)
				updateInfo()
				action.Text = "Buy"
				action.BackgroundColor3 = Theme.Good
				action.Activated:Connect(function()
					local n = tonumber(countBox.Text)
					if n == nil or n < 1 then
						toast("Enter how many to buy.", Theme.Bad)
						return
					end
					local result = invokeAction(function()
						return Net.invoke("BuyFromListing", listing.id, math.floor(n))
					end)
					if result then
						if result.ok then
							toast(("Bought %d for %d gems!"):format(result.count, result.spent), Theme.Good)
						elseif result.err == "insufficient_gems" then
							toast("Not enough gems!", Theme.Bad)
						else
							toast("Couldn't buy: " .. tostring(result.err), Theme.Bad)
						end
					end
					refresh()
				end)
			end
		end
	end

	local function renderBoard(listings: { any })
		clearRendered()
		local shown = 0
		for _, listing in listings do
			if listing.kind == activeTab then
				shown += 1
				renderListing(listing, shown)
			end
		end
		emptyLabel.Visible = shown == 0
		emptyLabel.Text = ({
			swap = "No swap trades posted — hit + to post one!",
			bulk = "No bulk buy orders — hit + to post one!",
			sell = "Nothing for sale — hit + to list items for gems!",
		})[activeTab]
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
		Components.closeOtherPanels(panel)
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

	-- modal handles the gem-only kinds (bulk buy order / sell listing); swap
	-- posting is the real trade window (compose mode)
	local modalKind: "bulk" | "sell" = "bulk"
	modeBtn.Visible = false
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
			EconomyController.ensure({ entry.itemId })
			tooltip.attach(tile, function()
				return EconomyController.get(entry.itemId) or entry, entry.count
			end)
			tile.Activated:Connect(function()
				picker.Visible = false
				onPick(entry.itemId, entry.name, entry.imageId)
			end)
			tile.Parent = pickGrid
			table.insert(pickSpawned, tile)
		end
		picker.Visible = true
	end

	autoBtn.Visible = false
	giveRow.Visible = false -- gem-only modals use only the want row (item + fields)

	-- gem-only modal: item picker (catalog) always on the want row; the two
	-- number fields mean different things per kind (bulk vs sell)
	local postTitle = post:WaitForChild("Title") :: TextLabel
	local function applyModalKind()
		local wantHeader = wantRow:WaitForChild("Header") :: TextLabel
		if modalKind == "bulk" then
			postTitle.Text = "Bulk buy order"
			wantHeader.Text = "BUY (count) FOR (total gems, escrowed)"
		else
			postTitle.Text = "Sell for gems"
			wantHeader.Text = "SELL (count) AT (gems each) — items escrowed"
		end
	end

	local wantItemBtn = wantRow:WaitForChild("ItemButton") :: ImageButton
	wantItemBtn.Activated:Connect(function()
		-- sell can only list items you own; bulk can target any catalog item
		openPicker(modalKind == "sell" and "inventory" or "catalog", function(itemId, name, imageId)
			wantItemId = itemId
			rowSet(wantRow, itemId, name, imageId)
		end)
	end)

	local function openModal(kind: "bulk" | "sell")
		modalKind = kind
		wantItemId = nil
		rowSet(wantRow, nil, nil, nil)
		applyModalKind()
		post.Visible = true
		if catalog == nil then
			task.spawn(function()
				local result = Net.invoke("GetCatalog")
				if result.ok then
					catalog = result.items
				end
			end)
		end
	end

	-- context-aware post button: acts on the active tab
	local postBtn = panel:WaitForChild("PostButton") :: TextButton
	local function updatePostBtn()
		postBtn.Text = ({
			swap = "+ Post swap",
			bulk = "+ Bulk order",
			sell = "+ Sell items",
		})[activeTab]
	end
	postBtn.Activated:Connect(function()
		if activeTab == "swap" then
			-- the STANDARD trade window in compose mode -> POST TO BOARD
			panel.Visible = false
			TradeScreen.openCompose(function(give, want, auto)
				task.spawn(function()
					local result = Net.invoke("PostListing", {
						kind = "swap",
						give = give,
						want = want,
						autoTrade = auto,
					})
					toast(result.ok and "Posted to the board!" or ("Couldn't post: " .. tostring(result.err)), result.ok and Theme.Good or Theme.Bad)
					if result.ok then
						-- they'll get notified later either way — "someone
						-- wants this" (ask-first) or "it went through" (auto)
						NotificationController.promptOptIn(
							"Enable notifications so we can tell you about activity on this trade!",
							toast
						)
					end
					BoardScreen.open()
				end)
			end)
		else
			openModal(activeTab :: any)
		end
	end)

	-- tab buttons
	local tabRow = panel:WaitForChild("TabRow") :: Frame
	local tabButtons = {
		swap = tabRow:WaitForChild("TabNormal") :: TextButton,
		bulk = tabRow:WaitForChild("TabBulk") :: TextButton,
		sell = tabRow:WaitForChild("TabGem") :: TextButton,
	}
	local function selectTab(tab: "swap" | "bulk" | "sell")
		activeTab = tab
		for key, btn in tabButtons do
			btn.BackgroundColor3 = (key == tab) and Theme.Accent or Theme.BgLight
		end
		updatePostBtn()
		if lastListings then
			renderBoard(lastListings)
		end
	end
	for tab, btn in tabButtons do
		btn.Activated:Connect(function()
			selectTab(tab :: any)
		end)
	end
	selectTab("swap")

	-- public: open the board straight to a given tab (pillar deep-link / tests)
	function BoardScreen.openTab(tab: "swap" | "bulk" | "sell")
		BoardScreen.open()
		selectTab(tab)
	end

	submitBtn.Activated:Connect(function()
		if wantItemId == nil then
			toast("Pick an item first.", Theme.Bad)
			return
		end
		local count = math.floor(tonumber((wantRow:WaitForChild("CountBox") :: TextBox).Text) or 0)
		local gems = math.floor(tonumber((wantRow:WaitForChild("GemsBox") :: TextBox).Text) or 0)
		local payload: any
		if modalKind == "bulk" then
			payload = { kind = "bulk", itemId = wantItemId, count = count, gems = gems }
		else
			payload = { kind = "sell", itemId = wantItemId, count = count, gemsPerCopy = gems }
		end
		local result = invokeAction(function()
			return Net.invoke("PostListing", payload)
		end)
		if result then
			if result.ok then
				toast("Posted to the board!", Theme.Good)
				post.Visible = false
				refresh()
				NotificationController.promptOptIn(
					modalKind == "bulk" and "Enable notifications so we can tell you when your bulk order fills!"
						or "Enable notifications so we can tell you when your listing sells!",
					toast
				)
			else
				toast("Couldn't post: " .. tostring(result.err), Theme.Bad)
			end
		end
	end)
end

return BoardScreen
