--!strict
-- RollService: spend gems -> receive one item. The gacha.
--
-- This is the main REASONED path for new goods entering the economy. Nothing
-- appears on a timer: every item minted here was paid for in gems that somebody
-- earned by selling something another trader wanted.
--
-- Pay more -> better odds. A tier's `luck` flattens the draw curve
-- (weight = assignmentWeight ^ (1/luck)); see RollConfig for the reasoning.
--
-- HARD RULE: only items with reserve remaining can be rolled. The last copy of
-- a limited leaves the reserve and that item is gone from the pool forever.
-- Reserve is taken with the SAME atomic CAS as store buys and starter draws, so
-- an item can never be over-distributed (circulating can never exceed
-- totalSupply) no matter how many servers roll at once.
--
-- Roll flow: resolve tier -> charge gems -> reserve a copy (refund if the pool
-- lost the race) -> grant.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Enums)
local RollConfig = require(ReplicatedStorage.Shared.Config.RollConfig)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local RollService = {}

local function bots(): any
	return require(script.Parent.BotService)
end

function RollService.tierById(id: string): any?
	for _, tier in RollConfig.Tiers do
		if tier.id == id then
			return tier
		end
	end
	return nil
end

-- The tier's minimum guaranteed value in gems (floorFrac * price). A property
-- of the TIER, not the rarity: draws never return an item worth less, and it
-- rises with tier so a Mythic roll guarantees far more of its cost back than
-- a Basic roll.
function RollService.floorFor(tier: any): number
	return math.floor(tier.gems * (tier.floorFrac or 0))
end

-- The tier's live draw table. Authored per-tier: the rarity odds come straight
-- from config (so the card shows exactly what happens), and within each rarity
-- the specific item is chosen by supply weight among that rarity's rollable
-- items (reserve left, value at/above the tier floor).
--
-- Returns the per-item entries { itemId, rarity, weight } and the resolved
-- per-rarity percentages. If a window rarity has no eligible item right now
-- (all sold out, or all below the floor), its share is redistributed across
-- the rarities that DO have stock, so the odds always sum to 100 and match
-- what can actually drop.
local function drawTable(tier: any): ({ any }, { [string]: number })
	local floor = RollService.floorFor(tier)
	local inWindow: { [string]: boolean } = {}
	for _, r in tier.window do
		inWindow[r] = true
	end

	-- rollable items grouped by rarity
	local byRarity: { [string]: { { itemId: string, weight: number } } } = {}
	for itemId, item in EconomyService.allItems() do
		if (item.assignmentWeight or 0) > 0 and item.rarity and inWindow[item.rarity] then
			local snap = EconomyService.snapshot(itemId)
			if snap and (snap.reserveRemaining or 0) > 0 and EconomyService.valueOf(itemId) >= floor then
				local group = byRarity[item.rarity]
				if group == nil then
					group = {}
					byRarity[item.rarity] = group
				end
				table.insert(group, { itemId = itemId, weight = math.max(item.assignmentWeight, 1) })
			end
		end
	end

	-- resolve per-rarity odds: authored share, but only over rarities that have
	-- stock, renormalized to 100
	local activeTotal = 0
	for _, rarity in tier.window do
		if byRarity[rarity] then
			activeTotal += tier.odds[rarity] or 0
		end
	end
	local rarityPct: { [string]: number } = {}
	if activeTotal > 0 then
		for _, rarity in tier.window do
			if byRarity[rarity] then
				rarityPct[rarity] = (tier.odds[rarity] or 0) / activeTotal * 100
			end
		end
	end

	-- split each rarity's share across its items by supply weight
	local entries: { any } = {}
	for rarity, group in byRarity do
		local sumW = 0
		for _, e in group do
			sumW += e.weight
		end
		for _, e in group do
			table.insert(entries, {
				itemId = e.itemId,
				rarity = rarity,
				pct = (rarityPct[rarity] or 0) * (e.weight / sumW),
			})
		end
	end
	return entries, rarityPct
end

-- Odds for a tier: per-item drop chances. The UI rolls these up by rarity, so
-- the card shows the tier's four window rarities at their authored odds.
function RollService.oddsFor(tier: any): { any }
	local entries = drawTable(tier)
	local out = {}
	for _, e in entries do
		local item = EconomyService.getItem(e.itemId)
		table.insert(out, {
			itemId = e.itemId,
			name = item and item.name or e.itemId,
			imageId = item and item.imageId or nil, -- feeds the roll animation
			rarity = e.rarity,
			pct = e.pct,
		})
	end
	table.sort(out, function(a, b)
		return a.pct > b.pct
	end)
	return out
end

-- Value of an item-payment offer at live prices. Pure read; the UI shows the
-- same number the server charges against.
function RollService.paymentValue(items: { [string]: number }): number
	local total = 0
	for itemId, count in items do
		total += EconomyService.valueOf(itemId) * count
	end
	return total
end

-- Pick an item for this tier. `ticket` drives the draw: real players get a
-- random one, bots pass a derived integer so the whole simulation stays
-- deterministic and reproducible.
function RollService.pick(tier: any, ticket: number?): string?
	local entries = drawTable(tier)
	if #entries == 0 then
		return nil
	end
	local total = 0
	for _, e in entries do
		total += e.pct
	end
	if total <= 0 then
		return nil
	end
	local r: number
	if ticket then
		r = ((ticket * 2654435761) % 4294967296) / 4294967296
	else
		r = math.random()
	end
	local point = r * total
	local running = 0
	for _, e in entries do
		running += e.pct
		if point < running then
			return e.itemId
		end
	end
	return entries[#entries].itemId
end

-- Item payment shape: { [itemId]: count }, bounded. Every id must be a real
-- registry item; the combined live Value must cover the tier's price. Paid
-- copies are REDISTRIBUTED into the reserve (someone else can roll them back
-- out) — which is why items that can no longer be re-made are refused: a
-- limited event item pushed into the reserve after its event ended would be
-- stuck there forever.
local function checkPayment(payment: any, tier: any): (boolean, string?, number)
	if type(payment) ~= "table" or type(payment.items) ~= "table" then
		return false, "bad_payment", 0
	end
	local distinct = 0
	for itemId, count in payment.items do
		if not Guard.isString(itemId, 64) or not Guard.isPositiveInt(count) or count > 99 then
			return false, "bad_payment", 0
		end
		if EconomyService.getItem(itemId) == nil then
			return false, "unknown_item", 0
		end
		if not EventConfig.isReobtainable(itemId) then
			return false, "not_reobtainable", 0
		end
		distinct += 1
		if distinct > 12 then
			return false, "bad_payment", 0
		end
	end
	if distinct == 0 then
		return false, "bad_payment", 0
	end
	local total = RollService.paymentValue(payment.items)
	if total < tier.gems then
		return false, "payment_too_low", total
	end
	return true, nil, total
end

-- Shared core. isBot routes charges/grants + reserve the same way the store and
-- crafting do: bots stay session-local (their state resets every server start,
-- so their draws must never touch the durable reserve), players are durable.
-- `payment` (players only): pay with items instead of gems.
local function rollCore(userId: number, tierId: any, ticket: number?, payment: any?)
	if not RollConfig.Enabled then
		return { ok = false, err = "disabled" }
	end
	if not Guard.isString(tierId, 32) then
		return { ok = false, err = "bad_args" }
	end
	local tier = RollService.tierById(tierId :: string)
	if tier == nil then
		return { ok = false, err = "unknown_tier" }
	end

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

	local paidValue = 0
	if payment ~= nil then
		if isBot then
			return { ok = false, err = "bad_payment" } -- bots pay gems only
		end
		local okPay, payErr, total = checkPayment(payment, tier)
		if not okPay then
			return { ok = false, err = payErr }
		end
		paidValue = total
	end

	local itemId = RollService.pick(tier, ticket)
	if itemId == nil then
		-- nothing in reserve clears this tier's value floor right now: either
		-- the whole pool is distributed, or only sub-floor items remain
		local anyLeft = #rollableIds() > 0
		return { ok = false, err = anyLeft and "no_reward_available" or "nothing_left" }
	end

	-- charge first (validates funds/ownership atomically)...
	local charge: any
	if payment then
		local negItems = {}
		for payId, count in payment.items do
			negItems[payId] = -count
		end
		charge = { items = negItems }
	else
		charge = { gems = -tier.gems }
	end
	local charged, chargeErr = delta(charge, Enums.GrantSource.Roll)
	if not charged then
		return { ok = false, err = chargeErr }
	end
	-- ...then take the copy out of the reserve. This CAS is what guarantees an
	-- item can never be distributed beyond its totalSupply.
	local reserved = if isBot then EconomyService.reserveOneLazy(itemId) else EconomyService.reserveOne(itemId)
	if not reserved then
		-- lost the race: give back exactly what was taken
		if payment then
			local posItems = {}
			for payId, count in payment.items do
				posItems[payId] = count
			end
			delta({ items = posItems }, Enums.GrantSource.Refund)
		else
			delta({ gems = tier.gems }, Enums.GrantSource.Refund)
		end
		return { ok = false, err = "nothing_left" }
	end

	-- item payments are REDISTRIBUTED: the copies go back into each item's
	-- reserve, where future rolls/draws can hand them to someone else. Only
	-- after the prize is safely ours, so a failed roll never moves anything.
	if payment then
		for payId, count in payment.items do
			EconomyService.restockCopies(payId, count)
		end
	end

	delta({ items = { [itemId] = 1 } }, Enums.GrantSource.Roll)
	if player then
		task.spawn(function()
			DataService.saveNow(player)
		end)
	end

	local item = EconomyService.getItem(itemId)
	EconomyService.broadcastStats({ itemId })
	AnalyticsService.log("roll", {
		userId = userId,
		tier = tier.id,
		gems = payment and 0 or tier.gems,
		paidValue = payment and paidValue or nil,
		itemId = itemId,
	})
	return {
		ok = true,
		item = {
			itemId = itemId,
			name = item and item.name or itemId,
			imageId = item and item.imageId or nil,
			rarity = item and item.rarity or nil,
			value = EconomyService.valueOf(itemId),
		},
		spent = payment and 0 or tier.gems,
		paidValue = payment and paidValue or nil,
	}
end

-- Bot entry: deterministic draw (no RNG anywhere in the simulation).
function RollService.botRoll(botId: number, tierId: string, ticket: number)
	return rollCore(botId, tierId, ticket)
end

--------------------------------------------------------------------------------
-- DEBUG: batch roll (admin only) — remove with the rest of the dev tooling
--------------------------------------------------------------------------------

-- Every item of one rarity that a roll could currently produce: registered,
-- rollable (assignmentWeight > 0), and with reserve left. Same eligibility a
-- real roll uses, minus the tier value floor — a batch roll is rarity-picked,
-- not tier-picked, so there is no floor to apply.
local function rollablesOfRarity(rarity: string): { { itemId: string, weight: number } }
	local out = {}
	for itemId, item in EconomyService.allItems() do
		if item.rarity == rarity and (item.assignmentWeight or 0) > 0 then
			local snap = EconomyService.snapshotCached(itemId)
			if snap and (snap.reserveRemaining or 0) > 0 then
				table.insert(out, { itemId = itemId, weight = math.max(item.assignmentWeight, 1) })
			end
		end
	end
	return out
end

-- Roll `count` times at one rarity, free, straight into the caller's inventory.
-- Weighted by assignmentWeight exactly like a real roll, so the spread looks
-- like what players actually see.
--
-- Uses reserveOneLazy (in-memory + dirty flush), NOT the strong CAS: the strong
-- path is one DataStore UpdateAsync per copy, so a 100-roll batch would fire 100
-- synchronous writes and stall every player on the server behind the request
-- budget. Lazy is the same call the bot simulation makes for the same reason.
--
-- Grants land as ONE inventory delta rather than `count` of them, and are tagged
-- Starter (not Roll) so debug loot never counts as earned in profile stats.
--
-- `useGems` charges the rarity's store cost per copy, in the SAME delta as the
-- grant, so it either all happens or none of it does. Off by default: dev loot
-- should not quietly drain the test wallet.
function RollService.debugBatchRoll(player: Player, rarity: any, count: any, useGems: any): any
	if not DebugConfig.BatchRollEnabled then
		return { ok = false, err = "disabled" }
	end
	if not (DebugConfig.AdminUserIds and DebugConfig.AdminUserIds[player.UserId]) then
		return { ok = false, err = "not_authorized" }
	end
	if not DataService.isLoaded(player) then
		return { ok = false, err = "loading" }
	end
	if not Guard.isString(rarity, 32) or Enums.RarityTier[rarity] == nil then
		return { ok = false, err = "bad_rarity" }
	end
	if not Guard.isPositiveInt(count) or count > DebugConfig.BatchRollMaxCount then
		return { ok = false, err = "bad_count" }
	end

	local pool = rollablesOfRarity(rarity :: string)
	if #pool == 0 then
		return { ok = false, err = "nothing_left" }
	end
	local totalWeight = 0
	for _, e in pool do
		totalWeight += e.weight
	end

	-- Reserve first, tally as we go. A copy whose reserve ran out mid-batch is
	-- skipped, not retried, so a nearly-exhausted rarity returns fewer than asked
	-- rather than spinning.
	local tally: { [string]: number } = {}
	local granted = 0
	for _ = 1, count :: number do
		local point = math.random() * totalWeight
		local running = 0
		local chosen = pool[#pool].itemId
		for _, e in pool do
			running += e.weight
			if point < running then
				chosen = e.itemId
				break
			end
		end
		if EconomyService.reserveOneLazy(chosen) then
			tally[chosen] = (tally[chosen] or 0) + 1
			granted += 1
		end
	end

	if granted == 0 then
		return { ok = false, err = "nothing_left" }
	end

	-- Charged in the same delta as the grant: applyDelta rejects the whole thing
	-- if the gems aren't there, so a batch can never half-apply.
	local spent = 0
	local delta: any = { items = tally }
	if useGems == true then
		spent = (Items.StoreCostByRarity[rarity] or 0) * granted
		delta.gems = -spent
	end

	local ok = InventoryService.applyDelta(player, delta, Enums.GrantSource.Starter)
	if not ok then
		-- put every reserved copy back; nothing was handed over
		for itemId, n in tally do
			EconomyService.restockCopiesLazy(itemId, n)
		end
		return { ok = false, err = useGems == true and "insufficient_gems" or "grant_failed" }
	end

	task.spawn(function()
		DataService.saveNow(player)
	end)

	-- rows carry everything the reveal animation needs, so the client can replay
	-- it without a second round trip
	local touched = {}
	local rows = {}
	for itemId, n in tally do
		table.insert(touched, itemId)
		local item = EconomyService.getItem(itemId)
		table.insert(rows, {
			itemId = itemId,
			name = item and item.name or itemId,
			rarity = item and item.rarity or rarity,
			imageId = item and item.imageId or nil,
			value = EconomyService.valueOf(itemId),
			count = n,
		})
	end
	table.sort(rows, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.name < b.name
	end)
	EconomyService.broadcastStats(touched)
	AnalyticsService.log("debug_batch_roll", {
		userId = player.UserId,
		rarity = rarity,
		asked = count,
		granted = granted,
		spent = spent,
		distinct = #rows,
	})
	return { ok = true, rarity = rarity, asked = count, granted = granted, spent = spent, rows = rows }
end

function RollService.Init() end

function RollService.Start()
	Net.bindFunction("GetRolls", function(player)
		local tiers = {}
		for _, tier in RollConfig.Tiers do
			table.insert(tiers, {
				id = tier.id,
				name = tier.name,
				gems = tier.gems,
				blurb = tier.blurb,
				minValue = RollService.floorFor(tier), -- guaranteed value floor
				odds = RollService.oddsFor(tier),
			})
		end
		return { ok = true, tiers = tiers, enabled = RollConfig.Enabled }
	end)

	-- (tierId, payment?) — payment = { items = {itemId->count} } pays with
	-- goods (burned) instead of gems; omit it for a plain gem roll
	Net.bindFunction("RollItem", function(player, tierId, payment)
		if not DataService.isLoaded(player) then
			return { ok = false, err = "loading" }
		end
		return rollCore(player.UserId, tierId, nil, payment)
	end)

	-- DEBUG ONLY (admin-gated). Remove with the dev tooling for release.
	Net.bindFunction("DebugBatchRoll", function(player, rarity, count, useGems)
		return RollService.debugBatchRoll(player, rarity, count, useGems)
	end)
end

return RollService
