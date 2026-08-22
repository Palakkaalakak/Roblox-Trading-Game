--!strict
-- MonetizationConfig: the shop catalogue. EVERY thing the shop sells is one
-- entry in `Offers` below — gem packs, gamepasses, subscriptions, bundles.
--
-- ADDING SOMETHING NEW IS A CONFIG EDIT, NOT A CODE EDIT:
--   1. Create the dev product / gamepass on the Roblox site.
--   2. Copy its id into a new entry below.
--   3. Reboot. It appears in the shop, in its section, with its badge, and
--      purchases grant automatically.
-- No new UI, no new service code. The shop renders every offer through one
-- card template and ProductService grants every offer through one receipt
-- handler.
--
-- FIELD REFERENCE
--   id            unique string, internal only
--   kind          "gems" | "gamepass" | "subscription" | "bundle"
--                 gems         -> grants grants.gems
--                 gamepass     -> one-time, shows OWNED once held
--                 subscription -> recurring (billing handled by Roblox)
--                 bundle       -> grants any mix of gems + items
--   section       shop section header text; new strings create new sections
--   productType   "devproduct" | "gamepass" — how Roblox charges for it
--   productId     the Roblox dev product / gamepass id
--   grants        { gems = n, items = { [itemId] = count } }
--   badge         optional corner ribbon: "BEST VALUE", "LIMITED", "-30%"
--   bonusPercent  optional; renders a gold "+N% BONUS" flourish
--   wasRobux      optional; renders a strikethrough "original price"
--   availableUntil optional unix time; renders a live "N days left" countdown
--                 and the offer stops being sellable once passed
--   giftable      reserved — gifting isn't built yet, but the schema carries it
--
-- NOTE ON IDS: every offer needs a Roblox dev product / gamepass id to be
-- buyable. Until each real product exists, entries point at PLACEHOLDER_PRODUCT_ID
-- (a stand-in dev product) so the shop renders fully buyable during development.
-- At publish, swap each one for its own real id — see the block just below.

export type Offer = {
	id: string,
	kind: "gems" | "gamepass" | "subscription" | "bundle",
	section: string,
	name: string,
	description: string,
	imageId: string?,
	productType: "devproduct" | "gamepass",
	productId: number,
	grants: { gems: number?, items: { [string]: number }? },
	badge: string?,
	bonusPercent: number?,
	wasRobux: number?,
	availableUntil: number?,
	giftable: boolean?,
	sortOrder: number,
	nameColor: { number }?, -- optional RGB tint for the card's name label
	featured: boolean?, -- render as a big wide feature card (like a Blox-Fruits combo)
	boothSlot: boolean?, -- grants +1 booth slot instead of gems/items
	boothSkin: string?, -- grants this BoothConfig skin id
	accent: { number }?, -- optional RGB tint for the card's stroke/gradient/ribbon
}

-- Shared stand-in dev product used by every offer that doesn't have its own real
-- Roblox id yet. Keeps the shop fully buyable in Studio and for devs. AT PUBLISH:
-- create each product on the Roblox site and replace this with each offer's own
-- id, so the correct pack grants on purchase.
local PLACEHOLDER_PRODUCT_ID = 3611275062

-- Exported so other monetized systems (e.g. the ad reward) can point at the same
-- stand-in during development and so tests can tell "shared placeholder" apart
-- from "two real products collided", which is a genuine bug.
local PlaceholderProductId = PLACEHOLDER_PRODUCT_ID

-- Trade ad boosts need an id of their OWN, not the shared placeholder. Every
-- shop offer already carries PlaceholderProductId, and ProductService.Init
-- assigns those directly into devProductHandlers; a later registerDevProduct on
-- that same id finds an existing entry and refuses -- silently, because the
-- warning is deliberately suppressed for the placeholder. The boost handler
-- would never register and no boost would ever grant, with no error anywhere.
-- A distinct (still fake) id keeps the slot free so the registration lands.
-- TODO: real id at publish.
local PlaceholderBoostProductId = PLACEHOLDER_PRODUCT_ID + 1

local MonetizationConfig = {
	PlaceholderProductId = PlaceholderProductId,
	PlaceholderBoostProductId = PlaceholderBoostProductId,

	-- Section order in the shop, top to bottom. Sections with no live offers
	-- are skipped, so unreleased categories simply don't render yet.
	SectionOrder = { "💎 GEM PACKS", "🎟 PASSES", "⭐ SUBSCRIPTIONS", "🎁 BUNDLES", "🏪 BOOTH" },

	-- Per-section card size, in pixels. Real shops don't use one card size for
	-- everything — small packs sit 5-across, chunkier items get wide 3-across
	-- cards with room for a longer name. Any section without an entry falls
	-- back to the template's own size, so this is optional everywhere.
	--   width  — cell width; the grid fits as many per row as the panel allows
	--   height — cell height
	SectionLayout = {
		["💎 GEM PACKS"] = { width = 150, height = 196 },
		["🏪 BOOTH"] = { width = 150, height = 196 },
		["🎟 PASSES"] = { width = 236, height = 250 },
		["⭐ SUBSCRIPTIONS"] = { width = 236, height = 250 },
		["🎁 BUNDLES"] = { width = 236, height = 250 },
	} :: { [string]: { width: number, height: number } },

	Offers = {
		-- ── Gem packs ────────────────────────────────────────────────────
		-- Escalating bonus % gives players a reason to buy the bigger pack;
		-- the "+N% BONUS" flourish and BEST VALUE ribbon are what sell it.
		{
			id = "gems_handful",
			kind = "gems",
			section = "💎 GEM PACKS",
			name = "Handful of Gems",
			description = "A starter pinch of gems.",
			imageId = "rbxassetid://15402880202", -- small gem
			productType = "devproduct",
			productId = PLACEHOLDER_PRODUCT_ID, -- TODO: real id at publish
			grants = { gems = 100 },
			sortOrder = 1,
		},
		{
			id = "gems_pouch",
			kind = "gems",
			section = "💎 GEM PACKS",
			name = "Pouch of Gems",
			description = "Enough for a few good rolls.",
			imageId = "rbxassetid://15402892798", -- gem bag
			productType = "devproduct",
			productId = PLACEHOLDER_PRODUCT_ID, -- TODO: real id at publish
			grants = { gems = 550 },
			bonusPercent = 10,
			sortOrder = 2,
		},
		{
			id = "gems_chest",
			kind = "gems",
			section = "💎 GEM PACKS",
			name = "Chest of Gems",
			description = "Serious buying power.",
			imageId = "rbxassetid://15402896733", -- gem chest
			productType = "devproduct",
			productId = PLACEHOLDER_PRODUCT_ID, -- TODO: real id at publish
			grants = { gems = 1200 },
			bonusPercent = 20,
			badge = "MOST POPULAR", -- decoy anchor: pulls buyers up the ladder
			sortOrder = 3,
		},
		{
			id = "gems_vault",
			kind = "gems",
			section = "💎 GEM PACKS",
			name = "Vault of Gems",
			description = "Stock up for the long haul.",
			imageId = "rbxassetid://15402885986", -- gem pile
			productType = "devproduct",
			productId = PLACEHOLDER_PRODUCT_ID, -- TODO: real id at publish
			grants = { gems = 2600 },
			bonusPercent = 30,
			sortOrder = 4,
		},
		{
			id = "gems_hoard",
			kind = "gems",
			section = "💎 GEM PACKS",
			name = "Dragon's Hoard",
			description = "The biggest pile we sell.",
			imageId = "rbxassetid://17368064384", -- big gem
			productType = "devproduct",
			productId = PLACEHOLDER_PRODUCT_ID, -- TODO: real id at publish
			grants = { gems = 6000 },
			bonusPercent = 40,
			badge = "BEST VALUE",
			featured = true, -- hero card: anchor high with the biggest pack
			sortOrder = 5,
		},

		-- ── Passes / subscriptions / bundles ─────────────────────────────
		-- Priority and duration only -- NOT featured. Only 3 featured slots
		-- exist per scope; a permanent featured pass would let one player
		-- squat the pool forever. Payment buys position/duration, never a
		-- trade action -- posting, browsing, accepting stay free for everyone.
		{
			id = "ad_pass_priority",
			kind = "adperk",
			section = "🎟 PASSES",
			name = "Ad Priority Pass",
			description = "Every trade ad you post sits above the free ads. Forever.",
			imageId = "rbxassetid://15402880202",
			productType = "gamepass",
			productId = PLACEHOLDER_PRODUCT_ID, -- TODO: real id at publish
			grants = { adPerk = "priority" },
			sortOrder = 60,
		},
		{
			id = "ad_pass_duration",
			kind = "adperk",
			section = "🎟 PASSES",
			name = "Ad Duration Pass",
			description = "Your trade ads last a full day and stay up after you leave.",
			imageId = "rbxassetid://15402892798",
			productType = "gamepass",
			productId = PLACEHOLDER_PRODUCT_ID, -- TODO: real id at publish
			grants = { adPerk = "duration" },
			sortOrder = 61,
		},
		--
		-- Example shapes for other kinds still unfilled in this section:
		--
		-- {
		-- 	id = "pass_trader",
		-- 	kind = "gamepass",
		-- 	section = "🎟 PASSES",
		-- 	name = "Trader's Pass",
		-- 	description = "+2 board listing slots, forever.",
		-- 	productType = "gamepass",
		-- 	productId = 123456789,
		-- 	grants = { items = { prod_trader_pass = 1 } },
		-- 	sortOrder = 1,
		-- },
		--
		-- {
		-- 	id = "bundle_starter",
		-- 	kind = "bundle",
		-- 	section = "🎁 BUNDLES",
		-- 	name = "Starter Bundle",
		-- 	description = "Gems plus a head start.",
		-- 	productType = "devproduct",
		-- 	productId = 123456789,
		-- 	grants = { gems = 800, items = { itm_1_5_jade_serpent = 1 } },
		-- 	badge = "LIMITED",
		-- 	wasRobux = 500,
		-- 	availableUntil = 1790000000,
		-- 	sortOrder = 1,
		-- },

		-- ── Booth ────────────────────────────────────────────────────────
		-- Storefront cosmetics and shelf space. Skins are COSMETIC ONLY: never
		-- price, tax, slot count, or which listings show. Slots add shelf space
		-- and nothing else. Both grant through BoothService, so a replayed
		-- receipt is a no-op.
		{
			id = "booth_slot",
			kind = "bundle",
			section = "🏪 BOOTH",
			name = "+1 Booth Slot",
			description = "One more thing for sale at your booth, forever.",
			productType = "devproduct",
			productId = PLACEHOLDER_PRODUCT_ID, -- TODO: real id at publish
			grants = {}, -- granted by BoothService; see ProductService
			boothSlot = true,
			sortOrder = 1,
		},
		{
			id = "booth_skin_sunset",
			kind = "bundle",
			section = "🏪 BOOTH",
			name = "Sunset Awning",
			description = "Warm stripes for a warm sales pitch.",
			productType = "devproduct",
			productId = PLACEHOLDER_PRODUCT_ID, -- TODO: real id at publish
			grants = {},
			boothSkin = "sunset",
			sortOrder = 2,
		},
		{
			id = "booth_skin_midnight",
			kind = "bundle",
			section = "🏪 BOOTH",
			name = "Midnight Counter",
			description = "For traders who work the late server.",
			productType = "devproduct",
			productId = PLACEHOLDER_PRODUCT_ID, -- TODO: real id at publish
			grants = {},
			boothSkin = "midnight",
			sortOrder = 3,
		},
		{
			id = "booth_skin_emerald",
			kind = "bundle",
			section = "🏪 BOOTH",
			name = "Emerald Bazaar",
			description = "Green, and not subtle about it.",
			productType = "devproduct",
			productId = PLACEHOLDER_PRODUCT_ID, -- TODO: real id at publish
			grants = {},
			boothSkin = "emerald",
			sortOrder = 4,
		},
		{
			id = "booth_skin_gilded",
			kind = "bundle",
			section = "🏪 BOOTH",
			name = "Gilded Pavilion",
			description = "Announces your net worth before you do.",
			productType = "devproduct",
			productId = PLACEHOLDER_PRODUCT_ID, -- TODO: real id at publish
			grants = {},
			boothSkin = "gilded",
			badge = "NEW",
			sortOrder = 5,
		},
	} :: { Offer },
}

local function sorted(list: { Offer }): { Offer }
	table.sort(list, function(a, b)
		if a.section ~= b.section then
			return a.section < b.section
		end
		return a.sortOrder < b.sortOrder
	end)
	return list
end

-- Offers the shop SHOWS: everything still inside its limited-time window,
-- including entries whose Roblox id hasn't been created yet. Those render as
-- "COMING SOON" instead of being hidden, so the shop looks stocked while it's
-- being set up and a half-configured entry can never be bought.
function MonetizationConfig.visibleOffers(now: number?): { Offer }
	local t = now or os.time()
	local out = {}
	for _, offer in MonetizationConfig.Offers do
		if offer.availableUntil == nil or t < offer.availableUntil then
			table.insert(out, offer)
		end
	end
	return sorted(out)
end

-- Offers that can actually be SOLD: visible, and backed by a real Roblox id.
-- Only these get a grant handler and only these accept a purchase prompt.
function MonetizationConfig.liveOffers(now: number?): { Offer }
	local out = {}
	for _, offer in MonetizationConfig.visibleOffers(now) do
		if offer.productId ~= 0 then
			table.insert(out, offer)
		end
	end
	return out
end

return MonetizationConfig
