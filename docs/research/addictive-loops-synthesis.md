# Addictive loops: consolidated synthesis (all research passes)

Source of record for the full cited reference: `addictive-loops-reference-full.md` (same folder). This file is the digest used for design decisions. Tags: [scholarly] / [dev-primary] / [secondary]. Items marked (unconfirmed) had no primary source retrieved.

## Mechanical tier test (dark / ultra dark are mechanical labels, not moral ones)
- **Normal:** transparent, self-limiting, player has full information.
- **Dark:** the decision point itself is engineered (timers, difficulty walls, continue-offers shown at the moment of failure).
- **Ultra dark:** the reward channel misleads (win-sound on a net loss), loss is socialised onto other players, a gambling surface is disguised as non-gambling content, or the cost of stopping exceeds any in-game loss.

## Core mechanisms (cross-genre)
- **Variable ratio** is the strongest schedule, but only works as a layer on top of real activity. A bare RNG button is gambling, not gameplay.
- **Near-miss** only works when the player can see how close they were, and when the player had some control over the attempt.
- **Goal gradient / endowed progress** (Kivetz 2006; Nunes & Dreze 2006): effort accelerates near a goal; a visible head start raises completion. Used in the cashout bar (7% tutorial head start, decaying-band curve, ratcheted peak).
- **Endowment / IKEA effect:** owned and self-made items are overvalued; effort only attaches value when the task completes (a failed craft that yields nothing breaks it).
- **Loss aversion:** an expiring advantage drives returns; destroying completed work drives exits.
- **Pity / guarantee meters:** hidden counter, N failures guarantees a strong result; players self-track and that tracking is engagement (Genshin: 0.6% base, soft pity ~74, hard 90).
- **Self-determination theory:** autonomy (choose route/risk/loadout), competence (visible mastery), relatedness (shared boards, crews, co-play). Pure extrinsic reward erodes interest (overjustification).

## Numbers worth designing against
- **Run length:** compact attempt 2-4 min (match-3 level, Clash Royale 3+1); Roblox hit sessions 14-25 min average (Grow a Garden ~17, Steal a Brainrot ~14, Blox Fruits ~20, Pet Sim 99 ~114 per tracker snapshot). Third-party snapshots, not studio telemetry.
- **Feedback cadence:** something visible every 1-6 s during active play; a reveal every 20-60 s; an escalation beat every 60-90 s. Slot-machine outcome cycle 3-6 s [scholarly].
- **Decision cadence:** a real bank-or-push choice every 60-90 s, stakes visible, outcome hidden (Balatro: see your engine, not the result).
- **Escalation shapes:** decaying multiplier (Balatro ante targets 300 > 800 > 2k > 5k > 11k > 20k > 35k > 50k, ~2.5x early decaying to ~1.4x); programmatic shrink (PUBG/Fortnite storm); exponential cost vs linear income with prestige reset (idle games; prestige doubling costs 4x-128x).
- **Failure penalty spectrum:** none (idle, Grow a Garden) > attempt cost (Candy Crush life) > rank cost (Clash Royale, League) > run loss with meta kept (Balatro, Slay the Spire) > gear loss with partial keep (Tarkov, Hunt) > stake loss/theft (slots, Steal a Brainrot). Roblox hits cluster at the soft end.
- **King (Candy Crush) tuning evidence [dev-primary]:** over-hard levels raise short-term conversion but churn players; easier tuning retained them and compounded later spend ("retention always wins"). Hard levels should be short.
- **Slay the Spire metrics [dev-primary]:** balance to percentiles, not averages; items found late in a run look overpowered purely from timing of acquisition.

## Roblox-specific findings
- **First 30 seconds:** one developer's 3-month tracking found 45% of players leave within 30 s; shortening onboarding moved D1 6% > 15% and session 7.5 > 9.5 min [dev-primary, self-report]. Another game with a 50% tutorial completion and a breakable first egg had ~1% D1 and ~3 min sessions. The first attempt at anything must be protected and guaranteed to succeed.
- **Funnel bug example:** Space Simulator X lost 47% of players before the first egg because the first area paid ~90% too little; fixing pricing fixed the funnel [dev-primary].
- **Tizzy RBLX (own game, dashboard):** 13.1k CCU, ~$25k/month, 42 min average playtime, D1 21-31% depending on cohort; credits PvP depth, sunk cost from base building, visible rarity teasing, scheduled events, removing auto-roll [dev-primary].
- **Grow a Garden (Jandel) [dev-primary]:** offline growth is the credited core hook; design pillar is low demand ("most players can achieve the chase goal each week"); weekly updates; peak ~22M CCU.
- **Fisch (WoozyNate) [dev-primary]:** multiple end goals for retention; per-fish resilience stat as the difficulty dial; mutations as near-infinite collection surface; rods differentiated by use case; event hunts every 30-60 min; ~470k CCU peak.
- **Adopt Me (Uplift) [dev-primary]:** weekly content cadence, collection and trading as the social layer; 1.92M CCU on one egg-update event.
- **Roblox experiments data [dev-primary via Roblox]:** tuning difficulty to a sweet spot gave +50% payer conversion; a free end-of-obby item +12.5% playtime; friends playing together +70% retention.
- **Failure penalty on Roblox:** Blox Fruits, Pet Sim, Fisch cost time not inventory. Steal a Brainrot is the hard-loss exception and the one with the most documented player anxiety.
- **Platform signal:** recommendations weight D1/D7/D28 retention, session quality, spend; first-session onboarding target 5 minutes or less (Roblox Creator Hub).

## Gaps (unverified)
Zurpz, Fireology, Lolzou, AlvinBlox/SmartyRBX retention numbers; BruceDevs in-video mechanics; Candy Crush life-refill timer; exact Tarkov raid timers; Balatro ante numbers beyond wiki data.
