--!strict
-- Trade ad rules and paid placement catalogue.
--
-- Two scopes with deliberately different economics:
--   * SERVER ads live in the server-local memBoard and die when the poster
--     leaves. They are cheap to boost because the audience is one server --
--     but whoever answers is online right now, so the trade settles at once.
--   * GLOBAL ads live in the MemoryStore map, reach the whole experience and
--     outlive the poster's session by GlobalGraceSeconds. Boosting them costs
--     more because the reach is the whole game.
--
-- Payment buys POSITION and DURATION. It never gates posting, browsing or
-- accepting -- that rule is load-bearing, not decoration.

local TradeAdConfig = {
	Scopes = {
		Server = "server",
		Global = "global",
	},

	-- Free allowance per scope. A player therefore starts with 3 server ads
	-- AND 3 global ads, not 3 in total.
	BaseSlotsPerScope = 3,
	-- Purchased slots stack on top, per scope. Capped so a single buyer can't
	-- crowd the whole board out of the free players' reach.
	MaxExtraSlots = 27,

	-- How long an ad outlives its poster's session. Server ads go the instant
	-- the poster leaves (their store is that server's memory); global ads get
	-- a grace window so a disconnect doesn't destroy a live negotiation.
	ServerGraceSeconds = 0,
	GlobalGraceSeconds = 2 * 3600,

	-- The sweep pushes an ad's death clock only when it is inside this window,
	-- so a long AFK session costs about one small write per ad per hour rather
	-- than one per sweep.
	RefreshThresholdSeconds = 3600,

	-- Scarce on purpose: scarcity is what makes the strip worth buying, and
	-- what stops it becoming a second feed.
	FeaturedSlotsPerScope = 6,

	BoostTier = {
		None = 0,
		Boosted = 1,
		Featured = 2,
	},
}

-- `productId` is the real Roblox dev product. Each SKU owns its OWN id, which
-- is what lets the receipt handler identify what was bought from the receipt
-- alone -- no recorded intent to trust, and therefore nothing to swap.
--
-- `shelf` drives the shop layout: every scope shows exactly three CARDS, low /
-- best / high, with the middle one flagged. The middle is where we want players
-- to land, and the ladder does that work by itself -- Boost 24h is 24x the time
-- of Boost 1h for 2.5x the price, so the comparison sells it.
--
-- Three cards is not three SKUs. BoardScreen groups SKUs by shelf and renders a
-- duration button per SKU inside the card, so a shelf may hold more than one
-- (global "high" holds Featured 24h and Featured 3d today). What the layout
-- actually requires is exactly one "low" and exactly one "best" per scope --
-- a second "best" would leave two cards both claiming to be the pick.
export type Sku = {
	id: string,
	scope: string,
	name: string,
	blurb: string,
	tier: number,
	seconds: number,
	robux: number,
	productId: number,
	shelf: string, -- "low" | "best" | "high"
}

local DAY = 24 * 3600

-- Not yet created in the Roblox dashboard. Registering a handler on 0 is a
-- no-op (see ProductService.registerDevProduct), so an uncreated SKU simply
-- cannot be bought rather than paying out the wrong thing.
local TODO_PRODUCT_ID = 0

TradeAdConfig.Skus = {
	-- Server scope: cheap, because the audience is one server.
	{
		id = "ad_boost_server_1h",
		scope = "server",
		name = "Boost 1 hour",
		blurb = "Your ad jumps above all free ads on this server for 1 hour.",
		tier = 1,
		seconds = 3600,
		robux = 10,
		productId = 3709440377,
		shelf = "low",
	},
	{
		id = "ad_boost_server_1d",
		scope = "server",
		name = "Boost 24 hours",
		blurb = "Your ad jumps above all free ads on this server for a full day, even after you leave.",
		tier = 1,
		seconds = DAY,
		robux = 25,
		productId = 3709438279,
		shelf = "best",
	},
	{
		id = "ad_featured_server_1d",
		scope = "server",
		name = "Featured 24 hours",
		blurb = "Pinned to this server's Featured strip for 24 hours. Only 6 slots exist.",
		tier = 2,
		seconds = DAY,
		robux = 49,
		productId = 3709438338,
		shelf = "high",
	},

	-- Global scope: same perks, whole-game reach, priced accordingly.
	{
		id = "ad_boost_global_1h",
		scope = "global",
		name = "Boost 1 hour",
		blurb = "Your ad jumps above all free ads game-wide for 1 hour.",
		tier = 1,
		seconds = 3600,
		robux = 25,
		productId = 3709440418,
		shelf = "low",
	},
	{
		id = "ad_boost_global_1d",
		scope = "global",
		name = "Boost 24 hours",
		blurb = "Your ad jumps above all free ads game-wide for a full day, even after you leave.",
		tier = 1,
		seconds = DAY,
		robux = 49,
		productId = 3709438385,
		shelf = "best",
	},
	{
		id = "ad_featured_global_1d",
		scope = "global",
		name = "Featured 24 hours",
		blurb = "Pinned to the global Featured strip for 24 hours. Only 6 slots exist.",
		tier = 2,
		seconds = DAY,
		robux = 99,
		productId = 3709438424,
		shelf = "high",
	},
	{
		id = "ad_featured_global_3d",
		scope = "global",
		name = "Featured 3 days",
		blurb = "Pinned to the global Featured strip for 3 days. Only 6 slots exist.",
		tier = 2,
		seconds = 3 * DAY,
		robux = 199,
		productId = 3709438460,
		shelf = "high",
	},
} :: { Sku }

local byId: { [string]: Sku } = {}
local byProductId: { [number]: Sku } = {}
for _, sku in TradeAdConfig.Skus do
	byId[sku.id] = sku
	if sku.productId ~= TODO_PRODUCT_ID then
		byProductId[sku.productId] = sku
	end
end

function TradeAdConfig.skuById(id: string): Sku?
	return byId[id]
end

-- Resolve a purchase from the RECEIPT rather than from anything the client
-- said. With one product id per SKU, the receipt alone proves what was bought,
-- so a client cannot ask for one thing and pay for another.
function TradeAdConfig.skuByProductId(productId: number): Sku?
	return byProductId[productId]
end

-- Every SKU that has a real product id behind it. A SKU still on
-- TODO_PRODUCT_ID is hidden from the shop rather than shown as unbuyable.
function TradeAdConfig.liveSkus(): { Sku }
	local out: { Sku } = {}
	for _, sku in TradeAdConfig.Skus do
		if sku.productId ~= TODO_PRODUCT_ID then
			table.insert(out, sku)
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- Shop presentation. Boosts are sold from the ONE storefront (ShopScreen), not
-- from a second parallel one — a player who wants to buy placement should end
-- up in the same shop as everyone buying anything else. These helpers are the
-- adapter: they describe the SKUs in the shape MonetizationConfig offers use,
-- so ShopScreen renders them through its existing card template with no
-- special-casing. The SKU catalogue above stays the single source of truth for
-- price, duration and tier.
--------------------------------------------------------------------------------

-- Simulator Icon Pack ids, reused from the shared UI chrome set. Exported so
-- the shop section, the boost sheet card and the inventory slot all show the
-- SAME art for the same tier -- a boost the player bought has to be
-- recognisable wherever it turns up.
TradeAdConfig.Icons = {
	Boost = "rbxassetid://15403064919", -- trade arrows
	Featured = "rbxassetid://17368097932", -- star
}

-- Art for one SKU, keyed off tier rather than id, so a new SKU inherits the
-- right icon without another lookup table to keep in sync.
function TradeAdConfig.iconFor(sku: Sku): string
	return sku.tier >= TradeAdConfig.BoostTier.Featured and TradeAdConfig.Icons.Featured
		or TradeAdConfig.Icons.Boost
end

local BOOST_ICON = TradeAdConfig.Icons.Boost
local FEATURED_ICON = TradeAdConfig.Icons.Featured

TradeAdConfig.ShopSections = {
	server = "⚡ AD BOOSTS · THIS SERVER",
	global = "⚡ AD BOOSTS · GLOBAL",
}

function TradeAdConfig.shopSection(scope: string): string
	return scope == TradeAdConfig.Scopes.Global and TradeAdConfig.ShopSections.global
		or TradeAdConfig.ShopSections.server
end

-- Shelf order is the whole persuasion: low anchors, best is the intended pick,
-- high anchors from above. Rendering them in any other order would break the
-- ladder the prices were written for.
local SHELF_SORT = { low = 1, best = 2, high = 3 }

-- Offer-shaped rows for the shop. One per live SKU, ordered low → best → high
-- within each scope's section, with the middle card carrying BEST VALUE.
function TradeAdConfig.shopOffers(): { any }
	local out = {}
	for _, sku in TradeAdConfig.liveSkus() do
		local isFeatured = sku.tier >= TradeAdConfig.BoostTier.Featured
		table.insert(out, {
			id = sku.id,
			kind = "adboost",
			section = TradeAdConfig.shopSection(sku.scope),
			name = sku.name,
			description = sku.blurb,
			imageId = isFeatured and FEATURED_ICON or BOOST_ICON,
			productType = "devproduct",
			productId = sku.productId,
			grants = {},
			badge = sku.shelf == "best" and "BEST VALUE" or nil,
			accent = isFeatured and { 253, 179, 30 } or nil, -- Theme.Gold
			sortOrder = (SHELF_SORT[sku.shelf] or 9) * 10 + sku.seconds / 3600,
		})
	end
	table.sort(out, function(a, b)
		if a.section ~= b.section then
			return a.section < b.section
		end
		return a.sortOrder < b.sortOrder
	end)
	return out
end

function TradeAdConfig.skusForScope(scope: string): { Sku }
	local out: { Sku } = {}
	for _, sku in TradeAdConfig.Skus do
		if sku.scope == scope then
			table.insert(out, sku)
		end
	end
	return out
end

return TradeAdConfig
