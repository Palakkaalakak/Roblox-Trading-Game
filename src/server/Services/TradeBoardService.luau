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
local AnalyticsService = require(script.Parent.AnalyticsService)
local NotificationService = require(script.Parent.NotificationService)

local MAX_BULK_COUNT = 1000
local BOARD_PAGE = 200 -- MemoryStore per-request ceiling
local MAX_BOARD_LISTINGS = 100_000 -- global soft cap per the whole board
local SCAN_CAP = 2_000 -- how deep routine scans page (newest-first)

-- STORAGE SPLIT — MemoryStore's memory quota is EXPERIENCE-WIDE (~64KB in
-- Studio, all sorted maps combined; sharding across maps changes nothing).
-- 100 market bots holding several resting quotes each is >100KB of listings
-- and can NEVER fit, so:
--   * PLAYER listings -> MemoryStore map (cross-server + offline settlement;
--     low volume, a handful per player).
--   * BOT listings    -> plain server-memory table. Bots run leader-elected
--     on ONE server, so their order book is inherently server-local; Luau is
--     single-threaded and the mutate transforms never yield, so in-memory
--     updates keep the exact CAS semantics MemoryStore gives us. Bot quotes
--     are pure simulation — they need no durability (a fresh server just
--     re-quotes) and no cross-server view.
local TradeBoardService = {}

local board: any -- MemoryStore map (player listings only)
local memBoard: { [string]: any } = {} -- bot listings, id -> record

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function newId(): string
	-- time prefix keeps range reads roughly newest-last, GUID guarantees unique
	return ("%010d_%s"):format(os.time(), HttpService:GenerateGUID(false):sub(1, 8))
end

local function mutate(id: string, fn: (any) -> any?): (any?, string?)
	-- bot listing: in-memory transform. Single Luau thread + no yields in fn
	-- means this is atomic — same CAS guarantee as UpdateAsync.
	local mem = memBoard[id]
	if mem ~= nil then
		local new, err = fn(mem)
		if new == nil then
			return nil, err or "cas_aborted"
		end
		memBoard[id] = new
		return new, nil
	end

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

-- terminal cleanup + point read, routed to whichever store holds the id
local function removeListing(id: string)
	if memBoard[id] ~= nil then
		memBoard[id] = nil
		return
	end
	board:RemoveAsync(id)
end

local function getListing(id: string): any
	if memBoard[id] ~= nil then
		return memBoard[id]
	end
	local v
	pcall(function()
		v = board:GetAsync(id)
	end)
	return v
end

-- Market bots (negative userIds) are full inventory actors: their charges
-- and credits route into BotService's durable state instead of a profile.
-- Lazy require: BotService requires this module for its board entry points.
local function bots(): any
	return require(script.Parent.BotService)
end

-- Charge/credit the ACTING party (player online here, or a bot). Same
-- validate-then-apply semantics either way. Returns ok, err.
local function actorDelta(userId: number, delta: any, source: string, key: string?): (boolean, string?)
	if userId < 0 then
		return bots().applyDelta(userId, delta, source, key)
	end
	local player = Players:GetPlayerByUserId(userId)
	if player == nil or not DataService.isLoaded(player) then
		return false, "loading"
	end
	return InventoryService.applyDelta(player, delta, source, key)
end

local function actorSave(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		task.spawn(function()
			DataService.saveNow(player)
		end)
	end
end

-- deliver goods to a user: direct when local+loaded, bot state for bots,
-- else mailbox. Idempotent.
local function deliver(userId: number, items: { [string]: number }, gems: number, source: string, claimId: string): boolean
	if userId < 0 then
		return bots().credit(userId, items, gems, claimId)
	end
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

-- Live trade feed: completed fills/swaps are broadcast to all clients as one
-- human-readable line (the ticker shows the last N). This is what makes the
-- economy VISIBLY alive — settlements otherwise only reach the server log.
-- Rate-limited: 500 bots can settle hundreds of deals per sweep; the ticker
-- is illustrative, not an audit log, so we cap broadcasts (excess dropped)
-- to keep network + client churn sane. Players trade rarely, so their events
-- almost always fit under the cap.
local ANNOUNCE_PER_WINDOW = 4
local ANNOUNCE_WINDOW = 1 -- seconds
local announceCount = 0
local announceWindowStart = 0
local function announce(text: string)
	local now = os.clock()
	if now - announceWindowStart >= ANNOUNCE_WINDOW then
		announceWindowStart = now
		announceCount = 0
	end
	if announceCount >= ANNOUNCE_PER_WINDOW then
		return
	end
	announceCount += 1
	Net.fireAllClients("BoardActivity", { text = text, t = os.time() })
end

local function itemLabel(itemId: string): string
	local item = EconomyService.getItem(itemId)
	return item and item.name or itemId
end

local function offerLabel(offer: any): string
	local parts = {}
	for itemId, count in offer.items do
		table.insert(parts, ("%dx %s"):format(count, itemLabel(itemId)))
	end
	table.sort(parts)
	if offer.gems and offer.gems > 0 then
		table.insert(parts, ("%d gems"):format(offer.gems))
	end
	return table.concat(parts, " + ")
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

local cancelListing -- fwd decl (defined below; scan lazy-expires through it)

-- Newest-first scan over the WHOLE board: in-memory bot listings merged with
-- the paged MemoryStore player map (both key-sorted descending; ids are
-- time-prefixed so this is newest-first). Lazy-expires stale listings as it
-- walks. Every read path uses this, so a fresh post is ALWAYS visible
-- immediately no matter how many listings exist.
local lastKnownCount = 0 -- refreshed by every scan; gates the global cap
local function scanListings(cap: number, fn: (l: any) -> boolean?)
	local now = os.time()

	-- snapshot bot keys descending (memBoard can shrink mid-walk via expiry)
	local memKeys = {}
	for k in memBoard do
		table.insert(memKeys, k)
	end
	table.sort(memKeys, function(a, b)
		return a > b
	end)
	local memIdx = 1

	local storeBuf: { any } = {}
	local storeIdx = 1
	local storeBound: string? = nil
	local storeDone = false
	local function storePeek(): any
		if storeIdx > #storeBuf and not storeDone then
			storeBuf = board:GetRangeAsync(Enum.SortDirection.Descending, BOARD_PAGE, storeBound)
			storeIdx = 1
			if #storeBuf > 0 then
				storeBound = storeBuf[#storeBuf].key
			end
			if #storeBuf < BOARD_PAGE then
				storeDone = true
			end
		end
		if storeIdx > #storeBuf then
			return nil
		end
		return storeBuf[storeIdx]
	end

	local seen = 0
	while seen < cap do
		-- next record = larger key of the two stream heads
		local memKey = memKeys[memIdx]
		local storeEntry = storePeek()
		local l
		if memKey ~= nil and (storeEntry == nil or memKey > storeEntry.key) then
			l = memBoard[memKey] -- may be nil if expired mid-walk; skip below
			memIdx += 1
		elseif storeEntry ~= nil then
			l = storeEntry.value
			storeIdx += 1
		else
			break -- both streams exhausted
		end
		seen += 1
		if l and l.status == "open" then
			if l.expiresAt and now > l.expiresAt then
				task.spawn(cancelListing, l, "expired")
			elseif fn(l) == false then
				lastKnownCount = math.max(lastKnownCount, seen)
				return
			end
		end
	end
	lastKnownCount = seen
end

-- cancel + refund escrow (poster action or expiry). Any server may run this.
cancelListing = function(listing: any, reason: string): boolean
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
	-- Terminal: drop the key entirely. The MemoryStore memory quota is
	-- experience-wide and small — leaving cancelled/done rows in place
	-- (relying on the multi-day TTL) fills it in minutes once posting is
	-- frequent, and every subsequent SetAsync starts failing with
	-- TotalMemoryOverLimit.
	removeListing(committed.id)
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

local CLIENT_PAGE = 200 -- newest listings sent to a client per fetch
local CLIENT_OWN_EXTRA = 50 -- viewer's own listings ride along even when older

local function handleGetBoard(player: Player)
	local listings = {}
	local others = 0
	local own = 0
	-- newest-first scan: the viewer's own posts are ALWAYS included (up to
	-- CLIENT_OWN_EXTRA) even past the page cut, so "I posted it but can't
	-- see it" is structurally impossible.
	scanListings(SCAN_CAP, function(l)
		local mine = l.posterId == player.UserId
		if mine and own < CLIENT_OWN_EXTRA then
			own += 1
			table.insert(listings, describe(l, player.UserId))
		elseif not mine and others < CLIENT_PAGE then
			others += 1
			table.insert(listings, describe(l, player.UserId))
		end
		if others >= CLIENT_PAGE and own >= CLIENT_OWN_EXTRA then
			return false -- both quotas filled: stop paging
		end
		return nil
	end)
	return { ok = true, listings = listings }
end

--------------------------------------------------------------------------------
-- Posting
--------------------------------------------------------------------------------

local function postCore(userId: number, userName: string, payload: any)
	if type(payload) ~= "table" then
		return { ok = false, err = "bad_args" }
	end
	-- no per-poster limits; only a global board cap (soft, from latest scan)
	if lastKnownCount >= MAX_BOARD_LISTINGS then
		return { ok = false, err = "board_full" }
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
		local escrowed, escrowErr = actorDelta(
			userId,
			{ items = negItems, gems = -payload.give.gems },
			Enums.GrantSource.Board
		)
		if not escrowed then
			return { ok = false, err = escrowErr }
		end

		listing = {
			id = id,
			kind = "swap",
			posterId = userId,
			posterName = userName,
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

		local escrowed, escrowErr = actorDelta(userId, { gems = -escrow }, Enums.GrantSource.Bulk)
		if not escrowed then
			return { ok = false, err = escrowErr }
		end

		listing = {
			id = id,
			kind = "bulk",
			posterId = userId,
			posterName = userName,
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
		local escrowed, escrowErr = actorDelta(
			userId,
			{ items = { [payload.itemId] = -payload.count } },
			Enums.GrantSource.Board
		)
		if not escrowed then
			return { ok = false, err = escrowErr }
		end

		listing = {
			id = id,
			kind = "sell",
			posterId = userId,
			posterName = userName,
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

	local stored = true
	if userId < 0 then
		memBoard[id] = listing -- bot: server-local order book, never fails
	else
		stored = pcall(function()
			board:SetAsync(id, listing, EconomyConfig.BoardListingTTLSeconds + 24 * 3600)
		end)
	end
	if not stored then
		-- give the escrow back; posting failed
		if listing.kind == "swap" then
			actorDelta(userId, { items = listing.give.items, gems = listing.give.gems }, Enums.GrantSource.Refund)
		elseif listing.kind == "sell" then
			actorDelta(userId, { items = { [listing.itemId] = listing.remainingCount } }, Enums.GrantSource.Refund)
		else -- bulk
			actorDelta(userId, { gems = listing.remainingCount * listing.gemsPerCopy }, Enums.GrantSource.Refund)
		end
		return { ok = false, err = "store_error" }
	end
	actorSave(userId)
	AnalyticsService.log("board_posted", { id = id, kind = listing.kind, userId = userId })

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
	scanListings(SCAN_CAP, function(other)
		if TradeBoardService.isCounterListing(listing, other) then
			match = other
			return false
		end
		return nil
	end)
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
		removeListing(l.id) -- terminal: keep the quota-bound MemoryStore lean
	end

	announce(("%s ⇄ %s matched mirror trades: %s for %s"):format(
		mine.posterName, theirs.posterName, offerLabel(mine.give), offerLabel(theirs.give)))
	AnalyticsService.log("board_matched", { a = mine.id, b = theirs.id })
end

--------------------------------------------------------------------------------
-- Swap accept / interest
--------------------------------------------------------------------------------

local function acceptCore(userId: number, userName: string, id: any)
	if not Guard.isString(id, 64) then
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
		if l.posterId == userId then
			return nil, "own_listing"
		end
		l.status = "claimed"
		l.claimedBy = userId
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
	local paid, payErr = actorDelta(
		userId,
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
	actorDelta(
		userId,
		{ items = claimed.give.items, gems = accepterNet },
		Enums.GrantSource.Board,
		"board_settle_" .. id .. "_taker"
	)
	actorSave(userId)

	local posterNet = Tax.split(claimed.want.gems)
	deliver(claimed.posterId, claimed.want.items, posterNet, Enums.GrantSource.Board, "board_settle_" .. id .. "_poster")

	mutate(id, function(l)
		l.status = "done"
		l.v += 1
		return l
	end)
	removeListing(id) -- terminal: keep the quota-bound MemoryStore lean

	announce(("%s ⇄ %s: %s for %s"):format(userName, claimed.posterName, offerLabel(claimed.want), offerLabel(claimed.give)))
	AnalyticsService.log("board_accepted", { id = id, by = userId })
	return { ok = true }
end

local function handleInterest(player: Player, id: any)
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

local function contributeCore(userId: number, userName: string, id: any, count: any)
	if not Guard.isString(id, 64) or not Guard.isPositiveInt(count) then
		return { ok = false, err = "bad_args" }
	end

	-- reserve part of the order (CAS; clamps to what's left)
	local taken = 0
	local committed, err = mutate(id, function(l)
		if l.kind ~= "bulk" or l.status ~= "open" then
			return nil, "gone"
		end
		if l.posterId == userId then
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
	local paid, payErr = actorDelta(
		userId,
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
	actorDelta(userId, { gems = net }, Enums.GrantSource.Bulk)
	actorSave(userId)
	deliver(
		committed.posterId,
		{ [committed.itemId] = taken },
		0,
		Enums.GrantSource.Bulk,
		("bulk_fill_%s_%d_%d"):format(id, userId, committed.remainingCount)
	)

	-- a filled bulk order is a real gems-for-copies transaction at a clean
	-- per-copy price — feed it into RAP just like a direct sale
	EconomyService.recordSale(committed.itemId, committed.gemsPerCopy, taken)

	if committed.status == "done" then
		removeListing(id) -- terminal: keep the quota-bound MemoryStore lean
	end
	announce(("%s filled %d x %s @ %d gems for %s"):format(userName, taken, itemLabel(committed.itemId), committed.gemsPerCopy, committed.posterName))
	AnalyticsService.log("bulk_contributed", { id = id, by = userId, count = taken, net = net, tax = cut })
	return { ok = true, payout = net, count = taken }
end

--------------------------------------------------------------------------------
-- Gem-only shop: buy from a sell listing
--------------------------------------------------------------------------------

local function buyCore(userId: number, userName: string, id: any, count: any)
	if not Guard.isString(id, 64) or not Guard.isPositiveInt(count) then
		return { ok = false, err = "bad_args" }
	end

	-- reserve part of the listing (CAS; clamps to what's left)
	local taken = 0
	local committed, err = mutate(id, function(l)
		if l.kind ~= "sell" or l.status ~= "open" then
			return nil, "gone"
		end
		if l.posterId == userId then
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
	local paid, payErr = actorDelta(userId, { gems = -spent }, Enums.GrantSource.Board)
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
	actorDelta(userId, { items = { [committed.itemId] = taken } }, Enums.GrantSource.Board)
	actorSave(userId)
	local net = Tax.split(spent)
	deliver(
		committed.posterId,
		{},
		net,
		Enums.GrantSource.Board,
		("sell_pay_%s_%d_%d"):format(id, userId, committed.remainingCount)
	)

	-- CLEAN gem price signal: a direct gems-for-item sale needs no barter
	-- imputation, so feed the exact per-copy price straight into RAP/Value.
	EconomyService.recordSale(committed.itemId, committed.gemsPerCopy, taken)

	if committed.status == "done" then
		removeListing(id) -- terminal: keep the quota-bound MemoryStore lean
	end
	announce(("%s bought %d x %s @ %d gems from %s"):format(userName, taken, itemLabel(committed.itemId), committed.gemsPerCopy, committed.posterName))
	AnalyticsService.log("sell_bought", { id = id, by = userId, count = taken, spent = spent })
	return { ok = true, spent = spent, count = taken }
end

--------------------------------------------------------------------------------
-- Cancel + lifecycle
--------------------------------------------------------------------------------

local function cancelCore(userId: number, id: any)
	if not Guard.isString(id, 64) then
		return { ok = false, err = "bad_args" }
	end
	local current = getListing(id)
	if current == nil or current.posterId ~= userId then
		return { ok = false, err = "not_yours" }
	end
	if not cancelListing(current, "cancelled_by_poster") then
		return { ok = false, err = "gone" }
	end
	return { ok = true }
end

--------------------------------------------------------------------------------
-- Bot entry points + raw reads (BotService brains; no Player involved)
--------------------------------------------------------------------------------

-- Raw open listing records, newest-first, paged (lazy-expiring).
function TradeBoardService.rawOpenListings(cap: number?): { any }
	local out = {}
	scanListings(cap or SCAN_CAP, function(l)
		table.insert(out, l)
		return nil
	end)
	return out
end

function TradeBoardService.botPost(botId: number, botName: string, payload: any)
	return postCore(botId, botName, payload)
end

function TradeBoardService.botAccept(botId: number, botName: string, id: string)
	return acceptCore(botId, botName, id)
end

function TradeBoardService.botContribute(botId: number, botName: string, id: string, count: number)
	return contributeCore(botId, botName, id, count)
end

function TradeBoardService.botBuy(botId: number, botName: string, id: string, count: number)
	return buyCore(botId, botName, id, count)
end

function TradeBoardService.botCancel(botId: number, id: string)
	return cancelCore(botId, id)
end

--------------------------------------------------------------------------------
-- Remote wrappers (real players; loaded-profile gate then shared cores)
--------------------------------------------------------------------------------

local function loadedGate(player: Player)
	return DataService.isLoaded(player)
end

function TradeBoardService.Init()
	StoreAdapters.init()
	board = StoreAdapters.sortedMap("TradeBoard_v7")

	-- One-time purge of retired MemoryStore maps (old boards + the retired
	-- EconomyHot mirror). Their entries persist on multi-day TTLs and count
	-- against the EXPERIENCE-WIDE MemoryStore memory quota — without this,
	-- writes to the new map keep failing with TotalMemoryOverLimit until the
	-- old TTLs lapse (days). Cheap when clean: one empty GetRangeAsync per
	-- retired map. Delete this block once the retired maps have aged out.
	task.spawn(function()
		local retired = { "TradeBoard_v3", "TradeBoard_v4", "TradeBoard_v6", "EconomyHot_v3" }
		for i = 1, 16 do
			table.insert(retired, "TradeBoard_v5_" .. i)
		end
		local purged = 0
		for _, name in retired do
			local old = StoreAdapters.sortedMap(name)
			while true do
				local page = old:GetRangeAsync(Enum.SortDirection.Ascending, 200)
				if #page == 0 then
					break
				end
				for _, entry in page do
					old:RemoveAsync(entry.key)
					purged += 1
				end
			end
		end
		if purged > 0 then
			print(("[Board] purged %d entries from retired board maps"):format(purged))
		end
	end)
end

function TradeBoardService.Start()
	Net.bindFunction("GetBoard", handleGetBoard)
	Net.bindFunction("PostListing", function(player, payload)
		if not loadedGate(player) then
			return { ok = false, err = "loading" }
		end
		return postCore(player.UserId, player.Name, payload)
	end)
	Net.bindFunction("CancelListing", function(player, id)
		return cancelCore(player.UserId, id)
	end)
	Net.bindFunction("AcceptListing", function(player, id)
		if not loadedGate(player) then
			return { ok = false, err = "loading" }
		end
		return acceptCore(player.UserId, player.Name, id)
	end)
	Net.bindFunction("RegisterInterest", handleInterest)
	Net.bindFunction("ContributeBulk", function(player, id, count)
		if not loadedGate(player) then
			return { ok = false, err = "loading" }
		end
		return contributeCore(player.UserId, player.Name, id, count)
	end)
	Net.bindFunction("BuyFromListing", function(player, id, count)
		if not loadedGate(player) then
			return { ok = false, err = "loading" }
		end
		return buyCore(player.UserId, player.Name, id, count)
	end)
end

return TradeBoardService
