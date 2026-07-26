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

-- ── GROWTH TEST PROFILE ──────────────────────────────────────────────────────
-- TEMPORARY, FOR FUN. This tuning points the whole population at one goal:
-- compound total economy value as fast as possible. It changes BOT BEHAVIOUR
-- ONLY — no player-facing number moves, and the value model is untouched.
--
-- WHAT ACTUALLY COMPOUNDS (see EconomyConfig): value = base * scarcity * demand,
-- and CRAFTING is the only real faucet. A craft does two things at once:
--   1. mints an output anchored at (inputs) * CraftValuePremium — value created
--   2. BURNS its inputs, and scarcity is ((circulating+burned)/circulating)^0.6
--      — so every burn lifts the value of every remaining copy of that input
-- (2) is the compounding term: it's multiplicative across the whole float, not
-- a one-off gain. So "grow as fast as possible" == "craft as much as possible",
-- and everything below exists to keep recipes fed.
--
-- To revert: restore the ORIGINAL values noted on each line.
local BotConfig = {
	Enabled = true,

	-- GROWTH TEST: was 500. MEASURED: at 500 a single sweep did not finish inside
	-- 45s, so the population only ever got ONE round of decisions and nothing
	-- compounded. Compounding needs many rounds, not many agents — a smaller
	-- population cycles far more often, and rounds are what multiply value.
	Count = 150,

	StartGems = 50, -- one-time seed balance per bot
	-- One-time seed items per bot. This is the economy's raw material, and it
	-- gates crafting: a recipe wanting 4x of ONE common is unreachable if the
	-- whole population only holds ~1 of that common per bot, because it takes a
	-- pile of trades to concentrate 4 into one pair of hands. Real traders hold
	-- dozens of items, not five — keep this well above the largest recipe count.
	-- GROWTH TEST: 14 -> 18. Raw material is the hard gate on crafting: a recipe
	-- wanting 4x of one common is unreachable if the population only holds ~1
	-- each. More stock makes recipes reachable sooner — but every extra item is
	-- scanned by every bot every sweep, and 26 measurably slowed sweeps down, so
	-- this is a compromise.
	StarterDraws = 18,

	-- Pace: HFT. One full sweep (every bot thinks once) every SweepSeconds;
	-- each bot executes up to TakesPerPass deals per pass. All state is
	-- in-memory (no DataStore in the hot path), so a 500-bot sweep is
	-- sub-second — a short interval + many takes yields hundreds of
	-- settlements per minute.
	-- GROWTH TEST: was 4 / 8. MEASURED: pushing TakesPerPass to 20 made a single
	-- 500-bot sweep take >45s, so sweeps-per-minute collapsed and total
	-- throughput fell — deals = sweeps x bots x takes, and per-sweep cost scales
	-- with takes, so inflating it buys nothing. Keep takes near baseline and let
	-- the cadence do the work.
	SweepSeconds = 2,
	TakesPerPass = 10,

	-- Numeric parameter formulas (index i, 1..Count). Co-prime strides so the
	-- traits decorrelate across the population.
	--   edge_i = EdgeMin + EdgeSpan * ((i * 7) % Count) / (Count - 1)
	-- edge is the margin a bot needs on a gem-priced deal (snipe / bulk /
	-- store / craft) and tightens with hunger.
	-- GROWTH TEST: was 0.02 / 0.10. Thinner margins mean deals clear instead of
	-- being held out for — throughput matters more than per-deal profit here.
	EdgeMin = 0.005,
	EdgeSpan = 0.04,

	-- Archetype mix (must sum to 100). Assigned deterministically by index so
	-- the distribution is exact and reproducible. Maker-heavy for liquidity.
	-- GROWTH TEST mix (was maker 28 / fundamentalist 20 / momentum 16 /
	-- speculator 14 / crafter 12 / collector 10). Crafters are the value faucet,
	-- so they dominate. Makers are kept substantial anyway — without a quoted
	-- market the crafters can't actually source inputs, and a starved crafter
	-- mints nothing. Speculators are cut hardest: hoarding scarce goods is the
	-- one behaviour that actively works against throughput here.
	Archetypes = {
		{ id = "crafter", pct = 46 },
		{ id = "maker", pct = 24 },
		{ id = "fundamentalist", pct = 16 },
		{ id = "momentum", pct = 8 },
		{ id = "collector", pct = 4 },
		{ id = "speculator", pct = 2 },
	},

	-- GROWTH TEST: was 2. Climbing toward more copies is what lets a crafter
	-- actually assemble a 4x-of-one-common recipe.
	TargetHoldPerItem = 4,
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
	-- GROWTH TEST: was 0.06 / 0.18 — bid up harder so upgrade offers get taken
	OverpayMin = 0.12,
	OverpaySpan = 0.28,
	-- Minimum Win a bot demands before accepting a swap:
	-- acceptEdge_i = AcceptEdgeMin + AcceptEdgeSpan * ((i*23) % Count)/(Count-1)
	-- Trades clear wherever some bot's overpay exceeds another's acceptEdge.
	-- GROWTH TEST: was 0.01 / 0.10 — accept almost any Win, so trades clear
	AcceptEdgeMin = 0.002,
	AcceptEdgeSpan = 0.03,
	MaxBundleItems = 6, -- most items a trade-up bundle may contain
	UpgradeMinPremium = 0.04, -- don't post an upgrade offer worth less than this

	-- Most a bot will pay (vs market value) for an item a profitable recipe
	-- needs. Slightly over value is fine — the craft premium pays for it, and
	-- this is what actually gets crafting fed.
	-- GROWTH TEST: was 1.12. Overpaying well past market for recipe inputs is
	-- correct here — the craft premium plus the scarcity lift from burning the
	-- inputs is worth far more than the overpay costs.
	InputOverpayCap = 1.6,

	-- Gem-poor liquidation: bots need gems for the store + craft costs. Below
	-- this, a bot lists ONE spare item for gems (a real reason to sell — not
	-- market-maker churn).
	GemPoorThreshold = 30,

	-- Liquidation price, as a fraction of market value — priced to actually
	-- move (the seller wants gems, so it goes slightly under value).
	MinSellVsValue = 0.85,

	-- GROWTH TEST: was 10. The hard floor a bot never spends below.
	MinGemsKept = 30,

	-- GROWTH TEST addition. MEASURED: with only a FIXED floor the gem pool is
	-- pinned near Count * MinGemsKept — bots spend everything above it, so
	-- raising WorkGems didn't grow the pool, it just converted gems into items
	-- faster (value +30% while gems went -4.5%).
	--
	-- So savings have to GROW with what a bot has earned: the effective floor is
	-- MinGemsKept + SavingsRateOfEarnings * lifetime gems earned. A bot banks a
	-- quarter of everything it has ever worked for and trades with the rest, so
	-- the pool climbs steadily in step with work instead of finding a ceiling.
	--
	-- MEASURED: this rate sets BOTH curves, in opposite directions. Banked gems
	-- are gems not spent, so a high rate grows the gem pool fast while starving
	-- the crafting that creates value — at 0.25 gems ran +18.8% against value at
	-- +6.9%, which is just inflation. Goods must outpace money, so the rate is
	-- kept low: enough that savings still accumulate (gems rise smoothly, never
	-- dipping) but small enough that most income reaches the craft engine.
	SavingsRateOfEarnings = 0.06,
	MaxHoldPerItem = 12, -- GROWTH TEST: was 8 — room to stockpile recipe inputs

	-- WORK — the gem faucet, and the only one. Every WorkIntervalSeconds a bot
	-- clocks in: it earns WorkGems, but goes dark for WorkDurationSeconds and
	-- cannot trade, roll, craft or buy while it does.
	--
	-- This is the bots' stand-in for the thing real players do to earn currency
	-- (grinding/farming), and the idle time is the point — the gems are PAID FOR
	-- with the opportunity cost of not being in the market. That's what makes it
	-- a real faucet rather than a stipend: the old drip handed out free money for
	-- nothing, which is why total gems climbed on their own.
	--
	-- It has to exist because rolls / store buys / craft fees BURN gems to NPCs,
	-- so without a faucet the pool only ever shrinks (measured: 25,000 -> ~3,900
	-- in minutes) and the whole economy winds down. Faucet + sink is the pair.
	-- Shifts are staggered by bot index, so the market never all downs tools at
	-- the same moment.
	-- GROWTH TEST: was 600 / 10 / 15.
	--
	-- Work is the ONLY net gem faucet — board sales just move gems between
	-- traders, so the pool's whole trajectory is set here. Craft fees, store buys
	-- and rolls are the sinks. At 120s/60 gems the faucet exactly cancelled them
	-- and the pool sat flat near 2,500, so income is raised modestly to sit a
	-- little AHEAD of the sinks: gems should climb steadily, not explode.
	--
	-- The idle time is the price of the money and is deliberately kept real — a
	-- working bot cannot trade, roll, craft or buy — so gems stay earned rather
	-- than handed out.
	-- MEASURED, in order: at 90s/55 with only a fixed floor the pool hovered at
	-- breakeven; raising it to 72 did NOT help (the pool is pinned by the floor,
	-- so extra income just converted to items faster). Once SavingsRateOfEarnings
	-- below made the reserve grow, 72 overshot — gems ran +28%/min against value
	-- at +13%/min, i.e. gem inflation outpacing goods. 40 keeps the climb steady
	-- and below the rate at which real value is created.
	WorkIntervalSeconds = 90, -- clock in every 90s
	WorkGems = 40, -- earned per shift
	WorkDurationSeconds = 8, -- time spent out of the market, per shift

	-- GROWTH TEST: was 25. Every sweep, so the growth curve is readable over a
	-- short run (a 500-bot sweep is far slower than SweepSeconds, so sweeps are
	-- scarce and each one is worth sampling).
	NetworthLogEvery = 1,
}

return BotConfig
