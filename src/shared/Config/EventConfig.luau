--!strict
-- EventConfig: limited events — crafting, sacrifices, rotating recipes.
--
-- EVERYTHING here is a RECIPE: consume inputs, receive a LIMITED output item.
--   * kind = "crafting"  -> several different item types, each any count (a
--     little of one, a lot of another) + optional gems. The cheaper path.
--   * kind = "sacrifice" -> ONE item type only, but a LOT of it — a real
--     dent in your holdings. Always costs MORE gems than a crafting recipe
--     (harder, more committed path to the same kind of output).
--
-- Each event may carry `npc = { position = {x, y, z} }`: the server spawns an
-- event NPC there at boot (shopkeeper-style, event-named sign); triggering
-- its prompt opens the Events panel filtered to that event. No `npc` field =
-- no NPC. There is NO HUD button for events — NPCs are the way in.
-- Consumed input items are DESTROYED (retired from circulation — the
-- existence counter drops). Output items are limited: `outputSupply` copies
-- total, reserved atomically cross-server; when the last one is crafted the
-- recipe automatically stops working ("Fully crafted!"). Outputs are normal
-- tradeable items with Store Cost: N/A (Event Item).
--
-- DEV WORKFLOW — adding an event:
--   1. Add an entry to Events below (or a recipe to RotatingRecipes.Pool).
--      Output `sku` must be NEW and unique (itemId becomes "evt_<sku>") —
--      never reuse one; old outputs live on in inventories.
--      Input ids must be REAL itemIds (check the registry / pool configs).
--   2. Reboot. Done. Set `enabled = false` (or add `endsAt`) to close it.
--
-- Timing: `startsAt`/`endsAt` are optional unix times; omitted = always on
-- (while `enabled`). RotatingRecipes picks ActiveCount recipes from Pool per
-- time window, deterministically — all servers agree with no coordination.

local EventConfig = {
	Events = {
		{
			id = "evt_alchemist",
			name = "Alchemist's Lab",
			kind = "crafting",
			enabled = true,
			recipes = {
				{
					rid = "transmutation_stone",
					inputs = { ["itm_1_1_stone_relic"] = 2, ["itm_1_3_amber_idol"] = 1 },
					gems = 30,
					output = {
						sku = "transmutation_stone",
						name = "Transmutation Stone",
						totalSupply = 20,
						imageId = "rbxassetid://15402885986", -- gem pile
					},
				},
			},
		},
		{
			id = "evt_shadow_ritual",
			name = "Shadow Ritual",
			kind = "sacrifice",
			enabled = true,
			recipes = {
				{
					rid = "shadow_crown",
					inputs = { ["itm_1_2_copper_coin"] = 5 }, -- one item type, a lot of it
					gems = 60, -- sacrifice always costs more gems than crafting
					output = {
						sku = "shadow_crown",
						name = "Shadow Crown",
						totalSupply = 15,
						imageId = "rbxassetid://100449548915705", -- purple coin
					},
				},
			},
		},
		{
			id = "evt_guardian_blessing",
			name = "Guardian's Blessing",
			kind = "crafting",
			enabled = true,
			recipes = {
				{
					rid = "rune_protection",
					inputs = { ["itm_1_5_jade_serpent"] = 1, ["itm_1_6_sunstone_charm"] = 1 },
					gems = 40,
					output = {
						sku = "rune_protection",
						name = "Rune of Protection",
						totalSupply = 18,
						imageId = "rbxassetid://15403275152", -- blue potion
					},
				},
			},
		},
	},

	-- Rotating recipes ("recipe store"): ActiveCount recipes from Pool are
	-- craftable per window; the set changes every RotationIntervalSeconds.
	RotatingRecipes = {
		enabled = false, -- sample only
		RotationIntervalSeconds = 3600, -- 1h windows (tune freely)
		ActiveCount = 1,
		Pool = {
			{
				rid = "gift_red",
				inputs = { ["itm_1_1_stone_relic"] = 1 },
				gems = 15,
				output = {
					sku = "crimson_gift",
					name = "Crimson Gift",
					totalSupply = 12,
					imageId = "rbxassetid://99174903737611",
				},
			},
			{
				rid = "gift_blue",
				inputs = { ["itm_1_3_amber_idol"] = 1 },
				gems = 15,
				output = {
					sku = "azure_gift",
					name = "Azure Gift",
					totalSupply = 12,
					imageId = "rbxassetid://128442519585600",
				},
			},
			{
				rid = "gift_pile",
				inputs = { ["itm_1_1_stone_relic"] = 1, ["itm_1_3_amber_idol"] = 1 },
				gems = 10,
				output = {
					sku = "gift_hoard",
					name = "Gift Hoard",
					totalSupply = 8,
					imageId = "rbxassetid://15402969720",
				},
			},
		},
	},
}

return EventConfig
