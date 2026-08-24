---
name: verify-ui
description: Use when any UI work in this Roblox project is about to be called done, committed, or reported — building or editing GuiBuilder/StarterGui panels, wiring a *Screen.luau, changing layout, sizes, or copy. Requires a screenshot of the populated UI and a programmatic overflow scan BEFORE any success claim.
---

# Verify UI Before Claiming Anything

## Rule zero: copy a proven layout, never invent one

**Do not design UI from imagination.** Every bad round in this project came from
guessing at a layout instead of copying one that already works.

Before laying out any new panel, card, row or shelf:

1. Find real references — the actual games and sites in this genre (Gamersberg,
   bloxfruitsvalues, Traderie for trade feeds; Pet Simulator X and similar for
   inventory slots and shop cards). Search the web and look at how they arrange
   the same information.
2. Copy the STRUCTURE — what sits where, what size relative to what, what
   information appears per element, what the hierarchy is.
3. Re-skin it in this project's style, pulling every colour from `Theme` and
   reusing `Components`. Never introduce a new palette.

The shop in this game is the standard to match: sectioned catalogue, uniform
cards, icon + name + description + price button, badge ribbons like
`BEST VALUE`. It reads well because it copies how real storefronts are built.
New UI should be recognisably the same family.

The failure mode this prevents: cards that are large, symmetrical, and empty —
technically laid out, informationally useless. If you cannot point at a
reference that arranges the information this way, you are guessing.


In this project, UI has been reported as working while it was visibly broken —
empty cards, orphaned labels, clipped frames, a paid gamepass that displayed
nothing. Every one of those passed the test suite. **Tests do not see the
screen. Only a screenshot does.**

## The rule

You may not say a UI change is done, fixed, working, or ready — and you may not
commit it as such — until you have:

1. Taken a screenshot of the UI **with real data in it**, and
2. Run the overflow scan below and had it come back clean, and
3. Looked at the screenshot and described what is actually in it.

"The build passed", "the remote returned ok", "the tests are green", and "the
layout numbers are correct" are **not** verification. A card measuring 300x130
tells you nothing about whether the card is empty.

## Empty states lie

A panel with nothing in it verifies nothing. Most defects here only appear
once the UI holds real content. **Populate it first**:

- Post real listings through the actual remotes (`PostListing`, etc.)
- Or clone the row/card template at runtime and fill its labels
- Runtime-only. Never write sample data into source.

If you screenshot an empty panel and call it verified, you have verified the
empty case and nothing else. That exact mistake shipped an unreadable Featured
strip because every screenshot taken of it happened to be empty.

## The overflow scan

Eyeballing misses clipping. Walk the tree and compare bounds:

```lua
local function scanOverflow(root: GuiObject): { string }
    local bad = {}
    for _, d in root:GetDescendants() do
        if d:IsA("GuiObject") and d.Visible then
            local p = d.Parent
            if p and p:IsA("GuiObject") then
                local dp, ds = d.AbsolutePosition, d.AbsoluteSize
                local pp, ps = p.AbsolutePosition, p.AbsoluteSize
                if dp.X < pp.X - 1 or dp.Y < pp.Y - 1
                    or dp.X + ds.X > pp.X + ps.X + 1
                    or dp.Y + ds.Y > pp.Y + ps.Y + 1 then
                    table.insert(bad, ("%s escapes %s"):format(d.Name, p.Name))
                end
            end
        end
    end
    return bad
end
```

Also flag any visible element whose `AbsoluteSize` is `0` on either axis — that
is the signature of a frame that failed to lay out, and it is what produces
"orphaned text floating over nothing".

## This is a mobile game

Verify at **three viewports**, screenshotting each: phone, tablet, desktop
(`resize_window`). Layout must be scale-based (`UDim2.fromScale`,
`UIAspectRatioConstraint`, `UISizeConstraint`, `UITextSizeConstraint`).
Offsets are for strokes, corner radii and small fixed padding only — never for
the primary layout of panels, rows, cards or slots. Touch targets must stay
comfortably tappable at phone size.

## Overlap is not escape — test for it separately

The bounds scan above catches a child leaving its parent. It does **not** catch
two siblings sitting on top of each other, which is what actually produces
clipped, half-readable text. Test sibling rectangles pairwise:

```lua
-- for each pair of visible siblings a, b
if a.x < b.x + b.w and b.x < a.x + a.w
    and a.y < b.y + b.h and b.y < a.y + a.h then
    -- OVERLAP
end
```

Real example from this project: a row's info column ran x=587..839 while its
button column ran x=724..839. Nothing escaped its parent, every test passed, and
the player saw `You're asking 77% m…` cut off mid-word behind a button. Columns
must be given non-overlapping ranges, not merely ranges that fit.

Ignore pairs that merely touch at an edge (`a.y + a.h == b.y`) — that is
stacking, not overlap.

## One screenshot of the whole screen is not enough

A full-screen capture hides small defects. After the wide shot, **zoom into each
quadrant** of the panel and look again (`screen_capture` supports a `region`).
Clipped text, a label sitting on a button, a badge half outside its chip — none
of these are legible at full-screen scale, and every one of them has shipped in
this project because the wide shot "looked fine".

## Check size in context, not in isolation

A panel that looks fine alone can be wrong on screen. Always compare it against
the viewport **and against the game's other panels**:

```lua
local cam = workspace.CurrentCamera.ViewportSize
for _, gui in playerGui:GetDescendants() do
    if gui:IsA("Frame") and gui.Name:match("Panel$") then
        print(("%s  %dx%d  = %.0f%% x %.0f%% of screen"):format(
            gui.Name, gui.AbsoluteSize.X, gui.AbsoluteSize.Y,
            gui.AbsoluteSize.X / cam.X * 100, gui.AbsoluteSize.Y / cam.Y * 100))
    end
end
```

A panel swallowing ~95% of the screen is wrong even if every child inside it is
laid out correctly. Panels in this game should feel consistent with each other —
if the board is twice the size of the shop and the inventory, the board is the
one that is wrong. Sameness across panels matters more than any single panel's
internal balance.

## Reading the screenshot honestly

Ask, and answer out loud:

- Can I tell **what** each card represents? Item name and value present, not a
  bare icon?
- Is anything floating with no container behind it?
- Is there a large dead area that content should occupy?
- Does the paid/premium element look better than the free one it outranks?
- Would a player understand this without explanation?

If the answer to any of these is bad, it is not done — say so plainly rather
than reporting success with a caveat.

## Always read the console

After every play session, call `get_console_output` and actually read it. Not
skim — read. A screenshot shows what rendered; the console shows what broke
getting there.

Things that have hidden in this project's console while the UI "looked fine":

- `StandardReadExperienceThrottled` / `DatastoreThrottled` storms — hundreds of
  retrying store reads starving every other system, including profile saves.
- `Infinite yield possible on WaitForChild(...)` — a wiring function that never
  finished, so half the panel is unwired and nothing tells you.
- Stack traces from a screen module that errored during `wire()`, leaving its
  public functions undefined.

Treat a wall of repeated errors as a defect to diagnose, never as background
noise, even when it looks unrelated to the thing you just changed — and even
when it was there before you arrived. Report it.

## The splice trap

Changes will not appear unless spliced correctly, and a stale UI looks
identical to "my edit did nothing":

1. `rojo build sync.project.json -o sync.rbxm`
2. Copy to **every** `%LOCALAPPDATA%\Roblox\Versions\*\content\`
3. In **Edit** mode, replace `Server`, `Shared`, and `Client` — putting `Client`
   into **both** StarterPlayerScripts (clone) and ReplicatedStorage. The running
   client comes from StarterPlayerScripts.
4. `GuiBuilder` is **studio-time**: destroy `StarterGui.TradingHUD` and
   `StarterGui.TradingModals`, then re-run
   `require(ReplicatedStorage.Shared.GuiBuilder).build()`.
5. Start play, populate, screenshot.

If `screen_capture` times out, stop/start play and retry. A timeout is not a
passing result and is never a reason to skip the screenshot.

**Destroy ALL matches, not the first one.** `FindFirstChild("Client")` removes
one instance. If an earlier splice left a duplicate, StarterPlayerScripts ends
up with two `Client` LocalScripts; both run, and `PlayerScripts.Client`
resolves to whichever is first. You then debug a module whose `wire()` never
ran while a second copy quietly drives the working UI — the symptoms are
"the screen works but my handle is missing functions", which reads exactly
like a game bug and is not one. Loop over `GetChildren()` and destroy every
match:

```lua
for _, c in container:GetChildren() do
    if c.Name == "Client" then c:Destroy() end
end
```

Before trusting any client-side diagnosis, count the copies first.

## Delegation does not transfer the duty

A subagent without Studio access cannot verify UI. If you dispatch UI work, the
screenshot obligation stays **yours** before the result is reported or committed.
Do not relay a subagent's confidence as verification.
