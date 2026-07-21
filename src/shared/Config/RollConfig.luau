--!strict
-- RollConfig: the gem gacha. Spend gems, get one item.
--
-- Rolls are the main paid way new goods enter the economy: a roll costs gems
-- (a sink) and mints one item from reserve into circulation. Nothing appears
-- on a timer — every new item was paid for.
--
-- Each tier is authored, not derived:
--   * window   — the four rarities this tier can produce (and the four rows
--                its card shows). Windows slide up the ladder as tiers get
--                pricier; the cheap tiers can't roll the top rarities and the
--                expensive tiers can't roll commons.
--   * odds     — the drop chance per rarity (percent, sums to 100). Authored
--                so the card shows exactly what happens. Pricier tiers weight
--                harder toward the high rarities.
--   * floorFrac — the tier's MINIMUM guaranteed value, as a fraction of its
--                gem price. A roll never returns an item worth less than
--                floorFrac * gems (items below it are dropped from the pool),
--                so the floor is a property of the TIER, not of whatever
--                rarity happened to drop. It rises with tier: a Basic roll
--                guarantees a little of its cost back, a Mythic roll most of it.
--
-- HARD RULE: a roll only ever produces an item with reserve left. The last
-- copy of a limited leaves reserve and can never be rolled again.

local RollConfig = {
	Enabled = true,

	-- world hookup: ProximityPrompt with this name opens the Rolls panel
	PromptName = "RollsPrompt",

	-- A roll can be paid in gems OR in items whose combined live Value covers
	-- the price. Item payments are REDISTRIBUTED back into reserve (someone
	-- else can roll them out), so items that can never be re-made (outputs of
	-- ended limited events) are refused — see EventConfig.isReobtainable.

	-- Five cost levels, cheapest first.
	Tiers = {
		{
			id = "basic",
			name = "Basic Roll",
			gems = 12,
			floorFrac = 0.35,
			window = { "Common", "Rare", "Legendary", "Mythical" },
			odds = { Common = 96.0, Rare = 3.2, Legendary = 0.6, Mythical = 0.2 },
			blurb = "Cheapest roll. Almost always a common.",
		},
		{
			id = "solid",
			name = "Solid Roll",
			gems = 25,
			floorFrac = 0.42,
			window = { "Common", "Rare", "Legendary", "Mythical" },
			odds = { Common = 74.0, Rare = 21.0, Legendary = 4.0, Mythical = 1.0 },
			blurb = "Commons still likely, but rares show up.",
		},
		{
			id = "lucky",
			name = "Lucky Roll",
			gems = 55,
			floorFrac = 0.46,
			window = { "Rare", "Legendary", "Mythical", "Godly" },
			odds = { Rare = 73.0, Legendary = 21.0, Mythical = 5.0, Godly = 1.0 },
			blurb = "No commons. Rares and up, real shot at legendaries.",
		},
		{
			id = "grand",
			name = "Grand Roll",
			gems = 110,
			floorFrac = 0.50,
			window = { "Rare", "Legendary", "Mythical", "Godly" },
			odds = { Rare = 40.0, Legendary = 38.0, Mythical = 17.0, Godly = 5.0 },
			blurb = "Legendaries common, mythicals within reach.",
		},
		{
			id = "mythic",
			name = "Mythic Roll",
			gems = 240,
			floorFrac = 0.52,
			window = { "Legendary", "Mythical", "Godly", "Celestial" },
			odds = { Legendary = 50.0, Mythical = 33.0, Godly = 12.0, Celestial = 5.0 },
			blurb = "Legendary floor. Best odds on godly and celestial.",
		},
	},
}

return RollConfig
