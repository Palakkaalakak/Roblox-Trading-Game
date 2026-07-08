--!strict
-- Rotation: deterministic time-window selection. Every server computes the
-- SAME active subset from the wall clock alone — no cross-server coordination,
-- no locks, no drift. Used by the limited store shelf and rotating recipes.

local Rotation = {}

-- Current window index for a given interval.
function Rotation.windowIndex(now: number, intervalSeconds: number): number
	return math.floor(now / math.max(intervalSeconds, 1))
end

-- When the current window ends (unix time).
function Rotation.windowEndsAt(now: number, intervalSeconds: number): number
	return (Rotation.windowIndex(now, intervalSeconds) + 1) * math.max(intervalSeconds, 1)
end

-- Deterministic pick of `count` distinct indices out of 1..poolSize for the
-- given window. Pure: same (windowIdx, poolSize, count) -> same result on
-- every server, every call.
function Rotation.pick(windowIdx: number, poolSize: number, count: number): { number }
	count = math.min(count, poolSize)
	local rng = Random.new(windowIdx * 7919 + poolSize * 31)
	local indices = table.create(poolSize)
	for i = 1, poolSize do
		indices[i] = i
	end
	for i = poolSize, 2, -1 do
		local j = rng:NextInteger(1, i)
		indices[i], indices[j] = indices[j], indices[i]
	end
	local out = table.create(count)
	for i = 1, count do
		out[i] = indices[i]
	end
	table.sort(out) -- stable presentation order
	return out
end

return Rotation
