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

-- Everything rollable RIGHT NOW: pool items that still have reserve left.
-- Sorted for deterministic iteration.
local function rollableIds(): { string }
	local out = {}
	for itemId, item in EconomyService.allItems() do
		if (item.assignmentWeight or 0) > 0 then
			local snap = EconomyService.snapshot(itemId)
			if snap and (snap.reserveRemaining or 0) > 0 then
				table.insert(out, itemId)
			end
		end
	end
	table.sort(out)
	return out
end

-- Odds for a tier, as a name->percent table. Pure function of the live pool +
-- the tier's luck, so the UI can show honest odds rather than vibes.
function RollService.oddsFor(tier: any): { { itemId: string, name: string, pct: number } }
	local ids = rollableIds()
	local weights, total = {}, 0
	for _, itemId in ids do
		local item = EconomyService.getItem(itemId)
		local w = math.max(item and item.assignmentWeight or 0, 1) ^ (1 / math.max(tier.luck, 0.0001))
		weights[itemId] = w
		total += w
	end
	local out = {}
	for _, itemId in ids do
		local item = EconomyService.getItem(itemId)
		table.insert(out, {
			itemId = itemId,
			name = item and item.name or itemId,
			rarity = item and item.rarity or nil, -- UI rolls these up per rarity
			pct = total > 0 and (weights[itemId] / total * 100) or 0,
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
	local ids = rollableIds()
	if #ids == 0 then
		return nil
	end
	local cum, total = {}, 0
	for i, itemId in ids do
		local item = EconomyService.getItem(itemId)
		total += math.max(item and item.assignmentWeight or 0, 1) ^ (1 / math.max(tier.luck, 0.0001))
		cum[i] = total
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
	for i, c in cum do
		if point < c then
			return ids[i]
		end
	end
	return ids[#ids]
end

-- Item payment shape: { [itemId]: count }, bounded. Every id must be a real
-- registry item; the combined live Value must cover the tier's price. Paid
-- copies are BURNED (retired from existence) — paying with goods is a sink.
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
		return { ok = false, err = "nothing_left" } -- every pool item fully distributed
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

	-- item payments leave existence for good (the sink) — only after the
	-- reserve is safely ours, so a failed roll never burns anything
	if payment then
		local touched = {}
		for payId, count in payment.items do
			EconomyService.retireCopies(payId, count)
			table.insert(touched, payId)
		end
		EconomyService.broadcastStats(touched)
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

function RollService.Init() end

function RollService.Start()
	Net.bindFunction("GetRolls", function(player)
		local tiers = {}
		for _, tier in RollConfig.Tiers do
			table.insert(tiers, {
				id = tier.id,
				name = tier.name,
				gems = tier.gems,
				luck = tier.luck,
				blurb = tier.blurb,
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
end

return RollService
