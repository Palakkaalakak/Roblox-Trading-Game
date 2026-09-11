# Game Info — TBD Trading (Roblox)

An overview of a Roblox item-trading economy game. "TBD Trading" is a placeholder name.

## What the game is

There is no combat, no obstacle course, no simulator-clicker loop. The entire game is: obtain items (gacha "rolls," crafting, or a gem store), hold a collection whose value moves with a live supply/demand economy, and trade — directly with another player, via a public trade board, or via player-run shop booths.

## The plaza — what the world actually looks like

The game world is one open plaza (a single low-poly Roblox baseplate area, no zones/floors to unlock), populated with **physical, walk-up NPCs and structures** rather than menu buttons for everything:

- **Shopkeeper NPC** — a standing R15-style character model next to a counter and a hanging sign ("Limited Store"). Walking up and holding E opens the Store.
- **Roll Master NPC** — same pattern, opens the gacha Rolls panel.
- **Event Host NPC** — opens the seasonal/limited Events panel.
- **Trade Board Pillar** — a tall pillar with a pinned-notice-style sign reading "TRADE BOARD," holding E opens the public board.
- **Three physical leaderboard boards** standing in the world (Portfolio Value, Total Trades, Rarest Item), each a screen-like model rendering the live top players client-side, with the viewer's own row highlighted even off the visible page.
- **Player-claimed trade booths** scattered around — hand-placed stall models a player claims (hold E), each with a SurfaceGui storefront face showing their stocked items with prices, walkable and browsable by other players like a real market stall. Booth "skins" are purely cosmetic recolors (Market Stall default, Sunset Awning, Midnight Counter, Emerald Bazaar, Gilded Pavilion).
- **AFK zone pads** — green floor pads, several placed around the map, capped at 6 players each (overflow routes to the next zone). Standing on one freezes your character and camera in place (GUI stays live) while a "Go AFK" panel runs.
- **A wooden AFK sign** planted in the middle of the plaza — walking up and pressing E opens the Go AFK panel directly, instead of a HUD button (this was a deliberate redesign this session: AFK access moved from a sidebar icon to a physical world object, matching how the Store/Rolls/Events/Board are all NPCs/props rather than menu buttons).

The sidebar HUD (screen-anchored, right edge) is reserved for things that aren't tied to a place in the world: Inventory, Trade (opens the picker), Profiles, Shop (Robux), Free Gems, Group (syndicate). Six icon buttons, evenly spaced. Notice the asymmetry: Store/Rolls/Events/Board/AFK are all physical and walked-to; Inventory/Trade/Profile/Shop/Group are menu-triggered. That split is a deliberate design pattern, not an accident — the world stays worth walking around in.

## The gacha roll experience

Opening the Rolls panel shows five tier cards (Basic through Mythic) with live per-item odds. Pulling the trigger plays a **case-opening / slot-machine reel animation** — a horizontal strip of item icons scrolls past a fixed center marker and decelerates onto the prize over about 4.5 seconds, heavily eased so the last second feels like it's "almost" stopping on each tile it creeps past before finally landing (this is the same reveal language used by Roblox gacha games like Bloxfruits' fruit-dealer wheel and most "case opening" simulators). Two specific psychology beats are baked into the reel construction on purpose (documented in the code as researched from gacha/slot design):
- **Near-miss** — the strip is seeded so a high-rarity icon sits directly next to the landing slot, so you visibly see what you almost got.
- **Back-loaded deceleration** — the scroll spends most of its time crawling rather than flying by, stretching out the anticipation right before the reveal.

Landing flashes a bright payoff pop timed to the exact instant the reel stops, then shows the item name in its rarity color plus its value in gems, with an "again" button right there to chain another pull.

## Core loop

1. Get items — roll gacha (gems), craft them from other items, or earn them via AFK zones.
2. Hold a collection whose Estimated Value tracks a live scarcity/demand economy, not fixed dev-set prices.
3. Trade — 1:1 direct trades, the public trade board (swap / bulk-buy / sell-shop listings), or booths.
4. Spend gems to roll/craft more, or spend Robux to boost trade-ad visibility or buy cosmetics.
5. Syndicates, leaderboards, and milestones sit on top and reward doing steps 1–4.

## The economy

Every item has a live Estimated Value computed from its base rarity price, how scarce it's become (copies burned vs. still circulating), and recent demand — not a number set by hand. A separate "RAP" (recent average price) is tracked from actual closed trades as an observed statistic. Each item also has a fixed lifetime supply cap; items enter circulation through rolls, crafting, and store buys, and leave circulation through crafting inputs and dedicated sacrifice recipes.

## Getting items, and why each path exists

There are four ways to get an item, and each one is deliberately a different lever on the economy — they're not just re-skins of "spend currency, get item."

**Rolls (gacha)** — the main *paid* path new goods enter the economy through. A roll costs gems (a real sink) and mints one item straight out of reserve into circulation; nothing appears on a timer, so every item in the world can be traced back to gems someone actually earned. 5 tiers (Basic/Solid/Lucky/Grand/Mythic), gems only, no pity system, straight weighted odds — pay more, roll from a higher rarity window. Rolls draw from a "pool," a rotating set of items spanning all six rarities that is the entire rollable set at any moment. The advertised odds are exact and never quietly shift: how many copies of an item remain never changes its drop chance, and the pool is replaced the instant any one of its items is exhausted, specifically because an item hitting zero would otherwise silently hand its odds share to the rest of its rarity. A retired pool isn't destroyed — crafting and roll payments return consumed copies to it, and once it's refilled enough it can become the active pool again, so nothing is ever truly gone from the loop.

**Crafting** — the *only* mechanic that actually creates value rather than moving it around. Trading is zero-sum (items just change hands); a craft consumes inputs and mints an output seeded above their combined worth, so every recipe completed genuinely grows the economy. This is why it's structured as a ladder: common materials → refined materials → mid-tier Artifacts → capstone Grails, each rung worth more than the last. Capstone recipes are deliberately steep — asking for more of a common than one player could realistically farm alone — on purpose: satisfying one means buying in bulk from everyone else, and that demand for cheap commons is what gives a brand-new player's starter items any real worth. One deliberate exception: at least one always-on, always-cheap recipe exists purely as a new-player on-ramp, exempt from the "worth farming" logic — everyone needs one thing they can always make. On top of the permanent ladder: rotating recipes (a handful active at a time, cycling on a timer, so there's always something changing even without a new season); sacrifice recipes, the heaviest true item sinks in the game; and seasonal/limited events with a hard end date, whose items are frozen forever once the season closes — a promise that "limited" actually means limited.

- **Unique Craft** — a personal mechanic, distinct from the shared ladder. Every player periodically gets temporary access to craft one item that already exists but that no live recipe is currently producing, with a cheap shopping list priced well below the item's value. The point isn't the discount — it's that everyone chasing the same recipes turns players into each other's competitors instead of trading partners. A Unique Craft drops one player into the market wanting something nobody else is currently bidding on, so whoever happens to hold those parts suddenly has a buyer — which is how a brand-new player who knows nothing about trading makes their first sale. Extra slots (holding more than one of these offers at once) are a steep, permanent gem sink.

**AFK zones** — standing on a pad accrues a reward every 10 minutes, increasing each tick, reset on leaving; the first payout is deliberately a full interval away, so idling never out-earns just playing normally, only leaving the game entirely. Built and wired end-to-end; the actual reward payout (items, gems, boosts, or roll credits) hasn't been chosen yet.

**The Store** — a fixed-price NPC shop, separate from rolls and the one path with no randomness at all: every item is limited stock at a hand-set gem price that never moves as it sells. Only a rotating subset of the catalog is on sale at once (a 6-hour "shelf" window), and within that, a couple of shelf items go on a timed 35%-off sale every 15 minutes. That sale isn't decoration — buying below market Value is free profit, so players pile in, that item's stock drains, and it gets genuinely scarcer (which lifts Value for everyone else already holding one). It's a real, recurring demand event, just a small, constant one rather than a seasonal one. Per-player purchase limits apply per item.

## Trading systems

**Direct 1:1 trade** — invite, both sides build an offer (a 3x3 grid, 9 item slots + gems each), both confirm, a short (2-second) cancelable grace window, then escrowed delivery. Works cross-server and even if a partner disconnects mid-trade. No typed chat required — a canned "quick chat" phrase bar sits right in the trade screen, grouped into four tabs (Offer / Items / Trade / Say) with real trader vocabulary: "That looks fair," "Add more," "That's way under value," "Clean trade? One for one," plus item-referencing phrases ("I want your %s," "I'll give you my %s") that fill in the actual item name. This exists specifically because Roblox restricts text chat between accounts in different age brackets — a 12-year-old and a 15-year-old often literally cannot type to each other — so the whole negotiation is playable by tapping buttons, with real market phrasing a new player can pick up by reading them.

**Trade board** — the biggest system in the game. Public listings with no escrow (a listing is a promise, not a deposit, so listed items stay fully usable until someone takes the trade). Three listing types: Swap ("this for that," can auto-settle or ask-first), Bulk (standing gem buy orders for N copies), and Sell (fixed-price gem shop listings). Listings can be server-scoped (free) or global (cross-server). Everyone gets free ad slots; paying with Robux boosts placement and duration on a tiered shelf (hourly/daily/multi-day), never gates the ability to post/browse/accept for free.

Visually, the board reads as a scrolling feed with a **gold-bordered "Featured" strip** pinned above it (roughly 3 cards visible per page, scrolling to fit up to 5), each featured card rendered exactly like a normal feed row just boxed in gold so it never feels like a second, different UI. Regular boosted (non-featured) ads get an **electric-cyan** tag instead — gold is reserved exclusively for Featured so the two tiers never read as the same thing at a glance. Putting up more than one copy of an item in a single trade offer doesn't create duplicate slots — it collapses into one square with a large impact-font count badge ("x5"), and any stack a player holds more than one of gets a small green "+" in the corner of its picker tile that opens a one-tap bulk-add prompt instead of clicking the item repeatedly. Accepting a trade shows an explicit "Are you sure?" confirmation screen before it fires. Wildcard tokens let a want-side be fuzzy ("Any Rare," "Any Upgrade") instead of naming a specific item.

**Booths** — hand-placed player shops in the world. Free to claim; stocking a slot just posts an ordinary Sell listing, so the same stock shows on the booth and the board at one price. Cosmetic booth skins are purchasable but never touch price, tax, or slot count.

## Progression & social systems

**Syndicates** (guilds) — founded with gems, fully custom roles/permissions. XP comes from things players already do: trading, filling board orders, and especially crafting. A donation/request system lets members ask for and give items to each other for XP. Levels unlock a higher member cap, extra board slots, a market fee discount, and a roll-luck bonus.

**Leaderboards** — Portfolio Value, Total Trades, and Rarest Item Held, each with all-time and auto-resetting weekly variants.

**Milestones & communal goals** — a personal craft-count milestone track and a daily server-wide craft-count goal. Both are built but currently switched off.

**Referrals & ad rewards** — inviting friends earns a gem-watch bonus for both sides. Rewarded ad video is itself gated behind a public server-wide player-count goal, shown to players as a visible progress bar.

## Monetization

Config-driven, all in one place. Gem packs (escalating bonus % per tier), gamepasses (always-boosted ads, ads that survive offline), stacking ad slots, and cosmetic booth slots/skins. Trade-ad boosting is covered above. Money consistently buys visibility, duration, convenience, and cosmetics — never an advantage in the trading/economy math itself, and never blocks the free path to post, browse, or accept trades.

## Items & rarity

Six rarity tiers (Common → Rare → Legendary → Mythical → Godly → Celestial), derived from each item's total supply cap. Base value roughly doubles per tier. Beyond the rotating starter pool, dozens more items exist purely as crafting/event outputs, each with its own supply cap.

New players get a small starter bundle (5 weighted draws) rather than a fixed kit. That's deliberate asymmetry, not noise: because it's *weighted* rather than uniform, two new players end up with meaningfully different portfolios — one got luckier than the other — which means there's immediately something worth trading between them on day one, instead of everyone starting with an identical kit that nobody wants to swap.

## Scam safeguards

The trading systems are built so a player can't be robbed by trusting the wrong person:

- **Direct trades are fully escrowed with hard state-machine invariants** — changing an offer resets both sides' confirmations (kills last-second swaps after you've agreed), confirming is only legal in the open-negotiation state, and both items are locked in before either side is credited. Once settlement begins it can't be aborted and must finish; a stuck settlement is retried until it completes rather than left half-done. Nobody can accept a trade and simply not pay.
- **Booth listings can't be swapped out from under a buyer.** The listing itself IS the offer — price and item are immutable the moment it's posted. A seller who changes their mind can only cancel, which just makes a pending buy fail with "gone" and charges the buyer nothing. There's deliberately no purchase-confirmation delay, because unlike games where a seller can silently swap what's on display between a buyer reading it and clicking, there's nothing here to protect against — a delay would only punish honest buyers.
- **Players standing near a booth go semi-transparent**, so nobody can body-block a stall and hide its stock from other shoppers.
- **The trade board's no-escrow design is safe by construction, not by trust**: a listing is a promise, and taking it either succeeds atomically or fails and charges nobody — there's no window where one side pays and the other doesn't.

## Interface conventions

Large numbers are always abbreviated in the UI (1,300 gems reads "1.3K," not the raw number), and any numeric input box accepts shorthand typing — typing "3k" into a quantity or price field resolves to 3000 automatically. Destructive admin actions (full economy reset) require 3 separate clicks spaced at least 3 seconds apart within a 12-second window, rather than a single confirm dialog, specifically to make it hard to trigger by accident.

## Other systems

Player profiles (viewable by others, with privacy toggles), and offline notifications (plus real push notifications for opted-in players).

## Built for ongoing content — the live-ops backbone

The crafting/event system was deliberately architected as an engine for a constant stream of updates, not a one-time content drop:

- **Seasonal/limited events** are a first-class category with a hard end date baked into config (add a new event, give it recipes and an end timestamp, done — no code changes). Once an event ends, its items are frozen forever ("reobtainable" flips off), which is what makes each season feel genuinely limited-time rather than always-repeatable.
- **Rotating recipes** cycle a subset of a larger recipe pool on a fixed timer (currently a handful active out of a pool of six, every 10 minutes) with zero stored state — purely a deterministic function of the clock, so every server agrees automatically and there's nothing to break on rotation.
- **Sold-out replacement** — when a permanent recipe's capped output sells out, it's automatically swapped for a pre-authored "spare" recipe at the next boundary, so a popular recipe going dry doesn't leave a dead station; new ones can just be authored and dropped in.
- New items, new recipes, and new seasonal events are all pure config additions on top of this — the intent is that content updates are mostly data, not new code.

## Built but currently switched off (ready to launch)

A few systems are fully implemented and wired end-to-end but intentionally disabled pending a decision or more polish:

- **Milestones & communal goals** — a personal craft-count reward track and a daily server-wide craft-count goal. Both just need `enabled = true` and reward tuning.
- **AFK zone reward payout** — the AFK system itself (zones, timers, escalating payout schedule) is fully built; only the actual reward type (items vs. gems vs. roll credits vs. banked trade-ad boosts) hasn't been chosen yet.
- **Real Robux product IDs** — gem packs and some ad-slot dev products are still on placeholder IDs pending the store going live.

## Open ideas under consideration

- **A guided first-profit strategy.** Right now the game teaches its core loop entirely through mechanics rather than screens — Unique Craft, for instance, is explicitly designed to teach "the four ways to get an item" (roll, store, board, direct trade) without a word of tutorial. There's no formal walkthrough yet that hands a brand-new player one concrete, repeatable strategy for turning their starter bundle into their first real profit. Whether that should be an explicit tutorial flow, or just better in-context nudging on top of what already exists (Unique Craft, the weighted/asymmetric starter bundle), is an open question worth researching against how other trading games solve first-session retention.
- **Bots as a new-player liquidity backstop.** The existing bot market simulator (built, currently off) has a "maker" archetype whose entire purpose is liquidity — quoting both sides of the market so other archetypes (crafters especially) always have someone to trade with. The idea under consideration isn't reviving the full simulation, but specifically using a small, targeted presence of that kind — enough that a brand-new player always has *someone* to trade with in their first few minutes, even at 2 AM on a quiet server, rather than depending on real player traffic being enough from day one.
