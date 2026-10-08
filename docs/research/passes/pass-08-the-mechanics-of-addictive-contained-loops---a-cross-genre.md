# The Mechanics of Addictive Contained Loops — A Cross-Genre Reference

Below, every number is tied to a source I actually retrieved this session. I tag each as **[scholarly]**, **[dev-primary]** (the designer/studio's own words — GDC, interview, patch note), or **[secondary]** (wiki, YouTube breakdown, forum analysis). Where I could not retrieve a hard number, I write **not found** rather than estimate. Where a wiki page is secondary but reproduces a primary patch note, I say so.

---

## 1. Slot Machines & Casino Game Design

**Session / spin length.** A spin is the atomic unit: the player presses spin, all reels animate in unison "for a brief duration, then each reel will [stop] left to right" [Near-Misses and Stop Buttons in Slot Machine Play, PMC/NIH](https://pmc.ncbi.nlm.nih.gov/articles/PMC5846825/). The paper measures the interval between the last reel stopping and the next spin press **in milliseconds** (the "post-reinforcement pause," or PRP) but the crawl did not return the numeric values — **exact ms not found**. The intent of that stop-left-to-right sequencing is to hold the last reel as the suspense beat.

**Stakes escalation.** Slot machines have no escalating session curve *inside* a spin — escalation is engineered cross-spin via:
- **Near-miss frequency**: near misses occurred at **15%, 30%, or 45%** of trials across published studies [Pisklak et al., *Journal of Gambling Studies*, 2020](https://link.springer.com/article/10.1007/s10899-019-09891-8) [scholarly]. Near-misses "trigger large skin conductance responses, but no post-reinforcement pauses" — i.e., they raise arousal and *do not* produce the pause that a real win does, keeping players spinning [Dixon et al., *Journal of Gambling Studies*, 2013](https://link.springer.com/article/10.1007/s10899-012-9333-x) [scholarly].
- **Weighted reels**: the near-miss is produced by "increasing the virtual weight of the blanks above and below the [payline]" so high-value symbols align on two reels and "barely miss" on the third [Wizard of Vegas forum, citing weighted-reel mechanics](https://wizardofvegas.com/forum/gambling/slots/14661-weighted-outcomes-on-mechanical-reel-slots/) [secondary]; corroborated by Horton et al. 2007 [scholarly, PDF](https://www.greo.ca/Modules/EvidenceCentre/files/Horton%20et%20al(2007)Do_weighted_reels_on_a_slot_machine_distort_a_gamblers_judgement.pdf).

**Stop-or-continue decision point.** There is effectively none inside a spin (the RNG resolves at press). This is precisely the design lesson: slots deliberately *remove* the decision and replace it with a forced cadence. The "stop button" is an **illusion of skill** — patient timing "doesn't really make any difference" [Tunica Travel explainer](https://tunicatravel.com/blog/does-stopping-the-slot-reels-early-change-your-result/) [secondary].

**Bad-outcome handling / keep-vs-lose.** Not applicable in slots — the "loss" is the wager itself. The relevant mechanic is **Losses Disguised as Wins (LDWs)**: a payout *smaller* than the wager, presented with full win audio/celebration. Players miscategorize LDWs as wins and overestimate their win frequency within a session [Graydon et al., *International Gambling Studies*, 2017](https://www.tandfonline.com/doi/full/10.1080/14459795.2017.1355404) [scholarly]; systematic review in Barton et al. 2017 [scholarly](https://link.springer.com/content/pdf/10.1007/s10899-017-9688-0.pdf).

**Feedback cadence.** Every spin (typically a few seconds) delivers a binary audiovisual verdict; near-misses deliver a *win-shaped* signal on a loss. That is the tightest feedback cadence in this entire document: **one reward/denial signal per few seconds, continuously.**

**Published retention data.** Not found in the sources retrieved (the behavioral studies measure arousal and PRP, not retention curves).

**Take-aways for your loop:** (a) engineer a *near-miss* state in your cache mini-game — a "two-of-three symbols aligned" visual that fires the loss animation with win sound about 15–45% of the time; (b) keep the reward signal per interaction down to seconds; (c) never show the player whether they'll succeed before they commit the action (Balatro does the same — see §7).

---

## 2. Mobile Gacha — Genshin Impact

**Session length.** Individual pull cadence is driven by the pity counter, not a timer. The relevant "session" is the pity cycle.

**Exact rates (dev-primary via wiki reproducing official rates).** [Genshin Impact Wiki — Wish](https://genshin-impact.fandom.com/wiki/Wish) [secondary, reproduces official rate disclosure]:
- 5★ base rate: **0.6%** (Character Event); **soft pity begins ~wish 74**; hard pity at **90**.
- Consolidated (including pity) 5★ rate: **1.6%** → **one 5★ per ~62.5 wishes** = 10,000 Primogems.
- 4★: base **5.1%**, average with pity **13%**; **guaranteed 4★ (or higher) on the 10th wish** if none in 9.
- Weapon banner: 5★ base **0.7%**, consolidated **1.85%**, soft pity ~wish **63**.
- Soft-pity detail from the community: wishes 1–73 sit at 0.6%, then the rate climbs sharply from wish 74 [HoYoLab community article](https://www.hoyolab.com/article/23221584) [secondary].

**Escalation curve.** The pity system is a **guaranteed-but-invisible rising probability** — a hidden meter that only the community reverse-engineered. The decision point ("pull again / stop") is made with *no on-screen meter*; players hold the count mentally or via third-party trackers.

**Bad outcome.** A "loss" (losing the 50:50 to the featured character) does not reset progress to zero — it grants a **guarantee** on the next 5★. That is the keep-on-failure design: the loss is partially banked.

**Feedback cadence.** Each pull = one multi-second animation with tiered rarity reveals (a star-count jump, gold vs purple flash).

**Retention data.** Not found — I did not retrieve published Supercell/HoYoverse retention telemetry.

---

## 3. Match-3 — Candy Crush Saga

**Session length.** Per-level; each level is a contained board with a move limit, so a session is ~1–3 minutes per attempt [secondary — Candy Crush Saga Wiki on level structure](https://candycrush.fandom.com/wiki/Cascades).

**Escalation mechanism — the cascade.** "Cascades occur when you trigger a chain reaction with one match," most easily triggered with **2–5 colors on the board** or a color bomb [Candy Crush Saga Wiki — Cascades](https://candycrush.fandom.com/wiki/Cascades) [secondary]. The cascade is the reward amplifier: one input → many sequential rewards.

**Stop-or-continue decision.** Made per-move with full information (the board is visible). The tension is a *move budget*, not hidden information.

**Feedback cadence.** The design writing stresses near-zero latency between action and payoff: "the pieces vanish, points appear, and the board changes… the board responds instantly with movement, sound, color, and score changes," and the intended rhythm is "quiet planning followed by explosive payoff" [PuzzlesArcade design breakdown](https://www.puzzlesarcade.com/behind-the-games/why-match-3-games-are-so-satisfying-the-design-behind-cascades-combos-and-flow) [secondary]. A cascade delivers a rapid burst of sub-second reward ticks — **specific ms not found**.

**Hard numbers on cascade scoring / drop weighting / failure-penalty split:** not found in retrievable sources (King does not publish live-tuning numbers, and the academic match-3 work retrieved measures player modeling, not tuned constants) [Kamaldinov & Makarov, IEEE CoG 2019](http://ieee-cog.org/2019/papers/paper_152.pdf) [scholarly].

**Take-away:** the *chain reaction* — a single skill input that resolves into a burst of escalating audio/visual ticks — is the reusable idea, and it maps directly onto a "one good trace → 5 bonus caches" cascade in your mini-game.

---

## 4. MOBA / Hero Shooter — League of Legends & Overwatch

**Session length (secondary, community-measured):**
- League: **25–35 minutes average**, ranked games tending to **30–35** [Aussyelo guide](https://www.aussyelo.com/blog/how-long-is-a-league-game), with live per-patch averages tracked at [LeagueOfGraphs game durations](https://www.leagueofgraphs.com/stats/game-durations) [secondary].
- Overwatch: roughly **10 minutes** per match, with "a bad game…5 mins and a good one 20–25" [r/Overwatch average game length](https://www.reddit.com/r/Overwatch/comments/38ekbt/average_game_length/), [Blizzard forums](https://us.forums.blizzard.com/en/overwatch/t/game-matches-take-too-long/808816) [secondary].

**Escalation curve.** Both use **timed power-ramp objects** (League: objectives/towers/barons that grow stronger with the clock; Overwatch: ult-charge and overtime). The specific tuned internal curves were **not found** in primary form this session. The published framing is that match tempo must keep "meaningful strategic choices" alive (see the PUBG dev-letter logic in §5, which is the same philosophy stated primally).

**Stop-or-continue decision.** Not a push-your-luck loop — one match, then a discrete "play again" decision. The design relevance to you is the **session-length anchor**: ~10 min (Overwatch) and ~30 min (League) are the two poles players accept for "one run, then re-queue."

**Feedback cadence.** Continuous micro-rewards (last hits, eliminations, ult-charge) — specific ratios not found.

**Dev-primary sources on pacing:** [Jeff Kaplan, AIAS Game Maker's Notebook](https://www.youtube.com/watch?v=dhN0I-CxFck) and the [Time Overwatch interview](https://time.com/4344566/overwatch-interview/) exist but specific match-length numbers were **not found** inside retrievable transcripts.

---

## 5. Battle Royale — PUBG (and Dark and Darker)

PUBG is the gold-standard **published stakes-escalation table**. All values below are from the [PUBG Wiki — The Playzone](https://pubg.wiki.gg/wiki/The_Playzone) [secondary, reproduces the PC 1.0 patch data and links the battlegrounds.party primary dataset].

**Erangel/Miramar (largest map), exact per-phase clock:**

| Phase | Delay before shrink | Shrink duration | Diameter (white) | Damage/sec |
|---|---|---|---|---|
| 1 | 120 s | 270 s | 3,994 m | 0.4% |
| 2 | 0 | 180 s | 2,397 m | 0.6% |
| 3 | 0 | 130 s | 1,318 m | 0.8% |
| 4 | 0 | 120 s | 725 m | 1% |
| 5 | 0 | 100 s | 363 m | 3% |
| 6 | 0 | 90 s | 181 m | 5% |
| 7 | 0 | 70 s | 91 m | 7% |
| 8 | 0 | 60 s | 45 m | 9% |

Total to final circle ≈ **31–32 minutes**, then a 180 s pause and a 15 s countdown to the closing phase at **11% dmg/sec**. Note the escalation shape:
- **Diameter shrinks geometrically** (4,000 → 45 m) while
- **Damage/sec rises 0.4% → 9% → 11%** — i.e., the penalty for being caught out *accelerates* in the last third of the session. The first circle alone eats ~11.5 of the ~32 minutes (a long, safe opening); the last four circles compress into ~7 minutes of high-stakes motion.
- **Sanhok** runs the same shape in **~25:50**, with a dynamic system that **shortens the delay further when survivor counts drop** (2nd phase when <30 survive, 3rd when <18, 4th when <10, 5th/6th when <3) [PUBG Wiki](https://pubg.wiki.gg/wiki/The_Playzone) [secondary].

**Dev-primary escalation rationale.** PUBG's [Blue Zone Revamp dev letter](https://pubg.com/en-asia/news/10280?category=dev_notes) states the design goal directly: the zone must "gradually restrict the playable area, encourage player encounters, and reduce the number of survivors," while — crucially — it "should **not** pressure players so aggressively that meaningful strategic choices disappear." They also state they analyzed "long-term gameplay data" and found that shrink times becoming shorter each phase caused "movement pressure, combat pressure, and Blue Zone damage pressure to converge," so they **lengthened shrink times and slightly shortened warning times** to smooth late-game pacing, and changed damage from distance-based to **time-in-zone-based** so escalation is "intuitive and predictable." This is the single best dev-primary statement on *why* an escalation curve must stay legible.

**Published data.** The dev letter confirms the team "analyzed long-term gameplay data" on survivor counts and engagement distances per phase, but **the raw retention/session numbers are not disclosed** — **not found**.

**Dark and Darker** (secondary): players argue the round is "too rushed" and "should be at least 2x as long," and note that removing the closing circle made the endgame degenerae into "running around desperately trying to find the extraction points" [r/DarkAndDarker](https://www.reddit.com/r/DarkAndDarker/comments/174kj6t/can_we_get_more_time_in_game/), [Steam thread](https://steamcommunity.com/app/2016590/discussions/0/4340987076277815140/) [secondary]. The mechanic relevant to you: the **outer boundary closing** is what forces the "move now or lose it" decision; removing it removed the tension.

---

## 6. Clicker / Incremental — Cookie Clicker

**Session length.** No run — it is unbounded; the "loop" is a **tick cadence**. The base loop is "click → earn currency → buy an auto-producer → earn passively" [Wikipedia — Cookie Clicker](https://en.wikipedia.org/wiki/Cookie_Clicker).

**Escalation.** Exponential/tetrational production growth (each building tier multiplies the rate). Deterding's scholarly analysis frames it as an idle system where progress "makes progress on its own, requiring no player [input]" — the escalation is in the *numbers*, not the difficulty [Deterding, "Cookie Clicker: Gamification," White Rose eprints](https://eprints.whiterose.ac.uk/id/document/1522736)[scholarly].

**Feedback cadence.** Continuous number-go-up (the cookie counter increments every tick) plus discrete milestone notifications. Specific tick rates not found. Adam Millard's analysis of the genre, [How Videogames Keep You Playing Forever](https://www.youtube.com/watch?v=woAiDiH_Y8Q) [secondary] is the best breakdown retrieved.

**Relevance to you:** the incremental lesson is **visible, constantly-ticking numbers**. Your cache counter should increment continuously, not just at cache-open.

---

## 7. Deckbuilding Roguelikes — Balatro, Slay the Spire, Luck be a Landlord

This is the closest cluster to your design. Balatro is the anchor.

**Session length.** A run = **8 antes**, each ante = **3 blinds** (Small → Big → random Boss) [Balatro Wiki — Blinds and Antes](https://balatrogame.fandom.com/wiki/Blinds_and_Antes) [secondary, reproduces in-game values]. Community runs commonly land **~30–60 min**; LocalThunk describes it as "a run-based game… score as many chips as possible to defeat an ever rising required score" [Rogueliker Balatro interview](https://rogueliker.com/balatro-interview/) [dev-primary].

**The escalation curve — exact score thresholds (this is the machine you should copy).** [Balatro Wiki](https://balatrogame.fandom.com/wiki/Blinds_and_Antes) [secondary]:

| Ante | Base chips required |
|---|---|
| 1 | 300 |
| 2 | 800 |
| 3 | 2,000 |
| 4 | 5,000 |
| 5 | 11,000 |
| 6 | 20,000 |
| 7 | 35,000 |
| 8 (Finisher) | 50,000 |

Blind thresholds within an ante: **Small = 1× base, Big = 1.5×, Boss = 2×**; in Endless mode scaling becomes **tetrational (x^x^x)** [Balatro Wiki](https://balatrogame.fandom.com/wiki/Blinds_and_Antes) [secondary]. The curve shape is the key data point: **~2.5× growth per ante** (300 → 800 → 2,000 → 5,000 → 11,000 → 20,000 → 35,000 → 50,000), while *the player's own multiplier stack compounds faster* — so the session feels like it's accelerating without ever breaking.

**Stop-or-continue decision.** Balatro's core: you choose your hand and **"cross your fingers and hit go"** with **no score preview**. LocalThunk: *"My personal belief is that the game is more fun when you set up your Rube Goldberg machine and watch it go before knowing whether or not the hand will win"* [GMTK, "Balatro's Cursed Design Problem"](https://gmtk.substack.com/p/balatros-cursed-design-problem) [secondary quoting dev-primary]. The visible information at decision time is *deliberately incomplete* — you see your engine, not the outcome.

**Feedback cadence (scoring reveal).** The reveal is **sequential and escalating**: "the numbers tick up with escalating sound effects; each card and Joker steps forward in turn to add their points to the total," and "the score multiplier will set on fire and start to burn hotter and hotter with each multiplication" [GMTK video transcript](https://www.youtube.com/watch?v=zk3S3o1qOHo) [secondary]. Worked example from the same source: straight = **30 chips**, additive card contributions **10/20/30/39/47**, two face cards **+30 each** → subtotal **137** × **4** = **548** — "not quite enough to beat the ante, but close." That *near-miss framing on the score itself* is the Balatro equivalent of a slot near-miss. **Exact per-tick ms not found.**

**Bad-outcome handling.** On a failed blind the run ends; you keep only meta-unlocks. LocalThunk's philosophy is "hang the picture by feel" — balance by feel, changing single numbers (cost, rarity, chip bonus, mult bonus) [Rogueliker interview](https://rogueliker.com/balatro-interview/) [dev-primary].

**Slay the Spire.** **Runs are ~45 minutes typical, 75–90 min for a deep run** [r/slaythespire](https://www.reddit.com/r/slaythespire/comments/1aeqnx1/how_long_do_your_runs_usually_take/), [Steam thread](https://steamcommunity.com/app/646570/discussions/0/1642042464745019506/) [secondary]. Structure: **each act = 17 floors**, ~50 floors to the top [Slay the Spire Wiki — Map Generation](https://slaythespire.wiki.gg/wiki/Map_Generation) [secondary]. Decision layering is documented by [Game Designer Plays' breakdown](https://www.youtube.com/watch?v=DnF8Yt3tNMU) [secondary]: three choice layers (combat / reward / overworld), with the risk example *"You were planning on fighting two elite enemies but you're on 10 HP so you play it safe and go to a question mark"* — a **legible, self-chosen stakes escalation**. The dev-primary GDC talk is **"Slay the Spire: Metrics Driven Design and Balance"** [GDC Vault](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics), and the primary interview [GameDeveloper.com](https://www.gamedeveloper.com/design/how-i-slay-the-spire-i-s-devs-use-data-to-balance-their-roguelike-deck-builder) confirms the balancing method: track **how often each card is picked** and **how often it appears in a winning deck**, using "at least 90" metric graphs. (This is why your game should log *pick rate* and *win-correlation* per cache/mutator.)

**Luck be a Landlord** — slot-machine-as-deckbuilder, explicitly cited by LocalThunk as an inspiration [Rogueliker interview](https://rogueliker.com/balatro-interview/). Dev interview: [Interviewing the developer of Luck be a Landlord](https://www.youtube.com/watch?v=W6UpGWUoufk) [secondary]. Specific tuned numbers **not found**.

---

## 8. Extraction Shooters — Escape from Tarkov & Hunt: Showdown

**This is the genre you named as the closest analogue — so I went deepest.**

### Escape from Tarkov

**Session length (secondary, per-map patch data).** Raid timers: **Shoreline 40 → 45 min**, **Interchange 35 → 40**, **Lighthouse 35 → 40** [community patch summary](https://www.facebook.com/groups/1714415802627065/posts/2113021832766458/); Scav raids can be flatteringly short (**~16 min** complained about) [Tarkov forum](https://forum.escapefromtarkov.com/topic/113237-seriously-wtf-a-16-min-scav-raid-timer-really/) [secondary]. The community explicitly frames **short timers as the mechanism that "force[s] quicker decisions about whether to fight, loot, or extract"** and "prevent[s] players from slowly looting the entire map" [Steam discussion](https://steamcommunity.com/app/3932890/discussions/1/805719526076353807/) [secondary]. That sentence is the design thesis of your activity.

**Why the timer was chosen (dev-primary).** Nikita Buyanov, in the [AIAS Game Maker's Notebook interview](https://www.youtube.com/watch?v=Vcz6ZpJeqtI), states: *"You'll start at a random point… there will be a timer within which you must get out. From a certain time on the timer, some exit points will open, and you must leave through those points, or you'll go missing. That is the concept of EFT."* The timer + **time-gated extraction points** is the deliberate rule that "forces players to make trade-offs while scavenging." **This is the single most directly transferable primary-source quote for your zone design: extraction is only available in windows, not always.**

**Stakes escalation.** Gated exit windows + escalating PvP density over the raid; **specific density curve not found**.

**Stop-or-continue decision.** Each loot interaction is a push-your-luck bet: more time in the zone = more loot = more exposure. The decision is made with the raid clock visible.

**Bad-outcome handling (dev-primary).** Buyanov: *"If you die in the raid you can lose everything… it's a polarization game, it takes you from extreme joy to extreme hate."* He explicitly names the resulting emotion **"gear fear."** **Note: the exact keep/lose percentage is NOT stated in the primary interview — I could not retrieve a number, so I will not invent one.** The community framing is full loss of carried + found gear on death.

**Data (dev-primary).** Buyanov cites **~30,000 concurrent users** as his "big success" benchmark and **~50 million installs** for the predecessor *Contract Wars*. **No session-length or retention percentages were given** — not found.

### Hunt: Showdown (the cleanest published keep/lose split in the genre)

From the [Hunt: Showdown Wiki — Game Modes](https://huntshowdown.fandom.com/wiki/Game_Modes) [secondary, reproduces in-game rules]:

- **Match cap: 45 minutes.** Match **also auto-ends 5 minutes after all bounties are extracted** — i.e., the *goal state shortens the session*.
- **Bounty Clash mode: 15 minutes.**
- **Extraction timer: 30 seconds** standing in the zone **without any teammate being downed** (was once ~10–20 s; players asked for 60 s when carrying a bounty) [r/HuntShowdown](https://www.reddit.com/r/HuntShowdown/comments/t25imf/how_many_times_are_you_on_the_heels_of_bounty/) [secondary].
- **Post-all-bounties grace: 5 minutes** to reach an extract or **the Hunter is lost**.
- **Out-of-bounds: 20 seconds** to return or be killed.
- **Keep-on-extract:** bounty points convert to hunt dollars at **1:1**, XP at **1:4** (Bloodline + Hunter).
- **Lose-on-death:** you **lose the Hunter and all equipped gear**, and receive **only half XP** — **but "gun/tool/consumable unlock xp is unaffected."** That final clause is the *keep-on-failure* design: a sliver of persistent progress survives even total loss, so a bad run never feels like zero.
- **Proximity tell:** a Clue **glows red when an enemy is within 30 meters** — the "you are no longer safe" signal. [Hunt Wiki](https://huntshowdown.fandom.com/wiki/Game_Modes) [secondary].
- Dev-primary framing: [Design Goals for Game Mechanics](https://www.youtube.com/watch?v=YBoNaw2kHn8) and the [45-minute time-limit dev video](https://www.youtube.com/watch?v=-5iI6cIxfU4) [dev-primary].

**The Hunt keep/lose split is exactly the blueprint for your failure-penalty:** lose the loot, lose the "Hunter" (kit), but **keep a fraction of XP**, and never touch the permanent unlock track.

---

## 9. Looter Shooters / ARPGs — Diablo & Path of Exile

**Feedback cadence (community + scholarly).**
- Diablo 4 community reports **~1 legendary every 5 minutes** as an acceptable cadence [r/diablo4](https://www.reddit.com/r/diablo4/comments/13g2ixx/legendary_drop_rates/) [secondary].
- Diablo 3: **a flat 1/400 (0.25%) chance per legendary drop** at high Greater Rift tiers, with ~60 runs netting ~700–720 legendaries [Blizzard D3 forums](https://us.forums.blizzard.com/en/d3/t/magic-find-and-drop-rates/65015) [secondary].
- The **design principle** is dev-adjacent-primary: Loot 2.0 explicitly raised the frequency and relevance of drops so that at least one statistically-useful item appears frequently. The designer [Josh Mosqueira's Loot 2.0 explainer](https://www.youtube.com/watch?v=rYbt27bRMos) exists but I did not retrieve its exact numbers [secondary].

**The dopamine mechanism (scholarly, and directly applicable).** [Psychology of Diablo III Loot, GameDeveloper.com](https://www.gamedeveloper.com/design/the-psychology-of-i-diablo-iii-i-loot) [scholarly/secondary] explains the mechanism from Schultz's work: dopamine neurons fire **in anticipation of reward (on the cue), then go quiet when the reward lands**; and *unpredicted* rewards cause a large dopamine gush "because unexpected dopamine rushes highlight failures in our predictive system." Conclusion quoted: *"the random nature of loot drops in many games is so effective at getting us to keep playing: it capitalizes on our brain's attempts to predict the unpredictable."* **Cue the reward signal slightly before the reward; occasionally make it exceed expectation.**

**Path of Exile.** Dev-primary, [GGG's Development Manifesto on maps](https://www.youtube.com/watch?v=FY1cWXxePWg) and the community debate around "1 life per map" [feedback video](https://www.youtube.com/watch?v=zjhDfFZsUyg) [secondary] — specific tuned numbers **not found** this session.

---

## 10. Social / Casual Mobile — Clash Royale & Coin Master

### Clash Royale
**Chest timers (secondary, reproduces in-game values):** chests take **3h, 8h, or 12h** to open, and players hold a **limited slot count (4)** [Mobile Free To Play, "Deconstructing Clash Royale"](https://mobilefreetoplay.com/deconstructing-clash-royale/) [secondary]. The article states the intent plainly: the slot friction "creates… uncertainty of hitting their Chest Timers" which "drives players to come back" and creates the pay-to-skip hook. Primary drop-rate disclosure exists: [Supercell's chest info](https://supercell.com/en/games/clashroyale/blog/news/clash-royale-chest-info-2) [dev-primary].

**Relevance to you:** the transferable number isn't the timer — it's the **slot cap creating an anticipatory return**, and the *pity cycle* of chest rarities (Supercell publishes Lucky Chest rates) [dev-primary link above].

### Coin Master
From the [KPI-based deconstruction](https://medium.com/@suganshreyas/coin-master-game-analysis-c201b7972fb7) [secondary]:
- Spin refill: **5 spins per 60 minutes**; cap **50 spins** → **~10 hours to refill fully**.
- The energy meter is explicitly **"a natural exit point of the session"** — the loop you should study for how a session *ends by design*.
- **Bet escalation inside a session:** a **2× bet pays 2× rewards but sinks 2 spins in one turn** — the in-session stakes dial.
- **Raids and shields are *slot-machine outputs*.** You attack/raid *by spinning*; you collect shields *by spinning* (max **3 shields**, consumed when attacked) — every PvP action is bolted onto the slot loop so that *more spins is always the answer*.

This is the most important structural lesson for you: **attach every secondary system (attack, defense, collection) as an output of the primary skill/timing loop**, so the primary loop is never bypassed.

---

## 11. Survivors-like — Vampire Survivors

**Session length (dev-secondary, wiki values).** Stage time limits are commonly **15:00, 20:00, 25:00, or 30:00** [Vampire Survivors Wiki — Stage](https://vampiresurvivors.fandom.com/wiki/Stage) [secondary]. Community consensus treats **30 min as the ceiling** and even complains it's "too long… too much dead time without any decisions" [QuarterToThree forum](https://forum.quartertothree.com/t/vampire-survivors-how-did-no-one-think-of-this-before/154735) [secondary].

**The escalation mechanism — minute-based waves, this is the exact pattern to copy.** Enemies "arrive in waves — **one wave every minute**" and each wave has a minimum count and spawn interval [Vampire Survivors Wiki — Enemies](https://vampire-survivors.fandom.com/wiki/Enemies) [secondary]. In **Inverse** mode, enemies start at **+200% HP and gain +5% HP and +0.5 speed per minute**; in **The Bone Zone**, "every minute, enemies' health and speed scale by **0.3 and 0.05** respectively, without a cap" [Vampire Survivors Wiki — Stage](https://vampiresurvivors.fandom.com/wiki/Stage) [secondary]. In **Endless**, each completed cycle: enemies **+100% HP, +50% spawn frequency/quantity, +25% damage** [same wiki] [secondary].

That is a **legible, minute-tick escalation curve** — exactly the shape you want for a 3–5 minute Roblox salvage run, compressed: e.g., a modifier every 30–45 seconds.

**Feedback cadence.** Continuous XP gems/level-ups on a sub-second basis; **exact tick rate not found**, but the design analysis [Adam Millard, "Vampire Survivors Only Works Because We're Stupid"](https://www.youtube.com/watch?v=bkVKLPvXBUc) [secondary] argues the constant, escalating visual noise is the hook.

**Failure.** At the time limit a **Reaper spawns every minute** to end the run — a *designed* hard stop rather than an ambiguous one [VS Wiki](https://vampiresurvivors.fandom.com/wiki/Stage) [secondary].

---

# SYNTHESIS — Target Numbers for Your Roblox Cache/Salvage Activity

Mapping the evidence above onto: *enter zone → timing/memory/tracing mini-game → push deeper or extract → lose all if caught/out of time.*

### A. Session length
| Source design | Length | Take |
|---|---|---|
| Overwatch match | ~10 min | upper bound for a "one more" unit |
| Vampire Survivors stage | 15–30 min | 30 min = ceiling; players call 30 too long |
| Tarkov raid | 35–45 min | long-form push-your-luck |
| Hunt match | 45 min cap, **goal-state trims ~5 min** | let reaching the objective *shorten* the run |
| Balatro run | 8 antes, ~30–60 min | too long for Roblox |
| **Target for you** | **3–6 minutes hard cap** | Between a Candy Crush level (1–3 min) and an Overwatch match (10 min); a Roblox player chains these. Tarkov's own community: short timers "force quicker decisions about whether… to extract" [Steam](https://steamcommunity.com/app/3932890/discussions/1/805719526076353807/). Make extraction available in **time-gated windows** (Tarkov primary: exits "open… at a certain time"), e.g. windows at 90s, 150s, 210s — this is the single strongest Tarkov mechanic to lift. |

### B. Escalation curve shape
Two proven shapes — pick one or fuse:
1. **Balatro's per-step multiplier** (copy verbatim): step thresholds at ≈ **300 → 800 → 2,000 → 5,000 → 11,000 → 20,000 → 35,000 → 50,000**, i.e. **~2.5× per step**, Small/Big/Boss within a step at **1× / 1.5× / 2×** [Balatro Wiki](https://balatrogame.fandom.com/wiki/Blinds_and_Antes). For you: each *deeper cache* raises the value by ~2.5× while the catch-risk rises on a similar multiplier — a matched curve, so the EV stays tempting but the variance widens.
2. **PUBG's phase clock** (copy the *shape*, scaled down): long safe opening, then damage/sec climbing **0.4% → 0.6% → 0.8% → 1% → 3% → 5% → 7% → 9% → 11%** with geometric area shrink [PUBG Wiki](https://pubg.wiki.gg/wiki/The_Playzone). For you: keep the first third of the run nearly risk-free, then have the "guard/security meter" climb steeply in the final 60 seconds.
- **Vampire Survivors** gives the tick granularity: **escalate every minute** (Inverse: +5% HP / +0.5 speed per minute; Endless: +100% HP / +50% spawn / +25% damage per cycle) [VS Wiki](https://vampiresurvivors.fandom.com/wiki/Stage). Compress to **a new escalation tick every 30–45 seconds** for a 3–6 min run.

**Legibility rule (dev-primary, PUBG):** escalation must be "**intuitive and predictable**," not a hidden number, and must never remove "meaningful strategic choices" — PUBG literally re-tuned to *slow* the mid-game when pressure converged [PUBG dev letter](https://pubg.com/en-asia/news/10280?category=dev_notes).

### C. Stop-or-continue decision point + visible info
- **Balatro:** decision made **with no score preview** — the player sees their engine, not the result [GMTK](https://gmtk.substack.com/p/balatros-cursed-design-problem). Implement this: **show the cache's rarity tier and your current haul, but NOT the roll outcome.**
- **Hunt:** the "you are unsafe" signal is a **30 m proximity glow** [Hunt Wiki](https://huntshowdown.fandom.com/wiki/Game_Modes). Give the player one continuous "heat/exposure meter" that reddens at a fixed distance/time — a *number they can read* but not a *certainty of outcome*.
- **Slay the Spire:** stakes are self-chosen ("two elites at 10 HP, or play safe") [breakdown](https://www.youtube.com/watch?v=DnF8Yt3tNMU). Offer a **bifurcated next-room choice**: safe cache (lower value, no risk increase) vs. deep cache (higher value, ＋1 risk tier).

### D. Failure-penalty split (keep vs. lose) — **the most important tuning dial**
Combine the two cleanest published splits:
- **Hunt: Showdown** — on death you lose the **Hunter + all gear** and **half your XP**, but **unlock XP is untouched** [Hunt Wiki](https://huntshowdown.fandom.com/wiki/Game_Modes).
- **Tarkov** — buy death = full loss of the raid, but **stash/persistent progress survives**; Buyanov's stated emotion is "extreme joy to extreme hate," engineered on purpose [AIAS interview](https://www.youtube.com/watch?v=Vcz6ZpJeqtI).
- **Genshin pity** — a "loss" grants a **guarantee next time** (partial banking of the failure) [Genshin Wiki](https://genshin-impact.fandom.com/wiki/Wish).

**Recommended target for you:**
- On failure (caught / timeout): **lose 100% of the run's salvage (the loot you were carrying)** so the push-your-luck tension is real.
- **Keep a fixed floor** — e.g. **~25% of XP/progress converted**, mirroring Hunt's "half XP but unlocks safe." Never zero-skill-progress: Hunt proves players tolerate full *loot* loss but not full *progression* loss.
- **Bank a pity token** on failure (Genshin-style) so the next run has one guaranteed high-rarity cache — this converts a rage-quit into a re-queue.

### E. Feedback cadence (how often the number goes up)
- **Slots: one verdict per spin (seconds).** Tightest possible cadence.
- **Diablo: a meaningful drop roughly every ~5 minutes** with a flat **~0.25–1% "jackpot" chance per event** [r/diablo4](https://www.reddit.com/r/diablo4/comments/13g2ixx/legendary_drop_rates/), [Blizzard forums](https://us.forums.blizzard.com/en/d3/t/magic-find-and-drop-rates/65015). Use the *cue-then-reward* mechanism from [GameDeveloper psychology piece](https://www.gamedeveloper.com/design/the-psychology-of-i-diablo-iii-i-loot).
- **Balatro: sequential ticking reveal** — every card/Joker ticks the total up in turn, sound escalates, multiplier "catches fire" [GMTK video](https://www.youtube.com/watch?v=zk3S3o1qOHo).
- **Vampire Survivors: a wave/reward every 60 s** [VS Wiki](https://vampiresurvivors.fandom.com/wiki/Enemies).

**Target for you:** **one micro reward signal every 1–3 seconds** while the tracing/memory mini-game runs (per-cleared-node tick, like Balatro's per-card tick — never one lump sum at the end), and **one macro reward (new cache) every 30–45 s**. Stage the payout with the Balatro pattern: additive ticks first, then a multiplier that escalates audiovisually.

### F. Near-miss / LDW layer (slot machine, scholarly)
Engineer an outcome that **looks like a win but is a loss**, delivered with the win sound: near-misses at **15–45%** frequency fire the same arousal as wins but *without* the pause that resets engagement [Dixon](https://link.springer.com/article/10.1007/s10899-012-9333-x), [Pisklak](https://link.springer.com/article/10.1007/s10899-019-09891-8). Implementation: a cache whose lock shows **two-of-three matching symbols** and plays the partial-success sting — a "so close" that measurably increases persistence.

### G. Session-exit and re-entry
- **Coin Master's energy meter is a *designed session-exit*** [medium deconstruction](https://medium.com/@suganshreyas/coin-master-game-analysis-c201b7972fb7). Give your activity a hard, visible run cap so the *end* is a natural "one more."
- **Clash Royale's limited slots** create the return hook [Mobile Free To Play](https://mobilefreetoplay.com/deconstructing-clash-royale/). For a Roblox trading game: let the player **hold only N un-extracted "salvage crates"** with a short real-time unlock, so un-extracted value pulls them back in.
- **Attach every side-system as an output of the core mini-game** (Coin Master's raids *and* shields are both slot outputs) — never let trading/attacking bypass the timing/memory/tracing loop.

---

## What I could not source (marked unconfirmed, per instruction)
- Exact millisecond reel-stop timings and PRP values (the Dixon paper gates its numbers behind the HTML I couldn't read; the PDF returned a cookie wall).
- Genshin / mobile-gacha published retention percentages.
- Candy Crush's actual cascade-scoring constants and King's A/B results.
- Tarkov's exact "percentage kept on death" (primary sources describe full *raid* loss but state no numeric split).
- PUBG's raw survivor-count telemetry behind the Blue Zone revamp (dev letter confirms analysis, omits figures).
- League/Overwatch internal pacing curves beyond measured average match length.

**Primary sources worth fetching next if you want to harden these:** the Slay the Spire GDC talk [GDC Vault 1025731](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics); the [Tarkov AIAS interview](https://www.youtube.com/watch?v=Vcz6ZpJeqtI) (full 86 min); [Hunt's Design Goals video](https://www.youtube.com/watch?v=YBoNaw2kHn8); and Mark Brown's GMTK pieces on [feedback loops](https://www.youtube.com/watch?v=H4kbJObhcHw) and [the two types of random](https://www.youtube.com/watch?v=dwI5b-wRLic).
