--!strict
-- ProductConfig: Robux products (gamepasses / dev products) granted as
-- TRADEABLE TOKEN ITEMS.
--
-- Roblox cannot transfer gamepass ownership between players, so the pattern
-- is: buying the product grants a normal registry ITEM (a "token"); the token
-- trades like any other item; gameplay benefits key off HOLDING the token
-- (check the player's inventory), not off MarketplaceService ownership.
--
-- DEV WORKFLOW — selling a product as a tradeable item:
--   1. Create the gamepass / dev product on the Roblox website.
--   2. Add an entry below with its id. `sku` must be new/unique
--      (itemId becomes "prod_<sku>").
--   3. Reboot. ProductService registers the token item and grants one per
--      purchase receipt. Dev products can be bought repeatedly; gamepasses
--      grant their token once on first join with the pass owned.
--
-- Empty by default — this is future-phase infrastructure; nothing binds to
-- MarketplaceService until an entry exists.

export type ProductDef = {
	sku: string,
	name: string,
	productType: "gamepass" | "devproduct",
	productId: number,
	totalSupply: number?, -- nil = unlimited mints (supply grows per purchase)
	imageId: string?,
}

local ProductConfig = {
	Products = {} :: { ProductDef },
	-- Example:
	-- {
	-- 	sku = "vip_token",
	-- 	name = "VIP Token",
	-- 	productType = "gamepass",
	-- 	productId = 123456789,
	-- 	imageId = "rbxassetid://16912465495",
	-- },
}

return ProductConfig
