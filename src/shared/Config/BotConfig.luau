--!strict
-- Market bots v6: 500 deterministic agents that trade the way Roblox players
-- actually trade — item-for-item barter judged Win/Fair/Lose on total value,
-- driven by TRADING UP and TRADING DOWN. (v5 quoted gem sell/bulk orders like
-- an HFT market maker: it churned constantly but went nowhere, because
-- item-for-item trading is zero-sum and nobody's worth could compound.)
--
-- WHY THIS PRODUCES A REAL ECONOMY:
--   * Starter pools differ, so bots begin with mismatched portfolios — the
--     precondition for any trade.
--   * A bot with many cheap items TRADES UP: bundles them (+ a gem sweetener)
--     and overpays a premium for one higher-tier item it wants.
--   * The holder of that item TRADES DOWN by accepting: it receives more total
--     value than it gives. That Win is how a trader compounds net worth.
--   * EVENTS are the value faucet: crafting burns cheap inputs and mints an
--     output worth +CraftValuePremium more, so wealth is genuinely created and
--     the common inputs get a demand sink (their supply drops, value rises).
--   * The GEM STORE is the supply faucet: fixed-price stock, so whenever store
--     price < market value it's free profit, and it injects new items.
--
-- Demand is still REASONED (never a dice roll): each bot's archetype scores
-- items from live market signals to decide WHICH item it climbs toward.
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

	StartGems = 50, -- one-time seed balance per bot
	StarterDraws = 5, -- one-time seed items per bot (in-memory reserve draws)

	-- Pace: HFT. One full sweep (every bot thinks once) every SweepSeconds;
	-- each bot executes up to TakesPerPass deals per pass. All state is
	-- in-memory (no DataStore in the hot path), so a 500-bot sweep is
	-- sub-second — a short interval + many takes yields hundreds of
	-- settlements per minute.
	SweepSeconds = 4,
	TakesPerPass = 8, -- max deals a bot executes per pass

	-- Numeric parameter formulas (index i, 1..Count). Co-prime strides so the
	-- traits decorrelate across the population.
	--   edge_i = EdgeMin + EdgeSpan * ((i * 7) % Count) / (Count - 1)
	-- edge is the margin a bot needs on a gem-priced deal (snipe / bulk /
	-- store / craft) and tightens with hunger.
	EdgeMin = 0.02,
	EdgeSpan = 0.10,

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

	TargetHoldPerItem = 2, -- how many of a wanted item a bot climbs toward
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

	-- TRADING MODEL (how real Roblox trading works — see BotService header):
	-- item-for-item barter judged by WFL (Win/Fair/Lose) on total value.
	--   * TRADE UP: bundle several lower items (+ optional gem sweetener) and
	--     offer them for ONE higher-tier item you want. The upgrader OVERPAYS
	--     — that premium is what makes a grail holder willing to part with it.
	--   * TRADE DOWN: accept someone's upgrade offer — you hand over the single
	--     high item and receive more total value back. That's a Win, and it is
	--     how a trader's net worth actually compounds.
	-- Offered premium when trading up: overpay_i = OverpayMin + OverpaySpan * ((i*17) % Count)/(Count-1)
	OverpayMin = 0.06,
	OverpaySpan = 0.18,
	-- Minimum Win a bot demands before accepting a swap:
	-- acceptEdge_i = AcceptEdgeMin + AcceptEdgeSpan * ((i*23) % Count)/(Count-1)
	-- Trades clear wherever some bot's overpay exceeds another's acceptEdge.
	AcceptEdgeMin = 0.01,
	AcceptEdgeSpan = 0.10,
	MaxBundleItems = 6, -- most items a trade-up bundle may contain
	UpgradeMinPremium = 0.04, -- don't post an upgrade offer worth less than this

	-- Gem-poor liquidation: bots need gems for the store + craft costs. Below
	-- this, a bot lists ONE spare item for gems (a real reason to sell — not
	-- market-maker churn).
	GemPoorThreshold = 30,

	-- Liquidation price, as a fraction of market value — priced to actually
	-- move (the seller wants gems, so it goes slightly under value).
	MinSellVsValue = 0.85,

	MinGemsKept = 10, -- with 50 starting gems, keep the spendable buffer usable
	MaxHoldPerItem = 8,

	-- Gem faucet: taxes + store buys + craft costs only ever DRAIN bot gems
	-- (bot-to-bot trade is zero-sum minus tax) — without income the population
	-- starves. A bot below StipendBelowGems gets a small StipendGems top-up
	-- every StipendEvery sweeps. Kept modest so it's a floor, not an inflating
	-- firehose (sweeps are 4s now, so this fires ~once a minute).
	StipendEvery = 15,
	StipendGems = 10,
	StipendBelowGems = 40,

	NetworthLogEvery = 25, -- log bot_sweep aggregate every N sweeps (~100s)
}

return BotConfig
