# Pass 13: minigames for the second map

Brief: `prompt-minigame-research.md`. This pass skips what `addictive-loops-synthesis.md` already holds (variable ratio, near-miss basics, pity meters, Balatro ante curve, Roblox session snapshots, Candy Crush tuning, Fisch dev notes, Grow a Garden low-demand pillar). Only new findings below. Sources are mostly wikis, press and forums; studio-primary sources are marked. Anything with no source is marked "unconfirmed".

## 1. Minigames that kept players replaying

**Stardew Valley fishing.**
- What the hands do: hold to raise a green bar, release to let it fall. The bar has momentum, so you nudge it with taps instead of chasing the fish. ([Stardew Valley Wiki, "Fishing Minigame"](https://stardew.wiki/fishing-minigame/); [Medium, "How to Fish in Stardew Valley"](https://medium.com/beyond-the-game/how-to-fish-in-stardew-valley-ed5b9d168771))
- Failure: a catch meter fills while the fish is inside the bar and drains while it is outside. When the meter empties, the fish gets away. You only lose the time you spent. (Stardew wiki, same page)
- Difficulty: fish move in five patterns ("mixed", "smooth", "sinker", and others), and rarer fish drain the meter faster. A higher fishing level makes the bar larger, so you can see your progress inside the minigame itself. ([Gamer Empire guide](https://gamerempire.net/stardew-valley-how-to-catch-fish/); Stardew wiki)
- Run length and retention numbers: unconfirmed.

**Fisch (Roblox): exact numbers for the reel phase.**
- Shake phase: each shake cuts 0.5 to 1.5 s off the wait for a bite, and missing one shake prompt restarts the cast. ([Official Fisch Wiki, "Fishing"](https://fischipedia.org/wiki/Fishing))
- Reel phase: progress rises or falls by 12% per second depending on whether the fish is inside the player's bar. At 0% the line snaps. So a perfect reel takes about 8 s. (Fischipedia; the 8 s figure is our arithmetic.)
- Gear stats change the controls, not the payout. "Resilience" makes the fish move less, and "Control" makes the player's bar wider. (Fischipedia)
- Players script auto-shake and auto-reel, so a timing minigame on Roblox will get automated. ([ScriptBlox listing](https://scriptblox.com/script/Fisch-Best-Auto-Shake-Auto-Reel-OP-71026))
- There is an open-source Roblox recreation you can read before building: ([littensy/fishing-minigame on GitHub](https://github.com/littensy/fishing-minigame))

**Peggle.**
- PopCap's studio director Sukhbir Sidhu based it on pachinko. ([Peggle wiki, "Making of Peggle"](https://peggle.fandom.com/wiki/Peggle_Deluxe/Making_of_Peggle))
- "Extreme Fever" (a rainbow plus Ode to Joy when you clear the last orange peg) began as a joke. It stayed because testers loved it. (Same source; [PC Gamer, "The Making of Peggle" p.2](https://www.pcgamer.com/the-making-of-peggle/2/) — page body could not be fetched)
- Press called it a "gradual addiction". ([NBC News](https://www.nbcnews.com/id/wbna18221146))
- The slow-motion last peg and the free-ball bucket: no source fetched, unconfirmed.

**Vampire Survivors.**
- A run counts as a success only if you survive 30 minutes. Runs that end short of that feel like near-wins, which Howell compares to the slot-machine near-miss. ([P. Howell, The Conversation, 13 Apr 2023](https://theconversation.com/vampire-survivors-how-developers-used-gambling-psychology-to-create-a-bafta-winning-game-203613))
- Gold earned in a run is spent between runs on upgrades. The game alternates stretches where you dominate with stretches of rising tension. (Same source)
- The developer previously worked on mobile gambling games. ([PC Gamer](https://www.pcgamer.com/vampire-survivors-saved-its-creator-from-working-on-mobile-gambling-games/))

**Balatro.**
- Every hand scores as Chips × Mult. The design work is in the feedback: each chip and multiplier is counted up on screen with animation, particles and sound. ([Wikipedia, Balatro](https://en.wikipedia.org/wiki/Balatro); [Blake Crosley, "Balatro: Juicy Feedback"](https://blakecrosley.com/guides/design/balatro))
- The chips-times-mult system existed from the earliest prototype. ([LocalThunk, "The Balatro Timeline"](https://localthunk.com/blog/balatro-timeline-3aarh), dev-primary)
- It sold more than 5 million copies by January 2025. (Wikipedia)
- It was inspired by Luck Be a Landlord. (Wikipedia)

**Luck Be a Landlord.**
- You build your own slot machine to pay rent that rises at each deadline. The developer wanted a slot game without predatory microtransactions. ([Wikipedia](https://en.wikipedia.org/wiki/Luck_Be_a_Landlord))
- The lesson: luck stops feeling like gambling when the player builds the machine and the target is fixed and visible ahead of time. (This is our interpretation.)

**Crossy Road.**
- An endless Frogger. A run ends on a single hit. It earned $10M in its first three months and reached 50M downloads within its first few months. ([Wikipedia, Crossy Road](https://en.wikipedia.org/wiki/Crossy_Road))
- Retention numbers: unconfirmed.

**Candy Crush and Subway Surfers.**
- Candy Crush sessions average about 15.8 minutes, and players open the game about 4.2 times a day. This is a secondary source, so the method is unknown. ([Udonis blog](https://www.blog.udonis.co/mobile-marketing/mobile-games/most-played-mobile-games))
- Subway Surfers session length: unconfirmed. For design notes see [Game World Observer, "Subway Surfers: a Gameplay Analysis"](https://gameworldobserver.com/2016/06/24/subway-surfers-gameplay-analysis).

**Not researched this pass:** Dig It, Fish It, Brotato, Hades, Slay the Spire, Steal a Brainrot. Hades and Slay the Spire are partly covered in the synthesis.

## 2. What makes one short minigame compulsive

- **A reel bar with momentum creates skill without reflex spam.** Stardew's sliding bar rewards tapping and reading the fish ahead of time. Fisch's 12%-per-second rate gives a readable, steady fill. (Sources in section 1)
- **Gear should change the controls, not the dice.** Fisch's resilience and control stats make the minigame easier without raising drop odds, so better gear shows up as visibly better skill. (Fischipedia)
- **Make the reveal an animation, not a number.** Balatro counts its score up step by step. Peggle's Extreme Fever turns the end of a level into a celebration. (Crosley; Peggle wiki)
- **A clear success line turns a failed run into a near-win.** Vampire Survivors' 30-minute line does this. (Howell 2023)
- **Microgames under 5 s that speed up across a chain.** WarioWare chains random microgames shorter than 5 s, each with a single goal ("collect coins", "press A on time"), and speeds up and gets harder as the chain goes on. ([Wikipedia, WarioWare](https://en.wikipedia.org/wiki/WarioWare); [Gingold, Game Studies 5(1)](https://www.gamestudies.org/0501/gingold/)) For us, a 60-120 s run can be built from short beats that get faster.

## 3. What makes a set of minigames compulsive together

- **WarioWare: randomness plus a speed ramp.** Variety comes from the random order. Consistency comes from every microgame sharing one input and one rising speed. (Wikipedia; Gingold)
- **Pet Simulator 99: zones, rebirths, and clan battles move players around the map.**
  - New zones unlock through quests. Each rebirth raises egg luck while enemies get tougher.
  - Clan battles last 1-2 weeks, give points for specific activities, and pay tiered rewards.
  - Changing which activities earn clan points is a lever for pulling players into different areas. (This is our inference.)
  - Sources: [Pet Sim fandom, "Clans"](https://pet-simulator.fandom.com/wiki/Clans_(Pet_Simulator_99)); [BIG Games update posts](https://www.biggames.io/post/pet-simulator-99-update-27); [dungeonpath clan guide](https://dungeonpath.com/posts/pet-simulator-99/clan-battles-guide/)
- **Grow a Garden: server-wide weather multipliers pull everyone to one activity at once.**
  - In Grow a Garden 2, every garden on the server gets the same weather. Each weather type applies its own mutation multiplier: Frozen ×14, Gold ×10, Electric ×25, Rainbow ×30, Bloodlit ×60.
  - "Admin abuse" sessions run about an hour before each Saturday update.
  - Sources are fan trackers, so these are medium evidence. ([mygagcalculator](https://mygagcalculator.com/all-weather-events-grow-a-garden/); [bloxultra](https://bloxultra.com/tools/grow-a-garden-2-weather); [bloxboom](https://bloxboom.com/blog/grow-a-garden-2-admin-abuse))
- **Rotating a featured area.** Making one area "featured" for a while with a boosted tier, so players don't camp one area: unconfirmed as a tested technique, extrapolated from the above.

## 4. Risk mechanics that are not gambling

- **Extraction: leave now or go deeper.**
  - Dark and Darker lets players either leave the dungeon or go deeper for better loot. ([Dot Esports](https://dotesports.com/indies/news/how-to-extract-in-dark-and-darker))
  - In Tarkov, raids often fail from greed ("one more bag") rather than poor aim. ([TEDx Stanley Park article](https://tedxstanleypark.com/the-psychology-of-tarkov-how-fear-greed-and-risk-shape-every-raid-you-play/), secondary)
  - Our soft-fail rule means you can't lose items. The stake has to be the tier earned so far in this run (for example, the run drops one tier).
- **A tension bar where skill changes the odds.** In Fisch and Stardew, the risk is real but entirely in the player's hands, with no hidden dice. (Section 1)
- **Roblox rules.** ([Creator Hub, "Paid random items"](https://create.roblox.com/docs/production/monetization/paid-random-items), official)
  - Rewards given for completing an action that costs no Robux do not need published odds.
  - Anything bought with Robux, or with currency bought with Robux, counts as paid random. That includes luck boosts and pity systems. Paid random items need every outcome and its exact odds shown, and every outcome must give the player something.
  - Rule for us: never sell a minigame entry, retry, or luck boost for gems. If we do, the minigame becomes a paid random item and we must disclose its odds.
  - Korean loot-box law pushed Roblox to show odds worldwide. ([TechTimes, 26 Jun 2026](https://www.techtimes.com/articles/319148/20260626/koreas-loot-box-rules-push-roblox-disclose-item-odds-worldwide.htm))

## 5. Co-op and social layers

- **Clan point races with tiered rewards.** Pet Sim 99 runs these over 1-2 weeks, with leaderboards sorted by daily points. ([petsimstats](https://www.petsimstats.com/clans))
- **Shared server events.** Grow a Garden weather affects every garden on the server, and admin sessions are announced in-game. (Section 3 sources)
- **Numbers.** No new retention figures for co-op inside minigames were found. The synthesis already has "friends playing together +70%".

## 6. Failures

- **Hypixel Skyblock: influencers flooded the dragon economy.**
  - YouTubers promoted dragon farming. Demand spiked, then dragon drops flooded the market and their prices collapsed.
  - Adding a guaranteed-drop meter ("RNG meter") with Floor 7 raised the supply of rare drops. That caused a shortage, and a price spike, of the items those drops needed.
  - Players argue that raising drop rates cheats people who already grinded for those items.
  - Sources are player forums, so these are medium evidence. ([Hypixel forum, "downfall of the economy"](https://hypixel.net/threads/im-praying-im-hoping-the-eventual-downfall-of-the-hypixel-skyblock-economy.2379584/page-4); ["A Look into Hypixel Skyblock Economy and Inflation"](https://hypixel.net/threads/a-look-into-hypixel-skyblock-economy-and-inflation.5364265/); ["Inflation, Proposed Fixes"](https://hypixel.net/threads/inflation-proposed-fixes-and-the-associated-issues-effort.4765757/))
  - Lesson: a pity counter that lets players choose the item, used in a repeatable minigame, mints a predictable supply. Cap it, or make it guarantee a tier and not a specific item.
- **Fisch: timing minigames get automated.** Auto-shake and auto-reel scripts exist. Validate input server-side, and randomise timing windows. (ScriptBlox)
- **Abandoned because too long, too random, or pay-to-win:** no new primary case found. Unconfirmed.

## 7. Pitch list (10 concepts)

Every concept follows the brief: 60-120 s runs, items only, performance sets the tier and RNG picks the item inside it, a bad run still pays the bottom tier, a hidden counter guarantees a good tier, and it works on mobile and PC.

1. **Reel Line (Area 1)**
   - Based on: Stardew and Fisch fishing.
   - Verb: hold or release a bar that has momentum, to keep a moving target inside it.
   - Risk: after each catch, keep the line in for a harder fish (more tier points), or bank what you have.
   - Skill: reading the fish's movement pattern.
   - Escalation: fish patterns shift from "smooth" to "sinker" types.
2. **Peg Drop**
   - Based on: Peggle.
   - Verb: aim and fire a ball.
   - Risk: aiming at bonus pegs pays more but risks losing the ball.
   - Skill: predicting angles and bounces.
   - Escalation: fewer balls left. Clearing every target triggers a fever bonus tier.
3. **Delve**
   - Based on: Dark and Darker extraction.
   - Verb: move and dodge through rooms.
   - Risk: at each exit door, leave with your current tier or go one room deeper. A hit drops you one tier.
   - Skill: dodging and route reading.
   - Escalation: each room is faster and denser.
4. **Hand of Five**
   - Based on: Balatro.
   - Verb: pick cards to play from a dealt hand.
   - Risk: limited discards. Hold out for a bigger combo, or play the safe hand now.
   - Skill: combo planning.
   - Escalation: the score target rises each round.
5. **Rent Reels**
   - Based on: Luck Be a Landlord.
   - Verb: choose which symbol to add to a small reel between spins.
   - Risk: a quota is due every 3 spins. Over-reach and you miss it, and the run ends at that tier.
   - Skill: building a combo engine. Spins are random, but the player builds the reel.
   - Note: no paid spins, to stay outside the paid-random rules.
6. **Micro Rush**
   - Based on: WarioWare.
   - Verb: one tap or swipe per microgame (each under 5 s).
   - Risk: you have 3 lives. Spend one on "skip" or push through.
   - Skill: reaction time and reading instructions.
   - Escalation: speed ramps every 4 games.
7. **Survive the Swarm**
   - Based on: Vampire Survivors.
   - Verb: move (attacks are automatic) and pick upgrades.
   - Risk: grab an elite drop that sits inside the swarm.
   - Skill: positioning and upgrade picks.
   - Escalation: waves thicken. Surviving 90 s is a visible success line.
8. **Hop Lane**
   - Based on: Crossy Road.
   - Verb: hop forward or sideways.
   - Risk: gem-colored "lanes of value" lie off the safe path. One hit ends the run, but you keep your banked distance tier.
   - Skill: timing gaps.
   - Escalation: traffic speeds up.
9. **Dig Line**
   - Based on: mining and digging simulators. Specific source: unconfirmed.
   - Verb: tap tiles to dig down while a cave-in meter rises.
   - Risk: dig deeper for rarer ore, or climb out before the meter fills. A cave-in keeps half your tier.
   - Skill: choosing a path through tile hardness you can see.
   - Escalation: harder tiles, and the meter rises faster.
10. **Weather Harvest (server co-op)**
    - Based on: Grow a Garden weather and Pet Sim clan races.
    - Verb: plant and harvest timing on shared plots.
    - Risk: wait for a server weather multiplier, or harvest now before the plot wilts.
    - Skill: reading the timing.
    - Escalation: an area-wide goal bar raises everyone's tier floor when it fills. The floor is capped, to protect supply.

## Final table

| Mechanic | Evidence | How it applies to us |
|---|---|---|
| Tension bar with momentum (Stardew/Fisch) | Strong (wikis agree, numbers given) | Core control for Reel Line; 12%/s fill gives about 8 s per catch |
| Gear changes controls, not drop odds (Fisch resilience/control) | Medium | Area upgrades widen the bar; keep item odds fixed per tier |
| Action rewards exempt from odds disclosure; paid luck or retries not exempt | Strong (Roblox official) | Never sell minigame entries, retries or boosts for gems |
| Step-by-step score count-up and celebration reveal (Balatro, Peggle) | Medium | Stage every tier reveal; count the score up |
| Visible success line makes failure feel close (Vampire Survivors) | Medium (academic op-ed) | Show the tier thresholds during the run |
| Microgames under 5 s that speed up (WarioWare) | Strong | Build 60-120 s runs from short beats that get faster |
| Extract-or-go-deeper choice (Dark and Darker, Tarkov) | Medium | The stake is this run's tier, never inventory |
| Server-wide multipliers move players together (Grow a Garden weather) | Medium (fan trackers) | Rotate a featured area with a temporary boost |
| Timed clan point races with tiered rewards (Pet Sim 99) | Medium | Area leaderboards; the scored activity rotates |
| Pity counter that lets players choose the item floods supply (Hypixel RNG meter) | Medium (forums) | Pity guarantees a tier, not an item; cap it per day |
| Timing minigames get automated by scripts (Fisch) | Medium | Server-side validation; randomised timing windows |
| Player-built luck feels fair (Luck Be a Landlord) | Medium | Rent Reels concept; quota shown in advance |
| Candy Crush 15.8 min per session, 4.2 sessions a day | Unconfirmed method (secondary) | Context only |
| Featured-area rotation keeps players from camping one area | Unconfirmed | Test with analytics |
