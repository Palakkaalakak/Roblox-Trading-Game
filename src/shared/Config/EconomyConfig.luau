--!strict
-- Economy config: value/demand/RAP constants and minimum-data (N/A) thresholds.
-- Stat dependency DAG (no cycles):
--   supply  <- distribution counts
--   demand  <- decayed interest events (EMA)
--   value   <- g(demand, supply)           (never reads RAP)
--   RAP     <- rolling avg of imputed gem prices of closed trades (reads value)

local EconomyConfig = {
	-- Demand EMA: decays toward 0 with a half-life, bumped by trade activity.
	DemandHalfLifeSeconds = 6 * 3600,
	DemandBumpOnTrade = 1.0, -- per closed trade containing the item
	DemandBumpOnOfferInclude = 0.2, -- when an item is placed into a live offer

	-- Value formula: value = max(1, round(Base * scarcity * demandFactor))
	--   scarcity     = (ReferenceSupply / max(circulating, 1)) ^ SupplyExponent
	--   demandFactor = 1 + DemandCoefficient * log10(1 + demandEMA)
	ValueBase = 10,
	ReferenceSupply = 500,
	SupplyExponent = 0.6,
	DemandCoefficient = 0.5,

	-- Minimum-data thresholds. Below these a stat is StatState.NA and the UI
	-- must render "N/A" (never 0/blank/null).
	MinSamples = {
		Demand = 1, -- demandSamples >= 1
		RAP = 1, -- rapCount >= 1 (at least one closed trade)
		ValueCirculating = 1, -- circulating >= 1
	},

	-- House cut on every player-to-player gem transfer (trades, board
	-- settlements, bulk payouts). The cut is burned — a real gem sink.
	GemTaxPercent = 5,

	-- Trade-board listings expire after this long (escrow auto-refunded).
	BoardListingTTLSeconds = 7 * 24 * 3600,

	-- Cross-server sync cadence.
	HotFlushIntervalSeconds = 60, -- MemoryStore -> DataStore durable flush
	StatsBroadcastTopic = "econ_delta",
	PoolBroadcastTopic = "pool_rotated",
	TradeBroadcastTopic = "trade_signal",
	MailboxBroadcastTopic = "mailbox_ping",
	BoardBroadcastTopic = "board_delta",
	NotifyBroadcastTopic = "notify_ping",
}

return EconomyConfig
