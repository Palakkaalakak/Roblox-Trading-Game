--!strict
-- ProductService: the single owner of Roblox purchases.
--
-- Roblox allows exactly ONE MarketplaceService.ProcessReceipt handler per
-- game, so every paid thing routes through here: shop gem packs, bundles,
-- gamepasses, subscriptions, rewarded-ad payouts, and the tradeable token
-- items from ProductConfig. Each is registered by productId with a grant
-- function; the receipt handler just looks up and dispatches.
--
-- Two catalogues feed it:
--   * MonetizationConfig.Offers — the shop (gems / bundles / passes / subs)
--   * ProductConfig.Products    — tradeable TOKEN items (a gamepass you can
--                                 trade; benefits key off HOLDING the token,
--                                 never off MarketplaceService ownership)
--
-- Adding a new sellable thing is a config entry in one of those two files.
-- Nothing here needs to change.
--
-- IDEMPOTENCY: every grant goes through InventoryService.applyDelta with a
-- claimId (receipt_<PurchaseId> / gamepass_<id>_<userId>). Replayed receipts
-- are no-ops, which is what lets us return PurchaseGranted safely.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Enums)
local ProductConfig = require(ReplicatedStorage.Shared.Config.ProductConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local TradeAdConfig = require(ReplicatedStorage.Shared.Config.TradeAdConfig)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local UNLIMITED_SUPPLY = 1_000_000_000 -- registry cap for unlimited-mint tokens

local ProductService = {}

-- productId -> { grant = (player, claimId) -> boolean, label = string }
local devProductHandlers: { [number]: any } = {}
local gamepassHandlers: { [number]: any } = {}
-- gamepassId -> offer/def, for the client's OWNED state
local gamepassOffers: { [number]: any } = {}

-- productId -> price in Robux. Filled lazily from GetProductInfo and cached so
-- the shop can print the real price on the BUY button (Blox-Fruits style)
-- without re-querying Roblox every time the shop opens.
local priceCache: { [number]: number } = {}

local function tokenItemId(sku: string): string
	return "prod_" .. sku
end

-- Robux price for an offer, cached. nil if it can't be resolved (no id yet,
-- not for sale, or the lookup failed).
local function priceInRobux(offer: any): number?
	local id = offer.productId
	if id == 0 then
		return nil
	end
	if priceCache[id] ~= nil then
		return priceCache[id]
	end
	local infoType = offer.productType == "gamepass" and Enum.InfoType.GamePass or Enum.InfoType.Product
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType)
	end)
	if ok and typeof(info) == "table" and info.PriceInRobux then
		priceCache[id] = info.PriceInRobux
		return info.PriceInRobux
	end
	return nil
end

--------------------------------------------------------------------------------
-- Grant kinds
--------------------------------------------------------------------------------

-- Tradeable token item (ProductConfig): draws from reserve when capped.
local function grantToken(player: Player, def: any, claimId: string): boolean
	local itemId = tokenItemId(def.sku)
	if def.totalSupply then
		if not EconomyService.reserveOne(itemId) then
			return false -- cap reached; leave the receipt pending
		end
	end
	local ok = InventoryService.applyDelta(player, { items = { [itemId] = 1 } }, Enums.GrantSource.Purchase, claimId)
	if ok then
		task.spawn(function()
			DataService.saveNow(player)
		end)
		AnalyticsService.log("product_granted", { userId = player.UserId, itemId = itemId, claimId = claimId })
	end
	return ok == true
end

-- Shop offer: gems, items, or both, in a single delta so it can't half-apply.
local function grantOffer(player: Player, offer: any, claimId: string): boolean
	local delta: any = {}
	if offer.grants.gems then
		delta.gems = offer.grants.gems
	end
	if offer.grants.items then
		local items = {}
		for itemId, count in offer.grants.items do
			items[itemId] = count
		end
		delta.items = items
	end
	-- Booth grants don't touch the inventory: shelf space and a skin live on the
	-- profile, not as items. Idempotent by construction — granting an owned skin
	-- or clamping at MaxSlots is a no-op — so a replayed receipt is safe.
	-- Ad perk grants flip a profile flag directly -- no inventory delta, no
	-- escrow. Idempotent: setting an already-true flag is a no-op, so a
	-- replayed receipt is safe.
	if offer.grants.adPerk then
		local prof = DataService.getProfile(player)
		if prof then
			prof.AdPerks = prof.AdPerks or { priority = false, duration = false }
			prof.AdPerks[offer.grants.adPerk] = true
			task.spawn(function()
				DataService.saveNow(player)
			end)
			AnalyticsService.log("offer_granted", {
				userId = player.UserId,
				offerId = offer.id,
				adPerk = offer.grants.adPerk,
				claimId = claimId,
			})
		end
		return prof ~= nil
	end

	-- Ad slots stack, so unlike the perk flags above this grant is NOT naturally
	-- idempotent -- a replayed receipt would hand out a second slot. ProcessReceipt
	-- dedupes on claimId before we get here, which is what makes the increment
	-- safe; the clamp is a ceiling, not a dedupe.
	if offer.grants.adSlots then
		local prof = DataService.getProfile(player)
		if prof then
			prof.TradeAds = prof.TradeAds or { extraSlots = 0, credits = {} }
			prof.TradeAds.extraSlots =
				math.min((prof.TradeAds.extraSlots or 0) + offer.grants.adSlots, TradeAdConfig.MaxExtraSlots)
			task.spawn(function()
				DataService.saveNow(player)
			end)
			AnalyticsService.log("offer_granted", {
				userId = player.UserId,
				offerId = offer.id,
				adSlots = offer.grants.adSlots,
				extraSlots = prof.TradeAds.extraSlots,
				claimId = claimId,
			})
		end
		return prof ~= nil
	end

	if offer.boothSlot or offer.boothSkin then
		local booth = require(script.Parent.BoothService)
		local granted = if offer.boothSkin
			then booth.grantSkin(player, offer.boothSkin)
			else booth.grantSlot(player)
		if granted then
			task.spawn(function()
				DataService.saveNow(player)
			end)
			AnalyticsService.log("offer_granted", {
				userId = player.UserId,
				offerId = offer.id,
				booth = offer.boothSkin or "slot",
				claimId = claimId,
			})
		end
		return granted
	end

	if delta.gems == nil and delta.items == nil then
		return false
	end
	local ok = InventoryService.applyDelta(player, delta, Enums.GrantSource.Purchase, claimId)
	if ok then
		task.spawn(function()
			DataService.saveNow(player)
		end)
		AnalyticsService.log("offer_granted", {
			userId = player.UserId,
			offerId = offer.id,
			gems = offer.grants.gems or 0,
			claimId = claimId,
		})
	end
	return ok == true
end

-- Public: the live Robux price of an offer, by offer id. Any surface that sells
-- something outside the shop panel (the booth's skin picker) needs the real
-- number rather than the word "Robux" — a price nobody can see is a price
-- nobody decides on. Shares the same cache the shop uses, so asking costs one
-- GetProductInfo per product for the life of the server.
-- Returns nil when the offer has no real id yet, so callers can fall back.
function ProductService.priceOf(offerId: string): number?
	for _, offer in MonetizationConfig.Offers do
		if offer.id == offerId then
			return priceInRobux(offer)
		end
	end
	return nil
end

-- Public: let other services (rewarded ads) register a dev product handler.
-- Keeps ProcessReceipt owned in exactly one place.
function ProductService.registerDevProduct(productId: number, label: string, grant: (Player, string) -> boolean)
	if productId == 0 then
		return
	end
	-- Handlers are keyed by product id, so a second registration for the same id
	-- would silently replace the first and pay out the wrong thing. Refuse it
	-- loudly instead: this is real money, and the failure is otherwise invisible
	-- until a player buys something and gets someone else's reward.
	local existing = devProductHandlers[productId]
	if existing then
		-- During development everything monetized points at one placeholder
		-- product, so collisions here are expected and harmless: the first
		-- handler keeps the id and the rest simply don't pay out yet. A collision
		-- between two REAL products is a money bug, so that one is shouted about.
		if productId ~= MonetizationConfig.PlaceholderProductId then
			warn(("[ProductService] dev product %d already grants %q; refusing to re-register it as %q")
				:format(productId, existing.label, label))
		end
		return
	end
	devProductHandlers[productId] = { grant = grant, label = label }
end

--------------------------------------------------------------------------------

function ProductService.Init()
	-- shop offers
	for _, offer in MonetizationConfig.liveOffers() do
		local handler = {
			label = offer.id,
			grant = function(player: Player, claimId: string)
				return grantOffer(player, offer, claimId)
			end,
		}
		if offer.productType == "gamepass" then
			gamepassHandlers[offer.productId] = handler
			gamepassOffers[offer.productId] = offer
		else
			devProductHandlers[offer.productId] = handler
		end
	end

	-- tradeable token items
	if #ProductConfig.Products > 0 then
		local defs = {}
		for _, def in ProductConfig.Products do
			table.insert(defs, {
				itemId = tokenItemId(def.sku),
				poolId = "products",
				name = def.name,
				totalSupply = def.totalSupply or UNLIMITED_SUPPLY,
				assignmentWeight = 0,
				imageId = def.imageId,
				eventItem = true, -- not gem-purchasable: "N/A (Event Item)"
				productType = def.productType,
				productId = def.productId,
			})
			local handler = {
				label = def.sku,
				grant = function(player: Player, claimId: string)
					return grantToken(player, def, claimId)
				end,
			}
			if def.productType == "devproduct" then
				devProductHandlers[def.productId] = handler
			else
				gamepassHandlers[def.productId] = handler
			end
		end
		EconomyService.registerItems(defs)
	end

	-- surface unconfigured entries rather than silently dropping them
	for _, offer in MonetizationConfig.Offers do
		if offer.productId == 0 then
			warn(("[Shop] offer %q has no Roblox productId yet — hidden from the shop"):format(offer.id))
		end
	end
end

function ProductService.Start()
	-- THE single receipt handler for the whole game.
	MarketplaceService.ProcessReceipt = function(receipt)
		local handler = devProductHandlers[receipt.ProductId]
		if handler == nil then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if player == nil or not DataService.isLoaded(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local granted = handler.grant(player, "receipt_" .. receipt.PurchaseId)
		return granted and Enum.ProductPurchaseDecision.PurchaseGranted
			or Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- gamepasses: grant once on join for owners (idempotent via claimId)
	DataService.ProfileLoaded:Connect(function(player, _profile)
		for passId, handler in gamepassHandlers do
			task.spawn(function()
				local owns = false
				pcall(function()
					owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
				end)
				if owns then
					handler.grant(player, ("gamepass_%d_%d"):format(passId, player.UserId))
				end
			end)
		end
	end)

	-- The shop catalogue the client renders. Sends only what the UI needs, plus
	-- which gamepasses this player already owns (for the OWNED state).
	Net.bindFunction("GetShop", function(player)
		local offers = {}
		for _, offer in MonetizationConfig.visibleOffers() do
			local sellable = offer.productId ~= 0
			local owned = false
			if sellable and offer.productType == "gamepass" then
				pcall(function()
					owned = MarketplaceService:UserOwnsGamePassAsync(player.UserId, offer.productId)
				end)
			end
			table.insert(offers, {
				sellable = sellable,
				id = offer.id,
				kind = offer.kind,
				section = offer.section,
				name = offer.name,
				description = offer.description,
				imageId = offer.imageId,
				productType = offer.productType,
				productId = offer.productId,
				gems = offer.grants.gems,
				badge = offer.badge,
				bonusPercent = offer.bonusPercent,
				wasRobux = offer.wasRobux,
				availableUntil = offer.availableUntil,
				nameColor = offer.nameColor,
				featured = offer.featured,
				accent = offer.accent,
				price = priceInRobux(offer),
				owned = owned,
			})
		end
		return {
			ok = true,
			offers = offers,
			sectionOrder = MonetizationConfig.SectionOrder,
			sectionLayout = MonetizationConfig.SectionLayout,
		}
	end)

	-- Purchases must be prompted server-side so the client can't invent products.
	Net.bindFunction("PromptPurchase", function(player, offerId)
		if not Guard.isString(offerId, 64) then
			return { ok = false, err = "bad_args" }
		end
		for _, offer in MonetizationConfig.liveOffers() do
			if offer.id == offerId then
				local ok = pcall(function()
					if offer.productType == "gamepass" then
						MarketplaceService:PromptGamePassPurchase(player, offer.productId)
					else
						MarketplaceService:PromptProductPurchase(player, offer.productId)
					end
				end)
				return { ok = ok }
			end
		end
		return { ok = false, err = "unknown_offer" }
	end)
end

return ProductService
