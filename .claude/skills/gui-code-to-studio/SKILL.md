---
name: gui-code-to-studio
description: Use whenever GuiBuilder.luau (or any StarterGui-authored UI) is edited in source — mirrors the change live into the running Studio instance instead of leaving it as code-only. Trigger on any new/moved/restyled GUI node, tab, button, or panel.
---

# GUI: code edit -> live Studio splice

This project builds UI once via `GuiBuilder.build()` into `StarterGui`, then edits happen
by hand in Studio. Source edits to `GuiBuilder.luau` do **NOT** auto-appear live — Studio's
StarterGui is a separate, already-baked tree. Every GUI source edit needs a matching live
edit, or the user can't see/test it and will call it out.

## Rule

Never report a GUI change "done" after only editing `.luau` source. Always follow with a
live `execute_luau` (`datamodel_type: "Edit"`) splice that produces the same structure in
`StarterGui`, then verify.

## Before touching live Studio

1. `list_roblox_studios` -> get `studio_id`.
2. `get_studio_state` -> confirm mode is `Edit` (not `Play`) unless told otherwise.
3. **Dump current ground truth first.** Never trust a prior session's notes/summary for
   live positions — the user hand-edits Studio between sessions constantly. Pull real
   `Position`/`Size`/`Name` via `execute_luau` or `inspect_instance` before writing new
   splice code that positions anything "relative to" an existing node.
4. **Never call `GuiBuilder.build()`** if the user has manually rearranged the live HUD —
   it destroys and rebuilds `TradingHUD`/`TradingModals`/`TradingHUDTop` wholesale, wiping
   any hand-placed nodes (extra buttons, moved icons, renamed labels). Confirm this only
   after checking — `search_game_tree` on `StarterGui` with depth 2 shows whether the live
   tree already has extra/renamed nodes beyond what source describes.

## Splicing a new node (button, panel, tab, label, etc.)

Do it with `Instance.new(...)` calls inline in `execute_luau`, not by requiring the
module and calling its builder function — the module's own require cache is separate
from the live server VM in this environment, and builder helpers like
`GuiBuilder.ensureHudNode` bake once and no-op on re-run (see "Editing an existing baked
node" below). Write the raw instance-construction code directly against the live tree so
it's guaranteed to take effect immediately, then keep it in sync with what `GuiBuilder.luau`
now describes in source.

Checklist per new node:
- `Name` must exactly match what wiring code (`WaitForChild("ThatName")`) expects.
- Reuse real values from `ICONS`/`C` tables in `GuiBuilder.luau` source — **grep for the
  icon/color first**, never invent a placeholder `rbxassetid://` number. A guessed asset id
  renders as a blank/invisible image and reads to the user as "the button doesn't exist."
- `AnchorPoint`, `Position`, `Size` should match the sibling nodes' convention (check one
  via `inspect_instance` first) — most icon buttons here use `AnchorPoint = (0.5, 0.5)`.
- Parent to the exact ScreenGui the source now targets (`TradingHUD` vs `TradingModals` vs
  `TradingHUDTop` — the last is the `IgnoreGuiInset = true` overlay; check which one source
  builds into before parenting).

## Editing an existing baked node

`ensureHudNode`/`ensurePanel` (and similar `FindFirstChild`-guarded builders) **no-op** if
the node already exists in `StarterGui` — re-running the builder after a source edit does
nothing live. To make a source edit to an existing node's geometry/style show up:
1. Either mutate the live instance's properties directly and individually
   (`node.Position = UDim2.fromScale(...)`), matching the new source values exactly, or
2. `node:Destroy()` then re-run the `ensure...` call so it rebuilds fresh from the
   now-current source — only safe if nothing else references that exact instance and no
   unrelated manual edits live on it that would be lost.

## Verify before claiming done

- `inspect_instance` on every new/changed node — confirm `Position`, `Size`, `Visible`,
  `Image`/`Text` actually match intent. An `Instance.new("ImageButton")` with a bad asset
  id LOOKS fine in the property dump (`Image` field is just a string) — it will not look
  fine on screen. Don't skip the screenshot check for anything image-based.
- `screen_capture` (needs `capture_id` param) for a visual check when the change is
  visible in the Edit-mode viewport.
- For pixel-overlap/clipping claims, don't eyeball a screenshot — compute real
  `AbsolutePosition`/`AbsoluteSize` bounding boxes for the actual children involved, not
  just a container's own frame (a container can look fine while its children overflow it).

## Common mistake this skill exists to prevent

Treating "I edited `GuiBuilder.luau`" as equivalent to "the user can now see and click
this." They are not the same action in this project. Every GUI task ends with a live
Studio splice + verification step, not a source diff.
