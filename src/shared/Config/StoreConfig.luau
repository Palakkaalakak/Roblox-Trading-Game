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
-- Pricing (computed live server-side):
--   price = StoreCostByRarity[rarity]                 (higher rarity = pricier)
--         * (SupplyReference / totalSupply) ^ SupplyExponent   (scarcer cap = pricier)
--         * (1 + DepletionRamp * fractionSold)        (price climbs as stock sells)

local StoreConfig = {
	-- price knobs
	SupplyReference = 100,
	SupplyExponent = 0.5,
	DepletionRamp = 1.0, -- last copy costs (1 + ramp) x the fresh price

	-- world hookup: ProximityPrompt with this name opens the store
	PromptName = "StorePrompt",

	Catalog = {
		{ sku = "golden_rocket", name = "Golden Rocket", totalSupply = 40, imageId = "rbxassetid://16670799841" },
		{ sku = "eternal_flame", name = "Eternal Flame", totalSupply = 60, imageId = "rbxassetid://15403144723" },
		{ sku = "frozen_star", name = "Frozen Star", totalSupply = 30, imageId = "rbxassetid://15403116835" },
		{ sku = "royal_ticket", name = "Royal Ticket", totalSupply = 100, imageId = "rbxassetid://17368125421" },
		{ sku = "shadow_key", name = "Shadow Key", totalSupply = 80, imageId = "rbxassetid://17368155868" },
		{ sku = "lucky_charm", name = "Lucky Charm", totalSupply = 120, imageId = "rbxassetid://17368085981" },
		{ sku = "mystery_crate", name = "Mystery Crate", totalSupply = 150, imageId = "rbxassetid://291724673" },
		{ sku = "golden_bobux", name = "Golden Bobux", totalSupply = 25, imageId = "rbxassetid://17368048685" },
		{ sku = "party_wheel", name = "Party Wheel", totalSupply = 90, imageId = "rbxassetid://17368197534" },
		{ sku = "ancient_disc", name = "Ancient Disc", totalSupply = 50, imageId = "rbxassetid://95668779942949" },
	},
}

return StoreConfig
