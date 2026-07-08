--!strict
-- Tax: the house cut on gem transfers between players (trades, board
-- settlements, bulk payouts). Receiver gets net; the cut is burned (gem sink).
-- Rate lives in EconomyConfig.GemTaxPercent.

local EconomyConfig = require(script.Parent.Parent.Config.EconomyConfig)

local Tax = {}

-- net, cut for a gross gem amount. net + cut == gross always.
function Tax.split(gross: number): (number, number)
	if gross <= 0 then
		return 0, 0
	end
	local net = math.floor(gross * (100 - EconomyConfig.GemTaxPercent) / 100)
	return net, gross - net
end

return Tax
