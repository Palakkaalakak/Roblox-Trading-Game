--!strict
-- WildcardConfig: trade-ad tokens — placeholder "wants" for swap listings.
--
-- A player posting a swap doesn't always have a specific item in mind; real
-- trading communities solve this with request tags on trade ads (Rolimon's:
-- Any / Upgrade / Downgrade / Adds / Rares / Demand). Tokens let a poster
-- advertise the GIVE side and describe the SHAPE of offer they want.
--
-- Rules (enforced server-side in TradeBoardService):
--   * tokens are valid ONLY on the WANT side of a swap listing
--   * a want containing any token forces the listing to ASK-FIRST — a fuzzy
--     want cannot auto-settle, the poster approves the concrete offer
--   * tokens are NOT items: never in the registry, never in inventories,
--     never listable on the Market (bulk/sell reject them as unknown items)
--
-- Icons are Simulator Icon Pack decals already used for UI chrome; ids are
-- distinct from any tradeable item's art so tokens read as tags, not goods.

local WildcardConfig = {}

WildcardConfig.Tokens = {
	{
		id = "wild_any",
		label = "Any Offer",
		imageId = "rbxassetid://15403064919", -- trade arrows
		blurb = "Open to anything — send what you've got.",
	},
	{
		id = "wild_upgrade",
		label = "Upgrade",
		imageId = "rbxassetid://17368097932", -- star
		blurb = "Wants one bigger item for this bundle.",
	},
	{
		id = "wild_downgrade",
		label = "Downgrade",
		imageId = "rbxassetid://15402892798", -- gem bag
		blurb = "Wants several smaller items for this.",
	},
	{
		id = "wild_adds",
		label = "Adds",
		imageId = "rbxassetid://15402885986", -- gem pile
		blurb = "Close deal — wants a little extra to balance it.",
	},
	{
		id = "wild_rares",
		label = "Rares",
		imageId = "rbxassetid://16912465495", -- crown
		blurb = "Wants Rare-or-better items only.",
	},
	{
		id = "wild_demand",
		label = "Demand",
		imageId = "rbxassetid://15403144723", -- fire
		blurb = "Wants high-demand items that trade fast.",
	},
	{
		id = "wild_event",
		label = "Event Item",
		imageId = "rbxassetid://15402896733", -- gem chest
		blurb = "Wants any crafted event item.",
	},
}

local byId: { [string]: any } = {}
for _, token in WildcardConfig.Tokens do
	byId[token.id] = token
end

function WildcardConfig.isWildcard(id: any): boolean
	return type(id) == "string" and byId[id] ~= nil
end

function WildcardConfig.byId(id: string): any?
	return byId[id]
end

-- Snapshot-shaped view for UI code that renders offer entries (slots, chips,
-- tooltips) — same fields it reads off an item snapshot, plus isWildcard so
-- the tooltip can show the blurb instead of item stats.
function WildcardConfig.snapshot(id: string): any?
	local token = byId[id]
	if token == nil then
		return nil
	end
	return {
		itemId = token.id,
		name = token.label,
		imageId = token.imageId,
		blurb = token.blurb,
		isWildcard = true,
	}
end

return WildcardConfig
