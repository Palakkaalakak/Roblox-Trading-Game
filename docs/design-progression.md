# Tutorial + Core Quest Progression (design)

> **IMPLEMENTED (current truth, supersedes tables below):** core strategy (roll, craft, market, board swap/sell, buy orders, trade, gem store) is never locked. 9 quests / 3 chapters: starter, craft, 3 rolls -> **Casual** | check a Market value, post a trade ad, complete a trade -> **Regular** (unlocks Bulk Buy) | sell an item, sell into a buy order, complete 3 trades -> **Trader** (unlocks Booths + Syndicates, Daily/Weekly, profit titles). Quests grant nothing else; Rep and claim buttons removed. Rank perks (gem store restock/slots, crafter slots/recipes) are NOT built yet.

Status: proposal, not implemented. **See the Evidence section: it revises the 12-quest table below to a 9-quest, 3-chapter chain with soft gating.**

## Principles (from research, applied)

| Principle | Source | What it means here |
|---|---|---|
| Core fun in <30 s, first reward <60 s | Roblox Creator Hub onboarding; ROLearn D1 guide | Starter reveal → free item in hand before the player touches anything |
| Nobody reads tutorials; arrow + object + feedback | Spaceport, Roblox onboarding docs | Every step = one world/UI arrow, max ~6 words of text |
| Gate by relevance, not by script | Nasty Rodent FTUE playbook | A feature unlocks when the player has a *reason* to use it (e.g. Board unlocks right after they own a duplicate) |
| Endowed progress | Nunes & Drèze; Psychology of Games | Chain shows "1 / 12" the moment it appears (starter reveal counts as quest 1) |
| Goal gradient | Kivetz et al. | Early quests take ~1–2 min each, later ones longer; the bar visibly accelerates near a rank-up |
| Variable reward | Skinner schedule; grinding research | Rolls/crafts stay random; quest *completion* is fixed so the player always knows the finish line |
| Habit loop only after mastery | PS99 ranks/stars pattern | Daily + Weekly appear only after the core chain, never compete with it |

Hard rules carried over: no gem rewards ever; bots never progress; ranks are modest (Noob → Casual → Regular → Trader).

## Minute 0–3: tutorial (unchanged start, tightened)

1. **Starter reveal** (existing takeover). Player gets free items. Chain counter appears: `Quest 1 / 12 ✓`.
2. **Crafter NPC** is the only lit NPC. Green highlight + gold arrow over it (existing TutorialGuide).
3. Prompt → Crafts panel opens on **Unique Craft**, arrow on the tab, then on the craft button.
4. Craft completes → arrow removed (fixed this session), confetti, toast `Quest 2 done — Rank up: Casual`.
5. Panel auto-closes 1.5 s later; the Quests HUD button pulses once. That's the tutorial. ~2–3 min.

Nothing else on the HUD is clickable yet except Inventory and Quests (locked buttons are greyed with a lock badge, tooltip = the quest that opens them). Seeing locked buttons = curiosity, not clutter.

## Core chain (12 quests, ~25–35 min total)

Each quest unlocks exactly one thing, and the next quest immediately uses it. `→` = what unlocks.

| # | Quest | Unlocks | Rank |
|---|---|---|---|
| 1 | Open your starter pack (auto) | Inventory | Noob |
| 2 | Craft at the Crafter | Crafter (already on) | **Casual** |
| 3 | Do your first roll (first roll free) | Rolls | |
| 4 | Do 3 rolls | — (gem sink habit) | |
| 5 | Check an item's value in the Market | Market | |
| 6 | Post a trade ad on the Board | Board (swap ads) | **Regular** |
| 7 | Complete a trade (bot fills fast for new players) | Trade | |
| 8 | Sell an item on the Board | Sell listings | |
| 9 | Buy from the Gem Store NPC | Store NPC | |
| 10 | Fill a bulk order | Bulk orders + Bulk Buy | |
| 11 | Claim a booth and set a tagline | Booths | |
| 12 | Join or create a Syndicate | Syndicates | **Trader** |

After #12: Daily + Weekly quests appear, streaks start, profit titles take over the overhead title. The rank strip stays as a trophy.

Always available from minute 0 (not gated, because they're passive or monetisation surfaces): Shop, Free Gems, AFK pads, Robux Rewards bar, Profile.

### Why this order
- **Craft first**: it's the tutorial and turns the starter items into something *new*, so the first action creates value (endowed progress).
- **Rolls before trading**: rolls are the variable-reward hook and produce duplicates, and duplicates are the reason to trade.
- **Market before Board**: the player learns what things are worth before listing, which stops bad first trades that feel like getting scammed (the biggest early-quit risk in trading games).
- **Trade then Sell**: 1:1 trade is social and exciting; sell is the utility version.
- **Store at 9**: by now they have gems from selling, so the store is a sink they can afford.
- **Social last**: booths/syndicates need confidence; they also become the long-term retention layer.

### Pacing targets
- Quests 1–4: ≤ 2 min each (goal gradient: fast early wins).
- Quests 5–9: 2–4 min each.
- Quests 10–12: 4–6 min each.
- If a quest stalls > 5 min, the Quests button shows a hint arrow pointing at the relevant NPC/button (same pointer component).

### Rank-ups
Casual at #2, Regular at #6, Trader at #12. Each rank-up = full-screen flash (0.8 s), overhead title changes, toast. No extra rank rewards until the real reward type replaces Rep.

## After the chain (habit layer)
- **Daily**: 3 quests (easy/medium/hard), reset 00:00 UTC; clearing all 3 extends the streak.
- **Weekly**: 3 bigger quests, reset Monday UTC.
- **Streak**: visible counter; a missed day resets it. Consider one free "streak freeze" per week (reduces rage-quits after a single miss).
- **Profit titles**: silent, earned through trade profit; announced by toast only.

## What changes in code (when approved)
- `QuestConfig.Quests` → the 12 above, each with `unlock = "<feature>"`.
- `RankConfig` thresholds → Casual 2, Regular 6, Trader 12.
- New `FeatureGate` (shared): `isUnlocked(completed, feature)`, used by HUD buttons (grey + lock badge) and by the server entry points (rolls, board, store, booths, syndicates).
- Quest 1 auto-completes on the starter reveal ack; Quest 2 completes on the tutorial craft.
- First roll free (one-time flag on profile).
- Stall hint: client timer per active quest → reuses `pointAt`.
- Profile migration: existing players keep `completed`, clamped to 12 → veterans are Trader.

## Evidence (controlled experiments, not blog opinion)

| Study | Sample | Result | What I conclude for us |
|---|---|---|---|
| Andersen et al., CHI 2012, *Impact of tutorials on games of varying complexity* | 45,000+ players, 8 tutorial designs x 3 games | Tutorials raised play time up to **29% in the most complex game**, **no significant effect in the two simple games**. Mechanics discoverable by experimenting don't need teaching. | Our economy (values, board, bulk, crafting chains) is complex, so a tutorial is justified. Simple, discoverable actions (roll, open inventory) should NOT be taught or gated. |
| Andersen et al., FDG 2011, *On the harmfulness of secondary game objectives* | 27,000+ players, A/B | Side objectives that **don't support the main goal cut play time and progress** (off-path coins made players finish fewer levels). Side goals that reinforce the main goal were consistently positive. | Every quest must advance the core loop (get items, learn value, trade profitably). Chores like "set a booth tagline" or "join a syndicate" are off-path, so they should not be in the core chain. |
| Cookie Cats gate A/B (Tactile) | 90,189 players | Moving the first forced gate **later** (level 30 to 40) **lowered D7 retention** 19.02% to 18.20%, p = 0.0016. | A natural stopping point early helps players come back instead of burning out in session 1. Our core chain should end in session 1 with a reason to return tomorrow (dailies), not be a 60-minute grind. |
| Adopt Me "Guide" (Dec 2025, watched walkthrough video) | top-10 Roblox game | Nothing is locked. Three parallel tracks (Pets / Explore / Home), steps in groups of 3, a small reward on every step, a bigger reward at the end of each group. The daily Task Board runs separately. | The biggest social Roblox game guides instead of gating. Short groups of 3 with a payoff each = goal gradient in practice. |
| PS99 ranks | top Roblox trading-adjacent game | Quests grant stars, stars raise rank, ranks unlock slots (more capacity), not whole features. | Gate *capacity/advanced tools*, not the basic verbs. |

### FINAL (owner decision): hard progression
Every feature is LOCKED until its quest unlocks it. Locked HUD buttons stay visible, greyed, with a lock badge and "Unlocks at quest N" tooltip. The server rejects locked actions too (not just the UI). Evidence is used for ORDER and PACING only:
- a new unlock every 1-3 min early (goal gradient; the tutorial study says the complex parts need teaching, so each unlock is taught once by arrow on first use),
- every quest stays on the trading loop (secondary-objectives study),
- chapters of 3 with a payoff each (Adopt Me Guide),
- the chain ends in session 1 with Daily/Weekly as the reason to return (Cookie Cats).

| Ch | # | Quest | Unlocks on completion |
|---|---|---|---|
| 1 Start | 1 | Open your starter pack (auto) | Inventory |
| | 2 | Craft at the Crafter (tutorial) | **Rolls** |
| | 3 | Do 3 rolls | **Market** (values) |
| → **Casual** | | | |
| 2 Trade | 4 | Check an item's value in the Market | **Board** (swap ads) |
| | 5 | Post a trade ad | **Trade** (1:1 player trades) |
| | 6 | Complete a trade | **Sell listings + Gem Store NPC** |
| → **Regular** | | | |
| 3 Profit | 7 | Sell an item for gems | **Bulk orders + Bulk Buy** |
| | 8 | Fill a bulk order | **Booths** |
| | 9 | Make a profitable trade | **Syndicates** |
| → **Trader**: Daily/Weekly quests, streaks, profit titles | | | |

**Rewards:** the unlock IS the reward. Rep is removed entirely (no counter, no "+N" text).
**Rank perks** (each rank-up, no currency minted; all still paid with gems/items, so no faucet):
- Casual: Gem Store NPC shows +1 shelf slot; Crafter shows +1 recipe per rotation.
- Regular: Gem Store restocks faster; 2nd Unique Craft slot.
- Trader: Gem Store can roll a rarer shelf item; Crafter shows the next tier's recipes early.
Daily/Weekly (post-chain) reward = progress toward the next profit title + streak count; no currency.

Open from minute 0 (not gameplay features): Shop, Free Gems, Robux Rewards bar, Settings, Profile, Quests. Crafter NPC open (it is the tutorial).
Existing players: migrated to their equivalent position; anyone already past old quest 9+ lands on Trader with everything unlocked.

### What I could not prove
No public Roblox-specific A/B data on feature gating exists (searched DevForum and Creator Hub: only advice threads). The studies above are Flash/mobile games, so treat the effect sizes as direction, not as numbers for us. The only way to be certain for this game is to A/B it ourselves: log `quest_completed` timestamps (already logged) and D1/D7 per variant.

## Sources
- [Roblox Creator Hub — Onboarding](https://create.roblox.com/docs/production/game-design/onboarding)
- [ROLearn — First Week Retention](https://rolearn.dev/guidance/first-week-retention-optimization/)
- [Spaceport — Hook players in the first 2 minutes](https://www.spaceport.xyz/blog/how-to-hook-players-in-the-first-2-minutes-game-retention-tips-for-roblox-devs)
- [Nasty Rodent — Onboarding and FTUE design](https://nastyrodent.com/onboarding-and-ftue-design/)
- [Psychology of Games — Endowed progress and quests](https://www.psychologyofgames.com/2010/11/endowed-progress-effect-and-game-quests/)
- [Kivetz et al. — Goal-gradient hypothesis resurrected](https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf)
- [PS99 Ranks wiki](https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99))
- [Andersen et al. 2012 (PDF)](https://grail.cs.washington.edu/projects/game-abtesting/chi2012/chi2012.pdf)
- [Andersen et al. 2011, secondary objectives](https://dl.acm.org/doi/10.1145/2159365.2159370)
- [Cookie Cats A/B analysis](https://github.com/nsy0079/cookie-cats-ab-test)
- [Adopt Me Guide walkthrough (video)](https://www.youtube.com/watch?v=K3lvMZyJTSA)
- [Adopt Me Task Board wiki](https://adoptme.fandom.com/wiki/Task_Board)

## Tutorial after the Unique Craft (proposal v2, research-backed)
Evidence: tutorials should stay under ~5 min, the biggest drop-off is in the tutorial, and first value must land in session 1 ([GameAnalytics](https://www.gameanalytics.com/blog/key-lessons-boost-game-retention), [Playio](https://blog.playio.co/retention-vs-playtime-mobile-gaming)). Grow a Garden teaches its whole loop once by doing it (buy, plant, harvest, sell, buy better) with no text ([GameSpot guide](https://www.gamespot.com/articles/grow-a-garden-beginners-guide-and-tips/1100-6535055/)). Albion's first real act is a market sale, then it hands the player the world ([Albion guide](https://whattheredheadsaid.com/how-to-start-strong-in-albion-online-beginners-guide-to-progression-and-economy/)).
Conclusion: show our full loop once (make, value, sell, spend), then stop. The starter reveal plus the craft take about 2.5 min, which leaves about 2 min.
1. Profit popup, then an arrow to the Board and a Market tab that opens on the crafted item with its best buy order highlighted: "Sell for N gems". One tap merges "see value" and "sell". Toast: "+N gems".
2. Arrow to the Rolls NPC: "Roll with your gems". Random item.
3. Quests button pulses: "More to unlock". Tutorial over.
Trades stay out of the tutorial (they depend on another player, so the wait is unpredictable).

## Core loop (research + reflection, 2026-09-26)
**Finding:** every top Roblox trading game has a SOLO loop (act, then earn, then spend on a random reward, then get stronger) and puts trading ON TOP of it as the social layer ([Roblox core loops](https://create.roblox.com/docs/production/game-design/core-loops), [Adopt Me analysis](https://www.arcadeattack.co.uk/how-adopt-me-turned-simple-ideas-into-lasting-gameplay/)). Grow a Garden's pull comes from a clock-aligned 5-min shop restock, idle growth that makes short logins productive, and random mutations ([Kinzoo](https://www.kinzoo.com/blog/a-parents-guide-to-robloxs-grow-a-garden), [gag.gg restock](https://gag.gg/seed-restock/)).
**Our gap:** the only way to get more fuel (gems) is trading with other players, or Robux. So a solo player runs dry, and the loop stalls whenever the market is quiet. Gems cannot become a solo faucet (they convert to Robux).
**Fix:** solo fuel that is NOT gems: **Roll Tickets** (non-tradeable, non-convertible).
- Earned from timers: 1 ticket every 8 min online, cap 3 banked (appointment + "don't waste the cap"). AFK zone (peripheral) = faster tickets.
- Spent on a Ticket Roll: common/rare pool only, draws from the same reserve (supply stays capped, no new items minted).

Loop (about 3 check-ins of about 7 min each, roughly 20 min/day):
1. **Roll** (tickets or gems) for a random item (variable reward).
2. **Collect**: an Index/collection book with a set bonus (clear goal, goal gradient).
3. **Craft up**: duplicates go to the Crafter for a higher tier (deterministic progress, a use for junk).
4. **Cash in**: sell or trade the extras for gems (trading is the accelerator, never the gate). Gems buy premium rolls and Gem Store items.
5. **Come back**: tickets refill, the Gem Store restocks on a clock-aligned 5-min cycle, event recipes rotate.

Peripherals unlocked progressively by core quests (depth, optional):
| Unlock | Deepens |
|---|---|
| AFK Zones | tickets while idle (idle growth) |
| Bulk Buy | bulk trading |
| 2nd/3rd Unique Craft slot | crafting |
| Booths | selling to passers-by |
| Syndicates | social / group trading |
| Leaderboard boards | status |

Open decision: ticket rolls vs a second soft currency. Tickets are recommended: simpler, and the value is capped by design.

## Core loop v3: trading IS the loop (supersedes the Roll Ticket / gacha framing above)
**Principle:** the loop must work solo and get better with more players. Trading is the staple. Rolls/crafting are item SOURCES, not the loop.

**Evidence:**
- Animal Crossing Stalk Market: one commodity, prices follow a few readable patterns (random / decreasing / small spike / large spike), items rot after a week. Players obsess over "when to sell" with ZERO other players needed ([Nookipedia](https://nookipedia.com/wiki/Stalk_Market), [Game8](https://game8.co/games/Animal-Crossing-New-Horizons/archives/284591)).
- Moonlighter/Recettear: the fun is price discovery (set a price, read NPC reactions, adjust) against NPC customers ([Game Wisdom](https://game-wisdom.com/analysis/moonlighter), [Moonlighter wiki](https://moonlighter.fandom.com/wiki/Selling_and_Reactions)).
- "Bigger and Better" / One Red Paperclip: trade-up chains are intrinsically compelling, with each trade a step toward something clearly better ([Wikipedia](https://en.wikipedia.org/wiki/One_red_paperclip)).

**Conclusion (our game):** a solo trading loop against **NPC Merchants**, with real players layered on top as better counterparties.

### NPC Merchants (the solo counterparty)
- 3 to 4 merchants in the plaza, each with a rotating **barter request**: "I want 2x A, I give 1x B". Item-for-item ONLY, so no gems are minted.
- Stock comes from the item reserve and what they take goes back to the reserve (like roll payments). Supply stays capped, no faucet.
- Deals rotate on a clock (e.g. every 10 min, staggered), which gives a reason to check back.
- Merchant deals are fair but slightly worse than the live market (a small spread). That spread is a value SINK, so real player trades are always the better deal when players exist. More players means better prices, and the loop scales with population.
- Merchant appetite follows the market: items whose value is spiking get requested more. The Liquidity solver can already see NPC legs, so merchants plug into chain trades too.

### The loop (about 3 check-ins of about 7 min each, roughly 20 min/day)
1. **Scan**: market-watch strip plus merchant boards show what is moving and who wants what.
2. **Trade up**: take a merchant deal, or a player ad, that turns what you hold into something worth more (bigger and better).
3. **Watch value**: holdings show live worth, and "+N worth" pops when your items gain (stalk-market tension: sell now or hold for the spike?).
4. **Cash out or hold**: sell to players for gems when the price is right.
5. **Come back**: merchants rotate, events/burns move prices, the Gem Store restocks.

Item SOURCES that feed the loop (not the loop): starter pack, crafting (also burns supply, which pushes prices), rolls (gems), Gem Store, events, and later optional low-population **activities** (e.g. a short solo minigame that yields common items from the reserve).

### Progressive depth (peripherals via core quests)
Extra merchant slots / better merchant spread (the main system improves), Bulk Buy, Booths (set your own prices like Moonlighter, passers-by + NPC shoppers), AFK zones, Syndicates, extra Unique Craft slots.

### Why not gacha-first
Gacha makes a trading game into a worse Pet Sim. Our moat is a real, visible, moving market. The loop must make the player a trader in minute 1, even alone on a server.

## Core loop v4: EXISTING features only (supersedes v3 NPC Merchants, which were not built)
The solo trade-up counterparty already exists: the **Unique Craft**. It is a personal, rotating, item-for-item deal (inputs to one output), priced to be profitable (EventConfig.UniqueCraft, input value below output value), with a slot refill cooldown of 30 min. That is Animal-Crossing-style timing plus Bigger-and-Better trade-up, already built.

Loop:
1. **Check Unique Craft offers** (Crafter NPC): each one shows what you'd make and the profit.
2. **Source the missing inputs.** Solo: your inventory, rolls (gems or item-paid), Gem Store, event recipes. With players: Market asks, swap ads, Bulk Buy. More players means easier sourcing and better prices.
3. **Craft**: the output is worth more than the inputs, and crafting burns supply, so values rise (the market moves because of you).
4. **Watch worth grow**: the Robux Rewards bar tracks portfolio worth (gems + item values). THE long-term payoff, already built.
5. **Sell / trade surplus** on the Market or board for gems, which fund the next sourcing.
6. **Come back**: Unique Craft slots refill (30 min), events rotate, Gem Store restocks, AFK ladder (reward TBD).

Quest-driven depth (all existing): 2nd to 5th Unique Craft slot (the main system improves: more parallel deals), Bulk Buy, Booths, AFK zones, Syndicates.
Tutorial already teaches beats 1 and 3 (the unique craft plus the profit popup). Remaining tutorial beat: show the Robux Rewards bar filling from the new item's worth, which closes the loop and points at the next offer.

## Option: activity layer (Pet Sim "pets mine coins" analogue, minus rolling). Idea stage, not built.
**Expeditions:** send owned items out on a timed expedition (15 min / 1 h / 4 h). They return with loot drawn from the item RESERVE (no minting), with a small chance of a rare. Higher-value or matching-set items get better loot tables.
- Gives items a USE beyond value, which creates demand, and demand is good for trading.
- Items away on expedition leave circulation, so supply tightens and prices move.
- Idle + appointment (come back when it returns); works fully solo.
- Trading feeds it (buy the right items to boost expeditions) and it feeds trading (loot to sell).
- Unlock via a core quest (peripheral depth).
Risks: it distributes reserve faster (tune drop pace); needs a UI and a service (moderate build).
Alternative: an active minigame (dig/fish). More fun per minute, but a much bigger build and no link to item ownership.
