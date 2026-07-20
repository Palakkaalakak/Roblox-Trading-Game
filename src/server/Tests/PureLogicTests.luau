--!strict
-- Unit tests: Rarity, WeightedDraw, RollingAverage, Guard, value formula.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local WeightedDraw = require(ReplicatedStorage.Shared.Util.WeightedDraw)
local RollingAverage = require(ReplicatedStorage.Shared.Util.RollingAverage)
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
			eq(Rarity.tierFor(19999), "Rare")
			eq(Rarity.tierFor(5000), "Rare")
			eq(Rarity.tierFor(4999), "Legendary")
			eq(Rarity.tierFor(1200), "Legendary")
			eq(Rarity.tierFor(1199), "Mythical")
			eq(Rarity.tierFor(300), "Mythical")
			eq(Rarity.tierFor(299), "Godly")
			eq(Rarity.tierFor(80), "Godly")
			eq(Rarity.tierFor(79), "Celestial")
			eq(Rarity.tierFor(1), "Celestial")
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

		["value: fundamentals only — base, scarcity(burned), demand"] = function()
			local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
			-- computeValue(base, circulating, burned, demand)
			-- nothing burned, no demand -> sits exactly on its anchor
			eq(EconomyService.computeValue(100, 500, 0, 0), 100, "unburned, cold = base")

			-- A SINK LIFTS EVERY HOLDER: destroy half the copies ever made and
			-- the survivors are worth strictly more, with nobody having traded.
			local burnt = EconomyService.computeValue(100, 500, 500, 0)
			assert(burnt > 100, "burning must raise value: " .. burnt)
			local burntHarder = EconomyService.computeValue(100, 100, 900, 0)
			assert(burntHarder > burnt, "more burned = scarcer = worth more")

			-- PRODUCTION doesn't inflate the unit price: minting more copies
			-- pushes scarcity back toward 1.0x, so value settles at base while
			-- COUNT (and thus total worth) is what grows.
			local flooded = EconomyService.computeValue(100, 5000, 500, 0)
			assert(flooded < burnt, "abundance must not price above scarcity")
			assert(flooded >= 100, "value floors at its anchor, never below")

			-- demand lifts value, and is capped by DemandCoefficient
			local hot = EconomyService.computeValue(100, 500, 0, EconomyConfig.DemandRef * 10)
			eq(hot, math.floor(100 * (1 + EconomyConfig.DemandCoefficient) + 0.5), "demand caps at DemandCoefficient")
			assert(hot > EconomyService.computeValue(100, 500, 0, 0), "demand must raise value")

			-- scarcity is clamped: burning can't 100x an item
			local absurd = EconomyService.computeValue(100, 1, 1000000, 0)
			assert(absurd <= 100 * EconomyConfig.ScarcityMax, "scarcity clamped to ScarcityMax")

			-- Value NEVER reads RAP: it isn't even an argument any more. That
			-- feedback loop (Value -> price -> RAP -> Value) is what made Value
			-- meaningless. Guard the signature so it can't creep back in.
			eq(debug.info(EconomyService.computeValue, "a"), 4, "computeValue takes exactly (base, circulating, burned, demand)")

			-- never below 1
			eq(EconomyService.computeValue(0, 0, 0, 0), 1)
		end,

		["value: event-item scarcity seed — scarcer cap worth more"] = function()
			local scarce = EconomyService.scarcitySeed(50)
			local common = EconomyService.scarcitySeed(20000)
			assert(scarce > common, "scarcity inversion")
			assert(common >= 1, "floor at 1")
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

		["gem tax: cut matches config, net+cut == gross, zero-safe"] = function()
			local Tax = require(ReplicatedStorage.Shared.Util.Tax)
			local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
			-- config-derived so tuning the rate (incl. to 0) doesn't fail the suite;
			-- the invariants below are what actually matter.
			local pct = EconomyConfig.GemTaxPercent
			local net, cut = Tax.split(100)
			eq(cut, math.floor(100 * pct / 100), "cut = GemTaxPercent of gross")
			eq(net + cut, 100, "conservation")
			local n2, c2 = Tax.split(7)
			eq(n2 + c2, 7, "conservation")
			assert(n2 >= 0 and c2 >= 0)
			local n0, c0 = Tax.split(0)
			eq(n0, 0)
			eq(c0, 0)
		end,

		["bulk quote: per-copy floor + exact escrow"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local perCopy, escrow = TradeBoardService.bulkQuote(30, 100)
			eq(perCopy, 3, "floor(100/30)")
			eq(escrow, 90, "escrow = perCopy * count")
			local p2, e2 = TradeBoardService.bulkQuote(10, 100)
			eq(p2, 10)
			eq(e2, 100)
		end,

		["store buy limit: default is 1"] = function()
			local StoreConfig = require(ReplicatedStorage.Shared.Config.StoreConfig)
			eq(StoreConfig.DefaultMaxPerPlayer, 1, "default per-player buy limit must be 1")
		end,
	},
}
