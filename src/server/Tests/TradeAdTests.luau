--!strict
-- Unit tests: trade ad config sanity, slot maths, lifetime and refresh rules,
-- featured pool accounting, and feed ordering. All pure -- no store calls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TradeAdConfig = require(ReplicatedStorage.Shared.Config.TradeAdConfig)
local TradeAdRules = require(ReplicatedStorage.Shared.Util.TradeAdRules)

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

local function truthy(v: any, label: string)
	if not v then
		error(label .. ": expected truthy, got " .. tostring(v), 2)
	end
end

return {
	name = "TradeAds",
	tests = {
		-- Every SKU has to name a scope that exists, cost something, and do
		-- something. A SKU that grants no tier and no time is a paid no-op --
		-- real money for nothing.
		["config: every SKU is well-formed and actually does something"] = function()
			truthy(#TradeAdConfig.Skus > 0, "no SKUs configured")
			local seen: { [string]: boolean } = {}
			for _, sku in TradeAdConfig.Skus do
				truthy(not seen[sku.id], "duplicate SKU id " .. sku.id)
				seen[sku.id] = true
				truthy(
					sku.scope == TradeAdConfig.Scopes.Server or sku.scope == TradeAdConfig.Scopes.Global,
					sku.id .. ": bad scope " .. tostring(sku.scope)
				)
				truthy(sku.robux > 0, sku.id .. ": costs nothing")
				truthy(
					sku.tier > TradeAdConfig.BoostTier.None and sku.seconds > 0,
					sku.id .. ": grants nothing"
				)
				truthy(
					sku.shelf == "low" or sku.shelf == "best" or sku.shelf == "high",
					sku.id .. ": bad shelf " .. tostring(sku.shelf)
				)
			end
		end,

		-- One product id per SKU is what lets the receipt handler identify a
		-- purchase from the receipt alone. Two SKUs sharing an id would make
		-- the cheap one indistinguishable from the expensive one at grant time
		-- -- which is exactly how you end up paying Boost's price for Featured.
		["config: every live SKU owns a distinct product id"] = function()
			-- Over Skus, not liveSkus(): liveSkus() filters on productId ~= 0, so
			-- asserting productId > 0 inside that loop can never fail. Every
			-- shipped SKU is meant to be buyable, and one left on the placeholder
			-- id is a shop card that silently does nothing.
			for _, sku in TradeAdConfig.Skus do
				truthy(sku.productId > 0, sku.id .. ": no real product id -- unbuyable")
			end
			local seenProduct: { [number]: string } = {}
			for _, sku in TradeAdConfig.liveSkus() do
				local clash = seenProduct[sku.productId]
				truthy(clash == nil, ("%s shares product id %d with %s"):format(sku.id, sku.productId, tostring(clash)))
				seenProduct[sku.productId] = sku.id
				eq(TradeAdConfig.skuByProductId(sku.productId), sku, sku.id .. ": receipt lookup round-trip")
			end
		end,

		-- The shop shows three CARDS per scope: low / best / high. BoardScreen
		-- groups SKUs by shelf and puts a duration button per SKU inside the
		-- card, so "high" is allowed to hold several durations (Featured 24h +
		-- Featured 3d). What must stay singular is "low" and "best": two cards
		-- both flagged as the pick is not a ladder, and the ribbon that makes
		-- the middle tier obvious silently stops being a layout.
		["config: each scope has exactly one low and one best shelf"] = function()
			for _, scope in { TradeAdConfig.Scopes.Server, TradeAdConfig.Scopes.Global } do
				local counts = { low = 0, best = 0, high = 0 }
				for _, sku in TradeAdConfig.skusForScope(scope) do
					counts[sku.shelf] += 1
				end
				eq(counts.low, 1, scope .. ": expected exactly one low shelf SKU")
				eq(counts.best, 1, scope .. ": expected exactly one best-value SKU")
				truthy(counts.high >= 1, scope .. ": expected at least one high shelf SKU")
			end
		end,

		-- Global reach costs more than one server. If a global SKU were ever
		-- cheaper than its server twin, nobody would buy the server one.
		["config: global SKUs cost more than their server twins"] = function()
			for _, server in TradeAdConfig.skusForScope(TradeAdConfig.Scopes.Server) do
				-- Count matches so a broken pairing (a tier added without a twin,
				-- a duration changed on one side, etc.) fails loudly instead of
				-- the loop just quietly asserting nothing and reporting PASS.
				local matches = 0
				for _, global in TradeAdConfig.skusForScope(TradeAdConfig.Scopes.Global) do
					if server.tier == global.tier and server.seconds == global.seconds then
						matches += 1
						truthy(
							global.robux > server.robux,
							("%s (%d) must cost more than %s (%d)"):format(global.id, global.robux, server.id, server.robux)
						)
					end
				end
				truthy(matches > 0, server.id .. ": no global twin -- this test would otherwise assert nothing")
			end
		end,

		-- Featured is scarce on purpose. A gamepass granting it permanently
		-- would let one player hold the whole pool forever, so no SKU that is
		-- a pass may carry the featured tier.
		["config: featured is per-ad only, never a permanent perk"] = function()
			eq(TradeAdConfig.FeaturedSlotsPerScope, 6, "featured slots per scope")
			for _, sku in TradeAdConfig.Skus do
				if sku.tier == TradeAdConfig.BoostTier.Featured then
					truthy(sku.seconds > 0, sku.id .. ": featured must be time-boxed, never permanent")
				end
			end
		end,

		["config: skuById finds real ids and rejects junk"] = function()
			local first = TradeAdConfig.Skus[1]
			eq(TradeAdConfig.skuById(first.id), first, "skuById round-trip")
			eq(TradeAdConfig.skuById("nope_not_a_sku"), nil, "unknown id")
		end,

		["slots: base allowance, purchased slots add, cap holds"] = function()
			eq(TradeAdRules.slotLimit(0), TradeAdConfig.BaseSlotsPerScope, "base")
			eq(TradeAdRules.slotLimit(2), TradeAdConfig.BaseSlotsPerScope + 2, "plus two")
			eq(
				TradeAdRules.slotLimit(9999),
				TradeAdConfig.BaseSlotsPerScope + TradeAdConfig.MaxExtraSlots,
				"cap"
			)
			truthy(TradeAdRules.canPost(2, 0), "under limit")
			truthy(not TradeAdRules.canPost(3, 0), "at limit")
			truthy(TradeAdRules.canPost(3, 1), "purchased slot opens it back up")
		end,

		-- Server ads die with the session because their store IS that server's
		-- memory. Global ads get a grace window so a disconnect mid-negotiation
		-- doesn't destroy the ad.
		["lifetime: server ads die on leave, global ads get a grace window"] = function()
			eq(TradeAdRules.graceFor("server"), TradeAdConfig.ServerGraceSeconds, "server grace")
			eq(TradeAdRules.graceFor("global"), TradeAdConfig.GlobalGraceSeconds, "global grace")
			truthy(TradeAdRules.graceFor("global") > TradeAdRules.graceFor("server"), "global outlives server")
		end,

		-- THE decay invariant. Staying online keeps an ad ALIVE, never on top.
		-- If a refresh ever moved bumpedAt, an AFK player would hold rank one
		-- forever for free and the whole paid-placement design would collapse.
		["refresh: pushes the death clock and never touches sort position"] = function()
			local now = 1000000
			local listing = {
				scope = "global",
				bumpedAt = now - 5000,
				expiresAt = now + 60, -- inside the refresh window
			}
			local before = listing.bumpedAt
			truthy(TradeAdRules.shouldRefresh(listing, now), "should refresh when near expiry")
			listing.expiresAt = TradeAdRules.refreshedExpiry(listing.scope, now)
			eq(listing.bumpedAt, before, "bumpedAt MUST NOT move")
			truthy(listing.expiresAt > now + TradeAdConfig.RefreshThresholdSeconds, "clock pushed clear of the window")
		end,

		["refresh: skipped while the ad is still comfortably alive"] = function()
			local now = 1000000
			local listing = { scope = "global", bumpedAt = now, expiresAt = now + 10 * 3600 }
			truthy(not TradeAdRules.shouldRefresh(listing, now), "no write needed yet")
		end,

		-- A gamepass upgrades every ad the player owns, so the tier has to come
		-- from the stamped perks as well as the purchased tier -- whichever is
		-- higher wins, and a purchase never downgrades a pass.
		["tier: stamped pass perks and purchased tier take the higher of the two"] = function()
			eq(TradeAdRules.effectiveTier({ boostTier = 0 }), 0, "plain ad")
			eq(TradeAdRules.effectiveTier({ boostTier = 0, perks = { priority = true } }), 1, "pass lifts it")
			eq(TradeAdRules.effectiveTier({ boostTier = 2, perks = { priority = true } }), 2, "purchase wins when higher")
		end,

		["featured: pool counts only live featured ads in that scope"] = function()
			local now = 1000
			local listings = {
				{ scope = "global", boostTier = 2, expiresAt = now + 100 },
				{ scope = "global", boostTier = 2, expiresAt = now - 1 }, -- expired, frees its slot
				{ scope = "server", boostTier = 2, expiresAt = now + 100 }, -- other scope
				{ scope = "global", boostTier = 1, expiresAt = now + 100 }, -- not featured
			}
			eq(TradeAdRules.featuredOpenSlots(listings, "global", now), TradeAdConfig.FeaturedSlotsPerScope - 1, "global")
			eq(TradeAdRules.featuredOpenSlots(listings, "server", now), TradeAdConfig.FeaturedSlotsPerScope - 1, "server")
		end,

		["order: tier first, then most recently bumped, then id"] = function()
			local hi = { boostTier = 2, bumpedAt = 1, id = "a" }
			local lo = { boostTier = 0, bumpedAt = 999, id = "b" }
			truthy(TradeAdRules.order(hi, lo), "tier beats recency")
			local newer = { boostTier = 0, bumpedAt = 500, id = "c" }
			local older = { boostTier = 0, bumpedAt = 100, id = "d" }
			truthy(TradeAdRules.order(newer, older), "recency breaks a tier tie")
		end,

		-- A v5 profile that predates trade ads must come back with the new
		-- fields populated, not nil -- every read site would otherwise need a
		-- nil guard, and one missed guard is a runtime error in production.
		["migration: a pre-trade-ads profile gains ad fields with safe defaults"] = function()
			local DataService = require(script.Parent.Parent.Services.DataService)
			local old = {
				SchemaVersion = 5,
				Gems = 10,
				Inventory = {},
				Booth = { skinId = "default", extraSlots = 0, tagline = "" },
			}
			local migrated = DataService.migrateForTest(old)
			eq(migrated.SchemaVersion, 6, "schema bumped")
			eq(migrated.TradeAds.extraSlots, 0, "extra slots default")
			eq(typeof(migrated.TradeAds.credits), "table", "credits table")
			eq(migrated.TradeAds.pending, nil, "no pending purchase")
			eq(migrated.AdPerks.priority, false, "priority pass default")
			eq(migrated.AdPerks.duration, false, "duration pass default")
			eq(migrated.Gems, 10, "existing data survives")
		end,

		-- Scope decides which store an ad lives in, so an unknown scope must be
		-- rejected at the door rather than silently defaulting -- a typo that
		-- routed a global ad into server memory would make it vanish on restart.
		["post: scope must be one the config knows"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local res = TradeBoardService.validateScope("sideways")
			truthy(not res, "unknown scope rejected")
			truthy(TradeBoardService.validateScope(TradeAdConfig.Scopes.Server), "server ok")
			truthy(TradeBoardService.validateScope(TradeAdConfig.Scopes.Global), "global ok")
		end,

		-- The limit is per scope, so filling your server slots must not block a
		-- global post. Players read "3 ads" as 3 of each; making it 3 total
		-- would silently halve what they think they bought.
		["post: slot limits count each scope separately"] = function()
			local limit = TradeAdRules.slotLimit(0)
			truthy(not TradeAdRules.canPost(limit, 0), "server slots full blocks another server ad")
			truthy(TradeAdRules.canPost(0, 0), "global slots untouched by server ads")
		end,

		-- Scope means REACH. A memBoard listing reaches exactly one server, so
		-- anything routed there must be server-scoped or the global tab starts
		-- advertising ads no other server can see. This locks the two together:
		-- if someone later lets a bot post as global, or routes a global ad into
		-- memory, one of these fails loudly.
		["post: scope and store can never disagree"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local Server, Global = TradeAdConfig.Scopes.Server, TradeAdConfig.Scopes.Global

			-- bots live only in this server's memory, so they are server-scoped
			-- no matter what scope the caller asked for
			eq(TradeBoardService.scopeFor(-42, Global), Server, "bot forced to server scope")
			eq(TradeBoardService.scopeFor(-42, Server), Server, "bot stays server scope")

			-- players keep the scope they chose
			eq(TradeBoardService.scopeFor(7, Global), Global, "player global respected")
			eq(TradeBoardService.scopeFor(7, Server), Server, "player server respected")

			-- and the storage decision is a pure function of scope
			truthy(TradeBoardService.storesInMemory(Server), "server scope stored in memory")
			truthy(not TradeBoardService.storesInMemory(Global), "global scope stored in shared map")
			truthy(
				TradeBoardService.storesInMemory(TradeBoardService.scopeFor(-42, Global)),
				"bot ad always lands in memory"
			)
		end,

		-- The slot limit is only worth what the count is worth, and players BUY
		-- extra slots -- a count that conflates scopes, or drifts, sells nothing.
		-- Server scope is counted exactly from memBoard, so this pins the rule:
		-- same poster, both scopes, and each scope must see only its own ads.
		["post: countOpenIn counts one poster's live ads per scope"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local Server, Global = TradeAdConfig.Scopes.Server, TradeAdConfig.Scopes.Global
			local now = 1000
			local me, other = 7, 8
			local fixture = {
				a = { posterId = me, scope = Server, status = "open", expiresAt = now + 60 },
				b = { posterId = me, scope = Server, status = "open", expiresAt = now + 60 },
				c = { posterId = me, scope = Global, status = "open", expiresAt = now + 60 },
				-- must not count: someone else's, closed, and expired
				d = { posterId = other, scope = Server, status = "open", expiresAt = now + 60 },
				e = { posterId = me, scope = Server, status = "cancelled", expiresAt = now + 60 },
				f = { posterId = me, scope = Server, status = "open", expiresAt = now - 1 },
			}

			-- fails loudly if the scopes were ever conflated: a combined count
			-- would read 3 here, not 2 and 1
			eq(TradeBoardService.countOpenIn(fixture, me, Server, now), 2, "server ads counted exactly")
			eq(TradeBoardService.countOpenIn(fixture, me, Global, now), 1, "global ads counted separately")
			eq(TradeBoardService.countOpenIn(fixture, other, Server, now), 1, "other poster counted alone")
			eq(TradeBoardService.countOpenIn(fixture, 999, Server, now), 0, "poster with no ads")

			-- server scope reads memBoard directly, so it is never capped
			truthy(TradeBoardService.storesInMemory(Server), "server count source is memory")
		end,

		-- The whole decay design rests on this: refreshing an ad extends its
		-- life without touching its rank. Verified against the real service
		-- helper rather than the rules module, because it is the service that
		-- could accidentally write bumpedAt alongside expiresAt.
		["sweep: presence refresh extends life without changing rank"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local now = os.time()
			local listing = {
				id = "test",
				scope = "global",
				status = "open",
				bumpedAt = now - 9000,
				expiresAt = now + 60,
			}
			local rankBefore = listing.bumpedAt
			local changed = TradeBoardService.applyPresenceRefresh(listing, now)
			truthy(changed, "an ad near expiry gets refreshed")
			eq(listing.bumpedAt, rankBefore, "rank MUST be untouched by a refresh")
			truthy(listing.expiresAt > now + 3600, "life extended past the refresh window")
		end,

		["sweep: a healthy ad is left alone, so no write is spent"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local now = os.time()
			local listing = { id = "t2", scope = "global", status = "open", bumpedAt = now, expiresAt = now + 20000 }
			eq(TradeBoardService.applyPresenceRefresh(listing, now), false, "no refresh needed")
			eq(listing.expiresAt, now + 20000, "clock untouched")
		end,

		-- shouldPresenceRefresh is the eligibility gate refreshPresenceExpiry
		-- actually runs. Injecting isOnline lets this fixture cover the sweep's
		-- own guards -- bot exclusion, offline poster, non-open, outside window
		-- -- without a real Players service or MemoryStore.
		["sweep: shouldPresenceRefresh gates on bot / presence / status / window"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local now = os.time()
			local everyoneOnline = function()
				return true
			end
			local everyoneOffline = function()
				return false
			end

			local bot = { posterId = -7, status = "open", expiresAt = now + 60 }
			eq(
				TradeBoardService.shouldPresenceRefresh(bot, now, everyoneOnline),
				false,
				"bot ad excluded even when its id reads 'online'"
			)

			local offline = { posterId = 5, status = "open", expiresAt = now + 60 }
			eq(
				TradeBoardService.shouldPresenceRefresh(offline, now, everyoneOffline),
				false,
				"poster not on this server is excluded"
			)

			local closed = { posterId = 5, status = "cancelled", expiresAt = now + 60 }
			eq(
				TradeBoardService.shouldPresenceRefresh(closed, now, everyoneOnline),
				false,
				"non-open listing is excluded"
			)

			local healthy = { posterId = 5, status = "open", expiresAt = now + 20000 }
			eq(
				TradeBoardService.shouldPresenceRefresh(healthy, now, everyoneOnline),
				false,
				"online poster but far from expiry: no write spent"
			)

			local dueForRefresh = { posterId = 5, status = "open", expiresAt = now + 60 }
			eq(
				TradeBoardService.shouldPresenceRefresh(dueForRefresh, now, everyoneOnline),
				true,
				"online poster, open, inside the refresh window: included"
			)
		end,

		-- Passes are stamped onto the listing at post time rather than looked up
		-- at sort time, because sorting happens on servers where the poster is
		-- absent -- there is nobody to ask about pass ownership there.
		["perks: pass state is stamped on the listing, not looked up when sorting"] = function()
			local free = { boostTier = 0, bumpedAt = 100, id = "free" }
			local passHolder = { boostTier = 0, bumpedAt = 50, perks = { priority = true }, id = "pass" }
			truthy(TradeAdRules.order(passHolder, free), "a pass holder outranks a newer free ad")
		end,

		["perks: a purchased featured tier still beats a priority pass"] = function()
			local pass = { boostTier = 0, perks = { priority = true }, bumpedAt = 999, id = "p" }
			local bought = { boostTier = 2, bumpedAt = 1, id = "b" }
			truthy(TradeAdRules.order(bought, pass), "featured outranks the priority pass")
		end,

		-- perksFor is the single shape both stamp sites (postCore, and the
		-- re-stamp in refreshPresenceExpiry) call, so they can't drift into
		-- different field names. This is the coverage that actually exercises
		-- Task 6's new code -- the two order() tests above only re-exercise
		-- Task 2's ordering.
		["perksFor: pass-holder profile yields true for the field they hold"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local perks = TradeBoardService.perksFor({ AdPerks = { priority = true, duration = false } })
			eq(perks.priority, true, "priority")
			eq(perks.duration, false, "duration")
		end,

		["perksFor: un-migrated profile (no AdPerks field) yields false, never nil"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local perks = TradeBoardService.perksFor({})
			eq(perks.priority, false, "priority")
			eq(perks.duration, false, "duration")
		end,

		["perksFor: nil profile (bot, or profile not loaded) yields false, never nil"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local perks = TradeBoardService.perksFor(nil)
			eq(perks.priority, false, "priority")
			eq(perks.duration, false, "duration")
		end,

		["perksFor: same shape (exact field names) across every input"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local cases = {
				TradeBoardService.perksFor({ AdPerks = { priority = true, duration = true } }),
				TradeBoardService.perksFor({}),
				TradeBoardService.perksFor(nil),
			}
			for _, perks in cases do
				truthy(perks.priority == true or perks.priority == false, "priority is a boolean, never nil")
				truthy(perks.duration == true or perks.duration == false, "duration is a boolean, never nil")
			end
		end,

		-- Every boost SKU registers its own receipt handler, and ProductService
		-- keys handlers by product id -- a second registration on an id the shop
		-- already claimed is REFUSED, silently for the placeholder. So a SKU
		-- sharing an id with any shop offer would simply never grant, with no
		-- error anywhere. This is the guard for that.
		["boost: no SKU shares a product id with a shop offer"] = function()
			local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
			local shopIds: { [number]: string } = {}
			for _, offer in MonetizationConfig.Offers do
				if offer.productId ~= 0 then
					shopIds[offer.productId] = offer.id
				end
			end
			for _, sku in TradeAdConfig.liveSkus() do
				local clash = shopIds[sku.productId]
				truthy(
					clash == nil,
					("SKU %s shares product id %d with shop offer %s -- its handler would never register")
						:format(sku.id, sku.productId, tostring(clash))
				)
			end
		end,

		-- BUY always banks. There is no listing to resolve against any more, so
		-- every live SKU must land a credit regardless of what the profile
		-- looked like before.
		["boost: bankCredit banks one credit, for every live SKU"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			for _, sku in TradeAdConfig.liveSkus() do
				local profile = {}
				TradeBoardService.bankCredit(profile, sku.id)
				eq(profile.TradeAds.credits[sku.id], 1, "credit banked for " .. sku.id)
			end
		end,

		["boost: bankCredit stacks on an existing balance"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local profile = { TradeAds = { extraSlots = 0, credits = { ad_boost_server_1h = 2 } } }
			TradeBoardService.bankCredit(profile, "ad_boost_server_1h")
			eq(profile.TradeAds.credits.ad_boost_server_1h, 3, "second receipt adds to the balance")
		end,

		-- APPLY spends exactly one credit; a refused apply must never touch the
		-- balance -- that is what makes double-spend impossible: the check and
		-- the decrement are the same call, so a failure leaves nothing charged.
		["boost: canApplySku allows a matching-scope owned open ad with a free slot"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local featured = TradeAdConfig.skuById("ad_featured_global_1d")
			local ad = { status = "open", scope = "global", posterId = 1 }
			truthy(TradeBoardService.canApplySku(ad, featured, 2, 1), "scope matches, owner matches, slot free")
		end,

		["boost: canApplySku refuses an ad in the wrong scope"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local serverSku = TradeAdConfig.skuById("ad_boost_server_1d")
			local globalAd = { status = "open", scope = "global", posterId = 1 }
			eq(TradeBoardService.canApplySku(globalAd, serverSku, 3, 1), false, "wrong scope -> refused")
		end,

		["boost: canApplySku refuses an ad the caller does not own"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local sku = TradeAdConfig.skuById("ad_boost_global_1d")
			local ad = { status = "open", scope = "global", posterId = 1 }
			eq(TradeBoardService.canApplySku(ad, sku, 3, 2), false, "caller 2 does not own poster 1's ad")
		end,

		["boost: canApplySku refuses a featured apply when the pool is full"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local featured = TradeAdConfig.skuById("ad_featured_server_1d")
			local ad = { status = "open", scope = "server", posterId = 1 }
			eq(TradeBoardService.canApplySku(ad, featured, 0, 1), false, "pool full -> refused")
			eq(
				TradeBoardService.canApplySku(ad, featured, 1, 1),
				true,
				"one slot free (of FeaturedSlotsPerScope=6) -> allowed"
			)
		end,

		["boost: canApplySku ignores the featured pool for a non-featured SKU"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local boost = TradeAdConfig.skuById("ad_boost_global_1d")
			local ad = { status = "open", scope = "global", posterId = 1 }
			truthy(TradeBoardService.canApplySku(ad, boost, 0, 1), "no scarce pool for a plain boost")
		end,

		-- Auto-renew: true only when every one of enabled/credit/slot/featured
		-- holds; false in each negative case.
		["boost: shouldAutoRenew is true only when every condition holds"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local now = 1000
			local featuredAd = { status = "open", boostTier = TradeAdConfig.BoostTier.Featured, expiresAt = now }
			truthy(
				TradeBoardService.shouldAutoRenew(featuredAd, 1, true, 1, now),
				"enabled, credit held, slot free, featured, due for refresh"
			)
		end,

		["boost: shouldAutoRenew is false when auto-renew is disabled"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local now = 1000
			local featuredAd = { status = "open", boostTier = TradeAdConfig.BoostTier.Featured, expiresAt = now }
			eq(TradeBoardService.shouldAutoRenew(featuredAd, 1, false, 1, now), false, "auto-renew off")
		end,

		["boost: shouldAutoRenew is false with no credit held"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local now = 1000
			local featuredAd = { status = "open", boostTier = TradeAdConfig.BoostTier.Featured, expiresAt = now }
			eq(TradeBoardService.shouldAutoRenew(featuredAd, 0, true, 1, now), false, "no credit")
		end,

		["boost: shouldAutoRenew is false when no featured slot is free"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local now = 1000
			local featuredAd = { status = "open", boostTier = TradeAdConfig.BoostTier.Featured, expiresAt = now }
			eq(TradeBoardService.shouldAutoRenew(featuredAd, 1, true, 0, now), false, "pool full")
		end,

		["boost: shouldAutoRenew is false for a non-featured ad"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local now = 1000
			local boostedAd = { status = "open", boostTier = TradeAdConfig.BoostTier.Boosted, expiresAt = now }
			eq(TradeBoardService.shouldAutoRenew(boostedAd, 1, true, 1, now), false, "not featured")
		end,

		-- Value-delta meter: percentage the POSTER is giving away, denominator is
		-- the WANT side (asymmetric on purpose -- see the function's own comment).
		["valueDelta: fair trade is 0"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			eq(TradeBoardService.valueDelta(100, 100), 0, "equal sides -> fair")
		end,

		["valueDelta: poster gives more is positive"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			eq(TradeBoardService.valueDelta(150, 100), 50, "give 150 vs want 100 -> +50%")
		end,

		["valueDelta: poster wants more is negative and asymmetric"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			-- NOT -50: denominator is the want side (150), not the give side, so
			-- this does not mirror the +50 case above.
			eq(TradeBoardService.valueDelta(100, 150), -33, "give 100 vs want 150 -> -33%")
		end,

		["valueDelta: both sides empty never divides by zero"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			eq(TradeBoardService.valueDelta(0, 0), 0, "0/0 -> 0, not an error")
		end,

		["valueDelta: empty want side (make-me-an-offer) does not error"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			eq(TradeBoardService.valueDelta(100, 0), 0, "want side empty -> 0, not an error")
		end,

		-- Placement is what the player paid for, and it runs on its own clock.
		-- Without boostExpiresAt the purchased tier never lapsed, so 10 R$ bought
		-- rank one forever and the advertised duration was fiction.
		["boost clock: an expired boost falls back to tier None"] = function()
			local now = 5000
			eq(TradeAdRules.effectiveTier({ boostTier = 2, boostExpiresAt = now + 10 }, now), 2, "inside the window")
			eq(TradeAdRules.effectiveTier({ boostTier = 2, boostExpiresAt = now - 1 }, now), 0, "past the window")
			-- A listing that predates the field has no clock, not a dead one.
			eq(TradeAdRules.effectiveTier({ boostTier = 2 }, now), 2, "legacy listing keeps its tier")
		end,

		["boost clock: an expired boost stops outranking a free ad"] = function()
			local now = 5000
			local lapsed = { boostTier = 2, boostExpiresAt = now - 1, bumpedAt = 100, id = "a" }
			local free = { boostTier = 0, bumpedAt = 200, id = "b" }
			eq(TradeAdRules.order(lapsed, free, now), false, "a lapsed boost sorts below a newer free ad")
			truthy(TradeAdRules.order(free, lapsed, now), "and the free ad sorts above it")
		end,

		-- The paid clock must not be extendable for free. The presence sweep runs
		-- while the poster is online and pushes expiresAt; if it touched
		-- boostExpiresAt as well, staying in game would renew a purchase forever.
		["sweep: presence refresh extends life but never the paid boost clock"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local now = os.time()
			local listing = {
				id = "paid",
				scope = "global",
				status = "open",
				bumpedAt = now - 9000,
				expiresAt = now + 60,
				boostTier = 2,
				boostExpiresAt = now + 120,
			}
			truthy(TradeBoardService.applyPresenceRefresh(listing, now), "an ad near expiry gets refreshed")
			truthy(listing.expiresAt > now + 3600, "life extended")
			eq(listing.boostExpiresAt, now + 120, "the PAID clock MUST be untouched by a free refresh")
			eq(listing.bumpedAt, now - 9000, "rank still untouched")
		end,

		-- The strip is scarce on purpose, so a squatter whose paid window ran out
		-- has to release the slot even while their ad is still alive.
		["featured: a lapsed featured boost frees its pool slot"] = function()
			local now = 1000
			local listings = {
				{ scope = "global", boostTier = 2, expiresAt = now + 9999, boostExpiresAt = now + 100 },
				{ scope = "global", boostTier = 2, expiresAt = now + 9999, boostExpiresAt = now - 1 },
			}
			eq(
				TradeAdRules.featuredOpenSlots(listings, "global", now),
				TradeAdConfig.FeaturedSlotsPerScope - 1,
				"only the ad inside its paid window holds a slot"
			)
		end,

		-- The live feed's sort used to be a second comparator that read boostTier
		-- raw and ignored perks entirely, so the Always Boosted pass did nothing
		-- any player could see. listingOrder now delegates to TradeAdRules.order.
		["order: listingOrder is the rules comparator, perks and all"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local passHolder = { boostTier = 0, perks = { priority = true }, bumpedAt = 50, id = "pass" }
			local free = { boostTier = 0, bumpedAt = 100, id = "free" }
			truthy(TradeBoardService.listingOrder(passHolder, free), "the pass lifts the ad in the LIVE feed sort")
			eq(TradeBoardService.listingOrder(free, passHolder), false, "and the free ad sorts below it")
		end,

		-- Renewal only matters when the strip is full, and the ad being renewed is
		-- itself one of the ads filling it. Counting it against its own renewal
		-- meant auto-renew could never fire in the only case it exists for -- so
		-- the caller excludes the candidate's own slot before asking.
		["boost: auto-renew fires when the ad itself holds the last slot"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local now = 1000
			local scope = TradeAdConfig.Scopes.Global
			local candidate = {
				id = "mine",
				scope = scope,
				status = "open",
				boostTier = TradeAdConfig.BoostTier.Featured,
				boostExpiresAt = now + 60,
				expiresAt = now + 60,
			}
			local listings = { candidate }
			for i = 2, TradeAdConfig.FeaturedSlotsPerScope do
				table.insert(listings, {
					id = "other" .. i,
					scope = scope,
					status = "open",
					boostTier = TradeAdConfig.BoostTier.Featured,
					boostExpiresAt = now + 9999,
					expiresAt = now + 9999,
				})
			end
			local pool = TradeAdRules.featuredOpenSlots(listings, scope, now)
			eq(pool, 0, "the strip is full")
			eq(
				TradeBoardService.shouldAutoRenew(candidate, 1, true, pool, now),
				false,
				"counting its own slot refuses -- the bug the caller must avoid"
			)
			truthy(
				TradeBoardService.shouldAutoRenew(candidate, 1, true, pool + 1, now),
				"excluding the candidate own slot lets its renewal through"
			)
		end,

		-- A featured ad whose paid window already lapsed is not featured any more:
		-- it has to be re-bought, not auto-renewed into a slot it no longer holds.
		["boost: auto-renew refuses an ad whose paid window already lapsed"] = function()
			local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
			local now = 1000
			local lapsed = {
				status = "open",
				boostTier = TradeAdConfig.BoostTier.Featured,
				boostExpiresAt = now - 1,
				expiresAt = now,
			}
			eq(TradeBoardService.shouldAutoRenew(lapsed, 1, true, 3, now), false, "lapsed boost is not featured")
		end,

		----------------------------------------------------------------------
		-- Shop adapter: boosts are sold from the ONE storefront, so the SKU
		-- catalogue has to describe itself in the shape the shop renders.
		----------------------------------------------------------------------

		["shop: every live SKU appears exactly once as a shop offer"] = function()
			local offers = TradeAdConfig.shopOffers()
			eq(#offers, #TradeAdConfig.liveSkus(), "one offer per live SKU")
			local seen: { [string]: number } = {}
			for _, offer in offers do
				seen[offer.id] = (seen[offer.id] or 0) + 1
			end
			for _, sku in TradeAdConfig.liveSkus() do
				eq(seen[sku.id], 1, sku.id .. " appears once")
			end
		end,

		["shop: a SKU with no real product id is never offered"] = function()
			local live: { [string]: boolean } = {}
			for _, sku in TradeAdConfig.liveSkus() do
				live[sku.id] = true
			end
			for _, offer in TradeAdConfig.shopOffers() do
				truthy(live[offer.id], offer.id .. " is backed by a real product")
				truthy(offer.productId > 0, offer.id .. " has a non-zero product id")
			end
		end,

		["shop: each scope lands in its own section"] = function()
			for _, offer in TradeAdConfig.shopOffers() do
				local sku = TradeAdConfig.skuById(offer.id)
				truthy(sku ~= nil, offer.id .. " resolves back to a SKU")
				eq(offer.section, TradeAdConfig.shopSection((sku :: any).scope), offer.id .. " section matches scope")
			end
		end,

		-- The ladder is the whole persuasion: low anchors, best is the pick,
		-- high anchors from above. Rendering them out of order would break it.
		["shop: shelves render low -> best -> high within a section"] = function()
			local rank = { low = 1, best = 2, high = 3 }
			local lastBySection: { [string]: number } = {}
			for _, offer in TradeAdConfig.shopOffers() do
				local sku = TradeAdConfig.skuById(offer.id) :: any
				local r = rank[sku.shelf]
				truthy(r ~= nil, offer.id .. " sits on a known shelf")
				local prev = lastBySection[offer.section] or 0
				truthy(r >= prev, offer.section .. ": shelves never go backwards")
				lastBySection[offer.section] = r
			end
		end,

		["shop: exactly the middle shelf carries BEST VALUE"] = function()
			local badged: { [string]: number } = {}
			for _, offer in TradeAdConfig.shopOffers() do
				local sku = TradeAdConfig.skuById(offer.id) :: any
				if sku.shelf == "best" then
					eq(offer.badge, "BEST VALUE", offer.id .. " is emphasised")
					badged[offer.section] = (badged[offer.section] or 0) + 1
				else
					eq(offer.badge, nil, offer.id .. " carries no badge")
				end
			end
			-- two cards both claiming to be the pick is the failure this guards
			for section, count in badged do
				eq(count, 1, section .. " has one BEST VALUE card")
			end
		end,

		["shop: every offer carries an icon and a blurb the card can render"] = function()
			for _, offer in TradeAdConfig.shopOffers() do
				truthy(type(offer.imageId) == "string" and #offer.imageId > 0, offer.id .. " has an icon")
				truthy(type(offer.description) == "string" and #offer.description > 0, offer.id .. " has a blurb")
				eq(offer.productType, "devproduct", offer.id .. " is a dev product")
			end
		end,

		-- Both boost sections must be ORDERED by the shop, or they would fall
		-- to the bottom as unordered leftovers below the booth cosmetics.
		["shop: both boost sections are ordered by MonetizationConfig"] = function()
			local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
			local ordered: { [string]: boolean } = {}
			for _, name in MonetizationConfig.SectionOrder do
				ordered[name] = true
			end
			truthy(ordered[TradeAdConfig.ShopSections.server], "server boost section is ordered")
			truthy(ordered[TradeAdConfig.ShopSections.global], "global boost section is ordered")
			for _, offer in TradeAdConfig.shopOffers() do
				truthy(ordered[offer.section], offer.section .. " is ordered")
				truthy(MonetizationConfig.SectionLayout[offer.section] ~= nil, offer.section .. " has a card size")
			end
		end,

		-- The boost sections must not collide with a hand-authored one, or the
		-- shop would interleave gem packs with placement.
		["shop: boost sections are not reused by MonetizationConfig.Offers"] = function()
			local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
			for _, offer in MonetizationConfig.Offers do
				truthy(
					offer.section ~= TradeAdConfig.ShopSections.server
						and offer.section ~= TradeAdConfig.ShopSections.global,
					offer.id .. " does not squat a boost section"
				)
			end
		end,

		["shop: offer ids resolve back through skuById for the purchase prompt"] = function()
			for _, offer in TradeAdConfig.shopOffers() do
				local sku = TradeAdConfig.skuById(offer.id)
				truthy(sku ~= nil, offer.id .. " is promptable")
				eq((sku :: any).productId, offer.productId, offer.id .. " prompts its own product")
			end
		end,
	},
}
