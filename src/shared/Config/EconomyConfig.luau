--!strict
-- Economy config: value/demand/RAP constants and minimum-data (N/A) thresholds.
-- Stat dependency DAG (no cycles):
--   supply  <- distribution counts (circulating) and burned counts
--   demand  <- decayed interest events (EMA)
--   value   <- g(demand, supply)           (never reads RAP)
--   RAP     <- rolling avg of imputed gem prices of closed trades (reads value)
--
-- That DAG is now actually enforced. Value used to blend a seed with RAP, with
-- the seed's weight decaying to ValueSeedFloor — so Value asymptotically BECAME
-- RAP. That's circular and it made Value meaningless: bots price off Value ->
-- trade at that price -> RAP records it -> Value follows RAP. A feedback loop
-- with no anchor, drifting wherever it had already been.
-- Value is now computed from fundamentals only (scarcity x demand), and RAP is
-- kept as a separate OBSERVED statistic that never feeds back in.

local EconomyConfig = {
	-- Demand EMA: decays toward 0 with a half-life, bumped by trade activity.
	DemandHalfLifeSeconds = 6 * 3600,
	DemandBumpOnTrade = 1.0, -- per closed trade containing the item
	DemandBumpOnOfferInclude = 0.2, -- when an item is placed into a live offer

	-- EST. VALUE = base * scarcity * demandFactor. Fundamentals only.
	--   base       the item's anchor: its store price, or its rarity's price
	--              (Items.StoreCostByRarity), or for crafted items what it cost
	--              to make. This is the ladder (8 / 35 / 130 / 500).
	--   scarcity   ((circulating + burned) / circulating) ^ SupplyExponent
	--              i.e. how much of everything ever handed out has since been
	--              DESTROYED. Nothing burned = 1.0x. Half burned = ~1.5x.
	--   demand     1 + DemandCoefficient * min(demandEMA / DemandRef, 1)
	--
	-- Why scarcity is measured against BURNED and not against totalSupply:
	-- totalSupply is a theoretical cap nobody approaches (a Common may allow
	-- 52k copies while 800 exist), so circulating/totalSupply says nothing about
	-- real scarcity and would price Commons above Mythicals. What actually makes
	-- a held item rarer is copies leaving existence.
	--
	-- The two properties this buys, which are the whole economy:
	--   * A SINK lifts EVERY holder. Burn copies -> scarcity up -> every holder
	--     of that item gets richer without trading. Non-zero-sum.
	--   * PRODUCTION grows the economy. New copies drive scarcity back toward
	--     1.0x, so unit value settles at base while COUNT rises: total worth
	--     (count * value) grows roughly linearly with goods produced. More
	--     stuff = a bigger economy, exactly as it should be.
	ValueBase = 10,
	ReferenceSupply = 500, -- used by scarcitySeed for event items with no recipe
	SupplyExponent = 0.6,
	DemandCoefficient = 0.5, -- a red-hot item is worth up to 1.5x its base
	DemandRef = 5, -- demand EMA that counts as "fully hot"
	ScarcityMax = 6, -- ceiling: burning can't 100x an item
	-- Crafted/event items anchor at (input value + input gems) * this. The >1
	-- premium is real value-add: the craft destroys the inputs and mints
	-- something worth more than they were.
	CraftValuePremium = 1.10,

	-- The inverse of CraftValuePremium, for SACRIFICE recipes (one expensive
	-- item in, several cheap EXISTING items out via output.count -- see
	-- CraftingService.craftCore). A craft mints value because the game
	-- controls the output's seed price; a sacrifice's output is an ordinary
	-- item with its own live Value, so there's nothing to seed -- the lossiness
	-- has to be authored in by hand, at recipe-design time, against current
	-- prices: pick `output.count` so
	--   count * outputItem.Value  <=  inputItem.Value * SacrificeEfficiency
	-- A ratio below 1.0 on purpose: a lossless breakdown would make
	-- Craft-then-Sacrifice-then-Craft a value-laundering loop with no cost,
	-- which defeats the entire point of Value being fundamentals-only and
	-- never inflatable by activity alone. This is a design guideline enforced
	-- by whoever authors a sacrifice recipe, not a runtime multiplier — a
	-- recipe's `count` is a fixed number in config, and live prices drift
	-- after authoring the same way a craft's premium can drift out of date.
	SacrificeEfficiency = 0.85,

	-- Minimum-data thresholds. Below these a stat is StatState.NA and the UI
	-- must render "N/A" (never 0/blank/null).
	MinSamples = {
		Demand = 1, -- demandSamples >= 1
		RAP = 1, -- rapCount >= 1 (at least one closed trade)
	},

	-- House cut on every player-to-player gem transfer (trades, board
	-- settlements, bulk payouts). The cut is burned — a real gem sink.
	GemTaxPercent = 0, -- temp 0: was bleeding pop faster than craft faucet minted

	-- Trade-board listings expire after this long. Nothing is held, so expiry
	-- just drops the row.
	BoardListingTTLSeconds = 7 * 24 * 3600,

	-- Cross-server sync cadence.
	HotFlushIntervalSeconds = 60, -- MemoryStore -> DataStore durable flush
	StatsBroadcastTopic = "econ_delta",
	PoolBroadcastTopic = "pool_rotated",
	TradeBroadcastTopic = "trade_signal",
	MailboxBroadcastTopic = "mailbox_ping",
	BoardBroadcastTopic = "board_delta",
	-- Settlement can't take from a poster who's live on ANOTHER server (their
	-- session lock means a detached write here would race their own save).
	-- Instead of refusing and waiting for a later retry pass, ask that server
	-- to make the take itself -- see TradeBoardService's BoardSettleTopic use.
	BoardSettleTopic = "board_settle",
	BoardSettleWaitSeconds = 3, -- how long to wait for the owning server's answer
}

return EconomyConfig
