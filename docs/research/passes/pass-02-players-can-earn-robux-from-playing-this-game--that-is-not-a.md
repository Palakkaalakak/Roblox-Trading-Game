Players can earn Robux from playing this game. That is not a side feature. It is the terminal reward that makes gems, items, and trades mean something, and it is the same proposition that made PLS DONATE a category. Everything below treats that as real: gems are a solvency-backed claim on Robux, items are how players compete for those gems, and the loop has to make both of those feel close enough to touch in the first session.

I am not going to score this 2 vs 3 vs 4. Those numbers would be invented. The bars below are observable player behaviors. A row is cleared when you can watch it happen, not when a designer decides the vibe is right.

---

# Part 1 — What actually compounds, in any game

Most writeups of "game psychology" are a junk drawer: variable rewards, a progress bar, a daily login, a leaderboard, and a hope that the pile becomes a game. It doesn't. A game is one repeated situation in which the player's action changes what they own, what they can do next, and what other people can see. Techniques only work when they are properties of that situation. Detached, they are juice.

The research that holds up is not a list of biases. It is a small set of mechanisms that change what a person does on the next trial, the next session, and the next week. They stack. They also cancel each other when you bolt them on separately.

## 1. The loop is three phases, and the third phase is where games die

A core loop is action, consequence, and reinvestment. The action has to be worth doing even before the prize. The consequence has to land immediately and be readable. The reinvestment is the part almost everyone skips: the thing you just got has to change the next action, or the action becomes a chore the moment the novelty of the prize fades.

That is why a chest that drops gold, in a game with nothing to spend gold on, kills the loop. It is also why a trading game whose only action is "wait for someone to accept" has no loop at all until a counterparty exists. The wait is not an action. The accept is not a reinvestment unless the item you received changes what you can post, craft, or risk next.

Nested time scales matter more than any single reward. The inner loop is seconds to a couple of minutes: one stake, one result, one decision. The session loop is ten to forty minutes: a run of those decisions that leaves you richer, poorer, or holding something you did not have. The return loop is tomorrow: something is resolving, expiring, or closer to a threshold you already started. Games that only have the inner loop exhaust people. Games that only have the return loop feel empty when you are actually in them. Roblox discovery, on Roblox's own account, pays for both staying and coming back. A loop that is only one of those is half a signal.

## 2. Dopamine is a prediction error, not a prize

Wolfram Schultz's recordings of dopamine neurons (the 1997–1998 work, replicated for decades) showed that the cells do not fire for a reward once the reward is expected. They fire when the outcome is better than the prediction. A fully predicted reward produces nothing. A predicted reward that fails to show up produces a dip below baseline. The learning signal is the gap, not the loot.

What that means in a game, practically:

- A guaranteed reward teaches the action once, then goes silent. That is the right tool for the first completion, and a dead tool if it is the only tool.
- An unpredictable reward keeps producing the gap, which is why variable-ratio schedules (reward after an unpredictable number of tries, averaging some rate) produce the highest response rates and the strongest resistance to quitting in Skinner and Ferster's schedule work. When the reward stops, the animal keeps going, because a miss was always part of the pattern. It is not evidence that the machine is broken.
- A reward the player can fully calculate in advance ("do this ten times, get exactly this") produces completion behavior, then a pause. That pause is the post-reinforcement pause on a fixed-ratio schedule. Useful for marching someone to a threshold. Useless as the thing that makes them start the next march.
- The size of the prize matters less than whether it violated the prediction. A small unexpected hit outperforms a large expected one on the next-trial motivation. Designers who "fix" a flat loop by making numbers bigger are treating a schedule problem as a magnitude problem.

There is a second finding that gets ignored because it complicates the slot-machine story. A 2016 lab study on simulated slot machines (James, O'Malley, and Tunney) crossed win rate with the gap between trials. People gambled more during acquisition when wins were frequent. They persisted longer after wins were turned off when wins had been rare, and the longest persistence was rare wins plus a long gap between trials. Impulsivity predicted longer persistence after the wins stopped. High win rate buys the early session. Lean, spaced outcomes buy the refusal to quit. A game that only does one of those has a hole at one end of the lifetime.

Near-misses are not free juice. Clark and colleagues (2009, *Neuron*) found that a near-miss increases the desire to go again and recruits some of the same circuitry as a win, but the motivational effect showed up on trials where the person had control over the gamble. A near-miss on a pure spinner you did not touch is a taunt. A near-miss on something you aimed, staked, or chose is a reason to repeat. If your roll is a button with no choice in it, the near-miss animation is decoration. If the player picked the stake, the recipe, or the target, the same animation is part of the loop.

## 3. Ownership is not a popup. It is a completed act.

Kahneman, Knetsch, and Thaler (1991) documented the endowment effect as a child of loss aversion: giving something up hurts more than getting the same thing feels good, on the order of about two to one in the classic mugs-and-money experiments. Once a thing is "mine," its price to sell and its price to buy diverge. Trading games run on that divergence. If they didn't, every trade would clear at a shared number and there would be nothing to negotiate.

The IKEA effect (Norton, Mochon, and Ariely, 2012) is narrower than people use it. Labor increased what people would pay for an object only when the labor successfully finished the object. Participants who built something and then destroyed it, or who failed to complete it, did not show the effect. Effort does not attach value. Finished effort does.

So a starter bundle handed over as a gift creates weaker attachment than a starter bundle the player just finished crafting, even if the items are identical. And a long grind that never completes does not make people love the game. It makes them feel behind. The first session needs a finished object, not a progress bar at 4%.

Sunk cost is the ugly twin of the same mechanism. Time, items, and identity already invested raise the pain of walking away. It keeps people in after the fun thins out. It does not create the fun. If the only reason to stay is what they have already spent, the moment a cleaner game appears they leave and resent yours. Investment has to keep paying forward into a new capability, not just into a taller pile.

## 4. Distance to a goal changes speed, and the distance is proportional

Hull's rats ran faster in the last segments of a runway than in the first. Kivetz, Urminsky, and Zheng (2006) showed the same pattern in humans with a real café stamp card and a real music-rating task. People bought coffee more often as they got closer to the free one — about 20% faster from the first gap to the last, roughly five days off a card that would otherwise have taken a month. The same people slowed down again after they redeemed, then sped up again toward the second reward. That reset matters. A goal you just finished does not carry its motivation into the next identical goal. You have to re-open the distance.

Two details from that paper are more useful than the headline:

Psychological distance was the fraction remaining, not the absolute count. A 12-stamp card with two stamps already on it was finished faster than a fresh 10-stamp card, even though both required ten more purchases. The head start was fake in terms of work remaining and real in terms of felt progress. People who accelerated harder toward the first reward were also more likely to come back and start the second.

Cards that could not be redeemed did not accelerate. They decelerated. The speed-up was the goal, not the habit of buying coffee.

For a game, the design consequences are specific. Show a goal whose remaining fraction is visible and shrinking. Give a head start that is felt, not a free payout that skips the work. Expect a slump the moment they cash the goal, and have the next goal already framed before they cash. A single enormous threshold that nobody will hit this week does not produce a gradient. It produces a rumor.

## 5. Status is a position other people can see, or it is nothing

Social identity theory (Tajfel and Turner) is the plain claim that once you categorize yourself as a member of a group, you take on the group's norms and you care about the group's standing against other groups. Leaderboards and clans are attempts to manufacture that. They fail in a predictable way.

A global board of the richest players is a wall. Almost everyone looking at it is not on it, and research on leaderboards in gamified systems keeps finding that overall rankings depress the people in the middle and bottom rather than pulling them up. The boards that move behavior are ones where the comparison set is people you can actually pass: your server, your week, your crew, people who started when you did.

Status also has to be worn in a shared space. A rank in a menu is a label. A rank floating over a character, standing at a booth, holding the item everyone on the floor wants, is a signal. PLS DONATE's entire game is that signal plus a Robux balance. Murder Mystery 2 knives have no combat function; they are valuable because other people see you holding them in a round. Adopt Me pets are valuable because they walk next to you. The moment an item stops being visible to other players, demand becomes a spreadsheet, and spreadsheet demand dies the way MM2 values die when people stop wanting the knife and only want the number.

Demand and rarity are not the same thing. Rolimon's own glossary uses the example: Valkyrie Helm is more demanded than rarer items like Memento Mori, because demand is how easily you can trade it onward, not how few copies exist. A game that prints "legendary" on everything and never shows those legendaries in other players' hands will have rarity and no demand. Demand is created when an item is (a) useful in the next action, (b) visible on someone else, and (c) hard to get in the form you need right now.

## 6. Scarcity only works if the missing thing is specific

Generic scarcity ("limited time!") is noise. Specific scarcity is "the one item that completes the thing I already started, and I can see someone else holding it." That requires three conditions at once:

- The player already owns part of a set, a recipe, or a route, so the missing piece is a hole in something that is theirs (endowment plus an incomplete pattern — the open loop only bites if they have already completed enough to care).
- They can see the missing piece in the world, on a board, on another player, in a shop rotation that will leave.
- Getting it is possible this session, by trade, by craft, by a run, or by spending. If it is only possible "later," the scarcity is a poster.

Rotations work because they add a clock to a specific want. A shop that rotates junk nobody needs is a timer on nothing. A shop that rotates the item currently under-supplied on the board is a timer on a real hole.

## 7. Social proof is other people's outcomes, arriving while you are deciding

People copy visible behavior, especially under uncertainty, especially when the copiers look like them. In a trading game the uncertainty is the price. If the only price is a number you invented, players either distrust it or treat it as law and stop negotiating. The games that grow a culture — limiteds, Adopt Me, MM2 — grow it because proofs exist: screenshots of completed trades that become the value list. The value list is not a feature you ship. It is a residue of public, legible outcomes.

The in-game version of a proof is a result other players witness: a trade that pops on the floor, a booth whose last sale is written on it, a crew whose weekly cashout is a number next to their name. Private inventories do not spread. Witnessed inventories do.

Friend graphs matter twice. They matter because a friend in the server is a counterparty you already trust, which solves liquidity for that pair. They matter because Roblox's recommendation system uses who your friends play. A game that is fun alone and better with a friend gets both session length and a distribution boost. A game that requires a friend before it is fun dies in the solo first session, which is most first sessions.

## 8. Money salience changes every number it touches

Once a currency can be exchanged for something with real-world spending power, every action priced in that currency inherits monetary incentive salience. Players track it harder, talk about it more, and tolerate more friction to get it. That is the entire reason "you can earn Robux" is a stronger pitch on Roblox than "you can earn coins." PLS DONATE did not invent a deep mechanic. It put Robux earning in a shared room and let people watch each other get paid.

The constraint you already set — gems enter only through Robux purchases or ads, at a rate that pays you, and never as a free drop — is what keeps that salience honest. If you print gems for play, two things happen. The cashout becomes a liability you cannot bound, and the gems stop feeling like money because everyone has them. Items can be printed. Gems cannot. The addictive activity has to run on items, information, and position, and the ache it produces has to be an ache for gems. Gems are the exit and the accelerator. They are not the thing you grind.

Virtual currency also obfuscates cost, which is why gem packs will outsell a raw Robux price for the same bundle if the pack sizes don't map cleanly onto the prices in the shop. That is mental accounting, and it is why odd pack sizes and bonus gems on larger packs move more Robux than a clean "10 gems = 1 Robux, buy exactly what you need." You already have the exchange rate as a design fact. The shop should not help players do that arithmetic easily at the moment of purchase. The cashout screen should do the arithmetic loudly, because that is the moment you want the Robux to feel real.

## 9. How these cancel each other

A few combinations that look like "more psychology" and actually break the loop:

- A variable-ratio roll that pays gems, plus a gem cashout, plus free gem sources, is insolvent and also trains players to ignore items. The roll has to pay items, or it has to cost gems and pay items worth more than the gems to the right buyer.
- A huge cashout goal with no early completion. No gradient, no IKEA finish, no story to post. The Robux pitch stays theoretical, and theoretical Robux does not retain.
- Feature unlocks that hide the trade floor until rank 3. You delayed the social proof and the friend-play signal until after the players who would have generated them already left.
- A liquidity bot that is the best price in the game. Players never need each other. The bot becomes the game. Social proof never forms. You have a single-player converter with extra UI.
- Idle pads that drip generic currency. If the currency is gems, you broke solvency. If the currency is random items with no relation to what the player staked or wants, you built a second game called "stand here," and it will cannibalize the first without feeding it.
- Near-miss fireworks on a roll the player did not choose. Noise. The same fireworks on a stake they picked, with the missed item then appearing as a real listing someone can buy, is supply generation plus motivation.

The pattern across all of these: the mechanism has to change the same objects the player is already acting on. A new object is a new game. You do not have the cold-start budget for a second game.

---

# Part 2 — What Roblox specifically pays for, and the bar

## What discovery actually optimizes

Roblox has said this in public, including John Ciancutti's August 2026 note on Home recommendations: distribution is driven by engagement, long-term retention, and monetization, together with safety. Games that are strong in retention or in monetization still get impressions. Games that are strong in both get broader distribution. There is no single metric that unlocks the page, and a game that is merely holding its own can lose impressions if other games are engaging and monetizing harder in the same week. Personalization uses who you are, what you have played and ignored, what your friends play, how much time and Robux you have put into an experience, and how well that experience keeps people like you.

Developer-side discussion treats a few signals as the ones that move impressions in practice: day-1 and day-7 return, session length, whether new players reach the core of the game before leaving (qualified play-through), icon and title click-through, likes and favorites, and monetization that is broad across players rather than a few whales. I am not going to pretend there is a published formula. Community heuristics you will see repeated — D1 around 20% or better, D7 around 8% or better, sessions past 15 minutes, like ratio above 70% — are rules of thumb developers use to judge whether they are in a healthy band, not official weights. Treat them as a band to aim at, then read your own analytics against genre benchmarks. A 6-minute session can be fine for an obby and fatal for a trading game, because Roblox compares you to games players treat as the same kind of thing.

Two structural facts about the platform change the design:

Mobile is most of the audience. The first session has to be readable on a phone, with one thumb, in a loud room. A trade UI that needs a desktop spreadsheet will lose the qualified-play-through filter before the economy ever matters.

External attention still matters, but as a spike that the algorithm can amplify, not as a substitute for retention. TikTok and YouTube move visits. Those visits only compound if the first session converts into a return and a purchase or an ad view. The content unit that spreads on those platforms, for this genre, is a number: a snipe, a flip, a cashout, a "started with nothing" inventory. If your result screens are not already that artifact, you will be asking creators to invent the story your game should have handed them.

Recency is a signal. Games that ship visible changes stay in rotation. A trading game has a natural version of this — rotations, new recipes, new routes, weekend demand shocks — and should use it so you are not dependent on a content team inventing a new zone every two weeks.

## How the successful Roblox economies actually work

These are not case studies to copy feature-by-feature. They are evidence about which object the loop is attached to.

**Limiteds.** The game is the gap between RAP and value. RAP is a slow average of recent sales. Value is what the item trades for, set by posted proofs, and demand is whether you can move it. Upgrading (many small items for one big one) and downgrading (one big item for many small ones) are the two verbs. They are not "winning" and "losing." A player upgrades because a single high-demand item is easier to flip onward and looks better in a flex. A player downgrades because they need liquidity, or because four mid items let them make three trades instead of one. Overpay is normal when you are chasing demand. The culture — sharking, sniping, projecting, hoarding, W/L posts — appears by itself once prices are public, slightly opaque, and tied to status. You do not need to design sharking. You need a market where a lie about price can work for an hour and a proof can correct it by tonight.

**PLS DONATE.** The pitch is Robux. The room is the mechanic. You stand at a booth, other people see your booth and your raised total, some of them buy your pass or shirt, Roblox pays you. The people who do well treat the booth as a performance: text, decoration, social proof of what they have already raised. The people who earn nothing still stay because they can see that earning is happening in the same room. That is the lesson. Earning Robux is the hook. Being in a room where earning is visible is the retention. A cashout button in a menu, with no one watching, is a weaker version of the same promise.

**Adopt Me.** The pet is the item, the social signal, and the labor sink at once. Aging, neon, and mega are completed labor, which is why people overvalue their own pet relative to an identical one in a trade window. Trading is not a mode you enter. It is what you do because your pet is the wrong pet and someone in the server is walking around with the right one. External value lists stabilized prices and also, over time, pulled demand off "I want that pet" and onto "I want the number." When demand is only the number, bot farming and oversupply collapse it. The pet still has to be wanted as a pet.

**Pet Simulator.** The inner loop is the egg, which is a variable-ratio pull. The expansion is the pet making the next pull faster or the next zone reachable. The status ceiling is the huge or the exclusive, which is also the tradeable. Rebirth resets the inner numbers and keeps the identity, which is how they get a post-reward reset without losing the player. The game thins out when a player believes they have finished the ceiling. Completion is the enemy. A moving ceiling, or a ceiling that is social rather than personal, lasts longer.

**Blox Fruits.** This is the one your "second path" instinct is reaching for, and it is worth being precise about why it works. Fruits enter the world two ways: you find or earn them through play, or you roll for them. Both ways put the same object in your hand. The object changes the next hour of play, because the fruit is your combat kit. Trading is a third door into the same object, not a separate hobby. Raids and bosses are sinks and social sessions that produce the currency you roll with. People stay for hours because the session has a verb (fight, move, dodge) that is satisfying before the drop, and the drop changes the verb. A boss that drops a coupon for a different game mode would not do this. The second path works because it is the same path.

**Murder Mystery 2 trading.** The knife does nothing mechanical. It works because every round is a stage, the knife is on the stage, and the value list gave traders a language. When the language ate the desire — people trading only the number, not the knife — values slid. Visibility without desire is a bubble. Desire without visibility never becomes a market.

## The Roblox bar

A row is cleared when the behavior is common in new players, not when the feature exists. "Working" is the threshold at which that signal can compound with the others. Below working, more marketing mostly burns visits. At working, on several rows at once, Home recommendations have the inputs Roblox says it uses, and the social loops that spread this genre have something to spread. That is as close to "almost guaranteed" as the platform allows. It is not a promise. A moderation hit, a dead icon, or a competitor having a louder week can still bury you. The bar is the part you control.

| Condition | Failing (you can see this) | Working (the threshold) | Compounding (what spreads) |
|---|---|---|---|
| First session reaches the core | Player leaves before they finish one meaningful action and understand why they would do it again | Most new players finish one full inner loop and can say what the game is | They finish the loop, want a specific next thing, and are still in the server when it becomes available |
| Session has a verb | Time in-game is menu, waiting, or idle with nothing resolving | A repeatable action fills most of a 10+ minute session and produces a legible result | The action is satisfying before the prize, and the prize changes the next action |
| Reason to return tomorrow | Logout is a hard stop; nothing is pending | Something they started resolves, expires, or gets closer overnight, and they know it | That pending thing is specific to an item or a deal they already care about, and coming back late has a cost |
| Other people are the point | Fun is identical alone; friends add nothing | Playing near others changes prices, chances, or what you can get | A friend in the server is a better session, and the game gives you a reason to pull them in |
| Status is worn | Ranks live in menus | Other players in the same space can see what you have done | What they see makes them want the thing you have, or the title you have, enough to start the loop |
| Money moment is real | Spending and earning are both abstract | A player can spend or earn something that maps to Robux inside the first few sessions, and they understand the mapping | They tell someone the number. The number is a Robux number |
| Monetization is wide | A few players buy a lot; everyone else never hits a pay or ad moment | Many players hit a small, optional pay or ad moment that continues an action they were already doing | Those moments sit on prediction errors and open loops, so paying and watching feel like finishing the action |
| The artifact travels | Nothing about a session is worth screenshotting | Result screens state a flip, a pull, a rank, or a cashout in one image | Creators can post that image without explaining the game |
| The game is still different next week | Same board, same prices, same recipes | Rotations, new recipes, or demand shocks change what is worth doing | Players come back to check the change, and the change creates new trades rather than obsoleting old items into junk |
| Phone-readable | Core action needs precision, dense text, or a second screen | A new player on mobile completes the first loop without a tutorial essay | Trading, rolling, and the verb all work one-handed |

Clearing working on the first session, the verb, the return reason, the money moment, and the social row at the same time is the actual gate. The other rows amplify a game that has already cleared those. They do not rescue a game that has not.

---

# Part 3 — This game

You already have the hard economic idea, and it is the right one. Players can earn Robux by playing. Gems convert to Robux at a rate you set. Gems enter the economy only when Robux reaches you, either because someone bought gems or because someone watched an ad at 10 gems per 1 Robux. Items can be created. Gems cannot. That split is the whole design. Protect it.

What you do not have yet is a situation the player can repeat in the first ten minutes when the market is thin. You have a set of correct systems — asymmetric starters, a crafter, a roll, a board, a market, booths, ranks, crews, a cashout — sitting next to each other. A new player who finishes the Unique Craft and lands on a trade board is waiting. Waiting is not a loop. The liquidity bot keeps them from being stuck, and it does not make them feel anything, because beating a bot at a price the bot is required to offer is not a story and not a status event. The fear you described is accurate. The fix is not a second game. It is making item acquisition, crafting, and trading into three doors on one outcome.

## The situation, stated as a situation

A player owns items. Items are unevenly distributed, so someone always has what someone else needs. An item can be risked, combined, split, bought, or sold. Risking and combining produce different items, not gems. Selling produces gems. Gems buy faster access to items, and gems past a threshold become Robux. Other players can see what you are holding and what you just did. The bot will always buy and sell at a floor so the economy cannot freeze. The player price is worse than the bot when you are impatient and better than the bot when you are patient or informed. That gap is the game. Limiteds already proved the gap is enough to build a culture on, if the items are wanted for a reason other than the gap itself.

The reason, in your game, cannot be "it is rare" alone. Rarity without a use collapses into the MM2 failure mode. The use has to be inside the same loop: this item, staked or crafted, changes what you can pull next, and this item, worn or shown at a booth, is what other people are trying to pull.

## Where the tutorial has to send them

The takeover screen is the right opening. Asymmetric bundles only create demand if the player understands the asymmetry before they trade. Show the distribution in player language, not designer language: "You started with 1 high item and 2 low. Most people in this server started with the opposite." Then one number: "If you sold to the floor right now, you would be X gems toward your first Robux." That number is the head start on the cashout meter. You are not giving them gems. You are showing them that their items are already a position on a Robux track. Kivetz's two pre-stamped squares. The work remaining is the same. The distance feels shorter. Do not let that number be zero, and do not let it be a lie — it has to be the bot's actual bid for their bundle.

The Unique Craft stays. It is the first completed labor, which is the condition under which effort attaches to an object. Make the craft take a real action, thirty to sixty seconds, not a confirm button. They have to finish something.

Then do not release them onto the board. The board is a menu until they have a want. Send them into one **Route**, alone, with the Unique Craft item as the stake. The Route is the verb. It is also how items keep entering the world after the starter pools stop mattering.

## The Route is not a mode. It is how items move.

A Route is a 60–90 second run, playable solo, better with one or two other people in the same physical space but not requiring them. The player stakes one item they own. They make a small number of choices or timing calls — enough that a miss feels like their miss. Clark's near-miss result depended on control; give them control. The stake determines the table. A low item can come back as a mid, split, or a near-miss. A high item can come back upgraded, downgraded into several mids, or intact plus a found piece. Your Unique Craft signature skews the table, permanently, for that player. That is asymmetrical demand with a cause that still exists on day thirty. The starter bundle only fires once.

Outcomes, all in items:

- The stake returns changed. Upgrade, split, or a side drop from a pool.
- A visible near-miss: the player sees the specific item, it does not enter their inventory, and it immediately becomes a real listing — on the board, at the booth row, or in the gem-store rotation — for a short window. Someone can buy it, including them. If they cannot afford it, they now have a specific gem number they are short, which is an ad moment and a trade moment, not a sad animation.
- A public tick. The result is announced on the floor, not buried in a popup only they see. Other players learn what just entered the economy. That is a proof. Proofs are how value lists form without you writing one.

The liquidity bot quotes a floor on anything a Route can produce, so a player is never holding an item they cannot exit. The bot's price is the RAP. The player market's price is the value. Post both, the way limited traders live in the gap between them. If the bot's buy price is ever the best price, widen the spread until player-to-player trades are how you actually profit. The bot is the reason the economy cannot die. It is not the opponent.

AFK pads are Routes with the timing stripped out. You stake an item, you stand on the pad, the Route resolves when you return or when the timer hits, whichever you designed. The idle reward is a resolution of a stake they chose, so coming back has a result they already care about. It is not a gem drip. A gem drip is insolvent. A random-item drip that ignores the stake is a different game leaking players out of this one.

Rolling is the same table, different door. The free roll every X minutes is a fixed-interval window: people show up when it opens, then go quiet, which is the scallop those schedules always produce. Use it as a return trigger, not as the core. Set X so that a player who is already in a session can hit one or two free rolls inside the session, and a player who left has one waiting when they come back tomorrow. The gem roll is the paid acceleration of the same table. The item-sacrifice roll is upgrading and downgrading as a button, which is the verb limited traders already have a word for. One table, three doors: Route (time and attention), roll (gems or a sacrificed item), shop rotation (gems, on a clock). If the roll can produce items the Route cannot, you have split the economy and the value list will not form.

## Crafting is the conversion the Route forces

Route output is messy on purpose. Wrong tier, wrong type, a piece of a recipe. The Crafter is where messy output becomes the item the board is paying for right now. Put the live board — best player bid, bot floor, and what the shop is about to rotate out — on the crafting screen. Choosing a recipe is a bet on demand, not a cookbook. That is the reinvestment phase. The item they just got changes which recipe is correct.

Unique Crafts are the personal skew made tradable. If only I can craft item U, then anyone who needs U has to trade me, run a Route that can drop it, or pay gems for it when it near-misses onto the board. That is a repeating source of asymmetrical demand. The starter pools should stay capped so day-one items do not inflate, and Unique outputs should be the things that stay scarce per player rather than scarce globally. Global scarcity of a craftable is an invitation to alt-farming. Personal scarcity of a craftable is a reason to find that player.

The sacrifice recipe you already have — one high item into many low ones — is downgrading. Keep it, and show the player the liquidity they gain: "these four lows are biddable right now; the high is not." Downgrading is how a stuck player gets back into the session instead of logging off. It should feel like a trader's decision, not like deleting a good item.

## The cashout is the goal, and the first one has to happen

100,000 gems at 100:1 is 1,000 Robux. As a late-game flex, fine. As the first time the Robux pitch becomes real, it is too far. A goal that far away does not produce the acceleration Kivetz measured, because the fraction remaining barely moves in a session, and it does not produce the IKEA completion, because nobody finishes. Players who can earn Robux but cannot imagine earning Robux this week will talk about the game as a scam or a grind, even if the math is fair.

Structure the track as steps, not one door.

- The meter is visible from the takeover screen, denominated in gems and in Robux, using your real rate.
- The first cashout threshold is low enough that an active player who trades, runs Routes, and watches some ads can hit it inside the first few sessions. I will not invent the number. Watch how many gems a real first-session player can assemble by selling to the bot and to other players, and set the first cashout near the top of that distribution, not at the fantasy end. The first cashout exists to create the sentence "I made Robux in this game." That sentence is your TikTok. PLS DONATE spread on that sentence. You have a stronger version available, because yours is a game and not only a booth, but only if the sentence gets said early.
- Later thresholds step up. Exchange rate can worsen at higher tiers, or the threshold can simply grow. Either way, the next goal is on screen before they confirm the current cashout, because motivation resets the moment the reward is taken. A profit title that updates at the moment of cashout, visible over their head on the floor, is the re-opened goal. The Robux was the prize. The title is why the next pile starts immediately.
- Never pay the first cashout in a way that prints gems. They reached it by selling items to players or to the bot, and by ad gems. The bot's gem float has to be funded by gem sinks (rolls, shop, ad boosts, booth slots) or by a treasury you filled with real Robux. If the bot is a gem fountain, the cashout is you paying players with your own money on a delay. Price the bot's spread so the treasury is fed by impatient sellers and gem spenders, not by hope.

Show the Robux number everywhere the gem number appears, once they have been told the rate. Monetary salience is the point. Obfuscate it in the gem-pack shop, where you want the pack to feel like a bundle rather than a unit price. Do not obfuscate it on the meter.

## Ranks, booths, crews — they have to live on the floor

Unlocking features by quest rank instead of gating currency is the right call. Gating currency would also fight the cashout story. The order of unlocks is the part to get right, because the first session cannot depend on a locked feature.

Unlock in the order the loop needs them, not the order that makes a progression chart look tidy.

1. Route, Crafter, bot floor, cashout meter. These are the solo loop. Available immediately after the one tutorial Route.
2. Direct trade and a booth, the moment the first Route ends. The booth is not a perk. It is how status becomes visible, which is the PLS DONATE lesson applied to your items. The booth shows what they are holding, their last result, their rank, and a one-line ask. It stands on the same floor as the Route exits, so the player who just finished a run walks past the player who wants the item. If booths are a separate place, you have built a lobby and a game and most players will pick one.
3. Trade ads and the market tab once they have completed a few trades and can read a price. These are literacy tools. Handing them over at minute two creates sharking victims and a dislike ratio.
4. Bulk buy once crews exist, because a chip-in order with strangers is awkward and a chip-in order with a crew is a goal.

The floating rank and profit title only work in a shared space with enough density that you see several titles in a minute. That is an argument for one main floor, not instances so small that everyone is alone, and not so large that titles become spam. Server size should be "I can see other people's booths and Route results without hunting."

Crews should be liquidity pools with a name, not a clan raid calendar. A crew goal that fits this loop: each member contributes the output of their Unique Craft toward a crew recipe nobody can finish alone, and the finished item is listed, with the gem proceeds split. Or a crew bulk-buy target sitting on the board, with the crew name on it, counting down. The crew's weekly gems cashed out, shown next to the crew name, is the intergroup comparison social identity actually runs on. A crew perk that prints gems is off the table. A crew perk that improves Route odds, booth count, or ad-boost duration is a perk priced in attention and in Robux, which you can fund.

Leaderboards: do not lead with a global richest board. It tells every new player they have lost. Lead with this server, this week, cohort-of-players-who-started-today, and crew versus crew. Put the global board in, for the people who want the ceiling, but it is not the board that retains the middle.

## Ads and products, sitting on the open loop

The ad is not a shop button. The moment it belongs is the moment a prediction just failed or a goal just got close.

- Near-miss listing: "Watch to buy it at the floor before it goes public" or "watch to reroll the last node of this Route." They were already in the action. The ad finishes it. Gems granted here still have to obey 10 per 1 Robux to you. If the offer is a discount rather than a gem grant, the discount is funded by the spread, not by printed gems.
- Roll window closed: "Watch to open it now." Fixed-interval frustration is the entire reason those windows print money. You already decided the free roll is on a timer. The ad is the skip.
- Cashout meter within one ad of a round number: show the gap in Robux, not just gems.

Gamepasses you listed — trade-ad boosts, extra booth slots, quest skip — fit if they buy position in the shared space rather than a private advantage nobody can see. An extra booth slot is visible. A quest skip is fine and small. A pass that secretly improves Route odds will be called out as pay-to-win and will also distort the value list, because paid players flood one item. If you sell Route advantage, sell it as more attempts (extra stake slots, shorter Route cooldown), not as better luck. More attempts is understandable. Hidden luck gets the game treated as rigged, and a trading game that feels rigged loses the proof culture it depends on.

Gem packs: odd sizes, a bonus on the larger packs, prices that do not divide cleanly into the shop's item prices. The player should feel short by a little after a pack, not exact. That shortness is the next pack, and it is also the reason they try to make up the difference by trading instead of only by paying. Both outcomes pay you. One of them also makes them play.

Subscriptions, if you add them, should protect a position they will lose: a booth slot that expires, a crew perk that lapses, a title style that goes dormant. Loss of something they already have outperforms the promise of something new, by the same asymmetry as the endowment effect. Do not threaten their items or their gem balance. Threatening money they earned is how you get a dislike wave. Threatening a cosmetic position they were proud of is how you get a renewal.

## What "success" means for this game, specifically

Same rule as part 2. A row is cleared when you can watch new players do it. The Robux column is not optional and not implied. If they cannot earn Robux, or cannot see that they can, this is a different game and this bar does not apply.

| Condition | Failing | Working | Compounding |
|---|---|---|---|
| Robux is understood | Player thinks gems are a toy currency, or never finds the meter | In the first session they can state the rate and see their items as a gem position toward a Robux cashout | They hit the first cashout, or watch someone in the server hit it, and the number is in Robux |
| First session has a finished object and a want | Tutorial ends on a board with nothing they need | They finish the Unique Craft, run one Route with it, and leave the Route wanting one specific item they saw and did not get | That item is buyable, craftable, or tradeable before they log out, and they know which |
| The verb fills the session | Time is spent waiting on trades | Routes, crafts, and rolls occupy most of 10+ minutes, and each one changes their inventory | They chain them: Route output decides the craft, craft decides the next stake, stake decides the trade |
| One economy | Roll, Route, craft, and shop produce different, unrelated items | All four doors draw from the same pools, and the bot quotes every pool | Player prices diverge from the bot floor in a way people argue about |
| Asymmetry refreshes | Only the starter bundle is uneven; by day two everyone has the same stuff | Unique Craft skew and Route stakes keep producing items other players cannot easily make | Players seek out specific other players because of what only that player can craft |
| The bot is a floor, not the game | Bot price is the best price, so nobody trades | Bot price is the exit; player trades beat it often enough that talking to people pays | Proofs of player trades are how new players learn prices, and the bot is what they use when they are done negotiating |
| Logout has a pending result | Nothing resolves while they are gone | A staked AFK Route, a roll window, a shop rotation, or a listing of theirs is going to change before tomorrow | Missing the window costs them a specific item they already saw |
| Status is on the floor | Titles are in a profile | Rank, title, and last result are visible on the booth floor while other people are there | A new player sees a title and a held item and asks how to get them, in chat, in the first session |
| Solvency holds under fun | The fun path prints gems, or the fun path never creates gem demand | Players want gems, can only get them from purchases, ads, or selling items to someone who got gems that way, and the bot's float is funded | Gem spend (rolls, shop, skips, slots) and ad views scale with how much people want items, not with a faucet |
| The artifact is a Robux story | Screenshots need a paragraph of explanation | A result card shows the flip or the cashout in gems and Robux | People post the card, and the card is enough to make a stranger understand they could earn Robux here |
| Friends have a job | A friend is another person waiting | A friend is a counterparty, a crew contributor, or a second set of eyes on a Route | Pulling a friend in changes both inventories today, which is why they get pulled |
| Monetization continues an action | Shop is a tab they open when bored | Ads and packs appear when they are short of a specific item or a specific gem gap | The shortfall is usually small, so the first purchase is small, and many players make it |
| Next week is a different market | Same recipes, same demand | Rotations and new recipe costs shift what the board wants | Old items remain useful as stakes and downgrade material, so the shift creates trades instead of wiping inventories |

The threshold is working, at the same time, on these rows: Robux understood, first session finished-object-and-want, the verb fills the session, one economy, the bot is a floor, logout has a pending result, solvency holds. Those seven are the core. Status on the floor, the artifact, friends, and monetization-on-the-action are what turn a retained player into a visit the algorithm can spread. Asymmetry that refreshes and a market that changes next week are what keep D7 from falling off a cliff once the starter bundle has been fully traded away.

If those seven are failing, do not buy a launch spike. The visits will not stick, and a spike that does not stick is just a bad week of qualified play-through. If those seven are working, a coordinated push — icon that shows a Robux number and an item, creators posting cashout cards, a weekend where a new Unique recipe drops — is the thing that turns retention into impressions. Roblox has been explicit that retention plus monetization gets broader distribution than either alone. This game can be both, because the thing players want (items, status, the next Route) is priced in a currency that becomes Robux, and the currency only enters when you get paid.

## What I would not add

A separate boss mode, fruit hunt, or combat zone whose drops are a coupon to come trade. That is the disconnected second game you were right to be unsure about. Blox Fruits gets away with grinding because the thing you grind for is the thing you fight with. You do not have a combat identity to change. Your identity is the inventory. Any new activity has to change the inventory through the same pools, or it will steal the session and give the market nothing.

A free gem quest, a gem idle pad, a gem daily. Each one is a small insolvency and a tax on the feeling that gems are Robux. Daily and weekly quests should pay items, recipe unlocks, booth time, Route attempts, and title progress. Not gems.

A global value list you author and enforce. Publish the bot floor. Let player proofs set the value. The arguments about whether a trade was a win are the content. If you dictate value, you have deleted the culture and become the bot.

Gating the first trade behind a rank. The first trade should happen while the Unique Craft is still warm and the near-miss is still on the board. Rank can gate ads, bulk buy, and extra booths. It should not gate the moment the game becomes multiplayer.

I understand the proposition: a player who shows up, stakes what they were given, and works the floor can end up with Robux. The design problem is making that path a repeated situation — stake, resolve, convert, get seen, come back because something they staked is about to resolve — rather than a lobby full of menus that would be addictive if the market were already full. The market gets full because the situation is repeatable on an empty Tuesday. Not the other way around.
