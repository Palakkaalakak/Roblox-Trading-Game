--!strict
-- Unit tests: Market order-book index, trade-ad tokens, perk scaffolding.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WildcardConfig = require(ReplicatedStorage.Shared.Config.WildcardConfig)

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

-- minimal live listing for index tests
local function listing(id: string, kind: string, itemId: string, price: number, remaining: number, extra: any?): any
	local l = {
		id = id,
		kind = kind,
		itemId = itemId,
		gemsPerCopy = price,
		remainingCount = remaining,
		status = "open",
		posterId = 1,
		posterName = "t",
	}
	for k, v in (extra or {}) :: any do
		l[k] = v
	end
	return l
end

-- one real registered itemId, or nil in Edit mode (services never boot there,
-- so the registry is empty — registry-dependent cases run in Play only)
local function someItemId(): string?
	local EconomyService = require(script.Parent.Parent.Services.EconomyService)
	for itemId in EconomyService.allItems() do
		return itemId
	end
	return nil
end

return {
	name = "BoardMarket",
	tests = {
		["wildcards: config is sane"] = function()
			eq(#WildcardConfig.Tokens >= 5, true, "enough tokens")
			local seen = {}
			for _, token in WildcardConfig.Tokens do
				assert(token.id:sub(1, 5) == "wild_", token.id .. " must be wild_-prefixed")
				assert(not seen[token.id], "duplicate id " .. token.id)
				seen[token.id] = true
				assert(#token.label > 0, token.id .. " needs a label")
				assert(#token.blurb > 0, token.id .. " needs a blurb")
				eq(WildcardConfig.isWildcard(token.id), true, token.id)
				local snap = WildcardConfig.snapshot(token.id) :: any
				eq(snap.isWildcard, true, "snapshot flag")
				eq(snap.name, token.label, "snapshot name")
			end
			eq(WildcardConfig.isWildcard("itm_1_1_stone_relic"), false, "real item is not a token")
			eq(WildcardConfig.isWildcard(nil), false, "nil is not a token")
		end,

		["wildcards: want-side tokens force ask-first, give-side rejected"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			-- gems-only offers avoid registry lookups, so these run in Edit too
			local gemsOnly = { items = {}, gems = 5 }

			-- token in want: valid AND flagged (postCore uses the flag to force ask-first)
			local ok, err, wild = TradeBoardService.checkSwapOffers(
				gemsOnly,
				{ items = { wild_upgrade = 1 }, gems = 0 }
			)
			eq(ok, true, "token want ok, err=" .. tostring(err))
			eq(wild, true, "token want flagged")

			-- token in give: rejected outright
			ok, err = TradeBoardService.checkSwapOffers(
				{ items = { wild_any = 1 }, gems = 0 },
				gemsOnly
			)
			eq(ok, false, "token give rejected")
			eq(err, "bad_offer", "give-side token error")

			-- unknown want id still rejected (empty registry answers nil too)
			ok, err = TradeBoardService.checkSwapOffers(
				gemsOnly,
				{ items = { itm_nope_never = 1 }, gems = 0 }
			)
			eq(ok, false, "unknown want rejected")
			eq(err, "unknown_item", "unknown want error")

			-- both sides empty is still rejected
			ok, err = TradeBoardService.checkSwapOffers({ items = {}, gems = 0 }, gemsOnly)
			eq(ok, false, "empty give rejected")
			eq(err, "empty_side", "empty give error")

			-- real-for-real needs a booted registry; runs in Play sessions
			local real = someItemId()
			if real then
				local okReal, errReal, wildReal = TradeBoardService.checkSwapOffers(
					{ items = { [real] = 1 }, gems = 0 },
					{ items = { [real] = 1 }, gems = 0 }
				)
				eq(okReal, true, "real-for-real ok, err=" .. tostring(errReal))
				eq(wildReal, false, "no wildcard flagged")
			end
		end,

		["index: asks and bids sort by price-time priority"] = function()
			local BookIndex = require(script.Parent.Parent.Services.BookIndex)
			local index = BookIndex.new()
			BookIndex.apply(index, listing("0000000002_a", "sell", "itm_x", 12, 3))
			BookIndex.apply(index, listing("0000000001_b", "sell", "itm_x", 9, 1))
			BookIndex.apply(index, listing("0000000003_c", "bulk", "itm_x", 7, 5))
			BookIndex.apply(index, listing("0000000004_d", "bulk", "itm_x", 8, 2))

			local asks, bids = BookIndex.book(index, "itm_x")
			eq(#asks, 2, "two asks")
			eq(asks[1].gemsPerCopy, 9, "cheapest ask first")
			eq(#bids, 2, "two bids")
			eq(bids[1].gemsPerCopy, 8, "highest bid first")

			-- price tie: higher boost wins, then newer id
			BookIndex.apply(index, listing("0000000005_e", "sell", "itm_x", 9, 1, { boostTier = 1 }))
			asks = BookIndex.book(index, "itm_x")
			eq(asks[1].id, "0000000005_e", "boosted tie-break first")
		end,

		["index: fills, cancels and expiry drop rows"] = function()
			local BookIndex = require(script.Parent.Parent.Services.BookIndex)
			local index = BookIndex.new()
			local l = listing("0000000001_a", "sell", "itm_y", 10, 2)
			BookIndex.apply(index, l)
			local asks = BookIndex.book(index, "itm_y")
			eq(#asks, 1, "listed")

			-- partial fill updates in place
			l.remainingCount = 1
			BookIndex.apply(index, l)
			asks = BookIndex.book(index, "itm_y")
			eq(asks[1].remainingCount, 1, "remaining updated")

			-- terminal fill removes
			l.remainingCount = 0
			l.status = "done"
			BookIndex.apply(index, l)
			asks = BookIndex.book(index, "itm_y")
			eq(#asks, 0, "done removed")

			-- cancelled removes
			local c = listing("0000000002_b", "bulk", "itm_y", 5, 4)
			BookIndex.apply(index, c)
			c.status = "cancelled"
			BookIndex.apply(index, c)
			local _, bids = BookIndex.book(index, "itm_y")
			eq(#bids, 0, "cancelled removed")

			-- expired filtered at read time
			local e = listing("0000000003_c", "sell", "itm_y", 6, 1, { expiresAt = 100 })
			BookIndex.apply(index, e)
			asks = BookIndex.book(index, "itm_y", 200)
			eq(#asks, 0, "expired hidden")
			asks = BookIndex.book(index, "itm_y", 50)
			eq(#asks, 1, "not yet expired shown")

			-- swaps never indexed
			BookIndex.apply(index, { id = "0000000004_d", kind = "swap", status = "open" })
			eq(index.byItem["itm_y"] ~= nil, true, "itm_y still present from e")
		end,

		["index: summary rolls up best prices and units"] = function()
			local BookIndex = require(script.Parent.Parent.Services.BookIndex)
			local index = BookIndex.new()
			BookIndex.apply(index, listing("0000000001_a", "sell", "itm_z", 12, 3))
			BookIndex.apply(index, listing("0000000002_b", "sell", "itm_z", 9, 2))
			BookIndex.apply(index, listing("0000000003_c", "bulk", "itm_z", 7, 10))
			local summary = BookIndex.summary(index)
			local row = summary["itm_z"]
			assert(row ~= nil, "row present")
			eq(row.bestAsk, 9, "best ask = cheapest sell")
			eq(row.bestBid, 7, "best bid = highest buy order")
			eq(row.askUnits, 5, "ask units summed")
			eq(row.bidUnits, 10, "bid units summed")
		end,

		["cross: maker price wins and the taker's over-escrow is refunded"] = function()
			local TBS = require(script.Parent.Parent.Services.TradeBoardService)
			local ask = { id = "a", kind = "sell", itemId = "itm_x", gemsPerCopy = 100, posterId = 1 }
			local bid = { id = "b", kind = "bulk", itemId = "itm_x", gemsPerCopy = 120, posterId = 2 }

			-- incoming ask crosses a resting higher bid: fills at the bid (maker),
			-- so the seller gets price improvement and there's nothing to refund
			local t = TBS.crossTerms(ask, bid)
			assert(t ~= nil, "ask should cross resting bid")
			eq(t.execPrice, 120, "exec at resting bid price")
			eq(t.refundPerCopy, 0, "no refund when the bid is the maker")
			eq(t.askId, "a", "ask id")
			eq(t.bidId, "b", "bid id")

			-- incoming bid crosses a resting lower ask: fills at the ask (maker),
			-- the buyer pays the ask and is refunded its bid over the ask
			local t2 = TBS.crossTerms(bid, ask)
			assert(t2 ~= nil, "bid should cross resting ask")
			eq(t2.execPrice, 100, "exec at resting ask price")
			eq(t2.refundPerCopy, 20, "buyer refunded bid minus ask")

			-- no cross when the spread isn't crossed
			local lowBid = { id = "c", kind = "bulk", itemId = "itm_x", gemsPerCopy = 90, posterId = 2 }
			eq(TBS.crossTerms(ask, lowBid), nil, "ask above bid: no cross")
			eq(TBS.crossTerms(lowBid, ask), nil, "bid below ask: no cross")

			-- never self-cross, never across items, never same-side
			local selfBid = { id = "d", kind = "bulk", itemId = "itm_x", gemsPerCopy = 120, posterId = 1 }
			eq(TBS.crossTerms(ask, selfBid), nil, "no self-cross")
			local otherItem = { id = "e", kind = "bulk", itemId = "itm_y", gemsPerCopy = 120, posterId = 2 }
			eq(TBS.crossTerms(ask, otherItem), nil, "no cross across items")
			local ask2 = { id = "f", kind = "sell", itemId = "itm_x", gemsPerCopy = 100, posterId = 2 }
			eq(TBS.crossTerms(ask, ask2), nil, "ask vs ask never crosses")
		end,

		["perks: listing order honors boost then recency"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local order = TradeBoardService.listingOrder
			local plain = { id = "0000000005_a", boostTier = 0, bumpedAt = 500 }
			local older = { id = "0000000001_b", boostTier = 0, bumpedAt = 100 }
			local boosted = { id = "0000000001_c", boostTier = 2, bumpedAt = 100 }
			eq(order(boosted, plain), true, "boost beats recency")
			eq(order(plain, older), true, "newer bump first among equals")
			-- sort round-trip
			local list = { plain, older, boosted }
			table.sort(list, order)
			eq(list[1].id, boosted.id, "boosted first")
			eq(list[2].id, plain.id, "then newest")
		end,
	},
}
