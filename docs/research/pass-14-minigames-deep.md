# Pass 14: Minigame design research (external deep-research AI, pasted verbatim)

Source: pasted by owner from a deep-research AI run of `prompt-minigame-research.md`. Evidence labels: dev-primary = developer posts/official docs/dev talks; scholarly = peer-reviewed; secondary = wikis, forums, trackers, press.

## Summary

Several requested numbers were never published. No published figure found for: immediate replay rate, mid-run quit rate, studio target clear rates, skill spread top vs bottom players, runs per session, share of players reaching area 2 or 3. Best substitutes:
- Lab data on cash-out behavior. In balloon-pumping studies, people stop at about 26-35 pumps when 64 earns the most (impulsivity.org/measurement/bart).
- Near-miss data. 19% near-miss outcomes instead of 2% raised trials played from 87 to 107 (Broussard et al. 2023, GREO).
- King's GDC lesson. Very hard levels raise purchases short term but lose players over time (mobilegamer.biz).
- Roblox ranking signals. Home recommendation rewards days played per week, playtime (counted up to 60 min/day), and playing with friends (Roblox DevForum).

Not sourced: Stardew Valley, WarioWare, Crossy Road, Subway Surfers, Mario Party, Vlambeer and "Juice it or lose it" talks.

---

## A. Games to study

**1. Fisch (Roblox)**
- Verb: hold mouse/tap to push a white bar right, release to drift left; keep fish icon inside bar (Fischipedia, secondary).
- Run: inputs locked first 1.2 s or until progress 20%. Progress goes up/down 12% per second depending on fish inside bar. Fastest catch 6.8 s of reeling, 8 s from animation start.
- Failure: catch lost when progress hits zero. Stats count "Reels snapped."
- Mastery: perfect catch (no progress lost) pays 10 C$ and 50% more XP. Pre-reel "Shake" button that jumps around cuts 0.5-1.5 s per press.
- Rod stats: Control widens bar (30% of track default). Resilience makes fish move less.
- Return hooks: catch streak shown above head after 10 in a row; server chat message when someone loses a streak; a 1-in-1,000 or rarer catch plants a flag showing its odds; 1-in-100,000 or rarer flag visible to whole server (cap 150 flags per server); catch sounds change with rarity. (Fischipedia)
- Numbers: ~2,000 CCU at Oct launch (LinkedIn, secondary); 13th Roblox game past 1M CCU (Reddit, secondary); on 30 Nov 2024 top by CCU, 100k+ ahead of Blox Fruits (Fischipedia).
- In-run risk choice: no number found. Only risk is snapping the line.

**2. Fish It (Roblox)**
- Seven rarity tiers Common to Secret. Secret fish can be 1 in 750k (Fish It Wiki, secondary). One Secret added in an update, Blocky Lochness Monster, 1 in 4 million (GosuGamers).
- No minigame details, run length, or retention numbers found.

**3. Grow a Garden (Roblox)**
- Verb: buy seeds, plant, harvest, sell. Crops grow while offline (Wikipedia, secondary).
- Return hooks: seeds go in/out of stock; exclusive items released weekly, must be online to claim.
- CCU peaks: 5M on 17 May, 11.7M on 31 May (Bizzy Bees), 16M on 21 June, 22.3M on 23 Aug 2025 (Wikipedia). 23 Aug record came during staged "admin war" with Steal a Brainrot developer. Passed Fortnite's 15.3M record (Game Developer).
- Average playtime 15.19 min (Rolimons, secondary). Developer declined to share revenue.

**4. Steal a Brainrot (Roblox)**
- Verb: buy characters off a conveyor belt; they earn income every few seconds. Run into other players' bases and steal theirs (capture the flag style) (Wikipedia).
- Defense: base button raises temporary shield; lock starts 60 s, +10 s per rebirth (u7buy, secondary).
- Numbers: 25,868,678 CCU on 11 Oct 2025 (Guinness World Records). Average playtime 9.75 min (Rolimons).
- Criticism: best items sold only for real money (Wikipedia).

**5. Pet Simulator 99 (Roblox)**
- 274 unlockable areas across 4 worlds and 8 sub-worlds. Rebirths at areas 25, 50, 75, 99, 125, 150, 175, 199, 219. Unlocking areas gives new eggs, upgrades, minigames, machines, boss chests (Pet Sim Wiki, secondary).
- Update 5 made pets "75% stronger, permanently" (BIG Games). Rotation gives better odds on certain huge pets every two days (Eloboost, secondary).
- No published bad-luck counter. No retention numbers.

**6. Blox Fruits (Roblox)**
- Fruit gacha pure luck. Price rises with player level; worse odds of a good fruit than natural spawns (wiki, secondary). No minigame or retention numbers.

**7. Anime Defenders (Roblox)**
- Summon rates 0.25% Mythic, 0.01% Secret (wiki). Limited banner guarantees Legendary at 50 summons, Mythic at 400 (Gamezebo). One update added 6,000-summon guarantee for Secrets (wiki).

**8. Dig It, Bee Swarm Simulator, mining sims (Roblox)**
- Beebom: for a Roblox digging game "the minigame is what you must play" to progress, tutorial teaches it. A smaller "Dig It!" showcase lists 10 terrain layers, 30 relics, 8 pickaxes (DevForum, secondary). BSS community guides set progression by bee count (42, then 45, then 50). No retention numbers.

**9. Peggle**
- Verb: aim and fire a ball into pegs.
- Reveal: when last orange peg is about to be hit, camera zooms into slow-motion close-up, drumroll, ends on Beethoven's "Ode to Joy" (CNN 2007).
- Failure softening: bucket moves along bottom; ball landing in it is free. Missing every peg gives coin flip for free ball (Peggle Wiki, secondary).
- Sound (Peggle 2): each peg hit plays next note of rising scale, up to 26 notes ~3.5 octaves (Audiogang).
- Sound (Peggle Blast): each peg hit plays a harp note, orange pegs add marimba layer; notes always in the music's scale (Audiokinetic blog).

**10. Peglin** - sold 100K+ units under two weeks of Early Access (Red Nexus postmortem video). No run or retention numbers.

**11. Balatro**
- Verb: choose cards to play/discard to beat score target.
- Targets: each ante three blinds: Small 1x base, Big 1.5x, Boss 2x. Small and Big skippable for a reward tag; Boss not (Balatro Wiki).
- Reveal: deliberately no score preview. Numbers count up with escalating sound effects, each card and Joker steps forward in turn. LocalThunk: the fun lives in the moment you hit play (Mark Brown, GMTK).
- Dev notes: LocalThunk balances "by feel", inspired by Luck Be a Landlord (Rogueliker).

**12. Luck Be a Landlord** - inspired Balatro scoring. No numbers. Core is a slot machine.

**13. Vampire Survivors**
- Verb: movement only; weapons auto-fire.
- Galante on slot design: slot games put "a huge attention to detail on the sounds, the animations, and the sequences," and he applied that. Chests stream items on ribbons of color with coins and a jingle; five-item chest adds fireworks (The Verge, 19 Feb 2022).
- Chest built from a slot-machine jingle he liked. Settled on 3-4 choices per level-up because two felt too few and more felt overwhelming (Android Police).
- Run: a "successful" run lasts 30 minutes (Howell, The Conversation, 13 Apr 2023).

**14. Brotato**
- Move while weapons auto-fire. 20 waves. Wave 1 = 20 s, each wave +5 s until 60 s from wave 9. Wave 20 = 90 s (Brotato Wiki). Shop between every wave.
- Higher difficulties: harder waves at 11-12, 14-15, 17-18, each 40% horde 60% elite, visible from the shop.

**15. Hades**
- God Mode starts 20% damage resistance, +2% per death, up to 80%. Kasavin: aim from the start was to "take the sting of failure" (Inverse, 11 Aug 2021). Players report avg 36.75 runs to first clear (Reddit, secondary).

**16. Slay the Spire 2**
- Across 240 million community runs, win rate 25%. Ascension 0 wins 16% (9% in first game). Ascension 10 (top) ~17%; first game's top A20 won 3% (Mega Crit, May 2026).

**17. Deep Rock Galactic**
- After main objective, 5 minutes to return to drop pod (wiki). Players report missions 25-40 min (Reddit, secondary).

**18. Dark and Darker** - players discuss low extraction rates (Reddit). No number found.

**19. Candy Crush**
- King GDC: Level 65 became highest-converting and highest-revenue level and also most churn; originally meant to be last level. A/B test making it easier lowered conversions but kept players longer (mobilegamer.biz, Mar 2024).
- Lives: store up to 200, accept only 20 per day (King support).

**20. Stardew Valley fishing/mining, WarioWare, Crossy Road, Subway Surfers** - no source retrieved.

---

## B. Numbers

1. Replay rate: no number found.
2. Mid-run quit rate: no number found. King measures "time to abandon" and "time to pass" per level; rule: a really hard level should also be really short; fixed its 100 least-fun levels for "a very significant uplift in engagement", no figures (mobilegamer.biz). Closest Roblox data: one dev reported 45% leaving in first 30 s; giving spawn area a clear first action dropped that to 18% (Reddit, secondary).
3. Difficulty targets: no published per-level targets from King, Rovio, Supercell, Roblox devs. Reference: StS2 wins 16-25% of runs (Mega Crit); Angry Birds 2 players report two losses in a row lowers difficulty one step (forum, secondary); King: "crazy hard levels never pay off" long run.
4. Cash out or keep going:
   - BART: average balloon pops at 64 pumps (money-maximizing stop). People typically stop 26-35. People cash out far too early.
   - Pig dice: "hold at 20" near optimal only when both scores low. Optimal player beats hold-at-20 player 58.7%. Two optimal players, first player wins 53% (Science News, Neller & Presser).
   - Deal or No Deal: contestants often refuse offers above expected value; more risk after losses (break-even effect) and after gains (house-money effect) (Post et al., Tinbergen).
   - How often continuing is correct in a game like yours: no number found.
5. Skill spread: no number found.
6. Feedback timing: Fisch one catch per 8 s at best, no input first 1.2 s. Brotato waves 20-60 s with shop after each. Coin Master 5 free spins every 50 min (GameAnalytics). Clash Royale chests 3/8/12 h; one opens at a time, four slots (Mobile Free to Play).
7. Difficulty curves, Balatro base score per ante 1-8:

   | Stake | A1 | A2 | A3 | A4 | A5 | A6 | A7 | A8 |
   |---|---|---|---|---|---|---|---|---|
   | White | 300 | 800 | 2,000 | 5,000 | 11,000 | 20,000 | 35,000 | 50,000 |
   | Green+ | 300 | 900 | 2,600 | 8,000 | 20,000 | 36,000 | 60,000 | 100,000 |
   | Purple+ | 300 | 1,000 | 3,200 | 9,000 | 25,000 | 60,000 | 110,000 | 200,000 |

   White-stake jumps: x2.67, x2.5, x2.5, x2.2, x1.82, x1.75, x1.43 (the research AI's arithmetic). Endless (ante 9+) grows much faster.
8. Bad-luck counters:

   | Game | Base | Soft start | Hard cap | Source |
   |---|---|---|---|---|
   | Genshin | 0.6% | pull 74 (jumps to ~6-7%, +~6% per pull) | 90 | HoYoLAB, fandom |
   | Honkai: Star Rail | not found | ~70-75 | 90 | HoYoLAB |
   | Arknights | 2% | after 50 pulls +2% per pull | 99 | wiki, shattered.io |
   | FGO | not found | none | 330 summons featured Servant (EN from 21 Nov 2022) | Siliconera, GamerBraves |
   | Hypixel SkyBlock RNG meter | item's rate | rate x (1 + 2 x meter fill), up to 3x | guaranteed when full; resets on drop | Hypixel wiki |
   | Hypixel other | | | trophy fish gold at 100 catches, diamond 600; chocolate eggs 250/1,250; 2,500 treasures; 2,000-block mineshaft counter | same |
   | Pet Sim 99, Fisch | no number found | | | |

   Effect on spending: of loot box buyers who saw published odds, only 19.3% said they spent less (Xiao 2023, PubMed). Retention effect of a guarantee counter: no number found.
9. Multi-area: Pet Sim 99 274 areas. Time per area, % reaching area 2/3, value multiplier per area: no number found.
10. Run vs session length: runs per session no number found. Grow a Garden 15.19 min; Steal a Brainrot 9.75 min (Rolimons). Roblox users avg 2.4 h/day across 21+ experiences/month (2024, PocketGamer.biz). Mobile sessions 40% shorter than desktop in one dev's game (Reddit, secondary).
11. Co-op/social: Roblox ranks with "intentional co-play days" (friends joining on purpose); players who play, spend, and play with friends more are likelier to stay, no number (DevForum Dec 2025). Duolingo leaderboards raised learning time 17% and tripled highly engaged learners (Lenny's). Admin war broadcast pushed both games to record CCU. Server-wide rare-find announcements: no number.
12. Item economy floods: OSRS added 1% Grand Exchange tax used to remove items (later 2%). Hypixel patch "heavily increased" drop rates of a rare item to push prices down; admins promised "massive coin sinks". Pet Sim 99 players report billions of diamonds entering daily. Grow a Garden players call economy "destroyed". Measured price changes after fixes: no number found.

---

## C. What makes it compelling

Individually
1. Tight feedback, short runs: King found longer levels less likely fun.
2. Escalation inside a run: Brotato 20 s to 60 s waves; Balatro 1x/1.5x/2x per ante.
3. Near-misses the player controlled: Howell argues every Vampire Survivors run ending short of 30 min feels like a near-win. A games-psychology writer suggests more reward thresholds (five instead of three) create more near-win chances, notes no research on near-misses in skill games (Psychology of Games).
4. Visible stakes, hidden outcome: Balatro hides score until commit.
5. Visible mastery: Fisch perfect-catch bonus, streak above head, server flags.

As a set
6. Area gating with rebirth checkpoints unlocking new minigames/machines (Pet Sim 99).
7. Rotating boosted pools: Pet Sim huge-pet rotation every two days; Grow a Garden changing stock.
8. One activity feeding another: Coin Master raids drop chests, chests give cards, card sets unlock pets, pets boost raids.
9. Mario Party, WarioWare, Fisch islands: no source retrieved.

Risk through skill
10. In Pig, right moment to stop depends on both scores.
11. Brotato shows upcoming hard waves before you commit.

Failures
12. Too hard: Candy Crush level 65 churn. 13. Pay-to-win: Steal a Brainrot criticism. 14. Inflation: Pet Sim 99, Grow a Garden. 15. Too punishing roguelikes: Kasavin says if you play five hours before restarting "you're not experiencing the cool part".

### C1. Aggressive engagement techniques, ranked by evidence strength

1. Near-miss frequency (scholarly): 19% vs 2% near-misses gave 107 vs 87 trials (~23% more, AI arithmetic) (Broussard 2023). Near-misses activate brain win circuitry (Clark 2009). For you: show next-tier threshold line on score bar.
2. Losses disguised as wins (scholarly): on a 15-line slot these (18.4% of spins) outnumber true wins (14.2%); skin-response arousal same as wins and higher than plain losses (Dixon 2010). Players overestimate wins (Graydon 2017). For you: give soft-fail payout the full reveal.
3. Streaks and loss aversion (dev-primary): two streak freezes vs one raised DAU 0.38%; streak animations +1.7% 7-day retention for new users; 7-day streak users 3.6x likelier to finish course (Duolingo blog). Share on 7+ day streaks roughly tripled to over half of daily users (Lenny's). For you: daily minigame streak with 1-2 banked freezes boosting tier odds.
4. Leaderboards/rivalry (dev-primary): +17% time, 3x highly engaged (Duolingo). Weekly per-area boards.
5. Difficulty spikes at point of sale (dev-primary): Candy Crush level 65. You sell no currency so spikes only cost players; keep short.
6. Guarantee counters: Hypixel meter shown on screen, player picks target item; grinding becomes visible progress.
7. Appointment timers/countdowns: Clash Royale 4 slots 3-12 h; Coin Master 5 spins/50 min; Grow a Garden weekly must-be-online items. Coin Master January revenue +250% YoY (GameAnalytics). Monopoly Go $6B fastest mobile (Scopely). None isolates one mechanic.
8. Raids and revenge (Coin Master): steal from bases; shields (max 3) partly protect.
9. Gifting/favors (Candy Crush lives): ask each friend once per day; one player reports ~10% response (Reddit).
10. Broadcast live events: admin war record CCU.
11. Break-even/house-money effects (scholarly): bigger risks right after loss or big gain (Post et al.). Offer keep-going right after strong or weak first half.
12. Variable-ratio, sunk cost, endowment, decoy pricing, rank decay, notification timing: no measured effect size found. Duolingo widget users "had far better retention", no number.

### C2. Presentation and feel

1. Sound: Peggle rising in-key note per peg (up to 26) and drumroll into Ode to Joy; Balatro escalating count-up; Fisch rarity-dependent catch sounds; Candy Crush gives every menu step its own sound (Game Developer). 91% of mobile players play sound off (TapResearch) vs 73% sound on (Facebook group, secondary): conflicting, never put critical info in sound alone. Cue-to-reward gap and sound lengths in ms: no number.
2. Juice: Sakurai scales hit-freeze with damage and caps it. Forum devs suggest 25-30 ms hit-freeze, 100 ms max. Street Fighter fireball hits freeze ~12 frames (sonichurricane, secondary). Vlambeer and "Juice it or lose it" talks exist, no numbers retrieved.
3. Reveal staging: Vampire Survivors chest ribbons/coins/jingle, five items add fireworks; Peggle slow-motion zoom. Reveal length before skip: no number.
4. UI: 80% of Roblox daily users mobile, 17% PC, 3% console (PocketGamer.biz). Touch targets 44x44 pt (Apple), 48x48 dp (Android) (LogRocket). Fisch lets players turn off "cancel on misclick".
5. Controls/latency: Fisch maps same action to hold-click (PC), R2 (PlayStation), tap-and-hold (mobile). Users notice as little as 2 ms delay when dragging on touchscreen (ResearchGate). Phone vibrations trigger a reward response distinct from other feedback (Hampton, J. Consumer Research).
6. Notifications/social visuals: Fisch regular flag 1-in-1,000, server-wide 1-in-100,000, cap 150 flags, server chat when streak breaks. Banner duration/intrusiveness: no number.
7. Onboarding: cutting tutorial 5 steps to 3 raised D1 6% to 15% in one Roblox game (Reddit, secondary). Roblox penalizes players leaving under 60 s or within 61-180 s (Roblox docs). Community guideline: at least 50% of new players past 3:00 (DevForum, secondary).
8. Failure presentation: Hades God Mode, story built to reduce sting; Peggle free-ball bucket and coin flip.
9. Roblox performance: 60 FPS = 16.67 ms/frame; under 1,000 draw calls and 1M triangles on baseline device (Roblox docs). One dev saw lower FPS and shorter sessions on mobile. FPS/load-time leave thresholds: no number.

---

## D. Verification
1. Peggle: slow-motion zoom and drumroll confirmed (CNN 2007, Jay is Games); free-ball bucket and coin flip confirmed (wiki, secondary). No PC Gamer article found.
2. Balatro "skip correct 15-25%": NOT verified, no number found. Forums say skipping ante 1 "almost never correct", skip tags usually traps.
3. Howell on Vampire Survivors: article exists (The Conversation, 13 Apr 2023), makes the near-win argument, no data. Galante says he did not learn mechanics from his gambling job (Android Police), partly conflicting with his Verge quote.
4. Fisch 12%/s: verified, secondary source.

---

## E. Pitch list
Shared rules: checkpoint cash-out at ~60 s (continuing raises tier ceiling and difficulty); score sets tier, randomness picks item inside tier; soft fail: bust after checkpoint keeps banked tier minus bonus.

| # | Concept | Verb | Risk choice at 60 s | Skill | Escalation | Based on |
|---|---|---|---|---|---|---|
| 1 | Reel Duel | Hold/release to keep fish in bar | Bank, or cast again for heavier fish with narrower bar | Bar tracking; perfect catches add score | Bar narrows, fish moves more | Fisch |
| 2 | Peg Drop | Aim and shoot ball | Bank, or bonus board with fewer balls | Angle planning, bank shots | Fewer balls, more blockers, moving free-ball bucket | Peggle/Peglin |
| 3 | Deep Dig | Tap to dig, choose path through tiles | Climb out at ladder, or go down a layer as lamp runs low | Route reading, hazard timing | Each layer worth more, more hazards | Roblox digging sims, DRG escape timer |
| 4 | Hand Score | Choose tiles to play/discard to beat target | After target 2 (1.5x), bank or face 2x boss target | Combo building, no score preview | 1x/1.5x/2x | Balatro |
| 5 | Wave Hold | Move to dodge, auto-fire | After wave 2, bank or face elite wave announced ahead | Dodging, positioning | Waves 20 s, 25 s, 30 s; elite wave shown ahead | Brotato/Vampire Survivors |
| 6 | Lane Dash | Swipe lanes/jump | Exit through gate, or continue faster | Reaction, patterns | Speed and density rise | Subway Surfers/Crossy Road (no sources) |
| 7 | Micro Chain | 3-5 s microgames in sequence | Bank at each speed-up, or continue faster | Fast rule reading | Speed rises | WarioWare (no source) |
| 8 | Vault Run | Explore, grab loot, reach exit | Extract at first exit, or go deeper before collapse | Route efficiency, carry limit | Collapse timer, rarer loot deeper | Dark and Darker/DRG |
| 9 | Cascade Clear | Swap to match | Bank, or harder board with fewer moves | Planning cascades | Fewer moves, blockers | Candy Crush (keep hard boards short) |
| 10 | Intent Duel | Play actions vs enemy whose next move is shown | Bank after enemy 1, or fight stronger enemy | Reading shown intent | Enemy health/damage scale per fight | Slay the Spire |

Fit with two-path rule: make hidden counter a visible meter (Hypixel-style); roller keeps pure-luck top end above minigames' Celestial odds; rotate which area's pool is boosted (Pet Sim every two days); remove items through crafting requests (OSRS tax/item sink) so repeat payouts don't flood market.

## Final table (key rows)

| Metric | Number | Source | Evidence |
|---|---|---|---|
| Spawn bounce fix | 45% to 18% leaving in first 30 s | Reddit dev | secondary |
| Tutorial length | D1 6% to 15% (5 to 3 steps) | same | secondary |
| Hard-level conversion vs churn | Candy Crush L65 top revenue, top churn | mobilegamer.biz | dev-primary |
| StS2 win rates | 16-25% | Mega Crit | dev-primary |
| Cash-out behavior | stop 26-35 pumps vs optimal 64 | impulsivity.org | scholarly |
| Optimal push-your-luck | optimal beats hold-at-20 58.7% | Science News | scholarly |
| Fisch reel | +-12%/s; 1.2 s lock; 6.8 s min; bar 30% | Fischipedia | secondary |
| Brotato waves | 20 s +5 s/wave to 60 s; wave 20 90 s | wiki | secondary |
| Balatro antes | 300/800/2k/5k/11k/20k/35k/50k; blinds 1x/1.5x/2x | wiki | secondary |
| Genshin | 0.6%, soft 74, hard 90 | HoYoLAB | secondary |
| Arknights | 2%, +2%/pull after 50, cap 99 | wiki | secondary |
| FGO | 330 | Siliconera | secondary |
| Hypixel RNG meter | up to 3x, guaranteed when full | wiki | secondary |
| Anime Defenders | Mythic 0.25%, guaranteed 400 | wiki, Gamezebo | secondary |
| Odds shown vs spending | 19.3% spent less | Xiao 2023 | scholarly |
| Pet Sim 99 | 274 areas, rebirths 25/50/75/99... | wiki | secondary |
| Sessions | GaG 15.19 min; SaB 9.75 min | Rolimons | secondary |
| Roblox ranking | playtime counted up to 60 min/day; co-play days | DevForum | dev-primary |
| Early-leave penalty | <60 s and 61-180 s counted against | Roblox docs | dev-primary |
| Leaderboards | +17% time; 3x engaged | Lenny's | dev-primary |
| Streak freezes | +0.38% DAU | Duolingo | dev-primary |
| Streak animation | +1.7% D7 new users | Duolingo | dev-primary |
| 7-day streak | 3.6x course completion | Duolingo | dev-primary |
| Near-miss | 107 vs 87 trials | Broussard | scholarly |
| Losses disguised as wins | 18.4% vs 14.2%, same arousal | Dixon 2010 | scholarly |
| Coin Master energy | 5 spins/50 min | GameAnalytics | secondary |
| Clash Royale chests | 3/8/12 h; 4 slots | MF2P | secondary |
| Hades God Mode | 20% +2%/death, cap 80% | Inverse | dev-primary |
| Vampire Survivors level-up | 3-4 choices | Android Police | dev-primary |
| Peggle notes | up to 26 rising notes | Audiogang | dev-primary |
| Mobile share | 80/17/3 | PocketGamer.biz | dev-primary |
| Touch targets | 44 pt / 48 dp | LogRocket | secondary |
| Frame budget | 16.67 ms; <1,000 draw calls; <1M tris | Roblox docs | dev-primary |
| Hit-freeze | 25-30 ms suggested; 100 ms max | Reddit | secondary |
| Sound off | 91% vs 73% sound-on (conflict) | TapResearch | secondary |
| Economy sink | GE tax 1% to 2% | OSRS wiki | dev-primary |
| Balatro skip 15-25% | no number found | | |

## Data limitations
No published figures for replay rate, mid-run quit rate, studio target clear rates, skill spread, runs per session, area progression. Session lengths and CCU from trackers/Wikipedia, not developers. Gacha numbers from wikis and community guides. Roblox retention results from one developer's self-reported Reddit post. No sources for Stardew, WarioWare, Crossy Road, Subway Surfers, Mario Party, Vlambeer/"Juice it or lose it" numbers.
