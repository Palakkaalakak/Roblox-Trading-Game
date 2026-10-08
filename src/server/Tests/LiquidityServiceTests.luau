--!strict
-- LiquidityService.solveListings: raw board listings in, chain trades out.

local Service = require(script.Parent.Parent.Services.LiquidityService)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.LiquidityConfig)

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

-- Shaped like TradeBoardService listings (give/want are {items, gems}).
local function swap(id: string, poster: number, give: any, want: any, createdAt: number?, auto: boolean?): any
	return {
		id = id,
		kind = "swap",
		posterId = poster,
		status = "open",
		autoTrade = auto ~= false,
		createdAt = createdAt or 0,
		give = { items = give, gems = 0 },
		want = { items = want, gems = 0 },
	}
end

local function sell(id: string, poster: number, itemId: string, price: number): any
	return { id = id, kind = "sell", posterId = poster, status = "open", createdAt = 0, itemId = itemId, gemsPerCopy = price, remainingCount = 1 }
end

local function bulk(id: string, poster: number, itemId: string, price: number): any
	return { id = id, kind = "bulk", posterId = poster, status = "open", createdAt = 0, itemId = itemId, gemsPerCopy = price, remainingCount = 1 }
end

return {
	name = "LiquidityService",
	tests = {
		["a 3-way chain of raw autoTrade swaps is found"] = function()
			local chains, legs = Service.solveListings({
				swap("a", 1, { sword = 1 }, { shield = 1 }),
				swap("b", 2, { shield = 1 }, { bow = 1 }),
				swap("c", 3, { bow = 1 }, { sword = 1 }),
			}, 100, Config.Dials.LOW)
			eq(legs, 3, "all three became legs")
			eq(#chains, 1, "one chain")
			eq(chains[1].participants, 3, "three served")
		end,

		["ask-first swaps are never included"] = function()
			local chains, legs = Service.solveListings({
				swap("a", 1, { sword = 1 }, { shield = 1 }),
				swap("b", 2, { shield = 1 }, { sword = 1 }, 0, false), -- ask-first
			}, 100, Config.Dials.LOW)
			eq(legs, 1, "the ask-first listing never became a leg")
			eq(#chains, 0, "so nothing to chain")
		end,

		-- LOW is pure barter; the Market's gem listings only join from MEDIUM.
		["gem listings join at MEDIUM but not at LOW"] = function()
			local board = {
				swap("sw", 1, { sword = 1 }, { shield = 1 }),
				sell("se", 2, "shield", 280),
				bulk("bu", 3, "sword", 300),
			}
			eq(#(Service.solveListings(board, 100, Config.Dials.LOW)), 0, "LOW ignores the Market")
			eq(#(Service.solveListings(board, 100, Config.Dials.MEDIUM)), 1, "MEDIUM bridges through it")
		end,

		["the leg cap keeps the OLDEST listings"] = function()
			local board = {}
			-- MaxLegs+50 mutually unmatched swaps, id encodes age
			for i = 1, Config.MaxLegs + 50 do
				table.insert(board, swap("s" .. i, i, { ["give" .. i] = 1 }, { ["want" .. i] = 1 }, i))
			end
			local _, legs = Service.solveListings(board, 10000, Config.Dials.LOW)
			eq(legs, Config.MaxLegs, "capped")
		end,
	},
}
