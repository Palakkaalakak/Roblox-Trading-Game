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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Enums)
local StoreConfig = require(ReplicatedStorage.Shared.Config.StoreConfig)
local Rotation = require(ReplicatedStorage.Shared.Util.Rotation)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local StoreService = {}

local catalogIds: { string } = {} -- ordered itemIds
local catalogSet: { [string]: boolean } = {}
local catalogMeta: { [string]: { maxPerPlayer: number? } } = {} -- itemId -> catalog extras
local catalogPrice: { [string]: number } = {}

local function itemIdFor(sku: string): string
	return "store_" .. sku
end

-- The catalog's IDENTITY (ids, prices, per-item limits) is a pure function of
-- config, so it's built at load rather than in Init. That keeps activeShelf /
-- priceFor Init-independent and testable — Init is only for the side effects
-- (registering the items with the economy).
for _, entry in StoreConfig.Catalog do
	local itemId = itemIdFor(entry.sku)
	table.insert(catalogIds, itemId)
	catalogSet[itemId] = true
	catalogMeta[itemId] = { maxPerPlayer = entry.maxPerPlayer }
	catalogPrice[itemId] = entry.price
end

-- Fixed gem price of a store item (set in StoreConfig, never formula-derived).
function StoreService.priceFor(itemId: string): number
	return catalogPrice[itemId] or 0
end

-- Which catalog itemIds are ON THE SHELF right now, plus when the shelf
-- rotates. Deterministic from the clock — every server agrees.
function StoreService.activeShelf(now: number): ({ [string]: boolean }, number?)
	local rot = StoreConfig.Rotation
	if not (rot and rot.enabled) then
		local all = {}
		for _, itemId in catalogIds do
			all[itemId] = true
		end
		return all, nil
	end
	local windowIdx = Rotation.windowIndex(now, rot.RotationIntervalSeconds)
	local active = {}
	for _, catalogIndex in Rotation.pick(windowIdx, #catalogIds, rot.ActiveCount) do
		active[catalogIds[catalogIndex]] = true
	end
	return active, Rotation.windowEndsAt(now, rot.RotationIntervalSeconds)
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

local function listing(player: Player): ({ any }, number?)
	local profile = DataService.getProfile(player)
	local shelf, rotatesAt = StoreService.activeShelf(os.time())
	local out = {}
	for _, itemId in catalogIds do
		if shelf[itemId] then
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
					price = StoreService.priceFor(itemId),
					limit = StoreService.buyLimitFor(player, itemId),
					purchased = profile and purchasedCount(profile, itemId) or 0,
				})
			end
		end
	end
	return out, rotatesAt
end

-- Market bots buy from the store too (same caps, same CAS stock draw);
-- their charges/records live in BotService state instead of a profile.
local function bots(): any
	return require(script.Parent.BotService)
end

local function buyCore(userId: number, itemId: any)
	if not Guard.isString(itemId, 64) or not catalogSet[itemId] then
		return { ok = false, err = "not_store_item" }
	end
	local shelf = StoreService.activeShelf(os.time())
	if not shelf[itemId] then
		return { ok = false, err = "not_on_shelf" } -- rotated out right now
	end
	local item = EconomyService.getItem(itemId)
	local snap = EconomyService.snapshot(itemId)
	if item == nil or snap == nil then
		return { ok = false, err = "unknown_item" }
	end

	local isBot = userId < 0
	local player = if isBot then nil else Players:GetPlayerByUserId(userId)
	local profile = player and DataService.getProfile(player) or nil

	-- per-buyer lifetime cap (purchases only; trading in more is fine)
	local meta = catalogMeta[itemId]
	local limit = (meta and meta.maxPerPlayer) or StoreConfig.DefaultMaxPerPlayer
	local bought = if isBot then bots().storeCount(userId, itemId) else (profile and purchasedCount(profile, itemId) or 0)
	if bought >= limit then
		return { ok = false, err = "buy_limit", limit = limit }
	end

	local remaining = snap.reserveRemaining or 0
	if remaining <= 0 then
		return { ok = false, err = "out_of_stock" }
	end

	local price = StoreService.priceFor(itemId)

	-- charge first (validates funds atomically)...
	local charged, chargeErr
	if isBot then
		charged, chargeErr = bots().applyDelta(userId, { gems = -price }, Enums.GrantSource.Store)
	else
		charged, chargeErr = InventoryService.applyDelta(player :: Player, { gems = -price }, Enums.GrantSource.Store)
	end
	if not charged then
		return { ok = false, err = chargeErr }
	end
	-- ...then take a copy out of stock. Bots use the lazy in-memory reserve
	-- (leader-local; no per-buy DataStore write) so 500 bots buying store
	-- stock each sweep can't stall the shared request budget; real players
	-- keep the strong cross-server CAS.
	local reserved = if isBot then EconomyService.reserveOneLazy(itemId) else EconomyService.reserveOne(itemId)
	if not reserved then
		if isBot then
			bots().applyDelta(userId, { gems = price }, Enums.GrantSource.Refund)
		else
			InventoryService.applyDelta(player :: Player, { gems = price }, Enums.GrantSource.Refund)
		end
		return { ok = false, err = "out_of_stock" }
	end
	if isBot then
		bots().applyDelta(userId, { items = { [itemId] = 1 } }, Enums.GrantSource.Store)
		bots().bumpStoreCount(userId, itemId)
	else
		InventoryService.applyDelta(player :: Player, { items = { [itemId] = 1 } }, Enums.GrantSource.Store)
		if profile then
			profile.StorePurchases[itemId] = purchasedCount(profile, itemId) + 1
		end
		DataService.saveNow(player :: Player)
	end

	AnalyticsService.log("store_purchase", { userId = userId, itemId = itemId, price = price })
	return { ok = true, price = price, purchased = bought + 1, limit = limit }
end

local function handleBuy(player: Player, itemId: any)
	if not DataService.isLoaded(player) then
		return { ok = false, err = "loading" }
	end
	return buyCore(player.UserId, itemId)
end

-- Bot entry: buy one copy at the fixed store price.
function StoreService.botBuy(botId: number, itemId: string)
	return buyCore(botId, itemId)
end

-- Bot-readable shelf: {itemId, price, remaining} for what's buyable now.
function StoreService.shelfForBots(): { any }
	local shelf = StoreService.activeShelf(os.time())
	local out = {}
	for itemId in shelf do
		local snap = EconomyService.snapshot(itemId)
		if snap and (snap.reserveRemaining or 0) > 0 then
			table.insert(out, {
				itemId = itemId,
				price = StoreService.priceFor(itemId),
				remaining = snap.reserveRemaining,
			})
		end
	end
	return out
end

function StoreService.Init()
	-- register the whole catalog as real items (idempotent; new skus appear
	-- after a config edit + reboot, sold-out old ones just stop being listed).
	-- The id/price/limit tables are already built at module load — see above.
	local defs = {}
	for _, entry in StoreConfig.Catalog do
		local itemId = itemIdFor(entry.sku)
		table.insert(defs, {
			itemId = itemId,
			poolId = "store",
			name = entry.name,
			totalSupply = entry.totalSupply,
			assignmentWeight = 0, -- never part of starter draws
			imageId = entry.imageId,
			storeCost = entry.price, -- displayed Store Cost = the fixed store price
		})
	end
	EconomyService.registerItems(defs)
end

function StoreService.Start()
	Net.bindFunction("GetStore", function(player)
		local items, rotatesAt = listing(player)
		return { ok = true, items = items, rotatesAt = rotatesAt }
	end)
	Net.bindFunction("BuyItem", handleBuy)

	-- prewarm the per-item economy records at boot: first store open used to
	-- do ~10 cold sequential MemoryStore reads and sit blank for seconds
	task.spawn(function()
		for _, itemId in catalogIds do
			EconomyService.snapshot(itemId)
		end
	end)
end

return StoreService
