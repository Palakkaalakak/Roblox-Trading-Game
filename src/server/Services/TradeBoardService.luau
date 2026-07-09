--!strict
-- TradeBoardService: the central pillar of outstanding trades.
--
-- SWAP listings — "this for that", posted when nobody in the server wants it:
--   * posting ESCROWS the give-side immediately (removed from the poster's
--     inventory into the listing), so offline settlement is always safe
--   * autoTrade = true : anyone who can pay the want-side accepts instantly;
--     works with the poster offline (goods delivered via mailbox)
--   * autoTrade = false: accepting registers INTEREST — the poster gets a
--     notification (online: toast, offline: queued for next login) and sees
--     interested traders on their listing to invite for a normal trade
--   * cancel/expiry refunds the escrow
--
-- BULK listings — gems-only buy orders for many copies of ONE item:
--   * posting escrows count x gemsPerCopy
--   * anyone contributes copies; each copy pays out gemsPerCopy, minus the
--     house gem tax; the poster's copies arrive via mailbox/direct
--   * order completes when filled; cancel refunds the remaining escrow
--
-- SELL listings — gems-only SHOP: sell Z copies of ONE item at Y gems each:
--   * posting escrows the Z copies
--   * any buyer purchases N (N<=remaining): pays N x Y gems, gets the copies;
--     the seller receives N x Y minus house tax
--   * this is a CLEAN gem-denominated price per item (the Robux-resale
--     analogue) and is recorded straight into RAP — the most precise price
--     signal in the economy, since no barter imputation is needed
--   * completes when sold out; cancel refunds remaining copies
--
-- All records live in a MemoryStore map (cross-server); every state change is
-- a CAS transform, so double-accepts / double-fills are impossible.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Enums)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)
local Tax = require(ReplicatedStorage.Shared.Util.Tax)

local Net = require(script.Parent.Parent.Net)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimitService = require(script.Parent.RateLimitService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local NotificationService = require(script.Parent.NotificationService)

local MAX_LISTINGS_PER_PLAYER = 3
local MAX_BULK_COUNT = 1000
local BOARD_PAGE = 100

local TradeBoardService = {}

local board: any -- MemoryStore map "TradeBoard_v1"

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function newId(): string
	-- time prefix keeps range reads roughly newest-last, GUID guarantees unique
	return ("%010d_%s"):format(os.time(), HttpService:GenerateGUID(false):sub(1, 8))
end

local function mutate(id: string, fn: (any) -> any?): (any?, string?)
	local errOut: string? = nil
	local result
	local ok = pcall(function()
		result = board:UpdateAsync(id, function(old)
			if old == nil then
				errOut = "not_found"
				return nil
			end
			local new, err = fn(old)
			if new == nil then
				errOut = err
				return nil
			end
			errOut = nil
			return new
		end, EconomyConfig.BoardListingTTLSeconds + 24 * 3600)
	end)
	if not ok then
		return nil, "store_error"
	end
	if result == nil then
		return nil, errOut or "cas_aborted"
	end
	return result, nil
end

-- deliver goods to a user: direct when local+loaded, else mailbox. Idempotent.
local function deliver(userId: number, items: { [string]: number }, gems: number, source: string, claimId: string): boolean
	local player = Players:GetPlayerByUserId(userId)
	if player and DataService.isLoaded(player) then
		local ok = InventoryService.applyDelta(player, { items = items, gems = gems }, source, claimId)
		if ok then
			task.spawn(function()
				DataService.saveNow(player)
			end)
			return true
		end
	end
	return DataService.mailboxAppend(userId, {
		claimId = claimId,
		items = items,
		gems = gems,
		source = source,
		createdAt = os.time(),
	})
end

-- bulk quote: what one copy pays and what the poster must escrow.
function TradeBoardService.bulkQuote(count: number, totalGems: number): (number, number)
	local perCopy = math.floor(totalGems / count)
	return perCopy, perCopy * count
end

-- exact offer equality (same item counts + same gems)
function TradeBoardService.offersEqual(a: any, b: any): boolean
	if a.gems ~= b.gems then
		return false
	end
	for itemId, count in a.items do
		if b.items[itemId] ~= count then
			return false
		end
	end
	for itemId, count in b.items do
		if a.items[itemId] ~= count then
			return false
		end
	end
	return true
end

-- two swap listings mirror each other when what one GIVES is exactly what
-- the other WANTS, both ways
function TradeBoardService.isCounterListing(mine: any, theirs: any): boolean
	return theirs.kind == "swap"
		and theirs.status == "open"
		and theirs.posterId ~= mine.posterId
		and TradeBoardService.offersEqual(mine.give, theirs.want)
		and TradeBoardService.offersEqual(mine.want, theirs.give)
end

local function activeListingCount(userId: number): number
	local n = 0
	for _, entry in board:GetRangeAsync(nil, BOARD_PAGE) do
		local l = entry.value
		if l and l.posterId == userId and l.status == "open" then
			n += 1
		end
	end
	return n
end

-- cancel + refund escrow (poster action or expiry). Any server may run this.
local function cancelListing(listing: any, reason: string): boolean
	local committed = mutate(listing.id, function(l)
		if l.status ~= "open" then
			return nil, "not_open"
		end
		l.status = "cancelled"
		l.v += 1
		return l
	end)
	if committed == nil then
		return false
	end
	if committed.kind == "swap" then
		deliver(committed.posterId, committed.give.items, committed.give.gems, Enums.GrantSource.Refund, "board_refund_" .. committed.id)
	elseif committed.kind == "sell" then
		-- return the unsold copies
		if committed.remainingCount > 0 then
			deliver(committed.posterId, { [committed.itemId] = committed.remainingCount }, 0, Enums.GrantSource.Refund, "board_refund_" .. committed.id)
		end
	else -- bulk
		local refund = committed.remainingCount * committed.gemsPerCopy
		if refund > 0 then
			deliver(committed.posterId, {}, refund, Enums.GrantSource.Refund, "board_refund_" .. committed.id)
		end
	end
	AnalyticsService.log("board_cancelled", { id = committed.id, reason = reason })
	return true
end

--------------------------------------------------------------------------------
-- Reads
--------------------------------------------------------------------------------

local function describe(listing: any, viewerId: number): any
	local function itemInfo(itemId: string)
		local item = EconomyService.getItem(itemId)
		return item and item.name or itemId, item and item.imageId or nil
	end
	local out = {
		id = listing.id,
		kind = listing.kind,
		posterId = listing.posterId,
		posterName = listing.posterName,
		mine = listing.posterId == viewerId,
		expiresAt = listing.expiresAt,
	}
	if listing.kind == "swap" then
		out.autoTrade = listing.autoTrade
		local function describeOffer(offer)
			local items = {}
			for itemId, count in offer.items do
				local name, imageId = itemInfo(itemId)
				table.insert(items, { itemId = itemId, name = name, imageId = imageId, count = count })
			end
			table.sort(items, function(a, b)
				return a.itemId < b.itemId
			end)
			return { items = items, gems = offer.gems }
		end
		out.give = describeOffer(listing.give)
		out.want = describeOffer(listing.want)
		local interested = {}
		for uid, name in listing.interested or {} do
			table.insert(interested, { userId = tonumber(uid), name = name })
		end
		out.interested = interested
	else
		-- bulk + sell share the same shape (item, counts, gemsPerCopy)
		local name, imageId = itemInfo(listing.itemId)
		out.itemId = listing.itemId
		out.itemName = name
		out.imageId = imageId
		out.wantedCount = listing.wantedCount
		out.remainingCount = listing.remainingCount
		out.gemsPerCopy = listing.gemsPerCopy
	end
	return out
end

local function handleGetBoard(player: Player)
	if not RateLimitService.check(player, "GetBoard") then
		return { ok = false, err = "rate_limited" }
	end
	local now = os.time()
	local listings = {}
	for _, entry in board:GetRangeAsync(nil, BOARD_PAGE) do
		local l = entry.value
		if l and l.status == "open" then
			if l.expiresAt and now > l.expiresAt then
				task.spawn(cancelListing, l, "expired") -- lazy expiry, refunds escrow
			else
				table.insert(listings, describe(l, player.UserId))
			end
		end
	end
	return { ok = true, listings = listings }
end

--------------------------------------------------------------------------------
-- Posting
--------------------------------------------------------------------------------

local function handlePost(player: Player, payload: any)
	if not RateLimitService.check(player, "PostListing") then
		return { ok = false, err = "rate_limited" }
	end
	if not DataService.isLoaded(player) then
		return { ok = false, err = "loading" }
	end
	if type(payload) ~= "table" then
		return { ok = false, err = "bad_args" }
	end
	if activeListingCount(player.UserId) >= MAX_LISTINGS_PER_PLAYER then
		return { ok = false, err = "too_many_listings" }
	end

	local now = os.time()
	local id = newId()
	local listing: any

	if payload.kind == "swap" then
		local giveOk = Guard.checkOfferShape(payload.give)
		local wantOk = Guard.checkOfferShape(payload.want)
		if not giveOk or not wantOk then
			return { ok = false, err = "bad_offer" }
		end
		local function empty(offer)
			if offer.gems > 0 then
				return false
			end
			for _ in offer.items do
				return false
			end
			return true
		end
		if empty(payload.give) or empty(payload.want) then
			return { ok = false, err = "empty_side" }
		end
		for itemId in payload.want.items do
			if EconomyService.getItem(itemId) == nil then
				return { ok = false, err = "unknown_item" }
			end
		end

		-- escrow the give side NOW (this is what makes offline auto-trade safe)
		local negItems = {}
		for itemId, count in payload.give.items do
			negItems[itemId] = -count
		end
		local escrowed, escrowErr = InventoryService.applyDelta(
			player,
			{ items = negItems, gems = -payload.give.gems },
			Enums.GrantSource.Board
		)
		if not escrowed then
			return { ok = false, err = escrowErr }
		end

		listing = {
			id = id,
			kind = "swap",
			posterId = player.UserId,
			posterName = player.Name,
			give = payload.give,
			want = payload.want,
			autoTrade = payload.autoTrade == true,
			interested = {},
			status = "open",
			createdAt = now,
			expiresAt = now + EconomyConfig.BoardListingTTLSeconds,
			v = 1,
		}
	elseif payload.kind == "bulk" then
		if not Guard.isString(payload.itemId, 64) or EconomyService.getItem(payload.itemId) == nil then
			return { ok = false, err = "unknown_item" }
		end
		if not Guard.isPositiveInt(payload.count) or payload.count > MAX_BULK_COUNT then
			return { ok = false, err = "bad_count" }
		end
		if not Guard.isPositiveInt(payload.gems) then
			return { ok = false, err = "bad_gems" }
		end
		local perCopy, escrow = TradeBoardService.bulkQuote(payload.count, payload.gems)
		if perCopy < 1 then
			return { ok = false, err = "gems_too_low" } -- must pay >= 1 gem per copy
		end

		local escrowed, escrowErr = InventoryService.applyDelta(player, { gems = -escrow }, Enums.GrantSource.Bulk)
		if not escrowed then
			return { ok = false, err = escrowErr }
		end

		listing = {
			id = id,
			kind = "bulk",
			posterId = player.UserId,
			posterName = player.Name,
			itemId = payload.itemId,
			wantedCount = payload.count,
			remainingCount = payload.count,
			gemsPerCopy = perCopy,
			status = "open",
			createdAt = now,
			expiresAt = now + EconomyConfig.BoardListingTTLSeconds,
			v = 1,
		}
	elseif payload.kind == "sell" then
		if not Guard.isString(payload.itemId, 64) or EconomyService.getItem(payload.itemId) == nil then
			return { ok = false, err = "unknown_item" }
		end
		if not Guard.isPositiveInt(payload.count) or payload.count > MAX_BULK_COUNT then
			return { ok = false, err = "bad_count" }
		end
		if not Guard.isPositiveInt(payload.gemsPerCopy) then
			return { ok = false, err = "bad_price" }
		end

		-- escrow the copies being sold
		local escrowed, escrowErr = InventoryService.applyDelta(
			player,
			{ items = { [payload.itemId] = -payload.count } },
			Enums.GrantSource.Board
		)
		if not escrowed then
			return { ok = false, err = escrowErr }
		end

		listing = {
			id = id,
			kind = "sell",
			posterId = player.UserId,
			posterName = player.Name,
			itemId = payload.itemId,
			wantedCount = payload.count, -- copies listed
			remainingCount = payload.count, -- copies still for sale
			gemsPerCopy = payload.gemsPerCopy,
			status = "open",
			createdAt = now,
			expiresAt = now + EconomyConfig.BoardListingTTLSeconds,
			v = 1,
		}
	else
		return { ok = false, err = "bad_kind" }
	end

	local stored = pcall(function()
		board:SetAsync(id, listing, EconomyConfig.BoardListingTTLSeconds + 24 * 3600)
	end)
	if not stored then
		-- give the escrow back; posting failed
		if listing.kind == "swap" then
			InventoryService.applyDelta(player, { items = listing.give.items, gems = listing.give.gems }, Enums.GrantSource.Refund)
		elseif listing.kind == "sell" then
			InventoryService.applyDelta(player, { items = { [listing.itemId] = listing.remainingCount } }, Enums.GrantSource.Refund)
		else -- bulk
			InventoryService.applyDelta(player, { gems = listing.remainingCount * listing.gemsPerCopy }, Enums.GrantSource.Refund)
		end
		return { ok = false, err = "store_error" }
	end
	task.spawn(function()
		DataService.saveNow(player)
	end)
	AnalyticsService.log("board_posted", { id = id, kind = listing.kind, userId = player.UserId })

	-- counter-listing check: someone already posted the mirror of this trade
	if listing.kind == "swap" then
		task.spawn(TradeBoardService.tryMatch, listing)
	end
	return { ok = true, id = id }
end

-- Find a mirror listing for a fresh swap post. Both auto-trade -> execute the
-- deal instantly (both escrows already exist, so this is pure delivery);
-- otherwise notify both posters that their match is on the board.
function TradeBoardService.tryMatch(listing: any)
	local match
	for _, entry in board:GetRangeAsync(nil, BOARD_PAGE) do
		local other = entry.value
		if other and TradeBoardService.isCounterListing(listing, other) then
			match = other
			break
		end
	end
	if match == nil then
		return
	end

	if not (listing.autoTrade and match.autoTrade) then
		NotificationService.notify(
			listing.posterId,
			("📌 %s posted the exact opposite of your board trade — invite them!"):format(match.posterName)
		)
		NotificationService.notify(
			match.posterId,
			("📌 %s posted the exact opposite of your board trade — invite them!"):format(listing.posterName)
		)
		return
	end

	-- both auto: claim BOTH listings (CAS; revert mine if theirs is gone)
	local mine = mutate(listing.id, function(l)
		if l.status ~= "open" then
			return nil, "gone"
		end
		l.status = "claimed"
		l.v += 1
		return l
	end)
	if mine == nil then
		return
	end
	local theirs = mutate(match.id, function(l)
		if l.status ~= "open" then
			return nil, "gone"
		end
		l.status = "claimed"
		l.v += 1
		return l
	end)
	if theirs == nil then
		mutate(listing.id, function(l)
			l.status = "open"
			l.v += 1
			return l
		end)
		return
	end

	-- swap the escrows (gem tax on each receiving side)
	local aNet = Tax.split(theirs.give.gems)
	deliver(mine.posterId, theirs.give.items, aNet, Enums.GrantSource.Board, "board_match_" .. mine.id)
	local bNet = Tax.split(mine.give.gems)
	deliver(theirs.posterId, mine.give.items, bNet, Enums.GrantSource.Board, "board_match_" .. theirs.id)

	for _, l in { mine, theirs } do
		mutate(l.id, function(rec)
			rec.status = "done"
			rec.v += 1
			return rec
		end)
	end

	NotificationService.notify(mine.posterId, "📌 Matched! Your board trade auto-completed with " .. theirs.posterName .. "!")
	NotificationService.notify(theirs.posterId, "📌 Matched! Your board trade auto-completed with " .. mine.posterName .. "!")
	AnalyticsService.log("board_matched", { a = mine.id, b = theirs.id })
end

--------------------------------------------------------------------------------
-- Swap accept / interest
--------------------------------------------------------------------------------

local function handleAccept(player: Player, id: any)
	if not RateLimitService.check(player, "AcceptListing") then
		return { ok = false, err = "rate_limited" }
	end
	if not DataService.isLoaded(player) or not Guard.isString(id, 64) then
		return { ok = false, err = "bad_args" }
	end

	-- claim it (CAS beats cross-server double-accepts)
	local claimed, err = mutate(id, function(l)
		if l.kind ~= "swap" or not l.autoTrade then
			return nil, "not_auto"
		end
		if l.status ~= "open" then
			return nil, "gone"
		end
		if l.posterId == player.UserId then
			return nil, "own_listing"
		end
		l.status = "claimed"
		l.claimedBy = player.UserId
		l.v += 1
		return l
	end)
	if claimed == nil then
		return { ok = false, err = err }
	end

	-- charge the accepter the want-side
	local negItems = {}
	for itemId, count in claimed.want.items do
		negItems[itemId] = -count
	end
	local paid, payErr = InventoryService.applyDelta(
		player,
		{ items = negItems, gems = -claimed.want.gems },
		Enums.GrantSource.Board
	)
	if not paid then
		mutate(id, function(l)
			l.status = "open"
			l.claimedBy = nil
			l.v += 1
			return l
		end)
		return { ok = false, err = payErr }
	end

	-- settle both directions (gem tax on each receiver's gems)
	local accepterNet = Tax.split(claimed.give.gems)
	InventoryService.applyDelta(
		player,
		{ items = claimed.give.items, gems = accepterNet },
		Enums.GrantSource.Board,
		"board_settle_" .. id .. "_taker"
	)
	task.spawn(function()
		DataService.saveNow(player)
	end)

	local posterNet = Tax.split(claimed.want.gems)
	deliver(claimed.posterId, claimed.want.items, posterNet, Enums.GrantSource.Board, "board_settle_" .. id .. "_poster")

	mutate(id, function(l)
		l.status = "done"
		l.v += 1
		return l
	end)

	NotificationService.notify(claimed.posterId, ("📌 Your board trade was accepted by %s!"):format(player.Name))
	AnalyticsService.log("board_accepted", { id = id, by = player.UserId })
	return { ok = true }
end

local function handleInterest(player: Player, id: any)
	if not RateLimitService.check(player, "RegisterInterest") then
		return { ok = false, err = "rate_limited" }
	end
	if not DataService.isLoaded(player) or not Guard.isString(id, 64) then
		return { ok = false, err = "bad_args" }
	end
	local committed, err = mutate(id, function(l)
		if l.kind ~= "swap" or l.autoTrade then
			return nil, "not_ask"
		end
		if l.status ~= "open" then
			return nil, "gone"
		end
		if l.posterId == player.UserId then
			return nil, "own_listing"
		end
		l.interested = l.interested or {}
		if l.interested[tostring(player.UserId)] then
			return nil, "already_interested"
		end
		l.interested[tostring(player.UserId)] = player.Name
		l.v += 1
		return l
	end)
	if committed == nil then
		return { ok = false, err = err }
	end
	NotificationService.notify(
		committed.posterId,
		("📌 %s wants your board trade! Open the board and invite them."):format(player.Name)
	)
	AnalyticsService.log("board_interest", { id = id, by = player.UserId })
	return { ok = true }
end

--------------------------------------------------------------------------------
-- Bulk contribute
--------------------------------------------------------------------------------

local function handleContribute(player: Player, id: any, count: any)
	if not RateLimitService.check(player, "ContributeBulk") then
		return { ok = false, err = "rate_limited" }
	end
	if not DataService.isLoaded(player) or not Guard.isString(id, 64) or not Guard.isPositiveInt(count) then
		return { ok = false, err = "bad_args" }
	end

	-- reserve part of the order (CAS; clamps to what's left)
	local taken = 0
	local committed, err = mutate(id, function(l)
		if l.kind ~= "bulk" or l.status ~= "open" then
			return nil, "gone"
		end
		if l.posterId == player.UserId then
			return nil, "own_listing"
		end
		taken = math.min(count, l.remainingCount)
		if taken <= 0 then
			return nil, "filled"
		end
		l.remainingCount -= taken
		if l.remainingCount <= 0 then
			l.status = "done"
		end
		l.v += 1
		return l
	end)
	if committed == nil then
		return { ok = false, err = err }
	end

	-- charge the contributor the copies
	local paid, payErr = InventoryService.applyDelta(
		player,
		{ items = { [committed.itemId] = -taken } },
		Enums.GrantSource.Bulk
	)
	if not paid then
		mutate(id, function(l)
			l.remainingCount += taken
			if l.status == "done" then
				l.status = "open"
			end
			l.v += 1
			return l
		end)
		return { ok = false, err = payErr }
	end

	-- pay out (taxed) + ship copies to the poster
	local gross = taken * committed.gemsPerCopy
	local net, cut = Tax.split(gross)
	InventoryService.applyDelta(player, { gems = net }, Enums.GrantSource.Bulk)
	task.spawn(function()
		DataService.saveNow(player)
	end)
	deliver(
		committed.posterId,
		{ [committed.itemId] = taken },
		0,
		Enums.GrantSource.Bulk,
		("bulk_fill_%s_%d_%d"):format(id, player.UserId, committed.remainingCount)
	)

	if committed.status == "done" then
		NotificationService.notify(committed.posterId, ("📌 Your bulk order for %dx %s is complete!"):format(committed.wantedCount, committed.itemId))
	end
	AnalyticsService.log("bulk_contributed", { id = id, by = player.UserId, count = taken, net = net, tax = cut })
	return { ok = true, payout = net, count = taken }
end

--------------------------------------------------------------------------------
-- Gem-only shop: buy from a sell listing
--------------------------------------------------------------------------------

local function handleBuyFromListing(player: Player, id: any, count: any)
	if not RateLimitService.check(player, "BuyFromListing") then
		return { ok = false, err = "rate_limited" }
	end
	if not DataService.isLoaded(player) or not Guard.isString(id, 64) or not Guard.isPositiveInt(count) then
		return { ok = false, err = "bad_args" }
	end

	-- reserve part of the listing (CAS; clamps to what's left)
	local taken = 0
	local committed, err = mutate(id, function(l)
		if l.kind ~= "sell" or l.status ~= "open" then
			return nil, "gone"
		end
		if l.posterId == player.UserId then
			return nil, "own_listing"
		end
		taken = math.min(count, l.remainingCount)
		if taken <= 0 then
			return nil, "sold_out"
		end
		l.remainingCount -= taken
		if l.remainingCount <= 0 then
			l.status = "done"
		end
		l.v += 1
		return l
	end)
	if committed == nil then
		return { ok = false, err = err }
	end

	-- charge the buyer gems for the copies
	local spent = taken * committed.gemsPerCopy
	local paid, payErr = InventoryService.applyDelta(player, { gems = -spent }, Enums.GrantSource.Board)
	if not paid then
		-- put the copies back on sale
		mutate(id, function(l)
			l.remainingCount += taken
			if l.status == "done" then
				l.status = "open"
			end
			l.v += 1
			return l
		end)
		return { ok = false, err = payErr }
	end

	-- deliver copies to the buyer, pay the seller (taxed)
	InventoryService.applyDelta(player, { items = { [committed.itemId] = taken } }, Enums.GrantSource.Board)
	task.spawn(function()
		DataService.saveNow(player)
	end)
	local net = Tax.split(spent)
	deliver(
		committed.posterId,
		{},
		net,
		Enums.GrantSource.Board,
		("sell_pay_%s_%d_%d"):format(id, player.UserId, committed.remainingCount)
	)

	-- CLEAN gem price signal: a direct gems-for-item sale needs no barter
	-- imputation, so feed the exact per-copy price straight into RAP/Value.
	EconomyService.recordSale(committed.itemId, committed.gemsPerCopy, taken)

	if committed.status == "done" then
		NotificationService.notify(committed.posterId, ("📌 Your sale of %dx %s sold out!"):format(committed.wantedCount, committed.itemId))
	end
	AnalyticsService.log("sell_bought", { id = id, by = player.UserId, count = taken, spent = spent })
	return { ok = true, spent = spent, count = taken }
end

--------------------------------------------------------------------------------
-- Cancel + lifecycle
--------------------------------------------------------------------------------

local function handleCancel(player: Player, id: any)
	if not RateLimitService.check(player, "CancelListing") then
		return { ok = false, err = "rate_limited" }
	end
	if not Guard.isString(id, 64) then
		return { ok = false, err = "bad_args" }
	end
	local current
	pcall(function()
		current = board:GetAsync(id)
	end)
	if current == nil or current.posterId ~= player.UserId then
		return { ok = false, err = "not_yours" }
	end
	if not cancelListing(current, "cancelled_by_poster") then
		return { ok = false, err = "gone" }
	end
	return { ok = true }
end

function TradeBoardService.Init()
	StoreAdapters.init()
	board = StoreAdapters.sortedMap("TradeBoard_v1")
end

function TradeBoardService.Start()
	Net.bindFunction("GetBoard", handleGetBoard)
	Net.bindFunction("PostListing", handlePost)
	Net.bindFunction("CancelListing", handleCancel)
	Net.bindFunction("AcceptListing", handleAccept)
	Net.bindFunction("RegisterInterest", handleInterest)
	Net.bindFunction("ContributeBulk", handleContribute)
	Net.bindFunction("BuyFromListing", handleBuyFromListing)
end

return TradeBoardService
