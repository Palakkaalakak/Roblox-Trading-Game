--!strict
-- Rarity: totalSupply -> tier via config thresholds. Pure.

local Items = require(script.Parent.Parent.Config.Items)

local Rarity = {}

-- Thresholds checked in order; first match wins; below all -> Mythical.
function Rarity.tierFor(totalSupply: number): string
	for _, row in Items.RarityThresholds do
		if totalSupply >= row.min then
			return row.tier
		end
	end
	return "Celestial"
end

-- Default assignment weight from supply (sublinear). Separate tunable from supply:
-- callers may override per item; this is only the default derivation.
function Rarity.defaultWeightFor(totalSupply: number): number
	local w = math.floor(totalSupply ^ Items.AssignmentWeightExponent * Items.AssignmentWeightScale + 0.5)
	return math.max(1, w)
end

return Rarity
