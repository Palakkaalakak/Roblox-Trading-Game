I understand the product. Players can earn real Robux from playing this game. That is the proposition, not a side note, and every system below is built around it.

The research below is synthesis from design writing, live Roblox economies, creator docs, and player accounts, not a pile of disconnected case studies. The rubrics are qualitative thresholds, not fake scores. Nothing here is playtested. These are design conditions that, if the live game actually produces them, make virality much more likely. They are not a guarantee printed in advance of players.

---

# Part 1 — What actually holds a player, mapped so it can sit inside any game

## The only loop that matters

Every session is the same cycle, at every scale:

**mental model → goal → action → feedback → updated model → next goal**

That cycle exists card-to-card, turn-to-turn, session-to-session, and season-to-season. A game is not a list of techniques. A game is one of these cycles, nested, where the output of the inner cycle is the input of the outer one. If a feature does not change the model, create a goal, or produce feedback the player can act on, it is not part of the game. It is furniture.

Celia Hodent's practical breakdown of retention, from her GDC work on Fortnite and earlier titles, is the cleanest map of what has to be true inside that cycle. Retention is engage-ability, and engage-ability has three pillars that feed each other:

1. **Motivation** — why the next action exists at all.
2. **Emotion** — how the action feels in the moment, including surprise and reappraisal after a loss.
3. **Game flow** — whether challenge, pacing, and learning rise as a sawtooth, not a flat line, so the player can feel competence against a reference point they already have.

Underneath motivation she separates four things that are usually mashed together and then misused:

- Biological and implicit drives: power, achievement, affiliation. Not everyone wants the same one.
- Learned drives: what the environment adds or removes after an action.
- Rewards as feedback, not as the goal. A reward that is the end of the chain kills the chain. A reward that is a means to the next goal keeps it.
- Intrinsic needs (competence, autonomy, relatedness) that extrinsic rewards either support or crush depending on whether the player still feels they chose the action and got better at it.

The behavioral piece underneath that, which she also lays out plainly, is the part most writeups stop at and then misapply:

| Schedule | What the player experiences | What behavior does |
|---|---|---|
| Continuous | Every action pays | Best for learning. Dies the moment you stop paying |
| Fixed interval | Pay arrives on a clock | Spike of activity right before the clock, then a pause |
| Fixed ratio | Pay after N actions | Pause after the payout, longer if N is large |
| Variable interval | Pay might arrive, time unknown | Steady checking |
| Variable ratio | Pay after an unknown number of actions | Highest, steadiest, hardest to extinguish |

Variable ratio is the strongest schedule. It is also the most abused, because people bolt a roll onto a game that has no reason to roll. The schedule only works if the thing being rolled changes what the player can do next. A jackpot that does not alter the next decision is a firework. A jackpot that creates a new trade, a new recipe, or a new person who wants what you just got is a loop.

Two placement rules matter more than the schedule itself:

- Randomness **before** the decision feels like a puzzle the player is solving. They keep agency.
- Randomness **after** the decision feels like a slot. Higher peaks, higher rage, and the player attributes the outcome to the game rather than to themselves.

Both belong in a trading game. They do not belong in the same moment. The roll is after. The trade, the craft, and the listing are before. If you collapse them, the player either feels cheated or feels like the game played itself.

## The drives that survive contact with a real session

These are the ones that show up again and again in games people actually stay in, stated as mechanisms rather than vocabulary:

**Ownership changes valuation immediately.** The moment an item is "mine," the player prices it above what they would have paid to acquire it. In a trading game this is not a flavor. It is the spread. Every trade negotiation is two people both overvaluing what they hold. The game does not need to invent this. It needs to make ownership visible, recent, and costly to reverse, so the bias has something to attach to.

**Losses weigh more than equal gains.** A player who watches an item they almost had go to someone else will work harder to get the next one than a player who simply never saw it. A player who is one craft away from a rank will not log off. A player who is told a listing is about to expire will act. The design consequence is not "punish people." It is: always show the thing that is about to be lost, and make the action that saves it the same action as the core loop.

**Proximity accelerates effort.** The closer a visible goal, the faster people work. This is why progress that starts at zero feels dead and progress that starts at 70% of a small first goal feels alive. It is also why a cashout number that is legible from minute one outperforms a cashout number that only appears after you "unlock the economy."

**Almost-wins increase the next attempt.** A result that is visibly adjacent to the result the player wanted produces more subsequent attempts than a clean miss. This is a structural property of the feedback, not a speech bubble. If your roll, your craft, and your trade result never show adjacency, you are throwing away the strongest free retention signal you have.

**Unfinished tasks stay in the head.** An open craft, an open listing, an open quest, an open trade ad, an open crew goal — each one is a reason the game is still "on" when the client is closed. The cap is real. Past a handful of open loops the player cannot see which one to close, and they close the game instead. Three visible open loops beat twelve buried ones.

**Labor increases attachment.** A player who did something to an item prices it higher and abandons it less easily than a player who was handed the same item. The labor has to be real and short. A five-minute ritual that produces a worse item than buying one is not labor. It is a tax, and players learn to route around taxes.

**Other people's behavior is the price list under uncertainty.** When a player cannot evaluate an item alone, they copy. Visible trades, visible booths, visible ranks, a public tape of what just sold — these are not social features. They are how price gets discovered. A trading game with no visible tape forces every player to invent a price, which means most of them invent the wrong one and leave.

**Status only works if a stranger can read it in one second.** A rank in a menu is a spreadsheet. A rank floating over a head, a booth that looks different, a title that changes how other players open a trade with you — that is status. Status is the drive that makes people do the unprofitable trade, because the unprofitable trade is how they get seen.

**Affiliation needs a shared object.** A crew with a chat and a badge is a Discord with extra steps. A crew whose goal is a number the market can move — a craft completed together, a bulk order filled together, a cashout milestone the crew hits — gives affiliation something to do inside the loop instead of beside it.

**Competence needs a reference point.** Players do not feel growth from a bigger number. They feel it when an old situation returns and they handle it differently. The first trade they botched, seen again two sessions later and closed cleanly, is worth more than a level-up popup. Sawtooth, not slope: give them a moment where the game is briefly harder than they are, then a moment where the same situation is easy, so the difference is theirs.

**Autonomy is the feeling that the outcome was chosen.** Even a roll can carry it if the player picked the currency, the pool, and the moment. A roll the game fires for them does not. The more of the loop the player can aim — which item to post, which recipe to run, which order to fill — the more a loss gets attributed to a decision they can improve, and the more they come back to improve it.

**The pause after a payout is the dangerous moment.** Fixed schedules produce a dead zone right after the reward. If your only reason to stay is the thing that just paid, the player leaves in that dead zone. The design job is to have the payout itself create the next open loop before the pause starts. The cashout, the craft result, the roll result — each one should land already pointing at a person, a listing, or a recipe.

**Generosity only works if the gift has a job.** Flooding a new player with rewards they cannot price teaches them that rewards are noise. Show the lock before the key. The player should meet the thing they cannot do yet, feel the lack for a few seconds, and then receive the thing that removes the lack. A starter bundle that is explained after the player has already tried to trade and failed is worth more than a starter bundle explained on a splash screen.

**Reappraisal decides whether a loss ends the session.** A trade that fails, a roll that misses, a listing that expires — if the only feedback is the loss, the player leaves. If the same screen shows what moved (you learned the price, you are closer to the recipe, someone just posted the other half), the loss becomes information. Information is a reason to act. A red "failed" is a reason to close the client.

## What "viral" actually is on a platform, before any rubric

Virality here is not a vibe. On Roblox specifically, organic distribution from Home is retrieval then ranking, and ranking is driven by what players do after they arrive from recommendations — not by what your ads did. The signals Roblox publishes as mattering most are: play-through rate, first-play bounce (under 60 seconds and 61–180 seconds, as a negative), play days per user across D1 / D2–7 / D8–28, and playtime per user. Next to those: intentional co-play days, qualified sessions, spend days, and Robux spent per user. Creator Rewards pays 5 Robux when an active spender (someone who has spent at least $9.99 on the platform in 60 days) gives your experience 10+ minutes and you are one of their first three experiences that day.

Read that as a design spec, not a marketing note:

- The first minute has to contain an action, not a menu.
- The first session has to contain a reason to come back tomorrow that is already in progress when they log off.
- Ten minutes is a payout threshold for you, so the loop has to be able to fill ten minutes without the player running out of decisions.
- Spend has to be able to happen on day one from a player who already spends elsewhere, which means the thing they buy has to be legible in the first session.
- Friends have to have a reason to be in the same server that is not "hang out." Co-play days are a ranked signal.

A game that nails psychology and bounces in 40 seconds gets nothing. A game that holds for 12 minutes and brings people back on day 2 and day 8 gets distribution. The rubric is a translation of the psychology into those conditions.

## The universal rubric

Read each row as a condition. "Second-best or better" means the live game is clearly producing the behavior in the middle column or the right column, not that you scored yourself a 3 in a spreadsheet. If most rows are in the middle or right column at the same time, distribution becomes much more likely, because those columns are the same behaviors the platform and the player both reward. Left column is how trading games and simulators actually die.

| Condition | Dead | Holding | Spreading |
|---|---|---|---|
| First action | Player reads, then decides whether to play | Player is handed a goal and acts inside 30 seconds | Player acts inside 15 seconds and the action changes their inventory |
| First session exit | Player leaves with nothing in progress | Player leaves with one open loop they can name | Player leaves with a specific person, listing, or craft waiting, and knows what it will do to their inventory |
| Decision density | Long stretches with nothing to decide | A decision every minute or two | Every decision changes the inventory or the price of something in it, and the next decision is visible before the current one resolves |
| Reward meaning | Rewards arrive before the player knows what they buy | Rewards are currency the player can spend on a known next step | Every reward is either an item someone else wants or the currency that buys one, and the player has seen that want |
| Schedule mix | One schedule, usually a timer | A timer plus a roll | Timer, roll, and player-triggered payouts (crafts, fills, trades) all feed the same inventory, so a payout on any of them creates work on the others |
| Loss visibility | Losses are silent | Losses are shown | The thing the player almost had is shown next to the action that gets the next one, and that action is the core verb |
| Status readability | Rank lives in a menu | Rank is visible to the player | A stranger can read your economic position in one second and it changes how they trade with you |
| Social proof of price | Prices are guessed | A value list exists outside the game | The game itself shows what just traded, for what, and the player uses that tape to price their own offer |
| Competence reference | Numbers go up | Numbers go up and a tutorial explains why | An early failure repeats later and the player handles it, and the game shows them that they did |
| Open-loop count | Zero, or more than the player can see | A few, buried in menus | Two or three, always on screen, each one closeable by the core verb |
| Return trigger | "Come back tomorrow" | A daily reward | Something in the world changed while they were gone (a fill, a craft ready, a price move, an offer) and the login screen shows it |
| Co-play | Friends can stand near each other | Friends can chat | Friends can move the same number (a fill, a craft, a cashout) and both inventories change |
| Monetization timing | Store is a tab | Store is offered at a moment of want | The thing being sold removes a friction the player just hit, in the same screen they hit it |
| Session length source | Padded with unskippable content | Enough content to fill 10 minutes | The loop naturally produces another decision at minute 10 because the last decision created it |

A game at "Holding" across most rows retains. A game at "Spreading" across most rows is what the Home ranking is built to distribute. The difference between those two columns is almost never a new feature. It is whether the existing feature changes the inventory and points at the next decision.

---

# Part 2 — The same machinery, on Roblox, in trading games specifically

## What the platform actually pays you for

Three separate Roblox money flows matter, and they are not the same flow as the one you are promising players.

**Your revenue** is what players spend: gamepasses, dev products, subscriptions, and the Robux that buys gems. That spend is also a ranking signal (spend days, Robux per user).

**Creator Rewards** is Roblox paying you 5 Robux when an active spender gives you 10+ minutes and you are among their first three experiences that day, plus audience-expansion share if you bring new or lapsed users who then spend on the platform. This pays for session length and for being a daily habit of people who already spend.

**Player cashout** is you paying players in Robux, funded only by gem purchases and ad-watched gems at 10 gems per 1 Robux that reaches you. This is a promise you are making with your own balance. It is also the single strongest reason anyone on this platform has to open your game instead of Adopt Me, MM2, or Pet Sim, because none of those pay the player in Robux for trading. Pet Sim players who want real money leave the platform and sell in Discord. You are proposing to keep that desire inside the client. That is the wedge. Treat it as the wedge.

Discovery docs are explicit that metadata which leads with a monetary reward gets less exposure. "Robux! Play now!" in the title is how you lose the Home impression, not how you get it. The cashout is the thing players tell each other. It is not the thing the thumbnail screams. The thumbnail shows the trade, the pile, the title over the head. The player who is already inside learns they can cash out, and they are the one who brings the next player.

## Why trading games on this platform actually hold people

Adopt Me, MM2, and Pet Sim are not the same game, but the part of each that keeps a player past the first week is the same part: an item with a socially agreed price, a person who wants it, and a visible gap between what you hold and what you could hold.

Adopt Me's trading hub exists because the previous loop was server-hopping until you found a body. The hub did not replace the trade. It removed the walk. Players still need Elvebredd and similar value sites because the game does not show a tape. The value site is a symptom of a missing feature, and it also became the game. People do not trade the pet. They trade the number on the site. When the site and the player's desire diverge, the trade dies even if both players wanted the pet. A trading game that publishes its own recent-trade tape pulls that power back inside the client, which means the session happens in your server instead of on a website.

MM2 trading persists on ugly knives with high numbers and pretty knives with low ones, because the community number and the visual desire are two different currencies. Players stay because both currencies are tradeable against each other. A game with only one currency of desire (rarity, or looks, or a gem price) has fewer trades, because fewer pairs of players disagree. Disagreement is liquidity. You want items that are worth different things to different people for different reasons: recipe input, roll fuel, booth flex, cashout path, crew goal. An item with one use has one price. An item with four uses has a spread, and spreads are what traders live on.

Pet Sim's own players, asked directly why they stay, do not say "the pets are cool" first. They say gambling, flexing, trading, the overnight drop, the huge that proved it was possible, the money already spent, the clan. One of them said the economy is the closest thing on the platform to a real market, and that if the economy dies the game dies. Another said they kept playing because they could sell gems for real money off-platform. Read that again against your proposition. You are building the thing those players are already leaving the platform to do, and you are building it where the session, the spend, and the status all stay in one place.

The failure mode of these games is also consistent. Inflation kills the number. When everything is worth more gems than a new player can touch, the new player has no trade, and the old player has no one to trade with. Pet Sim players describe this in plain language. The fix is not a bigger number. The fix is a sink that removes items and currency at the same rate production adds them, and a permanent reason for a rich player to want what a poor player has. Your asymmetric starter pools are that reason, if and only if the asymmetry keeps getting regenerated. A one-time starter bundle creates one day of asymmetry. Crafting, unique crafts, and the roll have to keep creating it, or the market finds one price and stops moving.

## What Roblox players actually do in the first minute

A developer who logged their own game for three months found 45% of players gone in 30 seconds, cut to 18% by putting a clear first action at spawn. Shortening a tutorial from five steps to three moved D1 from 6% to 15%. Daily login rewards roughly tripled D7 in that same game. Separate from that, a common practitioner read of playtime is that under 5 minutes is bad, 7–9 is good, 9–15 is excellent, and past 15 is rare. Creator Rewards pays at 10 minutes for a qualifying user. Your first-session design target is not "finish the tutorial." It is: action inside 15 seconds, a completed core verb inside 3 minutes, and a reason to still be deciding at minute 10.

Mobile sessions run shorter and convert to paying at a higher rate. Your entire loop has to be completable with a thumb. A trade board that needs a keyboard is a desktop feature in a mobile market.

## PLS DONATE is the closest existing proof of the cashout desire

PLS DONATE holds thousands of concurrent players doing nothing but standing at a booth asking other players for Robux. The loop is: stand, be seen, receive or not, adjust the booth, stand again. People donate to booths that look intentional and to players who are present and responsive. The desire being served is not gameplay. It is Robux, plus the status of being the person who has Robux, plus the small social hit of being the person who gave it.

Your game is that desire with a loop underneath it. The booth, the floating title, the public cashout — these are not references to PLS DONATE. They are the same drive, pointed at an inventory instead of a sign. A player who has cashed out once, with the amount visible over their head, is doing the job a donation booth does, except the Robux came from play and the next player can see the path.

## The Roblox trading rubric

Same reading rules. Middle or right column, across most rows, in the live game.

| Condition | Dead on Roblox | Holding | Spreading |
|---|---|---|---|
| First 30 seconds | Spawn, menu, read | Spawn, objective marker, walk | Spawn, inventory already changed, one button that does the verb |
| Minute 10 | Tutorial still going, or nothing left to do | Player has traded or crafted once | Player has an open offer, an open craft, and has seen a price move caused by someone else |
| Return reason | Daily chest | Daily chest plus a quest | Something another player did to your inventory or your listing while you were offline, shown before you spawn |
| Price discovery | External value site, or none | A number you publish | A live tape of completed trades the player quotes in their own offers |
| Asymmetry | Everyone starts identical, market clears in a day | Starter pools differ | Starter pools, unique crafts, and the roll keep producing items that specific other players need and you do not |
| Rich-needs-poor | Endgame players trade only with each other | Endgame sells to new players | A high-rank player is routinely buying or crafting with something only a low-rank player holds |
| Status at a distance | Rank in profile | Nametag | Title, booth tier, and last cashout readable from across the server, and it changes who walks up |
| 10-minute fill | Content gates | Enough UI to click | The loop generates the next decision out of the last one, so minute 10 is not a different activity from minute 2 |
| Co-play signal | Friends can join | Friends can trade each other | A friend joining moves a shared number (crew goal, bulk fill, joint craft) that neither could move as fast alone |
| Spend moment | Store button | Store with packs | The buy button appears on the exact friction the player just hit, priced in gems, with the Robux cost of those gems visible |
| Cashout legibility | Hidden until you qualify | Explained in a menu | A number on screen from minute one showing gems, the exchange, and the Robux it becomes, moving when you profit |
| Thumbnail honesty | Leads with Robux | Shows items | Shows a trade and a visible pile, and the player who clicks finds exactly that in the first minute |
| Sink | Items and gems only enter | A craft sink exists | Items leave the economy through crafts, sacrifices, and cashout at a rate that keeps a new player's starter relevant for weeks |
| Device | Desktop-first boards | Usable on mobile | The core verb (offer, accept, craft, list) is one thumb, and the tape is readable without a hover |

---

# Part 3 — The game you described, and the loop it is missing

## What you already have, read as one machine

You have the right pieces. They are not yet one verb.

The verb is **move an item to someone who prices it higher than you do, and get paid in gems.** Crafting, rolling, the board, the market, the bulk tab, the booth, the crew, the quests, the rank, the cashout — every one of those is a way of finding that someone, becoming that someone, or getting paid for having been that someone. The moment a feature does something else, it is a second game.

You also have the correct monetization constraint, and it is worth stating back so the design never "solves" it by cheating. Gems enter only through Robux spend or through ads at 10 gems per 1 Robux that reaches you. Gems do not get minted as quest rewards, login rewards, or crew rewards. That constraint is not a problem to design around. It is the reason the cashout can be real. Every system below respects it. Where a reward would normally be gems, it is an item, a fee reduction, a time reduction, or information.

The fear you named is correct. A liquidity bot plus asymmetric starters plus a board is a market. A market is not a loop until the player has something to do between trades that changes what they can trade. Right now the gap between "I spawned" and "I am in a negotiation" is a tutorial, a craft, and then a lobby. That gap is where your 30-second bounce lives.

## The second part, built out of the inventory instead of beside it

You were right that the loop needs a second motion, and right to be unsure about bolting on a hunt. The second motion is not a place. It is the other half of the same verb.

Trading answers: who wants what I have? It is player-paced, social, and dead when nobody is online or nobody disagrees with you.

The missing half answers: what do I hold, and what does the game itself want from me right now? It has to be available at minute one, solo, on mobile, in under a minute, and its output has to be an item from the same pools the market trades. If the output is a coupon, a ticket, or a currency that is not an item, you have built a second game that pays the first game a wage. Players will do the wage and skip the market, or do the market and ignore the wage. Either way one of them starves.

The motion that fits is a **priced offer from the economy itself**, on a clock, against your actual inventory.

Call it the **Desk**. It is not an NPC you walk to for a tutorial and then abandon. It is the surface the whole game happens on. The Crafter, the roll, the gem rotation, and the cashout are modes of the Desk. The board, the market, and the booth are the Desk pointed at other players instead of at the house.

Every few minutes the Desk puts up one offer that only exists because of what this player holds and what the market is short of. Not a random quest. A price.

Examples of what the Desk says, all of them the same sentence with different nouns:

- "I am paying 400 gems of item value for two of your Low Glass and one Copper. You hold both. The offer expires in 6 minutes."
- "Nobody has listed a Red Coil in 20 minutes and three unique crafts need one. Break your spare and I will pay the spread."
- "Your unique craft wants a Feather. A player named X just listed one. Here is the trade, pre-filled."
- "You are 1,200 gems of value away from the next profit title. This offer covers 300 of it."

The player does not go find a boss. The player looks at their inventory, looks at a price, and decides whether the spread is worth it. That decision is the same decision as a player trade. The house is simply always willing to be the other side, at a worse price than a player would take, so the loop never stops when the server is empty and never outcompetes a real player when one is there.

This is why it is not a disconnected feature. A Pet Sim egg hatch produces a pet you then use to hatch more eggs. A Blox Fruits drop produces a fruit you then fight with. Your equivalent is: the Desk consumes items and produces items, and both the consumed and the produced thing are what players trade. The house is a permanent, slightly dumb trader. Players are the sharp traders. The game is the difference between the two prices.

How the Desk stays solvent and stays inside your gem rule:

- The Desk never pays gems. It pays items, or it deletes items and hands back a bundle of items whose tradeable value the tape says is higher.
- When a player would rather have gems than the item, they sell the item on the market to another player, who paid gems they bought. The house never mints gems. Players move gems that already exist.
- The Desk's buy price is always worse than the recent player-to-player tape. If players are trading Red Coils at 200, the Desk buys them at 140 of item value. A player who can find another player always does better. The Desk is the floor, not the market. This is also your liquidity bot, made visible and made into the thing the player does while waiting.
- The Desk's offers are biased toward whatever the tape says is scarce. Scarcity is measured, not authored. If unique crafts and recipes are consuming Feathers, the Desk starts asking for Feathers, which makes Feathers worth walking across the server for, which makes the player who rolled a Feather three minutes ago suddenly holding something. That is asymmetry regenerating itself every cycle instead of once at spawn.

The roll, the craft, and the Desk are now one machine:

1. Roll spends an item or gems and returns items. Some are wanted by recipes, some by the Desk, some by a specific player.
2. Craft spends items and returns one item. The returned item is either a flex, a recipe input for someone else, or Desk fuel.
3. Desk spends items and returns items, priced off the tape, biased toward scarcity.
4. Any of the three outputs can be listed, posted, booth-sold, or fed back into either of the other two.

A player who is alone still plays, because the Desk is there. A player who is in a crowd plays better, because a player pays more than the Desk. The crowd is the upgrade, not the requirement. That is the difference between a trading game that is empty at 7am and a trading game that is playable at 7am and crowded at 4pm.

## The first session, as a single chain

The current tutorial walks the player to an NPC and ends. That is a tour. Tours are where the 30-second and 3-minute exits happen. Replace the walk with the chain. The chain is the tutorial. There is no separate tutorial.

**Second 0–15. The takeover is the first trade, not a loot screen.**
The asymmetric bundle is revealed one item at a time, best item last, with the tape price already on it — even if the tape is seeded by the house on day one. The player does not see "you got 7 items." The player sees "you got a Red Coil, last player trade 180, you have the only one in this server." Or, for the other starter: "you got 14 Low Glass, the Desk is buying Low Glass right now at 40 of value, and three players in this server have recipes that eat it." The asymmetry is stated as a sentence about other people, not as a rarity color. Ownership bias attaches to a sentence. It does not attach to a color.

**Second 15–90. One Desk offer, pre-aimed at what they were just handed.**
The Desk offer uses items from the bundle they are holding. Accepting it is one button. The result is a new item, animated, with its tape price, and with one line: "this is worth more to a player than to the Desk." That line is the entire game, taught by having just done it. No text box. The player has now completed the core verb against the house. They know what a spread is because they just took one.

**Minute 1.5–3. The unique craft, aimed at a hole the Desk just created.**
The unique craft should not be a random recipe. It should require one item the player does not hold and that the Desk's last offer, or the tape, says somebody does. The craft sits on screen as an open loop with the missing input named. This is the moment the player needs another person. Not before. If you send them to the board before they have a hole, the board is a directory. If you send them after they have a hole, the board is a tool.

**Minute 3–5. One pre-filled player offer.**
The trade board opens already filtered to the missing input. If a real player has it listed, the trade is one tap. If nobody does, the liquidity bot posts it at a worse price than a player would, clearly marked as the house, and the player can take it or wait. They complete the unique craft. The crafted item is unique to them, which means by construction someone else's unique craft or a recipe wants something adjacent to it and not this exact one. You do not need to explain asymmetrical demand. You just created a second player, somewhere, whose Desk is about to ask for something this player now holds.

**Minute 5–10. The cashout number and the first real want.**
From this moment the Robux number is on screen. Gems, divided by the exchange, shown as Robux, ticking when the player profits. A player at 600 gems sees 6 Robux. That is fine. The number is small and real, and it moves. Next to it, the next profit title and the gem distance to it. The player is not told "you can earn Robux." The player is watching the Robux number change because of a trade they just did.

Then the rank gate, used correctly. Noob cannot post a trade ad. The quest to become Casual is not "talk to three NPCs." It is "fill one player trade" — which they may have just done — and "list one item." Listing is the second real want, because a listed item can fill while they are offline, which is the return trigger. The session does not end by releasing them into a lobby. The session ends, whenever they leave, with a listing live and a unique craft sitting one input short of the next one.

That is a first session with no tour, no second game, and no moment where the player is supposed to figure out why they are here.

## Where each system you already named sits inside the verb

**Crafter.** Two directions, both sinks, both spread-makers. Many-low into one-high is how a poor starter becomes interesting to a rich player. One-high into many-low is how a rich player manufactures the exact fodder a poor player's unique craft is asking the Desk for. The second direction is the one that keeps rich players buying from poor players. Without it, rich players only trade with each other and the new player has nothing anyone wants. Show both directions as spreads against the tape, not as recipes to memorize. "Sacrifice the Coil, receive 9 Glass, the Desk is paying 40 per Glass this hour" is a decision. "Recipe #14" is homework.

**Unique crafts.** These are your permanent asymmetry engine. They only work if the missing inputs are drawn from the same pools other players are holding and rolling, and if the crafted output is itself an input to someone else's unique craft or to a public recipe. A unique item that only its owner wants is a trophy. A unique item that is one input away from a public recipe is a trade. Show the player, on the craft, the number of other players currently blocked on an input this craft produces. That number is the reason to finish it.

**The roll.** A timer roll is a fixed interval. It produces a login spike and a pause. Keep the timer, and add a second roll the player can fire by spending an item the Desk is currently buying. Now the roll is sometimes a slot and sometimes a decision about which item to burn. The result screen shows adjacency: how close the roll was to the item their unique craft wants, and who in the server holds the one they missed. The near-miss has somewhere to go. A near-miss that dumps the player back at the roll button is a slot machine. A near-miss that opens a pre-filled trade is the loop.

**Gem store rotation.** This is a fixed-interval scarcity shop. It works if the rotation is partly the items the tape says are scarce, not a hand-authored list, and if the discount is visible as a spread against the tape. "20% off" means nothing. "Cheaper than the last five player trades, gone in 4 minutes" means something. Buying here spends gems the player bought with Robux, which is the monetization, and it puts an item into the same pools, which is the loop. The rotation timer is also an open loop that survives logout.

**Trade board, market, bulk buy.** These are the same surface at three zoom levels. Board is a sentence ("want X, have Y"). Market is a price ("X for 200 gems"). Bulk is a shared price ("400 of us will take Glass at 30"). Do not make the player learn three interfaces. One listing object, three fields, and the bulk tab is just a listing where the quantity is larger than one player holds, so other players can attach their stock to it and split the fill. Bulk is your co-play signal. Two friends attaching stock to the same order is intentional co-play that moves a number. It is also how a new player with 14 Low Glass sells them in one action instead of 14.

**Direct trade.** The negotiation is the game. Show both players the tape price and the Desk price on every item in the window, so the argument is about the spread and not about whether one of them is lying. A player who can see that the other side is offering under the Desk price does not get sharked on their first day and leave. A player who wants to pay over the tape for a specific item still can. Information makes more trades happen, not fewer, because the trades that were going to be scams were going to end the session anyway.

**Ranks and the profit ladder.** Gating features instead of currency is the right call, with one correction. The gate should open by doing the verb, not by doing chores. Noob to Casual is one completed player trade and one live listing. Casual to Regular is a craft that used an item bought from another player. Regular to Trader is a profit threshold measured in tape value, not in gems bought. The profit titles after that are the ladder people will actually chase, because the title is over their head and the Robux number is next to it. Each title's threshold should be visible from the title before it, with the gap shown in gems and in Robux. Proximity does the work. A player at 80% of the next title does not log off to go play something else.

The floating title is your status system. Make it carry three things a stranger can read while walking past: rank or profit title, last cashout amount, and whether their booth is live. That third one turns status into foot traffic.

**Quests.** Daily and weekly quests that pay gems violate your own solvency rule, and quests that pay nothing get skipped. Quests pay in fee cuts, in Desk-offer quality, in roll charges that consume items rather than gems, and in recipe unlocks. The daily is always one Desk offer above the normal price, one roll that is biased toward the player's open unique craft, and one "your listing filled" bonus that is a fee rebate on the next listing. All three are the verb, pointed slightly in the player's favor, and none of them mint gems. The weekly is a crew-scale version of the same thing.

**Crews.** A crew goal that is "earn X gems together" pushes people to buy gems or to sit on the AFK pad. A crew goal that is "fill 200 bulk orders of whatever the Desk says is scarce this week" pushes people to trade, to roll, and to recruit the one member who holds the scarce thing. The perk for hitting it is a crew booth, a crew listing that pools stock, and a Desk bias for the whole crew for the next day. Relatedness with a shared object. The crew chat will happen on its own. You do not need to design the chat. You need to design the number they are all moving.

**Booths.** A booth is a listing you stand next to. PLS DONATE already proved that standing next to an offer, being present, and looking intentional gets Robux. Your booth shows the tape spread of what is on it, the player's title, and their last cashout. Extra booth slots as a gamepass is a clean spend: it is more surface area for the same verb, bought at the moment the player has more items than one booth holds. Do not make the booth a decorating minigame. Decoration that does not change the offer is a second game. A single "style" toggle that signals price tier is enough, because buyers use it as a filter.

**AFK pads.** Idle income that mints gems breaks solvency and trains players to leave. An AFK pad that advances the thing they already started is the pad you want. While they sit, their live listings stay up, their booth stays browsable, their roll timer accrues one charge that still costs an item to fire, and the Desk queues its next offer so it is waiting when they stand up. The pad is a pause button on the loop, not a second income. Players who want to go to school and come back to a fill will use it, and a fill that happened while they were on the pad is the strongest return trigger you can build, because it is another player spending gems that were bought with Robux.

**Leaderboards.** A gem leaderboard rewards spending and AFK. Run three boards: profit in tape value over the last 7 days, Robux cashed out, and bulk orders filled. All three are the verb. All three are readable as status. Reset the profit board weekly so a new player can appear on it. Never reset the cashout board. The cashout board is the proof that the proposition is real, and it is the thing players will screenshot.

**Cashout.** The threshold and the rate are balance, not design, but the presentation is design. The number is always on screen. The moment of cashout is public: a short, server-visible event on the player who cashed out, with the Robux amount, written onto their title for the rest of the day. That is the PLS DONATE booth moment, earned. It is also the advertisement your metadata is not allowed to be. Players will clip it. You do not put it in the thumbnail. You put it in the server, over a real player's head, every time it happens.

The exchange rate being worse than buying Robux directly is fine and should be obvious. Players are not cashing out because it is the efficient way to buy Robux. They are cashing out because they made it. The making is the game. The rate being public and stable matters more than the rate being generous. A rate that moves without a stated rule reads as the house changing the deal, and that is the one thing that will empty a trading game. If you ever change it, change it on a date you announced, and show the old and new rate on the cashout screen for a week.

**The liquidity bot.** Keep it. Make it visible and make it the Desk when no player is on the other side. A hidden bot that secretly takes the other side of trades at good prices teaches players that trades fill magically, and the day you turn it down the game feels broken. A visible house price that is always a little worse than a player teaches players to prefer players, which is what you want, while still giving a solo player something to do at minute one.

## Spend, placed on the friction instead of in a store

Every Robux product should be a faster or wider version of the verb, offered on the screen where the player just felt the limit.

- Gem packs, on the market screen, at the moment a listing is priced in gems the player does not have. The pack that covers the listing is the one highlighted. The Robux-to-gems-to-Robux-cashout math is visible, so the player can see that buying gems to flip can return Robux and can also see that the house takes a cut. Informed spend converts better than a surprise overdraft, and it keeps the cashout promise believable.
- Trade ad boost, on the board, on a listing that has had no offers. The boost is priority in other players' pre-filled searches, not a cosmetic arrow.
- Extra booth slot, on the booth, when the player tries to place an item and the booth is full.
- Quest skip, only for a quest that is "wait" and not for a quest that is "trade." Skipping a wait is a convenience. Skipping the verb removes the player from the loop you need them in.
- Subscription: one extra Desk offer per cycle, biased to the player's open craft, and a fee rebate on listings. It does not mint gems. It makes the same loop fire more often and cost less in fees. Fees are your gem sink. The subscription sells the sink back at a discount, which is sustainable because the subscriber is also the person most likely to buy gems to post larger listings.
- Ads: 10 gems per 1 Robux that reaches you, offered at the same moment as a gem pack, as the slow version of the same purchase. The player choosing between "watch" and "buy" is a monetization decision that does not interrupt a trade. Do not offer it on a timer in the middle of a negotiation.

## What not to add

A zone, a hunt, a combat room, a tycoon plot, a pet that needs feeding, an obby that drops a token. Any of those produces a session that does not change the inventory through the same pools. Players will do whichever side pays more per minute and abandon the other, and you will have split your concurrent count across two games that share a lobby. If you want more "doing," add it as another price the Desk can offer, another recipe the crafter can run, another way to attach stock to a bulk order. The content updates of this game are new items in the same pools, new recipes that consume old items, and new titles on the same ladder. That is also how you avoid the inflation death: every update should consume more of the old item than it creates of the new one, and the tape will tell you whether you got the ratio right.

## The rubric for this game

Same rules. This is the bar the live game has to clear. Middle or right column across most rows, measured in the analytics, not estimated in a design doc.

| Condition | This game is failing | This game is holding | This game spreads |
|---|---|---|---|
| First 15 seconds | Takeover screen, then a walk to an NPC | Takeover, then a marker | Takeover states the spread in one sentence and the Desk offer is already aimed at the bundle in their hand |
| First completed verb | Unique craft against an NPC, then a lobby | One craft and one trade inside the session | House trade, then unique craft, then a player or house fill, all inside 5 minutes, all changing the same inventory |
| Minute 10 | Player is done or lost | Player is browsing | Player has a live listing, an open craft with one named missing input, and has watched the Robux number move |
| Solo play | Nothing to do without another player | Bot fills trades invisibly | The Desk is a visible, worse-priced counterparty, and the player can tell the difference and prefers players when they appear |
| Asymmetry after day 3 | Starter pools have been traded into one price | Unique crafts still differ | Desk offers, unique crafts, and the roll are all consuming whatever the tape says is scarce, so a new starter is still relevant |
| Rich needs poor | High ranks trade with high ranks | High ranks sell to low ranks | Sacrificing a high item into fodder, and bulk-filling low items, is routinely how a high rank progresses a title |
| Cashout belief | Explained in a help menu | Shown as a balance | On screen from minute one as Robux, and a real cashout has been seen over another player's head in the server |
| Return trigger | Daily quest reset | Daily quest plus a reward | A listing filled, a Desk offer queued, or a craft input listed by someone else while they were offline, shown before spawn |
| Gem solvency | Quests or pads mint gems | Gems only from purchases and ads | Every reward is an item, a fee cut, a bias, or information, and the gem balance of the economy is auditable against Robux in |
| Price truth | Players need an external site | You publish a value | The tape of completed trades is in the trade window, and players quote it |
| Near-miss destination | Roll again | Roll again, with a pity counter | The miss names the player or the listing that has the adjacent item and opens the trade |
| Status | Rank in a menu | Floating rank | Title, last cashout, and live booth readable from across the server, and players walk to the high ones |
| Co-play | Friends can stand together | Friends can trade | Friends attach stock to the same bulk order or the same crew scarcity goal, and both inventories move |
| Spend placement | A store tab | Packs in the store | The gem pack, the boost, and the booth slot appear on the screen where the player just hit the limit, with the Robux math visible |
| 10-minute Creator Rewards fit | Padded tutorial | Enough clicking | The loop produces the next decision out of the last one, so a paying Roblox user still has an unresolved offer at minute 10 |
| Thumbnail vs. promise | Title leads with Robux | Title mentions trading | Thumbnail shows a trade and a pile; the Robux is discovered in the first session and then carried out of the game by the player who cashed out |
| Sink versus production | Items only enter | Crafts consume some | Every content drop consumes more old items than it adds new ones, and the tape stays movable for a new player |
| Open loops on screen | None, or a quest log | A quest tracker | Exactly three: the open craft, the live listing, the next title gap in Robux. Everything else is behind them |
| Loss reappraisal | Trade failed | Trade failed, try again | The fail screen shows the tape, the Desk price, and the next best counterparty, so the loss is a new offer |
| Device | Boards built for a mouse | Works on mobile | Offer, accept, craft, list, and read the tape are all one thumb |

## How you would know it is working, without pretending you already measured it

Watch four numbers before you spend on ads. First-session bounce under 60 seconds. Whether the player who finishes the house trade also completes a player or house fill in the same session. Whether day-2 returners come back to a listing that filled or a Desk offer that was waiting, rather than to a daily chest. Whether gems outstanding are fully backed by Robux received at the 10:1 rule. If the first three are weak, no amount of booths, crews, or ranks will move Home recommendations. If the fourth is weak, the cashout promise is a timer on the business.

The game you described is one verb short of being a loop, and the verb is already implied by the systems you listed. The Desk is that verb made available when no player is around, at a worse price, against the same items, feeding the same tape. Everything else you named either helps a player find a better price than the Desk or shows other players that they did. That is a game. A second zone is not.
