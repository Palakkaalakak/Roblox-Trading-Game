--!strict
-- TradeService: full trade lifecycle — invite/accept, offers, simultaneous
-- confirm, escrow deposit, two-phase settlement, refunds, timeouts,
-- disconnects. Cross-server by construction: the authoritative TradeRecord
-- lives in a MemoryStore map; every transition is a TradeCore pure function
-- executed inside UpdateAsync (CAS); servers coordinate via invalidation
-- pings. Co-located players are just the fast case of the same path.
--
-- Delivery/refund idempotency: deterministic claim ids
--   deposit_<tradeId>_<userId> / settle_<tradeId>_<userId> / refund_<tradeId>_<userId>
-- guarded by profile.ClaimedIds (online apply) and mailbox claimId dedupe
-- (offline apply). Racing servers can both attempt delivery; exactly one
-- credit lands.
--
-- KNOWN ACCEPTED RISK (documented in plan): a server crash in the tiny window
-- between a durable escrow save and the markDeposited CAS can strand a
-- deposit. Logged loudly; journal-based recovery is a future-phase hardening.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Enums)
local TradeConfig = require(ReplicatedStorage.Shared.Config.TradeConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)
local Tax = require(ReplicatedStorage.Shared.Util.Tax)

local Net = require(script.Parent.Parent.Net)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local TradeCore = require(script.Parent.TradeCore)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimitService = require(script.Parent.RateLimitService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local TradeService = {}

local tradeMap: any -- MemoryStore map "Trades_v1": tradeId -> TradeRecord
local userToTrade: { [number]: string } = {} -- local players only
local activeTradeIds: { [string]: boolean } = {} -- trades this server sweeps
local nameCache: { [number]: string } = {}

local ownerId = game.JobId ~= "" and game.JobId or "studio-" .. tostring(math.floor(os.clock() * 1000))

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.Name
		return player.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("User " .. tostring(userId))
	return nameCache[userId]
end

local function fetch(tradeId: string): any?
	local record
	pcall(function()
		record = tradeMap:GetAsync(tradeId)
	end)
	return record
end

-- Run a TradeCore transition atomically. Returns (committedRecord?, err?).
local function mutate(tradeId: string, fn: (record: any) -> (any?, string?)): (any?, string?)
	local errOut: string? = nil
	local result
	local ok = pcall(function()
		result = tradeMap:UpdateAsync(tradeId, function(old)
			if old == nil then
				errOut = "not_found"
				return nil
			end
			local new, err = fn(old)
			if new == nil then
				errOut = err
				return nil
			end
			errOut = nil
			return new
		end)
	end)
	if not ok then
		return nil, "store_error"
	end
	if result == nil then
		return nil, errOut or "cas_aborted"
	end
	return result, nil
end

local function negate(offer: any): any
	local items = {}
	for itemId, count in offer.items do
		items[itemId] = -count
	end
	return { items = items, gems = -offer.gems }
end

local function offerIsEmpty(offer: any): boolean
	if offer.gems > 0 then
		return false
	end
	for _ in offer.items do
		return false
	end
	return true
end

local function track(record: any)
	activeTradeIds[record.tradeId] = true
	for _, key in { "a", "b" } do
		local player = Players:GetPlayerByUserId(record[key].userId)
		if player and (record.state ~= "Invited" or key == "a") then
			-- invitee isn't bound to the trade until accept
			userToTrade[record[key].userId] = record.tradeId
		end
	end
end

local function untrack(record: any)
	activeTradeIds[record.tradeId] = nil
	for _, key in { "a", "b" } do
		if userToTrade[record[key].userId] == record.tradeId then
			userToTrade[record[key].userId] = nil
		end
	end
end

local function notifyLocal(record: any)
	for _, key in { "a", "b" } do
		local side = record[key]
		local player = Players:GetPlayerByUserId(side.userId)
		if player then
			local view = TradeCore.viewFor(record, side.userId, nameOf(record[TradeCore.otherKey(key)].userId))
			Net.fireClient("TradeStateChanged", player, view)
		end
	end
end

local function publishPing(tradeId: string)
	-- `from` lets us ignore our own MessagingService echo (live mode delivers
	-- publishes back to the sender, which double-drove settlement)
	StoreAdapters.publish(EconomyConfig.TradeBroadcastTopic, { tradeId = tradeId, from = ownerId })
end

-- Trade-path saves are fire-and-forget: profile mutations are already applied
-- in-memory (autosave + release cover durability). Synchronous DataStore
-- writes here were what made accepts feel seconds-slow.
local function saveAsync(player: Player)
	task.spawn(function()
		DataService.saveNow(player)
	end)
end

--------------------------------------------------------------------------------
-- Refunds + abort
--------------------------------------------------------------------------------

-- Claim ids are scoped to the confirm round so escrow refunded after an
-- unaccept can never alias a later round's keys.
local function claimIdFor(kind: string, record: any, userId: number, round: number?): string
	return ("%s_%s_r%d_%d"):format(kind, record.tradeId, round or record.round or 1, userId)
end

-- Return escrowed goods to a side. Local player -> direct apply; otherwise
-- mailbox. Idempotent via deterministic claimId on both paths.
local function refundSide(record: any, key: string)
	local side = record[key]
	if not side.deposited or side.refunded then
		return
	end
	local claimId = claimIdFor("refund", record, side.userId)
	local player = Players:GetPlayerByUserId(side.userId)
	local delivered = false

	if player and DataService.isLoaded(player) then
		local ok = InventoryService.applyDelta(
			player,
			{ items = side.offer.items, gems = side.offer.gems },
			Enums.GrantSource.Refund,
			claimId
		)
		if ok then
			saveAsync(player)
			delivered = true
		end
	end
	if not delivered then
		delivered = DataService.mailboxAppend(side.userId, {
			claimId = claimId,
			items = side.offer.items,
			gems = side.offer.gems,
			source = Enums.GrantSource.Refund,
			fromTradeId = record.tradeId,
			createdAt = os.time(),
		})
	end
	if delivered then
		mutate(record.tradeId, function(r)
			return TradeCore.markRefunded(r, side.userId, os.time())
		end)
	end
end

local function handleAborted(record: any)
	refundSide(record, "a")
	refundSide(record, "b")
	for _, key in { "a", "b" } do
		local player = Players:GetPlayerByUserId(record[key].userId)
		if player then
			Net.fireClient("TradeAborted", player, record.tradeId, record.abortReason or "aborted")
		end
	end
	untrack(record)
end

local function abortTrade(tradeId: string, reason: string)
	local record, err = mutate(tradeId, function(r)
		return TradeCore.abort(r, reason, os.time())
	end)
	if record then
		AnalyticsService.log("trade_aborted", { tradeId = tradeId, reason = reason })
		handleAborted(record)
		notifyLocal(record)
		publishPing(tradeId)
	elseif err == "bad_state" then
		-- already terminal or settling; if aborted, make sure refunds ran
		local current = fetch(tradeId)
		if current and current.state == "Aborted" then
			handleAborted(current)
		end
	end
end

--------------------------------------------------------------------------------
-- Settlement engine
--------------------------------------------------------------------------------

-- Economy updates, run exactly once (by the server whose CAS completed the
-- trade). RAP: gems are the numeraire; each item copy's imputed price is the
-- counterparty's total offer value distributed pro-rata by this side's item
-- values. Demand bumps ride along inside recordTradePrice.
local function applyEconomyUpdates(record: any)
	local touched: { string } = {}
	for _, key in { "a", "b" } do
		local side = record[key]
		local other = record[TradeCore.otherKey(key)]

		local sideItemsValue = 0
		local values: { [string]: number } = {}
		for itemId, count in side.offer.items do
			local v = EconomyService.valueOf(itemId)
			values[itemId] = v
			sideItemsValue += v * count
		end
		local sideTotal = sideItemsValue + side.offer.gems
		local counterpartyTotal = other.offer.gems
		for itemId, count in other.offer.items do
			counterpartyTotal += EconomyService.valueOf(itemId) * count
		end

		if sideTotal > 0 and counterpartyTotal > 0 then
			for itemId, count in side.offer.items do
				local imputed = counterpartyTotal * (values[itemId] / sideTotal)
				for _ = 1, math.min(count, TradeConfig.MaxCountPerSlot) do
					EconomyService.recordTradePrice(itemId, imputed)
				end
				table.insert(touched, itemId)
			end
		else
			-- gift (one side empty): no price signal, but interest is real
			for itemId in side.offer.items do
				EconomyService.bumpDemand(itemId, EconomyConfig.DemandBumpOnTrade, true)
				table.insert(touched, itemId)
			end
		end
	end
	if #touched > 0 then
		EconomyService.broadcastStats(touched)
	end
end

-- Credit one side with the counterparty's goods. Idempotent.
local function creditSide(record: any, key: string): boolean
	local side = record[key]
	if side.credited then
		return true
	end
	local goods = record[TradeCore.otherKey(key)].offer
	local netGems, taxCut = Tax.split(goods.gems) -- house cut on gem transfers
	local claimId = claimIdFor("settle", record, side.userId)
	local player = Players:GetPlayerByUserId(side.userId)
	local delivered = false

	if player and DataService.isLoaded(player) then
		local ok = InventoryService.applyDelta(
			player,
			{ items = goods.items, gems = netGems },
			Enums.GrantSource.Trade,
			claimId
		)
		if ok then
			saveAsync(player)
			Net.fireClient("TradeSettled", player, record.tradeId, goods.items, netGems)
			delivered = true
		end
	end
	if not delivered then
		delivered = DataService.mailboxAppend(side.userId, {
			claimId = claimId,
			items = goods.items,
			gems = netGems,
			source = Enums.GrantSource.Trade,
			fromTradeId = record.tradeId,
			createdAt = os.time(),
		})
	end
	if delivered and taxCut > 0 then
		AnalyticsService.log("gem_tax", { source = "trade", tradeId = record.tradeId, cut = taxCut })
	end
	return delivered
end

-- Escrow deposit for a LOCAL player. apply (idempotent) -> save -> CAS.
local function attemptDeposit(record: any, key: string)
	local side = record[key]
	if side.deposited then
		return
	end
	local player = Players:GetPlayerByUserId(side.userId)
	if player == nil or not DataService.isLoaded(player) then
		return -- their server (or the sweep after they rejoin) handles it
	end

	local round = record.round or 1
	local claimId = claimIdFor("deposit", record, side.userId, round)
	local ok, err = InventoryService.applyDelta(player, negate(side.offer), Enums.GrantSource.Trade, claimId)
	if not ok then
		AnalyticsService.log("deposit_failed", { tradeId = record.tradeId, userId = side.userId, err = err })
		abortTrade(record.tradeId, "deposit_failed")
		return
	end
	saveAsync(player)

	local committed, mErr = mutate(record.tradeId, function(r)
		if (r.round or 1) ~= round then
			return nil, "round_changed" -- unaccept+reaccept raced us
		end
		return TradeCore.markDeposited(r, side.userId, os.time())
	end)
	if committed then
		notifyLocal(committed)
		publishPing(record.tradeId)
	elseif mErr == "bad_state" or mErr == "round_changed" then
		-- trade aborted OR dropped back to Opened (unaccept during grace)
		-- while we escrowed: undo our escrow. Round-scoped claim id keeps
		-- this refund from ever colliding with a later round.
		local current = fetch(record.tradeId)
		if current == nil or current.state ~= "Settling" and current.state ~= "Settled" then
			InventoryService.applyDelta(
				player,
				{ items = side.offer.items, gems = side.offer.gems },
				Enums.GrantSource.Refund,
				claimIdFor("refund", record, side.userId, round)
			)
			saveAsync(player)
		end
	end
end

-- One driver at a time per trade on this server. Settlement used to run
-- concurrently (confirm handler + grace timer + our own ping echo), which
-- felt slow and double-fired notifications.
local driving: { [string]: boolean } = {}

local function progressInner(record: any)
	if record.state == "Confirmed" then
		-- PS99-style grace window: both accepted, but deposits wait a few
		-- seconds so either player can still cancel. Server-enforced.
		local graceEndsAt = (record.confirmedAt or 0) + TradeConfig.ConfirmGraceSeconds
		local remaining = graceEndsAt - os.time()
		if remaining > 0 then
			task.delay(remaining + 0.05, function()
				local fresh = fetch(record.tradeId)
				if fresh and fresh.state == "Confirmed" then
					TradeService.progress(fresh)
				end
			end)
			return
		end
		attemptDeposit(record, "a")
		attemptDeposit(record, "b")
		-- fall through to settlement in the SAME drive (no re-entry hop)
		record = fetch(record.tradeId) or record
	end

	if record.state == "Settling" then
		for _, key in { "a", "b" } do
			if not record[key].credited and creditSide(record, key) then
				local committed = mutate(record.tradeId, function(r)
					return TradeCore.markCredited(r, record[key].userId, os.time(), ownerId)
				end)
				if committed then
					record = committed
				end
			end
		end
		if record.state == "Settled" then
			notifyLocal(record)
			publishPing(record.tradeId)
			if record.settledBy == ownerId then
				applyEconomyUpdates(record)
				AnalyticsService.log("trade_settled", { tradeId = record.tradeId })
			end
			untrack(record)
		end
	elseif record.state == "Aborted" then
		handleAborted(record)
	elseif record.state == "Settled" then
		untrack(record)
	end
end

-- Drive a record forward from wherever it is. Idempotent + re-entrancy-safe.
function TradeService.progress(record: any)
	local id = record.tradeId
	if driving[id] then
		return
	end
	driving[id] = true
	local ok, err = pcall(progressInner, record)
	driving[id] = nil
	if not ok then
		warn("[Trade] progress failed for " .. id .. ": " .. tostring(err))
	end
end

--------------------------------------------------------------------------------
-- Remote handlers
--------------------------------------------------------------------------------

local function guardCommon(player: Player, op: string): (boolean, string?)
	if not TradeConfig.Enabled then
		return false, "trading_disabled"
	end
	if not RateLimitService.check(player, op) then
		return false, "rate_limited"
	end
	if not DataService.isLoaded(player) then
		return false, "loading"
	end
	return true, nil
end

local function handleRequestTrade(player: Player, targetUserId: any)
	local ok, err = guardCommon(player, "RequestTrade")
	if not ok then
		return { ok = false, err = err }
	end
	if not Guard.isUserId(targetUserId) then
		return { ok = false, err = "bad_target" }
	end
	if targetUserId == player.UserId then
		return { ok = false, err = "self_trade" }
	end
	if userToTrade[player.UserId] then
		return { ok = false, err = "already_in_trade" }
	end

	local tradeId = DataService.newId()
	local record = TradeCore.newRecord(tradeId, player.UserId, targetUserId, os.time(), TradeConfig.InviteTimeoutSeconds)
	local stored = pcall(function()
		tradeMap:SetAsync(tradeId, record)
	end)
	if not stored then
		return { ok = false, err = "store_error" }
	end

	userToTrade[player.UserId] = tradeId
	activeTradeIds[tradeId] = true
	AnalyticsService.log("trade_requested", { tradeId = tradeId, from = player.UserId, to = targetUserId })

	-- deliver invite: local fast path + cross-server ping
	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		Net.fireClient("TradeInvite", target, tradeId, player.UserId, player.Name)
	end
	publishPing(tradeId)
	return { ok = true, tradeId = tradeId }
end

local function handleRespond(player: Player, tradeId: any, accept: any)
	local ok, err = guardCommon(player, "RespondToRequest")
	if not ok then
		return { ok = false, err = err }
	end
	if not Guard.isTradeId(tradeId) or not Guard.isBool(accept) then
		return { ok = false, err = "bad_args" }
	end

	if not accept then
		local record = fetch(tradeId)
		if record and record.b.userId == player.UserId and record.state == "Invited" then
			abortTrade(tradeId, "declined")
		end
		return { ok = true }
	end

	if userToTrade[player.UserId] then
		return { ok = false, err = "already_in_trade" }
	end
	local committed, mErr = mutate(tradeId, function(r)
		return TradeCore.accept(r, player.UserId, os.time(), TradeConfig.TradeIdleTimeoutSeconds)
	end)
	if committed == nil then
		return { ok = false, err = mErr }
	end
	track(committed)
	notifyLocal(committed)
	publishPing(tradeId)
	AnalyticsService.log("trade_opened", { tradeId = tradeId })
	return { ok = true }
end

local function handleSetOffer(player: Player, tradeId: any, offer: any)
	local ok, err = guardCommon(player, "SetOffer")
	if not ok then
		return { ok = false, err = err }
	end
	if not Guard.isTradeId(tradeId) then
		return { ok = false, err = "bad_args" }
	end
	local shapeOk, shapeErr = Guard.checkOfferShape(offer)
	if not shapeOk then
		return { ok = false, err = shapeErr }
	end
	-- items must exist in the global registry
	for itemId in offer.items do
		if EconomyService.getItem(itemId) == nil then
			return { ok = false, err = "unknown_item" }
		end
	end
	-- ownership/sufficiency vs live server-side profile
	local afford, affordErr = InventoryService.canAfford(player, offer)
	if not afford then
		return { ok = false, err = affordErr }
	end

	local committed, mErr = mutate(tradeId, function(r)
		return TradeCore.setOffer(r, player.UserId, offer, os.time(), TradeConfig.TradeIdleTimeoutSeconds)
	end)
	if committed == nil then
		return { ok = false, err = mErr }
	end
	for itemId in offer.items do
		EconomyService.bumpDemand(itemId, EconomyConfig.DemandBumpOnOfferInclude, false)
	end
	notifyLocal(committed)
	publishPing(tradeId)
	return { ok = true }
end

local function handleSetConfirm(player: Player, tradeId: any, confirmed: any)
	local ok, err = guardCommon(player, "SetConfirm")
	if not ok then
		return { ok = false, err = err }
	end
	if not Guard.isTradeId(tradeId) or not Guard.isBool(confirmed) then
		return { ok = false, err = "bad_args" }
	end

	if confirmed then
		-- re-validate ownership at confirm time (deposit re-validates again)
		local record = fetch(tradeId)
		if record == nil then
			return { ok = false, err = "not_found" }
		end
		local key = TradeCore.sideKeyOf(record, player.UserId)
		if key == nil then
			return { ok = false, err = "not_participant" }
		end
		local afford, affordErr = InventoryService.canAfford(player, record[key].offer)
		if not afford then
			return { ok = false, err = affordErr }
		end
	end

	local committed, mErr = mutate(tradeId, function(r)
		return TradeCore.setConfirm(r, player.UserId, confirmed, os.time())
	end)
	-- Every confirm/unaccept, not just full double-confirm — this is the only
	-- server-side trace of a single-side accept, which previously left zero
	-- log evidence when a trade never reached "both confirmed".
	AnalyticsService.log("trade_confirm_set", {
		tradeId = tradeId,
		userId = player.UserId,
		requested = confirmed,
		ok = committed ~= nil,
		err = mErr,
		resultState = committed and committed.state or nil,
	})
	if committed == nil then
		return { ok = false, err = mErr }
	end
	if committed.state == "Confirmed" then
		AnalyticsService.log("trade_confirmed", { tradeId = tradeId })
		TradeService.progress(committed)
	end
	notifyLocal(committed)
	publishPing(tradeId)
	return { ok = true }
end

local function handleCancel(player: Player, tradeId: any)
	local ok, err = guardCommon(player, "CancelTrade")
	if not ok then
		return { ok = false, err = err }
	end
	if not Guard.isTradeId(tradeId) then
		return { ok = false, err = "bad_args" }
	end
	local record = fetch(tradeId)
	if record == nil or TradeCore.sideKeyOf(record, player.UserId) == nil then
		return { ok = false, err = "not_participant" }
	end
	abortTrade(tradeId, "cancelled")
	return { ok = true }
end

--------------------------------------------------------------------------------
-- Sweep + lifecycle
--------------------------------------------------------------------------------

local function sweep()
	local now = os.time()
	for tradeId in activeTradeIds do
		local record = fetch(tradeId)
		if record == nil then
			activeTradeIds[tradeId] = nil
		elseif TradeCore.isTerminal(record) then
			TradeService.progress(record)
		elseif TradeCore.isExpired(record, now) then
			abortTrade(tradeId, "timeout")
		elseif record.state == "Confirmed" then
			if now - record.touchedAt > TradeConfig.SettleStuckSeconds then
				-- a side never managed to deposit (offline?); abort + refund
				abortTrade(tradeId, "deposit_timeout")
			else
				TradeService.progress(record)
			end
		elseif record.state == "Settling" then
			TradeService.progress(record) -- idempotent re-drive
		end
	end
end

function TradeService.Init()
	StoreAdapters.init()
	tradeMap = StoreAdapters.sortedMap("Trades_v1")
end

function TradeService.Start()
	Net.bindFunction("RequestTrade", handleRequestTrade)
	Net.bindFunction("RespondToRequest", handleRespond)
	Net.bindFunction("SetOffer", handleSetOffer)
	Net.bindFunction("SetConfirm", handleSetConfirm)
	Net.bindFunction("CancelTrade", handleCancel)

	-- cross-server trade pings: refresh, notify local participants, progress
	StoreAdapters.subscribe(EconomyConfig.TradeBroadcastTopic, function(payload)
		if type(payload) ~= "table" or type(payload.tradeId) ~= "string" then
			return
		end
		if payload.from == ownerId then
			return -- our own echo; we already handled this transition locally
		end
		local record = fetch(payload.tradeId)
		if record == nil then
			return
		end
		local hasLocal = Players:GetPlayerByUserId(record.a.userId) ~= nil
			or Players:GetPlayerByUserId(record.b.userId) ~= nil
		if not hasLocal then
			return
		end
		if record.state == "Invited" then
			local target = Players:GetPlayerByUserId(record.b.userId)
			if target then
				Net.fireClient("TradeInvite", target, record.tradeId, record.a.userId, nameOf(record.a.userId))
			end
			activeTradeIds[record.tradeId] = true
		else
			track(record)
			notifyLocal(record)
			TradeService.progress(record)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local tradeId = userToTrade[player.UserId]
		if tradeId then
			local record = fetch(tradeId)
			if record and (record.state == "Invited" or record.state == "Opened" or record.state == "Confirmed") then
				abortTrade(tradeId, "player_left")
			end
			userToTrade[player.UserId] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(TradeConfig.SweepIntervalSeconds)
			sweep()
		end
	end)

	game:BindToClose(function()
		-- fail open trades fast so the counterparty isn't stuck; Settling
		-- completes idempotently via another server or mailbox on next login
		for tradeId in activeTradeIds do
			local record = fetch(tradeId)
			if record and (record.state == "Invited" or record.state == "Opened" or record.state == "Confirmed") then
				abortTrade(tradeId, "server_shutdown")
			end
		end
	end)
end

return TradeService
