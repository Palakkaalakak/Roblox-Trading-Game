--!strict
-- Unit tests: Rarity, WeightedDraw, RollingAverage, RateLimiter, Guard, value formula.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local WeightedDraw = require(ReplicatedStorage.Shared.Util.WeightedDraw)
local RollingAverage = require(ReplicatedStorage.Shared.Util.RollingAverage)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)
local EconomyService = require(script.Parent.Parent.Services.EconomyService)

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

return {
	name = "PureLogic",
	tests = {
		["rarity threshold boundaries"] = function()
			eq(Rarity.tierFor(20000), "Common")
			eq(Rarity.tierFor(15000), "Common")
			eq(Rarity.tierFor(14999), "Rare")
			eq(Rarity.tierFor(6000), "Rare")
			eq(Rarity.tierFor(5999), "Legendary")
			eq(Rarity.tierFor(2000), "Legendary")
			eq(Rarity.tierFor(1999), "Mythical")
			eq(Rarity.tierFor(1), "Mythical")
		end,

		["default weight monotonic and >= 1"] = function()
			local last = 0
			for _, supply in { 1, 10, 60, 150, 450, 800, 1000 } do
				local w = Rarity.defaultWeightFor(supply)
				assert(w >= 1, "weight below 1")
				assert(w >= last, "weight not monotonic")
				last = w
			end
		end,

		["weighted draw: empty and zero-weight give nil"] = function()
			eq(WeightedDraw.draw({}), nil)
			eq(WeightedDraw.draw({ { id = "x", weight = 0 } }), nil)
		end,

		["weighted draw: single candidate always wins"] = function()
			local rng = Random.new(42)
			for _ = 1, 20 do
				eq(WeightedDraw.draw({ { id = "only", weight = 5 } }, rng), "only")
			end
		end,

		["weighted draw: distribution tracks weights"] = function()
			local rng = Random.new(1337)
			local candidates = {
				{ id = "heavy", weight = 90 },
				{ id = "light", weight = 10 },
			}
			local counts = { heavy = 0, light = 0 }
			local n = 10000
			for _ = 1, n do
				local id = WeightedDraw.draw(candidates, rng) :: string
				counts[id] += 1
			end
			local heavyShare = counts.heavy / n
			assert(heavyShare > 0.85 and heavyShare < 0.95, "heavy share off: " .. heavyShare)
		end,

		["rolling average matches arithmetic mean"] = function()
			local samples = { 10, 20, 30, 40, 100 }
			local avg, count = 0, 0
			local sum = 0
			for _, s in samples do
				avg, count = RollingAverage.push(avg, count, s)
				sum += s
			end
			eq(count, #samples)
			assert(math.abs(avg - sum / #samples) < 1e-9, "avg mismatch: " .. avg)
		end,

		["rate limiter: burst then deny, refill via clock"] = function()
			local now = 0
			local limiter = RateLimiter.new(60, 3, function()
				return now
			end)
			assert(limiter:check("u1"))
			assert(limiter:check("u1"))
			assert(limiter:check("u1"))
			assert(not limiter:check("u1"), "burst not exhausted")
			now = 1 -- 60/min = 1 token per second
			assert(limiter:check("u1"), "did not refill")
			assert(not limiter:check("u1"))
			-- independent keys
			assert(limiter:check("u2"))
		end,

		["guard: valid offer accepted"] = function()
			local ok = Guard.checkOfferShape({ items = { itm_a = 2 }, gems = 50 })
			assert(ok)
			ok = Guard.checkOfferShape({ items = {}, gems = 0 })
			assert(ok, "empty offer should be structurally valid")
		end,

		["guard: bad offers rejected"] = function()
			local cases: { any } = {
				"nope",
				{ items = {}, gems = -1 },
				{ items = {}, gems = 1.5 },
				{ items = { itm_a = 0 }, gems = 0 },
				{ items = { itm_a = -3 }, gems = 0 },
				{ items = { itm_a = 2.5 }, gems = 0 },
				{ items = { [1] = 2 }, gems = 0 },
				{ items = {}, gems = 0, extra = true },
			}
			for i, offer in cases do
				local ok = Guard.checkOfferShape(offer)
				assert(not ok, "case " .. i .. " should be rejected")
			end
			-- copy cap: 9 copies fit (one per slot), 10 do not
			local nine = {}
			for i = 1, 9 do
				nine["itm_" .. i] = 1
			end
			assert(Guard.checkOfferShape({ items = nine, gems = 0 }), "9 copies should fit")
			assert(not Guard.checkOfferShape({ items = { itm_a = 10 }, gems = 0 }), "copy cap not enforced")
		end,

		["value formula: N/A below circulating threshold, else >= 1"] = function()
			eq(EconomyService.computeValue(1000, 0, 0), nil, "circ 0 must be N/A")
			local v1 = EconomyService.computeValue(1000, 1, 0)
			assert(v1 ~= nil and v1 >= 1, "circ 1 must be a real value")
		end,

		["value formula: scarcer cap is worth more, demand raises value"] = function()
			local scarce = EconomyService.computeValue(50, 1, 0) :: number
			local common = EconomyService.computeValue(20000, 1, 0) :: number
			assert(scarce > common, "scarcity inversion")
			assert(common <= 2, "huge-pool items must be cheap: " .. common)
			local hot = EconomyService.computeValue(1000, 1, 50) :: number
			local cold = EconomyService.computeValue(1000, 1, 0) :: number
			assert(hot > cold, "demand should raise value")
		end,

		["store pricing: fixed per-item price from config"] = function()
			local StoreService = require(script.Parent.Parent.Services.StoreService)
			local StoreConfig = require(ReplicatedStorage.Shared.Config.StoreConfig)
			-- every catalog entry's fixed price is returned verbatim by itemId
			for _, entry in StoreConfig.Catalog do
				local id = "store_" .. entry.sku
				eq(StoreService.priceFor(id), entry.price, "fixed price for " .. id)
			end
			-- unknown item -> 0
			eq(StoreService.priceFor("store_nope"), 0)
		end,

		["store buy limit: default is 1"] = function()
			local StoreConfig = require(ReplicatedStorage.Shared.Config.StoreConfig)
			eq(StoreConfig.DefaultMaxPerPlayer, 1, "default per-player buy limit must be 1")
		end,
	},
}
