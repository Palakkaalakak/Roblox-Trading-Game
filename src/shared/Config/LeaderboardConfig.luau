--!strict
-- LeaderboardConfig: which boards exist and how they behave.
--
-- Adding a board is a config entry plus one scorer in LeaderboardService — no
-- new UI, no new remotes; the screen renders whatever the server sends.
--
-- WEEKLY vs ALL-TIME: a weekly board is the same board with the current week's
-- index appended to its DataStore key (Rotation.windowIndex over a 7-day
-- window). When the week rolls over the key simply stops matching and a fresh
-- board starts — no cron, no reset job, no cross-server coordination, and old
-- weeks stay readable if we ever want history.

local LeaderboardConfig = {
	-- How many ranked rows a board returns. OrderedDataStore pages cap at 100.
	TopCount = 50,

	-- Seconds between score writes FOR ONE PLAYER on ONE board. Scores are
	-- pushed on a timer, never per event: a trade can change portfolio value
	-- hundreds of times a minute and OrderedDataStore has a per-key write
	-- budget that a busy server would blow through instantly.
	WriteIntervalSeconds = 180,

	-- Length of a "weekly" window.
	WeekSeconds = 7 * 24 * 3600,

	-- Board order is presentation order in the UI.
	Boards = {
		{
			id = "portfolio",
			name = "Portfolio Value",
			blurb = "Everything you own, at live Est. Value.",
			-- suffix on the store name; the weekly variant appends the window
			store = "LB_Portfolio_v1",
			unit = "gems",
		},
		{
			id = "trades",
			name = "Total Trades",
			blurb = "Completed trades, all time.",
			store = "LB_Trades_v1",
			unit = "trades",
		},
		{
			id = "rarest",
			name = "Rarest Item",
			blurb = "The scarcest thing in your inventory.",
			-- scored by scarcity: a smaller totalSupply is a better score, so
			-- the scorer inverts it (see LeaderboardService.scoreRarest)
			store = "LB_Rarest_v1",
			unit = "scarcity",
		},
	},
}

-- Board descriptor by id, or nil for an unknown id (never trust a client id).
function LeaderboardConfig.byId(id: string): any?
	for _, board in LeaderboardConfig.Boards do
		if board.id == id then
			return board
		end
	end
	return nil
end

-- DataStore name for a board in a given scope. Weekly appends the window index
-- so a new week is automatically a new, empty board.
function LeaderboardConfig.storeName(board: any, scope: string, windowIndex: number): string
	if scope == "weekly" then
		return board.store .. "_w" .. tostring(windowIndex)
	end
	return board.store
end

return LeaderboardConfig
