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

## Getting items

**Rolls (gacha)** — 5 tiers (Basic/Solid/Lucky/Grand/Mythic), gems only, no pity system, straight weighted odds. Higher tiers cost more and roll from higher rarity windows. Rolls draw from a "pool" — a rotating set of items spanning all six rarities, which is the entire rollable set at any moment. The advertised odds are exact: how many copies of an item remain never changes its drop chance, and the pool is replaced the instant any one of its items is exhausted (an item at zero would otherwise hand its share to the rest of its rarity). A retired pool isn't destroyed — crafting and roll payments return consumed copies to it, and once it has refilled enough it can become the active pool again.

**Crafting** — recipes consume items (no gem fee) to produce something worth more than the inputs. Structured as a ladder: common materials → refined materials → mid-tier Artifacts → capstone Grails, each rung more valuable, with capstones steep enough that no single player farms them alone. Includes:
- Permanent stations always available (some deliberately cheap as a new-player on-ramp).
- Rotating recipes (a handful active at a time, on a timer).
- Sacrifice recipes — the heaviest true item sinks in the game.
- Seasonal/limited events with a hard end date; once ended, those items are frozen forever.
- **Unique Craft** — a personal mechanic where each player periodically gets temporary access to craft one existing item that no live recipe currently produces, with a cheap shopping list priced well below the output's value. Extra slots for holding more of these at once are a steep gem sink.

**AFK zones** — standing on a pad accrues a reward every 10 minutes, increasing each tick, reset on leaving. Built and wired end-to-end; the actual reward payout (items, gems, boosts, or roll credits) hasn't been chosen yet.

**The Store** — a fixed-price NPC shop, separate from rolls. Every item is limited stock at a hand-set gem price that never moves as it sells (unlike rolls, this isn't formula-driven). Only a rotating subset of the catalog is on sale at once (a 6-hour "shelf" window), and within that a couple of shelf items go on a timed 35%-off sale every 15 minutes — a genuine demand signal, since buying below market Value is free profit that drains that item's stock and makes it scarcer for everyone else holding one. Per-player purchase limits apply per item.

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

Six rarity tiers (Common → Rare → Legendary → Mythical → Godly → Celestial), derived from each item's total supply cap. Base value roughly doubles per tier. New players get a small weighted starter bundle. Beyond the rotating starter pool, dozens more items exist purely as crafting/event outputs, each with its own supply cap.

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
