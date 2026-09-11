# Game Info — TBD Trading (Roblox)

An exhaustive overview of a Roblox item-trading economy game. "TBD Trading" is a placeholder name. This is the full brief — every system, every number, and the reasoning behind each design decision, not just a summary.

## What the game is

There is no combat, no obstacle course, no simulator-clicker loop. The entire game is: obtain items (gacha "rolls," crafting, or a fixed-price store), hold a collection whose value moves with a live supply/demand economy, and trade — directly with another player, via a public trade board, or via player-run shop booths.

## The plaza — what the world actually looks like

The game world is one open plaza (a single low-poly Roblox baseplate area, no zones/floors to unlock), populated with **physical, walk-up NPCs and structures** rather than menu buttons for everything:

- **Shopkeeper NPC** — a standing character model next to a counter and a hanging sign ("Limited Store"). Walking up and holding E opens the Store.
- **Roll Master NPC** — same pattern, opens the gacha Rolls panel.
- **Event Host NPC** — opens the seasonal/limited Events panel.
- **Trade Board Pillar** — a tall pillar with a pinned-notice-style sign reading "TRADE BOARD," holding E opens the public board.
- **Three physical leaderboard boards** standing in the world (Portfolio Value, Total Trades, Rarest Item), each a screen-like model rendering the live top players client-side, with the viewer's own row highlighted even off the visible page.
- **Player-claimed trade booths** scattered around — hand-placed stall models a player claims (hold E), each with a SurfaceGui storefront face showing their stocked items with prices. Booths are never spawned by code; adding or moving one is purely a Studio edit.
- **AFK zone pads** — green floor pads, several placed around the map, capped at 6 players each (overflow routes to the next zone). Standing on one freezes your character and camera in place (GUI stays live) while a "Go AFK" panel runs.
- **A wooden AFK sign** planted in the middle of the plaza — walking up and pressing E opens the Go AFK panel directly, instead of a HUD button. AFK access was deliberately moved from a sidebar icon to a physical world object, matching how Store/Rolls/Events/Board are all NPCs/props rather than menu buttons.

The sidebar HUD (screen-anchored, right edge) is reserved for things that aren't tied to a place in the world: Inventory, Trade (opens the picker), Profiles, Shop (Robux), Free Gems, Group (syndicate) — six icon buttons, evenly spaced. That split (world objects for the economy loop, menu buttons for account-level screens) is a deliberate pattern, not an accident — the world stays worth walking around in.

## The gacha roll experience

Opening the Rolls panel shows five tier cards with live per-item odds. Pulling the trigger plays a **case-opening / slot-machine reel animation** — a horizontal strip of item icons scrolls past a fixed center marker and decelerates onto the prize over about 4.5 seconds, heavily eased so the last second feels like it's "almost" stopping on each tile it creeps past before finally landing (the same reveal language used by Roblox gacha games like Bloxfruits' fruit-dealer wheel and most "case opening" simulators). Two specific psychology beats are built into the reel on purpose, researched from gacha/slot-machine design:
- **Near-miss** — the strip is seeded so a high-rarity icon sits directly next to the landing slot, so you visibly see what you almost got.
- **Back-loaded deceleration** — the scroll spends most of its time crawling rather than flying by, stretching out the anticipation right before the reveal.

Landing flashes a bright payoff pop timed to the exact instant the reel stops, then shows the item name in its rarity color plus its value in gems, with an "again" button right there to chain another pull.

## Core loop

1. Get items — roll gacha (gems), craft them from other items, buy them from the fixed-price Store, or earn them via AFK zones.
2. Hold a collection whose Estimated Value tracks a live economy, not fixed dev-set prices.
3. Trade — 1:1 direct trades, the public trade board (swap / bulk-buy / sell-shop listings), or booths.
4. Spend gems to roll/craft more, or spend Robux to boost trade-ad visibility or buy cosmetics.
5. Syndicates, leaderboards, and milestones sit on top and reward doing steps 1–4.

## The economy engine

Every item has a live Estimated Value, a fixed lifetime supply cap (`totalSupply`, set once, never changed), and a "reserve" of undistributed copies. Items enter circulation by being drawn from reserve — rolls, crafting outputs, and store buys all pull from the same reserve via one atomic cross-server operation, so the same "last copy" can never be handed to two players on different servers at once. Items leave circulation ("burn") through crafting inputs (consumed and redistributed, not destroyed — see Crafting below) and dedicated sacrifice recipes (true sinks).

**Value formula, as actually implemented:** `Value = max(1, floor(base * demandFactor + 0.5))`, where `demandFactor = 1 + DemandCoefficient * min(demand / DemandRef, 1)` (currently `DemandCoefficient = 0.5`, `DemandRef = 5`, so a red-hot item can be worth up to 1.5x its base). `base` is the item's rarity anchor price, or — for crafted/event items — `(sum of input values + input gems) * CraftValuePremium` (currently 1.10, a genuine +10% value-add for crafting). Demand itself is an exponentially-decaying moving average (half-life 6 hours) bumped by +1.0 per closed trade containing the item and +0.2 whenever it's placed into a live trade-ad offer.

*Worth flagging honestly:* the codebase's own comments describe an additional scarcity multiplier — `((circulating+burned)/circulating)^SupplyExponent`, capped at 6x — as part of the intended formula, and `EconomyConfig` documents it at length as core design ("a sink lifts EVERY holder... non-zero-sum"). But the actual `computeValue` function that runs at runtime only takes `(base, demand)` — no scarcity term currently executes. This looks like a genuine doc/implementation drift, not a deliberate simplification, and is worth resolving one way or the other.

**RAP** (recent average price) is tracked separately as an *observed* statistic from real gem-denominated trade settlements — imputed pro-rata when a trade includes non-gem items on both sides, skipped (demand-bump only) for a pure one-sided "gift" trade. RAP deliberately never feeds back into Value; an earlier version blended a value seed with RAP with decaying weight so Value asymptotically *became* RAP, a feedback loop with no anchor, and that was removed on purpose.

**Storage split:** reserve/circulating counts (correctness-critical) go through the strong atomic path — a DataStore CAS write per reservation, or an in-memory-only "lazy" path used carefully in specific burst scenarios (admin batch-rolls, bot simulation) with a documented, tighter tradeoff each time. RAP and demand (high-frequency, statistical) live in a local cache with a dirty flag, flushed durably every 60 seconds, last-writer-wins — readers are at most one flush stale. No economy state lives in MemoryStore; that quota is experience-wide and tiny (~64KB in Studio) and is reserved entirely for the trade board.

## Getting items, and why each path exists

There are four ways to get an item, each a deliberately different lever on the economy.

### Rolls (gacha)

The main *paid* path new goods enter the economy through — nothing appears on a timer, every item can be traced back to gems someone actually earned. 5 tiers, gems only, no pity system, straight weighted odds:

| Tier | Cost | Value floor | Rarity window | Odds |
|---|---|---|---|---|
| Basic | 12 gems | 35% of cost | Common/Rare/Legendary/Mythical | 96.0 / 3.2 / 0.6 / 0.2% |
| Solid | 25 gems | 42% of cost | same | 74.0 / 21.0 / 4.0 / 1.0% |
| Lucky | 55 gems | 46% of cost | Rare/Legendary/Mythical/Godly | 73.0 / 21.0 / 5.0 / 1.0% |
| Grand | 110 gems | 50% of cost | same | 40.0 / 38.0 / 17.0 / 5.0% |
| Mythic | 240 gems | 52% of cost | Legendary/Mythical/Godly/Celestial | 50.0 / 33.0 / 12.0 / 5.0% |

The "value floor" is a genuine guarantee, not marketing — a roll will never return an item worth less than that fraction of what you paid; items below the floor are excluded from that tier's pool for that rarity.

Rolls draw from a "pool" — a rotating set of items spanning all six rarities, which is the *entire* rollable set at any moment. The advertised odds are exact and can't drift: how many copies of an item remain never changes its drop chance (the split within a rarity uses a fixed weight derived from the item's supply cap at creation, never its current remaining count), and the pool is replaced the instant *any one* of its items is fully exhausted, rather than waiting for the whole pool to run dry. The reasoning: while every item in a rarity still has at least one copy, the odds are exactly what's advertised no matter how lopsided the counts get; the moment one item hits zero, it would otherwise drop out of its rarity's weight split and every other item in that rarity would become likelier than advertised without anyone agreeing to that — both a lie to the player and a farmable exploit (drain the item you don't want, the rest improve). If a roll's random draw happens to land on a rarity that's momentarily empty, the roll is refused and refunded rather than quietly sliding into a neighboring rarity — the player is charged nothing and a fresh pool is minted in the background.

A retired pool isn't destroyed. Crafting inputs and roll item-payments redistribute consumed copies back to the item (and therefore the pool) they came from, so a retired pool slowly refills. Once it's recovered at least 20% of the total supply it was minted with, *and* every item in it holds at least one copy again, it's revived and preferred over minting an entirely new pool — nothing is ever permanently thrown away.

A roll can also be paid in items instead of gems, as long as their combined live Value covers the tier price (up to 12 distinct items, 99 copies each); those items are redistributed back into reserve the same way crafting inputs are. Items from *ended* limited/seasonal events are refused as payment specifically because pushing one back into reserve after its season closed would quietly undo the "this can never be made again" promise.

### Crafting

The *only* mechanic that actually creates value rather than moving it around — trading is zero-sum (items just change hands), a craft consumes inputs and mints an output seeded above their combined worth (currently +10%), so every completed craft genuinely grows the economy. This is why it's structured as a ladder — commons → refined materials → mid-tier Artifacts → capstone Grails, each rung worth more than the last:

- **Alchemist's Lab** (permanent, always-on, deliberately cheap) — the on-ramp. Transmutation Stone and Rune of Protection, exempt from the "should be hard to farm" logic on purpose: every new player needs at least one recipe they can always make, win or lose on rotation.
- **The Refinery** (permanent) — 4 recipes, each turning 15 copies of one common into a refined material capped at 2,500 total supply. Deliberately scarce even as a "basic" material: flood it and it's worthless.
- **Artisan Bench** (permanent) — 8 mid-tier recipes producing Artifacts and Cores (supply caps 300–900), the ladder's middle rungs.
- **Rotating recipes** — 4 of a 6-recipe pool active at any time, on a strict 10-minute rotation, computed purely from the clock (every server agrees automatically, nothing to break on rotation). By rule, a rotating recipe may only ever produce a terminal item nothing else depends on, so a window closing can never strand another recipe chain that needs its output.
- **Shadow Ritual** (sacrifice recipes) — the heaviest true item sinks in the game: 30 Copper Coin → Shadow Crown (220 supply), 30 Stone Relic → Hollow Effigy (180 supply). These genuinely destroy, not redistribute.
- **The Grand Forge** (capstone) — Ancient Grail (5 Storm Artifact + 1 Crimson Crown → 80 supply), Eternal Diadem (5 Ember Artifact + 1 Void Shard → 40 supply), and Worldheart, a deliberately *branching* capstone (1 Sunforged Core + 1 Voidforged Core → 25 supply) built from two independent sub-ladders of equal depth meeting at the top. Capstone input counts are deliberately steep — more of a common than one player could realistically farm alone — on purpose: satisfying one means buying hundreds off the market from everyone else, and that demand is what gives a brand-new player's cheapest starter items any real worth at all. Nothing else does.
- **Seasonal/limited events** — a hard end date built into config (currently Midsummer Festival, ending Aug 1 2026). Once an event ends, its items are frozen forever — never craftable, never payable into a roll — a real promise that "limited" means limited.
- **Sold-out replacement** — when a permanent recipe's capped output fully sells out, it's automatically swapped for a pre-authored "spare" recipe at the next 20-minute boundary, so a popular recipe running dry doesn't leave a dead, permanently-broken crafting station.

Consumed crafting inputs are **redistributed back into the shared reserve, not destroyed** (sacrifice recipes are the deliberate exception) — a common eaten by the hundreds at the top of the ladder recycles straight back into new players' starter grants instead of the world ever running dry.

**Unique Craft** — a distinct, personal mechanic. Every player periodically gets temporary access (3-hour window) to craft one item that already exists but that no live recipe is currently producing, with a cheap shopping list (2–3 distinct common/rare items, priced at 45–70% of the output's value). The reasoning: everyone chasing the same recipes turns players into each other's competitors instead of trading partners; a Unique Craft drops one player into the market wanting something nobody else is currently bidding on, so whoever happens to hold those parts suddenly has a buyer — which is how a brand-new player who knows nothing about trading makes their first sale. It also incidentally teaches all four ways to get an item (roll, store, board, direct trade) without a word of tutorial, since filling the shopping list can be done any of those ways. Extra slots for holding more than one offer at once are a steep, permanent gem sink: 750 → 2,000 → 5,000 → 12,000 gems.

### AFK zones

Standing on a pad accrues a reward every 10 minutes, increasing each tick, reset on leaving. The first payout is deliberately a full interval away — AFK income should never beat simply playing normally for ten minutes, only beat leaving the game entirely. The reward ladder (8 rungs) is fully built and wired; every rung currently pays "tbd" (declared, deliberately paying nothing yet, not a bug) — the actual reward type (items, gems, banked trade-ad boosts, or roll credits) hasn't been chosen. Standing too far from the pad (checked every tick) drops the session; leaving resets the whole ladder back to the first rung, specifically to stop hopping in and out to keep re-earning the top payout.

### The Store

A fixed-price NPC shop, separate from rolls and the one acquisition path with zero randomness. Every item is limited stock at a hand-set gem price that never moves as it sells — 10 items currently, priced 10–25 gems, supplies 25–150. Only a rotating subset (6 of the catalog) is on sale at once, on a 6-hour shelf window, and within that, 2 shelf items go on a genuine, timed 35%-off sale every 15 minutes. That's a real recurring demand event, not decoration: buying below market Value is free profit, so players pile in, that item's stock drains, and it gets genuinely scarcer for everyone else already holding one. Per-player purchase limits apply per item (default: 1).

## Trading systems

### Direct 1:1 trade

Invite, both sides build an offer (a 3x3 grid, 9 item slots + gems each, up to 99 copies per slot, up to 1,000,000,000 gems), both confirm, a 2-second cancelable grace window (the only artificial wait in the whole flow, deliberately PS99-style — either side can still back out before anything is locked in), then escrowed delivery. Works cross-server and survives a partner disconnecting mid-trade — the authoritative trade record lives in a cross-server store and every state transition is a pure, testable function with hard invariants: changing an offer resets both sides' confirmations (kills last-second swap attempts after agreement), items are only ever locked in once both sides have confirmed, and once settlement begins it cannot be aborted — it's retried until it completes, never left half-done.

No typed chat required — a canned "quick chat" phrase bar sits right in the trade screen, grouped into four tabs (Offer / Items / Trade / Say) with real trader vocabulary: "That looks fair," "Add more," "That's way under value," "Clean trade? One for one," plus item-referencing phrases ("I want your %s," "I'll give you my %s") that fill in the actual item name server-side. This exists specifically because Roblox restricts text chat between accounts in different age brackets — a 12-year-old and a 15-year-old often literally cannot type to each other — so the whole negotiation is playable by tapping buttons, and a player who can't type can still learn real trading vocabulary by reading the options.

### Trade board

The biggest system in the game. Public listings with **no escrow at all** — a listing is a promise, not a deposit. Posting only checks you currently hold the goods right now; they stay fully usable, tradeable, and rollable right up until someone actually takes the trade. The real check happens at settlement: if the poster is online on this server, it's an ordinary delta; if offline, it's a safe conditional write directly to their profile; if they're online on a *different* server, the take is refused (their profile is locked there) and the listing just waits to be tried again; if the poster genuinely can't cover it anymore for any other reason, the listing is cancelled outright rather than serving a broken promise.

Three listing types:
- **Swap** ("this for that") — can auto-settle instantly if the terms match (works even with the poster offline), or register as an "interest" the poster reviews and invites to trade. The want side can hold wildcard tokens ("Any Rare," "Any Upgrade," "Any Event Item" — 7 tokens total, modeled on Rolimon's request tags) instead of naming a specific item, which forces ask-first since a fuzzy want can't auto-settle.
- **Bulk** — a standing gem-denominated buy order for N copies of one item (up to 1,000 at once); gems are checked but never held until something actually fills the order.
- **Sell** — a fixed-price gem shop listing; the same mechanism booths use under the hood.

Sell and Bulk orders on the same item cross like a real order book: if a resting sell (ask) and a resting buy order (bid) can match, they fill automatically at the resting order's price — genuine price improvement for whoever takes second.

Listings can be server-scoped (free, dies when you leave that server) or global (cross-server, survives a 2-hour grace window after you disconnect). Everyone gets 3 free ad slots per scope; extra slots are purchasable, capped at 27 total per scope. Paying with Robux boosts placement and duration on a tiered shelf — 1 hour up to 3 days, server or global scope, with a scarce "Featured" tier (only 5 slots per scope, deliberately scarce — a permanent featured pass would let one player squat the pool forever). The shelf pricing is deliberately anchored: a cheap "low" option, an intended "best value" pick, and an expensive "high" option that makes the middle one look reasonable by comparison (e.g. a 24-hour boost costs 2.5x a 1-hour boost for 24x the duration). Boosting never gates the ability to post, browse, or accept trades for free — money only ever buys position and duration.

Visually, the board reads as a scrolling feed with a **gold-bordered "Featured" strip** pinned above it (roughly 3 cards visible per page, scrolling to fit up to 5), each featured card rendered exactly like a normal feed row just boxed in gold so it never feels like a second, different UI. Regular boosted (non-featured) ads get an **electric-cyan** tag instead — gold is reserved exclusively for Featured so the two tiers never read as the same thing at a glance. Putting up more than one copy of an item in a single trade offer doesn't create duplicate slots — it collapses into one square with a large impact-font count badge ("x5"), and any stack a player holds more than one of gets a small green "+" in the corner of its picker tile that opens a one-tap bulk-add prompt instead of clicking the item repeatedly. Accepting a trade shows an explicit "Are you sure?" confirmation screen before it fires. A live activity ticker shows recent board fills (deliberately illustrative, rate-limited to 4 announcements per second — not meant as an audit log).

### Booths

Hand-placed player shops in the world, free to claim (hold E). A booth doesn't sell anything of its own — stocking a slot just posts an ordinary Sell listing on the board, so the exact same stock shows on the booth *and* the board at one price, and nothing is ever held. Base 5 slots, purchasable up to 20, arranged in a 5x2 visible grid (scrolls for more). No purchase cooldown, deliberately: unlike games where a booth slot is a mutable display a seller can swap between a buyer reading it and clicking, here the listing ID *is* the offer — price and item are immutable once posted, so a seller who changes their mind can only cancel, which just makes a pending buy fail with "gone" and charges the buyer nothing. A cooldown would protect against nothing and only punish honest buyers. Players standing within 12 studs of a booth render semi-transparent, so nobody can body-block a stall and hide its stock from other shoppers. Cosmetic booth skins are purchasable (5 currently, placeholder recolors pending real art) but never touch price, tax, or slot count — kept strictly cosmetic on purpose so a storefront upgrade can never become pay-to-win.

## Scam safeguards

- **Direct trades are fully escrowed with hard state-machine invariants** — changing an offer resets both sides' confirmations, confirming is only legal during open negotiation, and both items are locked in before either side is credited. Settlement, once started, can't be aborted and is retried until it completes, never left half-done — nobody can accept a trade and simply not pay.
- **Booth and board listings can't be swapped out from under a buyer.** The listing itself *is* the offer — price and item are immutable the moment it's posted.
- **Players standing near a booth go semi-transparent**, so nobody can body-block a stall and hide its stock.
- **The trade board's no-escrow design is safe by construction, not by trust**: a listing take either succeeds atomically or fails and charges nobody — there's no window where one side pays and the other doesn't.
- **Group chat text is filtered per-reader**, not pre-rendered once and broadcast — the same string can legitimately read differently (blocked words vary) per viewer, so it's filtered fresh for every single reader.
- **Trade quick-chat carries zero player-authored text** — only phrase IDs cross the network, the server looks up the wording — so there is nothing to filter and nothing an exploiter could inject.

## Progression & social systems

**Syndicates** (guilds) — founded for 500 gems, fully custom roles and permissions (owner can create/rename/reorder/delete up to 8 roles, not a hardcoded preset list; only Owner and a base Member role are permanent). XP comes from things players already do — 10 XP per trade (both sides earn it), 6 per board fill, 15 per craft (the highest, deliberately, since crafting is the actual value-creating action). A donation/request system is explicitly modeled on Clash of Clans' troop-donation mechanic — described in the code as "the single strongest retention mechanic in that game" — where members post requests (up to 2 open at once, capped at 500 total, expiring after 24 hours) and others donate items for 12 XP each, more than a trade earns. 10 levels, cumulative XP up to 75,000, unlocking a rising member cap (10 → 100), extra board slots (+1 at level 2, +2 more at 5, +3 more at 8), a market fee discount (5% → 10% → 15% at levels 3/6/9), and a roll-luck bonus (+0.02 → +0.05 → +0.08 at levels 4/7/10).

**Leaderboards** — Portfolio Value (live net worth), Total Trades, and Rarest Item Held (scored inversely by supply — the scarcer the item, the higher the score), each with all-time and auto-resetting weekly variants. Scores are pushed on a staggered timer (not per-event, since portfolio value can change hundreds of times a minute) but a player's own live value is overlaid on top of the cached board the instant they open it, so a just-completed trade is never invisible.

**Milestones & communal goals** — a personal craft-count reward track (5 crafts → 1,200 crafts, "Apprentice" through "Legend," rewarding items, never gems, since gems only ever enter the game through ads or Robux) and a daily server-wide craft-count goal (400 crafts by anyone, contributors-only claim so it can't be farmed by idling). Both fully built, both currently switched off pending enabling and reward tuning.

**Referrals & ad rewards** — invite 3 friends (via Roblox's own game-invite prompt) and both the inviter and everyone they brought get a 20% gem bonus on their next 15 rewarded-ad watches. Rewarded ad video itself is gated behind Roblox's own platform requirement (public game, 13+ ID-verified creator, 2,000+ monthly unique visitors) — shown to players honestly as a visible progress bar toward that number rather than hidden. Once unlocked: 50 gems per watch, capped at 5 watches/day, 2-minute cooldown between watches.

## Monetization

Config-driven, all in one place, structured so adding a new offer is a data edit, not new code. Gem packs (5 tiers, 100 → 6,000 gems, with an escalating bonus of 0% → 40% at the top) use deliberate pricing psychology — the middle pack is flagged "Most Popular" as a decoy anchor pulling buyers up the ladder, and the top pack is the featured hero card. Gamepasses include an "Always Boosted" pass and an "Ad Duration" pass (ads survive a full day even while offline) — both deliberately *excluded* from the Featured board tier, since a permanent featured pass would let one player squat the scarce Featured pool forever. Ad slots stack additively (+1/+3/+5). Booth slots and skins are purchasable but cosmetic-only. Trade-ad boosting is covered above. Across all of it: money consistently buys visibility, duration, convenience, and cosmetics — never an advantage in the trading/economy math itself, and never blocks the free path to post, browse, or accept trades.

There's also a parallel, currently-empty system for *tradeable* purchase tokens — since a Roblox gamepass itself can't be resold or traded, any future benefit meant to be player-tradeable would be granted as an ordinary inventory item instead, with gameplay perks keyed off holding that item rather than off Roblox's own gamepass-ownership API. Infrastructure exists; nothing uses it yet.

## Items & rarity

Six rarity tiers (Common → Rare → Legendary → Mythical → Godly → Celestial), derived automatically from each item's total supply cap — never hand-labeled. Thresholds: Common ≥20,000 copies ever mintable, Rare ≥5,000, Legendary ≥1,200, Mythical ≥300, Godly ≥80, Celestial below that (down to about 40). The top three tiers are deliberately kept close together in supply so the value ladder has no big cliff. Base store price roughly doubles per tier: 8 / 35 / 130 / 300 / 650 / 1,300 gems for Common through Celestial.

New players get a starter bundle of 5 weighted draws (duplicates allowed) rather than a fixed kit. That's deliberate asymmetry, not noise: because it's weighted rather than uniform, two new players end up with meaningfully different portfolios — one got luckier than the other — which means there's immediately something worth trading between them on day one, instead of everyone starting with an identical kit nobody wants to swap.

Beyond the rotating 5-item starter pool, dozens more items exist purely as crafting/event outputs, each with its own independent supply cap.

## Interface conventions

Large numbers are always abbreviated in the UI (1,300 gems reads "1.3K," not the raw number, using one shared formatter everywhere so the same number never reads differently on two screens), and any numeric input box accepts shorthand typing — typing "3k" into a quantity or price field resolves to 3000 automatically. Destructive admin actions (full economy reset) require 3 separate clicks spaced at least 3 seconds apart within a 12-second window, rather than a single confirm dialog, specifically to make it hard to trigger by accident.

## Other systems

**Player profiles** — viewable by others, with privacy toggles applied at write time so private data never enters the public-readable snapshot in the first place. Up to 6 showcase items and 3 stat chips, both configurable, both requiring the player to actually own/qualify for what they display.

**Notifications** — deliberately offline-only; a player currently in the game gets nothing from this system (the live UI already shows current state, and toasting every board event was judged noise). An offline player gets a durable queued notification replayed at next login, plus a real push notification through Roblox's own notification API for opted-in players (subject to Roblox's hard platform limit of one push per player per day per experience).

## Built for ongoing content — the live-ops backbone

The crafting/event system was deliberately architected as an engine for a constant stream of updates, not a one-time content drop:

- **Seasonal/limited events** are a first-class category with a hard end date baked into config (add a new event, give it recipes and an end timestamp, done — no code changes). Once an event ends, its items are frozen forever, which is what makes each season feel genuinely limited-time rather than always-repeatable.
- **Rotating recipes** cycle a subset of a larger recipe pool on a fixed timer (currently a handful active out of a pool of six, every 10 minutes) with zero stored state — purely a deterministic function of the clock, so every server agrees automatically and there's nothing to break on rotation.
- **Sold-out replacement** — when a permanent recipe's capped output sells out, it's automatically swapped for a pre-authored "spare" recipe at the next boundary, so a popular recipe going dry doesn't leave a dead station; new ones can just be authored and dropped in.
- New items, new recipes, and new seasonal events are all pure config additions on top of this — the intent is that content updates are mostly data, not new code.

## Built but currently switched off (ready to launch)

A few systems are fully implemented and wired end-to-end but intentionally disabled pending a decision or more polish:

- **Milestones & communal goals** — a personal craft-count reward track and a daily server-wide craft-count goal. Both just need `enabled = true` and reward tuning.
- **AFK zone reward payout** — the AFK system itself (zones, timers, escalating payout schedule) is fully built; only the actual reward type (items vs. gems vs. roll credits vs. banked trade-ad boosts) hasn't been chosen yet.
- **Real Robux product IDs** — gem packs and some ad-slot dev products are still on placeholder IDs pending the store going live.

## Open ideas under consideration

- **A guided first-profit strategy.** Right now the game teaches its core loop entirely through mechanics rather than screens — Unique Craft, for instance, is explicitly designed to teach "the four ways to get an item" without a word of tutorial. There's no formal walkthrough yet that hands a brand-new player one concrete, repeatable strategy for turning their starter bundle into their first real profit. Whether that should be an explicit tutorial flow, or just better in-context nudging on top of what already exists (Unique Craft, the weighted/asymmetric starter bundle), is an open question.
- **Bots as a new-player liquidity backstop.** A full bot-driven market simulation exists in the codebase (hundreds of agents with distinct trading personalities) but is currently off while the economy is tuned directly against real player behavior. The idea under consideration isn't reviving that full simulation — it's specifically using a small, targeted presence purely for liquidity, so a brand-new player always has *someone* to trade with in their first few minutes, even at 2 AM on a quiet server, rather than depending on real player traffic being enough from day one.
