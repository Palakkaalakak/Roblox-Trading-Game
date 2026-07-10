--!strict
-- Trade config: slot limits, timeouts, kill switch.

local TradeConfig = {
	Enabled = true, -- kill switch: false rejects all trade remotes server-side

	MaxSlotsPerSide = 9, -- distinct item stacks per offer side (3x3 grid)
	MaxCountPerSlot = 99, -- copies per stack in one offer
	MaxGemsPerOffer = 1_000_000_000,

	-- After BOTH players accept, the server waits this long before locking in
	-- (PS99-style countdown). Either player can still cancel during it.
	ConfirmGraceSeconds = 4,

	InviteTimeoutSeconds = 60, -- pending invite expiry
	TradeIdleTimeoutSeconds = 300, -- open trade with no activity
	SettleStuckSeconds = 120, -- Settling older than this gets re-driven (idempotent)
	SweepIntervalSeconds = 15,
}

return TradeConfig
