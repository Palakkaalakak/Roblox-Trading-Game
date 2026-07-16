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
		["rolls: five tiers, strictly pricier and luckier"] = function()
			eq(#RollConfig.Tiers, 5, "tier count")
			local seen = {}
			for i, tier in RollConfig.Tiers do
				assert(not seen[tier.id], "duplicate tier id " .. tier.id)
				seen[tier.id] = true
				assert(#tier.name > 0 and #tier.blurb > 0, tier.id .. " needs name+blurb")
				if i > 1 then
					local prev = RollConfig.Tiers[i - 1]
					assert(tier.gems > prev.gems, tier.id .. " must cost more than " .. prev.id)
					assert(tier.luck > prev.luck, tier.id .. " must be luckier than " .. prev.id)
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

		["rolls: empty payment is worth zero"] = function()
			local RollService = require(script.Parent.Parent.Services.RollService)
			eq(RollService.paymentValue({}), 0, "empty payment")
		end,
	},
}
