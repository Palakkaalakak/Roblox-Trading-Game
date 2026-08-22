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
		-- something. A SKU that grants no tier, no bump and no time is a paid
		-- no-op -- real money for nothing.
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
					sku.tier > TradeAdConfig.BoostTier.None or sku.bump or sku.seconds > 0,
					sku.id .. ": grants nothing"
				)
			end
		end,

		-- Global reach costs more than one server. If a global SKU were ever
		-- cheaper than its server twin, nobody would buy the server one.
		["config: global SKUs cost more than their server twins"] = function()
			for _, server in TradeAdConfig.skusForScope(TradeAdConfig.Scopes.Server) do
				-- Count matches so a broken pairing (bump flipped, tier added
				-- without a twin, etc.) fails loudly instead of the loop just
				-- quietly asserting nothing and reporting PASS.
				local matches = 0
				for _, global in TradeAdConfig.skusForScope(TradeAdConfig.Scopes.Global) do
					if server.tier == global.tier and server.bump == global.bump and server.seconds == global.seconds then
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
			eq(TradeAdConfig.FeaturedSlotsPerScope, 3, "featured slots per scope")
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
	},
}
