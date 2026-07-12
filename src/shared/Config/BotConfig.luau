--!strict
-- Market bots v3: 100 independent, fully DETERMINISTIC trading agents.
-- No randomness anywhere — every price and decision is a calculation from
-- market state (fair value, order book, supply/demand) and the bot's own
-- position. Strategies (adapted from real market microstructure):
--
--   1. INVENTORY-SKEWED MARKET MAKING (Avellaneda-Stoikov, simplified):
--      each bot quotes a sell (ask) and a bulk buy (bid) around its
--      reservation price r = fair * (1 - gamma * (position - target)/scale).
--      Holding too much of an item lowers r (quote cheaper, shed inventory);
--      holding none raises it (bid harder). Different positions + different
--      gamma/edge per bot -> quotes structurally cross -> constant trade.
--   2. STAT-ARB TAKING: lift any ask priced <= r*(1-edge); sell into any
--      bid whose after-tax proceeds >= r*(1+edge). Pure threshold rules.
--   3. PRODUCTION ARBITRAGE (events): craft when fair(output) beats total
--      input cost by the bot's edge; when inputs are missing, BID for them
--      (need-based pricing — the recipe's profitability sets what the bot
--      will pay).
--   4. PRIMARY-MARKET ARB (NPC store): buy stock priced under fair value.
--
-- Per-bot parameters derive from the bot index via fixed formulas (below),
-- so the population is heterogeneous but reproducible run-to-run.
--
-- KILL SWITCH: Enabled = false stops all brains and cancels leftover bot
-- listings at next boot.

local BotConfig = {
	Enabled = true,

	Count = 100, -- number of independent bots (userIds -101 .. -(100+Count))

	StartGems = 300, -- one-time seed balance per bot
	StarterDraws = 4, -- one-time seed items per bot (real reserve draws)

	-- Pace: one full sweep (every bot thinks once) per SweepSeconds.
	SweepSeconds = 45,
	TakesPerPass = 2, -- max deals a bot executes per pass
	QuoteItemsPerBot = 2, -- how many items a bot actively quotes (specialization)

	-- Parameter formulas (index i, 1..Count). Deliberately co-prime strides
	-- so the three traits decorrelate across the population.
	--   edge_i   = EdgeMin  + EdgeSpan  * ((i * 7)  % Count) / (Count - 1)
	--   gamma_i  = GammaMin + GammaSpan * ((i * 13) % Count) / (Count - 1)
	--   target_i = TargetGemFracMin + TargetGemFracSpan * ((i * 29) % Count) / (Count - 1)
	EdgeMin = 0.02,
	EdgeSpan = 0.10,
	GammaMin = 0.04,
	GammaSpan = 0.16,
	TargetGemFracMin = 0.30,
	TargetGemFracSpan = 0.40,

	-- Reservation-price model
	TargetHoldPerItem = 2, -- position target per item
	SkewScale = 4, -- units of excess position per full gamma step
	DemandTilt = 0.10, -- fair value tilt per unit of normalized demand
	DemandRef = 5, -- demand EMA that counts as "fully hot"

	-- Guard rails: quotes stay tethered to market value; deterministic churn
	-- can't spiral prices.
	MinSellVsValue = 0.85,
	MaxBidVsValue = 1.15,

	-- Quote management: replace own quote when its price drifts off the
	-- currently-computed one by more than RepriceFrac, or when stale.
	RepriceFrac = 0.10,
	RepriceSeconds = 300,

	MinGemsKept = 25,
	MaxHoldPerItem = 8,
	QuoteCopies = 2, -- copies per sell quote / per bulk bid

	NetworthLogEvery = 10, -- log bot_networth every N sweeps (aggregate)
}

return BotConfig
