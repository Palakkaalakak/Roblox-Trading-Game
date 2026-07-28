--!strict
-- Unit tests: ProfileProjection pure logic (showcase/value/chips/privacy).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PP = require(ReplicatedStorage.Shared.Util.ProfileProjection)

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

local function view(id: string, opts: any?)
	opts = opts or {}
	return {
		itemId = id,
		name = id,
		rarity = opts.rarity or "Common",
		imageId = "",
		estValue = opts.estValue or 1,
		circulating = opts.circulating or 1,
	}
end

return {
	name = "Profile",
	tests = {
		["earned source: trade + board count; debug/refund/starter do not"] = function()
			eq(PP.isEarnedSource("trade"), true, "trade")
			eq(PP.isEarnedSource("board"), true, "board")
			eq(PP.isEarnedSource("debug"), false, "debug")
			eq(PP.isEarnedSource("refund"), false, "refund")
			eq(PP.isEarnedSource("starter"), false, "starter")
		end,

		["defaultShowcase: scarcest (fewest circulating) first, capped"] = function()
			local circ = { a = 50, b = 10, c = 30, d = 5 }
			local resolve = function(id)
				if not circ[id] then
					return nil
				end
				return view(id, { circulating = circ[id] })
			end
			local sc = PP.defaultShowcase({ a = 1, b = 2, c = 1, d = 9 }, resolve, 3)
			eq(#sc, 3, "cap")
			eq(sc[1], "d", "5 circ scarcest")
			eq(sc[2], "b", "10 circ next")
			eq(sc[3], "c", "30 circ third")
		end,

		["resolveShowcase: drops items no longer owned or unresolvable"] = function()
			local resolve = function(id)
				if id == "gone" then
					return nil
				end
				return view(id)
			end
			local out = PP.resolveShowcase({ "keep", "sold", "gone" }, { keep = 1, sold = 0 }, resolve)
			eq(#out, 1, "only keep survives")
			eq(out[1].itemId, "keep")
		end,

		["portfolioValue: sum of estValue * count over owned"] = function()
			local resolve = function(id)
				return view(id, { estValue = ({ x = 10, y = 3 })[id] or 0 })
			end
			eq(PP.portfolioValue({ x = 2, y = 4 }, resolve), 10 * 2 + 3 * 4)
		end,

		["resolveChip: mythicals counts Mythical AND the tiers above it"] = function()
			-- Godly and Celestial were added ABOVE Mythical; a chip that counted
			-- only exact-"Mythical" quietly ignored a player's rarest items.
			local RARITY = { m = "Mythical", g = "Godly", cel = "Celestial", c = "Common", r = "Rare" }
			local resolve = function(id)
				return view(id, { rarity = RARITY[id] or "Common" })
			end
			local ctx = {
				inventory = { m = 3, g = 1, cel = 1, c = 1, r = 2 },
				resolve = resolve, gems = 0, lifetime = { gemsEarned = 0, trades = 0 }, firstJoin = 0, now = 0,
			}
			eq(PP.resolveChip("mythicals", ctx).value, 3, "Mythical + Godly + Celestial")
			eq(PP.resolveChip("celestials", ctx).value, 1, "Celestial only")
			-- an owned-but-zero entry must never count toward either
			ctx.inventory.cel = 0
			eq(PP.resolveChip("celestials", ctx).value, 0, "zero-count isn't owned")
		end,

		["resolveChip: crafted + referrals reflect the newer systems"] = function()
			local resolve = function(id)
				return view(id)
			end
			local ctx = {
				inventory = { evt_grail = 1, evt_essence = 4, itm_1_1_stone = 9 },
				resolve = resolve, gems = 0, lifetime = { gemsEarned = 0, trades = 0 },
				referrals = 3, firstJoin = 0, now = 0,
			}
			eq(PP.resolveChip("crafted", ctx).value, 2, "distinct evt_ items only")
			eq(PP.resolveChip("referrals", ctx).value, 3, "friends invited")
			-- referrals must default rather than error when absent
			ctx.referrals = nil
			eq(PP.resolveChip("referrals", ctx).value, 0, "defaults to zero")
		end,

		["project: hideValue drops aggregate AND portfolioValue chip"] = function()
			local resolve = function(id)
				return view(id, { estValue = 5 })
			end
			local pub = PP.project({
				userId = 1, name = "n", displayName = "d", firstJoin = 0, now = 100,
				inventory = { a = 1 }, gems = 7,
				showcase = {}, statChips = { "portfolioValue", "gems" }, status = "hi",
				privacy = { hideValue = true, hideShowcase = false },
				lifetime = { gemsEarned = 0, trades = 0 }, resolve = resolve,
			})
			eq(pub.portfolioValue, nil, "aggregate hidden")
			local hasPv = false
			for _, c in pub.statChips do
				if c.key == "portfolioValue" then
					hasPv = true
				end
			end
			eq(hasPv, false, "portfolioValue chip dropped")
			eq(pub.showcase ~= nil, true, "showcase still present")
		end,

		["project: hideShowcase omits showcase, keeps value"] = function()
			local resolve = function(id)
				return view(id, { estValue = 5 })
			end
			local pub = PP.project({
				userId = 1, name = "n", displayName = "d", firstJoin = 0, now = 100,
				inventory = { a = 1 }, gems = 0,
				showcase = {}, statChips = {}, status = "",
				privacy = { hideValue = false, hideShowcase = true },
				lifetime = { gemsEarned = 0, trades = 0 }, resolve = resolve,
			})
			eq(pub.showcase, nil, "showcase omitted")
			eq(pub.portfolioValue, 5, "value present")
		end,

		["resolveChip: accountAge removed, unknown keys resolve to nil"] = function()
			local resolve = function(_)
				return nil
			end
			local ctx = { inventory = {}, resolve = resolve, gems = 0, lifetime = { gemsEarned = 0, trades = 0 }, firstJoin = 0, now = 100 }
			eq(PP.resolveChip("accountAge", ctx), nil, "accountAge no longer a stat")
			eq(PP.resolveChip("nonsense", ctx), nil, "unknown key")
		end,

		["project: default chips cap at 3 (portfolioValue/trades/mythicals)"] = function()
			local resolve = function(id)
				return view(id, { estValue = 1 })
			end
			local pub = PP.project({
				userId = 1, name = "n", displayName = "d", firstJoin = 0, now = 0,
				inventory = {}, gems = 0, showcase = {}, statChips = {},
				status = "", privacy = { hideValue = false, hideShowcase = false },
				lifetime = { gemsEarned = 0, trades = 0 }, resolve = resolve,
			})
			eq(#pub.statChips, 3, "default chip count")
			eq(pub.statChips[1].key, "portfolioValue")
			eq(pub.statChips[2].key, "trades")
			eq(pub.statChips[3].key, "mythicals")
		end,

		["project: empty inventory yields empty showcase + zero value"] = function()
			local resolve = function(_)
				return nil
			end
			local pub = PP.project({
				userId = 1, name = "n", displayName = "d", firstJoin = 0, now = 0,
				inventory = {}, gems = 0, showcase = {}, statChips = { "portfolioValue" },
				status = "", privacy = { hideValue = false, hideShowcase = false },
				lifetime = { gemsEarned = 0, trades = 0 }, resolve = resolve,
			})
			eq(pub.portfolioValue, 0, "zero value")
			eq(#pub.showcase, 0, "empty showcase")
		end,
	},
}
