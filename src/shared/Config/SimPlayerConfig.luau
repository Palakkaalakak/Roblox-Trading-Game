--!strict
-- SimPlayerConfig: the simulated player population (DEV/TEST ONLY).
--
-- Why this replaces the archetype bots for testing: those are deterministic
-- market participants — every bot ranks items by the same shared fair value, so
-- every bot targets the same top items and posts the same "cheap bundle for one
-- great item" swap. That is the textbook ABM failure mode (identical rules ->
-- lock-step behaviour). Real players disagree about value, want different
-- things, act at random moments, and leave when trades stall. Gode & Sunder
-- (1993): budget-constrained RANDOM traders already reproduce human market
-- efficiency — heterogeneity and noise matter, cleverness doesn't.
--
-- Each agent draws every parameter individually around its segment's mean.

local SimPlayerConfig = {
	-- Master switch for the whole feature (the debug button still needs it).
	Enabled = true,

	Count = 450,

	-- How many distinct items the population trades in (an even slice of the value
	-- range). Depth per item is what lets barter loops exist at all.
	Universe = 60,

	-- Sim clock runs this many times faster than wall time: activity is
	-- multiplied, patience and session lengths divided. Tests would otherwise
	-- wait hours for a "3 minute patience" agent to give up.
	TimeScale = 4,

	-- Demand concentration: HotItems items are chased by everyone; HotShare is the
	-- fraction of wants (and of starting stock) that falls on them.
	HotItems = 6,
	HotShare = 0.6,

	MaxActionsPerTick = 60, -- safety ceiling only; the real bound is the time budget
	TickBudgetSeconds = 0.006, -- max CPU per sweep tick spent on the population
	ListingCap = 4, -- open listings one agent may hold at once

	-- Negative ids well clear of BotService's -(100+i) range.
	IdBase = -20000,

	-- pct: share of the population. activity: mean actions per minute WHILE
	-- online (lognormal-jittered per agent). patience: minutes an agent waits on
	-- an unfilled listing before giving up. sigma: how badly this agent
	-- misjudges an item's value (lognormal). accept: fraction of its own belief
	-- it needs back to take a deal (flippers demand a margin, new players
	-- accept losses). Every sim swap is auto-fill; none ask first.
	-- weights: relative odds of each action when it wakes.
	Segments = {
		{
			id = "new", pct = 30, activity = 0.5, patience = 3, sigma = 0.45, accept = 0.70,
			inv = { 3, 8 }, gems = { 100, 400 }, goals = 0, session = 8, offline = 6,
			weights = { swap = 3, sell = 1, bulk = 0.5, accept = 1, buy = 1, roll = 3, store = 2, craft = 0 },
		},
		{
			id = "casual", pct = 22, activity = 0.4, patience = 8, sigma = 0.30, accept = 0.85,
			inv = { 6, 16 }, gems = { 200, 900 }, goals = 1, session = 12, offline = 8,
			weights = { swap = 3, sell = 2, bulk = 1, accept = 1, buy = 1.5, roll = 2, store = 1.5, craft = 0.5 },
		},
		{
			id = "progression", pct = 18, activity = 0.6, patience = 25, sigma = 0.20, accept = 0.92,
			inv = { 8, 20 }, gems = { 400, 1500 }, goals = 2, session = 20, offline = 10,
			weights = { swap = 2, sell = 1, bulk = 2, accept = 1, buy = 2, roll = 1.5, store = 1, craft = 3 },
		},
		{
			id = "collector", pct = 12, activity = 0.3, patience = 90, sigma = 0.12, accept = 0.99,
			inv = { 30, 70 }, gems = { 800, 3000 }, goals = 3, session = 25, offline = 15,
			weights = { swap = 3, sell = 0.3, bulk = 3, accept = 0.5, buy = 2, roll = 1, store = 0.5, craft = 0.5 },
		},
		{
			id = "flipper", pct = 8, activity = 2.0, patience = 240, sigma = 0.06, accept = 1.10,
			inv = { 20, 45 }, gems = { 2000, 8000 }, goals = 0, session = 40, offline = 5,
			weights = { swap = 2, sell = 3, bulk = 3, accept = 1.5, buy = 4, roll = 0.5, store = 1, craft = 0.5 },
		},
		{
			id = "lawyer", pct = 6, activity = 0.6, patience = 30, sigma = 0.04, accept = 1.0,
			inv = { 10, 25 }, gems = { 500, 2000 }, goals = 1, session = 15, offline = 10,
			weights = { swap = 3, sell = 1.5, bulk = 1, accept = 1, buy = 1, roll = 0.5, store = 0.5, craft = 0.5 },
		},
		{
			id = "hoarder", pct = 4, activity = 0.08, patience = 600, sigma = 0.15, accept = 1.5,
			inv = { 60, 130 }, gems = { 1500, 6000 }, goals = 3, session = 30, offline = 30,
			weights = { swap = 0.5, sell = 0.1, bulk = 1, accept = 0.15, buy = 2, roll = 2, store = 1, craft = 0 },
		},
	},
}

return SimPlayerConfig
