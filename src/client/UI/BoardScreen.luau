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
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(script.Parent.Parent.Net)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local TradeController = require(script.Parent.Parent.Controllers.TradeController)
local NotificationController = require(script.Parent.Parent.Controllers.NotificationController)
local TradeScreen = require(script.Parent.TradeScreen)
local MarketScreen = require(script.Parent.MarketScreen)
local ShopScreen = require(script.Parent.ShopScreen)

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
	local featuredHeader = panel:WaitForChild("FeaturedHeader") :: TextLabel
	local featuredDivider = panel:WaitForChild("FeaturedDivider") :: Frame
	-- Feed geometry is expressed as FRACTIONS of the panel, not pixels: the
	-- board is scale-native, so the band the feed occupies has to move in the
	-- same units the builder laid it out in.
	local FEED_X = 0.014
	local FEED_W = 0.972
	local FEED_BOTTOM_GUTTER = 0.02
	-- tabs + scope row + boost slots occupy the band above 0.35
	local LIST_Y_NO_FEATURED = 0.250

	-- Header, band and divider live and die together: half of a collapsed strip
	-- is a gold word floating over nothing.
	-- The gold block is a 3-wide grid, so its height is a function of how many
	-- ads are actually featured: one row for up to three, two beyond that. A
	-- fixed two-row block would reserve half the panel for empty gold whenever
	-- a single ad is featured, and the feed underneath is what most players
	-- opened the board for.
	-- Sized so that even the worst case (six featured, two rows) still leaves a
	-- full feed row visible underneath. At 0.148 two rows pushed the feed down
	-- to ~57px against a 131px row, so the first ad was sliced in half by the
	-- panel edge — the paid shelf was eating the thing it sits on top of.
	-- One rail row is one feed row, because they are literally the same row.
	-- 204px against a 509px panel, so a row is ~0.40 of the panel's height.
	-- Rows are shorter now, so a rail row is ~0.33 of the panel.
	local FEATURED_ROW_H = 0.335
	local FEATURED_TOP = 0.302
	local FEATURED_GAP = 0.012
	local FEATURED_VISIBLE_ROWS = 3
	-- The rail may take most of the panel -- it is the paid shelf and the point
	-- of the screen when anything is featured. The feed keeps enough to show it
	-- continues below and can be scrolled to.
	local FEED_MIN_H = 0.10

	-- The rail is a fixed THREE rows tall and scrolls to reach the rest of the
	-- five slots. Sizing it to the live count would make the feed underneath
	-- jump every time an ad was featured or expired; a fixed height that scrolls
	-- keeps the feed's top edge still.
	local function setFeaturedVisible(visible: boolean, count: number?)
		featuredStrip.Visible = visible
		featuredHeader.Visible = visible
		featuredDivider.Visible = visible
		-- Cap the rail at whatever actually fits above a usable feed. Asking for
		-- three rows on a panel only ~2.5 rows tall would push the feed off the
		-- bottom entirely, so the rail takes what it can and scrolls for the rest.
		local roomRows = math.floor((1 - FEATURED_TOP - FEATURED_GAP - FEED_MIN_H - FEED_BOTTOM_GUTTER) / FEATURED_ROW_H)
		local fits = math.max(1, math.min(FEATURED_VISIBLE_ROWS, roomRows))
		local shown = math.min(count or 0, fits)
		local railRows = math.max(1, shown)
		featuredStrip.Size = UDim2.fromScale(FEED_W, railRows * FEATURED_ROW_H)
		local listY = visible and (FEATURED_TOP + railRows * FEATURED_ROW_H + FEATURED_GAP) or LIST_Y_NO_FEATURED
		list.Position = UDim2.fromScale(FEED_X, listY)
		list.Size = UDim2.fromScale(FEED_W, 1 - listY - FEED_BOTTOM_GUTTER)
		emptyLabel.Position = UDim2.fromScale(FEED_X, listY + 0.07)
		featuredDivider.Position = UDim2.fromScale(FEED_X, listY - FEATURED_GAP * 0.5)
	end
	setFeaturedVisible(false)

	-- Banked credits as a slot row above the feed. Same data source and same
	-- click targets as the 220px rail it replaces — layout only.
	local boostStrip = panel:WaitForChild("BoostSlotRow") :: Frame
	local boostSlotTemplate = boostStrip:WaitForChild("BoostSlot") :: TextButton
	local boostAddSlot = boostStrip:WaitForChild("AddSlot") :: TextButton
	local boostSlotSpawned: { Instance } = {}
	local lastBoostState: any = nil

	-- boost sheet (spend a banked credit, or buy one, for one ad)
	local boostSheet = panel:WaitForChild("BoostSheet") :: Frame
	local sheetCreditsList = boostSheet:WaitForChild("CreditsList") :: ScrollingFrame
	local sheetCreditTemplate = sheetCreditsList:WaitForChild("CreditButton") :: TextButton
	local sheetCreditsEmpty = boostSheet:WaitForChild("EmptyLabel") :: TextLabel
	local sheetSkuRow = boostSheet:WaitForChild("SkuRow") :: Frame
	local sheetSkuTemplate = sheetSkuRow:WaitForChild("SkuCard") :: Frame
	local sheetAutoRenewBox = (boostSheet:WaitForChild("AutoRenew") :: Frame):WaitForChild("Checkbox") :: TextButton
	local sheetOpenShopBtn = boostSheet:WaitForChild("OpenShopButton") :: TextButton
	local sheetSpawned: { Instance } = {}
	local sheetScope: string = TradeAdConfig.Scopes.Server
	local sheetListingId: string? = nil

	-- post-time boost picker (item 3): shown between compose and PostListing
	local postBoostPanel = panel:WaitForChild("PostBoostPanel") :: Frame
	local postBoostOptions = postBoostPanel:WaitForChild("OptionsList") :: ScrollingFrame
	local postBoostOptionTemplate = postBoostOptions:WaitForChild("OptionButton") :: TextButton
	local postBoostEmpty = postBoostPanel:WaitForChild("EmptyLabel") :: TextLabel
	local postBoostGetBtn = postBoostPanel:WaitForChild("GetBoostsButton") :: TextButton
	local postBoostPostBtn = postBoostPanel:WaitForChild("PostButton") :: TextButton
	local postBoostCloseBtn = postBoostPanel:WaitForChild("CloseButton") :: TextButton
	local postBoostSpawned: { Instance } = {}

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
		postBoostPanel.Visible = false -- a half-answered post picker must not survive a close
		MarketScreen.hide() -- stop background refreshes while closed
	end)

	-- Set by renderBoard; cleared here so a teardown can never leave the cache
	-- claiming a board is on screen when the list is actually empty.
	local invalidateBoardCache: () -> () = function() end

	local function clearRendered()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
		invalidateBoardCache()
	end

	-- "x2 · 1.2k" — count and unit value on one line. Value is what a trader
	-- actually decides on, and the server has been sending it per item since
	-- the payload gained `value`; the chip used to throw it away and show a
	-- bare "x1", which told nobody anything.
	-- Count only. The tile is icon-sized, so a gem figure printed on it was
	-- unreadable at any font that fit; hovering the tile shows the item's name
	-- and live value, which is where a price belongs. The badge answers the one
	-- thing the icon cannot: how many.
	local function countValueText(entry: any): string
		if entry.wildcard then
			return "any"
		end
		return "x" .. entry.count
	end

	-- One offer chip: icon + NAME + count/value. Real items hover to live
	-- stats; trade-ad tokens hover to their explanation. Gems are never a chip
	-- — see fillOfferChips.
	local function addChip(holder: Frame, entry: any, order: number)
		local chip = chipTemplate:Clone()
		chip.Visible = true
		chip.LayoutOrder = order
		Components.setIcon(chip:WaitForChild("Icon") :: ImageLabel, { imageId = entry.imageId, name = entry.name })
		;(chip:WaitForChild("NameLabel") :: TextLabel).Text = entry.name
		;(chip:WaitForChild("CountLabel") :: TextLabel).Text = countValueText(entry)
		chip.Parent = holder
		table.insert(spawned, chip)
		if entry.itemId and not entry.wildcard then
			EconomyController.ensure({ entry.itemId })
		end
		tooltip.attach(chip, function()
			if entry.wildcard and entry.itemId then
				return WildcardConfig.snapshot(entry.itemId), nil
			end
			if entry.itemId then
				return EconomyController.get(entry.itemId) or { name = entry.name, imageId = entry.imageId }, nil
			end
			return { name = entry.name, imageId = entry.imageId }, nil
		end)
	end

	-- Up to four item tiles a side, laid out 2x2 from the top-left so the same
	-- item always lands in the same place whatever else the side holds. Names
	-- and live values come from hovering a tile (see addChip's tooltip.attach).
	-- The post panel sells nine slots a side, so the feed has to be able to show
	-- nine. It does it by changing the DENSITY of the block, never its size: a
	-- side holding four or fewer lays out 2x2 with big tiles, five or more
	-- switches the same block to 3x3 with smaller ones. Nothing is ever hidden
	-- behind a "+N", and because the block keeps its footprint the poster name,
	-- arrow and verdict stay where they were aligned to.
	local CHIP_CAP = 9
	local function gridColsFor(count: number): number
		return count > 4 and 3 or 2
	end

	-- Both sides share one density even when their counts differ. A 2x2 facing
	-- a 3x3 makes the smaller side's items look more valuable than the other's
	-- purely because their art is bigger, which is a lie about the trade.
	local function applyChipGrid(holder: Frame, cols: number)
		local grid = holder:FindFirstChildWhichIsA("UIGridLayout")
		if grid == nil then
			return
		end
		-- Tiles do not fill the block edge to edge. Once the block grew, a 2x2
		-- of near-full-width tiles read as one solid slab rather than four
		-- separate things you could count; the air between them is what makes
		-- them read as individual items.
		local cell = cols == 2 and 0.40 or 0.28
		local pad = cols == 2 and 0.20 or 0.08
		grid.CellSize = UDim2.fromScale(cell, cell)
		grid.CellPadding = UDim2.fromScale(pad, pad)
		grid.FillDirectionMaxCells = cols
	end

	local function fillOfferChips(
		holder: Frame,
		gemsIcon: ImageLabel,
		gemsLabel: TextLabel,
		offer: any,
		cols: number
	)
		local more = holder:WaitForChild("MoreLabel") :: TextLabel
		applyChipGrid(holder, cols)
		-- The cap is the post panel's own slot count, so in practice nothing is
		-- ever truncated; it only guards against a malformed payload.
		local shown = math.min(#offer.items, CHIP_CAP)
		for i = 1, shown do
			addChip(holder, offer.items[i], i)
		end
		local extra = #offer.items - shown
		more.Visible = extra > 0
		more.Text = extra > 0 and ("+%d"):format(extra) or ""
		local hasGems = offer.gems > 0
		gemsIcon.Visible = hasGems
		gemsLabel.Text = hasGems and ("+%d gems (after tax)"):format(Tax.split(offer.gems)) or ""
	end

	-- The single wording for "is this trade fair", shared by the feed rows and
	-- the featured cards so the same listing never gets two different verdicts.
	--
	-- On your OWN ad this must describe the ad, not judge it — "-77% you" on
	-- your own listing reads like a self-inflicted scam warning. valueDelta is
	-- signed from the GIVE side: negative means the want side is worth more,
	-- i.e. you are asking a premium, so the sign is flipped to keep the number
	-- describing the size of what you ask OVER what you offer.
	local function verdictFor(listing: any): (string, Color3)
		if listing.valueDelta == 0 then
			return "Fair", Theme.TextDim
		elseif listing.mine then
			if listing.valueDelta < 0 then
				return ("You're asking %d%% more"):format(-listing.valueDelta), Theme.TextDim
			end
			return ("You're offering %d%% more"):format(listing.valueDelta), Theme.TextDim
		elseif listing.valueDelta > 0 then
			return ("You gain %d%%"):format(listing.valueDelta), Theme.Good
		end
		return ("You lose %d%%"):format(-listing.valueDelta), Theme.Bad
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

	-- "2d left" / "23h left" / "45m left" — the BOOST's own clock, which is a
	-- different thing from the ad's lifetime pill above it.
	local function boostLeftText(boostExpiresAt: number): string
		local remaining = math.max(0, boostExpiresAt - os.time())
		local days = math.floor(remaining / DAY_SECONDS)
		if days >= 1 then
			return ("%dd left"):format(days)
		end
		local hours = math.floor(remaining / 3600)
		if hours >= 1 then
			return ("%dh left"):format(hours)
		end
		return ("%dm left"):format(math.max(1, math.floor(remaining / 60)))
	end

	-- One storefront. "Get boosts" anywhere on the board lands in ShopScreen on
	-- that scope's boost shelves — never in a second parallel shop.
	local function openShopAtBoosts(scope: string)
		panel.Visible = false
		MarketScreen.hide()
		local openAt = (ShopScreen :: any).openAt
		if openAt then
			openAt(TradeAdConfig.shopSection(scope))
		end
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

	-- Applying a boost used to be silent, so a player had no way to tell a
	-- purchase had done anything. Say what they got and for how long.
	local function boostSuccessText(sku: any): string
		local where = sku.scope == TradeAdConfig.Scopes.Global and "all free ads game-wide"
			or "free ads on this server"
		if sku.tier >= TradeAdConfig.BoostTier.Featured then
			return ("Featured! Your ad is pinned to the Featured strip for %s."):format(formatDuration(sku.seconds))
		end
		return ("Boosted! Your ad is above %s for %s."):format(where, formatDuration(sku.seconds))
	end

	local BOOST_ERRORS = {
		no_credit = "You don't own that boost any more.",
		not_your_ad = "You can only boost your own ads.",
		cannot_apply = "No Featured slots free right now — try a Boost instead.",
		gone = "That ad is gone — nothing was spent.",
	}

	-- Shared by the boost sheet and the post-time picker so both give the same
	-- confirmation for the same action.
	local function applyBoost(listingId: string, sku: any): boolean
		local result = invokeAction(function()
			return Net.invoke("ApplyAdBoost", listingId, sku.id)
		end)
		if result == nil then
			return false
		end
		if result.ok then
			toast(boostSuccessText(sku), Theme.Good)
			return true
		end
		toast(BOOST_ERRORS[tostring(result.err)] or ("Couldn't apply boost: " .. tostring(result.err)), Theme.Bad)
		return false
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
						if applyBoost(listingId, sku) then
							closeBoostSheet()
							refresh()
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
				-- same art as this tier's shop section and inventory slot, so a
				-- boost is recognisable wherever the player meets it
				;(card:WaitForChild("Icon") :: ImageLabel).Image = TradeAdConfig.iconFor(first)
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

	-- One slot per OWNED boost: icon, count badge, short name. Consumables in
	-- Roblox games read as slots, not as a comma-separated sentence — and a
	-- slot is a click target, so spending and buying are the same gesture.
	local function slotName(sku: any): string
		-- the scope is already implied by the board tab the player is on, so
		-- the slot caption spends its ~62px on duration instead
		return sku.tier >= TradeAdConfig.BoostTier.Featured and ("Featured " .. formatDuration(sku.seconds))
			or ("Boost " .. formatDuration(sku.seconds))
	end

	-- The ad a slot-tap should target: the player's own open ad in that scope.
	-- Picking it here (rather than inventing a chooser) keeps spending on the
	-- existing ApplyAdBoost path with nothing new server-side.
	local function ownListingIn(scope: string): string?
		for _, listing in lastListings or {} do
			if listing.mine and listing.kind == "swap" and listing.scope == scope then
				return listing.id
			end
		end
		return nil
	end

	local function renderBoostInventory(boostState: any)
		for _, inst in boostSlotSpawned do
			inst:Destroy()
		end
		table.clear(boostSlotSpawned)

		local order = 0
		for _, sku in TradeAdConfig.liveSkus() do
			local count = boostState.credits[sku.id] or 0
			-- Only the credits spendable on the scope being viewed. A global
			-- credit shown while the Server tab is open read as "you have one",
			-- then the boost sheet -- which is scoped -- answered "no banked
			-- boosts for this server yet". Same player, same second, two
			-- opposite answers.
			if count > 0 and sku.scope == activeScope then
				order += 1
				local slot = boostSlotTemplate:Clone()
				slot.Name = "slot_" .. sku.id
				slot.Visible = true
				slot.LayoutOrder = order
				;(slot:WaitForChild("Icon") :: ImageLabel).Image = TradeAdConfig.iconFor(sku)
				;(slot:WaitForChild("CountBadge") :: TextLabel).Text = "x" .. count
				;(slot:WaitForChild("NameLabel") :: TextLabel).Text = slotName(sku)
				slot.Activated:Connect(function()
					-- opens the sheet already aimed at one of your ads when you
					-- have one, so the credit is one more tap from being spent
					openBoostSheet(sku.scope, ownListingIn(sku.scope))
				end)
				slot.Parent = boostStrip
				table.insert(boostSlotSpawned, slot)
			end
		end
		-- nothing owned leaves just the AddSlot, which is a real affordance
		-- rather than a reserved empty block
		;(boostAddSlot:WaitForChild("NameLabel") :: TextLabel).Text = order == 0 and "Get boosts" or "More"
	end
	boostAddSlot.Activated:Connect(function()
		openShopAtBoosts(activeScope)
	end)
	sheetOpenShopBtn.Activated:Connect(function()
		closeBoostSheet()
		openShopAtBoosts(sheetScope)
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

	-- Blocking "are you sure?" over the board. Yields the calling thread until
	-- the player answers, so the accept path stays one straight line instead of
	-- splitting into callbacks.
	local confirmPanel = panel:WaitForChild("ConfirmPanel") :: Frame
	local confirmBody = confirmPanel:WaitForChild("Body") :: TextLabel
	local confirmYes = confirmPanel:WaitForChild("YesButton") :: TextButton
	local confirmNo = confirmPanel:WaitForChild("NoButton") :: TextButton
	local confirmAnswer = Instance.new("BindableEvent")
	confirmYes.Activated:Connect(function()
		confirmPanel.Visible = false
		confirmAnswer:Fire(true)
	end)
	confirmNo.Activated:Connect(function()
		confirmPanel.Visible = false
		confirmAnswer:Fire(false)
	end)

	local function askConfirm(listing: any): boolean
		confirmBody.Text = listing.autoTrade
				and "This trade goes through straight away and cannot be undone."
			or "This sends a trade request to the poster."
		confirmPanel.Visible = true
		return confirmAnswer.Event:Wait()
	end

	-- `parent` is the feed by default and the featured rail when a listing is
	-- featured. Same template, same wiring, same everything -- a featured ad IS
	-- a normal ad, it just sits in the gold box instead of the feed.
	local function renderListing(listing: any, order: number, parent: Instance?)
		local row = rowTemplate:Clone()
		row.Name = "listing_" .. listing.id
		row.Visible = true
		row.LayoutOrder = order
		row.Parent = parent or list
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
		local boostBadge = row:WaitForChild("BoostBadge") :: TextLabel
		countBox.Visible = false
		;(row:WaitForChild("PosterLabel") :: TextLabel).Text = listing.posterName
			.. (listing.mine and " (you)" or "")

		-- Answers the only question this flag exists to answer: if I accept, does
		-- the trade happen NOW or do I have to wait for the poster? "AUTO-TRADE"
		-- and "ASK FIRST" were internal names for the two modes, sitting
		-- unexplained in the middle of the row -- a player has no way to know
		-- that "ask first" means their acceptance is a request, not a trade.
		badge.Text = listing.autoTrade and "Accepting will trigger the trade" or "Accepting sends a request"
		badge.TextColor3 = listing.autoTrade and Theme.Good or Theme.Warn
		-- one density for both sides, driven by whichever side carries more
		local chipCols = gridColsFor(math.max(#listing.give.items, #listing.want.items))
		fillOfferChips(giveHolder, giveGemsIcon, giveGemsLabel, listing.give, chipCols) -- what the poster GIVES you
		fillOfferChips(wantHolder, wantGemsIcon, wantGemsLabel, listing.want, chipCols) -- what they WANT from you

		-- the verdict, right after the want side so it reads as part of the trade
		valueChip.Text, valueChip.TextColor3 = verdictFor(listing)
		-- Same colour on the row's left spine: a player scanning the feed gets
		-- the good/bad signal from the edge of the list without reading words.
		local spine = row:FindFirstChild("AccentBar")
		if spine and spine:IsA("Frame") then
			spine.BackgroundColor3 = valueChip.TextColor3
		end

		-- time-left pill: surfaces the presence-tied lifetime — otherwise
		-- invisible — so players learn staying online keeps an ad alive
		if listing.here then
			-- Spell the rule out rather than just asserting "Live": the presence
			-- mechanic is invisible otherwise, and a player has no way to learn
			-- that staying in the game is what keeps their ad alive.
			timePill.Text = "No time limit while you're in the game · 2h after you leave (unless boosted)"
			timePill.TextColor3 = Theme.Good
		else
			timePill.Text = timeLeftText(listing.expiresAt)
			timePill.TextColor3 = Theme.TextDim
		end

		-- boost badge: a paid placement has to keep LOOKING paid in the feed —
		-- position alone is not something a player can read as "it worked".
		-- Shown on everyone's ads, not just your own, because that visible
		-- privilege is what the boost is actually selling.
		local tier = listing.boostTier or TradeAdConfig.BoostTier.None
		boostBadge.Visible = tier >= TradeAdConfig.BoostTier.Boosted
		if not boostBadge.Visible then
			local edge = row:FindFirstChildWhichIsA("UIStroke")
			if edge then
				edge.Color = Theme.Stroke
				edge.Transparency = 0
			end
		end
		if boostBadge.Visible then
			local icon = tier >= TradeAdConfig.BoostTier.Featured and "★ FEATURED" or "⚡ BOOSTED"
			-- no boostExpiresAt means the tier comes from a pass perk, which
			-- has no clock to count down
			if listing.boostExpiresAt then
				boostBadge.Text = ("%s · %s"):format(icon, boostLeftText(listing.boostExpiresAt))
			else
				boostBadge.Text = icon
			end
			-- Featured keeps gold; Boost gets electric cyan. Sharing a colour made
			-- the cheap tier and the scarce one look like the same purchase.
			local tint = tier >= TradeAdConfig.BoostTier.Featured and Theme.Gold or Theme.Electric
			boostBadge.TextColor3 = tint
			-- and a faint outline on the row itself, so a boosted ad reads as
			-- lifted even before you get to the badge
			local edge = row:FindFirstChildWhichIsA("UIStroke")
			if edge then
				edge.Color = tint
				edge.Transparency = 0.72
			end
		end

		-- boost button: only the poster can push their own ad. Two buttons stack
		-- in the action column; a lone button centres in it. Doing this here
		-- rather than in the template keeps the common one-button row visually
		-- balanced instead of top-heavy.
		boostBtn.Visible = listing.mine
		if listing.mine then
			-- SIDE BY SIDE, not stacked. Both buttons carry a touch-size floor
			-- (44px and 40px), which together exceed the row's own height once
			-- rows were shortened — so stacking made them physically overlap no
			-- matter what scale values they were given. The row has width to
			-- spare and height it does not, so the pair goes horizontal.
			-- Boost LEFT, Cancel RIGHT: the destructive one sits outermost, away
			-- from the button a poster actually reaches for.
			boostBtn.AnchorPoint = Vector2.new(0.5, 0.5)
			boostBtn.Position = UDim2.fromScale(0.845, 0.46)
			boostBtn.Size = UDim2.fromScale(0.086, 0.26)
			action.AnchorPoint = Vector2.new(0.5, 0.5)
			action.Position = UDim2.fromScale(0.939, 0.46)
			action.Size = UDim2.fromScale(0.086, 0.26)
		else
			-- One button, so it CENTRES in the same column the pair occupies
			-- (0.800..0.984) instead of hugging the right edge. Left at the edge
			-- it opened a button-sized hole where Boost would have been, and the
			-- row read as though something had failed to load.
			-- WIDE, not square. One button gets the whole column (0.800..0.984),
			-- the same span its caption underneath occupies, so the two read as
			-- one object. At 0.088 it was as tall as it was wide and sat in the
			-- middle of a lot of nothing.
			action.AnchorPoint = Vector2.new(0.5, 0.5)
			action.Position = UDim2.fromScale(0.892, 0.46)
			action.Size = UDim2.fromScale(0.184, 0.26)
		end
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
				-- Accepting hands over real items and cannot be undone, so it asks
				-- first rather than resolving on one stray tap.
				if not askConfirm(listing) then
					return
				end
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



	-- Gold rail above the feed holding the featured ads for the active scope.
	--
	-- These are the SAME rows the feed renders, not a bespoke card. The card
	-- version had its own layout, its own item chips and its own idea of what a
	-- trade looks like, so the paid placement read as a different, smaller
	-- product than the free listing underneath it. Paying should move your ad,
	-- not redraw it.
	--
	-- A featured ad appears here and NOWHERE else -- renderBoard keeps it out of
	-- the feed, so the rail is a promotion rather than a duplicate.
	local function renderFeatured(featured: { any })
		for i, listing in featured do
			renderListing(listing, i, featuredStrip)
		end
		setFeaturedVisible(#featured > 0, #featured)
	end

	-- Rebuilding the feed destroys and re-creates roughly a thousand instances
	-- (a row carries ~40 descendants, plus up to 18 item tiles). Most refreshes
	-- return a board identical to the one already on screen -- reopening the
	-- panel, finishing an unrelated action, a poll that found nothing new -- so
	-- the expensive part is skipped unless something a player can actually see
	-- has changed. Anything that alters a row's appearance belongs in this
	-- signature; scope and tab are in it because switching either changes which
	-- listings render.
	local lastSignature: string? = nil
	invalidateBoardCache = function()
		lastSignature = nil
	end
	local function signatureOf(scopeListings: { any }): string
		local parts = table.create(#scopeListings + 1)
		parts[1] = activeScope .. "|" .. activeTab
		for i, l in scopeListings do
			parts[i + 1] = table.concat({
				l.id,
				-- boostTier, not `tier`: the payload calls it boostTier and carries no
				-- `status` at all. Reading names it does not have made both entries a
				-- constant nil, so featuring or boosting an ad changed nothing the
				-- cache could see and the feed kept showing stale rows.
				tostring(l.boostTier or 0),
				tostring(l.expiresAt or 0),
				tostring(l.mine),
				tostring(l.autoTrade),
				tostring(#l.interested),
			}, ",")
		end
		return table.concat(parts, ";")
	end

	local function renderBoard(listings: { any })
		local scopeListings = {}
		for _, listing in listings do
			if listing.kind == "swap" and listing.scope == activeScope then
				table.insert(scopeListings, listing)
			end
		end

		local signature = signatureOf(scopeListings)
		if signature == lastSignature and #spawned > 0 then
			return -- identical board already on screen; nothing to rebuild
		end
		clearRendered() -- nils lastSignature via invalidateBoardCache
		lastSignature = signature

		-- A featured ad belongs to the rail and is kept OUT of the feed. Showing
		-- it in both made the paid slot look like a duplicate posting rather than
		-- a promotion, and cost the feed a row to say the same thing twice.
		local featured, rest = {}, {}
		for _, listing in scopeListings do
			local isFeatured = listing.boostTier ~= nil
				and listing.boostTier >= TradeAdConfig.BoostTier.Featured
				and #featured < TradeAdConfig.FeaturedSlotsPerScope
			if isFeatured then
				table.insert(featured, listing)
			else
				table.insert(rest, listing)
			end
		end

		renderFeatured(featured)
		for i, listing in rest do
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

	-- A banked credit shows up the moment it is bought. The server fires this as
	-- soon as the receipt is processed, so the slot row no longer waits for the
	-- player to switch tabs before admitting the purchase worked.
	Net.on("AdBoostStateChanged", function()
		refreshBoostInventory()
	end)

	local function selectScope(scope: string)
		activeScope = scope
		for key, btn in scopeButtons do
			btn.BackgroundColor3 = (key == scope) and Theme.Accent or Theme.BgLight
		end
		if lastListings then
			renderBoard(lastListings)
		end
		-- the slot row only shows credits for the scope in view, so it has to
		-- follow the tab
		if lastBoostState then
			renderBoostInventory(lastBoostState)
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
			boostStrip.Visible = true
			if lastListings then
				renderBoard(lastListings)
			end
			refresh()
			refreshBoostInventory()
		else
			clearRendered()
				emptyLabel.Visible = false
			list.Visible = false
			postBtn.Visible = false
			scopeRow.Visible = false
			setFeaturedVisible(false)
			boostStrip.Visible = false
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

	-- The composed trade, held between the compose window closing and the
	-- boost picker resolving. Nothing is posted until the player answers the
	-- picker, so the boost choice is part of posting rather than a chore the
	-- player has to rediscover afterwards.
	local pendingPost: { give: any, want: any, auto: boolean, scope: string }? = nil

	local function clearPostBoostOptions()
		for _, inst in postBoostSpawned do
			inst:Destroy()
		end
		table.clear(postBoostSpawned)
	end

	local function closePostBoost()
		postBoostPanel.Visible = false
		pendingPost = nil
		clearPostBoostOptions()
	end

	-- Server error codes are field names, not sentences. A player who saw
	-- "Couldn't post: empty_side" learned nothing they could act on, so every
	-- reachable code gets plain wording; anything unmapped still surfaces its
	-- code rather than a shrug, so a new failure stays diagnosable.
	local POST_ERRORS: { [string]: string } = {
		empty_side = "Both sides need something in them — add what you want in return.",
		ad_slots_full = "You've used all your trade ad slots in this feed. Cancel one, or buy more slots.",
		board_full = "The board is completely full right now. Try again shortly.",
		unknown_item = "One of the items in this trade no longer exists.",
		bad_offer = "That trade isn't valid — check both sides and try again.",
		bad_scope = "That feed doesn't exist. Reopen the board and try again.",
		not_holding = "You no longer hold everything you offered.",
		insufficient = "You no longer hold everything you offered.",
		loading = "Your data is still loading — give it a second and try again.",
		bad_args = "Something about that trade was malformed. Rebuild it and try again.",
	}
	local function postErrorText(err: any): string
		local mapped = type(err) == "string" and POST_ERRORS[err] or nil
		if mapped then
			return mapped
		end
		return "Couldn't post: " .. tostring(err)
	end

	local function submitPost(sku: any?)
		local pending = pendingPost
		if pending == nil then
			return
		end
		postBoostPanel.Visible = false
		clearPostBoostOptions()
		pendingPost = nil
		task.spawn(function()
			local result = Net.invoke("PostListing", {
				kind = "swap",
				give = pending.give,
				want = pending.want,
				autoTrade = pending.auto,
				-- post into the feed the player is looking at, which is also
				-- the scope whose credits the picker just offered
				scope = pending.scope,
			})
			toast(
				result.ok and "Posted to the board!" or postErrorText(result.err),
				result.ok and Theme.Good or Theme.Bad
			)
			if result.ok then
				-- reuse the existing apply endpoint rather than teaching the
				-- server a post-with-boost path: buying and applying stay the
				-- two separate actions they already are
				if sku and result.id then
					applyBoost(result.id, sku)
				end
				NotificationController.promptOptIn(
					"Enable notifications so we can tell you about activity on this trade!",
					toast
				)
			end
			refreshBoostInventory()
			BoardScreen.open()
		end)
	end

	local function renderPostBoostOptions(scope: string)
		clearPostBoostOptions()
		local credits = (lastBoostState and lastBoostState.credits) or {}
		local order = 0

		local none = postBoostOptionTemplate:Clone()
		none.Name = "option_none"
		none.Visible = true
		none.LayoutOrder = 0
		none.Text = "No boost — post for free"
		none.Activated:Connect(function()
			submitPost(nil)
		end)
		none.Parent = postBoostOptions
		table.insert(postBoostSpawned, none)

		for _, sku in TradeAdConfig.skusForScope(scope) do
			local count = credits[sku.id] or 0
			if count > 0 then
				order += 1
				local btn = postBoostOptionTemplate:Clone()
				btn.Name = "option_" .. sku.id
				btn.Visible = true
				btn.LayoutOrder = order
				btn.Text = ("%s — %s  (x%d owned)"):format(sku.name, formatDuration(sku.seconds), count)
				btn.Activated:Connect(function()
					submitPost(sku)
				end)
				btn.Parent = postBoostOptions
				table.insert(postBoostSpawned, btn)
			end
		end

		-- the picker stays visible with zero credits: hiding it would make the
		-- option undiscoverable for exactly the players who have never bought
		postBoostEmpty.Visible = order == 0
		postBoostEmpty.Text = ("You have no boosts banked for %s yet."):format(scopeLabel(scope))
	end

	postBoostCloseBtn.Activated:Connect(function()
		closePostBoost()
		toast("Post cancelled — nothing went up.", Theme.Warn)
	end)
	postBoostPostBtn.Activated:Connect(function()
		submitPost(nil)
	end)
	postBoostGetBtn.Activated:Connect(function()
		-- leaving for the shop drops the composed trade; say so rather than
		-- silently discarding it
		local scope = pendingPost and pendingPost.scope or activeScope
		closePostBoost()
		toast("Post cancelled — grab a boost, then post again.", Theme.Warn)
		openShopAtBoosts(scope)
	end)

	postBtn.Activated:Connect(function()
		panel.Visible = false
		TradeScreen.openCompose(function(give, want, auto)
			pendingPost = { give = give, want = want, auto = auto, scope = activeScope }
			BoardScreen.open()
			postBoostPanel.Visible = true
			renderPostBoostOptions(activeScope)
			-- credits may be stale (a purchase can have landed since the last
			-- board open); re-render once the fresh state arrives
			task.spawn(function()
				local result = Net.invoke("GetAdBoostState")
				if result.ok then
					lastBoostState = result
					renderBoostInventory(result)
					if postBoostPanel.Visible then
						renderPostBoostOptions(activeScope)
					end
				end
			end)
		end)
	end)

	selectTab("swap")
end

return BoardScreen
