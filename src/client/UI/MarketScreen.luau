--!strict
-- Market tab wiring (lives inside BoardPanel; BoardScreen switches to it).
-- The player-to-player market for gem-priced orders, in two views:
--   * HOME — searchable directory of every item: live Value/RAP and the best
--     "buy for" (cheapest sell listing) / "sell for" (highest buy order).
--   * BOOK — one item's order book: sellers left, buyers right. Buy from an
--     ask, sell into a bid, or post your own from here (item prefilled).
-- Gems are the PRICE AXIS, never a row: every order is items priced in gems.
-- Reads hit the server's in-memory book index (GetMarketSummary/GetItemBook);
-- writes reuse the existing board remotes, so fills keep feeding RAP/Value.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Tax = require(ReplicatedStorage.Shared.Util.Tax)
local Net = require(script.Parent.Parent.Net)
local InventoryController = require(script.Parent.Parent.Controllers.InventoryController)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local NotificationController = require(script.Parent.Parent.Controllers.NotificationController)

local MarketScreen = {}

function MarketScreen.wire(gui: ScreenGui, tooltip: any, toast: (text: string, color: Color3) -> ())
	local panel = gui:WaitForChild("BoardPanel") :: Frame
	local home = panel:WaitForChild("MarketHome") :: Frame
	local homeSearch = home:WaitForChild("SearchBox") :: TextBox
	local marketList = home:WaitForChild("MarketList") :: ScrollingFrame
	local rowTemplate = marketList:WaitForChild("MarketRow") :: TextButton
	local homeEmpty = home:WaitForChild("HomeEmptyLabel") :: TextLabel

	local book = panel:WaitForChild("MarketBook") :: Frame
	local backBtn = book:WaitForChild("BackButton") :: TextButton
	local bookIcon = book:WaitForChild("Icon") :: ImageLabel
	local bookName = book:WaitForChild("ItemName") :: TextLabel
	local bookStats = book:WaitForChild("StatsLine") :: TextLabel
	local postSellBtn = book:WaitForChild("PostSellButton") :: TextButton
	local postBuyBtn = book:WaitForChild("PostBuyButton") :: TextButton
	local sellers = book:WaitForChild("SellersPanel") :: Frame
	local buyers = book:WaitForChild("BuyersPanel") :: Frame

	local post = panel:WaitForChild("PostPanel") :: Frame
	local wantRow = post:WaitForChild("WantRow") :: Frame
	local postTitle = post:WaitForChild("Title") :: TextLabel
	local submitBtn = post:WaitForChild("SubmitButton") :: TextButton

	local active = false -- Market tab selected AND board panel open
	local currentItemId: string? = nil -- nil = home, set = that item's book
	local summary: { any }? = nil -- last directory payload (itemId-keyed render source)
	local busy = false
	-- Rows update IN PLACE across refreshes (keyed by itemId / listing id).
	-- The market refreshes every second or so while bots trade; rebuilding
	-- rows wholesale would destroy a button mid-click and eat the input.
	local homeRows: { [string]: { row: TextButton, update: (any) -> () } } = {}
	local orderRows: { [string]: { row: Frame, setListing: (any) -> (), order: number } } = {}

	local function invokeAction(fn: () -> any): any
		if busy then
			return nil
		end
		busy = true
		local result = fn()
		busy = false
		return result
	end

	-- snapshot for an item: live stats push first, else the summary row
	local function snapshotFor(itemId: string): any?
		local live = EconomyController.get(itemId)
		if live then
			return live
		end
		for _, row in summary or {} do
			if row.itemId == itemId then
				return row
			end
		end
		return nil
	end

	----------------------------------------------------------------------
	-- HOME: the directory
	----------------------------------------------------------------------

	local function gemsText(n: number?): string
		return n and (tostring(n) .. " gems") or "—"
	end

	local function ensureHomeRow(entry: any): { row: TextButton, update: (any) -> () }
		local cached = homeRows[entry.itemId]
		if cached then
			return cached
		end
		local row = rowTemplate:Clone()
		row.Name = entry.itemId
		;(row:WaitForChild("ItemName") :: TextLabel).Text = entry.name
		local rarity = row:WaitForChild("Rarity") :: TextLabel
		rarity.Text = entry.rarity or ""
		rarity.TextColor3 = Components.rarityColor(entry.rarity)
		;(row:WaitForChild("Stripe") :: Frame).BackgroundColor3 = Components.rarityColor(entry.rarity)
		Components.setIcon(row:WaitForChild("Icon") :: ImageLabel, entry)
		tooltip.attach(row, function()
			return snapshotFor(entry.itemId), InventoryController.inventory:get()[entry.itemId]
		end)
		row.Activated:Connect(function()
			MarketScreen.openItem(entry.itemId)
		end)
		local valueLabel = row:WaitForChild("ValueLabel") :: TextLabel
		local rapLabel = row:WaitForChild("RapLabel") :: TextLabel
		local buyLabel = row:WaitForChild("BuyLabel") :: TextLabel
		local sellLabel = row:WaitForChild("SellLabel") :: TextLabel
		local entryCache = {
			row = row,
			update = function(e: any)
				valueLabel.Text = Components.statText(e.value)
				rapLabel.Text = Components.statText(e.rap)
				buyLabel.Text = gemsText(e.bestAsk)
				sellLabel.Text = gemsText(e.bestBid)
			end,
		}
		row.Parent = marketList
		homeRows[entry.itemId] = entryCache
		return entryCache
	end

	local function renderHome()
		if summary == nil then
			-- never leave the directory as a blank void; say what's happening
			homeEmpty.Text = "Loading the market…"
			homeEmpty.Visible = true
			return
		end
		local query = homeSearch.Text:lower()
		local rows = {}
		for _, entry in summary :: { any } do
			if query == "" or entry.name:lower():find(query, 1, true) then
				table.insert(rows, entry)
			end
		end
		-- most valuable first: the natural "front page" of a market
		table.sort(rows, function(a, b)
			local av = a.value and a.value.value or 0
			local bv = b.value and b.value.value or 0
			if av ~= bv then
				return av > bv
			end
			return a.name < b.name
		end)

		local shown: { [string]: boolean } = {}
		for order, entry in rows do
			local cached = ensureHomeRow(entry)
			cached.update(entry)
			cached.row.LayoutOrder = order
			cached.row.Visible = true
			shown[entry.itemId] = true
		end
		for itemId, cached in homeRows do
			if not shown[itemId] then
				cached.row.Visible = false
			end
		end
		homeEmpty.Text = "No items match that search."
		homeEmpty.Visible = #rows == 0
	end

	-- one GetMarketSummary in flight; bursts collapse into a trailing call
	local fetchingHome = false
	local homeQueued = false
	local function refreshHome()
		if fetchingHome then
			homeQueued = true
			return
		end
		fetchingHome = true
		task.spawn(function()
			-- pcall'd so a dropped payload can't kill the thread mid-loop: that
			-- would leave fetchingHome stuck true and the market would never
			-- refresh again for the rest of the session.
			pcall(function()
				repeat
					homeQueued = false
					local result = Net.invoke("GetMarketSummary")
					if result and result.ok then
						summary = result.items
						if active and currentItemId == nil then
							renderHome()
						end
						-- server is still warming its item cache: the list it just
						-- sent is partial, so keep asking until it's complete
						if result.warming and active then
							homeQueued = true
						end
					elseif summary == nil and active then
						-- nothing to show AND the read failed: keep trying rather
						-- than stranding the directory on "Loading the market…"
						homeQueued = true
					end
					if homeQueued then
						task.wait(0.5)
					end
				until not homeQueued
			end)
			fetchingHome = false
		end)
	end

	local searchDebounce: thread? = nil
	homeSearch:GetPropertyChangedSignal("Text"):Connect(function()
		if searchDebounce then
			task.cancel(searchDebounce)
		end
		searchDebounce = task.delay(0.15, function()
			searchDebounce = nil
			renderHome()
		end)
	end)

	----------------------------------------------------------------------
	-- BOOK: one item's orders
	----------------------------------------------------------------------

	local refreshBook -- fwd decl

	-- One order row, wired ONCE and updated in place on refresh. Sellers' rows
	-- let you BUY copies; buyers' rows let you SELL into their order. Your own
	-- rows show Cancel instead.
	local function ensureOrderRow(listing: any, template: Frame, parent: ScrollingFrame, isAsk: boolean)
		local cached = orderRows[listing.id]
		if cached then
			cached.setListing(listing)
			return cached
		end
		local row = template:Clone()
		row.Name = "order_" .. listing.id
		local poster = row:WaitForChild("PosterLabel") :: TextLabel
		local price = row:WaitForChild("PriceLabel") :: TextLabel
		local stock = row:WaitForChild("StockLabel") :: TextLabel
		local countBox = row:WaitForChild("CountBox") :: TextBox
		local action = row:WaitForChild("ActionButton") :: TextButton

		local current = listing -- latest server view; buttons read this
		poster.Text = listing.posterName .. (listing.mine and " (you)" or "")
		price.Text = tostring(listing.gemsPerCopy) .. " gems each"

		local function updateStock()
			local remaining = current.remainingCount
			if current.mine then
				stock.Text = isAsk and (remaining .. " still for sale") or ("still wants " .. remaining)
				return
			end
			local n = math.clamp(math.floor(tonumber(countBox.Text) or 0), 0, remaining)
			if n < 1 then
				stock.Text = isAsk and (remaining .. " for sale") or ("wants " .. remaining .. " more")
			elseif isAsk then
				stock.Text = ("Buy %d for %d gems"):format(n, n * current.gemsPerCopy)
			else
				stock.Text = ("Sell %d, get %d gems"):format(n, Tax.split(n * current.gemsPerCopy))
			end
		end

		if listing.mine then
			countBox.Visible = false
			action.Text = "Cancel"
			action.BackgroundColor3 = Theme.Bad
			action.Activated:Connect(function()
				local result = invokeAction(function()
					return Net.invoke("CancelListing", current.id)
				end)
				if result and result.ok then
					toast("Order cancelled — escrow returned.", Theme.Warn)
				end
				refreshBook()
			end)
		else
			if isAsk then
				countBox.Text = "1"
				action.Text = "Buy"
				action.BackgroundColor3 = Theme.Good
			else
				local owned = InventoryController.inventory:get()[listing.itemId] or 0
				countBox.Text = tostring(math.clamp(owned, 0, listing.remainingCount))
				action.Text = "Sell"
				action.BackgroundColor3 = Theme.Accent
			end
			countBox:GetPropertyChangedSignal("Text"):Connect(updateStock)
			action.Activated:Connect(function()
				local n = math.floor(tonumber(countBox.Text) or 0)
				if n < 1 then
					toast(isAsk and "Enter how many to buy." or "Enter how many to sell.", Theme.Bad)
					return
				end
				local result = invokeAction(function()
					return Net.invoke(isAsk and "BuyFromListing" or "ContributeBulk", current.id, n)
				end)
				if result then
					if result.ok and isAsk then
						toast(("Bought %d for %d gems!"):format(result.count, result.spent), Theme.Good)
					elseif result.ok then
						toast(("Sold %d for %d gems!"):format(result.count, result.payout), Theme.Good)
					elseif result.err == "insufficient_gems" then
						toast("Not enough gems!", Theme.Bad)
					elseif result.err == "insufficient_items" then
						toast("You don't own that many!", Theme.Bad)
					elseif result.err == "gone" or result.err == "sold_out" or result.err == "filled" then
						toast("Too late — that order just closed.", Theme.Warn)
					else
						toast("Failed: " .. tostring(result.err), Theme.Bad)
					end
				end
				refreshBook()
			end)
		end

		cached = {
			row = row,
			order = 0,
			setListing = function(l: any)
				current = l
				updateStock()
			end,
		}
		updateStock()
		row.Visible = true
		row.Parent = parent
		orderRows[listing.id] = cached
		return cached
	end

	local function renderBook(asks: { any }, bids: { any })
		local sellersList = sellers:WaitForChild("BookList") :: ScrollingFrame
		local buyersList = buyers:WaitForChild("BookList") :: ScrollingFrame
		local sellersTemplate = sellersList:WaitForChild("BookRow") :: Frame
		local buyersTemplate = buyersList:WaitForChild("BookRow") :: Frame

		local seen: { [string]: boolean } = {}
		for order, l in asks do
			local cached = ensureOrderRow(l, sellersTemplate, sellersList, true)
			cached.row.LayoutOrder = order
			seen[l.id] = true
		end
		for order, l in bids do
			local cached = ensureOrderRow(l, buyersTemplate, buyersList, false)
			cached.row.LayoutOrder = order
			seen[l.id] = true
		end
		-- listings that closed since the last refresh
		for id, cached in orderRows do
			if not seen[id] then
				cached.row:Destroy()
				orderRows[id] = nil
			end
		end
		;(sellers:WaitForChild("EmptyLabel") :: TextLabel).Visible = #asks == 0
		;(buyers:WaitForChild("EmptyLabel") :: TextLabel).Visible = #bids == 0

		-- Middle: halfway between the best bid and the best ask — the price the
		-- item is really "worth" right now. The server sorts asks cheapest-first
		-- and bids highest-first, so the best of each is simply the first row.
		-- With only one side quoted there is no midpoint, and inventing one from
		-- a single price would be a made-up number, so say which side is missing.
		local mid = book:WaitForChild("MidLabel") :: TextLabel
		local bestAsk = asks[1] and asks[1].gemsPerCopy
		local bestBid = bids[1] and bids[1].gemsPerCopy
		if bestAsk and bestBid then
			local m = (bestAsk + bestBid) / 2
			-- halves happen whenever the spread is odd; keep one decimal then
			local shown = m % 1 == 0 and tostring(math.floor(m)) or ("%.1f"):format(m)
			mid.Text = ("Middle: %s gems   (buy %d / sell %d)"):format(shown, bestAsk, bestBid)
			mid.TextColor3 = Theme.Gem
		elseif bestAsk then
			mid.Text = ("Middle: — no buy orders   (cheapest %d gems)"):format(bestAsk)
			mid.TextColor3 = Theme.TextDim
		elseif bestBid then
			mid.Text = ("Middle: — nothing for sale   (best offer %d gems)"):format(bestBid)
			mid.TextColor3 = Theme.TextDim
		else
			mid.Text = "Middle: — no orders yet"
			mid.TextColor3 = Theme.TextDim
		end
	end

	local function clearOrderRows()
		for id, cached in orderRows do
			cached.row:Destroy()
			orderRows[id] = nil
		end
	end

	local function renderBookHeader()
		local itemId = currentItemId
		if itemId == nil then
			return
		end
		local snap = snapshotFor(itemId)
		bookName.Text = snap and snap.name or itemId
		Components.setIcon(bookIcon, snap)
		bookStats.Text = snap
				and ("Value %s  ·  RAP %s  ·  %s"):format(
					Components.statText(snap.value),
					Components.statText(snap.rap),
					Components.existenceText(snap)
				)
			or ""
	end

	local fetchingBook = false
	local bookQueued = false
	refreshBook = function()
		local itemId = currentItemId
		if itemId == nil then
			return
		end
		if fetchingBook then
			bookQueued = true
			return
		end
		fetchingBook = true
		task.spawn(function()
			pcall(function()
				repeat
					bookQueued = false
					local result = Net.invoke("GetItemBook", itemId)
					if result and result.ok and active and currentItemId == itemId then
						renderBookHeader()
						renderBook(result.asks, result.bids)
					end
					if bookQueued then
						task.wait(0.5)
					end
				until not bookQueued
			end)
			fetchingBook = false
		end)
	end

	----------------------------------------------------------------------
	-- POST modal: sell listing / buy order for the item you're looking at
	----------------------------------------------------------------------

	local postKind: "sell" | "bulk" = "sell"
	local postCloseBtn = post:WaitForChild("CloseButton") :: TextButton
	postCloseBtn.Activated:Connect(function()
		post.Visible = false
	end)

	local function openPost(kind: "sell" | "bulk")
		local itemId = currentItemId
		if itemId == nil then
			return
		end
		postKind = kind
		local snap = snapshotFor(itemId)
		local name = snap and snap.name or itemId
		local header = wantRow:WaitForChild("Header") :: TextLabel
		local countHeader = wantRow:WaitForChild("CountHeader") :: TextLabel
		local gemsHeader = wantRow:WaitForChild("GemsHeader") :: TextLabel
		local countBox = wantRow:WaitForChild("CountBox") :: TextBox
		local gemsBox = wantRow:WaitForChild("GemsBox") :: TextBox
		Components.setIcon(wantRow:WaitForChild("ItemButton") :: any, snap)
		;(wantRow:WaitForChild("ItemName") :: TextLabel).Text = name
		if kind == "sell" then
			local owned = InventoryController.inventory:get()[itemId] or 0
			postTitle.Text = "Sell " .. name
			header.Text = ("YOUR COPIES GO UP FOR SALE (you own %d)"):format(owned)
			countHeader.Text = "how many"
			gemsHeader.Text = "gems each"
			countBox.Text = tostring(math.max(owned, 1))
		else
			postTitle.Text = "Buy order: " .. name
			header.Text = "OFFER GEMS FOR COPIES (gems escrowed until filled)"
			countHeader.Text = "how many"
			gemsHeader.Text = "total gems"
			countBox.Text = "1"
		end
		gemsBox.Text = ""
		post.Visible = true
	end

	postSellBtn.Activated:Connect(function()
		openPost("sell")
	end)
	postBuyBtn.Activated:Connect(function()
		openPost("bulk")
	end)

	submitBtn.Activated:Connect(function()
		local itemId = currentItemId
		if itemId == nil then
			return
		end
		local countBox = wantRow:WaitForChild("CountBox") :: TextBox
		local gemsBox = wantRow:WaitForChild("GemsBox") :: TextBox
		local count = math.floor(tonumber(countBox.Text) or 0)
		local gems = math.floor(tonumber(gemsBox.Text) or 0)
		if count < 1 or gems < 1 then
			toast("Fill in both numbers first.", Theme.Bad)
			return
		end
		local payload: any
		if postKind == "sell" then
			payload = { kind = "sell", itemId = itemId, count = count, gemsPerCopy = gems }
		else
			payload = { kind = "bulk", itemId = itemId, count = count, gems = gems }
		end
		local result = invokeAction(function()
			return Net.invoke("PostListing", payload)
		end)
		if result == nil then
			return
		end
		if result.ok then
			toast("Posted to the Market!", Theme.Good)
			post.Visible = false
			refreshBook()
			refreshHome()
			NotificationController.promptOptIn(
				postKind == "sell" and "Enable notifications so we can tell you when your listing sells!"
					or "Enable notifications so we can tell you when your buy order fills!",
				toast
			)
		elseif result.err == "insufficient_items" then
			toast("You don't own that many!", Theme.Bad)
		elseif result.err == "insufficient_gems" then
			toast("Not enough gems to escrow that order!", Theme.Bad)
		elseif result.err == "gems_too_low" then
			toast("Offer at least 1 gem per copy.", Theme.Bad)
		else
			toast("Couldn't post: " .. tostring(result.err), Theme.Bad)
		end
	end)

	----------------------------------------------------------------------
	-- View switching + liveness
	----------------------------------------------------------------------

	local function showHome()
		currentItemId = nil
		clearOrderRows()
		book.Visible = false
		home.Visible = true
		renderHome() -- instant paint from cache
		refreshHome()
	end

	backBtn.Activated:Connect(showHome)

	function MarketScreen.openItem(itemId: string)
		if currentItemId ~= itemId then
			clearOrderRows() -- rows from another item's book
		end
		currentItemId = itemId
		home.Visible = false
		book.Visible = true
		EconomyController.ensure({ itemId })
		renderBookHeader()
		refreshBook()
	end

	-- BoardScreen calls these on tab switches / panel close.
	function MarketScreen.show()
		active = true
		-- A stale filter survives a panel close, so reopening the board would
		-- land on an empty directory that reads as a broken market.
		homeSearch.Text = ""
		showHome()
	end

	function MarketScreen.hide()
		active = false
		clearOrderRows()
		home.Visible = false
		book.Visible = false
		post.Visible = false
	end

	-- fills happening anywhere (bots included) show up while you watch
	local activityDebounce: thread? = nil
	Net.on("BoardActivity", function()
		if not active or activityDebounce then
			return
		end
		activityDebounce = task.delay(1, function()
			activityDebounce = nil
			if not active then
				return
			end
			if currentItemId then
				refreshBook()
			else
				refreshHome()
			end
		end)
	end)
end

return MarketScreen
