--!strict
-- SimPlayerService: a population of believable simulated players (DEV/TEST).
--
-- Not market makers — people. Each agent belongs to a segment (new player,
-- collector, flipper...), holds its own PRIVATE value beliefs (so two agents
-- honestly disagree about whether a trade is a win), wants different things,
-- acts at random moments, and gives up and leaves when its trades stall. That
-- disagreement + impatience is what makes unfillable demand exist at all, which
-- is the problem the liquidity facilitator is meant to solve.
--
-- Everything goes through the same entry points real bots already use:
-- TradeBoardService.bot* for the board, RollService/StoreService/CraftingService
-- .bot* for the NPCs, and BotService's in-memory ledger for inventories. Unique
-- crafts are per-player and a bot can never hold one, so they're out of scope.
--
-- Runs on BotService's leader-elected sweep (registerSweepHook), so exactly one
-- server ever drives the population.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SimPlayerConfig = require(ReplicatedStorage.Shared.Config.SimPlayerConfig)
local RollConfig = require(ReplicatedStorage.Shared.Config.RollConfig)

local BotService = require(script.Parent.BotService)
local TradeBoardService = require(script.Parent.TradeBoardService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local SimPlayerService = {}

type Agent = {
	id: number,
	index: number,
	name: string,
	seg: any,
	rng: Random,
	activity: number, -- actions per minute while online
	beliefs: { [string]: number },
	goals: { string },
	nextAt: number,
	onlineUntil: number,
	offlineUntil: number,
	frustration: number,
	listings: { [string]: number }, -- listingId -> giveUpAt (sim time)
	seeded: boolean,
	rolls: number,
	deals: number,
	wealth: number, -- multiplier on stock and gems; heavy-tailed on purpose
}

local agents: { Agent } = {}
local enabled = false
local catalog: { { id: string, val: number } } = {}
local ticket = 0
local hot: { string } = {} -- the few items everyone is chasing

local funnel: { [string]: number } = {} -- attempts/ok per action, swap failure reasons
local function bump(key: string)
	funnel[key] = (funnel[key] or 0) + 1
end
local stats = { posted = 0, filled = 0, expired = 0, accepted = 0, rolls = 0, store = 0, crafts = 0, actions = 0, left = 0 }

local FIRST = { "Ada", "Brutus", "Cleo", "Dot", "Edgar", "Fern", "Gus", "Hazel", "Igor", "June", "Kai", "Lena" }
local LAST = { "Byte", "Copper", "Drift", "Ember", "Flux", "Gale", "Ash", "Pip", "Quill", "Sable", "Thorn", "Vale" }

--------------------------------------------------------------------------------
-- Random helpers (every agent owns its own Random, so behaviour is independent)
--------------------------------------------------------------------------------

local function exponential(rng: Random, mean: number): number
	return -mean * math.log(1 - rng:NextNumber() * 0.999999)
end

local function normal(rng: Random): number
	local u1, u2 = math.max(rng:NextNumber(), 1e-9), rng:NextNumber()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local function lognormal(rng: Random, sigma: number): number
	return math.exp(sigma * normal(rng))
end

local function hashStr(s: string): number
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + s:byte(i)) % 2147483647
	end
	return h
end

local function pickWeighted(rng: Random, weights: { [string]: number }, allowed: { [string]: boolean }): string?
	local total = 0
	for k, w in weights do
		if allowed[k] then
			total += w
		end
	end
	if total <= 0 then
		return nil
	end
	local r = rng:NextNumber() * total
	for k, w in weights do
		if allowed[k] then
			r -= w
			if r <= 0 then
				return k
			end
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Beliefs
--------------------------------------------------------------------------------

-- What THIS agent thinks an item is worth: the real value distorted by a
-- factor fixed per (agent, item). Two agents looking at one trade can both be
-- "right" that it's a win, which is exactly what a real Roblox trading server
-- is like — there is no in-game price, only rival opinions.
local function belief(a: Agent, itemId: string): number
	local f = a.beliefs[itemId]
	if f == nil then
		f = lognormal(Random.new(a.index * 7919 + hashStr(itemId)), a.seg.sigma)
		a.beliefs[itemId] = f
	end
	return math.max(1, EconomyService.valueOf(itemId) * f)
end

local function bundleBelief(a: Agent, items: { [string]: number }, gems: number): number
	local v = gems
	for itemId, n in items do
		v += belief(a, itemId) * n
	end
	return v
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

local function buildCatalog()
	-- EconomyService.valueOf reads through to a synchronous GetAsync on a cold
	-- cache; calling it for ~290 items in a tight loop before the background
	-- warm pass has filled hotCache is what threw a DataStore GetAsync storm
	-- (StandardReadExperienceThrottled) the moment the liquidity button first
	-- enabled the population. Wait for the warm cache -- it's a one-time,
	-- background pass anyway -- so every read here is a free in-memory hit.
	if not EconomyService.isWarm() then
		local waited = 0
		while not EconomyService.isWarm() and waited < 30 do
			task.wait(1)
			waited += 1
		end
	end
	catalog = {}
	for _, itemId in EconomyService.allItemIds() do
		local item = EconomyService.getItem(itemId)
		if item and (item.assignmentWeight or 0) > 0 then
			table.insert(catalog, { id = itemId, val = EconomyService.valueOf(itemId) })
		end
	end
	table.sort(catalog, function(x, y)
		return x.val < y.val
	end)
	-- Real markets trade a few dozen popular items, not the whole catalogue.
	-- With ~290 items and a few hundred listings each item had one or two, so no
	-- give was anyone else's want and no chain could ever close. Keep an evenly
	-- spaced slice of the value range so every price tier is still represented.
	local universe = SimPlayerConfig.Universe
	if universe and #catalog > universe then
		local slice = {}
		for i = 1, universe do
			table.insert(slice, catalog[math.max(1, math.floor(i * #catalog / universe))])
		end
		catalog = slice
	end
	-- Real trading concentrates on a handful of hot items rather than spreading
	-- demand evenly over the whole catalogue. Without this every want was
	-- effectively unique, so no agent's want was anyone else's give and nothing
	-- could ever balance. Fixed seed: the same items stay hot across toggles.
	hot = {}
	local hr = Random.new(20260920)
	for _ = 1, math.min(SimPlayerConfig.HotItems, #catalog) do
		table.insert(hot, catalog[hr:NextInteger(1, #catalog)].id)
	end
end

-- Items whose value sits near `target`, so a swap asks for something roughly
-- comparable rather than always reaching for the single most valuable item.
local function nearValue(rng: Random, target: number, exclude: { [string]: boolean }): string?
	local n = #catalog
	if n == 0 then
		return nil
	end
	local lo, hi = 1, n
	while lo < hi do
		local mid = (lo + hi) // 2
		if catalog[mid].val < target then
			lo = mid + 1
		else
			hi = mid
		end
	end
	for _ = 1, 8 do
		local pick = catalog[math.clamp(lo + rng:NextInteger(-4, 4), 1, n)]
		if not exclude[pick.id] then
			return pick.id
		end
	end
	return nil
end

local function segmentFor(i: number): any
	-- exact percentage split, interleaved by a co-prime stride
	local bucket = ((i * 37) % 100) + 1
	local acc = 0
	for _, seg in SimPlayerConfig.Segments do
		acc += seg.pct
		if bucket <= acc then
			return seg
		end
	end
	return SimPlayerConfig.Segments[1]
end

local function newAgent(i: number, now: number): Agent
	local seg = segmentFor(i)
	local rng = Random.new(i * 104729 + 17)
	local a: Agent = {
		id = SimPlayerConfig.IdBase - i,
		index = i,
		name = ("%s %s [sim]"):format(FIRST[((i - 1) % #FIRST) + 1], LAST[(math.floor((i - 1) / #FIRST) % #LAST) + 1]),
		seg = seg,
		rng = rng,
		activity = seg.activity * lognormal(rng, 0.5) * SimPlayerConfig.TimeScale,
		beliefs = {},
		goals = {},
		nextAt = now + rng:NextNumber() * 30, -- staggered: nobody wakes on the same tick
		onlineUntil = now + exponential(rng, seg.session * 60 / SimPlayerConfig.TimeScale),
		offlineUntil = 0,
		frustration = 0,
		listings = {},
		seeded = false,
		rolls = 0,
		deals = 0,
		-- Real economies are top-heavy: a few players hold most of the value.
		-- Lognormal wealth is what produces that shape (Gini ~0.6-0.8).
		wealth = lognormal(rng, 0.9),
	}
	-- collection goals skew toward the rare end of the catalogue
	for _ = 1, seg.goals do
		if #catalog > 0 then
			local u = rng:NextNumber()
			local idx = math.clamp(#catalog - math.floor(#catalog * u * u), 1, #catalog)
			table.insert(a.goals, catalog[idx].id)
		end
	end
	return a
end

local function seedAgent(a: Agent)
	a.seeded = true
	local seg = a.seg
	BotService.credit(a.id, {}, math.floor(a.rng:NextInteger(seg.gems[1], seg.gems[2]) * a.wealth), "sim_seed_gems_" .. a.id)
	local want = math.clamp(math.floor(a.rng:NextInteger(seg.inv[1], seg.inv[2]) * a.wealth), 1, 250)
	-- serious collectors chase the valuable end of the catalogue
	local rich = seg.goals >= 2
	local held: { [string]: number } = {}
	for _ = 1, want do
		local u = a.rng:NextNumber()
		if rich then
			u = u ^ 0.5
		end
		local pick = catalog[math.clamp(math.ceil(u * #catalog), 1, math.max(1, #catalog))]
		if #hot > 0 and a.rng:NextNumber() < SimPlayerConfig.HotShare then
			local hid = hot[a.rng:NextInteger(1, #hot)]
			for _, c in catalog do
				if c.id == hid then
					pick = c
					break
				end
			end
		end
		-- new players skew toward cheap items, collectors toward everything
		if pick and (seg.id ~= "new" or a.rng:NextNumber() < 0.5 or pick.val < 200) then
			if EconomyService.reserveOneBotLocal(pick.id) then
				held[pick.id] = (held[pick.id] or 0) + 1
			end
		end
	end
	BotService.credit(a.id, held, 0, "sim_seed_items_" .. a.id)
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local function heldSpare(a: Agent): { string }
	local out = {}
	local isGoal = {}
	for _, g in a.goals do
		isGoal[g] = true
	end
	for itemId, n in BotService.inventoryOf(a.id) do
		if n > 0 and not isGoal[itemId] then
			table.insert(out, itemId)
		end
	end
	return out
end

local function track(a: Agent, listingId: string, now: number)
	local patience = a.seg.patience * 60 / SimPlayerConfig.TimeScale
	a.listings[listingId] = now + exponential(a.rng, patience)
	stats.posted += 1
end

local function openCount(a: Agent): number
	local n = 0
	for _ in a.listings do
		n += 1
	end
	return n
end

-- Items that are inputs to a currently-active recipe whose output is worth
-- clearly more than its inputs. An agent that wants one of these has an
-- IMMEDIATE, profitable use for it, which is the one reason it may overpay by
-- more than the usual margin. Cached: recipes rotate on a scale of minutes.
local urgentCache: { [string]: number } = {}
local urgentAt = 0
local function urgentInputs(): { [string]: number }
	local now = os.time()
	if now - urgentAt < 30 then
		return urgentCache
	end
	urgentAt = now
	urgentCache = {}
	local CraftingService = require(script.Parent.CraftingService) :: any
	for _, event in CraftingService.activeEvents(now) do
		for _, recipe in event.recipes do
			local cost = recipe.gems or 0
			for id, n in recipe.inputs do
				cost += EconomyService.valueOf(id) * n
			end
			local outVal = EconomyService.valueOf(CraftingService.recipeOutputId(recipe))
			if outVal >= cost * 1.15 then
				local profit = outVal / math.max(cost, 1)
				for id in recipe.inputs do
					urgentCache[id] = math.max(urgentCache[id] or 0, profit)
				end
			end
		end
	end
	return urgentCache
end

-- Build the give side of a swap: spare items whose believed worth adds up to
-- about `target`, never blowing far past it, plus at most a small gem top-up.
-- Returns nil when this agent simply cannot make a sane offer for that want.
local function buildGive(a: Agent, spare: { string }, target: number): ({ [string]: number }?, number)
	local inv = BotService.inventoryOf(a.id)
	local cands: { { id: string, val: number } } = {}
	for _, id in spare do
		local v = belief(a, id)
		if v <= target * 1.12 then
			table.insert(cands, { id = id, val = v })
		end
	end
	table.sort(cands, function(x, y)
		return x.val > y.val
	end)
	-- Most real ads are ONE kind of thing for one thing. Two give-kinds plus a
	-- gem sweetener per ad means every chain has more kinds to place than
	-- anyone wants, so nothing can ever balance. Prefer a single kind whose
	-- copies land within the honest band, and no sweetener.
	if a.rng:NextNumber() < 0.8 then
		local bestId: string? = nil
		local bestK, bestErr = 0, math.huge
		for _, c in cands do
			for k = 1, math.min(inv[c.id] or 0, 3) do
				local v = c.val * k
				if v >= target * 0.85 and v <= target * 1.12 and math.abs(v - target) < bestErr then
					bestId, bestK, bestErr = c.id, k, math.abs(v - target)
				end
			end
		end
		if bestId then
			return { [bestId] = bestK }, 0
		end
	end
	local give: { [string]: number } = {}
	local total, n, distinct = 0, 0, 0
	for _, c in cands do
		-- Real offers are mostly one or two kinds of thing. Long mixed bundles
		-- can never line up with anyone else's want, so cap the variety.
		if distinct >= 2 then
			break
		end
		if total >= target * 0.85 then
			break
		end
		local added = false
		for _ = 1, math.min(inv[c.id] or 0, 3) do
			if total + c.val > target * 1.12 or n >= 4 then
				break
			end
			give[c.id] = (give[c.id] or 0) + 1
			total += c.val
			n += 1
			added = true
		end
		if added then
			distinct += 1
		end
	end
	if n == 0 then
		return nil, 0
	end
	-- gems are a sweetener, not the payment: capped at 20% of the ask
	local gems = 0
	if total < target then
		gems = math.min(math.ceil(target - total), BotService.gemsOf(a.id), math.ceil(target * 0.2))
	end
	if total + gems < target * 0.85 then
		return nil, 0 -- too far short to be an honest offer
	end
	return give, gems
end

local function actSwap(a: Agent, now: number): boolean
	local spare = heldSpare(a)
	if #spare == 0 then
		bump("swap_fail_nospare")
		return false
	end
	-- Pick the WANT first, then build a give side worth about that much. The
	-- other way round (random give, random want) produced offers like "two items
	-- for something worth 1/29th of them" and "one item plus 800 gems".
	-- LIQUID wants first (hot/near-value: plenty of people hold spare copies),
	-- goals LAST. Goals skew toward the rare/expensive end of the catalogue by
	-- design (collectors chase scarce stuff) -- almost nobody holds a spare
	-- copy of something scarce, so a goal-first order meant most swap attempts
	-- fixated on an item structurally unmatchable, and connectivity cratered as
	-- goal-driven swaps piled up. Goal-chasing still happens, just not first.
	local wants: { string } = {}
	if #hot > 0 and a.rng:NextNumber() < SimPlayerConfig.HotShare then
		table.insert(wants, hot[a.rng:NextInteger(1, #hot)])
	end
	local anchor = spare[a.rng:NextInteger(1, #spare)]
	local near = nearValue(a.rng, belief(a, anchor) * (0.8 + a.rng:NextNumber() * 0.6), { [anchor] = true })
	if near then
		table.insert(wants, near) -- always a comparable fallback
	end
	if #a.goals > 0 and a.rng:NextNumber() < 0.6 then
		table.insert(wants, a.goals[a.rng:NextInteger(1, #a.goals)])
	end

	for _, wantId in wants do
		local held = BotService.inventoryOf(a.id)[wantId] or 0
		if held == 0 then
			local wantVal = belief(a, wantId)
			local count = wantVal < 40 and 2 or 1
			-- agents that demand a margin ask for more; eager ones overpay a bit
			local target = wantVal * count * math.clamp(1 / a.seg.accept, 0.9, 1.08)
			local give, gems = buildGive(a, spare, target)
			-- Beliefs may be wrong (that's the point of private beliefs), but never
			-- absurd: even a clueless new player doesn't hand over five times what
			-- they ask for. Check the offer against TRUE values before posting.
			local sane = false
			if give and not give[wantId] then
				local trueGive, trueWant = gems, EconomyService.valueOf(wantId) * count
				for id, n in give do
					trueGive += EconomyService.valueOf(id) * n
				end
				local ratio = trueGive / math.max(trueWant, 1)
				-- At most ~10% more than the item is worth. The exception is an
				-- item with an immediate profitable use (a recipe input whose
				-- output is worth more): then it may pay up to most of that
				-- profit, capped, because it will earn it straight back.
				local maxRatio = 1.10
				local profit = urgentInputs()[wantId]
				if profit then
					maxRatio = math.min(1.10 + (profit - 1) * 0.6, 1.5)
				end
				sane = ratio >= 0.8 and ratio <= maxRatio
			end
			if not give then
				bump("swap_fail_unbuildable")
			elseif not sane then
				bump("swap_fail_insane")
			end
			if give and sane then
				local res = TradeBoardService.botPost(a.id, a.name, {
					kind = "swap",
					give = { items = give, gems = gems },
					want = { items = { [wantId] = count }, gems = 0 },
					autoTrade = true, -- sims never ask first: every swap fills on its own
				})
				if res.ok and res.id then
					track(a, res.id, now)
					return true
				end
				bump("swap_fail_post_" .. tostring(res.err))
			end
		else
			bump("swap_fail_alreadyheld")
		end
	end
	return false
end

local function actSell(a: Agent, now: number): boolean
	local spare = heldSpare(a)
	if #spare == 0 then
		return false
	end
	local id = spare[a.rng:NextInteger(1, #spare)]
	local have = BotService.inventoryOf(a.id)[id] or 0
	local markup = a.seg.id == "lawyer" and 0 or a.rng:NextNumber() * 0.3
	local price = math.max(1, math.floor(belief(a, id) * (1 + markup)))
	local res = TradeBoardService.botPost(a.id, a.name, {
		kind = "sell",
		itemId = id,
		count = a.rng:NextInteger(1, math.max(1, math.min(have, 3))),
		gemsPerCopy = price,
	})
	if res.ok and res.id then
		track(a, res.id, now)
		return true
	end
	return false
end

local function actBulk(a: Agent, now: number): boolean
	local id: string?
	if #a.goals > 0 and a.rng:NextNumber() < 0.7 then
		id = a.goals[a.rng:NextInteger(1, #a.goals)]
	elseif #hot > 0 and a.rng:NextNumber() < SimPlayerConfig.HotShare then
		id = hot[a.rng:NextInteger(1, #hot)]
	elseif #catalog > 0 then
		id = catalog[a.rng:NextInteger(1, #catalog)].id
	end
	if id == nil then
		return false
	end
	local count = a.rng:NextInteger(1, 5)
	local per = math.max(1, math.floor(belief(a, id) * (0.8 + a.rng:NextNumber() * 0.2)))
	local total = per * count
	if total > BotService.gemsOf(a.id) then
		return false
	end
	local res = TradeBoardService.botPost(a.id, a.name, { kind = "bulk", itemId = id, count = count, gems = total })
	if res.ok and res.id then
		track(a, res.id, now)
		return true
	end
	return false
end

-- Bulk Buy: a standing item-for-item order. The payout is what the agent can
-- actually spare, priced against TRUE value and never more than 8% above the
-- wanted copies' true value (the same overpay ceiling swaps obey).
local function actBulkBuyPost(a: Agent, now: number): boolean
	local id: string?
	if #a.goals > 0 and a.rng:NextNumber() < 0.7 then
		id = a.goals[a.rng:NextInteger(1, #a.goals)]
	elseif #hot > 0 and a.rng:NextNumber() < SimPlayerConfig.HotShare then
		id = hot[a.rng:NextInteger(1, #hot)]
	elseif #catalog > 0 then
		id = catalog[a.rng:NextInteger(1, #catalog)].id
	end
	if id == nil then
		return false
	end
	local unitIn = a.rng:NextInteger(1, 3)
	local units = a.rng:NextInteger(2, 8)
	local target = EconomyService.valueOf(id) * unitIn * (1 + a.rng:NextNumber() * 0.08)
	local inv = BotService.inventoryOf(a.id)
	local payItems: { [string]: number } = {}
	local paid = 0
	local spare = heldSpare(a)
	if #spare > 0 and a.rng:NextNumber() < 0.7 then
		local s = spare[a.rng:NextInteger(1, #spare)]
		if s ~= id then
			local v = EconomyService.valueOf(s)
			local n = math.floor(target / v)
			if n >= 1 and (inv[s] or 0) >= n * units then
				payItems[s] = n
				paid = n * v
			end
		end
	end
	local gems = math.max(0, math.floor(target - paid + 0.5))
	if next(payItems) == nil and gems < 1 then
		return false
	end
	if gems * units > BotService.gemsOf(a.id) then
		return false
	end
	local res = TradeBoardService.botPost(a.id, a.name, {
		kind = "bulkbuy",
		itemId = id,
		count = units * unitIn,
		unitIn = unitIn,
		payout = { items = payItems, gems = gems > 0 and gems or nil },
	})
	if res.ok and res.id then
		track(a, res.id, now)
		return true
	end
	return false
end

-- Fill part of someone's Bulk Buy if OUR beliefs say the payout beats the copies.
local function actContributeBB(a: Agent, listings: { any }): boolean
	local inv = BotService.inventoryOf(a.id)
	local isGoal = {}
	for _, g in a.goals do
		isGoal[g] = true
	end
	local start = a.rng:NextInteger(1, math.max(1, #listings))
	for step = 0, math.min(#listings, 40) - 1 do
		local l = listings[((start + step - 1) % #listings) + 1]
		if l.kind == "bulkbuy" and l.posterId ~= a.id and l.status == "open" and not isGoal[l.wantItemId] then
			local held = inv[l.wantItemId] or 0
			if held >= l.unitIn then
				local gain = bundleBelief(a, l.payout.items, l.payout.gems or 0)
				local cost = belief(a, l.wantItemId) * l.unitIn
				if gain >= cost * a.seg.accept then
					local units = math.min(a.rng:NextInteger(1, 3), held // l.unitIn, l.remainingCount // l.unitIn)
					if units >= 1 then
						local res = TradeBoardService.botContributeBulkBuy(a.id, a.name, l.id, units)
						if res.ok then
							stats.accepted += 1
							a.deals += 1
							bump("ok_bulkbuy_fill")
							return true
						end
					end
				end
			end
		end
	end
	return false
end

-- Take someone else's open swap if OUR beliefs say it's a good deal.
local function actAccept(a: Agent, listings: { any }): boolean
	local inv = BotService.inventoryOf(a.id)
	local start = a.rng:NextInteger(1, math.max(1, #listings))
	for step = 0, math.min(#listings, 40) - 1 do
		local l = listings[((start + step - 1) % #listings) + 1]
		if l.kind == "swap" and l.autoTrade and l.posterId ~= a.id and l.status == "open" then
			local canPay = true
			for itemId, n in l.want.items do
				if (inv[itemId] or 0) < n then
					canPay = false
					break
				end
			end
			if canPay and (l.want.gems or 0) <= BotService.gemsOf(a.id) then
				local gain = bundleBelief(a, l.give.items, l.give.gems or 0)
				local cost = bundleBelief(a, l.want.items, l.want.gems or 0)
				if gain >= cost * a.seg.accept then
					local res = TradeBoardService.botAccept(a.id, a.name, l.id)
					if res.ok then
						stats.accepted += 1
						a.deals += 1
						return true
					end
				end
			end
		end
	end
	return false
end

local function actBuy(a: Agent, listings: { any }): boolean
	local gems = BotService.gemsOf(a.id)
	local start = a.rng:NextInteger(1, math.max(1, #listings))
	for step = 0, math.min(#listings, 40) - 1 do
		local l = listings[((start + step - 1) % #listings) + 1]
		if l.kind == "sell" and l.posterId ~= a.id and l.status == "open" and l.gemsPerCopy <= gems then
			if l.gemsPerCopy <= belief(a, l.itemId) * (2 - a.seg.accept) then
				local res = TradeBoardService.botBuy(a.id, a.name, l.id, 1)
				if res.ok then
					stats.accepted += 1
					a.deals += 1
					return true
				end
			end
		end
	end
	return false
end

local function actRoll(a: Agent): boolean
	if not RollConfig.Enabled then
		return false
	end
	local gems = BotService.gemsOf(a.id)
	local affordable = {}
	for _, tier in RollConfig.Tiers do
		if tier.gems <= gems then
			table.insert(affordable, tier)
		end
	end
	if #affordable == 0 then
		return false
	end
	local RollService = require(script.Parent.RollService) :: any
	local tier = affordable[a.rng:NextInteger(1, #affordable)]
	a.rolls += 1
	ticket += 1
	local res = RollService.botRoll(a.id, tier.id, a.index * 7919 + a.rolls * 104729 + ticket)
	if res.ok then
		stats.rolls += 1
		return true
	end
	return false
end

local function actStore(a: Agent): boolean
	local StoreService = require(script.Parent.StoreService) :: any
	local gems = BotService.gemsOf(a.id)
	local shelf = StoreService.shelfForBots()
	local options = {}
	for _, s in shelf do
		if s.price <= gems then
			table.insert(options, s)
		end
	end
	if #options == 0 then
		return false
	end
	local pick = options[a.rng:NextInteger(1, #options)]
	local res = StoreService.botBuy(a.id, pick.itemId)
	if res.ok then
		stats.store += 1
		return true
	end
	return false
end

local function actCraft(a: Agent, now: number): boolean
	local CraftingService = require(script.Parent.CraftingService) :: any
	local inv = BotService.inventoryOf(a.id)
	local gems = BotService.gemsOf(a.id)
	for _, event in CraftingService.activeEvents(now) do
		for _, recipe in event.recipes do
			local ok = (recipe.gems or 0) <= gems
			for itemId, n in recipe.inputs do
				if (inv[itemId] or 0) < n then
					ok = false
					break
				end
			end
			if ok and a.rng:NextNumber() < 0.5 then
				local res = CraftingService.botCraft(a.id, event.id, recipe.rid)
				if res.ok then
					stats.crafts += 1
					return true
				end
			end
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Patience: post, wait, give up, maybe leave
--------------------------------------------------------------------------------

local function reviewListings(a: Agent, openIds: { [string]: boolean }, now: number)
	for id, giveUpAt in a.listings do
		if not openIds[id] then
			-- gone from the board before its deadline: someone took it
			a.listings[id] = nil
			stats.filled += 1
			a.deals += 1
			a.frustration = math.max(0, a.frustration - 0.5)
		elseif now >= giveUpAt then
			TradeBoardService.botCancel(a.id, id)
			a.listings[id] = nil
			stats.expired += 1
			a.frustration += 1
			-- unsatisfied players leave sooner, and stay away longer
			local hazard = 0.15 * (1 + 0.5 * a.frustration)
			if a.rng:NextNumber() < hazard then
				a.onlineUntil = now
				a.offlineUntil = now
					+ exponential(a.rng, a.seg.offline * 60 / SimPlayerConfig.TimeScale * (1 + a.frustration))
				stats.left += 1
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Tick (runs on the leader's sweep)
--------------------------------------------------------------------------------

local lastShapeAt = 0
local tickOffset = 0
local function gini(vals: { number }): number
	table.sort(vals)
	local n, sum, cum = #vals, 0, 0
	for _, v in vals do
		sum += v
	end
	if n == 0 or sum == 0 then
		return 0
	end
	for i, v in vals do
		cum += (2 * i - n - 1) * v
	end
	return cum / (n * sum)
end

local function publishShape(now: number)
	local worth, deals, online = {}, {}, 0
	for _, a in agents do
		local v = BotService.gemsOf(a.id)
		for id, n in BotService.inventoryOf(a.id) do
			v += EconomyService.valueOf(id) * n
		end
		table.insert(worth, v)
		table.insert(deals, a.deals)
		if now < a.onlineUntil and now >= a.offlineUntil then
			online += 1
		end
	end
	local total = 0
	for _, v in worth do
		total += v
	end
	table.sort(worth, function(x, y)
		return x > y
	end)
	local top = 0
	for i = 1, math.max(1, #worth // 10) do
		top += worth[i] or 0
	end
	table.sort(deals)
	ReplicatedStorage:SetAttribute("SimGini", math.floor(gini(table.clone(worth)) * 100))
	ReplicatedStorage:SetAttribute("SimTop10Pct", total > 0 and math.floor(top / total * 100) or 0)
	ReplicatedStorage:SetAttribute("SimMedianDeals", deals[math.max(1, #deals // 2)] or 0)
	ReplicatedStorage:SetAttribute("SimOnline", online)
	local parts = {}
	for k, v in funnel do
		table.insert(parts, k .. "=" .. v)
	end
	table.sort(parts)
	ReplicatedStorage:SetAttribute("SimFunnel", table.concat(parts, " "))
end

local function publish()
	ReplicatedStorage:SetAttribute("SimAgents", #agents)
	ReplicatedStorage:SetAttribute("SimPosted", stats.posted)
	ReplicatedStorage:SetAttribute("SimFilled", stats.filled)
	ReplicatedStorage:SetAttribute("SimExpired", stats.expired)
	ReplicatedStorage:SetAttribute("SimAccepted", stats.accepted)
	ReplicatedStorage:SetAttribute("SimRolls", stats.rolls)
	ReplicatedStorage:SetAttribute("SimStore", stats.store)
	ReplicatedStorage:SetAttribute("SimCrafts", stats.crafts)
	ReplicatedStorage:SetAttribute("SimLeft", stats.left)
end

local function tick(_: number)
	if not enabled then
		return
	end
	-- Waking an unseeded agent calls seedAgent -> EconomyService.reserveOneBotLocal
	-- per item, which reads through to a synchronous GetAsync on a cold record.
	-- 450 agents waking within their first ~30s, each seeding up to 250 items,
	-- is exactly what threw the GetAsync storm -- hold every agent unseeded/
	-- un-ticked until the background warm pass has cached the whole catalogue.
	if not EconomyService.isWarm() then
		return
	end
	local now = os.clock()
	local listings = TradeBoardService.rawOpenListings()
	local openIds: { [string]: boolean } = {}
	for _, l in listings do
		openIds[l.id] = true
	end

	-- Bounded by TIME, not a fixed action count: a count that suits 50 agents
	-- starves 450 (activity stopped scaling with population). The start index
	-- rotates so a tick that runs out of time never favours the same agents.
	local budget = SimPlayerConfig.MaxActionsPerTick
	local t0 = os.clock()
	local n = #agents
	tickOffset = (tickOffset + 37) % math.max(n, 1)
	for k = 0, n - 1 do
		if os.clock() - t0 > SimPlayerConfig.TickBudgetSeconds then
			bump("tick_budget_hit")
			break
		end
		local a = agents[((k + tickOffset) % n) + 1]
		if not a.seeded then
			seedAgent(a)
		end
		if a.listings and next(a.listings) ~= nil then
			reviewListings(a, openIds, now)
		end
		-- session model: online for a while, then away for a while
		if now >= a.onlineUntil and now >= a.offlineUntil then
			if a.offlineUntil <= a.onlineUntil then
				a.offlineUntil = now + exponential(a.rng, a.seg.offline * 60 / SimPlayerConfig.TimeScale)
			else
				a.onlineUntil = now + exponential(a.rng, a.seg.session * 60 / SimPlayerConfig.TimeScale)
			end
		end
		local online = now < a.onlineUntil and now >= a.offlineUntil
		if online and budget > 0 and now >= a.nextAt then
			a.nextAt = now + exponential(a.rng, 60 / math.max(a.activity, 0.01))

			local allowed = {
				swap = openCount(a) < SimPlayerConfig.ListingCap,
				sell = openCount(a) < SimPlayerConfig.ListingCap,
				bulk = openCount(a) < SimPlayerConfig.ListingCap,
				accept = true,
				buy = true,
				roll = true,
				store = true,
				craft = true,
			}
			local action = pickWeighted(a.rng, a.seg.weights, allowed)
			local done = false
			if action then
				bump("try_" .. action)
			end
			if action == "swap" then
				done = actSwap(a, now)
			elseif action == "sell" then
				done = actSell(a, now)
			elseif action == "bulk" then
				if a.rng:NextNumber() < 0.4 then
					done = actBulkBuyPost(a, now)
					if done then
						bump("ok_bulkbuy_post")
					end
				else
					done = actBulk(a, now)
				end
			elseif action == "accept" then
				done = actAccept(a, listings) or actContributeBB(a, listings)
			elseif action == "buy" then
				done = actBuy(a, listings)
			elseif action == "roll" then
				done = actRoll(a)
			elseif action == "store" then
				done = actStore(a)
			elseif action == "craft" then
				done = actCraft(a, os.time())
			end
			if done then
				budget -= 1
				stats.actions += 1
				bump("ok_" .. (action :: string))
			end
		end
	end
	publish()
	if now - lastShapeAt > 5 then
		lastShapeAt = now
		publishShape(now)
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function SimPlayerService.setEnabled(on: boolean)
	if on == enabled then
		return
	end
	enabled = on and SimPlayerConfig.Enabled
	if enabled then
		if #catalog == 0 then
			task.spawn(buildCatalog) -- may wait on warmCache; must not block the caller
		end
		if #agents == 0 then
			local now = os.clock()
			for i = 1, SimPlayerConfig.Count do
				table.insert(agents, newAgent(i, now))
			end
		end
	else
		-- switching off pulls every sim listing so the board isn't left showing
		-- offers nobody is servicing
		for _, a in agents do
			for id in a.listings do
				TradeBoardService.botCancel(a.id, id)
			end
			a.listings = {}
		end
	end
	AnalyticsService.log("sim_players", { enabled = enabled, agents = #agents })
end

function SimPlayerService.isEnabled(): boolean
	return enabled
end

-- Exposed for tests: the segment mix actually produced for a population size.
function SimPlayerService.segmentCounts(n: number): { [string]: number }
	local out: { [string]: number } = {}
	for i = 1, n do
		local id = segmentFor(i).id
		out[id] = (out[id] or 0) + 1
	end
	return out
end

function SimPlayerService.Init() end

function SimPlayerService.Start()
	BotService.registerSweepHook(tick)
end

return SimPlayerService
