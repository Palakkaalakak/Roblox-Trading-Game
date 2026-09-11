# Game Info — TBD Trading (Roblox)

An overview of a Roblox item-trading economy game. "TBD Trading" is a placeholder name.

## What the game is

There is no combat, no obstacle course, no simulator-clicker loop. The entire game is: obtain items (gacha "rolls," crafting, or a gem store), hold a collection whose value moves with a live supply/demand economy, and trade — directly with another player, via a public trade board, or via player-run shop booths.

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

## Trading systems

**Direct 1:1 trade** — invite, both sides build an offer (up to 9 item slots + gems each), both confirm, a short cancelable grace window, then escrowed delivery. Works cross-server and even if a partner disconnects mid-trade. No typed chat required — a canned "quick chat" phrase system covers real trading vocabulary and lets players reference specific items ("I want your X") without needing Roblox's age-gated text chat.

**Trade board** — the biggest system in the game. Public listings with no escrow (a listing is a promise, not a deposit, so listed items stay fully usable until someone takes the trade). Three listing types: Swap ("this for that," can auto-settle or ask-first), Bulk (standing gem buy orders for N copies), and Sell (fixed-price gem shop listings). Listings can be server-scoped (free) or global (cross-server). Everyone gets free ad slots; paying with Robux boosts placement and duration on a tiered shelf (hourly/daily/multi-day, with a scarce "Featured" tier), never gates the ability to post/browse/accept for free. Wildcard tokens let a want-side be fuzzy ("Any Rare") instead of a specific item.

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

## Market simulation (bots)

The codebase includes an elaborate bot-driven market simulator (hundreds of agents with different trading personalities — value hunters, trend chasers, hoarders, crafters, collectors, market makers) meant to keep the economy feeling alive with few real players online. It currently exists but is switched off; the game is tuned around real player behavior.

## Other systems

Player profiles (viewable by others, with privacy toggles), offline notifications (plus real push notifications for opted-in players), and an admin/debug layer (hardcoded admin user list, debug gem grants, batch-roll testing tool) that's meant to be stripped before release.
