# Roblox Trading Game — CORE Build Implementation Plan

## Context

Greenfield Roblox (Luau / Studio) trading game. This plan covers **only the CORE phase**: (1) a rotating 5-item starter pool with scarcity-derived rarity and a one-time per-player starter draw, (2) a peer-to-peer trading UI (Roblox-native / Pet-Sim style) that trades items **and** gems atomically, showing four live stats (value / demand / supply / RAP) with explicit N/A handling, and (3) a persistent per-player gem balance. Future phases (gem shop / Robux / crafting sinks) are **out of scope** — this plan only flags where a core choice would make them harder to bolt on.

**Design intent captured from clarifying Q&A:**
- **Starter portfolios must be heterogeneous** so the economy moves even among fresh players (some need to trade up, some down). Solution: multi-item starter bundle drawn against a pool that is *generated with a guaranteed rarity spread*.
- **Cross-server trading** (two players in different server instances can trade). This is the hard path and drives most of the infrastructure complexity below. Accepted deliberately.
- **Plan for growth** (hundreds–thousands CCU, many concurrent servers) → shared economy state must be authoritative and cross-server-consistent via MemoryStore + DataStore + MessagingService.
- **Stack: chosen for you** (see below).
- **Market manipulation (hoarding, price swings) is emergent, not to be suppressed.** No holding caps, price floors/ceilings, or anti-hoarding limits. Only anti-scam/anti-exploit protection (simultaneous confirm, server-side validation) is in scope.

---

## Locked Decisions

| Area | Decision |
|---|---|
| Trade scope | Cross-server, via escrow + two-phase settlement. All trades route through one settlement path (co-located players are just the fast case). |
| Scale | Design for growth; MemoryStore hot state + DataStore durable + MessagingService pub/sub. |
| Starter draw | **Bundle of K=4 weighted draws** (tunable) per first join, against a pool generated with an enforced rarity spread. Duplicates allowed (stack counts). Details in §6. |
| Rarity | Derived from `totalSupply` via thresholds; never hand-labeled. |
| Items | Fungible per `itemId` (no serials — out of scope). Inventory = `itemId → count`. |
| Gems | Server-authoritative non-negative integer balance. Single mutation chokepoint (`InventoryService.AdjustGems`) so a future shop reuses it. |

---

## Tech Stack & Tooling (chosen)

- **Rojo** — filesystem ⇄ Studio sync; everything lives in source control (not a bare `.rbxl`).
- **Wally** — package manager for the deps below.
- **Knit** — server Services / client Controllers + auto-generated, namespaced Remotes. Gives us a clean service boundary and typed client API fast. (Thin; replaceable — we don't couple domain logic to it.)
- **ProfileStore** (ProfileService successor) — session-locked player persistence, autosave, `BindToClose` handling, schema template. Session locking is mandatory for a trading economy (prevents duplication via multi-server load).
- **Fusion** — reactive UI. `Value`/`Computed`/`Observer` map directly onto "UI stays reactive to server state." Server pushes deltas → controller sets Fusion `Value`s → UI recomputes.
- **Luau strict typing** across shared modules.
- **TestEZ** — unit tests for pure logic (weighted draw, rolling average, value formula, offer validation, rarity derivation).
- **Selene** (lint) + **StyLua** (format) + a CI check.

Rationale: this is the shortest path to a *correct, reactive, cross-server-safe, testable* build. Every choice is standard and well-documented; no exotic dependencies.

---

## 1. Foundational / Implicit Infrastructure Inventory

The visible features cannot run without all of this. Complete list (not just the examples the brief named):

**Networking & trust boundary**
- Central Remote registry (via Knit `Client` tables). Every RemoteEvent/Function validated **server-side**; client is never trusted for inventory, gems, supply, stat values, prices, or trade state.
- Per-remote input schema guards (type/shape/range) in `Shared/Util/Guard`.
- Per-player, per-remote **rate limiting** (trade requests, offer edits, confirms) → `RateLimitService`. Token-bucket.
- **Anti-exploit invariants**: offered items/gems must be owned at settlement time (re-checked, not just at offer build); no negative gems; no item counts below zero; confirm can't precede both offers being locked.

**Session lifecycle**
- Join: load profile (session-locked), claim pending **mailbox** grants (cross-server settlements delivered while offline), grant starter bundle if first join, hydrate client state.
- Leave: cancel any in-flight trade the player is in (refund escrow), release trade session, save+release profile.
- Server shutdown: `game:BindToClose` — flush all profiles, flush economy hot-state deltas to DataStore, fail/refund open trades.
- Session-lock steal / load failure: kick with a clear message rather than proceed on stale data.

**Player persistence (DataStore via ProfileStore)**
- Profile schema template + `SchemaVersion` + forward-migration function run on load.
- Save timing: ProfileStore autosave + explicit save on trade settlement + on leave + `BindToClose`.
- Retry/backoff + throttling budget awareness (`DataStoreService:GetRequestBudgetForRequestType`).
- Idempotency keys: `StarterGrantId`, per-settlement `SettlementId`, mailbox claim ids — so a retried/duplicated operation never double-credits.

**Global economy consistency (cross-server)**
- Durable authoritative economy record per item in a DataStore (`EconomyStore`).
- **Hot mirror in MemoryStoreService** (SortedMap) for low-latency cross-server reads and **atomic compare-and-set** on supply reservation (this is what prevents two servers handing out the same last copy).
- **Global Item Registry** (durable): `itemId → {name, poolId, totalSupply, rarity, assignmentWeight, createdAt}`. Required because a traded item may belong to an *old, rotated-out* pool; any server must resolve any `itemId`'s metadata. Cached per server, updated via pub/sub.
- **MessagingService** pub/sub: broadcast economy deltas (RAP/demand updates, new pool generated, item exhausted) so every server's cache + connected clients update reactively.
- Periodic reconciliation: flush MemoryStore deltas → DataStore; rehydrate MemoryStore from DataStore on cache miss/expiry (MemoryStore is not durable).

**Pool rotation coordination**
- Detecting "all 5 reserves == 0" is a distributed condition. Exactly-one-server election via a MemoryStore **lock key** (`pool:rotationLock`, owner+expiry) so only one server generates the replacement set; result written to registry + `EconomyStore`, broadcast via MessagingService.

**Trade engine (cross-server)**
- Matchmaking / request-accept across servers (MessagingService for signaling + MemoryStore for the durable trade record).
- Trade state machine with server-authoritative transitions.
- Escrow + two-phase settlement + compensation (refund) on timeout/abort.
- Disconnect-mid-trade handling at every state.
- Trade + settlement **transaction log** (analytics + dispute/debug + future economy audits).

**Observability**
- `AnalyticsService`: structured events (starter grant, trade opened/confirmed/settled/aborted, rotation, economy write, exploit-guard rejections). Roblox AnalyticsService + external sink later.
- Error telemetry on every DataStore/MemoryStore/Messaging failure path.

**Config & tuning**
- All tunables (supply counts, rarity thresholds, assignment-weight formula, bundle size K, value/demand/RAP constants, min-data thresholds, rate limits, timeouts) centralized in `Shared/Config`, not scattered as magic numbers.

**Safety controls**
- Feature-flag / kill switch for trading and for economy writes (disable trades without shipping code if an exploit is found live).
- Time source: server-authoritative `os.time()` for demand-decay windows and trade timeouts (never client clocks).

**Testing / QA scaffolding**
- TestEZ unit suite for pure logic; a scriptable integration harness that simulates joins/draws/trades; explicit exploit test cases (spoofed remotes, double-confirm, offer-edit-after-confirm, self-trade, offline settlement, rotation-during-join).

---

## 2. Project / Module Structure

```
ReplicatedStorage/
  Packages/            -- Wally: Knit, Fusion, Signal, Promise, TestEZ (ProfileStore is server-only)
  Shared/
    Config/
      Items.luau            -- pool-gen params, rarity thresholds, assignment-weight formula, starter K
      EconomyConfig.luau    -- value/demand/RAP constants, min-data thresholds
      TradeConfig.luau      -- slot limits, timeouts, rate limits, kill switch
    Types.luau              -- Item, InventoryEntry, Offer, TradeRecord, EconomySnapshot, Mailbox
    Enums.luau              -- RarityTier, TradeState, StatState (Known/NA), RemoteNames
    Util/
      Guard.luau            -- remote input validation
      WeightedDraw.luau     -- pure weighted selection (unit-tested)
      RollingAverage.luau   -- incremental RAP accumulator (unit-tested)
      RateLimiter.luau      -- token bucket
      Rarity.luau           -- supply -> tier (pure, unit-tested)
ServerScriptService/
  Services/
    DataService.luau        -- ProfileStore wrapper: load/save/lock, migration, mailbox claim
    InventoryService.luau   -- authoritative item + gem mutations (single chokepoint)
    EconomyService.luau     -- supply/demand/RAP authoritative state, MemoryStore mirror, sync
    StarterService.luau     -- first-join detect, bundle draw, reserve consumption
    PoolService.luau        -- current pool state, exhaustion detect, rotation election+gen
    TradeService.luau       -- trade lifecycle, escrow, two-phase settlement, mailbox delivery
    MatchmakingService.luau -- cross-server request/accept signaling
    RateLimitService.luau
    AnalyticsService.luau
    init.server.luau        -- Knit.Start
StarterPlayer/StarterPlayerScripts/
  Controllers/
    UIController.luau        -- Fusion roots, screen manager
    InventoryController.luau -- client mirror of inventory + gems (Fusion Values)
    EconomyController.luau   -- client mirror of stats for visible items (Fusion Values)
    TradeController.luau     -- trade UI state machine + confirm flow
    init.client.luau         -- Knit.Start
```

Why: services are single-purpose with explicit interfaces; authoritative mutations funnel through `InventoryService` + `EconomyService` (no other code touches balances/supply), which is what makes exploits and future-phase hooks tractable.

---

## 3. Data Model

**Global Item Registry entry** (durable, `itemId`-keyed):
```
Item = {
  itemId: string,        -- globally unique, stable forever (survives rotation)
  poolId: string,        -- which generated pool it belongs to
  name: string,
  totalSupply: number,   -- fixed cap; drives rarity + scarcity
  assignmentWeight: number, -- draw weight; SEPARATE tunable (see §6)
  rarity: RarityTier,    -- DERIVED from totalSupply, cached for display
  createdAt: number,
}
```

**Economy record** (durable in `EconomyStore`, hot in MemoryStore):
```
EconomySnapshot = {
  itemId: string,
  reserveRemaining: number,  -- undistributed copies; starter draw decrements; 0 across pool -> rotation
  circulating: number,       -- copies held by players = totalSupply - reserveRemaining
  demandEMA: number,         -- decayed interest signal
  demandSamples: number,     -- for N/A threshold
  rapValue: number,          -- rolling avg imputed gem-price
  rapCount: number,          -- closed trades counted; 0 -> RAP is N/A
  updatedAt: number,
}
```

**Player profile** (ProfileStore `Profile.Data`):
```
{
  SchemaVersion = 1,
  Gems = 0,                                   -- non-negative integer
  Inventory = { [itemId: string] = count },   -- fungible counts
  StarterGranted = false,
  StarterGrantId = "",                        -- idempotency
  Mailbox = { [claimId: string] = { items = {...}, gems = n, fromTradeId = "" } },
  Meta = { firstJoin = t, lastLogin = t, joins = n },
}
```

**Trade record** (durable in MemoryStore, keyed `tradeId`):
```
TradeRecord = {
  tradeId, state,            -- Opened|OffersLocked|Confirmed|Settling|Settled|Aborted
  a = { userId, offer = {items={itemId:count}, gems}, confirmed:bool, deposited:bool },
  b = { ... },
  createdAt, expiresAt, settlementId,
}
```
`StatState` enum (`Known` / `NA`) travels with every stat to the client so N/A is a first-class value, never a magic sentinel number.

---

## 4. Networking Surface (Remotes)

Via Knit `Client` methods/signals. All server-validated.

- `TradeService.Client`:
  - `RequestTrade(targetUserId)` → creates cross-server trade session (RemoteFunction, rate-limited)
  - `RespondToRequest(tradeId, accept)` 
  - `SetOffer(tradeId, offer)` → validate ownership, set + **reset both confirms** on any change
  - `SetConfirm(tradeId, confirmed)` → cannot confirm unless offers locked
  - `CancelTrade(tradeId)`
  - Signals: `TradeStateChanged`, `OfferUpdated`, `TradeSettled`, `TradeAborted`
- `EconomyService.Client`:
  - `GetStats(itemIds)` (RemoteFunction) → snapshot with `StatState`
  - Signal `StatsUpdated(itemId, snapshot)` (pushed on economy deltas for items the player is viewing/holding)
- `InventoryService.Client`:
  - Signal `InventoryChanged`, `GemsChanged`
  - `GetInventory()` (RemoteFunction, initial hydrate)

No remote ever accepts a client-reported value that the server then trusts (no client-sent prices, balances, or stat values).

---

## 5. Value / Demand / Supply / RAP — Calculation, Storage, Sync, N/A

**Dependency DAG (no cycles):**
- `supply` ← counts (distribution + registry). 
- `demand` ← recent interest events (EMA with time decay).
- `value` ← `g(demand, supply)` — scarcity formula (does **not** depend on RAP → no circularity).
- `RAP` ← rolling average of *imputed gem-price* of closed trades; imputation reads `value` at trade time.

**Supply (stat shown):** `circulating = totalSupply − reserveRemaining` (copies held by players). Trades transfer, don't change it. No sinks in core → monotonic up until reserve drained. (Flag: crafting phase will *decrement* circulating; field is signed-capable now.)

**Demand:** EMA updated on each completed trade involving the item (and on offer-inclusion events), decayed by elapsed time toward zero: `demandEMA = demandEMA * decay^Δt + weight`. Server-time only.

**Value:** `value = base * scarcityFactor(circulating) * demandFactor(demandEMA)`, constants in `EconomyConfig`. Scarcity rises as circulating falls. Emergent hoarding naturally raises value (fewer freely-traded copies show up, demand/RAP heat up) — **not suppressed**.

**RAP (incremental, per closed trade):** gems are the numeraire. For each item leaving a side, imputed price = `counterpartyTotalValue * (thisItemValue / thisSideTotalValue)`, where `counterpartyTotalValue = counterpartyGems + Σ(counterparty item values)`. Then `rapValue += (impPrice − rapValue) / (rapCount+1); rapCount += 1`. Uses `RollingAverage.luau`. Incremental, O(1), no history scan.

**Storage & cross-server sync:**
- Authoritative record in `EconomyStore` (DataStore) + hot mirror in MemoryStore.
- Supply reservation (starter draw) uses MemoryStore `UpdateAsync` **compare-and-set** → atomic across servers.
- RAP/demand writes: computed on the settling server, written to MemoryStore, flushed to DataStore periodically, **broadcast via MessagingService** so all servers update caches and push `StatsUpdated` to clients viewing that item.
- On MemoryStore miss/expiry → rehydrate from DataStore (durable is source of truth).

**N/A / insufficient-data (consistent in data layer AND UI):**
| Stat | Shows real value when | Else |
|---|---|---|
| Supply | always (known count; a just-rotated item can legitimately read `0` circulating) | 0 shown only when genuinely 0 in circulation |
| Demand | `demandSamples ≥ 1` | **N/A** |
| Value | `circulating ≥ 1` (needs ≥1 real supply data point) | **N/A** |
| RAP | `rapCount ≥ 1` (≥1 completed trade) | **N/A** |

`StatState.NA` is carried through the snapshot type end-to-end. UI renders "N/A", never 0/null/blank. Thresholds live in `EconomyConfig` (tunable).

---

## 6. Starter Draw + Pool Rotation

**Rarity thresholds** (derived from `totalSupply`; example, tunable in `Items.luau`):
- Common ≥ 750 · Rare 300–749 · Legendary 100–299 · Mythical < 100.

**Assignment weight** — separate tunable, default related to supply but overridable:
`assignmentWeight = round(totalSupply ^ 0.75 * c)`. Sublinear so rarer items appear less often but not never. Both `totalSupply` and `assignmentWeight` are independent per-item fields (weight can be hand-overridden without touching supply).

**Pool generation (guarantees heterogeneity):** each generated set of 5 must span tiers — enforce e.g. ≥1 Mythical/Legendary and ≥2 Common. This structurally guarantees fresh players get varied portfolios (the "economy moves among starters" requirement), instead of relying on luck.

**Starter draw (first join only):** grant a **bundle of K=4** (tunable) copies:
```
for i in 1..K:
  candidates = pool items with reserveRemaining > 0
  if candidates empty: break            -- pool fully drained mid-bundle (rare tail)
  itemId = WeightedDraw(candidates by assignmentWeight)
  reserved = EconomyService.ReserveOne(itemId)   -- MemoryStore CAS; atomic cross-server
  if reserved: add itemId to grant (stack duplicates)
  else: retry loop (item raced to 0 on another server; re-pick from fresh candidates)
InventoryService.GrantStarter(userId, grant, StarterGrantId)   -- idempotent
set Profile.StarterGranted = true
```
Duplicates allowed → creates "3× common, want 1 rare" trade dynamics. Weighted draws + rarity-spread pool → most bundles common-heavy, a lucky minority hit high rarity → asymmetric portfolios → trade motive without needing rich players present.

**Exhaustion detection + rotation:**
- `ReserveOne` decrements `reserveRemaining` atomically. When a decrement flips the **last of all 5** to 0, that server attempts to acquire MemoryStore `pool:rotationLock` (owner+expiry).
- Lock winner generates a new set of 5 (new `itemId`s, names, supplies, weights, derived rarities, enforced spread), writes them to the Item Registry + `EconomyStore`, sets them as current pool, releases lock, and broadcasts `PoolRotated` via MessagingService.
- All servers update their cached "current pool" on the broadcast. New joiners now draw from the new set.
- **Existing players keep old-pool items** — those `itemId`s stay valid in the registry forever, remain tradeable, and keep their own economy records (supply/RAP/demand continue for the old items independently).

---

## 7. Trade Flow (Cross-Server, Atomic Items + Gems, Simultaneous Confirm)

Because the two players may be on **different servers**, we cannot hold both session locks at once. We use **escrow + two-phase settlement with compensating refunds**. One path for all trades (co-located is just faster messaging).

**State machine:** `Opened → OffersLocked → Confirmed → Settling → Settled` (or `→ Aborted` from any pre-Settled state).

1. **Request / match.** A requests trade with B (by userId/friend). `MatchmakingService` creates a `TradeRecord` in MemoryStore (`tradeId`), signals B's server via MessagingService. B accepts → `Opened`. Rate-limited; both must not already be in a trade.
2. **Build offers.** Each side calls `SetOffer`. Server validates **against that player's own session-locked inventory + gem balance** (ownership + sufficiency + non-negative + slot limits). **Any offer change resets both `confirmed` flags to false** (structurally blocks last-second bait-and-switch).
3. **Simultaneous confirm (server-enforced).** `SetConfirm(true)` is rejected unless offers are locked and unchanged. A confirm is only recorded server-side; a malicious client cannot fake the other side's confirm because each confirm is written to the authoritative `TradeRecord` by that player's own server, keyed to their userId. Settlement begins **only when the record shows both `confirmed == true`**.
4. **Phase 1 — deposit to escrow.** On both-confirmed, each player's home server **atomically removes** its player's offered items + gems from the (session-locked) profile and marks `deposited = true` in the `TradeRecord`. Items+gems for one side move together (single `InventoryService` transaction) → no partial state within a side. If a deposit fails (e.g., ownership changed), the trade aborts and any already-deposited side is refunded (Phase-3 compensation).
5. **Phase 2 — settle.** When the record shows **both sides deposited**, settlement (guarded by `settlementId` idempotency) credits each side the counterparty's escrowed items **and** gems together. Delivery:
   - Recipient online on some server → credited directly to their session-locked profile.
   - Recipient offline / on a server not processing → written to their **Mailbox** (durable), claimed on next profile load. Either way the credit is atomic (items+gems in one write) and idempotent.
   - Record → `Settled`. Economy updates fire: RAP (imputed price per item), demand bump, `StatsUpdated` broadcast.
6. **Abort / timeout / disconnect.** Expiry timer or either player disconnecting/cancelling before `Settling` → `Aborted`, all escrowed goods refunded via owner Mailbox (idempotent). Disconnect *during* `Settling` is safe: settlement is idempotent and completes via Mailbox regardless of presence.

**Atomicity guarantee:** items and gems for a side are always one transaction; a side is never half-moved. Cross-server atomicity is achieved by escrow (both sides fully deposited before either is credited) + idempotent, durable delivery (Mailbox) — the classic saga/2PC-with-compensation pattern.

---

## 8. UI Architecture & Reactivity

- **Fusion** declarative components. Client controllers hold `Value` objects; UI is `Computed`/`New` bound to them → any state change re-renders automatically.
- `InventoryController` holds `Value(inventory)` + `Value(gems)`, updated by `InventoryChanged`/`GemsChanged` signals.
- `EconomyController` holds a `Value` per visible item's stats; subscribes to `StatsUpdated`; renders N/A when `StatState.NA`.
- `TradeController` holds the trade `Value(state)` + both offers; the two-panel trade screen (your offer / their offer, item slots, gem field, per-side accept state) is a pure function of that state. Confirm buttons reflect server-authoritative `confirmed` flags (client shows, server decides).
- **Reactivity to server = signals in → Fusion Values set → UI recomputes.** No polling. Trade panel, inventory grid, and stat rows all update live as the server pushes deltas (including another server's economy broadcasts arriving via MessagingService → `StatsUpdated`).
- Visual/UX reference: Roblox native trade + Pet-Sim — two-panel offer layout, click/drag from inventory into slots, explicit per-side accept/decline lights, live stat rows (Value / Demand / Supply / RAP or N/A) on every item tile in both the trade screen and the browse/inventory view.

---

## 9. Persistence End-to-End

**Player:** ProfileStore session-locked profile per userId. Load on join (migrate if `SchemaVersion` old, claim Mailbox), autosave + save-on-settlement + save-on-leave + `BindToClose` flush. Session lock prevents the same profile loading on two servers → prevents duplication. Load failure → kick, don't proceed.

**Global economy:** authoritative in `EconomyStore` DataStore + Item Registry DataStore; hot mirror + atomic reservations + trade records in MemoryStore; deltas broadcast via MessagingService. Periodic MemoryStore→DataStore flush; DataStore→MemoryStore rehydrate on miss. `BindToClose` flushes pending economy deltas. All economy mutations idempotent where retried.

**Throttling:** respect DataStore/MemoryStore request budgets; batch economy flushes; exponential backoff; never spin-retry.

---

## 10. Implementation Milestones (ordered)

1. **Tooling & skeleton** — Rojo + Wally + Knit + Fusion + ProfileStore installed; empty services/controllers boot; Selene/StyLua/TestEZ CI green.
2. **Config + pure logic (TDD)** — `Items`, `EconomyConfig`, `TradeConfig`; `Rarity`, `WeightedDraw`, `RollingAverage`, `Guard`, `RateLimiter` with unit tests.
3. **Player persistence** — `DataService` (ProfileStore, schema v1, migration stub, Mailbox claim); join/leave/BindToClose; `InventoryService` gem + item chokepoint with invariants.
4. **Item Registry + Economy state** — `EconomyService`: DataStore records, MemoryStore mirror, atomic `ReserveOne`, value/demand/RAP compute + N/A, MessagingService broadcast + cache.
5. **Starter draw + rotation** — `StarterService` (idempotent bundle draw), `PoolService` (exhaustion detect, rotation lock/election/gen/broadcast). Seed initial 5.
6. **Client hydrate + reactive stats UI** — controllers mirror inventory/gems/stats into Fusion; browse/inventory view with live 4-stat tiles (incl. N/A).
7. **Trade engine** — `MatchmakingService` (cross-server request/accept) + `TradeService` state machine, offer validation, confirm reset, escrow deposit, two-phase settle, Mailbox delivery, refunds, timeouts, disconnect handling.
8. **Trade UI** — two-panel Fusion screen; slots, gem input, per-side accept lights; wired to server-authoritative state.
9. **Anti-exploit + rate limits + kill switch + analytics** hardening pass.
10. **QA** — exploit test cases, cross-server integration harness, rotation-under-load, soak/duplication tests.

---

## 11. Risks & Edge Cases

- **Exploited remotes** → all inputs server-validated via `Guard`; ownership re-checked at settlement, not just at offer.
- **Double-spend last copy across servers** → MemoryStore CAS `ReserveOne`; no non-atomic decrement path exists.
- **Two servers rotate simultaneously** → single MemoryStore rotation lock; only lock owner generates; others adopt via broadcast.
- **Join at the exact moment of rotation** → draw reads current pool atomically per `ReserveOne`; if an item raced to 0, re-pick from fresh candidates; if whole pool drained mid-bundle, grant the partial bundle and let rotation complete (next joiners get new pool). Player never gets a phantom copy.
- **Partial-transfer mid-trade** → escrow + two-phase + idempotent Mailbox delivery; a side is never half-credited; failure refunds via compensation.
- **Disconnect mid-trade** → pre-`Settling` aborts+refunds; during `Settling` settlement is idempotent and completes via Mailbox.
- **Simultaneous confirm race / offer edit after confirm** → any offer change resets both confirms; settlement gated on both-confirmed-in-record.
- **DataStore throttling / MemoryStore expiry** → budget checks, backoff, batched flush, DataStore-as-source-of-truth rehydrate.
- **Duplication via multi-server profile load** → ProfileStore session lock; kick on lock failure.
- **Self-trade / trading with self across two clients** → reject same-userId; one-active-trade-per-player invariant.
- **RAP manipulation** → intended/emergent (not suppressed). Only guard is that prices are real closed-trade imputations from validated offers — no fake trades possible.
- **Gem/int overflow & negatives** → clamp to non-negative integer, bounded max, single mutation chokepoint.
- **Mailbox growth / never-claimed grants** → durable; claimed on next login; bounded size + analytics alert if unbounded.

---

## 12. Future-Phase Change Points (flag only — not building)

- **Gem shop / Robux:** gems already flow through one chokepoint (`InventoryService.AdjustGems`) with idempotent transactions — a shop/purchase grant hooks in cleanly. Add a `source` tag to grants now (`starter|trade|shop|craft`) so later faucet/sink accounting is free.
- **Crafting sinks:** core assumes supply is monotonic (no destruction). `circulating`/`reserveRemaining` are stored signed-capable and mutated only via `EconomyService`, so a sink that burns copies can decrement supply without a schema change. Rotation trigger is currently keyed on `reserveRemaining == 0 for all 5`; injecting crafted/non-starter items into the pool later will need that trigger generalized — **flagged**.
- **Item Registry** already supports arbitrary non-starter items (any `itemId` with metadata), so crafted items are addressable and tradeable with zero core rework.
- **Schema versioning** (`SchemaVersion` + migration on load) is in place from day one, so future profile fields (owned cosmetics, shop history) migrate safely.
- **Serials** are explicitly out of scope; inventory is fungible counts. If serials are ever wanted, inventory model changes from `itemId→count` to per-copy records — **flagged as a non-trivial later migration.**

---

## 13. Proposed Extra Features (sensible additions — your call)

- **`source` tag on every grant** (starter/trade) now → free faucet/sink analytics later. Low cost, high future value.
- **Trade history log per player** (last N trades) — cheap given the settlement transaction log already exists; big QA/dispute value.
- **Kill switch / feature flags** for trading + economy writes (already in `TradeConfig`) — lets you disable trading live if an exploit appears, without a redeploy.
- **Economy snapshot analytics** (periodic dump of supply/RAP/demand per item) — data you'll want the moment the economy is live.
- **"One active trade per player" + block trading with self** invariants — trivial, closes a class of exploits.
- **Deterministic seedable pool generation** (seed logged) — makes rotation reproducible for debugging/tests.

---

## 14. Verification

- **Unit (TestEZ):** rarity derivation thresholds; weighted draw distribution (statistical); rolling-average RAP correctness; offer validation rejects unowned/over-balance/negative; N/A thresholds flip at exactly 1 sample.
- **Integration harness (scripted in Studio):** simulate N first-joins → assert reserves decrement, bundles heterogeneous, rotation fires at total exhaustion, existing inventories untouched post-rotation.
- **Trade correctness:** two-client (and simulated two-server) trade of items+gems → assert atomic transfer, both-confirm gating, offer-edit resets confirm, escrow refund on abort, idempotent settlement (run settlement twice → single credit), offline recipient receives via Mailbox on next login.
- **Exploit suite:** spoofed remote args, confirm-before-lock, offer-edit-after-confirm, self-trade, replayed settlement id, double `ReserveOne` on last copy across two servers → all rejected/safe.
- **Live smoke:** publish to a test place, run 2 real clients across 2 servers, execute a cross-server trade, observe live stat updates + N/A on a fresh rotated item, force a server shutdown mid-trade and confirm refund/settlement integrity.
```
