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
	local featuredCardTemplate = featuredStrip:WaitForChild("FeaturedCard") :: Frame
	local featuredMiniChip = (featuredCardTemplate:WaitForChild("GiveHolder") :: Frame):WaitForChild("MiniChip") :: Frame
	local featuredDivider = panel:WaitForChild("FeaturedDivider") :: Frame
	local featuredSpawned: { Instance } = {}
	local FEED_W = 976 -- reclaimed from the old 220px boost rail
	-- the tab row, scope filter and boost slot row occupy 40..148
	local LIST_Y_NO_FEATURED = 152
	-- header (152..168) + strip (172..310) + divider (314..316), then a gutter
	local LIST_Y_WITH_FEATURED = 322

	-- Header, band and divider live and die together: half of a collapsed strip
	-- is a gold word floating over nothing.
	local function setFeaturedVisible(visible: boolean)
		featuredStrip.Visible = visible
		featuredHeader.Visible = visible
		featuredDivider.Visible = visible
		local listY = visible and LIST_Y_WITH_FEATURED or LIST_Y_NO_FEATURED
		list.Position = UDim2.fromOffset(12, listY)
		list.Size = UDim2.new(0, FEED_W, 1, -(listY + 12))
		emptyLabel.Position = UDim2.fromOffset(12, listY + 38)
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

	local function clearRendered()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
	end

	-- "x2 · 1.2k" — count and unit value on one line. Value is what a trader
	-- actually decides on, and the server has been sending it per item since
	-- the payload gained `value`; the chip used to throw it away and show a
	-- bare "x1", which told nobody anything.
	local function countValueText(entry: any): string
		local countText = entry.wildcard and "any" or ("x" .. entry.count)
		if entry.value == nil or entry.value <= 0 then
			return countText
		end
		return ("%s · %s"):format(countText, Format.abbrev(entry.value * entry.count))
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

	-- One named chip per side plus a "+N more" line, rather than a wall of
	-- anonymous icons: a row that shows five 46px squares and no names is
	-- unreadable, and every real trade-ad board leads with one item.
	local function fillOfferChips(holder: Frame, gemsIcon: ImageLabel, gemsLabel: TextLabel, offer: any)
		local more = holder:WaitForChild("MoreLabel") :: TextLabel
		local first = offer.items[1]
		if first then
			addChip(holder, first, 1)
		end
		local extra = #offer.items - (first and 1 or 0)
		more.Visible = extra > 0
		more.Text = extra > 0 and ("+%d more item%s"):format(extra, extra == 1 and "" or "s") or ""
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
			if count > 0 then
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
		local boostBadge = row:WaitForChild("BoostBadge") :: TextLabel
		countBox.Visible = false
		;(row:WaitForChild("PosterLabel") :: TextLabel).Text = listing.posterName
			.. (listing.mine and " (you)" or "")

		badge.Text = listing.autoTrade and "AUTO-TRADE" or "ASK FIRST"
		badge.TextColor3 = listing.autoTrade and Theme.Good or Theme.Warn
		fillOfferChips(giveHolder, giveGemsIcon, giveGemsLabel, listing.give) -- what the poster GIVES you
		fillOfferChips(wantHolder, wantGemsIcon, wantGemsLabel, listing.want) -- what they WANT from you

		-- the verdict, right after the want side so it reads as part of the trade
		valueChip.Text, valueChip.TextColor3 = verdictFor(listing)

		-- time-left pill: surfaces the presence-tied lifetime — otherwise
		-- invisible — so players learn staying online keeps an ad alive
		if listing.here then
			timePill.Text = "Live · you're in game"
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
		if boostBadge.Visible then
			local icon = tier >= TradeAdConfig.BoostTier.Featured and "★ FEATURED" or "⚡ BOOSTED"
			-- no boostExpiresAt means the tier comes from a pass perk, which
			-- has no clock to count down
			if listing.boostExpiresAt then
				boostBadge.Text = ("%s · %s"):format(icon, boostLeftText(listing.boostExpiresAt))
			else
				boostBadge.Text = icon
			end
			boostBadge.TextColor3 = tier >= TradeAdConfig.BoostTier.Featured and Theme.Gold or Theme.Warn
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

	-- Fill one side of a featured card: ONE named, priced item plus a "+N more"
	-- line. The card is fixed-height on purpose (a wrapping summary used to
	-- jitter every card's height), and one item with a name and a value is
	-- worth more to a trader than three anonymous icons.
	local function fillFeaturedSide(holder: Frame, offer: any)
		local more = holder:WaitForChild("MoreLabel") :: TextLabel
		local entry = offer.items[1]
		if entry then
			local chip = featuredMiniChip:Clone()
			chip.Name = "chip"
			chip.Visible = true
			chip.LayoutOrder = 1
			Components.setIcon(chip:WaitForChild("Icon") :: ImageLabel, { imageId = entry.imageId, name = entry.name })
			;(chip:WaitForChild("NameLabel") :: TextLabel).Text = entry.name
			;(chip:WaitForChild("CountLabel") :: TextLabel).Text = countValueText(entry)
			chip.Parent = holder
			table.insert(featuredSpawned, chip)
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
		-- gems on a side still count as "something else in this trade"
		local extra = #offer.items - (entry and 1 or 0)
		if offer.gems > 0 then
			extra += 1
		end
		more.Visible = extra > 0
		more.Text = extra > 0 and ("+%d more"):format(extra) or ""
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

				-- what / how much / is it fair — the three things a trader
				-- decides on. Anything less and the paid card is worth less
				-- than the free row underneath it.
				fillFeaturedSide(card:WaitForChild("GiveHolder") :: Frame, listing.give)
				fillFeaturedSide(card:WaitForChild("WantHolder") :: Frame, listing.want)

				local verdict = card:WaitForChild("VerdictLabel") :: TextLabel
				verdict.Text, verdict.TextColor3 = verdictFor(listing)

				-- countdown only: every card in this strip is featured, so
				-- repeating the word on each one was noise against the art
				local tierLabel = card:WaitForChild("TierLabel") :: TextLabel
				tierLabel.Text = listing.boostExpiresAt and boostLeftText(listing.boostExpiresAt) or "Featured"

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
			boostStrip.Visible = true
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
				result.ok and "Posted to the board!" or ("Couldn't post: " .. tostring(result.err)),
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
