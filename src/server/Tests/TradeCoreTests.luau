--!strict
-- Unit tests: TradeCore pure state machine — the anti-scam invariants.

local TradeCore = require(script.Parent.Parent.Services.TradeCore)

local A, B, STRANGER = 111, 222, 999
local T0 = 1000

local function freshOpened(): any
	local r = TradeCore.newRecord("trade_test_1", A, B, T0, 60)
	local accepted = TradeCore.accept(r, B, T0 + 1, 300)
	assert(accepted, "accept failed")
	return accepted
end

local function offer(items: { [string]: number }, gems: number): any
	return { items = items, gems = gems }
end

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

return {
	name = "TradeCore",
	tests = {
		["happy path: invite to settled"] = function()
			local r = TradeCore.newRecord("t1", A, B, T0, 60)
			eq(r.state, "Invited")

			r = TradeCore.accept(r, B, T0 + 1, 300) :: any
			eq(r.state, "Opened")

			r = TradeCore.setOffer(r, A, offer({ itm_x = 1 }, 0), T0 + 2, 300) :: any
			r = TradeCore.setOffer(r, B, offer({}, 50), T0 + 3, 300) :: any
			eq(r.state, "Opened")

			r = TradeCore.setConfirm(r, A, true, T0 + 4) :: any
			eq(r.state, "Opened", "one confirm must not advance")
			r = TradeCore.setConfirm(r, B, true, T0 + 5) :: any
			eq(r.state, "Confirmed", "both confirms must advance")
			assert(r.settlementId == "settle_t1_r1", "deterministic settlement id")

			r = TradeCore.markDeposited(r, A, T0 + 6) :: any
			eq(r.state, "Confirmed")
			r = TradeCore.markDeposited(r, B, T0 + 7) :: any
			eq(r.state, "Settling", "both deposits -> Settling")

			r = TradeCore.markCredited(r, A, T0 + 8, "server1") :: any
			eq(r.state, "Settling")
			r = TradeCore.markCredited(r, B, T0 + 9, "server2") :: any
			eq(r.state, "Settled")
			eq(r.settledBy, "server2", "completer stamps settledBy")
		end,

		["offer edit resets BOTH confirms"] = function()
			local r = freshOpened()
			r = TradeCore.setOffer(r, A, offer({ itm_x = 1 }, 0), T0 + 2, 300) :: any
			r = TradeCore.setConfirm(r, A, true, T0 + 3) :: any
			r = TradeCore.setConfirm(r, B, false, T0 + 4) :: any
			assert(r.a.confirmed, "A should be confirmed")

			-- B swaps the offer at the last second
			r = TradeCore.setOffer(r, B, offer({}, 1), T0 + 5, 300) :: any
			assert(not r.a.confirmed, "A confirm must reset on B's edit")
			assert(not r.b.confirmed, "B confirm must reset on B's edit")
			eq(r.state, "Opened")
		end,

		["non-participant rejected everywhere"] = function()
			local r = freshOpened()
			local _, err = TradeCore.setOffer(r, STRANGER, offer({}, 1), T0 + 2, 300)
			eq(err, "not_participant")
			_, err = TradeCore.setConfirm(r, STRANGER, true, T0 + 2)
			eq(err, "not_participant")
			_, err = TradeCore.markDeposited(r, STRANGER, T0 + 2)
			eq(err, "bad_state") -- not even in a depositable state
		end,

		["wrong-state transitions rejected"] = function()
			local r = TradeCore.newRecord("t2", A, B, T0, 60)
			-- confirm before accept
			local _, err = TradeCore.setConfirm(r, A, true, T0 + 1)
			eq(err, "bad_state")
			-- accept by the wrong side
			_, err = TradeCore.accept(r, A, T0 + 1, 300)
			eq(err, "not_invitee")
			-- deposit before both confirmed
			local opened = TradeCore.accept(r, B, T0 + 1, 300) :: any
			_, err = TradeCore.markDeposited(opened, A, T0 + 2)
			eq(err, "bad_state")
		end,

		["no abort from Settling or Settled"] = function()
			local r = freshOpened()
			r = TradeCore.setOffer(r, A, offer({ itm_x = 1 }, 0), T0 + 2, 300) :: any
			r = TradeCore.setConfirm(r, A, true, T0 + 3) :: any
			r = TradeCore.setConfirm(r, B, true, T0 + 4) :: any
			r = TradeCore.markDeposited(r, A, T0 + 5) :: any
			r = TradeCore.markDeposited(r, B, T0 + 6) :: any
			eq(r.state, "Settling")

			local _, err = TradeCore.abort(r, "nope", T0 + 7)
			eq(err, "bad_state", "abort from Settling must fail")

			r = TradeCore.markCredited(r, A, T0 + 8, "s") :: any
			r = TradeCore.markCredited(r, B, T0 + 9, "s") :: any
			_, err = TradeCore.abort(r, "nope", T0 + 10)
			eq(err, "bad_state", "abort from Settled must fail")
		end,

		["abort + refund bookkeeping idempotent"] = function()
			local r = freshOpened()
			r = TradeCore.setOffer(r, A, offer({ itm_x = 2 }, 10), T0 + 2, 300) :: any
			r = TradeCore.setConfirm(r, A, true, T0 + 3) :: any
			r = TradeCore.setConfirm(r, B, true, T0 + 4) :: any
			r = TradeCore.markDeposited(r, A, T0 + 5) :: any -- only A escrowed

			r = TradeCore.abort(r, "player_left", T0 + 6) :: any
			eq(r.state, "Aborted")

			r = TradeCore.markRefunded(r, A, T0 + 7) :: any
			assert(r.a.refunded)
			local _, err = TradeCore.markRefunded(r, A, T0 + 8)
			eq(err, "already_refunded", "double refund must be rejected")
		end,

		["deposit/credit idempotency signals"] = function()
			local r = freshOpened()
			r = TradeCore.setOffer(r, A, offer({ itm_x = 1 }, 0), T0 + 2, 300) :: any
			r = TradeCore.setConfirm(r, A, true, T0 + 3) :: any
			r = TradeCore.setConfirm(r, B, true, T0 + 4) :: any
			r = TradeCore.markDeposited(r, A, T0 + 5) :: any
			local _, err = TradeCore.markDeposited(r, A, T0 + 6)
			eq(err, "already_deposited")
		end,

		["unaccept during grace reverts to Opened, round scopes ids"] = function()
			local r = freshOpened()
			r = TradeCore.setOffer(r, A, offer({ itm_x = 1 }, 0), T0 + 2, 300) :: any
			r = TradeCore.setConfirm(r, A, true, T0 + 3) :: any
			r = TradeCore.setConfirm(r, B, true, T0 + 4) :: any
			eq(r.state, "Confirmed")
			eq(r.round, 1)
			assert(r.confirmedAt == T0 + 4, "confirmedAt stamped")

			-- A bails during the countdown
			r = TradeCore.setConfirm(r, A, false, T0 + 5) :: any
			eq(r.state, "Opened", "unaccept must revert to Opened")
			eq(r.confirmedAt, nil)
			eq(r.settlementId, nil)
			assert(r.b.confirmed, "other side's accept survives")

			-- both accept again: new round, new settlement id
			r = TradeCore.setConfirm(r, A, true, T0 + 6) :: any
			eq(r.state, "Confirmed")
			eq(r.round, 2)
			eq(r.settlementId, "settle_" .. r.tradeId .. "_r2")

			-- once a deposit lands, unaccept is too late
			r = TradeCore.markDeposited(r, A, T0 + 7) :: any
			local _, err = TradeCore.setConfirm(r, B, false, T0 + 8)
			eq(err, "too_late")
		end,

		["expiry only in Invited/Opened"] = function()
			local r = TradeCore.newRecord("t3", A, B, T0, 60)
			assert(TradeCore.isExpired(r, T0 + 61), "invite should expire")
			assert(not TradeCore.isExpired(r, T0 + 59))
		end,

		["client view hides internals"] = function()
			local r = freshOpened()
			r = TradeCore.setOffer(r, A, offer({ itm_x = 1 }, 5), T0 + 2, 300) :: any
			local view = TradeCore.viewFor(r, A, "Bob") :: any
			eq(view.them.userId, B)
			eq(view.them.name, "Bob")
			assert(view.them.offer ~= nil)
			assert(view.them.deposited == nil, "deposited must not leak to client view")
			assert(view.them.refunded == nil, "refunded must not leak")
			eq(TradeCore.viewFor(r, STRANGER), nil)
		end,
	},
}
