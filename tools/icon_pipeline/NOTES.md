# Icon pipeline — pumping out new items without art skill

## The actual bottleneck

`PoolService.generateDefs` can already mint an unlimited number of structurally
valid items for free — name (676 adjective×noun combos), supply, rarity, and
draw weight all auto-derive. **The only hard ceiling is unique icons**: two
items may never share one, and the built-in Simulator Icon Pack only has
~35-40 icons that don't look like currency or UI chrome. That's the whole
bottleneck.

## The fix: game-icons.net

- **4,180 icons**, CC-BY-3.0 (free for commercial use, attribution required).
- Single-color line art — genuinely well-suited to per-item tinting later
  (tint by rarity, or by the adjective already in the generated name — "Frozen
  X" renders ice-blue, "Crimson X" renders red) without needing separate art
  per color.
- Source repo: `github.com/game-icons/icons` (all SVGs, organized by author
  subfolder). Not a Roblox-native asset library — players won't recognize the
  style from other Roblox games, which matters for the "feels custom" goal.

Curated category starting points (author subfolders in the repo worth
rasterizing first, before touching all 4,180 at once):
- `delapouite/` — huge general fantasy/item/loot category, hundreds of icons.
- `lorc/` — heavy on weapons, gems, potions, armor — good rarity-ladder fodder.
- `willdabeast/` — smaller, stylistically consistent set, good for a themed
  seasonal event drop.

Pick ~50-100 icons per batch that fit an actual near-term need (a themed
event, a rotation refresh) rather than bulk-rasterizing everything up front —
see "how many do we actually need" below.

## Pipeline

1. `git clone https://github.com/game-icons/icons`
2. Rasterize the SVGs you want to PNG (see the docstring in `upload_icons.py`
   for a 3-line `cairosvg` snippet — no Inkscape/design tool required).
3. Set three env vars: `ROBLOX_OPEN_CLOUD_API_KEY` (create at
   create.roblox.com/dashboard/credentials, scope: Assets → Write, restricted
   to this experience), `ROBLOX_CREATOR_TYPE` (`User` or `Group`),
   `ROBLOX_CREATOR_ID`.
4. `python upload_icons.py --input rasterized/ --manifest manifest.json --luau-out new_icons.luau --limit 40`
5. Paste `new_icons.luau`'s lines into `IconPool` in
   `src/shared/Config/Items.luau`.

Re-running the script only uploads files not already in `manifest.json`, so
this is meant to be run repeatedly in small batches over the game's life, not
once in bulk.

## How many do you actually need, and how fast

Each generated pool consumes 14 icons (`PoolTemplate` has 14 slots). At the
game's current scale, a healthy few-months runway is maybe 10-20 pools —
140-280 icons. **A single ~40-icon batch (the script's default `--limit`)
roughly triples the entire current usable icon supply in one run.** There is
no need to upload thousands at once; that just front-loads moderation risk
and burns variety you haven't found a use for yet. Batch it against actual
need (a new event, a stale rotation) instead.

## Required: attribution

CC-BY-3.0 requires crediting game-icons.net and the specific icon authors
somewhere a player can reach — a credits/about screen, the game's Roblox
description, or a group wall post all satisfy this. This is a real license
term, not optional polish — don't ship uploads without it somewhere.

## What this does NOT solve

- **Recipe/event items are a separate, worse bottleneck** — they need a prose
  blurb and must satisfy `CraftingService`'s recipe-graph validator (no shared
  outputs, rotating recipes terminal-only, limited-input chains matching their
  output's expiry). This icon pipeline feeds the *pool* (roll) side only. A
  templated "ladder generator" (theme in, full recipe chain out) is the
  equivalent fix for that side and hasn't been built.
- **Item count should trail population, not lead it.** More distinct items at
  low player counts fragments the order book — nobody finds a counterparty for
  anything specific. Use this pipeline to keep pace with actual growth, not to
  front-load hundreds of items before there are players to trade them.
