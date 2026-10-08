--!strict
-- LiquidityService: IO shell for the chain-trade facilitator.
--
-- Phase 2 scope: level state + the admin-gated remote that sets it. The solve
-- loop lands in Phase 3 (dry-run first). The level lives in module state, NOT
-- by mutating the shared config, so the debug button can change it at runtime
-- without a server restart.
--
-- Any level other than OFF also switches the bot population on (per the
-- debug-button rule); OFF switches it off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
local LiquidityConfig = require(ReplicatedStorage.Shared.Config.LiquidityConfig)

local Net = require(script.Parent.Parent.Net)
local AnalyticsService = require(script.Parent.AnalyticsService)
local BotService = require(script.Parent.BotService)
local SimPlayerService = require(script.Parent.SimPlayerService)

local Core = require(script.Parent.LiquidityCore)
local TradeBoardService = require(script.Parent.TradeBoardService)

local LiquidityService = {}

local level = "OFF"

-- counters, mirrored onto ReplicatedStorage so they stay readable when the
-- console buffer has evicted the log lines (and from outside this module's
-- own require cache, which tooling can't see into)
local stats = { passes = 0, chains = 0, participants = 0, lastLegs = 0, lastChains = 0, npcChains = 0 }
local lastPassAt = 0

local function publishStats()
	ReplicatedStorage:SetAttribute("LiqPasses", stats.passes)
	ReplicatedStorage:SetAttribute("LiqChains", stats.chains)
	ReplicatedStorage:SetAttribute("LiqNpcChains", stats.npcChains)
	ReplicatedStorage:SetAttribute("LiqParticipants", stats.participants)
	ReplicatedStorage:SetAttribute("LiqLegsLast", stats.lastLegs)
	ReplicatedStorage:SetAttribute("LiqChainsLast", stats.lastChains)
end

-- Solve over legs the caller already normalised. Sorts and caps IN PLACE, so
-- anything that needs the full set must read it first.
function LiquidityService.solveLegs(legs: { any }, now: number, dials: any, npc: { any }?): ({ any }, number)
	-- oldest first, then cap: the longest-waiting listings are the ones worth
	-- rescuing, and it bounds the pass cost regardless of board size
	table.sort(legs, function(a, b)
		return a.createdAt < b.createdAt
	end)
	local cap = LiquidityConfig.MaxLegs
	if #legs > cap then
		for i = #legs, cap + 1, -1 do
			legs[i] = nil
		end
	end
	local count = #legs
	-- System legs join AFTER the cap so they never crowd out player listings,
	-- and only where gem/item bridging is allowed (never at LOW).
	if npc and dials.impliedEnabled then
		for _, leg in npc do
			table.insert(legs, leg)
		end
	end
	return Core.solve(legs, now, dials), count
end

-- One solve over a snapshot of raw board listings. Pure with respect to the
-- board: it reads what it is handed and returns what it found, so tests can
-- feed it synthetic listings. `dials` is the current level's table.
function LiquidityService.solveListings(listings: { any }, now: number, dials: any): ({ any }, number)
	local legs = {}
	for _, listing in listings do
		local leg = Core.normalize(listing)
		if leg then
			table.insert(legs, leg)
		end
	end
	return LiquidityService.solveLegs(legs, now, dials)
end

local function labelOf(chain: any): string
	local parts = {}
	for _, leg in chain.legs do
		table.insert(parts, ("%s×%d"):format(leg.kind, chain.units[leg.id] or 1))
	end
	return table.concat(parts, " + ")
end

-- The gem store shelf and the active event recipes, as legs. The bot sees the
-- WHOLE economy, not just the board: "buy X from the store" and "craft X from
-- Y" are two more ways an item can come into existence for a chain that needs
-- it, and the same balance check covers them (gems and inputs are just keys).
-- Cached: shelves and recipes rotate on a scale of minutes.
local npcCache: { any } = {}
local npcAt = 0
local NPC_ID_BASE = -1000000
local NPC_MAX_UNITS = 25

local function npcLegs(now: number): { any }
	if now - npcAt < 10 and npcAt ~= 0 then
		return npcCache
	end
	-- StoreService.shelfForBots() reads EconomyService.snapshot() (NOT cached),
	-- which reads through to a synchronous GetAsync on a cold item. Right after
	-- boot most items aren't warm yet, and this runs on every liquidity pass --
	-- gate it so it can't throw a GetAsync storm before warmCache catches up.
	local EconomyService = require(script.Parent.EconomyService) :: any
	if not EconomyService.isWarm() then
		return npcCache
	end
	npcAt = now
	local legs: { any } = {}
	local function add(id: string, kind: string, give: { [string]: number }, want: { [string]: number }, maxUnits: number)
		if maxUnits < 1 or next(give) == nil or next(want) == nil then
			return
		end
		table.insert(legs, {
			id = id,
			posterId = NPC_ID_BASE - #legs, -- unique per leg: no "same poster" clash
			kind = kind,
			npc = true,
			createdAt = now, -- never the oldest, and never a seed anyway
			give = give,
			want = want,
			maxUnits = math.min(maxUnits, NPC_MAX_UNITS),
		})
	end
	local ok = pcall(function()
		local StoreService = require(script.Parent.StoreService) :: any
		for _, entry in StoreService.shelfForBots() do
			add("store:" .. entry.itemId, "store", { [entry.itemId] = 1 }, { [Core.GEM_KEY] = entry.price }, entry.remaining)
		end
		local CraftingService = require(script.Parent.CraftingService) :: any
		local EconomyService = require(script.Parent.EconomyService) :: any
		for _, event in CraftingService.activeEvents(now) do
			for _, recipe in event.recipes do
				local want: { [string]: number } = {}
				for itemId, n in recipe.inputs do
					want[itemId] = n
				end
				if (recipe.gems or 0) > 0 then
					want[Core.GEM_KEY] = recipe.gems
				end
				local outId = CraftingService.recipeOutputId(recipe)
				local snap = EconomyService.snapshotCached(outId)
				add(("craft:%s:%s"):format(event.id, tostring(recipe.rid)), "craft", { [outId] = 1 }, want, snap and snap.reserveRemaining or NPC_MAX_UNITS)
			end
		end
	end)
	if not ok then
		legs = {} -- a service not ready yet: no system legs this round, not a crash
		npcAt = 0
	end
	npcCache = legs
	return legs
end

local function pass(sweep: number)
	local dials = LiquidityService.dials()
	if dials == nil then
		return
	end
	local now = os.time()
	if os.clock() - lastPassAt < dials.tickSeconds then
		return
	end
	lastPassAt = os.clock()

	local listings = TradeBoardService.rawOpenListings()

	-- Normalise ONCE; composition, connectivity and the solve all read this.
	local legs: { any } = {}
	local kinds = { swap = 0, sell = 0, bulk = 0, bulkbuy = 0, ignored = 0 }
	local swapLegs: { any } = {}
	for _, l in listings do
		local leg = Core.normalize(l)
		if leg then
			table.insert(legs, leg)
			kinds[leg.kind] = (kinds[leg.kind] or 0) + 1
			if leg.kind == "swap" then
				table.insert(swapLegs, leg)
			end
		else
			kinds.ignored += 1
		end
	end
	local npc = npcLegs(now)
	-- connectivity: how many swaps have their WANT supplied by someone else's
	-- give, and their GIVE wanted by someone else. A chain needs both directions
	-- around every leg, so low numbers here mean the board is structurally
	-- unmatchable rather than the solver missing something.
	do
		local giveBy: { [string]: { [number]: boolean } } = {}
		local wantBy: { [string]: { [number]: boolean } } = {}
		for _, leg in swapLegs do
			for k in leg.give do
				giveBy[k] = giveBy[k] or {}
				giveBy[k][leg.posterId] = true
			end
			for k in leg.want do
				wantBy[k] = wantBy[k] or {}
				wantBy[k][leg.posterId] = true
			end
		end
		-- the store shelf and event recipes supply things too
		for _, leg in npc do
			for k in leg.give do
				giveBy[k] = giveBy[k] or {}
				giveBy[k][leg.posterId] = true
			end
		end
		local supplied, demanded = 0, 0
		for _, leg in swapLegs do
			local sup, dem = true, true
			for k in leg.want do
				local ok = false
				for p in giveBy[k] or {} do
					if p ~= leg.posterId then
						ok = true
						break
					end
				end
				sup = sup and ok
			end
			for k in leg.give do
				local ok = false
				for p in wantBy[k] or {} do
					if p ~= leg.posterId then
						ok = true
						break
					end
				end
				dem = dem and ok
			end
			if sup then
				supplied += 1
			end
			if dem then
				demanded += 1
			end
		end
		ReplicatedStorage:SetAttribute("LiqSwapsWantSupplied", supplied)
		ReplicatedStorage:SetAttribute("LiqSwapsGiveDemanded", demanded)
	end
	-- last: solveLegs sorts and truncates the list in place
	local chains, legCount = LiquidityService.solveLegs(legs, now, dials, npc)
	ReplicatedStorage:SetAttribute("LiqNpcLegs", #npc)
	ReplicatedStorage:SetAttribute("LiqBulkBuys", kinds.bulkbuy)
	ReplicatedStorage:SetAttribute("LiqSwaps", kinds.swap)
	ReplicatedStorage:SetAttribute("LiqSells", kinds.sell)
	ReplicatedStorage:SetAttribute("LiqBulks", kinds.bulk)
	ReplicatedStorage:SetAttribute("LiqIgnored", kinds.ignored)

	stats.passes += 1
	stats.lastLegs = legCount
	stats.lastChains = #chains
	for i, chain in chains do
		stats.chains += 1
		for _, leg in chain.legs do
			if leg.npc then
				stats.npcChains += 1
				break
			end
		end
		stats.participants += chain.participants
		if i <= LiquidityConfig.DetailLogPerPass then
			AnalyticsService.log("liquidity_chain_found", {
				level = level,
				dry = LiquidityConfig.DryRun,
				participants = chain.participants,
				shape = labelOf(chain),
			})
		end
	end
	publishStats()

	-- DryRun=false has no executor yet (Phase 5); it must not silently
	-- pretend to act, so it degrades to dry-run loudly.
	if not LiquidityConfig.DryRun and stats.passes == 1 then
		warn("[Liquidity] DryRun=false but execution is not built yet; still dry-running")
	end

	if stats.passes % LiquidityConfig.SummaryEveryPasses == 0 then
		AnalyticsService.log("liquidity_dryrun", {
			level = level,
			passes = stats.passes,
			legs = legCount,
			chains = stats.chains,
			participants = stats.participants,
		})
	end
end

-- Overall-economy totals for the monitor panel. Cached snapshots only (never a
-- DataStore read), refreshed every few seconds.
local lastEcoAt = 0
local function ecoStats()
	if os.clock() - lastEcoAt < 5 then
		return
	end
	lastEcoAt = os.clock()
	local EconomyService = require(script.Parent.EconomyService) :: any
	local items, circ, reserve, cap = 0, 0, 0, 0
	for _, id in EconomyService.allItemIds() do
		local snap = EconomyService.snapshotCached(id)
		if snap then
			items += 1
			local c = (snap.supply and snap.supply.value) or 0
			circ += c
			reserve += snap.reserveRemaining or 0
			cap += c * ((snap.value and snap.value.value) or 0)
		end
	end
	ReplicatedStorage:SetAttribute("EcoItemsTracked", items)
	ReplicatedStorage:SetAttribute("EcoCirculating", circ)
	ReplicatedStorage:SetAttribute("EcoReserveLeft", reserve)
	ReplicatedStorage:SetAttribute("EcoMarketCapGems", math.floor(cap))
end

local function isValidLevel(name: any): boolean
	for _, l in LiquidityConfig.Levels do
		if l == name then
			return true
		end
	end
	return false
end

function LiquidityService.getLevel(): string
	return level
end

-- The dials for the current level, or nil when OFF / disabled.
function LiquidityService.dials(): any?
	if not LiquidityConfig.Enabled or level == "OFF" then
		return nil
	end
	return LiquidityConfig.Dials[level]
end

function LiquidityService.setLevel(name: string): boolean
	if not isValidLevel(name) then
		return false
	end
	level = name
	ReplicatedStorage:SetAttribute("LiqLevel", name)
	-- BotService's loop is only the leader-elected host for the hooks (its own
	-- archetype brains obey BotConfig.Enabled), so it runs whenever we do.
	BotService.setEnabled(name ~= "OFF")
	SimPlayerService.setEnabled(name ~= "OFF")
	AnalyticsService.log("liquidity_level", { level = name })
	return true
end

function LiquidityService.Init() end

function LiquidityService.Start()
	-- Runs on the bots' leader-elected sweep rather than its own loop, so
	-- exactly one server ever runs a pass. Nothing happens while OFF: the
	-- sweep itself is stopped then, and dials() returns nil regardless.
	BotService.registerSweepHook(pass)
	BotService.registerSweepHook(ecoStats)
	ReplicatedStorage:SetAttribute("LiqLevel", level)

	-- DEBUG ONLY (admin-gated). Cycles the facilitator level. Passing no level
	-- just reports the current one, so the button can sync its label on join.
	Net.bindFunction("DebugSetLiquidityLevel", function(player, requested)
		if not (DebugConfig.AdminUserIds and DebugConfig.AdminUserIds[player.UserId]) then
			return { ok = false, err = "not_admin" }
		end
		if requested ~= nil then
			if not LiquidityService.setLevel(requested) then
				return { ok = false, err = "bad_level" }
			end
		end
		return { ok = true, level = level }
	end)
end

return LiquidityService
