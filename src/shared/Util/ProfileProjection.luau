--!strict
-- Pure projection: a private profile + an economy resolver -> the PUBLIC
-- snapshot. No services, no yielding, no DataStore — unit-testable. Privacy is
-- enforced by OMISSION here (hidden sections become nil), so the impure caller
-- writes a key that physically lacks private data.

local ProfileProjection = {}

export type ItemView = {
	itemId: string,
	name: string,
	rarity: string,
	imageId: string,
	estValue: number,
	circulating: number,
}
type Resolver = (itemId: string) -> ItemView?

-- Gem inflows that count toward Lifetime.gemsEarned. Refund = your own gems
-- back; debug = fake faucet; starter = grant. Only real trading counts.
local EARNED = { trade = true, board = true }
function ProfileProjection.isEarnedSource(source: string): boolean
	return EARNED[source] == true
end

local SHOWCASE_MAX = 6
local CHIP_MAX = 3
local DEFAULT_CHIPS = { "portfolioValue", "trades", "mythicals" }

-- The rarity ladder grew (Godly and Celestial were added above Mythical), so
-- "Mythicals Owned" silently ignored a player's two rarest tiers. It now counts
-- Mythical AND everything above it — hence the label. `celestials` exists for
-- players who want to show off the very top tier on its own.
local TOP_TIERS = { Mythical = true, Godly = true, Celestial = true }

local CHIP_LABELS = {
	portfolioValue = "Portfolio Value",
	trades = "Trades",
	gemsEarned = "Gems Earned",
	mythicals = "Mythical+ Owned",
	celestials = "Celestials Owned",
	distinctItems = "Distinct Items",
	crafted = "Items Crafted",
	referrals = "Friends Invited",
	gems = "Gems",
}
ProfileProjection.AllowedChips = CHIP_LABELS

-- Simulator Icon Pack asset ids, one per stat (gem concept always uses the
-- same GemIcon id — never a different-but-similar gem graphic).
ProfileProjection.ChipIcons = {
	portfolioValue = "rbxassetid://17368064384", -- Gems.GemIcon
	gems = "rbxassetid://17368064384", -- Gems.GemIcon
	gemsEarned = "rbxassetid://17368064384", -- Gems.GemIcon
	trades = "rbxassetid://15403064919", -- Arrows.Trade
	mythicals = "rbxassetid://17368097932", -- Stars.Star
	celestials = "rbxassetid://16912465495", -- crown (the top of the ladder)
	distinctItems = "rbxassetid://127110909372919", -- Menus.Index
	crafted = "rbxassetid://15402896733", -- chest (crafted goods)
	referrals = "rbxassetid://15403064919", -- Arrows.Trade
}

-- owned (count>=1) + resolvable itemIds, ascending CIRCULATING (fewest in
-- existence = scarcest first); ties by itemId for determinism. Up to `limit`.
function ProfileProjection.defaultShowcase(inv: { [string]: number }, resolve: Resolver, limit: number): { string }
	local owned: { ItemView } = {}
	for itemId, count in inv do
		if count >= 1 then
			local v = resolve(itemId)
			if v then
				table.insert(owned, v)
			end
		end
	end
	table.sort(owned, function(a, b)
		if a.circulating ~= b.circulating then
			return a.circulating < b.circulating
		end
		return a.itemId < b.itemId
	end)
	local out: { string } = {}
	for i = 1, math.min(limit, #owned) do
		out[i] = owned[i].itemId
	end
	return out
end

-- filter to still-owned + resolvable, preserve order, map to ItemView.
function ProfileProjection.resolveShowcase(ids: { string }, inv: { [string]: number }, resolve: Resolver): { ItemView }
	local out: { ItemView } = {}
	for _, itemId in ids do
		if (inv[itemId] or 0) >= 1 then
			local v = resolve(itemId)
			if v then
				table.insert(out, v)
			end
		end
	end
	return out
end

function ProfileProjection.portfolioValue(inv: { [string]: number }, resolve: Resolver): number
	local total = 0
	for itemId, count in inv do
		if count >= 1 then
			local v = resolve(itemId)
			if v then
				total += v.estValue * count
			end
		end
	end
	return math.floor(total + 0.5)
end

function ProfileProjection.resolveChip(key: string, ctx: any): { key: string, label: string, value: number, icon: string }?
	local label = CHIP_LABELS[key]
	if label == nil then
		return nil
	end
	local value: number
	if key == "portfolioValue" then
		value = ProfileProjection.portfolioValue(ctx.inventory, ctx.resolve)
	elseif key == "trades" then
		value = ctx.lifetime.trades
	elseif key == "gemsEarned" then
		value = ctx.lifetime.gemsEarned
	elseif key == "gems" then
		value = ctx.gems
	elseif key == "distinctItems" then
		local n = 0
		for _, c in ctx.inventory do
			if c >= 1 then
				n += 1
			end
		end
		value = n
	elseif key == "mythicals" then
		-- Mythical and everything above it (Godly, Celestial) — see TOP_TIERS
		local n = 0
		for itemId, c in ctx.inventory do
			if c >= 1 then
				local v = ctx.resolve(itemId)
				if v and TOP_TIERS[v.rarity] then
					n += 1
				end
			end
		end
		value = n
	elseif key == "celestials" then
		local n = 0
		for itemId, c in ctx.inventory do
			if c >= 1 then
				local v = ctx.resolve(itemId)
				if v and v.rarity == "Celestial" then
					n += 1
				end
			end
		end
		value = n
	elseif key == "crafted" then
		-- distinct crafted/event items held; event outputs are the "evt_" ids
		local n = 0
		for itemId, c in ctx.inventory do
			if c >= 1 and itemId:sub(1, 4) == "evt_" then
				n += 1
			end
		end
		value = n
	elseif key == "referrals" then
		value = ctx.referrals or 0
	else
		return nil
	end
	return { key = key, label = label, value = value, icon = ProfileProjection.ChipIcons[key] or "" }
end

-- Assemble the public snapshot, honoring privacy toggles by omission.
function ProfileProjection.project(args: any): any
	local privacy = args.privacy or { hideValue = false, hideShowcase = false }
	local ctx = {
		inventory = args.inventory,
		resolve = args.resolve,
		gems = args.gems,
		lifetime = args.lifetime,
		referrals = args.referrals or 0,
		firstJoin = args.firstJoin,
		now = args.now,
	}

	local showcase: { ItemView }? = nil
	if not privacy.hideShowcase then
		local ids = args.showcase
		if ids == nil or #ids == 0 then
			ids = ProfileProjection.defaultShowcase(args.inventory, args.resolve, SHOWCASE_MAX)
		end
		showcase = ProfileProjection.resolveShowcase(ids, args.inventory, args.resolve)
	end

	local portfolioValue: number? = nil
	if not privacy.hideValue then
		portfolioValue = ProfileProjection.portfolioValue(args.inventory, args.resolve)
	end

	local keys = args.statChips
	if keys == nil or #keys == 0 then
		keys = DEFAULT_CHIPS
	end
	local chips = {}
	for _, key in keys do
		if #chips >= CHIP_MAX then
			break
		end
		if not (key == "portfolioValue" and privacy.hideValue) then
			local chip = ProfileProjection.resolveChip(key, ctx)
			if chip then
				table.insert(chips, chip)
			end
		end
	end

	return {
		userId = args.userId,
		name = args.name,
		displayName = args.displayName,
		firstJoin = args.firstJoin,
		portfolioValue = portfolioValue,
		showcase = showcase,
		statChips = chips,
		status = args.status or "",
		updatedAt = args.now,
	}
end

return ProfileProjection
