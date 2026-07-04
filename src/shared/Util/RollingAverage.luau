--!strict
-- RollingAverage: incremental mean (O(1), no history). Used for RAP.
-- avg' = avg + (sample - avg) / (count + 1)

local RollingAverage = {}

function RollingAverage.push(avg: number, count: number, sample: number): (number, number)
	local newCount = count + 1
	local newAvg = avg + (sample - avg) / newCount
	return newAvg, newCount
end

return RollingAverage
