--!strict
-- Shared enums. String values (not numbers) so wire payloads stay debuggable.

local Enums = {
	RarityTier = {
		Common = "Common",
		Rare = "Rare",
		Legendary = "Legendary",
		Mythical = "Mythical",
		Godly = "Godly",
		Celestial = "Celestial",
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
		Store = "store",
		Craft = "craft",
		Purchase = "purchase", -- Robux gamepass/devproduct token grants
		Board = "board", -- trade-board settlements
		Bulk = "bulk", -- bulk-order contributions/payouts
		Roll = "roll", -- gem-paid gacha pulls (the main goods faucet)
	},

	-- Remote names, single registry. Functions = request/response, Events = server pushes.
	RemoteFunctions = {
		"GetInventory", -- () -> {gems, inventory, poolItemIds}
		"GetStats", -- (itemIds) -> {snapshots}
		"GetCurrentPool", -- () -> {poolId, items}
		"SearchPlayers", -- (query) -> {ok, results = {{userId, name}}}
		"DebugGiveGems", -- () -> {ok} — debug only, removed for release
		"GetStore", -- () -> {ok, items = {storeItem}} — NPC limited store listing
		"BuyItem", -- (itemId) -> {ok, price?, err?}
		"GetEvents", -- () -> {ok, events = {...}} — active crafting/sacrifice events
		"GetRecipeGraph", -- () -> {ok, recipes = {{eventId, eventName, recipe}}} — the FULL static ladder, for the recipe-chain view
		"CraftItem", -- (eventId, rid) -> {ok, output?, err?}
		"GetCatalog", -- () -> {ok, items = {{itemId, name, imageId}}} — every registered item
		"GetBoard", -- () -> {ok, listings}
		"GetMarketSummary", -- () -> {ok, items} — per-item stats + best bid/ask (Market directory)
		"GetItemBook", -- (itemId) -> {ok, asks, bids} — one item's live order book
		"PostListing", -- (payload) -> {ok, id?, err?} — swap or bulk
		"CancelListing", -- (id) -> {ok, err?}
		"AcceptListing", -- (id) -> {ok, err?} — auto-trade swaps
		"RegisterInterest", -- (id) -> {ok, err?} — ask-first swaps
		"ContributeBulk", -- (id, count) -> {ok, payout?, err?}
		"BuyFromListing", -- (id, count) -> {ok, spent?, err?} — gem-only sell listings
		"RequestTrade", -- (targetUserId) -> {ok, tradeId?}
		"RespondToRequest", -- (tradeId, accept) -> {ok}
		"SetOffer", -- (tradeId, offer) -> {ok}
		"SetConfirm", -- (tradeId, confirmed) -> {ok}
		"CancelTrade", -- (tradeId) -> {ok}
		"GetProfile", -- (userId) -> {ok, profile} — public snapshot, online or offline
		"SetShowcase", -- (itemIds) -> {ok, err} — owner picks <=6 items
		"SetStatus", -- (text) -> {ok, err} — filtered "looking for" text
		"SetStatChips", -- (keys) -> {ok, err} — owner pins <=4 stats
		"SetPrivacy", -- ({hideValue, hideShowcase}) -> {ok, err}
		"GetBotData", -- () -> {ok, data} — admin-only bot inspector (temporary)
		"GetShop", -- () -> {ok, offers, sectionOrder} — Robux shop catalogue
		"PromptPurchase", -- (offerId) -> {ok, err?} — server-side purchase prompt
		"GetRolls", -- () -> {ok, tiers = {{id, name, gems, luck, odds}}} — gacha tiers + live odds
		"RollItem", -- (tierId, payment?) -> {ok, item?, spent?, err?} — pay gems (or items, burned) for a roll
		"GetFreeGems", -- () -> {ok, unlocked, players, target, reward, remaining, cooldown, available}
		"WatchAd", -- () -> {ok, err?} — plays a rewarded video; the gems arrive via ProcessReceipt
		"DebugForceGoal", -- () -> {ok, forced} — debug only, removed for release: toggles the unlocked view
	},
	RemoteEvents = {
		"InventoryChanged", -- (inventory, gems)
		"StatsUpdated", -- ({snapshots})
		"TradeInvite", -- (tradeId, fromUserId, fromName)
		"TradeStateChanged", -- (sanitized trade view)
		"TradeSettled", -- (tradeId, receivedItems, receivedGems)
		"TradeAborted", -- (tradeId, reason)
		"Notify", -- (text) — generic notification toast
		"BoardActivity", -- ({text, t}) — live trade-feed line (fills/swaps)
	},
}

return Enums
