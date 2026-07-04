# Roblox Trading Game — Core

Core build of a player-to-player trading game: rotating starter item pools with
scarcity-derived rarity, a cross-server trade engine (items + gems, atomic,
simultaneous-confirm), live per-item stats (Value / Demand / Supply / RAP with
explicit N/A states), and persistent gem balances.

Design plan: [docs/plan.md](docs/plan.md). Managed
with [Rojo](https://rojo.space) 7.7.0 (via aftman). **Zero external packages** —
reactive state, signals, session-locked persistence, and the test harness are
all small in-repo modules.

## Layout

```
src/
  shared/            -> ReplicatedStorage.Shared
    Config/          Items (pool gen, rarity thresholds, weights), EconomyConfig, TradeConfig
    Enums, Types     wire enums + Luau types
    Util/            Signal, State (mini reactive layer), Guard, WeightedDraw,
                     RollingAverage, RateLimiter, Rarity
  server/            -> ServerScriptService.Server (Script)
    Net              remote registry (only place remotes are created)
    Stores/          StoreAdapters (DataStore/MemoryStore/Messaging with
                     in-memory mock fallback), SessionStore (session locking)
    Services/        DataService, InventoryService, EconomyService, PoolService,
                     StarterService, TradeCore (pure state machine), TradeService,
                     RateLimitService, AnalyticsService
    Tests/           TestRunner + suites (pure logic, trade state machine)
  client/            -> StarterPlayer.StarterPlayerScripts.Client (LocalScript)
    Net              client remote access
    Controllers/     Inventory / Economy / Trade (reactive State mirrors)
    UI/              Theme, Components, HUD, InventoryScreen, TradeScreen
```

## Workflows

**Build + open:**
```bash
rojo build -o place.rbxl default.project.json
```

**Live sync while editing:** install the Rojo Studio plugin, then
```bash
rojo serve
```

**Push into an already-open Studio session without the plugin** (what the MCP
agent workflow uses): `rojo build -o sync.rbxm sync.project.json`, copy the
rbxm into the Studio version `content/` folder, then in Studio run the import
snippet (destroys + re-parents `Shared`/`Server`/`Client` from
`game:GetObjects("rbxasset://trading_sync.rbxm")`).

**Tests:** in Studio (Edit mode) run
```lua
print(require(game.ServerScriptService.Server.Tests.TestRunner).run())
```

## Studio vs live behavior

`StoreAdapters` probes DataStore access at boot:

- **mock mode** (Studio without API access): all three backends run in-memory,
  single-server semantics, messaging is loopback. Everything works offline;
  data resets each play session.
- **live mode** (published place, *Enable Studio Access to API Services* on):
  DataStore (durable), MemoryStore (hot cross-server state + CAS reservations +
  trade records), MessagingService (invalidation pings).

Cross-server trading, pool rotation election, and RAP/demand sync are only
truly multi-server in live mode; the code path is identical in both.

## Tuning

Everything intentional lives in `src/shared/Config/`:

- `Items.luau` — starter bundle size (K=4), starter gems (100), rarity
  thresholds (Common ≥750 / Rare ≥300 / Legendary ≥100 / else Mythical),
  assignment-weight formula (`supply^0.75`), initial placeholder pool,
  procedural pool template + name parts for rotation.
- `EconomyConfig.luau` — demand half-life, value formula constants, N/A
  minimum-data thresholds, flush/broadcast cadence.
- `TradeConfig.luau` — kill switch, slot/gem caps, timeouts, per-remote rate
  limits.

## Known accepted risks (core phase)

- Crash in the tiny window between a durable escrow save and the trade-record
  CAS can strand one side's deposit (logged; journal recovery is future work).
- Starter reserve copies leak (never circulate) if the server dies between the
  reservation CAS and the profile save. Logged, tolerable at core scale.
- `SessionStore` is a minimal ProfileStore-equivalent; swapping in
  loleris/ProfileStore later only touches `DataService`.
