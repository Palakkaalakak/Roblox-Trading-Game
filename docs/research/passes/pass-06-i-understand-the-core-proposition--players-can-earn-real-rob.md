I understand the core proposition: players can earn real Robux from playing this game. That is the product. Every item, rank, and listing is a claim on that exit, and the exit is only believable if the gem supply behind it is backed. The research below treats every mechanism as material — schedules of reward, loss frames, status, appointment, spend paths, social obligation — and then builds the rubrics and the solo loop on top of that, including the Robux exit as the unit the other mechanisms are denominated in.

---

# Part 1 — Mechanisms that map onto any game

## What a mechanism is here

A mechanism is a reliable change in what a person does next, produced by how an outcome is delivered, framed, or witnessed. It is not a slogan and it is not a genre. The same mechanism runs in a slot machine, a crafting menu, a loyalty card, and a trade board, because it runs on the structure of the feedback, not on the fiction wrapped around it.

The useful unit is the loop John Hopson described in 2001 in "Behavioral Game Design" (Gamasutra), drawing on B. F. Skinner's schedules of reinforcement. A loop has three phases: anticipation (a desired state is vivid), action (the player does the thing the designer wants repeated), and reward (something arrives that makes the next anticipation possible). Adam Crowe's later formulation calls the habitual version of this a compulsion loop: a designed chain that repeats because the reward is neurochemical — pleasure, or relief from the tension of not having the thing yet. A core loop is just the chain of actions. It becomes a habit when the phases are tuned so that stopping is harder than continuing. Games that spread are games in which several of these tunings are present at once and do not cancel each other. One strong loop with the other phases missing produces a short spike and a quiet exit.

What follows is the set of tunings that show up across games, each with the actual mechanism and a real source, then the way they stack.

## Variable-ratio reinforcement

Skinner's operant chamber delivered food on rules. Two dimensions matter: ratio versus interval (reward after a count of actions, or reward after a stretch of time), and fixed versus variable (the count or the stretch is constant, or it changes). A fixed ratio — every tenth press pays — produces a pause after each reward. The animal has just been paid and the next payment is known to be far. A variable ratio — on average every tenth press, but the next one might be the first or the fiftieth — does not produce that pause. The next action is always a candidate. Response rate stays high, and extinction (stopping after the rewards have actually ended) is slow, because the animal cannot tell a dry streak from the ordinary gap between payments.

Hopson (2001) mapped this onto games directly. A fixed drop ("every five kills, a chest") trains the player to rest after the chest. A variable drop ("chests come from kills, rate unknown, sometimes two in a row, sometimes none for a long stretch") trains the player to take the next kill. The action being conditioned is whatever sits immediately before the variable outcome. If the variable outcome sits behind a menu, the menu is what gets repeated. If it sits behind a craft, the craft gets repeated. If it sits behind a purchase, the purchase gets repeated. The schedule does not care which of those the designer intended. It conditions the last action before the reveal.

Two boundaries matter. First, the player has to believe the action is connected to the outcome. If the roll is visibly random and the player's input does not change the bands, the conditioned action collapses into "press the button," which is weak and easy to abandon. If the input changes the bands — different materials, different timing, a visible shift — the conditioned action is the choice, and choices are stickier because the player can tell themselves skill is involved. Second, a reward that is too rare stops functioning as a schedule and starts functioning as a rumor. The player needs enough small outcomes to keep the ratio feeling alive, with the rare outcome as the top of the same distribution, not as a separate event that never comes.

## The near-miss

A near-miss is a loss whose feedback resembles a win. Luke Clark and colleagues (2009, Neuron, "Gambling Near-Misses Enhance Motivation to Gamble and Recruit Win-Related Brain Circuitry") ran a slot task and found that near-misses were rated less pleasant than wins — people know they lost — but increased the desire to continue, and recruited reward-circuitry overlap with actual wins, including the ventral striatum. Later work (Chase and Clark, 2010) associated midbrain response to near-misses with gambling severity. The mechanism is a split evaluation: conscious appraisal says "loss," the reward system partly says "win-like," and the mismatch is resolved by another attempt rather than by stopping. A full miss does not do this. A full miss is consistent across both appraisals, and consistency is easy to walk away from.

The design consequence is narrow and easy to miss. The near-miss has to be perceivable as close. An instant "fail" toast is a full miss no matter what the underlying roll was. A visible track that slows and stops one band short of the rare outcome is a near-miss. Clark's subjects saw the reels. They did not read a result string. Games that hide the roll and announce the result throw away the mechanism they think they are using.

## Reference dependence and loss aversion

Kahneman and Tversky (1979, Econometrica, "Prospect Theory: An Analysis of Decision under Risk") showed that people do not evaluate outcomes as final wealth. They evaluate changes from a reference point, and the value function is steeper on the loss side than on the gain side. Their phrase is that losses loom larger than gains. A second finding in the same paper, the certainty effect, is that people overweight outcomes that are certain relative to outcomes that are probable: a sure small gain is chosen over a better gamble more often than the expected values justify, and a sure small loss is avoided even when taking the gamble would be better.

In a game this splits into two design facts. Gains and losses are not symmetric motivators. Removing something the player already treats as theirs — a streak, a listing advantage, a rank step that was shown as filled, a craft window that was open — moves behavior more than granting an equivalent new thing. And a sure small item will often be chosen over a chance at a better item, until the player is already inside a gamble, at which point loss-chasing (continuing to avoid realizing the loss) takes over. The reference point is movable. Show a player a higher state and then put them below it, and the gap is coded as a loss relative to the new reference, not as a neutral starting position. That is why an opening that lets the player briefly hold, or clearly see, the top outcome, and then returns them to the starter state, pulls harder than an opening that never shows the top outcome at all.

## Endowment

Kahneman, Knetsch, and Thaler (1990, American Economic Review) randomly gave coffee mugs to half their subjects and then ran markets. Sellers' median asking price was about $7; buyers' median offer was under $3; people asked to choose between a mug and cash sat near the buyers, not the sellers. Ownership itself moved the reference point. Giving the mug up was framed as a loss. Buying it was framed as a gain. The same object, two frames, a spread of roughly two to one.

In any game with an inventory, the moment an item enters the inventory its subjective value jumps above the price a non-owner will pay. This is not a bug in the market. It is the market's native friction. Every trade has to cross that spread: the owner's loss-framed minimum versus the buyer's gain-framed maximum. Markets that collapse the spread — an NPC that buys at a posted price — remove the friction and also remove the reason for two players to talk. Markets that never cross the spread — owners list at endowed prices, buyers will not meet them, nothing clears — remove the reason to stay. The working condition is a spread that player-to-player negotiation can actually close, often because the buyer has a use for the item the owner does not, or because the owner needs the proceeds more than they need the item.

## Labor and successful completion

Michael Norton, Daniel Mochon, and Dan Ariely (2012, Journal of Consumer Psychology, "The IKEA effect: When labor leads to love") had people assemble boxes, fold origami, and build Lego sets. Builders valued their successful creations more than non-builders valued identical objects, and more than the builders themselves would have paid for a pre-built version. The boundary condition is the important part: labor increased value only when the task was successfully completed. When builders assembled something and then destroyed it, or when they failed to finish, the premium disappeared. Effort that does not complete does not create attachment. It creates a sunk cost with no object to love, which is a reason to quit rather than a reason to stay.

Mapped onto a game: a craft that resolves into an item the player holds will be overvalued relative to the same item handed over completed. A craft that fails into nothing will not. The design target is therefore a resolution that always completes into something held — a lesser item, returned materials, a visible step — with the rare completion as the top of that same resolution, not as the only resolution that counts. Failed labor that yields an empty inventory is the condition under which Norton, Mochon, and Ariely found the premium gone.

## Goal gradient and illusionary progress

Clark Hull (1932, and the 1934 alley experiments) found that rats ran faster as they approached the food box. The tendency to approach increased with proximity to the reward. Ran Kivetz, Oleg Urminsky, and Yuhuang Zheng (2006, Journal of Marketing Research, "The Goal-Gradient Hypothesis Resurrected") showed the same pattern in people: café loyalty-card holders bought more frequently as they neared the free coffee. They also showed that perceived distance works as well as actual distance. A card with 12 stamps, 2 of them already filled, was completed faster than a card with 10 stamps, none filled, even though both required 10 purchases. The pre-filled stamps were not a larger reward. They were a shorter-looking road.

Two consequences. A single far reward — a cashout, a top rank, a rare item — does not accelerate behavior while it still looks far. Intermediate marks, close enough to see the remaining distance, do. And a bar that starts empty looks farther than a bar that starts with the first step already credited, even when the remaining work is identical. The credit has to be real in the sense that the player did something (they joined, they received a starter stack, they opened the menu). A fake stamp the player can see was not earned becomes noise. A stamp tied to an action they already took becomes proximity.

## Sunk cost and consistency

Once time, money, or effort has been committed, abandoning the commitment means admitting the prior spend produced nothing. That admission is itself a loss relative to the reference point "I am someone whose spend was worth it." Hal Arkes and Catherine Blumer (1985) demonstrated sunk-cost persistence in theater tickets and investment scenarios: people continued a course of action more when they had already paid, even when the forward-looking value was the same. Robert Cialdini's consistency principle (Influence, 1984) is the social version: people act to stay aligned with what they have already done and said, especially if the earlier act was public.

In a game, a partial rank, a half-filled craft, a listing that has not sold, and a gem balance that has not reached the exit are all sunk costs. They pull harder when they are visible to other players, because quitting is then not only a private loss but a public inconsistency. They pull less when the player can tell themselves the spend was entertainment already consumed. The exit — if the spend was real money, or time aimed at real money — makes the sunk cost sharper, because the alternative framing ("it was just a game") is harder to use.

## Social proof under uncertainty

Cialdini (1984) described social proof as looking to other people's behavior to decide one's own, and located its strength in ambiguous situations. When the correct action is obvious, other people's behavior is background. When the correct action is unclear — what is this worth, is this trade fair, is this game worth staying in — other people's behavior becomes the evidence. Later work on responsiveness to social proof (for example Venema and colleagues, 2020) keeps the same condition: uncertainty amplifies copying; similarity of the model to the observer amplifies it further. A stranger's action is weaker evidence than the action of someone who looks like the observer's peer.

Trading games, loot games, and any game with unpublished prices are high-uncertainty environments by default. A visible recent sale, a crowded stall, a peer of the same rank completing the same craft, a leaderboard of people one step ahead — these are not decoration. They are the information the player uses to set a price and to decide whether to continue. A game that hides all of that asks every player to price in the dark, which newcomers cannot do, so they either underprice once and leave or overpay once and leave. A game that publishes a complete, static price list removes the uncertainty and, with it, the reason to watch anyone else. The band that keeps social proof working is partial visibility: enough completed trades on screen that a newcomer can learn, enough unpublished judgment left that a veteran still earns something for knowing more.

## Scarcity and the decoy

Restriction raises perceived value when the restriction is believed. A store shelf that actually rotates, a craft window that actually closes, a stall count that is actually finite — these work because the player can fail to get the thing. A "limited" tag on an item that is always available stops working as soon as the player has seen it twice. Zagal, Björk, and Lewis (2013, FDG, "Dark Patterns in the Design of Games") note the related point about literacy: once players can see the device, it no longer operates in the dark, and a known device is less effective than an unknown one. Real restriction does not depend on the player failing to understand it. It depends on the restriction being true.

A separate choice mechanism, the decoy, comes from the asymmetric-dominance work Dan Ariely popularized in Predictably Irrational and that a 2018 Roblox developer article (RichOfPickles, Roblox Developer Medium) applied directly to in-game shops. When three options are shown, and one of them is clearly worse than a middle option on every dimension while the expensive option is only better on one dimension, the middle option is chosen more often than it would be alone. The middle option is not "free." An extra bundled into it — Ariely's zero-price effect is the related finding that a zero marginal add-on is overweighted — makes the middle option feel like the rational purchase rather than the designed one. The layout does the work: the intended option sits in the center, the two flanks make it look like the compromise, and the bundled extra is an item or a convenience, not a change to the underlying exchange rate of the premium currency.

## Status as instrument, not costume

A title that other players can see, and that changes what those players will do, is instrumental status. A title that only the owner sees, or that everyone sees but nobody acts on, is a costume. Costumes are abandoned when the novelty ends. Instrumental status is retained because losing it changes the terms of trade, the people who will deal with you, and the rooms you can enter.

Zagal, Björk, and Lewis split their catalog into temporal patterns (grinding; playing by appointment), monetary patterns (pay to skip; pre-delivered content; monetized rivalries), and social-capital patterns (social pyramid schemes; impersonation). The social-capital pair is the relevant one here. A social pyramid scheme, in their terms, is progress that requires recruiting other players, so that each recruited player inherits the same need and the graph grows from obligation rather than from preference. Their FarmVille example is concrete: without enough neighbors, meaningful progress required either real money or convincing family to join, and the newly convinced then had to convince others. Impersonation is the game speaking in a friend's voice for an action the friend did not take. The first pattern creates obligation. The second spends the friend's reputation to manufacture presence.

Presence can also be manufactured from real actions, which is not impersonation. A feed of trades that actually happened, a stall that is actually occupied, a name actually attached to a sale — these are social proof, and they work in an empty-feeling server the same way a crowded one does, as long as the events are real. Fabricating the events spends trust once and then stops working.

Monetized rivalry, in the same paper, is a public ranking that spend can move. The mechanism is not the ranking. It is the combination of a visible gap between the player and the next name, and a purchase that closes the gap faster than play. If play cannot move the ranking at all, non-spenders have no path and leave. If spend cannot move it at all, the ranking does not convert. The stacked version — play moves it slowly, spend moves it faster, the gap is always shown — is the pattern Järvinen summarized, in the source Zagal cites, as design for pay-to-win but balance for grind-to-compete.

## Appointment, grinding, and the return

Playing by appointment, as Zagal, Björk, and Lewis define it, is a schedule the game sets, which the player must meet or lose value they already had. FarmVille crops that wither if not harvested are the example. The darkness in their framing comes from the player's real day being reorganized around the game's timer. The mechanism, stripped of that framing, is a loss frame on a timer: missing the window destroys or degrades something already owned, so the return is avoidance of a loss rather than pursuit of a bonus. A timer that only grants a bonus if you show up is a gain frame. Gain-framed returns are weaker, which is the prospect-theory asymmetry, not a moral distinction. Optional appointments — Animal Crossing's visiting character, a store rotation that adds options without destroying owned goods — invite a return. They do not compel one. Compelled returns produce more sessions and more resentment when the player notices the compulsion. Invited returns produce fewer sessions and less backlash. Which one a given game wants is a tuning, and the two can sit on different systems in the same game: a degrading advantage on a craft window (loss frame, strong return) and a rotating shop that simply changes (gain frame, weak return), with owned rare items never destroyed, because destroying a completed labor product removes the attachment Norton and colleagues found and replaces it with a reason to quit.

Grinding, in the same paper, is repetitive action whose function is to extend duration, with time invested standing in for skill. It coerces when the player cannot estimate the time, and when refusing to do it means losing to people who did. A repetition that produces objects other players want is not the same pattern. The time is still spent, but the output enters a second loop (trade, status, exit) so the repetition has a product. Pure grinding — repetition that produces a number nobody else can see — ends when the player notices the number is the only product. Productive repetition ends when the product stops being wanted. Those are different failure modes and they ask for different fixes.

## Currency confusion and delayed cost

A premium currency that is not one-to-one with the money spent inserts a translation the player does once, at purchase, and then stops doing. Subsequent decisions are made in the premium unit. King and Delfabbro (2018) describe predatory monetization as purchase systems that conceal the long-run cost until the player is already financially and psychologically invested. The concealment is not usually a hidden fee. It is the combination of a translated currency, a variable reward that arrives sometimes, and a sunk cost that has already accumulated by the time the player sits down to convert the premium unit back into money. At that moment, stopping means realizing the loss. Continuing means another translation they will again forget inside the session.

The same translation runs in reverse when the premium currency can be converted back into platform money. Every item is then a claim on that conversion, denominated in a unit the player does not constantly translate. The exit makes upstream rewards feel like money. It also makes a bad trade feel like lost money, which sharpens both endowment (hold, don't sell cheap) and loss aversion (don't realize the loss). The spread between hold-price and clear-price gets wider, not narrower, when the exit is real. That is the central tension of any play-to-exit economy, and it is a mechanism, not a side effect.

## Aspirational anchor

The anticipation phase of the loop can be set by showing the player the higher state before they can reach it. The GameAnalytics writeup of compulsion loops cites the implementations: Clash of Clans letting a new player visit the top of the leaderboard, Hay Day's tutorial forcing a visit to a fully built farm, and the RPG device of opening at high power and then stripping the player back to the start. The mechanism is reference-point setting. The higher state becomes the origin from which the starter state is measured, so the starter state is a loss relative to what was just seen, and the loop has a target. An anchor that is never shown leaves the player with no picture of what the actions are for. An anchor that is shown and then given away for nothing collapses the distance the gradient needs.

## How the mechanisms stack

None of these is sufficient alone, and several of them cancel if they are tuned against each other.

Variable ratio keeps the next action likely. Near-miss keeps it likely after a loss, but only if the loss looks close. Successful completion makes the output feel like more than its clearing price, which is good for attachment and bad for selling, unless a buyer exists who wants the item for a different reason. Goal gradient accelerates the player near a mark and does nothing while the only mark is far, so intermediate marks are required for the acceleration to ever turn on. Loss frames on timers bring the player back, and destruction of completed items pushes them out, so the thing that expires should be an advantage or a window, not the object the labor produced. Social proof prices the object in public, which is what allows the endowed owner and the non-owner to find a number between their two private values. Instrumental status makes the intermediate marks worth reaching in front of other people. The aspirational anchor sets the far reference. The translated currency hides the running cost of chasing it. The exit, if it exists, denominates all of the above in money and makes every one of those effects larger.

A stack in which the exit is promised but the currency can be created by play, without new money coming in, eventually breaks the exit. Players who notice early do not deposit. Players who notice late say so in public. Either way the anchor ("this is worth real money") stops being believed, and every mechanism that was borrowing its force from that anchor gets weaker at once. Solvency of the premium currency — new units enter only when new money enters — is the condition under which the rest of the stack keeps its denomination.

Literacy cuts the other way. Zagal, Björk, and Lewis observe that a pattern the player can see and consent to is no longer operating in the dark. Variable ratio, near-miss, and loss frames do not require darkness to function; they function on the structure of the feedback, and players who understand them still respond, which is the finding across the near-miss and loss-aversion literatures (knowing the bias does not reliably stop the behavior). Decoys, fake scarcity, and impersonation do require a degree of inattention, and they decay as the audience learns the genre. A game aimed at a genre-literate audience should put its weight on the mechanisms that survive literacy — schedules, completion, gradients, real scarcity, real presence, a real exit — and use the devices that decay as seasoning, not as the structure.

## Success rubric (any game)

Tiers, worst to best: **Thin**, **Partial**, **Working**, **Dense**.

The threshold in this rubric is Working or better on every row. That is a design heuristic, not a measured law. It has not been playtested on any specific title here. The reasoning behind the threshold is the stacking point above: the mechanisms reinforce each other only when each phase of the loop is at least functioning. A game that is Dense on variable rewards and Thin on opening legibility never gets the schedule a chance to run. A game that is Dense on status and Thin on a crossable value spread produces a leaderboard nobody trades under. "Far more likely" means: in the band where every row is at Working or Dense, the loops can close often enough that return, invitation, and spend have something to attach to. Below that band on any single row, that row's absence is a plausible reason the rest fails to compound. It is not proof that a given game will fail.

**1. Opening legibility.** Can a new player see what they do, what they can get, and the next action, before they have read anything?
Thin: the first minute is a document. Partial: the action is visible but the payoff is not. Working: one action completes, and its result is an object or a step the player holds. Dense: that first result is visibly the same kind of object the rest of the game trades in, so the player has already touched the real economy.

**2. Solo closure.** Is there a repeatable action that pays off with no other player required?
Thin: nothing happens until a counterparty arrives. Partial: a solo action exists but its output is a private number, useless once people arrive. Working: the solo action produces objects the shared economy already uses. Dense: the solo action also teaches the prices and the targets the shared economy is currently using, so the stockpile is aimed, not random.

**3. Variable-ratio action.** Is the repeated action paid on a variable schedule the player can feel?
Thin: fixed payout every time, or a rare payout that never comes. Partial: variable, but the player cannot see the connection between their choice and the bands. Working: choices shift the odds, small outcomes arrive often, rare outcomes are the top of the same roll. Dense: the player can narrate a reason their last choice mattered, whether or not it did as much as they think.

**4. Perceivable near-miss.** When the rare outcome is missed closely, can the player see the closeness?
Thin: results are announced as success or fail with no track. Partial: a track exists but resolves too fast to read. Working: the stop is visible and a near stop is distinguishable from a full miss. Dense: the near stop also returns something held, so the loss and the continuation are the same event.

**5. Completed-labor attachment.** Does effort resolve into a held object often enough that attachment forms?
Thin: most attempts resolve into nothing. Partial: attempts resolve, but into a currency or a number, not an object. Working: attempts resolve into objects the player keeps. Dense: the player can point at an object and say they made it, and other players can want that same object.

**6. Goal gradient.** Are there intermediate marks close enough to accelerate effort, with the far reward still visible?
Thin: one far reward, no marks between. Partial: marks exist but the remaining distance is hidden. Working: the next mark is visible and close, and the bar does not start empty. Dense: the marks are public, so reaching one changes how other players treat you, and the far reward remains on screen as the anchor.

**7. Loss-framed return.** Does missing a window cost an advantage the player already had, without destroying completed work?
Thin: no reason to come back except memory. Partial: a bonus waits, and missing it costs nothing already owned. Working: an advantage or a window expires, and owned objects do not. Dense: the expiring advantage is the one the player was actively preparing, so the return is specific, not generic.

**8. Crossable value spread.** Can an owner's endowed price and a buyer's offer actually meet?
Thin: no buyer, or a posted NPC price that erases negotiation. Partial: buyers exist but prices never clear. Working: some trades clear through negotiation or a listing format that lets the two sides move. Dense: the player can learn, from watching clears, where the spread usually sits, and can still profit by knowing more than that.

**9. Social proof under uncertainty.** When price or quality is unclear, is other people's real behavior visible?
Thin: the player prices alone. Partial: visibility exists but the events are fabricated or stale. Working: recent real actions of similar players are on screen. Dense: the player can filter that evidence to people at their own level, so the model looks like them.

**10. Instrumental status.** Does a visible standing change what other players will do?
Thin: no standing, or a standing nobody sees. Partial: a standing everyone sees and nobody acts on. Working: standing changes access, terms, or who will initiate. Dense: the player can feel the change in a single session after crossing a mark, not only over weeks.

**11. Aspirational anchor.** Is the higher state shown before it is reachable?
Thin: the top of the game is undescribed. Partial: the top is described in text. Working: the player sees a real higher state — another player's, or a brief taste — and is then at the start. Dense: the path from the start to that state is made of the same actions the player can already perform.

**12. Believable exit, if the game has one.** If outcomes convert to something outside the game, is that conversion backed?
Thin: the conversion is promised and the unit it pays in can be created without new outside value coming in. Partial: the conversion exists but the rate or the threshold is opaque enough that players cannot tell if it is real. Working: new premium units enter only when new outside value enters, and the conversion burns units rather than printing them. Dense: the player can see their distance to the threshold in the same unit they already spend, and can see that other players have crossed it.

**13. Occupied market.** Does the shared space look inhabited when the player arrives?
Thin: empty room, no trace of other players. Partial: traces exist but are old or fake. Working: real recent activity is visible, including activity from players who are not currently clicking. Dense: a new player can join that activity without already knowing someone — list, stand, buy — and be seen doing it.

**14. Instrumental invitation.** Does bringing another person in change what the inviter can do, in a way the invited person then also wants?
Thin: invite buttons with no effect. Partial: a cosmetic for inviting, which the invited person does not need to repeat. Working: the invited person's presence improves a real action for both, and the invited person faces the same improvement if they invite. Dense: the improvement is felt in the first shared session, not after a long recruitment grind.

**15. Spend that sinks into play.** Does spending money buy a clearer, faster, or more convenient version of actions the player can also perform, rather than a separate game?
Thin: no spend path, or a spend path that replaces play entirely. Partial: spend buys a private advantage that never touches the shared objects. Working: spend buys time, convenience, or a known object from the same pools play produces, and the spent unit leaves circulation or stays backed. Dense: the player who spends and the player who plays are holding interchangeable objects, so they meet in the same market.

---

# Part 2 — The same rubric on Roblox

## What the platform adds

Roblox is not a neutral host. It selects for a subset of the mechanisms in Part 1, and it adds a currency that is both the money players spend and, in this game, the money players can earn. That dual use is the fact everything else hangs on. A player who earns Robux inside the experience is not collecting a score that happens to be named after the platform currency. They are accumulating a claim on Robux, paid out past a threshold at a rate. Upstream of that claim, the platform also pays the creator: engagement-based payouts track Premium members' time in the experience, rewarded video ads pay the creator when a player opts into a 6-to-30-second ad, and direct Robux purchases pay the creator through the usual store. Those creator-side flows are real, and they are not the same pipe as player cashout. Mixing them up in the design — treating "the game earns Robux" as if it were "the player earns Robux" — produces a game that monetizes the creator and strands the player. This game's proposition is the second one. The first one still has to balance, because player cashout is Robux leaving, and it can only keep leaving if Robux has been coming in.

Discovery follows the same split. John Ciancutti's August 20, 2026 note on the developer forum, ahead of the Recommended For You update targeted for late August or early September 2026, states the operating rule in public: Home recommendations use a range of signals; there is no single metric; games with strong retention and games with monetization both still receive impressions; games that are strong in both may receive broader distribution. If retention is low, the note says to fix the first session, the core loop, and the reasons to return before tuning monetization. If retention is high, monetization that players can feel, placed at natural moments, is what widens distribution. Seasonality, competing games, and algorithm changes move impressions even when a game's own signals hold still. None of that is a formula a designer can solve for. It is a selection pressure: a game that does not get a second session from a meaningful share of first-time players does not get to find out whether its economy works, and a game that retains but never gives those players a reason to spend or to watch an ad leaves the distribution narrower than a game that does both.

The audience sharpens the first-session requirement. A large share of players are young, on a phone, in a session that can end because someone called them. Creator discussions of day-one retention repeatedly land on the same observation: if the first action is not available in seconds, a large fraction of joiners are gone before any loop starts. Text tutorials are a common place those joiners leave. The mechanisms in Part 1 that require a ten-minute explanation never fire. The mechanisms that fire on one completed action can.

Rewarded video, per the creator documentation, is a full-screen opt-in ad of 6 to 30 seconds, triggered by a button the player presses, with the reward disclosed before the ad plays, granted immediately, and not randomized. The recommended reward size is on the order of a few Robux of value, delivered as a developer product that would normally be purchasable. The docs tell creators not to inflate currency, not to gate progress behind the ad, and not to promise free Robux as the bait. For a game whose gem supply is capped to real Robux inflows, the ad is one of the two legal mints — purchase is the other — and it has to stay a fixed grant of the same gem product the store sells, at the stated rate, disclosed as an ad. It is not a random drop and it is not a Robux drop.

The genre context is the trading plaza, not the obby. Pet Simulator's plaza is a separate server of stalls, with AFK occupants common enough that players write guides about which booths are alive and which are parked, and with purchase cooldowns so a listing cannot be sniped in the same instant it appears. Adopt Me's economy runs on community value lists maintained outside the game; player writeups treat knowing values as the actual skill, and treat a fully official, complete price list as a threat to that skill rather than as a courtesy. Both patterns are player-reported and neither is a law. They are evidence about what the audience already knows how to do: stand at a stall, leave the stall up while away, read a recent sale, distrust a price they cannot verify, and stay for the argument about what something is worth. A Roblox trading game that does not support those behaviors is asking the audience to forget a skill they already have. A Roblox trading game that automates those behaviors entirely is asking them to stay for a shop.

Appointment mechanics have to survive interruption. A wither timer that punishes a child who got pulled off the device produces a loss frame and also a quit. The loss frame that fits this platform is an advantage that cools off — a craft bias, a fee waiver, a rotation window — while the objects already completed stay in the inventory, and while an AFK pad can finish a job that was already started. The session metric and the player's real evening are not the same clock. AFK occupancy is how trading games on this platform keep the room looking inhabited and keep a job completing when the player cannot hold the device. It is also how a returning player meets a variable reward: sometimes the stall sold, sometimes it did not, and they could not have known which without coming back.

## Rubric, adapted

Same tiers: Thin, Partial, Working, Dense. Same threshold: Working or better on every row, as a heuristic, not a tested result. What changes is what the tiers mean when the platform is Roblox and the audience already knows stalls, value arguments, and short sessions.

**1. Opening legibility.** Working means one craft, roll, or listing completes before any tutorial text, on a phone screen, with the result in the inventory. Dense means that result is an item other players in this genre would recognize as tradeable, and the Robux exit is visible as a threshold on the gem balance without a paragraph explaining it.

**2. Solo closure.** Working means a player who joins an empty server can still produce items the board, the booths, and the store rotation already use. Dense means that by the time a second player arrives, the first player's stockpile is already pointed at what the rotation has been showing, so the empty-server time was not a different game.

**3. Variable-ratio action.** Working means the roll's small outcomes arrive inside a short session, and the rare outcome is on the same roll. Dense means the player's material choice visibly shifts the bands, so the conditioned action is the choice, which this audience will talk about the way they talk about values.

**4. Perceivable near-miss.** Working means the roll is a track the player watches, and a stop just short of the rare band is readable on a phone. Dense means that near stop returns materials into the same stacks the next roll consumes, so the next attempt is already funded by the miss.

**5. Completed-labor attachment.** Working means a finished craft sits in the inventory as an item, not as a private point total. Dense means the player can list that item on a booth or the board without converting it into something else first, so the attachment and the market are about the same object.

**6. Goal gradient.** Working means the next rank is on screen, the remaining distance is a count of actions they can do today, and the bar started with a step already credited for joining. Dense means crossing the rank changes booth treatment or trade access in the same session, and the cashout threshold stays visible behind the rank as the far anchor. Ranks that take weeks to move do not accelerate anyone on this platform; the session is too short for a distant bar to feel close.

**7. Loss-framed return.** Working means a rotation or a craft bias expires, and completed items do not. Dense means an AFK pad can finish the job they already started, so the loss they are avoiding is a missed window, not a punished absence. A wither that deletes inventory is the wrong loss frame for a platform where players are pulled off the device.

**8. Crossable value spread.** Working means booths and the board let two players meet between the owner's price and the buyer's, with no NPC quoting a buy price. Dense means recent clears are visible enough that a new player can learn the band the way Adopt Me players learn values, without the game publishing a complete list that ends the argument.

**9. Social proof under uncertainty.** Working means real sales, real booth occupants, and real crafts are on screen, including from players who are AFK. Dense means a player can see activity from people at their own rank, not only from the top of the leaderboard, so the model looks like a peer rather than a different species.

**10. Instrumental status.** Working means the rank is visible on the booth and changes who will start a trade or what the listing fee is. Dense means a player feels that change immediately on crossing into the next rank, in the plaza, in front of other people. A rank that lives in a profile menu does not do this.

**11. Aspirational anchor.** Working means a new player can see a Trader's booth, the current Gem Store rotation's rare piece, and the cashout threshold, in the first session. Dense means all three are made of items and actions the new player can already touch: the same craft, the same roll, the same gems.

**12. Believable exit.** This row is not optional on this platform for this kind of game, because Robux is a real balance players already understand from every other experience. Working means gems enter a balance only when Robux has come in — a purchase, or a rewarded ad at a fixed disclosed rate — and cashout burns gems past a visible threshold at a stated rate. Dense means the player can watch the gem balance, the threshold, and other players' cashed-out status without anyone explaining the backing, and can see that quests, stalls, and AFK did not mint the gems they are looking at. Creator-side ad revenue and Premium engagement payouts are not displayed as if they were the player's cashout. They are the inflows that make the player's cashout possible.

**13. Occupied market.** Working means booths stay listed while the owner is on an AFK pad, and the board shows recent sales. Dense means a new player can stock a booth from solo crafts and be indistinguishable, at a glance, from everyone else standing there. Empty plazas read as dead to this audience within seconds, because they have stood in full ones.

**14. Instrumental invitation.** Working means a crew member in the same server shortens a craft or waives a fee for both parties. Dense means the invited player hits that benefit in the first session and immediately has a reason to bring one more person for the same benefit. Cosmetic crew badges do not propagate.

**15. Spend that sinks into play.** Working means gems bought with Robux, or granted by the rewarded ad at the fixed rate, are spent at the store on known items, materials, or time reductions from the same pools crafting produces. Dense means a spender and a crafter list interchangeable items on the same booth row, so spend is a parallel path into the market, not a private buff. Bonus gems that improve the Robux-to-gem rate break the backing the exit depends on, and a randomized ad reward breaks the platform's own ad rules. Neither belongs on this row.

---

# Part 3 — This game

## The constraint, in my words

Gems are a backed claim on Robux. A gem may appear in a player's balance for exactly two reasons: they paid Robux for it, or they finished a rewarded ad and the grant is the fixed 10 gems per 1 Robux that ad brought in. Every other event in the game is forbidden from causing a gem to enter a balance. Quests, dailies, rank-ups, the Crafter, Unique Crafts, rolls, the Gem Store, an NPC, a buy-back, a "the store purchases your item," an AFK pad, a crew perk, a leaderboard prize, a solo activity, a refund, and a rebate are all forbidden as gem sources. If a fee is waived, the fee is not charged. It is not charged and then refunded in gems, because a refund would put gems into the balance without a new Robux event. Player-to-player payment is different from creation: if one player spends gems they already hold and another player receives those same gems, the supply does not grow. That transfer is the market. The system never takes the buy side of a trade for gems. I will check every mechanic below against this before it stands, and I will say what it pays in.

Starter pools, under this rule, are materials and items. They do not contain gems. The cashout threshold and rate stay whatever they already are; cashout burns gems the player already holds. It does not mint them.

## The solo activity

This is an extension of the Crafter, the roll, Unique Crafts, and the Gem Store rotation. It is not a new desk, not a new NPC, and not a new named system. A player with no one else in the server can repeat it. Its outputs are the same items the board, the booths, the 1:1 trade window, and the Gem Store rotation already use.

The player opens the Crafter with materials from the starter pools, or with materials and items a previous craft returned. They choose what to feed in. The existing roll resolves on a strip they watch, not as an instant toast. The strip is marked in bands: a low band that returns a portion of the materials they put in, a standard craft band, a better craft band, and a Unique Craft band. The strip slows before it stops. A stop in the band immediately below Unique is readable as close. That is the near-miss, and it is perceivable, which is the condition under which Clark's result applies.

Every stop completes. The low band returns materials to the stacks they already have. The craft bands place an item in the inventory. The Unique band places a Unique Craft. There is no empty resolution, because empty resolution is the case where completed-labor attachment does not form. The item placed is not a solo-only token. It is an item from the pools the board already lists and the booths already display. The player can hold it, and the moment any other player exists they can list it, trade it 1:1, or leave it on a booth. Until then it is a stockpile of the real market, built alone.

The Gem Store rotation is the target while no buyer is online. The rotation already tells the server which categories are current, because those are the items the store is offering for gems this window. The Crafter's roll, for materials in the currently featured category, has its upper bands slightly wider during that window. This is a weight on the existing roll, driven by the existing rotation. It pays nothing by itself. When the rotation changes, the width returns to normal. Materials the player gathered for the old window are still theirs — nothing is deleted — but the craft advantage they were building has cooled. That is the loss frame that brings them back for the next rotation, without destroying a completed Unique, which would throw away the attachment the craft just created.

The first roll in a new account finishes quickly, inside the span of a short Roblox session, so the loop closes once before the player is pulled off the device. Later Unique attempts take longer. A longer attempt that has already been started can be left on an AFK pad. The pad does not start jobs by itself and does not invent materials. It finishes a Crafter roll the player already fed. They return to a completed item or a returned material stack, sometimes closer to Unique than they expected, sometimes not. That uncertainty is the variable reward on the return.

What the player feels, alone, in order: they chose materials (the action that gets conditioned), they watched the strip (anticipation), they saw it stop, often close (near-miss or hit), they held an item or a returned stack (completion), the rank bar moved (gradient), the Gem Store window told them what to feed next (a target with no partner), and the cashout threshold sat on the gem line at whatever balance they actually have, which is zero until they buy gems or finish an ad. The exit is visible. The Crafter did not pay it.

The Gem Store remains a seller. The player may spend gems there — gems they bought with Robux, or gems a rewarded ad granted at 10 per 1 Robux — on materials, on a time reduction for the next Unique attempt, or on a specific item the rotation is currently stocking. Those are sinks. The store does not buy the player's crafts. There is no NPC paycheck for solo play. The satisfaction is the held item, the close roll, the moving rank, and a stockpile that is already in the market's language. When a counterparty finally stands at a booth, the solo player is not starting over. They are opening a trade window on objects both of them already know.

Rank quests attach to this without a new giver. The quest line is the existing Noob, Casual, Regular, Trader track. Noob asks for Crafter rolls and for standing at a booth with one crafted item listed. Casual asks for a near-miss band hit and for a listing on the board or a booth. Regular asks for a completed Unique Craft. Trader is not reachable alone, because Trader requires completed trades with other players. That is intentional. The solo loop carries the player through Noob and Casual and up to the edge of Regular. Trader is the mark that pulls them into the plaza once partners exist, which is the goal gradient doing the handoff from solo to market. The far anchor, cashout, stays on screen the whole time so the ranks are read as steps toward Robux rather than as badges.

## Self-check, mechanic by mechanic

**Crafter repeat use, including the watched roll strip.** Pays in crafted items and in returned materials from the stacks the player already put in, not gems.

**Near-miss band on that roll.** Pays in the craft of the band it actually landed in, plus returned materials, not gems. The closeness is display. Display pays nothing.

**Unique Craft success on that roll.** Pays in the Unique Craft item, not gems.

**Rotation weight on the Crafter roll.** Pays nothing. It changes band width. The roll's payout is still items and returned materials, not gems.

**Rotation expiry of that weight.** Pays nothing. It removes an advantage. It does not grant gems to compensate, and it does not delete owned items.

**AFK pad finishing a Crafter roll already started.** Pays in the item or the returned materials that roll was already going to produce, not gems. The pad does not generate a payout of its own.

**Noob quests on the Crafter and the booth.** Pay in starter-pool materials, or in a listing-fee waiver on the first board or booth listing. A waiver means the fee is not charged. Pays in materials or a waived fee, not gems.

**Casual quests on the near-miss band and the first listing.** Pay in a time reduction on the next Unique Craft attempt, or in a fee waiver. Pays in time or a waived fee, not gems.

**Regular quest on a completed Unique Craft.** Pays in a material bundle from the same pools, or in a longer fee waiver. Pays in materials or a waived fee, not gems.

**Trader quests.** Pay in fee waivers or time reductions on the Crafter. The gems a Trader actually receives come from other players spending gems they already hold. The quest does not pay gems.

**Rank bar with the first step already credited for receiving starter pools.** Pays nothing. It is perceived distance. The quest at the end of the bar pays as above, not gems.

**Gem Store purchases.** The player spends gems and receives a material, a time reduction, or a specific rotation item. The store pays in that item, material, or time reduction, not gems. Gems move from the player into a sink.

**Gem Store decoy layout.** Three offers, the intended one in the center, the flanks making it the compromise, a bundled extra on the center offer. The extra is a material or a Crafter time reduction. It is not bonus gems, because bonus gems would change the 10-per-1-Robux rate without a matching Robux inflow. Pays in a material or a time reduction, not gems.

**Rewarded ad, surfaced at the Gem Store.** This is the allowed exception, not a new source. It pays in gems at 10 per 1 Robux because that is the rewarded-ad mint, disclosed before the ad plays, fixed, not randomized, and granted as the same gem product a Robux purchase grants. The Crafter does not pay this. The quest does not pay this. The ad receipt does. It is not offered as free Robux.

**Crew perk, while a crew member shares the server.** Shortens Crafter time or widens the material-return band slightly. Pays in time or in returned materials, not gems. No crew stipend.

**Leaderboard of Unique Crafts, sales count, and rank.** Display only, except that a top slot for a period grants a fee waiver and a Crafter time reduction. Pays in a waived fee and a time reduction, not gems. No gem prize.

**Board listing, booth listing, bulk buy, 1:1 trade.** The system charges a fee by not returning it — a sink — or waives it by not charging it. Bulk buy is one player spending gems they already hold to purchase several listings from other players. The system does not buy. 1:1 is item for item; if gems change hands inside a 1:1, they are gems already in a player's balance moving to another player. Pays in items, and in gem transfers between players, not in newly created gems.

**Cashout.** Burns gems the player already holds, past the existing threshold, at the existing rate, and pays Robux out. It does not create gems. This is the exit the rest of the game is denominated in. Players can earn real Robux here, and they earn it by converting backed gems, not by being paid gems for playing.

## Rubric for this game

Same tiers, same threshold: Working or better on every row is the band where these systems can reinforce each other. That is a heuristic. It has not been playtested on this game. Nothing below is a claim that a given score has already been achieved.

**1. Opening legibility.** Working: join, starter pools in the inventory (materials and items, not gems), Crafter open, one roll watched to completion, item held, before any explanation. Dense: the booth row and the Gem Store rotation are in the same view as that item, and the cashout threshold is visible on a gem balance that reads zero until a purchase or an ad. The proposal puts the first roll on the Crafter specifically so this row can reach Dense without a new surface. Pays in the crafted item, not gems.

**2. Solo closure.** Working: the Crafter loop above produces board-legal items with no counterparty. Dense: the rotation weight aims those items at the category the store is currently teaching the server to want, so an empty-server stockpile is already in the market's current language. This is the row the solo activity exists to move. The Crafter pays in items and returned materials, not gems. The weight pays nothing.

**3. Variable-ratio action.** Working: most rolls land in craft bands or material-return, Uniques are the top of the same strip, and the player sees enough outcomes in one short session to feel the ratio. Dense: material choice and the current rotation both move the bands, so the player can tell a story about the choice. The roll pays in items and materials, not gems.

**4. Perceivable near-miss.** Working: the strip slows and a stop just under the Unique band is readable on a phone. Dense: that stop returns materials the next roll consumes, so the miss funds the continuation. Pays in the landed craft plus returned materials, not gems.

**5. Completed-labor attachment.** Working: every roll completes into a held item or a held material stack. Dense: the player can put that item on a booth without transforming it, and a buyer can want it for the same reason the Gem Store rotation featured its category. Pays in items, not gems. No empty fail state, because an empty fail is how this row falls to Thin.

**6. Goal gradient.** Working: Noob, Casual, Regular, Trader are on screen in those names, the next one is a short count of Crafter, listing, or trade actions, and the bar starts with the starter-pool step already filled. Dense: crossing a rank changes booth treatment or the listing fee immediately, and the cashout threshold remains the far mark behind Trader. Quest payouts along this bar pay in materials, time reductions, or fee waivers, not gems. The pre-filled step pays nothing.

**7. Loss-framed return.** Working: when the Gem Store rotation changes, the Crafter's widened bands for the old category return to normal, and owned items stay owned. Dense: a roll already started can finish on an AFK pad, so the player who gets pulled off the device does not lose the attempt, and still has a reason to come back before the next rotation cools the advantage they were building. The expiry pays nothing. The pad pays in the craft's item or materials, not gems.

**8. Crossable value spread.** Working: booths, the board, and 1:1 are the only way an item becomes gems, and the gems that move already existed in a player's balance. The Gem Store does not buy. Dense: recent clears show on the board so a Noob can see the band a Regular actually paid, without a published price list that ends the value argument this audience stays for. System side of every trade pays in nothing. Players pay each other in items or in existing gems.

**9. Social proof under uncertainty.** Working: booth occupancy, including AFK occupancy, and recent board clears are visible. Dense: those feeds can be read at the viewer's own rank, so a Casual sees Casuals clearing, not only Traders. Display pays nothing.

**10. Instrumental status.** Working: Noob, Casual, Regular, and Trader show on the booth, and at least one of fee, who-may-initiate, or bulk-buy access changes at Regular and again at Trader. Dense: the change is obvious in the plaza in the same session the rank ticks over. The rank-up itself pays in a fee waiver or a time reduction if it pays at all, not gems.

**11. Aspirational anchor.** Working: from the Crafter, the player can see a stocked Trader booth, the rare piece in the current Gem Store rotation, and the cashout threshold. Dense: all three are the same objects the Crafter roll can produce and the same gems a purchase or an ad can add. Nothing new is shown that the existing systems cannot eventually yield. The anchor pays nothing.

**12. Believable exit.** Working: the only gem mints are a Robux purchase and the rewarded ad at 10 gems per 1 Robux; cashout burns gems past the existing threshold at the existing rate; no quest, pad, crew, store, or craft mints gems. Dense: a player can audit their own balance against those two sources and against transfers from other players, and can see other players who have cashed out, so the Robux exit is demonstrated rather than described. This row is the core proposition. Players can earn real Robux from this game. They earn it by converting gems that entered through Robux, not by being paid gems for playing. Every mechanic in the section above was checked against that. The ad pays in gems only as the stated exception. Everything else pays in items, materials, time, or waived fees, not gems.

**13. Occupied market.** Working: AFK pads keep booths listed, and the board keeps recent sales. Dense: a player who has only used the Crafter can stock a booth with those crafts and look, to a passerby, like everyone else in the row. The pad pays in completed crafts, not gems. The booth pays its owner only if another player spends gems they already hold.

**14. Instrumental invitation.** Working: a crew member in the server shortens Crafter time or widens material return for both. Dense: the invited player feels that on the first shared roll and has the same reason to invite one more. Crew perk pays in time or returned materials, not gems.

**15. Spend that sinks into play.** Working: gems leave the balance at the Gem Store in exchange for materials, time reductions, or a specific rotation item from the pools the Crafter also fills. Dense: that store item and a Crafter Unique are interchangeable on the board, so the spender and the solo crafter meet as holders of the same goods. The center offer in the store layout bundles a material or a time reduction, not extra gems. The store pays in the purchased good, not gems.

A game sitting at Working or Dense on all fifteen is in the band where a short first session can close, a solo player can build real stock before anyone else arrives, a near-miss can fund the next roll, a rank can pull them into the plaza, a rotation can bring them back, a booth can sell to a stranger, and the gems in that sale can be traced to Robux that actually came in — which is what makes the cashout a thing players will believe long enough to chase. That is the heuristic. It is not a result from playtesting this game, and it should not be treated as one until the rolls, the rotation width, the rank distances, and the existing cashout rate have been in front of players who can leave.Research complete across scholarly literature (Zagal et al.'s dark pattern taxonomy, Aagaard et al.'s CHI study, Niknejad et al.'s mobile-game analysis, Brooks & Clark's loot box work, Lehdonvirta/Hamari's virtual-goods economics, Castronova's virtual economy work), industry sources, Roblox developer forums, platform documentation, and player community accounts. Here is the full document.

---

# The Psychology of Game Engagement: A Complete Analysis and Application

---

## PART 1 — The Full Catalog: Every Technique, Every Mechanism

### 1.1 How this is organized

Rather than sorting techniques into "normal," "dark," and "ultra dark" as three separate bins — which implies a moral ranking — I've organized everything by **the underlying psychological mechanism being engaged**, and tagged each technique with where it sits on the intensity spectrum: **standard** (baseline engagement craft), **dark** (the technique works by exploiting a gap between the player's intent and the player's behavior), and **ultra dark** (the technique deliberately conceals costs or manufactures dependency in ways documented to correlate with harmful outcomes in the research literature). Every technique is presented as working design material. The taxonomy backbone comes from Zagal, Björk & Lewis (2013), who first classified game dark patterns into **temporal**, **monetary**, and **social-capital** categories, later extended by Aagaard et al. (CHI 2022) and the community catalog at darkpattern.games to include a fourth **psychological** category. The empirical picture of how pervasive these are: an analysis of 1,496 mobile games found 85,388 rated dark-pattern instances, with only 10.76% of games showing none at all — meaning these techniques are not fringe; they are the mainstream vocabulary of the medium [arXiv / Niknejad et al.](https://arxiv.org/html/2412.05039v1) [Aagaard et al., CHI 2022](https://dl.acm.org/doi/abs/10.1145/3491101.3519837)

### 1.2 Variable-reward mechanisms (the slot-machine engine)

**The mechanism.** Ferster & Skinner (1957) established that a **variable-ratio reinforcement schedule** — reward arrives after an unpredictable number of attempts — produces the highest and most extinction-resistant response rate of any schedule. The player cannot know *which* pull pays, so every pull is a maybe, and quitting feels like walking away one attempt before the win. Neurochemically, dopamine fires most strongly at **anticipation of an uncertain reward**, not at the reward itself — the wanting system, not the liking system. This is why the *moment before* a loot box opens, with its drumroll animation, is the engineered peak.

**Where it appears in games:** loot boxes, gacha rolls, card packs, random drops, RNG crafting outcomes, wheel spins. Brooks & Clark (2019, *Addictive Behaviors*, 420+ citations) documented that loot box engagement shares the core characteristics of gambling, including variable-ratio reinforcement, and correlates with problem-gambling measures [Brooks & Clark](https://www.sciencedirect.com/science/article/pii/S0306460318315077). King & Delfabbro coined **"predatory monetization"** for systems that hide long-term costs until the player is already financially and psychologically invested — this is the academic anchor for what players call "ultra dark."

**Spectrum instances:**
- *Standard:* random loot drops with visible, published odds; a crafting system where the recipe is known but the quality roll is variable.
- *Dark:* odds present but buried; "pity timers" that exist but aren't disclosed; near-miss presentation (the reel *almost* landing on the legendary) which gambling research shows increases continued play despite being objectively a loss.
- *Ultra dark:* probability manipulation without disclosure, dynamic odds, spend-gated pity, and layering — a random reward that must itself be upgraded through another random system paid in premium currency.

**The transferable lesson for any game:** uncertainty about *outcome* sustains engagement far better than certainty, but uncertainty about *rules* (hidden odds, moving targets) is what turns the same lever into the darker version. A roll with known odds and a visible result is still the single most powerful engagement primitive ever discovered in the medium.

### 1.3 Time-based mechanisms (the appointment engine)

**The mechanism.** Zagal et al. define **temporal dark patterns** as designs that prolong or shorten interaction sequences against player expectations [Zagal et al., via Niknejad et al. 2024](https://dl.acm.org/doi/full/10.1145/3701571.3701604). Two sub-mechanisms matter:

- **Playing by appointment** — the game schedules the player's life. Daily login rewards, streaks, time-gated events, energy meters, crops that wilt. The hook is **loss aversion** (Kahneman & Tversky: losses weigh roughly twice as heavily as equivalent gains): a streak is framed as something you *own* that will be *taken*, so logging in is protecting property, not seeking fun. Daily check-in behavior in one documented mobile study shifted from reward-seeking to loss-avoidance within about two weeks.
- **Grinding + pay-to-skip** — the game deliberately installs friction (an artificial obstacle), then sells the removal of the friction it created. The monetary pattern only works because the temporal pattern made the baseline unpleasant. The design skill is calibrating the friction to be *bearable but memorable*.

**Spectrum instances:**
- *Standard:* daily quests, rested-XP systems (World of Warcraft's rested bonus actually rewards absence — a notable counter-design), weekly resets that create rhythm without punishment.
- *Dark:* streaks that reset to zero on a missed day, limited-time events with no return date, energy systems tuned so a free player hits the wall mid-flow.
- *Ultra dark:* appointment chains that stack — daily login gates a weekly bonus that gates a monthly reward, so one missed day cascades into losing all three — combined with pay-to-skip priced at the exact point of maximum frustration.

### 1.4 Scarcity, urgency, and FOMO (the rotation engine)

**The mechanism.** Perceived scarcity increases perceived value — this is one of the most replicated findings in consumer psychology, and Hamari & Lehdonvirta (2010, 773 citations) showed it applies directly to virtual goods: "a perception of scarcity" drives demand for items that are, in physical terms, infinitely copyable [Hamari & Lehdonvirta](https://www.econstor.eu/handle/10419/190610). Rotating shops convert *availability* into *urgency*: the item isn't rare in absolute terms, but it is rare *right now*, which compresses the purchase decision from "someday, maybe" into "today or possibly never." The additional twist is **anticipated regret** — players buy not because they want the item, but to insure against the future state of wanting it and not having it.

Player communities are fully literate in this now — forum threads about rotating shops in ESO, Darktide, and 2XKO show players naming the mechanism explicitly ("artificial scarcity," "FOMO rotation") — and the striking finding from those threads is that *the mechanic still works on players who can name it* [Fatshark forums](https://forums.fatsharkgames.com/t/get-rid-of-fomo-item-shop-rotation/120596). Knowing the lever doesn't neutralize the lever, because the regret is real even when the scarcity is manufactured.

**Spectrum instances:**
- *Standard:* seasonal content, rotating stock with a published schedule, limited-quantity world items.
- *Dark:* unannounced rotation windows, "last chance" items that quietly return later (which trains cynicism), countdown timers on shop tiles.
- *Ultra dark:* fake countdowns that reset, individually-differentiated scarcity (different players shown different "leaving soon" timers), and limited items sold during a window engineered to close just before a competing purchase opportunity.

### 1.5 Ownership and labor mechanisms (the investment engine)

Three distinct but related biases, each with a real citation:

- **Endowment effect** (Kahneman, Knetsch & Thaler): ownership itself inflates value. The moment an item enters a player's inventory, losing it hurts more than never having had it. Trade systems exploit this constantly — the person *holding* the item demands more than they'd ever pay for it, which is precisely why player-to-player trade negotiations feel charged [The Decision Lab](https://thedecisionlab.com/biases/endowment-effect).
- **IKEA effect** (Norton, Mochon & Ariely, 2012, *Journal of Consumer Psychology*): people assign disproportionately higher value to things they partially created, *even when the result is objectively worse*. A crafted item is worth more to its crafter than an identical dropped item. This is the deep reason crafting systems retain players out of proportion to their mechanical depth — the crafting is doing identity work, not item work [IKEA effect in gamification](https://agate.id/the-ikea-effect-in-gamification-harnessing-player-engagement/).
- **Sunk cost / accumulated investment**: time, currency, rank, relationships, and collections already deposited into a game raise the cost of leaving. Note the mechanism is forward-looking — players stay not because past time is recoverable (it isn't) but because the accumulated position *would be abandoned*, which is loss aversion again.

**Spectrum instances:**
- *Standard:* crafting, housing, character customization, collections.
- *Dark:* starter gifts engineered to trigger endowment ("your free legendary — don't lose it!"), deletion-of-progress as a monetizable threat, inventories that fill up to sell storage.
- *Ultra dark:* systems where the player's accumulated position is explicitly held hostage — pay or your streak/rank/pet decays.

### 1.6 Progress and goal mechanisms (the almost-there engine)

**Goal-gradient effect** (Kivetz, Urminsky & Zheng, 2006, *Journal of Marketing Research* — the famous coffee-stamp-card experiment): effort accelerates as perceived distance to the goal shrinks. Two operational consequences every progression designer uses: (a) visible progress bars convert abstract advancement into tangible proximity; (b) **endowed progress** — giving the player head start ("2 of 10 stamps pre-filled") — dramatically increases completion versus the same remaining distance from zero, because the goal is now framed as already-in-progress, and abandoning it is a loss [goal-gradient effect](https://uxplanet.org/the-goal-gradient-effect-5f29bb5b7e0d).

**The Zeigarnik effect** (Bluma Zeigarnik, 1920s): interrupted, incomplete tasks are remembered and mentally "held open" better than completed ones. Quest journals, uncollected reward icons, and red-dot notification badges all work by keeping loops deliberately *open* — the badge isn't information, it's an itch. Games stack dozens of open loops so that at any moment, *something* is unfinished and pulling the player back.

**Spectrum instances:**
- *Standard:* quest logs, achievement lists, rank ladders, collection tabs.
- *Dark:* progress bars that slow down as they fill (velocity manipulation — the bar lies about how close you are), endless prestiges designed so no loop ever closes, notification dots that can't be dismissed without paying.
- *Ultra dark:* progress systems tuned so the last increment before a reward costs more than all previous increments combined, disclosed nowhere.

### 1.7 Social mechanisms (the obligation engine)

Zagal et al.'s **social-capital dark patterns** exploit relationships as a resource. The mechanisms:

- **Social obligation and reciprocity**: gifts create debts; guild daily-contribution systems convert friendship into a chore schedule. Players who join social structures retain dramatically better — Roblox's own developer material reports playing with friends increases retention by ~70%, and third-party retention guides cite guild members retaining 3–5× better than solo players [Roblox "From the Devs"](https://medium.com/roblox-developer/from-the-devs-how-social-loops-keep-players-playing-6b24b299c124) [bloxg retention guide](https://bloxg.com/guides/roblox-player-retention).
- **Monetized rivalry**: leaderboards and PvP ladders that can be climbed by spending. The rivalry is real; the ladder is a toll booth.
- **Social pyramid schemes**: referral systems where recruiting friends is the primary progression vector.
- **Status display**: cosmetics, rare items, and titles as visible rank markers. Lehdonvirta (2009, 712 citations) found virtual-goods purchases are driven by functional, hedonic, *and social* attributes — with social display (what the item says about you to others) often dominant in multiplayer contexts [Lehdonvirta 2009](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1351769).

**Spectrum instances:**
- *Standard:* guilds/crews, trading, co-op bonuses, gifting.
- *Dark:* guilt-tripping guild contribution quotas, pay-to-win ladders, referral-gated content.
- *Ultra dark:* systems that let players spend money to *damage* rivals, and social obligations with monetary penalties for letting the group down.

### 1.8 Currency architecture mechanisms (the obfuscation engine)

**The mechanism.** Dual-currency (soft + premium) design does three things at once: it decouples price from money (a 1,200-gem item doesn't *feel* like $12), it manufactures leftover balances (gem packs sized so you always have some left over — an unspent balance is a reason to return *and* a psychological nudge to top up to afford the next thing), and it fragments the player's mental accounting. Castronova's "On Virtual Economies" (2002) remains the foundational text: virtual economies are real economies, and whoever controls the faucet/sink balance controls perceived value [Castronova](https://www.econstor.eu/handle/10419/76069).

**Spectrum instances:**
- *Standard:* one earnable currency, one premium currency, clear conversion.
- *Dark:* premium packs sized to guarantee leftovers, deliberate price obfuscation, intermediate conversion currencies.
- *Ultra dark:* three-plus currency layers where the exchange rate changes at each layer, making the real-money cost of anything effectively uncomputable for the player.

### 1.9 The hook architecture (how it all chains)

Nir Eyal's **Hook Model** (trigger → action → variable reward → investment) is the meta-pattern that chains the above: an external trigger (notification, rotation reset) prompts an action (log in, roll), which produces a variable reward (1.2), which demands an investment (1.5 — crafting, collecting, ranking up) that *itself becomes the next trigger* (endowed progress, open loops, owned assets). The compulsion loop literature on Wikipedia and GameAnalytics converges on the same structure: anticipation → challenge → variable reward → re-investment [Compulsion loop](https://en.wikipedia.org/wiki/Compulsion_loop). Every long-lived game is, at the systems level, a set of these loops of different lengths (seconds: the roll; minutes: the quest; days: the rank; weeks: the market position) nested inside each other.

### 1.10 Distillation: the universal mechanisms that map onto ANY game

Stripping every genre-specific surface away, the research reduces to **eight universal levers**:

1. **Variable outcomes** — uncertainty about *what* you'll get sustains action better than certainty (Skinner; Brooks & Clark).
2. **Open loops** — unfinished, visible business pulls players back (Zeigarnik).
3. **Approaching goals** — visible proximity accelerates effort; pre-started progress accelerates it more (Kivetz et al.).
4. **Owned and made things** — possession and self-assembly inflate value beyond the object's objective worth (endowment; IKEA effect).
5. **Scarcity and windows** — limited availability, real or scheduled, compresses decisions and creates check-in rhythm (Hamari & Lehdonvirta).
6. **Social stakes** — relationships, obligations, rivalries, and status displays make leaving socially expensive (Zagal; Roblox's own retention data).
7. **Faucets and sinks** — perceived value of everything is downstream of controlled supply and enforced demand (Castronova; every DevForum economy thread).
8. **Nested loops** — engagement holds when short, medium, and long loops interlock so there's always a next thing at every time horizon (Eyal; compulsion-loop literature).

### 1.11 THE SUCCESS RUBRIC (any game)

Tiers are qualitative: **Absent / Baseline / Strong / Exceptional**. The claim, stated as a design hypothesis rather than a law: *a game scoring **Strong or better on every row** is far more likely to achieve durable virality than one with any row at Baseline or below.* This is a heuristic distilled from the literature above, not a measured law — no rubric substitutes for playtesting, and specific thresholds must be tuned per game.

| # | Row (mechanism) | Baseline | Strong (threshold) | Exceptional |
|---|---|---|---|---|
| 1 | Variable outcomes | Rewards are deterministic | A core action has exciting uncertain outcomes with known rules | Multiple uncertainty layers (drop, quality, rarity) feed each other |
| 2 | Open loops | One quest at a time | Several concurrent visible goals at different horizons | Something is always unfinished at every session length, without feeling cluttered |
| 3 | Goal proximity | Progress is invisible | All major progression has visible bars/counters | New goals arrive pre-started (endowed progress) |
| 4 | Ownership & labor | Items are disposable loot | Players craft/customize/own things they value | Player-made items carry identity and are shown to others |
| 5 | Scarcity & rhythm | Everything always available | Scheduled rotation/reset creates a return rhythm | Scarcity is real (limited supply) and publicly visible |
| 6 | Social stakes | Solo-playable, social is cosmetic | Social systems give concrete advantages | Social position (rank, wealth, reputation) is publicly legible and costly to abandon |
| 7 | Economy balance | Currency inflates freely | Faucets and sinks are deliberately tuned | The economy has real scarcity, real trade, and observable prices |
| 8 | Nested loops | One gameplay loop | Short/medium/long loops interlock | Each loop feeds the others (short-loop output is long-loop input) |
| 9 | First-session hook | Tutorial, then nothing | First session ends mid-goal with the next session pre-seeded | First session ends with an owned, self-made asset and an open loop |

---

## PART 2 — Roblox-Specific Layer

### 2.1 What the Roblox context changes

**The platform is the discovery engine, and it pays for retention.** Roblox's own announcements state the Recommended-for-You algorithm now weights retention across day 1, days 2–7, *and days 8–28* — meaning design that produces 28-day returning players is directly rewarded with impressions [Roblox newsroom](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox) [DevForum algorithm update](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575). On Roblox, retention mechanics aren't just engagement design — they are your marketing budget. This makes the "open loops" and "rhythm" rows of the rubric doubly important here.

**Session length is a ranking signal too.** Concurrent players and average session time feed the same discovery system. This is the structural reason **AFK pads** exist across the platform: they convert willing players into session-length and concurrency. A DevForum thread analyzing AFK zones found the design genuinely extends sessions but requires careful event analytics to distinguish real engagement from parked players [DevForum AFK analysis](https://devforum.roblox.com/t/afk-zone-decreasing-average-session-time-by-25/3561558).

**Social features are the highest-leverage retention investment on the platform.** Roblox's own developer guidance attributes ~70% retention lift to playing with friends; guild/crew members retain multiples better than solo players [Roblox "From the Devs"](https://medium.com/roblox-developer/from-the-devs-how-social-loops-keep-players-playing-6b24b299c124). Roblox's official retention documentation explicitly lists **trading** among the social systems that drive retention [Roblox Creator Hub](https://create.roblox.com/docs/production/analytics/retention). Crews, booths, and trading aren't features on Roblox — they're the retention backbone.

**Trading cultures are self-organizing and status-driven.** Adopt Me's economy shows the full psychology stack in the wild: supply-and-demand pricing on scarcity, "happy values" (community-agreed price consensus), visible wealth hierarchies, and "broke to rich" trading content as a genre — the *fantasy of trading up from nothing* is itself a content engine that markets the game for free [cacti.gg Adopt Me analysis](https://cacti.ggmm.com/the-hidden-psychology-of-happy-values-in-adopt-me-how-rare-pets-shape-digital-desire) [Adopt Me economy thread](https://www.reddit.com/r/AdoptMeRBX/comments/1s4kwid/adopt_me_economy/). Trade Hangout demonstrates that a *pure trading social space* — booths, flexing limiteds, deal-hunting — is viable as an entire game [Trade Hangout wiki](https://roblox.fandom.com/wiki/Merely_Studios/Trade_Hangout).

**Robux-earning propositions are a proven virality engine.** PLS DONATE — a game whose entire core loop is "claim a booth, receive Robux" — became one of the platform's biggest games on that single proposition [PLS DONATE](https://www.roblox.com/games/8737602449/PLS-DONATE). The Reddit thread "Pls Donate — what is the point?" is instructive: even observers who don't understand the game recognize its gravitational pull, because *earn-real-Robux* is the strongest headline a Roblox game can carry [r/roblox](https://www.reddit.com/r/roblox/comments/1ad47p2/pls_donate_what_is_the_point/).

**Rewarded ads are now a first-class faucet.** Rewarded video is available to all eligible creators; players 13+ opt in for defined, non-randomized rewards, and Roblox recommends reward value around 3–10 Robux equivalent, with direct Robux payouts prohibited — which is exactly why an intermediate currency (gems) paid at a fixed Robux-equivalent rate is the correct architecture [GameBiz rewarded ads guide](https://www.gamebizconsulting.com/blog/roblox-ad-monetization-guide-2026) [Roblox Creator Hub — rewarded ads](https://create.roblox.com/docs/production/promotion/rewarded-video-ads).

**Economy tuning follows the platform's folk wisdom.** DevForum consensus: keep free-currency accrual "fair but low," make early items cheap and later items progressively more expensive, and always pair faucets with sinks (consumables, fees, repairs) to prevent inflation from gutting perceived value [DevForum economy design](https://devforum.roblox.com/t/how-to-design-the-ideal-in-game-economy/238862).

### 2.2 THE ROBLOX SUCCESS RUBRIC

Same threshold logic: **Strong or better on every row** for virality likelihood. Same caveat: heuristic, not law; tune by playtesting.

| # | Row | Baseline | Strong (threshold) | Exceptional |
|---|---|---|---|---|
| 1 | First-session hook (D1) | Player finishes tutorial and drifts | First session ends with an owned asset and an open loop | First session produces something *tradeable* the player made themselves |
| 2 | 28-day rhythm (matches the algorithm) | No scheduled rhythm | Rotation/reset cycle gives a reason to return weekly | Stacked rhythms: short rotation + longer rank/season arc |
| 3 | Variable outcomes | Deterministic rewards | A roll/rng core with known rules and exciting ceiling | Rolls feed crafting feed trade: uncertainty compounds through systems |
| 4 | Trading liquidity | 1:1 trades only | A board/market where offers can be found asynchronously | Visible price consensus emerges (community "values") — the market becomes content |
| 5 | Session-length design | Sessions end when content ends | AFK/idle structure extends sessions legitimately | Idle presence is *also* social presence (booths, crew spaces) |
| 6 | Social stakes | Chat exists | Crews give concrete shared goals and perks | Crews, booths, and leaderboards make status publicly legible server-wide |
| 7 | Earn-real-Robux clarity | Proposition is vague | Players understand exactly how play converts to cashout | The path to first cashout is visible from session one and progress toward it is tracked |
| 8 | Economy solvency & sinks | Faucets outpace sinks | Every faucet has a matching sink; supply is controlled | The solvency rule itself is a public trust signal |
| 9 | Content-engine externality | Nothing clip-worthy | Wealth moments and rare rolls are screenshot-worthy | "Broke to rich" and rare-roll moments are YouTube/TikTok-native by design |

---

## PART 3 — The Rubric Applied to This Exact Game

### 3.1 Statement of understanding — the core proposition

I understand and state plainly, up front: **players can earn real Robux from playing this game.** Gems accumulate through play (via items, trading, and the market), reach a defined **cashout threshold**, and convert to real Robux at a defined **cashout rate**. This is not a side feature, a footnote, or a marketing garnish — it is the core proposition, the headline, and the reason the game exists on the same virality axis as PLS DONATE. Every system in the game either feeds a player's path toward cashout or feeds the economy that makes cashout meaningful, and the analysis below treats it that way throughout.

### 3.2 The hard constraint, restated in my own words

Before proposing anything, here is the constraint as I understand it and will apply it: **a gem can only ever be born from real money.** A gem enters a player's balance in exactly two ways — (a) the player directly purchases gems with Robux, or (b) the player watches a rewarded ad, and the ad revenue (real money received by the game) funds gems at the fixed rate of 10 gems per 1 Robux. No quest, no daily, no NPC, no store buy-back, no AFK pad, no crew perk, no solo activity, no market mechanism may ever *create* a gem. This is the **gem-solvency rule**: because gems cash out to real Robux, the total gem supply must never exceed what real money has paid for — any system that mints gems without Robux behind them would be printing unbacked claims on the developer's own DevEx balance. Therefore, every mechanic I propose below is checked before inclusion: if it rewards the player, the reward must be **items, materials, craft inputs, market/board fee reductions, roll-cost reductions, time reductions, booth perks, or rank/quest progress — never gems.** Where a player ends up with gems, it must be because *another player* (or the store acting purely as a pass-through of player-deposited gems) transferred already-existing gems to them. I state the payout explicitly for each mechanic: "pays in X, not gems."

### 3.3 Scoring the game against the rubric, row by row

**Row 1 — First-session hook. Assessment: Strong, improvable to Exceptional.** The game has the raw materials for the best possible first session on the platform: starter pools give the new player immediate material, the Crafter turns that material into a *self-made* item (IKEA effect — the crafted thing is worth more to them than an identical found thing), and rolling gives the first variable-reward spike within minutes. The gap: the first session must end with the player holding something *tradeable* and mid-way toward a visible goal. Concretely: the Noob quest track should guarantee that session one ends with (a) one self-crafted item sitting in inventory, (b) the Casual-rank bar visibly partially filled (endowed progress — pre-start the bar so the player is "already on the way," Kivetz et al.), and (c) one open loop left deliberately dangling (a partially-complete Unique Craft, or a posted offer on the board awaiting a bite). *Constraint check: starter pools and quest completion here pay in items/materials and rank progress, not gems.* ✔

**Row 2 — 28-day rhythm. Assessment: Strong.** The gem store rotation is the return-rhythm engine, and it maps directly onto the discovery algorithm's 8–28 day window. Make the rotation schedule *published* (players should be able to learn it — community knowledge of rotation timing becomes Discord/wiki content, which is free marketing), and layer it: a short rotation (store stock) inside a longer arc (rank ladder Noob → Casual → Regular → Trader, and any seasonal board resets). *No payout involved — the store takes gems in; it never pays gems out.* ✔

**Row 3 — Variable outcomes. Assessment: Strong.** Rolling is the Skinnerian core, and Unique Crafts add the second uncertainty layer (roll outcome → craft outcome). The key design quality is *known rules, exciting ceiling*: published roll odds, visible Unique Craft possibilities, and rare outcomes that are publicly celebrated (a server-wide or crew-wide announcement on a Unique Craft pull costs nothing and converts one player's dopamine into everyone's goal). *Constraint check: rolls consume roll-access/materials and output items, not gems.* ✔

**Row 4 — Trading liquidity. Assessment: the game's crown jewel — push to Exceptional.** The trade board/market with bulk buy plus 1:1 trading is a complete market stack most Roblox games never build. The Exceptional tier is reached when **price consensus becomes visible and community-owned**: the board should show recent completed-trade history per item (not a suggested price — actual clearing prices), which lets "values" emerge the way Adopt Me's did. Community value-lists are a content engine: YouTubers make "values update" videos, players argue about them, and the argument itself is retention. The endowment effect does the rest — every holder overvalues what they hold, every buyer underbids, and the friction between the two *is* the gameplay of a trading game. *Constraint check: all trades and market transactions move existing player-held items and existing player-held gems between players; the board itself mints nothing. Any market fee should be taken in items or a burn of listed materials where possible; if a gem-denominated listing fee exists, it is a sink that removes existing gems, never a faucet.* ✔

**Row 5 — Session-length design. Assessment: Strong.** AFK pads plus booths mean a player's idle time still registers as presence — and booth presence is *socially functional* presence (a manned booth is a storefront other players visit). Tighten it: AFK pads should sit within sight of the booths and board, so parked players are scenery and social proof for the market (a busy-looking market is a trustworthy-looking market). *Constraint check: AFK pads pay nothing that enters the gem economy — any AFK reward is materials or roll-access, not gems; ideally pads pay nothing at all beyond presence.* ✔

**Row 6 — Social stakes. Assessment: Strong, improvable to Exceptional.** Crews exist; the upgrade is giving crews *shared, visible, ranked goals* that use existing systems: crew leaderboards (which exist) ranked by crew trade volume or Unique Crafts completed, and crew booths (a shared storefront — an extension of the existing booth feature, not a new structure). The rank names — Noob, Casual, Regular, Trader — are a public status ladder; make rank visible on the avatar/booth so "Trader" reads as a title others can see from across the server. Socially legible status is the expensive-to-abandon asset that anchors long-term retention. *Constraint check: crew perks and leaderboard placement pay in fee reductions, booth cosmetics, roll-cost reductions, and rank progress — never gems.* ✔

**Row 7 — Earn-real-Robux clarity. Assessment: must be Exceptional, because it is the proposition.** The path must be legible from minute one: a persistent, visible tracker showing the player's current position relative to the cashout threshold ("your tradable inventory's current market value + your gem balance vs. the threshold"), tutorialized in session one. Every system tooltip should answer "how does this get me closer to cashing out" — the Crafter makes things people buy, the board is where you sell them, bulk buy is how you scale, rank unlocks better market access. The cashout threshold and rate should be stated in-game in plain language, not buried in a menu. Clarity here is not a courtesy; it is the conversion funnel for the entire virality engine — "a Roblox game where you actually cash out" is the headline that travels by word of mouth, exactly as PLS DONATE's did. *Constraint check: the only gems a player ever holds arrived via Robux purchase, rewarded ads at the 10:1 rate, or transfer from another player's existing balance. Cashout is a payout of the game's real, backed gem liability — it never creates supply.* ✔

**Row 8 — Economy solvency & sinks. Assessment: Strong, and structurally advantaged.** The gem-solvency rule means the game already has the cleanest possible premium-currency backing on the platform — supply is definitionally backed by real money. The remaining work is the *item* economy: item faucets (starter pools, rolling, crafting) need matching item sinks. Existing features provide them without any new system: crafting consumes materials (a sink), market listing fees in materials (a sink), and the gem store rotation pulls player gems out of circulation (the premium sink). Watch the ratio the DevForum wisdom prescribes: early items cheap and quick, later items progressively longer to work toward — challenging but never impossible [DevForum economy design](https://devforum.roblox.com/t/how-to-design-the-ideal-in-game-economy/238862). *Constraint check: all sinks destroy or transfer existing assets; nothing mints gems.* ✔

**Row 9 — Content-engine externality. Assessment: improvable to Exceptional cheaply.** The game natively generates the two most viral Roblox content formats: rare-roll moments (rolling → Unique Craft) and wealth-arc stories ("Noob to Trader," the broke-to-rich genre that Adopt Me built an ecosystem of). Engineer the capture: server announcements for Unique Crafts, a visible leaderboard that makes wealth arcs legible, and cashout milestones worth clipping ("player just cashed out" — with the player's opt-in — is the single most persuasive advertisement this game can produce, because it proves the proposition). *No payout involved.* ✔

### 3.4 The solo activity — the actual proposal

The requirement: a repeatable, satisfying solo activity needing no counterparty, built only from the Crafter, Unique Craft, rolling, and Gem-Store systems already in the game, that feeds the same item pools and the same market. Here it is:

**Crafter Work Orders** — a permanent, rotating list of *requested crafts* posted on the Crafter itself.

- **What it is:** The Crafter (the existing NPC/station) always displays a handful of open work orders — each one a request for a specific crafted item: "3× [mid-tier craft]," "1× [item requiring a rolled rare material]," occasionally "1× [Unique Craft]." The orders rotate on the same rhythm infrastructure as the gem store rotation, so the check-in habit loops through one station.
- **What the player does, alone:** Use starter-pool materials and rolled materials (the existing rolling system) to craft the requested items at the Crafter (existing), then turn them in at the same station. No other player is involved at any step. Early on — before any trading partners exist — this is the complete loop: gather → roll → craft → deliver → repeat, with the goal-gradient pull of a rotating order list that's always partially completable with what you have.
- **What it pays — constraint check, stated explicitly: work orders pay in items, materials, roll-access, and rank/quest progress (Noob → Casual → Regular → Trader XP), never gems.** Fulfilled orders return material bundles (including materials one tier above what the player can currently roll — a taste of the future), occasional Unique Craft *recipes/blueprints* (not the finished item — the player still has to roll and craft it), and quest-track progress. Not one gem is created or transferred by the Crafter. ✔
- **Why it feeds the same pools and market:** Orders deliberately request items one band above the player's comfort zone, so fulfilling them produces *surplus* mid-tier crafts the player doesn't need — natural sellable stock for the board/market and bulk buy. And the materials one tier up create *demand* the player can't fully self-supply, which is what pushes them, when ready, to the board and 1:1 trading to fill gaps. The solo loop is thus the on-ramp that manufactures both the supply and the motivation for the multiplayer economy, rather than competing with it.
- **Why it satisfies solo:** it stacks the mechanisms without any counterparty — variable outcomes (rolling for materials), IKEA-effect ownership (everything delivered is self-crafted), goal-gradient (order lists are visible, partially done, and pre-started where possible), Zeigarnik (an order list always has something unfilled), and appointment rhythm (rotation gives tomorrow a reason to exist). It is the Blox Fruits shape — a self-directed solo progression that needs no bartering — expressed entirely through this game's own existing verbs: roll, craft, deliver.
- **Feature lineage, as required:** it is the **Crafter** wearing a "requests" hat, fed by **rolling** and **starter pools**, scheduled by the **gem-store rotation** infrastructure, and tracked by the existing **quest/rank** system. No new NPC, desk, dispenser, or named system is introduced. ✔

**One supporting extension, same constraint:** let the quest system include standing work-order milestones ("complete 10 work orders as a Casual") paying in rank progress and a booth cosmetic — *pays in progress and cosmetics, not gems.* ✔

### 3.5 Final rubric verdict for this game

| Row | Score | One-line note |
|---|---|---|
| First-session hook | Strong → Exceptional with the session-one ending above | Self-made tradeable asset + open loop |
| 28-day rhythm | Strong | Publish the rotation schedule; layer rank arc |
| Variable outcomes | Strong | Announce rare outcomes publicly |
| Trading liquidity | Strong → Exceptional with visible trade history | Let community values emerge |
| Session-length | Strong | Co-locate AFK pads with booths/board |
| Social stakes | Strong → Exceptional with crew goals + visible rank | Status must be publicly legible |
| Robux-earning clarity | Target: Exceptional | Threshold tracker visible from minute one — this is the headline |
| Solvency & sinks | Strong | Gem backing is already airtight; tune item sinks |
| Content externality | Strong → Exceptional with cashout-milestone moments | Proof of cashout is the best ad |

The game meets or exceeds the Strong threshold on every row as designed, with the highest-leverage upgrades concentrated in rows 1, 4, 6, 7, and 9 — all achievable by reshaping existing features, and every proposed mechanic above verified to pay in items, materials, progress, cosmetics, or fee/time reductions — never in gems.

---

**Key sources:** [Zagal et al. taxonomy via Niknejad et al. 2024](https://dl.acm.org/doi/full/10.1145/3701571.3701604) · [Aagaard et al., CHI 2022](https://dl.acm.org/doi/abs/10.1145/3491101.3519837) · [Dark-pattern prevalence study, arXiv](https://arxiv.org/html/2412.05039v1) · [Brooks & Clark 2019, loot boxes](https://www.sciencedirect.com/science/article/pii/S0306460318315077) · [Hamari & Lehdonvirta 2010](https://www.econstor.eu/handle/10419/190610) · [Lehdonvirta 2009](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1351769) · [Castronova, On Virtual Economies](https://www.econstor.eu/handle/10419/76069) · [Roblox Discovery/retention update](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox) · [Roblox social retention](https://medium.com/roblox-developer/from-the-devs-how-social-loops-keep-players-playing-6b24b299c124) · [Roblox rewarded ads](https://create.roblox.com/docs/production/promotion/rewarded-video-ads) · [GameBiz Roblox ad guide](https://www.gamebizconsulting.com/blog/roblox-ad-monetization-guide-2026) · [DevForum economy design](https://devforum.roblox.com/t/how-to-design-the-ideal-in-game-economy/238862) · [PLS DONATE](https://www.roblox.com/games/8737602449/PLS-DONATE) · [Adopt Me economy analysis](https://cacti.ggmm.com/the-hidden-psychology-of-happy-values-in-adopt-me-how-rare-pets-shape-digital-desire) · [darkpattern.games](https://www.darkpattern.games/)

**Suggested next steps if you want them:** (1) a tuning worksheet mapping each work-order tier to material costs and rank XP; (2) a session-one script (minute-by-minute first-session flow implementing the Row 1 ending); (3) a deeper pass on market fee/sink sizing once you have even a few days of playtest telemetry — the rubric gives you the structure, but the actual ratios should come from your own players' data.
