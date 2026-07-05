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
	-- How many weighted draws each first-join starter bundle contains.
	-- Duplicates allowed (stack counts). K=4 chosen so portfolios are
	-- heterogeneous enough for starter-vs-starter trading.
	StarterBundleSize = 4,

	-- Gems granted alongside the starter bundle. 0 for now — the gem faucet
	-- arrives with the shop phase; use the debug button meanwhile.
	StarterGems = 0,

	-- totalSupply >= threshold -> that tier (checked top-down). Below all -> Mythical.
	RarityThresholds = {
		{ tier = "Common", min = 750 },
		{ tier = "Rare", min = 300 },
		{ tier = "Legendary", min = 100 },
		-- < 100 -> Mythical
	},

	-- assignmentWeight default = round(totalSupply ^ exponent * scale).
	AssignmentWeightExponent = 0.75,
	AssignmentWeightScale = 1,

	-- Placeholder initial pool (pool #1). Spread satisfies the pool-generation
	-- invariant: >=2 Common, >=1 Rare, >=1 Legendary-or-Mythical.
	-- imageId: decal ids from the Simulator Icon Pack (Workspace).
	InitialPool = {
		{ name = "Stone Relic", totalSupply = 1000, imageId = "rbxassetid://17368402884" }, -- crate
		{ name = "Amber Idol", totalSupply = 800, imageId = "rbxassetid://12129301834" }, -- trophy
		{ name = "Jade Serpent", totalSupply = 450, imageId = "rbxassetid://15403270948" }, -- green potion
		{ name = "Crimson Crown", totalSupply = 150, imageId = "rbxassetid://16912465495" }, -- crown
		{ name = "Void Shard", totalSupply = 60, imageId = "rbxassetid://15402964203" }, -- beta gem
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

	-- Procedural generation template for rotated pools (pool #2+).
	-- One entry per slot; supply rolled uniformly in [min, max].
	-- Template guarantees the rarity spread structurally.
	PoolTemplate = {
		{ min = 750, max = 1200 }, -- Common
		{ min = 750, max = 1200 }, -- Common
		{ min = 300, max = 600 }, -- Rare
		{ min = 100, max = 250 }, -- Legendary
		{ min = 40, max = 90 }, -- Mythical
	},

	-- Name generation for rotated pools.
	NameAdjectives = {
		"Ancient", "Frozen", "Gilded", "Shadow", "Solar", "Storm", "Ember",
		"Ivory", "Obsidian", "Coral", "Astral", "Rusted", "Verdant", "Silent",
		"Molten", "Twilight", "Radiant", "Hollow", "Feral", "Arcane",
	},
	NameNouns = {
		"Totem", "Mask", "Blade", "Orb", "Crown", "Idol", "Talisman",
		"Lantern", "Chalice", "Sigil", "Fang", "Mirror", "Drum", "Compass",
		"Feather", "Prism", "Horn", "Locket", "Scepter", "Shard",
	},
}

return Items
