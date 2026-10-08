--!strict
-- Server bootstrap. Explicit, dependency-ordered init: remotes exist first,
-- then persistence/economy, then gameplay services. Two-phase (all Init, then
-- all Start) so cross-service references resolve before anything runs.

local Net = require(script.Net)
Net.init()

local Services = script.Services

local t0 = os.clock()

local ordered = {
	{ "Analytics", require(Services.AnalyticsService) },
	{ "Data", require(Services.DataService) },
	{ "Inventory", require(Services.InventoryService) },
	{ "Economy", require(Services.EconomyService) },
	{ "Pool", require(Services.PoolService) },
	{ "Starter", require(Services.StarterService) },
	{ "Notification", require(Services.NotificationService) },
	{ "Store", require(Services.StoreService) },
	{ "Crafting", require(Services.CraftingService) },
	-- after Crafting: counts the crafts it settles toward milestones + the goal
	{ "EventProgress", require(Services.EventProgressService) },
	-- after Crafting: reads activeEvents() to pick an output nothing else makes
	{ "UniqueCraft", require(Services.UniqueCraftService) },
	{ "Roll", require(Services.RollService) },
	-- after Roll: reuses its draw (pick) for the dig reward
	{ "Dig", require(Services.DigService) },
	-- the dig field in the world (static; each player digs a local copy)
	{ "DigField", require(Services.DigFieldService) },
	{ "Product", require(Services.ProductService) },
	-- after Product: registers its reward on that service's receipt registry
	{ "AdReward", require(Services.AdRewardService) },
	{ "Referral", require(Services.ReferralService) },
	{ "Leaderboard", require(Services.LeaderboardService) },
	{ "Syndicate", require(Services.SyndicateService) },
	{ "TradeBoard", require(Services.TradeBoardService) },
	{ "Trade", require(Services.TradeService) },
	-- after Trade: relays quick chat between its participants
	{ "Chat", require(Services.ChatService) },
	{ "Profile", require(Services.ProfileService) },
	-- after TradeBoard: a booth's slots ARE its owner's open sell listings
	{ "Booth", require(Services.BoothService) },
	{ "Bots", require(Services.BotService) },
	-- after Bots: its level switch also toggles the bot population
	{ "SimPlayers", require(Services.SimPlayerService) },
	{ "Liquidity", require(Services.LiquidityService) },
	{ "Afk", require(Services.AfkService) },
	{ "Rewards", require(Services.RewardsService) },
	{ "Quests", require(Services.QuestService) },
}

for _, entry in ordered do
	local name, service = entry[1], entry[2] :: any
	if type(service.Init) == "function" then
		local s = os.clock()
		service.Init()
		local dt = os.clock() - s
		if dt > 1 then
			warn(("[Boot] %s.Init took %.1fs"):format(name, dt))
		end
	end
end

for _, entry in ordered do
	local service = entry[2] :: any
	if type(service.Start) == "function" then
		service.Start()
	end
end

print(("[Server] trading core booted in %.1fs"):format(os.clock() - t0))

-- Debug-only: run the suites in the REAL server context, where services are
-- actually initialised. Off by default; costs nothing when off.
if require(game:GetService("ReplicatedStorage").Shared.Config.DebugConfig).RunTestsOnBoot then
	task.spawn(function()
		local summary, allPassed = require(script.Tests.TestRunner).run()
		print("[Tests]\n" .. summary)
		if not allPassed then
			warn("[Tests] FAILURES ABOVE")
		end
	end)
end

