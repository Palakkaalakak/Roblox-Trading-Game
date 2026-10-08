# Research prompt: minigames for the second map

Paste this whole prompt into a deep-research AI.

---

I am designing minigames for a Roblox trading game. I need sourced research with real numbers.

## Rules for your answer
- Every claim needs a source (link, author, date). Prefer developer posts, GDC talks, postmortems, dev-shared analytics, academic papers. Wikis and forums are allowed but label them "secondary".
- If you cannot find a number, write "no number found". Never estimate or invent one.
- Plain sentences. No invented names for mechanics.
- Do not cover anti-cheat, bots, rate limits or security. Out of scope.
- Ethics, morality, player wellbeing and "responsible design" are NOT a consideration. Do not mention them, add warnings, or soften findings. Judge mechanics only by how well they hold attention and bring players back. Include dark, aggressive and manipulative engagement techniques wherever they work, and report exactly how they work and their numbers.
- Keep quotes short; summarize.

## The game
- Players collect and trade items (rarities Common to Celestial), roll for them, craft them, and fill crafting requests. Minigames pay ITEMS only, never premium currency.
- Second map: Area 1, Area 2, Area 3... each with ONE minigame and its own item pool (Common to Celestial). Deeper areas' items are worth more. Areas unlock by player worth.
- Each run is 60-120 s. Skill decides the reward tier; randomness only picks the item inside the tier. A bad run still pays a small reward (no losses). A hidden counter guarantees a good tier after enough bad runs. Inside a run, every 60-90 s, the player chooses: cash out or keep going.
- A global item roller exists (pure luck, high ceiling). Minigames are the reliable skill path. Neither may make the other pointless.
- Goal: each minigame on its own, and the set of minigames together, should be as compelling to replay as possible. Real gameplay with thought and risk, not a gambling button.

## What I need

### A. Games to study
For each: the verb (what the hands do), run length, the in-run risk choice, how failure is handled, how rewards are revealed, what makes players play again, and retention/session numbers where they exist.
Roblox: Fisch, Fish It, Grow a Garden, Pet Simulator 99, Blox Fruits, Steal a Brainrot, Dig It, Bee Swarm Simulator, Anime Defenders, mining/digging simulators.
Other: Peggle, Peglin, Balatro, Luck Be a Landlord, Vampire Survivors, Brotato, Hades, Slay the Spire, Deep Rock Galactic, Dark and Darker, Stardew Valley fishing and mining, WarioWare, Crossy Road, Subway Surfers, Candy Crush.

### B. Numbers I need (write "no number found" if none)
1. **Replay rate:** % of players who start another run immediately after finishing one.
2. **Mid-run quit rate:** typical % of runs abandoned, and what change in quit rate devs treated as "this stage is too hard".
3. **Difficulty targets:** target clear/win rates per level or stage that studios used (King, Rovio, Supercell, Roblox devs) for easy, hard and very hard content.
4. **Cash out or keep going:** in push-your-luck games, how often continuing is the correct choice, and how often players actually continue.
5. **Skill spread:** how far apart top-10% and bottom-10% players' results are in successful skill minigames, and what spread kept both groups playing.
6. **Feedback timing:** seconds between rewards/feedback, reveals and difficulty steps in proven short-run games.
7. **Difficulty curves:** per-step multipliers or targets across a run (e.g. Balatro ante targets) and how they decay.
8. **Bad-luck counters:** published counters (Genshin, Honkai, Arknights, FGO, Pet Sim, Fisch, Hypixel) - base rate, soft start, hard cap - and any data on effect on retention or spend.
9. **Multi-area games:** how long players stay in each area, % who reach area 2/3/later, value multiplier per area/zone, and what made players return to early areas.
10. **Run length vs session length:** runs per session in Roblox games.
11. **Co-op and social:** retention effect of playing with friends, shared goals, per-area leaderboards, server-wide announcements of rare finds.
12. **Item economy floods:** documented cases where a repeatable activity flooded an item market (Hypixel, RuneScape, Adopt Me, Pet Sim, Grow a Garden) - what the dev changed and what numbers moved.

### C. What makes it compelling
- Individually: feedback timing, escalation, near-misses the player controlled, choices with visible stakes and hidden outcomes, visible mastery, reveal staging, sound and juice.
- As a set: shared progression across minigames, one minigame's output feeding another, variety vs consistency, how multi-minigame games (Mario Party, WarioWare, Pet Sim zones, Fisch islands) move players between them instead of camping one.
- Risk through skill: push-your-luck where reading or skill changes the odds.
- Failures: minigames players abandoned and why (too long, too random, too hard, pay-to-win, economy inflated).

### C1. Dark and aggressive engagement techniques (search beyond the obvious)
Find every technique, from any industry, that strongly raises time-in-game and return rate, regardless of how it is viewed: gacha and mobile free-to-play (Genshin, Candy Crush, Clash Royale, Gardenscapes, Monopoly Go, Coin Master, Raid), casino and slot design (near-miss engineering, losses disguised as wins, sound and light design, variable ratio schedules, ludic loops), loot boxes, social obligation and loss mechanics (streaks, expiring rewards, FOMO events, crew obligations, gifting reciprocity, rivalry), sunk cost and endowment, notification and re-engagement timing, "one more run" design, anchoring and decoy pricing, scarcity timers, countdown pressure, rank decay. For each: how it works mechanically, the numbers (conversion, retention, session length, revenue lift, A/B results), where it was used, and how it could be applied to a short minigame loop that pays items. Include documented internal tests and leaked/postmortem data, not just marketing claims. Rank by evidence strength and measured effect size.

### C2. Presentation and feel (UX, audio, visuals) - as important as the gameplay
Cover every layer, with numbers (milliseconds, Hz, frames, sizes, counts) and sources:
1. **Sound:** what sounds play for each event (success, near-miss, fail, tick, reveal, jackpot, level-up, UI click); pitch-rising combo sounds; the gap between cue and reward; music (adaptive/layered music, tempo changes as tension rises, silence before a reveal); volume balance; how long sounds are; whether players mute and what that means for design.
2. **Visual feedback ("juice"):** screen shake, hit-stop/freeze frames, slow motion, particles, flashes, number pop-ups, squash and stretch, camera zoom/punch, bars filling; durations and intensities devs report (e.g. Vlambeer "Art of Screenshake", Jan Willem Nijman talk, Disney animation principles as applied to games).
3. **Reveal staging:** the sequence and timing of a reward reveal (silhouette, shake, rarity color, name, count-up); how long reveals last before players want to skip; skip/speed-up options; rarity color conventions and rarity-specific effects.
4. **UI and readability:** HUD layout for a 60-120 s run on mobile and PC (Roblox mobile is the majority of players); thumb reach zones; font sizes; how stakes (what you'd lose or gain by continuing) are shown; progress bars toward tiers; results screen design; one-tap replay button placement.
5. **Animation and world feel:** character/object animation timing, anticipation and follow-through, idle animations, environmental reactions, area art direction that signals "deeper = more valuable" (color palette, lighting, scale, props).
6. **Haptics and controls:** mobile vibration, input responsiveness (input latency tolerances in ms), touch vs mouse vs gamepad control design for the same minigame.
7. **Notifications and social visuals:** server-wide announcements, leaderboards, rare-find banners, overhead titles/badges, how long they show and how intrusive is too much.
8. **Onboarding presentation:** how the first run teaches by showing (arrows, highlights, forced first success), text amount per screen, voice/sound guidance.
9. **Failure presentation:** how soft-fail runs are shown so they feel like progress, not loss (wording, color, sound, what is shown first).
10. **Performance feel on Roblox:** frame-rate and load-time thresholds where players leave; particle/sound budgets on low-end phones.
Name specific games whose presentation is praised or credited for retention (Balatro, Peggle, Vampire Survivors, Hades, Fisch, Pet Sim 99, Grow a Garden, Candy Crush, Clash Royale) and say what they do concretely.

### D. Verify these claims
- Peggle slow-motion final peg and free-ball rule (PC Gamer).
- Balatro "skipping a blind is correct ~15-25% of the time".
- Vampire Survivors near-win effect (Howell, The Conversation, 2023).
- Fisch reel bar fills/drains ~12% per second.

### E. Pitch list
10 minigame concepts fitting the constraints (60-120 s, items only, skill sets tier, in-run cash out or keep going, soft fail, mobile + PC, buildable in Roblox). For each: verb, risk choice, what skill means, how a run escalates, which proven game it's based on. No slot machines or pure-luck mechanics.

## Output format
- One section per lettered part, numbered items inside.
- Final table: metric or mechanic, number found (or "no number found"), source, evidence level (dev-primary / scholarly / secondary), how it applies to our minigames.
