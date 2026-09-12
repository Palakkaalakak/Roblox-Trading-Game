--!strict
-- UniqueCraftService: the per-player "Unique Craft" offer.
--
-- WHAT IT IS. A player is temporarily allowed to craft an item that already
-- exists in the game and already has supply, but that no live recipe currently
-- produces. It is not a new item and it is not unique to them — only the
-- ACCESS is theirs, and only for a while.
--
-- WHY. Everyone chasing the same recipes makes players each other's
-- competitors instead of each other's counterparties, and competitors don't
-- trade much. A unique craft drops one player into the market with a shopping
-- list nobody else is bidding against, so they can actually fill it — and
-- whoever happens to be holding those inputs suddenly has a buyer. That second
-- half is the point: it is how a brand-new player sells something without
-- knowing the first thing about trading.
--
-- WHERE THE STATE LIVES. On the player's profile (Profile.UniqueCrafts, keyed
-- by slot), so it saves with everything else and survives a rejoin.
--
-- SLOTS. Everyone starts with one. Further slots are bought with gems and
-- kept forever, each holding an independent offer with its own expiry and
-- cooldown. That is a deliberate gem SINK -- gems only enter through ads and
-- Robux -- and it scales the mechanic with investment: more slots means more
-- shopping lists in the market at once, which is more demand for everyone.
--
-- HOW THE OFFER IS BUILT. Output: an item whose rarity is eligible, which has
-- reserve left, and which no live recipe produces. Inputs: a few items priced
-- so the whole list costs a FRACTION of what the output is worth (see
-- EventConfig.UniqueCraft.InputValueFraction). That margin is deliberate — the
-- player can read both numbers off the UI and work out that it's worth doing,
-- which is the entire trading lesson in one action.
--
-- The offer is generated per player and never shared, so two players can hold
-- different offers for the same output without interfering; the output's own
-- reserve is still the hard cap on how many can ever exist.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NotificationService = require(script.Parent.NotificationService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local UNIQUE_EVENT_ID = "evt_unique"

local UniqueCraftService = {}

local function cfg()
	return EventConfig.UniqueCraft
end

--------------------------------------------------------------------------------
-- Candidate pools
--------------------------------------------------------------------------------

-- Every itemId some live recipe already produces. Those are excluded as
-- outputs: the whole point is to open up something that ISN'T otherwise
-- craftable right now.
local function producedIds(now: number): { [string]: boolean }
	local produced: { [string]: boolean } = {}
	local CraftingService = require(script.Parent.CraftingService)
	for _, event in CraftingService.activeEvents(now) do
		for _, recipe in event.recipes do
			produced[CraftingService.recipeOutputId(recipe)] = true
		end
	end
	-- Generated sold-out replacements ("... Mk3") are internal machinery, not
	-- things a player should ever be sent hunting for. Excluded outright.
	for itemId in CraftingService.generatedOutputIds() do
		produced[itemId] = true
	end
	return produced
end

-- Items eligible to be the OUTPUT. Three rules, in order of why they matter:
--
--   1. RE-OBTAINABLE. Outputs of limited/seasonal events are excluded — the
--      same EventConfig.isReobtainable check rolls use. A seasonal exclusive
--      that has ended must stay ended; re-minting one through a unique craft
--      would quietly undo the promise that it can never be made again.
--   2. NOT CURRENTLY CRAFTABLE. If some live recipe already produces it, this
--      grants nothing — the whole point is opening up something that is
--      otherwise closed right now.
--   3. STOCK LEFT. Crafting draws on the item's own reserve, so a fully
--      distributed item has nothing to give.
function UniqueCraftService.outputCandidates(now: number): { any }
	local produced = producedIds(now)
	local excludeRarity: { [string]: boolean } = {}
	for _, rarity in (cfg().ExcludeRarities or {}) do
		excludeRarity[rarity] = true
	end

	local out = {}
	for _, itemId in EconomyService.allItemIds() do
		if not produced[itemId] and EventConfig.isReobtainable(itemId) then
			local item = EconomyService.getItem(itemId)
			if item and not excludeRarity[item.rarity or ""] then
				local snap = EconomyService.snapshot(itemId)
				if snap and (snap.reserveRemaining or 0) > 0 then
					table.insert(out, { itemId = itemId, snapshot = snap })
				end
			end
		end
	end
	return out
end

-- Items eligible to be INPUTS: anything cheap enough to be worth asking for in
-- quantity. Event outputs are excluded — a list should be fillable off the
-- market, not gated behind another recipe the player may not have access to.
local function inputCandidates(): { any }
	local allowed: { [string]: boolean } = {}
	for _, rarity in (cfg().InputRarities or {}) do
		allowed[rarity] = true
	end
	local out = {}
	for _, itemId in EconomyService.allItemIds() do
		if itemId:sub(1, 4) ~= "evt_" then
			local snap = EconomyService.snapshot(itemId)
			if snap and allowed[snap.rarity or ""] and (snap.value and snap.value.value or 0) > 0 then
				table.insert(out, { itemId = itemId, value = snap.value.value })
			end
		end
	end
	table.sort(out, function(a, b)
		return a.itemId < b.itemId -- deterministic base order; shuffled per roll
	end)
	return out
end

--------------------------------------------------------------------------------
-- Building an offer
--------------------------------------------------------------------------------

-- Pure given its candidate lists and a seeded Random, so the shape of an offer
-- is testable without a live economy.
-- `owned` is accepted for signature/call-site compatibility (callers still
-- pass the player's inventory) but no longer consulted here — see the note
-- below the input-picking loop for why.
function UniqueCraftService.buildOffer(outputs: { any }, inputs: { any }, rng: Random, at: number, owned: { [string]: number }?): any?
	if #outputs == 0 or #inputs == 0 then
		return nil
	end
	local settings = cfg()

	-- INPUTS FIRST, OUTPUT TO SUIT. Sizing counts from the output's value made a
	-- Godly ask for 25x of everything, which no new player can reach. Picking a
	-- few cheap items in small counts and then finding an output worth
	-- proportionally more keeps every offer to roughly "three commons for a
	-- rare", whatever the catalogue happens to contain.
	local pool = table.clone(inputs)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	-- cheapest-leaning: sort the shuffled pool by value so a list is built from
	-- the low end of the catalogue rather than whatever landed first
	table.sort(pool, function(a, b)
		return a.value < b.value
	end)
	local cheapCount = math.max(math.min(#pool, math.ceil(#pool * 0.6)), 1)

	local kinds = rng:NextInteger(settings.InputKinds.min, settings.InputKinds.max)
	local chosen, inputValue = {}, 0
	local picked = 0
	for _ = 1, kinds do
		local candidate = pool[rng:NextInteger(1, cheapCount)]
		if candidate and chosen[candidate.itemId] == nil then
			local count = rng:NextInteger(settings.CountPerInput.min, settings.CountPerInput.max)
			chosen[candidate.itemId] = count
			inputValue += candidate.value * count
			picked += 1
		end
	end
	if picked == 0 or inputValue <= 0 then
		return nil
	end
	-- Inputs are drawn from the general cheap-leaning pool, not filtered to what
	-- the player already owns, so whether this list happens to be immediately
	-- fillable is incidental, not something to force either way. An offer the
	-- player can complete right now is a legitimate outcome (instant payoff,
	-- especially valuable for a fresh player whose starter bundle happens to
	-- cover it, or a player liquidating a rare into commons via a
	-- Dilute-shaped offer) exactly as much as one that sends them to the
	-- market is. Forcing every offer to require a trip out used to be the
	-- rule; it no longer is — both are correct, and which one shows up is
	-- just whatever the random draw against the player's real holdings
	-- produces.

	-- Now find an output worth enough that the inputs cost InputValueFraction of
	-- it -- i.e. the craft is visibly worth doing from numbers already on screen.
	local fraction = settings.InputValueFraction.min
		+ rng:NextNumber() * (settings.InputValueFraction.max - settings.InputValueFraction.min)
	local wanted = inputValue / fraction
	local tolerance = settings.OutputValueTolerance

	local viable = {}
	for _, candidate in outputs do
		local value = (candidate.snapshot.value and candidate.snapshot.value.value) or 0
		if value > inputValue and value <= wanted * tolerance then
			table.insert(viable, candidate)
		end
	end
	if #viable == 0 then
		return nil -- nothing proportionate; caller retries with a different list
	end
	local pick = viable[rng:NextInteger(1, #viable)]

	return {
		outputItemId = pick.itemId,
		outputName = pick.snapshot.name,
		outputImageId = pick.snapshot.imageId,
		outputValue = (pick.snapshot.value and pick.snapshot.value.value) or 0,
		inputs = chosen,
		expiresAt = at + settings.DurationSeconds,
	}
end

--------------------------------------------------------------------------------
-- Per-player offer lifecycle
--------------------------------------------------------------------------------

-- How many slots this player has unlocked. Everyone has at least one.
function UniqueCraftService.slotsFor(profile: any): number
	local owned = (profile and profile.UniqueCraftSlots) or 1
	return math.clamp(owned, 1, EventConfig.maxUniqueSlots())
end

-- Live offers, indexed by slot. An expired offer is cleared here rather than on
-- a timer, so an offline player's clock still runs out correctly and each slot
-- starts its own cooldown independently.
function UniqueCraftService.offersFor(player: Player, now: number): { any }
	local profile = DataService.getProfile(player)
	if profile == nil or not cfg().enabled then
		return {}
	end
	profile.UniqueCrafts = profile.UniqueCrafts or {}
	profile.UniqueCraftNextAt = profile.UniqueCraftNextAt or {}

	local slots = UniqueCraftService.slotsFor(profile)
	local live = {}
	for slot = 1, slots do
		local offer = profile.UniqueCrafts[slot]
		if offer ~= nil then
			if (offer.expiresAt or 0) <= now then
				profile.UniqueCrafts[slot] = nil
				profile.UniqueCraftNextAt[slot] = now + cfg().CooldownSeconds
			else
				live[slot] = offer
			end
		end
	end
	return live
end

-- Fill any empty slot whose cooldown has passed. Safe to call often — it
-- no-ops unless there is actually something to hand out.
function UniqueCraftService.maybeOffer(player: Player, now: number)
	if not cfg().enabled then
		return
	end
	local profile = DataService.getProfile(player)
	if profile == nil then
		return
	end
	local live = UniqueCraftService.offersFor(player, now)
	local slots = UniqueCraftService.slotsFor(profile)

	local outputs, inputs = nil, nil
	local granted = false
	for slot = 1, slots do
		if live[slot] == nil and (profile.UniqueCraftNextAt[slot] or 0) <= now then
			-- built lazily: most calls fill nothing and shouldn't pay for the scan
			outputs = outputs or UniqueCraftService.outputCandidates(now)
			inputs = inputs or inputCandidates()
			-- seed varies per slot so two slots never draw the same offer
			local rng = Random.new(now + player.UserId * 31 + slot * 7919)
			local offer = nil
			for _ = 1, 8 do
				offer = UniqueCraftService.buildOffer(outputs, inputs, rng, now, profile.Inventory)
				-- two slots offering the same output would read as a duplicate
				if offer ~= nil then
					local clash = false
					for _, other in profile.UniqueCrafts do
						if other and other.outputItemId == offer.outputItemId then
							clash = true
						end
					end
					if not clash then
						break
					end
					offer = nil
				end
			end
			if offer ~= nil then
				profile.UniqueCrafts[slot] = offer
				granted = true
				NotificationService.notify(
					player.UserId,
					("Unique Craft unlocked: %s — gather the parts and make one."):format(offer.outputName)
				)
				AnalyticsService.log("unique_craft_offered", {
					userId = player.UserId, output = offer.outputItemId, slot = slot,
				})
			end
		end
	end
	if granted then
		task.spawn(function()
			DataService.saveNow(player)
		end)
	end
end

-- Unlock the next slot for gems. Permanent once bought.
function UniqueCraftService.buySlot(player: Player): any
	local profile = DataService.getProfile(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local current = UniqueCraftService.slotsFor(profile)
	local nextSlot = current + 1
	local cost = EventConfig.uniqueSlotCost(nextSlot)
	if cost == nil then
		return { ok = false, err = "max_slots" }
	end
	local paid = InventoryService.applyDelta(player, { gems = -cost }, "unique_slot")
	if not paid then
		return { ok = false, err = "insufficient_gems" }
	end
	profile.UniqueCraftSlots = nextSlot
	task.spawn(function()
		DataService.saveNow(player)
	end)
	-- fill it straight away, or the purchase does nothing visible until the
	-- next sweep and reads as broken
	UniqueCraftService.maybeOffer(player, os.time())
	AnalyticsService.log("unique_slot_bought", { userId = player.UserId, slot = nextSlot, gems = cost })
	return { ok = true, slots = nextSlot }
end

-- What the client needs to render the tab: every live offer plus the price of
-- the next slot (nil when they own them all).
function UniqueCraftService.stateFor(player: Player, now: number): any
	local profile = DataService.getProfile(player)
	if profile == nil then
		return { ok = false, err = "loading" }
	end
	local slots = UniqueCraftService.slotsFor(profile)
	local live = UniqueCraftService.offersFor(player, now)
	local rows = {}
	for slot = 1, slots do
		local offer = live[slot]
		table.insert(rows, {
			slot = slot,
			offer = offer,
			-- an empty slot is waiting, not broken: say when it refills
			refillsAt = offer == nil and (profile.UniqueCraftNextAt[slot] or now) or nil,
		})
	end
	return {
		ok = true,
		slots = slots,
		maxSlots = EventConfig.maxUniqueSlots(),
		nextSlotCost = EventConfig.uniqueSlotCost(slots + 1),
		rows = rows,
		now = now,
	}
end

-- An offer expressed as an ordinary recipe, so it renders and crafts through
-- exactly the same code path as every other recipe.
local function asRecipe(offer: any, slot: number): any
	return {
		rid = "unique_" .. tostring(slot),
		tier = 2,
		blurb = "Only you can make this, and only for a while. Buy or trade for the parts.",
		inputs = offer.inputs,
		unique = true,
		slot = slot,
		output = {
			-- an EXISTING item: the sku IS its real id, so the craft draws on that
			-- item's own reserve and cap like anything else
			sku = offer.outputItemId,
			itemId = offer.outputItemId,
			name = offer.outputName,
			imageId = offer.outputImageId,
		},
		expiresAt = offer.expiresAt,
	}
end

function UniqueCraftService.recipesFor(player: Player, now: number): { any }
	local out = {}
	for slot, offer in UniqueCraftService.offersFor(player, now) do
		table.insert(out, asRecipe(offer, slot))
	end
	table.sort(out, function(a, b)
		return a.slot < b.slot
	end)
	return out
end

-- Resolve one recipe by its rid, for crafting.
function UniqueCraftService.recipeByRid(player: Player, rid: string, now: number): any?
	for _, recipe in UniqueCraftService.recipesFor(player, now) do
		if recipe.rid == rid then
			return recipe
		end
	end
	return nil
end

function UniqueCraftService.eventId(): string
	return UNIQUE_EVENT_ID
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function UniqueCraftService.Init() end

function UniqueCraftService.Start()
	Net.bindFunction("GetUniqueCrafts", function(player)
		return UniqueCraftService.stateFor(player, os.time())
	end)
	Net.bindFunction("BuyUniqueCraftSlot", function(player)
		return UniqueCraftService.buySlot(player)
	end)

	-- offer one shortly after a profile loads, so a brand-new player has a
	-- concrete thing to chase before they have any idea what the game is
	DataService.ProfileLoaded:Connect(function(player)
		task.delay(5, function()
			if player.Parent then
				UniqueCraftService.maybeOffer(player, os.time())
			end
		end)
	end)

	-- and top players up as their offers lapse
	task.spawn(function()
		while true do
			task.wait(60)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				if DataService.isLoaded(player) then
					UniqueCraftService.maybeOffer(player, now)
				end
			end
		end
	end)
end

return UniqueCraftService
