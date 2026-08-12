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
-- WHERE THE STATE LIVES. On the player's profile (Profile.UniqueCraft), so it
-- saves with everything else and survives a rejoin. One offer at a time.
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

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
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
			produced["evt_" .. recipe.output.sku] = true
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
function UniqueCraftService.buildOffer(outputs: { any }, inputs: { any }, rng: Random, at: number, owned: { [string]: number }?): any?
	if #outputs == 0 or #inputs == 0 then
		return nil
	end
	local settings = cfg()
	local have = owned or {}

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
	local chosen, inputValue, anyShortfall = {}, 0, false
	local picked = 0
	for _ = 1, kinds do
		local candidate = pool[rng:NextInteger(1, cheapCount)]
		if candidate and chosen[candidate.itemId] == nil then
			local count = rng:NextInteger(settings.CountPerInput.min, settings.CountPerInput.max)
			chosen[candidate.itemId] = count
			inputValue += candidate.value * count
			picked += 1
			if count > (have[candidate.itemId] or 0) then
				anyShortfall = true
			end
		end
	end
	if picked == 0 or inputValue <= 0 then
		return nil
	end
	-- An offer fillable from the shelf teaches nothing and moves nothing: the
	-- whole point is to send the player out to buy or trade for the parts.
	if not anyShortfall and owned ~= nil then
		return nil
	end

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

-- The player's live offer, or nil. Expired offers are cleared here rather than
-- on a timer, so an offline player's clock still runs out correctly.
function UniqueCraftService.offerFor(player: Player, now: number): any?
	local profile = DataService.getProfile(player)
	if profile == nil or not cfg().enabled then
		return nil
	end
	local offer = profile.UniqueCraft
	if offer == nil then
		return nil
	end
	if (offer.expiresAt or 0) <= now then
		profile.UniqueCraft = nil
		profile.UniqueCraftNextAt = now + cfg().CooldownSeconds
		return nil
	end
	return offer
end

-- Offer one if they don't have one and the cooldown has passed. Safe to call
-- often — it no-ops unless there is actually something to hand out.
function UniqueCraftService.maybeOffer(player: Player, now: number): any?
	if not cfg().enabled then
		return nil
	end
	local profile = DataService.getProfile(player)
	if profile == nil then
		return nil
	end
	if UniqueCraftService.offerFor(player, now) ~= nil then
		return profile.UniqueCraft
	end
	if (profile.UniqueCraftNextAt or 0) > now then
		return nil
	end

	local rng = Random.new(now + player.UserId)
	local outputs = UniqueCraftService.outputCandidates(now)
	local inputs = inputCandidates()
	-- a given output may have nothing cheap enough to ask for; try a few before
	-- giving up so one awkward item doesn't deny the player an offer entirely
	local offer = nil
	for _ = 1, 8 do
		offer = UniqueCraftService.buildOffer(outputs, inputs, rng, now, profile.Inventory)
		if offer ~= nil then
			break
		end
	end
	if offer == nil then
		return nil
	end
	profile.UniqueCraft = offer
	task.spawn(function()
		DataService.saveNow(player)
	end)
	NotificationService.notify(
		player.UserId,
		("Unique Craft unlocked: %s — gather the parts and make one."):format(offer.outputName)
	)
	AnalyticsService.log("unique_craft_offered", {
		userId = player.UserId, output = offer.outputItemId,
	})
	return offer
end

-- The offer expressed as an ordinary recipe, so it renders and crafts through
-- exactly the same code path as every other recipe.
function UniqueCraftService.recipeFor(player: Player, now: number): any?
	local offer = UniqueCraftService.offerFor(player, now)
	if offer == nil then
		return nil
	end
	return {
		rid = "unique",
		tier = 2,
		blurb = "Only you can make this, and only for a while. Buy or trade for the parts.",
		inputs = offer.inputs,
		unique = true,
		output = {
			-- an EXISTING item: sku is derived back to its real id, so the
			-- craft draws on that item's own reserve and cap like anything else
			sku = offer.outputItemId,
			itemId = offer.outputItemId,
			name = offer.outputName,
			imageId = offer.outputImageId,
		},
		expiresAt = offer.expiresAt,
	}
end

function UniqueCraftService.eventId(): string
	return UNIQUE_EVENT_ID
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function UniqueCraftService.Init() end

function UniqueCraftService.Start()
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
