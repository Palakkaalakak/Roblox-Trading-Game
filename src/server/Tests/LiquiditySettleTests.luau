--!strict
-- Integration tests for TradeBoardService.settleChain — the N-party settlement.
--
-- Uses BOTS as the participants: their inventories are plain in-memory state,
-- so a test can seed them and assert on them without going near a real player
-- profile. Settlement itself takes the identical path either way (actorDelta
-- dispatches on the sign of the userId), so this exercises the real code.
--
-- Services only exist in Play mode, so every case here no-ops in Edit.

local TradeBoardService = require(script.Parent.Parent.Services.TradeBoardService)
local BotService = require(script.Parent.Parent.Services.BotService)
local EconomyService = require(script.Parent.Parent.Services.EconomyService)

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

-- A silent early-return reads as a PASS, which is how four empty tests once
-- looked green. Announce every skip loudly instead.
local function skip(reason: string)
	warn("[Tests] SKIPPED (LiquiditySettle): " .. reason)
end

-- Two distinct registered items, or nil when the registry is empty (Edit mode).
local function twoItems(): (string?, string?)
	local first, second = nil, nil
	for itemId in EconomyService.allItems() do
		if first == nil then
			first = itemId
		elseif second == nil then
			second = itemId
			break
		end
	end
	return first, second
end

local seq = 0
local function nextOp(): string
	seq += 1
	return ("t%d_%d"):format(os.time() % 100000, seq)
end

-- Give a bot a clean, known holding of one item.
local function seedBot(botId: number, itemId: string, count: number): boolean
	local ok = BotService.credit(botId, { [itemId] = count }, 0, "seed_" .. nextOp())
	return ok == true or ok == nil
end

local function holds(botId: number, itemId: string, count: number): boolean
	return BotService.canAfford(botId, { items = { [itemId] = count }, gems = 0 }) == true
end

-- A settlement leg: this poster hands over `take` and receives `give`.
local function leg(listingId: string, posterId: number, takeItem: string, giveItem: string): any
	return {
		listingId = listingId,
		posterId = posterId,
		takeItems = { [takeItem] = 1 },
		takeGems = 0,
		giveItems = { [giveItem] = 1 },
		giveGems = 0,
		units = 1,
	}
end

return {
	name = "LiquiditySettle",
	tests = {
		-- Guards: these must hold regardless of mode, and cost nothing.
		["settleChain rejects malformed input"] = function()
			local ok = TradeBoardService.settleChain("op", {})
			eq(ok, false, "a chain needs at least two legs")

			local dup = {
				leg("l1", -101, "a", "b"),
				leg("l2", -101, "b", "a"), -- same posterId twice
			}
			local ok2, err = TradeBoardService.settleChain(nextOp(), dup)
			eq(ok2, false, "self-dealing refused at the settlement boundary")
			eq(err, "self_deal", "and named as such")
		end,

		-- A take that fails must leave EVERY participant exactly as they were.
		-- This is the invariant that matters most: the bot may never end up
		-- holding goods, and no poster may be left debited.
		["failed take hands back everything already taken"] = function()
			local itemA, itemB = twoItems()
			if itemA == nil or itemB == nil then
				skip("registry empty (Edit mode?)")
				return
			end
			local a, b = -101, -102
			if not (seedBot(a, itemA, 1) and seedBot(b, itemB, 1)) then
				skip("bot ledger unavailable")
				return
			end
			truthy(holds(a, itemA, 1), "bot a seeded")

			-- b is drained AFTER seeding, so its take will fail partway through.
			BotService.applyDelta(b, { items = { [itemB] = -1 }, gems = 0 }, "test", "drain_" .. nextOp())
			eq(holds(b, itemB, 1), false, "bot b can no longer cover its promise")

			local legs = {
				leg("__test_missing_a", a, itemA, itemB),
				leg("__test_missing_b", b, itemB, itemA),
			}
			local ok = TradeBoardService.settleChain(nextOp(), legs)
			eq(ok, false, "settlement aborts")

			-- a's goods were either never taken or handed straight back.
			truthy(holds(a, itemA, 1), "bot a is whole again")
			-- and nothing was delivered: a must NOT have received b's item.
			eq(holds(a, itemB, 1), false, "no delivery happened on an aborted chain")
		end,

		-- Crash between TAKE and DELIVER is the one scenario that could strand
		-- goods. Recovery must finish the job; deliveries are keyed by claimId
		-- so replaying them is safe.
		["recovery completes an op that died after taking"] = function()
			local itemA = (twoItems())
			if itemA == nil then
				skip("registry empty (Edit mode?)")
				return
			end
			local a = -103
			if not seedBot(a, itemA, 0) then
				skip("bot ledger unavailable")
				return
			end
			local before = holds(a, itemA, 1)

			-- Stand in for a crashed op: a journal entry mid-delivery.
			local opId = nextOp()
			local rec = {
				opId = opId,
				phase = "delivering",
				legs = {
					{
						listingId = "__test_recover",
						posterId = a,
						takeItems = {},
						takeGems = 0,
						giveItems = { [itemA] = 1 },
						giveGems = 0,
						units = 1,
					},
				},
				taken = { __test_recover = true },
			}
			TradeBoardService.__testJournalPut(opId, rec)

			local handled = TradeBoardService.recoverLiquidityJournal()
			truthy(handled >= 1, "the interrupted op was picked up")
			if not before then
				truthy(holds(a, itemA, 1), "the owed delivery landed on recovery")
			end

			-- Replaying is idempotent: a second pass must not pay twice.
			TradeBoardService.__testJournalPut(opId, rec)
			TradeBoardService.recoverLiquidityJournal()
			eq(holds(a, itemA, 2), false, "recovery never double-pays")
		end,

		-- A journal entry that died BEFORE delivering must return what it took
		-- rather than completing.
		["recovery returns takes for an op that died while taking"] = function()
			local itemA = (twoItems())
			if itemA == nil then
				skip("registry empty (Edit mode?)")
				return
			end
			local a = -104
			if not seedBot(a, itemA, 0) then
				skip("bot ledger unavailable")
				return
			end

			local opId = nextOp()
			TradeBoardService.__testJournalPut(opId, {
				opId = opId,
				phase = "taking",
				legs = {
					{
						listingId = "__test_undo",
						posterId = a,
						takeItems = { [itemA] = 1 }, -- what was taken, to be returned
						takeGems = 0,
						giveItems = {},
						giveGems = 0,
						units = 1,
					},
				},
				taken = { __test_undo = true },
			})

			local had = holds(a, itemA, 1)
			TradeBoardService.recoverLiquidityJournal()
			if not had then
				truthy(holds(a, itemA, 1), "what was taken came back")
			end
		end,
	},
}
