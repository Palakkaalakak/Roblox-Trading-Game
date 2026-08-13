--!strict
-- BoothConfig: player storefronts in the trading plaza.
--
-- A booth is a HAND-PLACED model. Nothing here spawns one: BoothService finds
-- whatever carries the CollectionService tag below and reads its BoothId
-- attribute for identity. Adding, moving or removing a booth is a Studio edit.
--
-- A booth is a SURFACE over sell listings that already exist. Stocking a slot
-- posts an ordinary `sell` listing, so the same stock shows on the booth and in
-- the Market at one price. Nothing is ever held — posting only checks you hold
-- the goods, exactly as the rest of the board works.
--
-- Skins are COSMETIC ONLY. They never touch price, tax, slot count, or which
-- listings are visible. That rule holds in every game that ships booths, and
-- breaking it is how a storefront turns into pay-to-win.

local BoothConfig = {
	Enabled = true, -- kill switch: false leaves every booth unclaimable

	-- World contract ------------------------------------------------------
	-- Tag every placed booth model with this, and give it a unique BoothId.
	Tag = "TradeBooth",
	IdAttribute = "BoothId",
	-- Required children of a placed booth model. A booth missing any of these
	-- is skipped with a warning rather than half-working.
	AnchorName = "Anchor", -- BasePart; its front face carries the SurfaceGui
	SkinMountName = "SkinMount", -- BasePart; recoloured by the equipped skin
	PromptName = "BoothPrompt", -- ProximityPrompt

	-- Claiming ------------------------------------------------------------
	ClaimHoldSeconds = 1, -- hold E, so a claim is deliberate
	MaxPromptDistance = 14,

	-- Slots ---------------------------------------------------------------
	BaseSlots = 5, -- everyone starts with a full visible row
	MaxSlots = 20, -- ceiling on BaseSlots + purchased extras
	GridColumns = 5, -- visible grid is 5 wide...
	GridRows = 2, -- ...and 2 tall; more scrolls

	-- Storefront text -----------------------------------------------------
	MaxTaglineLength = 60,

	-- Anti-scam -----------------------------------------------------------
	-- PS99 shipped booths without either of these and had to patch them in 13
	-- months later, after the scams were established. They cost nothing now.
	--
	-- A slot stocked within this many seconds cannot be bought. Kills the
	-- swap-the-item-as-they-click bait: the buyer always has time to see what
	-- they are actually clicking. Enforced on the listing's creation time.
	ListCooldownSeconds = 3,
	-- Players within this many studs of a booth render semi-transparent, so
	-- nobody can stand in front of a display and body-block it.
	TransparencyRadius = 12,
	NearBoothTransparency = 0.6,

	-- Skins ---------------------------------------------------------------
	-- PLACEHOLDER SET. Each skin recolours the placed booth's parts; there is
	-- no art dependency yet, so booths look distinct without waiting on
	-- models. At publish, give a skin a `model` (a Model in ReplicatedStorage)
	-- and BoothService mounts that instead of tinting — see applySkin.
	--
	-- `sold = false` means it cannot be bought and is granted some other way
	-- (default, events, group join). Robux-buyable skins are the ones with a
	-- matching MonetizationConfig entry, keyed by offerId.
	DefaultSkinId = "default",
	Skins = {
		{
			id = "default",
			name = "Market Stall",
			blurb = "The one everybody starts with.",
			canopy = { 90, 100, 120 },
			trim = { 140, 150, 170 },
			sold = false,
		},
		{
			id = "sunset",
			name = "Sunset Awning",
			blurb = "Warm stripes for a warm sales pitch.",
			canopy = { 235, 120, 60 },
			trim = { 255, 200, 110 },
			offerId = "booth_skin_sunset",
		},
		{
			id = "midnight",
			name = "Midnight Counter",
			blurb = "For traders who work the late server.",
			canopy = { 45, 50, 95 },
			trim = { 120, 140, 255 },
			offerId = "booth_skin_midnight",
		},
		{
			id = "emerald",
			name = "Emerald Bazaar",
			blurb = "Green, and not subtle about it.",
			canopy = { 40, 150, 95 },
			trim = { 120, 255, 190 },
			offerId = "booth_skin_emerald",
		},
		{
			id = "gilded",
			name = "Gilded Pavilion",
			blurb = "Announces your net worth before you do.",
			canopy = { 190, 150, 45 },
			trim = { 255, 225, 120 },
			offerId = "booth_skin_gilded",
		},
	},
}

function BoothConfig.skinById(id: string?): any?
	for _, skin in BoothConfig.Skins do
		if skin.id == id then
			return skin
		end
	end
	return nil
end

-- The skin a booth should actually render: the requested one if it exists,
-- otherwise the default. Never nil, so no caller has to handle a missing skin.
function BoothConfig.resolveSkin(id: string?): any
	return BoothConfig.skinById(id) or BoothConfig.skinById(BoothConfig.DefaultSkinId) or BoothConfig.Skins[1]
end

-- Slots this player has. Purchased extras are additive and capped, so a
-- runaway grant can never produce a booth with hundreds of shelves.
function BoothConfig.slotsFor(extraSlots: number?): number
	return math.clamp(BoothConfig.BaseSlots + (extraSlots or 0), BoothConfig.BaseSlots, BoothConfig.MaxSlots)
end

return BoothConfig
