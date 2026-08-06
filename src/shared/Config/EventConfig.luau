--!strict
-- EventConfig: the economy's VALUE ENGINE — crafting, sacrifices, rotating recipes.
--
-- WHY EVENTS EXIST (read this before tuning anything):
-- Item-for-item trading is zero-sum: it moves worth around, it never creates
-- any. Crafting is the only thing that MAKES value: a recipe consumes its
-- inputs and mints an output seeded at (input value) * EconomyConfig.
-- CraftValuePremium — every craft mints more worth than it consumes. Crafting
-- costs ITEMS ONLY — no gem fee (gems only ever enter the game via ads/Robux,
-- so they're never a raw material).
--
-- Consumed inputs are REDISTRIBUTED back into the shared reserve, not
-- destroyed (same mechanism rolls already use for item-payments) — so a
-- common eaten by the hundreds up at the top of the ladder recycles straight
-- back to new players' free starter grants instead of the world ever running
-- dry. An item's price never reacts to this cycling either way (see
-- EconomyService.computeValue): only its fixed totalSupply cap and live
-- demand set what it's worth, so no single item can be inflated or deflated
-- by crafting activity. The economy still grows overall, just by COUNT — new
-- items and new recipes, each with their own cap, entering over time (via
-- events, rolls, the gem-store NPC, or the starter pool).
--
-- THE LADDER (each rung is +10% value and a source of REAL demand for the
-- rung below): commons --> Refined Essence --> Artifact --> Grail.
-- This is where "pro" players buy in bulk from everyone else: a capstone
-- recipe's input counts are meant to be steep — often more than one player
-- could ever farm alone — so satisfying it means buying hundreds of a common
-- off the market, not grinding it out solo. That demand is what makes a
-- beginner's cheapest items worth anything at all: nothing else does.
-- Every rung is still SUPPLY-CAPPED (totalSupply), including the material —
-- net worth is sum(count * value), and an uncapped material prices itself to
-- nothing and destroys worth faster than any premium creates it.
--
-- One exception on purpose: the Alchemist's Lab stays CHEAP and always-on.
-- Every new player needs at least one thing they can always make, win or
-- lose on rotation — that's the on-ramp, not a whale target.
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
					blurb = "Five storm artifacts and a crown, forged into something the server remembers.",
					inputs = {
						["evt_storm_artifact"] = 5,
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
						["evt_ember_artifact"] = 5,
						["itm_1_11_void_shard"] = 1,
					},
					output = {
						sku = "eternal_diadem",
						name = "Eternal Diadem",
						totalSupply = 40,
						imageId = "rbxassetid://16912465495", -- crown
					},
				},
				-- BRANCHING capstone. Both halves are themselves crafted from
				-- crafted parts, so this one's tree is a real pyramid rather than
				-- a single chain: two independent branches of equal depth meeting
				-- at the top. Deliberately the widest recipe in the game.
				{
					rid = "worldheart",
					tier = 3,
					blurb = "Two halves, each built from scratch. Almost nobody finishes one alone.",
					inputs = {
						["evt_sunforged_core"] = 1,
						["evt_voidforged_core"] = 1,
					},
					output = {
						sku = "worldheart",
						name = "Worldheart",
						totalSupply = 25,
						imageId = "rbxassetid://17368097932", -- star
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
					blurb = "Feed the dark thirty coins. Ask no questions.",
					inputs = { ["itm_1_2_copper_coin"] = 30 },
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
					blurb = "Thirty relics of stone for one hollow thing.",
					inputs = { ["itm_1_1_stone_relic"] = 30 },
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
		-- THE REFINERY — commons into Refined Essence. PERMANENT on purpose:
		-- Essence feeds most of the ladder, and anything that feeds another
		-- recipe must be craftable at ANY moment (see the rotation rule at the
		-- top of this file). Several roads, one shared material pool.
		--------------------------------------------------------------------
		{
			id = "evt_refinery",
			name = "The Refinery",
			kind = "crafting",
			enabled = true,
			recipes = {
				{
					rid = "refine_stone",
					tier = 1,
					blurb = "Stone Relics, ground down to something purer.",
					inputs = { ["itm_1_1_stone_relic"] = 15 },
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
					blurb = "Copper, melted down.",
					inputs = { ["itm_1_2_copper_coin"] = 15 },
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
					blurb = "Amber Idols burn hot and clean.",
					inputs = { ["itm_1_3_amber_idol"] = 15 },
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
					blurb = "Clay Totems, fired down to essence.",
					inputs = { ["itm_1_4_clay_totem"] = 15 },
					output = {
						sku = "refined_essence",
						name = "Refined Essence",
						totalSupply = 2500,
						imageId = "rbxassetid://15403265114",
					},
				},
			},
		},

		--------------------------------------------------------------------
		-- ARTISAN BENCH — every MIDDLE rung of the ladder: artifacts, the
		-- Worldheart fragments, and the two cores. All permanent, for the same
		-- reason as the Refinery: each one feeds something above it, so none of
		-- them may ever be rotation-gated.
		--------------------------------------------------------------------
		{
			id = "evt_artisan",
			name = "Artisan Bench",
			kind = "crafting",
			enabled = true,
			recipes = {
				{
					rid = "artifact_storm",
					tier = 2,
					blurb = "Bind essence to a serpent and it holds a storm.",
					inputs = { ["evt_refined_essence"] = 10, ["itm_1_5_jade_serpent"] = 1 },
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
					inputs = { ["evt_refined_essence"] = 10, ["itm_1_6_sunstone_charm"] = 1 },
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
					inputs = { ["evt_refined_essence"] = 10, ["itm_1_7_frost_lantern"] = 1 },
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
					inputs = { ["evt_refined_essence"] = 14, ["itm_1_10_obsidian_fang"] = 1 },
					output = {
						sku = "gilded_artifact",
						name = "Gilded Artifact",
						totalSupply = 500,
						imageId = "rbxassetid://15402855334", -- coin chest
					},
				},
				{
					rid = "sun_fragment",
					tier = 1,
					blurb = "Sunstone ground fine and bound with essence.",
					inputs = { ["evt_refined_essence"] = 4, ["itm_1_6_sunstone_charm"] = 2 },
					output = {
						sku = "sun_fragment",
						name = "Sun Fragment",
						totalSupply = 700,
						imageId = "rbxassetid://17368097932", -- star
					},
				},
				{
					rid = "void_fragment",
					tier = 1,
					blurb = "A shard of nothing, held together by essence.",
					inputs = { ["evt_refined_essence"] = 4, ["itm_1_11_void_shard"] = 1 },
					output = {
						sku = "void_fragment",
						name = "Void Fragment",
						totalSupply = 700,
						imageId = "rbxassetid://15403027709", -- bomb
					},
				},
				{
					rid = "sunforged_core",
					tier = 2,
					blurb = "An ember artifact and three sun fragments, forged as one.",
					inputs = { ["evt_ember_artifact"] = 1, ["evt_sun_fragment"] = 3 },
					output = {
						sku = "sunforged_core",
						name = "Sunforged Core",
						totalSupply = 300,
						imageId = "rbxassetid://15403144723", -- fire
					},
				},
				{
					rid = "voidforged_core",
					tier = 2,
					blurb = "A storm artifact and three void fragments, forged as one.",
					inputs = { ["evt_storm_artifact"] = 1, ["evt_void_fragment"] = 3 },
					output = {
						sku = "voidforged_core",
						name = "Voidforged Core",
						totalSupply = 300,
						imageId = "rbxassetid://15402964203", -- void shard
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
	--
	-- HARD RULE (enforced by CraftingService.validateRecipeGraph): a rotating
	-- recipe may only ever produce a TERMINAL item — something no other recipe
	-- consumes. If a rotating output fed another recipe, that recipe would be
	-- uncraftable for everyone whenever its input wasn't one of this window's
	-- picks, which is exactly the dead end players used to hit. Every middle
	-- rung therefore lives on a permanent station (Refinery / Artisan Bench).
	--
	-- Rotating is where VARIETY and urgency live: these consume the ladder's
	-- output and mint standalone trophies that nothing else eats, so a window
	-- closing can never strand a chain.
	RotatingRecipes = {
		enabled = true,
		RotationIntervalSeconds = 600, -- 10-minute windows
		ActiveCount = 4,
		Pool = {
			-- TERMINAL TROPHIES ONLY. Each of these consumes the ladder's output
			-- and produces something no other recipe eats, so a window closing
			-- can never make another recipe uncraftable.
			{
				rid = "storm_totem",
				tier = 3,
				blurb = "A storm, pinned to a totem. Wanted this window only.",
				inputs = { ["evt_storm_artifact"] = 2, ["itm_1_4_clay_totem"] = 6 },
				output = {
					sku = "storm_totem",
					name = "Storm Totem",
					totalSupply = 260,
					imageId = "rbxassetid://15403144723", -- fire
				},
			},
			{
				rid = "ember_idol",
				tier = 3,
				blurb = "Amber wrapped around a captured ember.",
				inputs = { ["evt_ember_artifact"] = 2, ["itm_1_3_amber_idol"] = 6 },
				output = {
					sku = "ember_idol",
					name = "Ember Idol",
					totalSupply = 260,
					imageId = "rbxassetid://17368097932", -- star
				},
			},
			{
				rid = "frost_crown",
				tier = 3,
				blurb = "It never melts, and it never warms.",
				inputs = { ["evt_frost_artifact"] = 2, ["itm_1_7_frost_lantern"] = 3 },
				output = {
					sku = "frost_crown",
					name = "Frost Crown",
					totalSupply = 200,
					imageId = "rbxassetid://16912465495", -- crown
				},
			},
			{
				rid = "gilded_mask",
				tier = 3,
				blurb = "Gold over bone. Worn once, remembered forever.",
				inputs = { ["evt_gilded_artifact"] = 2, ["itm_1_10_obsidian_fang"] = 3 },
				output = {
					sku = "gilded_mask",
					name = "Gilded Mask",
					totalSupply = 160,
					imageId = "rbxassetid://15402855334", -- coin chest
				},
			},
			{
				rid = "essence_lantern",
				tier = 2,
				blurb = "Cheap to make while it's up. Gone when the window turns.",
				inputs = { ["evt_refined_essence"] = 6, ["itm_1_2_copper_coin"] = 8 },
				output = {
					sku = "essence_lantern",
					name = "Essence Lantern",
					totalSupply = 420,
					imageId = "rbxassetid://15402892798", -- gem bag
				},
			},
			{
				rid = "relic_cairn",
				tier = 1,
				blurb = "A pile of relics, stacked with intent.",
				inputs = { ["itm_1_1_stone_relic"] = 10, ["itm_1_5_jade_serpent"] = 2 },
				output = {
					sku = "relic_cairn",
					name = "Relic Cairn",
					totalSupply = 500,
					imageId = "rbxassetid://15403027709", -- bomb
				},
			},
		},
	},

	--------------------------------------------------------------------------
	-- SOLD-OUT REPLACEMENT
	--
	-- A permanent station's recipe mints a capped number of copies and then it
	-- is finished forever. Without this, every station slowly turns into a wall
	-- of greyed-out "SOLD OUT" rows and the ladder stops accepting the commons
	-- it exists to consume.
	--
	-- So: once a permanent recipe is sold out, the next replacement window
	-- swaps it for a SPARE — a fresh recipe with its own new output and its own
	-- new cap. Rotating recipes are exempt; they already rotate away on their
	-- own and come back, so replacing them would just churn.
	--
	-- The swap is derived from the clock (which window we're in) and the recipe
	-- id, never from stored state, so every server picks the same replacement
	-- with no coordination and no migration. Spares are pre-authored below;
	-- when the list runs out, CraftingService generates a variant from the
	-- sold-out recipe instead, so a station can never run out of replacements.
	Replacement = {
		enabled = true,
		IntervalSeconds = 1200, -- 20 minutes; a sold-out recipe is swapped at the next boundary
		SparePool = {
			{
				rid = "spare_river_charm",
				tier = 1,
				blurb = "Cut from riverstone while the old mould cooled.",
				inputs = { ["itm_1_1_stone_relic"] = 12, ["itm_1_2_copper_coin"] = 6 },
				output = {
					sku = "river_charm",
					name = "River Charm",
					totalSupply = 460,
					imageId = "rbxassetid://15402892798", -- gem bag
				},
			},
			{
				rid = "spare_ashen_sigil",
				tier = 2,
				blurb = "Struck from the ashes of a finished run.",
				inputs = { ["evt_refined_essence"] = 8, ["itm_1_3_amber_idol"] = 4 },
				output = {
					sku = "ashen_sigil",
					name = "Ashen Sigil",
					totalSupply = 300,
					imageId = "rbxassetid://15403144723", -- fire
				},
			},
			{
				rid = "spare_tidebound_relic",
				tier = 2,
				blurb = "The sea gave this one back.",
				inputs = { ["evt_refined_essence"] = 10, ["itm_1_5_jade_serpent"] = 3 },
				output = {
					sku = "tidebound_relic",
					name = "Tidebound Relic",
					totalSupply = 240,
					imageId = "rbxassetid://15403275152", -- blue potion
				},
			},
			{
				rid = "spare_sunless_crown",
				tier = 3,
				blurb = "Forged to replace a crown nobody can make anymore.",
				inputs = { ["evt_frost_artifact"] = 3, ["itm_1_7_frost_lantern"] = 4 },
				output = {
					sku = "sunless_crown",
					name = "Sunless Crown",
					totalSupply = 140,
					imageId = "rbxassetid://16912465495", -- crown
				},
			},
		},
	},

	--------------------------------------------------------------------------
	-- UNIQUE CRAFT
	--
	-- One player at a time gets temporary access to craft an item that ALREADY
	-- EXISTS in the game but is not currently the output of any live recipe.
	--
	-- WHY IT EXISTS. Every player wanting the same things makes them each
	-- other's competitors rather than each other's counterparties, and a market
	-- of competitors barely trades. A unique craft puts ONE player in the market
	-- with a specific shopping list that nobody is bidding against, which means
	-- (a) they can actually fill it, and (b) whoever is holding those inputs
	-- finally has a buyer. That second half is what lets a brand-new player sell
	-- anything at all without knowing how to trade.
	--
	-- It also teaches the four ways to get an item without a word of tutorial:
	-- to fill the list you can roll, buy from the gem store, buy on the board,
	-- or trade someone directly.
	UniqueCraft = {
		enabled = true,
		DurationSeconds = 3 * 3600, -- how long the offer stays craftable
		CooldownSeconds = 30 * 60, -- gap after one ends before the next is offered

		-- Candidate OUTPUTS are ANY item that is (a) still re-obtainable, so
		-- ended seasonal exclusives stay ended, and (b) not produced by any
		-- live recipe right now. Rarity is deliberately NOT a filter — a rare
		-- output is a real moment, and the item's own reserve already caps how
		-- many can exist. Add rarities here only if the top end proves swingy.
		ExcludeRarities = {},

		-- How many DISTINCT input items the list asks for, and how many of
		-- each. Kept deliberately SMALL: a Unique Craft has to be reachable
		-- by a brand-new player, so the shape is "three different commons
		-- for a rare", not a bulk order. The output is then chosen to suit
		-- the inputs (see InputValueFraction) rather than the other way
		-- round -- sizing counts from the output's value is what produced
		-- 25x Stone Relic for a Godly.
		--
		-- FUTURE: scale these with the player's level / wealth so veterans
		-- get proportionally bigger lists. buildOffer already takes the
		-- player's inventory, so it is the natural place to hang that.
		InputKinds = { min = 2, max = 3 },
		CountPerInput = { min = 1, max = 3 },

		-- The list is sized so its total input value lands in this band relative
		-- to the output's value. Below 1.0 means the craft is profitable at
		-- market prices — deliberate, because this is an on-ramp: the player
		-- should be able to work out "inputs cost less than the output is worth"
		-- from numbers the game already shows them. Raise toward 1.0 to make it
		-- a genuine judgement call instead.
		InputValueFraction = { min = 0.45, max = 0.7 },
		-- Widen the hunt for a matching output before giving up.
		OutputValueTolerance = 3.0,

	},

	--------------------------------------------------------------------------
	-- MILESTONES — the personal reason to keep crafting.
	--
	-- Crafting is the value engine, but on its own it is a flat activity: the
	-- thousandth craft feels exactly like the first. A milestone track gives
	-- the whole activity a shape — visible progress, a next thing to reach,
	-- and a reward that is itself a tradeable item, so hitting one puts new
	-- goods into the economy rather than gems (gems only ever come from ads or
	-- Robux; see AdConfig).
	--
	-- Rewards are ordinary items pulled from the shared reserve, so a milestone
	-- is a redistribution, not an inflation.
	-- TURNED OFF. Left fully intact: set enabled = true to bring the whole
	-- track back (server awards and the Crafting panel card both key off
	-- this flag alone).
	Milestones = {
		enabled = false,
		Tiers = {
			{ crafts = 5, name = "Apprentice", reward = { itemId = "itm_1_1_stone_relic", count = 5 } },
			{ crafts = 25, name = "Journeyman", reward = { itemId = "itm_1_3_amber_idol", count = 4 } },
			{ crafts = 75, name = "Artisan", reward = { itemId = "itm_1_5_jade_serpent", count = 4 } },
			{ crafts = 200, name = "Master", reward = { itemId = "itm_1_7_frost_lantern", count = 3 } },
			{ crafts = 500, name = "Grandmaster", reward = { itemId = "itm_1_10_obsidian_fang", count = 2 } },
			{ crafts = 1200, name = "Legend", reward = { itemId = "itm_1_11_void_shard", count = 1 } },
		},
	},

	--------------------------------------------------------------------------
	-- COMMUNAL GOAL — the whole server pulling on one rope.
	--
	-- This is the piece that makes events social AND makes recruiting pay off
	-- directly: the target is a fixed number of crafts by EVERYONE, so every
	-- extra player in the experience visibly moves a bar that the player
	-- watching it benefits from. Bringing a friend is not altruism, it is the
	-- fastest way to finish the goal.
	--
	-- Only players who CONTRIBUTED can claim, so it can't be farmed by idling,
	-- and the reward is an item so the payout is redistribution rather than a
	-- gem faucet. The counter is keyed by window index, so it resets itself on
	-- the clock with no reset job — the same trick the weekly leaderboards use.
	-- TURNED OFF, same as Milestones above: flip enabled to restore.
	CommunalGoal = {
		enabled = false,
		WindowSeconds = 24 * 3600, -- a fresh goal every day
		Target = 400, -- crafts by everyone, combined
		MinContribution = 1, -- crafts needed before you may claim
		Reward = { itemId = "itm_1_8_crimson_crown", count = 1 },
		Name = "Server Forge",
		Blurb = "Everyone's crafts count. Finish it together, everyone who helped gets paid.",
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
	-- Spares stand in for sold-out PERMANENT recipes, so they inherit that
	-- category: they can always come back, which is what isReobtainable asks.
	local rep = EventConfig.Replacement
	if rep and rep.enabled then
		for _, recipe in rep.SparePool do
			index["evt_" .. recipe.output.sku] = { name = "Restocked Recipes", category = "permanent" }
		end
	end
	producerIndex = index
	return index
end

-- The milestone tier a craft count has reached, and the next one to aim at.
-- Pure, so the client can render the same track the server pays out from.
function EventConfig.milestoneAt(crafts: number): (number, any?)
	local reached = 0
	local nextTier = nil
	for i, tier in EventConfig.Milestones.Tiers do
		if crafts >= tier.crafts then
			reached = i
		elseif nextTier == nil then
			nextTier = tier
		end
	end
	return reached, nextTier
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
