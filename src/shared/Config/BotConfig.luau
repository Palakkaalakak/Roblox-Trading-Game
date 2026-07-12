--!strict
-- Market bots v5: 500 independent, fully DETERMINISTIC trading agents whose
-- DEMAND IS REASONED, not random. Every bot belongs to a trader archetype
-- (drawn from real agent-based-market-model literature), and what a bot wants
-- to acquire is computed from actual market signals — never a dice roll or an
-- arbitrary hash.
--
-- WHY ARCHETYPES: in real markets people trade because they value the same
-- asset differently, and those valuations come from concrete reasons —
-- someone needs the item as a production input, someone thinks it's
-- underpriced, someone is chasing a hot trend, someone is cornering a scarce
-- supply. A single shared "fair value" produces a no-trade equilibrium (every
-- bid below fair, every ask above, nothing crosses). Heterogeneous, reasoned
-- valuations make bids and asks overlap continuously — that is what actually
-- jumpstarts an economy.
--
-- THE SIX ARCHETYPES (desire = which items the bot is currently trying to
-- acquire; scored from live market state, recomputed each sweep):
--   * fundamentalist — wants items trading BELOW their Est. Value (buy low).
--     Reason: mispricing. score = (Value - bestAsk)/Value.
--   * momentum       — wants items with RISING demand (chase the trend).
--     Reason: demand signal. score = normalized demand EMA.
--   * speculator     — wants SCARCE items to hoard (corner tight supply).
--     Reason: scarcity. score = 1 - circulating/totalSupply.
--   * crafter        — wants INPUTS to a currently-profitable recipe.
--     Reason: production. score = recipe edge if item is an input.
--   * collector      — wants items it owns FEW of, weighted to rarer ones
--     (completing a set). Reason: completeness. score = rarityRank/(1+owned).
--   * maker          — market maker: little directional desire; earns the
--     bid/ask spread by quoting both sides tightly. Reason: liquidity.
--
-- Everything else (inventory-skewed reservation pricing, hunger, barter swaps,
-- stipend) is unchanged from v4. Per-bot numeric params still derive from the
-- index via fixed co-prime strides, so the population is reproducible.
--
-- KILL SWITCH: Enabled = false stops all brains and clears bot listings.

local BotConfig = {
	Enabled = true,

	Count = 500, -- number of independent bots (userIds -101 .. -(100+Count))

	StartGems = 300, -- one-time seed balance per bot
	StarterDraws = 5, -- one-time seed items per bot (in-memory reserve draws)

	-- Pace: one full sweep (every bot thinks once) per SweepSeconds. With 500
	-- bots the per-bot work must stay tiny (all in-memory now — no DataStore).
	SweepSeconds = 30,
	TakesPerPass = 2, -- max deals a bot executes per pass
	QuoteItemsPerBot = 2, -- how many items a bot actively quotes (specialization)

	-- Numeric parameter formulas (index i, 1..Count). Co-prime strides so the
	-- traits decorrelate across the population.
	--   edge_i   = EdgeMin  + EdgeSpan  * ((i * 7)  % Count) / (Count - 1)
	--   gamma_i  = GammaMin + GammaSpan * ((i * 13) % Count) / (Count - 1)
	--   target_i = TargetGemFracMin + TargetGemFracSpan * ((i * 29) % Count) / (Count - 1)
	EdgeMin = 0.02,
	EdgeSpan = 0.10,
	GammaMin = 0.04,
	GammaSpan = 0.16,
	TargetGemFracMin = 0.30,
	TargetGemFracSpan = 0.40,

	-- Archetype mix (must sum to 100). Assigned deterministically by index so
	-- the distribution is exact and reproducible. Maker-heavy for liquidity.
	Archetypes = {
		{ id = "maker", pct = 28 },
		{ id = "fundamentalist", pct = 20 },
		{ id = "momentum", pct = 16 },
		{ id = "speculator", pct = 14 },
		{ id = "crafter", pct = 12 },
		{ id = "collector", pct = 10 },
	},

	-- Reservation-price model
	TargetHoldPerItem = 2, -- position target per item
	SkewScale = 4, -- units of excess position per full gamma step
	DemandTilt = 0.10, -- fair value tilt per unit of normalized demand
	DemandRef = 5, -- demand EMA that counts as "fully hot"

	-- Reasoned demand: each sweep a bot ranks items by its archetype's score
	-- function and DESIRES the top DesireCount. Desired items get +PrefBoost
	-- on the bot's private value, everything else -PrefTrim — the overlap
	-- between one bot's boosted bid and another's trimmed ask is what clears.
	DesireCount = 3,
	PrefBoost = 0.30,
	PrefTrim = 0.10,

	-- Hunger: a bot's edge divides by (1 + HungerEdgeDecay * sweepsSinceFill),
	-- floored at MinEdge — starved bots trade tighter until they fill.
	HungerEdgeDecay = 0.2,
	MinEdge = 0.01,

	-- Barter: post a 1-for-1 swap (give non-desired, want desired) when the
	-- two fair values are within SwapMaxValueGap of each other. One open
	-- swap per bot.
	SwapMaxValueGap = 0.35,

	-- Guard rails: quotes stay tethered to market value; deterministic churn
	-- can't spiral prices.
	MinSellVsValue = 0.85,
	MaxBidVsValue = 1.15,

	-- Quote management: replace own quote only when its price drifts off the
	-- freshly-computed one by more than RepriceFrac (no age-based churn).
	RepriceFrac = 0.10,

	MinGemsKept = 25,
	MaxHoldPerItem = 8,
	QuoteCopies = 2, -- copies per sell quote / per bulk bid

	-- Gem faucet: taxes + store buys + craft costs only ever DRAIN bot gems
	-- (bot-to-bot trade is zero-sum minus tax) — without income the population
	-- starves. Every StipendEvery sweeps a bot below StipendBelowGems gets a
	-- StipendGems top-up.
	StipendEvery = 10,
	StipendGems = 25,
	StipendBelowGems = 150,

	NetworthLogEvery = 10, -- log bot_sweep aggregate every N sweeps
}

return BotConfig
