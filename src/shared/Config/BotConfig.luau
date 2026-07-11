--!strict
-- Market bots: simulated traders whose ONLY goal is profit. They hold real
-- durable inventories + gems and act through the exact same escrowed, taxed
-- paths players use — trade board (sell/bulk/swap), the NPC gem store, and
-- event crafting/sacrifices. Their self-interested churn is what seeds
-- prices (RAP) and gets the market moving.
--
-- KILL SWITCH: set Enabled = false before publishing. Bots stop acting and
-- any listings they still have on the board are cancelled at next boot.

local BotConfig = {
	Enabled = true,

	-- negative userIds can never collide with real players
	Bots = {
		{ userId = -101, name = "Ada [bot]", margin = 0.05 }, -- scalper: tiny edges, high volume
		{ userId = -102, name = "Brutus [bot]", margin = 0.12 }, -- holds out for big wins
		{ userId = -103, name = "Cleo [bot]", margin = 0.08 },
		{ userId = -104, name = "Dot [bot]", margin = 0.04 }, -- near-market, trades constantly
		{ userId = -105, name = "Edgar [bot]", margin = 0.10 },
	},

	StartGems = 500, -- one-time seed balance per bot
	StarterDraws = 6, -- one-time seed items per bot (drawn from the live pool reserve)

	-- Pace: one brain pass per bot every ~TickSeconds (jittered ±50%). Each
	-- pass may TAKE up to TakesPerTick deals (buy/fill/accept/store/craft)
	-- and then place/refresh one listing of its own.
	TickSeconds = 6,
	TakesPerTick = 3,
	MaxListingsPerBot = 3, -- board hard cap is 3/poster; use all of it
	RepriceSeconds = 240, -- cancel + relist own quotes this old (keeps quotes near opinion)

	-- Opinions: each bot carries a persistent per-item price opinion that
	-- random-walks each pass (bounded). Bots trade WITH EACH OTHER exactly
	-- when their opinions disagree by more than their margins — a drifting
	-- walk crosses far more often than memoryless noise.
	OpinionWalkStep = 0.04, -- max drift per pass
	OpinionBound = 0.20, -- opinion stays within ±20% of market value
	DecisionNoise = 0.03, -- small extra per-decision jitter

	-- Guard rails: quotes stay tethered to the market value so bot-bot churn
	-- can't spiral prices to 0 or the moon no matter how opinions drift.
	MinSellVsValue = 0.85, -- never quote a sell below 85% of value
	MaxBidVsValue = 1.15, -- never bid above 115% of value

	MinGemsKept = 30, -- never spend below this reserve
	MaxHoldPerItem = 8, -- stop buying an item you're already deep in
	-- Portfolio pressure: below the low gem fraction the bot only sells;
	-- above the high fraction it hunts purchases harder.
	GemFractionLow = 0.25,
	GemFractionHigh = 0.70,

	NetworthLogEvery = 8, -- log bot_networth every N passes per bot
}

return BotConfig
