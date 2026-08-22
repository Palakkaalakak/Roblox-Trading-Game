# Trade Ads — Design

Date: 2026-08-22
Status: approved, ready for implementation plan

## Summary

Turn the existing "TRADES" board tab into a real **Trade Ads** system: player-posted
"I give X, I want Y" listings with a lifetime tied to presence, two visibility scopes
(this server / global), per-player slot limits, and paid placement that never gates
trading itself.

Most of the storage and sort machinery already exists as scaffolding. This is
primarily a purchase flow + lifetime model + UI job.

## Prior art

Researched gamersberg.com and bloxfruitsvalues.com trade-ad feeds. Conventions adopted:

- Offering / Requesting shown side by side, item chips with quantity multipliers
- Per-side value total plus a **value-difference (WFL) meter**
- Live feed, newest first; ad leaves on expiry or manual delete
- Their stated rule, adopted verbatim as ours: *boosting is optional and only changes
  where an ad sits in the feed — it does not gate any part of trading*

Noted but deferred: per-item demand rating (`8/10`) shown next to value (we already
compute demand in the value formula, so it is cheap to surface later); completed-trade
history database.

## What already exists

From `TradeBoardService.luau`:

| Piece | State |
|---|---|
| `listing.boostTier` | field exists, always `0` |
| `listing.bumpedAt`, `expiresAt`, `ttlSeconds` | exist, wired to lazy expiry |
| `listingOrder` | already sorts `boostTier` desc, then `bumpedAt` desc |
| `TradeBoardService.boostListing(id, tier, extendSeconds)` | fully written, nothing calls it |
| Global reach | player ads in MemoryStore map — already cross-server |
| Offline settlement | already works; no escrow, take happens at settlement |
| Bot ads | server-local `memBoard` — inherently "this server" |
| Per-poster slot limit | **does not exist** ("no per-poster limits; only a global board cap") |
| By-poster index | **does not exist** — own ads found by scanning and filtering `posterId` |

From `ProductService.luau`:

| Piece | State |
|---|---|
| `registerDevProduct(productId, label, grant)` | public extension point; `ProcessReceipt` owned in one place |
| Gamepass support | `productType = "gamepass"`, idempotent grant-on-join via claimId, owned-state query, `PromptGamePassPurchase` |
| Duplicate product ids | refused; for `PlaceholderProductId` the first handler silently wins |

## Scopes

Two scopes, surfaced as a `THIS SERVER | GLOBAL` filter inside the Trade Ads tab
(mirrors how profiles show server people alongside global).

**Server ads**
- Stored in server-local `memBoard` (already free, already server-local)
- Live only while the poster is in this server; they disappear when the poster leaves
- Payoff: whoever answers is online right now, so the trade settles immediately
- Cheaper boosts

**Global ads**
- Stored in the MemoryStore map (existing, already cross-server)
- Live while the poster is in game, plus 2h after they leave
- Reach the whole experience, but the poster may be offline
- More expensive boosts

Paid duration overrides the lifetime rule in **both** scopes — a paid server ad
survives the poster leaving, for the purchased window.

## Lifetime model

On post: `expiresAt = now + 2h`.

While the poster is in game, the ad's death clock is pushed forward. Stay AFK five
days and the ad lives five days. Leave, and nothing pushes it, so it dies within 2h
(server ads: immediately, see above).

**The push touches `expiresAt` only, never `bumpedAt`.** This is the whole decay
mechanic: sort order is by `bumpedAt`, so an AFK ad stays *alive* while steadily
*sinking* as newer ads arrive. Staying online keeps an ad alive, not on top. Only
payment buys position.

### Refresh mechanism

There is no by-poster index, so a per-player refresh loop would mean a full board scan
per player. Instead the refresh **piggybacks on the existing per-server board sweep**:
while walking listings it already scans, the server pushes `expiresAt` for any listing
whose poster is on *this* server and is within an hour of expiring.

- One scan, no extra reads
- Naturally cross-server: each server refreshes only its own players' ads
- Roughly one small write per ad per hour, for online posters only

The write budget matters here — see the syndicate write-storm regression fixed in
`df516be`. Do not add a per-action or per-frame write path.

## Slots

3 open ads per player **per scope** (3 server + 3 global).

- `profile.ExtraAdSlots` adds on top, granted by a repeatable dev product
- Enforced at post time; the count comes from the existing scan
- Rejecting a post over the limit returns a normal error, no special handling

## Paid placement

Payment buys **position and duration only**. Posting, browsing, and accepting are free
for everyone, always. No pay-to-trade.

`boostTier`: `0` free, `1` priority, `2` featured. `boostListing` already uses
`math.max`, so purchases upgrade and never downgrade.

### Per-ad dev products

| SKU | Server | Global |
|---|---|---|
| Bump — jump to top of the free feed now, then sink normally | 10 | 25 |
| Priority 24h — sits above all free ads | 25 | 49 |
| Featured 24h — pinned in the Featured strip | 49 | 99 |
| Featured 3d | — | 199 |

### Gamepasses (permanent, apply to all your ads)

| Pass | Price | Effect |
|---|---|---|
| Ad Priority Pass | 199 | all your ads are tier 1 |
| Ad Duration Pass | 149 | all your ads get 24h lifetime; server ads survive leaving |

**Featured is deliberately excluded from gamepasses.** There are only 3 slots per
scope; a permanent featured pass would let one player squat the pool forever.

### Repeatable dev product

| SKU | Price | Effect |
|---|---|---|
| +1 Ad Slot | 49 | stacks, increments `profile.ExtraAdSlots` |

All product ids point at `PLACEHOLDER_PRODUCT_ID` for now. Real ids at publish.

### Featured scarcity

3 Featured slots per scope. When full, the purchase is blocked rather than queued.

If a receipt lands when the pool is full (or the target ad is already gone), the boost
is **banked as a credit on the profile** and can be applied to any open ad later. This
reuses the credit fallback rather than adding a slot-claim system: no atomic claim, no
hold TTL, no leak cleanup. Worst case, someone waits.

## Purchase flow

1. Client calls `PromptAdBoost(listingId, sku)`
2. Server validates the ad is the caller's and still open, records the intent
   (in memory and on the profile), then prompts the purchase
3. `ProcessReceipt` → the registered boost handler reads the intent and applies the SKU
4. If the ad is gone, or the Featured pool is full, bank a credit instead
5. `ApplyAdBoostCredit(listingId, sku)` spends a banked credit on any open ad

**The SKU rides in the intent, not the product id.** This is required, not stylistic:
`registerDevProduct` refuses duplicate ids, and with every SKU pointing at the
placeholder only the first would register — buying Featured 3d would grant Bump. One
handler reads the intent instead, so the placeholder behaves correctly today and real
ids drop in later with no restructure.

Intent is persisted on the profile so a receipt re-delivered after a rejoin or server
restart still finds its target. Receipts must never silently evaporate; a purchase that
cannot be applied becomes a credit.

Keep a single-line check that the receipt's product id matches the intent's expected
id, with a comment noting it only bites once real ids exist. Cheap now, easy to forget
later.

### Perk resolution

Gamepass ownership resolves to a profile flag on join, and that flag is **stamped onto
the listing at post time** (`listing.perks`). Sorting stays a pure comparison with no
lookups — which matters because ads are sorted on *other* servers where the poster is
not present. The refresh sweep re-stamps, so a pass bought after posting still upgrades
live ads.

## UI

Tab label `TRADES` → **`TRADE ADS`**. Internals keep saying "listing"; no churn.

**Scope filter** — `THIS SERVER | GLOBAL` at the top of the tab. The view builder adds
`here = Players:GetPlayerByUserId(posterId) ~= nil`; the client filters on it. Zero
extra storage or reads. Bot ads are server-local already, so they are inherently "this
server".

**Featured strip** — top of the tab, horizontal, max 3, gold-edged, labeled `FEATURED`.
**Collapses to zero height when empty**, so a quiet board is not a wall of dead space.
Shows live availability (`FEATURED — 1/3 open`); when full, the buy button is disabled
and shows when the next slot frees up.

**Main feed** — below, newest first, Priority ads badged and sorted above free ones.

**Row** — `Give ⇄ Want` with item chips and quantity multipliers, plus:
- **Value delta chip** — `+12% you` / `Fair` / `-8% you`, from
  `EconomyService.snapshot().value`. This is the WFL meter every researched site leads
  with.
- **Time-left pill** — `2h left` / `23h left` / `Live · you're in game` in green.
  Without this the AFK mechanic is invisible and nobody learns it exists.

**Boost sheet** — modal listing the SKUs available for that ad's scope, each stating in
plain words what it does, its price, and its duration. Reuses the `ShopScreen` card
pattern. A `⏱ Boost` button appears on your own ads only.

Mobile: featured strip scrolls horizontally, main feed vertical.

## Testing

Pure-logic tests in the existing `TestRunner`:

- Boost tier ordering, and that ties fall through to bump recency
- TTL refresh math
- **Refresh pushes `expiresAt` but never `bumpedAt`** — the decay invariant
- Slot limit enforcement, including `ExtraAdSlots`
- Credit fallback when the ad is gone or the Featured pool is full
- Featured selection and empty-strip collapse
- Scope split: server ads never leak into the global feed

## Explicitly out of scope

- Real Roblox product ids (placeholder until publish)
- Per-item demand rating in the row
- Completed-trade history database
- Gem pricing (Robux only for now; gems reconsidered if the economy needs the sink)
