Research complete — ~60 sources pulled across 8 search rounds, including developer-primary interviews, systematic-review scholarship, platform telemetry, and Roblox creator/studio material. Below is the full reference document. Sources are tagged [scholarly], [dev-primary], or [secondary] per your scheme. Where a number is commonly reported but I couldn't pin it to a retrieved source this pass, it's marked *(unconfirmed)*.

---

# Addictive Continuous Gameplay Loops: A Cross-Genre Mechanical Reference

---

## 1. Slot Machines / Casino Design

**Session length.** Not measured in "sessions" by design — the unit is the *spin*, and the design goal is maximizing **time-on-device** as the primary profit metric. Schüll documents that the industry explicitly re-engineered machines in the 2000s to extend time-on-device: levers replaced with buttons, animations made skippable, coins replaced with virtual credits on loyalty cards — all to remove friction between bets and enable "instant re-betting" [dev-primary/industry, via scholarly review — [Hsu, Social Studies of Science review of *Addiction by Design*]](https://www.natashadowschull.org/wp-content/uploads/2018/06/book1review-SSS-Hsu.pdf).

**Feedback cadence.** The tightest in this entire document: one resolved outcome per button press, typically a few seconds per spin. The target state is the "machine zone" — "an affective state of calm equilibrium" produced by a "tight cybernetic loop between machine and player and by the machine's ability to give instant feedback," reached by "increasing the speed of betting until the point where the risks of each individual bet are smoothed out over thousands of plays, establishing a 'perfect contingency'" [scholarly — [Hsu/Schüll]](https://www.natashadowschull.org/wp-content/uploads/2018/06/book1review-SSS-Hsu.pdf).

**Stakes escalation.** Not within-session difficulty escalation but *volatility smoothing*: payout algorithms are tuned to increase the frequency of small wins over big ones, flattening the loss curve so the player's balance decays slowly enough to never trigger a stop decision [scholarly — [Hsu/Schüll]](https://www.natashadowschull.org/wp-content/uploads/2018/06/book1review-SSS-Hsu.pdf).

**Bad-outcome handling — the key mechanical finding.** Two documented disguises for losses:
- **Near misses** (symbols stopping one position off a jackpot): reliably increase motivation to persist and cause players to over-report how often they won; produce elevated skin-conductance arousal [scholarly — [Barton et al. 2017 systematic review, 51 studies]](https://pmc.ncbi.nlm.nih.gov/articles/PMC5663799/).
- **Losses disguised as wins (LDWs)**: on multiline machines, a "win" that pays back *less than the wager* still triggers full win audiovisuals. Measured on Lucky Larry's Lobstermania: players won on **15.6%** of spins, experienced LDWs on **17.1%** of spins, and cleanly lost on **67.3%** — yet skin-conductance response to LDWs was statistically indistinguishable from true wins. Net effect: ~1 in 3 spins produces a win-*signal* while the balance falls [scholarly — [Dixon et al., U. Waterloo]](https://uwaterloo.ca/reasoning-decision-making-lab/sites/default/files/uploads/files/DixFugetal_10c.pdf?ref=blog.woojinkim.org). Five studies confirm LDWs inflate players' estimates of win frequency [Barton et al., above].

**Scale numbers.** Atlantic City 2015: 16,384 machines → $1.73B (71% of all casino revenue). Nevada: 167k machines → $7.08B (63% of revenue). Macau 2016: 13,826 EGMs → $1.42B [scholarly — [Barton et al.]](https://pmc.ncbi.nlm.nih.gov/articles/PMC5663799/).

**Foundational framework.** John Hopson's *Behavioral Game Design* (Gamasutra, 2001) is the canonical mapping of Skinner's schedules onto games: ratio vs. interval, fixed vs. variable contingencies, and extinction avoidance — variable-ratio schedules produce the highest, most extinction-resistant response rates [secondary/design-primary — [Gamasutra]](http://www.gamasutra.com/view/feature/3085/behavioral_game_design.php?page=1); summarized with the three-phase **Anticipation → Action → Reward** compulsion-loop model at [GameAnalytics](https://www.gameanalytics.com/blog/the-compulsion-loop-explained) [secondary].

---

## 2. Mobile Gacha — Genshin Impact, Fate/Grand Order

**Exact mechanic numbers (Genshin).** Base 5★ rate **0.6%/pull**, flat for pulls 1–73; soft pity begins at pull **74** (~+6 percentage points per pull); hard pity guarantees at **90**. The 50/50: 50% chance the 5★ is the featured unit; since v5.0 (Aug 2024), "Capturing Radiance" quietly converts some losses, data-mined effective rate ≈ **55%**. Cost: 160 Primogems/pull ≈ $1.98 at best pack; the $4.99 Welkin Moon pass delivers ~3,000 Primogems over 30 days (<$0.28/wish) — a delayed-gratification discount that converts spenders into daily logins [secondary — [shattered.io]](https://shattered.io/is-genshin-impact-pay-to-win-2026/).

**Pity as a cross-banner asset.** The critical retention mechanic: pity progress *carries over* between banners. A player at 70 pity experiences every future pull as discounted; skipping a banner feels like abandoning invested capital. Design analysis frames banner gacha as a **Single-Bidder Myerson Auction** — each pull is an indirect bid, and "succeed-after-winning" (progress carries to the next target) mathematically out-generates "reset-after-winning" [secondary — [Jadhav, *How to Design Gacha Systems*]](https://kausthub.substack.com/p/how-to-design-gacha-systems). Recommended operator tactics from the same analysis: keep future banners secret to discourage hoarding; sequence generous free-pull periods into low-demand banners and scarcity into high-demand ones.

**FGO contrast.** FGO ran for years with *no* effective pity (its "USO" pity required ~10 copies of already-max-rarity units — functionally nothing); a real guarantee (330 pulls) only arrived in 2022 — yet it grossed **$5.4B by July 2021 and ~$7B by September 2023**; publisher Aniplex's revenue doubled to **$1.8B in FY2017-18** on FGO alone [secondary — [Wikipedia]](https://en.wikipedia.org/wiki/Fate/Grand_Order), [gamesindustry.biz]](https://www.gamesindustry.biz/fate-grand-order-drives-usd1-8-billion-revenue-for-sony-owned-aniplex). Lesson: character-attachment demand can carry a far harsher pity economy than Genshin's; spending is driven by emotional attachment built through lore *before* a unit becomes pullable ("Wanderer" effect) [secondary — [Jadhav]](https://kausthub.substack.com/p/how-to-design-gacha-systems).

**Whale concentration.** Across the genre: average paying player ≈ **$85/month**; the **top 2% of spenders generate ~72% of revenue** [secondary — [shattered.io]](https://shattered.io/is-genshin-impact-pay-to-win-2026/). Genshin: **$3.7B mobile revenue in its first 24 months**; >$10B lifetime by end of 2025 [same source].

**Session/cadence structure.** The within-session loop (resin/stamina caps, daily commissions) is a fixed-interval rationing layer; the *banner* (21-day limited window) is the escalation structure — urgency rises as the banner's expiry approaches, with the stop/continue decision ("pull now or save") fully informed except for the deliberately hidden future banner schedule.

---

## 3. Match-3 — Candy Crush Saga (King)

**Session/run length.** King's own GDC 2024 data science talk (head of central insights Jan Wedekind, senior director Xavier Guardiola): **"The longer the level is, the less likely it is to be fun"** — and maximum recommended level duration is *difficulty-dependent*: **if a level is really hard, it should be really short** [dev-primary — [mobilegamer.biz coverage of King's GDC talk]](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/).

**The canonical difficulty-spike finding.** Level 65 — originally built as the game's final stage — became "the highest converting level in the game and the stage that has made the most revenue ever," but also caused the most churn. King's A/B test result: raising difficulty raises short-term conversion, **but making the level easier retained players longer**, and "those players, like compound interest, will start growing and in subsequent levels they may start spending." Wedekind's conclusion: **"crazy hard levels never pay off, at least in the long term… retention always wins"** [dev-primary — same source].

**Measurement machinery.** King scores every level on **"time to abandon"** (intrinsic motivation proxy) vs. **"time to pass"** (difficulty proxy), explicitly to *disentangle fun from difficulty* — "hard levels can be fun… easy levels… can have no churn but not be much fun." Player skill is captured "in probably months or even weeks" from win/loss/attempt counts. King continuously identifies and reworks its **100 least-fun levels**, producing "a very significant uplift in engagement" [dev-primary — same source]. Scale context: millions of players past level 10,000, most never paying.

**Escalation & stop points.** The saga map is the meta-escalation; lives are the session gate — fail a level, lose a life, and the stop/continue decision is presented with full information (moves remaining, one-shot boosters, gold-bar purchase to continue). The fail screen is the monetization point: the level you've invested attempts into is *one purchase* from completion.

---

## 4. MOBA / Hero Shooter — League of Legends, Overwatch

**Session (match) length.** League of Legends: **30–45 min** typical [secondary — [thevaultohio]](https://www.thevaultohio.com/post/esports-game-durations-explained-impact-strategies-and-industry-insights). Hard telemetry from 623,281 ranked NA matches: mean **35:59** (Bronze) falling monotonically to **31:12** (Challenger), standard deviation ~8 min — better players close games faster, and high-elo matches have a "more predictable shape" [secondary data analysis — [LeagueMath]](https://www.leaguemath.com/match-duration-analysis/). Overwatch: **15–25 min** standard, Quick Play ~16–17 min [secondary — [r/Overwatch]](https://www.reddit.com/r/Overwatch/comments/38ekbt/average_game_length/), [Blizzard forums]](https://us.forums.blizzard.com/en/overwatch/t/game-matches-take-too-long/808816).

**Stop/continue decision points.** League's is the most formalized in the genre: the **surrender vote at 15:00** (unanimous at 15–19 min, 4/5 after 20; 3:30 remake if a player never connects) [secondary — [LoL Wiki]](https://leagueoflegends.fandom.com/wiki/Surrendering). The vote *is* the visible-information decision point: score, gold diff, and LP stake are all on screen. Notably, a failed 4–1 surrender vote in ranked correlates with a **97% loss rate** — players' read of "winnable" is accurate, and the one holdout extends a doomed session [secondary — [r/leagueoflegends]](https://www.reddit.com/r/leagueoflegends/comments/12cmyue/a_failed_41_surrender_vote_in_ranked_has_a_97/).

**Stakes escalation.** Within a match: gold/experience compounding means early outcomes *escalate* (a kill is worth more in tempo than its face value), with Baron/Elder buffs as forced late-game cliff events. Across matches: the **ranked ladder** converts every match into a stake — LP gains/losses, promos, decay — which is why the "one more game to end on a win" pattern is the genre's signature session-extender; loss-streak tilt is measurable in match data [secondary — [ranked-fatigue-analysis, Riot API study]](https://github.com/aceumlol/ranked-fatigue-analysis).

**Failure outcome.** Loss of LP/MMR only; all cosmetic/champion inventory kept. Overwatch per Blizzard's own matchmaker blog: "your MMR adjustment after every match is not impacted by your performance in each match" — pure outcome-based stake, which maximizes the informational clarity of the ladder decision [dev-primary — [Blizzard dev blog]](https://us.forums.blizzard.com/en/overwatch/t/overwatch-2-developer-blog-explaining-matchmaker-goals-and-plans-part-2/780306).

**Feedback cadence.** Kills/assists/CS/objectives every few minutes in-match; the loud signal is end-of-match: rank bar movement, MVP/POTG. Between-session cadence is the queue: near-zero downtime ("just one more") is the structural feature — matches are atomic, self-contained 15–45 min commitments with a guaranteed resolution.

---

## 5. Battle Royale — PUBG, Fortnite

**Match length.** Fortnite: **15–20 min typical, ~25 max** when the storm fully closes; Epic has repeatedly *shortened* matches — one patch cut storm wait/close times enough to make matches "up to 2 minutes & 28 seconds shorter" [secondary — [YouTube]](https://www.youtube.com/watch?v=pXpLkh7Cs4w), [HYPEX/X]](https://x.com/HYPEX/status/2081849380387131423?lang=en). Community estimate of the older, slower pacing: ~25 min full matches [secondary — [r/FortniteBR]](https://www.reddit.com/r/FortniteBR/comments/128twoj/public_matches_are_too_long/).

**Escalation curve — the cleanest engineered shape in any genre.** The storm circle is a **programmatic stakes-escalation function**: safe area shrinks on a fixed schedule, forcing encounter rate from near-zero (loot phase) to guaranteed (final circle). Every match has the same arc — sparse/loot → positional/mid → forced/endgame — which means every match *narratively peaks*. The shrinking circle is the mechanism that guarantees the session ends at maximum tension rather than petering out [secondary — [SSRN spatial-design paper]](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5676547), [ResearchGate design study]](https://www.researchgate.net/publication/375991241_Design_Implementation_and_Performance_Optimization_of_Battle_Royale_Games).

**Stop/continue decision & visible information.** Continuous and information-rich: player count remaining, circle timer, zone position, your loot quality — the player always knows their approximate standing and can disengage (avoid fights) or commit (push). Placement itself is the stakes dial: top-10 is visible survival value.

**Failure outcome.** Total within-match loss (you keep nothing from the match), but the meta-layer (BP progress, XP, quests) always advances — so even a 60-second death yields *some* visible progress, softening the re-queue decision. The ~seconds-long requeue to a fresh 100-player lobby is the loop-closer: loss → instant new chance at the win that "almost" happened.

**Feedback cadence.** Loot acquisition every 10–60s in early game (each chest/house a mini variable-ratio pull), eliminations and placement tickers through mid-game, and a single massive terminal signal (Victory Royale). Fortnite specifically layers a positive loop — simple looting plus growth-by-combat — that PUBG's slower, more punishing pacing lacks [secondary — [Medium comparative analysis]](https://medium.com/@madchunpodcast/pubg-vs-fortnite-game-feel-and-analysis-85771d5f18ab).

---

## 6. Clicker / Incremental Games

**Session & loop structure.** Orteil (Julien Thiennot), Cookie Clicker's creator, in his own words: "It wasn't meant to be fun! We just tapped into the core psychological appeal behind a lot of games: getting something done. Life is a confusing mess where progress is often unclear and unrewarding, but video games make goals much more explicit; for idle games it's as bare-bones as making a number go up" [dev-primary — [Waypoint/Vice]](https://www.vice.com/en/article/cookie-clicker-wasnt-meant-to-be-fun-why-is-it-so-popular-8-years-later/).

**Stakes escalation & the prestige reset.** The defining structure: exponential cost growth guarantees the player hits a wall where "you cannot produce enough cookies to reach the next upgrade" — the answer is **ascension** (a New Game Plus that converts accumulated progress into permanent multipliers), "then, you do the loop again." Thiennot describes deliberately "stretching the game out" over eight years, adding a minigame per building — "it's very convenient to have this endless design space" [dev-primary — same source]. Community consensus names the prestige loop itself as the genre's core: "the 'prestige loop' is the core of the game, and not just a bonus" [secondary — [NeoGAF incremental thread]](https://www.neogaf.com/threads/the-incremental-games-topic-cookie-clicker-is-a-genre-now.884591/).

**Failure outcome.** None — the genre's radical design choice. There is no loss state; the "bad outcome" is merely *slower progress*, and even offline time accrues. The wall is a pacing gate, not a punishment.

**Feedback cadence.** Dual-rate: per-click/per-second number increments (continuous, sub-second), purchase unlocks every few minutes early (decaying to hours/days late — the cadence is a deliberate decay curve), and rare stochastic events (golden cookies) as variable-interval jackpots. Reported engagement: players self-report "3–4 hours a day just watching… waiting for the golden cookies" and "thousands of hours over the years" [secondary — [Vice]](https://www.vice.com/en/article/cookie-clicker-wasnt-meant-to-be-fun-why-is-it-so-popular-8-years-later/). The genre was codified academically early via the GDC Vault talk *Idle Games: The Mechanics and Monetization of Self-Playing Games* ([GDC Vault](https://www.gdcvault.com/play/1022065/Idle-Games-The-Mechanics-and)) [dev-primary].

---

## 7. Deckbuilding Roguelikes — Balatro, Slay the Spire, Luck be a Landlord

**Balatro (LocalThunk).** Run structure: 8 antes × 3 blinds; community-measured full win runs run **~2–3 hours** (~24 rounds, 5–8 min each) [secondary — [r/balatro]](https://www.reddit.com/r/balatro/comments/1grfksd/winning_takes_forever/), [Steam discussions]](https://steamcommunity.com/app/2379780/discussions/0/4293690852337438680/); HowLongToBeat logs ~7.5h "main" and ~251h completionist [secondary — [HLTB]](https://howlongtobeat.com/game/132112). The designer's own account of the escalation engine: "The central mechanic is to score as many chips as possible to defeat an ever rising required score. There are a bunch of interlocking mechanics that allow you to score more chips as you progress" — and crucially, the metastrategy he observed emerging is **risk mitigation**: "the discourse has been shifting more and more towards risk reduction" — players build runs that can't be countered by boss blinds [dev-primary — [Rogueliker interview]](https://rogueliker.com/balatro-interview/). On failure: the run is lost but meta-unlocks persist; on cadence, every blind (~5 min) resolves to a shop — a guaranteed reward-and-rebuild beat. The poker skin was explicitly "an onboarding tool": "People love to hold a set of cards in their hand, organize and arrange them… such a simple and familiar approach to strategy games that are usually very information dense" [dev-primary — same source]. Commercial: 500k copies in ~2 weeks, 1M+ within a month [secondary — [TouchArcade]](https://toucharcade.com/2024/03/18/balatro-interview-mobile-port-localthunk-dlc-plans-updates-new-jokers-demo-feedback/).

**Slay the Spire (MegaCrit).** Run = 50–54 floors across 3 acts; measured runs **~30–55 min** typical (Ironclad ~30 min avg), 90–120 min for full victory runs [secondary — [r/slaythespire]](https://www.reddit.com/r/slaythespire/comments/1aeqnx1/how_long_do_your_runs_usually_take/), [slaythespire.info]](https://slaythespire.info/en/i-looked-into-the-time-required-for-a-single-run-broken-down-by-character/), [Kinglink review]](https://kinglink-reviews.com/2019/08/25/slay-the-spire-review/). The decision structure is the escalation: map pathing makes every node a visible-information stop/continue choice (elite = higher risk/reward, rest site = heal-vs-upgrade trade), and "damage is so hard to avoid in each and every combat that it always feels like there are stakes to every decision" [secondary — [The Gemsbok]](https://thegemsbok.com/art-reviews-and-articles/slay-the-spire-mega-crit-games-outside-help-tips-wikis/). The **Ascension** system (20 escalating difficulty modifiers) is the post-mastery retention layer. Failure: total run loss, partial meta-progress (unlocks); because a run is only ~45 min, the restart cost is low — the engine of "one more run."

**Luck be a Landlord (TrampolineTales).** The slot machine *as* roguelike: spins generate symbols; **rent is due every N spins and doubles**, so the escalation curve is a literal exponential debt clock — each rent payment survived resets the tension at a higher baseline. Symbols persist and synergize, so the deckbuild *is* the slot's paytable. Direct lineage: LocalThunk credits LbaL videos as the trigger for Balatro's single-player solitaire direction — "I really appreciated the scoring mechanics in that game and the lighter theming" [dev-primary — [Rogueliker]](https://rogueliker.com/balatro-interview/). Developer postmortem and long-form design interviews: [dev-primary — [TrampolineTales blog]](https://blog.trampolinetales.com/whats-next-for-luck-be-a-landlord/), [Dev Dive video interview]](https://www.youtube.com/watch?v=BRdZkPyjC3I).

---

## 8. Extraction Shooters — Escape from Tarkov, Hunt: Showdown

**Session (raid) length.** Tarkov raids are hard-capped per map, roughly **~20–50 minutes** (small maps shorter; a documented 45-min Shoreline raid walkthrough is typical of mid-size maps) *(map-by-map timers: wiki-standard, unconfirmed against primary patch notes this pass)* [secondary — [MTBtrigger raid breakdown]](https://www.youtube.com/watch?v=fdzJSANEvHs). Hunt: Showdown matches are capped at **45 minutes** (update 1.9; most action resolves in the first ~20) [secondary — [r/HuntShowdown]](https://www.reddit.com/r/HuntShowdown/comments/vbfxpd/new_match_time_limit_45_minutes_update_19/).

**Stakes escalation — the genre's core invention.** Everything you carry in is wagered; everything you find is only *yours* if you extract. Escalation is endogenous: every minute in-raid your backpack's value (and thus the cost of death) grows — the stakes curve is the loot accumulation curve itself. Tarkov's **"Found in Raid"** rule formalizes the stop/continue gate: to keep items' quest/flea value you must extract with "Survived" status — which requires **≥200 EXP earned or ≥7 minutes in-raid**, explicitly blocking zero-risk dash-and-grab runs [secondary (official rules reference) — [Tarkov Wiki]](https://escapefromtarkov.fandom.com/wiki/Found_in_raid).

**Stop/continue decision with visible information.** The extraction decision is continuous and fully informed: you can always see your haul, the raid timer, and (in Hunt) the bounty carriers' locations. Hunt adds a formal double-gate: extraction takes **30s undefended, 60s with a bounty** — carrying the prize literally doubles your exposure window, and the banish/bounty-scan system *broadcasts* your position to the lobby [secondary — [Steam discussions]](https://steamcommunity.com/app/594650/discussions/8/6278597937782761851/?l=italian). Hunt also layers a daily-retention mechanic onto it: bonus XP/dollars for your **first bounty extraction with each hunter per day** [dev-primary — [Crytek developer highlight]](https://www.youtube.com/watch?v=5v4UBVLA5jY).

**Failure outcome — the harshest in this document.** Death = loss of all carried gear ("gear fear" is the community's name for the resulting risk aversion). Mitigation is partial and priced: **insurance** returns gear only if no player loots it, after a real-time delay; the **secure container** preserves a few items regardless — a designed "you never lose everything" floor that keeps the loss painful but never total [secondary — [Tarkov community/wiki]](https://escapefromtarkov.fandom.com/wiki/Found_in_raid), [r/EscapefromTarkov]](https://www.reddit.com/r/EscapefromTarkov/comments/o8u9jm/no_more_secure_containers/). Periodic full **wipes** reset the entire economy — the genre's macro-escalation reset.

**Designer framing.** Nikita Buyanov (Battlestate head) positions Tarkov as having *created* the genre: "maybe create another genre, like how I did with extraction shooters" — and describes the decade of live iteration as the design process itself [dev-primary — [Buyanov via IGN/DualShockers]](https://www.dualshockers.com/bsg-nikita-buyanov-escape-from-tarkov-testing-phase/); long-form: [Game Maker's Notebook podcast]](https://interactive.libsyn.com/website/escape-from-tarkov-and-the-creation-of-extraction-shooters-with-nikita-buyanov), [Access Granted interview]](https://www.youtube.com/watch?v=pcetkc8gq1w).

---

## 9. Looter Shooters / ARPGs — Diablo, Path of Exile

**The foundational mechanism.** David Brevik's GDC 2016 *Classic Game Postmortem: Diablo* is the genre's primary source: loot was explicitly built from **D&D-style random loot tables**, and Brevik has described the item slot machine as the point — every kill is a pull on a randomized paytable, with item quality tiers as the jackpot structure [dev-primary — [GDC Vault]](https://gdcvault.com/play/1023469/Classic-Game-Postmortem), full talk [YouTube]](https://www.youtube.com/watch?v=VscdPA6sUkc), coverage [PC Gamer]](https://www.pcgamer.com/diablo-designer-david-breviks-full-gdc-post-mortem-is-now-online/).

**Feedback cadence.** The densest reward stream of any RPG genre: every enemy kill is a roll (seconds), with visible tier color-coding (white→blue→yellow→orange/green) as an at-a-glance excitement hierarchy — the *sound and beam* of a rare drop is a slot-machine audiovisual jackpot by design. Session scale is the dungeon clear (tens of minutes); the macro loop is difficulty-tier climbing (Torment/Maps) with paragon-style infinite vertical progression so the loop never terminates.

**Why loot excitement fails when tuned wrong — the PoE GDC finding.** The GDC talk *Meaningful Loot & Efficient Trading* ( Grinding Gear's Chris Wilson era design philosophy, discussed widely in the PoE community): "The reason why players don't feel excitement at loot drops is simple: the quantity of nearly zero-value items is unfathomably large" — i.e., **excitement is a function of the value distribution, not drop frequency**; a loot filter (community-built) became mandatory UI precisely because raw drop volume exceeds human filtering [secondary — [r/pathofexile discussion of the GDC talk]](https://www.reddit.com/r/pathofexile/comments/f0s7h5/interesting_gdc_talk_meaningful_loot_efficient/).

**Failure/keep structure.** Softcore ARPGs: death costs time/durability only — the wager is minimal and the pull-rate is the hook. Diablo II's gamble/vendor and rune economy, and PoE's crafting-as-gambling (currency items are literally re-roll tokens), move the slot mechanic *into the economy*: every chaos orb is a paid pull on an item's affix table. Blizzard's own D4 *Loot Reborn* redesign (Season 4) — fewer, stronger drops; deterministic tempering/masterworking layered on random base rolls — is the modern live tuning of exactly this tension [dev-primary — [Blizzard]](https://www.youtube.com/watch?v=awvOopWqiHU).

---

## 10. Social / Casual Mobile — Clash Royale, Coin Master

**Clash Royale (Supercell).** Match: **3:00 + 1:00 overtime** on draw [secondary — [Deconstructor of Fun]](https://www.deconstructoroffun.com/blog//2016/02/clash-royale-next-billion-dollar-game.html). The retention architecture is the **chest economy**: chests take **3 / 8 / 12 hours** to unlock by rarity, **only one unlocks at a time**, inventory capped at **4** — win more than your unlock rate and you stop earning chests entirely: a soft progression blocker that converts "one more match" into "come back in 3 hours." Free chests on a **4-hour** timer (buffer of 2 = "conveniently the average length of a work day"); Crown Chests on a **24-hour** timer [secondary — [GameDeveloper breakdown]](https://www.gamedeveloper.com/design/breaking-down-supercell-s-next-hit-clash-royale). Key design credits: battles cost **zero resources** ("players can play for hours on end" — a deliberate break from build-and-battle energy gates), and chest timers create "a very positive return session, which rewards a player for the battle they won hours ago" — the appointment mechanic as *reward you already earned* [secondary — [Deconstructor of Fun]](https://www.deconstructoroffun.com/blog//2016/02/clash-royale-next-billion-dollar-game.html). Within-match cadence: elixir ticks every ~2.8s (2x in final minute, 3x in overtime) — the pacing accelerates toward the timer, an in-match escalation curve compressed into 180 seconds. Design philosophy primary source: Stefan Engblom's GDC 2017 *Quest for the Healthy Metagame* [dev-primary — [GDC Vault]](https://www.gdcvault.com/play/1024272/Quest-for-the-Healthy-Metagame), [YouTube]](https://www.youtube.com/watch?v=bHLQQh8Ctu4).

**Coin Master (Moon Active).** A slot machine wearing a village-builder skin — the genre blur is the design: spins (5 free spins per **50 minutes** — the energy gate) → coins/raids/attacks/shields → village upgrades → saga-map progression → higher jackpots [secondary — [GameAnalytics/Deconstructor of Fun]](https://www.gameanalytics.com/blog/coin-master-social-casino). The social layer is the differentiator vs. pure slots: **attacks and raids steal real coins from real friends**, generating revenge loops; shields are consumable defense rolls from the same slot. Cadence architecture per Funovus's teardown: multiple **milestone systems deliberately offset in time** so reward windfalls align or interleave — "each milestone system has a start and end time, so players know when the next influx of rewards will be. This acts as a magnet to pull players back" — plus short timed boost windows that let players feel they're "outsmarting the game by being an opportunist," and shop offers surfaced *exactly* when the player runs out of spins [secondary — [Funovus]](https://www.funovus.com/blogs/coin-master/). Scale: category-leading — slots are ~78% of social-casino revenue; Coin Master's January revenue grew **+250% YoY** at its breakout [secondary — GameAnalytics, above].

---

## 11. Design-Analysis YouTube Channels (non-Roblox)

**Game Maker's Toolkit (Mark Brown).** The compulsion-loop reference episode is *"Addictive" Gameplay Loops and Compulsion Exit Ramps* — its core taxonomy: the **compulsion loop** (the designed anticipation→action→reward chain) vs. the **exit ramp** (a designed stopping cue — or its absence). The catalog of loop techniques named: daily login ladders, appointment timers, energy systems, loss-aversion streaks, and investment-based sunk-time returns [secondary — [YouTube]](https://www.youtube.com/watch?v=E-O-6QzrNr0), write-up [access-ability.uk]](https://access-ability.uk/2022/04/25/addictive-gameplay-loops-and-compulsion-exit-ramps/). Broader channel: [GMTK]](https://www.youtube.com/c/MarkBrownGMT%7D).

**Adam Millard — The Architect of Games.** *How Gameplay Loops Keep You Playing* is the direct loop-anatomy essay — loops as the foundational retention trick, nested micro/meso/macro layers [secondary — [YouTube]](https://www.youtube.com/watch?v=Sk-nbAtIUko). Adjacent relevant essays: *Are Games Getting Too Random?* (RNG as engagement engine), the hour-long *Balatro……* breakdown, and *How "Bad" Balance Can Be A Good Thing* (asymmetry creating pursuit) [secondary — [channel]](https://www.youtube.com/@ArchitectofGames/videos). *(Note: full transcripts were not retrievable this pass — video-level claims above are from titles/abstracts; treat mechanic specifics as unconfirmed.)*

**Design Doc.** Genre-and-element video essays — ongoing series on what makes specific design decisions work (e.g., *What Makes A Great Impossible Boss?*), with focus on how small decisions compound into cohesive experiences rather than monetization loops [secondary — [channel]](https://www.youtube.com/channel/UCNOVwMpD-5A1xzcQGbIHNeA).

**Game Wisdom (Josh Bycer).** Daily design-theory essays and developer livecasts — strongest on systemic analysis of why repetitive design succeeds or fails (*Why Objective Game Design Doesn't Work*, *When Repetitive Design Fails*) [secondary — [channel]](https://www.youtube.com/c/game-wisdom), [game-wisdom.com]](https://game-wisdom.com/about).

**Extra Credits.** The earliest mainstream channel treatment of these topics — operant conditioning, the Skinner box episodes, and "addiction" mechanics framed for a lay audience; historically important as the gateway source but largely derivative of Hopson's *Behavioral Game Design* (Section 1) [secondary]. *(Direct episode URLs not re-verified this pass — unconfirmed.)*

---

## 12. GDC Vault, Postmortems, Blogs, Scholarship — Consolidated Primary Sources

| Source | Type | Key contribution |
|---|---|---|
| Hopson, *Behavioral Game Design* (Gamasutra 2001) | [dev-primary]/foundational | Skinner schedules → games; variable-ratio = highest persistence; extinction avoidance [link](http://www.gamasutra.com/view/feature/3085/behavioral_game_design.php?page=1) |
| Schüll, *Addiction by Design* (2012) | [scholarly] | Machine zone, time-on-device, speed-of-play engineering, small-win smoothing [review](https://www.natashadowschull.org/wp-content/uploads/2018/06/book1review-SSS-Hsu.pdf) |
| Barton et al. 2017 (51-study review) | [scholarly] | Near-miss & LDW effects on persistence/arousal [link](https://pmc.ncbi.nlm.nih.gov/articles/PMC5663799/) |
| Dixon et al. (Waterloo) | [scholarly] | LDW arousal = win arousal; 15.6/17.1/67.3% outcome split [link](https://uwaterloo.ca/reasoning-decision-making-lab/sites/default/files/uploads/files/DixFugetal_10c.pdf?ref=blog.woojinkim.org) |
| Brevik, *Diablo* postmortem (GDC 2016) | [dev-primary] | Random loot tables as core loop [link](https://gdcvault.com/play/1023469/Classic-Game-Postmortem) |
| Engblom, *Healthy Metagame* (GDC 2017) | [dev-primary] | Clash Royale balance philosophy [link](https://gdcvault.com/play/1024272/Quest-for-the-Healthy-Metagame) |
| King GDC 2024 (Wedekind/Guardiola) | [dev-primary] | Level-65 lesson; time-to-abandon vs time-to-pass; "retention always wins" [link](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/) |
| *Idle Games* GDC Vault | [dev-primary] | Idle mechanics codified [link](https://www.gdcvault.com/play/1022065/Idle-Games-The-Mechanics-and) |
| Daniel Cook, *Loops and Arcs* (Lost Garden) | [dev-primary] | Nested loop architecture grammar [link](http://www.lostgarden.com/2012/04/loops-and-arcs.html?m=1) |
| Deconstructor of Fun | [secondary] | Clash Royale & Coin Master teardowns [link](https://www.deconstructoroffun.com/blog//2016/02/clash-royale-next-billion-dollar-game.html) |

---

## 13. Roblox — Creators, DevForum, and Studio-Level Primary Material

### Platform telemetry context (the numbers the algorithm optimizes)
Roblox's discovery algorithm rewards **session length and day-over-day retention** above all else — "the difference between a 50 CCU game and a 50,000 CCU game isn't code quality — it's how well the game is engineered around human behavior." Design rules given: core loop explainable in one sentence; "playing within seconds, not reading instructions"; immediate positive reinforcement on first interaction [secondary (experienced-dev long-form) — [DevForum]](https://devforum.roblox.com/t/why-your-technically-superior-game-isn%E2%80%99t-succeeding-on-roblox-and-why-the-algorithm-ignores-it/4461606). Platform-wide average session length sits around **~11 minutes** per RoMonitor's platform stats (its homepage banner reports an average session length in that band) [secondary telemetry — [RoMonitor Stats]](https://romonitorstats.com/); per-experience examples: branded experiences ~5.4 min, top experiences ~11 min with ~80% returning-ish rates [secondary — [RoMonitor branded]](https://romonitorstats.com/branded/). DevForum practitioner data points: a developer's three games with *real* average sessions of **9, 16, and 30 minutes** [dev-primary — [DevForum analytics thread]](https://devforum.roblox.com/t/analytics-engagement-average-session-time/2667529); a failing-game autopsy: **~3-minute average playtime, ~1% D1 retention, only ~50% tutorial completion**, with the largest drop-off at the first hatching step — responder prescription: remove failure from the tutorial, make the first egg "insanely easy," add multiplayer because "players love to show off, they love to compete" [dev-primary — [DevForum]](https://devforum.roblox.com/t/game%E2%80%99s-retention-and-average-session-time-extremely-low/4269329). A separate 3-month telemetry study found **45% of players leave within the first 30 seconds** — the first half-minute is the entire funnel [dev-primary — [r/robloxgamedev]](https://www.reddit.com/r/robloxgamedev/comments/1sakqj4/i_tracked_retention_on_my_roblox_game_for_3/) *(snippet-confirmed; full post blocked)*.

### Developer YouTubers
- **BruceDevs** — the most numbers-transparent Roblox dev-creator: *"How I made 23M ROBUX this year as a small Roblox developer (5M Visits)"* (17 min) and *"DevExing $6,000,000 Robux"* document actual DevEx-scale revenue for a small developer; *"why YOU are failing as a Roblox Developer"* covers his read of the algorithm (session/retention weighting) [dev-primary — [channel]](https://www.youtube.com/@1_Bruce), [23M Robux video]](https://www.youtube.com/watch?v=wKI3PBO3bB0), [algorithm video]](https://www.youtube.com/watch?v=i3RQXxZeVYc). *(Transcripts unretrievable this pass — specific in-video mechanics unconfirmed.)*
- **TizzyBlox (Tizzy RBLX)** — the closest thing to a Roblox GMTK: *"Roblox Game Design Explained Like You're 5"* advances an **"80/20 formula behind EVERY viral hit"**; *"I Found 5 Things That Guarantee a Viral Roblox Game"*; and numbers-bearing dev-diary titles like *"I Made ANOTHER $25,070/mo Roblox Game (13.1k CCU)"* — real revenue-per-CCU data points from a working developer [dev-primary (own games) / secondary (others') — [video]](https://www.youtube.com/watch?v=CRCcsYEB_6A), [5 Things]](https://www.youtube.com/watch?v=FnsIL4zPCQg), [$25k/mo]](https://www.youtube.com/watch?v=nggNvUILQ1I). *(In-video specifics unconfirmed — no transcripts.)*
- **SmartyRBX** — dev commentary/motivation channel (~700 videos) aimed at working developers; recurring topics: how pros learned, developer economics (e.g., the "14-year-old making $100k/month" interview lineage) [secondary — [channel]](https://www.youtube.com/@SmartyRBX), [live Q&A]](https://www.youtube.com/watch?v=B5JXM3dmqMY).
- **AlvinBlox, Fireology, Zurpz** — primarily *tutorial/education* channels (scripting series, beginner guides) rather than loop-analysis; their contribution to this library is onboarding craft, not retention mechanics [secondary — e.g., [AlvinBlox ep.1]](https://www.youtube.com/watch?v=aX0Kw_txrIY). *("Zurpz" returned no verifiable channel this pass — treat as unconfirmed/likely conflated name.)*

### Studio-level hits (dev-primary where possible)
- **Adopt Me (Uplift Games).** Official studio numbers: **22B+ visits, 1.92M record CCU** (Ocean Egg update, April 2021), **30M→60M+ MAU** in 2020-21, **+400% YoY revenue (2020)**, 40-person studio. The named mechanism: a **regular content-drop cadence** (egg updates as appointment events that spike CCU records) plus collection/trading as the social retention layer [dev-primary — [Uplift Games launch release]](https://www.uplift.games/blog/uplift-games-launch-release).
- **Fisch (WoozyNate).** The richest single Roblox dev-primary source found. Built solo in **4 months**; core design philosophy stated outright: open-ended with **more than one "end goal"** — "retention of players relies on the ability to play a game in multiple ways. They should always have a reason to come back." Mechanics credited: Stardew-style fishing minigame with per-fish "Resilience" stat (difficulty dial per catch); **procedural fish mutations (~25 per fish: weight seeds, shiny/sparkling variants)** — the collection surface is near-infinite; rods differentiated by *use case* not power (no single "best rod"); islands as exploration gates. LiveOps doctrine: events must add "a new challenge, feature, or exclusive gift" plus lore — FischFright added time-windowed exclusive fish "creating a sense of urgency," with ingredient hunts every **30–60 minutes**. Results cited: steady "tens of thousands" CCU post-event, **~470,000 CCU peak** [dev-primary — [Roblox Creator Spotlight, DevForum]](https://devforum.roblox.com/t/creator-spotlight-woozynate-makes-a-splash-with-fisch/3269481); companion video: [Inside the Development of Fisch]](https://www.youtube.com/watch?v=24EdKhjcMuo).
- **Pet Simulator 99 (BIG Games).** The update machine: dev blog shows **weekly shipped updates** (Update 86→95 across ~9 weeks in 2026), every one structured identically — new RNG hatch/roll target ("Roll for 14 pickaxe powers!", "Craft 1 of 3,000 TITANICs"), a limited-time exclusive, a leaderboard/clan battle, and a time-gated drop ("hourly RAFFLE", "hourly chests"). Named loop: grind currency → hatch eggs (visible rarity ladder: normal→gold→rainbow→shiny→Huge→**Titanic/Gargantuan**) → trade → leaderboard. The *hatch* is the slot pull; "Huge/Titanic" rarity tiers are the jackpot audiovisual [dev-primary — [BIG Games dev blog]](https://biggames.io/post). Estimated cumulative earnings for BIG Games: **~$200M+** (community estimate, [secondary — [YouTube documentary]](https://www.youtube.com/watch?v=OzpU6augtD8)); studio reportedly on track for **$5M+/year** at sale rumors [secondary — [SuperBiz/X]](https://x.com/superbiz_/status/1950176461899325948).
- **Grow a Garden.** 16-year-old original creator; later co-owned by Janzen "Jandel" Madsen with Do Big Studios taking a minority stake and pushing monetization that "increase[s] the pace of its idle element." The core trick: **your garden grows while you are offline** — idle progression as the return-hook — plus seed-shop restock timers and weather events as scheduled FOMO beats. Numbers: launched March 25, 2025 → **#1 Robux-spending experience within one month**, peak **21.3–22M CCU** (June–July 2025) — surpassing Fortnite's all-time 15.3M record and every Steam game ever [secondary — [GameDeveloper]](https://www.gamedeveloper.com/business/roblox-s-grow-a-garden-had-nearly-22-million-concurrent-users-in-july), [PocketGamer.biz]](https://www.pocketgamer.biz/robloxs-peak-concurrent-user-count-hits-record-474m-as-steal-a-brainrot-and-grow-a-garden-compete/).
- **Steal a Brainrot (SpyderSammy / Do Big Studios).** Loop: conveyor-belt purchase of income-generating "brainrots" (**income ticks every few seconds**) → defend with a **temporary shield button** → or *steal from other players' bases* ("capture the flag" loop) → rebirth reset for permanent multipliers. Critic-cited addictiveness driver: "lack of complexity and straightforward gameplay loop." The escalation/engagement weapon is the **"Admin Abuse" event**: the developer drops into public servers unannounced, spawns rares and chaos — recurring scheduled variants (Taco Tuesday) make players "camp the track" for event-only spawns. Numbers: launched May 16, 2025 → 7B visits by July → CCU ladder **5M (Jul) → 20M (Aug 23, during a staged "admin war" with Grow a Garden's Jandel) → 24M (Sep 13) → 25.4M (Oct)** — the largest CCU ever recorded for a game; the admin-war week drove Roblox's platform record to **47.4M concurrent** [secondary — [Wikipedia]](https://en.wikipedia.org/wiki/Steal_a_Brainrot), [Eldorado]](https://www.eldorado.gg/blog/steal-a-brainrot-en/sammy-steal-a-brainrot-guide/), [PocketGamer.biz]](https://www.pocketgamer.biz/robloxs-peak-concurrent-user-count-hits-record-474m-as-steal-a-brainrot-and-grow-a-garden-compete/).
- **Blox Fruits (Gamer Robot).** The longevity case: 5B visits (Apr 2022) → 15B (Apr 2023) → 20B (Aug 2023) → 50B-visit event (2025-26); ~2.78M peak CCU. Retention credit per community: unusually **fast, trailer-driven update cadence** (numbered "Updates" with YouTube trailers as marketing beats) over a bandit/RNG fruit-spawn core loop [secondary — [Wikitubia]](https://youtube.fandom.com/wiki/Gamer_Robot), [r/bloxfruits]](https://www.reddit.com/r/bloxfruits/comments/1fedkc8/blox_fruits_developers_are_so_quick_with_updates/), [Gamer Robot]](https://www.youtube.com/c/GamerRobot).

---

## 14. Synthesis — General-Purpose Numbers & Shapes

**Session-length bands (what shipped successes actually use):**

| Band | Genre examples | Design implication |
|---|---|---|
| 3–10 s atomic loop | Slots (spin), clickers (click), gacha pull | Sub-10s resolution; the *loop* is the session |
| 3–4 min match | Clash Royale (3+1), Roblox avg session floor (~3 min failing) | Maximum sessions/day; chest-timer gates become the meta-loop |
| ~10–25 min | Fortnite (15–20), Overwatch (15–25), Hunt action phase (~20 of 45), Slay the Spire short runs (30), Roblox healthy games (9–16 min avg) | The dominant "contained session" band — one complete arc with a guaranteed resolution |
| 30–50 min | League (31–36), Tarkov raids (20–50 cap), Slay the Spire full runs | Requires intra-session escalation + a formal surrender/extraction decision point |
| 2–3 h runs | Balatro win runs, incremental "active" phases | Only works with per-5-min reward beats (shops/blinds) inside |

**Escalation curve shapes (named, reusable):**
1. **Programmatic shrink** (BR storm, Tarkov raid timer): schedule forces encounter density to 100% at session end. Guaranteed climax.
2. **Exponential debt clock** (Luck be a Landlord rent doubling, incremental cost growth): the wall arrives on schedule; reset/prestige is the release valve.
3. **Compound-interest stakes** (MOBA gold, extraction loot accumulation): time-in-session *is* the stake; later minutes are worth more.
4. **Rising threshold** (Balatro antes, Candy Crush saga map): fixed goalposts, scaling requirement; King's corollary — **hard levels must be short levels**, and long-term retention beats short-term conversion ("retention always wins").
5. **Ladder stake** (ranked LP): stakes live *across* sessions; the session is merely where they're settled.

**Stop/continue decision-point patterns:** (a) *formal vote* (LoL surrender at 15:00 — needs full information on screen); (b) *extraction gate* (Tarkov/Hunt — leaving early forfeits upside; Hunt prices it literally: 30s vs 60s exposure); (c) *inventory-full gate* (Clash Royale chests — playing on yields zero, pushing the stop decision to a timer); (d) *energy/spins depletion* (Coin Master 5/50min, lives systems) with a purchase offered at the exact depletion moment; (e) *pity proximity* (gacha — every stop is framed as abandoning invested progress).

**Failure-penalty tuning ladder (softest → harshest):** incrementals (no loss state) → BR (match loss, meta-progress kept) → MOBA (rank points only) → roguelikes (run lost, ~30–60 min, meta-unlocks kept — cheap restart is the point) → extraction (full gear loss, softened by insurance/secure-container floors) → slots (continuous monetary loss, disguised by LDWs at ~17% of outcomes + near-misses). The recurring pattern: **even the harshest systems install a "you never lose everything" floor** (secure container, insurance, kept unlocks).

**Feedback cadence targets:** visible reward signal every **<10 s** at the atomic layer (spin/click/kill/loot tick); a *decision or upgrade* beat every **30 s–5 min** (shop, chest, node choice); a *session-level resolution* every **3–50 min**; *appointment beats* at **4 h / 24 h / weekly** (free chests, crown chests, Roblox weekly updates, Fisch events every 30–60 min *within* events); *macro resets* seasonally (wipes, ranked splits, prestige).

**Cross-cutting validated numbers:** top 2% of spenders ≈ 72% of gacha revenue; LDWs ≈ 17% of slot outcomes registering as wins; 45% of Roblox players gone in the first 30 seconds; King's level-65 lesson (highest-revenue level = highest-churn level); Roblox healthy-session band 9–30 min; Grow a Garden 22M CCU / Steal a Brainrot 25.4M CCU proving the ceiling of simple-loop + scheduled-event design.

---

**Known gaps (marked rather than silently dropped):** full transcripts for the GMTK/Adam Millard/BruceDevs/TizzyBlox/SmartyRBX/Fisch-event/Buyanov videos were unretrievable this pass (their listings above are title/abstract-level); "Zurpz" could not be verified as a real channel; per-map Tarkov raid timers and Brevik's exact drop-rate anecdotes are wiki/lore-standard but not re-confirmed against the primary sources in this round.# Mechanical Design of Contained, Continuous Gameplay Loops: A Cross-Genre Reference

## How to read this document

Each genre section uses the same six fields: **session/run length**, **stakes-escalation curve**, **stop-or-continue decision points and visible information**, **bad-outcome handling (what is kept vs. lost)**, **feedback cadence**, and **published or informal numbers**. Every source carries one of three tags:

- **[scholarly]**: peer-reviewed or academic work.
- **[dev-primary]**: the studio's or designer's own words, including a Roblox creator discussing their own game.
- **[secondary]**: analysis, wikis, trackers, journalism or commentary.

Where a figure is my own arithmetic from cited inputs, it is labelled **(computed)**. Where a figure comes from general game knowledge that I could not re-verify in this session, it is labelled **(unverified)**. The "Data Limitations" section at the end lists every gap.

---

## 1. Slot machines and casino electronic gaming machines (EGMs)

### Session/run length and cycle time
A slot's contained loop is the single spin. On traditional mechanical-reel games, a player can spin about every 6 seconds (about 10 spins per minute, or 600 per hour). On video slots, a player can spin about every 3 seconds, or 1,200 per hour [cdspress.ca (Harrigan & Dixon, PAR-sheet study)](https://cdspress.ca/wp-content/uploads/2022/08/Kevin-A.-Harrigan-Mike-Dixon-.pdf) **[scholarly]**. There is no natural end to a session. The loop repeats until the credit meter hits zero or the player stops. Anthropologist Natasha Dow Schüll spent 15 years studying how slot design keeps players engaged "for more than 12 hours at a time" in what she calls the "machine zone" [KNPR](https://knpr.org/show/knprs-state-of-nevada/2012-10-03/gambling-addiction-the-machine-zone) **[scholarly/secondary interview]**.

### Stakes escalation within a session
A slot does not escalate on its own. The house edge is flat per spin. Any escalation comes from the player choosing a higher bet per line or more lines. The design lever is the payback-percentage version. Machines that look identical to the player can range from 85% to 96.2% payback. The PAR-sheet study uses *Lucky Larry's Lobstermania* as its example [cdspress.ca](https://cdspress.ca/wp-content/uploads/2022/08/Kevin-A.-Harrigan-Mike-Dixon-.pdf) **[scholarly]**.

### Stop/continue decision and visible information
The decision comes after every spin, with no forced break. The player sees the credit meter, the last result and, on multi-line games, which lines "won." Two engineered signals shape this decision:

- **Near misses.** These are manufactured through **symbol clustering**. The high-paying Double Diamond symbol appears five times more often just above or below the payline than on it. **Asymmetric reels** also help: one reel is "starved" of the bonus symbol, which raises near-miss frequency and lowers wins [cdspress.ca](https://cdspress.ca/wp-content/uploads/2022/08/Kevin-A.-Harrigan-Mike-Dixon-.pdf) **[scholarly]**.
- **Losses disguised as wins (LDWs).** On a 15-line game at 5 credits per line (a 75-credit bet), a 30-credit "win" is a 45-credit net loss. The machine still celebrates it with the same sounds and animations as a real win [PMC (Barton et al. 2017 systematic review)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5663799/) **[scholarly]**.

The Barton review covered 51 studies. It found that near misses were "significantly more arousing, motivating, and frustrating than losses" and "motivate continued play." More frequent LDWs were associated with players overestimating how much they were winning, driven by the celebratory audio and visuals [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5663799/) **[scholarly]**. A 2024 online-slot study likewise found that wins significantly increased subsequent spin behaviour. It also tested the combined effects of LDWs and near misses [APA PsycNet (Palmer et al. 2024)](https://psycnet.apa.org/fulltext/2024-81139-001.html) **[scholarly]**.

### Bad outcome
A losing spin forfeits the stake, and nothing carries over. What makes a loss tolerable is the prize distribution. In *Lobstermania*, prizes of 2 and 5 credits make up about 70–75% of all winning hits [cdspress.ca](https://cdspress.ca/wp-content/uploads/2022/08/Kevin-A.-Harrigan-Mike-Dixon-.pdf) **[scholarly]**. Small, frequent returns keep the balance draining slowly instead of collapsing.

### Feedback cadence
Hit frequency (the share of spins that win something on a given line) ranges from 4.9% on the 85%-payback *Lobstermania* to 16.7% on *Money Storm*. It barely changes between payback versions of the same game [cdspress.ca](https://cdspress.ca/wp-content/uploads/2022/08/Kevin-A.-Harrigan-Mike-Dixon-.pdf) **[scholarly]**. At a 3-second spin and 16.7% single-line hit frequency, that is one win signal roughly every 18 seconds **(computed)**. On multi-line games the rate of celebrated outcomes is much higher, because LDWs trigger the same celebration.

### Numbers
In 2015, 16,384 slot machines in Atlantic City produced $1.73 billion, about 71% of all casino revenue in the city. In Nevada, 167,000 machines produced $7.08 billion. In Macau in 2016, 13,826 EGMs produced about $1.42 billion [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5663799/) **[scholarly]**.

---

## 2. Mobile gacha (Genshin Impact, Fate/Grand Order)

### Session/run length
The contained loop is the pull: one pull or a 10-pull. In Genshin one wish costs 160 primogems [Genshin Tactics](https://genshintactics.com/guides/genshin-pity-system-explained-2026/) **[secondary]**. A pull session ends when currency runs out. A survey of 713 gacha players reported daily play time as follows [MDPI (Lakić et al. 2023)](https://www.mdpi.com/2078-2489/14/7/399) **[scholarly]**:

| Daily play time | Share of players |
|---|---|
| Under 1 hour | 10.2% |
| 1–2 hours | 38.3% |
| 2–3 hours | 27.1% |
| 3–4 hours | 11.9% |
| 4–5 hours | 5% |
| Over 5 hours | 7.4% |

### Escalation curve: flat, then a ramp to a hard cap
Genshin's character banner is the standard example of a **flat-then-ramp** probability curve [Genshin Tactics](https://genshintactics.com/guides/genshin-pity-system-explained-2026/) **[secondary]**:

- **Base rate.** 0.6% per wish for a 5★, flat from wish 1 to about wish 73.
- **Soft pity.** From wish 74 the rate climbs by about 6 percentage points per pull. HoYoLAB community documentation gives about 7% at wish 74 [HoYoLAB](https://www.hoyolab.com/article/23221584) **[secondary]**.
- **Hard pity.** Wish 90 is guaranteed.
- **Weapon banner.** Soft pity starts at 63, hard pity is 80.
- **4★ rate.** A 4★ comes at least every 10 pulls [YouTube guide](https://www.youtube.com/watch?v=ZUc-vYkcVjc) **[secondary]**.

The Genshin Tactics guide puts the average pull-to-5★ at "roughly 78–80 wishes." My own estimate is lower. The chance of no 5★ in 73 pulls at 0.6% is 0.994^73 ≈ 64.5%, so about 35% of players hit before soft pity. That puts the unconditional expected pull count nearer 61–63 **(computed estimate)**. The 78–80 figure more likely describes players who reach soft pity.

**The 50/50 layer.** Each 5★ on a character event banner has a 50% chance of being the featured character. Losing the 50/50 flags the account, so the next 5★ is guaranteed to be featured [Genshin Tactics](https://genshintactics.com/guides/genshin-pity-system-explained-2026/) **[secondary]**. This creates two stacked escalation curves: pity within a single 5★, and the guarantee across two 5★s.

FGO uses a flatter design. Each Saint Quartz summon has a 1% SSR chance (Servant or Craft Essence). A guide describes a "$480 spark" [shattered.io](https://shattered.io/fate-grand-order-pity-odds-2026/) **[secondary]**. The rate-up SSR pity system caps how much a player spends for a single copy of the featured SSR [FGO Wiki](https://fategrandorder.fandom.com/wiki/Rate-Up_SSR_Pity_System) **[secondary]**.

### Stop/continue decision and visible information
The decision point is every pull. The information that matters most is the player's **pity counter**, meaning pulls since the last 5★ and whether the next one is guaranteed. Players track this and plan around it. A 2025 behavioural study found that "pity systems lower perceived risk, boosting payment intention." It also found they can cap spending while encouraging commitment once a player is close to the threshold [ScienceDirect (Ma et al. 2025)](https://www.sciencedirect.com/science/article/abs/pii/S1875952125001247) **[scholarly]**. A separate academic paper models Genshin's odds structure directly [UKM APJITM (Thavamuni)](https://www.ukm.my/apjitm/public/assets/article/2025/1401/04.pdf) **[scholarly]**.

### Bad outcome
A bad pull never produces nothing. The player always gets a 3★ or better, and the pity counter keeps advancing, so every miss is recorded as progress toward the guarantee. A lost 50/50 still gives a usable 5★ and converts the next 5★ into a guarantee [Genshin Tactics](https://genshintactics.com/guides/genshin-pity-system-explained-2026/) **[secondary]**.

### Feedback cadence
- Every pull: an animation (a colour tell during the drop).
- At most every 10 pulls: a 4★.
- About every 60–90 pulls: a 5★.

### Numbers
In the MDPI survey, 80.2% of 713 participants had spent money on gacha, and 30.9% had spent more than $300. The most common reasons were [MDPI](https://www.mdpi.com/2078-2489/14/7/399) **[scholarly]**:

| Reason for spending | Share of answers |
|---|---|
| Unlocking a character or weapon | 77.7% |
| Limited-time availability | 53.8% |
| Skins | 39.3% |
| Faster progress | 20.5% |
| Competitive advantage | 5.8% |

A community thread citing Sensor Tower puts FGO's average revenue per download at $500–600 [Reddit r/gachagaming](https://www.reddit.com/r/gachagaming/comments/1p1ktcc/fategrand_orders_average_revenue_per_player_is/) **[secondary]**.

---

## 3. Match-3 (Candy Crush Saga)

### Session/run length and why
The contained loop is one level with a move limit. King's GDC 2024 data talk is the key source. Senior director of data science Xavier Guardiola said: "The longer the level is, the less likely it is to be fun." King found that the maximum recommended level length depends on difficulty: "if a level is really hard, it should also be really short" [mobilegamer.biz](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/) **[dev-primary, reported]**. Sessions overall are capped by lives. The game starts players with 5 lives, "usually more than enough to pass by time on that short subway or bus ride" [Game Developer](https://www.gamedeveloper.com/design/candy-crush-saga-a-sweet-journey-into-monetization) **[secondary]**. The commonly cited refill of about 30 minutes per life was not verified in this session **(unverified)**.

### Escalation curve: peaks and valleys
Within a level, stakes rise as moves run down. Across levels, a secondary analysis describes a **peak-and-valley** pattern: "frustratingly difficult levels are immediately followed up with usually 5–6 easy to medium difficulty levels" [Game Developer](https://www.gamedeveloper.com/design/candy-crush-saga-a-sweet-journey-into-monetization) **[secondary]**. King has also built a shared stat language for blockers as difficulty drivers [GDC Vault](https://gdcvault.com/play/1026813/Blockers-Analyzing-Difficulty-Drivers-in) **[dev-primary]**. Jeremy Kang's GDC talk covers level design across hundreds of levels [YouTube (GDC)](https://www.youtube.com/watch?v=LuNH9Rz2e2k) **[dev-primary]**.

### Stop/continue decision and visible information
The key decision comes when the player runs out of moves. They can see the objective still remaining and are offered 5 extra moves: "I would have beat this level if I had one more move… Well you can buy 5 more moves" [Game Developer](https://www.gamedeveloper.com/design/candy-crush-saga-a-sweet-journey-into-monetization) **[secondary]**. The second decision is at zero lives: wait, ask friends, or pay.

### Bad outcome
Losing a level costs one life and nothing else. Map progress and boosters are kept. King's data on over-tuned difficulty is the most important tuning evidence in this report [mobilegamer.biz](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/) **[dev-primary, reported]**:

- Level 65 was originally meant to be the final level. It became the highest-converting level and the one that "has made the most revenue ever." It also caused the most churn.
- An A/B test showed that a harder level raised conversion in the short term, but an easier level "retained players longer." Guardiola said those players "like compound interest, will start growing and in subsequent levels they may start spending."
- King measures fun with **"time to abandon"** and **"time to pass,"** weighted by player-skill profiles.
- Fixing the **100 least-fun levels** produced "a very significant uplift in engagement."
- Jan Wedekind summed it up: "Crazy hard levels never pay off… retention always wins."

### Feedback cadence
Every swap produces a match animation and sound, so feedback is sub-second to about 2 seconds per move. Cascades and special candies give intermittent bigger signals within each move.

### Numbers
- Millions of players have passed level 10,000, and most have never paid [mobilegamer.biz](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/) **[dev-primary, reported]**.
- At the 2013 writing, the game made "upwards of $62 million per month" [Game Developer](https://www.gamedeveloper.com/design/candy-crush-saga-a-sweet-journey-into-monetization) **[secondary]**.
- Booster prices at that time [Game Developer](https://www.gamedeveloper.com/design/candy-crush-saga-a-sweet-journey-into-monetization):
  - Color Bomb ×3: $0.99
  - Striped and Wrapped ×3: $1.99
  - Coconut Wheel ×3: $3.99
  - Charm of Life (raises the life cap from 5 to 8): $16.99

---

## 4. MOBA and hero-shooter session structure (League of Legends, Overwatch)

### Session/run length
League's match length falls as skill rises. An analysis of 623,281 ranked NA matches found [LeagueMath](https://www.leaguemath.com/match-duration-analysis/) **[secondary, Riot API data]**:

| Rank | Average length | Standard deviation |
|---|---|---|
| Bronze | 35:59 | 8:32 |
| Silver | 35:25 | 8:15 |
| Gold | 34:40 | 8:03 |
| Platinum | 33:47 | 7:56 |
| Diamond | 32:37 | 7:53 |
| Master | 31:27 | 7:49 |
| Challenger | 31:12 | 7:41 |

A more recent tracker covering 3.3 million matches shows Iron around 29:25 and Bronze around 30:11 [League of Graphs](https://www.leagueofgraphs.com/stats/game-durations) **[secondary]**. That fits a long-term shortening of games from about 30–35 minutes toward about 25 minutes [Sullla](https://sullla.com/LoL/gottagofast.html) **[secondary]**.

Overwatch runs much shorter. A thread reporting a Blizzard metrics disclosure cites an average competitive game of about 12 minutes and an average quick play game of about 8 minutes [Reddit r/Competitiveoverwatch](https://www.reddit.com/r/Competitiveoverwatch/comments/1kco71l/blizzard_lets_slip_some_gameplay_metrics_showing/) **[secondary]**. Players on the official forum estimate 7–8 minutes for quick play, with Control maps running up to about 14 minutes and 2CP as short as 3–4 minutes [Blizzard Forums](https://us.forums.blizzard.com/en/overwatch/t/does-anyone-know-the-average-time-of-a-qp-game/519753) **[secondary]**. An Overwatch 2 quick play test reportedly cut match times and extensions by 30%, sped up payloads by 60% and shortened respawns by 25% [Facebook group post](https://www.facebook.com/groups/409901703293362/posts/1553876908895830/) **[secondary]**.

### Escalation curve
MOBAs escalate economically: gold and levels compound, respawn timers lengthen, and objectives such as Baron decide games late. Hero shooters escalate through overtime, ultimate charge and objective progress.

### Stop/continue decision and visible information
- **Within a match**, League gates exits:
  - With an AFK teammate, a remake vote opens at 3:30.
  - The normal surrender vote opens at 15 minutes and needs 4 of 5 votes; a unanimous vote is allowed earlier if a player is AFK [League Wiki](https://leagueoflegends.fandom.com/wiki/Surrendering) **[secondary]**, [BoostingMarket](https://boostingmarket.com/blogs/lol-when-to-surrender-15/) **[secondary]**.
  - A failed vote has a 3-minute cooldown [Reddit](https://www.reddit.com/r/leagueoflegends/comments/i1r2c5/surrender_vote_should_be_enabled_at_20_regardless/) **[secondary]**.
- **Between matches**, the decision is "queue again." The visible information is LP or rank change and the win/loss streak. Queue time also shapes it. Jeff Kaplan said that before role queue, a fair damage-role match could take 13 to 26 minutes [Blizzard Forums (Stylosa interview)](https://us.forums.blizzard.com/en/overwatch/t/stylosa-jeff-kaplan-interview-part-2-competitive-talk-role-queue-game-features-etc/310174) **[dev-primary, transcribed]**.

### Bad outcome
A loss costs rank points and the time spent. Account progression, cosmetics and unlocks are kept. A remake erases the loss entirely, while a surrender at 15 minutes with a missing player still counts as a defeat [NerfPlz](https://www.nerfplz.com/2026/11/surrendering-explained-10-rules-of-ff.html) **[secondary]**.

### Feedback cadence
Last-hits, kills, assists and objective captures give signals every few seconds. There is a larger signal at the end of each match.

---

## 5. Battle royale (PUBG, Fortnite)

### Session/run length and why
Brendan Greene said of PUBG's round length: "we wanted to make it 30 minutes, and we thought about 35 or pushing it to 40. But that's a nice time for me." The circle shape was practical: "I couldn't code squares. So I made a circle." He worked out the circle timings and sizes from his Arma III mod [GamesBeat (Gamelab 2019 transcript)](https://gamesbeat.com/brendan-greene-and-rami-ismail/) **[dev-primary]**.

Fortnite's storm table (v41.20) implies about 23 minutes from the storm first forming to the final circle **(computed)**, on top of the time before the storm forms [Fortnite Wiki](https://fortnite.fandom.com/wiki/The_Storm) **[secondary]**:

| Stage | Wait | Shrink | Damage per second (while shrinking → after) | Diameter |
|---|---|---|---|---|
| 1 | 2:00 | 1:30 | 1 → 1 | 2,200 m |
| 2 | 1:30 | 1:30 | 1 → 1 | 1,800 m |
| 3 | 1:45 | 1:30 | 1 → 1 | 1,400 m |
| 4 | 1:30 | 1:30 | 1 → 1 | 1,000 m |
| 5 | 1:00 | 1:00 | 1 → 2 | 600 m |
| 6 | 1:00 | 1:00 | 2 → 5 | 350 m |
| 7 | 1:00 | 1:00 | 5 → 8 | 200 m |
| 8 | 0:45 | 0:45 | 8 → 10 | 100 m |
| 9 | 0:30 | 0:55 | 10 → 10 | 50 m |
| 10 | 0:00 | 0:30 | 10 → 10 | 20 m |

Adding the 1:00 formation delay, the waits come to about 12:00 and the shrinks to about 11:10 **(computed)**. The summary returned with the wiki page gave 22:20, which is an addition error. Fortnite Reload's maximum match length was reported as 23 minutes, down from 25 [Facebook post](https://www.facebook.com/GPEP133/posts/fortnite-reload-matches-are-now-longer-first-3-storm-circles-extended-wait-time-/1582952526956477/) **[secondary]**. Epic keeps retuning the phases, for example "Circle three will now begin closing sooner but more slowly" [PCGamesN](https://www.pcgamesn.com/fortnite/more-storm-circle-timing-adjustments) **[secondary]**.

### Escalation curve: an accelerating squeeze
Two curves overlap. Phase intervals shrink from 2:00 to 0:30, and storm damage per second rises tenfold (1 → 10). The playable area falls from 2,200 m to 0. Density of players and pace of events both climb to the end. Greene describes the emotional shape as tension and release: "PUBG is a horror game dressed up as a shooter. You need to give them those dips of, okay, I'm safe. And then you hear a gunshot" [GamesBeat](https://gamesbeat.com/brendan-greene-and-rami-ismail/) **[dev-primary]**.

### Stop/continue decision and visible information
- **Within a match:** where to drop, whether to fight or rotate, when to move for the next circle. The player sees the current and next circle, the phase timer and players remaining.
- **Between matches:** requeue. Dying early costs little time, so requeuing is cheap.

### Bad outcome
Death ends the run, and everything picked up in the match is lost. Account-level progression (battle pass XP, cosmetics) is kept. Greene put the win rate at "something like 10 or 20 percent" [GamesBeat](https://gamesbeat.com/brendan-greene-and-rami-ismail/) **[dev-primary]**. Most matches end in a loss, so the loop depends on each attempt being cheap to restart and producing a different story. Greene calls the genre a "story generator."

### Feedback cadence
- Every few seconds: loot pickups.
- Roughly every 1:00–3:30: a new storm phase announcement.
- Irregularly: gunfire and eliminations.

### Numbers
- PUBG Mobile passed 400 million downloads, and the team grew from about 30 to more than 400 people in a year [GamesBeat](https://gamesbeat.com/brendan-greene-and-rami-ismail/) **[dev-primary]**.
- Fortnite's peak of 15.3 million concurrent players (late 2020) stood as a benchmark until 2025 [PocketGamer.biz](https://www.pocketgamer.biz/robloxs-grow-a-garden-hits-industry-record-213m-concurrent-users-surpassing-pubg-fortnite-and-more/) **[secondary]**.

---

## 6. Clicker and incremental games

### Session/run length
The contained loop is a **prestige run**: build up, hit a wall, reset for a permanent multiplier. Session length is set by where the cost curve outruns production.

### Escalation curve: exponential cost against linear production
Kongregate's Anthony Pecorella gave the core equations [Game Developer (The Math of Idle Games, Part I)](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i) **[dev-primary]**:

- `cost_next = cost_base × (rate_growth)^owned`
- `production_total = (production_base × owned) × multipliers`
- "Early on in a run, your production will exceed costs while eventually costs will become prohibitive."
- In AdVenture Capitalist, the Lemonade Stand has a growth rate of 1.07, a base cost of 4 and base production of 1.67/sec. The 11th stand costs 4 × 1.07^10 = 7.87.

Prestige formulas compress growth by different amounts [Kongregate (Part III)](https://www.kongregate.com/pages/the-math-of-idle-games-part-iii) **[dev-primary]**:

| Game | Prestige currency formula |
|---|---|
| Realm Grinder | p = (√(1 + 8·c/10¹²) − 1)/2 |
| AdVenture Capitalist | p = 150·√(c/10¹⁵) |
| Cookie Clicker | p = ∛(c/10¹²) |
| Egg, Inc. | Δp = (c/10⁶)^0.14 |

Pecorella notes that doubling prestige in Realm Grinder needs 4× the previous run, while Egg, Inc. needs 128× (2⁷). That is meant "to nudge players into more active play and reduce the influence of time on progression." He gives prestige two purposes: "the ladder climbing effect… reset with a huge boost that gives a sense of power and progress," and reining growth back to a stable number the developer can tune around [Kongregate](https://www.kongregate.com/pages/the-math-of-idle-games-part-iii) **[dev-primary]**.

### Stop/continue decision and visible information
The key decision is when to prestige. The player sees the prestige currency they would gain against their current multiplier, so the choice is a visible ratio. Between prestiges, it is buy now versus save. Players simplify by buying in bulk, for example in multiples of 100 [Game Developer](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i) **[dev-primary]**.

### Bad outcome
There is no failure state. The "loss" is a voluntary reset that always leaves the player stronger. The worst case is slow progress. Offline production means time away still pays out.

### Feedback cadence
Numbers tick up continuously, several times a second. Purchases come every few seconds early in a run and stretch to minutes as costs outpace production. The dedicated 2015 GDC talk on the genre's core loop, metagame and Kongregate platform metrics is [GDC Vault](https://www.gdcvault.com/play/1022065/Idle-Games-The-Mechanics-and) **[dev-primary]**. Its metrics were not accessible in this session.

---

## 7. Deckbuilding roguelikes (Balatro, Slay the Spire, Luck be a Landlord)

### Balatro
**Structure.** A run is 8 antes of 3 blinds each (Small, Big, Boss). Clearing the ante-8 Boss Blind completes the run, and endless mode continues afterward [Dot Esports](https://dotesports.com/indies/news/balatro-antes-blinds-explained) **[secondary]**, [Balatro Wiki](https://balatrowiki.org/w/Blinds_and_Antes) **[secondary]**. The base score targets usually quoted per ante are 300, 800, 2,000, 5,000, 11,000, 20,000, 35,000 and 50,000 chips, with Big Blinds at 1.5× and Boss Blinds at 2× **(unverified)**. That is a steep, roughly exponential climb.

**Core mechanic.** LocalThunk: "The game had the CHIP X MULT mechanic already. I really don't know where this idea came from but it seemed very natural for a scoring system." He added an ascension system (Stakes) borrowed from Slay the Spire "to add difficulty and give players a sort of checklist to work through." A friend suggested the flamingo score effect as visual feedback for good hands [LocalThunk blog](https://localthunk.com/blog/balatro-timeline-3aarh) **[dev-primary]**.

**What he credits.** "People love to hold a set of cards in their hand, organize and arrange them, think about which cards make sense to play and which they might want to hold on to." On balance: "almost all balance changes can be made by changing a number (cost, rarity, chip bonus, mult bonus)." On randomness: "There is a lot of randomness, possibly too much, but the metastrategy for Balatro is around mitigating risk" [Rogueliker](https://rogueliker.com/balatro-interview/) **[dev-primary]**. His influences were Big Two and videos of *Luck be a Landlord* [TouchArcade](https://toucharcade.com/2024/03/18/balatro-interview-mobile-port-localthunk-dlc-plans-updates-new-jokers-demo-feedback/) **[dev-primary]**.

**Demo design.** The first demo was limited to 50 rounds. It was later changed to be content-limited rather than round-limited, "so players can play as much as they want" [LocalThunk blog](https://localthunk.com/blog/balatro-timeline-3aarh) **[dev-primary]**.

**Decisions and cadence.** The player decides every hand: which cards to play or discard, with hands and discards remaining and the score target visible. There is a shop after every blind. Each hand's chip × mult count-up is the feedback moment, roughly every 10–30 seconds **(estimate)**.

**Bad outcome.** Failing a blind ends the run. Unlocks, collection entries and stake progress are kept.

**Numbers.** Balatro sold 50,000 copies on Steam within about two hours of launch and 119,000 by the end of launch day [LocalThunk blog](https://localthunk.com/blog/balatro-timeline-3aarh) **[dev-primary]**. It passed 500,000 and then 1 million [TouchArcade](https://toucharcade.com/2024/03/18/balatro-interview-mobile-port-localthunk-dlc-plans-updates-new-jokers-demo-feedback/) **[secondary]**.

### Slay the Spire
Mega Crit balanced the game with two main metrics. Anthony Giovannetti: how often a card is picked when offered ("too low and it's basically not a card in our game at that point") and how often it appears in winning decks ("too high and you know that card is overpowered"). They also tracked what a card was passed over for and average damage taken from specific enemies. "The first time we made our metrics, we had three graphs; now we have at least 90" [Game Developer](https://www.gamedeveloper.com/design/how-i-slay-the-spire-i-s-devs-use-data-to-balance-their-roguelike-deck-builder) **[dev-primary, reported]**. The full GDC 2019 talk is "Metrics Driven Design and Balance" [YouTube (GDC)](https://www.youtube.com/watch?v=7rqfbvnO_H0) **[dev-primary]**. A run spans three acts with a boss at the end of each. The visible information at each decision is the map's branching paths, current HP and deck contents.

### Luck be a Landlord
The loop is a slot machine the player builds: "Players must accumulate increasing amounts of money to pay their rent within a limited number of spins. After each spin, players can add another symbol." Symbols combine (cats drink milk, bees pollinate flowers), some symbols destroy others, and the player wins by paying 12 rents [Wikipedia](https://en.wikipedia.org/wiki/Luck_Be_a_Landlord) **[secondary]**.

- **Escalation:** rent amounts rise on a fixed schedule.
- **Decision point:** after every spin, the player sees rent due and spins left.
- **Feedback:** every spin pays out, about every 2–5 seconds.

Dan DiIorio built it "wanting to make a slot machine game that did not depend on predatory microtransactions." Pocket Gamer called it "insanely addicting." It was banned on Google Play in 13 countries under simulated-gambling policy [Wikipedia](https://en.wikipedia.org/wiki/Luck_Be_a_Landlord) **[secondary]**.

---

## 8. Extraction shooters (Escape from Tarkov, Hunt: Showdown)

### Escape from Tarkov
**Session length.** Raids have map-specific timers. A player-reported figure gives Customs as 25 minutes [Facebook group](https://www.facebook.com/groups/1714415802627065/posts/2209638116438162/) **[secondary, player-reported]**. Timers have changed across patches and were not verified here.

**Minimum-engagement rule.** Extracting without either 200 XP or 7 minutes in the raid gives a "Run Through" status, so the raid does not count for certain quests [Tarkov Wiki (The Guide)](https://escapefromtarkov.fandom.com/wiki/The_Guide) **[secondary]**. A community explainer says anyone who extracts after 7 minutes gets a 300-XP exploration bonus [Reddit](https://www.reddit.com/r/EscapefromTarkov/comments/qs9cjc/a_complete_explanation_of_the_run_through/) **[secondary]**.

**Escalation.** Stakes rise as the player loots. The value carried grows over the raid, so each minute alive is worth more and costs more to lose.

**Stop/continue decision.** Extract now with current loot, or keep looting. The player sees the raid timer and known extraction points; some extracts have conditions.

**Bad outcome: tiered retention.**
- Everything carried is lost.
- The **secure container** is "guaranteed storage, unaffected by raid losses."
- **Insured** gear returns if no other player took it [LeprEstore guide](https://leprestore.com/guides/eft/escape-from-tarkov-insurance-explained/?srsltid=AU7gw4UwALkOT-D42zW8wPvUqoF_UUt0gb1Zl99g0AkUwRcy-pIGKweI) **[secondary]**, arriving 24–36 hours later [EFT Forum](https://forum.escapefromtarkov.com/topic/110304-insurance-return-out-of-time-no-to-change/) **[secondary]**.

**What the designer credits.** Nikita Buyanov: "I originally designed Tarkov as a niche game with a small player base. When you get something without effort, it doesn't carry the same emotional weight as when you've truly earned it." The interview reported almost 150,000 concurrent players at the time of writing [ESPN](https://www.espn.com/gaming/story/_/id/44700185/escape-tarkov-nikita-buyanov-interview) **[dev-primary]**.

### Hunt: Showdown
**Session length.** Bounty Hunt matches end at 45 minutes, or 5 minutes after all bounties have been extracted. Up to 12 players take part, solo or in teams of 2 or 3 [Hunt Wiki](https://huntshowdown.fandom.com/wiki/Game_Modes) **[secondary]**. The 45-minute limit came in with update 1.9 [Reddit](https://www.reddit.com/r/HuntShowdown/comments/vbfxpd/new_match_time_limit_45_minutes_update_19/) **[secondary]**. Crytek's shorter Bounty Clash mode lasts 15 minutes, dropping to 90 seconds once the bounty token is extracted [Hunt Wiki.gg](https://huntshowdown.wiki.gg/wiki/Game_Modes/Bounty_Clash) **[secondary]**, [Crytek Press](https://press.crytek.com/hunt-showdown-1896-reveals-new-event-and-a-limited-time-game-mode-coming-this-halloween) **[dev-primary]**.

**Escalation.** The match moves through four phases, and each one exposes the player more [Hunt Wiki](https://huntshowdown.fandom.com/wiki/Game_Modes) **[secondary]**:

1. **Clues** narrow down where the boss is.
2. **The boss kill and banish** give away the team's position.
3. **Picking up the bounty** grants 5 seconds of enhanced Dark Sight but marks the carrier on every map with lightning bolts.
4. **Extraction** needs 30 seconds inside the zone with no teammate downed.

**Bad outcome.** "Players who die or otherwise fail to extract lose their Hunter and his/her equipment and only gain half XP." A Hunter who dies on their last unburned health bar cannot be revived [Hunt Wiki](https://huntshowdown.fandom.com/wiki/Game_Modes) **[secondary]**. The player keeps account-level progress and half the XP. Crytek also added a daily first-bounty-extraction bonus of XP and Hunt Dollars per Hunter [Facebook (Hunt official)](https://www.facebook.com/huntshowdown/videos/first-bounty-extraction-bonus-i-developer-highlight/1106836843475416/) **[dev-primary]**. Crytek's own statement of mechanic design goals is at [YouTube (Crytek)](https://www.youtube.com/watch?v=YBoNaw2kHn8) **[dev-primary]**; its transcript was not retrieved.

---

## 9. Looter shooters and ARPGs (Diablo, Path of Exile, Blox Fruits as a Roblox ARPG)

### Diablo: the killing-and-loot "slot machine"
David Brevik described the loop directly: "The best analogy is it's a slot machine. Every time you kill a monster you put a quarter into the slot machine and pull the lever and out could come nothing, you could get your quarter back, or you could hit a jackpot… it's got kind of this addictive quality" [TweakTown (reporting Ars Technica)](https://www.tweaktown.com/news/74666/diablos-loot-lottery-rng-is-like-slot-machine-says-david-brevik/index.html) **[dev-primary, reported]**.

Brevik on design intent: "we liked the addictive feeling of just one more monster, just one more piece of loot." Erich Schaefer also compared looting to slot machines [TheGamer](https://www.thegamer.com/diablo-2-loot-interview/) **[dev-primary, reported]**. Both designers have explained how colour-coded rarity and drop sound effects became the standard loot presentation [Mein-MMO](https://mein-mmo.de/en/fathers-of-diablo-explain-how-they-invented-loot-in-video-games-that-makes-us-addicted,670631/) **[dev-primary, reported]**. Brevik's GDC 2016 Diablo postmortem is at [YouTube (GDC)](https://www.youtube.com/watch?v=VscdPA6sUkc) **[dev-primary]**.

- **Feedback cadence:** every kill is a lottery draw, so seconds apart during clears. Most results are common, and rare drops arrive with a distinct colour and sound.
- **Bad outcome:** very little. In softcore modes, death usually means a corpse run or a small penalty, and farming continues.
- **Stop/continue:** "one more monster" or one more map. The player sees their inventory, the loot on the ground and the next area.

### Path of Exile
Chris Wilson's GDC 2019 talk, "Designing 'Path of Exile' to Be Played Forever," covers how the game "has been designed to retain and grow its community for the very long term" [GDC Vault](https://www.gdcvault.com/play/1025784/Designing-Path-of-Exile-to) **[dev-primary]**. The Vault page was login-gated, and the talk's figures could not be extracted. The core structure is time-limited leagues that reset characters and the economy onto a fresh ladder. The usual cycle of about 13 weeks is **(unverified)**.

### Blox Fruits (Roblox ARPG loop)
Blox Fruits uses timed spawns that bring players back [Rolimons](https://www.rolimons.com/game/2753915549) **[dev-primary text on the game page / secondary tracker]**:

- Level cap 3,000.
- Fruits spawn on the map every hour and despawn after 20 minutes.
- The Fruit Dealer restocks random fruits every 4 hours.

Rolimons lists about 64.7 billion visits and average playtime of 20.39. The unit is not labelled and is most likely minutes. The game set a Roblox record of more than 2.26 million concurrent users [X (Bloxy News)](https://x.com/Bloxy_News/status/1868147544171397408) **[secondary]**. A creator reports it averaged over 800,000 concurrent players a year earlier and has fallen to about 150,000 [YouTube](https://www.youtube.com/watch?v=7r7piSOrYAo) **[secondary]**. An estimate puts its Robux bookings at $8–12 million per month during 2023–2024 [FourWeekMBA](https://fourweekmba.com/roblox-revenue/) **[secondary, estimate]**.

---

## 10. Social and casual mobile (Clash Royale, Coin Master)

### Clash Royale
**Session length.** A match is "a hectic strategic game that lasts only a few minutes" [Mobile Free to Play](https://mobilefreetoplay.com/deconstructing-clash-royale/) **[secondary]**. It ends when time runs out or a player earns 3 crowns. Elixir regenerates to a cap of 10, and decks hold 8 cards [Game Developer](https://www.gamedeveloper.com/design/breaking-down-supercell-s-next-hit-clash-royale) **[secondary]**. The commonly cited 3:00 regulation plus overtime is **(unverified)**.

**Meta layer: appointment mechanics.** The classic system worked like this [Mobile Free to Play](https://mobilefreetoplay.com/deconstructing-clash-royale/) **[secondary]**, [Game Developer](https://www.gamedeveloper.com/design/breaking-down-supercell-s-next-hit-clash-royale) **[secondary]**:
- Won chests take 3, 8 or 12 hours to open, one at a time.
- Only 4 chest slots.
- A free chest every 4 hours, storing up to 2.
- A crown chest after 10 crowns, once every 24 hours.

A Game Developer analysis says "almost every feature outside of combat exists as layered set of appointment mechanics" [Game Developer](https://www.gamedeveloper.com/design/breaking-down-supercell-s-next-hit-clash-royale) **[secondary]**. The key idea is limiting rewards rather than play: "Instead of pacing the players through energy… they went with a system that limits the rewards players get." A player can keep playing with full slots but earns no chests [Mobile Free to Play](https://mobilefreetoplay.com/deconstructing-clash-royale/) **[secondary]**. In the 2025 Q1 update Supercell removed chest timers, replacing them with instant unlocks and "Lucky Drops" [YouTube (TV Royale)](https://www.youtube.com/watch?v=mgtVaUE2d8s) **[dev-primary]**, [RoyaleAPI forum](https://discuss.royaleapi.com/t/rip-chests-2025-q1-update-clash-royale-news-blog-royaleapi/29629) **[secondary]**.

**Bad outcome.** Losing a match costs trophies, and no chest drops. Cards and levels are kept.

### Coin Master
**Core loop.** The player spins a slot machine for coins and builds a village with them. Three hammers trigger **Attack**: the player picks a structure on another player's base. Three pigs trigger **Raid**, which bypasses shields and gives the player three guesses at where the coins are. Shields come randomly from spins, apply automatically, and cap at 3 [GameAnalytics](https://www.gameanalytics.com/blog/coin-master-social-casino) **[secondary]**.

**Spin economy.** Sources disagree, probably because of different versions:
- 5 free spins every 50 minutes, citing a 2019 Deconstructor of Fun analysis [GameAnalytics](https://www.gameanalytics.com/blog/coin-master-social-casino) **[secondary]**.
- 5 spins per hour with a 50-spin cap, so a full refill takes 10 hours [Udonis](https://www.blog.udonis.co/mobile-marketing/mobile-games/coin-master-monetization) **[secondary]**.

**Stakes escalation.** A bet multiplier unlocks after a few sessions. It lets players "risk running out of spins early in exchange for more rewards" [Udonis](https://www.blog.udonis.co/mobile-marketing/mobile-games/coin-master-monetization) **[secondary]**.

**Bad outcome.** A bad spin wastes one spin, and every spin pays something or triggers an event. The social loss is having your village attacked or raided, which "will inevitably happen to every village, and the players can only minimize the damage" [Udonis](https://www.blog.udonis.co/mobile-marketing/mobile-games/coin-master-monetization) **[secondary]**.

**Numbers.** More than $3.1 billion lifetime revenue, over $800 million in 2022, over 300 million downloads and more than 3 million new users a month [Udonis](https://www.blog.udonis.co/mobile-marketing/mobile-games/coin-master-monetization) **[secondary]**.

---

## 11. General game-design YouTube channels (Game Maker's Toolkit, Extra Credits, Adam Millard, Design Doc, Game Wisdom)

**Coverage caveat.** Transcripts could not be retrieved for any videos in this category; the tool returned "No transcript available." What follows is from titles, descriptions and third-party summaries only. No session-length numbers from these channels could be verified, and this section is thinner than the others as a result.

- **Extra Credits** [secondary]. "The Skinner Box" [YouTube](https://www.youtube.com/watch?v=tWtvrPTbQ_c) is the most-cited primer on reinforcement schedules applied to games. "Progression Systems – How Good Games Avoid Skinner Boxes" (about 1.3 million views) [YouTube](https://www.youtube.com/watch?v=o9NytJXbJmI) contrasts extrinsic schedules with intrinsic progression. GameAnalytics adopts this framing and breaks the loop into three phases (**Anticipation → Action → Reward**). It gives mobile examples: "aspirational neighbours" (Clash of Clans leaderboard cities, the tutorial visit to "Greg" in Hay Day), variable-ratio captures, and timer-based appointment mechanics (Game of War) [GameAnalytics](https://www.gameanalytics.com/blog/the-compulsion-loop-explained) **[secondary]**.
- **Game Maker's Toolkit (Mark Brown)** [secondary]. "Roguelikes, Persistency, and Progression" covers whether roguelikes should have persistent upgrades [YouTube](https://www.youtube.com/watch?v=G9FB5R4wVno&xstg=CAMSBhUD_LL2Hw%3D%3D). A community summary reports its central claim: "side-grade progression is preferable to strictly upside progression" [Reddit r/HadesTheGame](https://www.reddit.com/r/HadesTheGame/comments/ahj4au/game_makers_toolkit_on_roguelikes_what_could/). The failure-penalty question here is whether a lost run keeps power or only options.
- **Adam Millard (The Architect of Games)** [secondary]. "How Gameplay Loops Keep You Playing" [YouTube](https://www.youtube.com/watch?v=Sk-nbAtIUko). "In Defence of Randomness": "It doesn't actually matter whether something is random or not…" [Reddit r/Games](https://www.reddit.com/r/Games/comments/gcu9fi/in_defence_of_randomness_adam_millard_the/). "How To Design An Unsolvable Problem" [YouTube](https://www.youtube.com/watch?v=toD5D6PDofU).
- **"Design Doc"** [secondary]. I could not confirm which videos belong to this channel. Closely related titles found were "Designing Addiction: The Twisted Psychology Of Game Design" [YouTube](https://www.youtube.com/watch?v=K0M1PuQaE8s) and Design Delve's "Why Are Some Games So Horrifically Addictive?" [YouTube](https://www.youtube.com/watch?v=JVZmxVDzkjk). The channel attribution for both is unconfirmed.
- **Game Wisdom (Josh Bycer)** [secondary]. "A Critical Thought on 'Gacha' Game Design" [YouTube](https://www.youtube.com/watch?v=7VAsrkAX2QI&xstg=CAMSBhUD_LL2Hw%3D%3D), "How to Design Around RNG | Roguelike Roundtable" [YouTube](https://www.youtube.com/watch?v=zb9LuzXDAew&xstg=CAMSBhUD_LL2Hw%3D%3D), and the channel [YouTube](https://www.youtube.com/c/game-wisdom), which describes interviewing developers for more than 10 years.

---

## 12. GDC talks, postmortems, designer blogs and scholarly work (index)

This is a cross-reference of the primary and academic sources used above.

**GDC and developer talks [dev-primary]:**
- King: level fun metrics [mobilegamer.biz](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/), blockers [GDC Vault](https://gdcvault.com/play/1026813/Blockers-Analyzing-Difficulty-Drivers-in), AI regression testing [GDC Vault](https://gdcvault.com/play/1023858/How-King-Uses-AI-in).
- Pecorella on idle games [GDC Vault](https://www.gdcvault.com/play/1023876/Quest-for-Progress-The-Math).
- Giovannetti on Slay the Spire metrics [YouTube](https://www.youtube.com/watch?v=7rqfbvnO_H0).
- Wilson on Path of Exile [GDC Vault](https://www.gdcvault.com/play/1025784/Designing-Path-of-Exile-to).
- Brevik's Diablo postmortem [YouTube](https://www.youtube.com/watch?v=VscdPA6sUkc).

**Designer blogs and interviews [dev-primary]:**
- LocalThunk [blog](https://localthunk.com/blog/balatro-timeline-3aarh).
- Greene [GamesBeat](https://gamesbeat.com/brendan-greene-and-rami-ismail/).
- Buyanov [ESPN](https://www.espn.com/gaming/story/_/id/44700185/escape-tarkov-nikita-buyanov-interview).

**Scholarly [scholarly]:**
- Barton 2017 on LDWs and near misses [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5663799/).
- Harrigan & Dixon on PAR sheets [cdspress.ca](https://cdspress.ca/wp-content/uploads/2022/08/Kevin-A.-Harrigan-Mike-Dixon-.pdf).
- Palmer 2024 on near misses in online slots [APA](https://psycnet.apa.org/fulltext/2024-81139-001.html).
- Lakić 2023 on gacha spending [MDPI](https://www.mdpi.com/2078-2489/14/7/399).
- Ma 2025 on pity systems [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S1875952125001247).

---

## 13. Roblox developers, creators and studios

This section is structured the same way as the others. Its sources are split by tag:
- **[dev-primary]:** Jandel, WoozyNate, the Adopt Me developers, TizzyBlox and BruceDevs.
- **[secondary]:** trackers such as RoMonitor and Rolimons, and creators analysing other people's games.

### 13.1 Grow a Garden (Jandel / Splitting Point, with Do Big Studios)
**Core mechanic credited: offline growth.** Jandel: "The core loop of the game is just like buying seeds and planting them. But I think one of the main drivers… is this whole like grow offline mechanic. So people can plant a seed, they can leave, they can come back two hours later, 30 minutes, 24 hours and their garden has grown and progressed." He adds that the "persistence and kind of live feel… makes it feel alive" [YouTube (Roblox Tech Talks EP29)](https://www.youtube.com/watch?v=6iB5__RCQDc) **[dev-primary]**. In another interview: "You return and your plants have grown bigger, or you've grown new fruit. It was a novel concept for Roblox" [GamesBeat](https://gamesbeat.com/janzen-madsen-interview/) **[dev-primary]**.

**Stakes and failure design: deliberately low.** "One of the real design pillars of the game is we don't actually want to demand a lot from people… I intentionally design the updates each week where… most of the players can actually achieve the final objective or the chase goal." And: "If you miss a week, like I don't want you to really get left behind, you could just join the next week" [YouTube (Tech Talks)](https://www.youtube.com/watch?v=6iB5__RCQDc) **[dev-primary]**. In practice there is no failure state; time away is rewarded.

**Social mechanic.** Players can help each other: "even something as simple as placing a sprinkler on someone else's garden… an experienced player comes up and gives them a super expensive fruit" [YouTube (Tech Talks)](https://www.youtube.com/watch?v=6iB5__RCQDc) **[dev-primary]**.

**Update and return cadence.**
- Weekly updates: "We update at 7am PST… every Saturday, and each week we've seen more and more people show up to celebrate the launch of the update and receive their celebratory update gift" [GameDiscoverCo](https://newsletter.gamediscover.co/p/what-grow-a-gardens-89-million-ccu) **[dev-primary, quoted]**.
- Jandel says the studio has updated weekly for 3–4 years [YouTube (Tech Talks)](https://www.youtube.com/watch?v=6iB5__RCQDc) **[dev-primary]**.
- Within a session, a creator breakdown cites Grow a Garden's shop stock refreshing every 5 minutes, a mechanic later copied by *Steal an Egg* [YouTube (creator breakdown)](https://www.youtube.com/watch?v=CRCcsYEB_6A) **[secondary]**.

**Numbers.**
- Peak concurrent players 22.3 million, about 60 million peak DAU, about 30 billion plays [GamesBeat](https://gamesbeat.com/janzen-madsen-interview/) **[dev-primary]**.
- About 30 engineers on the game, up from 10 [YouTube (Tech Talks)](https://www.youtube.com/watch?v=6iB5__RCQDc) **[dev-primary]**.
- Growth: records of 5M → 7.3M → 8.9M → 21.3M CCU (June 21, 2025). The spike fell to 7.6M within an hour and 5.5M within two. Over a 14-day window it averaged 2.7M CCU and passed 10M only twice [PocketGamer.biz](https://www.pocketgamer.biz/robloxs-grow-a-garden-hits-industry-record-213m-concurrent-users-surpassing-pubg-fortnite-and-more/) **[secondary]**.
- At the 8.9M stage it held 1.5–2.5M CCU "at all times." Splitting Point had 19 developers and moved about 12 onto the game after acquiring it [GameDiscoverCo](https://newsletter.gamediscover.co/p/what-grow-a-gardens-89-million-ccu) **[secondary + dev-primary quotes]**.
- RoMonitor shows a peak of 22.38M and 35.95 billion lifetime visits [RoMonitor](https://romonitorstats.com/experience/126884695634066/) **[secondary tool]**. Roblox RTC logged 22,346,725 [X (Roblox_RTC)](https://x.com/Roblox_RTC/status/1959281995453706447) **[secondary]**.
- In Roblox's Q2 2025 results, Grow a Garden, Steal a Brainrot and Dead Rails were among the platform's top 10 experiences by player spending. Roblox reported $1.1 billion revenue and 111.8 million DAU (+41%) [Game Developer](https://www.gamedeveloper.com/business/roblox-s-grow-a-garden-had-nearly-22-million-concurrent-users-in-july) **[secondary, citing Roblox filings]**.

### 13.2 Steal a Brainrot (SpyderSammy / Do Big Studios)
**Loop.** A conveyor in the middle of the map sells Brainrots, which "generate income every few seconds." Players progress by buying rarer ones or stealing from other players, "a gameplay loop comparable to the sport capture the flag." Each base has a button for a temporary shield. Rebirth resets progress in exchange for better stats and extra currency [Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot) **[secondary]**.

**Structure against the six fields.**
- **Escalation:** each purchase is rarer and more valuable, so each theft risks more.
- **Stop/continue:** leave the base to steal, or stay to defend. The player sees the shield timer and other players' bases.
- **Bad outcome:** losing a stolen Brainrot to a thief. Rebirth stats are kept.
- **Feedback:** income ticks every few seconds.

**Numbers.**
- 25.4 million CCU in October 2025, the first game above 25M. Its average playtime was "roughly a third of Grow a Garden's" [PocketGamer.biz](https://www.pocketgamer.biz/robloxs-steal-a-brainrot-becomes-first-game-to-surpass-25m-concurrent-players/) **[secondary]**.
- Earlier record of 24,136,040 [X (Roblox_RTC)](https://x.com/Roblox_RTC/status/1966948186653863995?lang=en) **[secondary]**. Fan-compiled records list 25,836,222 on October 11, 2025 [Guinness Records Fandom](https://guinness-world-records.fandom.com/wiki/Roblox_records) **[secondary]**.
- Roblox's platform-wide peak reached 47.4 million that August [PocketGamer.biz](https://www.pocketgamer.biz/robloxs-steal-a-brainrot-becomes-first-game-to-surpass-25m-concurrent-players/) **[secondary]**.

### 13.3 Fisch (WoozyNate)
**What the developer credits.** "Retention of players relies on the ability to play a game in multiple ways. They should always have a reason to come back." The loop is fishing, exploring and completing quests, with a different set of fish at each location [Roblox DevForum (Creator Spotlight)](https://devforum.roblox.com/t/creator-spotlight-woozynate-makes-a-splash-with-fisch/3269481) **[dev-primary, Roblox-authored]**.

**Named mechanics.**
- Each fish has a **Resilience** stat that sets how fast the minigame bar moves.
- Mutations such as shiny or sparkling are generated with the fish's weight as the random seed.
- No rod is strictly best: each has its own use case and a special ability. The Magma Rod is for volcanoes; the Trident Rod gives passive boosts and can freeze the bar [Roblox DevForum](https://devforum.roblox.com/t/creator-spotlight-woozynate-makes-a-splash-with-fisch/3269481) **[dev-primary]**.

**Structure against the six fields.**
- **Cycle:** one cast plus one minigame, tens of seconds per catch **(estimate)**.
- **Feedback:** every catch shows rarity, weight and any mutation.
- **Escalation:** harder zones and stronger fish need better rods.
- **Bad outcome:** a lost fish, and nothing more.

**Numbers.**
- CCU peaked at about 470,000 after the FischFright event [Roblox DevForum](https://devforum.roblox.com/t/creator-spotlight-woozynate-makes-a-splash-with-fisch/3269481) **[dev-primary]**.
- A consultant reported 2,000 concurrent players at the October 5 launch and rapid growth over the next 44 days [LinkedIn (James Purell)](https://www.linkedin.com/posts/jamespurell_the-fastest-growing-game-on-roblox-right-activity-7262440362147823618-umJr) **[secondary]**.
- A later post calls it the 13th game to reach 1M CCU [Reddit r/roblox](https://www.reddit.com/r/roblox/comments/1nxxswe/fisch_is_the_13th_game_to_hit_1_million_ccu/) **[secondary]**. A tracker lists an all-time peak of 419,625 for one place [HowManyArePlaying](https://howmanyareplaying.com/roblox/experience/5750914919) **[secondary tool]**. These figures conflict.

A Roblox Creator Events session, "Inside the Development of Fisch," exists [YouTube](https://www.youtube.com/watch?v=24EdKhjcMuo) **[dev-primary]**, but its transcript was unavailable.

### 13.4 Adopt Me! (DreamCraft → Uplift Games: NewFissy, Bethink)
**What the developers credit.**
- NewFissy: mechanics "players had never seen before on the site such as being able to seamlessly and naturally carry another player in your arms," plus a "relentless focus on quality."
- Bethink: "best tech… great art and a LOT of planned out marketing."
- Cadence: "We try to publish meaningful updates weekly." Bethink stockpiles ready-to-ship updates, while deeper code changes ship quarterly.
- Localization: "Over a quarter of our player base speaks a different language other than English" [NextPowers (Medium)](https://nextpowers.medium.com/roblox-adopt-me-interview-5e00b188ef) **[dev-primary]**.

**Metrics the studio says to watch.** Uplift's David Statter names three: average time a user spends in-game, feedback score percentage, and DAU/MAU. On revenue: "while the minority will provide you with the majority of your revenue, it is the majority of your players that will form the core of your net promoters" [GamesIndustry.biz](https://www.gamesindustry.biz/roblox-101-adopt-me-developers-tips-on-finding-success) **[dev-primary]**.

**Loop structure (general game knowledge, not sourced here).** Pets age through tasks (needs), eggs hatch pets at random rarities, and trading gives value to what a player keeps. Nothing is ever lost. Stakes come from trade value.

**Numbers.**
- MAU doubled to 60 million by January 2021, and revenue rose 400% during 2020 [PCGamesInsider](https://www.pcgamesinsider.biz/interviews-and-opinion/72169/why-the-devs-behind-robloxs-adopt-me-are-launching-new-studio-uplift-games/) **[dev-primary interview]**.
- Record 1.92 million CCU with the Ocean Egg update in April 2021 [Uplift Games blog](https://www.uplift.games/blog/uplift-games-launch-release) **[dev-primary]**.
- A team of 40, scaling toward 100 [PCGamesInsider](https://www.pcgamesinsider.biz/interviews-and-opinion/72169/why-the-devs-behind-robloxs-adopt-me-are-launching-new-studio-uplift-games/) **[dev-primary]**.
- More than 22 billion visits at the Uplift launch [Game Developer](https://www.gamedeveloper.com/business/roblox-developers-behind-i-adopt-me-i-form-new-studio-uplift-games) **[secondary]**.

### 13.5 Pet Simulator 99 / X (BIG Games)
No BIG Games design interview with numbers was found in this session. The figures come from public tools and the studio's site:
- All-time peak of 732,936 CCU (December 9, 2023), about 2.65 billion visits, 94.74% rating, and **average playtime of 114.41 minutes**. That is the longest average session of any game tracked in this report [Rolimons](https://www.rolimons.com/game/8737899170) **[secondary tool]**.
- The BIG Games site claims "1.5 MILLION PEAK CONCURRENT PLAYERS" [BIG Games](https://biggames.io/) **[dev-primary claim]**. It does not say which game.
- BIG Games publishes developer blogs and patch notes around hatch variants (Gold, Rainbow, Shiny, Huge/Gargantuan pets) [BIG Games Dev Blogs](https://biggames.io/post) **[dev-primary]**.

The loop is to hatch eggs at random rarities with near-continuous animations, send pets to farm currency, and unlock the next zone. It is structurally an idle-clicker cost curve with a gacha output **(analysis)**.

### 13.6 TizzyBlox / "Tizzy RBLX" (developer discussing own games) [dev-primary]
**Own game: *Build a Base and Steal*.** Numbers shown live on his Creator Dashboard [YouTube](https://www.youtube.com/watch?v=nggNvUILQ1I):

| Metric | Value |
|---|---|
| CCU at recording (up from about 1k a week earlier) | 13,244 |
| Robux over 72 hours | 716,367 |
| Estimated monthly revenue | $25,070 |
| D1 retention | 21.44% |
| D7 retention (shown / his projection) | 1.38% / about 4% |
| Average playtime | 42.2 minutes |
| Session time tile | 14.5 minutes |
| Payer conversion | 0.75% |
| Revenue per paying user | 162.5 Robux |
| New users per day | 92,513 |

**Mechanics he credits** [YouTube](https://www.youtube.com/watch?v=nggNvUILQ1I):
- **The PvP stealing loop:** "The loop of: build, someone tries to steal, rebuild = TONS of depth." He adds: "PvP makes it so no session ever truly feels the same."
- **Sunk cost from base building:** players spend 20+ minutes building a base and become attached to it.
- **Scheduled events:** "mystery event in 25min."
- **Visible rarity teasing in the roller:** "the first time you click a roll, you will see it flash by super cool looking pets." He says this and other roller changes more than doubled payer conversion.
- **Pricing and onboarding changes:** removing auto-roll, offering Robux on the upgrade board when a player is short of cash, updating daily, and shipping a new tutorial every day for the first week.

**Follow-up video on the same game** [YouTube](https://www.youtube.com/watch?v=FnsIL4zPCQg):
- About 33 million visits and a 60,000 CCU peak during an "admin abuse" event.
- New-user first-session retention of 95% at 30 seconds and 65% at 5 minutes. He compares this with 20–30% at 5 minutes for many games he has reviewed.
- "You need to get them emotionally invested into the game in the first 90 seconds."
- His five pillars: a clickable fantasy, onboarding that explains why an action matters, a game that is "ten times more fun to play with friends," simple mechanics with depth, and clippability (easy to turn into short videos).

His channel also advertises other games at "$44,052/mo" [YouTube](https://www.youtube.com/watch?v=E_tVm3bc5Xo) and "$119,300/mo" [YouTube (channel)](https://www.youtube.com/channel/UCb0CbfnzYo6mLreJIXDxMtQ/about). These are title claims and were not verified.

### 13.7 BruceDevs (developer discussing own games) [dev-primary]
In "How Much I Made In 1 Year Developing on Roblox…" he shows his own dashboards [YouTube](https://www.youtube.com/watch?v=dbNA3K8lt2w):

| Game | Genre / build time | Visits | Robux and other figures |
|---|---|---|---|
| *Paint or Die* | RNG party game, about 3 months | about 20,000 | "flopped" |
| *BRAINROT TAG!* | Tag game, built over Christmas | 1.5 million+ | 920,642 Robux lifetime plus 351,162 in Premium payouts; peak about 450 CCU; stats "easily 90th percentile" in its prime |
| *Grow Bamboo For Pandas!* | Simulator, built in 1 week at 16 hours a day | 575,000 | 331,457 Robux lifetime |

- **Total:** about $6,485 USD for the year.
- **Top earners:** a 500-coin product that made 200,000 Robux, and a 199-Robux "Nuke All" troll product that made 80,000.
- **What sold best in the panda simulator:** "stealing people's pandas… and a random secret which is just like fully gambling."
- **Loop sourcing:** the panda game was "just a copy of a core loop that someone else had made… with pandas and bamboo," with offline earnings claimed on return.
- **Retention cost:** the game had poor D7.
- Other video titles on his channel include "How I made 23M ROBUX this year as a small roblox developer (5M Visits)" and "This Roblox game earned $25,000,000 robux in a month" [YouTube (BruceDevs)](https://www.youtube.com/@1_Bruce) **[dev-primary titles]**.

### 13.8 Other named creators: Zurpz, AlvinBlox, SmartyRBX, Fireology
- **Zurpz (attribution unconfirmed).** The video "Roblox Game Design Explained Like You're 5 Yrs Old" [YouTube](https://www.youtube.com/watch?v=CRCcsYEB_6A) came up in a search for Zurpz, but the creator never says his channel name on camera; he identifies his own game as *Raise An Anomaly*. Treat as **[secondary]** for other games and **[dev-primary]** for his own. Key claims:
  - Nearly every "brainrot" hit uses one loop: "leave base, get thing."
  - Games differ in *when* the random roll happens. In *Steal an Egg* it comes after acquiring the item; in *Kick a Lucky Block* it comes before.
  - "Tension, release" pressure-valve level design, where the player "stop[s] to decide if you want to keep going."
  - The 5-minute stock refresh (Grow a Garden seeds, *Steal an Egg* eggs) "stacked on a lot of FOMO" when combined with PvP.
  - The "20% rule": change 20% of a reference game to reach 5–10k CCU.
  - *Raise an Anomaly*'s loop is steal eggs from SCP monsters, hatch them, then feed and level the babies [Roblox](https://www.roblox.com/games/71443883879110/Raise-an-Anomaly) **[dev-primary game description]**.
- **AlvinBlox.** Mainly a scripting tutorial channel ("over a decade of experience") [YouTube](https://www.youtube.com/c/alvinblox), [AlvinBlox.com](https://alvinblox.com/). No retention or session numbers were found.
- **SmartyRBX.** Runs live game-review streams and paid reviews [SmartyRBX](https://www.smartyrbx.com/review), and his "Lazymaxxing" AI-assisted development approach [SmartyRBX](https://smartyrbx.com/). A community thread describes his current stance as "make simple games that everyone wants" [Reddit](https://www.reddit.com/r/robloxgamedev/comments/1lmi4sa/what_do_you_think_about_smarty_rbx/) **[secondary]**. No numeric claims were retrieved.
- **Fireology.** No channel or content could be found under this name in this session.

### 13.9 DevForum and Roblox-published long-form data
- **Roblox "Experiments" case studies** [Roblox DevForum](https://devforum.roblox.com/t/running-successful-experiments-insights-from-top-creators/4549276) **[dev-primary, creator results published by Roblox]**:

| Game | Change tested | Result |
|---|---|---|
| *Build a Crazy Tower* | Tuning "block pools" to find a difficulty sweet spot | +50% payer conversion, +10% average session time |
| *Trolls cannot break this tower* | A free item at the end of an obby | +12.5% playtime, +5.3% D1, no monetization loss |
| *Weird Gun Game* | Replacing the shop with level-based progression | +10% D1 |
| *Flight World* | New mobile altitude controls | +8.2% playtime, +23% revenue |

- **Playing with friends** "can increase your game's retention by 70%," per Roblox Developer Relations. The recommended fix is repeating social systems: weekly company leagues, visitable houses, and houses that produce currency [Medium (Roblox DevRel)](https://medium.com/roblox-developer/from-the-devs-how-social-loops-keep-players-playing-6b24b299c124) **[dev-primary]**.
- **Front-page advice** from loleris, General_Punctuation and TypicalType: clear goals, goals that are not too easy, "an element of randomness," and daily rewards [Roblox DevForum](https://devforum.roblox.com/t/what-makes-a-front-page-game-tutorial-advice-from-top-roblox-devs/1144242) **[dev-primary compilation]**.
- **Small-developer telemetry** [dev-primary, self-reported]:
  - One developer found 45% of players left within 30 seconds. After shortening the opening, D1 went from 6% to 15% and average session from 7.5 to 9.5 minutes [Reddit r/robloxgamedev](https://www.reddit.com/r/robloxgamedev/comments/1sakqj4/i_tracked_retention_on_my_roblox_game_for_3/).
  - Another saw playtime fall from 18 to 12 minutes and D1 from 8–10% to 4–6% after an update [Roblox DevForum](https://devforum.roblox.com/t/sudden-drop-on-playtime-and-retention-with-update/3880064).
  - Roblox's own docs point developers to the "New User First Session Retention" metric [Roblox DevForum](https://devforum.roblox.com/t/game%E2%80%99s-retention-and-average-session-time-extremely-low/4269329).

---

## 14. Cross-genre synthesis: general-purpose numbers

### 14.1 Session and cycle length bands

| Band | Duration | Examples (sourced above) |
|---|---|---|
| Micro-cycle (single action → outcome) | 1–6 s | Slot spin 3–6 s; Coin Master spin; LBaL spin; match-3 swap; idle tick |
| Short cycle (one decision unit) | 10–60 s | Balatro hand; Fisch catch; gacha 10-pull animation; Hunt extraction 30 s |
| Contained short match | 2–5 min | Clash Royale ("a few minutes"); hard Candy Crush levels kept short |
| Mid match | 7–15 min | Overwatch QP about 8 / comp about 12; Hunt Bounty Clash 15 |
| Long match | 20–45 min | Fortnite about 23 (computed); PUBG 30-minute target; LoL 29–36; Tarkov raid timers; Hunt 45 cap |
| Roblox session telemetry | 7.5–114 min average | 7.5–9.5 (small dev); 12–18 (DevForum); 20.39 (Blox Fruits); 42.2 (Build a Base and Steal); 114.41 (Pet Sim 99) |

Two rules recur across these bands:
- **The harder the unit, the shorter it should be.** King's finding: a hard level should also be a short one.
- **Minimum-engagement floors exist.** Tarkov's 7-minute or 200-XP "Run Through" rule sets a floor under raid length.

### 14.2 Return and appointment cadence

| Interval | Examples |
|---|---|
| 5 min | Grow a Garden / *Steal an Egg* stock refresh |
| 20–25 min | Blox Fruits fruit despawn (20); *Build a Base and Steal* mystery event (25) |
| 50–60 min | Coin Master 5-spin regeneration; Blox Fruits hourly fruit spawn |
| 3–12 h | Clash Royale chest unlocks (3/8/12); free chest every 4 h; Blox Fruits dealer restock every 4 h |
| 10 h | Coin Master full refill (50 spins) |
| 24 h | Clash Royale crown chest; Hunt daily first-extraction bonus; Tarkov insurance return (24–36 h) |
| 7 days | Grow a Garden (Saturday 7am PST) and Adopt Me weekly updates |
| About quarterly | Adopt Me deep updates |

Offline accrual (idle games, Grow a Garden, BruceDevs' offline earnings) makes every return interval pay out, so time away itself becomes a reward.

### 14.3 Escalation curve shapes

1. **Flat-then-ramp to a cap (pity).** Genshin: 0.6% flat to 73, about +6 points per pull from 74, 100% at 90. The visible counter turns every miss into progress.
2. **Accelerating squeeze.** Fortnite storm: intervals shrink from 2:00 to 0:30, damage per second rises 1 → 10, area falls from 2,200 m to 0. Tension builds to a single end point.
3. **Exponential cost against linear income, then reset.** Idle games: cost × 1.07^n. Prestige gains grow as roughly the square root to the seventh root of lifetime or run earnings, so doubling prestige takes 4× to 128× the previous run.
4. **Steep stepped targets.** Balatro antes (roughly exponential, unverified) and LBaL's rising rent schedule. The build must outgrow the curve.
5. **Rising carried value (extraction).** Tarkov and Hunt: stakes grow the longer the player survives. Hunt adds a visibility cost when carrying the bounty (map lightning).
6. **Peak-and-valley difficulty.** Candy Crush: a hard level followed by 5–6 easier ones.
7. **Tension and release.** Greene's "dips of… I'm safe"; the Roblox pressure-valve pattern of running, finding a safe spot, and deciding whether to push on.

### 14.4 Stop-or-continue decision points: what the player sees

Across every genre, the continue decision comes with a **visible gap or threshold**:

| Genre | What the player sees |
|---|---|
| Slots | Credit meter, near-miss symbol just off the line, LDW celebration |
| Gacha | Pity count and 50/50 guarantee status |
| Match-3 | Moves left, objective remaining, +5 moves offer |
| Roguelikes | Score target against hands and discards left (Balatro); rent due against spins left (LBaL) |
| Extraction | Raid timer, extraction points, bag value |
| MOBA | Surrender vote from 15:00 (4 of 5), remake from 3:30 |
| Clash Royale | Chest slots full or open |
| Coin Master | Spin count and bet multiplier |
| Roblox | Restock countdown, event countdown, other players' bases or pets visible (aspirational comparison) |

### 14.5 Failure-penalty tuning spectrum

| Tier | What is lost | What is kept | Examples |
|---|---|---|---|
| 0: No failure | Nothing (time only) | Everything; offline progress continues | Grow a Garden ("don't… get left behind"); idle games; Adopt Me |
| 1: Attempt cost | One life, spin or pull | All progress; pity advances | Candy Crush (5 lives); Coin Master; gacha (pity keeps counting) |
| 2: Rank or reward cost | Trophies, LP, the chest | Cards, account, cosmetics | Clash Royale; League; Overwatch |
| 3: Run loss with meta-keep | The run | Unlocks, ascension or stakes, account XP | Balatro; Slay the Spire; BR battle pass |
| 4: Gear loss with partial keep | Carried gear, Hunter | Secure container, insurance (24–36 h), half XP, account | Tarkov; Hunt |
| 5: Stake loss or theft | Wager, or the stolen item | Rebirth stats, base | Slots; Steal a Brainrot / Build a Base and Steal |

**Tuning evidence.**
- King found that over-tuned difficulty raised short-term conversion but increased churn, and that easier tuning kept players longer and compounded later spending.
- *Build a Crazy Tower* found a difficulty "sweet spot" worth +50% payer conversion.
- Greene's 10–20% win rate shows a high-failure loop holds up when each attempt is cheap and varied.

### 14.6 Feedback cadence targets
- **Continuous (under 1 s):** idle number ticks, match-3 animations.
- **Every 2–6 s:** slot spin result; Steal a Brainrot income ticks; Diablo kill-and-drop lottery; LBaL spin payout.
- **Every 10–30 s:** a "notable" signal. A 16.7% hit frequency at 3 s/spin gives about one win per 18 s (computed); Balatro hand scoring; Fisch catch reveal.
- **Every 10 actions:** a guaranteed mid-tier reward (Genshin 4★ per 10 pulls).
- **Every 60–90 actions or minutes:** a top-tier guarantee (5★ at 90; about 1 hour spawn cycles).
- **Most small rewards are tiny.** In the slot data, 70–75% of wins are the two smallest prizes. Big rewards get distinct presentation: colour, sound, "flash-by" teasing of rare items.

### 14.7 First-session numbers (Roblox platform)
- **30 seconds:** 45% churn in one small game [Reddit](https://www.reddit.com/r/robloxgamedev/comments/1sakqj4/i_tracked_retention_on_my_roblox_game_for_3/), against 95% retained in *Build a Base and Steal* [YouTube (Tizzy)](https://www.youtube.com/watch?v=FnsIL4zPCQg).
- **5 minutes:** 65% retained for a strong game against 20–30% for weak ones (Tizzy).
- **90 seconds:** Tizzy's target for getting a player emotionally invested.
- **D1 retention:** 4–10% for struggling games, 15% after fixes, 21.44% for a top performer.
- **Friends:** +70% retention when playing with friends (Roblox DevRel).

---

## Data Limitations

| Item | Status / fallback | Data year |
|---|---|---|
| YouTube transcripts for GMTK, Extra Credits, Adam Millard, Game Wisdom, Design Doc, and the Fisch Creator Events video | Transcript unavailable; titles, descriptions and third-party summaries used | Various |
| "Design Doc" channel attribution | Could not confirm which videos belong to the channel; related videos flagged | — |
| Zurpz | Video found by name search; channel not confirmed on-camera | 2025–26 |
| Fireology | No content found | — |
| AlvinBlox, SmartyRBX | No retention or session numbers found | — |
| Path of Exile GDC talk numbers | GDC Vault login-gated; the ~13-week league cycle is unverified | 2019 |
| Candy Crush life-refill timer (~30 min) | Unverified | — |
| Balatro ante chip targets | From game knowledge, unverified in this session | 2024 |
| Clash Royale 3:00 regulation + overtime | Unverified; chest timers are the classic system, now replaced (2025) | 2016 / 2025 |
| Overwatch average match length | Reddit thread reporting a Blizzard disclosure; original not accessed | ~2025 |
| Tarkov raid timers | Player-reported (Customs 25 min); changes by patch | Various |
| Coin Master spin regeneration | Two sources disagree (5 per 50 min vs 5 per 60 min), likely different versions | 2019 / 2021+ |
| Genshin average pulls | Source says 78–80; my calculation gives about 61–63 overall | 2026 guide |
| Fortnite total match length | The summary returned with the wiki page gave 22:20 (arithmetic error); my corrected sum is about 23 min | v41.20 |
| Blox Fruits "20.39" average playtime | Unit not labelled on Rolimons; assumed minutes | 2026 |
| Fisch peak CCU | Sources conflict (470k dev-reported; 419,625 for one place; "1M CCU" on Reddit) | 2024–25 |
| Blox Fruits revenue ($8–12M/month) | Third-party estimate, not developer-confirmed | 2023–24 |
| Tizzy's $44k / $119k per month | Video-title claims, not shown on a dashboard in this session | 2025–26 |
| Pet Simulator 99 design interviews | No BIG Games design interview with numbers found; tracker data only | 2023–26 |
