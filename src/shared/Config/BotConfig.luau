--!strict
-- Market bots: simulated traders that act like real players (own persistent
-- inventory + gems, post/accept/buy/contribute on the trade board through the
-- exact same escrowed, taxed paths). Goal: maximize their own gems — their
-- self-interested trading is what jumpstarts prices (RAP) and liquidity.
--
-- KILL SWITCH: set Enabled = false before publishing. Bots stop acting and
-- any listings they still have on the board are cancelled at next boot
-- (escrow refunds back into their own stored state, not into the world).

local BotConfig = {
	Enabled = true,

	-- negative userIds can never collide with real players
	Bots = {
		{ userId = -101, name = "Ada [bot]", margin = 0.06 }, -- tight margins, trades a lot
		{ userId = -102, name = "Brutus [bot]", margin = 0.12 }, -- greedy, fewer deals
		{ userId = -103, name = "Cleo [bot]", margin = 0.08 },
		{ userId = -104, name = "Dot [bot]", margin = 0.05 }, -- near-market scalper
		{ userId = -105, name = "Edgar [bot]", margin = 0.10 },
	},

	StartGems = 500, -- one-time seed balance per bot
	StarterDraws = 6, -- one-time seed items per bot (drawn from the live pool reserve)

	TickSeconds = 20, -- avg seconds between one bot's actions (jittered ±50%)
	-- Imperfect information: each decision uses value * (1 ± noise). Without
	-- it, rational margins never cross and bots would only ever trade with
	-- players — the noise makes them occasionally disagree on worth and deal
	-- with EACH OTHER, which is what seeds RAP before any player shows up.
	ValueNoise = 0.12,
	MaxListingsPerBot = 2, -- open board listings a bot keeps at once
	RepriceSeconds = 15 * 60, -- cancel + relist own listings older than this
	MinGemsKept = 40, -- never spend below this reserve
	SaveIntervalSeconds = 120,
}

return BotConfig
