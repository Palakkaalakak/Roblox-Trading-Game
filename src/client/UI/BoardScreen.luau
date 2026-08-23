--!strict
-- Trade Ads — item-for-item swap listings (AUTO = instant accept, ASK =
--     register interest). Posting opens the trade window in compose mode;
--     the want side accepts trade-ad tokens (Upgrade, Any, …) from
--     WildcardConfig, which force the listing to ask-first. Two tabs:
--   * TRADE ADS — the swap board above, with a server/global scope filter,
--     a featured strip, and paid boost placement (see TradeAdConfig).
--   * MARKET — the per-item order book (buy orders + sell listings, priced
--     in gems). All of it lives in MarketScreen; this file just switches.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local WildcardConfig = require(ReplicatedStorage.Shared.Config.WildcardConfig)
local TradeAdConfig = require(ReplicatedStorage.Shared.Config.TradeAdConfig)
local Tax = require(ReplicatedStorage.Shared.Util.Tax)
local Net = require(script.Parent.Parent.Net)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local TradeController = require(script.Parent.Parent.Controllers.TradeController)
local NotificationController = require(script.Parent.Parent.Controllers.NotificationController)
local TradeScreen = require(script.Parent.TradeScreen)
local MarketScreen = require(script.Parent.MarketScreen)

local BoardScreen = {}

function BoardScreen.wire(gui: ScreenGui, tooltip: any, toast: (text: string, color: Color3) -> ())
	MarketScreen.wire(gui, tooltip, toast)

	local panel = gui:WaitForChild("BoardPanel") :: Frame
	local list = panel:WaitForChild("ListingList") :: ScrollingFrame
	local rowTemplate = list:WaitForChild("ListingRow") :: Frame
	local chipTemplate = (rowTemplate:WaitForChild("GiveHolder") :: Frame):WaitForChild("Chip") :: Frame
	local emptyLabel = panel:WaitForChild("EmptyLabel") :: TextLabel

	-- scope filter
	local scopeRow = panel:WaitForChild("ScopeRow") :: Frame
	local scopeButtons = {
		server = scopeRow:WaitForChild("ScopeServer") :: TextButton,
		global = scopeRow:WaitForChild("ScopeGlobal") :: TextButton,
	}

	-- featured strip (collapses to nothing when the active scope has no
	-- boostTier >= 2 listings)
	local featuredStrip = panel:WaitForChild("FeaturedStrip") :: ScrollingFrame
	local featuredCardTemplate = featuredStrip:WaitForChild("FeaturedCard") :: Frame
	local featuredSpawned: { Instance } = {}
	local LIST_Y_NO_FEATURED = 112
	local FEATURED_H = 110
	local LIST_Y_WITH_FEATURED = LIST_Y_NO_FEATURED + FEATURED_H + 8

	local function setFeaturedVisible(visible: boolean)
		featuredStrip.Visible = visible
		local listY = visible and LIST_Y_WITH_FEATURED or LIST_Y_NO_FEATURED
		list.Position = UDim2.fromOffset(12, listY)
		list.Size = UDim2.new(0, 744, 1, -(listY + 12))
		emptyLabel.Position = UDim2.fromOffset(12, listY + 38)
	end
	setFeaturedVisible(false)

	-- boost inventory (banked, unspent credits)
	local boostInv = panel:WaitForChild("BoostInventoryPanel") :: Frame
	local creditsList = boostInv:WaitForChild("CreditsList") :: ScrollingFrame
	local creditRowTemplate = creditsList:WaitForChild("BoostCreditRow") :: Frame
	local boostInvEmpty = boostInv:WaitForChild("EmptyLabel") :: TextLabel
	local boostInvGetButton = boostInv:WaitForChild("GetBoostsButton") :: TextButton
	local boostInvSpawned: { Instance } = {}
	local lastBoostState: any = nil

	-- boost sheet (spend a banked credit, or buy one, for one ad)
	local boostSheet = panel:WaitForChild("BoostSheet") :: Frame
	local sheetCreditsList = boostSheet:WaitForChild("CreditsList") :: ScrollingFrame
	local sheetCreditTemplate = sheetCreditsList:WaitForChild("CreditButton") :: TextButton
	local sheetCreditsEmpty = boostSheet:WaitForChild("EmptyLabel") :: TextLabel
	local sheetSkuRow = boostSheet:WaitForChild("SkuRow") :: Frame
	local sheetSkuTemplate = sheetSkuRow:WaitForChild("SkuCard") :: Frame
	local sheetAutoRenewBox = (boostSheet:WaitForChild("AutoRenew") :: Frame):WaitForChild("Checkbox") :: TextButton
	local sheetSpawned: { Instance } = {}
	local sheetScope: string = TradeAdConfig.Scopes.Server
	local sheetListingId: string? = nil

	local spawned: { Instance } = {}
	local lastListings: { any }? = nil
	local busy = false
	local refresh
	local openBoostSheet: (scope: string, listingId: string?) -> ()
	local activeTab: "swap" | "market" = "swap"
	-- default "server": bot ads are all server-scoped, so the global feed
	-- looks empty at low population — a new player's first look at the board
	-- should show ads, not a void
	local activeScope: string = TradeAdConfig.Scopes.Server

	local closeBtn = panel:WaitForChild("CloseButton") :: TextButton
	closeBtn.Activated:Connect(function()
		panel.Visible = false
		MarketScreen.hide() -- stop background refreshes while closed
	end)

	local function clearRendered()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
	end

	-- One offer chip. Real items hover to live stats; trade-ad tokens hover
	-- to their explanation. Gems are never a chip — see fillOfferChips.
	local function addChip(holder: Frame, imageId: string?, name: string, countText: string, order: number, itemId: string?, isWildcard: boolean?)
		local chip = chipTemplate:Clone()
		chip.Visible = true
		chip.LayoutOrder = order
		Components.setIcon(chip:WaitForChild("Icon") :: ImageLabel, { imageId = imageId, name = name })
		;(chip:WaitForChild("CountLabel") :: TextLabel).Text = countText
		chip.Parent = holder
		table.insert(spawned, chip)
		if itemId and not isWildcard then
			EconomyController.ensure({ itemId })
		end
		tooltip.attach(chip, function()
			if isWildcard and itemId then
				return WildcardConfig.snapshot(itemId), nil
			end
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
			local countText = entry.wildcard and "" or ("x" .. entry.count)
			addChip(holder, entry.imageId, entry.name, countText, order, entry.itemId, entry.wildcard)
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

	-- "2h left" / "45m left" — makes the presence-tied ad lifetime visible.
	local function timeLeftText(expiresAt: number): string
		local remaining = math.max(0, expiresAt - os.time())
		local hours = math.floor(remaining / 3600)
		if hours >= 1 then
			return ("%dh left"):format(hours)
		end
		return ("%dm left"):format(math.max(1, math.floor(remaining / 60)))
	end

	-- "scope" is internal jargon; players see "this server" / "global ads"
	local function scopeLabel(scope: string): string
		return scope == TradeAdConfig.Scopes.Global and "global ads" or "this server"
	end

	local DAY_SECONDS = 24 * 3600

	-- "24h", "3 days", "45m" — used on the per-duration buttons when a shelf
	-- holds more than one SKU (today: the "high"/Featured shelf)
	local function formatDuration(seconds: number): string
		if seconds == DAY_SECONDS then
			return "24h"
		elseif seconds % DAY_SECONDS == 0 then
			return ("%d days"):format(seconds / DAY_SECONDS)
		elseif seconds % 3600 == 0 then
			return ("%dh"):format(seconds / 3600)
		end
		return ("%dm"):format(math.max(1, math.floor(seconds / 60)))
	end

	--------------------------------------------------------------------------
	-- Boost sheet: spend a banked credit, or buy one, for one ad. Opened from
	-- a listing's own "⏱ Boost" button (sheetListingId set) or from the boost
	-- inventory panel's "+" (sheetListingId nil — buy-only, nothing to spend on
	-- yet).
	--------------------------------------------------------------------------

	local function clearSheet()
		for _, inst in sheetSpawned do
			inst:Destroy()
		end
		table.clear(sheetSpawned)
	end

	local function refreshBoostInventory() -- fwd decl target, assigned below
	end

	local function closeBoostSheet()
		boostSheet.Visible = false
		clearSheet()
	end
	(boostSheet:WaitForChild("CloseButton") :: TextButton).Activated:Connect(closeBoostSheet)

	local function renderSheetCredits(boostState: any)
		local order = 0
		for _, sku in TradeAdConfig.skusForScope(sheetScope) do
			local count = boostState.credits[sku.id] or 0
			if count > 0 then
				order += 1
				local btn = sheetCreditTemplate:Clone()
				btn.Name = "credit_" .. sku.id
				btn.Visible = true
				btn.LayoutOrder = order
				btn.Text = ("%s\nx%d owned%s"):format(sku.name, count, sheetListingId and " — tap to apply" or "")
				btn.AutoButtonColor = sheetListingId ~= nil
				if sheetListingId then
					local listingId = sheetListingId
					btn.Activated:Connect(function()
						local result = invokeAction(function()
							return Net.invoke("ApplyAdBoost", listingId, sku.id)
						end)
						if result then
							if result.ok then
								toast("Boost applied!", Theme.Good)
								closeBoostSheet()
								refresh()
							else
								toast("Couldn't apply boost: " .. tostring(result.err), Theme.Bad)
							end
						end
						refreshBoostInventory()
					end)
				end
				btn.Parent = sheetCreditsList
				table.insert(sheetSpawned, btn)
			end
		end
		sheetCreditsEmpty.Visible = order == 0
		sheetCreditsEmpty.Text = ("No banked boosts for %s yet — buy one below."):format(scopeLabel(sheetScope))
	end

	local SHELF_ORDER = { "low", "best", "high" }

	-- wires one price button to one SKU: label, out-of-slots gating, purchase
	local function wireSkuButton(btn: TextButton, sku: any, boostState: any)
		local outOfSlots = sku.tier == TradeAdConfig.BoostTier.Featured
			and (boostState.featuredOpen[sheetScope] or 0) <= 0
		btn.Visible = not outOfSlots
		if outOfSlots then
			return false
		end
		btn.Text = ("%s — %d R$"):format(formatDuration(sku.seconds), sku.robux)
		btn.Activated:Connect(function()
			local result = invokeAction(function()
				return Net.invoke("PromptAdBoost", sku.id)
			end)
			if result and not result.ok then
				toast("Couldn't open that purchase.", Theme.Bad)
			end
			refreshBoostInventory()
		end)
		return true
	end

	-- Exactly three cards — low / best / high — never one-per-SKU. Global's
	-- "high" shelf holds two SKUs (Featured 24h + Featured 3d); rather than
	-- spill a 4th card past the sheet's edge, that shelf's card offers both
	-- durations as two stacked price buttons.
	local function renderSheetSkus(boostState: any)
		local byShelf: { [string]: { any } } = {}
		for _, sku in TradeAdConfig.skusForScope(sheetScope) do
			local bucket = byShelf[sku.shelf]
			if bucket == nil then
				bucket = {}
				byShelf[sku.shelf] = bucket
			end
			table.insert(bucket, sku)
		end

		local order = 0
		for _, shelf in SHELF_ORDER do
			local bucket = byShelf[shelf]
			if bucket and #bucket > 0 then
				order += 1
				local card = sheetSkuTemplate:Clone()
				card.Name = "shelf_" .. shelf
				card.Visible = true
				card.LayoutOrder = order

				local first = bucket[1]
				;(card:WaitForChild("NameLabel") :: TextLabel).Text = #bucket > 1 and "Featured" or first.name
				;(card:WaitForChild("BlurbLabel") :: TextLabel).Text = first.blurb
				;(card:WaitForChild("Ribbon") :: Frame).Visible = shelf == "best"

				local buyBtn = card:WaitForChild("BuyButton") :: TextButton
				local buyBtn2 = card:WaitForChild("BuyButton2") :: TextButton
				local shown1 = wireSkuButton(buyBtn, bucket[1], boostState)
				local shown2 = false
				if bucket[2] then
					shown2 = wireSkuButton(buyBtn2, bucket[2], boostState)
				else
					buyBtn2.Visible = false
				end

				;(card:WaitForChild("NoSlotsLabel") :: TextLabel).Visible = not shown1 and not shown2

				card.Parent = sheetSkuRow
				table.insert(sheetSpawned, card)
			end
		end
	end

	local sheetAutoRenewLabel = (boostSheet:WaitForChild("AutoRenew") :: Frame):WaitForChild("Label") :: TextLabel
	-- false while nothing is scheduled and there's no Featured credit banked
	-- to schedule — greyed out then so the checkbox doesn't imply a renewal
	-- is pending when nothing is
	local sheetAutoRenewInteractable = true

	local function renderBoostSheet(boostState: any)
		clearSheet()
		renderSheetCredits(boostState)
		renderSheetSkus(boostState)

		local enabled = boostState.autoRenew[sheetScope] == true
		local hasFeaturedCredit = false
		for _, sku in TradeAdConfig.skusForScope(sheetScope) do
			if sku.tier == TradeAdConfig.BoostTier.Featured and (boostState.credits[sku.id] or 0) > 0 then
				hasFeaturedCredit = true
				break
			end
		end
		sheetAutoRenewInteractable = enabled or hasFeaturedCredit
		sheetAutoRenewBox.Text = enabled and "✓" or ""
		sheetAutoRenewBox.AutoButtonColor = sheetAutoRenewInteractable
		sheetAutoRenewBox.BackgroundColor3 = sheetAutoRenewInteractable and Theme.BgLight or Theme.Bg
		sheetAutoRenewLabel.TextColor3 = sheetAutoRenewInteractable and Theme.TextPrimary or Theme.TextDim
	end

	-- scope-prefixed short label: "Boost 24 hours" (global) -> "Global Boost 24h"
	local function shortSkuLabel(sku: any): string
		local scopeName = sku.scope == TradeAdConfig.Scopes.Global and "Global" or "Server"
		local shortName = sku.name:gsub(" hours", "h"):gsub(" hour", "h")
		return scopeName .. " " .. shortName
	end

	local function clearBoostInv()
		for _, inst in boostInvSpawned do
			inst:Destroy()
		end
		table.clear(boostInvSpawned)
	end

	local function renderBoostInventory(boostState: any)
		clearBoostInv()
		local order = 0
		for _, sku in TradeAdConfig.liveSkus() do
			local count = boostState.credits[sku.id] or 0
			if count > 0 then
				order += 1
				local row = creditRowTemplate:Clone()
				row.Name = "credit_" .. sku.id
				row.Visible = true
				row.LayoutOrder = order
				;(row:WaitForChild("Label") :: TextLabel).Text = ("%s: %d"):format(shortSkuLabel(sku), count)
				;(row:WaitForChild("AddButton") :: TextButton).Activated:Connect(function()
					openBoostSheet(sku.scope, nil)
				end)
				row.Parent = creditsList
				table.insert(boostInvSpawned, row)
			end
		end
		-- zero boosts owned is exactly the player who most needs a way to the
		-- shop, so the empty state gets its own buy button, not just a label
		boostInvEmpty.Visible = order == 0
		boostInvGetButton.Visible = order == 0
	end
	boostInvGetButton.Activated:Connect(function()
		openBoostSheet(activeScope, nil)
	end)

	refreshBoostInventory = function()
		task.spawn(function()
			local result = Net.invoke("GetAdBoostState")
			if result.ok then
				lastBoostState = result
				renderBoostInventory(result)
				if boostSheet.Visible then
					renderBoostSheet(result)
				end
			end
		end)
	end

	sheetAutoRenewBox.Activated:Connect(function()
		if not sheetAutoRenewInteractable then
			return
		end
		local enabled = sheetAutoRenewBox.Text == ""
		local result = invokeAction(function()
			return Net.invoke("SetAdAutoRenew", sheetScope, enabled)
		end)
		if result and result.ok then
			sheetAutoRenewBox.Text = enabled and "✓" or ""
		end
	end)

	openBoostSheet = function(scope: string, listingId: string?)
		sheetScope = scope
		sheetListingId = listingId
		boostSheet.Visible = true
		if lastBoostState then
			renderBoostSheet(lastBoostState)
		end
		refreshBoostInventory()
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
		local valueChip = row:WaitForChild("ValueChip") :: TextLabel
		local timePill = row:WaitForChild("TimePill") :: TextLabel
		local boostBtn = row:WaitForChild("BoostButton") :: TextButton
		countBox.Visible = false
		;(row:WaitForChild("PosterLabel") :: TextLabel).Text = listing.posterName
			.. (listing.mine and " (you)" or "")

		badge.Text = listing.autoTrade and "AUTO-TRADE" or "ASK FIRST"
		badge.TextColor3 = listing.autoTrade and Theme.Good or Theme.Warn
		fillOfferChips(giveHolder, giveGemsIcon, giveGemsLabel, listing.give) -- what the poster GIVES you
		fillOfferChips(wantHolder, wantGemsIcon, wantGemsLabel, listing.want) -- what they WANT from you

		-- value-delta chip. On your OWN ad this must describe the ad, not judge
		-- it — "-77% you" on your own listing reads like a self-inflicted scam
		-- warning. On someone else's ad the delta is genuinely useful, but
		-- "+12% you" leaves "you" dangling after a percentage with no verb to
		-- anchor it, so spell out the direction instead.
		if listing.valueDelta == 0 then
			valueChip.Text = "Fair"
			valueChip.TextColor3 = Theme.TextDim
		elseif listing.mine then
			-- valueDelta is signed from the GIVE side: negative means the want
			-- side is worth more, i.e. you are asking for a premium. Feeding
			-- that sign straight into "asking" produces "You're asking -77%",
			-- which reads as asking for less. Flip it so the number always
			-- describes the size of what you are asking OVER what you offer.
			if listing.valueDelta < 0 then
				valueChip.Text = ("You're asking %d%% more"):format(-listing.valueDelta)
			else
				valueChip.Text = ("You're offering %d%% more"):format(listing.valueDelta)
			end
			valueChip.TextColor3 = Theme.TextDim
		elseif listing.valueDelta > 0 then
			valueChip.Text = ("You gain %d%%"):format(listing.valueDelta)
			valueChip.TextColor3 = Theme.Good
		else
			valueChip.Text = ("You lose %d%%"):format(-listing.valueDelta)
			valueChip.TextColor3 = Theme.Bad
		end

		-- time-left pill: surfaces the presence-tied lifetime — otherwise
		-- invisible — so players learn staying online keeps an ad alive
		if listing.here then
			timePill.Text = "Live · you're in game"
			timePill.TextColor3 = Theme.Good
		else
			timePill.Text = timeLeftText(listing.expiresAt)
			timePill.TextColor3 = Theme.TextDim
		end

		-- boost button: only the poster can push their own ad
		boostBtn.Visible = listing.mine
		if listing.mine then
			boostBtn.Activated:Connect(function()
				openBoostSheet(listing.scope, listing.id)
			end)
		end
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
				badge.Text ..= "  (yours)"
			else
				action.Text = "Cancel"
				action.BackgroundColor3 = Theme.Bad
				action.Activated:Connect(function()
					local result = invokeAction(function()
						return Net.invoke("CancelListing", listing.id)
					end)
					if result and result.ok then
						toast("Listing cancelled.", Theme.Warn)
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
	end

	local function clearFeatured()
		for _, inst in featuredSpawned do
			inst:Destroy()
		end
		table.clear(featuredSpawned)
	end

	-- gold strip above the list: at most FeaturedSlotsPerScope boosted ads for
	-- the active scope. Collapses to nothing rather than show as an empty rail.
	local function renderFeatured(scopeListings: { any })
		clearFeatured()
		local shown = 0
		for _, listing in scopeListings do
			if shown >= TradeAdConfig.FeaturedSlotsPerScope then
				break
			end
			if listing.boostTier and listing.boostTier >= TradeAdConfig.BoostTier.Featured then
				shown += 1
				local card = featuredCardTemplate:Clone()
				card.Name = "featured_" .. listing.id
				card.Visible = true
				card.LayoutOrder = shown
				;(card:WaitForChild("PosterLabel") :: TextLabel).Text = listing.posterName
				local giveNames, wantNames = {}, {}
				for _, e in listing.give.items do
					table.insert(giveNames, e.name)
				end
				for _, e in listing.want.items do
					table.insert(wantNames, e.name)
				end
				;(card:WaitForChild("SummaryLabel") :: TextLabel).Text = table.concat(giveNames, ", ")
					.. " ⇄ "
					.. table.concat(wantNames, ", ")
				card.Parent = featuredStrip
				table.insert(featuredSpawned, card)
			end
		end
		setFeaturedVisible(shown > 0)
	end

	local function renderBoard(listings: { any })
		clearRendered()
		local scopeListings = {}
		for _, listing in listings do
			if listing.kind == "swap" and listing.scope == activeScope then
				table.insert(scopeListings, listing)
			end
		end
		renderFeatured(scopeListings)
		for i, listing in scopeListings do
			renderListing(listing, i)
		end
		emptyLabel.Visible = #scopeListings == 0 and activeTab == "swap"
		emptyLabel.Text = "No trades posted — hit + to post one!"
	end

	refresh = function()
		task.spawn(function()
			local result = Net.invoke("GetBoard")
			if result.ok then
				lastListings = result.listings
				if panel.Visible and activeTab == "swap" then
					renderBoard(result.listings)
				end
			end
		end)
	end

	local function selectScope(scope: string)
		activeScope = scope
		for key, btn in scopeButtons do
			btn.BackgroundColor3 = (key == scope) and Theme.Accent or Theme.BgLight
		end
		if lastListings then
			renderBoard(lastListings)
		end
	end
	for scope, btn in scopeButtons do
		btn.Activated:Connect(function()
			selectScope(scope)
		end)
	end
	selectScope(activeScope)

	--------------------------------------------------------------------------
	-- Tabs
	--------------------------------------------------------------------------

	local postBtn = panel:WaitForChild("PostButton") :: TextButton
	postBtn.Text = "+ Post trade"

	local tabRow = panel:WaitForChild("TabRow") :: Frame
	local tabButtons = {
		swap = tabRow:WaitForChild("TabTrades") :: TextButton,
		market = tabRow:WaitForChild("TabMarket") :: TextButton,
	}
	local function selectTab(tab: "swap" | "market")
		activeTab = tab
		for key, btn in tabButtons do
			btn.BackgroundColor3 = (key == tab) and Theme.Accent or Theme.BgLight
		end
		if tab == "swap" then
			MarketScreen.hide()
			list.Visible = true
			postBtn.Visible = true
			scopeRow.Visible = true
			boostInv.Visible = true
			if lastListings then
				renderBoard(lastListings)
			end
			refresh()
			refreshBoostInventory()
		else
			clearRendered()
			clearFeatured()
			emptyLabel.Visible = false
			list.Visible = false
			postBtn.Visible = false
			scopeRow.Visible = false
			setFeaturedVisible(false)
			boostInv.Visible = false
			MarketScreen.show()
		end
	end
	for tab, btn in tabButtons do
		btn.Activated:Connect(function()
			selectTab(tab :: any)
		end)
	end

	function BoardScreen.open()
		Components.closeOtherPanels(panel)
		panel.Visible = true
		selectTab(activeTab)
	end

	function BoardScreen.toggle()
		if panel.Visible then
			panel.Visible = false
			MarketScreen.hide()
		else
			BoardScreen.open()
		end
	end

	-- public: open the board straight to a given tab (pillar deep-link / tests)
	function BoardScreen.openTab(tab: "swap" | "market")
		activeTab = tab
		BoardScreen.open()
	end

	--------------------------------------------------------------------------
	-- Posting a swap: the trade window in compose mode
	--------------------------------------------------------------------------

	postBtn.Activated:Connect(function()
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
					NotificationController.promptOptIn(
						"Enable notifications so we can tell you about activity on this trade!",
						toast
					)
				end
				BoardScreen.open()
			end)
		end)
	end)

	selectTab("swap")
end

return BoardScreen
