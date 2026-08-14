--!strict
-- Items config: rarity thresholds, assignment-weight formula, starter bundle,
-- placeholder initial pool, and procedural pool-generation parameters.
-- Rarity is DERIVED from totalSupply via RarityThresholds — never hand-labeled.
-- assignmentWeight is a SEPARATE tunable; default derived sublinearly from supply
-- (supply^AssignmentWeightExponent) so rarer items draw less often but not never.

export type ItemDef = {
	itemId: string,
	name: string,
	totalSupply: number,
	assignmentWeight: number,
}

local Items = {
	-- How many weighpted draws each first-join starter bundle contains.
	-- Duplicates allowed (stack counts). K chosen so portfolios are
	-- heterogeneous enough for starter-vs-starter trading.
	StarterBundleSize = 5,

	-- Gems granted alongside the starter bundle. 0 for now — the gem faucet
	-- arrives with the shop phase; use the debug button meanwhile.
	StarterGems = 0,

	-- totalSupply >= threshold -> that tier (checked top-down). Below all ->
	-- Celestial (the rarest). SIX tiers: the top three (Mythical/Godly/
	-- Celestial) sit close together in supply so the VALUE ladder has no big
	-- cliff — roll tiers window four adjacent rarities each (see RollConfig).
	RarityThresholds = {
		{ tier = "Common", min = 20000 },
		{ tier = "Rare", min = 5000 },
		{ tier = "Legendary", min = 1200 },
		{ tier = "Mythical", min = 300 },
		{ tier = "Godly", min = 80 },
		-- < 80 -> Celestial (down to ~40)
	},

	-- assignmentWeight default = round(totalSupply ^ exponent * scale).
	AssignmentWeightExponent = 0.75,
	AssignmentWeightScale = 1,

	-- Store cost (gems) per rarity tier — ALSO the base Value seed (see
	-- EconomyService.seedFor). A smooth ~2x-per-tier ladder: no gap for a roll
	-- price to fall into and force a jackpot-only pool. Mythical eased down
	-- (500 -> 300) so it sits closer to Legendary; Godly/Celestial extend the top.
	StoreCostByRarity = {
		Common = 8,
		Rare = 35,
		Legendary = 130,
		Mythical = 300,
		Godly = 650,
		Celestial = 1300,
	},

	-- Placeholder initial pool (pool #1) — 12 diverse items spanning every
	-- tier so a fresh economy already has a wide value ladder. Spread satisfies
	-- the pool-generation invariant (>=3 Common, >=1 of each higher tier).
	-- imageId: decal ids from the Simulator Icon Pack (Workspace).
	InitialPool = {
		-- Common (plentiful, cheap)
		{ name = "Stone Relic", totalSupply = 52000, imageId = "rbxassetid://17368402884" }, -- crate
		{ name = "Copper Coin", totalSupply = 44000, imageId = "rbxassetid://15402844695" }, -- coin stack
		{ name = "Amber Idol", totalSupply = 33000, imageId = "rbxassetid://12129301834" }, -- trophy
		{ name = "Clay Totem", totalSupply = 24000, imageId = "rbxassetid://17368122337" }, -- box
		-- Rare
		{ name = "Jade Serpent", totalSupply = 14000, imageId = "rbxassetid://15403270948" }, -- green potion
		{ name = "Sunstone Charm", totalSupply = 9000, imageId = "rbxassetid://17368097932" }, -- star
		{ name = "Frost Lantern", totalSupply = 5600, imageId = "rbxassetid://15403275152" }, -- blue potion
		-- Legendary (1200-4999)
		{ name = "Crimson Crown", totalSupply = 3000, imageId = "rbxassetid://16912465495" }, -- crown
		{ name = "Storm Sigil", totalSupply = 1500, imageId = "rbxassetid://15403144723" }, -- fire
		-- Mythical (300-1199)
		{ name = "Obsidian Fang", totalSupply = 900, imageId = "rbxassetid://17368155868" }, -- key
		{ name = "Void Shard", totalSupply = 420, imageId = "rbxassetid://15402964203" }, -- beta gem
		-- Godly (80-299)
		{ name = "Astral Prism", totalSupply = 200, imageId = "rbxassetid://15402896733" }, -- gem chest
		{ name = "Solar Halo", totalSupply = 90, imageId = "rbxassetid://15403047368" }, -- triple stars
		-- Celestial (<80, the rarest of all)
		{ name = "Eclipse Core", totalSupply = 48, imageId = "rbxassetid://15402892798" }, -- gem bag
	},

	-- Icon candidates for procedurally generated pools (rotation). Drawn
	-- without replacement per pool; recycled across pools when exhausted.
	IconPool = {
		"rbxassetid://15403265114", -- red potion
		"rbxassetid://15403275152", -- blue potion
		"rbxassetid://17368152653", -- yellow potion
		"rbxassetid://15403263527", -- purple potion
		"rbxassetid://15402844695", -- coin stack
		"rbxassetid://15402852027", -- coin bag
		"rbxassetid://15402855334", -- coin chest
		"rbxassetid://140358917263311", -- red coin
		"rbxassetid://83939430689931", -- green coin
		"rbxassetid://120383690499369", -- blue coin
		"rbxassetid://100449548915705", -- purple coin
		"rbxassetid://15402885986", -- gem pile
		"rbxassetid://15402892798", -- gem bag
		"rbxassetid://15402896733", -- gem chest
		"rbxassetid://17368125421", -- ticket
		"rbxassetid://17368155868", -- key
		"rbxassetid://15403027709", -- bomb
		"rbxassetid://15403144723", -- fire
		"rbxassetid://84364030718064", -- cookie
		"rbxassetid://17368097932", -- star
		"rbxassetid://15403047368", -- triple stars
		"rbxassetid://15402967660", -- gift
		"rbxassetid://15402969720", -- multi gifts
		"rbxassetid://17368122337", -- box
		"rbxassetid://17368197534", -- wheel
	},

	-- Procedural generation template for rotated pools (pool #2+). One entry
	-- per slot; supply rolled uniformly in [min, max]. Template guarantees the
	-- full six-tier rarity spread structurally (>=1 of every tier).
	PoolTemplate = {
		{ min = 24000, max = 60000 }, -- Common
		{ min = 22000, max = 50000 }, -- Common
		{ min = 20000, max = 40000 }, -- Common
		{ min = 12000, max = 19000 }, -- Rare
		{ min = 8000, max = 15000 }, -- Rare
		{ min = 5000, max = 9000 }, -- Rare
		{ min = 2500, max = 4800 }, -- Legendary
		{ min = 1400, max = 2800 }, -- Legendary
		{ min = 1200, max = 2000 }, -- Legendary
		{ min = 600, max = 1100 }, -- Mythical
		{ min = 320, max = 700 }, -- Mythical
		{ min = 150, max = 290 }, -- Godly
		{ min = 85, max = 180 }, -- Godly
		{ min = 45, max = 78 }, -- Celestial
	},

	-- Name generation for rotated pools.
	NameAdjectives = {
		"Ancient", "Frozen", "Gilded", "Shadow", "Solar", "Storm", "Ember",
		"Ivory", "Obsidian", "Coral", "Astral", "Rusted", "Verdant", "Silent",
		"Molten", "Twilight", "Radiant", "Hollow", "Feral", "Arcane",
		"Cursed", "Sacred", "Frostbit", "Sunlit", "Umbral", "Prismatic",
	},
	NameNouns = {
		"Totem", "Mask", "Blade", "Orb", "Crown", "Idol", "Talisman",
		"Lantern", "Chalice", "Sigil", "Fang", "Mirror", "Drum", "Compass",
		"Feather", "Prism", "Horn", "Locket", "Scepter", "Shard",
		"Relic", "Effigy", "Gauntlet", "Rune", "Censer", "Diadem",
	},
}

return Items
