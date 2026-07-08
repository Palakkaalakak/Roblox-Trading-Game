--!strict
-- Server bootstrap. Explicit, dependency-ordered init: remotes exist first,
-- then persistence/economy, then gameplay services. Two-phase (all Init, then
-- all Start) so cross-service references resolve before anything runs.

local Net = require(script.Net)
Net.init()

local Services = script.Services

local ordered = {
	require(Services.AnalyticsService),
	require(Services.RateLimitService),
	require(Services.DataService),
	require(Services.InventoryService),
	require(Services.EconomyService),
	require(Services.PoolService),
	require(Services.StarterService),
	require(Services.StoreService),
	require(Services.CraftingService),
	require(Services.ProductService),
	require(Services.TradeService),
}

for _, service in ordered do
	if type((service :: any).Init) == "function" then
		(service :: any).Init()
	end
end

for _, service in ordered do
	if type((service :: any).Start) == "function" then
		(service :: any).Start()
	end
end

print("[Server] trading core booted")
