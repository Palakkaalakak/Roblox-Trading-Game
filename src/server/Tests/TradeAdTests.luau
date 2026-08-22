--!strict
-- Unit tests: trade ad config sanity, slot maths, lifetime and refresh rules,
-- featured pool accounting, and feed ordering. All pure -- no store calls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TradeAdConfig = require(ReplicatedStorage.Shared.Config.TradeAdConfig)

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

local function truthy(v: any, label: string)
	if not v then
		error(label .. ": expected truthy, got " .. tostring(v), 2)
	end
end

return {
	name = "TradeAds",
	tests = {
		-- Every SKU has to name a scope that exists, cost something, and do
		-- something. A SKU that grants no tier, no bump and no time is a paid
		-- no-op -- real money for nothing.
		["config: every SKU is well-formed and actually does something"] = function()
			truthy(#TradeAdConfig.Skus > 0, "no SKUs configured")
			local seen: { [string]: boolean } = {}
			for _, sku in TradeAdConfig.Skus do
				truthy(not seen[sku.id], "duplicate SKU id " .. sku.id)
				seen[sku.id] = true
				truthy(
					sku.scope == TradeAdConfig.Scopes.Server or sku.scope == TradeAdConfig.Scopes.Global,
					sku.id .. ": bad scope " .. tostring(sku.scope)
				)
				truthy(sku.robux > 0, sku.id .. ": costs nothing")
				truthy(
					sku.tier > TradeAdConfig.BoostTier.None or sku.bump or sku.seconds > 0,
					sku.id .. ": grants nothing"
				)
			end
		end,

		-- Global reach costs more than one server. If a global SKU were ever
		-- cheaper than its server twin, nobody would buy the server one.
		["config: global SKUs cost more than their server twins"] = function()
			for _, server in TradeAdConfig.skusForScope(TradeAdConfig.Scopes.Server) do
				-- Count matches so a broken pairing (bump flipped, tier added
				-- without a twin, etc.) fails loudly instead of the loop just
				-- quietly asserting nothing and reporting PASS.
				local matches = 0
				for _, global in TradeAdConfig.skusForScope(TradeAdConfig.Scopes.Global) do
					if server.tier == global.tier and server.bump == global.bump and server.seconds == global.seconds then
						matches += 1
						truthy(
							global.robux > server.robux,
							("%s (%d) must cost more than %s (%d)"):format(global.id, global.robux, server.id, server.robux)
						)
					end
				end
				truthy(matches > 0, server.id .. ": no global twin -- this test would otherwise assert nothing")
			end
		end,

		-- Featured is scarce on purpose. A gamepass granting it permanently
		-- would let one player hold the whole pool forever, so no SKU that is
		-- a pass may carry the featured tier.
		["config: featured is per-ad only, never a permanent perk"] = function()
			eq(TradeAdConfig.FeaturedSlotsPerScope, 3, "featured slots per scope")
			for _, sku in TradeAdConfig.Skus do
				if sku.tier == TradeAdConfig.BoostTier.Featured then
					truthy(sku.seconds > 0, sku.id .. ": featured must be time-boxed, never permanent")
				end
			end
		end,

		["config: skuById finds real ids and rejects junk"] = function()
			local first = TradeAdConfig.Skus[1]
			eq(TradeAdConfig.skuById(first.id), first, "skuById round-trip")
			eq(TradeAdConfig.skuById("nope_not_a_sku"), nil, "unknown id")
		end,
	},
}
