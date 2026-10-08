# Reference: Repeatable, escalating gameplay loops across genres

**Evidence convention.** `[scholarly]` marks research studies; `[dev-primary]` marks a studio, designer, or creator discussing its own game or product; `[secondary]` marks analysis, reporting, player/community posts, or creator commentary about someone else’s game. Where a source does not report a requested measurement, I say **not reported** rather than estimating it. “Feedback cadence” means how often the player receives a meaningful in-game reward or result—not how often a screen animates.

## 1. Roblox creators, developer commentary, and shipped-game evidence

### Roblox-focused YouTubers named in the request

| Creator/source | What the source supports | Requested mechanics and measurements |
|---|---|---|
| **BruceDevs** — [“How I made 23M ROBUX this year as a small Roblox developer (5M Visits)”](https://www.youtube.com/watch?v=wKI3PBO3bB0) | The video title and its description attribute **23 million Robux** and **5 million visits** to the creator’s development year. This is self-reported creator material, so the metric is **[dev-primary]**. | **Exact game/core loop:** not established in the accessible source text. **Session length, escalation, stop/continue decision, failure keep/loss, feedback interval, retention and CCU:** not reported in the accessible transcript/search record. I could not verify which of the creator’s games the headline metrics refer to, so I do not attach them to a particular title. |
| **Tizzy RBLX** (the search results surfaced this channel, rather than an account clearly named “TizzyBlox”) — [“I Made Another $25,070/mo Roblox Game (13.1k CCU)”](https://www.youtube.com/watch?v=nggNvUILQ1I); [available transcript](https://sozai.app/transcript/made-25070-month-roblox-game/) | In his own postmortem-style video, Tizzy names the game **Build a Base and Steal** and describes the loop as rolling for pets, building/defending a base, and PvP theft. He reports roughly **$25,000 monthly revenue**, **13.1k CCU**, a launch about **two weeks** before recording, and growth from **1k to over 13k CCU in about a week**. These are **[dev-primary] self-reports**, not independently audited figures. | **Session:** reports **42 minutes average playtime**. **Escalation:** pet rolls and base-building feed a PvP economy; theft and defenses make other players a source of risk. He reports removing auto-roll, changing the tutorial to foreground the base/locking mechanic, shrinking the map, and adjusting the upgrade board. **Stop/continue:** the source exposes the base/roll/PvP choices, but gives no measured decision-point telemetry. **Bad outcome:** the transcript establishes theft/defense as part of the loop but does not say precisely what the defender keeps or loses on a raid; **not reported**. **Cadence:** each roll and PvP interaction produces a result, but no seconds-per-reward figure is given. **Retention:** Tizzy reports **31% D1 retention for search traffic**. The same transcript includes UI-like D7 values—“2.93, 2.01, 3.45”—without sufficiently clear units or labels; I leave them uninterpreted. |
| **AlvinBlox** — [“Here’s Why Roblox Games Blow Up”](https://www.youtube.com/watch?v=Y93DRfB-Deo) | The search result confirms an **11:01** analysis video, but the accessible video transcript was unavailable. This is a **[secondary]** source: analysis of games, not the games’ developer speaking. | **Specific game mechanic, session length, escalation, decision visibility, failure persistence, feedback seconds, and performance metrics:** not verifiable from the accessible transcript. The video title alone is not evidence for a particular mechanic or number. |
| **SmartyRBX** — [“The Secret To Making Your Roblox Game FUN!”](https://www.youtube.com/watch?v=gc7K98RlOik) | Search results identify a short game-design video by a Roblox developer/educator. The transcript was unavailable, so I cannot attribute the forum’s separate “flex mechanic” advice to SmartyRBX. | **Specific claims and the six requested loop details:** not verifiable from the accessible transcript. No session or retention numbers established. |
| **Zurpz** | Targeted searches did not surface a clearly matching Roblox game-design breakdown, shipped-game postmortem, or developer commentary that could be verified for this task. | **No source-specific loop or metrics verified.** |
| **Fireology** | Targeted searches did not surface a clearly matching Roblox game-design breakdown or shipped-game postmortem. Search results included unrelated material, so I have not treated it as evidence. | **No source-specific loop or metrics verified.** |
| **Lolzou** | Targeted searches did not surface a clearly attributable Roblox developer commentary or game-design breakdown. | **No source-specific loop or metrics verified.** |

Those negative entries are **search-result limitations**, not a claim that the creators have never made relevant content. I found a clear self-reported gameplay-and-metrics breakdown for Tizzy RBLX and a headline-only self-report for BruceDevs; I did **not** find equivalent, transcript-verifiable evidence for every named channel. [**dev-primary**: Tizzy’s self-report](https://www.youtube.com/watch?v=nggNvUILQ1I) [**secondary**: AlvinBlox](https://www.youtube.com/watch?v=Y93DRfB-Deo)

### Roblox Developer Forum posts: real funnel observations and shipped-game anecdotes

- **Space Simulator X — developer’s retention thread.** The team reports that onboarding analytics showed **47% of players left before collecting 100 coins for the first egg**. They found a bug that made the first area pay out about **90% fewer coins** than intended: the first hatch took roughly **30–40 rocks** rather than **3–4**. The developers changed the first egg price to **70 coins**, lowered a later area price to **3,000**, moved shops closer to spawn, and increased early progression. **Loop:** break rocks → earn coins → hatch an animal/egg → improve progress. **Stop point:** the first egg is a clear first-session milestone; the measured funnel shows drop-off before it. **Failure:** no death penalty is described; the measured failure is abandonment from slow progress. **Feedback cadence:** earnings happen during rock-breaking, but no seconds-per-feedback number is given. [**dev-primary**: developers discussing their own game and analytics](https://devforum.roblox.com/t/any-tips-to-improve-d1-retention-for-my-game/3123291)

- **A simple animal-hatching game — “Game’s retention and average session time extremely low.”** The creator reports a roughly **5-second tutorial**, about **50%** tutorial completion, the biggest churn at the first animal hatch, an average playtime of about **3 minutes**, and approximately **1% D1 retention**. Players who got through onboarding commonly hatched **one or two** more times and left. The developer describes the hatching minigame as dull and unforgiving: one error broke the egg, despite the first hatch being intended not to fail. **Escalation:** repeated hatches, daily/playtime rewards, and a pity system; the source does not quantify their impact. **Stop/continue:** continue by hatching again; first-hatch friction was the critical observed exit point. **Bad outcome:** a broken egg was the specific failure; the creator says first-hatch protection existed, but later failures could break the egg. **Cadence:** per-hatch results, no seconds figure. [**dev-primary**: developer’s own analytics and design discussion](https://devforum.roblox.com/t/game%E2%80%99s-retention-and-average-session-time-extremely-low/4269329)

- **Pipe Dash / recommendation traffic — creator’s reported CCU.** In the same D1 thread, a developer discussing their own game says it had previously reached **300–500 CCU**, later saw around **100 concurrent players**, and that **100 CCU** was low relative to its previous peak. The post does not provide a session-length or retention series for Pipe Dash, so those fields are **not reported**. [**dev-primary**: creator-reported figures in forum discussion](https://devforum.roblox.com/t/any-tips-to-improve-d1-retention-for-my-game/3123291)

- **The forum’s general “addicting” advice thread.** A duel-game developer asks why a 1v1 game plus a currency-funded spinner/crate did not feel compelling. A respondent points to visible cosmetics as a “flex” mechanic: the player can display an item that signals time or effort. **Session length, escalation, failure retention, and reward interval:** not reported. This is **community advice**, not the game’s shipped analytics or a verified success postmortem. [**secondary**: forum discussion](https://devforum.roblox.com/t/making-aspects-of-game-addicting/2566286)

- **“So your game died…” — market/design post.** The author’s central design argument is to distinguish a game’s repeatable fun from a clear niche, and contrasts transient spikes with a stable community. It does not give measured success data for a named hit; it is best treated as a **[secondary]** design essay, not a telemetry source. [**secondary**](https://devforum.roblox.com/t/so-your-game-died-a-thread-on-game-design-and-the-market/2644450)

Roblox’s own creator documentation provides a useful measurement vocabulary: D1/D7/D30 are cohort-return measures; core-loop and onboarding completion can be measured step by step; the guidance says the first-time experience should get players to the core loop quickly, with **5 minutes or less** as an ideal onboarding target. These are platform recommendations, not claims about any one hit’s actual session duration. [**dev-primary**: Roblox Creator Hub retention documentation](https://create.roblox.com/docs/production/analytics/retention)

### Roblox hits and studio-side material

#### [Grow a Garden](https://www.rolimons.com/game/126884695634066)

- **Loop and mechanic:** buy seeds → plant → wait → harvest and sell → reinvest in seeds or garden growth. The garden continues growing while the player is offline. Players can also steal from other gardens and compare crops/currency. BBC reporting describes competition over who has the most in-game currency or best plant; the captured Rolimons game description independently states the seed/plant/grow/harvest/offline loop. [**secondary**: BBC report](https://www.bbc.com/news/articles/cj4edkdxz2xo) [**secondary**: game-page tracker/description](https://www.rolimons.com/game/126884695634066)
- **Session length:** the Rolimons page snapshot returned **16.96 minutes average playtime**. It is a third-party snapshot, not Roblox’s internal retention dashboard. **Feedback cadence:** harvest/plant transactions are event-based; no exact seconds-per-reward interval is published in these sources. [**secondary**](https://www.rolimons.com/game/126884695634066)
- **Escalation and decisions:** the player sees a plot and current shop stock, chooses what to plant, and can wait offline or remain in-session to tend/harvest. Crop rarity/value and garden comparison create longer-horizon goals; the sources do not publish a numeric within-session difficulty curve or a precise “continue versus quit” telemetry point. **Bad outcome:** the reported player-to-player theft mechanic creates a loss possibility, but the cited sources do not specify exactly what remains protected or is lost on a theft. [**secondary**: BBC gameplay reporting](https://www.bbc.com/news/articles/cj4edkdxz2xo)
- **Performance:** GameDeveloper, citing Roblox’s Q2 2025 results, reports nearly **22 million concurrent users in July 2025**. The later Rolimons snapshot lists **22,375,597** as all-time peak CCU and **35.9 billion** visits; use those as tracker-reported historical values, not current concurrent users. [**secondary**: GameDeveloper](https://www.gamedeveloper.com/business/roblox-s-grow-a-garden-had-nearly-22-million-concurrent-users-in-july) [**secondary**: Rolimons snapshot](https://www.rolimons.com/game/126884695634066)

#### [Steal a Brainrot](https://www.rolimons.com/game/109983668079237)

- **Loop and mechanic:** buy a Brainrot → generate money → steal from other players → reinvest/rebirth; the game page also lists slaps and troll gear. The visible risk source is opponent theft; the game’s own page description lists the basic loop. [**secondary**: tracker-captured game description](https://www.rolimons.com/game/109983668079237)
- **Session length:** Rolimons returned **13.90 minutes average playtime** in the captured page data. **Escalation:** rebirth and money-generation progression; the exact threshold curve and value of each rebirth are not present in this source. **Decision visibility:** the player can see owned collectibles, generated money, and other players’ bases; the sources do not provide decision telemetry. **Bad outcome:** theft is an explicit mechanic, but the cited page does not specify exactly which assets are protected, lost, or retained after a failed defense. **Feedback cadence:** money/steal/rebirth outcomes are visible events; no exact seconds rate is reported. [**secondary**](https://www.rolimons.com/game/109983668079237)
- **Performance:** PocketGamer reports a **25.4 million CCU record** and compares it with Grow a Garden’s roughly **22.4 million** peak. Rolimons’ snapshot lists **13.90 minutes** average playtime. These are reported platform/game figures, not in-game session telemetry from the studio. [**secondary**: PocketGamer](https://pocketgamer.biz/robloxs-steal-a-brainrot-becomes-first-game-to-surpass-25m-concurrent-players/) [**secondary**: Rolimons](https://www.rolimons.com/game/109983668079237)

#### [Fisch](https://devforum.roblox.com/t/creator-spotlight-woozynate-makes-a-splash-with-fisch/3269481)

- **Loop and mechanic:** explore an island/area → choose a location and rod → fish through a catch minigame → collect species, variants, and weight records → pursue quests, better stats, or competition. Creator WoozyNate says he made the game open-ended with multiple goals because different players pursue collection, stats, or competition. Fish resilience varies, changing how difficult the catch minigame is; rods have distinct use cases and abilities. [**dev-primary**: WoozyNate interview](https://devforum.roblox.com/t/creator-spotlight-woozynate-makes-a-splash-with-fisch/3269481)
- **Session/stakes/decisions:** the interview gives no average session length. Stakes rise through more difficult fish, rare species/variants, and location-specific requirements. The player’s visible decision is where to fish and which rod to use; the exact choice cadence or “stop now” data is not reported. **Bad outcome:** a failed catch is part of the minigame, but the interview does not specify what inventory or progress is lost on failure. **Feedback cadence:** one fish-catch minigame produces a result; seconds per catch are not reported.
- **Longer-cycle event and metrics:** WoozyNate says FischFright’s ingredient hunt recurred every **30 minutes to an hour**, with exclusive event fish appearing during the event. The Roblox creator spotlight says the game reached about **470,000 peak CCU** after the event, with tens of thousands of concurrent players sustained during the event. [**dev-primary**](https://devforum.roblox.com/t/creator-spotlight-woozynate-makes-a-splash-with-fisch/3269481)

#### [Adopt Me!](https://www.uplift.games/blog/uplift-games-launch-release)

- **Loop and mechanic:** explore/socialize → adopt, collect, and care for pets → trade or decorate/build → continue collecting and playing with friends. The studio describes house-building, collecting and trading **150+ pets**, and player-created activities with friends. The cited studio release does not specify task durations or average session time. [**dev-primary**: Uplift Games](https://www.uplift.games/blog/uplift-games-launch-release)
- **Escalation/decisions/failure/cadence:** the source supports accumulating a collection and creating social goals, but does not give the within-session escalation curve, a quantified stop/continue point, or exact loss-on-failure rules. Feedback is event/task/collection based; seconds per reward are not reported.
- **Metrics:** Uplift Games reported **22 billion visits**, **60+ million monthly users** after a **100%** rise from January 2020 to January 2021, **1.92 million CCU** during the April 2021 Ocean Egg update, and **over 400% year-over-year revenue growth in 2020**. These are historical studio-published figures, not current stats. [**dev-primary**](https://www.uplift.games/blog/uplift-games-launch-release)

#### [Pet Simulator 99](https://biggames.io/post/category/pet-simulator-99)

BIG Games’ developer blog presents a repeated structure of pet-powered collection, eggs/hatching, upgrades, zones, and rotating events/minigames. Recent entries also describe limited-time collectibles, leagues, clan battles, and bosses. The source demonstrates the studio’s live-ops loop, but does **not** provide a stable average session length, retention telemetry, failure penalty, or per-minute reward interval. The full loop’s exact numbers vary by update, so I do not infer a single permanent timing. [**dev-primary**: BIG Games developer blog](https://biggames.io/post/category/pet-simulator-99)

---

## 2. Other genres and representative games

### Slot machines and casino-style loops

- **Measured interval:** a study of simulated slot play tested **3-second** and **10-second** inter-trial intervals and reinforcement probabilities of **0.3** and **0.7**. In the experiment, a low win rate paired with the **10-second** interval produced longer persistence during extinction than high reinforcement. The paper’s simulated machine used a **3p wager** and payouts of **10–30p** for different symbols. This is experimental evidence about that task, not a universal machine setting. [**scholarly**](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2016.00046/full)
- **Real-machine cadence:** another scholarly source cited by the literature search states that real slot players typically spin about once every **3–6 seconds**. A study of near misses/losses-disguised-as-wins evaluated outcomes as distinct signals; it does not provide a portable “stop decision” or player-session duration for every machine. [**scholarly**: slot-machine study](https://uwaterloo.ca/reasoning-decision-making-lab/sites/default/files/uploads/files/DixFugetal_10c.pdf) [**scholarly**: systematic review](https://pmc.ncbi.nlm.nih.gov/articles/PMC5663799/)
- **Loop fields:** each wager resolves to a win/loss signal; the player can press again after viewing the result and remaining balance. The sources establish the stake/outcome cycle and trial timing, but not an average real-world session duration, the machine’s exact player-facing decision interface, or a standard amount kept after a bad result. In the study, the wager is exposed to the result on each play; no broader account-level retention rule is reported. [**scholarly**](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2016.00046/full)

### Mobile gacha

**Genshin Impact’s Wish guarantee** gives a clean numerical example of a long-horizon chance loop: HoYoverse support says a player is guaranteed a 5-star character within **90 wishes**; on the relevant event banner the featured character probability is described as **50%** when a 5-star is obtained. Each pull resolves immediately; if a high-rarity result does not appear, the number of prior wishes is the relevant accumulated state for reaching the guarantee. The official support source does not state typical session length, seconds per pull, or average pull count per session. [**dev-primary**: HoYoverse support](https://support.hoyoverse.com/hc/en-us/articles/50333940684953-How-does-the-Wish-guarantee-system-work)

- **Escalation:** accumulated wishes advance toward the **90-wish** guarantee. **Decision point:** after each result, the player can stop or continue; the official help describes the guarantee but not the in-client visibility of a numeric pity counter. **Bad result:** the pull’s currency is spent and the target character is not necessarily obtained, while progress toward the guarantee remains relevant. **Feedback:** one reveal per pull; no exact number of seconds is published. [**dev-primary**](https://support.hoyoverse.com/hc/en-us/articles/50333940684953-How-does-the-Wish-guarantee-system-work)

### Match-3: Candy Crush Saga

- **Session/run length:** a 2013 GameDeveloper analysis describes typical levels as **30 seconds to 2 minutes**. A modern King data-science account discussed level length qualitatively, saying longer levels are less likely to be fun and that the maximum recommended duration depends on difficulty; it did not publish a universal numeric cap. [**secondary**: historical level-length analysis](https://www.gamedeveloper.com/design/candy-crush-saga-a-sweet-journey-into-monetization) [**secondary**: report of King’s GDC metrics talk](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/)
- **Loop and feedback:** swap candies → resolve matches/cascades → work toward a level objective under a move limit → win, fail, or continue. The player receives immediate visual score/progress feedback after moves; exact seconds-per-signal are not reported. A GDC discussion of King’s process emphasizes theory, tools, testing, and data-driven level tuning. [**secondary**: GDC talk coverage](https://www.gamedeveloper.com/design/video-king-s-guide-to-level-design-for-casual-games)
- **Escalation and decision:** objective difficulty rises across levels; the player sees remaining moves and board state and chooses each swap. King’s data-science report says the famously difficult level 65 initially produced high conversion but also high churn; making it easier lowered immediate conversion but retained players longer. King measures “time to abandon” and “time to pass,” rather than treating difficulty alone as fun. [**secondary**](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/)
- **Bad outcome/continue:** official Candy Crush support says players begin with **5 lives** and lose one on a failed level; it describes replenishment rules. An older analysis reports an extra-moves offer of **5 moves** and a **$0.99** life refill, but that is a dated secondary description, not a statement of current pricing. [**dev-primary**: King support](https://candycrush.zendesk.com/hc/en-us/articles/360000750878-How-do-lives-work) [**secondary**: older monetization analysis](https://www.gamedeveloper.com/design/candy-crush-saga-a-sweet-journey-into-monetization)

### MOBA / real-time PvP: Clash Royale; hero shooter: Overwatch

**Clash Royale** has a measurable compact match loop: card deck → **3-minute** battle → **up to 1 minute overtime** if tied → trophy/chest outcome → card/gold upgrades → revised deck. Players have a visible hand of cards and elixir; the deconstruction reports elixir generation at **1 point every 2 seconds** during the opening phase, then doubled generation in the final minute. That pacing makes the same decision—play a card or save elixir—more time-pressured as the battle approaches its end. [**secondary**: game-design deconstruction](https://www.gamedeveloper.com/design/clash-royale---deconstructing-supercell-s-next-billion-dollar-game)

- **Stop/continue:** after battle, the player can queue again or return to deck/meta management. Victory grants trophies and a chest; defeat loses trophies in the analyzed model but does not delete the player’s deck. The visible battle state is towers, card hand, elixir, and clock. **Feedback cadence:** battle events occur continuously; the exact seconds between reward signals are not measured, but elixir changes at **2-second** intervals. **Session length:** one battle is **3–4 minutes**, with the one-minute overtime conditional on a tie. [**secondary**](https://www.gamedeveloper.com/design/clash-royale---deconstructing-supercell-s-next-billion-dollar-game)

**Overwatch Quick Play** is a useful hero-shooter comparison, but the timing evidence found here is a community post citing gameplay metrics, not a developer postmortem: it reports an average Quick Play match of about **8 minutes** and competitive matches around **12 minutes**. The post does not establish a universal average across patches/modes. The requested mechanics/failure fields are therefore not represented as developer-verified measurements here. [**secondary**: community report of gameplay metrics](https://www.reddit.com/r/Competitiveoverwatch/comments/1kco71l/blizzard_lets_slip_some_gameplay_metrics_showing/)

### Battle royale: PUBG / Fortnite

PUBG creator Brendan Greene describes the shrinking circle as a simple way to keep all remaining players in one area, avoiding late-game cases where separated players cannot find each other. The circle converts time into spatial pressure: players see the safe area and must decide whether to move, fight, or take a longer route as the playable zone contracts. [**dev-primary**: creator interview](https://arstechnica.com/gaming/2018/07/video-chat-with-pubg-creator-we-could-put-battle-royale-in-everything/)

- **Session length:** the creator interview does not state a typical match length; I did not find a dependable fixed duration that holds across PUBG/Fortnite modes and patches. **Bad outcome:** elimination ends that match’s survival attempt; the cited interview does not give a general account of which between-match progression is retained. **Feedback cadence:** exploration, combat, loot, and circle movement are ongoing, but no seconds-per-reward measure is reported. The strongest directly sourced mechanism here is the **shrinking spatial boundary and information it exposes**, not a documented average session time. [**dev-primary**](https://arstechnica.com/gaming/2018/07/video-chat-with-pubg-creator-we-could-put-battle-royale-in-everything/)

### Clicker / incremental: Cookie Clicker

The documented loop is click a large cookie to gain cookies → buy production buildings/upgrades → increase cookies-per-second → unlock further purchases. The creator’s site and retrospective describe prestige/ascension as a reset that grants a longer-term prestige resource. [**secondary**: design retrospective](https://www.gamedeveloper.com/design/the-recipe-behind-cookie-clicker)

- **Session length:** open-ended; no published average was established here. **Feedback cadence:** a click immediately yields a cookie; passive production generates ongoing progress, but no specific production tick interval is documented in the sources reviewed. **Escalation:** production rates and purchase costs scale; the player chooses which upgrade and when to ascend. **Failure:** no ordinary “bad run” or life loss is central to this loop; ascension is a voluntary reset with prestige progression. Exact values depend on the current game state and are not reported here. [**secondary**](https://www.gamedeveloper.com/design/the-recipe-behind-cookie-clicker)

### Deckbuilding roguelikes: Balatro and Slay the Spire

**Balatro.** In a developer interview, LocalThunk describes a run as scoring enough chips to beat an ever-rising required score. Jokers and other modifiers combine into synergies; LocalThunk says the metastrategy is to mitigate risk while making the build strong enough to win. The player chooses hands, shop purchases, skips, and build direction, with score thresholds and resources visible. [**dev-primary**: LocalThunk interview](https://rogueliker.com/balatro-interview/)

- **Session/run length:** the interview does not report a standard run duration. **Escalation:** required scores rise; the player assembles a build to meet them. **Stop/continue:** the player can continue the run or end it after losing; the source discusses risk reduction but does not document a separate cash-out decision. **Bad outcome:** a lost run ends the current run’s build; exact persistence of unlocks and the current-run inventory is not quantified in the interview. **Feedback cadence:** score resolves after each played hand, but exact seconds per hand are not reported. The same interview records **500,000 copies sold** at the time of publication; that is a launch-era sales number, not a session metric. [**dev-primary**](https://rogueliker.com/balatro-interview/)

**Slay the Spire.** The Mega Crit GDC talk is explicitly about metrics-driven balance; public GDC search results identify that subject, though the Vault page did not expose the talk text in this pass. As a practical player-reported run-length reference, a Steam discussion gives **45–60 minutes** for a typical run for that poster and **30–90 minutes** for daily runs, explicitly as anecdote rather than a studio average. [**dev-primary**: Mega Crit’s GDC talk listing](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics) [**secondary**: player reports](https://steamcommunity.com/app/646570/discussions/0/1642042464745019506/)

- **Loop:** choose map path → battle → choose a card/reward or skip → shop/rest/event → prepare for harder encounters and bosses. The choices are visible at route nodes, combat, and reward/shop screens. **Escalation:** enemies and act/boss milestones increase pressure; the player’s deck and relics evolve through the run. **Bad outcome:** defeat ends the current run and loses run-specific build state; exact long-term unlock retention is not measured in the cited player timing discussion. **Feedback cadence:** turn-by-turn combat results and post-battle rewards, with no seconds-per-feedback rate reported. [**secondary**: player run-length discussion](https://steamcommunity.com/app/646570/discussions/0/1642042464745019506/) [**dev-primary**: GDC session listing](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics)

### Extraction shooters: Hunt: Showdown and Escape from Tarkov

**Hunt: Showdown 1896.** Crytek describes a bounty-hunt match as **12 players**, solo or in teams of two or three, competing to kill a boss, take a Bounty Token, and extract. It also describes a shorter solo mode, Soul Survivor. The design’s core decision is when to pursue, carry, and extract a bounty while other hunters can contest it; Crytek describes a single mistake as potentially costing everything. [**dev-primary**: Crytek game description](https://www.crytek.com/news/devils-trail-transforms-hunt-showdown-1896)

- **Session length:** a community guide gives **45 minutes** as the Bounty Hunt hard limit and about **25 minutes** as a likely average for that guide’s play context; these are **[secondary]** figures and may vary with version/mode. [**secondary**: Hunt guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2760060527)
- **Escalation/visible information:** clues, boss activity, enemy traces, bounty markers, and extraction points create progressively better information and a more valuable but more exposed return trip. In Crytek’s 2026 event description, the choice is explicitly framed as rushing the known boss target or spending time scouting for hidden locations and tactical information. [**dev-primary**](https://www.crytek.com/news/devils-trail-transforms-hunt-showdown-1896)
- **Bad outcome/cadence:** death can cost the hunter and carried gear; exact recovery exceptions and current insurance rules are not specified in the cited release. Bounty extraction is the clear stop-or-continue decision. Reward signals occur at clues, combat, boss kill, bounty pickup, and extraction; the sources do not state a seconds-based cadence. [**dev-primary**](https://www.crytek.com/news/devils-trail-transforms-hunt-showdown-1896)

**Escape from Tarkov.** The extraction structure is raid → scavenge/complete objectives → decide whether to extract with carried loot or keep exploring → next raid/Hideout progression. Current raid timers vary by map/version, and the sources reviewed did not establish a stable current “typical raid” duration. A secure container protects its contents from being lost on death, while other carried items are at risk; that distinction is documented in the game’s community wiki. [**secondary**: looting reference](https://escapefromtarkov.fandom.com/wiki/Looting)

- **Escalation/visible decision:** inventory value, health/ammunition, remaining raid time, and known extraction options inform the decision to leave or continue. **Bad outcome:** death risks carried gear and raid loot; the cited secure-container source specifies the protected exception. **Feedback cadence:** loot, encounters, and extraction outcomes are event-based; no fixed per-minute reward rate or average session figure is reported here. [**secondary**](https://escapefromtarkov.fandom.com/wiki/Looting)

### Looter shooters / ARPGs: Diablo and Path of Exile

**Diablo III loot.** The analyzed loop is combat → randomized drops → compare/upgrade/salvage or trade → return to combat. Random drops create a variable reward event; the secondary design analysis also describes achievement notifications as a social signal that makes high-tier finds salient. It gives no exact drop interval, session length, or average number of encounters before an upgrade. [**secondary**: GameDeveloper analysis](https://www.gamedeveloper.com/design/the-psychology-of-i-diablo-iii-i-loot)

- **Escalation:** the target item/build provides a long-horizon objective while each drop can offer an immediate upgrade. **Stop/continue:** continue farming or return to inventory/auction systems; exact player-visible drop-rate information is not stated in the article. **Bad outcome:** an unhelpful drop costs time but the source does not describe a run-ending loss. **Feedback:** each drop/achievement event; seconds per drop are not specified. [**secondary**](https://www.gamedeveloper.com/design/the-psychology-of-i-diablo-iii-i-loot)

**Path of Exile.** A GGG designer interview describes item, skill, and support-gem balance, crafting systems, encounter setup, and league mechanics as areas of design work. A designer’s personal retrospective mentions needing months to understand the game, multiple failed builds before reaching endgame, and roughly **100 hours** of Docks farming in an early-era example; that is an individual historical account, not a recommended or average session length. [**dev-primary**: GGG designer interview](https://www.pathofexile.com/forum/view-thread/2858423)

- **Session/stop/failure/cadence:** the source does not establish a typical map duration, a numeric escalation curve, or seconds-per-drop. The repeated structure supported by the source is build customization and progression via items/skills, with periodic balance and league systems; details of death/loot persistence are not described in this interview. [**dev-primary**](https://www.pathofexile.com/forum/view-thread/2858423)

### Social-casual mobile: Coin Master

GameAnalytics’ analysis describes a clear slot-to-village progression loop: spin reels → receive coins, attack, raid, or shields → spend coins on buildings → finish a village and unlock the next. A raid is triggered by **three pig symbols**; the attacker gets **three chances** to locate coins. An attack is triggered by **three hammer symbols**. More spins can be wagered to multiply the result. [**secondary**: GameAnalytics analysis](https://www.gameanalytics.com/blog/coin-master-social-casino)

- **Session length and resource cadence:** the analysis says the game grants **5 free spins every 50 minutes**. This differs from some other secondary guides that report **5 per hour** with a **50-spin cap**; the sources disagree, so the 50-minute figure is attributed specifically to the GameAnalytics article, not treated as a universal current rule. [**secondary**](https://www.gameanalytics.com/blog/coin-master-social-casino) [**secondary**: alternate tracker guide](https://coinmasterwiki.com/guides/how-many-free-spins-per-day-coin-master/)
- **Escalation and visible choice:** village completion advances to a new base; later villages unlock features and higher payouts. The player sees the reel symbols and can choose how many spins to wager. **Bad outcome:** an attack may be blocked by shields; a raid can return no loot, and the article describes the three-guess raid mini-game. **Feedback cadence:** one slot result per spin and immediate attack/raid outcomes; no universal seconds-per-spin figure is supplied. [**secondary**](https://www.gameanalytics.com/blog/coin-master-social-casino)

---

## 3. Cross-genre synthesis: reported timing bands and loop shapes

These are **observed examples**, not universal targets. The published figures mix controlled research, game rules, creator self-reports, third-party tracker snapshots, and player anecdotes—so they should not be read as directly comparable averages.

| Observed scale | Source-backed examples | What the player receives |
|---|---|---|
| **Seconds per micro-outcome** | Slot study: **3 or 10 seconds** between trials; reported real-machine play: about **3–6 seconds** per spin. [**scholarly**](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2016.00046/full) | A discrete win/loss or spin result. |
| **Seconds to minutes per action set/level** | Candy Crush level analysis: **30 seconds to 2 minutes**; Clash Royale: **3 minutes plus up to 1 minute overtime**; Clash Royale elixir increments every **2 seconds** in the cited design analysis. [**secondary**](https://www.gamedeveloper.com/design/candy-crush-saga-a-sweet-journey-into-monetization) [**secondary**](https://www.gamedeveloper.com/design/clash-royale---deconstructing-supercell-s-next-billion-dollar-game) | A level completion/failure, a battle result, or repeated tactical-state changes. |
| **Roughly 14–17 minutes average playtime in third-party Roblox snapshots** | Grow a Garden **16.96 minutes**; Steal a Brainrot **13.90 minutes**. These are Rolimons page snapshots, not studio telemetry. [**secondary**](https://www.rolimons.com/game/126884695634066) [**secondary**](https://www.rolimons.com/game/109983668079237) | Several cycles of harvest/collect or buy/steal/reinvest can fit within one visit; exact per-cycle timing is not reported. |
| **Longer creator-reported visit** | Tizzy RBLX reports **42 minutes average playtime** for Build a Base and Steal. [**dev-primary**](https://sozai.app/transcript/made-25070-month-roblox-game/) | Repeated base/roll/PvP interaction; the source does not break 42 minutes into micro-loop counts. |
| **Bounded high-stakes mission** | Hunt guide: **45-minute hard cap**, about **25 minutes average** in the guide’s context. [**secondary**](https://steamcommunity.com/sharedfiles/filedetails/?id=2760060527) | Multiple rounds of exploration and conflict accumulate toward an extraction decision. |
| **Run-based deckbuilder** | Slay the Spire player reports: **45–60 minutes** typical for that poster; daily runs **30–90 minutes**. [**secondary**](https://steamcommunity.com/app/646570/discussions/0/1642042464745019506/) | Route, battle, reward/shop, and boss phases; one defeat ends the current build/run. |

Across the examples, four escalation shapes recur:

1. **Rising thresholds:** Balatro’s required score rises; Cookie Clicker increases production and purchase scale; village/zone progression in Coin Master and pet simulators raises the next milestone. The player sees a threshold or progress state and decides whether to continue, change build, or reset.
2. **Increasing volatility/value:** gacha pity accumulates toward a stated guarantee; randomized loot can yield an immediate upgrade or a non-upgrade; casino spins vary payout and raid outcomes. The visible result is immediate, while the long-horizon goal remains open.
3. **Time compression:** Clash Royale’s overtime and doubled elixir pace push decisions faster late in the match; battle-royale circles reduce safe space; extraction games make carried value and remaining time more salient as a run proceeds.
4. **Persistent compounding:** Grow a Garden’s crops grow offline; incremental games continue production; collection and social comparison persist across visits. In these cases, “stop” does not necessarily mean that the game state stops changing.

**Failure-penalty patterns supported by the sources:** Candy Crush uses a bounded life loss on a failed level; run-based deckbuilders end the current run’s built state; extraction games put carried loot/equipment at risk while providing exceptions such as Tarkov’s secure container; Coin Master uses shields to block some attacks while raids can fail to return loot; Grow a Garden and Fisch sources do not establish a precise failure-retention rule. The source-backed spectrum therefore runs from **local retry cost** to **run reset** to **carried-inventory risk**—with the exact retained/lost state varying by title. [**dev-primary**: King support](https://candycrush.zendesk.com/hc/en-us/articles/360000750878-How-do-lives-work) [**secondary**: Tarkov secure containers](https://escapefromtarkov.fandom.com/wiki/Looting) [**secondary**: Coin Master](https://www.gameanalytics.com/blog/coin-master-social-casino)

**Feedback cadence, stated conservatively:** the clearest exact intervals in this sweep are the slot-study’s **3/10-second** trial intervals and Clash Royale’s **2-second** elixir increments. Other games publish immediate event-level results—hatches, catches, harvests, card rewards, loot drops, or battle results—but not a standardized number of seconds between reward signals. Where the source does not publish a seconds measure, it remains **not reported**, rather than being inferred from gameplay footage. [**scholarly**](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2016.00046/full) [**secondary**](https://www.gamedeveloper.com/design/clash-royale---deconstructing-supercell-s-next-billion-dollar-game)

**Highest-confidence takeaways from this evidence set:** short self-contained outcomes are documented at the slot, match-3, and Clash Royale scales; measurable escalation often appears as a changing threshold, time pressure, or exposed inventory value; and failure penalties range from losing a life to ending a run or risking carried gear. Roblox’s strongest available quantitative evidence here is unusually creator-specific: Tizzy’s **42-minute** reported average visit with **31%** D1 search retention, plus forum developers’ concrete onboarding funnels and churn points. These figures are source-specific and should not be generalized across genres or platforms. [**dev-primary**: Tizzy transcript](https://sozai.app/transcript/made-25070-month-roblox-game/) [**dev-primary**: Roblox forum funnel data](https://devforum.roblox.com/t/any-tips-to-improve-d1-retention-for-my-game/3123291)# Contained Continuous Gameplay Loops: Mechanical Reference Library

## Scope and evidence standard

This report isolates the **repeatable play unit contained within one sitting**—spin, hand, level, match, raid, map, farming cycle, or prestige cycle. For each case it separates:

1. **Loop duration**
2. **Within-session escalation**
3. **Stop-or-continue decision**
4. **Bad-outcome accounting**
5. **Visible feedback cadence**
6. **Published or self-reported performance data**

Source labels mean:

- **[scholarly]** — peer-reviewed research or an academic study.
- **[dev-primary]** — the actual developer, studio, or a developer reporting their own game and analytics.
- **[secondary]** — analysis by journalists, consultants, players, or YouTubers who did not make the game.

“Not reported” means the reviewed source did not publish the measurement. It is not an estimate. Where a duration follows directly from formal game rules—such as Clash Royale’s three-minute clock—it is labeled a **rules-derived duration**, not telemetry.

---

# Part I — Roblox-focused creators, studios, and developer reports

## 1. Roblox creator-source audit

The Roblox creator ecosystem is poorly indexed compared with GDC and conventional games media. Several requested creators have useful public titles and channel descriptions but no indexed transcript or searchable written breakdown from which second-by-second mechanics can be reliably quoted. The distinction below prevents video titles, thumbnails, and promotional claims from being mistaken for telemetry.

| Creator/source | Classification | Verifiable material surfaced | Reported numbers | Mechanic evidence obtainable in this pass |
|---|---|---|---:|---|
| [BruceDevs](https://www.youtube.com/@1_Bruce) | **[dev-primary]** when discussing his own games | Channel describes a Roblox developer documenting commercial results. A video title reports **23M Robux in one year from 5M visits**; another advertises the earnings of a **2,000+ CCU** game. | 23M Robux/year; 5M visits; 2K+ CCU | Titles establish scale but do not expose enough detail to attribute a particular loop mechanic or exact session cadence. |
| [Tizzy RBLX](https://www.youtube.com/channel/UCb0CbfnzYo6mLreJIXDxMtQ/about) | **[dev-primary]** for his games; **[secondary]** for other games | Videos explicitly frame Roblox game ideation and repeatable commercial launches. | Video titles claim **$44,052/month**, **$25,070/month**, and **13.1K CCU**; a separate analysis promises five traits distinguishing games with **100K+ players**. | The indexed material establishes the creator’s numerical claims but not a transcript-level mapping between those numbers and individual mechanics. [Source](https://www.youtube.com/watch?v=E_tVm3bc5Xo) [Source](https://www.youtube.com/watch?v=nggNvUILQ1I) [Source](https://www.youtube.com/watch?v=FnsIL4zPCQg) |
| [SmartyRBX](https://www.youtube.com/channel/UC7S7ohTj_2Bb8HROK1QKpAw) | Usually **[secondary]**; **[dev-primary]** for his own projects | Long-form streams include “A 2 BILLION VISIT ROBLOX DEV GIVES ME ADVICE” and public game-building sessions. | Interview subject described as developer of a 2B-visit experience; stream is approximately **9h 25m**, not a gameplay-session measurement. | Useful interview lead, but the indexed page did not expose a timestamped transcript permitting clean extraction of the guest’s mechanic claims. [Source](https://www.youtube.com/watch?v=HKmEh0aU8QI) |
| [AlvinBlox](https://www.youtube.com/c/AlvinBLOX/about) | **[dev-primary]** for his own development; otherwise instructional | More than a decade of Roblox-development experience; content is primarily scripting and production education. | No relevant retention, CCU, session, or revenue figures surfaced in the reviewed results. | No adequately supported “why this game blew up” loop postmortem was found; therefore no mechanic is attributed to him here. |
| Zurpz | Unresolved | General analytics and Roblox growth videos surfaced, but none could be confidently tied to the requested creator identity. | Not verified | No attribution made. |
| Lolzou | Unresolved | Search results did not expose a reliable dev-side channel or transcript. | Not verified | No attribution made. |
| Fireology | Unresolved | Results were dominated by unrelated fire-effect tutorials and “Fire Devz.” | Not verified | No attribution made. |

### What the verifiable creator evidence does establish

BruceDevs and Tizzy RBLX are especially valuable because their titles disclose business-scale outcome measurements uncommon in conventional design commentary: millions of visits, thousands of concurrent users, tens of millions of Robux, and five-figure monthly dollar claims. However, those titles alone cannot support claims such as “a reward every eight seconds caused 13.1K CCU.” The reliable finding is narrower: **commercially successful Roblox developers publicly treat genre selection, rapid ideation, front-page discovery, analytics, and repeatable launches as a unified production discipline**, while their published headlines emphasize CCU and revenue as the outcome variables. [BruceDevs](https://www.youtube.com/watch?v=dbNA3K8lt2w) [Tizzy RBLX](https://www.youtube.com/watch?v=8q6kdFVL_fY)

---

## 2. Roblox’s platform-defined loop and measurement framework

Roblox formally defines the core loop as the actions users repeat to progress during one session; its own pet-adoption example consists of adopting, caring for, and progressing with a pet. Its Creator Analytics system separates acquisition, engagement, retention, and monetization, including average session time, D1/D7 retention, payer conversion, ARPPU, and revenue. This matters mechanically: the platform evaluates both whether the player survives the opening minutes and whether the loop creates return behavior over subsequent days. **[dev-primary]** [Roblox Creator Documentation](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/analytics/retention.md) [Roblox Analytics](https://create.roblox.com/docs/production/analytics)

Roblox’s discovery system has used **qualified play-through rate**, seven-day playtime per user, retention, spending, and related satisfaction signals. One official announcement described seven-day playtime as capped at **60 minutes per user** for a particular recommendation signal; later discovery material divided play-through behavior into more granular measures. Consequently, the first contained Roblox loop has two practical boundaries: it must create understandable action quickly enough to avoid an early bounce, while exposing enough next-step value to carry play beyond a short qualification threshold. **[dev-primary]** [Roblox DevForum](https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators/3587441) [Roblox Discovery Documentation](https://create.roblox.com/docs/discovery)

A third-party benchmark report found that Roblox’s 2023 session distribution ranged from about **four minutes at the 25th percentile to approximately 25 minutes at the 95th percentile**, a roughly sixfold span. The same reporting describes users as returning for multiple sessions per day, meaning average daily platform time should not be confused with one contained session. **[secondary]** [GameAnalytics 2025 Roblox Benchmark Report](https://www.gameanalytics.com/reports/2025-roblox-report)

---

## 3. Developer-reported Roblox onboarding and retention experiments

Several developer self-reports give unusually concrete evidence about the first-session bottleneck:

- One shipped game was reported as stuck around **80–110 CCU**, providing a live-game context rather than a prototype critique. The discussion focused on retention and whether the experience converted an initial recommendation test into sustained concurrency. **[dev-primary]** [Roblox DevForum](https://devforum.roblox.com/t/released-new-game-but-i-need-help-with-ccu-and-retention/3787933)
- A second developer reported **10–30 CCU** for *Pong Arcade* while asking for retention feedback. **[dev-primary]** [Roblox DevForum](https://devforum.roblox.com/t/help-with-retention/3882323)
- Another reported an average session of approximately **3.0 minutes** and **2.30% D1 retention** after roughly a week and a half of sponsored acquisition. That is a clear example of a contained loop failing before it can establish repeat intent. **[dev-primary]** [Roblox DevForum](https://devforum.roblox.com/t/suggestions-to-improve-average-session-time-day-1-retention/2935525)
- A developer with a longer experience reported raising session length to approximately **20 minutes** while still experiencing weak return retention. This separates “the loop can hold a current session” from “the loop creates a reason to begin another session tomorrow.” **[dev-primary]** [Roblox DevForum](https://devforum.roblox.com/t/high-session-length-but-low-retention-rate/1752184)
- A three-month community post reported that **45% of players left within 30 seconds**. Shortening onboarding reportedly increased D1 retention from **6% to 15%** and average session length from **7.5 to 9.5 minutes**. This is a developer self-report rather than independently audited analytics, but it supplies a direct intervention-to-outcome claim: remove pre-loop delay and let the repeatable action begin sooner. **[dev-primary/self-report]** [Roblox developer report](https://www.reddit.com/r/robloxgamedev/comments/1sakqj4/i_tracked_retention_on_my_roblox_game_for_3/)

The common mechanical conclusion is that Roblox’s first “session loop” begins before the nominal game loop. The first rewardable action must be legible within seconds; otherwise players never enter the economy, collection, combat, or social loop that was designed to retain them.

---

## 4. [Adopt Me!](https://www.rolimons.com/game/920587237)

### Contained loop

**Acquire or hatch a pet → satisfy visible pet needs → receive currency/progression → customize, trade, or obtain another pet → repeat.**

The loop stacks three scales:

1. A short need-completion transaction.
2. A pet-growth and collection cycle.
3. A long collection/trading economy.

Each pet displays what it needs, so the player’s next action and expected reward are visible. Completion produces currency and advances pet development. Trading then turns accumulated progress into a player-controlled stop-or-continue decision: keep the current pet, combine or mature it, or exchange it for a more desirable collection state.

### Timing and feedback

An exact telemetry-backed pet-need interval was not published in the sources reviewed. The operative feedback unit is nevertheless smaller than a whole session: each need or task ends with visible currency/progression, while hatching and trading create larger punctuating outcomes. The complete session length was likewise not reported in the studio source.

### Escalation and bad outcomes

Escalation is primarily **value accumulation**, not session failure. A pet becomes more developed; the player’s inventory and trade options become more valuable; rare acquisition possibilities increase the prospective value of continuing. A bad outcome generally leaves the player with accumulated pets, currency, and task progress. In a trade, the visible offered items and accept state expose the decision information before commitment.

### Reported evidence

Roblox hosted a first-party panel in which Adopt Me, Brookhaven, and Paradoxum Games described experiments used to grow their experiences. The central development practice is not simply adding more rewards; it is testing changes against behavioral analytics and retaining variants that improve measurable player behavior. **[dev-primary]** [Roblox analytics and experimentation panel](https://www.youtube.com/watch?v=j6OPA95-1O0)

Rolimon’s records at least **44.87 billion plays** for Adopt Me at the time indexed. This is public tracker data, not internal retention telemetry. **[secondary]** [Rolimon’s](https://www.rolimons.com/game/920587237)

---

## 5. [Pet Simulator 99](https://www.rolimons.com/game/8737899170) / Pet Simulator X

### Contained loop

**Direct pets onto breakables → receive multiple currencies/items → open the next area or egg → hatch pets → equip stronger pets → destroy higher-value breakables faster.**

This is a tightly coupled positive-feedback economy. Every upgrade simultaneously:

- raises output per second;
- reduces the time to the next visible payout;
- unlocks a higher-value target;
- expands the rarity chase through new eggs.

The short loop is tapping or assigning pets to a target and watching health convert into coins and item drops. The medium loop is entering a new zone. The long loop is pet collection, rarity improvement, trading, and prestige-style rebirth systems.

### Escalation

The session escalates by **numerical compression followed by tier reset**. Upgrades make current targets trivial, then the next zone restores resistance and introduces a more expensive egg or currency tier. This creates a sawtooth: rapid empowerment, gate purchase, renewed friction, then another acceleration.

### Stop-or-continue information

After almost every breakable or zone purchase the player sees:

- current currency;
- next-area price;
- egg price;
- relative pet strength;
- quest/rank progress;
- time-limited bonuses or events.

The stop decision is therefore continually framed as a visible remaining distance: “one more breakable,” “one more egg,” or “one more zone.”

### Bad outcomes

A weak hatch still remains an owned pet and may contribute to combining, indexing, trading, or team filling. Failure does not normally erase prior zone access or accumulated inventory. The cost is chiefly spent currency and opportunity time.

### Cadence and performance

The immediate reward cadence can be sub-second when multiple pets generate damage and coin particles, but no official seconds-per-reward telemetry was published. BIG Games reports a **1.5 million peak CCU** for its portfolio/site presentation, while Rolimon’s records more than **2.65 billion plays** for Pet Simulator 99. BIG Games also advertises weekly developer-blog updates, indicating a live cadence layered over the internal loop. **[dev-primary]** [BIG Games](https://biggames.io/) **[secondary tracker]** [Rolimon’s](https://www.rolimons.com/game/8737899170)

---

## 6. [Blox Fruits](https://www.rolimons.com/game/2753915549)

### Contained loop

**Accept quest → defeat a repeated enemy set → receive XP and money → increase stats or acquire combat abilities → move to a stronger enemy/island → repeat.**

Combat supplies very dense feedback: individual hits, damage numbers, mastery progress, enemy health reduction, kills, quest completion, XP, currency, and level changes. The important structural feature is that one enemy kill advances several overlapping counters.

### Escalation

Escalation is **power ladder plus rarity acquisition**. Enemies gain health and damage; islands increase level requirements; bosses add longer fights and drop tables; fruit acquisition can change the player’s complete move set. The player’s accumulated power also unlocks movement into new seas and endgame systems.

### Stop-or-continue information

At quest completion the player can see:

- current level and XP;
- next level distance;
- money balance;
- nearby quest level requirements;
- mastery progress;
- available fruit or equipment objectives.

There is usually no enforced session endpoint, so quests and level-ups serve as soft exit points.

### Bad outcomes and metrics

Death typically costs position and time rather than deleting the character’s level, fruit, permanent unlocks, or inventory. The low destruction of accumulated state supports uninterrupted repetition.

Rolimon’s reported an **average playtime of 20.39 minutes** and at least **64.7 billion visits** in the indexed snapshot. A public industry post reported a later peak of approximately **2.7 million concurrent players**. Both are tracker/commentary figures rather than studio telemetry. **[secondary]** [Rolimon’s](https://www.rolimons.com/game/2753915549) [Reported CCU milestone](https://www.linkedin.com/posts/jamespurell_blox-fruits-smashes-through-to-27-million-activity-7278128387452239872-PyJ8)

---

## 7. [Fisch](https://devforum.roblox.com/t/creator-spotlight-woozynate-makes-a-splash-with-fisch/3269481)

### Contained loop

**Choose fishing location and equipment → cast → receive bite signal → execute catch interaction → reveal species, weight, rarity, and value → sell or retain → purchase rods/bait/transport → explore another location.**

Roblox’s creator spotlight explicitly identifies the broader loop as **fishing, exploring, and completing quests**, with social competition around catches. **[dev-primary/platform interview]** [Roblox Creator Spotlight](https://devforum.roblox.com/t/creator-spotlight-woozynate-makes-a-splash-with-fisch/3269481)

### Escalation

Escalation is layered across one session:

- improved rods change control and catch capability;
- bait changes probability;
- new locations expose different tables;
- weather, time, or events modify availability;
- rarer fish increase sale and collection value;
- carrying unsold catches accumulates a larger cash-out.

Unlike a battle royale, pressure does not have to rise monotonically. Escalation comes from **increasing prospective value** and expanding the rarity space.

### Decision and bad outcome

After each catch, the full result is visible: fish identity, rarity, dimensions/value, collection significance, and current equipment progression. The player may sell, continue farming the same table, or relocate. A missed fish normally costs the attempt and time; previous catches, rods, currency, and collection progress remain.

### Cadence and performance

Exact bite-to-catch duration and average session length were not published in the creator spotlight. The feedback unit is one fishing attempt, with intermediate signals at cast, bite, struggle, catch, reveal, and sale.

Rolimon’s recorded an all-time peak of **1,273,618 CCU** in October 2025. A separate growth report described an increase from approximately **2,000 CCU at launch on October 5** to large-scale front-page performance within 44 days. These are public analytics observations rather than the studio’s internal retention figures. **[secondary]** [Rolimon’s](https://www.rolimons.com/game/16732694052) [Growth report](https://www.linkedin.com/posts/jamespurell_the-fastest-growing-game-on-roblox-right-activity-7262440362147823618-umJr)

---

## 8. [Grow a Garden](https://gamesbeat.com/janzen-madsen-interview/)

### Contained loop

**Buy seed → plant → wait/grow, including offline → harvest → sell → buy higher-value seeds, plots, pets, or multipliers → display or trade results → repeat.**

The important mechanical change from a conventional farming session is **offline continuity**. A planted crop remains an unresolved future reward after the player leaves. Re-entry therefore starts with accumulated harvests rather than a cold start.

### Escalation

Within a session, escalation follows a compounding production curve:

1. Initial seeds create low-value output.
2. Harvest proceeds fund more seeds and plot capacity.
3. Rarer seeds produce larger nominal values.
4. Mutations, size variation, weather, pets, and limited events multiply potential value.
5. The player accumulates a garden with increasing visual and economic density.

This is not just linear income. Multipliers combine with rare base items, producing occasional discontinuous jumps.

### Stop-or-continue decision

The player can stop after planting because the system preserves future growth, or continue to optimize by:

- checking stock rotations;
- harvesting mature plants;
- reinvesting cash;
- waiting for weather or event transformations;
- comparing unusually large or mutated produce.

Visible growth states and shop stock communicate what is currently unresolved.

### Bad outcome

A low-value seed or ordinary crop still produces saleable output. Existing plots, crops, pets, currency, and upgrades persist. The loss is comparative—an ordinary result instead of a rare mutation—rather than a total session wipe.

### Cadence and performance

The action cadence ranges from seconds for planting and harvesting to longer offline timers. No creator source in the reviewed set gave a single average-session figure.

Creator Janzen “Jandel” Madsen reported that Grow a Garden reached **60 million players and 30 billion plays within a few months**. Public reporting recorded **21.3 million concurrent users on June 21, 2025**, followed by nearly **22 million** in July. **[dev-primary interview]** [GamesBeat](https://gamesbeat.com/janzen-madsen-interview/) **[secondary]** [PocketGamer.biz](https://www.pocketgamer.biz/robloxs-grow-a-garden-hits-industry-record-213m-concurrent-users-surpassing-pubg-fortnite-and-more/) [Game Developer](https://www.gamedeveloper.com/business/roblox-s-grow-a-garden-had-nearly-22-million-concurrent-users-in-july)

---

## 9. [Steal a Brainrot](https://www.rolimons.com/game/109983668079237)

### Contained loop

**Acquire an income-producing character → place it in the base → collect generated currency → buy a higher-value producer or steal one from another base → transport it through exposed space → secure it → repeat.**

The distinctive component is that economic accumulation and PvP exposure are the same system. A high-value unit is:

- a production upgrade;
- a visible collection trophy;
- a theft target;
- a transport risk;
- a reason to protect or revisit the base.

### Escalation

The curve is **stored-value escalation**. As the session proceeds, the player owns more valuable producers and becomes a more attractive target. Attempting to steal a superior unit raises both prospective gain and exposure time. The economy continuously advertises other players’ attainable value.

### Stop-or-continue decision

Decision points occur when the player:

- has enough currency to buy a producer;
- sees a stealable unit in another base;
- decides whether the transit risk is acceptable;
- secures a stolen unit;
- chooses whether to remain and protect accumulated assets.

The player can inspect the target’s rarity/value, route, defenders, and base state before committing.

### Bad outcome

A failed theft loses the carried target and time; previously secured producers and much of the persistent economy remain. Conversely, a defensive failure can remove a valuable producer, making this one of the sharper loss states among mass-market Roblox loops.

### Cadence and performance

Base income supplies repeated visible currency feedback, while purchases and thefts are larger punctuation events. The reviewed sources did not publish a verified seconds-per-income-tick or average session duration.

Rolimon’s reports an all-time peak of **25,836,222 CCU on October 11, 2025**. Contemporary trade reporting separately documented the game becoming the first Roblox experience to surpass **25 million concurrent users**. **[secondary tracker]** [Rolimon’s](https://www.rolimons.com/game/109983668079237) [PocketGamer.biz](https://www.pocketgamer.biz/robloxs-steal-a-brainrot-becomes-first-game-to-surpass-25m-concurrent-players/)

---

## 10. Roblox loop pattern summary

Across the most successful Roblox examples, the contained loop generally does **not** end in a hard reset. Instead it converts play into persistent inventory, economic throughput, collection completeness, or social status.

| Loop archetype | Smallest reward unit | Escalation mechanism | Exit point | Typical bad outcome |
|---|---:|---|---|---|
| Pet care/trading | One need/task | Pet maturity and trade value | Need completion, hatch, trade | Time or unfavorable trade; collection persists |
| Pet simulator | Breakable or drop burst | Exponential damage and area gates | Zone unlock, egg batch | Low-rarity hatch; pet remains useful |
| Roblox RPG | Hit, kill, quest | Level/mastery/island ladder | Quest or level completion | Position/time loss |
| Fishing RNG | Fishing attempt | Equipment, tables, rare catches | Catch reveal or sale | Missed catch; previous haul remains |
| Offline farming | Plant/harvest | Compounding plot and rarity multipliers | Plant before leaving, shop rotation | Ordinary yield rather than rare yield |
| Social theft | Income tick/theft attempt | Increasing stored and exposed value | Successful secure or failed theft | Carried target or owned producer can be lost |

The strongest shared architecture is **nested persistence**: even if the smallest attempt fails, one or more surrounding meters usually advance or remain intact.

---

# Part II — Casino and slot-machine loops

## [Electronic gaming machines](https://pmc.ncbi.nlm.nih.gov/articles/PMC7882578)

### Contained loop

**Stake → initiate spin → anticipation → audiovisual outcome → balance update → immediately restake.**

The loop’s critical property is event frequency. Experimental literature uses an example of **10 spins per minute**, or one resolved event every **six seconds**. Some experimental manipulations compare even shorter intervals such as **1.5, 3, and 6 seconds**. **[scholarly]** [Harris et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC7882578/)

### Escalation and decision

Escalation occurs through stake size, multiline coverage, accumulated balance change, bonus meters, and progressive-jackpot state. The stop-or-continue decision appears after every spin with balance, win amount, paytable, stake, and bonus state visible.

### Bad outcome

A conventional loss removes the stake. Multiline machines can also produce a **loss disguised as a win**: the machine returns less than the total wager but presents celebratory audio and animation. Laboratory work found these events more arousing than ordinary losses and capable of causing players to overestimate the number of genuine wins. **[scholarly]** [PubMed](https://pubmed.ncbi.nlm.nih.gov/20712818/) [Systematic review](https://link.springer.com/article/10.1007/s10899-017-9688-0)

### Reinforcement geometry

Valuable outcomes operate on an unpredictable or variable-ratio schedule. Near misses preserve high salience despite yielding no payout; reviews find that their effect on persistence varies by task and player, but they reliably produce strong subjective or physiological responses. Following wins, players exhibit a measurable **post-reinforcement pause** before beginning the next spin, making reward consumption itself part of the timing design. **[scholarly]** [Near-miss review](https://link.springer.com/article/10.1007/s10899-019-09891-8) [Post-reinforcement pauses](https://pubmed.ncbi.nlm.nih.gov/38429228/)

**Reference parameters:** approximately **1.5–6 seconds per outcome** in experimental fast-play conditions; stop/continue after every outcome; complete stake loss on ordinary failure; partial return can be presented as a rewarding event.

---

# Part III — Mobile gacha

## [Gacha and loot-box reward loops](https://pmc.ncbi.nlm.nih.gov/articles/PMC7882574/)

### Contained loop

**Earn or purchase pull currency → inspect banner and pity state → pull → rarity reveal → convert result into roster power, duplicates, or upgrade material → continue toward the target or stop.**

The reveal is multi-stage: activation, anticipation animation, rarity color, identity reveal, and duplicate conversion. Every pull therefore has a visible result even when it misses the featured target.

### Escalation

The within-banner escalation curve is generated by **pity accumulation**. Each unsuccessful pull raises the player’s sunk progress toward a guaranteed high-rarity result. In Genshin Impact’s character banner, community-documented hard pity is **90 pulls**, with player analysis placing “soft pity” from approximately pull **74**. A first high-rarity result may also resolve a featured/non-featured branch, meaning the player can leave with a five-star while still not receiving the advertised target. **[secondary]** [HoYoLAB community guide](https://www.hoyolab.com/article/23221584) [Five-minute system breakdown](https://www.youtube.com/watch?v=hdeC24S7rgI)

### Decision information

At each pull or ten-pull bundle, the player can inspect:

- currency remaining;
- banner time remaining;
- published rarity rules;
- pull-history or inferred pity count;
- whether the next high-rarity result is guaranteed to be featured;
- current duplicate/upgrade value.

### Bad outcome

A non-target pull usually remains as a character, weapon, duplicate currency, or upgrade material, while pity often persists within the banner category. Thus a miss can preserve both **item value** and **guarantee progress**. Research on loot boxes confirms that rare rewards produce greater physiological arousal than common rewards and that the reward structure is variable-ratio. **[scholarly]** [Larche et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC7882574/)

### Session structure

The gacha pull itself is seconds long, but the containing mobile session frequently couples it to a roughly **first-ten-minutes daily quest/reward window**, according to temporal-structure research on gacha participation. No dependable cross-title average session duration was identified; the relevant architecture is several brief resource tasks feeding a much shorter reveal loop. **[scholarly]** [DiGRA](https://dl.digra.org/index.php/dl/article/download/2743/2729/2789)

---

# Part IV — Match-3

## [Candy Crush-style match-3](https://www.gameanalytics.com/blog/how-to-crack-the-match-3-code-part-1)

### Contained loop

**Inspect board → make a swap → immediate clear/cascade → advance objective counter → spend another move → win or exhaust moves → spend/recover life → enter next level.**

Industry analysis places a typical match-3 session or level attempt at approximately **2–4 minutes**. **[secondary]** [GameAnalytics](https://www.gameanalytics.com/blog/how-to-crack-the-match-3-code-part-1)

### Escalation

The tension curve is produced by depletion:

- moves remaining fall;
- objective remainder becomes more specific;
- blocked areas constrain future options;
- cascades may open or damage the board;
- the relative value of each remaining move rises.

Unlike RPG power curves, the player normally becomes **more constrained** as the attempt continues.

### Decision point

The critical stop-or-continue decision arrives when moves are exhausted. Visible information includes remaining objective, board state, offered extra moves or boosters, life balance, and progress already invested in the level.

### Bad outcome

The player loses a life and the current board state, but keeps completed levels, currency, owned boosters, and map progression. This makes a failed 2–4-minute attempt meaningful without erasing the longer campaign.

### Feedback cadence

Every move produces board motion, sound, score changes, obstacle damage, or a no-match correction. The cadence is normally one signal every few seconds, with cascades producing multiple sub-rewards from a single input.

---

# Part V — Social/casual mobile

## [Clash Royale](https://www.gamedeveloper.com/design/clash-royale---deconstructing-supercell-s-next-billion-dollar-game)

### Contained loop

**Queue → fight a three-minute real-time match → possibly enter overtime → gain or lose trophies → receive chest/reward progress → adjust deck → queue again.**

The original widely analyzed format used **three minutes plus up to one minute of overtime**, giving a rules-derived run length of **3–4 minutes**. Later modes have used five-minute structures and final-minute triple-elixir pacing, but the historically influential loop is the compact 3+1 format. **[secondary]** [Game Developer](https://www.gamedeveloper.com/design/clash-royale---deconstructing-supercells-next-billion-dollar-game)

### Escalation

Elixir generation and the clock create a temporal escalation. Tower damage becomes persistent positional information; the final phase increases resource throughput; overtime converts a symmetric board into sudden-death pressure. Each deployment has immediate battlefield feedback, while tower destruction is the larger milestone.

### Stop-or-continue information

After every match the player sees trophies, chest slots, deck state, card-upgrade progress, quests/events, and time remaining on chest unlocks. These present multiple “almost complete” distances before the requeue decision.

### Bad outcome

A loss costs trophies or event progress but does not consume the deck or card upgrades. The attempt resets completely while the collection remains.

---

## [Coin Master](https://www.gameanalytics.com/blog/coin-master-social-casino)

### Contained loop

**Spin → receive coins, attack, raid, shield, or energy → spend coins on village upgrades → complete village → move to a more expensive village → regenerate spins → return.**

GameAnalytics describes spins as the driver of all core-loop engagement and reports **five free spins every 50 minutes**. **[secondary]** [GameAnalytics](https://www.gameanalytics.com/blog/coin-master-social-casino)

### Escalation and decision

Each spin is a short slot-like resolution. Across the session, the coin balance approaches an upgrade threshold while unspent coins remain exposed to raids. The player decides whether to bank value by buying a village component, continue spinning for a larger balance, or stop and wait for regenerated spins.

### Bad outcome

A low-value spin still resolves immediately. Raids may remove exposed coins, but purchased village pieces and completed villages persist. Shields convert some incoming attacks into visible consumed protection rather than permanent progress loss.

### Cadence

The reward cadence is one spin every few seconds until energy is exhausted. The 50-minute regeneration interval then turns the stopped session into a scheduled return opportunity.

---

# Part VI — Battle royale

## [PUBG and the shrinking-zone loop](https://pubg.com/en-asia/news/10280?category=dev_notes)

### Contained loop

**Drop with minimal equipment → loot → move toward safety → survive encounters → inherit better equipment and positional information → face a smaller zone and fewer opponents → final elimination or victory.**

PUBG’s developer documentation explicitly identifies the Blue Zone as the system shaping the pace and flow of every match. Its structure makes safe zones smaller and, in traditional configurations, shortens shrink periods as the match progresses. **[dev-primary]** [PUBG Dev Letter](https://pubg.com/en-asia/news/10280?category=dev_notes)

### Escalation

Battle royale uses a convergent pressure curve:

- play space contracts;
- traversal options diminish;
- damage outside the zone increases or becomes less tolerable;
- surviving opponents are increasingly equipped;
- every elimination raises the player’s placement value;
- accumulated loot makes death more costly in terms of foregone win probability, despite no cross-match item loss.

### Decision point

The player repeatedly decides whether to:

- fight for visible loot;
- move early for position;
- remain outside safety briefly;
- reveal position by shooting;
- loot a defeated player;
- disengage and protect placement.

The player sees zone timing, map geometry, inventory, health, remaining-player count, and often the direction of nearby combat.

### Bad outcome and feedback

Death ends the run and discards all match-acquired equipment. Account XP, quest progression, cosmetic progression, and ranking effects persist. Feedback occurs at several rates: movement and looting every few seconds; shots/hits instantly; kills at irregular intervals; zone transitions every few minutes; placement after elimination.

---

# Part VII — MOBA and hero-shooter loops

## MOBA structure

**Lane or clear camps → gain gold/XP → purchase power → contest objective → destroy structures → compress access to the enemy base.**

The escalation curve is multiplicative: resources buy combat power, combat power raises access to future resources, and structural victories reduce the opponent’s safe map. A kill therefore has immediate value and changes subsequent acquisition capacity.

The stop-or-continue points are tactical rather than session exits: continue a fight, chase, return to buy, contest an objective, or convert a kill into a tower. Visible information includes health, cooldowns, death timers, gold, objective timers, map vision, and structure state.

A bad fight costs time, position, bounty, and possibly an objective, but the player retains levels, completed items, and prior structural gains until the match ends. Feedback cadence ranges from sub-second damage and resource ticks to wave-level income every few dozen seconds and objective-level rewards every few minutes.

Riot has publicly discussed match duration, snowballing, durability, and role balance as interdependent systems: shortening or lengthening the game requires adjusting how quickly early advantages become decisive. **[dev-primary]** [League of Legends development update](https://www.youtube.com/watch?v=9j9pjdHm6M8)

## Hero-shooter structure

Hero shooters compress the MOBA economy into ability-charge and objective cycles:

**take space → deal/heal damage → charge high-impact abilities → spend them to win a fight → move objective → repeat.**

Escalation comes from shrinking objective time, ultimates becoming available, respawn travel, and the need to win the next fight before the clock expires. A team can lose an engagement yet retain partial ultimate charge and accumulated objective progress. The feedback cadence is extremely dense: hit markers, health movement, elimination signals, ability readiness, objective percentage, and match-clock updates.

Exact cross-title match lengths were not consistently published in the primary sources reviewed, so no universal duration is asserted here.

---

# Part VIII — Deckbuilding roguelikes

## [Slay the Spire](https://www.youtube.com/watch?v=7rqfbvnO_H0)

### Contained loop

**Choose map node → fight with a drawn hand and visible enemy intentions → receive card/relic/gold reward → alter deck → choose next node → defeat act boss or die.**

A developer interview described internal work around playing through a complete game in approximately **90 minutes**, providing a reasonable primary-context run scale rather than a speedrun estimate. **[dev-primary]** [Casey Yano interview](https://justingarydesign.substack.com/p/casey-yano-designing-with-detail)

### Escalation

The game increases risk and value simultaneously:

- enemies gain stronger behavior sets;
- elites offer relics but cost more health;
- cards accumulate, increasing both potential synergies and deck dilution;
- relic combinations create nonlinear power;
- path decisions become constrained near the act boss;
- ascension modifiers progressively sharpen the whole run.

### Stop-or-continue decisions

The important decisions are explicit and information-rich:

- choose among visible map branches;
- fight an elite or take a safer route;
- add a card or skip it;
- spend gold now or save for a later shop;
- rest or upgrade;
- retain a potion or spend it to preserve health.

Enemy intent is visible, so risk is often calculable rather than hidden.

### Bad outcome

Death erases the run’s deck, relics, gold, and route. The player retains character unlocks, ascension progression, and knowledge. During a successful battle with a poor reward, “skip” protects deck quality, making rejection itself a valuable action.

### Feedback cadence and data

Every card provides immediate block, damage, energy, draw, status, or enemy-state feedback. A combat resolves over minutes, nodes over several minutes, acts over tens of minutes, and a full run around the cited 90-minute scale.

Mega Crit’s GDC talk describes balancing from large-scale metrics rather than relying only on designer intuition, including card-pick and win-rate data. **[dev-primary]** [GDC Vault](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics)

---

## [Balatro](https://rogueliker.com/balatro-interview/)

### Contained loop

**Inspect hand → discard or play a poker hand → score chips × multiplier → meet the blind → shop for Jokers/cards/vouchers → face a higher blind → repeat.**

### Escalation

The mechanical curve is unusually clean:

- required blind score rises;
- Ante progression increases the baseline target;
- Jokers add additive, multiplicative, conditional, or economic scaling;
- deck manipulation increases the consistency of desired hands;
- Boss Blinds impose rule changes;
- accumulated economy makes rerolls and shops more valuable.

The player is not merely trying to score more. They are building a score-generating machine whose growth rate must stay above the blind curve.

### Stop-or-continue decision

Within a blind, every hand creates a decision among playing, discarding, conserving limited hands, or preserving cards for a stronger combination. Between blinds, the player sees current money, interest thresholds, shop inventory, Joker slots, hand levels, and the next blind’s required score and modifier.

### Bad outcome

Failing to reach the blind’s score ends the run and removes the constructed deck/Joker engine. Collection discoveries and unlocks remain. A weak shop result costs opportunity but can be mitigated by saving money, rerolling, or skipping.

### Feedback cadence

Each played hand produces an escalating score sequence in which card effects and Jokers resolve one after another. That sequencing turns one input into multiple visible sub-rewards. LocalThunk has explained that the prototype drew from *Big Two* and *Luck Be a Landlord*, emphasizing systemic combinations rather than narrative progression. The reviewed interviews did not publish a reliable average run length. **[dev-primary]** [LocalThunk interview](https://rogueliker.com/balatro-interview/) [LocalThunk conversation](https://www.youtube.com/watch?v=b8CyE1svP2k)

---

# Part IX — Extraction shooters

## [Escape from Tarkov](https://www.youtube.com/watch?v=Vcz6ZpJeqtI)

### Contained loop

**Choose carried equipment → enter raid → loot and complete tasks → accumulate increasingly valuable carried inventory → decide whether to seek more value or extract → survive or lose unsecured equipment.**

### Escalation

Tarkov’s stakes rise because every acquired item increases the value currently exposed to death. Time also changes map occupancy and extraction feasibility. The player’s remaining ammunition, health, hydration, task items, and route risk become more consequential as the raid progresses.

### Stop-or-continue information

At almost any point the player can evaluate:

- carried loot;
- quest completion;
- health and limb state;
- ammunition and medicine;
- raid clock;
- available extracts;
- audible combat;
- the value of insured versus uninsured equipment.

Secure containers create a second accounting layer: certain items can remain protected even if the raid ends badly.

### Bad outcome

Death normally loses carried weapons, armor, and unsecured loot. Items in the secure container remain; insured gear may return if no other player extracts it. Successful extraction converts temporary raid inventory into persistent stash value.

A commonly documented rule requires at least **seven elapsed minutes** or sufficient XP to avoid a “run-through” result, creating a formal minimum-effort gate before a low-contact extraction is fully credited. **[secondary/community rules documentation]** [Tarkov run-through explanation](https://www.reddit.com/r/EscapefromTarkov/comments/qs9cjc/a_complete_explanation_of_the_run_through/)

Battlestate’s founder and game director Nikita Buyanov describes Tarkov’s inspirations and extraction structure in a primary interview, but the surfaced material did not provide a single universal raid duration; map timers vary. **[dev-primary]** [Game Maker’s Notebook interview](https://www.youtube.com/watch?v=Vcz6ZpJeqtI)

---

## Hunt: Showdown

### Contained loop

**Enter with a persistent hunter and equipment → investigate clues → locate/kill boss → initiate a visible banish timer → collect bounty → cross an exposed map to extraction → survive interception.**

### Escalation

Every phase broadcasts more information:

- clues narrow the boss location;
- gunfire reveals approximate position;
- killing the boss focuses opponents;
- banishing identifies the compound;
- carrying the bounty provides information but marks the team as the primary target;
- extraction creates a final defend-or-escape interval.

### Stop-or-continue decision

A team may leave without a bounty, contest a boss, steal a bounty, hunt another team, pursue a second boss, or extract with current gains. Visible information includes health chunks, ammunition, consumables, boss/banish state, bounty position, extraction locations, and remaining match time.

### Bad outcome and duration

Death can remove the hunter and equipped loadout, while account-level currency, unlocks, and roster assets persist. A successful extraction preserves hunter progression and equipment.

Update 1.9 reduced the match cap to **45 minutes**; community reporting noted that bosses were often killed and banished within approximately **5–7 minutes**, leaving a substantial player-created confrontation and extraction window. The 45-minute cap is rules data, while the 5–7-minute figure is informal player observation. **[secondary]** [Hunt discussion](https://www.reddit.com/r/HuntShowdown/comments/vbfxpd/new_match_time_limit_45_minutes_update_19/)

---

# Part X — Looter ARPGs and looter shooters

## Diablo

### Contained loop

**Kill dense enemy pack → receive immediate item/currency burst → inspect rarity and affixes → equip, salvage, or retain → increase clear speed → enter higher difficulty or repeat activity.**

Diablo’s original designers have explicitly compared killing monsters for randomized loot to **pulling a slot-machine lever**. David Brevik and the Schaefer brothers identify variable randomized treasure as a foundational source of repeatability. **[dev-primary via interview reporting]** [Diablo loot interview](https://www.thegamer.com/diablo-2-loot-interview/) [Brevik report](https://www.tweaktown.com/news/74666/diablos-loot-lottery-rng-is-like-slot-machine-says-david-brevik/index.html)

### Escalation

The escalation curve combines:

- increasing enemy density and difficulty;
- growing kill speed;
- more frequent loot events;
- rarer affix combinations;
- difficulty tiers that raise both danger and reward;
- build thresholds that create sudden power jumps.

This creates alternating plateaus and breakpoints: most drops are filtered or salvaged, but one affix combination may substantially change the build.

### Decision and failure

Players repeatedly decide whether to inspect, equip, salvage, reroll, or continue farming. On death, modern Diablo modes usually preserve inventory and progression while imposing time, durability, or activity penalties; hardcore modes destroy the character’s run state.

Diablo III’s Loot 2.0 redesign increased relevant drops and oriented itemization toward the current class, restoring direct monster-kill-to-upgrade causality after the auction-house economy had weakened it. **[dev-primary]** [Loot 2.0 presentation](https://www.youtube.com/watch?v=rYbt27bRMqs) [Diablo III GDC postmortem](https://www.youtube.com/watch?v=vWYEWRrFgUY)

## Path of Exile

### Contained map loop

**Invest a map and modifiers → enter a limited-instance area → clear enemies and league encounters → collect currency/items/maps → defeat boss → use output to craft or invest in a harder map.**

The risk curve begins before entry: map modifiers can be rolled for quantity and rarity while simultaneously increasing monster damage, defenses, or mechanical constraints. The player chooses the difficulty/reward package and may spend additional resources to amplify it.

A bad result can consume the map and entry investment; items already removed through portals persist, while death consumes one of the map’s limited portals. The remaining-portal count makes failure visibly finite. Exact cross-league map duration was not published in the reviewed primary material; build power and map layout create substantial variance.

## Destiny-style looter shooter

The contained loop substitutes an authored mission or activity for an ARPG map:

**complete encounter → receive weapon/armor roll → compare power and perks → dismantle or equip → repeat for target roll or weekly threshold.**

The key difference from Diablo is longer time between major loot resolutions and more explicit deterministic overlays—quests, reputation, guaranteed weekly rewards, and crafting. Secondary design analysis notes that Destiny combines random drops with fixed reward schedules, preventing the loop from depending on one reward schedule alone. **[secondary]** [Game Developer](https://www.gamedeveloper.com/design/psychology-and-destiny-s-loot-system)

---

# Part XI — Clicker and incremental games

## [Cookie Clicker](https://www.gamedeveloper.com/design/the-recipe-behind-cookie-clicker)

### Contained loop

**Click → number rises immediately → buy generator → number rises automatically → purchase multiplier or new production tier → wait for threshold → repeat or prestige.**

The smallest loop can resolve every fraction of a second. The larger loop continually lengthens because the next threshold costs exponentially more, while automation keeps producing during inaction.

### Escalation

Incremental escalation is primarily **rate escalation**:

- manual output becomes automated;
- automation buys more automation;
- multipliers compound;
- new systems appear at numerical milestones;
- prestige converts the current economy into a permanent multiplier and restarts the visible numbers.

This produces repeated compression: a formerly large target becomes trivial, then a newly exposed target restores distance.

### Stop-or-continue decision

The player continually sees:

- current currency;
- currency per second;
- exact upgrade price;
- production increase;
- time-to-afford implied by those figures;
- temporary events such as Golden Cookies.

Every purchase creates another visible horizon.

### Bad outcome

There is usually no conventional failure. A suboptimal purchase delays the next threshold but increases production. Prestige sacrifices current-scale assets while retaining a permanent meta multiplier.

### Designer and research evidence

Game Developer’s analysis describes Cookie Clicker as difficult to step away from despite the minimal input, crediting the rising counter, layered upgrades, discoveries, and automated continuation. **[secondary]** [Game Developer](https://www.gamedeveloper.com/design/the-recipe-behind-cookie-clicker)

A CHI paper interviewed designers of six popular idle games and found that idle-game design is not simply “no interaction”: designers deliberately place games along an interactivity spectrum, introduce discovery in layers, and manage alternation between attention and absence. **[scholarly]** [ACM](https://dl.acm.org/doi/10.1145/3311350.3347180) [Open paper](https://par.nsf.gov/servlets/purl/10174274)

---

# Part XII — Cross-genre mechanical synthesis

## 1. Session-length bands

| Band | Shipped examples | Mechanical function |
|---:|---|---|
| **1.5–6 seconds** | Fast EGM/slot outcomes | Complete wager–result–restake loop; maximum outcome density |
| **2–4 minutes** | Match-3 level; original Clash Royale match before/with short overtime | One complete, discardable attempt with immediate restart |
| **7–10 minutes** | Improved Roblox onboarding case; short gacha daily task cluster | Enough time for one economy or progression arc without a long commitment |
| **~20 minutes** | Blox Fruits public average; successful Roblox session target in DevForum report | Several nested loops: quests, upgrades, travel, social exposure |
| **45 minutes maximum** | Hunt: Showdown match cap | Long accumulation followed by concentrated extraction risk |
| **~90 minutes** | Slay the Spire complete-run development context | Full build construction, escalation, and destructive resolution |

The central distinction is not simply “short versus long.” Successful long sessions contain smaller finished units. A 90-minute deckbuilding run still resolves a hand in seconds, a combat in minutes, a node immediately afterward, and an act after several nodes.

---

## 2. Reusable escalation-curve shapes

### A. Depleting runway

**Moves/time/resources decrease while objective distance remains visible.**

Used by match-3, card hands, mission timers, and limited portals. Every remaining unit becomes more valuable as the run progresses.

### B. Convergent pressure

**Playable space and safe choices contract.**

Used by battle royale circles, MOBA base compression, bounty convergence, and extraction timers.

### C. Exposed-value accumulation

**The player carries or owns increasingly valuable state that can still be lost.**

Used by Tarkov loot, Hunt bounties, Steal a Brainrot producers, and unbanked social-casino currency.

### D. Compounding throughput

**Current rewards purchase higher future reward rate.**

Used by Cookie Clicker, Pet Simulator, Grow a Garden, ARPG clear-speed builds, and village builders.

### E. Requirement outruns engine

**The target rises geometrically and the player must build a faster-growing machine.**

Used by Balatro blinds, high-tier ARPG maps, ascension systems, and endless incremental modes.

### F. Guarantee accumulation

**Failures advance a visible or inferable counter toward a forced success.**

Used by gacha pity, collection shards, quest bars, chest tracks, and guaranteed upgrade systems.

### G. Sawtooth mastery

**The player dominates a tier, unlocks the next, and temporarily returns to friction.**

Used by Roblox simulators, RPG islands, Diablo difficulties, PoE map tiers, and prestige cycles.

---

## 3. Stop-or-continue decision templates

The most mechanically productive decision points occur after an outcome has been consumed but before its value is fully secured:

| Decision | Visible information | Exemplars |
|---|---|---|
| **Restake immediately** | Balance, last outcome, stake, bonus state | Slots |
| **Spend to rescue attempt** | Remaining objective, board state, extra moves | Match-3 |
| **Requeue** | Rank/trophy change, reward slots, quests | Clash Royale |
| **Cash out or carry more** | Inventory value, health, time, route | Tarkov |
| **Take bounty or leave** | Boss/banish state, ammo, enemy signals | Hunt |
| **Fight elite or preserve health** | Map path, HP, reward type | Slay the Spire |
| **Buy now or preserve interest** | Shop inventory, money threshold, next target | Balatro |
| **Harvest now or leave production running** | Growth state, shop stock, modifiers | Grow a Garden |
| **Secure current producer or attempt theft** | Target value, defenders, route | Steal a Brainrot |
| **Prestige or continue compounding** | Reset reward, current production, next unlock | Incremental games |

A strong decision point exposes at least three quantities: **current secured value, prospective additional value, and value at risk**.

---

## 4. Feedback-cadence bands

| Cadence | Appropriate signal |
|---:|---|
| **Below 1 second** | Damage ticks, currency increments, multiplier counting, particles |
| **1–6 seconds** | Slot spin, clicker purchase, card play, Roblox breakable burst, combat exchange |
| **10–45 seconds** | Enemy kill, fishing attempt, pet task, lane wave, small objective |
| **2–4 minutes** | Match-3 level, Clash Royale match, boss phase, quest cluster |
| **5–15 minutes** | Zone transition, map completion, extraction decision, gacha daily block |
| **20–90 minutes** | Full RPG session, extraction match, roguelike run |

Dense visual feedback does not require valuable rewards at the same rate. Many successful loops give **frequent state confirmation**—damage, particles, meter movement—while reserving build-changing rewards for longer intervals.

---

## 5. Failure-penalty tuning patterns

### Soft failure: attempt resets, metagame survives

Used by match-3, Clash Royale, most Roblox RPGs, and standard ARPG modes. Best suited to attempts lasting roughly two to several minutes.

### Residual-value failure: weak result still becomes material

Used by gacha duplicates, low-rarity pets, ordinary crops, salvageable ARPG loot, and incremental purchases. The outcome is below target but not mechanically null.

### Protected-pocket failure

Used by Tarkov secure containers, account progression, insurance, and partial quest credit. The session can fail sharply while a selected subset survives.

### Exposed-value failure

Used by extraction shooters and social-theft games. The player can choose how much accumulated value to expose and when to secure it.

### Full run destruction with permanent knowledge/unlocks

Used by Slay the Spire, Balatro, hardcore ARPG modes, and battle royale. This works because the run itself is a distinct authored object and restart friction is low.

### Voluntary reset for permanent acceleration

Used by incremental prestige and rebirth systems. Apparent loss is transformed into a player-selected conversion from current scale to future rate.

---

## 6. General-purpose numerical reference set

The following numbers are the most defensible cross-genre anchors from the reviewed material:

- **Outcome cadence:** approximately **1.5–6 seconds** for a complete high-frequency chance event.
- **Compact attempt:** **2–4 minutes** for a complete match-3 level or original Clash Royale battle.
- **Roblox opening danger window:** as much as **45% churn within the first 30 seconds** in one developer self-report.
- **Roblox session improvement case:** **7.5 → 9.5 minutes** after shorter onboarding; D1 **6% → 15%**.
- **Weak Roblox case:** approximately **3.0-minute average session** and **2.30% D1 retention**.
- **Roblox public session distribution:** roughly **4 minutes at the 25th percentile** and **25 minutes at the 95th percentile** in the cited benchmark.
- **Persistent Roblox RPG example:** **20.39-minute average playtime** for Blox Fruits in Rolimon’s indexed snapshot.
- **Extraction threshold:** **seven minutes or sufficient XP** to avoid Tarkov’s run-through classification.
- **Extraction cap:** **45 minutes** for Hunt: Showdown’s cited ruleset.
- **Deckbuilding full-run scale:** approximately **90 minutes** in the cited Slay the Spire development context.
- **Regeneration return timer:** Coin Master’s cited **five free spins every 50 minutes**.
- **Guarantee horizon:** Genshin character-banner hard pity at **90 pulls**, with community-observed acceleration around pull **74**.
- **Mass-scale Roblox outcomes:** Pet Simulator’s **1.5M peak CCU**, Fisch’s tracked **1.27M peak**, Blox Fruits’ reported **2.7M peak**, Grow a Garden’s roughly **21.3–22M peak**, and Steal a Brainrot’s tracked **25.84M peak**.

---

# Final mechanical model

Across genres, the most repeated contained-loop architecture is:

> **Legible action → immediate state response → uncertain or variable result → retained progress → newly visible near-term target → higher-value or higher-risk continuation offer.**

The loop becomes continuous when five layers align:

1. **The next input is available immediately.**
2. **Some visible state changes every few seconds.**
3. **A complete sub-goal resolves within minutes.**
4. **Failure leaves a reason or resource for another attempt.**
5. **Continuation increases either prospective value, exposed value, constraint, or guarantee progress.**

The major genre differences are therefore not whether a loop provides rewards, but **what becomes more consequential over time**:

- Slots escalate **stake exposure and unresolved chance**.
- Gacha escalates **guarantee proximity**.
- Match-3 escalates **scarcity of remaining moves**.
- MOBAs escalate **economic and territorial advantage**.
- Battle royale escalates **placement value and spatial compression**.
- Incremental games escalate **production rate and threshold magnitude**.
- Deckbuilding roguelikes escalate **engine complexity against rising requirements**.
- Extraction shooters escalate **carried value at risk**.
- Looter games escalate **clear speed and rarity search space**.
- Roblox simulators escalate **persistent throughput, collection value, social comparison, and visible next-price distance**.

The most broadly portable structure is not a particular reward type. It is the combination of **fast confirmation, medium-length completion, persistent residue, and a continuation decision whose value and risk are both visible**.
