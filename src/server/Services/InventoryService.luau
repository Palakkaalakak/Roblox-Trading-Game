--!strict
-- InventoryService: THE single chokepoint for item + gem mutations on loaded
-- profiles. Validate-all-then-apply => a delta is atomic (all-or-nothing) in
-- memory; durability via save. No other module writes Inventory/Gems directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local GEM_CAP = 2 ^ 50 -- sanity ceiling, far above any legit balance

local InventoryService = {}

export type Delta = {
	items: { [string]: number }?, -- itemId -> signed count
	gems: number?, -- signed
}

-- Validate a delta against a profile without mutating. Returns ok, err.
local function validate(profile: any, delta: Delta): (boolean, string?)
	if delta.gems then
		local newGems = profile.Gems + delta.gems
		if newGems < 0 then
			return false, "insufficient_gems"
		end
		if newGems > GEM_CAP then
			return false, "gem_cap"
		end
	end
	if delta.items then
		for itemId, count in delta.items do
			local newCount = (profile.Inventory[itemId] or 0) + count
			if newCount < 0 then
				return false, "insufficient_items:" .. itemId
			end
		end
	end
	return true, nil
end

-- Atomically apply a delta to a loaded player's profile.
-- idempotencyKey (optional): recorded in profile.ClaimedIds; a repeat apply
-- with the same key becomes a no-op success.
function InventoryService.applyDelta(player: Player, delta: Delta, source: string, idempotencyKey: string?): (boolean, string?)
	local profile = DataService.getProfile(player)
	if profile == nil then
		return false, "profile_not_loaded"
	end

	if idempotencyKey and profile.ClaimedIds[idempotencyKey] then
		return true, nil -- already applied
	end

	local ok, err = validate(profile, delta)
	if not ok then
		return false, err
	end

	if delta.gems then
		profile.Gems += delta.gems
	end
	if delta.items then
		for itemId, count in delta.items do
			local newCount = (profile.Inventory[itemId] or 0) + count
			profile.Inventory[itemId] = newCount ~= 0 and newCount or nil
		end
	end
	if idempotencyKey then
		profile.ClaimedIds[idempotencyKey] = true
	end

	AnalyticsService.log("inventory_delta", {
		userId = player.UserId,
		source = source,
		gems = delta.gems or 0,
		items = delta.items or {},
	})

	InventoryService.pushState(player)
	return true, nil
end

-- Can this profile afford this (positive) offer right now?
function InventoryService.canAfford(player: Player, offer: { items: { [string]: number }, gems: number }): (boolean, string?)
	local profile = DataService.getProfile(player)
	if profile == nil then
		return false, "profile_not_loaded"
	end
	if profile.Gems < offer.gems then
		return false, "insufficient_gems"
	end
	for itemId, count in offer.items do
		if (profile.Inventory[itemId] or 0) < count then
			return false, "insufficient_items:" .. itemId
		end
	end
	return true, nil
end

-- Push authoritative inventory + gems snapshot to the owning client.
function InventoryService.pushState(player: Player)
	local profile = DataService.getProfile(player)
	if profile then
		Net.fireClient("InventoryChanged", player, profile.Inventory, profile.Gems)
	end
end

function InventoryService.Init() end

function InventoryService.Start()
	Net.bindFunction("GetInventory", function(player)
		local profile = DataService.getProfile(player)
		if profile == nil then
			return { ok = false, err = "loading" }
		end
		return { ok = true, inventory = profile.Inventory, gems = profile.Gems }
	end)

	-- DEBUG ONLY: +gems button faucet. Delete with DebugConfig for release.
	local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
	local RateLimitService = require(script.Parent.RateLimitService) :: any
	Net.bindFunction("DebugGiveGems", function(player)
		if not DebugConfig.GiveGemsEnabled then
			return { ok = false, err = "disabled" }
		end
		if not RateLimitService.check(player, "DebugGiveGems") then
			return { ok = false, err = "rate_limited" }
		end
		local ok, err = InventoryService.applyDelta(player, { gems = DebugConfig.GiveGemsAmount }, "debug")
		return { ok = ok, err = err }
	end)
end

return InventoryService
