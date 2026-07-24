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

local function tokenItemId(sku: string): string
	return "prod_" .. sku
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

-- Public: let other services (rewarded ads) register a dev product handler.
-- Keeps ProcessReceipt owned in exactly one place.
function ProductService.registerDevProduct(productId: number, label: string, grant: (Player, string) -> boolean)
	if productId == 0 then
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
				owned = owned,
			})
		end
		return { ok = true, offers = offers, sectionOrder = MonetizationConfig.SectionOrder }
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
