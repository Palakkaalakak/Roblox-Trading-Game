--!strict
-- Unit tests for the three Phase-4 additions: syndicate requests, the
-- milestone track, and sold-out recipe replacement.
--
-- All three have a pure core on purpose, so the rules that actually matter
-- (expiry, ordering, tier boundaries, spare uniqueness) can be checked without
-- a DataStore, a player, or a live server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local SyndicateConfig = require(ReplicatedStorage.Shared.Config.SyndicateConfig)

local SyndicateService = require(script.Parent.Parent.Services.SyndicateService)
local CraftingService = require(script.Parent.Parent.Services.CraftingService)

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

return {
	name = "Progress",
	tests = {
		--------------------------------------------------------------------
		-- Syndicate requests
		--------------------------------------------------------------------
		["requests: expired and filled ones are dropped"] = function()
			local now = 1000
			local record = {
				requests = {
					{ reqId = "a", remaining = 5, expiresAt = now + 100, createdAt = 10 },
					{ reqId = "b", remaining = 0, expiresAt = now + 100, createdAt = 20 }, -- filled
					{ reqId = "c", remaining = 3, expiresAt = now - 1, createdAt = 30 }, -- expired
				},
			}
			local live = SyndicateService.liveRequests(record, now)
			eq(#live, 1, "only the open, unexpired request survives")
			eq(live[1].reqId, "a")
		end,

		["requests: oldest first, so nobody's ask is buried by a newer one"] = function()
			local now = 1000
			local record = {
				requests = {
					{ reqId = "new", remaining = 1, expiresAt = now + 100, createdAt = 300 },
					{ reqId = "old", remaining = 1, expiresAt = now + 100, createdAt = 100 },
					{ reqId = "mid", remaining = 1, expiresAt = now + 100, createdAt = 200 },
				},
			}
			local live = SyndicateService.liveRequests(record, now)
			eq(live[1].reqId, "old")
			eq(live[2].reqId, "mid")
			eq(live[3].reqId, "new")
		end,

		["requests: a record with no requests reads as empty, not nil"] = function()
			eq(#SyndicateService.liveRequests({}, 1000), 0)
			eq(#SyndicateService.liveRequests(nil, 1000), 0)
		end,

		["requests: donating is worth more XP than a trade"] = function()
			assert(
				SyndicateConfig.DonationXp > SyndicateConfig.XpSources.trade,
				"donation must out-pay a trade — it's the behaviour the system exists to encourage"
			)
		end,

		--------------------------------------------------------------------
		-- Milestones
		--------------------------------------------------------------------
		["milestones: boundaries are inclusive and the next tier is reported"] = function()
			local tiers = EventConfig.Milestones.Tiers
			local first = tiers[1]

			local reached, nextTier = EventConfig.milestoneAt(0)
			eq(reached, 0, "no crafts, no milestone")
			eq(nextTier.crafts, first.crafts, "aims at the first tier")

			reached = EventConfig.milestoneAt(first.crafts - 1)
			eq(reached, 0, "one short doesn't count")

			reached, nextTier = EventConfig.milestoneAt(first.crafts)
			eq(reached, 1, "hitting the number exactly earns the tier")
			eq(nextTier.crafts, tiers[2].crafts)
		end,

		["milestones: past the last tier there is nothing left to aim at"] = function()
			local tiers = EventConfig.Milestones.Tiers
			local reached, nextTier = EventConfig.milestoneAt(tiers[#tiers].crafts + 10000)
			eq(reached, #tiers, "every tier earned")
			eq(nextTier, nil, "and no next tier, so the UI shows a finished track")
		end,

		["milestones: the track only ever goes up"] = function()
			local previous = -1
			for i, tier in EventConfig.Milestones.Tiers do
				assert(tier.crafts > previous, ("tier %d must cost more than the one before"):format(i))
				assert(tier.reward.count > 0, "every tier pays something")
				previous = tier.crafts
			end
		end,

		--------------------------------------------------------------------
		-- Sold-out replacement
		--------------------------------------------------------------------
		["replacement: generated spares are unique, bounded and cost more"] = function()
			local recipe = {
				rid = "demo",
				tier = 2,
				blurb = "x",
				inputs = { ["itm_1_1_stone_relic"] = 4 },
				output = { sku = "demo", name = "Demo", totalSupply = 100, imageId = "" },
			}
			local spares = CraftingService.generatedSpares(recipe)
			assert(#spares > 0, "there is always a fallback")

			local seen: { [string]: boolean } = {}
			for _, spare in spares do
				assert(not seen[spare.output.sku], "each generated output sku is distinct")
				seen[spare.output.sku] = true
				assert(spare.output.sku ~= recipe.output.sku, "and never reuses the original's sku")
				assert(
					spare.inputs["itm_1_1_stone_relic"] > recipe.inputs["itm_1_1_stone_relic"],
					"a replacement asks for more, so a station gets hungrier over time"
				)
				assert(spare.output.totalSupply > 0, "a spare with no supply would be dead on arrival")
			end
		end,

		["replacement: a recipe with stock is never substituted"] = function()
			-- an unregistered sku has no economy record, which must read as
			-- "not sold out" — otherwise brand-new recipes get replaced on sight
			local recipe = {
				rid = "unregistered_demo",
				tier = 1,
				blurb = "x",
				inputs = { ["itm_1_1_stone_relic"] = 2 },
				output = { sku = "unregistered_demo_sku", name = "Demo", totalSupply = 10, imageId = "" },
			}
			eq(CraftingService.substitute(recipe, os.time()).rid, recipe.rid)
		end,

		["replacement: spares are authored before anything is generated"] = function()
			local rep = EventConfig.Replacement
			assert(rep ~= nil, "replacement config exists")
			assert(#rep.SparePool > 0, "the authored pool is tried first, so it must not be empty")
			assert(rep.IntervalSeconds > 0, "a zero interval would swap recipes every frame")
		end,

		["replacement: every authored spare produces something new"] = function()
			local existing: { [string]: boolean } = {}
			for _, event in EventConfig.Events do
				for _, recipe in event.recipes do
					existing[recipe.output.sku] = true
				end
			end
			for _, recipe in EventConfig.RotatingRecipes.Pool do
				existing[recipe.output.sku] = true
			end
			for _, spare in EventConfig.Replacement.SparePool do
				assert(
					not existing[spare.output.sku],
					("spare %s reuses an existing output sku, which would share its supply cap")
						:format(spare.rid)
				)
			end
		end,

		--------------------------------------------------------------------
		-- Communal goal
		--------------------------------------------------------------------
		["goal: reaching it needs more than one person's session"] = function()
			local goal = EventConfig.CommunalGoal
			assert(goal.Target > 0, "a zero target would be complete on arrival")
			assert(goal.MinContribution >= 1, "idlers must not be able to claim")
			assert(goal.Reward.count > 0, "the goal pays something")
			assert(goal.WindowSeconds > 0, "the window is what resets the counter")
		end,
	},
}
