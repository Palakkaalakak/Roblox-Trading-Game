--!strict
-- EconomyService: authoritative shared economy state.
--   * Global Item Registry (durable; any server resolves any itemId ever made)
--   * Per-item EconomyRecord: reserve/circulating/demand/RAP
--     - durable copy in DataStore (source of truth; atomic UpdateAsync CAS)
--     - local cache per server, invalidated by MessagingService pings
--   * value/demand/supply/RAP snapshots with explicit N/A (StatState)
--
-- NO MemoryStore here: its memory quota is EXPERIENCE-WIDE and tiny (~64KB
-- in Studio) — a hot mirror of every item's record ate the entire quota by
-- itself and starved every other MemoryStore consumer (the trade board).
-- Consistency is split by what each mutation needs:
--   * reserve/retire (correctness-critical counts) -> DataStore UpdateAsync,
--     atomic cross-server, written through immediately
--   * RAP/demand stats (high-frequency, statistical) -> local record + dirty
--     flag, flushed durably every HotFlushIntervalSeconds (last-writer-wins
--     by updatedAt); cross-server readers are at most one flush stale
--
-- Stat DAG: supply<-counts, demand<-events, value<-g(demand,supply), RAP<-trades.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Enums = require(ReplicatedStorage.Shared.Enums)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local RollingAverage = require(ReplicatedStorage.Shared.Util.RollingAverage)
local Rarity = require(ReplicatedStorage.Shared.Util.Rarity)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local Net = require(script.Parent.Parent.Net)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local AnalyticsService = require(script.Parent.AnalyticsService)

local EconomyService = {}

local registryStore: any -- DataStore "ItemRegistry_v1", key "all" -> {itemId -> Item}
local econStore: any -- DataStore "EconomyStore_v1", key itemId -> EconomyRecord

local registry: { [string]: any } = {} -- itemId -> Item (local cache)
local hotCache: { [string]: any } = {} -- itemId -> EconomyRecord (local cache)
local dirty: { [string]: boolean } = {} -- itemIds needing durable flush
-- itemIds carrying SESSION-LOCAL edits (bot sim supply). Never flushed, and
-- never invalidated either: the durable record doesn't have these edits, so
-- dropping the cache would silently revert them.
local localOnly: { [string]: boolean } = {}
-- Set once warmCache() has pulled a record for every registered item. Until
-- then registry-wide readers serve only what's cached (see snapshotCached).
local warmed = false

-- Cross-server broadcast coalescing: a burst of broadcastStats calls (bot
-- seeding, a busy sweep, several trades in one tick) collapses into ONE
-- MessagingService publish per BROADCAST_COALESCE_SECONDS instead of one per
-- call — a topic's publish rate is tightly capped, and 100 bots trading
-- concurrently blew through it in seconds without this.
local pendingBroadcast: { [string]: boolean } = {}
local broadcastScheduled = false
local BROADCAST_COALESCE_SECONDS = 1.5

--------------------------------------------------------------------------------
-- Pure-ish math
--------------------------------------------------------------------------------

local demandDecayPerSecond = 0.5 ^ (1 / EconomyConfig.DemandHalfLifeSeconds)

local function decayedDemand(record: any, now: number): number
	local dt = math.max(0, now - (record.demandT or now))
	return (record.demandEMA or 0) * demandDecayPerSecond ^ dt
end

-- Est. Value is GEM-DENOMINATED and ALWAYS DEFINED (never N/A) — every player
-- sees the same number for the same item, everywhere, and it is a pure
-- function of FUNDAMENTALS: what the thing anchors at, how much of it has been
-- destroyed, and how badly people want it. See the EconomyConfig header for
-- the formula and why it is built this way.
--
-- Value deliberately does NOT read RAP. It used to blend a seed with RAP, with
-- the seed's weight decaying to a 0.04 floor — so Value asymptotically BECAME
-- RAP, and RAP is just the average of prices that were themselves set off
-- Value. That loop had no anchor: Value only ever told you where Value had
-- already been, and no amount of burning or demand could move it. RAP is still
-- computed and displayed, purely as an OBSERVED statistic.
-- Deterministic from (registry, economy record): no per-client divergence.

-- Anchor price in gems for an event item with no recipe to cost out.
function EconomyService.scarcitySeed(totalSupply: number): number
	local scarcity = (EconomyConfig.ReferenceSupply / math.max(totalSupply, 1)) ^ EconomyConfig.SupplyExponent
	return math.max(1, math.floor(EconomyConfig.ValueBase * scarcity + 0.5))
end

-- value = base * demandFactor.
--
-- `base` already prices the item from its fixed totalSupply cap (see
-- scarcitySeed / displayStoreCost) — a small cap means a high base, a huge cap
-- means a low one, and that number never moves once set. Deliberately no
-- separate scarcity term reacting to circulating/burned counts: an item's
-- price must not run away or collapse from crafting activity alone. The
-- economy still grows in aggregate as more items and item TYPES enter the
-- world (each with its own capped base), just never by inflating one item's
-- unit price. Demand is the only thing that moves a price day to day, and
-- it's capped at +DemandCoefficient so it can only ever nudge, not spiral.
--
-- (Revisit if the game reaches a scale where a circulation-aware term is
-- worth the added complexity — deliberately left simple for now.)
function EconomyService.computeValue(base: number, demand: number): number
	local demandFactor = 1 + EconomyConfig.DemandCoefficient * math.min(demand / EconomyConfig.DemandRef, 1)
	return math.max(1, math.floor(base * demandFactor + 0.5))
end

-- Live rarity->gems lookup against the CURRENT config — never frozen into
-- storage, so a balance change in Items.StoreCostByRarity takes effect for
-- every already-registered item immediately, no data migration required.
local function rarityFallbackCost(rarity: string?): number?
	return rarity and Items.StoreCostByRarity[rarity] or nil
end

-- The gem number shown as "Store Cost" and used to seed Est. Value: explicit
-- price if the item has one (NPC store / product token), else the live
-- rarity price, else nil for event items (displayed "N/A (Event Item)").
function EconomyService.displayStoreCost(item: any): number?
	if item.eventItem then
		return nil
	end
	return item.storeCost or rarityFallbackCost(item.rarity)
end

-- Event/crafted items have no store cost. Seed their Est. Value from what it
-- COST to make one: sum of input item values + input gems, +10% (the crafting
-- premium). That premium is also the economy's main VALUE FAUCET — crafting
-- destroys the inputs and mints an output worth more than they were, so a
-- bot/player who crafts genuinely grows net worth (trading alone is zero-sum
-- minus tax). Built once from EventConfig; falls back to scarcity if a recipe
-- is missing. `evt_<sku>` matches CraftingService.outputItemId.
local eventRecipeIndex: { [string]: { inputs: { [string]: number }, gems: number } }? = nil
local function buildEventRecipeIndex()
	local index: { [string]: any } = {}
	local function add(recipe: any)
		index["evt_" .. recipe.output.sku] = { inputs = recipe.inputs, gems = recipe.gems or 0 }
	end
	for _, event in EventConfig.Events do
		for _, recipe in event.recipes do
			add(recipe)
		end
	end
	if EventConfig.RotatingRecipes then
		for _, recipe in EventConfig.RotatingRecipes.Pool do
			add(recipe)
		end
	end
	eventRecipeIndex = index
end

local function eventSeed(itemId: string): number?
	if eventRecipeIndex == nil then
		buildEventRecipeIndex()
	end
	local recipe = (eventRecipeIndex :: any)[itemId]
	if recipe == nil then
		return nil
	end
	local total = recipe.gems
	for inId, count in recipe.inputs do
		total += EconomyService.valueOf(inId) * count
	end
	return math.max(1, math.floor(total * EconomyConfig.CraftValuePremium + 0.5))
end

local function seedFor(item: any, itemId: string?): number
	if item.eventItem and itemId then
		local es = eventSeed(itemId)
		if es then
			return es
		end
	end
	return EconomyService.displayStoreCost(item) or EconomyService.scarcitySeed(item.totalSupply)
end

local function freshRecord(itemId: string, totalSupply: number, now: number)
	return {
		itemId = itemId,
		reserveRemaining = totalSupply,
		circulating = 0,
		burned = 0, -- copies destroyed forever (craft/sacrifice inputs) -> scarcity
		demandEMA = 0,
		demandT = now,
		demandSamples = 0,
		rapValue = 0,
		rapCount = 0,
		updatedAt = now,
	}
end

--------------------------------------------------------------------------------
-- Registry
--------------------------------------------------------------------------------

-- Cooldown on registry re-reads. getItem() re-fetches on a miss ("maybe
-- another server registered it") — but a genuinely-unknown id would otherwise
-- turn EVERY lookup into a DataStore GetAsync, and a busy bot sweep into a
-- read-throttle storm. One refresh per window is plenty: cross-server
-- registrations are rare and never latency-critical.
local REGISTRY_RELOAD_COOLDOWN = 10
local lastRegistryLoad = 0

function EconomyService.loadRegistry()
	if os.clock() - lastRegistryLoad < REGISTRY_RELOAD_COOLDOWN then
		return
	end
	lastRegistryLoad = os.clock()
	local stored
	pcall(function()
		stored = registryStore:GetAsync("all")
	end)
	-- keep what we have on a failed/empty read; never wipe a live registry
	if stored then
		registry = stored
	elseif next(registry or {}) == nil then
		registry = {}
	end
end

-- Register new items (rotation / seed). Item defs: {itemId, poolId, name,
-- totalSupply, assignmentWeight}. Rarity derived here — never passed in.
--
-- FAST on reboot: when every def is already registered and needs no backfill,
-- this is zero store calls (boot used to burn ~1s per item re-seeding records
-- that already existed). Economy records are NOT written here — getRecord
-- lazy-seeds them from the registry on first touch.
function EconomyService.registerItems(defs: { any })
	local now = os.time()

	-- diff against the in-memory registry first. storeCost is only ever
	-- diffed/written when a def carries an EXPLICIT price (NPC store /
	-- product tokens) — rarity-derived cost is never frozen into storage
	-- (see rarityFallbackCost), so a nil storeCost on a non-event item is
	-- the correct steady state, not something to "fix".
	local dirtyDefs = {}
	local reasons = {}
	for _, def in defs do
		local existing = registry[def.itemId]
		if existing == nil then
			table.insert(dirtyDefs, def)
			if #reasons < 3 then
				table.insert(reasons, def.itemId .. ":missing")
			end
		elseif (existing.imageId == nil and def.imageId ~= nil)
			or (def.eventItem and (not existing.eventItem or existing.storeCost ~= nil))
			or (def.storeCost ~= nil and existing.storeCost ~= def.storeCost)
		then
			table.insert(dirtyDefs, def) -- needs a backfill / explicit-price resync
			if #reasons < 3 then
				table.insert(reasons, def.itemId .. ":backfill")
			end
		end
	end
	if #dirtyDefs == 0 then
		return -- everything already registered; boot stays instant
	end

	registryStore:UpdateAsync("all", function(old)
		old = old or {}
		for _, def in dirtyDefs do
			local rarity = Rarity.tierFor(def.totalSupply)
			if old[def.itemId] == nil then
				old[def.itemId] = {
					itemId = def.itemId,
					poolId = def.poolId,
					name = def.name,
					totalSupply = def.totalSupply,
					assignmentWeight = def.assignmentWeight,
					rarity = rarity,
					imageId = def.imageId,
					-- ONLY explicit fixed prices are stored. Event items: no
					-- store cost (UI: "N/A (Event Item)"). Everything else:
					-- nil, resolved live from current config every read.
					storeCost = if def.eventItem then nil else def.storeCost,
					eventItem = def.eventItem,
					-- Robux product tokens (tradeable stand-ins for passes/products)
					productType = def.productType,
					productId = def.productId,
					createdAt = now,
				}
			else
				-- backfill fields added after the entry was written
				if old[def.itemId].imageId == nil and def.imageId ~= nil then
					old[def.itemId].imageId = def.imageId
				end
				if def.eventItem then
					old[def.itemId].eventItem = true
					old[def.itemId].storeCost = nil
				elseif def.storeCost ~= nil then
					old[def.itemId].storeCost = def.storeCost -- explicit price changed in config
				end
			end
		end
		registry = old
		return old
	end)
	AnalyticsService.log("items_registered", { count = #dirtyDefs, why = table.concat(reasons, ",") })
end

function EconomyService.getItem(itemId: string): any?
	if registry[itemId] == nil then
		EconomyService.loadRegistry() -- maybe another server registered it
	end
	return registry[itemId]
end

function EconomyService.allItems(): { [string]: any }
	return registry
end

--------------------------------------------------------------------------------
-- Hot record access + mutation
--------------------------------------------------------------------------------

-- Read-through: local cache -> durable -> fresh.
local function getRecord(itemId: string): any?
	if hotCache[itemId] then
		return hotCache[itemId]
	end
	local rec
	pcall(function()
		rec = econStore:GetAsync(itemId)
	end)
	if rec == nil then
		local item = EconomyService.getItem(itemId)
		if item == nil then
			return nil
		end
		rec = freshRecord(itemId, item.totalSupply, os.time())
	end
	hotCache[itemId] = rec
	return rec
end

-- STRONG mutation: atomic durable CAS (DataStore UpdateAsync). For
-- correctness-critical counts (reserve/circulating) that must never
-- double-apply across servers.
-- CRITICAL: the transform must be PURE — no yields, no store reads. The
-- store may invoke it multiple times, and yielding inside it double-applies
-- mutations (this exact bug inflated circulating counts). The item lookup
-- happens BEFORE the CAS for the same reason.
local function mutateRecord(itemId: string, transform: (any) -> any?): any?
	local item = EconomyService.getItem(itemId)
	if item == nil then
		return nil
	end
	local result
	local ok = pcall(function()
		result = econStore:UpdateAsync(itemId, function(old)
			return transform(old or freshRecord(itemId, item.totalSupply, os.time()))
		end)
	end)
	if not ok or result == nil then
		return nil
	end
	hotCache[itemId] = result
	return result
end

-- LAZY mutation: local record + dirty flag, flushed durably on a timer.
-- For high-frequency statistical updates (RAP samples, demand bumps) that a
-- DataStore write-per-call would throttle into the ground. Cross-server
-- merge is last-writer-wins by updatedAt at flush time.
local function mutateRecordLazy(itemId: string, transform: (any) -> any?): any?
	local rec = getRecord(itemId)
	if rec == nil then
		return nil
	end
	local new = transform(rec)
	if new == nil then
		return nil
	end
	hotCache[itemId] = new
	dirty[itemId] = true
	return new
end

-- SESSION-LOCAL mutation: in-memory only, deliberately never marked dirty and
-- so never flushed to the durable record. This is the market bots' lane: their
-- own gems/inventory are in-memory and wiped on every server start, so anything
-- they do to the shared economy MUST reset with them. Persisting it desyncs the
-- durable record from a bot population that no longer exists — exactly the bug
-- that once drained every scarce item's reserve to 0 permanently.
local function mutateRecordLocal(itemId: string, transform: (any) -> any?): any?
	local rec = getRecord(itemId)
	if rec == nil then
		return nil
	end
	local new = transform(rec)
	if new == nil then
		return nil
	end
	hotCache[itemId] = new -- NOT dirty: dies with the session, by design
	-- ...but it must survive cache INVALIDATION, which is a different thing.
	-- The durable record has never heard of these edits, so re-reading it would
	-- silently revert them. (This bit hard: every broadcast reset the bots'
	-- entire goods supply back to 0 while they were visibly holding 200k of
	-- items, and Value's scarcity term was reading that zero.)
	localOnly[itemId] = true
	return new
end

--------------------------------------------------------------------------------
-- Public mutations
--------------------------------------------------------------------------------

-- Bot PRODUCTION: new goods enter circulation (session-local). Growing the
-- count of goods is the only thing that genuinely grows total worth — trading
-- just moves it and crafting only converts it.
function EconomyService.addCirculatingLocal(itemId: string, count: number)
	if count <= 0 then
		return
	end
	local item = EconomyService.getItem(itemId)
	local cap = item and item.totalSupply or math.huge
	mutateRecordLocal(itemId, function(old)
		-- Hard clamp: circulating can NEVER exceed how many can ever exist.
		-- ("X in existence" showing more than the cap is nonsense, and it made
		-- the scarcity term lie.)
		old.circulating = math.min((old.circulating or 0) + count, cap)
		old.updatedAt = os.time()
		return old
	end)
end

-- Reserve one undistributed copy (starter draw). Atomic cross-server.
-- Returns (reserved, remainingAfter). Success derived from the committed CAS
-- result (transform may retry under contention; never trust closure flags).
-- Take one copy out of the reserve into circulation.
--
-- LAZY, not a per-call DataStore write. A write costs ~400ms, and this sits on
-- the response path of every craft, roll and store buy — the player was waiting
-- most of a second to be handed one item. In-memory now, flushed on the usual
-- timer.
--
-- What that trades away: two servers can each hand out what the durable record
-- thinks is the last copy, so `circulating` can drift a few over `totalSupply`
-- before the flushes merge. That is a soft cap on a cosmetic scarcity number,
-- not currency or ownership — nobody's items are duplicated, and the counter
-- self-corrects on the next flush. The alternative is a second of latency on
-- the single most-clicked action in the game, which is a worse trade.
function EconomyService.reserveOne(itemId: string): (boolean, number)
	local rec = mutateRecordLazy(itemId, function(old)
		if (old.reserveRemaining or 0) <= 0 then
			return nil -- abort: nothing left to reserve
		end
		old.reserveRemaining -= 1
		old.circulating += 1
		old.updatedAt = os.time()
		return old
	end)
	if rec == nil then
		return false, 0
	end
	EconomyService.broadcastStats({ itemId })
	return true, rec.reserveRemaining
end

-- Reserve one copy the LAZY way (in-memory record + dirty flush). For the
-- market-bot seeding burst only: 500 bots x StarterDraws would be thousands
-- of synchronous DataStore UpdateAsync calls through reserveOne and blow the
-- request budget (which then starves player profile ops). Bots run
-- leader-local, so the leader's cached record is authoritative here; the
-- flush persists circulating/reserve within the minute. Real players still
-- use the strong reserveOne (cross-server atomic).
function EconomyService.reserveOneLazy(itemId: string): boolean
	local rec = mutateRecordLocal(itemId, function(old)
		if (old.reserveRemaining or 0) <= 0 then
			return nil
		end
		old.reserveRemaining -= 1
		old.circulating += 1
		old.updatedAt = os.time()
		return old
	end)
	return rec ~= nil
end

-- Demand bump (offer inclusion or trade completion).
function EconomyService.bumpDemand(itemId: string, amount: number, countAsSample: boolean)
	mutateRecordLazy(itemId, function(old)
		local now = os.time()
		old.demandEMA = decayedDemand(old, now) + amount
		old.demandT = now
		if countAsSample then
			old.demandSamples = (old.demandSamples or 0) + 1
		end
		old.updatedAt = now
		return old
	end)
end

-- Return copies from circulation to the RESERVE (the roll/draw pool) — the
-- inverse of reserveOne. Used by roll item-payments AND crafting inputs:
-- consumed copies are redistributed, not destroyed, so someone else (a new
-- player's free starter grant, a roll, a store restock) can draw them back out.
-- Strong CAS like reserveOne; never moves more than circulation holds.
-- Put copies back into the reserve. Lazy for the same reason as reserveOne:
-- it runs per consumed ingredient, so a strong write here cost a round trip
-- per item on every craft.
function EconomyService.restockCopies(itemId: string, count: number)
	if count <= 0 then
		return
	end
	mutateRecordLazy(itemId, function(old)
		local back = math.min(count, old.circulating or 0)
		old.circulating = math.max(0, (old.circulating or 0) - back)
		old.reserveRemaining = (old.reserveRemaining or 0) + back
		old.updatedAt = os.time()
		return old
	end)
	EconomyService.broadcastStats({ itemId })
end

-- Lazy counterpart of restockCopies (in-memory + dirty flush) — same rationale
-- as reserveOneLazy/retireCopiesLazy: a synchronous DataStore UpdateAsync per
-- craft, across many bots, starves the shared request budget.
function EconomyService.restockCopiesLazy(itemId: string, count: number)
	if count <= 0 then
		return
	end
	mutateRecordLocal(itemId, function(old)
		local back = math.min(count, old.circulating or 0)
		old.circulating = math.max(0, (old.circulating or 0) - back)
		old.reserveRemaining = (old.reserveRemaining or 0) + back
		old.updatedAt = os.time()
		return old
	end)
	EconomyService.broadcastStats({ itemId })
end

-- Retire copies from circulation (crafting/sacrifice sink: the consumed
-- items are destroyed). totalSupply is untouched — "X/Y in existence" shows
-- X dropping while Y stays the historical cap. Atomic cross-server.
function EconomyService.retireCopies(itemId: string, count: number)
	if count <= 0 then
		return
	end
	mutateRecord(itemId, function(old)
		local gone = math.min(count, old.circulating or 0)
		old.circulating = math.max(0, (old.circulating or 0) - count)
		-- destroyed copies are what make the survivors scarcer, and thus what
		-- lifts every holder's Est. Value. Without this the sink is invisible.
		old.burned = (old.burned or 0) + gone
		old.updatedAt = os.time()
		return old
	end)
	EconomyService.broadcastStats({ itemId })
end

-- MAINTENANCE ONLY: put an item back to its untouched state — full reserve,
-- nothing circulating, nothing burned. Written through the same strong CAS as
-- every other reserve mutation, so it cannot race a live buy/craft, and it
-- refreshes this server's cache immediately.
--
-- Exists because wiping records straight out of the DataStore does NOT work:
-- every server holds a hot cache that it flushes back on shutdown, so a
-- external delete gets silently overwritten by the next flush. Going through
-- the service is the only way to reset an item and have it stick.
function EconomyService.resetItem(itemId: string): (boolean, string?)
	local item = EconomyService.getItem(itemId)
	if item == nil then
		return false, "unknown_item"
	end
	local rec = mutateRecord(itemId, function(old)
		old.reserveRemaining = item.totalSupply
		old.circulating = 0
		old.burned = 0
		old.demandEMA = 0
		old.demandSamples = 0
		old.rapValue = 0
		old.rapCount = 0
		old.updatedAt = os.time()
		return old
	end)
	if rec == nil then
		return false, "store_error"
	end
	hotCache[itemId] = rec
	EconomyService.broadcastStats({ itemId })
	AnalyticsService.log("item_reset", { itemId = itemId, totalSupply = item.totalSupply })
	return true, nil
end

-- Every registered itemId, so maintenance can sweep the whole catalogue.
function EconomyService.allItemIds(): { string }
	local out = {}
	for itemId in registry do
		table.insert(out, itemId)
	end
	return out
end

-- Retire copies the LAZY way (in-memory + dirty flush). For the market-bot
-- craft path only — same rationale as reserveOneLazy: a synchronous DataStore
-- UpdateAsync per bot craft, x hundreds of bots, starves the request budget
-- and stalls player calls.
function EconomyService.retireCopiesLazy(itemId: string, count: number)
	if count <= 0 then
		return
	end
	mutateRecordLocal(itemId, function(old)
		local gone = math.min(count, old.circulating or 0)
		old.circulating = math.max(0, (old.circulating or 0) - count)
		-- destroyed copies are what make the survivors scarcer, and thus what
		-- lifts every holder's Est. Value. Without this the sink is invisible.
		old.burned = (old.burned or 0) + gone
		old.updatedAt = os.time()
		return old
	end)
	EconomyService.broadcastStats({ itemId })
end

-- Record a closed-trade imputed price into RAP (+ demand sample).
function EconomyService.recordTradePrice(itemId: string, imputedPrice: number)
	mutateRecordLazy(itemId, function(old)
		local now = os.time()
		old.rapValue, old.rapCount = RollingAverage.push(old.rapValue or 0, old.rapCount or 0, imputedPrice)
		old.demandEMA = decayedDemand(old, now) + EconomyConfig.DemandBumpOnTrade
		old.demandT = now
		old.demandSamples = (old.demandSamples or 0) + 1
		old.updatedAt = now
		return old
	end)
	AnalyticsService.log("rap_update", { itemId = itemId, price = imputedPrice })
end

-- Record a gem-only SALE: an exact per-copy gem price, `count` copies. This
-- is the cleanest possible signal (no barter imputation), so each copy is a
-- full RAP sample. One CAS pushes them all (RollingAverage.push is pure, so
-- looping inside the transform is safe). Sample count capped to bound work.
function EconomyService.recordSale(itemId: string, pricePerCopy: number, count: number)
	local samples = math.clamp(count, 1, 50)
	mutateRecordLazy(itemId, function(old)
		local now = os.time()
		local avg, n = old.rapValue or 0, old.rapCount or 0
		for _ = 1, samples do
			avg, n = RollingAverage.push(avg, n, pricePerCopy)
		end
		old.rapValue, old.rapCount = avg, n
		old.demandEMA = decayedDemand(old, now) + EconomyConfig.DemandBumpOnTrade
		old.demandT = now
		old.demandSamples = (old.demandSamples or 0) + 1
		old.updatedAt = now
		return old
	end)
	EconomyService.broadcastStats({ itemId })
	AnalyticsService.log("sale_price", { itemId = itemId, price = pricePerCopy, copies = count })
end

--------------------------------------------------------------------------------
-- Snapshots (client-facing, N/A-aware)
--------------------------------------------------------------------------------

local function stat(known: boolean, value: number?): any
	if known and value ~= nil then
		return { state = Enums.StatState.Known, value = value }
	end
	return { state = Enums.StatState.NA }
end

-- Snapshot WITHOUT the read-through: nil when the record isn't cached yet.
-- getRecord blocks on a DataStore GetAsync per cold item, so a caller that
-- sweeps the whole registry (the market directory) would serialise one round
-- trip per item and stall for many seconds on a freshly booted server. Those
-- callers use this and let warmCache() fill in the rest.
function EconomyService.snapshotCached(itemId: string): any?
	if hotCache[itemId] == nil then
		return nil
	end
	return EconomyService.snapshot(itemId)
end

-- True once every registered item has a cached record (see warmCache).
function EconomyService.isWarm(): boolean
	return warmed
end

function EconomyService.snapshot(itemId: string): any?
	local item = EconomyService.getItem(itemId)
	local rec = getRecord(itemId)
	if item == nil or rec == nil then
		return nil
	end
	local now = os.time()
	local demand = decayedDemand(rec, now)
	local circulating = rec.circulating or 0
	local value = EconomyService.computeValue(seedFor(item, itemId), demand)

	return {
		itemId = itemId,
		name = item.name,
		rarity = item.rarity,
		imageId = item.imageId,
		totalSupply = item.totalSupply, -- fixed cap (the Y in "X/Y in existence")
		storeCost = EconomyService.displayStoreCost(item), -- gems; nil = event item (same number that seeds Value)
		-- supply is always known (authoritative count; 0 is a real value)
		supply = stat(true, circulating),
		demand = stat((rec.demandSamples or 0) >= EconomyConfig.MinSamples.Demand, math.floor(demand * 100 + 0.5) / 100),
		value = stat(true, value), -- always defined: same number for every player
		rap = stat((rec.rapCount or 0) >= EconomyConfig.MinSamples.RAP, math.floor((rec.rapValue or 0) + 0.5)),
		reserveRemaining = rec.reserveRemaining or 0,
	}
end

-- Gem value used inside RAP imputation + trade totals (always defined).
function EconomyService.valueOf(itemId: string): number
	local item = EconomyService.getItem(itemId)
	local rec = getRecord(itemId)
	if item == nil then
		return 1
	end
	return EconomyService.computeValue(seedFor(item, itemId), rec and decayedDemand(rec, os.time()) or 0)
end

--------------------------------------------------------------------------------
-- Sync: broadcast + flush + subscribe
--------------------------------------------------------------------------------

-- Invalidation ping: other servers drop caches + everyone pushes fresh
-- snapshots to clients. Payload = item ids only (MessagingService ~1KB cap).
-- Local clients get pushStats immediately (unaffected by the coalesce below,
-- so the acting player's own UI stays snappy); the cross-server publish is
-- debounced.
function EconomyService.broadcastStats(itemIds: { string })
	EconomyService.pushStats(itemIds)

	for _, itemId in itemIds do
		pendingBroadcast[itemId] = true
	end
	if broadcastScheduled then
		return
	end
	broadcastScheduled = true
	task.delay(BROADCAST_COALESCE_SECONDS, function()
		broadcastScheduled = false
		local ids = {}
		for itemId in pendingBroadcast do
			table.insert(ids, itemId)
		end
		table.clear(pendingBroadcast)
		if #ids > 0 then
			StoreAdapters.publish(EconomyConfig.StatsBroadcastTopic, { items = ids })
		end
	end)
end

function EconomyService.pushStats(itemIds: { string })
	local snapshots = {}
	for _, itemId in itemIds do
		local snap = EconomyService.snapshot(itemId)
		if snap then
			table.insert(snapshots, snap)
		end
	end
	if #snapshots > 0 then
		Net.fireAllClients("StatsUpdated", snapshots)
	end
end

local function flushDirty()
	for itemId in dirty do
		dirty[itemId] = nil
		local rec = hotCache[itemId]
		if rec then
			pcall(function()
				econStore:UpdateAsync(itemId, function(old)
					-- last-writer-wins by updatedAt; hot is newer in practice
					if old and old.updatedAt and rec.updatedAt and old.updatedAt > rec.updatedAt then
						return old
					end
					return rec
				end)
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

-- RESET GENERATION. A reset puts every reserve back to full; that is only
-- honest if the copies already handed out stop existing at the same moment,
-- otherwise the cap is re-mintable and players end up holding more than the
-- item's total supply. Players online at the time are cleared directly.
-- Everyone else is caught on their next load by comparing this counter, which
-- is durable and experience-wide, against the one stamped on their profile.
local RESET_GEN_KEY = "__reset_generation"
local resetGen = 0

local function readResetGeneration(): number
	local ok, stored = pcall(function()
		return econStore:GetAsync(RESET_GEN_KEY)
	end)
	if ok then
		resetGen = tonumber(stored) or 0
	end
	return resetGen
end

local function bumpResetGeneration(): number
	local ok, updated = pcall(function()
		return econStore:UpdateAsync(RESET_GEN_KEY, function(old)
			return (tonumber(old) or 0) + 1
		end)
	end)
	if ok then
		resetGen = tonumber(updated) or (resetGen + 1)
	else
		resetGen += 1 -- still wipe this server's players; the durable bump retries next reset
	end
	return resetGen
end

-- What a reset does to one profile. Held stacks are not "reset" by restocking
-- the reserve -- they have to go, or the supply cap means nothing. Returns
-- whether the profile changed, so a caller only pushes state when it did.
-- StarterGranted separates an established profile from one that has not been
-- given anything yet: a brand-new profile holds nothing from before the reset
-- and must not be cleared out from under StarterService.
function EconomyService.applyResetToProfile(profile: any, gen: number): boolean
	if (tonumber(profile.EconomyGen) or 0) == gen then
		return false
	end
	if profile.StarterGranted then
		profile.Inventory = {}
	end
	profile.EconomyGen = gen
	return true
end

function EconomyService.Init()
	StoreAdapters.init()
	-- v6: six-tier rarity restructure (added Godly/Celestial, eased Mythical
	-- threshold + supplies) — bumped so already-registered items re-seed with
	-- the new rarity/totalSupply instead of silently freezing at old values.
	registryStore = StoreAdapters.dataStore("ItemRegistry_v6")
	econStore = StoreAdapters.dataStore("EconomyStore_v6")
	readResetGeneration()
	EconomyService.loadRegistry()
	-- NOTE: registry.storeCost is only ever persisted for items with an
	-- EXPLICIT fixed price (NPC store catalog, product tokens). Everything
	-- else derives its cost live from item.rarity + the current
	-- Items.StoreCostByRarity table (see seedFor/rarityFallbackCost below) —
	-- do not add a backfill here that freezes a rarity price into storage;
	-- that is exactly the bug that let a stale pre-rebalance Common price
	-- (100) outlive the "cheap prices" config change silently.
end

function EconomyService.Start()
	-- remote: full item directory (board want-pickers etc)
	Net.bindFunction("GetCatalog", function(player)
		-- Sold-out replacement variants are internal machinery: they exist so a
		-- spent station always has something to offer. Listing the unused ones
		-- buries real items under rows of near-identical "Mk" entries, so they
		-- only appear once copies actually exist. Lazy require: CraftingService
		-- pulls in this service, and a top-level require would cycle.
		local generated = {}
		pcall(function()
			generated = require(script.Parent.CraftingService).generatedOutputIds()
		end)

		local items = {}
		for itemId, item in registry do
			local hide = false
			if generated[itemId] then
				local record = hotCache[itemId]
				local circulating = record and record.supply or 0
				hide = circulating <= 0
			end
			if not hide then
				table.insert(items, { itemId = itemId, name = item.name, imageId = item.imageId })
			end
		end
		table.sort(items, function(a, b)
			return a.name < b.name
		end)
		return { ok = true, items = items }
	end)

	-- MAINTENANCE, admin-gated: put every item back to full reserve. Needed for
	-- launch prep because the bot simulation crafted several event outputs to
	-- exhaustion, and those records cannot be cleared from OUTSIDE the game —
	-- each server holds a hot cache it flushes back over an external delete, so
	-- the reset has to go through the service. Remove with the debug tooling.
	local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
	Net.bindFunction("AdminResetEconomy", function(player)
		if not (DebugConfig.AdminUserIds and DebugConfig.AdminUserIds[player.UserId]) then
			return { ok = false, err = "not_admin" }
		end
		local reset, failed = 0, {}
		for _, itemId in EconomyService.allItemIds() do
			local ok, err = EconomyService.resetItem(itemId)
			if ok then
				reset += 1
			else
				table.insert(failed, itemId .. ":" .. tostring(err))
			end
		end
		-- The reserves are full again, so the copies already out there have to
		-- stop existing -- otherwise the cap is simply mintable twice and
		-- players keep stacks larger than the item's total supply.
		local gen = bumpResetGeneration()
		local DataService = require(script.Parent.DataService) :: any
		local InventoryService = require(script.Parent.InventoryService) :: any
		local wiped = 0
		for _, other in Players:GetPlayers() do
			local profile = DataService.getProfile(other)
			if profile then
				if EconomyService.applyResetToProfile(profile, gen) then
					InventoryService.pushState(other)
					wiped += 1
				end
			end
		end
		-- other servers need the new generation, or their players keep theirs
		StoreAdapters.publish(EconomyConfig.StatsBroadcastTopic, { resetGen = gen })
		AnalyticsService.log("admin_reset_economy", { by = player.UserId, reset = reset, wiped = wiped, gen = gen })
		return { ok = true, reset = reset, failed = failed, wiped = wiped }
	end)

	-- remote: batch stat fetch
	Net.bindFunction("GetStats", function(player, itemIds)
		local ok, err = Guard.checkItemIdList(itemIds, 64)
		if not ok then
			return { ok = false, err = err }
		end
		local snapshots = {}
		for _, itemId in itemIds :: { string } do
			local snap = EconomyService.snapshot(itemId)
			if snap then
				table.insert(snapshots, snap)
			end
		end
		return { ok = true, snapshots = snapshots }
	end)

	-- Players who were elsewhere when the reset ran. Their profile still
	-- carries the previous generation, so the stacks it holds came from an
	-- economy that no longer exists.
	local DataServiceRef = require(script.Parent.DataService) :: any
	DataServiceRef.ProfileLoaded:Connect(function(_player, data)
		EconomyService.applyResetToProfile(data, resetGen)
	end)

	-- cross-server economy deltas: invalidate + push
	StoreAdapters.subscribe(EconomyConfig.StatsBroadcastTopic, function(payload)
		if type(payload) ~= "table" then
			return
		end
		local broadcastGen = tonumber(payload.resetGen)
		if broadcastGen and broadcastGen > resetGen then
			resetGen = broadcastGen
			local DataService = require(script.Parent.DataService) :: any
			local InventoryService = require(script.Parent.InventoryService) :: any
			for _, other in Players:GetPlayers() do
				local profile = DataService.getProfile(other)
				if profile and EconomyService.applyResetToProfile(profile, resetGen) then
					InventoryService.pushState(other)
				end
			end
		end
		if type(payload.items) ~= "table" then
			return
		end
		for _, itemId in payload.items do
			-- Only drop the cache for items we have NO unflushed local update
			-- for. RAP/demand updates live in hotCache + dirty and are flushed
			-- to durable only every HotFlushIntervalSeconds; a broadcast (incl.
			-- our own, which MessagingService delivers back to the sender) that
			-- nulls the cache would force a re-read of the STALE durable record,
			-- making an actively-trading item's RAP flicker to N/A until the
			-- next sale repopulates it. If it's dirty, our copy is the newest.
			if type(itemId) == "string" and not dirty[itemId] and not localOnly[itemId] then
				hotCache[itemId] = nil -- refetch from durable on next read
			end
		end
		EconomyService.pushStats(payload.items)
	end)

	-- Pull every item's record into hotCache off the request path. getRecord
	-- costs one DataStore round trip per cold item, so without this the first
	-- caller to sweep the registry (the market directory) pays all of them in
	-- series inside its own remote call and the panel sits blank for ~15s.
	task.spawn(function()
		local queue = {}
		for itemId in registry do
			if hotCache[itemId] == nil then
				table.insert(queue, itemId)
			end
		end
		-- A few readers in parallel: one round trip at a time takes ~45s over a
		-- couple hundred items. Kept small on purpose — the DataStore request
		-- budget is shared with profile loads, which must not be starved.
		local next_ = 1
		local running = 0
		local WORKERS = 4
		for _ = 1, WORKERS do
			running += 1
			task.spawn(function()
				while next_ <= #queue do
					local itemId = queue[next_]
					next_ += 1
					getRecord(itemId)
				end
				running -= 1
			end)
		end
		while running > 0 do
			task.wait(0.1)
		end
		warmed = true
	end)

	-- periodic durable flush
	task.spawn(function()
		while true do
			task.wait(EconomyConfig.HotFlushIntervalSeconds)
			flushDirty()
		end
	end)

	game:BindToClose(function()
		flushDirty()
	end)
end

return EconomyService
