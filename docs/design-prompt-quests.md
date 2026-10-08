# Design prompt — Quests panel

Paste everything below the line into Claude Design.

---

## What I'm building

A Roblox **item-trading economy game**. Players roll for items, trade them on a board, craft, and cash gems out for Robux.

I need the **Quests panel**. Quests are a short, ordered checklist: one active at a time, each pays gems and moves you up a rank (Noob → Casual → Trader → Pro → Sweat → OG). Ranks unlock features and give you a title shown above your head. Past the last quest, titles keep climbing with trading profit.

Its job: make a player want to do "just one more".

## What it has to show

- where I am (rank) and how close the next one is
- the quest I'm on now, its progress, and what I get for it
- a way to skip the current quest for Robux (just "SKIP (R$ 49)", price is a placeholder)
- a hint of what's coming next
- what it looks like once every quest is done

## Constraints (light)

- Big, the same size class as the game's other main panels (Shop etc.), not a small popup.
- It should sit comfortably next to the other panels without looking pasted in. Beyond that, the look is yours.
- Must be buildable with standard Roblox UI (frames, text, strokes, gradients, simple icons) and work on phones.

## Reference specs (starting points, not rules)

**Size.** Same as the Shop panel: centred, **66% of screen width × 84% of height**, capped at **900 × 700 px**. Phone floor ~340 px wide. Content scrolls if it has to.

**Palette the game already uses** (use, remix or ignore):

| Role | Colour |
|---|---|
| Base / deepest | `#20222A` |
| Panel | `#262933` |
| Raised surface | `#2C2F3A` |
| Border / divider | `#464A5A` |
| Text | `#F0F2F8` |
| Dim text | `#A0A5B4` |
| Gold (reward, rank) | `#FDB31E` |
| Gem cyan (gem amounts) | `#78DCE8` |
| Blue (info / action) | `#58A6FF` |
| Green (positive, buy) | `#57D982` |
| Amber (warning) | `#FABE50` |
| Red (close, negative) | `#F05F5F` |

**Type.** Gotham Bold for headings and numbers, Gotham for body. **Corners** 6–10 px. **Close button:** small red "X", top-right.

Everything else, like layout, hierarchy, style, motion and copy, is up to you. Surprise me.
