--!strict
-- Shared enums. String values (not numbers) so wire payloads stay debuggable.

local Enums = {
	RarityTier = {
		Common = "Common",
		Rare = "Rare",
		Legendary = "Legendary",
		Mythical = "Mythical",
	},

	TradeState = {
		Invited = "Invited", -- request sent, awaiting accept
		Opened = "Opened", -- both in trade screen, building offers
		Confirmed = "Confirmed", -- both confirmed; deposits in progress
		Settling = "Settling", -- both sides escrowed; crediting
		Settled = "Settled", -- terminal success
		Aborted = "Aborted", -- terminal failure/cancel; refunds issued
	},

	StatState = {
		Known = "Known",
		NA = "NA", -- insufficient data; UI must render "N/A"
	},

	GrantSource = { -- tagged on every inventory/gem mutation (future faucet/sink audit)
		Starter = "starter",
		Trade = "trade",
		Refund = "refund",
		Mailbox = "mailbox",
	},

	-- Remote names, single registry. Functions = request/response, Events = server pushes.
	RemoteFunctions = {
		"GetInventory", -- () -> {gems, inventory, poolItemIds}
		"GetStats", -- (itemIds) -> {snapshots}
		"GetCurrentPool", -- () -> {poolId, items}
		"RequestTrade", -- (targetUserId) -> {ok, tradeId?}
		"RespondToRequest", -- (tradeId, accept) -> {ok}
		"SetOffer", -- (tradeId, offer) -> {ok}
		"SetConfirm", -- (tradeId, confirmed) -> {ok}
		"CancelTrade", -- (tradeId) -> {ok}
	},
	RemoteEvents = {
		"InventoryChanged", -- (inventory, gems)
		"StatsUpdated", -- ({snapshots})
		"TradeInvite", -- (tradeId, fromUserId, fromName)
		"TradeStateChanged", -- (sanitized trade view)
		"TradeSettled", -- (tradeId, receivedItems, receivedGems)
		"TradeAborted", -- (tradeId, reason)
	},
}

return Enums
