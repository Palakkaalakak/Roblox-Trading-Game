--!strict
-- EventConfig: limited events — crafting, sacrifices, rotating recipes.
--
-- EVERYTHING here is a RECIPE: consume inputs, receive a LIMITED output item.
--   * kind = "crafting"  -> multi-item recipes (any inputs + optional gems)
--   * kind = "sacrifice" -> deleting EXACTLY ONE item (one input, count 1,
--     no gems). Enforced at boot — violations warn and the recipe is skipped.
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
			id = "evt_forge",
			name = "The Forge",
			kind = "crafting",
			enabled = false, -- sample only; flip on (or add a new entry) to run an event
			-- startsAt = nil, endsAt = nil  -> always on while enabled
			recipes = {
				{
					rid = "molten_idol",
					inputs = { ["itm_1_1_stone_relic"] = 2, ["itm_1_2_amber_idol"] = 1 },
					gems = 25,
					output = {
						sku = "molten_idol",
						name = "Molten Idol",
						totalSupply = 15,
						imageId = "rbxassetid://133423089599802", -- golden cash
					},
				},
			},
		},
		{
			id = "evt_void_altar",
			name = "Void Altar",
			kind = "sacrifice",
			enabled = false, -- sample only
			recipes = {
				{
					rid = "void_sigil",
					inputs = { ["itm_1_3_jade_serpent"] = 1 },
					gems = 0,
					output = {
						sku = "void_sigil",
						name = "Void Sigil",
						totalSupply = 10,
						imageId = "rbxassetid://100449548915705", -- purple coin
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
				inputs = { ["itm_1_2_amber_idol"] = 1 },
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
				inputs = { ["itm_1_1_stone_relic"] = 1, ["itm_1_2_amber_idol"] = 1 },
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
