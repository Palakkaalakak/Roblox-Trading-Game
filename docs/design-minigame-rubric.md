# Minigame + loop rubric (second map)

Rule for this file: every criterion is either (a) a number with a cited source, or (b) a metric we measure ourselves, marked **[no external number]**. For (b), the target is set from our first playtest baseline; nothing here invents a figure. Sources are in `research/` (synthesis, reference-full, pass-13-minigames).

Tiers: Not Achieved / Emerging / Developing / Applying / Exceeding.
Ship threshold: Applying on every row, Exceeding on starred (*) rows.

Metric definitions used below:
- **30-s bounce:** % of players who leave the game within 30 s of first entering Area 1.
- **Mid-run quit:** % of runs abandoned before the run ends.
- **Replay rate:** % of finished runs followed by another run within 10 s.
- **Gap:** seconds between visible reward/state changes during a run (from telemetry or video frame count).

## Part A - per minigame

### A1* First run
- Not Achieved: first run can pay nothing.
- Emerging: first run pays something for <100% of players.
- Developing: first run pays a guaranteed good result for 100% of players.
- Applying: first reward <=30 s after entering; 30-s bounce measured.
- Exceeding: 30-s bounce below 45%.
- Sources: 45% of players left within 30 s, and cutting onboarding moved D1 6% to 15% (DevForum dev self-report); a breakable first egg gave ~1% D1 (DevForum); Roblox onboarding target <=5 min (Creator Hub).

### A2* Run length and re-entry
- Not Achieved: run >240 s, or a load screen between runs.
- Emerging: run length varies more than 2x between runs, or >2 clicks to re-enter.
- Developing: run 60-120 s, re-entry in <=2 clicks.
- Applying: run 60-120 s, 1 click, 0 s load.
- Exceeding: replay rate above baseline after tuning **[no external number]**.
- Sources: compact attempt 2-4 min (Candy Crush level, Clash Royale 3+1 min); WarioWare microgames <5 s each (pass-13); Roblox hit sessions 14-25 min average (tracker snapshots).

### A3* Feedback cadence
- Not Achieved: max gap >10 s, or one payout at run end only.
- Emerging: average gap 6-10 s.
- Developing: average gap <=6 s.
- Applying: gap 1-6 s; a reveal every 20-60 s; an escalation step every 60-90 s.
- Exceeding: Applying, plus every success has a cue before the reward.
- Sources: slot outcome cycle 3-6 s [scholarly]; 1-6 s / 20-60 s / 60-90 s cadence (synthesis); Fisch catch ~8 s at 12%/s reel fill (pass-13, arithmetic from wiki).

### A4* Cash out or keep going
- Not Achieved: no in-run choice.
- Emerging: choice exists, but >90% of players pick the same option every time **[no external number; "obvious choice" proxy]**.
- Developing: choice every 60-90 s, stakes shown.
- Applying: as Developing, outcome hidden until chosen.
- Exceeding: "keep going" is the correct choice roughly 15-25% of the time.
- Sources: Balatro skip correct ~15-25% (synthesis, wiki-level, unconfirmed by dev); 60-90 s decision cadence (synthesis).

### A5 Pre-run choices
- Not Achieved: 0 choices.
- Emerging: choices are cosmetic only.
- Developing: >=1 choice (loadout / route / risk level) that changes the run.
- Applying: no single option is picked in >80% of runs **[no external number]**.
- Exceeding: >=2 choices interact (e.g. consumable x risk level).
- Source: Fisch rods differ by use case, gear changes controls not odds (pass-13).

### A6 Skill
- Not Achieved: top-10% and bottom-10% players get the same average tier.
- Emerging: they differ by <1 tier.
- Developing: performance sets the tier.
- Applying: top-10% average tier >= 1 tier above bottom-10% **[no external number]**.
- Exceeding: mastery rank unlocks new options; per-player tier rises over first 20 runs **[no external number]**.
- Source: balance to percentiles, not averages (Slay the Spire GDC).

### A7 Difficulty curve
- Not Achieved: difficulty flat across the run.
- Emerging: rises, but mid-run quit spikes at one stage.
- Developing: rises every stage.
- Applying: step multiplier decays (example: ~2.5x per step early, ~1.4x late).
- Exceeding: mid-run quit does not spike at any stage, and replay rate holds **[no external number]**.
- Sources: Balatro ante targets 300>800>2k>5k>11k>20k>35k>50k (~2.5x decaying to ~1.4x, wiki); tuning difficulty to a sweet spot gave +50% payer conversion (Roblox experiments); over-hard levels churned players (King).

### A8 Near-miss
- Not Achieved: a miss shows no distance to success.
- Emerging: distance shown only sometimes.
- Developing: distance to next tier always shown.
- Applying: the miss came from a player action (not a random roll).
- Exceeding: tier thresholds shown during the run.
- Sources: near-miss only motivates when the player had control (Clark 2009); Vampire Survivors visible 30-min goal makes short runs read as near-wins (Howell 2023, pass-13).

### A9* No-loss floor and bad-luck counter
- Not Achieved: a bad run pays 0 or costs items.
- Emerging: floor exists for <100% of runs.
- Developing: 100% of runs pay the floor.
- Applying: hidden counter guarantees a strong tier after N bad runs; counter guarantees a TIER, never a chosen item, and is capped.
- Exceeding: as Applying, with N tuned from data.
- Sources: Genshin 0.6% base, soft pity ~74, hard 90; Hypixel chosen-item pity flooded rare supply (forums, pass-13).

### A10 Reward structure
- Not Achieved: RNG decides the tier.
- Developing: performance sets tier, RNG picks item in tier.
- Applying: plus a small jackpot chance.
- Exceeding: staged reveal (count-up, rarity color) and server announcement for jackpots.
- Sources: Balatro step-by-step score count; Peggle "Extreme Fever" kept after testers loved it (pass-13).

### A11 Variety
- Not Achieved: same verb in 2+ areas.
- Developing: each area a different verb, same structure.
- Applying: item variants (mutations) per item.
- Exceeding: new content on a weekly cadence.
- Sources: Fisch ~25 mutations per fish; Adopt Me / Grow a Garden weekly updates (synthesis).

### A12 Rewards granted by server
- Not Achieved: client grants items.
- Applying: server grants the reward (standard Roblox remote pattern). Nothing more; no anti-bot or rate-limit work.

### A13 Progress per run
- Not Achieved: a run leaves nothing.
- Developing: 100% of runs advance something persistent.
- Applying: end screen shows what advanced.
- Exceeding: end screen names one goal at >=70% progress **[no external number for 70%]**.
- Source: goal gradient (Kivetz 2006); endowed progress (Nunes & Dreze 2006).

### A14 Clip-worthy moments
- Developing: big result readable in one screenshot.
- Applying: rare finds get a staged moment.
- Exceeding: server announcement on rare finds.
- Source: Tizzy clippability pillar (dev-primary).

## Part B - whole loop

### B1* Closed loop
- Developing: field items usable in Crafter, Roller, Unique Crafts, Market (4 of 4).
- Applying: worth unlocks next area.
- Exceeding: % of field items that get used (crafted, rolled, traded, UC) within 24 h measured and rising **[no external number]**.

### B2* Two paths
- Not Achieved: >90% of item value gained comes from one path **[no external number]**.
- Developing: Roller ceiling > best minigame tier; minigame variance < Roller variance.
- Applying/Exceeding: % of sessions using both Roller and a minigame measured and rising **[no external number]**.

### B3 Unlock bar
- Developing: next area visible with pool shown.
- Applying: bar starts with a head start.
- Source: 7% tutorial head start used in cashout bar; endowed progress raised completion (Nunes & Dreze 2006).

### B4* Items in vs out
- Not Achieved: 0 sinks.
- Developing: per-area pool caps + consumable burn.
- Applying: reserve per rarity monitored; items entering vs leaving per day logged.
- Exceeding: items leaving / items entering >= target ratio **[no external number]**.
- Source: Hypixel pity price spikes (pass-13).

### B5 Low-tier demand
- Developing: UC counts for low-tier items rise with progress.
- Applying: % of low-tier trades where buyer is a deeper-area player **[no external number]**.

### B6 Reasons to return
- Developing: >=1 timer on an hours scale.
- Applying: >=3 timers on different schedules.
- Sources: Fisch events every 30-60 min; Pet Sim clan races 1-2 weeks; Grow a Garden weekly (synthesis, pass-13).

### B7 Return payoff
- Developing: something resolves while offline.
- Applying: return screen shows it.
- Source: Grow a Garden offline growth as core hook (dev-primary).

### B8 Status
- Developing: per-area leaderboard.
- Applying: rank visible in world.
- Exceeding: server announcement of rare finds.

### B9 Co-op
- Developing: 100% solo-playable.
- Applying: playing with a friend measurably raises reward per minute **[no external number]**.
- Source: friends playing together +70% retention (Roblox DevRel).

### B10 Session shape
- Developing: average session 14-25 min.
- Source: Grow a Garden ~17, Steal a Brainrot ~14, Blox Fruits ~20 min (tracker snapshots).

### B11* Tutorial
- Developing: starter > Area 1 run > Crafter.
- Applying: plus guaranteed UC + optional trade.
- Exceeding: tutorial completed in <=5 min by the median player.
- Source: Roblox onboarding <=5 min (Creator Hub); 50% tutorial completion game had ~1% D1 (DevForum).

### B12* Gem rule
- Exceeding: automated test fails on any gem grant outside Robux purchase / ads; nothing about a minigame (entry, retry, boost, pity) sold for gems.
- Source: Roblox paid random item policy (pass-13).

### B13 Consistency
- Developing: all minigames share run length, cash-out step, floor, counter.
- Applying: shared code.

### B14 Telemetry
- Developing: log tier, cash-out choice, run length, quit point per run.
- Applying: balance to percentiles.
- Source: Slay the Spire GDC.

## Pre-build checklist (per minigame)
Verb; pre-run choices; cash-out moment; step multipliers; tiers + jackpot + counter N; floor; server validation; systems fed; "pays items, not gems".
