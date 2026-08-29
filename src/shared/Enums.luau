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
		"CraftItem", -- (eventId, rid, count?) -> {ok, made?, asked?, output?, err?}
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
		"GetShop", -- () -> {ok, offers, sectionOrder} — Robux shop catalogue
		"PromptPurchase", -- (offerId) -> {ok, err?} — server-side purchase prompt
		"GetRolls", -- () -> {ok, tiers = {{id, name, gems, luck, odds}}} — gacha tiers + live odds
		"RollItem", -- (tierId, payment?) -> {ok, item?, spent?, err?} — pay gems (or items, burned) for a roll
		"GetLeaderboard", -- (boardId, scope) -> {ok, rows, you, resetsAt?} — scope "alltime"|"weekly"
		"GetSyndicate", -- () -> {ok, syndicate?, invites} — your clan + pending invites
		"BrowseSyndicates", -- () -> {ok, syndicates} — public directory, best first
		"CreateSyndicate", -- (name, tag) -> {ok, syndicate?, err?}
		"JoinSyndicate", -- (id) -> {ok, syndicate?, err?}
		"LeaveSyndicate", -- () -> {ok, disbanded?, err?}
		"InviteToSyndicate", -- (targetUserId) -> {ok, err?}
		"SyndicateModerate", -- (targetUserId, action) -> {ok, err?} — kick|promote|demote
		"PostSyndicateRequest", -- (itemId, count) -> {ok, err?} — ask your clan for items
		"FillSyndicateRequest", -- (reqId, count) -> {ok, count?, err?} — donate from your inventory
		"SyndicateSetRole", -- (targetUserId, role) -> {ok, syndicate?, err?}
		"SyndicateSetPermission", -- (roleId, action, allowed) -> owner only
		"SyndicateCreateRole", -- (name) -> {ok, syndicate?, err?}
		"SyndicateRenameRole", -- (roleId, name) -> {ok, syndicate?, err?}
		"SyndicateDeleteRole", -- (roleId) -> {ok, syndicate?, err?}
		"SyndicateMoveRole", -- (roleId, direction) -> {ok, syndicate?, err?} -- (role, action, allowed) -> {ok, syndicate?, err?} — owner only
		"SetSyndicatePolicy", -- (policy) -> {ok, err?} — Open|Request|Invite
		"GetUniqueCrafts", -- () -> {ok, slots, maxSlots, nextSlotCost, rows}
		"BuyUniqueCraftSlot", -- () -> {ok, slots?, err?} — gems for a permanent extra slot
		"GetCraftProgress", -- () -> {ok, crafts, tiers, goal} — milestone track + communal goal
		"ClaimMilestone", -- (index) -> {ok, name?, err?}
		"ClaimCommunalGoal", -- () -> {ok, err?}
		"TradeQuickChat", -- (tradeId, phraseId, itemId?) -> {ok, err?} — canned phrases only
		"SendGroupChat", -- (message) -> {ok, err?} — filtered per reader
		"GetGroupChat", -- () -> {ok} — replays recent history to the caller
		"GetFreeGems", -- () -> {ok, unlocked, players, target, reward, remaining, cooldown, available}
		"WatchAd", -- () -> {ok, err?} — plays a rewarded video; the gems arrive via ProcessReceipt
		"AdminResetEconomy", -- () -> {ok, reset} — admin only: every item back to full reserve
		"DebugBatchRoll", -- (rarity, count) -> {ok, granted, tally, err?} — admin only: N rolls at one rarity
		"GetBooths", -- () -> {ok, booths, yours?, skins, owned} — plaza storefronts
		"ClaimBooth", -- (boothId) -> {ok, err?} — first-come, released on leave
		"ReleaseBooth", -- () -> {ok}
		"SetBoothSkin", -- (skinId) -> {ok, err?} — cosmetic only, must be owned
		"SetBoothTagline", -- (text) -> {ok, tagline?, err?} — filtered
		"DebugForceGoal", -- () -> {ok, forced} — debug only, removed for release: toggles the unlocked view
		"PromptAdBoost", -- (skuId) -> {ok, err?} — server-side boost purchase prompt; always banks a credit
		"ApplyAdBoost", -- (listingId, skuId) -> {ok, err?} — spend a banked credit on your own open ad
		"GetAdBoostState", -- () -> {ok, credits, featuredOpen, autoRenew} — owned credits + free featured slots
		"SetAdAutoRenew", -- (scope, enabled) -> {ok, err?} — per-scope featured auto-renew preference
		"SetPerkDebug", -- (offerId, enabled) -> {ok, err?} — DEV ONLY: suppress an owned pass's perk
		"EnterAfk", -- () -> {ok, afk, zoneId?, err?} — take a spot on an AFK pad
		"LeaveAfk", -- () -> {ok, afk} — stand back up; drops the reward ladder
		"GetAfkState", -- () -> {ok, afk, ticks?, secondsToNext?, nextReward}
	},
	RemoteEvents = {
		"InventoryChanged", -- (inventory, gems)
		"StatsUpdated", -- ({snapshots})
		"TradeInvite", -- (tradeId, fromUserId, fromName)
		"TradeStateChanged", -- (sanitized trade view)
		"TradeSettled", -- (tradeId, receivedItems, receivedGems)
		"TradeAborted", -- (tradeId, reason)
		"AdBoostStateChanged", -- () — a boost credit was banked; refetch GetAdBoostState
		"AfkStateChanged", -- (state) — AFK session started, paid a tick, or ended
		"Notify", -- (text) — generic notification toast
		"TradeChat", -- ({tradeId, fromUserId, fromName, text, at})
		"GroupChat", -- ({groupId, userId, name, text, at}) — already filtered for this reader
		"BoothsChanged", -- ({booth}) — plaza storefront state for every booth
		"BoardActivity", -- ({text, t}) — live trade-feed line (fills/swaps)
	},
}

return Enums
