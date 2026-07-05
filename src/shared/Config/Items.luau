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
	InitialPool = {
		{ name = "Stone Relic", totalSupply = 1000 },
		{ name = "Amber Idol", totalSupply = 800 },
		{ name = "Jade Serpent", totalSupply = 450 },
		{ name = "Crimson Crown", totalSupply = 150 },
		{ name = "Void Shard", totalSupply = 60 },
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
