--!strict
-- TradeController: client-side trade session state + remote calls.
-- The server view (TradeStateChanged) is the ONLY source of truth the UI
-- renders; user actions are requests, never local mutations.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Net = require(script.Parent.Parent.Net)

local TradeController = {}

TradeController.trade = State.Value(nil :: any) -- sanitized view or nil
TradeController.invite = State.Value(nil :: any) -- {tradeId, fromUserId, fromName} or nil
TradeController.pendingConfirm = State.Value(false) -- accept toggle in flight (optimistic UI)
TradeController.settled = Signal.new() -- (tradeId, items, gems) — toast hook
TradeController.aborted = Signal.new() -- (tradeId, reason)
TradeController.actionError = Signal.new() -- (code) — surface rejections

local function currentTradeId(): string?
	local t = TradeController.trade:get()
	return t and t.tradeId or nil
end

--------------------------------------------------------------------------------
-- Actions (fire-and-observe; server responds via TradeStateChanged)
--------------------------------------------------------------------------------

function TradeController.requestTrade(targetUserId: number)
	task.spawn(function()
		local result = Net.invoke("RequestTrade", targetUserId)
		if not result.ok then
			TradeController.actionError:Fire(result.err or "failed")
		end
	end)
end

function TradeController.respond(accept: boolean)
	local invite = TradeController.invite:get()
	if invite == nil then
		return
	end
	TradeController.invite:set(nil)
	task.spawn(function()
		local result = Net.invoke("RespondToRequest", invite.tradeId, accept)
		if not result.ok then
			TradeController.actionError:Fire(result.err or "failed")
		end
	end)
end

-- Build next offer from the current view + a mutation, then submit whole offer.
local function submitOffer(mutator: (offer: any) -> any)
	local view = TradeController.trade:get()
	if view == nil then
		return
	end
	local offer = { items = {}, gems = view.you.offer.gems }
	for itemId, count in view.you.offer.items do
		offer.items[itemId] = count
	end
	offer = mutator(offer)
	task.spawn(function()
		local result = Net.invoke("SetOffer", view.tradeId, offer)
		if not result.ok then
			TradeController.actionError:Fire(result.err or "failed")
		end
	end)
end

function TradeController.addItem(itemId: string)
	submitOffer(function(offer)
		offer.items[itemId] = (offer.items[itemId] or 0) + 1
		return offer
	end)
end

function TradeController.removeItem(itemId: string)
	submitOffer(function(offer)
		local count = (offer.items[itemId] or 0) - 1
		offer.items[itemId] = count > 0 and count or nil
		return offer
	end)
end

function TradeController.setGems(gems: number)
	submitOffer(function(offer)
		offer.gems = math.max(0, math.floor(gems))
		return offer
	end)
end

function TradeController.setConfirm(confirmed: boolean)
	local tradeId = currentTradeId()
	if tradeId == nil or TradeController.pendingConfirm:get() then
		return
	end
	TradeController.pendingConfirm:set(true)
	task.spawn(function()
		local result = Net.invoke("SetConfirm", tradeId, confirmed)
		TradeController.pendingConfirm:set(false)
		if not result.ok then
			TradeController.actionError:Fire(result.err or "failed")
		end
	end)
end

function TradeController.cancel()
	local tradeId = currentTradeId()
	if tradeId == nil then
		return
	end
	task.spawn(function()
		Net.invoke("CancelTrade", tradeId)
	end)
	TradeController.trade:set(nil)
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function TradeController.Init() end

function TradeController.Start()
	-- Once a trade ends, late/stale views for it are dropped (this is what
	-- stopped the closed panel flashing back open) and each toast fires at
	-- most once (they used to double up when settlement ran twice).
	local seen: { [string]: boolean } = {}
	local seenCount = 0
	local function once(key: string): boolean
		if seen[key] then
			return false
		end
		if seenCount > 300 then
			table.clear(seen)
			seenCount = 0
		end
		seen[key] = true
		seenCount += 1
		return true
	end
	local function isTerminal(tradeId: string): boolean
		return seen["end_" .. tradeId] == true
	end
	local function closeTrade(tradeId: string)
		once("end_" .. tradeId)
		local current = TradeController.trade:get()
		if current and current.tradeId == tradeId then
			TradeController.trade:set(nil)
		end
	end

	Net.on("TradeInvite", function(tradeId, fromUserId, fromName)
		if isTerminal(tradeId) then
			return
		end
		TradeController.invite:set({ tradeId = tradeId, fromUserId = fromUserId, fromName = fromName })
	end)

	Net.on("TradeStateChanged", function(view)
		if type(view) ~= "table" or isTerminal(view.tradeId) then
			return
		end
		local current = TradeController.trade:get()
		if current and current.tradeId == view.tradeId and current.v >= view.v then
			return -- stale
		end
		if view.state == "Settled" or view.state == "Aborted" then
			closeTrade(view.tradeId)
		else
			TradeController.trade:set(view, true)
		end
	end)

	Net.on("TradeSettled", function(tradeId, items, gems)
		closeTrade(tradeId)
		if once("settled_" .. tradeId) then
			TradeController.settled:Fire(tradeId, items, gems)
		end
	end)

	Net.on("TradeAborted", function(tradeId, reason)
		closeTrade(tradeId)
		local invite = TradeController.invite:get()
		if invite and invite.tradeId == tradeId then
			TradeController.invite:set(nil)
		end
		if once("aborted_" .. tradeId) then
			TradeController.aborted:Fire(tradeId, reason)
		end
	end)
end

return TradeController
