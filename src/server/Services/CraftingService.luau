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

local CraftingService = {}

local function outputItemId(sku: string): string
	return "evt_" .. sku
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

-- Active event descriptors:
-- { id, name, kind, category, endsAt?, rotatesAt?, recipes }
-- category: "permanent" (always-on station) | "limited" (has an end date,
-- i.e. temporary/seasonal) | "rotating" (the windowed recipe set).
function CraftingService.activeEvents(now: number): { any }
	local out = {}
	for _, event in EventConfig.Events do
		if eventActive(event, now) then
			table.insert(out, {
				id = event.id,
				name = event.name,
				kind = event.kind,
				category = (event.endsAt or event.startsAt) and "limited" or "permanent",
				endsAt = event.endsAt,
				recipes = event.recipes,
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

	local outId = outputItemId(recipe.output.sku)
	local snap = EconomyService.snapshot(outId)
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
			remaining = snap and snap.reserveRemaining or 0,
			total = recipe.output.totalSupply,
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

	local recipe = CraftingService.findActiveRecipe(eventId :: string, rid :: string, os.time())
	if recipe == nil then
		return { ok = false, err = "recipe_not_active" }
	end
	local outId = outputItemId(recipe.output.sku)

	local isBot = userId < 0
	local player = if isBot then nil else Players:GetPlayerByUserId(userId)
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
