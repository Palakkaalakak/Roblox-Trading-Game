--!strict
-- EventConfig: the economy's VALUE ENGINE — crafting, sacrifices, rotating recipes.
--
-- WHY EVENTS EXIST (read this before tuning anything):
-- Item-for-item trading is zero-sum: it moves worth around, it never creates
-- any. Crafting is the only thing that MAKES value, and it does it twice over:
--   1. THE PREMIUM. A recipe burns its inputs and mints an output seeded at
--      (input value) * EconomyConfig.CraftValuePremium. Every craft mints more
--      worth than it destroys. Crafting costs ITEMS ONLY — no gem fee.
--   2. THE SINK (the big one). Burned copies leave existence forever. The
--      ROTATING refinery deliberately points that sink at a couple of specific
--      commons per window, so crafters all bid for the SAME items at once —
--      those spike, then the window rotates and the next ones spike. Supply
--      only ever ratchets down, so values trend up for EVERYONE holding them,
--      not just whoever crafted. That is how the whole economy grows instead
--      of a few traders getting rich off everyone else.
--
-- THE LADDER (each rung is +10% and a demand sink for the rung below):
--   commons --3x--> Refined Essence --3x + a rare--> Artifact --2x--> Grail
-- Input counts are deliberately small. Every count here must stay <=
-- BotConfig.MaxHoldPerItem AND be reachable given BotConfig.StarterDraws — a
-- recipe wanting more of one item than the population can concentrate into one
-- pair of hands simply never fires, and the whole value engine stalls.
-- Every rung is SUPPLY-CAPPED, including the material. That is not a nicety:
-- net worth is sum(count * value), and value is whatever the market pays, so
-- minting an unlimited material just prices it to nothing and DESTROYS worth
-- faster than the premium creates it (measured: 137 Essence flooded out and its
-- value fell 50 -> 39). Scarcity is what makes a craft's premium stick.
--
-- Each event may carry `npc = { position = {x, y, z} }`: the server spawns an
-- event NPC there at boot; triggering its prompt opens the Events panel.
-- Output items are ordinary tradeable items with Store Cost "N/A (Event Item)".
--
-- DEV WORKFLOW — adding an event:
--   1. Add an entry to Events (or a recipe to RotatingRecipes.Pool).
--      Output `sku` must be NEW and unique (itemId becomes "evt_<sku>") —
--      never reuse one; old outputs live on in inventories. Several recipes MAY
--      share one output sku (the refinery does this on purpose: many roads to
--      the same material, one shared supply pool).
--      Input ids must be REAL itemIds (check Items.luau / the registry).
--   2. Reboot. Done. Set `enabled = false` (or add `endsAt`) to close it.
--
-- Timing: `startsAt`/`endsAt` are optional unix times; omitted = always on
-- (while `enabled`). RotatingRecipes picks ActiveCount recipes from Pool per
-- time window, deterministically — all servers agree with no coordination.

local EventConfig: any = {
	Events = {
		--------------------------------------------------------------------
		-- TIER 3 — the capstone. Burns Artifacts into a true grail.
		--------------------------------------------------------------------
		{
			id = "evt_grand_forge",
			name = "The Grand Forge",
			kind = "crafting",
			enabled = true,
			recipes = {
				{
					rid = "ancient_grail",
					tier = 3,
					blurb = "Two artifacts and a crown, forged into something the server remembers.",
					inputs = {
						["evt_storm_artifact"] = 2,
						["itm_1_8_crimson_crown"] = 1,
					},
					output = {
						sku = "ancient_grail",
						name = "Ancient Grail",
						totalSupply = 80,
						imageId = "rbxassetid://15402896733", -- gem chest
					},
				},
				{
					rid = "eternal_diadem",
					tier = 3,
					blurb = "The rarest thing anyone can make. The Void does not give it up cheaply.",
					inputs = {
						["evt_ember_artifact"] = 2,
						["itm_1_11_void_shard"] = 1,
					},
					output = {
						sku = "eternal_diadem",
						name = "Eternal Diadem",
						totalSupply = 40,
						imageId = "rbxassetid://16912465495", -- crown
					},
				},
			},
		},

		--------------------------------------------------------------------
		-- SACRIFICE — one item type, a LOT of it. The heaviest single sink in
		-- the game: it eats the most copies per output.
		--------------------------------------------------------------------
		{
			id = "evt_shadow_ritual",
			name = "Shadow Ritual",
			kind = "sacrifice",
			enabled = true,
			recipes = {
				{
					rid = "shadow_crown",
					tier = 2,
					blurb = "Feed the dark six coins. Ask no questions.",
					-- NOTE: keep every input count <= BotConfig.MaxHoldPerItem (8),
					-- or no bot can ever physically stockpile enough to craft it.
					inputs = { ["itm_1_2_copper_coin"] = 6 },
					output = {
						sku = "shadow_crown",
						name = "Shadow Crown",
						totalSupply = 220,
						imageId = "rbxassetid://100449548915705", -- purple coin
					},
				},
				{
					rid = "hollow_effigy",
					tier = 2,
					blurb = "Six relics of stone for one hollow thing.",
					inputs = { ["itm_1_1_stone_relic"] = 6 },
					output = {
						sku = "hollow_effigy",
						name = "Hollow Effigy",
						totalSupply = 180,
						imageId = "rbxassetid://15403027709", -- bomb
					},
				},
			},
		},

		--------------------------------------------------------------------
		-- SEASONAL — limited-time events with an endsAt. They show up on the
		-- Events panel's "Limited" tab with a live countdown, then vanish.
		-- Inputs are always base-pool items (never event items), so a
		-- seasonal recipe can NEVER be gated behind a rotation window.
		--------------------------------------------------------------------
		{
			id = "evt_midsummer",
			name = "🌞 Midsummer Festival",
			kind = "crafting",
			enabled = true,
			endsAt = 1785542400, -- Aug 1 2026 00:00 UTC
			recipes = {
				{
					rid = "solstice_talisman",
					tier = 2,
					blurb = "Only while the sun is high. Gone in August.",
					inputs = { ["itm_1_6_sunstone_charm"] = 2, ["itm_1_3_amber_idol"] = 1 },
					output = {
						sku = "solstice_talisman",
						name = "Solstice Talisman",
						totalSupply = 150,
						imageId = "rbxassetid://17368097932", -- star
					},
				},
				{
					rid = "midsummer_wreath",
					tier = 1,
					blurb = "Woven once a year. Cheap to make, gone forever after.",
					inputs = { ["itm_1_4_clay_totem"] = 2, ["itm_1_5_jade_serpent"] = 1 },
					output = {
						sku = "midsummer_wreath",
						name = "Midsummer Wreath",
						totalSupply = 260,
						imageId = "rbxassetid://15403275152", -- blue potion
					},
				},
			},
		},

		--------------------------------------------------------------------
		-- ALCHEMIST — always-on entry point. Cheap, common inputs, so there
		-- is always SOMETHING to make even on a bad rotation.
		--------------------------------------------------------------------
		{
			id = "evt_alchemist",
			name = "Alchemist's Lab",
			kind = "crafting",
			enabled = true,
			recipes = {
				{
					rid = "transmutation_stone",
					tier = 2,
					blurb = "The first thing every trader learns to make.",
					inputs = { ["itm_1_1_stone_relic"] = 2, ["itm_1_3_amber_idol"] = 1 },
					output = {
						sku = "transmutation_stone",
						name = "Transmutation Stone",
						totalSupply = 400,
						imageId = "rbxassetid://15402885986", -- gem pile
					},
				},
				{
					rid = "rune_protection",
					tier = 2,
					blurb = "Serpent and sun, bound into a ward.",
					inputs = { ["itm_1_5_jade_serpent"] = 1, ["itm_1_6_sunstone_charm"] = 1 },
					output = {
						sku = "rune_protection",
						name = "Rune of Protection",
						totalSupply = 300,
						imageId = "rbxassetid://15403275152", -- blue potion
					},
				},
			},
		},
	},

	-- ROTATING RECIPES — the live half of the economy.
	-- ActiveCount recipes are craftable per window; the set changes every
	-- RotationIntervalSeconds, deterministically, on every server at once.
	-- The pool deliberately mixes:
	--   * TIER 1 refinery (commons -> Refined Essence). Rotating WHICH common
	--     is wanted is the whole point — it concentrates every crafter's demand
	--     onto a couple of items at a time, spikes them, then moves on.
	--   * TIER 2 artisan (essence + a rare -> an Artifact).
	RotatingRecipes = {
		enabled = true,
		RotationIntervalSeconds = 600, -- 10-minute windows
		ActiveCount = 4,
		Pool = {
			-- TIER 1: the refinery. Many roads, ONE shared material pool.
			{
				rid = "refine_stone",
				tier = 1,
				blurb = "Stone Relics are wanted this window. Grind them down.",
				inputs = { ["itm_1_1_stone_relic"] = 3 },
				output = {
					sku = "refined_essence",
					name = "Refined Essence",
					totalSupply = 2500, -- scarce ON PURPOSE: flood it and it's worthless
					imageId = "rbxassetid://15403265114", -- red potion
				},
			},
			{
				rid = "refine_copper",
				tier = 1,
				blurb = "Copper is in demand. Melt it down.",
				inputs = { ["itm_1_2_copper_coin"] = 3 },
				output = {
					sku = "refined_essence",
					name = "Refined Essence",
					totalSupply = 2500,
					imageId = "rbxassetid://15403265114",
				},
			},
			{
				rid = "refine_amber",
				tier = 1,
				blurb = "Amber Idols burn hot this window.",
				inputs = { ["itm_1_3_amber_idol"] = 3 },
				output = {
					sku = "refined_essence",
					name = "Refined Essence",
					totalSupply = 2500,
					imageId = "rbxassetid://15403265114",
				},
			},
			{
				rid = "refine_clay",
				tier = 1,
				blurb = "Clay Totems are the ask right now.",
				inputs = { ["itm_1_4_clay_totem"] = 3 },
				output = {
					sku = "refined_essence",
					name = "Refined Essence",
					totalSupply = 2500,
					imageId = "rbxassetid://15403265114",
				},
			},

			-- TIER 2: the artisan bench. Essence + a rare -> an Artifact.
			{
				rid = "artifact_storm",
				tier = 2,
				blurb = "Bind essence to a serpent and it holds a storm.",
				inputs = { ["evt_refined_essence"] = 3, ["itm_1_5_jade_serpent"] = 1 },
				output = {
					sku = "storm_artifact",
					name = "Storm Artifact",
					totalSupply = 900,
					imageId = "rbxassetid://15403144723", -- fire
				},
			},
			{
				rid = "artifact_ember",
				tier = 2,
				blurb = "Sunstone and essence. Warm to the touch, forever.",
				inputs = { ["evt_refined_essence"] = 3, ["itm_1_6_sunstone_charm"] = 1 },
				output = {
					sku = "ember_artifact",
					name = "Ember Artifact",
					totalSupply = 900,
					imageId = "rbxassetid://17368097932", -- star
				},
			},
			{
				rid = "artifact_frost",
				tier = 2,
				blurb = "A lantern that never thaws.",
				inputs = { ["evt_refined_essence"] = 3, ["itm_1_7_frost_lantern"] = 1 },
				output = {
					sku = "frost_artifact",
					name = "Frost Artifact",
					totalSupply = 900,
					imageId = "rbxassetid://15402892798", -- gem bag
				},
			},
			{
				rid = "artifact_gilded",
				tier = 2,
				blurb = "Essence poured over a fang. Obscene, and worth it.",
				inputs = { ["evt_refined_essence"] = 4, ["itm_1_10_obsidian_fang"] = 1 },
				output = {
					sku = "gilded_artifact",
					name = "Gilded Artifact",
					totalSupply = 500,
					imageId = "rbxassetid://15402855334", -- coin chest
				},
			},
		},
	},
}

--------------------------------------------------------------------------------
-- Producer lookup (shared helpers — client and server answer the same way)
--------------------------------------------------------------------------------

-- itemId -> { name, category } for every craftable output.
-- category: "permanent" (always-on station) | "rotating" (pool; the recipe
-- reappears in future windows) | "limited" (has a start/end; once it's over,
-- the item can never be made again).
local producerIndex: { [string]: { name: string, category: string } }? = nil
local function producers(): { [string]: { name: string, category: string } }
	if producerIndex then
		return producerIndex
	end
	local index: { [string]: { name: string, category: string } } = {}
	for _, event in EventConfig.Events do
		if event.enabled then
			local category = (event.endsAt or event.startsAt) and "limited" or "permanent"
			for _, recipe in event.recipes do
				index["evt_" .. recipe.output.sku] = { name = event.name, category = category }
			end
		end
	end
	local rot = EventConfig.RotatingRecipes
	if rot and rot.enabled then
		for _, recipe in rot.Pool do
			index["evt_" .. recipe.output.sku] = { name = "Rotating Recipes", category = "rotating" }
		end
	end
	producerIndex = index
	return index
end

-- Who makes this event item? nil for base-pool items and unknown ids.
function EventConfig.producerOf(itemId: string): { name: string, category: string }?
	return producers()[itemId]
end

-- Can more copies of this item still enter the world? Base items: always
-- (rolls, store, starter draws). Event items: only while a recipe can still
-- mint them — permanent stations and the rotating pool qualify, LIMITED
-- events do not (once the season ends, copies pushed back into the reserve
-- would be stuck there forever). Drives what the Rolls NPC accepts as
-- payment: traded-in items are REDISTRIBUTED into the reserve, not destroyed,
-- so anything paid in must be able to come back out.
function EventConfig.isReobtainable(itemId: string): boolean
	if itemId:sub(1, 4) ~= "evt_" then
		return true
	end
	local producer = producers()[itemId]
	return producer ~= nil and producer.category ~= "limited"
end

return EventConfig
