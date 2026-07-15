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
	-- Est. Value (gems, always defined):
	--   seed  = storeCost, or for event items: ValueBase * (ReferenceSupply/totalSupply)^SupplyExponent
	--   final = seed until RAP has ValueRapBlend samples, then
	--           ValueSeedWeight*seed + (1-ValueSeedWeight)*RAP (market takes over)
	ValueBase = 10,
	ReferenceSupply = 500,
	SupplyExponent = 0.6,
	DemandCoefficient = 0.5,
	-- Crafted/event items seed at (input value + input gems) * this. The >1
	-- premium is the economy's main VALUE FAUCET: crafting burns the inputs and
	-- mints something worth more, so crafting genuinely creates net worth
	-- (item-for-item trading is zero-sum minus tax).
	CraftValuePremium = 1.10,

	ValueSeedWeight = 0.20, -- initial anchor weight (one whale trade still can't 10x value)
	ValueSeedHalfLife = 5, -- samples over which the anchor's pull roughly halves
	ValueSeedFloor = 0.04, -- anchor never fully disappears (residual stability)

	-- "X/Y in existence" (X = held copies, Y = total ever distributable) vs
	-- just "X in existence". Toggle without touching UI code.
	ShowExistenceCap = false,

	-- Minimum-data thresholds. Below these a stat is StatState.NA and the UI
	-- must render "N/A" (never 0/blank/null).
	MinSamples = {
		Demand = 1, -- demandSamples >= 1
		RAP = 1, -- rapCount >= 1 (at least one closed trade)
		ValueRapBlend = 1, -- market price starts moving Est. Value after 1 real sale
	},

	-- House cut on every player-to-player gem transfer (trades, board
	-- settlements, bulk payouts). The cut is burned — a real gem sink.
	GemTaxPercent = 0, -- temp 0: was bleeding pop faster than craft faucet minted

	-- Trade-board listings expire after this long (escrow auto-refunded).
	BoardListingTTLSeconds = 7 * 24 * 3600,

	-- Cross-server sync cadence.
	HotFlushIntervalSeconds = 60, -- MemoryStore -> DataStore durable flush
	StatsBroadcastTopic = "econ_delta",
	PoolBroadcastTopic = "pool_rotated",
	TradeBroadcastTopic = "trade_signal",
	MailboxBroadcastTopic = "mailbox_ping",
	BoardBroadcastTopic = "board_delta",
}

return EconomyConfig
