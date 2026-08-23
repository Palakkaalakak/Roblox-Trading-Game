--!strict
-- TradeBoardService: the central pillar of outstanding trades.
--
-- NO ESCROW. A listing is a PROMISE, not a deposit: posting only checks you
-- currently hold the goods, and they stay in your inventory — still usable,
-- still tradeable, still rollable — until something actually settles. The take
-- happens at settlement, and it is the real check:
--   * poster is in this server  -> normal profile delta
--   * poster is offline         -> conditional CAS write straight at their
--                                  profile key (safe because the profile is
--                                  session-locked, so "no live lock" means
--                                  nobody owns it) — see DataService.debitOffline
--   * poster is live elsewhere  -> we refuse ("busy") and the listing goes back
--                                  on the board to settle on a later attempt
-- If the take fails for any other reason, the poster can't cover the promise
-- any more (they spent it, traded it, burned it), so the LISTING IS CANCELLED
-- and nobody is paid for something that isn't there.
--
-- SWAP listings — "this for that", posted when nobody in the server wants it:
--   * posting checks the give-side is held; it is taken at settlement, from
--     both sides, before either delivery happens
--   * autoTrade = true : anyone who can pay the want-side accepts instantly;
--     works with the poster offline (goods delivered via mailbox)
--   * autoTrade = false: accepting registers INTEREST — the poster gets a
--     notification (online: toast, offline: queued for next login) and sees
--     interested traders on their listing to invite for a normal trade
--   * the want side may hold TRADE-AD TOKENS (WildcardConfig: Any/Upgrade/…)
--     instead of concrete items; any token forces the listing to ask-first,
--     because a fuzzy want can't auto-settle. Tokens never appear on the give
--     side and are never items.
--   * cancel/expiry just withdraws the promise — there is nothing to refund
--
-- BULK listings — gems-only buy orders for many copies of ONE item:
--   * posting checks you can cover count x gemsPerCopy; the gems stay spendable
--   * anyone contributes copies; each copy pays out gemsPerCopy, minus the
--     house gem tax; the poster's copies arrive via mailbox/direct
--   * order completes when filled; cancel just withdraws it
--
-- SELL listings — gems-only SHOP: sell Z copies of ONE item at Y gems each:
--   * posting checks you hold the Z copies; they stay yours until sold
--   * any buyer purchases N (N<=remaining): pays N x Y gems, gets the copies;
--     the seller receives N x Y minus house tax
--   * this is a CLEAN gem-denominated price per item (the Robux-resale
--     analogue) and is recorded straight into RAP — the most precise price
--     signal in the economy, since no barter imputation is needed
--   * completes when sold out; cancel just withdraws the remaining copies
--
-- All records live in a MemoryStore map (cross-server); every state change is
-- a CAS transform, so double-accepts / double-fills are impossible.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Enums)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local WildcardConfig = require(ReplicatedStorage.Shared.Config.WildcardConfig)
local BoothConfig = require(ReplicatedStorage.Shared.Config.BoothConfig)
local TradeAdConfig = require(ReplicatedStorage.Shared.Config.TradeAdConfig)
local TradeAdRules = require(ReplicatedStorage.Shared.Util.TradeAdRules)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)
local Tax = require(ReplicatedStorage.Shared.Util.Tax)

local Net = require(script.Parent.Parent.Net)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local BookIndex = require(script.Parent.BookIndex)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local NotificationService = require(script.Parent.NotificationService)
local ProductService = require(script.Parent.ProductService)

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
-- id -> record. Every server-scoped listing on this server: bots (which exist
-- nowhere else) and players who chose server scope. Complete by construction,
-- which is what lets countOpenFor count server slots exactly.
local memBoard: { [string]: any } = {}

-- Per-item order-book index (sell = asks, bulk = bids) serving the Market
-- tab's reads without touching MemoryStore. Updated incrementally on every
-- local post/cancel/fill; rebuilt from a full scan periodically so listings
-- posted on OTHER servers appear within a rebuild interval.
local bookIndex = BookIndex.new()
local BOOK_REBUILD_SECONDS = 60

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function newId(): string
	-- time prefix keeps range reads roughly newest-last, GUID guarantees unique
	return ("%010d_%s"):format(os.time(), HttpService:GenerateGUID(false):sub(1, 8))
end

local function mutate(id: string, fn: (any) -> any?): (any?, string?)
	-- Where the listing ACTUALLY lives decides the transform, never the poster
	-- id: server-scoped player ads live in memBoard too, so a positive poster
	-- id is no longer proof of a shared-store listing.
	-- In-memory transform is atomic: single Luau thread + no yields in fn gives
	-- the same CAS guarantee as UpdateAsync.
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

-- Take goods/gems from a listing's poster, wherever they are. This is what
-- replaces escrow: nothing is held when a listing is posted, so the goods are
-- only moved at settlement, and the take is what proves the poster can still
-- honour the listing.
--
--   bot            -> in-memory bot state
--   loaded here    -> normal profile delta
--   anywhere else  -> conditional CAS write straight at the profile key
--
-- Returns (true) or (false, reason). "busy" means the poster is live on another
-- server right now and the caller should leave the listing alone and retry;
-- anything else means they can no longer cover it and the listing is dead.
local function takeFromPoster(
	userId: number,
	items: { [string]: number },
	gems: number,
	source: string,
	claimId: string
): (boolean, string?)
	if userId < 0 then
		local neg = {}
		for itemId, count in items do
			neg[itemId] = -count
		end
		return bots().applyDelta(userId, { items = neg, gems = -gems }, source, claimId)
	end
	local player = Players:GetPlayerByUserId(userId)
	if player and DataService.isLoaded(player) then
		local neg = {}
		for itemId, count in items do
			neg[itemId] = -count
		end
		local ok, err = InventoryService.applyDelta(player, { items = neg, gems = -gems }, source, claimId)
		if ok then
			task.spawn(function()
				DataService.saveNow(player)
			end)
		end
		return ok, err
	end
	return DataService.debitOffline(userId, items, gems, claimId)
end

-- Does this user hold all of it right now? Used at POST time only — a listing
-- is a promise, and this stops you promising something you never had. It is
-- Purchased booth slots for a live player. Reads the profile directly rather
-- than going through BoothService, which requires this module — a top-level
-- require would cycle. Offline or unloaded posters get the base allowance.
local function boothExtraSlots(userId: number): number
	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return 0
	end
	local profile = DataService.getProfile(player)
	local booth = profile and profile.Booth
	return (booth and booth.extraSlots) or 0
end

-- deliberately not a reservation: the goods stay yours until settlement, and
-- the take at settlement is the real check.
local function posterHolds(userId: number, items: { [string]: number }, gems: number): (boolean, string?)
	if userId < 0 then
		return bots().canAfford(userId, { items = items, gems = gems })
	end
	local player = Players:GetPlayerByUserId(userId)
	if player == nil or not DataService.isLoaded(player) then
		return false, "loading"
	end
	return InventoryService.canAfford(player, { items = items, gems = gems })
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

-- bulk quote: what one copy pays, and the gem total the poster must be able to
-- cover. Nothing is ever held — the total is only checked, never taken.
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

-- Percentage the POSTER is giving away, from the viewer's perspective:
-- positive means the poster's side is worth more. Denominator is the WANT
-- side on purpose (asymmetric) -- it answers "how good a deal is this for
-- ME, relative to what I'd have to give up", not some symmetric spread.
-- An empty want side ("make me an offer") is legitimate, not an error, so it
-- reads as fair (0) rather than dividing by zero.
function TradeBoardService.valueDelta(giveValue: number, wantValue: number): number
	if wantValue <= 0 then
		return 0
	end
	local pct = (giveValue - wantValue) / wantValue * 100
	if pct >= 0 then
		return math.floor(pct + 0.5)
	end
	return math.ceil(pct - 0.5)
end

-- Total value of one side of a swap offer: per-item Value (EconomyService's
-- read, never RAP) times count, plus any gems on that side. An item that
-- can't be resolved (e.g. it vanished from the registry) contributes 0
-- rather than erroring -- this only feeds a UI meter, never a trade gate.
local function offerValue(offer: any): number
	local total = offer.gems or 0
	for itemId, count in offer.items do
		local snap = EconomyService.snapshot(itemId)
		local v = snap and snap.value and snap.value.value or 0
		total += v * count
	end
	return total
end

-- Pure validation for a swap payload's two offers (shape, non-empty, item
-- existence, trade-ad token rules). Tokens are legal ONLY on the want side;
-- a tokened want makes the listing fuzzy, so the caller must force ask-first.
-- Returns ok, err?, wantsWildcard.
function TradeBoardService.checkSwapOffers(give: any, want: any): (boolean, string?, boolean)
	if not Guard.checkOfferShape(give) or not Guard.checkOfferShape(want) then
		return false, "bad_offer", false
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
	if empty(give) or empty(want) then
		return false, "empty_side", false
	end
	local wantsWildcard = false
	for itemId in give.items do
		if WildcardConfig.isWildcard(itemId) then
			return false, "bad_offer", false
		end
	end
	for itemId in want.items do
		if WildcardConfig.isWildcard(itemId) then
			wantsWildcard = true
		elseif EconomyService.getItem(itemId) == nil then
			return false, "unknown_item", false
		end
	end
	return true, nil, wantsWildcard
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

-- CROSS-MATCH terms for a gem-denominated pair (sell = ask, bulk = bid). If a
-- fresh `incoming` order crosses a `resting` opposite order — same item, other
-- poster, and bid price >= ask price — return the execution terms, else nil.
--
-- Execution is at the RESTING (maker) order's price, so the taker gets price
-- improvement: a seller who crosses a higher resting bid is paid the bid, and a
-- buyer who crosses a lower resting ask pays only the ask. Nothing is escrowed,
-- so the buyer is simply charged the execution price — there is no difference to
-- refund. Pure — fully unit-testable.
function TradeBoardService.crossTerms(incoming: any, resting: any): any?
	if incoming.itemId ~= resting.itemId or incoming.posterId == resting.posterId then
		return nil
	end
	local ask, bid
	if incoming.kind == "sell" and resting.kind == "bulk" then
		ask, bid = incoming, resting
	elseif incoming.kind == "bulk" and resting.kind == "sell" then
		ask, bid = resting, incoming
	else
		return nil -- same side, or a non-order-book kind
	end
	if bid.gemsPerCopy < ask.gemsPerCopy then
		return nil -- spread not crossed
	end
	return {
		askId = ask.id,
		bidId = bid.id,
		execPrice = resting.gemsPerCopy,
	}
end

local cancelListing -- fwd decl (defined below; scan lazy-expires through it)
local reopenOrCancel -- fwd decl (defined with the crossing code, used by tryMatch)

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

-- cancel a listing (poster action or expiry). Any server may run this.
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
	BookIndex.apply(bookIndex, committed)
	-- Nothing to refund: without escrow a resting listing never held anything.
	-- Cancelling (or expiring) just withdraws the promise.
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
	-- trade-ad tokens resolve from WildcardConfig (they're not registry items)
	local function itemInfo(itemId: string): (string, string?, boolean)
		local token = WildcardConfig.byId(itemId)
		if token then
			return token.label, token.imageId, true
		end
		local item = EconomyService.getItem(itemId)
		return item and item.name or itemId, item and item.imageId or nil, false
	end
	local out = {
		id = listing.id,
		kind = listing.kind,
		posterId = listing.posterId,
		posterName = listing.posterName,
		mine = listing.posterId == viewerId,
		expiresAt = listing.expiresAt,
		-- The tier IN FORCE right now, not the one on the record: a paid
		-- window that has run out must stop showing a Featured pill.
		boostTier = TradeAdRules.effectiveTier(listing, os.time()),
		-- The boost's OWN clock, not the ad's. The feed row counts this down in
		-- its "⚡ BOOSTED · 23h left" badge, so a buyer keeps seeing the thing
		-- they paid for instead of having to trust that it worked. nil means
		-- "no paid window" (a pass perk, or an unboosted ad).
		boostExpiresAt = listing.boostExpiresAt,
		scope = listing.scope or TradeAdConfig.Scopes.Global, -- legacy listings predate the field
		-- poster present on THIS server right now -- drives the scope filter and
		-- the "Live" pill: an ad from someone present settles immediately.
		here = listing.posterId > 0 and Players:GetPlayerByUserId(listing.posterId) ~= nil,
		perks = { priority = (listing.perks and listing.perks.priority) == true },
	}
	if listing.kind == "swap" then
		out.autoTrade = listing.autoTrade
		out.giveValue = offerValue(listing.give)
		out.wantValue = offerValue(listing.want)
		out.valueDelta = TradeBoardService.valueDelta(out.giveValue, out.wantValue)
		local function describeOffer(offer)
			local items = {}
			for itemId, count in offer.items do
				local name, imageId, wildcard = itemInfo(itemId)
				-- Per-item UNIT value. The feed used to ship only the side
				-- totals, so a chip could show an icon and a count and nothing
				-- a trader could judge -- every real trade-ad board shows
				-- icon + name + value per item, and the number was already
				-- being computed here for offerValue.
				local snap = not wildcard and EconomyService.snapshot(itemId) or nil
				local unitValue = snap and snap.value and snap.value.value or nil
				table.insert(items, {
					itemId = itemId,
					name = name,
					imageId = imageId,
					count = count,
					value = unitValue,
					wildcard = wildcard or nil,
				})
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

-- Display order is TradeAdRules.order and nothing else. It used to be a
-- second comparator living here, which silently ignored perks.priority and
-- boost expiry -- a gamepass players had paid for did nothing they could
-- see. One rule, one place, so that cannot recur.
local function listingOrder(a: any, b: any): boolean
	return TradeAdRules.order(a, b, os.time())
end
TradeBoardService.listingOrder = listingOrder

local function handleGetBoard(player: Player)
	local raw = {}
	local others = 0
	local own = 0
	-- newest-first scan: the viewer's own posts are ALWAYS included (up to
	-- CLIENT_OWN_EXTRA) even past the page cut, so "I posted it but can't
	-- see it" is structurally impossible.
	scanListings(SCAN_CAP, function(l)
		local mine = l.posterId == player.UserId
		if mine and own < CLIENT_OWN_EXTRA then
			own += 1
			table.insert(raw, l)
		elseif not mine and others < CLIENT_PAGE then
			others += 1
			table.insert(raw, l)
		end
		if others >= CLIENT_PAGE and own >= CLIENT_OWN_EXTRA then
			return false -- both quotas filled: stop paging
		end
		return nil
	end)
	table.sort(raw, listingOrder)
	local listings = {}
	for _, l in raw do
		table.insert(listings, describe(l, player.UserId))
	end
	return { ok = true, listings = listings }
end

--------------------------------------------------------------------------------
-- Market reads (per-item order book, served from the in-memory index)
--------------------------------------------------------------------------------

-- Directory: one row per registered item — live stats + best prices. The
-- whole payload is a few dozen small rows; no MemoryStore touched.
-- Sold-out replacement variants ("... Mk3") are internal machinery: the crafting
-- service mints them so a spent station always has something to offer. GetCatalog
-- already keeps the unused ones out of item pickers; the market directory holds to
-- the same rule, or the front page fills with near-identical rows for items nobody
-- owns. The set is fixed for the life of the server, so resolve it once. Lazy
-- require: CraftingService pulls in this service, and a top-level require cycles.
local generatedIds: { [string]: boolean }? = nil
local function generatedVariants(): { [string]: boolean }
	if generatedIds == nil then
		local resolved = {}
		pcall(function()
			resolved = require(script.Parent.CraftingService).generatedOutputIds()
		end)
		generatedIds = resolved
	end
	return generatedIds :: any
end

local function handleGetMarketSummary(player: Player)
	local now = os.time()
	local books = BookIndex.summary(bookIndex, now)
	local generated = generatedVariants()
	local items = {}
	-- snapshotCached, NOT snapshot: a cold record costs a DataStore round trip,
	-- and sweeping the registry through the blocking read stalls this call for
	-- seconds on a fresh server. EconomyService warms the cache at boot; until
	-- it finishes we serve what's ready and tell the client to keep asking.
	for itemId in EconomyService.allItems() do
		local snap = EconomyService.snapshotCached(itemId)
		if snap and generated[itemId] and (snap.supply and snap.supply.value or 0) <= 0 then
			snap = nil -- a replacement nobody has minted yet
		end
		if snap then
			local book = books[itemId]
			snap.bestAsk = book and book.bestAsk or nil
			snap.bestBid = book and book.bestBid or nil
			snap.askUnits = book and book.askUnits or 0
			snap.bidUnits = book and book.bidUnits or 0
			table.insert(items, snap)
		end
	end
	return { ok = true, items = items, now = now, warming = not EconomyService.isWarm() }
end

-- One item's live book: asks cheapest-first, bids highest-first.
local function handleGetItemBook(player: Player, itemId: any)
	if not Guard.isString(itemId, 64) then
		return { ok = false, err = "bad_args" }
	end
	if EconomyService.getItem(itemId) == nil then
		return { ok = false, err = "unknown_item" }
	end
	local asks, bids = BookIndex.book(bookIndex, itemId :: string, os.time())
	local function describeAll(list)
		local out = {}
		for _, l in list do
			table.insert(out, describe(l, player.UserId))
		end
		return out
	end
	return { ok = true, asks = describeAll(asks), bids = describeAll(bids) }
end

-- Rebuild the index from a full board walk: picks up listings posted on other
-- servers and self-heals any drift. Cheap — one paged scan per interval.
local function rebuildBookIndex()
	local fresh = BookIndex.new()
	scanListings(SCAN_CAP, function(l)
		BookIndex.apply(fresh, l)
		return nil
	end)
	bookIndex = fresh
end

--------------------------------------------------------------------------------
-- Posting
--------------------------------------------------------------------------------

-- Scope routes an ad to a store, so an unrecognised one is a hard error rather
-- than a default: a global ad misrouted into server memory would disappear at
-- the next restart with no trace of why.
function TradeBoardService.validateScope(scope: any): boolean
	return scope == TradeAdConfig.Scopes.Server or scope == TradeAdConfig.Scopes.Global
end

-- Scope describes REACH, and a memBoard listing reaches exactly one server, so
-- a bot ad is server-scoped by definition -- it physically cannot be seen from
-- anywhere else. Calling it global would advertise it on the global tab as a
-- whole-game listing no other server can see, and strip the server tab of the
-- listings that make a low-population board look alive. Single source of truth
-- for the routing decision: scope and store can never disagree.
function TradeBoardService.scopeFor(userId: number, requestedScope: string): string
	if userId < 0 then
		return TradeAdConfig.Scopes.Server
	end
	return requestedScope
end

-- Does this scope live in the server-local map rather than the shared store?
function TradeBoardService.storesInMemory(scope: string): boolean
	return scope == TradeAdConfig.Scopes.Server
end

-- Count this poster's live ads in one scope out of any collection of listings.
-- Split out so the counting rule is testable without a store: the callers below
-- differ only in which collection they can see.
function TradeBoardService.countOpenIn(listings: any, userId: number, scope: string, now: number?): number
	local at = now or os.time()
	local n = 0
	for _, l in listings do
		if
			l ~= nil
			and l.posterId == userId
			and l.scope == scope
			and l.status == "open"
			and (l.expiresAt == nil or at <= l.expiresAt)
		then
			n += 1
		end
	end
	return n
end

-- How many open ads this player already holds in one scope.
--
-- Server scope is EXACT: memBoard is by construction the complete set of
-- server-scoped listings on this server, so walking it counts every one. It is
-- a plain in-memory table, so no cap and no store call.
--
-- Global scope is BEST-EFFORT above SCAN_CAP: there is no by-poster index and
-- no cross-server bookkeeping, so it reuses the capped newest-first scan the
-- board already keeps warm. Past SCAN_CAP a player's oldest global ads fall
-- outside the window and go uncounted. That error is deliberate and one-way --
-- an uncounted ad hands the player an extra slot, it never blocks them. Wrongly
-- denying a slot someone PAID for (see the "+1 Ad Slot" product) is the worse
-- failure, so the approximation errs toward letting them post.
function TradeBoardService.countOpenFor(userId: number, scope: string): number
	if TradeBoardService.storesInMemory(scope) then
		return TradeBoardService.countOpenIn(memBoard, userId, scope)
	end
	return TradeBoardService.countOpenIn(TradeBoardService.rawOpenListings(), userId, scope)
end

-- Pure shape helper for the perks stamped onto a listing. Both stamp sites
-- (postCore at post time, refreshPresenceExpiry's re-stamp) call this so they
-- can never drift into different field names or shapes. Never returns nil for
-- either field -- TradeAdRules.effectiveTier reads listing.perks.priority
-- directly, and a nil there (vs. false) would be a silent shape bug.
function TradeBoardService.perksFor(profile: any): { priority: boolean, duration: boolean }
	local perks = profile and profile.AdPerks
	return {
		priority = (perks and perks.priority) == true,
		duration = (perks and perks.duration) == true,
	}
end

local function postCore(userId: number, userName: string, payload: any)
	if type(payload) ~= "table" then
		return { ok = false, err = "bad_args" }
	end

	local requestedScope = payload.scope or TradeAdConfig.Scopes.Global
	if not TradeBoardService.validateScope(requestedScope) then
		return { ok = false, err = "bad_scope" }
	end
	local scope = TradeBoardService.scopeFor(userId, requestedScope)

	-- Per-poster limits, per scope: 3 free ads on this server AND 3 globally,
	-- plus whatever headroom the player bought. Bots stay unlimited — throttling
	-- them would starve the simulated market. Still bounded by the global board
	-- cap below, which protects the store rather than the player.
	-- The poster is by definition online here (they just called the remote), so
	-- resolving through Players is enough -- DataService has no by-userId
	-- profile lookup, and adding one for this would be dead weight.
	local posterProfile: any = nil
	if userId > 0 then
		local posterPlayer = Players:GetPlayerByUserId(userId)
		posterProfile = posterPlayer and DataService.getProfile(posterPlayer) or nil
		local extraSlots = (posterProfile and posterProfile.TradeAds and posterProfile.TradeAds.extraSlots) or 0
		if not TradeAdRules.canPost(TradeBoardService.countOpenFor(userId, scope), extraSlots) then
			return { ok = false, err = "ad_slots_full" }
		end
	end

	if lastKnownCount >= MAX_BOARD_LISTINGS then
		return { ok = false, err = "board_full" }
	end

	local now = os.time()
	local id = newId()
	local listing: any

	if payload.kind == "swap" then
		local offersOk, offersErr, wantsWildcard = TradeBoardService.checkSwapOffers(payload.give, payload.want)
		if not offersOk then
			return { ok = false, err = offersErr }
		end

		-- NO ESCROW: the give side stays in the poster's inventory and remains
		-- theirs to use. We only check they hold it right now, so you can't list
		-- what you don't have; it's taken at settlement instead.
		local holdsIt, holdErr = posterHolds(userId, payload.give.items, payload.give.gems)
		if not holdsIt then
			return { ok = false, err = holdErr }
		end

		listing = {
			id = id,
			kind = "swap",
			posterId = userId,
			posterName = userName,
			give = payload.give,
			want = payload.want,
			autoTrade = payload.autoTrade == true and not wantsWildcard,
			interested = {},
			status = "open",
			createdAt = now,
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
		local perCopy, gemTotal = TradeBoardService.bulkQuote(payload.count, payload.gems)
		if perCopy < 1 then
			return { ok = false, err = "gems_too_low" } -- must pay >= 1 gem per copy
		end

		-- checked, never held: the gems stay spendable until copies actually arrive
		local holdsIt, holdErr = posterHolds(userId, {}, gemTotal)
		if not holdsIt then
			return { ok = false, err = holdErr }
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

		-- Booth slots cap how many things you can have for sale at once. Players
		-- only: bots have no booth. Applies to `sell` alone — swaps and buy
		-- orders are not what a booth displays, so they stay uncapped.
		if userId > 0 and BoothConfig.Enabled then
			local slots = BoothConfig.slotsFor(boothExtraSlots(userId))
			if #TradeBoardService.sellListingsOf(userId) >= slots then
				return { ok = false, err = "slot_cap" }
			end
		end

		-- nothing held: the copies stay usable/tradeable while they sit for sale
		local holdsIt, holdErr = posterHolds(userId, { [payload.itemId] = payload.count }, 0)
		if not holdsIt then
			return { ok = false, err = holdErr }
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
			v = 1,
		}
	else
		return { ok = false, err = "bad_kind" }
	end

	-- Every listing carries boost/bump/TTL fields; paid perks are a field write
	-- away (see boostListing).
	listing.boostTier = 0
	listing.bumpedAt = now
	listing.scope = scope
	-- An ad starts with only its scope's grace window on the clock, NOT the old
	-- multi-day board TTL. The presence sweep is what keeps it alive while the
	-- poster is in game, so the starting clock has to be short enough that the
	-- sweep is actually the thing extending it. Seeding a week here would make
	-- the sweep dead code (shouldRefresh only fires near expiry) and every ad
	-- would outlive its poster by days -- which is exactly the behaviour the
	-- presence model replaces.
	listing.expiresAt = now + (listing.ttlSeconds or TradeAdRules.refreshedExpiry(scope, 0))

	-- Snapshot the poster's pass perks onto the ad. Sorting runs on servers the
	-- poster is not in, so there is nobody to ask about pass ownership there;
	-- the answer has to travel with the listing. Reuses posterProfile from the
	-- slot-limit check above (nil for bots/unloaded profiles, which is fine --
	-- perksFor treats nil as no perks) instead of looking the profile up again.
	listing.perks = TradeBoardService.perksFor(posterProfile)

	local stored = true
	-- Storage follows scope and nothing else. scopeFor has already forced bots to
	-- server scope, so this single test keeps scope and store in lockstep: a
	-- memBoard listing is always server-scoped, and vice versa.
	if TradeBoardService.storesInMemory(scope) then
		memBoard[id] = listing -- server-local order book, never fails
	else
		stored = pcall(function()
			board:SetAsync(id, listing, EconomyConfig.BoardListingTTLSeconds + 24 * 3600)
		end)
	end
	if stored then
		BookIndex.apply(bookIndex, listing)
	end
	if not stored then
		-- nothing to give back: without escrow the goods never left the poster
		return { ok = false, err = "store_error" }
	end
	actorSave(userId)
	AnalyticsService.log("board_posted", { id = id, kind = listing.kind, userId = userId })

	-- matching on post: swaps look for their mirror; gem-denominated orders
	-- (sell/bulk) cross against the resting book automatically
	if listing.kind == "swap" then
		task.spawn(TradeBoardService.tryMatch, listing)
	elseif listing.kind == "sell" or listing.kind == "bulk" then
		task.spawn(TradeBoardService.tryCross, listing)
	end
	-- scope travels back so the poster's client can offer exactly the banked
	-- credits that are applicable to the ad it just created (a credit whose
	-- scope differs is rejected by canApplySku)
	return { ok = true, id = id, scope = scope }
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

	-- No escrow, so take BOTH give-sides first and only deliver if both succeed.
	-- If either poster can no longer cover their side, that listing is dead: it
	-- gets cancelled and anything already taken is handed straight back.
	local tookMine, mineErr = takeFromPoster(
		mine.posterId, mine.give.items, mine.give.gems, Enums.GrantSource.Board, "board_match_take_" .. mine.id)
	if not tookMine then
		reopenOrCancel(mine, mineErr)
		reopenOrCancel(theirs, "partner_gone")
		return
	end
	local tookTheirs, theirsErr = takeFromPoster(
		theirs.posterId, theirs.give.items, theirs.give.gems, Enums.GrantSource.Board, "board_match_take_" .. theirs.id)
	if not tookTheirs then
		-- give the first side back untouched, then drop whichever listing failed
		deliver(mine.posterId, mine.give.items, mine.give.gems, Enums.GrantSource.Refund, "board_match_undo_" .. mine.id)
		reopenOrCancel(theirs, theirsErr)
		reopenOrCancel(mine, "partner_gone")
		return
	end

	-- both sides secured: deliver (gem tax on each receiving side)
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


-- Syndicate XP for a board fill. Lazy require avoids a require cycle, and
-- addXp already no-ops for bots and for anyone not in a syndicate.
local function syndicateXp(userId: number)
	if userId < 0 then
		return
	end
	local ok, Syndicate = pcall(function()
		return require(script.Parent.SyndicateService)
	end)
	if ok then
		Syndicate.addXp(userId, "boardFill")
	end
end

--------------------------------------------------------------------------------
-- Order-book crossing: a resting ask (sell) and bid (bulk) that cross execute
-- automatically, no manual Buy/Contribute. Continuous double auction.
--------------------------------------------------------------------------------

-- reserve up to `qty` copies off a live listing (CAS); returns committed record
-- (or nil) and the count actually taken.
local function reserveCopies(id: string, qty: number): (any, number)
	local taken = 0
	local committed = mutate(id, function(l)
		if l.status ~= "open" then
			return nil, "gone"
		end
		taken = math.min(qty, l.remainingCount)
		if taken <= 0 then
			return nil, "empty"
		end
		l.remainingCount -= taken
		if l.remainingCount <= 0 then
			l.status = "done"
		end
		l.v += 1
		return l
	end)
	if committed == nil then
		return nil, 0
	end
	return committed, taken
end

-- hand `qty` copies back to a listing that was over-reserved (reopens if needed)
local function unreserveCopies(id: string, qty: number): any
	return mutate(id, function(l)
		l.remainingCount += qty
		if l.status == "done" then
			l.status = "open"
		end
		l.v += 1
		return l
	end)
end

-- A settlement take failed. "busy" is transient — the poster is live on another
-- server this instant — so the listing goes back on the board and will settle on
-- a later attempt. Any other reason means they can't cover it any more (spent,
-- traded away, deleted), so the listing is cancelled: this is the promise-based
-- model's whole point, per "if the item's gone, just remove the offer".
reopenOrCancel = function(listing: any, reason: string?)
	if reason == "busy" or reason == "loading" then
		local reopened = mutate(listing.id, function(l)
			if l.status == "claimed" then
				l.status = "open"
				l.v += 1
				return l
			end
			return nil, "not_claimed"
		end)
		if reopened then
			BookIndex.apply(bookIndex, reopened)
		end
		return
	end
	cancelListing(listing, "poster_cannot_cover")
end

-- Execute ONE cross between a resting ask (sell) and bid (bulk) at execPrice.
-- Reserves min-available on both (revert on shortfall), delivers copies to the
-- buyer, taxed gems to the seller, records the
-- clean price into RAP, and drops any listing that filled. Returns copies traded.
local function crossFillOnce(askId: string, bidId: string, execPrice: number): number
	local a = getListing(askId)
	local b = getListing(bidId)
	if a == nil or b == nil or a.status ~= "open" or b.status ~= "open" then
		return 0
	end
	local qty = math.min(a.remainingCount, b.remainingCount)
	if qty <= 0 then
		return 0
	end
	local itemId = a.itemId

	-- reserve on the ask, then the same amount on the bid; if the bid can't
	-- cover it (raced), hand the shortfall back to the ask
	local askCommit, tookAsk = reserveCopies(askId, qty)
	if askCommit == nil or tookAsk <= 0 then
		return 0
	end
	local bidCommit, tookBid = reserveCopies(bidId, tookAsk)
	if bidCommit == nil or tookBid <= 0 then
		local rev = unreserveCopies(askId, tookAsk)
		if rev then
			BookIndex.apply(bookIndex, rev)
		end
		return 0
	end
	if tookBid < tookAsk then
		local rev = unreserveCopies(askId, tookAsk - tookBid)
		if rev then
			askCommit = rev
		end
	end
	local q = tookBid

	BookIndex.apply(bookIndex, askCommit)
	BookIndex.apply(bookIndex, bidCommit)

	-- unique per fill between this pair: remaining strictly decreases each time
	local nonce = ("%d_%d"):format(askCommit.remainingCount, bidCommit.remainingCount)

	-- No escrow: take the copies off the seller and the gems off the buyer
	-- BEFORE anything is delivered. The buyer is only ever charged the execution
	-- price, so there is no overpayment to refund any more.
	local gross = q * execPrice
	local tookCopies, copiesErr = takeFromPoster(
		askCommit.posterId, { [itemId] = q }, 0, Enums.GrantSource.Board,
		("cross_take_copies_%s_%s_%s"):format(askId, bidId, nonce))
	if not tookCopies then
		local revA = unreserveCopies(askId, q)
		if revA then BookIndex.apply(bookIndex, revA) end
		local revB = unreserveCopies(bidId, q)
		if revB then BookIndex.apply(bookIndex, revB) end
		reopenOrCancel(askCommit, copiesErr)
		return 0
	end
	local tookGems, gemsErr = takeFromPoster(
		bidCommit.posterId, {}, gross, Enums.GrantSource.Board,
		("cross_take_gems_%s_%s_%s"):format(askId, bidId, nonce))
	if not tookGems then
		-- hand the seller's copies straight back, then restore both books
		deliver(askCommit.posterId, { [itemId] = q }, 0, Enums.GrantSource.Refund,
			("cross_undo_copies_%s_%s_%s"):format(askId, bidId, nonce))
		local revA = unreserveCopies(askId, q)
		if revA then BookIndex.apply(bookIndex, revA) end
		local revB = unreserveCopies(bidId, q)
		if revB then BookIndex.apply(bookIndex, revB) end
		reopenOrCancel(bidCommit, gemsErr)
		return 0
	end

	-- copies to the buyer
	deliver(bidCommit.posterId, { [itemId] = q }, 0, Enums.GrantSource.Board, ("cross_copies_%s_%s_%s"):format(askId, bidId, nonce))
	-- taxed gems to the seller
	local net, cut = Tax.split(gross)
	deliver(askCommit.posterId, {}, net, Enums.GrantSource.Board, ("cross_pay_%s_%s_%s"):format(askId, bidId, nonce))
	actorSave(askCommit.posterId)
	actorSave(bidCommit.posterId)

	-- a direct gems-for-item fill at a clean per-copy price — feed RAP/Value
	EconomyService.recordSale(itemId, execPrice, q)

	if askCommit.status == "done" then
		removeListing(askId)
	end
	if bidCommit.status == "done" then
		removeListing(bidId)
	end

	announce(("%s ⇄ %s: %d x %s @ %d gems"):format(askCommit.posterName, bidCommit.posterName, q, itemLabel(itemId), execPrice))
	syndicateXp(askCommit.posterId)
	syndicateXp(bidCommit.posterId)
	AnalyticsService.log("board_crossed", { ask = askId, bid = bidId, qty = q, price = execPrice, tax = cut })
	return q
end

-- After a fresh sell/bulk post, cross it against the best resting opposite
-- orders until it's filled or nothing crosses. The index is already price-time
-- sorted, so the best-priced maker matches first.
function TradeBoardService.tryCross(incoming: any)
	if incoming.kind ~= "sell" and incoming.kind ~= "bulk" then
		return
	end
	local itemId = incoming.itemId
	for _ = 1, 256 do -- bounded: a fill either progresses or evicts a stale row
		local cur = getListing(incoming.id)
		if cur == nil or cur.status ~= "open" or (cur.remainingCount or 0) <= 0 then
			return
		end
		local asks, bids = BookIndex.book(bookIndex, itemId, os.time())
		local makers = incoming.kind == "sell" and bids or asks
		local terms, chosen
		for _, m in makers do
			if m.id ~= incoming.id and m.posterId ~= incoming.posterId then
				local t = TradeBoardService.crossTerms(cur, m)
				if t then
					terms, chosen = t, m
					break
				end
			end
		end
		if terms == nil then
			return -- nothing crosses; the remainder rests on the book
		end
		local q = crossFillOnce(terms.askId, terms.bidId, terms.execPrice)
		if q <= 0 then
			-- the index row was stale (filled elsewhere); resync it from the
			-- authoritative record, or evict it, then try the next maker
			local fresh = getListing(chosen.id)
			if fresh then
				BookIndex.apply(bookIndex, fresh)
			else
				chosen.status = "done"
				chosen.remainingCount = 0
				BookIndex.apply(bookIndex, chosen)
			end
		end
	end
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
	BookIndex.apply(bookIndex, committed)

	-- charge the contributor the copies
	local paid, payErr = actorDelta(
		userId,
		{ items = { [committed.itemId] = -taken } },
		Enums.GrantSource.Bulk
	)
	if not paid then
		local reverted = mutate(id, function(l)
			l.remainingCount += taken
			if l.status == "done" then
				l.status = "open"
			end
			l.v += 1
			return l
		end)
		if reverted then
			BookIndex.apply(bookIndex, reverted)
		end
		return { ok = false, err = payErr }
	end

	-- No escrow: take the gems off the buy-order's poster before paying anyone.
	-- If they can't cover it any more, undo the contributor's copies and drop
	-- the order.
	local gross = taken * committed.gemsPerCopy
	local tookGems, gemsErr = takeFromPoster(
		committed.posterId, {}, gross, Enums.GrantSource.Bulk,
		("bulk_take_%s_%d_%d"):format(id, userId, committed.remainingCount))
	if not tookGems then
		actorDelta(userId, { items = { [committed.itemId] = taken } }, Enums.GrantSource.Refund)
		local reverted = mutate(id, function(l)
			l.remainingCount += taken
			if l.status == "done" then
				l.status = "open"
			end
			l.v += 1
			return l
		end)
		if reverted then
			BookIndex.apply(bookIndex, reverted)
			reopenOrCancel(reverted, gemsErr)
		end
		return { ok = false, err = gemsErr == "busy" and "poster_busy" or "poster_cannot_pay" }
	end

	-- pay out (taxed) + ship copies to the poster
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
	syndicateXp(userId)
	syndicateXp(committed.posterId)
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
	BookIndex.apply(bookIndex, committed)

	-- charge the buyer gems for the copies
	local spent = taken * committed.gemsPerCopy
	local paid, payErr = actorDelta(userId, { gems = -spent }, Enums.GrantSource.Board)
	if not paid then
		-- put the copies back on sale
		local reverted = mutate(id, function(l)
			l.remainingCount += taken
			if l.status == "done" then
				l.status = "open"
			end
			l.v += 1
			return l
		end)
		if reverted then
			BookIndex.apply(bookIndex, reverted)
		end
		return { ok = false, err = payErr }
	end

	-- No escrow: take the copies off the seller before handing them over. If the
	-- seller no longer has them, refund the buyer's gems and drop the listing —
	-- the promise went stale, so the offer disappears.
	local tookCopies, copiesErr = takeFromPoster(
		committed.posterId, { [committed.itemId] = taken }, 0, Enums.GrantSource.Board,
		("sell_take_%s_%d_%d"):format(id, userId, committed.remainingCount))
	if not tookCopies then
		actorDelta(userId, { gems = spent }, Enums.GrantSource.Refund)
		local reverted = mutate(id, function(l)
			l.remainingCount += taken
			if l.status == "done" then
				l.status = "open"
			end
			l.v += 1
			return l
		end)
		if reverted then
			BookIndex.apply(bookIndex, reverted)
			reopenOrCancel(reverted, copiesErr)
		end
		return { ok = false, err = copiesErr == "busy" and "seller_busy" or "seller_no_longer_has_it" }
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
	syndicateXp(userId)
	syndicateXp(committed.posterId)
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

-- The paid apply path: this is what ApplyAdBoost and auto-renew both land on.
-- Higher boostTier sorts first (see TradeAdRules.order), extendSeconds buys
-- both extra uptime AND the placement window, and the bump refreshes recency.
--
-- Placement gets its OWN clock. expiresAt is how long the ad lives and the
-- presence sweep may extend it for free; boostExpiresAt is how long the buyer
-- paid to sit on top and NOTHING extends it but another purchase. Extending an
-- unexpired window adds to it rather than restarting it, so stacking two
-- purchases gives the buyer the time they paid for.
function TradeBoardService.boostListing(id: string, tier: number, extendSeconds: number?)
	local committed = mutate(id, function(l)
		if l.status ~= "open" then
			return nil, "gone"
		end
		local now = os.time()
		l.boostTier = math.max(l.boostTier or 0, tier)
		l.bumpedAt = now
		if extendSeconds and extendSeconds > 0 then
			l.expiresAt = (l.expiresAt or now) + extendSeconds
			local boostFrom = l.boostExpiresAt
			if boostFrom == nil or boostFrom < now then
				boostFrom = now
			end
			l.boostExpiresAt = boostFrom + extendSeconds
		end
		l.v += 1
		return l
	end)
	if committed == nil then
		return { ok = false, err = "gone" }
	end
	BookIndex.apply(bookIndex, committed)
	return { ok = true }
end

-- Published for the boost remotes: they have to resolve an id to a listing
-- before charging for it. Same function the internals already use; only the
-- visibility changes.
function TradeBoardService.getListing(id: string): any
	return getListing(id)
end

-- Bank a purchased credit. This is the ONLY thing a receipt does — buying and
-- applying are separate actions now, so a receipt never has to decide whether
-- a listing is still around to take it. It must never fail: it builds the
-- container it writes into rather than assuming migration ran.
function TradeBoardService.bankCredit(profile: any, skuId: string)
	profile.TradeAds = profile.TradeAds or { extraSlots = 0, credits = {} }
	profile.TradeAds.credits = profile.TradeAds.credits or {}
	profile.TradeAds.credits[skuId] = (profile.TradeAds.credits[skuId] or 0) + 1
end

-- Whether spending a banked credit on `listing` is allowed. Pure so it can be
-- tested without a profile write: the caller must own the ad, its scope must
-- match the SKU (a server SKU must not buy global reach at the server price),
-- and a featured SKU needs a free slot in the strip.
function TradeBoardService.canApplySku(listing: any?, sku: any, openFeatured: number, callerId: number): boolean
	if listing == nil or listing.status ~= "open" then
		return false
	end
	if listing.posterId ~= callerId then
		return false
	end
	if listing.scope ~= sku.scope then
		return false
	end
	if sku.tier >= TradeAdConfig.BoostTier.Featured and openFeatured <= 0 then
		return false
	end
	return true
end

-- Pure decision for the presence sweep's auto-renew: extend a featured ad on
-- the poster's dime only when every one of these holds. `credits` is the
-- caller's already-loaded credit table for the SKU that matches this scope's
-- featured tier, kept pure by taking the count directly rather than a profile.
--
-- `openFeatured` must EXCLUDE this listing's own slot. A featured ad occupies
-- a slot by definition, so counting itself made the pool read as full in the
-- only situation renewal exists for -- a full strip -- and renewal never fired.
function TradeBoardService.shouldAutoRenew(
	listing: any,
	credits: number,
	autoRenew: boolean,
	openFeatured: number,
	now: number
): boolean
	if not autoRenew then
		return false
	end
	if credits <= 0 then
		return false
	end
	if openFeatured <= 0 then
		return false
	end
	if listing.status ~= "open" then
		return false
	end
	-- effectiveTier, not the raw field: an ad whose paid window already lapsed
	-- is not featured any more and must re-buy rather than auto-renew.
	if TradeAdRules.effectiveTier(listing, now) < TradeAdConfig.BoostTier.Featured then
		return false
	end
	return TradeAdRules.shouldRefresh(listing, now)
end

-- Whether a scope has auto-renew enabled. A missing table means no migration
-- ran yet, which must read as "off" everywhere, not crash.
local function autoRenewEnabled(profile: any, scope: string): boolean
	local autoRenew = profile.TradeAds and profile.TradeAds.autoRenew
	return autoRenew ~= nil and autoRenew[scope] == true
end

-- The first featured SKU for this scope that the profile still holds a credit
-- for. Auto-renew spends whichever featured credit is available rather than
-- preferring one SKU over another -- there is nothing to prefer, they land the
-- same tier.
local function heldFeaturedSku(profile: any, scope: string): any
	local credits = (profile.TradeAds and profile.TradeAds.credits) or {}
	for _, sku in TradeAdConfig.skusForScope(scope) do
		if sku.tier >= TradeAdConfig.BoostTier.Featured and (credits[sku.id] or 0) > 0 then
			return sku
		end
	end
	return nil
end

-- Apply a SKU to a listing. Bump refreshes rank, tier lifts placement, seconds
-- buy uptime that survives the poster logging out.
-- Returns whether the listing actually took the boost: canApplySku reads a
-- scanned copy, but boostListing re-checks the live record, so an ad can still
-- die in between. The caller re-credits on false rather than swallowing a
-- spent credit.
local function applySku(listingId: string, sku: any): boolean
	local res = TradeBoardService.boostListing(listingId, sku.tier, sku.seconds > 0 and sku.seconds or nil)
	return res.ok == true
end

-- Push one listing's death clock if it is close to expiring. Returns whether
-- anything changed, so the caller only spends a store write when it did.
--
-- This deliberately assigns expiresAt and NOTHING else. Moving bumpedAt here
-- would hand an AFK player permanent rank one for free and make every paid
-- placement worthless; writing boostExpiresAt here would do the same to the
-- purchased placement window, turning one 10 R$ boost into a permanent one.
-- Both invariants are covered by tests for that reason.
function TradeBoardService.applyPresenceRefresh(listing: any, now: number): boolean
	if listing.status ~= "open" then
		return false
	end
	if not TradeAdRules.shouldRefresh(listing, now) then
		return false
	end
	listing.expiresAt = TradeAdRules.refreshedExpiry(listing.scope or TradeAdConfig.Scopes.Global, now)
	return true
end

-- Pure eligibility decision: should THIS server refresh THIS listing right
-- now? `isOnline` is injected (rather than calling Players directly) so tests
-- can exercise every guard -- bot exclusion, offline poster, non-open status,
-- outside the refresh window -- without touching real Players or MemoryStore.
-- Bots use negative posterId and must never be refreshed by presence: only a
-- real, connected player keeps an ad alive.
function TradeBoardService.shouldPresenceRefresh(listing: any, now: number, isOnline: (number) -> boolean): boolean
	if listing.posterId == nil or listing.posterId <= 0 then
		return false
	end
	if not isOnline(listing.posterId) then
		return false
	end
	if listing.status ~= "open" then
		return false
	end
	return TradeAdRules.shouldRefresh(listing, now)
end

local function isPlayerOnline(userId: number): boolean
	return Players:GetPlayerByUserId(userId) ~= nil
end

-- Walk the board once and keep alive every ad whose poster is on THIS server.
-- There is no by-poster index, so a per-player loop would mean a full scan per
-- player; piggybacking the scan the sweep already performs costs nothing extra,
-- and each server naturally refreshes only its own players' ads.
function TradeBoardService.refreshPresenceExpiry()
	local now = os.time()
	local open = TradeBoardService.rawOpenListings()
	local openFeaturedByScope = {
		[TradeAdConfig.Scopes.Server] = TradeAdRules.featuredOpenSlots(open, TradeAdConfig.Scopes.Server, now),
		[TradeAdConfig.Scopes.Global] = TradeAdRules.featuredOpenSlots(open, TradeAdConfig.Scopes.Global, now),
	}
	for _, l in open do
		if TradeBoardService.shouldPresenceRefresh(l, now, isPlayerOnline) then
			-- Decided inside the transform, spent outside it. UpdateAsync re-runs
			-- its callback on a CAS conflict, so a decrement written inside would
			-- bill the player once per retry; and a store error after an inside
			-- decrement would take the credit with nothing granted.
			local renewedSku: any = nil
			-- Re-check inside mutate against the freshly-read live record: it
			-- may have changed between this scan and the write (another
			-- server/action touched it), and a nil return here intentionally
			-- skips the store write rather than spending one on a stale check.
			local committed = mutate(l.id, function(live)
				renewedSku = nil -- this callback can re-run; never carry a stale decision
				if not TradeBoardService.applyPresenceRefresh(live, now) then
					return nil
				end
				-- Re-stamp perks so a pass bought after posting still lifts
				-- already-live ads. Rides the write this refresh is already
				-- doing -- no extra store write budget spent.
				-- Safe because this branch only runs for posters present on
				-- this server -- that is the filter that got us here.
				local posterHere = Players:GetPlayerByUserId(live.posterId)
				local prof = posterHere and DataService.getProfile(posterHere) or nil
				if prof then
					live.perks = TradeBoardService.perksFor(prof)
					-- Auto-renew rides this same write -- no second store write
					-- path and no second sweep (a throttling incident already
					-- taught us that cost).
					local scope = live.scope or TradeAdConfig.Scopes.Global
					local sku = heldFeaturedSku(prof, scope)
					if sku then
						-- This ad already holds one of the scope's slots, so it must
						-- not be counted against itself: renewal only ever matters
						-- when the strip is full, and that is precisely the case a
						-- self-inclusive count rejected.
						local pool = openFeaturedByScope[scope] or 0
						if TradeAdRules.effectiveTier(live, now) >= TradeAdConfig.BoostTier.Featured then
							pool += 1
						end
						if
							TradeBoardService.shouldAutoRenew(
								live,
								(prof.TradeAds.credits[sku.id] or 0),
								autoRenewEnabled(prof, scope),
								pool,
								now
							)
						then
							live.expiresAt = (live.expiresAt or now) + sku.seconds
							-- Renew the PLACEMENT window too, not just the life clock:
							-- renewing a featured ad that has dropped off the strip is
							-- not what the buyer is paying for.
							local boostFrom = live.boostExpiresAt
							if boostFrom == nil or boostFrom < now then
								boostFrom = now
							end
							live.boostExpiresAt = boostFrom + sku.seconds
							renewedSku = sku
						end
					end
				end
				live.v += 1
				return live
			end)
			if renewedSku ~= nil then
				local posterHere = Players:GetPlayerByUserId(l.posterId)
				local prof = posterHere and DataService.getProfile(posterHere) or nil
				if committed ~= nil and prof then
					-- Charged only once the extension is actually committed.
					local credits = prof.TradeAds.credits
					credits[renewedSku.id] = math.max(0, (credits[renewedSku.id] or 0) - 1)
					-- No pool decrement here on purpose. A renewal is only ever
					-- granted to an ad that is featured RIGHT NOW, which means
					-- featuredOpenSlots already counted its slot as used before the
					-- sweep started -- renewing takes no new slot. Decrementing
					-- would double-count it and block the next ad from keeping the
					-- slot it already owns. The +1 self-exclusion above is what
					-- keeps each candidate scored against its own slot only.
					AnalyticsService.log("ad_boost_auto_renewed", { userId = l.posterId, sku = renewedSku.id })
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Bot entry points + raw reads (BotService brains; no Player involved)
--------------------------------------------------------------------------------

-- Raw open listing records, newest-first, paged (lazy-expiring).
-- Every open SELL listing this user has, newest-first. Two callers: the booth
-- face renders these as its stocked slots, and PostListing counts them against
-- the booth slot cap. Bot listings live in the same scan, so this is correct
-- for them too.
function TradeBoardService.sellListingsOf(userId: number): { any }
	local out = {}
	scanListings(SCAN_CAP, function(l)
		if l.kind == "sell" and l.posterId == userId and l.status == "open" then
			table.insert(out, l)
		end
		return nil
	end)
	return out
end

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
	board = StoreAdapters.sortedMap("TradeBoard_v8")

	-- One-time purge of retired MemoryStore maps (old boards + the retired
	-- EconomyHot mirror). Their entries persist on multi-day TTLs and count
	-- against the EXPERIENCE-WIDE MemoryStore memory quota — without this,
	-- writes to the new map keep failing with TotalMemoryOverLimit until the
	-- old TTLs lapse (days). Cheap when clean: one empty GetRangeAsync per
	-- retired map. Delete this block once the retired maps have aged out.
	task.spawn(function()
		local retired = { "TradeBoard_v3", "TradeBoard_v4", "TradeBoard_v6", "TradeBoard_v7", "EconomyHot_v3" }
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
	-- A server-scoped ad promises "the poster is HERE, so this settles now".
	-- The moment they leave, that promise is false, so the ad goes with them
	-- rather than lingering until its clock runs out and wasting the reader's
	-- time on someone who cannot answer. Global ads are untouched -- outliving
	-- the session is the whole point of paying for global reach.
	--
	-- Cheap by construction: server-scoped ads live in the in-memory memBoard,
	-- so this is a table walk and a table delete, never a store call.
	Players.PlayerRemoving:Connect(function(player)
		for id, listing in memBoard do
			if
				listing.posterId == player.UserId
				and listing.scope == TradeAdConfig.Scopes.Server
				and listing.status == "open"
			then
				task.spawn(cancelListing, listing, "poster_left")
			end
		end
	end)

	-- keep the market index fresh: initial fill + periodic full-scan rebuild
	-- (picks up cross-server posts; local ops update it inline). pcall'd —
	-- a throttled MemoryStore page must never kill the loop.
	task.spawn(function()
		while true do
			pcall(rebuildBookIndex)
			-- Piggyback the presence refresh on the scan the rebuild just did --
			-- no second timer, no second full-board walk.
			pcall(TradeBoardService.refreshPresenceExpiry)
			task.wait(BOOK_REBUILD_SECONDS)
		end
	end)

	Net.bindFunction("GetBoard", handleGetBoard)
	Net.bindFunction("GetMarketSummary", handleGetMarketSummary)
	Net.bindFunction("GetItemBook", handleGetItemBook)
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

	--------------------------------------------------------------------------
	-- Paid ad boosts. Payment buys POSITION and DURATION only -- posting,
	-- browsing and accepting stay free and none of them route through here.
	--
	-- BUY and APPLY are separate actions. Buying always banks a credit on the
	-- profile; applying spends a banked credit on the caller's own open ad,
	-- for free, with no purchase involved. This is what makes the old intent
	-- model's three failure modes structurally impossible:
	--   * lost intent silently discarding a paid receipt -- there is no
	--     intent to lose; every receipt banks unconditionally.
	--   * a client swapping the intent to a pricier SKU before the receipt
	--     landed -- there is nothing to swap; each SKU owns its own product
	--     id, so the receipt alone says what was bought.
	--   * a double-spent credit under concurrency -- the credit check and the
	--     decrement happen in the same profile write, with no yield between.
	--------------------------------------------------------------------------

	Net.bindFunction("PromptAdBoost", function(player, skuId)
		if not Guard.isString(skuId, 64) then
			return { ok = false, err = "bad_args" }
		end
		local sku = TradeAdConfig.skuById(skuId :: string)
		if sku == nil or sku.productId <= 0 then
			return { ok = false, err = "unknown_sku" }
		end
		-- Nothing recorded here -- the receipt identifies the SKU by its own
		-- product id, so there is no intent for a swapped prompt to corrupt.
		MarketplaceService:PromptProductPurchase(player, sku.productId)
		return { ok = true }
	end)

	Net.bindFunction("ApplyAdBoost", function(player, listingId, skuId)
		if not Guard.isString(listingId, 64) or not Guard.isString(skuId, 64) then
			return { ok = false, err = "bad_args" }
		end
		local sku = TradeAdConfig.skuById(skuId :: string)
		local profile = DataService.getProfile(player)
		if sku == nil or profile == nil then
			return { ok = false, err = "bad_args" }
		end
		local listing = TradeBoardService.getListing(listingId :: string)
		if listing == nil or listing.posterId ~= player.UserId then
			return { ok = false, err = "not_your_ad" }
		end
		local credits = (profile.TradeAds and profile.TradeAds.credits) or {}
		if (credits[skuId] or 0) <= 0 then
			return { ok = false, err = "no_credit" }
		end
		local now = os.time()
		local openFeatured = TradeAdRules.featuredOpenSlots(TradeBoardService.rawOpenListings(), listing.scope, now)
		-- An ad that already holds a featured slot must not be counted against
		-- itself when it buys more time in that same slot, or extending a
		-- Featured ad would be impossible exactly while the strip is full.
		if TradeAdRules.effectiveTier(listing, now) >= TradeAdConfig.BoostTier.Featured then
			openFeatured += 1
		end
		if not TradeBoardService.canApplySku(listing, sku, openFeatured, player.UserId) then
			return { ok = false, err = "cannot_apply" }
		end
		-- Decrement BEFORE applying, re-credit on failure. The check and the
		-- decrement above already happened in this one profile-bound call with
		-- no yield between them, so nothing else can observe or spend this
		-- credit in between -- that is what makes double-spend impossible here.
		credits[skuId] -= 1
		if not applySku(listingId :: string, sku) then
			credits[skuId] += 1
			return { ok = false, err = "gone" }
		end
		AnalyticsService.log("ad_boost_applied", { userId = player.UserId, sku = sku.id })
		return { ok = true }
	end)

	Net.bindFunction("GetAdBoostState", function(player)
		local profile = DataService.getProfile(player)
		local credits = (profile and profile.TradeAds and profile.TradeAds.credits) or {}
		local autoRenew = (profile and profile.TradeAds and profile.TradeAds.autoRenew) or {}
		local open = TradeBoardService.rawOpenListings()
		local now = os.time()
		return {
			ok = true,
			credits = credits,
			featuredOpen = {
				server = TradeAdRules.featuredOpenSlots(open, TradeAdConfig.Scopes.Server, now),
				global = TradeAdRules.featuredOpenSlots(open, TradeAdConfig.Scopes.Global, now),
			},
			autoRenew = {
				server = autoRenew[TradeAdConfig.Scopes.Server] == true,
				global = autoRenew[TradeAdConfig.Scopes.Global] == true,
			},
		}
	end)

	Net.bindFunction("SetAdAutoRenew", function(player, scope, enabled)
		if not Guard.isString(scope, 16) or (scope ~= TradeAdConfig.Scopes.Server and scope ~= TradeAdConfig.Scopes.Global) then
			return { ok = false, err = "bad_args" }
		end
		local profile = DataService.getProfile(player)
		if profile == nil then
			return { ok = false, err = "no_profile" }
		end
		profile.TradeAds = profile.TradeAds or { extraSlots = 0, credits = {} }
		profile.TradeAds.autoRenew = profile.TradeAds.autoRenew or {}
		profile.TradeAds.autoRenew[scope] = enabled == true
		return { ok = true }
	end)

	-- One handler per SKU, each on its own real product id -- the receipt
	-- alone proves what was bought, so there is nothing client-supplied to
	-- trust here. Looping liveSkus() (rather than all Skus) is just for
	-- clarity: registering on productId 0 is already a no-op.
	for _, sku in TradeAdConfig.liveSkus() do
		ProductService.registerDevProduct(sku.productId, sku.id, function(player, claimId)
			local profile = DataService.getProfile(player)
			if profile == nil then
				return false -- let Roblox retry; the profile may still be loading
			end
			-- A receipt ALWAYS banks. There is no listing to apply to and no
			-- intent to consult -- that is what removes the "purchase resolves
			-- against a listing that already died" failure mode entirely.
			TradeBoardService.bankCredit(profile, sku.id)
			AnalyticsService.log("ad_boost_purchased", { userId = player.UserId, sku = sku.id, claimId = claimId })
			return true
		end)
	end
end

return TradeBoardService
