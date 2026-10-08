--!strict
-- LiquidityCore: PURE chain-trade solver. No IO, no services, no Instances —
-- every function is (data) -> (data). LiquidityService feeds it a snapshot of
-- the board and executes what it returns; tests run it raw.
--
-- A CHAIN TRADE is a set of listings settled ALL AT ONCE because what the set
-- collectively gives covers what it collectively wants. Anna gives a Sword and
-- wants a Shield, Ben gives a Shield and wants a Bow, Cara gives a Bow and
-- wants a Sword: no two of them can trade, but all three together balance.
-- It does NOT have to be a loop — see the 4-party test case, which balances
-- with no cycle in it at all and which any loop-finder would miss.
--
-- Everything reduces to ONE check. Normalise every listing kind to a per-unit
-- give/want pair, then:
--
--     feasible(S) <=> for every key k:  sum(give[k] * units) >= sum(want[k] * units)
--
-- Items are fungible by itemId, so that is plain counting — not a path search.
-- Gems ride along as just another key (GEM_KEY), which keeps the arithmetic
-- uniform instead of special-casing currency everywhere.
--
-- Invariants enforced here (the rest live in LiquidityService):
--   * every participant receives AT LEAST its stated want — terms are met by
--     construction, since each leg is credited exactly `want * units`; excess
--     only ever ADDS to someone. Never worsen a poster's posted terms.
--   * excess with no taker means REJECT the chain — the bot may not keep it
--   * never two legs from the same posterId (no self-dealing)
--   * only pre-authorised listings enter at all (see `normalize`)

local LiquidityCore = {}

-- Gems are modelled as just another fungible key so give/want arithmetic is
-- uniform. "\0" cannot collide with a real itemId.
local GEM_KEY = "\0gems"
LiquidityCore.GEM_KEY = GEM_KEY

export type Bundle = { items: { [string]: number }, gems: number }

-- One normalised listing. `give`/`want` are PER UNIT; a swap is simply an
-- indivisible 1-unit leg, while sell/bulk/bulkbuy are divisible. That single
-- shape is what lets one balance check serve all four listing kinds.
export type Leg = {
	id: string,
	posterId: number,
	kind: string,
	createdAt: number,
	give: { [string]: number },
	want: { [string]: number },
	maxUnits: number,
	-- A system counterparty (gem store shelf, event recipe) rather than a
	-- player listing: unlimited-ish supply, never seeds a chain, never takes
	-- leftovers, and may serve several chains in one pass.
	npc: boolean?,
}

export type Chain = {
	legs: { Leg },
	units: { [string]: number }, -- legId -> units taken
	bonus: { [string]: { [string]: number } }, -- legId -> key -> extra credited
	participants: number,
}

--------------------------------------------------------------------------------
-- Flat-map helpers
--------------------------------------------------------------------------------

local function flatten(bundle: Bundle?): { [string]: number }
	local out = {}
	if bundle == nil then
		return out
	end
	for itemId, n in bundle.items or {} do
		if n ~= 0 then
			out[itemId] = (out[itemId] or 0) + n
		end
	end
	local gems = bundle.gems or 0
	if gems ~= 0 then
		out[GEM_KEY] = (out[GEM_KEY] or 0) + gems
	end
	return out
end
LiquidityCore.flatten = flatten

local function scaledAdd(into: { [string]: number }, src: { [string]: number }, mult: number)
	for k, n in src do
		local v = (into[k] or 0) + n * mult
		if v == 0 then
			into[k] = nil
		else
			into[k] = v
		end
	end
end

--------------------------------------------------------------------------------
-- Normalisation — the consent gate
--------------------------------------------------------------------------------

-- Turn a raw board listing into a Leg, or nil when the bot may not touch it.
--
-- `autoTrade == false` means the poster wants to review offers themselves, so
-- those are ignored outright — not filled, not flagged. Wildcard wants can't
-- be settled automatically either, since a fuzzy want has no concrete bundle.
function LiquidityCore.normalize(listing: any): Leg?
	if listing == nil or listing.status ~= "open" then
		return nil
	end
	local kind = listing.kind
	local createdAt = listing.createdAt or 0
	local posterId = listing.posterId

	if kind == "swap" then
		if listing.autoTrade ~= true then
			return nil -- ask-first: poster reviews it, bot stays out
		end
		if listing.hasWildcard == true then
			return nil -- fuzzy want cannot auto-settle
		end
		local give, want = flatten(listing.give), flatten(listing.want)
		if next(give) == nil or next(want) == nil then
			return nil
		end
		return {
			id = listing.id,
			posterId = posterId,
			kind = kind,
			createdAt = createdAt,
			give = give,
			want = want,
			maxUnits = 1, -- indivisible: the bundle is the offer
		}
	elseif kind == "sell" then
		-- Seller hands over 1 copy, receives gemsPerCopy. Divisible per copy.
		local remaining = listing.remainingCount or 0
		local price = listing.gemsPerCopy or 0
		if remaining <= 0 or price <= 0 or listing.itemId == nil then
			return nil
		end
		return {
			id = listing.id,
			posterId = posterId,
			kind = kind,
			createdAt = createdAt,
			give = { [listing.itemId] = 1 },
			want = { [GEM_KEY] = price },
			maxUnits = remaining,
		}
	elseif kind == "bulk" then
		-- Buy order: poster hands over gems, receives 1 copy. Divisible.
		local remaining = listing.remainingCount or 0
		local price = listing.gemsPerCopy or 0
		if remaining <= 0 or price <= 0 or listing.itemId == nil then
			return nil
		end
		return {
			id = listing.id,
			posterId = posterId,
			kind = kind,
			createdAt = createdAt,
			give = { [GEM_KEY] = price },
			want = { [listing.itemId] = 1 },
			maxUnits = remaining,
		}
	elseif kind == "bulkbuy" then
		-- Part D. Poster wants `unitIn` of wantItemId per unit and pays out
		-- `payout` for each. Contributions must be whole multiples of unitIn,
		-- which falls out of counting in units rather than raw copies.
		local remaining = listing.remainingCount or 0
		local unitIn = listing.unitIn or 1
		if remaining <= 0 or unitIn < 1 or listing.wantItemId == nil then
			return nil
		end
		local payout = flatten(listing.payout)
		if next(payout) == nil then
			return nil
		end
		local units = math.floor(remaining / unitIn)
		if units < 1 then
			return nil
		end
		return {
			id = listing.id,
			posterId = posterId,
			kind = kind,
			createdAt = createdAt,
			give = payout,
			want = { [listing.wantItemId] = unitIn },
			maxUnits = units,
		}
	end
	return nil
end

--------------------------------------------------------------------------------
-- The balance check
--------------------------------------------------------------------------------

-- Net position of a chain: positive = surplus the group holds after everyone
-- is paid, negative = shortfall the group still needs.
function LiquidityCore.net(legs: { Leg }, units: { [string]: number }): { [string]: number }
	local acc = {}
	for _, leg in legs do
		local n = units[leg.id] or 0
		if n > 0 then
			scaledAdd(acc, leg.give, n)
			scaledAdd(acc, leg.want, -n)
		end
	end
	return acc
end

-- Everything the group still needs (the positive part of -net).
local function shortfallOf(net: { [string]: number }): ({ [string]: number }, boolean)
	local short, any = {}, false
	for k, n in net do
		if n < 0 then
			short[k] = -n
			any = true
		end
	end
	return short, any
end

-- Surplus left over once every want is covered (the positive part of net).
local function excessOf(net: { [string]: number }): ({ [string]: number }, boolean)
	local ex, any = {}, false
	for k, n in net do
		if n > 0 then
			ex[k] = n
			any = true
		end
	end
	return ex, any
end

LiquidityCore.shortfallOf = shortfallOf
LiquidityCore.excessOf = excessOf

-- feasible <=> nothing is short. This is the whole condition.
function LiquidityCore.feasible(legs: { Leg }, units: { [string]: number }): boolean
	local _, isShort = shortfallOf(LiquidityCore.net(legs, units))
	return not isShort
end

--------------------------------------------------------------------------------
-- Excess distribution
--------------------------------------------------------------------------------

-- Surplus has no owner: the giver already received their stated want, and the
-- bot may not keep it (that would be holding stock). So it may only go to a
-- participant who actually WANTED that item — strictly better for them, which
-- keeps the never-worsen-terms invariant intact. If nobody wants it, the
-- chain is rejected outright rather than leaving the bot holding a remainder.
function LiquidityCore.distributeExcess(
	legs: { Leg },
	units: { [string]: number },
	excess: { [string]: number }
): (boolean, { [string]: { [string]: number } })
	local bonus: { [string]: { [string]: number } } = {}
	for key, amount in excess do
		local taker: Leg? = nil
		for _, leg in legs do
			if (units[leg.id] or 0) > 0 and (leg.want[key] or 0) > 0 and not leg.npc then
				taker = leg
				break
			end
		end
		if taker == nil then
			return false, {} -- nobody wants it; bot will not absorb it
		end
		local t = taker :: Leg
		bonus[t.id] = bonus[t.id] or {}
		bonus[t.id][key] = (bonus[t.id][key] or 0) + amount
	end
	return true, bonus
end

--------------------------------------------------------------------------------
-- Greedy closure
--------------------------------------------------------------------------------

local function buildChain(legs: { Leg }, units: { [string]: number }): Chain?
	local net = LiquidityCore.net(legs, units)
	local _, isShort = shortfallOf(net)
	if isShort then
		return nil
	end
	local excess, hasExcess = excessOf(net)
	local bonus: { [string]: { [string]: number } } = {}
	if hasExcess then
		local ok, assigned = LiquidityCore.distributeExcess(legs, units, excess)
		if not ok then
			return nil
		end
		bonus = assigned
	end
	-- participants are the PLAYERS served; system legs are machinery
	local players = 0
	for _, leg in legs do
		if not leg.npc then
			players += 1
		end
	end
	return { legs = legs, units = units, bonus = bonus, participants = players }
end

-- Pick the unused listing covering the most of `need`, looking at either the
-- give side or the want side. `field` is "give" when we're short of something,
-- "want" when we have leftover that needs a home.
local function bestCandidate(
	pool: { Leg },
	units: { [string]: number },
	usedPoster: { [number]: boolean },
	need: { [string]: number },
	field: string
): (Leg?, number)
	local best: Leg? = nil
	local bestUnits, bestCover = 0, 0
	for _, cand in pool do
		if units[cand.id] == nil and not usedPoster[cand.posterId] then
			local side = (field == "give") and cand.give or cand.want
			local cover, needUnits = 0, 0
			for key, amount in need do
				local per = side[key] or 0
				if per > 0 then
					local u = math.min(math.ceil(amount / per), cand.maxUnits)
					needUnits = math.max(needUnits, u)
					cover += math.min(per * u, amount)
				end
			end
			if cover > bestCover then
				best, bestCover, bestUnits = cand, cover, math.max(1, needUnits)
			end
		end
	end
	return best, bestUnits
end

-- Grow a chain outward from one seed listing.
--
-- Deliberately NOT subset enumeration — choosing the subset is the expensive
-- part, so instead we close the gap greedily, in BOTH directions:
--
--   * short of something  -> pull in a listing that GIVES it
--   * leftover nobody in the chain wants -> pull in a listing that WANTS it
--
-- That second branch is what rescues chains which would otherwise be binned
-- for having an odd item left over (the bot may not keep it). Handling it
-- inside the same loop is simpler and strictly better than building the chain,
-- rejecting it, and trying to merge it with another one afterwards.
--
-- Terminates at maxParticipants. Being occasionally suboptimal costs a missed
-- match, never a wrong one.
function LiquidityCore.growFrom(pool: { Leg }, seed: Leg, opts: any): Chain?
	local maxParticipants = (opts and opts.maxParticipants) or 8
	local legs: { Leg } = { seed }
	local units: { [string]: number } = { [seed.id] = 1 }
	local usedPoster: { [number]: boolean } = { [seed.posterId] = true }

	for _ = 1, maxParticipants + 1 do
		local net = LiquidityCore.net(legs, units)
		local short, isShort = shortfallOf(net)

		local need, field
		if isShort then
			need, field = short, "give"
		else
			local excess, hasExcess = excessOf(net)
			if not hasExcess then
				return buildChain(legs, units) -- exact balance
			end
			local ok = LiquidityCore.distributeExcess(legs, units, excess)
			if ok then
				return buildChain(legs, units) -- leftover has a taker inside the chain
			end
			need, field = excess, "want" -- leftover needs a home: find someone who wants it
		end

		if #legs >= maxParticipants then
			return nil
		end
		local best, bestUnits = bestCandidate(pool, units, usedPoster, need, field)
		if best == nil then
			return nil
		end
		local b = best :: Leg
		table.insert(legs, b)
		units[b.id] = math.min(math.max(1, bestUnits), b.maxUnits)
		usedPoster[b.posterId] = true
	end

	return nil
end

--------------------------------------------------------------------------------
-- Implied orders (the gem bridge) — no separate code path
--------------------------------------------------------------------------------

-- A swap "gives A, wants B" is equivalent to `sell A for g` + `buy B for g`,
-- so it can be filled against gem-denominated listings even when no barter
-- mirror exists. That needs NO dedicated matcher: gems are just another key in
-- the balance check, so growFrom already pulls in a `sell` that supplies B and
-- then a `bulk` that pays the gems it needs. What `solve` adds is the RULES:
--
--   * `impliedEnabled = false` keeps gem legs out of the pool entirely, so the
--     LOW level only ever does pure barter chains.
--   * every chain must contain at least one swap. A sell+bulk pair with no swap
--     is the order book's job (crossTerms fires on post, at the maker's price)
--     — matching it here would only settle it at the wrong price.
--   * prices are only ever ones players posted; there is no valuation
--     fallback, since a derived price would make the bot a price-setter.

local function hasSwap(chain: Chain): boolean
	for _, leg in chain.legs do
		if leg.kind == "swap" then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Scoring
--------------------------------------------------------------------------------

-- Rank by PLAYERS SERVED and HOW LONG THEY WAITED — never by value extracted.
-- The churn problem isn't "too few trades", it's "my trade never filled", so
-- the oldest listings matter most. Larger chains are mildly penalised: every
-- extra leg is one more promise that might not be backed at settlement.
function LiquidityCore.score(chain: Chain, now: number, weights: any): number
	local w = weights or {}
	local wServed = w.served or 10
	local wAge = w.age or 0.01
	local wRisk = w.risk or 1

	local age = 0
	for _, leg in chain.legs do
		age += math.max(0, now - leg.createdAt)
	end
	return chain.participants * wServed + age * wAge - chain.participants * wRisk
end

--------------------------------------------------------------------------------
-- Top-level solve
--------------------------------------------------------------------------------

-- Seed from every listing, oldest first (stale-listing rescue), keep the
-- best-scoring disjoint chains. Legs are vertex-disjoint within a pass.
function LiquidityCore.solve(pool: { Leg }, now: number, opts: any): { Chain }
	local options = opts or {}
	local maxOps = options.maxOps or 3

	-- LOW never bridges through gems: drop sell/bulk legs so only barter remains.
	local usable = pool
	if not options.impliedEnabled then
		usable = {}
		for _, leg in pool do
			if leg.kind == "swap" then
				table.insert(usable, leg)
			end
		end
	end

	-- Only swaps seed a chain: they are the unfilled barter demand we exist to
	-- serve. Oldest first (stale-listing rescue).
	local seeds: { Leg } = {}
	for _, leg in usable do
		if leg.kind == "swap" then
			table.insert(seeds, leg)
		end
	end
	table.sort(seeds, function(x, y)
		return x.createdAt < y.createdAt
	end)

	-- Bound the pass: seeding is roughly seeds x participants x pool. Oldest
	-- seeds first, so what is skipped is only ever the freshest listings.
	local maxSeeds = options.maxSeeds or 40
	local candidates: { Chain } = {}
	for i, seed in seeds do
		if i > maxSeeds then
			break
		end
		local chain = LiquidityCore.growFrom(usable, seed, options)
		if chain and hasSwap(chain) then
			table.insert(candidates, chain)
		end
	end

	table.sort(candidates, function(x, y)
		return LiquidityCore.score(x, now, options.weights) > LiquidityCore.score(y, now, options.weights)
	end)

	local usedLeg: { [string]: boolean } = {}
	local chosen: { Chain } = {}
	for _, chain in candidates do
		local clash = false
		for _, leg in chain.legs do
			if usedLeg[leg.id] and not leg.npc then
				clash = true
				break
			end
		end
		if not clash then
			for _, leg in chain.legs do
				usedLeg[leg.id] = true
			end
			table.insert(chosen, chain)
			if #chosen >= maxOps then
				break
			end
		end
	end
	return chosen
end

return LiquidityCore
