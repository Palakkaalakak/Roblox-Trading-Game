--!strict
-- WeightedDraw: pure weighted random selection. Deterministic with a seeded Random.

export type Candidate = { id: string, weight: number }

local WeightedDraw = {}

-- Returns the chosen id, or nil if no candidate has positive weight.
function WeightedDraw.draw(candidates: { Candidate }, rng: Random?): string?
	local r = rng or Random.new()
	local total = 0
	for _, c in candidates do
		if c.weight > 0 then
			total += c.weight
		end
	end
	if total <= 0 then
		return nil
	end

	local roll = r:NextNumber() * total
	local acc = 0
	for _, c in candidates do
		if c.weight > 0 then
			acc += c.weight
			if roll <= acc then
				return c.id
			end
		end
	end
	-- float edge: fall back to last positive-weight candidate
	for i = #candidates, 1, -1 do
		if candidates[i].weight > 0 then
			return candidates[i].id
		end
	end
	return nil
end

return WeightedDraw
