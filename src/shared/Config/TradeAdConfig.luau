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
	FeaturedSlotsPerScope = 3,

	BoostTier = {
		None = 0,
		Priority = 1,
		Featured = 2,
	},
}

export type Sku = {
	id: string,
	scope: string,
	name: string,
	blurb: string,
	tier: number,
	bump: boolean,
	seconds: number,
	robux: number,
}

local DAY = 24 * 3600

TradeAdConfig.Skus = {
	-- Server scope: cheap, because the audience is one server.
	{
		id = "ad_bump_server",
		scope = "server",
		name = "Bump",
		blurb = "Jump to the top of this server's feed now. Sinks normally after.",
		tier = 0,
		bump = true,
		seconds = 0,
		robux = 10,
	},
	{
		id = "ad_priority_server_1d",
		scope = "server",
		name = "Priority 24h",
		blurb = "Sits above every free ad on this server for 24 hours, even after you leave.",
		tier = 1,
		bump = true,
		seconds = DAY,
		robux = 25,
	},
	{
		id = "ad_featured_server_1d",
		scope = "server",
		name = "Featured 24h",
		blurb = "Pinned to this server's Featured strip for 24 hours. Only 3 slots.",
		tier = 2,
		bump = true,
		seconds = DAY,
		robux = 49,
	},

	-- Global scope: same perks, whole-game reach, priced accordingly.
	{
		id = "ad_bump_global",
		scope = "global",
		name = "Bump",
		blurb = "Jump to the top of the global feed now. Sinks normally after.",
		tier = 0,
		bump = true,
		seconds = 0,
		robux = 25,
	},
	{
		id = "ad_priority_global_1d",
		scope = "global",
		name = "Priority 24h",
		blurb = "Sits above every free ad game-wide for 24 hours, even after you leave.",
		tier = 1,
		bump = true,
		seconds = DAY,
		robux = 49,
	},
	{
		id = "ad_featured_global_1d",
		scope = "global",
		name = "Featured 24h",
		blurb = "Pinned to the global Featured strip for 24 hours. Only 3 slots.",
		tier = 2,
		bump = true,
		seconds = DAY,
		robux = 99,
	},
	{
		id = "ad_featured_global_3d",
		scope = "global",
		name = "Featured 3 days",
		blurb = "Pinned to the global Featured strip for 3 days. Only 3 slots.",
		tier = 2,
		bump = true,
		seconds = 3 * DAY,
		robux = 199,
	},
} :: { Sku }

local byId: { [string]: Sku } = {}
for _, sku in TradeAdConfig.Skus do
	byId[sku.id] = sku
end

function TradeAdConfig.skuById(id: string): Sku?
	return byId[id]
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
