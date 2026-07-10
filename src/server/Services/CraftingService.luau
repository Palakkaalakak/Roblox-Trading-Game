--!strict
-- CraftingService: limited events — crafting, sacrifices, rotating recipes.
--
-- Every recipe consumes inputs (items and/or gems) and produces one copy of a
-- LIMITED output item. Output stock is the item's reserve, taken with the
-- same atomic cross-server CAS as store buys and starter draws — when the
-- last copy is crafted the recipe stops working everywhere at once
-- ("Fully crafted!"). Consumed input items are RETIRED from circulation (a
-- real sink: existence counts drop). Outputs are ordinary tradeable items
-- with Store Cost "N/A (Event Item)".
--
-- Active-recipe resolution is a PURE function of the wall clock (enabled
-- flags + start/end windows + deterministic rotation), so every server
-- agrees with zero coordination.
--
-- Craft flow: resolve active recipe -> charge inputs (atomic in-memory) ->
-- reserve output copy (CAS; refund inputs if it lost the race) -> retire
-- consumed copies -> grant output -> async save.

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

-- Active event descriptors: { id, name, kind, endsAt?, rotatesAt?, recipes }
function CraftingService.activeEvents(now: number): { any }
	local out = {}
	for _, event in EventConfig.Events do
		if eventActive(event, now) then
			table.insert(out, {
				id = event.id,
				name = event.name,
				kind = event.kind,
				endsAt = event.endsAt,
				recipes = event.recipes,
			})
		end
	end

	local rot = EventConfig.RotatingRecipes
	if rot and rot.enabled and #rot.Pool > 0 then
		local windowIdx = Rotation.windowIndex(now, rot.RotationIntervalSeconds)
		local recipes = {}
		for _, poolIndex in Rotation.pick(windowIdx, #rot.Pool, rot.ActiveCount) do
			table.insert(recipes, rot.Pool[poolIndex])
		end
		table.insert(out, {
			id = ROTATING_EVENT_ID,
			name = "Rotating Recipes",
			kind = "crafting",
			rotatesAt = Rotation.windowEndsAt(now, rot.RotationIntervalSeconds),
			recipes = recipes,
		})
	end
	return out
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

local function describeRecipe(recipe: any, profile: any): any
	local inputs = {}
	for itemId, count in recipe.inputs do
		local item = EconomyService.getItem(itemId)
		table.insert(inputs, {
			itemId = itemId,
			name = item and item.name or itemId,
			imageId = item and item.imageId or nil,
			count = count,
			owned = profile and (profile.Inventory[itemId] or 0) or 0,
		})
	end
	table.sort(inputs, function(a, b)
		return a.itemId < b.itemId
	end)

	local outId = outputItemId(recipe.output.sku)
	local snap = EconomyService.snapshot(outId)
	return {
		rid = recipe.rid,
		inputs = inputs,
		gems = recipe.gems or 0,
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
			table.insert(recipes, describeRecipe(recipe, profile))
		end
		table.insert(events, {
			id = event.id,
			name = event.name,
			kind = event.kind,
			endsAt = event.endsAt,
			rotatesAt = event.rotatesAt,
			recipes = recipes,
		})
	end
	return { ok = true, events = events, now = now }
end

local function handleCraft(player: Player, eventId: any, rid: any)
	if not DataService.isLoaded(player) then
		return { ok = false, err = "loading" }
	end
	if not Guard.isString(eventId, 64) or not Guard.isString(rid, 64) then
		return { ok = false, err = "bad_args" }
	end

	local recipe = CraftingService.findActiveRecipe(eventId :: string, rid :: string, os.time())
	if recipe == nil then
		return { ok = false, err = "recipe_not_active" }
	end
	local outId = outputItemId(recipe.output.sku)

	-- charge all inputs atomically (validate-all-then-apply)
	local negInputs = {}
	for itemId, count in recipe.inputs do
		negInputs[itemId] = -count
	end
	local charged, chargeErr = InventoryService.applyDelta(
		player,
		{ items = negInputs, gems = -(recipe.gems or 0) },
		Enums.GrantSource.Craft
	)
	if not charged then
		return { ok = false, err = chargeErr } -- insufficient_items / insufficient_gems
	end

	-- take one output copy from the uncrafted reserve (atomic cross-server)
	local reserved = EconomyService.reserveOne(outId)
	if not reserved then
		-- fully crafted elsewhere: give everything back
		local posInputs = {}
		for itemId, count in recipe.inputs do
			posInputs[itemId] = count
		end
		InventoryService.applyDelta(player, { items = posInputs, gems = recipe.gems or 0 }, Enums.GrantSource.Refund)
		return { ok = false, err = "recipe_soldout" }
	end

	-- consumed inputs leave existence (the sink)
	local touched = {}
	for itemId, count in recipe.inputs do
		EconomyService.retireCopies(itemId, count)
		table.insert(touched, itemId)
	end

	InventoryService.applyDelta(player, { items = { [outId] = 1 } }, Enums.GrantSource.Craft)
	task.spawn(function()
		DataService.saveNow(player)
	end)

	AnalyticsService.log("craft", {
		userId = player.UserId,
		eventId = eventId,
		rid = rid,
		output = outId,
		gems = recipe.gems or 0,
	})
	return { ok = true, output = { itemId = outId, name = recipe.output.name } }
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
end

function CraftingService.Start()
	Net.bindFunction("GetEvents", handleGetEvents)
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
