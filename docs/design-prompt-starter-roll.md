# Design prompt — New-player welcome + starter roll

Paste everything below the line into Claude Design (or any UI design tool).

---

## What I'm building

A Roblox **item-trading economy game**. Players roll for items, trade them with each
other, run market stalls, and craft. Items have real computed values (scarcity ×
demand), and gems convert to Robux at a published rate — so an item is genuinely
worth something, and players know it.

I need the **first 60–90 seconds a brand-new player ever sees**. This is a full-screen
takeover on first join: it cannot be closed, skipped, or dismissed. It is the single
highest-leverage screen in the game — if it doesn't hook, they leave and never trade.

## The flow (4 states — I want all of them designed)

**State 1 — Welcome.** Big, loud, almost no words. Something like
"WELCOME! READY TO EARN SOME ROBUX?" then "THEN ROLL YOUR FIRST ITEMS!" and a single
fat green button: **"Roll starter items"**. Nothing else on screen. No close button,
no X, no "skip" — this is deliberate.

**State 2 — Rolling.** The button is pressed and multiple roll strips spin at once.
(Strip design is locked — see below.) Tension moment.

**State 3 — The variant callout.** Mid-roll or on landing, a pop-in / fade-out banner
announces which of two starts the player got:
- **"LUCKY! YOU GOT A SUPER-ROLL"** — fewer strips (≈3), but high-value items. The
  strips' outlines turn **purple** for this variant.
- **"LUCKY! YOU GOT MULTIROLL"** — many strips (≈6), lots of cheap items.

Both are framed as *lucky* — there is no "bad" outcome, and the player must feel they
got the good one either way. This asymmetry is intentional: it seeds a market where
different players hold different things and therefore have a reason to trade.

**Player-facing copy must never say or imply any of that.** No line on screen should
hint that the variant is deliberate, that it's designed to create trading demand, or
that one player got a different shape of reward than another for a reason. As far as
the player can tell, they just got lucky — full stop. Keep the mechanism invisible;
only "LUCKY! YOU GOT X" ever reaches the screen.

**State 4 — Reveal + the hook line.** "CONGRATULATIONS!" with their new items laid
out, and then the payload line:

> **"YOU'RE ALREADY WORTH ≈X ROBUX"**

computed from the aggregate value of what they just rolled. This is the moment the
whole screen exists for — they own something real, with a real number on it, within
90 seconds of joining, before spending anything.

## LOCKED — do not redesign the roll strip

The strip mechanic already exists in-game and must stay recognizable:

- A **horizontal, clipped strip** of square item tiles that scrolls right-to-left past
  a **fixed center marker**, decelerating to a stop with the prize under the marker.
- Tiles either side of the winner stay visible — the deliberate **near-miss**: you see
  what slid past and what almost landed.
- Each tile: square item art, rounded (~8px), with a **dark translucent name band**
  across the bottom carrying the item name in small caps-ish text.
- The center marker carries a **rarity-colored glow** that resolves to the winning
  item's rarity color on landing.

**What's new here (and what I want you to compose):** instead of one strip, the
starter roll shows **several strips stacked vertically**, all spinning
**simultaneously** with **different offsets/speeds** so it reads as chaotic and
random rather than synchronized. Like:

```
[ ——— strip 1 spinning ——— ]
[ ——— strip 2 spinning ——— ]
[ ——— strip 3 spinning ——— ]
```

3 strips for SUPER-ROLL, ~6 for MULTIROLL. How they stagger, land, and resolve
(all at once? cascading? one dramatic last?) is yours to design — that's the
showpiece.

## Visual vocabulary (match this)

Dark, chunky, rounded, Pet-Simulator-adjacent. Bold headers, rarity-colored accents,
gold reserved for premium/Robux moments.

**Fonts:** Gotham Bold for everything structural, Gotham (regular) for secondary text.

**Core palette:**
| Role | Hex |
|---|---|
| Background | `#20222A` |
| Background (light) | `#2C2F3A` |
| Panel | `#262933` |
| Stroke / border | `#464A5A` |
| Text primary | `#F0F2F8` |
| Text dim | `#A0A5B4` |

**Accents:**
| Role | Hex |
|---|---|
| Gem (cyan) | `#78DCE8` |
| Gold | `#FDB31E` |
| Good / confirm green | `#57D982` |
| Punchy CTA green | `#2FE04A` |
| Hot magenta (bonus lines) | `#E21EAA` |
| Electric cyan | `#40E0FF` |
| Bad / danger | `#F05F5F` |

**Premium gold gradient** (used for anything Robux/value-flavored — keep it *yellow*
gold, never orange): `#FFEB96` → `#F5D45A`, with a dark gold edge stroke `#A87E1E`.
Glossy metallic fill runs `#FFFAC8` → `#FDE776` → `#FFF194` → `#F6D860` top to bottom.

**Rarity colors** (for tile glows / outlines):
| Rarity | Hex |
|---|---|
| Common | `#9AA0A6` |
| Rare | `#4FC3F7` |
| Legendary | `#FFB74D` |
| Mythical | `#BA68C8` |
| Godly | `#FF5F82` |
| Celestial | `#78F5EB` |

**Conventions already used throughout the game:** 10px corner radius on panels, 6px on
small controls; 1.5–2.5px strokes; dark text-stroke (`#0F1016`) behind bold light text;
a white top-fading "sheen" gradient over premium cards; gold gradient strokes on
anything high-value. Section headers occasionally carry a single emoji (e.g. "💎 GEM
PACKS") — sparing use is on-brand, spam is not.

## Constraints

- **Mobile-first.** Most players are on phones. Everything must read at phone size;
  hit targets ≥44px. Design for a ~390×844 phone frame *and* show me how it holds at
  desktop.
- **No fake device chrome** (no drawn status bars).
- **No close/skip affordance anywhere** in states 1–3.
- The reveal must not visually leak the result before the strips land.

## What I want from you

Explore hard — this screen should feel like a slot machine crossed with a prize drop,
not a form. Give me:

1. All 4 states as separate artboards.
2. Both variants (SUPER-ROLL purple outlines / MULTIROLL many strips) visibly distinct.
3. At least 2 genuinely different directions for the celebration treatment
   (state 3 + 4) — e.g. one restrained/premium, one maximalist/explosive — so I can pick.

Use placeholder squares for item art. Real copy, not lorem ipsum. The tone is loud,
kid-readable, hype — but the value line ("YOU'RE ALREADY WORTH ≈X ROBUX") should land
as *credible*, not as a scammy banner ad.

## Why it's built this way (background for you, not screen content)

This section explains intent so your design choices reinforce it — none of this
reasoning should ever appear as copy, flavor text, or a tooltip on the actual screens.

- **Endowment effect** — handing a player real, valued property in the first session
  makes them treat the account as something they own and would lose by leaving.
- **Guaranteed-win first pull** — no bad outcome on the first roll; both variants are
  framed as lucky.
- **Near-miss visibility** — seeing the items that *almost* landed is what makes the
  strip tense rather than a loading bar.
- **Asymmetric starts** — different players holding different things is what makes a
  market exist at all on day one. The player must never learn this is why.
