# Research Brief — Wait Tolerance & Roblox KPI Maximisation

**For:** an AI research agent with web access.
**Context:** Roblox item-trading economy game. Async trading (orders accumulate
while offline). Monetisation includes paid trade-ad boosts. Solo developer,
weak at art/VFX/modelling — do not propose art-heavy solutions.

**Read `INFO.md` in this repo first** for the full game description.

---

## Why this brief exists

Two questions could not be answered from existing literature and need
dedicated research:

1. How long can a player's pending order sit before the wait costs more
   retention than it builds?
2. What concrete, already-validated mechanics would move our weakest Roblox
   KPI bucket?

A 2024 CHI PLAY literature review ("Towards Understanding Waiting in Video
Games", Tepponen et al.) confirms there is **no comprehensive academic answer**
to Q1 — the field is explicitly scattered. So this needs primary-ish sourcing:
postmortems, GDC talks, dev blogs, analytics vendor reports, and reverse-
engineering of shipped games.

---

## What we already know (do NOT re-research these)

- Roblox's Recommended For You algorithm (June 2026) uses a 28-day window.
  Signals, measured across D1 / D2-7 / D8-28: playtime, play days, qualified
  play sessions, **intentional co-play days** (headline signal), spend days,
  Robux spent. Qualified play-through rate was removed and split into
  play-through rate, first-play bounce rate, session quality, spend.
- Roblox categorises games by passing thresholds per KPI. Score behaves like a
  MIN, not an average — the weakest KPI determines the bucket.
- Roblox median session: 12-18 min. D1 retention median ~22-27%.
  ARPDAU ~$0.05-0.15.
- Grow a Garden: avg session UNDER 12 min, seed shop refreshes every 5 min,
  offline crop growth, 1B visits in 33 days.
- PS99 Trading Plaza: 60s auctions, any bid in final 15s resets timer to 15s.
  Cross-server Trading Terminal with teleport.
- Steal a Brainrot: 25M+ CCU, stealing alerts the victim -> revenge loop.
- Monopoly Go partner events: shared progress bar with a specific friend.
- Mabinogi auction house: 6h min / 36h max listing, 48-60h for paid tiers.
  Paid tiers buy longer EXPOSURE, not faster fills.
- Maister's waiting principles (occupied/uncertain/unexplained).
- Buell & Norton labor illusion (visible effort raises perceived value).
- Async multiplayer ~30% higher 6-month retention vs sync.
- Hybrid short+long progression ~19% higher D30 vs linear.

---

## Question 1 — Wait tolerance in async trading/marketplace games

**Core question:** For a game where orders fill while the player is offline,
how long should an order remain unfilled before it stops driving return visits
and starts driving churn?

Find:

1. **Shipped listing/order durations and their rationale.** WoW, FFXIV, EVE,
   OSRS Grand Exchange, Warframe, Path of Exile, Albion, Mabinogi, Steam
   Community Market, PS99, Adopt Me, Rolimon's trade ads. For each: default
   duration, max duration, whether paid tiers extend it, and any dev
   commentary on WHY those numbers.
2. **Published abandonment / time-to-churn curves.** Any game or analytics
   vendor that has published how unfilled-request latency correlates with
   return rate or churn. GameAnalytics, deltaDNA, Unity Analytics, AppsFlyer,
   GameRefinery, Naavik, Deconstructor of Fun.
3. **Appointment-mechanic interval data.** What return intervals are actually
   used by high-retention games, and is there evidence on which intervals
   maximise play DAYS specifically (as opposed to sessions or minutes)?
   Especially: intervals designed to straddle sleep.
4. **The anticipation/frustration crossover.** Any empirical work on where a
   wait flips from positive anticipation to negative. Includes non-games:
   food delivery, ride-hailing, e-commerce shipping, dating apps.
5. **Counter-evidence.** Cases where reducing wait times HURT retention or
   revenue. Specifically look for instant-fill or auto-match features that
   were reverted.

**Deliverable:** a recommended default order duration, a recommended
"guaranteed eventual fill" backstop, and the reasoning, with sources. Flag
explicitly where you are extrapolating rather than citing.

---

## Question 2 — Paid boosts vs free fills

We sell trade-ad boosts. A bot that fills orders quickly for free would
undercut that.

Find:
- How shipped games price and position paid visibility in player markets
  without cannibalising it with free convenience.
- Whether "pay for exposure/duration" outperforms "pay for speed" in
  marketplace monetisation, and evidence either way.
- Any data on how paid-visibility features affect spend DAYS (frequency)
  vs total spend, given Roblox scores these separately.

---

## Question 3 — Mechanics to lift each KPI

For each Roblox signal below, find 3-5 **specific, shipped, validated**
mechanics, with the game that used it and any published effect size.
Exclude anything requiring significant custom art, VFX, or modelling.

- **First-play bounce rate** — first 60 seconds.
- **Session quality / playtime** — what keeps a trading-game session alive
  past the 90 seconds the core loop actually takes. Especially mechanics that
  are NOT currency sinks (players avoid those).
- **Play days** — daily-cadence hooks beyond generic daily rewards.
- **Intentional co-play days** — THE highest-weighted signal and our biggest
  gap. Our trading is anonymous and async; nothing requires a specific friend.
  Find co-op mechanics validated in trading/economy games specifically.
- **Spend days (frequency, not total)** — mechanics producing many small
  purchase days rather than few large ones.
- **D8-28 retention** — long-horizon progression in economy games.

---

## Question 4 — Trading-game specific retention teardowns

Deep teardowns of the retention and economy design of: Adopt Me, Pet Simulator
99, Grow a Garden, Steal a Brainrot, Murder Mystery 2, Blox Fruits, Trade
Hangout, plus non-Roblox comparators (Warframe, Team Fortress 2, CS2, Path of
Exile, Neopets, Animal Crossing turnip market).

For each: what specifically drives return visits, how trading is made social,
how they handle low-population hours, and what they monetise in the trading
layer.

---

## Constraints on recommendations

- No teleporting between servers (resets playtime, harms our rating).
- Never grant free currency unless it was earned from a real trade or paid for.
- No art-heavy, VFX-heavy, or model-heavy proposals.
- Market manipulation by players is acceptable — treated as a feature.
- Do not propose escrow, rate limits, or heavy anti-abuse machinery.
- Prefer mechanics a solo dev can ship.

## Output format

For each question: findings with inline source links, then a short
"what I'd do" section. Separate **cited fact** from **inference** explicitly.
State clearly where evidence does not exist rather than filling the gap.
