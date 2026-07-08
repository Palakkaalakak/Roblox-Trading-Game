--!strict
-- ProductService: Robux gamepasses / dev products granted as TRADEABLE token
-- items (see ProductConfig for the pattern + dev workflow).
--
-- Infrastructure only until ProductConfig.Products has entries; then:
--   * token items are registered in the global registry (tradeable, with
--     existence tracking; unlimited-mint tokens grow supply per purchase)
--   * dev products: ProcessReceipt grants one token per purchase (idempotent
--     via the receipt's PurchaseId)
--   * gamepasses: one-time token grant on join for owners (idempotent via
--     profile.ClaimedIds)
-- Benefits should key off HOLDING the token (inventory check), never off
-- MarketplaceService ownership — that's what makes them tradeable.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Enums)
local ProductConfig = require(ReplicatedStorage.Shared.Config.ProductConfig)

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local UNLIMITED_SUPPLY = 1_000_000_000 -- registry cap for unlimited-mint tokens

local ProductService = {}

local byDevProductId: { [number]: any } = {}
local byGamepassId: { [number]: any } = {}

local function tokenItemId(sku: string): string
	return "prod_" .. sku
end

local function grantToken(player: Player, def: any, claimId: string): boolean
	local itemId = tokenItemId(def.sku)
	-- limited tokens draw from the reserve; unlimited ones mint freely
	if def.totalSupply then
		local reserved = EconomyService.reserveOne(itemId)
		if not reserved then
			return false -- cap reached; receipt stays pending / no grant
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

function ProductService.Init()
	if #ProductConfig.Products == 0 then
		return -- pure future-phase infra; nothing to register yet
	end
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
		if def.productType == "devproduct" then
			byDevProductId[def.productId] = def
		else
			byGamepassId[def.productId] = def
		end
	end
	EconomyService.registerItems(defs)
end

function ProductService.Start()
	if #ProductConfig.Products == 0 then
		return
	end

	-- dev products: one token per purchase, idempotent on PurchaseId
	MarketplaceService.ProcessReceipt = function(receipt)
		local def = byDevProductId[receipt.ProductId]
		if def == nil then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if player == nil or not DataService.isLoaded(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local granted = grantToken(player, def, "receipt_" .. receipt.PurchaseId)
		return granted and Enum.ProductPurchaseDecision.PurchaseGranted
			or Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- gamepasses: one-time token on join for owners
	DataService.ProfileLoaded:Connect(function(player, _profile)
		for passId, def in byGamepassId do
			task.spawn(function()
				local owns = false
				pcall(function()
					owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
				end)
				if owns then
					grantToken(player, def, ("gamepass_%d_%d"):format(passId, player.UserId))
				end
			end)
		end
	end)
end

return ProductService
