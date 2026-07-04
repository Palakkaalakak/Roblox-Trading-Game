--!strict
-- RateLimitService: per-player, per-op token buckets from TradeConfig.RateLimits.
-- check(player, op) -> bool. Denials are logged (exploit signal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TradeConfig = require(ReplicatedStorage.Shared.Config.TradeConfig)
local RateLimiter = require(ReplicatedStorage.Shared.Util.RateLimiter)
local AnalyticsService = require(script.Parent.AnalyticsService)

local RateLimitService = {}

local limiters: { [string]: any } = {}

function RateLimitService.Init()
	for op, cfg in TradeConfig.RateLimits do
		limiters[op] = RateLimiter.new(cfg[1], cfg[2])
	end
end

function RateLimitService.Start()
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:forget(tostring(player.UserId))
		end
	end)
end

function RateLimitService.check(player: Player, op: string): boolean
	local limiter = limiters[op]
	if limiter == nil then
		return true -- un-configured op: allow, but that's a code smell
	end
	local allowed = limiter:check(tostring(player.UserId))
	if not allowed then
		AnalyticsService.log("rate_limited", { userId = player.UserId, op = op })
	end
	return allowed
end

return RateLimitService
