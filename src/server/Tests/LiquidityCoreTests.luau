--!strict
-- Unit tests for LiquidityCore: the pure chain-trade solver.

local Core = require(script.Parent.Parent.Services.LiquidityCore)

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

local function truthy(v: any, label: string)
	if not v then
		error(label, 2)
	end
end

-- Terse listing builders. `g`/`w` are {itemId = count} maps; gems via GEM.
local GEM = Core.GEM_KEY

local function swap(id: string, poster: number, give: any, want: any, extra: any?): any
	local l: any = {
		id = id,
		kind = "swap",
		posterId = poster,
		status = "open",
		autoTrade = true,
		createdAt = 0,
		give = { items = give, gems = 0 },
		want = { items = want, gems = 0 },
	}
	for k, v in (extra or {}) :: any do
		l[k] = v
	end
	return l
end

local function sell(id: string, poster: number, itemId: string, price: number, count: number): any
	return {
		id = id,
		kind = "sell",
		posterId = poster,
		status = "open",
		createdAt = 0,
		itemId = itemId,
		gemsPerCopy = price,
		remainingCount = count,
	}
end

local function bulk(id: string, poster: number, itemId: string, price: number, count: number): any
	return {
		id = id,
		kind = "bulk",
		posterId = poster,
		status = "open",
		createdAt = 0,
		itemId = itemId,
		gemsPerCopy = price,
		remainingCount = count,
	}
end

local npcCounter = 0
local function npcLeg(id: string, kind: string, give: any, want: any, maxUnits: number): any
	npcCounter += 1
	return { id = id, posterId = -1000000 - npcCounter, kind = kind, npc = true, createdAt = 100, give = give, want = want, maxUnits = maxUnits }
end

local function norm(listings: { any }): { any }
	local out = {}
	for _, l in listings do
		local leg = Core.normalize(l)
		if leg then
			table.insert(out, leg)
		end
	end
	return out
end

local function unitsOf(legs: { any }): any
	local u = {}
	for _, leg in legs do
		u[leg.id] = 1
	end
	return u
end

return {
	name = "LiquidityCore",
	tests = {
		--------------------------------------------------------------------
		-- The balance check
		--------------------------------------------------------------------

		-- The whole premise: a set balances when pooled give covers pooled
		-- want. This set has NO cycle and NO chain running through it — any
		-- loop-finder or string-follower misses it entirely.
		["4-party set with no loop still balances"] = function()
			local legs = norm({
				swap("a", 1, { sword = 2 }, { shield = 1 }),
				swap("b", 2, { shield = 1 }, { sword = 1 }),
				swap("c", 3, { sword = 1 }, { shield = 1 }),
				swap("d", 4, { shield = 1 }, { sword = 2 }),
			})
			eq(#legs, 4, "all four normalised")
			-- pooled give: sword 3, shield 2 | pooled want: sword 3, shield 2
			local net = Core.net(legs, unitsOf(legs))
			eq(net.sword, nil, "swords net to zero")
			eq(net.shield, nil, "shields net to zero")
			eq(Core.feasible(legs, unitsOf(legs)), true, "set is feasible")
		end,

		["set is infeasible when pooled give does not cover pooled want"] = function()
			local legs = norm({
				swap("a", 1, { sword = 1 }, { shield = 2 }),
				swap("b", 2, { shield = 1 }, { sword = 1 }),
			})
			eq(Core.feasible(legs, unitsOf(legs)), false, "one shield short")
		end,

		--------------------------------------------------------------------
		-- Growing a chain
		--------------------------------------------------------------------

		-- Anna/Ben/Cara: no two can trade, all three together can.
		["three-way chain forms when no pair could trade"] = function()
			local pool = norm({
				swap("anna", 1, { sword = 1 }, { shield = 1 }),
				swap("ben", 2, { shield = 1 }, { bow = 1 }),
				swap("cara", 3, { bow = 1 }, { sword = 1 }),
			})
			local chain = Core.growFrom(pool, pool[1], { maxParticipants = 8 })
			truthy(chain, "chain found")
			eq((chain :: any).participants, 3, "all three served")
			eq(Core.feasible((chain :: any).legs, (chain :: any).units), true, "balances")
		end,

		["participant cap is respected"] = function()
			local pool = norm({
				swap("anna", 1, { sword = 1 }, { shield = 1 }),
				swap("ben", 2, { shield = 1 }, { bow = 1 }),
				swap("cara", 3, { bow = 1 }, { sword = 1 }),
			})
			eq(Core.growFrom(pool, pool[1], { maxParticipants = 2 }), nil, "3-way blocked at cap 2")
		end,

		-- Two listings from one poster is the alt-account/self-deal vector.
		["never chains two listings from the same poster"] = function()
			local pool = norm({
				swap("a", 7, { sword = 1 }, { shield = 1 }),
				swap("b", 7, { shield = 1 }, { sword = 1 }), -- same posterId
			})
			eq(Core.growFrom(pool, pool[1], { maxParticipants = 8 }), nil, "self-deal refused")
		end,

		--------------------------------------------------------------------
		-- Excess
		--------------------------------------------------------------------

		-- Leftover may only go to someone who actually wanted that item —
		-- strictly better for them, so posted terms are never worsened.
		["leftover goes to a participant who wanted it, as a bonus"] = function()
			local pool = norm({
				swap("a", 1, { sword = 2 }, { shield = 1 }),
				swap("b", 2, { shield = 1 }, { sword = 1 }),
			})
			local chain = Core.growFrom(pool, pool[1], { maxParticipants = 8 })
			truthy(chain, "chain found")
			local c = chain :: any
			eq(c.bonus.b.sword, 1, "spare sword credited to the poster who wanted swords")
		end,

		-- The bot may not keep a remainder, so if nobody in the pool wants it
		-- the chain must be refused outright rather than leaving it holding stock.
		["chain refused when leftover has no taker anywhere"] = function()
			local pool = norm({
				swap("a", 1, { sword = 1, bow = 1 }, { shield = 1 }),
				swap("b", 2, { shield = 1 }, { sword = 1 }),
			})
			eq(Core.growFrom(pool, pool[1], { maxParticipants = 8 }), nil, "orphan bow refused")
		end,

		-- Same leftover, but now someone else in the pool wants a bow. The
		-- bidirectional closure should pull them in rather than bin the chain.
		["chain rescued by pulling in someone who wants the leftover"] = function()
			local pool = norm({
				swap("a", 1, { sword = 1, bow = 1 }, { shield = 1 }),
				swap("b", 2, { shield = 1 }, { sword = 1 }),
				swap("c", 3, { shield = 1 }, { bow = 1 }),
			})
			local chain = Core.growFrom(pool, pool[1], { maxParticipants = 8 })
			truthy(chain, "chain rescued instead of binned")
			local c = chain :: any
			truthy(c.participants >= 3, "the bow-wanter was pulled in")
			eq(Core.feasible(c.legs, c.units), true, "balances")
		end,

		--------------------------------------------------------------------
		-- Consent gate
		--------------------------------------------------------------------

		["ask-first and wildcard listings are ignored entirely"] = function()
			eq(
				Core.normalize(swap("a", 1, { sword = 1 }, { shield = 1 }, { autoTrade = false })),
				nil,
				"autoTrade=false excluded"
			)
			eq(
				Core.normalize(swap("b", 1, { sword = 1 }, { shield = 1 }, { hasWildcard = true })),
				nil,
				"wildcard want excluded"
			)
			eq(Core.normalize(swap("c", 1, { sword = 1 }, { shield = 1 }, { status = "filled" })), nil, "closed excluded")
			truthy(Core.normalize(swap("d", 1, { sword = 1 }, { shield = 1 })), "plain autoTrade swap included")
		end,

		-- Scope is a player-visibility rule, not a bot rule: the bot is not
		-- scope-bound, so normalise must not filter on it.
		["scope never excludes a listing"] = function()
			local a = swap("a", 1, { sword = 1 }, { shield = 1 }, { scope = "server" })
			local b = swap("b", 2, { sword = 1 }, { shield = 1 }, { scope = "global" })
			truthy(Core.normalize(a), "server-scoped included")
			truthy(Core.normalize(b), "global-scoped included")
		end,

		--------------------------------------------------------------------
		-- Gem-denominated kinds
		--------------------------------------------------------------------

		["sell and bulk normalise to per-unit give/want"] = function()
			local s = Core.normalize(sell("s", 1, "sword", 300, 5)) :: any
			eq(s.give.sword, 1, "sell gives one copy per unit")
			eq(s.want[GEM], 300, "sell wants the posted price per unit")
			eq(s.maxUnits, 5, "divisible up to remaining stock")

			local b = Core.normalize(bulk("b", 2, "sword", 280, 4)) :: any
			eq(b.give[GEM], 280, "bulk pays gems per unit")
			eq(b.want.sword, 1, "bulk wants one copy per unit")
			eq(b.maxUnits, 4, "divisible up to remaining count")
		end,

		-- Bulk Buy (Part D): contributions must be whole multiples of unitIn,
		-- which falls out of counting in units rather than raw copies.
		["bulkbuy normalises in whole unitIn multiples"] = function()
			local leg = Core.normalize({
				id = "bb",
				kind = "bulkbuy",
				posterId = 1,
				status = "open",
				createdAt = 0,
				wantItemId = "sword",
				unitIn = 2,
				remainingCount = 7,
				payout = { items = { shield = 1 }, gems = 0 },
			}) :: any
			eq(leg.want.sword, 2, "wants unitIn per unit")
			eq(leg.give.shield, 1, "pays payout per unit")
			eq(leg.maxUnits, 3, "7 remaining at unitIn 2 = 3 whole units, no dust")
		end,

		--------------------------------------------------------------------
		-- Implied orders: the gem bridge
		--------------------------------------------------------------------

		-- A swap with no barter mirror, bridged through gem listings. This is
		-- the case the live board can never match today, because tryMatch only
		-- compares swap-to-swap and crossTerms only gem-to-gem.
		["swap with no mirror is bridged by an existing sell and bulk"] = function()
			local pool = norm({
				swap("sw", 1, { sword = 1 }, { shield = 1 }),
				sell("se", 2, "shield", 280, 1), -- supplies what the swap wants
				bulk("bu", 3, "sword", 300, 1), -- absorbs what the swap gives
			})
			eq(#pool, 3, "all three normalised")
			local found = Core.solve(pool, 100, { impliedEnabled = true, maxParticipants = 4, maxOps = 4 })
			eq(#found, 1, "one bridged chain")
			local c = found[1]
			eq(c.participants, 3, "swap + sell + bulk")
			eq(Core.feasible(c.legs, c.units), true, "gem legs balance")
		end,

		["no bridge when the gem legs do not cover"] = function()
			-- bulk pays 200 but the sell wants 280: 80 short, nobody funds it.
			local pool = norm({
				swap("sw", 1, { sword = 1 }, { shield = 1 }),
				sell("se", 2, "shield", 280, 1),
				bulk("bu", 3, "sword", 200, 1),
			})
			eq(#Core.solve(pool, 100, { impliedEnabled = true, maxParticipants = 4 }), 0, "underfunded bridge refused")
		end,

		-- LOW level: pure barter only, gem legs are never touched.
		["bridging is off when impliedEnabled is false"] = function()
			local pool = norm({
				swap("sw", 1, { sword = 1 }, { shield = 1 }),
				sell("se", 2, "shield", 280, 1),
				bulk("bu", 3, "sword", 300, 1),
			})
			eq(#Core.solve(pool, 100, { impliedEnabled = false, maxParticipants = 4 }), 0, "no gem legs at LOW")
		end,

		-- A sell + bulk with no swap is the order book's job (crossTerms, at the
		-- maker's price). Matching it here would settle it at the wrong price.
		["a chain with no swap in it is never produced"] = function()
			local pool = norm({
				sell("se", 1, "sword", 280, 1),
				bulk("bu", 2, "sword", 300, 1),
			})
			eq(#Core.solve(pool, 100, { impliedEnabled = true, maxParticipants = 4 }), 0, "sell+bulk alone left to the book")
		end,

		--------------------------------------------------------------------
		-- Scoring and solve
		--------------------------------------------------------------------

		-- Rank by players served and how long they waited, never by value.
		["older listings score higher"] = function()
			local fresh = { legs = {}, units = {}, bonus = {}, participants = 2 }
			local stale = { legs = {}, units = {}, bonus = {}, participants = 2 }
			fresh.legs = { { createdAt = 1000 }, { createdAt = 1000 } } :: any
			stale.legs = { { createdAt = 0 }, { createdAt = 0 } } :: any
			local a = Core.score(fresh :: any, 1000, nil)
			local b = Core.score(stale :: any, 1000, nil)
			truthy(b > a, "the longer-waiting chain ranks first")
		end,

		["solve returns disjoint chains and respects maxOps"] = function()
			local pool = norm({
				swap("a1", 1, { sword = 1 }, { shield = 1 }),
				swap("a2", 2, { shield = 1 }, { sword = 1 }),
				swap("b1", 3, { bow = 1 }, { helm = 1 }),
				swap("b2", 4, { helm = 1 }, { bow = 1 }),
			})
			local chains = Core.solve(pool, 100, { maxParticipants = 4, maxOps = 5 })
			truthy(#chains >= 2, "both independent pairs found")

			local seen = {}
			for _, c in chains do
				for _, leg in c.legs do
					eq(seen[leg.id], nil, "a listing is never used by two chains in one pass")
					seen[leg.id] = true
				end
			end

			eq(#Core.solve(pool, 100, { maxParticipants = 4, maxOps = 1 }), 1, "maxOps caps the pass")
		end,

		-- ── system legs: gem store shelf + event recipes ─────────────────────
		["a craft recipe can close a chain no players could"] = function()
			-- swap: gives a, wants b. Nobody gives b, but a recipe turns a into b.
			local pool = norm({ swap("sw", 1, { a = 1 }, { b = 1 }) })
			table.insert(pool, npcLeg("craft:e:r", "craft", { b = 1 }, { a = 1 }, 5))
			local found = Core.solve(pool, 100, { impliedEnabled = true, maxParticipants = 4 })
			eq(#found, 1, "recipe bridges the swap")
			eq(found[1].participants, 1, "only players count as participants")
			eq(Core.feasible(found[1].legs, found[1].units), true, "balances")
		end,

		["a system leg never absorbs leftovers"] = function()
			-- swap gives a x2 but the recipe only consumes one: the spare a has no
			-- PLAYER taker, so the chain is refused rather than feeding the recipe.
			local pool = norm({ swap("sw", 1, { a = 2 }, { b = 1 }) })
			table.insert(pool, npcLeg("craft:e:r", "craft", { b = 1 }, { a = 1 }, 5))
			eq(#Core.solve(pool, 100, { impliedEnabled = true, maxParticipants = 4 }), 0, "npc cannot keep the excess")
		end,

		["system legs stay out at LOW"] = function()
			local pool = norm({ swap("sw", 1, { a = 1 }, { b = 1 }) })
			table.insert(pool, npcLeg("craft:e:r", "craft", { b = 1 }, { a = 1 }, 5))
			eq(#Core.solve(pool, 100, { impliedEnabled = false, maxParticipants = 4 }), 0, "barter only at LOW")
		end,

		["the store shelf plus a buy order closes a swap"] = function()
			-- swap: gives a, wants b. Store sells b for 100. A bulk buyer pays 100 for a.
			local pool = norm({
				swap("sw", 1, { a = 1 }, { b = 1 }),
				bulk("bu", 3, "a", 100, 1),
			})
			table.insert(pool, npcLeg("store:b", "store", { b = 1 }, { [GEM] = 100 }, 20))
			local found = Core.solve(pool, 100, { impliedEnabled = true, maxParticipants = 4 })
			eq(#found, 1, "swap + store + bulk")
			eq(found[1].participants, 2, "two players served")
		end,

		["one system leg can serve two chains in a pass"] = function()
			local pool = norm({
				swap("s1", 1, { a = 1 }, { b = 1 }),
				swap("s2", 2, { a = 1 }, { b = 1 }),
			})
			table.insert(pool, npcLeg("craft:e:r", "craft", { b = 1 }, { a = 1 }, 5))
			local found = Core.solve(pool, 100, { impliedEnabled = true, maxParticipants = 4, maxOps = 4 })
			eq(#found, 2, "recipe reused across chains")
		end,
	},
}
