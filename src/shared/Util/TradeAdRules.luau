--!strict
-- Pure decision logic for trade ads. No store calls, no Players lookups --
-- everything here is a function of its arguments, so it can be unit tested
-- without a running game, and so the same answers hold on every server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TradeAdConfig = require(ReplicatedStorage.Shared.Config.TradeAdConfig)

local TradeAdRules = {}

-- Free allowance plus whatever the player bought, clamped so one buyer can't
-- crowd everyone else off the board.
function TradeAdRules.slotLimit(extraSlots: number): number
	local extra = math.clamp(extraSlots or 0, 0, TradeAdConfig.MaxExtraSlots)
	return TradeAdConfig.BaseSlotsPerScope + extra
end

function TradeAdRules.canPost(openCount: number, extraSlots: number): boolean
	return openCount < TradeAdRules.slotLimit(extraSlots)
end

function TradeAdRules.graceFor(scope: string): number
	if scope == TradeAdConfig.Scopes.Server then
		return TradeAdConfig.ServerGraceSeconds
	end
	return TradeAdConfig.GlobalGraceSeconds
end

-- Only worth a write once the ad is actually close to dying. Checking on every
-- sweep but writing rarely is what keeps this to roughly one write per ad per
-- hour instead of one per sweep.
function TradeAdRules.shouldRefresh(listing: any, now: number): boolean
	local expiresAt = listing.expiresAt
	if expiresAt == nil then
		return true
	end
	return (expiresAt - now) < TradeAdConfig.RefreshThresholdSeconds
end

-- The new death clock. Note what this does NOT return: a bumpedAt. Callers
-- assign this to expiresAt and nothing else -- staying online keeps an ad
-- alive, it does not keep it on top.
function TradeAdRules.refreshedExpiry(scope: string, now: number): number
	local grace = TradeAdRules.graceFor(scope)
	-- Server ads have no grace, so without a floor they would expire the moment
	-- the sweep touched them. The refresh window is that floor: it is exactly
	-- how long we can promise before the next sweep gets another chance.
	return now + math.max(grace, TradeAdConfig.RefreshThresholdSeconds * 2)
end

-- A gamepass lifts every ad its owner holds; a purchased tier lifts one ad.
-- Take the higher so buying a one-off never downgrades a pass holder.
--
-- The purchased tier runs on its OWN clock (boostExpiresAt), separate from the
-- ad's life clock (expiresAt). They have to be separate because the presence
-- sweep extends expiresAt for free while the poster is online -- if placement
-- rode that same field, one 10 R$ purchase would buy permanent rank one and
-- the advertised duration would mean nothing. A nil boostExpiresAt is a
-- listing that predates the field, and reads as "no clock", not "expired".
--
-- `now` is optional only so existing pure callers keep working; production
-- call sites all pass it.
function TradeAdRules.effectiveTier(listing: any, now: number?): number
	local tier = listing.boostTier or TradeAdConfig.BoostTier.None
	local boostExpiresAt = listing.boostExpiresAt
	if boostExpiresAt ~= nil and (now or os.time()) > boostExpiresAt then
		tier = TradeAdConfig.BoostTier.None
	end
	local perks = listing.perks
	if perks and perks.priority and tier < TradeAdConfig.BoostTier.Boosted then
		tier = TradeAdConfig.BoostTier.Boosted
	end
	return tier
end

-- How many featured slots are still buyable in this scope. Expired ads free
-- their slot automatically, and so does an ad whose paid featured window ran
-- out while the ad itself lives on -- both go through effectiveTier so the
-- pool and the sort can never disagree about who is featured.
function TradeAdRules.featuredOpenSlots(listings: { any }, scope: string, now: number): number
	local used = 0
	for _, l in listings do
		if
			l.scope == scope
			and TradeAdRules.effectiveTier(l, now) >= TradeAdConfig.BoostTier.Featured
			and (l.expiresAt == nil or l.expiresAt > now)
		then
			used += 1
		end
	end
	return math.max(0, TradeAdConfig.FeaturedSlotsPerScope - used)
end

-- Feed order: paid tier first, then most recently bumped, then id (ids are
-- time-prefixed, so id order is creation order and the sort is total). This is
-- the ONE ordering rule -- TradeBoardService.listingOrder delegates here so a
-- second comparator can never quietly drop perks or boost expiry on the floor.
function TradeAdRules.order(a: any, b: any, now: number?): boolean
	local at = now or os.time()
	local aTier, bTier = TradeAdRules.effectiveTier(a, at), TradeAdRules.effectiveTier(b, at)
	if aTier ~= bTier then
		return aTier > bTier
	end
	local aBump = a.bumpedAt or a.createdAt or 0
	local bBump = b.bumpedAt or b.createdAt or 0
	if aBump ~= bBump then
		return aBump > bBump
	end
	return (a.id or "") > (b.id or "")
end

return TradeAdRules
