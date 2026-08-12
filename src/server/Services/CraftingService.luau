--!strict
-- CraftingService: limited events — crafting, sacrifices, rotating recipes.
--
-- Every recipe consumes inputs (items and/or gems) and produces one copy of a
-- LIMITED output item. Output stock is the item's reserve, taken with the
-- same atomic cross-server CAS as store buys and starter draws — when the
-- last copy is crafted the recipe stops working everywhere at once
-- ("Fully crafted!"). Consumed input items are REDISTRIBUTED back into that
-- same shared reserve, not destroyed — exactly like a roll item-payment —
-- so a common eaten by the hundreds at the top of the ladder recycles
-- straight back to new players' free starter grants instead of ever running
-- out. Outputs are ordinary tradeable items with Store Cost "N/A (Event Item)".
--
-- An item's Est. Value never reacts to this cycling (see EconomyService.
-- computeValue) — only its fixed totalSupply cap and live demand set its
-- price, so no single item can be inflated or deflated by crafting activity.
-- The economy still grows, just by COUNT: new items and new recipes, each
-- with their own cap, entering over time.
--
-- Active-recipe resolution is a PURE function of the wall clock (enabled
-- flags + start/end windows + deterministic rotation), so every server
-- agrees with zero coordination.
--
-- Craft flow: resolve active recipe -> charge inputs (atomic in-memory) ->
-- reserve output copy (CAS; refund inputs if it lost the race) -> redistribute
-- consumed copies back to the reserve -> grant output -> async save.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Enums)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Rotation = require(ReplicatedStorage.Shared.Util.Rotation)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ROTATING_EVENT_ID = "evt_rotating"
local UNIQUE_EVENT_ID = "evt_unique"

-- Lazy: UniqueCraftService reads activeEvents() from here, so requiring it
-- at the top would cycle.
local function uniqueCrafts(): any
	return require(script.Parent.UniqueCraftService)
end

local CraftingService = {}

local function outputItemId(sku: string): string
	return "evt_" .. sku
end

-- A recipe's output id. Normally "evt_<sku>", but a Unique Craft names an item
-- that ALREADY exists, so it carries an explicit itemId and we use that — the
-- craft then draws on that item's own reserve and cap like any other source.
local function recipeOutputId(recipe: any): string
	return recipe.output.itemId or outputItemId(recipe.output.sku)
end

--------------------------------------------------------------------------------
-- Recipe graph sanity
--------------------------------------------------------------------------------

-- Who makes each event item? Static config lookup (client uses the same one)
-- used ONLY by validateRecipeGraph's reachability check, which is deliberately
-- window-agnostic — a recipe is "reachable" if some window could ever produce
-- its input, not just this one.
local function producerName(itemId: string): string?
	local producer = EventConfig.producerOf(itemId)
	return producer and producer.name or nil
end

-- Every event-item INPUT must have a recipe somewhere that produces it —
-- otherwise a recipe can exist that is impossible to ever craft (its input
-- can neither be rolled, bought, nor made). Returns violation strings;
-- empty = the whole recipe graph is reachable. Pure config check.
function CraftingService.validateRecipeGraph(): { string }
	local violations = {}
	local function checkRecipe(where: string, recipe: any)
		for itemId in recipe.inputs do
			if itemId:sub(1, 4) == "evt_" and producerName(itemId) == nil then
				table.insert(
					violations,
					("%s/%s needs %s, but nothing active produces it"):format(where, recipe.rid, itemId)
				)
			end
		end
	end
	for _, event in EventConfig.Events do
		if event.enabled then
			for _, recipe in event.recipes do
				checkRecipe(event.id, recipe)
			end
		end
	end
	local rot = EventConfig.RotatingRecipes
	if rot and rot.enabled then
		for _, recipe in rot.Pool do
			checkRecipe(ROTATING_EVENT_ID, recipe)
		end
	end

	-- NO TWO RECIPES MAY SHARE AN OUTPUT. An item is one thing with one way to
	-- make it; several recipes minting the same sku renders as a column of
	-- identical rows the player cannot tell apart, and splits one item's supply
	-- across unrelated routes. (The refinery used to do this deliberately —
	-- four commons all producing one "Refined Essence" — and it read as a bug.)
	do
		local madeBy: { [string]: string } = {}
		local function claim(list: { any }, where: string)
			for _, recipe in list do
				local outId = recipeOutputId(recipe)
				local existing = madeBy[outId]
				if existing then
					table.insert(
						violations,
						("%s/%s outputs %s, but %s already does — an item needs exactly one recipe")
							:format(where, recipe.rid, outId, existing)
					)
				else
					madeBy[outId] = where .. "/" .. recipe.rid
				end
			end
		end
		for _, event in EventConfig.Events do
			if event.enabled then
				claim(event.recipes, event.id)
			end
		end
		if rot and rot.enabled then
			claim(rot.Pool, ROTATING_EVENT_ID)
		end
	end

	-- A rotating recipe may only ever produce a TERMINAL item. If a rotating
	-- output fed some other recipe, that recipe would be uncraftable for
	-- everyone in every window where its input wasn't picked — the dead end
	-- players used to hit. Middle rungs belong on permanent stations.
	if rot and rot.enabled then
		local consumed: { [string]: string } = {}
		local function noteInputs(list: { any }, where: string)
			for _, recipe in list do
				for itemId in recipe.inputs do
					consumed[itemId] = where .. "/" .. recipe.rid
				end
			end
		end
		for _, event in EventConfig.Events do
			if event.enabled then
				noteInputs(event.recipes, event.id)
			end
		end
		noteInputs(rot.Pool, ROTATING_EVENT_ID)
		for _, recipe in rot.Pool do
			local outId = outputItemId(recipe.output.sku)
			if consumed[outId] then
				table.insert(
					violations,
					("rotating/%s makes %s, but %s consumes it — a rotating output must be terminal")
						:format(recipe.rid, outId, consumed[outId])
				)
			end
		end
	end

	-- An item that feeds another recipe may be LIMITED only when the thing it
	-- feeds is limited too and expires with it; otherwise the moment the season
	-- ends the recipe above it becomes permanently uncraftable.
	local endsAtOf: { [string]: number? } = {}
	local limitedOutputs: { [string]: any } = {}
	for _, event in EventConfig.Events do
		if event.enabled and (event.endsAt or event.startsAt) then
			for _, recipe in event.recipes do
				local outId = outputItemId(recipe.output.sku)
				limitedOutputs[outId] = event
				endsAtOf[outId] = event.endsAt
			end
		end
	end
	local function checkLimitedInputs(list: { any }, ownerEndsAt: number?, where: string)
		for _, recipe in list do
			for itemId in recipe.inputs do
				local producer = limitedOutputs[itemId]
				if producer and (ownerEndsAt == nil or endsAtOf[itemId] ~= ownerEndsAt) then
					table.insert(
						violations,
						("%s/%s needs %s, which is limited and expires on a different schedule")
							:format(where, recipe.rid, itemId)
					)
				end
			end
		end
	end
	for _, event in EventConfig.Events do
		if event.enabled then
			checkLimitedInputs(event.recipes, event.endsAt, event.id)
		end
	end
	if rot and rot.enabled then
		checkLimitedInputs(rot.Pool, nil, ROTATING_EVENT_ID)
	end
	return violations
end

--------------------------------------------------------------------------------
-- Active events/recipes (pure time functions)
--------------------------------------------------------------------------------

local function eventActive(event: any, now: number): boolean
	if not event.enabled then
		return false
	end
	if event.startsAt and now < event.startsAt then
		return false
	end
	if event.endsAt and now >= event.endsAt then
		return false
	end
	return true
end

-- The picked window must always be able to PROGRESS: if none of the picked
-- recipes is a tier-1 material producer (commons -> essence), every tier-2
-- recipe that window is gated on essence already in circulation — a fresh
-- economy would stall. Deterministically swap the last pick for a tier-1
-- recipe (pure function of the window, so all servers agree).
local function ensureMaterialProducer(pool: { any }, picks: { number }, windowIdx: number): { number }
	for _, poolIndex in picks do
		if (pool[poolIndex].tier or 1) == 1 then
			return picks
		end
	end
	local tierOnes = {}
	for i, recipe in pool do
		if (recipe.tier or 1) == 1 then
			table.insert(tierOnes, i)
		end
	end
	if #tierOnes == 0 then
		return picks -- pool has no materials at all; nothing to guarantee
	end
	picks[#picks] = tierOnes[(windowIdx % #tierOnes) + 1]
	table.sort(picks)
	return picks
end

--------------------------------------------------------------------------------
-- Sold-out replacement (see EventConfig.Replacement)
--
-- A permanent recipe that has minted its whole supply is dead weight: it eats
-- nothing and mints nothing, and a station full of them stops absorbing the
-- commons the ladder exists to consume. Once one sells out, the next
-- replacement window swaps in a spare with a fresh output and a fresh cap.
--
-- The choice is derived from (recipe id, window index) alone — no stored state,
-- so every server independently agrees on the same substitution and nothing
-- needs migrating. Rotating recipes are exempt: they already leave and come
-- back on their own.
--------------------------------------------------------------------------------

local GENERATED_VARIANTS = 6 -- bounded, so every possible output can be registered at boot

-- Fallback spares, derived from the recipe being replaced, for when the
-- authored SparePool is exhausted. Deterministic and bounded, which is what
-- lets Init register every output these can ever produce.
function CraftingService.generatedSpares(recipe: any): { any }
	local out = {}
	for n = 1, GENERATED_VARIANTS do
		local inputs = {}
		for itemId, count in recipe.inputs do
			-- each generation asks for a little more, so a long-lived station
			-- keeps getting hungrier rather than looping the same recipe
			inputs[itemId] = count + n
		end
		table.insert(out, {
			rid = ("%s_r%d"):format(recipe.rid, n),
			tier = recipe.tier,
			blurb = recipe.blurb,
			generated = true,
			inputs = inputs,
			output = {
				sku = ("%s_r%d"):format(recipe.output.sku, n),
				name = ("%s Mk%d"):format(recipe.output.name, n + 1),
				totalSupply = math.max(1, math.floor(recipe.output.totalSupply * 0.8)),
				imageId = recipe.output.imageId,
			},
		})
	end
	return out
end

-- Every output the generated fallbacks can ever produce. These exist so a
-- sold-out station always has something to offer, but until one is actually
-- substituted in and crafted it is pure machinery — it must not show up in
-- item pickers, where seven near-identical "Mk" rows bury the real item.
local generatedIds: { [string]: boolean }? = nil
function CraftingService.generatedOutputIds(): { [string]: boolean }
	if generatedIds then
		return generatedIds
	end
	local ids: { [string]: boolean } = {}
	for _, event in EventConfig.Events do
		if not (event.endsAt or event.startsAt) then
			for _, recipe in event.recipes do
				for _, spare in CraftingService.generatedSpares(recipe) do
					ids[outputItemId(spare.output.sku)] = true
				end
			end
		end
	end
	generatedIds = ids
	return ids
end

local soldOutCache: { [string]: { at: number, value: boolean } } = {}
local SOLDOUT_TTL = 15

local function isSoldOut(itemId: string): boolean
	local cached = soldOutCache[itemId]
	if cached and (os.clock() - cached.at) < SOLDOUT_TTL then
		return cached.value
	end
	local snap = EconomyService.snapshot(itemId)
	-- a missing record is NOT sold out: it just hasn't been written yet, and
	-- treating it as exhausted would replace brand-new recipes on sight
	local value = snap ~= nil and (snap.reserveRemaining or 1) <= 0
	soldOutCache[itemId] = { at = os.clock(), value = value }
	return value
end

-- Every candidate that may stand in for `recipe`, in preference order:
-- authored spares first, then generated variants.
local function spareCandidates(recipe: any): { any }
	local candidates = {}
	for _, spare in EventConfig.Replacement.SparePool do
		table.insert(candidates, spare)
	end
	for _, spare in CraftingService.generatedSpares(recipe) do
		table.insert(candidates, spare)
	end
	return candidates
end

-- The recipe a station should actually offer in place of `recipe` right now.
-- Returns `recipe` itself while it still has stock, or when replacement is off.
function CraftingService.substitute(recipe: any, now: number): any
	local rep = EventConfig.Replacement
	if not (rep and rep.enabled) then
		return recipe
	end
	if not isSoldOut(outputItemId(recipe.output.sku)) then
		return recipe
	end

	local windowIdx = Rotation.windowIndex(now, rep.IntervalSeconds)
	local candidates = spareCandidates(recipe)
	if #candidates == 0 then
		return recipe
	end
	-- start from a per-recipe offset so two stations selling out in the same
	-- window don't both grab the same spare, then walk on past any spare that
	-- is itself exhausted
	local offset = #recipe.rid + windowIdx
	for step = 0, #candidates - 1 do
		local candidate = candidates[((offset + step) % #candidates) + 1]
		if not isSoldOut(outputItemId(candidate.output.sku)) then
			return candidate
		end
	end
	return recipe -- everything is spent; show the original as sold out
end

-- Active event descriptors:
-- { id, name, kind, category, endsAt?, rotatesAt?, recipes }
-- category: "permanent" (always-on station) | "limited" (has an end date,
-- i.e. temporary/seasonal) | "rotating" (the windowed recipe set).
function CraftingService.activeEvents(now: number): { any }
	local out = {}
	for _, event in EventConfig.Events do
		if eventActive(event, now) then
			local limited = (event.endsAt or event.startsAt) ~= nil
			-- LIMITED events are meant to end, so a sold-out recipe there stays
			-- sold out; only always-on stations restock with a spare.
			local recipes = event.recipes
			if not limited then
				recipes = {}
				for i, recipe in event.recipes do
					recipes[i] = CraftingService.substitute(recipe, now)
				end
			end
			table.insert(out, {
				id = event.id,
				name = event.name,
				kind = event.kind,
				category = limited and "limited" or "permanent",
				endsAt = event.endsAt,
				recipes = recipes,
			})
		end
	end

	local rot = EventConfig.RotatingRecipes
	if rot and rot.enabled and #rot.Pool > 0 then
		local windowIdx = Rotation.windowIndex(now, rot.RotationIntervalSeconds)
		local picks = Rotation.pick(windowIdx, #rot.Pool, rot.ActiveCount)
		picks = ensureMaterialProducer(rot.Pool, picks, windowIdx)
		local recipes = {}
		for _, poolIndex in picks do
			table.insert(recipes, rot.Pool[poolIndex])
		end
		table.insert(out, {
			id = ROTATING_EVENT_ID,
			name = "Rotating Recipes",
			kind = "crafting",
			category = "rotating",
			rotatesAt = Rotation.windowEndsAt(now, rot.RotationIntervalSeconds),
			recipes = recipes,
		})
	end
	return out
end

-- Window-aware producer lookup for the "need X? craft it at Y" UI hint.
-- EventConfig.producerOf (the static index) doesn't know which rotating
-- recipes are picked THIS window, so it used to point players at a station
-- that was, in practice, closed — the recipe existed in the pool but simply
-- wasn't one of this window's ActiveCount picks. This checks the actual
-- active set first; if a rotating recipe makes the item but isn't active
-- right now, it says so and gives the time the window rotates next, instead
-- of claiming it's craftable when it isn't.
function CraftingService.liveProducerOf(itemId: string, now: number): { name: string, availableNow: boolean, rotatesAt: number? }?
	for _, event in CraftingService.activeEvents(now) do
		for _, recipe in event.recipes do
			if outputItemId(recipe.output.sku) == itemId then
				return { name = event.name, availableNow = true }
			end
		end
	end
	local rot = EventConfig.RotatingRecipes
	if rot and rot.enabled then
		for _, recipe in rot.Pool do
			if outputItemId(recipe.output.sku) == itemId then
				return {
					name = "Rotating Recipes",
					availableNow = false,
					rotatesAt = Rotation.windowEndsAt(now, rot.RotationIntervalSeconds),
				}
			end
		end
	end
	return nil
end

-- Expose for tests: pure pick-with-guarantee for an arbitrary window.
function CraftingService.rotationPicksFor(windowIdx: number): { number }
	local rot = EventConfig.RotatingRecipes
	local picks = Rotation.pick(windowIdx, #rot.Pool, rot.ActiveCount)
	return ensureMaterialProducer(rot.Pool, picks, windowIdx)
end

-- Find an ACTIVE recipe by (eventId, rid). Nil when not currently active.
function CraftingService.findActiveRecipe(eventId: string, rid: string, now: number): any?
	for _, event in CraftingService.activeEvents(now) do
		if event.id == eventId then
			for _, recipe in event.recipes do
				if recipe.rid == rid then
					return recipe
				end
			end
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------------------

local function describeRecipe(recipe: any, profile: any, now: number): any
	local inputs = {}
	local craftable = true
	for itemId, count in recipe.inputs do
		local item = EconomyService.getItem(itemId)
		local owned = profile and (profile.Inventory[itemId] or 0) or 0
		if owned < count then
			craftable = false
		end
		table.insert(inputs, {
			itemId = itemId,
			name = item and item.name or itemId,
			imageId = item and item.imageId or nil,
			count = count,
			owned = owned,
			-- event-item inputs say WHERE they're made (and whether that's
			-- actually open THIS rotation), so the UI can point a player at a
			-- real source instead of a dead end
			from = itemId:sub(1, 4) == "evt_" and CraftingService.liveProducerOf(itemId, now) or nil,
		})
	end
	table.sort(inputs, function(a, b)
		return a.itemId < b.itemId
	end)
	if profile and (recipe.gems or 0) > profile.Gems then
		craftable = false
	end

	local outId = recipeOutputId(recipe)
	local snap = EconomyService.snapshot(outId)
	-- NO RECORD MEANS NOTHING HAS BEEN TAKEN YET, so the reserve is full — it
	-- must NOT read as 0, which is "fully crafted". Getting this backwards makes
	-- a brand-new (or freshly reset) recipe look permanently sold out.
	--
	-- This is also why the number is read live on every GetEvents rather than
	-- cached client-side: consumed inputs are REDISTRIBUTED back into an item's
	-- reserve (crafting, roll item-payments), so a recipe that was fully crafted
	-- can legitimately become available again and the UI has to notice.
	-- A Unique Craft outputs an item that already exists, so its cap lives on
	-- the ITEM, not on the recipe — fall back to the snapshot for both halves
	-- or the row renders "?/? left".
	local total = recipe.output.totalSupply or (snap and snap.totalSupply)
	local remaining = snap and snap.reserveRemaining or total
	return {
		rid = recipe.rid,
		tier = recipe.tier or 1,
		blurb = recipe.blurb,
		inputs = inputs,
		gems = recipe.gems or 0,
		craftable = craftable,
		output = {
			itemId = outId,
			name = recipe.output.name,
			imageId = recipe.output.imageId,
			remaining = remaining,
			total = total,
		},
	}
end

local function handleGetEvents(player: Player)
	local profile = DataService.getProfile(player)
	local now = os.time()
	local events = {}
	for _, event in CraftingService.activeEvents(now) do
		local recipes = {}
		for _, recipe in event.recipes do
			table.insert(recipes, describeRecipe(recipe, profile, now))
		end
		table.insert(events, {
			id = event.id,
			name = event.name,
			kind = event.kind,
			category = event.category,
			endsAt = event.endsAt,
			rotatesAt = event.rotatesAt,
			recipes = recipes,
		})
	end

	-- the player's own Unique Craft, rendered through the same recipe shape as
	-- everything else. Listed FIRST: it is the one thing on this screen that is
	-- theirs alone and it expires, so it should not be buried under the ladder.
	local uniques = uniqueCrafts().recipesFor(player, now)
	if #uniques > 0 then
		local described = {}
		for _, recipe in uniques do
			table.insert(described, describeRecipe(recipe, profile, now))
		end
		table.insert(events, 1, {
			id = UNIQUE_EVENT_ID,
			name = "Unique Crafts",
			kind = "crafting",
			category = "unique",
			recipes = described,
		})
	end
	return { ok = true, events = events, now = now }
end

-- The FULL static ladder — every recipe that exists, regardless of whether
-- this rotation window happens to have it active. GetEvents only ever shows
-- what's craftable RIGHT NOW; the recipe-chain view needs the whole graph so
-- a player can see what a Tier 3 grail eats even when the Tier 1/2 recipes
-- feeding it aren't this window's picks. Read-only, no gating — this is what
-- makes the ladder legible.
local function handleGetRecipeGraph(player: Player)
	local profile = DataService.getProfile(player)
	local now = os.time()
	local out = {}
	for _, event in EventConfig.Events do
		if event.enabled then
			for _, recipe in event.recipes do
				table.insert(out, {
					eventId = event.id,
					eventName = event.name,
					recipe = describeRecipe(recipe, profile, now),
				})
			end
		end
	end
	local rot = EventConfig.RotatingRecipes
	if rot and rot.enabled then
		for _, recipe in rot.Pool do
			table.insert(out, {
				eventId = ROTATING_EVENT_ID,
				eventName = "Rotating Recipes",
				recipe = describeRecipe(recipe, profile, now),
			})
		end
	end
	-- the player's own Unique Craft, or its "How to make" tree would find no
	-- producer for the output and draw a single lonely node
	for _, recipe in uniqueCrafts().recipesFor(player, now) do
		table.insert(out, {
			eventId = UNIQUE_EVENT_ID,
			eventName = "Unique Crafts",
			recipe = describeRecipe(recipe, profile, now),
		})
	end
	return { ok = true, recipes = out }
end

-- Bots craft too; their charges/grants live in BotService state.
local function bots(): any
	return require(script.Parent.BotService)
end

local function craftCore(userId: number, eventId: any, rid: any)
	if not Guard.isString(eventId, 64) or not Guard.isString(rid, 64) then
		return { ok = false, err = "bad_args" }
	end

	local isBot = userId < 0
	local player = if isBot then nil else Players:GetPlayerByUserId(userId)

	local recipe
	if eventId == UNIQUE_EVENT_ID then
		-- per-player, so it resolves from the player's own offer rather than
		-- the global active set (and a bot can never hold one)
		recipe = if player then uniqueCrafts().recipeByRid(player, rid :: string, os.time()) else nil
	else
		recipe = CraftingService.findActiveRecipe(eventId :: string, rid :: string, os.time())
	end
	if recipe == nil then
		return { ok = false, err = "recipe_not_active" }
	end
	local outId = recipeOutputId(recipe)

	local function delta(d: any, source: string): (boolean, string?)
		if isBot then
			return bots().applyDelta(userId, d, source)
		end
		if player == nil then
			return false, "loading"
		end
		return InventoryService.applyDelta(player, d, source)
	end

	-- charge all inputs atomically (validate-all-then-apply)
	local negInputs = {}
	for itemId, count in recipe.inputs do
		negInputs[itemId] = -count
	end
	local charged, chargeErr = delta(
		{ items = negInputs, gems = -(recipe.gems or 0) },
		Enums.GrantSource.Craft
	)
	if not charged then
		return { ok = false, err = chargeErr } -- insufficient_items / insufficient_gems
	end

	-- take one output copy from the uncrafted reserve. Bots use the lazy
	-- in-memory path (leader-local, no per-craft DataStore write) so a busy
	-- 500-bot sweep never stalls the shared request budget; players keep the
	-- strong cross-server CAS.
	local reserved = if isBot then EconomyService.reserveOneLazy(outId) else EconomyService.reserveOne(outId)
	if not reserved then
		-- fully crafted elsewhere: give everything back
		local posInputs = {}
		for itemId, count in recipe.inputs do
			posInputs[itemId] = count
		end
		delta({ items = posInputs, gems = recipe.gems or 0 }, Enums.GrantSource.Refund)
		return { ok = false, err = "recipe_soldout" }
	end

	-- consumed inputs go back to the shared reserve — redistributed, never
	-- destroyed (see the file header). Bots restock lazily (see reserveOneLazy).
	local touched = {}
	for itemId, count in recipe.inputs do
		if isBot then
			EconomyService.restockCopiesLazy(itemId, count)
		else
			EconomyService.restockCopies(itemId, count)
		end
		table.insert(touched, itemId)
	end

	delta({ items = { [outId] = 1 } }, Enums.GrantSource.Craft)
	if player then
		task.spawn(function()
			DataService.saveNow(player)
		end)
	end

	-- syndicate XP for the craft. Lazy require: SyndicateService pulls in
	-- Data/Inventory, and requiring it at the top would form a cycle. Bots have
	-- no syndicate, so this is players only.
	if not isBot then
		local ok, Syndicate = pcall(function()
			return require(script.Parent.SyndicateService)
		end)
		if ok then
			Syndicate.addXp(userId, "craft")
		end
		-- milestone + communal-goal progress. Bots are excluded on purpose: a
		-- communal goal bots can finish isn't a communal goal.
		if player then
			local okProgress, Progress = pcall(function()
				return require(script.Parent.EventProgressService)
			end)
			if okProgress then
				Progress.recordCraft(player)
			end
		end
	end

	AnalyticsService.log("craft", {
		userId = userId,
		eventId = eventId,
		rid = rid,
		output = outId,
		gems = recipe.gems or 0,
	})
	return { ok = true, output = { itemId = outId, name = recipe.output.name } }
end

local function handleCraft(player: Player, eventId: any, rid: any)
	if not DataService.isLoaded(player) then
		return { ok = false, err = "loading" }
	end
	return craftCore(player.UserId, eventId, rid)
end

-- Bot entry points + helpers
function CraftingService.botCraft(botId: number, eventId: string, rid: string)
	return craftCore(botId, eventId, rid)
end

function CraftingService.outputIdFor(sku: string): string
	return outputItemId(sku)
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function CraftingService.Init()
	-- register every possible output up front (idempotent), so recipes from
	-- any rotation window resolve on any server
	local defs = {}
	local function addOutput(recipe: any, poolId: string)
		table.insert(defs, {
			itemId = outputItemId(recipe.output.sku),
			poolId = poolId,
			name = recipe.output.name,
			totalSupply = recipe.output.totalSupply,
			assignmentWeight = 0, -- never part of starter draws
			imageId = recipe.output.imageId,
			eventItem = true, -- no store cost: displays "N/A (Event Item)"
		})
	end
	for _, event in EventConfig.Events do
		for _, recipe in event.recipes do
			addOutput(recipe, event.id)
		end
	end
	if EventConfig.RotatingRecipes then
		for _, recipe in EventConfig.RotatingRecipes.Pool do
			addOutput(recipe, ROTATING_EVENT_ID)
		end
	end
	-- Replacement outputs are registered NOW, not when a substitution first
	-- happens: a recipe swapped in mid-session must already have an economy
	-- record, or its very first craft would fail with no reserve to draw from.
	-- Generated variants are bounded (GENERATED_VARIANTS), which is what makes
	-- enumerating them here possible at all.
	local rep = EventConfig.Replacement
	if rep and rep.enabled then
		for _, spare in rep.SparePool do
			addOutput(spare, "evt_replacement")
		end
		for _, event in EventConfig.Events do
			if not (event.endsAt or event.startsAt) then
				for _, recipe in event.recipes do
					for _, spare in CraftingService.generatedSpares(recipe) do
						addOutput(spare, event.id)
					end
				end
			end
		end
	end
	EconomyService.registerItems(defs)

	-- a config mistake here means an event that can NEVER be crafted — shout
	for _, violation in CraftingService.validateRecipeGraph() do
		warn("[Crafting] UNREACHABLE RECIPE: " .. violation)
	end
end

function CraftingService.Start()
	Net.bindFunction("GetEvents", handleGetEvents)
	Net.bindFunction("GetRecipeGraph", handleGetRecipeGraph)
	Net.bindFunction("CraftItem", handleCraft)

	-- prewarm output records so the events screen opens instantly
	task.spawn(function()
		for _, event in CraftingService.activeEvents(os.time()) do
			for _, recipe in event.recipes do
				EconomyService.snapshot(outputItemId(recipe.output.sku))
			end
		end
	end)
end

return CraftingService
