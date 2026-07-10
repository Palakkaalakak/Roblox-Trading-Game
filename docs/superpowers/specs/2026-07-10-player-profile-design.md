# Player Profile — Design Spec

Date: 2026-07-10
Status: Approved (design); pending implementation plan.

## Goal

A Blox-Fruits-style **Player Profile**: a Server tab (players in the current
instance) and a Global tab (search any player who ever joined), each opening
into a profile view. A profile shows a player-curated public face — identity,
a small showcase, an aggregate portfolio value, pinned stat chips, and a
free-text status — never the full inventory. Players opt out of showing their
aggregate value and/or showcase. Profiles are viewable for offline players.

## Non-goals

- No full-inventory exposure. Ever. Only the showcase + aggregate total.
- No client-side privacy filtering — the server writes only public bytes.
- No report/block/social-graph features (future).
- No pixel-level UI layout here (that lives in the implementation plan; UI is
  built once in `GuiBuilder`, per the project's established pattern).

## Locked decisions

| Decision | Value |
|---|---|
| Default showcase | Player's 6 **scarcest** owned items — ascending **circulating** supply (fewest in existence first). |
| Stat chips | Player pins up to 4. Default set (unpinned): portfolio value, total trades, mythicals owned, account age. |
| Lifetime counters | Track **both** `gemsEarned` and `trades` (new persistent counters). |
| Own-profile entry | New HUD **"Profile"** button. |
| Read architecture | **Public snapshot store** (Approach A below). |
| Portfolio value | Sum of item Est. Values only. Gems are separate (offered as a stat chip), never folded in. |

## Architecture — read path

Session-locked profiles can't be read for an offline (or another online) player
without fighting the lock. Solution: each player's home server maintains a
**lock-free public snapshot**.

- New DataStore `PublicProfile_v1`, keyed by `userId`.
- The owner's server writes the snapshot; anyone reads it with a plain
  `GetAsync` (+ short server-side cache).
- Uniform for online and offline targets. No lock contention.
- **Privacy by construction**: hidden sections (per the player's toggles) are
  omitted at *write* time, so private data is never in the public key — the
  client cannot even attempt to see it.

Rejected alternatives:
- **Live cross-server request (MessagingService):** can't reach offline players
  at all, so still needs the snapshot as a fallback — strictly more complex for
  marginal freshness.
- **Raw `GetAsync` of the private profile store, filter on read:** reads the
  entire private profile just to strip it; couples viewing to the private
  schema; no clean privacy boundary.

### Snapshot write triggers (owner's server)

- On profile load (initial write).
- On any profile edit (showcase / status / chips / privacy) — immediate.
- On inventory or gems change — **debounced** (~few seconds, like the economy
  HotFlush) → recompute `portfolioValue`, re-filter showcase to still-owned,
  recompute derived chips.
- On leave (final write).

Debounce is required: inventory mutates rapidly during trades; an un-debounced
write-per-mutation would spam the DataStore. The debounce window is also the
freshness bound for an online target's showcase/value.

## Data model

### Private profile (`PlayerProfiles_v1`) — schema v1 → v2 migration

New fields (added by a `migrations[1]` function that bumps `SchemaVersion` to 2,
following the existing pattern in `DataService.luau`):

```
Showcase   : { string }          -- <=6 itemIds, player-ordered; {} => use default
StatChips  : { string }          -- <=4 stat keys; {} => default set
Status     : string              -- filtered "looking for" text, length-capped
Privacy    : { hideValue: boolean, hideShowcase: boolean }  -- default { false, false }
Lifetime   : { gemsEarned: number, trades: number }         -- default { 0, 0 }
```

`Showcase = {}` (empty) means "not customized → default scarcest-6".
`Privacy.hideShowcase = true` means "show nothing" — distinct from empty.

### Public snapshot (`PublicProfile_v1`, keyed userId)

Contains ONLY public data:

```
{
  userId, name, displayName,
  firstJoin,                    -- join date (from Meta.firstJoin)
  portfolioValue : number?,     -- omitted entirely if Privacy.hideValue
  showcase       : { { itemId, name, rarity, imageId, estValue } }?,
                                -- omitted entirely if Privacy.hideShowcase;
                                -- each entry re-validated still-owned at write
  statChips      : { { key, label, value } },   -- <=4, resolved values
  status         : string,      -- filtered; "" if none
  updatedAt,
}
```

No raw inventory. No private fields. Hidden sections absent, not nulled.

## Networking (new remotes — all rate-limited)

| Remote | Direction | Notes |
|---|---|---|
| `GetProfile(userId)` | RF | Cached snapshot `GetAsync`. Returns public subset. New rate-limit bucket. |
| `SetShowcase(itemIds)` | RF | Owner-only. Validate each owned + `<=6`. Triggers snapshot rewrite. |
| `SetStatus(text)` | RF | Owner-only. `FilterStringAsync` + length cap. Triggers rewrite. |
| `SetStatChips(keys)` | RF | Owner-only. Validate keys against allowed set + `<=4`. Triggers rewrite. |
| `SetPrivacy(toggles)` | RF | Owner-only. `{ hideValue, hideShowcase }`. Triggers rewrite. |

- **Server tab** lists `Players:GetPlayers()` client-side (not private) — no new
  remote. Row click → `GetProfile`.
- **Global tab** reuses the existing `SearchPlayers` remote (already resolves
  anyone who ever joined via `SeenPlayers_v1`). Row click → `GetProfile`.

## Self vs. other view

- **Self** (HUD Profile button): the edit screen reads your **live private**
  profile, so you always see your own hidden data and current inventory (for the
  showcase picker). Edits go through the `Set*` remotes.
- **Other** (from a browser row): reads the **snapshot**. Read-only + a Trade
  button. Trade button hidden/disabled when the target is offline.

## Correctness details

- **Showcase re-validation "still owned at render time":** at every snapshot
  write, the showcase is filtered to itemIds still in `Inventory` with count
  `>= 1`; others are dropped. `SetShowcase` also validates ownership at set
  time. An offline player's inventory is frozen (cross-server settlements to an
  offline recipient go to the Mailbox, claimed only on next login), so the
  snapshot stays valid while offline. An online player trading away a showcased
  item triggers a debounced rewrite that drops it within the debounce window.
- **Client never filters private data:** toggles applied at write time; the
  snapshot physically lacks hidden sections.
- **Status text:** `TextService:FilterStringAsync` (async) is mandatory —
  user text shown to other players is a Roblox ToS requirement, not just a
  length limit. Stored already-filtered.
- **Rate limiting:** `GetProfile` and every `Set*` remote get token-bucket
  limits in `TradeConfig.RateLimits`.
- **Offline resolution:** snapshot `GetAsync` works regardless of online state;
  identity also embedded in the snapshot (name/displayName) so no second lookup.

## Lifetime counters

- **`gemsEarned`**: incremented at the `InventoryService` gem chokepoint on
  positive gem inflows from real economic sources (trade, board payout, sell) —
  **excludes** the debug faucet (`source == "debug"`) so it reflects real
  earnings.
- **`trades`**: `+1` per settled trade per party. Online side incremented in the
  settle path; offline recipient incremented on mailbox claim. Idempotent via
  the existing `ClaimedIds` log so a retried/duplicated settlement never
  double-counts.

## Stat chips — allowed keys

Resolved server-side at snapshot write. Derivable (no new tracking) unless noted:

| key | label | source |
|---|---|---|
| `portfolioValue` | Portfolio Value | sum of item Est. Values (also the standalone aggregate) |
| `trades` | Trades | `Lifetime.trades` (new counter) |
| `gemsEarned` | Gems Earned | `Lifetime.gemsEarned` (new counter) |
| `mythicals` | Mythicals Owned | count of owned items whose rarity == Mythical |
| `accountAge` | Account Age | now − `Meta.firstJoin` |
| `distinctItems` | Distinct Items | number of itemId keys owned |
| `gems` | Gems | current `Gems` balance |

Default pinned set (player hasn't chosen): `portfolioValue`, `trades`,
`mythicals`, `accountAge`.

**Toggle interaction:** `Privacy.hideValue` suppresses portfolio value
*everywhere* — the standalone aggregate AND the `portfolioValue` chip (dropped
from `statChips` at write time even if pinned). `hideShowcase` suppresses only
the showcase. The `gems` chip is independent — not affected by `hideValue`.

## UI

- New `GuiBuilder` `ProfilePanel`: header (avatar, displayName, @username, join
  date), portfolio value (big number or "Hidden"), 6-tile showcase grid, stat
  chip row (≤4), status text, and either a Trade button (other) or edit controls
  (self: showcase picker reusing the existing item picker, status textbox, chip
  picker, privacy toggles).
- New HUD **"Profile"** button → own profile (edit).
- Player browser with **Server** + **Global** tabs → row → `ProfilePanel(userId)`.
- Runtime wiring in a new client controller/screen; layout/styling in
  `GuiBuilder` per the project pattern (runtime scripts only `WaitForChild` +
  wire, never rebuild).

## Testing

- **Pure units:** scarcity-sort default showcase (ascending circulating);
  filter-showcase-to-owned; public-subset projection honoring toggles (hidden
  sections absent, not nulled); stat-chip value resolution; status length/empty
  handling.
- **Studio integration:** self-edit round-trips to snapshot; view an online and
  an offline target; a traded-away showcased item disappears from the target's
  profile; hidden value/showcase absent from the fetched payload (not just
  visually hidden); rate limits reject floods.

## Future flags (not building)

- Report/block, "recently traded with", featured-badge — the snapshot schema can
  gain fields via the same additive pattern.
- If profile views become hot, add a MessagingService live-refresh on top of the
  snapshot (Approach B) as an optimization, not a replacement.
