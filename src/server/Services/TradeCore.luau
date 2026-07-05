--!strict
-- TradeCore: PURE trade state machine. No IO, no services, no Instances —
-- every transition is (record, args, now) -> (newRecord?, err?). TradeService
-- runs these inside MemoryStore UpdateAsync transforms; tests run them raw.
--
-- States: Invited -> Opened -> Confirmed -> Settling -> Settled
--                     any pre-Settling state -> Aborted
--
-- Invariants enforced here:
--   * any offer change resets BOTH confirms (kills last-second swaps)
--   * confirm only in Opened; settlement gate = both confirmed IN THE RECORD
--   * deposits only in Confirmed; Settling only when both deposited
--   * credits only in Settling; Settled only when both credited
--   * no abort from Settling/Settled (settlement is idempotent + must finish)

local TradeCore = {}

export type Side = {
	userId: number,
	offer: { items: { [string]: number }, gems: number },
	confirmed: boolean,
	deposited: boolean,
	credited: boolean,
	refunded: boolean,
}

local function emptyOffer()
	return { items = {}, gems = 0 }
end

local function newSide(userId: number): Side
	return {
		userId = userId,
		offer = emptyOffer(),
		confirmed = false,
		deposited = false,
		credited = false,
		refunded = false,
	}
end

function TradeCore.newRecord(tradeId: string, aUserId: number, bUserId: number, now: number, inviteTimeout: number)
	return {
		tradeId = tradeId,
		state = "Invited",
		v = 1,
		a = newSide(aUserId),
		b = newSide(bUserId),
		createdAt = now,
		touchedAt = now,
		expiresAt = now + inviteTimeout,
		settlementId = nil,
		settledBy = nil,
		abortReason = nil,
	}
end

function TradeCore.sideKeyOf(record: any, userId: number): string?
	if record.a.userId == userId then
		return "a"
	elseif record.b.userId == userId then
		return "b"
	end
	return nil
end

local function otherKey(key: string): string
	return key == "a" and "b" or "a"
end
TradeCore.otherKey = otherKey

local function touch(record: any, now: number)
	record.v += 1
	record.touchedAt = now
end

--------------------------------------------------------------------------------
-- Transitions (mutate the passed record copy; return record or nil+err)
--------------------------------------------------------------------------------

-- B accepts the invite.
function TradeCore.accept(record: any, byUserId: number, now: number, idleTimeout: number): (any?, string?)
	if record.state ~= "Invited" then
		return nil, "bad_state"
	end
	if record.b.userId ~= byUserId then
		return nil, "not_invitee"
	end
	record.state = "Opened"
	record.expiresAt = now + idleTimeout
	touch(record, now)
	return record, nil
end

-- Replace a side's offer. Resets both confirms.
function TradeCore.setOffer(record: any, byUserId: number, offer: any, now: number, idleTimeout: number): (any?, string?)
	if record.state ~= "Opened" then
		return nil, "bad_state"
	end
	local key = TradeCore.sideKeyOf(record, byUserId)
	if key == nil then
		return nil, "not_participant"
	end
	record[key].offer = offer
	record.a.confirmed = false
	record.b.confirmed = false
	record.expiresAt = now + idleTimeout
	touch(record, now)
	return record, nil
end

-- Set/unset confirm. When both sides are confirmed the record advances to
-- Confirmed — the ONLY path there, and it happens atomically with the second
-- confirm inside the same transform.
-- UNACCEPT is also legal during the Confirmed grace window (deposits haven't
-- started): it drops the trade back to Opened, keeping the other side's
-- accept. The grace re-drive sees state ~= Confirmed and stands down.
function TradeCore.setConfirm(record: any, byUserId: number, confirmed: boolean, now: number): (any?, string?)
	local key = TradeCore.sideKeyOf(record, byUserId)
	if key == nil then
		return nil, "not_participant"
	end

	if record.state == "Confirmed" then
		if confirmed then
			return nil, "bad_state" -- already fully accepted
		end
		if record.a.deposited or record.b.deposited then
			return nil, "too_late" -- escrow already started; countdown is over
		end
		record[key].confirmed = false
		record.state = "Opened"
		record.confirmedAt = nil
		record.settlementId = nil
		touch(record, now)
		return record, nil
	end

	if record.state ~= "Opened" then
		return nil, "bad_state"
	end
	record[key].confirmed = confirmed
	if record.a.confirmed and record.b.confirmed then
		record.state = "Confirmed"
		-- round-scoped ids: an escrow refunded after an unaccept can never
		-- alias a later confirm round's deposit/settle idempotency keys
		record.round = (record.round or 0) + 1
		record.settlementId = ("settle_%s_r%d"):format(record.tradeId, record.round)
		record.confirmedAt = now -- grace countdown anchor (settlement waits)
	end
	touch(record, now)
	return record, nil
end

-- Mark a side's escrow deposit complete. Both deposited -> Settling.
function TradeCore.markDeposited(record: any, userId: number, now: number): (any?, string?)
	if record.state ~= "Confirmed" and record.state ~= "Settling" then
		return nil, "bad_state"
	end
	local key = TradeCore.sideKeyOf(record, userId)
	if key == nil then
		return nil, "not_participant"
	end
	if record[key].deposited then
		return nil, "already_deposited" -- idempotent no-op signal
	end
	record[key].deposited = true
	if record.a.deposited and record.b.deposited then
		record.state = "Settling"
	end
	touch(record, now)
	return record, nil
end

-- Mark a side credited (they received the counterparty's goods).
-- settledBy stamps the server whose commit completed the trade — that server
-- (and only that server) runs the economy updates.
function TradeCore.markCredited(record: any, userId: number, now: number, by: string): (any?, string?)
	if record.state ~= "Settling" then
		return nil, "bad_state"
	end
	local key = TradeCore.sideKeyOf(record, userId)
	if key == nil then
		return nil, "not_participant"
	end
	if record[key].credited then
		return nil, "already_credited"
	end
	record[key].credited = true
	if record.a.credited and record.b.credited then
		record.state = "Settled"
		record.settledBy = by
	end
	touch(record, now)
	return record, nil
end

-- Abort. Legal from Invited/Opened/Confirmed only. Refund bookkeeping is the
-- caller's job (sides with deposited=true and refunded=false need refunds).
function TradeCore.abort(record: any, reason: string, now: number): (any?, string?)
	if record.state == "Settling" or record.state == "Settled" or record.state == "Aborted" then
		return nil, "bad_state"
	end
	record.state = "Aborted"
	record.abortReason = reason
	touch(record, now)
	return record, nil
end

function TradeCore.markRefunded(record: any, userId: number, now: number): (any?, string?)
	if record.state ~= "Aborted" then
		return nil, "bad_state"
	end
	local key = TradeCore.sideKeyOf(record, userId)
	if key == nil then
		return nil, "not_participant"
	end
	if record[key].refunded then
		return nil, "already_refunded"
	end
	record[key].refunded = true
	touch(record, now)
	return record, nil
end

--------------------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------------------

function TradeCore.isExpired(record: any, now: number): boolean
	return (record.state == "Invited" or record.state == "Opened") and now > record.expiresAt
end

function TradeCore.isTerminal(record: any): boolean
	return record.state == "Settled" or record.state == "Aborted"
end

-- Sanitized per-player view (never leaks the other side's internals beyond
-- what the UI needs).
function TradeCore.viewFor(record: any, userId: number, otherName: string?): any?
	local key = TradeCore.sideKeyOf(record, userId)
	if key == nil then
		return nil
	end
	local me = record[key]
	local them = record[otherKey(key)]
	return {
		tradeId = record.tradeId,
		state = record.state,
		v = record.v,
		expiresAt = record.expiresAt,
		confirmedAt = record.confirmedAt,
		abortReason = record.abortReason,
		you = {
			offer = me.offer,
			confirmed = me.confirmed,
		},
		them = {
			userId = them.userId,
			name = otherName,
			offer = them.offer,
			confirmed = them.confirmed,
		},
	}
end

return TradeCore
