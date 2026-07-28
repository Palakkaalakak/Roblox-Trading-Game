--!strict
-- Format: one place for how NUMBERS are shown to players.
--
-- Every screen used to carry its own local comma() helper, so a value could be
-- punctuated three different ways depending on where you looked. This is the
-- single source of truth; screens format through it and nothing else.
--
--   abbrev(1000)       -> "1K"
--   abbrev(1234)       -> "1.2K"
--   abbrev(12345)      -> "12.3K"
--   abbrev(234000000000) -> "234B"
--
-- Trailing ".0" is trimmed, so a round thousand reads "1K" rather than "1.0K".
-- Below 1000 the number is shown in full — abbreviating small values only makes
-- them harder to read.
--
-- WHERE NOT TO USE THIS: anywhere the player is committing to an exact figure
-- (typing an order price, confirming a trade, the gem cost on a purchase). A
-- trader needs to see 1,234 gems, not "1.2K". Use comma() there. Abbreviation
-- is for DISPLAY of large aggregates — leaderboard scores, portfolio totals,
-- supply counts.

local Format = {}

-- Standard short-scale suffixes. Beyond this the numbers stop being meaningful
-- in a game economy, and the last suffix simply keeps scaling.
local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1,234". Exact, grouped, no rounding.
function Format.comma(n: number): string
	local negative = n < 0
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	out = (out:gsub("^,", ""))
	return negative and ("-" .. out) or out
end

-- 1234 -> "1.2K". Rounds DOWN so a displayed figure never overstates what a
-- player actually has (showing "2K" for 1999 gems invites "where's my gem?").
function Format.abbrev(n: number): string
	local negative = n < 0
	local value = math.abs(n)
	if value < 1000 then
		return (negative and "-" or "") .. tostring(math.floor(value))
	end

	local index = 0
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end

	-- one decimal below 100, none above — "12.3K" is useful, "123.4K" is noise
	local text
	if value < 100 then
		local truncated = math.floor(value * 10) / 10
		text = (truncated % 1 == 0) and tostring(math.floor(truncated)) or ("%.1f"):format(truncated)
	else
		text = tostring(math.floor(value))
	end
	return (negative and "-" or "") .. text .. SUFFIXES[index]
end

return Format
