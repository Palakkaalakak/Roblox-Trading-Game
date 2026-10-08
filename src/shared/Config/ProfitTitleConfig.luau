--!strict
-- ProfitTitleConfig: the title ladder that continues PAST the quest ranks
-- (RankConfig). Once a player has completed every quest, further titles come
-- from LIFETIME TRADE PROFIT instead (profile.Lifetime.gemsEarned -- already
-- tracked, already a ratchet: it only ever increases, so losing gems or item
-- value can never demote a title). Effects (gradients, strokes, VFX) are
-- deliberately NOT built yet -- `tier` is reserved for that: 1 = plain,
-- 2 = nicer, 3 = coolest.
--
-- Thresholds are GENERATED, not hand-typed: each tier is a geometric run from
-- `start`, growing by `growth` per step, so 120 numbers can't have a typo'd
-- one buried in them. Tune a tier's climb by changing `growth`, not by
-- editing every number in it.

local ProfitTitleConfig = {}

local TIER_NAMES = { "plain", "nicer", "coolest" }

-- 30 plain
local PLAIN = {
	"Hustler", "Grinder", "Flipper", "Sniper", "Haggler",
	"Bargainer", "Swapper", "Trader", "Dealer", "Broker",
	"Hoarder", "Collector", "Stacker", "Bag Chaser", "Coin Farmer",
	"Gem Hunter", "Deal Sniper", "Market Rat", "Value Hunter", "Trade Grinder",
	"Side Hustler", "Fast Flipper", "Lowballer", "Offer Spammer", "Lurker",
	"Window Shopper", "Stock Checker", "RAP Watcher", "Price Checker", "Trade Enjoyer",
}

-- 40 nicer
local NICER = {
	"Sweaty Trader", "Tryhard Flipper", "Big Flipper", "Smart Hoarder", "Pro Sniper",
	"Certified Trader", "Top Flipper", "Elite Sniper", "Rich Kid", "Big Baller",
	"Baller", "Money Bags", "Deal Wizard", "Trade Wizard", "Market Menace",
	"Flip King", "RAP Chaser", "Value Master", "Gem Lord", "Stack Lord",
	"Cash Cow", "Trade Beast", "Trade Machine", "Swap Machine", "Flip Machine",
	"Bag Secured", "Profit Printer", "Gem Printer", "Deal Hunter", "Trade Hunter",
	"Trade Sweat", "Market Sweat", "Hoard Boss", "Sniper Boss", "Flip Boss",
	"Trade Boss", "Deal Boss", "Market Boss", "Big Spender", "High Roller",
}

-- 50 coolest
local COOLEST = {
	"Certified Whale", "Goated Trader", "Cracked Trader", "Sigma Trader", "Sigma Flipper",
	"Chad Merchant", "Aura Farmer", "Market Mogul", "Trade Mogul", "Flip Mogul",
	"Hoard Mogul", "Gem Mogul", "Deal Mogul", "Trade Tycoon", "Flip Tycoon",
	"Market Tycoon", "Gem Tycoon", "Stack Tycoon", "Whale Tier", "Mega Whale",
	"Giga Whale", "Giga Trader", "Giga Flipper", "Giga Baller", "Giga Chad",
	"Trade King", "Flip King II", "Market King", "Gem King", "Stack King",
	"Trade God", "Flip God", "Market God", "Gem God", "Stack God",
	"Goated Flipper", "Goated Whale", "Cracked Whale", "Cracked Flipper", "Certified Legend",
	"Trade Legend", "Flip Legend", "Market Legend", "Gem Legend", "Untouchable",
	"Hall of Fame", "Trading Royalty", "The Final Boss", "The Market Itself", "Endgame",
}

-- Tier definitions: `start` is the first threshold in the tier, `growth` the
-- per-step multiplier. Each tier's start is set well above the previous
-- tier's last threshold, so tiers don't overlap.
local TIER_DEFS = {
	{ titles = PLAIN, start = 40, growth = 1.2 }, -- ~250 -> ~10.9K
	{ titles = NICER, start = 12000, growth = 1.11 }, -- ~15K -> ~1.19M
	{ titles = COOLEST, start = 1500000, growth = 1.10 }, -- ~1.5M -> ~157M
}

-- Flat, sorted-ascending list built once at require time: { threshold, title, tier }.
local LADDER: { { threshold: number, title: string, tier: number } } = {}
for tierIndex, def in TIER_DEFS do
	local threshold = def.start
	for _, title in def.titles do
		table.insert(LADDER, { threshold = math.floor(threshold), title = title, tier = tierIndex })
		threshold *= def.growth
	end
end

ProfitTitleConfig.Ladder = LADDER
ProfitTitleConfig.TierNames = TIER_NAMES

-- The highest-threshold entry `lifetimeProfit` has reached, or nil if it
-- hasn't hit even the first one yet (still just holds their quest-rank title).
function ProfitTitleConfig.titleFor(lifetimeProfit: number): { threshold: number, title: string, tier: number }?
	local best = nil
	for _, entry in LADDER do
		if lifetimeProfit >= entry.threshold then
			best = entry
		else
			break -- LADDER is ascending; nothing further can match
		end
	end
	return best
end

return ProfitTitleConfig
