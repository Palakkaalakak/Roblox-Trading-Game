--!strict
-- Guard: remote input validation. Every client-facing handler runs args through
-- these before touching state. Returns (ok, err) pairs; never throws.

local TradeConfig = require(script.Parent.Parent.Config.TradeConfig)

local Guard = {}

function Guard.isString(v: any, maxLen: number?): boolean
	return type(v) == "string" and #v <= (maxLen or 128)
end

function Guard.isInt(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and v % 1 == 0
end

function Guard.isPositiveInt(v: any): boolean
	return Guard.isInt(v) and v > 0
end

function Guard.isNonNegativeInt(v: any): boolean
	return Guard.isInt(v) and v >= 0
end

-- Note: Studio local test-server players get NEGATIVE user ids (-1, -2, …),
-- so nonzero integers are accepted; negatives never occur in production.
function Guard.isUserId(v: any): boolean
	return Guard.isInt(v) and v ~= 0 and math.abs(v) < 2 ^ 52
end

function Guard.isBool(v: any): boolean
	return type(v) == "boolean"
end

-- Trade id: GUID-ish token we generated. Bound length, string only.
function Guard.isTradeId(v: any): boolean
	return Guard.isString(v, 64) and #(v :: string) >= 8
end

-- Offer shape: { items: {itemId->count}, gems: number }. Structural check only;
-- ownership/sufficiency is checked separately against the server-side profile.
function Guard.checkOfferShape(v: any): (boolean, string?)
	if type(v) ~= "table" then
		return false, "offer_not_table"
	end
	local items = (v :: any).items
	local gems = (v :: any).gems
	if type(items) ~= "table" then
		return false, "items_not_table"
	end
	if not Guard.isNonNegativeInt(gems) or gems > TradeConfig.MaxGemsPerOffer then
		return false, "bad_gems"
	end
	local slots = 0
	for itemId, count in items do
		if not Guard.isString(itemId, 64) then
			return false, "bad_item_id"
		end
		if not Guard.isPositiveInt(count) or count > TradeConfig.MaxCountPerSlot then
			return false, "bad_item_count"
		end
		slots += 1
		if slots > TradeConfig.MaxSlotsPerSide then
			return false, "too_many_slots"
		end
	end
	-- reject extra keys smuggled into the payload
	for k in v :: any do
		if k ~= "items" and k ~= "gems" then
			return false, "unexpected_key"
		end
	end
	return true, nil
end

-- Item id list for GetStats: bounded array of strings.
function Guard.checkItemIdList(v: any, maxItems: number?): (boolean, string?)
	if type(v) ~= "table" then
		return false, "not_table"
	end
	local n = 0
	for i, itemId in v :: any do
		if type(i) ~= "number" or not Guard.isString(itemId, 64) then
			return false, "bad_entry"
		end
		n += 1
		if n > (maxItems or 64) then
			return false, "too_many"
		end
	end
	return true, nil
end

return Guard
