--!strict
-- StoreConfig: the NPC limited-item store.
--
-- EVERY store item is limited. When its copies are gone it shows SOLD OUT.
--
-- DEV WORKFLOW — replacing a sold-out item:
--   1. Edit the Catalog entry below: new `sku`, `name`, `totalSupply`,
--      `imageId`. The sku MUST be new/unique (it becomes the itemId
--      "store_<sku>") — never reuse a sku, the old item lives on in player
--      inventories and stays tradeable.
--   2. That's it. Next server boot registers the new item and the store
--      sells it. The old entry can be deleted from this list.
--
-- Pricing is a FIXED gem `price` set per item below — not formula-derived.
-- Edit a `price` to change what it costs; the price never moves as stock sells.

local StoreConfig = {
	-- Per-player PURCHASE limit (persisted; trading is unaffected — players
	-- can hold more via trades, they just can't BUY more than this).
	-- Per-item override: add `maxPerPlayer = N` to a Catalog entry.
	-- Gamepass/per-player boosts: extend StoreService.buyLimitFor().
	DefaultMaxPerPlayer = 1,

	-- world hookup: ProximityPrompt with this name opens the store
	PromptName = "StorePrompt",

	-- Rotating shelf: only ActiveCount catalog items are on sale per time
	-- window; the set changes every RotationIntervalSeconds (deterministic —
	-- all servers agree). Off-shelf items can't be bought until they rotate
	-- back in. Set enabled = false for a static always-on catalog.
	Rotation = {
		enabled = true,
		RotationIntervalSeconds = 6 * 3600, -- 6h shelves
		ActiveCount = 6,
	},

	-- SALES. Every DiscountIntervalSeconds a deterministic slice of whatever is
	-- on the shelf goes on sale at PercentOff. Same trick as the shelf itself:
	-- a pure function of the clock, so every server agrees with no coordination.
	--
	-- This isn't decoration — a discount is a real demand signal. A sale price
	-- under market Value is free profit, so traders pile in, that item's stock
	-- drains, and it gets scarcer (which lifts its Value for everyone holding
	-- one). Sales rotate faster than the shelf so there's always something
	-- moving.
	Discounts = {
		enabled = true,
		DiscountIntervalSeconds = 900, -- a fresh sale every 15 minutes
		Count = 2, -- how many of the on-shelf items are on sale at once
		PercentOff = 35,
	},

	-- Each item: fixed `price` (gems), `totalSupply` (stock), `imageId`.
	Catalog = {
		{ sku = "golden_rocket", name = "Golden Rocket", price = 20, totalSupply = 40, imageId = "rbxassetid://16670799841" },
		{ sku = "eternal_flame", name = "Eternal Flame", price = 16, totalSupply = 60, imageId = "rbxassetid://15403144723" },
		{ sku = "frozen_star", name = "Frozen Star", price = 22, totalSupply = 30, imageId = "rbxassetid://15403116835" },
		{ sku = "royal_ticket", name = "Royal Ticket", price = 12, totalSupply = 100, imageId = "rbxassetid://17368125421" },
		{ sku = "shadow_key", name = "Shadow Key", price = 14, totalSupply = 80, imageId = "rbxassetid://17368155868" },
		{ sku = "lucky_charm", name = "Lucky Charm", price = 11, totalSupply = 120, imageId = "rbxassetid://17368085981" },
		{ sku = "mystery_crate", name = "Mystery Crate", price = 10, totalSupply = 150, imageId = "rbxassetid://291724673" },
		{ sku = "golden_bobux", name = "Golden Bobux", price = 25, totalSupply = 25, imageId = "rbxassetid://17368048685" },
		{ sku = "party_wheel", name = "Party Wheel", price = 13, totalSupply = 90, imageId = "rbxassetid://17368197534" },
		{ sku = "ancient_disc", name = "Ancient Disc", price = 18, totalSupply = 50, imageId = "rbxassetid://95668779942949" },
	},
}

return StoreConfig
