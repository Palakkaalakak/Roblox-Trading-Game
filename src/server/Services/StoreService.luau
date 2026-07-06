--!strict
-- StoreService: the NPC limited-item store.
--
-- Catalog items are ordinary registry items (poolId "store") whose
-- reserveRemaining IS the shop stock: buying reserves one copy atomically
-- (same MemoryStore CAS as starter draws), so cross-server double-sells are
-- impossible, existence counts stay exact, and sold items trade like any
-- other item afterward.
--
-- Purchase flow: quote price -> charge gems -> reserve copy -> grant item.
-- Reserve failure (sold out under us) refunds the charge. All same-server,
-- in-memory profile ops => no partial state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Enums)
local StoreConfig = require(ReplicatedStorage.Shared.Config.StoreConfig)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimitService = require(script.Parent.RateLimitService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local StoreService = {}

local catalogIds: { string } = {} -- ordered itemIds
local catalogSet: { [string]: boolean } = {}
local catalogMeta: { [string]: { maxPerPlayer: number? } } = {} -- itemId -> catalog extras

local function itemIdFor(sku: string): string
	return "store_" .. sku
end

-- How many of this item ONE player may buy from the store (lifetime).
-- Purchases only — trading in more is always allowed. Single extension point:
--   * per-item override via Catalog `maxPerPlayer`
--   * later: gamepass/VIP boosts keyed on `player` (add checks here)
--   * later: per-item event rules
function StoreService.buyLimitFor(player: Player, itemId: string): number
	local meta = catalogMeta[itemId]
	local limit = (meta and meta.maxPerPlayer) or StoreConfig.DefaultMaxPerPlayer
	-- e.g. future: if PassService.owns(player, DOUBLE_BUY_PASS) then limit *= 2 end
	return limit
end

-- Lifetime store-buy count for a player+item (lazy-inits legacy profiles).
local function purchasedCount(profile: any, itemId: string): number
	if profile.StorePurchases == nil then
		profile.StorePurchases = {}
	end
	return profile.StorePurchases[itemId] or 0
end

-- Live price for a store item. Pure given (totalSupply, remaining).
-- Supply-driven so scarcer items cost more; climbs as stock depletes.
function StoreService.priceFor(totalSupply: number, remaining: number): number
	local supplyFactor = (StoreConfig.SupplyReference / math.max(totalSupply, 1)) ^ StoreConfig.SupplyExponent
	local sold = math.clamp(1 - remaining / math.max(totalSupply, 1), 0, 1)
	local ramp = 1 + StoreConfig.DepletionRamp * sold
	return math.max(1, math.floor(StoreConfig.BaseGems * supplyFactor * ramp + 0.5))
end

local function listing(player: Player): { any }
	local profile = DataService.getProfile(player)
	local out = {}
	for _, itemId in catalogIds do
		local item = EconomyService.getItem(itemId)
		local snap = EconomyService.snapshot(itemId)
		if item and snap then
			local remaining = snap.reserveRemaining or 0
			table.insert(out, {
				itemId = itemId,
				name = item.name,
				rarity = item.rarity,
				imageId = item.imageId,
				totalSupply = item.totalSupply,
				remaining = remaining,
				price = StoreService.priceFor(item.totalSupply, remaining),
				limit = StoreService.buyLimitFor(player, itemId),
				purchased = profile and purchasedCount(profile, itemId) or 0,
			})
		end
	end
	return out
end

local function handleBuy(player: Player, itemId: any)
	if not RateLimitService.check(player, "BuyItem") then
		return { ok = false, err = "rate_limited" }
	end
	if not DataService.isLoaded(player) then
		return { ok = false, err = "loading" }
	end
	if not Guard.isString(itemId, 64) or not catalogSet[itemId] then
		return { ok = false, err = "not_store_item" }
	end
	local item = EconomyService.getItem(itemId)
	local snap = EconomyService.snapshot(itemId)
	if item == nil or snap == nil then
		return { ok = false, err = "unknown_item" }
	end

	-- per-player buy limit (purchases only; trading in more is fine)
	local profile = DataService.getProfile(player)
	local limit = StoreService.buyLimitFor(player, itemId)
	if profile and purchasedCount(profile, itemId) >= limit then
		return { ok = false, err = "buy_limit", limit = limit }
	end

	local remaining = snap.reserveRemaining or 0
	if remaining <= 0 then
		return { ok = false, err = "out_of_stock" }
	end

	local price = StoreService.priceFor(item.totalSupply, remaining)

	-- charge first (validates funds atomically in-memory)...
	local charged, chargeErr = InventoryService.applyDelta(player, { gems = -price }, Enums.GrantSource.Store)
	if not charged then
		return { ok = false, err = chargeErr }
	end
	-- ...then take a copy out of stock (atomic cross-server CAS)
	local reserved = EconomyService.reserveOne(itemId)
	if not reserved then
		InventoryService.applyDelta(player, { gems = price }, Enums.GrantSource.Refund)
		return { ok = false, err = "out_of_stock" }
	end
	InventoryService.applyDelta(player, { items = { [itemId] = 1 } }, Enums.GrantSource.Store)
	-- record the purchase against the player's limit
	if profile then
		profile.StorePurchases[itemId] = purchasedCount(profile, itemId) + 1
	end
	DataService.saveNow(player)

	AnalyticsService.log("store_purchase", { userId = player.UserId, itemId = itemId, price = price })
	return { ok = true, price = price, purchased = profile and profile.StorePurchases[itemId] or 1, limit = limit }
end

function StoreService.Init()
	-- register the whole catalog as real items (idempotent; new skus appear
	-- after a config edit + reboot, sold-out old ones just stop being listed)
	local defs = {}
	for _, entry in StoreConfig.Catalog do
		local itemId = itemIdFor(entry.sku)
		table.insert(catalogIds, itemId)
		catalogSet[itemId] = true
		catalogMeta[itemId] = { maxPerPlayer = entry.maxPerPlayer }
		table.insert(defs, {
			itemId = itemId,
			poolId = "store",
			name = entry.name,
			totalSupply = entry.totalSupply,
			assignmentWeight = 0, -- never part of starter draws
			imageId = entry.imageId,
			storeCost = StoreService.priceFor(entry.totalSupply, entry.totalSupply),
		})
	end
	EconomyService.registerItems(defs)
end

function StoreService.Start()
	Net.bindFunction("GetStore", function(player)
		if not RateLimitService.check(player, "GetStore") then
			return { ok = false, err = "rate_limited" }
		end
		return { ok = true, items = listing(player) }
	end)
	Net.bindFunction("BuyItem", handleBuy)
end

return StoreService
