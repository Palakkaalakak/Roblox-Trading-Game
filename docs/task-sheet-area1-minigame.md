# Task sheet: Design the Area 1 minigame

**Name:** ______________  **Date:** ______________

## The brief
Area 1 is the first area of the second map. It has ONE minigame and its own item pool (Common to Celestial). Every new player plays it first, so it must hook them in the first minute and still be fun after hundreds of runs. Design it on paper first. Nothing gets built until this sheet is complete.

## Fixed rules (you cannot change these)
1. The minigame pays ITEMS only. It never pays gems.
2. A run lasts 60-120 seconds and you can start another with one click.
3. Your skill decides the reward tier (Floor / Good / Great / Jackpot-eligible). Chance only picks which item you get inside that tier.
4. The player chooses how much risk to take (self-determination: autonomy). Every minigame offers at least a **safe way to play**: a bad run still pays the lowest tier and no items are lost. A map may ALSO have **high-risk minigames or modes** where the player stakes items and can lose them for a bigger payout. Area 1 must be playable safely; a risky mode in Area 1 is optional (see Part 3, question 8b).
5. A hidden counter guarantees a strong tier after enough bad runs in the safe mode. It guarantees a tier, never a specific item. (Whether the counter also covers risky modes is part of your design, Part 4.)
6. Once, around the 60-second mark, the player chooses: cash out or keep going. Going on raises the best possible tier and the difficulty.
7. The first run ever is guaranteed to pay a good result.
8. Must work on mobile first (80% of Roblox players), then PC.
9. Area 1 items are the lowest-value area (the next areas' items are worth more). Its Common items get used in bulk later, so Area 1 must stay worth playing.

## Resources (read first)
- `docs/design-minigame-rubric.md` - how your design will be marked
- `docs/research/pass-14-minigames-deep.md` - numbers and examples
- `docs/research/pass-13-minigames.md` - first research pass
- `docs/design-second-map-areas.md` - where Area 1 fits

---

## Part 1: Pick your idea (10 marks)
Choose ONE concept from the pitch list (Reel Duel, Peg Drop, Deep Dig, Hand Score, Wave Hold, Vault Run, Cascade Clear, Intent Duel) or invent your own that follows the fixed rules.

1. Concept name: ____________________
2. In one sentence, what do the player's hands do (the verb)? ____________________
3. Which proven game is it based on, and what exactly did that game do that you are copying? ____________________
4. Why is it a good first minigame for a brand-new player? (2-3 sentences) ____________________
5. Explain why it is real gameplay with thought, not a gambling button. ____________________

## Part 2: One run, second by second (20 marks)
Fill in the timeline. Aim for something visible happening every 1-6 seconds.

| Time | What the player does | What the screen/sound does | What the player decides (if anything) |
|---|---|---|---|
| 0-5 s | | | |
| 5-15 s | | | |
| 15-30 s | | | |
| 30-60 s | | | |
| ~60 s (cash out or keep going) | | | |
| 60-90 s | | | |
| End of run (reveal) | | | |

6. Mark where the first reward arrives. Target: within 30 seconds of entering (Roblox counts players who leave in under 60 s against a game). Your answer: ____ s
7. Mark one moment where a player could lose (miss, run out, hit). What does a "close call" look like on screen? ____________________

## Part 3: Choices (10 marks)
8. Before the run, what can the player choose (loadout, route, risk level)? What does each choice cost and give? List at least two choices:
   - Choice A: ____________________
   - Choice B: ____________________
8b. **Risk menu (autonomy).** Design what the player can choose between: a safe mode (nothing lost) and, optionally, a risky mode (items staked). Fill in:
   - Safe mode: what it pays, what the ceiling is. ____________________
   - Risky mode (or leave blank and write "none in Area 1, because ___"): what the player stakes (which items, how many), what happens to staked items on a loss (they go back to the reserve, never to gems), what the payout is on a win, and why the best skilled players would choose it. ____________________
   - How does a player know the exact stakes and odds before choosing? ____________________
   - Why would a player choose safe sometimes and risky other times, so the choice stays a real decision? ____________________
   - Does the risky mode pay more per minute than safe for a skilled player, and by how much? (Remember the Roller is the luck path; risky minigames must not copy it with a bare chance of loss. Skill must change the odds.) ____________________
9. At the cash-out moment, what exactly does the player SEE (stakes) and what is HIDDEN (outcome)?
   - Visible: ____________________
   - Hidden: ____________________
10. Research shows people usually cash out too early (they stop at 26-35 pumps when 64 pays most). What does your design do so that going on is a tempting, fair choice? ____________________

## Part 4: Skill and rewards (20 marks)
11. What does a skilled player do differently from a new player? Name 2 things. ____________________
12. Fill in the tier table. Decide what score gets each tier (use made-up numbers for now, mark them "to tune in playtest").

| Tier | Score needed | What it pays (item rarity range, count) |
|---|---|---|
| Floor | | |
| Good | | |
| Great | | |
| Jackpot-eligible | | |

13. What is the guaranteed payout of a bad run in the safe mode? (Must feel real, not insulting.) ____________________
13b. If you have a risky mode: what does a bad run cost, and what does the player get back (partial return, a consolation reward, progress toward the counter)? ____________________
14. Bad-luck counter: after how many bad runs does the next run get upgraded one tier? N = ____. (Genshin guarantees at 90 pulls; Arknights ramps after 50. Yours is much smaller because runs are short.) Is the counter shown to the player, hidden, or shown as a meter? ____. Why? ____________________
15. Describe the first-ever run: how is it guaranteed good, and how does the player not notice it is guaranteed? ____________________

## Part 5: Difficulty curve (10 marks)
16. How does the run get harder? Give actual numbers, e.g. "stage 1 target 300, stage 2 target 800, stage 3 target 2,000".

| Stage | Target / difficulty number | Jump from previous stage (x) |
|---|---|---|
| 1 | | - |
| 2 | | |
| 3 | | |

Reference: Balatro's targets jump about x2.67, x2.5, x2.5, x2.2, x1.82, x1.75, x1.43. Early jumps are big, later ones smaller. Does yours do the same? ____________________
17. Which stage do you expect most players to quit at, and why? How will you check it in playtest? ____________________

## Part 6: How it looks, sounds and feels (15 marks)
Everything must be doable on mobile (buttons at least 44x44 points).

| Event | Sound | Visual effect | How long |
|---|---|---|---|
| Good move / success | | | |
| Combo rising | | | |
| Close call / near miss | | | |
| Cash-out choice appears | | | |
| Reward reveal (silhouette > rarity color > name) | | | |
| Rare / jackpot find | | | |
| Bad run (soft fail) | | | |

18. Reference examples: Peggle plays a rising musical note for each peg (up to 26 notes) and slows down for the last peg. Balatro counts the score up step by step with rising sounds. Vampire Survivors streams items out of a chest on ribbons of color. Which one idea from each (or others) do you use? ____________________
19. Roughly 91% of mobile players may play with sound off in one survey (another says 73% on). How does the player still understand everything with the sound off? ____________________
20. Sketch the run screen (HUD) and the results screen. Show where the one-tap "play again" button is and where the next-tier line is. (Draw on the back or attach.)

## Part 7: Connecting to the rest of the game (10 marks)
21. Which items does Area 1 pay out? List 6-10 item ideas across Common to Celestial (names only). ____________________
22. Where do Area 1 items get used? Tick all that apply and give one example each:
   - [ ] Crafter: ____________________
   - [ ] Roller (as payment): ____________________
   - [ ] Unique Crafts (needed in large counts later): ____________________
   - [ ] Market / trading: ____________________
23. What does the end-of-run screen point the player at next? (Something they are close to: a craft, the next area's unlock bar, a streak.) ____________________
24. One reason to come back tomorrow (daily streak, weekly featured pool, event). ____________________

## Part 8: Self-check against the rules (5 marks)
Tick only if true. Then give a one-line proof for each.
- [ ] Pays items, not gems. Proof: ____________________
- [ ] Safe mode: a bad run still pays and loses nothing. Proof: ____________________
- [ ] Any risky mode: stakes and odds are shown first, losses go to the reserve (not gems), skill changes the odds. Proof: ____________________
- [ ] Skill sets the tier, chance only picks the item. Proof: ____________________
- [ ] Run is 60-120 s, one click to replay. Proof: ____________________
- [ ] First run guaranteed good. Proof: ____________________
- [ ] Works on a phone. Proof: ____________________

---

## Marking guide (matches the rubric)
Each part is scored on five levels: **Not Achieved / Emerging / Developing / Applying / Exceeding**. To pass, everything must reach Applying. The starred items must reach Exceeding.

| Part | Marks | Starred items (must be Exceeding) |
|---|---|---|
| 1 Idea | 10 | |
| 2 Run timeline | 20 | First run and time to first win; feedback every 1-6 s |
| 3 Choices | 10 | Cash out or keep going every 60-90 s |
| 4 Skill and rewards | 20 | No-loss floor and bad-luck counter |
| 5 Difficulty | 10 | |
| 6 Look and sound | 15 | |
| 7 Connections | 10 | Closed loop with Crafter / Roller / Unique Crafts / Market |
| 8 Self-check | 5 | Gem rule |
| **Total** | **100** | |

## Extension (optional)
- Design a second, high-risk minigame for the same map (items staked, can be lost) and say how it differs from the safe one in verb, stakes and who it is for.
- Write one sentence for what changes in Area 2 (a different verb, same structure) so the two areas feel different.
- Plan how you will measure, in playtest, the numbers the research could not give us: how many players start another run straight away, where they quit mid-run, and how far top and bottom players score apart. Write the targets after your first playtest.

---

# Worked examples (famous games, filled in as if they had done this worksheet)

How to read these: facts marked with a source come from `research/pass-14-minigames-deep.md`. Anything marked **(adapted)** is how the idea would be changed to fit our rules (items only, 60-120 s, safe mode, etc.), not what the original game does. "Not published" means no number was found.

## Example 1: Fisch (reeling) - Parts 1-8

**Part 1.** Concept: fishing bar. Verb: hold to push a bar right, release to let it drift left, keep the fish icon inside the bar. Good first minigame because the rule is learned in seconds. Real gameplay: your control decides whether you catch the fish; chance only decides which fish bites.

**Part 2 (one catch).**

| Time | Player does | Screen/sound | Decision |
|---|---|---|---|
| 0-1.2 s | Nothing (inputs locked until 1.2 s or 20% progress) | Bar appears, progress starts at 20% | none |
| 1.2-8 s | Hold/release to keep fish in bar | Progress rises 12% per second while the fish is inside, falls 12% per second outside | keep tracking |
| Catch | Progress hits 100% | Rarity-dependent catch sound; perfect catch (no progress lost) pays extra | none |
| After | Collect | Streak counter above head after 10 in a row | cast again |

First reward: fastest catch is 6.8 s of reeling, 8 s from the animation start. Close call: the bar drains while the fish drifts out. Failure: progress hits zero and the line snaps.

**Part 3.** Pre-run choices: rod (Control widens the bar, 30% of the track by default; Resilience makes the fish move less) and bait. Cash-out moment: Fisch has none in a catch; this is the gap our design must fill **(adapted: after a catch, bank it or cast again for a heavier fish with a narrower bar)**. Risk menu: Fisch is safe only (only loss is the catch).

**Part 4.** Skilled players hold the bar steadily and get perfect catches (+10 C$ and +50% XP). Rewards: rarity of the fish is chance; perfect catch is skill. Bad-luck counter: not published. Soft fail: a snapped line loses only the catch.

**Part 5.** Difficulty comes from fish resilience and bar width, set per fish (rarer fish are harder). Stage numbers: not published.

**Part 6.** Sound changes with catch rarity. 1-in-1,000 catches plant a flag showing the odds; 1-in-100,000 catches plant a flag the whole server sees (cap 150 flags per server). Streak shown above the head; server chat when someone loses a streak. Controls: hold-click on PC, R2 on PlayStation, tap-and-hold on mobile.

**Part 7.** Fish feed the sell/trade economy. Return hooks: streaks, server-wide flags, events.

**Part 8 check.** Items not gems: yes. Skill sets outcome: partly (rarity of the fish is chance). Run length: 8 s per catch, so it is a loop of short beats, not one 60-120 s run **(adapted: chain 8-10 catches into one run)**.

What to copy: learned in seconds, visible progress bar, rarity-linked sound, server-visible rare finds.

## Example 2: Peggle - Parts 1-8

**Part 1.** Verb: aim and fire a ball into pegs. Good first game: one input (aim), instant feedback.

**Part 2.** Fire a ball; each peg hit plays the next note of a rising scale (up to 26 notes, about 3.5 octaves in Peggle 2). When the last orange peg is about to be hit, the camera zooms into slow motion with a drumroll and ends on Beethoven's "Ode to Joy".

**Part 3.** Decision: where to aim each shot. Cash-out: none in the original **(adapted: after clearing half the orange pegs, bank your tier or play a bonus board with fewer balls)**.

**Part 4.** Skill is angle planning and bank shots. Soft fail: a bucket moves along the bottom and a ball landing in it is free; missing every peg gives a coin flip for a free ball.

**Part 6.** Rising in-key notes per hit (Peggle Blast: harp note per hit, marimba layer on orange pegs, always in the music's scale). Slow motion and drumroll before the final peg.

**Part 8 check.** Soft fail: yes (free ball). Skill: yes. Items: n/a. Run length: not published.

What to copy: rising notes tied to success, a staged slow-motion finish, a free-ball safety net.

## Example 3: Balatro (score target) - Parts 1-8

**Part 1.** Verb: choose cards to play or discard to beat a score target. Based on Luck Be a Landlord. Real gameplay: you build combos; the score is your decisions, not a roll.

**Part 2.** Each ante has three rounds: Small (1x base score), Big (1.5x), Boss (2x). Small and Big can be skipped for a reward tag; Boss cannot. No score preview: numbers count up with escalating sounds and each card and Joker steps forward in turn.

**Part 3.** Cash-out equivalent: skip a round or play it. Stakes visible (target), outcome hidden (final score). Forum players say skipping in ante 1 is almost never correct (secondary). The "15-25% correct" figure is **not verified**.

**Part 5 (difficulty numbers).** White stake base scores for antes 1-8: 300, 800, 2,000, 5,000, 11,000, 20,000, 35,000, 50,000. Jumps: x2.67, x2.5, x2.5, x2.2, x1.82, x1.75, x1.43. Early jumps big, later smaller.

**Part 6.** Escalating count-up sounds; each card steps forward. The developer, LocalThunk, says the fun lives in the moment you hit play.

**Part 8 check.** Skill: yes. Bad-luck counter: none. Items: n/a.

What to copy: visible target ladder, step-by-step count-up reveal, decaying jump between stages.

## Example 4: Dark and Darker / Deep Rock Galactic (extract or push on) - the risky mode

**Part 1.** Verb: explore, grab loot, get back out. Based on extraction games.

**Part 8b (risk menu).** Risky mode: your carried loot is at stake until you extract. Deep Rock Galactic gives 5 minutes to return to the drop pod after the main objective; missions take 25-40 minutes (player reports). Dark and Darker players discuss low extraction rates (no number found). Skill changes the odds: route choice and timing. Stakes are visible (what you carry, how much time is left).

**Part 4.** Bad run: you lose what you carried. Consolation: not published in these games.

**(adapted for us).** Vault Run, 90 s: pick safe (always keep the floor tier) or risky (stake items; extract at the first exit with the tier banked, or go deeper for a later exit before a collapse timer). Lost stakes go back to the reserve, never to gems.

What to copy: a clear countdown, visible stakes, one decision that matters.

## Example 5: Brotato (waves) - Parts 5 and 3

**Part 5.** 20 waves. Wave 1 lasts 20 s, each wave adds 5 s until 60 s from wave 9, and wave 20 lasts 90 s. Harder waves at 11-12, 14-15 and 17-18 are 40% horde and 60% elite, and you can see them coming from the shop.
**Part 3.** Between waves, the shop is the decision point. Seeing the harder wave coming before you commit is visible stakes with a hidden outcome.

What to copy: segmenting a run into short stages with a decision between them, and warning the player before the hard part.
