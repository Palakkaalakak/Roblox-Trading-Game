--!strict
-- BookIndex: pure per-item order-book index over board listings.
--
-- The Market tab needs "all listings for THIS item" and "best prices per
-- item" — the board's flat newest-first scan answers neither without paging
-- MemoryStore on every open (the exact call that gets RequestThrottled).
-- This index is plain tables, maintained incrementally by TradeBoardService
-- on every local post/cancel/fill and rebuilt periodically from a full scan
-- (which also picks up listings posted on other servers).
--
-- Pure module: no services, no time source of its own — fully unit-testable.
-- Only gem-denominated kinds are indexed: sell = asks, bulk = bids. Swaps are
-- barter, not order-book rows.

local BookIndex = {}

export type Index = { byItem: { [string]: { asks: { [string]: any }, bids: { [string]: any } } } }

function BookIndex.new(): Index
	return { byItem = {} }
end

local function isLive(listing: any, now: number?): boolean
	if listing.status ~= "open" or (listing.remainingCount or 0) <= 0 then
		return false
	end
	if now and listing.expiresAt and now > listing.expiresAt then
		return false
	end
	return true
end

-- Upsert or drop one listing based on its current state. Call with the
-- committed record after every mutation; terminal states remove themselves.
function BookIndex.apply(index: Index, listing: any)
	if listing.kind ~= "sell" and listing.kind ~= "bulk" then
		return
	end
	local side = listing.kind == "sell" and "asks" or "bids"
	local entry = index.byItem[listing.itemId]
	if isLive(listing) then
		if entry == nil then
			entry = { asks = {}, bids = {} }
			index.byItem[listing.itemId] = entry
		end
		entry[side][listing.id] = listing
	elseif entry ~= nil then
		entry[side][listing.id] = nil
		if next(entry.asks) == nil and next(entry.bids) == nil then
			index.byItem[listing.itemId] = nil
		end
	end
end

-- Price-time priority: best price first; ties go to higher boost, then the
-- newer listing (ids are time-prefixed, so id order is creation order).
local function beats(a: any, b: any, wantLow: boolean): boolean
	if a.gemsPerCopy ~= b.gemsPerCopy then
		if wantLow then
			return a.gemsPerCopy < b.gemsPerCopy
		end
		return a.gemsPerCopy > b.gemsPerCopy
	end
	local aBoost, bBoost = a.boostTier or 0, b.boostTier or 0
	if aBoost ~= bBoost then
		return aBoost > bBoost
	end
	return a.id > b.id
end

-- One item's live book: asks cheapest-first, bids highest-first.
function BookIndex.book(index: Index, itemId: string, now: number?): (any, any)
	local entry = index.byItem[itemId]
	local asks, bids = {}, {}
	if entry then
		for _, l in entry.asks do
			if isLive(l, now) then
				table.insert(asks, l)
			end
		end
		for _, l in entry.bids do
			if isLive(l, now) then
				table.insert(bids, l)
			end
		end
	end
	table.sort(asks, function(a, b)
		return beats(a, b, true)
	end)
	table.sort(bids, function(a, b)
		return beats(a, b, false)
	end)
	return asks, bids
end

-- Per-item roll-up for the Market directory: best prices + open unit counts.
function BookIndex.summary(index: Index, now: number?): { [string]: any }
	local out: { [string]: any } = {}
	for itemId, entry in index.byItem do
		local row = { bestAsk = nil :: number?, bestBid = nil :: number?, askUnits = 0, bidUnits = 0 }
		for _, l in entry.asks do
			if isLive(l, now) then
				row.askUnits += l.remainingCount
				if row.bestAsk == nil or l.gemsPerCopy < row.bestAsk then
					row.bestAsk = l.gemsPerCopy
				end
			end
		end
		for _, l in entry.bids do
			if isLive(l, now) then
				row.bidUnits += l.remainingCount
				if row.bestBid == nil or l.gemsPerCopy > row.bestBid then
					row.bestBid = l.gemsPerCopy
				end
			end
		end
		if row.askUnits > 0 or row.bidUnits > 0 then
			out[itemId] = row
		end
	end
	return out
end

return BookIndex
