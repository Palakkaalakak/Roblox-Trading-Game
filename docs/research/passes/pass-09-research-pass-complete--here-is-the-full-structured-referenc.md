Research pass complete. Here is the full structured reference document. Everything is tagged **[scholarly]**, **[developer-primary]**, or **[community/YouTube-secondary]**, and anything I could not verify to a number is marked *unconfirmed* rather than guessed.

---

# Mechanical Anatomy of Addictive Push-Your-Luck Loops
### A cross-genre reference document for a Roblox solo extraction/salvage activity

---

## SECTION 1 — THE CLOSEST ANALOGUES (deep treatment)

### 1.1 Escape from Tarkov — the canonical "lose everything" loop

**Session/run length.** Raids are self-contained **10–40 minute sessions**, with per-map raid timers ranging from ~20 min (Factory, reduced from 35 min in a documented patch) up to ~45–50 min (Interchange, Reserve). Battlestate actively tunes these timers downward or upward per map, and community response to timer cuts is intense — evidence that the raid timer *is* the tension dial. **[community/YouTube-secondary: Fischer design essay](https://fischerdesign.medium.com/tarkov-breaking-the-rules-ae67fde10848); [r/EscapefromTarkov timer discussion](https://www.reddit.com/r/EscapefromTarkov/comments/eryi07/new_total_raid_times/); [official wiki: "Run Through" requires ≥7 min in raid or ≥200 EXP](https://escapefromtarkov.fandom.com/wiki/The_Guide)**

**Stakes-escalation curve.** Escalation is *inventory-value-driven*, not scripted: your backpack fills, so the value at risk climbs continuously while the extraction distance doesn't shrink. Audio is the escalation cue system — noise discipline is a player-controlled dial (movement speed steps change your noise radius), so the player self-modulates risk and *feels* the escalation in their own behavior. **[community/YouTube-secondary: Fischer](https://fischerdesign.medium.com/tarkov-breaking-the-rules-ae67fde10848)**

**Stop-or-continue decision points.** Continuous rather than discrete: health, ammo, food/water, distance to extract, value already carried, and auditory intel on other players are the visible state at every decision. The decision is *informed but never certain* — you know what you carry, you never know who's left. **[community/YouTube-secondary: Fischer](https://fischerdesign.medium.com/tarkov-breaking-the-rules-ae67fde10848)**

**Failure split (the key tuning).** On death you lose **everything carried** except items in the **secure container** (a small fixed grid — the most contested mechanic in the game; a large player contingent argues it undermines the game's core identity because it insulates loot from risk). Insurance returns uninsured gear after a delay *only if nobody looted it*. So the split is: **~2–9 slots kept, everything else lost**. The deliberate design lesson: the keep-fraction is tiny but non-zero, which makes every death survivable emotionally while keeping every raid lethal financially. **[community/YouTube-secondary: r/EscapefromTarkov secure-container debate](https://www.reddit.com/r/EscapefromTarkov/comments/m8q7hc/you_should_not_be_allowed_to_put_any_item_inside/)**

**Why it hooks (secondary synthesis).** Long low-activity stretches punctuated by rare, high-magnitude spikes; the spikes carry more weight *because* the baseline is quiet. Critically: **when a player's stash overflows, the emotional impact of loss erodes** — scarcity perception is the engine, and wealth accumulation is the enemy. One essayist reports the spike moment arriving "maybe 10 minutes in" to a raid, and a single pivot raid moving inventory value to ~4.5M — the anecdotal shape of the variance. **[community/YouTube-secondary: soma., "Why Extraction Shooters Are So Addictive"](https://www.youtube.com/watch?v=fODPG2RDGLg)**

---

### 1.2 Hunt: Showdown — discrete "bank it or fight for more"

**Session length.** Bounty Hunt: **45 min hard cap**, auto-ending 5 min after all bounties are extracted. Bounty Clash (the compressed variant): **15 min**. The 15-minute variant exists precisely because the full loop's pacing was too slow for some retention profiles. **[community/YouTube-secondary: official Hunt wiki](https://huntshowdown.fandom.com/wiki/Game_Modes)**

**Stop-or-continue.** The genre's cleanest discrete decision: kill the boss → take the bounty (which **broadcasts your position on the map to every other player**) → walk to extract. Taking the bounty is opting into being hunted. Extraction itself takes **30 seconds** standing in the zone — 30 seconds of deliberate, announced vulnerability. That 30-second exposed channel is a mechanic worth stealing whole: extraction is never instant, it's a held breath. **[community/YouTube-secondary: wiki](https://huntshowdown.fandom.com/wiki/Game_Modes); [Steam community: extraction timing](https://steamcommunity.com/app/594650/discussions/8/6278597937782761851/)**

**Failure split.** On death: **lose the Hunter and all equipment; keep half XP**; unlock-track XP is unaffected. A sharper split than Tarkov (you lose a leveled character, not just gear) softened by guaranteed partial XP. **[community/YouTube-secondary: wiki](https://huntshowdown.fandom.com/wiki/Game_Modes)**

---

### 1.3 Balatro — escalation curve, fully documented

This is the best-documented escalation curve in the genre because the numbers are all in-game:

| Ante | Small Blind (×1.0) | Big Blind (×1.5) | Boss Blind (×2.0) |
|---|---|---|---|
| 1 | 300 | 450 | 600 |
| 2 | 800 | 1,200 | 1,600 |
| 3 | 2,000 | 3,000 | 4,000 |
| 4 | 5,000 | 7,500 | 10,000 |
| 5 | 11,000 | 16,500 | 22,000 |
| 6 | 20,000 | 30,000 | 40,000 |
| 7 | 35,000 | 52,500 | 70,000 |
| 8 | 50,000 | 75,000 | 100,000 |

**Structure:** 8 antes × 3 blinds, starting resources **$4, 8-card hand, 4 hands + 3 discards per blind**. Curve shape: the ratio between consecutive antes is roughly **2.5× early (300→800→2000), decaying to ~1.4× late (35k→50k)** — front-loaded growth that makes early progress feel explosive and late progress feel earned. **[community/YouTube-secondary: Fextralife beginner's guide](https://balatro.wiki.fextralife.com/Beginner%27s_Guide), corroborated by [Balatro Wiki](https://balatrogame.fandom.com/wiki/Blinds_and_Antes)**

**The reveal cadence.** GMTK identifies the core hook as the *un-previewed score reveal*: the game deliberately does not show your projected score, so every hand is a slot pull — numbers tick up card-by-card with escalating sound, multipliers "catch fire." LocalThunk stated the joy lives in "that precise moment… when you cross your fingers and hit play." The per-hand reveal is a **~5–15 second escalating audiovisual reward sequence** occurring every ~30–90 seconds of play. **[community/YouTube-secondary, citing developer-primary interviews: GMTK, "Balatro's 'Cursed' Design Problem"](https://www.youtube.com/watch?v=zk3S3o1qOHo); [AIAS Game Maker's Notebook interview with LocalThunk, 2h16m](https://www.youtube.com/watch?v=b8CyE1svP2k)**

**Decision points.** After each blind: shop (spend now vs. save for interest/economy), skip blind (forfeit shop+reward for a tag bonus) — a literal stop-or-continue bet. Every shop is a "push your build deeper or consolidate" decision with full information visible except the next boss. **[community/YouTube-secondary: GMTK](https://www.youtube.com/watch?v=zk3S3o1qOHo)**

---

### 1.4 Luck be a Landlord — rent as the extraction timer

The entire push-your-luck tension is one rising number against a fixed allowance of pulls. Exact schedule (Floor 1):

| Payment # | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Spins given | 5 | 5 | 6 | 6 | 7 | 7 | 8 | 8 | 9 | 9 | 10 | 10 |
| Rent due | 25 | 50 | 100 | 150 | 225 | 300 | 350 | 425 | 575 | 625 | 675 | 777 |

**Win at payment 12; Endless mode adds +500/cycle.** Failure split: **total — miss rent once, the run ends and everything is lost**; the only persistence is meta-unlocks (new floors, symbol pool additions). The version history on the wiki shows the developer hand-tuning individual payments by ±25–75 coins across five patches — evidence that *individual steps on the escalation ladder* are the balance levers, not the overall shape. **[community/YouTube-secondary: LBAL Wiki rent table & version history](https://luck-be-a-landlord.fandom.com/wiki/Rent)** — and the tension source is stated in the designer's own framing: rent is "the main source of dramatic tension." **[developer-primary: presskit/interviews via TrampolineTales](https://trampolinetales.com/lbal/presskit); [Olexa dev interview, 1h+](https://www.youtube.com/watch?v=W6UpGWUoufk)**

**Retention proof point:** after v1.0 the game went from ~150 to ~1,000 concurrent players and launch-week sales were ~30× the control week — with *zero* failure forgiveness in the loop. Hard fail + short runs + visible escalate-or-die number is retention-viable. **[developer-primary: TrampolineTales dev blog](https://blog.trampolinetales.com/whats-next-for-luck-be-a-landlord/)**

---

### 1.5 Slay the Spire — metrics-driven failure tolerance

**Structure:** 3 acts, ~45–60 min full run (community consensus; the GDC talk confirms 3-act structure but not a stated minute target — *unconfirmed as a design target*). **20 Ascension levels** of post-victory difficulty as the retention tail. **[developer-primary: Giovannetti, GDC 2019, "Metrics Driven Design and Balance"](https://www.youtube.com/watch?v=7rqfbvnO_H0) / [GDC Vault](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics)**

**Key methodological lessons from the talk:** (1) MegaCrit ran an **in-house telemetry server collecting data on every run's death or victory**; (2) they caught a major trap — aggregate win-rate data was skewed by a tiny cohort of "super play testers" playing "unhealthy amounts," so *balance to percentiles, not averages*; (3) cards appearing late (e.g., Madness in act-3 events) looked overpowered in win-rate data purely due to *timing of acquisition* — an artifact directly relevant to you: items found deep in a zone will look stronger than they are. (4) Weekly cadence of visible iteration was itself a retention driver. **[developer-primary: GDC talk](https://www.youtube.com/watch?v=7rqfbvnO_H0)**

**Failure split:** full run loss on death; meta-persistence limited to unlocks (cards/relics/characters) and Ascension progression. The genre-standard split per GMTK's taxonomy: run loot lost, *variety unlocks* kept — Enter the Gungeon keeps boss-currency for pool expansion, Rogue Legacy keeps cash→permanent stat upgrades, Dead Cells forces you to *bank currency at stations mid-run or lose it* (the most extraction-like design in the roguelike canon: an in-run decision to convert at-risk currency into safe progress), Into the Breach keeps exactly one soldier. **[community/YouTube-secondary: GMTK, "Roguelikes, Persistency, and Progression"](https://www.youtube.com/watch?v=G9FB5R4wVno)**

---

## SECTION 2 — CROSS-GENRE NUMBERS

### 2.1 Slot machines / casino — the feedback-cadence ground truth

- **Spin/event cycle: ~3 seconds.** Experimental conditions tested at 1.5s / 3s / 4.5s per spin; faster event frequency measurably degrades players' ability to inhibit continued play. **[scholarly: Harris et al. 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7882578/)**
- **Losses disguised as wins (LDWs):** on modern multi-line machines a large share of "win" celebrations pay back *less than the bet* — the win audiovisuals fire anyway, inflating perceived win frequency; players systematically overestimate how often they won. **[scholarly: Barton et al. 2017 systematic review, 51 studies](https://pmc.ncbi.nlm.nih.gov/articles/PMC5663799/); [Dixon et al., U. Waterloo](https://uwaterloo.ca/reasoning-decision-making-lab/sites/default/files/uploads/files/DixFugetal_10c.pdf)**
- **Near misses:** 9/9 reviewed studies found near misses increase motivation to continue; 3 found they extend session length. **[scholarly: Barton et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC5663799/)**
- **Mechanical translation:** the reward *ceremony* should fire on anything ≥ a threshold fraction of expected value, not just on true wins — the celebration is the reward, decoupled from the payout.

### 2.2 Gacha — Genshin's documented pity ramp

| Wish # | 1–73 | 74 | 76 | 78 | 80+ | 89 | 90 |
|---|---|---|---|---|---|---|---|
| 5★ rate | 0.6% flat | ~6.5% | ~18% | ~30% | steep climb | ~96% | 100% |

**~85% of all 5★ drops land between pulls 74–89; only ~15% hit hard pity. Weapon banner: soft pity at 63, hard at 80.** The ramp is invisible in-game (no counter shown) but fully known by the community — players self-track, which *increases* engagement rather than reducing the gamble. **[community/YouTube-secondary aggregating datamined primary data (Paimon.moe, KeqingMains): GenshinTactics](https://genshintactics.com/guides/genshin-pity-system-explained-2026/)** The design pattern: a hidden escalating probability behind a visible fixed cost per pull — directly applicable to your cache mini-game's rare-loot rolls.

### 2.3 Match-3 — King's difficulty science

- **"The longer the level is, the less likely it is to be fun" — and maximum recommended level duration scales inversely with difficulty: hard levels must be short.** **[developer-primary: King GDC talk, Guardiola & Wedekind, via MobileGamer.biz](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/)**
- King A/B tested the infamous Level 65: **raising difficulty raised short-term conversion but caused the most churn of any level; easing it retained players who then monetized later — "retention always wins."** King measures levels on *time-to-abandon* vs *time-to-pass* to disentangle difficulty from fun, profiles player skill within weeks, and continuously prunes the 100 least-fun levels (doing so produced "a very significant uplift in engagement"). **[developer-primary: same]**
- Session granularity: individual Candy Crush attempts run ~1–3 minutes *(community-documented norm, not stated in the talk — mark unconfirmed)*; lives regenerate on a ~30-min timer creating appointment return loops.

### 2.4 MOBA / hero-shooter session pacing

- **League of Legends: 30–35 min average historically → ~25 min by Season 9**, driven by deliberate Riot accelerants: Rift Herald, anti-stall Baron buff, Turret Plating (160g/plate, >1000g for fast pushers), and surrender threshold lowered 25 → 20 → 15 min. The documented reason: competitive pressure from faster-loop games (Fortnite). **[community/YouTube-secondary analysis of developer changes: Sullla](https://sullla.com/LoL/gottagofast.html)** Player-measured averages now run ~30–34.5 min at mid ranks. **[community-secondary: r/leagueoflegends](https://www.reddit.com/r/leagueoflegends/comments/1q9lu49/)**
- **Overwatch: ~10–20 min matches** (Quick Play ~16–17 min). **[community-secondary: various](https://www.facebook.com/fb-answers/overwatch-game-length-guide/)**
- Takeaway: even the slowest successful competitive loops compress toward **≤30 min**, and designers pay gold to players who end games *faster* — momentum is subsidized, stalling is taxed.

### 2.5 Battle royale — the shrinking zone as a pacing instrument

PUBG's own dev letter is the cleanest developer-primary statement of circle-as-tension-design: warning times vs shrink times are tuned **per phase**; their telemetry showed late phases (5–6) over-compressing movement+combat+damage pressure, so they *extended late-game shrink times* and replaced distance-scaled damage with **time-in-zone-scaled damage** to kill "heal-through-the-blue" stalling strategies. Phase timings are mode-specific (Normal vs Ranked get different curves). **[developer-primary: PUBG Blue Zone Revamp dev letter](https://pubg.com/en-asia/news/10280?category=dev_notes)** Community-documented damage per phase roughly doubles per circle (1 → 2 → 5 → 10 HP/s early-mid). **[community-secondary: Steam forums](https://steamcommunity.com/app/578080/discussions/1/135513549089919839/)** Fortnite's storm runs ~9 phases over ~20 min with phase timing re-tuned chapter over chapter. **[community-secondary: Fortnite Wiki](https://fortnite.fandom.com/wiki/The_Storm)**

### 2.6 Social/casual mobile — appointment mechanics

- **Coin Master: 5 spins per 50–60 min, cap 50** — the energy timer *is* the session shaper: ~10 natural spin sessions/day possible, each lasting minutes. Raids add a mini push-your-luck inside the slot loop: 3 digs to locate fragmented loot, some digs yield nothing; shields cap at 3, forcing return visits to refill. The revenge loop ("your coins were stolen") is an externally-generated return trigger. **[community/YouTube-secondary, citing Deconstructor of Fun: GameAnalytics](https://www.gameanalytics.com/blog/coin-master-social-casino); [Appeconomies](https://appeconomies.com/how-coin-master-reimagined-slots/)**
- **Clash Royale:** matches are **3 min + overtime**; chest unlock timers gate post-match rewards — Silver **3h**, Golden **8h** *(community-documented standard values; the wiki page I pulled didn't restate them — treat as well-established but community-sourced)*. Match (3 min) and meta-timer (3–8h) operate on two different cadence scales simultaneously — micro-loop for play, macro-loop for return. **[community-secondary: Clash Royale Wiki](https://clashroyale.fandom.com/wiki/Chests); Supercell's own [drop-rate disclosure](https://supercell.com/en/games/clashroyale/blog/news/clash-royale-chest-info-2/) [developer-primary]**

### 2.7 Clicker/incremental & looter shooters

- **Cookie Clicker:** feedback begins at *every click* (sub-second cadence) and the prestige ("ascend") loop converts total loss of current progress into a permanent multiplier — proof that **voluntary full reset with a kept multiplier** is itself compelling when the player chooses the moment. **[community-secondary: Vice](https://www.vice.com/en/article/cookie-clicker-wasnt-meant-to-be-fun-why-is-it-so-popular-8-years-later/); [Mechanics of Magic analysis](https://mechanicsofmagic.com/2025/05/24/cookie-clicker-satisfaction-of-doing-nothing/)**
- **Diablo:** Brevik's GDC postmortem attributes the "one more floor" pull to *immediate* action (fast clicks, minimal UI, late-added quickbar), small dense tile-based levels with stairs randomized into view, and stacked difficulty tiers for replay — micro-loops measured in seconds-to-minutes nested in floor-loops. No numeric drop rates given in the talk. **[developer-primary: Brevik, Diablo Classic Postmortem](https://www.youtube.com/watch?v=VscdPA6sUkc)**
- **Path of Exile:** Chris Wilson has stated players prefer *frequent small drops during* mapping over one mountain of loot at the end — cadence beats magnitude. **[community-secondary reporting developer statements: r/pathofexile on Baeclast](https://www.reddit.com/r/pathofexile/comments/bw9qn2/); [Wilson GDC talk, "Designed to Be Played Forever"](https://www.gdcvault.com/play/1025784/Designing-Path-of-Exile-to) [developer-primary]]**

---

## SECTION 3 — SYNTHESIS: TARGET NUMBERS FOR YOUR ROBLOX ACTIVITY

| Axis | Recommended target | Evidence base |
|---|---|---|
| **Run length** | **8–15 min full-depth run; first extract reachable at ~3–5 min.** Hunt compressed 45→15 min for retention; King: hard content must be short; Clash Royale proves 3-min loops sustain billions of sessions. Roblox session norms argue for the short end. | Hunt wiki; King GDC; Sullla |
| **Escalation curve** | **Depth tiers with ~1.5–2.5× value-per-cache growth per tier, front-loaded (Balatro's 2.67×→1.43× decaying ratio).** Make the *visible multiplier* explicit: a depth meter showing "next ring = ×2 loot, +1 threat pip." | Balatro ante table; LBAL rent ladder (25→777 over 12 payments) |
| **Stop/continue cadence** | **A discrete decision every 60–90 seconds** (Balatro's blind/shop rhythm; LBAL's rent cycle). After every 2–4 caches, force the bank-or-push choice at a checkpoint — Dead Cells' bank-or-lose stations are the exact template. | GMTK persistency taxonomy; Balatro structure |
| **Hard timer** | **A visible zone-collapse timer (LBAL rent / PUBG phase hybrid): total run cap ~12 min, with escalating hazard ticks in the final third.** Time-scaled (not distance-scaled) pressure, per PUBG's revamp rationale — predictable, intuitive, ungameable by stalling. | PUBG dev letter; LBAL rent table |
| **Extraction ritual** | **Extraction is a 20–30 s channel, announced/visible, interruptible** (Hunt's 30 s). The held breath at the end is where the story happens — never instant-extract. | Hunt wiki |
| **Failure split** | **Lose all unextracted loot; keep a 1-slot "secure pouch" (Tarkov) + partial meta-XP (~50%, Hunt).** Keep-fraction small but non-zero; full-loss-with-meta-unlocks is proven retention-viable (LBAL grew 6.7× concurrents with zero forgiveness). Add an insurance-style delayed partial return as a paid/earned softener later. | Tarkov secure container; Hunt 50% XP; LBAL dev blog |
| **Feedback cadence** | **A reward *ceremony* every 3–10 s** (slot event cycle: 3 s; Balatro hand reveal: 5–15 s every 30–90 s). Each cache mini-game = one "pull" with an escalating audiovisual reveal; fire win-celebration audio even on marginal results (LDW principle), and show *near-miss* states on rare-tier rolls ("2 of 3 jackpot symbols"). | Harris 2020; Barton 2017; GMTK/Balatro |
| **Hidden ramp** | Rare-cache odds: **flat base rate + soft-pity ramp beginning ~70–80% toward a guaranteed pity** (Genshin: 0.6% flat → ramp at 74 → 100% at 90). Never show the counter; players will track it themselves and that tracking is engagement. | GenshinTactics/Paimon.moe |
| **Macro-loop (return triggers)** | Session-parallel timers on a *different* timescale: daily salvage-contract refresh, a 3–8 h "appraisal" timer on extracted loot (Clash Royale chest pattern), or an energy-style entry allowance (Coin Master: 5/50 min, cap 50) if you want to cap daily runs. | Supercell; GameAnalytics/Coin Master |
| **Tuning method** | Telemetry per run-end (win/loss/depth reached); **balance to percentiles, not averages** (MegaCrit's super-tester skew warning); items only found deep will look overpowered in aggregate — normalize by acquisition depth. Long A/B tests over short ones (King: retention compounds like interest). | GDC StS talk; King GDC |

**The single sentence version:** a ~10-minute run; a visible ×1.5–2.5 depth multiplier ladder; a forced bank-or-push checkpoint every ~60–90 s; a 3–10 s reward ceremony per cache with LDW-style celebration and near-misses; a 20–30 s exposed extraction channel; on failure lose everything except one pouch slot and half XP; and a hidden soft-pity ramp on the rare drop.

**Caveats on sources:** exact Clash Royale chest hours, Candy Crush per-attempt duration, and Slay the Spire's target run-minutes are community-documented norms rather than developer-stated numbers in the sources retrieved; everything else above is quoted from primary or directly-cited secondary material.
