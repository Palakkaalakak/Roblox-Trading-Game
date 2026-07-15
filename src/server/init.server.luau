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
	{ "Roll", require(Services.RollService) },
	{ "Product", require(Services.ProductService) },
	{ "TradeBoard", require(Services.TradeBoardService) },
	{ "Trade", require(Services.TradeService) },
	{ "Profile", require(Services.ProfileService) },
	{ "Bots", require(Services.BotService) },
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
