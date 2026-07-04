--!strict
-- Token-bucket rate limiter, keyed. check(key) consumes one token if available.
-- Injectable clock for tests.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_ratePerSecond: number,
		_burst: number,
		_buckets: { [string]: { tokens: number, last: number } },
		_clock: () -> number,
	},
	RateLimiter
))

function RateLimiter.new(perMinute: number, burst: number, clock: (() -> number)?): RateLimiter
	return setmetatable({
		_ratePerSecond = perMinute / 60,
		_burst = burst,
		_buckets = {},
		_clock = clock or os.clock,
	}, RateLimiter)
end

function RateLimiter.check(self: RateLimiter, key: string): boolean
	local now = self._clock()
	local b = self._buckets[key]
	if b == nil then
		b = { tokens = self._burst, last = now }
		self._buckets[key] = b
	end
	-- refill
	b.tokens = math.min(self._burst, b.tokens + (now - b.last) * self._ratePerSecond)
	b.last = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.forget(self: RateLimiter, key: string)
	self._buckets[key] = nil
end

return RateLimiter
