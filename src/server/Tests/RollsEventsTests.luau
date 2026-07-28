--!strict
-- Unit tests: roll tiers, event categories, recipe-graph reachability, and
-- the rotation window's always-progressable guarantee.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RollConfig = require(ReplicatedStorage.Shared.Config.RollConfig)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

return {
	name = "RollsEvents",
	tests = {
		["rolls: five tiers, pricier + higher floor, valid windows/odds"] = function()
			eq(#RollConfig.Tiers, 5, "tier count")
			local seen = {}
			for i, tier in RollConfig.Tiers do
				assert(not seen[tier.id], "duplicate tier id " .. tier.id)
				seen[tier.id] = true
				assert(#tier.name > 0 and #tier.blurb > 0, tier.id .. " needs name+blurb")
				-- window is exactly four rarities, odds cover them and sum ~100
				eq(#tier.window, 4, tier.id .. " window size")
				local sum = 0
				for _, rarity in tier.window do
					assert(tier.odds[rarity] ~= nil, tier.id .. " missing odds for " .. rarity)
					sum += tier.odds[rarity]
				end
				assert(math.abs(sum - 100) < 0.01, tier.id .. " odds must sum to 100, got " .. sum)
				assert(tier.floorFrac > 0 and tier.floorFrac < 1, tier.id .. " floorFrac in (0,1)")
				if i > 1 then
					local prev = RollConfig.Tiers[i - 1]
					assert(tier.gems > prev.gems, tier.id .. " must cost more than " .. prev.id)
					-- the guaranteed value floor rises with tier
					assert(tier.floorFrac >= prev.floorFrac, tier.id .. " floor must not drop below " .. prev.id)
				end
			end
			assert(#RollConfig.PromptName > 0, "world prompt name set")
		end,

		["events: recipe graph fully reachable"] = function()
			local CraftingService = require(script.Parent.Parent.Services.CraftingService)
			local violations = CraftingService.validateRecipeGraph()
			eq(#violations, 0, "unreachable recipes: " .. table.concat(violations, " | "))
		end,

		["events: every rotation window can refine materials"] = function()
			local CraftingService = require(script.Parent.Parent.Services.CraftingService)
			local pool = EventConfig.RotatingRecipes.Pool
			for window = 0, 60 do
				local picks = CraftingService.rotationPicksFor(window)
				eq(#picks, EventConfig.RotatingRecipes.ActiveCount, "pick count, window " .. window)
				local hasMaterial = false
				local seen = {}
				for _, poolIndex in picks do
					assert(not seen[poolIndex], "duplicate pick in window " .. window)
					seen[poolIndex] = true
					if (pool[poolIndex].tier or 1) == 1 then
						hasMaterial = true
					end
				end
				assert(hasMaterial, "window " .. window .. " has no tier-1 material recipe")
			end
		end,

		["events: categories split permanent vs limited vs rotating"] = function()
			local CraftingService = require(script.Parent.Parent.Services.CraftingService)
			local now = os.time()
			local byId = {}
			for _, event in CraftingService.activeEvents(now) do
				byId[event.id] = event.category
			end
			eq(byId["evt_alchemist"], "permanent", "alchemist")
			eq(byId["evt_rotating"], "rotating", "rotating block")
			-- midsummer is limited while its end date is in the future
			if now < 1785542400 then
				eq(byId["evt_midsummer"], "limited", "midsummer")
			else
				eq(byId["evt_midsummer"], nil, "midsummer expired")
			end
		end,

		["events: liveProducerOf reflects the ACTIVE window, not the whole pool"] = function()
			-- The bug this guards: the static index used to list every recipe in
			-- RotatingRecipes.Pool as a producer, so the "craft it at X" hint
			-- pointed players at recipes that were in the pool but NOT one of
			-- this window's ActiveCount picks — a dead end. liveProducerOf must
			-- only claim "available now" for what's actually active this window.
			local CraftingService = require(script.Parent.Parent.Services.CraftingService)
			local now = os.time()
			local activeOutputs = {}
			for _, event in CraftingService.activeEvents(now) do
				for _, recipe in event.recipes do
					activeOutputs["evt_" .. recipe.output.sku] = true
				end
			end
			for _, recipe in EventConfig.RotatingRecipes.Pool do
				local outId = "evt_" .. recipe.output.sku
				local info = CraftingService.liveProducerOf(outId, now)
				assert(info ~= nil, outId .. " must resolve to SOME producer info")
				eq(info.availableNow, activeOutputs[outId] == true, outId .. " availableNow must match this window's actual picks")
				if not info.availableNow then
					assert(info.rotatesAt ~= nil and info.rotatesAt > now, outId .. " must say when it returns")
				end
			end
			-- a permanent station's output is always available, never rotation-gated
			local stationInfo = CraftingService.liveProducerOf("evt_transmutation_stone", now)
			assert(stationInfo ~= nil and stationInfo.availableNow == true, "permanent station always available")
			-- a base (non-event) item has no producer at all
			eq(CraftingService.liveProducerOf("itm_1_1_stone_relic", now), nil, "base items have no producer")
			eq(CraftingService.liveProducerOf("evt_totally_made_up", now), nil, "unknown event item has no producer")
		end,

		["rolls: empty payment is worth zero"] = function()
			local RollService = require(script.Parent.Parent.Services.RollService)
			eq(RollService.paymentValue({}), 0, "empty payment")
		end,

		["rolls: guaranteed floor is per-tier and rises in gems"] = function()
			local RollService = require(script.Parent.Parent.Services.RollService)
			local tiers = RollConfig.Tiers
			for _, tier in tiers do
				eq(RollService.floorFor(tier), math.floor(tier.gems * tier.floorFrac), "floor for " .. tier.id)
			end
			-- the guaranteed gem-value floor grows every tier
			for i = 2, #tiers do
				assert(
					RollService.floorFor(tiers[i]) > RollService.floorFor(tiers[i - 1]),
					tiers[i].id .. " floor must exceed " .. tiers[i - 1].id
				)
			end
			-- top tier's window carries no Common (mythic starts at Legendary)
			local topWindow = tiers[#tiers].window
			for _, rarity in topWindow do
				assert(rarity ~= "Common" and rarity ~= "Rare", "top tier window too low: " .. rarity)
			end
			-- when the registry is booted (Play), the top tier never shows Common
			local EconomyService = require(script.Parent.Parent.Services.EconomyService)
			if next(EconomyService.allItems()) ~= nil then
				for _, o in RollService.oddsFor(tiers[#tiers]) do
					eq(o.rarity ~= "Common", true, "no Common in top-tier odds: " .. tostring(o.name))
				end
			end
		end,

		["rolls: only re-obtainable items may pay for a roll"] = function()
			-- base-pool items: always fine (rolls/store/draws restock them)
			eq(EventConfig.isReobtainable("itm_1_1_stone_relic"), true, "base item")
			-- rotating-pool outputs: the recipe reappears in future windows
			eq(EventConfig.isReobtainable("evt_refined_essence"), true, "rotating output")
			eq(EventConfig.isReobtainable("evt_storm_artifact"), true, "rotating artifact")
			-- permanent-station outputs: craftable forever
			eq(EventConfig.isReobtainable("evt_transmutation_stone"), true, "station output")
			eq(EventConfig.isReobtainable("evt_ancient_grail"), true, "grail (permanent forge)")
			-- limited/seasonal outputs: once the event ends they can NEVER be
			-- re-made, so redistributing them into the reserve would strand them
			eq(EventConfig.isReobtainable("evt_solstice_talisman"), false, "seasonal output")
			eq(EventConfig.isReobtainable("evt_midsummer_wreath"), false, "seasonal output 2")
			-- unknown event ids are never eligible
			eq(EventConfig.isReobtainable("evt_never_existed"), false, "unknown evt id")
		end,
	},
}
