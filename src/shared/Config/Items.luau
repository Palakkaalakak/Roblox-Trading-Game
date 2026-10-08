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

	-- The first-join reveal shows one of two asymmetric shapes, chosen once per
	-- account and never told apart to the player as anything but "lucky" (see
	-- the starter-roll takeover UI). This is what seeds day-one trading: a
	-- minority hold a few valuable things, the majority hold a lot of cheap
	-- things, so both sides of a trade exist from the first session.
	--   super  -- few items, drawn only from the upper rarity window
	--   multi  -- many items, drawn from the normal full pool (commons likely)
	StarterVariants = {
		SuperChance = 0.25, -- fraction of new accounts that land on "super"
		Super = { count = 3, minRarity = "Legendary" }, -- Legendary/Mythical/Godly/Celestial
		Multi = { count = 6 }, -- keep <= GuiBuilder's STARTER_MAX_ITEMS (one reel band each)
		-- Hook psychology: every new account must land on the reveal screen
		-- worth AT LEAST this many gems (5000 gems = 50 Robux at
		-- RewardsConfig.BaseGemsPerRobux=100). StarterService tops this up
		-- after the normal weighted draw by adding extra copies of whatever
		-- was ALREADY granted (never new distinct items), so the reveal grid
		-- doesn't balloon and the number always matches real inventory.
		MinTotalValue = 5000,
	},

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

	-- ROLL POOL ROTATION. A pool used to retire only once EVERY item in it hit
	-- zero reserve. That is far too late: the advertised odds break the moment
	-- the FIRST item runs out.
	--
	-- Why the first one and not the last: a roll picks a rarity by the tier's
	-- authored odds, then picks an item inside that rarity by assignment weight.
	-- While every item still has at least one copy, that distribution is exactly
	-- what the odds card claims — and it stays exact no matter how lopsided the
	-- remaining COUNTS get, because counts are not weights. One item down to a
	-- single copy changes nothing. But an item at ZERO drops out of its rarity's
	-- weight split entirely, and its share is silently absorbed by whatever else
	-- is in that rarity. That is a probability change nobody agreed to, and it is
	-- farmable: drain the item you don't want and the rest get likelier.
	--
	-- So the rule is simply: a pool is replaced as soon as any of its items is
	-- exhausted. Counts do not move probability; an empty slot does.
	RollPoolRotation = {
		-- How often a server re-checks the active pool for an exhausted item.
		-- The roll and starter-draw paths also poke it on the spot, so this is
		-- only the backstop for copies leaving by some other route.
		CheckIntervalSeconds = 45,

		-- A retired pool is not dead. Consumed copies are redistributed, not
		-- destroyed — crafting inputs and roll item-payments hand them back to
		-- the item they came from, which is the pool they came from. So a pool
		-- that was retired for running an item dry slowly refills, and once it
		-- has recovered this fraction of the total supply it was minted with it
		-- becomes eligible to be the active pool again.
		--
		-- Eligibility ALSO requires every one of its items to hold at least one
		-- copy: reviving a pool with a hole in it would break the advertised
		-- odds on the very first roll, which is the thing rotation exists to
		-- prevent. Recovery is the gate; completeness is the invariant.
		RevivalStockFraction = 0.2,
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
