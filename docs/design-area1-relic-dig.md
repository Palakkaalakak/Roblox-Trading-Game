# Area 1 minigame: Relic Dig (design, version 2, checked against the research)

Status: design proposal, not built. Sources are in `research/pass-14-minigames-deep.md` ("pass 14") and `research/addictive-loops-synthesis.md`. **PLACEHOLDER** means no published number exists and it must be set in playtests. Nothing is claimed as researched unless a source is named.

Version 2 change: version 1 used Minesweeper-style clue numbers, which a new player cannot understand in 10 seconds. They are removed. Everything below must be understood from watching a 10-second demo, with no text.

## 1. The 10-second explanation
"Drag your finger over the dirt to brush it away and uncover the relic. Go gently near the relic. Brush too fast and it cracks."

That is the whole rule. One gesture, no numbers, no reading. This is the pass/fail test for the design:

**Playtest test: show a brand-new player a silent 10-second demo. 9 of 10 must complete a correct first run with no text help. PLACEHOLDER target, set after the first playtest.**

Why 10 seconds: 45% of players left within 30 s in one developer's tracking (secondary), and Roblox counts players who leave in under 60 s against a game (Roblox docs).

## 2. Rules it must follow (from the brief)
- Pays items only, never gems.
- Run is 60-120 s; one tap to go again; no loading.
- Skill sets the reward level; chance only picks the item inside the level.
- Safe mode never loses items. Optional risky mode stakes an item (a loss returns it to the reserve, never to gems).
- A bad-luck counter guarantees a level, never a specific item.
- First run guaranteed good. Works with one thumb on a phone.

## 3. The screen (one picture)
- A patch of dirt with a relic buried in it. The brush follows the finger.
- A **speed ring around the brush** shows how hard you are brushing: green (safe), yellow (careful), red (the relic cracks if it is under the brush). Drag slow and the ring is green, drag fast and it goes red. This is understood by looking, no words.
- A faint **warm glow** shows through the dirt over the relic, getting brighter as the brush nears it (the "warmer / colder" idea everyone knows).
- Top bar: time left, and a **reward bar** with lines marking Floor / Good / Great / Perfect, so the player always sees how close they are to the next level. Seeing the next level is what makes misses count (near-miss study: 107 vs 87 plays with more near-misses, Broussard 2023, scholarly).
- Works with the sound off: ring colors, glow, and a phone buzz carry everything. Sound only adds (survey results conflict: 91% vs 73% sound on, secondary).

## 4. One run, timed (about 70-80 s)

Stage lengths are **PLACEHOLDERS**; stage lengths in Brotato run 20-60 s with a decision point between stages (secondary), which is the shape used here.

| Time | What happens on screen | What the player decides |
|---|---|---|
| 0-3 s | A hand shows one drag. The first drag always uncovers a glint of the relic (guaranteed good start in the first run). A rising note plays. | none |
| 3-25 s (stage 1) | Fast sweeps clear plain dirt. Dirt puffs and crumbles on every drag. The relic glows brighter as it nears. Each piece uncovered plays the next note of a rising scale. | where to sweep fast, where to go gently |
| about 12 s | The relic's outline starts to read. The Good line is within reach. | which part to finish first |
| 25 s | Stage 1 timer ends. **Checkpoint banner:** shows how much is uncovered, the reward level it pays now, and the next level. Below it, a dark silhouette of a deeper, rarer relic glows in its rarity color. | **Take it now, or dig deeper** |
| 25-55 s (stage 2, if you dig) | A deeper layer. Harder crust (more of it is slow-only), a shorter timer, a higher reward ceiling. | where to be gentle, with less time |
| End | Dust blows off. The relic appears as a dark shape, then its rarity color, then its name. The reward level counts up step by step. | none |

Where each timing comes from:
- First reward within 3 s: the target is under 30 s.
- Something visible every 1-6 s: slot outcome cycles are 3-6 s (scholarly). Here dirt reacts to every drag, a piece uncovers every few seconds, and glow and notes change continuously, so there is no silent stretch.
- Reveal every 20-60 s, and a stage change at 60-90 s: synthesis targets.
- Run length 60-120 s: the brief's rule.

## 5. Choices that matter

**Before the run (3 tools; Vampire Survivors settled on 3-4 options, Android Police, dev-primary):**
- **Fine Brush:** small area, forgiving ring (the red zone starts later). Slow but safe.
- **Wide Brush:** large area, fast, but the red zone starts early. Fast but risky.
- **Sifter:** removes dirt in a medium area but cannot crack the relic. Safe, but uncovers less per second.

Tools change how you play, never the drop odds (Fisch: better gear changes the controls, not the odds; secondary).

**At the checkpoint:**
- Visible: relic uncovered, current reward level, next level, glowing teaser of the deeper relic.
- Hidden: whether you will finish the deeper layer in time.
- People cash out too early: the balloon task's money-maximizing stop is 64 pumps but people stopped at 26-35 (scholarly). So the deeper relic is shown glowing in its rarity color. I found no number for how often continuing is the right choice, so I make no claim.

## 6. Where the skill is
1. **Speed control:** read the ring and keep the brush in the green near the relic, fast over plain dirt. Speed is rewarded only where it is safe.
2. **Finding the relic fast:** read the glow to head straight to it instead of clearing everything.
3. **Knowing the shapes:** the same relics return (a Jade Serpent is always a serpent). A player who knows the shape sweeps its edges confidently and skips plain dirt. This is what improves over 20+ runs.
4. **Using the clock:** choosing what to uncover first, since time is limited.

Skill has one job here: it decides how high the reward level is. It does not need to be deep or keep growing for dozens of runs. It only has to be easy to see, so a better run gets a visibly higher level than a worse one. (Owner decision.)

Measuring skill: skill spread between top and bottom players has no published number (pass 14, B5). Playtest target: top 10% average at least one reward level above bottom 10%. **PLACEHOLDER.**

## 7. Reward levels and difficulty curve

Reward level is the percentage of the relic uncovered without cracking at the end. **All thresholds are PLACEHOLDERS.**

| Level | Stage 1 | Deeper layer | What it pays |
|---|---|---|---|
| Floor | any | any | lowest Area 1 rarity range |
| Good | 50% | 50% | |
| Great | 75% | 75% | |
| Perfect (jackpot-eligible) | 100% | 100% | top of range plus a small jackpot chance |

- The deeper layer has the same percentages but harder crust and less time, and pays a higher rarity range inside Area 1's pool (it does not reach into other areas' items).
- The difficulty step is one clear jump, like Balatro's 1x, 1.5x, 2x rounds (secondary): about 1.5x harder. **PLACEHOLDER.**
- Performance sets the level; chance only picks the item inside it.

## 8. Never lose, always progress

**Safe mode (default):**
- A cracked or unfinished relic still pays Floor. A run always pays something (Hades: the aim was to "take the sting of failure", dev-primary; Peggle's free ball, secondary).
- A Floor run gets the same reveal as any other (losses disguised as wins: same arousal as wins in a slot study, scholarly).
- **Crack handling:** one crack costs a small part of the reward, never the whole run. A crack shows instantly on screen, so the player sees it was their own speed.
- **Free retry beat:** after two cracks in a row, the next brush stroke is slowed down by 20% to help (like Peggle's free-ball bucket; value is a **PLACEHOLDER**).

**Bad-luck counter:**
- Counts runs that ended below Good. After N bad runs, the next run is upgraded one level. It guarantees a level, never a specific item (Hypixel's item-picking counter made rare items cheap and caused price spikes, forum evidence, secondary).
- Shown as a "Site Luck" meter that fills each bad run, so bad runs feel like progress. Hypixel shows its meter on screen.
- N = **PLACEHOLDER**. Published counters are for expensive single pulls: Genshin 90, Arknights 99 hard cap. Free 75-second runs need a much smaller N.

**Mastery and the Relic Codex:**
- Each relic shape seen is added to a Codex page. Filling pages unlocks new tools and sites. This rewards learning shapes (skill row 3).
- Every run advances at least one of: Codex, Site Luck, mastery XP. The results screen shows which, and points at the closest unfinished goal (goal gradient; a 7-day streak made Duolingo learners 3.6x more likely to finish a course, dev-primary).

**Risky mode (optional, ships after safe mode works):**
- "Sealed Tomb": stake one item. Harder crust and a shorter timer, but a rarer relic. Reach Good or better and you win it; fall short and the staked item returns to the reserve, never to gems.
- Odds and stakes are shown before choosing. Skill changes the odds, so it is not a bare gamble.

## 9. Feel (sound, look, reveal)
- **Continuous feedback:** every drag shows crumbling dirt and a scraping sound. The sound pitch rises as you uncover relic.
- **Piece uncovered:** the next note of a rising in-key scale; Peggle 2 climbs up to 26 notes (Audiogang, dev-primary). Notes reset each run.
- **Crack:** a short sharp sound and a visible fracture line, never a punishing sound.
- **Reveal staging:** silhouette, rarity color, name, then the reward level counting up, as Balatro does (GMTK, secondary). Vampire Survivors chests stream items on ribbons of color, with fireworks on a five-item chest (The Verge).
- **Rare finds:** a jackpot relic gets a server-wide announcement (Fisch plants a server-wide flag for 1-in-100,000 catches, capped at 150 per server, secondary).
- **Freeze and slow motion:** forum guidance is 25-30 ms freeze, 100 ms maximum (secondary). Use only on the last piece of a Perfect.
- **Mobile:** drag works with one thumb; a buzz on each piece found; the "Dig again" button sits in thumb reach on the results screen.
- **Performance:** stay under about 1,000 draw calls, 1M triangles and 16.67 ms per frame (Roblox docs, dev-primary). Dirt is 2D layers and particles, so this is easy.

## 10. First run (tutorial) and return hooks

First run, scripted, with no text:
1. A hand shows one drag. The first drag uncovers a glint within 3 s.
2. The ring is shown turning red once, with a harmless crack on a decoy stone, so the player learns the rule by seeing it.
3. The first run is guaranteed to reach Good. It ends with a reveal that points to the Crafter for the guaranteed Unique Craft, then back to the site.
(Cutting a tutorial from 5 steps to 3 raised day-1 retention 6% to 15% in one developer's game, secondary.)

Return hooks:
- Site Luck meter and Codex progress (progress between sessions).
- Daily streak with one banked freeze (two freezes instead of one raised daily users 0.38% at Duolingo, dev-primary).
- A weekly featured relic with a boosted site (Pet Sim 99 rotates boosted huge pets every two days; Grow a Garden rotates stock weekly; secondary).

## 11. How it connects to the rest of the game
- **Crafter:** Area 1 relics are recipe inputs.
- **Roller:** relics can pay for rolls.
- **Unique Crafts:** low-tier relics are requested in large counts by players further along, so Area 1 stays worth playing.
- **Market and trade board:** relics are ordinary tradeable items.
- **Unlocks:** worth unlocks the next area; the end screen shows that bar.
- **Economy:** the reserve caps how many copies of each relic can ever exist. Risky-mode losses and crafting sinks pull items back out (Old School RuneScape's sales tax went 1% to 2% to fight flooding; dev-primary).
- **Gem rule:** nothing in Relic Dig grants or sells gems.

## 12. Score against the checks (honest)

| Check | Score | Why |
|---|---|---|
| 1 Understood in 10 s, one input | 2 (to be confirmed by the playtest test in section 1) | One drag, a green/yellow/red ring, and a glow. No numbers, no text. |
| 2 Something visible every 1-6 s | 2 | Dirt reacts to every drag; pieces and notes every few seconds. |
| 3 Stop point near 60 s with a choice | 1 | The checkpoint is at about 25 s in this version because the run is short. Move it to about 45-60 s if playtests show 25 s feels too early. |
| 4 Skill changes the result | 2 | Speed control, finding the relic by glow, and shape knowledge. |
| 5 Visible, controllable near-misses | 2 | Reward bar with levels shown; cracks come from the player's own speed. |
| 6 A bad run pays | 2 | Floor reward plus the 20% slowdown help after two cracks. |
| 7 Stageable reveal | 2 | Silhouette, color, name, count-up. |
| 8 One thumb on a phone | 2 | One drag. |
| 9 No obvious best choice | 1 | The deeper teaser makes going on tempting, but the right answer depends on how much time is left. Playtest. |
| 10 Depth past 20 runs | not needed | Owner decision: skill only sets how high the reward is. Shape knowledge and the Codex are bonuses. |
| 11 Each run differs | 2 | New relic, new position, new crust pattern. |
| 12 Clip-worthy | 2 | A near-crack save and a staged Perfect reveal read well in a screenshot. |
| 13 Feeds the loop | 2 | Crafter, Roller, Unique Crafts, Market. |

**Weak spots:** checks 3 and 9, both about the checkpoint choice. Check 3: the checkpoint is at about 25 s, earlier than the 60 s target. Check 9: the right answer depends on how much time is left. Both need playtests.

## 13. Numbers I could not source (set these in playtests)
Stage lengths, reward level percentages, the deeper-layer difficulty step, the crack penalty, the speed-ring thresholds, the slowdown help, bad-luck counter N, jackpot chance, risky-mode difficulty, and the top-versus-bottom skill gap. The research found no published figure for replay rate, mid-run quit rate, or runs per session either, so measure those from the first playtest.
