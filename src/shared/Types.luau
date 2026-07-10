--!strict
-- Shared Luau types for the trading core.

export type RarityTier = "Common" | "Rare" | "Legendary" | "Mythical"
export type StatState = "Known" | "NA"
export type TradeState = "Invited" | "Opened" | "Confirmed" | "Settling" | "Settled" | "Aborted"

-- Registered item (Global Item Registry). itemId stays valid forever, across rotations.
export type Item = {
	itemId: string,
	poolId: string,
	name: string,
	totalSupply: number,
	assignmentWeight: number,
	rarity: RarityTier, -- derived from totalSupply; cached for display
	createdAt: number,
}

-- Authoritative per-item economy record (durable in EconomyStore, hot in MemoryStore).
export type EconomyRecord = {
	itemId: string,
	reserveRemaining: number, -- undistributed copies (starter draws take from here)
	circulating: number, -- copies held by players
	demandEMA: number,
	demandT: number, -- server time of last demand update (for decay)
	demandSamples: number,
	rapValue: number,
	rapCount: number,
	updatedAt: number,
}

-- One displayed stat: value present only when state == "Known".
export type Stat = {
	state: StatState,
	value: number?,
}

-- Client-facing snapshot of one item's live stats.
export type StatSnapshot = {
	itemId: string,
	name: string,
	rarity: RarityTier,
	value: Stat,
	demand: Stat,
	supply: Stat, -- circulating copies
	rap: Stat,
	reserveRemaining: number,
}

-- One side of a trade offer. items: itemId -> count.
export type Offer = {
	items: { [string]: number },
	gems: number,
}

export type TradeSide = {
	userId: number,
	offer: Offer,
	confirmed: boolean,
	deposited: boolean,
	credited: boolean,
	refunded: boolean,
}

-- Authoritative cross-server trade record (MemoryStore).
export type TradeRecord = {
	tradeId: string,
	state: TradeState,
	v: number, -- version; bumped on every mutation, receivers drop stale
	a: TradeSide,
	b: TradeSide,
	createdAt: number,
	touchedAt: number,
	expiresAt: number,
	settlementId: string?,
	abortReason: string?,
}

-- Mailbox entry (durable, separate store; append-only until claimed).
export type MailboxEntry = {
	claimId: string, -- idempotency key
	items: { [string]: number },
	gems: number,
	source: string,
	fromTradeId: string?,
	createdAt: number,
}

-- Persisted player profile (Data of the session-locked store).
export type Profile = {
	SchemaVersion: number,
	Gems: number,
	Inventory: { [string]: number },
	StarterGranted: boolean,
	StarterGrantId: string,
	ClaimedIds: { [string]: boolean }, -- settlement/mailbox idempotency log
	Meta: { firstJoin: number, lastLogin: number, joins: number },
	-- v2: player profile (public-facing, opt-out privacy)
	Showcase: { string }, -- <=6 itemIds, player-ordered; {} => default scarcest-6
	StatChips: { string }, -- <=4 stat keys; {} => default set
	Status: string, -- filtered "looking for" text
	Privacy: { hideValue: boolean, hideShowcase: boolean },
	Lifetime: { gemsEarned: number, trades: number },
}

-- One showcased/priced item, resolved from live economy state.
export type ItemView = {
	itemId: string,
	name: string,
	rarity: string,
	imageId: string,
	estValue: number,
	circulating: number,
}

-- Public snapshot served for any player (online or offline). Hidden sections
-- are ABSENT (not nulled) — privacy applied at write time.
export type PublicProfile = {
	userId: number,
	name: string,
	displayName: string,
	firstJoin: number,
	portfolioValue: number?, -- absent if hidden
	showcase: { ItemView }?, -- absent if hidden
	statChips: { { key: string, label: string, value: number } },
	status: string,
	updatedAt: number,
}

return nil
