# Second map (field areas) - design (rough, not built)

Status: design proposal. Nothing here is implemented. Supersedes the "Salvage Runs" idea (rejected: did not fit the game).

## Skeleton (from the owner's rough idea)
1. A second, prettier map, separate from the trading plaza.
2. Areas on it unlock by total worth (gems + item value).
3. Each area = one minigame + its own exclusive item pool spanning Common-Celestial (see design-second-map-areas.md for the rarity decision).
4. Reward = performance + RNG (performance sets the tier, RNG picks the item inside it).
5. All items come from the existing capped reserve. Gems are never produced (hard rule).

## Corrected connections (owner clarifications)
- **Roller is NOT area-constrained.** Rolling still rolls from all items, so a level-1 player can roll something usually only a deep-area player could farm. Luck stays a global possibility. Field items can be used as item payment for rolls (rolls already accept items); that is the only link.
- **Design principle: two paths to good items.** The global Roller is the high-ceiling LUCK path (costs gems or items, any item at any level, a level-1 player can hit something deep-area-tier). The field minigames are the reliable SKILL path (no gem cost, floor guaranteed, per-area pool ceiling). Players choose between them for exactly that reason, so the minigame must never out-pay the roll's ceiling (or the roll becomes pointless) and the roll must never be the only way to get good items (or the minigame becomes pointless). Tune pool ceilings and roll costs together.
- **Gem Store sells items, as it always has.** It does not sell gear or consumables. No area spotlight.
- **Unique Crafts draw inputs from the current area AND previous areas.** Offers are built from the union of the player's unlocked area pools.
- **Vertical asymmetric demand:** as a player progresses, UC requests increasingly ask for LOW-tier items in LARGE quantities. Low-level players farm/hold commons that high-level players need in bulk, which creates market flow across levels. (Current UC config: InputRarities Common/Rare, CountPerInput 1-3, InputValueFraction 0.45-0.7 - counts must scale with progression; output must stay worth more than inputs.)
- **Crafter** consumes field items as recipe inputs. Gear crafted at the Crafter is OPEN (owner has not decided).
- **Events** (crafting/sacrifice) are themed to field areas: weekly area event adds an exclusive item pool and event recipes at the Crafter that consume it.
- **Market/Board:** field output is ordinary tradeable items.
- **Worth bar:** field items count toward worth; worth unlocks areas (loop closes).

## Tutorial flow (target)
Starter reveal > portal > Area 1 (first run guaranteed good) > back to plaza > guaranteed-completable Unique Craft from starter + Area 1 haul > optional list/trade > repeat. Ends on an open loop: portal pulses, next area visible but locked with its pool shown, UC slot cooling down.

## Minigame rules (shared structure, different minigame per area)
- 60-120 s runs; instant re-entry; feedback every few seconds; reveal every 20-60 s.
- Pre-run choice (autonomy): loadout / route / risk tier. Deeper or riskier = better pool tier.
- In-run cash out or keep going every 60-90 s: stakes visible, outcome hidden, reward on a decaying curve.
- Soft fail: a bad run pays the guaranteed reward, never nothing. Hidden bad-luck counter guarantees a strong result after enough bad runs.
- Performance sets the reward tier; RNG only picks the item within the tier (never a bare lottery).
- Mastery rank per minigame (competence); shared area leaderboards, crew haul goals, optional co-op runs (relatedness).
- First run of Area 1 is protected and guaranteed good (first-30-seconds finding).
- Candidate minigames (Roblox-proven shapes): fishing-style cast and catch (bait/depth choice, tension management), falling items (lane choice, combo multiplier, cash out or keep going), tower climb (branching routes, safe points).

## Consumables (proposed addition)
Certain items crafted together at the Crafter make single-use consumables that improve odds. They burn the input items (a reserve sink), create bulk demand for low-tier items from earlier areas (vertical demand), and give runs a pre-run loadout choice (autonomy).
- Minigame effects: wider timing window, one extra cash out step, bad-luck protection-counter boost, bias within the reward tier, floor protection.
- Roll effects (optional, capped): small shift toward higher rarity bands or one guaranteed minimum rarity. Must stay small so the minigame never out-pays the roll ceiling and vice versa.
- Rules: small, single-use, recipes span several areas, never create gems or items, only shift odds.
- Open: tradeable or not; roll boosts at all or minigame-only (lean minigame-only first); crafted instantly or with a Crafter timer.

## Quest changes (proposed)
Ranks Noob/Casual/Regular/Trader unchanged; core trading/rolling/crafting stay unlocked; Bulk Buy (Regular), Booths + Syndicates (Trader) stay gated; quests grant no currency; areas unlock by WORTH (not quests) so quests teach the loop but never gate it.
New notify kinds: field_run, field_cashout, area_unlock, consumable, uc_complete (server-authoritative, called from the field minigame service; bots excluded).
Proposed chain (12 quests, 3 chapters):
1. Start (to Casual): open starter pack (auto); first field run; guaranteed Unique Craft from the haul.
2. Loop (to Regular): roll once (field items can pay); check an item's value in the Market; 3 field runs with at least one cash out; craft a consumable.
3. Trade (to Trader): post a trade ad; complete a trade; sell an item; unlock Area 2; complete a UC using items from two areas.
Dailies (after chain): N field runs, cash out once at depth, craft a consumable, fill one UC request. Weeklies: weekly area event, mastery rank, trade volume. Streak unchanged.
Code: schema bump + migration, existing progress preserved, `catchUp` completes any new quest whose count is already met.
Open: dailies pay consumables or progress-only; chain length; first field run before any trading quest (lean yes).

## Risks / open decisions
1. **Reserve drain:** new grindable item faucet needs sinks (per-run item fee, capped pools per area, diminishing returns per hour). Entry model undecided.
2. **Worth-gate exploit:** borrowing/buying an item to unlock permanently. Options: gate on lifetime earned worth, or accept (pool caps limit the real reward). Undecided.
3. **Rich-get-richer:** Area 1 must stay fun and pay for a long time.
4. **Build cost:** one minigame per area; launch with 3.
5. **Same place vs separate place:** same place (region) recommended to keep economy, trading and servers unified.
6. **Server-authoritative scoring** for every minigame (anti-exploit).
7. Gear from the Crafter: undecided.
8. Area themes and the first three minigames: undecided.

## Constraint checklist (every addition must pass)
- Pays in items/materials only, never gems (gems only from Robux purchase, rewarded ads at 10 gems per Robux, or player-to-player trades).
- Items only from the capped reserve.
- Built from existing systems where possible; no new standalone NPC/currency.
- Soft failure (Roblox-native), guaranteed first win, real gameplay (not an RNG button).

Research: see `research/addictive-loops-synthesis.md` and `research/addictive-loops-reference-full.md`.
