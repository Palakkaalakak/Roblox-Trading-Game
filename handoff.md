# HANDOFF — read fully before touching anything

Roblox trading game (Rojo + Luau `--!strict`), repo root = this folder, branch `feat/trade-ads`.
Player-facing: trade board (swap ads / market / bulk buy), gacha rolls, events/crafting, gem store, booths, syndicates, community Robux-rewards bar, quests/ranks.

## 0. The user (most important)
- **Ultra credit efficiency is a hard requirement.** Cheap, few calls, batch reads, no re-exploration, no essays. Terse replies (caveman ultra).
- Hates: asking permission for obvious next steps, stopping without doing, unverified "done" claims, dumping raw console logs, restarting Play needlessly.
- Wants: things done, verified by **screenshot**, and Studio kept in sync (see §2). Never claim done without checking.
- Design for **players**, not bots. Bots/sims are test aids; never reshape player-facing economics for them.
- Use Roblox lingo/culture in copy (Noob, Pro, Sweat, OG…). **Search before guessing cultural things.**
- Model guide: **Sonnet 5 medium** for UI/config/mechanical edits. **Opus 5.5 medium** (cheaper+faster than Opus 5: $4/$20 per M, ~30% faster, ~40% less cost at default effort) ONLY for: architecture changes (e.g. DataStore redesign), a bug not localised after 2 attempts, new multi-service system design. Never ultracode/high unless told.

## 1. Tools/plugins you MUST use
- **caveman ultra** (`/caveman ultra`): terse output always.
- **context-mode** (`ctx_batch_execute`, `ctx_execute_file`, `ctx_search`): for reading/analysing big files or many greps. Only printed output enters context. Writes must use Write/Edit (ctx_execute cannot persist edits).
- **RTK** hook rewrites shell cmds. `rg` is NOT on PATH in Bash → use the **Grep tool** (not bash grep).
- **Read tool shows one extra leading tab** vs real file indentation. Copy Edit `old_string` indentation from the real file (1 tab less than shown) or Edit fails.
- **Bash heredocs mangle backslashes** (`\n` inside Python strings became real newlines). For Python splice scripts: write the script with the **Write tool** to the scratchpad, then run it. Use `chr(10)`/`chr(92)` if needed.
- Batch independent tool calls in ONE message.
- Don't call `get_console_output` raw (huge). Filter via `LogService:GetLogHistory()` in `execute_luau`.

## 2. Studio / Rojo workflow (constant pain — read)
- Rojo live-syncs source → Studio **only for edits; a running Play does NOT pick up changes**. To test: `start_stop_play false` → `true` (restart Play). Verify sync with `script_grep`.
- **Studio id changes** after reconnects; call `list_roblox_studios` when a call says "not connected".
- `start_stop_play` often gets a **stale start job** ("Start play hasn't finished yet"). Waiting doesn't help. Ask the user to press **F5**, or wait for a new studio id.
- `execute_luau` calls >~50s time out (split waits). `datamodel_type` required: Edit/Client/Server. Server datamodel is unavailable in Edit mode.
- `execute_luau` runs in a **separate module cache**: services required there are uninitialised. Read live state via **ReplicatedStorage attributes** (`Liq*`, `Sim*`, `Eco*`, `Bot*`) or the STATS panel. Don't call TradeBoardService.rawOpenListings etc. from it.
- `getconnections`/`firesignal` unavailable. Click UI via `user_mouse_input` (`mouseButtonClick`, `mouse_button:"left"`, coords from `AbsolutePosition`; often "hits CoreGUI"/unreliable) or set `.Visible` directly for panels.
- **GuiBuilder changes must be mirrored into live Studio** (StarterGui, Edit datamodel) — skill `gui-code-to-studio`. Lazy panels (Rolls/Shop/Syndicate) are built on first open via `GuiBuilder.ensurePanel`; ShopScreen etc. expect specific child names (e.g. `ShopPanel.CloseButton` must be a **direct child**).
- Screenshot: `screen_capture` needs a `capture_id`. Use skill `verify-ui` for UI work.
- Parse errors in any required module kill server boot. After big edits restart once and check errors.

## 3. Architecture (server: `src/server`, client: `src/client`, shared: `src/shared`)
Services registered in `src/server/init.server.luau` (order matters). Key ones:
- **DataService**: player profiles (session-locked DataStore `PlayerProfiles_v5`). Schema **v10**; `template()` + `migrations[n]`. New fields → add to template AND a migration. `getProfile(player)` returns `.Data`.
- **EconomyService**: per-item records (`EconomyStore_v6`, key = itemId): supply/reserve/circulating/burned/demand/RAP. `hotCache`, `getRecord` (read-through GetAsync), `snapshot` (uncached read-through!) vs `snapshotCached`, `warmCache` (background paced pre-load), `isWarm()`. Value = base×scarcity(burned)×demand, **never reads RAP**. Growth = goods entering via rolls / gem store NPC / event NPC.
- **TradeBoardService**: listings kinds `swap`(give/want bundles, autoTrade), `sell`, `bulk`(gem buy order), **`bulkbuy`**(item-for-item standing order, unitIn+payout), scope server/global, `crossTerms`, `settleChain` (N-party, journalled), `tryMatch` (bilateral mirror on post). Rank gate: bulkbuy posts need `QuestService.hasUnlock(userId,"bulkbuy")` (bots exempt).
- **LiquidityService/LiquidityCore/LiquidityConfig**: chain-trade facilitator. Bot is an **orchestrator, never a counterparty, never holds stock, never creates gems**. Levels OFF/LOW/MEDIUM/HIGH (debug button, `DebugSetLiquidityLevel`). **DryRun=true — no executor yet** (Phase 5). Solver = pooled give ≥ pooled want per key (gems key `"\0gems"`). Sees board legs + **NPC legs** (gem-store shelf, active event recipes; never seeds, never absorbs leftovers). Publishes `Liq*` attributes. Unit tests pass (`LiquidityCoreTests`); **chains still 0 live** (sim demand shape; real players should differ).
- **SimPlayerService/SimPlayerConfig**: 450 simulated players (Gode–Sunder-style heterogeneous agents; Universe=60 items; single-kind gives; goals tried last). DEV/TEST only. Gated on `EconomyService.isWarm()`. **BotService**: older archetype bots + leader-elected sweep hooking Liquidity/Sim.
- **QuestService/QuestConfig/RankConfig/ProfitTitleConfig** (REWORKED, see `docs/design-progression.md`): core chain = 9 quests, 3 chapters -> ranks Noob/Casual(3)/Regular(6)/Trader(9). Core strategy (roll/craft/market/board/trade/gem store) is NEVER locked. Milestone unlocks only: Bulk Buy (Regular), Booths + Syndicates (Trader), enforced server AND client (`QuestService.hasUnlock`, `RankConfig.unlocked`). **Quests grant nothing (no gems, no Rep; Rep/claim/streak-bonus removed).** Planned rewards = better offers from existing NPCs (gem store slots/restock, crafter slots/recipes) - NOT built. Robux skip (`quest_skip`) still completes the current quest. Quests are NOT part of the tutorial; the tutorial is separate (TutorialGuide/StarterRollScreen/EventsScreen). `notify` kinds: starter (AckStarterReveal), craft, roll, market_check (GetItemBook), post_trade, complete_trade, sell, bulk_contribute. `catchUp` completes already-met quests; ProfileLoaded clamps `completed` to chain length. After the chain: Daily+Weekly (`setsUnlocked`) - content TBD by user, currently reward-free, streak only. Profit titles (120, `Lifetime.gemsEarned`, effects not built). Title attrs `RankTitle`/`RankId`/`RankTier` -> `RankTitleController` billboard (Noob/Casual white).
- **ProductService**: single owner of MarketplaceService.ProcessReceipt; offers in `MonetizationConfig.Offers` (grants gems/items/adPerk/adSlots/boothSlot/questSkip). User owns ad passes → their ads are always boosted (not a bug).
- **Other**: RollService (gacha), CraftingService/EventConfig (recipes), UniqueCraftService, StoreService (limited gem store), BoothService, SyndicateService, RewardsService (Community Robux bar), AfkService, NotificationService, Leaderboards, StarterService (first-join reveal).
- **Client**: controllers in `src/client/Controllers`, screens in `src/client/UI`, `init.client.luau` wires everything. `BulkBuyScreen` (code-built tab + order builder using TradeScreen's item picker via `TradeScreen.pickItem`), `MonitorPanel` (admin STATS button: auto-lists all `Liq/Sim/Bot/Eco` attrs), `AdminPanel` (debug buttons), Quests panel = `src/client/UI/QuestsScreen.luau` (hero card + 5-tile board; post-chain: Daily/Weekly tabs), wired from `init.client.luau` over the `RewardsPanel` shell (same size as Shop 0.66x0.84 max 900x700, original dark colours). HUD toasts live in a top ScreenGui `ToastOverlay` (DisplayOrder 150), background-free coloured text. Remote `Notify(text, color?)`.
- Robux Rewards bar/Conversion panel now uses **portfolio worth (gems + item values)**; note tells players to cash out items.

## 4. DataStore — REDESIGNED (done, verified)
Old design (one DataStore key per item, per-item GetAsync on cache miss, cache dropped on every cross-server ping) caused constant throttling. Now in `EconomyService`:
- Item records packed into **4 shard keys** (`EconomyShards_v1`, "s1".."s4", `shardOf(itemId)` hash). **Boot reads 4 keys → whole economy in memory.** `getRecord`/`snapshot`/`valueOf`/`snapshotCached` are **memory-only** after that (no caller changes needed). Never add a DataStore read to a read path.
- `flushDirty` (every `HotFlushIntervalSeconds`=60): one merged `UpdateAsync` per shard (per-item last-writer-wins by `updatedAt`); the returned merge is how other servers' changes arrive. Broadcast pings no longer drop the cache.
- `mutateRecord` (strong CAS: `retireCopies`, `resetItem`) now CASes the item's shard. `resetAllItems()` = 1 write per shard (admin reset).
- **Legacy migration**: items in no shard are read once from old `EconomyStore_v6` (paced 1 per 3s, background), marked dirty, flushed into shards; `warmed` flips true after. First boot ≈150 calls, later boots ≈4 + migration tail. `isWarm()` gates Sim/Liquidity NPC legs.
- Counter attribute **`EcoDsCalls`** (in STATS panel) = every DataStore call the economy service makes. Verified: 0 throttle lines, 16 calls in first 30s of a warm boot.
- `StoreAdapters`: `awaitBudget` gate (uses `GetRequestBudgetForRequestType`, reserves budget for player profiles; "Economy"/"Leaderboard" stores are background priority) + in-flight read dedupe. Keep.
- Other DataStore users (profiles, syndicates, leaderboards, board) untouched. Profiles remain the throttle-sensitive path — keep their calls minimal.

## 4b. Existing gem sources (CHECK BEFORE DESIGNING ANY LOOP)
Not only trading: **Free Gems / rewarded ads** (`AdConfig`, `FreeGemsScreen`, `WatchAd`): all numbers in `AdConfig` (50 gems per ad, 5/day, 120s cooldown, 20% referral bonus for the first 15 watches) are **PLACEHOLDERS, amounts TBD by the user**. Design around the mechanism, never around the number. Locked until the game passes 2,000 monthly visitors (Roblox rule), so until then it is a community-goal progress bar. Paid via ProcessReceipt. Also: Robux gem packs (Shop; the paid Starter Bundle is commented out), AFK ladder (`AfkConfig`, reward TBD), trading. The FREE one-time first-join starter grant (`StarterService`: items only, `Items.StarterGems` = 0) is a one-time seed, not a repeatable faucet. Ad gems are Robux-backed (Roblox pays us), so they are the ONE legitimate gem faucet.

## 5. Known issues / pending
- **Shop panel blank/slow** after ShopPanel edits: probably the old per-item read stalls (now fixed) but NOT re-verified. Open Shop first thing; if still blank check `ShopScreen.wire` + server payload.
- Chains = 0 live with sims. Real players untested. Phase 5 (executor beyond DryRun, scale to 1000, OFF vs ON experiment) not built.
- Trade Ads greyed Accept + BulkBuy shared picker + Quests panel verified by screenshot; Shop after edit NOT re-verified.
- Profit-title **effects** (gradients/strokes/VFX per tier) not built — `tier` field reserved.
- Quest panel: quest completion isn't pushed to client (20s poll in `QuestController`).
- 3 pre-existing failing tests (PureLogic copy cap, TradeAds featured slots, schema-bump test).
- Placeholder Robux product ids everywhere (`PLACEHOLDER_PRODUCT_ID`).
- `.claude/skills/gui-code-to-studio` and `verify-ui` exist — use them for UI work.

- Tutorial (in progress, user-owned flow): starter reveal -> Crafter NPC (renamed `CrafterNPC`, prompt "Crafter") -> Unique Craft (stuck-arrow bug FIXED via `TutorialGuide.Stopped`). NEXT: continue after the unique craft. Rule: **gems can never be handed out** (no gem faucet; sim buyers must not mint gems), so proposed loop = item -> craft -> Market value -> roll paid with an ITEM (rolls accept item payment) -> new item -> Quests button pulses. Not built; user has not approved yet.
- Splice recipe (Rojo often disconnected): `rojo build sync.project.json -o sync.rbxm`, copy to every `%LOCALAPPDATA%\Roblox\Versions\*\content\`, then in Edit `game:GetObjects("rbxasset://sync.rbxm")` and replace Server/Shared/Client (purge ALL old copies; Client goes to StarterPlayerScripts AND ReplicatedStorage).

## 5b. Core-loop design state (see `docs/design-progression.md`, section "Core loop")
- Goal: simple, quick, addictive loop for ~20 min/day (about 3 check-ins of about 7 min). Trading uncertainty must be the hook, not the obstacle.
- **This is OUR game: copy others only where it makes the game more successful.** Our unique hook = values move visibly with scarcity/demand (burns, crafts, events) and players watch it happen in-game (other trading games keep values on outside sites). Proposed loop: read the market (market-watch strip: what is moving) -> act (roll/craft toward it; crafting burns supply and raises value) -> watch worth change ("+N worth" pops) -> cash out or hold -> return for clock-aligned rotations (Gem Store 5-min, Crafter events).
- Solo fuel gap before 2,000 visits (no ads): proposed non-tradeable, non-convertible Roll Tickets (about 1 per 8 min, cap 3, common/rare pool from the same capped reserve). After ads unlock, tickets overlap with ad gems, so keep them small. NOT decided/built.
- Peripheral unlocks via quests: AFK zones (idle tickets/intel), Bulk Buy, extra Unique Craft slots, Booths, Syndicates. Quest rewards = better offers from existing NPCs, never currency.
- Tutorial last beat under discussion: market-watch strip + "+N worth" pop (recommended) vs an item-paid roll. Awaiting user decision. Nothing above is built.

## 5c. Second map + research (saved to files, read these first)
- `docs/design-second-map.md`: current design of the second map (field areas, one minigame + item pool each, worth-gated). Roller stays GLOBAL (all items), Gem Store sells ITEMS only, Unique Crafts draw from current + previous areas with large low-tier counts at higher progression (vertical demand). Not built.
- `docs/research/addictive-loops-synthesis.md` (digest) and `docs/research/addictive-loops-reference-full.md` (full cited reference).
- `docs/design-progression.md`, `docs/game-overview.md` (game description in owner's voice).
- Rejected ideas: Salvage Runs (does not fit), NPC buy-back for gems (violates gem rule), bare push-your-luck/RNG layers (gambling is not gameplay).

## 6. Standing rules (from memory)
UI icons: use **Workspace › Simulator Icon Pack** decals (e.g. `Menus/Quests` = `rbxassetid://17368118782`), standardise gem icon. MemoryStore quota is experience-wide (~64KB total): sim/bot data stays in server memory. Bots are ephemeral/in-memory, never mutate durable economy reserve. GUI changes always spliced into live Studio too. Verify UI by screenshot and time actions. Credit efficiency + game performance always.
