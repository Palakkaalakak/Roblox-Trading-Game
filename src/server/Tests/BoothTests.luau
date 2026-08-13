--!strict
-- Booth tests: the pure rules a storefront depends on — slot arithmetic, skin
-- resolution, and the config invariants that keep skins cosmetic.
--
-- Claim/release is server-local instance state driven by real players and
-- placed models, so it is verified in Studio rather than here; what's testable
-- without a DataModel is the maths and the catalogue, and both are exactly
-- where a silent mistake would turn into pay-to-win or a broken grid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BoothConfig = require(ReplicatedStorage.Shared.Config.BoothConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

local function truthy(v: any, label: string)
	if not v then
		error(label, 2)
	end
end

return {
	name = "Booths",
	tests = {
		["slots: base allowance, extras add, ceiling holds"] = function()
			eq(BoothConfig.slotsFor(0), BoothConfig.BaseSlots, "no extras = base")
			eq(BoothConfig.slotsFor(nil), BoothConfig.BaseSlots, "nil extras = base")
			eq(BoothConfig.slotsFor(3), BoothConfig.BaseSlots + 3, "extras are additive")
			eq(BoothConfig.slotsFor(9999), BoothConfig.MaxSlots, "clamped at MaxSlots")
			-- a negative extras value must never drop someone below the base
			eq(BoothConfig.slotsFor(-5), BoothConfig.BaseSlots, "never below base")
		end,

		["slots: the visible grid holds exactly one starting allowance"] = function()
			-- The point of BaseSlots = GridColumns is that a new player sees one
			-- full row and the buy-me slot starts row two. If these drift apart
			-- the grid opens on a half-empty row, which reads as broken.
			eq(BoothConfig.BaseSlots, BoothConfig.GridColumns, "base slots should fill exactly one row")
			truthy(BoothConfig.GridRows >= 2, "need a second row for the purchasable slot")
			truthy(BoothConfig.MaxSlots > BoothConfig.BaseSlots, "there must be something to buy")
		end,

		["skins: unknown ids fall back, never nil"] = function()
			eq(BoothConfig.resolveSkin("no_such_skin").id, BoothConfig.DefaultSkinId, "unknown -> default")
			eq(BoothConfig.resolveSkin(nil).id, BoothConfig.DefaultSkinId, "nil -> default")
			eq(BoothConfig.resolveSkin("sunset").id, "sunset", "known id resolves to itself")
			truthy(BoothConfig.skinById("no_such_skin") == nil, "skinById is strict")
		end,

		["skins: the default exists and is not for sale"] = function()
			local default = BoothConfig.skinById(BoothConfig.DefaultSkinId)
			truthy(default ~= nil, "the default skin must exist")
			truthy((default :: any).offerId == nil, "the default skin must never be sold")
		end,

		["skins: ids are unique and every skin can be rendered"] = function()
			local seen: { [string]: boolean } = {}
			for _, skin in BoothConfig.Skins do
				truthy(not seen[skin.id], "duplicate skin id: " .. skin.id)
				seen[skin.id] = true
				truthy(type(skin.name) == "string" and skin.name ~= "", skin.id .. " needs a name")
				-- placeholder skins tint geometry, so both colours must be there
				truthy(typeof(skin.canopy) == "table" and #skin.canopy == 3, skin.id .. " needs an RGB canopy")
				truthy(typeof(skin.trim) == "table" and #skin.trim == 3, skin.id .. " needs an RGB trim")
			end
		end,

		["skins: cosmetic only — no skin grants slots, gems or items"] = function()
			-- This is the rule every shipped booth game holds to, and the one
			-- that turns a storefront into pay-to-win the moment it breaks.
			for _, skin in BoothConfig.Skins do
				truthy((skin :: any).slots == nil, skin.id .. " must not grant slots")
				truthy((skin :: any).grants == nil, skin.id .. " must not grant anything")
				truthy((skin :: any).discount == nil, skin.id .. " must not affect price")
			end
		end,

		["shop: every sellable skin has an offer, and every offer a skin"] = function()
			local offerById: { [string]: any } = {}
			for _, offer in MonetizationConfig.Offers do
				offerById[offer.id] = offer
			end
			for _, skin in BoothConfig.Skins do
				local offerId = (skin :: any).offerId
				if offerId then
					local offer = offerById[offerId]
					truthy(offer ~= nil, skin.id .. " points at missing offer " .. tostring(offerId))
					eq(offer.boothSkin, skin.id, offerId .. " must grant the skin that references it")
				end
			end
			for _, offer in MonetizationConfig.Offers do
				if offer.boothSkin then
					truthy(
						BoothConfig.skinById(offer.boothSkin) ~= nil,
						offer.id .. " grants unknown skin " .. tostring(offer.boothSkin)
					)
				end
			end
		end,

		["shop: booth offers grant no gems or items"] = function()
			-- Booth purchases write to the profile through BoothService. If one
			-- also carried gems/items it would double-grant through the normal
			-- inventory path as well.
			for _, offer in MonetizationConfig.Offers do
				if offer.boothSkin or offer.boothSlot then
					local grants = offer.grants or {}
					truthy(grants.gems == nil, offer.id .. " must not grant gems")
					truthy(grants.items == nil, offer.id .. " must not grant items")
				end
			end
		end,

		["anti-scam: the list cooldown is real and bounded"] = function()
			-- Zero would mean no protection at all; anything long enough to
			-- notice makes normal buying feel broken.
			truthy(BoothConfig.ListCooldownSeconds > 0, "cooldown must actually block something")
			truthy(BoothConfig.ListCooldownSeconds <= 10, "cooldown must not feel like a bug")
		end,

		["world contract: names the discovery code depends on are set"] = function()
			for _, key in { "Tag", "IdAttribute", "AnchorName", "SkinMountName", "PromptName" } do
				local v = (BoothConfig :: any)[key]
				truthy(type(v) == "string" and v ~= "", key .. " must be a non-empty string")
			end
		end,
	},
}
