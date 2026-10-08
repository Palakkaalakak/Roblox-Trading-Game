# Second map - how the areas work (design, not built)

Companion to `design-second-map.md` (connections, quests, consumables) and `design-minigame-rubric.md` (how we score it). Areas are named Area 1, Area 2, Area 3 (no themed names). All numbers are TBD and tuned against the rubric. Hard rules: rewards are items/progress only (never gems), items come only from the capped reserve, soft failure, first run guaranteed good, server-authoritative.

## 1. Shape of the place
- **Same place, a separate region** (not a second Place) so trading, the economy, servers and DataStore stay unified. Players teleport between the plaza and the field hub inside the same server.
- **Field hub:** a prettier shared space with a gate per area, per-area leaderboards, a mastery wall, and a rare-find ticker. Other players are visible here (social proof, status), but **runs are solo instances** (no counterparty needed, no griefing).
- **Gates show everything:** locked/unlocked state, the item pool preview, your mastery rank, and your distance to the unlock (worth bar with endowed head start).
- A permanent portal back to the plaza; the plaza gets a matching portal. No loading screens.

## 2. Area ladder and rarity (DECIDED: option A)

**Every area has its own Common to Celestial ladder, and items in a deeper area are worth more than the same rarity in the area before.** An Area 3 Common can be worth more than an Area 1 Godly. How much more per area is set by the owner (their example: about 100x).

Why A and not "more rarity tiers" (option B): rarity comes from how few copies exist (Items.RarityThresholds from totalSupply), and the rarest items have only about 40-80 copies. New top tiers would have even smaller supplies, which a repeatable minigame would hand out in hours. With A, an area's Common items stay plentiful (so the minigame can keep paying) but are worth more because of the area, not because they are scarce.

What this means:
- Each area has its own set of items (about 14, a mix of Common to Celestial) with their own supply.
- Area N's items are worth more than Area N-1's, by a set multiplier per area (TBD by owner).
- The Roller stays global and can still hit any item in any area, so a low-level player can get lucky.
- Early-area items are cheap, so later Unique Crafts and consumables ask for them in large counts.

Implications (to build): item value needs an area multiplier on top of rarity, and the Roller must price by item value instead of by rarity so area items fit its price windows. Current rarity supply counts (e.g. Celestial ~40-80 copies) are placeholders and will be raised; the cashout amount is also a placeholder.

| Area | Verb | Value level | Gate (placeholder) |
|---|---|---|---|
| Area 1 | cast and catch | lowest | open from minute one |
| Area 2 | falling items | higher | peak worth >= TBD and Area 1 mastery 2 |
| Area 3 | tower climb (verb under review) | higher again | peak worth >= TBD and Area 2 mastery 2 |

- **Dual gate:** peak worth (server-computed, ratcheted) AND a mastery rank in the previous area.
- Old areas stay playable; deep players earn little value there, so they buy early-area items from newer players.

## 3. Shared run structure (every minigame uses it)
1. **Pre-run (autonomy):** pick risk tier (Easy / Normal / Hard), a route or style, and optionally one consumable. Entry cost is paid here. Loadout locks.
2. **Run (75-120 s):** 3 stages, 2 safe points (a decision about every 40-60 s, inside the 60-90 s research band once the run is chained). Each stage has its own mini-objective. At a safe point: cash out what you have, or keep going to the next stage. **Every stage end pops a visible cashed-out item/value tick**, so the first reward lands ~20-25 s in (first-30-seconds rule). Value multiplier curve decays: x1.0 > x2.5 > x4.0 (+150% then +60%).
3. **Risk meter** is always visible (stakes shown, outcome hidden). Pushing past a threshold risks the *uncashed-out* portion only.
4. **Failing a stage is decided by skill, not dice:** you fail if you miss the *next stage's objective* (miss the tension window, hit the junk, fall). Harder stages and Hard difficulty raise the skill bar. Uncashed-out bonus is lost; **the cashed-out portion and the guaranteed reward are kept**. Nothing already earned or owned is ever lost. Tune so going further is usually the wrong call for an average player but obviously right for a skilled one (regret loop, competence).
5. **Results:** staged reveal, what advanced (mastery XP, bad-luck protection, gate bar), and one near-complete goal. One click to run again.
- **Feedback cadence:** tick every 1-6 s, reveal every 20-60 s, escalation beat every 60-90 s. Reward cue (sound, glow, silhouette) fires slightly BEFORE the item reveal; pitch/size escalate per clean action; partial results get a real (floor) celebration.
- **Optional Hard difficulty:** higher entry fee, higher multiplier, and a smaller guaranteed reward if you fail. Easy/Normal keep the full guaranteed reward. This gives players who want real stakes a hard-mode choice (autonomy) without forcing hard loss on everyone (Roblox hits are soft-fail; Steal a Brainrot's hard loss drew the most anxiety).

## 4. Reward model (same formula, different pools)
- **Score S** from performance (stage clears, accuracy, cashed-out depth, risk tier). Server computes it.
- **Tier from S:** thresholds map S to Floor / Good / Great / Jackpot-eligible.
- **Item within tier:** RNG over that tier's weights from the area band. Performance never rolls the dice on tier; RNG never decides tier.
- **Floor:** every run pays at least the lowest reward tier (soft fail).
- **bad-luck protection:** hidden counter of runs below Good. At threshold N (TBD ~8-12) the next Good-or-better run is upgraded one tier. Never shown as a number.
- **Jackpot:** small chance on Great+ for the top of the area band, announced server-wide.
- **Reserve:** every payout reserves a copy via the reserve (like rolls). If a rarity is out of stock, the pick falls back down the tier ("restocking" handling) and never mints items.
- **Two-path calibration:** expected value per minute of the best minigame run stays below the Roller's high-end outcomes but with far lower variance; tuned with the rubric row B2.

## 5. Launch minigames (verb, choices, decisions)
**Area 1 (cast and catch):**
- Pre-run: bait (changes which items bite), depth (deeper = better band, harder tension).
- Run: cast, a bite window, then a tension-bar minigame (keep the line in the sweet spot).
- Stage = one fish. Checkpoint after each: cash out the catch or keep casting at rising line-snap risk.
- Mastery unlocks: new spots, finer tension window, rare bait slots.

**Area 2 (falling items):**
- Pre-run: lane/zone and style (wide net vs precision).
- Run: items fall; collect valuable ones, dodge junk; combo multiplier rises per clean catch, junk resets it.
- Stage = a wave. Checkpoint after each: cash out the combo or keep going into a faster, denser wave.
- Mastery unlocks: new zones, longer combo caps, magnet tools.

**Area 3 (tower climb):**
- Pre-run: route (safe path vs risky shortcut) and starting height.
- Run: platforming with branching routes; safe points are real safe points.
- Stage = a floor band. Falling returns you to the last safe point (keeps cashed-out floors).
- Mastery unlocks: shortcuts, extra safe points, grapple tools.

All three obey the same structure, so mastery, bad-luck protection and risk language feel shared.

## 6. Mastery and status
- **Mastery rank per area** (1-5) from run XP. Ranks add *options* (routes, tools, risk tiers), not just bigger numbers.
- **Leaderboards per area** (weekly and all-time) and a mastery badge shown over the character (feeds the existing floating title system).
- **Rare finds:** server-wide announcement plus a hub ticker (clip moment).

## 7. Economy safety
- **Faucet controls:** per-run entry cost (small, from the area band so it burns a few commons), per-area item caps, **diminishing returns per hour** (soft; recovers), reserve-aware payouts.
- **Sinks:** entry costs, consumables (burn items), gear crafted at the Crafter (optional).
- **Vertical demand:** UC requests and consumable recipes ask for large counts of low-tier items from earlier areas as players progress, and deep players earn less per minute farming them, so commons flow from newer players to deeper ones through the market.
- **No bots** progress or farm (userId < 0 excluded); sim players never touch the reserve.
- **Gem rule:** nothing here mints gems. Gems only leave players (entry upgrades are items, not gems).

## 8. Events
- **Weekly area event:** one area gets a modifier (for example wider Hard risk with a bigger multiplier) and an exclusive event item pool.
- **Event recipes at the Crafter** consume the exclusive items; **Unique Craft** offers in event weeks bias toward the event area's pool, tailoring UC to the map.
- Staggered clocks (UC cooldown, event window, rotation) give the appointment layer.

## 9. Server architecture (sketch)
- **FieldService (new, server):** owns run sessions. `StartRun(areaId, loadout)`: checks unlock, charges entry, locks loadout, creates a run with a server seed and expected timeline. `Checkpoint(runId, choice)`: cash out/keep going, validated against minimum plausible times. `EndRun(runId)`: computes S, tier, item pick (reserve), grants through InventoryService with a Field grant source, updates mastery/bad-luck protection/stats on the profile, notifies QuestService.
- **FieldConfig (shared):** areas, bands, gates, tier thresholds, curve, bad-luck protection N, entry costs.
- **Profile fields (DataService, schema bump):** area mastery XP, bad-luck counters, unlocked areas (derived from worth + mastery, re-checked server-side), per-hour run window.
- **No extra DataStore calls per run:** everything rides the existing profile save.
- **Client:** FieldHub screen/portal, per-minigame client modules sharing a RunUI (risk meter, safe point prompt, results), built to the UI style used elsewhere. Client reports inputs; the server decides outcomes.
- **Anti-exploit:** rate limits, minimum run durations, server-side score from reported events, replay logs.

## 10. Build order
1. Shared run structure + RunUI + FieldService with one placeholder minigame and the reward model.
2. Area 1 minigame fully built; first-run guarantee and tutorial flow.
3. Hub, gates, unlock logic, leaderboards.
4. Quest kinds and chain rewrite; Crafter/UC hooks and consumables.
5. Areas 2 and 3; events.
6. Telemetry and rubric scoring pass.

## 11. Open decisions
1. Entry cost model: per-run commons fee vs timed tickets vs free runs with diminishing returns (lean: small fee plus diminishing returns).
2. Gate: dual (peak worth + previous mastery) as proposed, or worth only.
3. (Decided: every area has the full six-tier ladder.)
4. Optional co-op runs: launch or later.
5. Gear crafted at the Crafter: yes/no.
6. Real names and art direction for areas.

## 12. Review against the research (changes applied above and below)
1. **Run structure was too dense.** 3-4 safe points in 60-120 s over-shot the 60-90 s decision cadence. Now 3 stages / 2 safe points, with a cashed-out-item pop every stage so rewards arrive early.
2. **Failing a stage must be skill, not RNG.** Random failures would make it gambling. You fail by missing the next stage's objective; RNG only picks the item inside the earned tier.
3. **First 30 seconds.** First-ever run is shorter (about 45 s, 2 stages, guaranteed Good), first item pops at ~20-25 s, nothing can fail it.
4. **Appointment layer was weak.** Added **Lucky Hour events**: every ~60 min a 10-15 min server-visible window where one area has a boosted rare chance and a hub ticker (Blox Fruits hourly spawn / Fisch event windows / Grow a Garden restock rushes). Gives staggered hours-scale clocks alongside the UC cooldown and weekly event.
5. **Offline hook missing.** Grow a Garden's credited hook is offline progress. Proposal (needs a decision): the existing AFK pads feed hidden bad-luck protection progress and a small capped entry-fee discount while away, never items or gems directly. Items stay run-based.
6. **Economy: recirculation is not a sink.** Entry fees returned to the reserve just recirculate. Real sinks are permanent burns: consumable crafting, Crafter recipes, UC consumption. Fees remain useful (they keep commons moving) but the faucet must be tested: run the existing sim players against a field payout model before shipping, and allocate a field share of each band's reserve so rolls do not hit "restocking".
7. **Worth gate must be server-computed.** The cashout bar's worth is client-reported (display only). Gating needs a server worth function (inventory x `EconomyService.valueOf` + gems, cached, ratcheted into the profile). Mastery-rank half of the gate is cheap to tune: rank 2 should take about 5 runs.
8. **Anti-exploit by minigame.** Tower climb (movement) is the hardest to validate server-side. Prefer a deterministic or server-timed Area 3 verb, or validate with server physics and replay logs; decide before building it.
9. **Scope.** Research (Tizzy, Roblox hits) favours simple loops shipped fast. Ship a **vertical slice first**: hub + Area 1 + run structure + reward model + first-run tutorial. Do not start Areas 2-3 until Area 1 scores Applying on every starred rubric row and telemetry shows the funnel works.
10. **Relatedness at launch:** hub presence, leaderboards, rare-find ticker, Lucky Hour crowds, crew haul goals. True co-op runs later.

Gem-rule re-check (all of the above): pays items/progress, never gems.
