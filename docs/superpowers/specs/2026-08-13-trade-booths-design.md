# Trade Booths — Design

Date: 2026-08-13
Status: approved for planning

## Summary

A booth is a hand-placed physical storefront in the trading plaza. A player claims
one, stocks its slots, and the booth becomes the walk-up face of the sell listings
they already post. It is also a place to show off: their name, their group, their
booth skin, a line of their own text.

Booths add no new economy. Stocking a slot posts an ordinary `sell` listing through
the existing path, so the same stock appears on the booth and in the Market, at one
price, feeding the same RAP signal.

Nothing is ever held. Posting to a booth checks the player holds the goods and
leaves them in their inventory, exactly as the board does today.

## Research that shaped this

Pet Simulator 99, PLS DONATE, and Bubble Gum Simulator Infinity all converge on the
same shape, and the useful details are:

- Booths are claimed physically, first-come, with a hold-to-claim so it is
  deliberate rather than an accidental keypress.
- PS99 gives 4 listing slots by default and sells more as vouchers, purchasable
  with Robux *or* from other players.
- Booth skins are cosmetic only in every one of them. They never affect price,
  fees, or capacity.
- PS99's Trading Terminal searches every server for an item sitting in a booth and
  teleports you there. Physical booths do not scale without a search layer. Our
  Market tab already is that layer.
- PS99 shipped booths without anti-scam and patched them 13 months later: players
  now render transparent near booths, and a newly listed item cannot be bought for
  3 seconds. Both are cheap to build in from the start, so we do.

## What already exists

| Need | Existing system |
|---|---|
| Sell N copies at Y gems each, partial fills | `sell` listings in `TradeBoardService` |
| Selling while the owner is offline | `DataService.debitOffline` settlement path |
| Cross-server search over stock | Market tab / `GetMarketSummary` |
| Item stat card on hover | `Components` tooltip |
| Robux purchases | `MonetizationConfig.Offers` + `ProductService` |
| Buyable-in-Studio placeholders | `MonetizationConfig.PlaceholderProductId` |
| Group name and tag | `SyndicateService` |
| Portfolio value / trade count / rarest | `ProfileService` projection |

The booth is a surface over these. The genuinely new pieces are the claim
lifecycle, the booth face, the skin catalogue, and the per-player sell-listing cap.

## Placement contract

Booths are placed by hand in Studio. The system never spawns them.

A booth is any model tagged `TradeBooth` via CollectionService, containing:

- `Anchor` — a `BasePart` whose front face carries the SurfaceGui.
- `SkinMount` — a `BasePart` marking where a skin model attaches.
- `ClaimPrompt` — a `ProximityPrompt`.

Identity comes from a `BoothId` string attribute on the model. It must be unique
and stable; a booth whose id changes is a different booth. Booths missing a
required child, or sharing an id with another booth, are skipped and warned about
at boot rather than half-working.

Adding, moving, or removing a booth is a Studio edit. No code change.

The place's max player count is set to the number of placed booths, so a booth is
always available and no player is ever locked out.

## Claim lifecycle

- **Claim** — hold E for 1 second on an unclaimed booth. Free. One booth per player.
- **Occupied** — another player's booth shows their storefront; E opens a read-only
  browse view, not a claim.
- **Release** — on the owner leaving the server, or unclaiming from the booth UI.
  The display resets to unclaimed.

Claim state is **server-local and in-memory**. Booths are physical spots in one
server, so a booth claim has no meaning in another server and nothing about it
needs to be durable. Nothing goes in MemoryStore — its quota is experience-wide
and already tight, and booth claims are exactly the kind of high-churn,
zero-durability state that must not go there.

Releasing a booth does **not** touch listings. Stock stays live in the Market and
keeps selling while the owner is offline. The booth is the storefront; the listing
is the thing being sold.

## Booth stock

A booth slot holds one `sell` listing: N copies of one item at Y gems each.

Stocking a slot calls the existing `PostListing` path with `kind = "sell"`. Nothing
about matching, partial fills, tax, RAP, or settlement changes. Clearing a slot
cancels the listing through the existing cancel path.

A player's booth shows their own live `sell` listings, whether posted at the booth
or from the Market tab. The two are the same set.

### Slot cap

Sell listings are currently uncapped per player. Booth slots introduce a cap:

```
slots = BoothConfig.BaseSlots + profile.Booth.extraSlots
```

`BaseSlots` is 5. The cap applies to **`sell` listings only** — swaps and buy
orders stay uncapped, because they are not what a booth displays.

Enforced server-side in `PostListing`, counting the player's open `sell` listings
before accepting a new one. The client greys out full grids, but the server is the
authority.

Players who already hold more sell listings than their cap keep them. The cap
blocks new posts; it never cancels existing ones.

## Booth face

A SurfaceGui on `Anchor`.

**Header** — display name, group tag, and the owner's tagline. The tagline is
player-typed, capped at 60 characters, and filtered per reader through
`TextService:FilterStringAsync` + `GetChatForUserAsync`, the same as group chat.
An empty filter result renders as empty, never as the raw string.

**Flex strip** — portfolio value, trades completed, rarest item held. Reuses the
`ProfileService` projection and honours the existing `Privacy.hideValue` and
`Privacy.hideShowcase` flags. A player hiding their value on their profile hides
it on their booth.

**Grid** — 5 columns × 2 rows visible, scrollable vertically for more.

- *Filled slot* — item icon, name, price each, remaining count. Hover gives the
  standard stat card.
- *Empty owned slot* — dashed outline, click to stock.
- *Next purchasable slot* — a white square with a `+`, click prompts the Robux
  purchase.
- *Beyond that* — not drawn.

With `BaseSlots = 5`, a new player sees one full row and the `+` at the start of
row two.

**Unclaimed booth** — a "Claim this booth" plate and nothing else.

## Monetization

Both go in `MonetizationConfig.Offers` against `PlaceholderProductId`, so they are
fully buyable in Studio immediately and become real by swapping one id each.

**Skins** — cosmetic only. They never touch price, tax, slot count, or listing
visibility. A `BoothConfig.Skins` table maps `skinId` to a display name and a model
in `ReplicatedStorage`. The placeholder set is built from primitives to match the
existing world; the models are swapped later without touching the code that mounts
them.

**Slots** — one dev product granting +1 slot, repeatable. Stored on the profile,
so it survives and rides along when products become tradeable later.

## Profile

New `Booth` table:

```lua
Booth = {
  skinId = "default",
  extraSlots = 0,
  tagline = "",
}
```

`SCHEMA_VERSION` bumps, with the same `data.X = data.X or default` migration shape
the existing fields use.

## Anti-scam

- **Transparency near booths** — players within a few studs of a booth render
  semi-transparent to everyone, so nobody can body-block a display. Client-side
  presentation only.
- **No purchase cooldown**, deliberately. PS99 added one because a booth slot
  there is a mutable display: the seller can swap what's on the shelf between a
  buyer reading it and clicking. Here the listing id IS the offer — price and
  item are immutable once posted, and a seller who changes their mind can only
  cancel, which makes the buy fail with `gone` and charges nothing. A delay would
  defend against nothing and would punish honest buyers.

## Failure handling

- Booth model missing a required child, or a duplicate `BoothId` — skipped, warned
  at boot. Other booths work.
- Stocking a slot when the player no longer holds the item — the existing
  `PostListing` check rejects it; the slot stays empty and the UI says why.
- Stocking a slot at the cap — server rejects with `slot_cap`; the UI points at the
  `+` slot.
- Owner leaves mid-purchase — irrelevant. Listings settle against an offline poster
  through the existing path.
- Player disconnects holding a claim — `PlayerRemoving` releases it. A booth whose
  claimant is no longer in the server is released on the next sweep as a backstop.
- Filter failure on a tagline — renders empty, never raw.
- SurfaceGui refresh — booths update on listing change events, not per frame.

## Testing

Pure-logic tests in the existing runner:

- Claim: unclaimed → claimed; second claimant rejected; release returns it to
  unclaimed; one booth per player.
- Slot cap: `BaseSlots + extraSlots`; posting at the cap rejected; cancelling frees
  a slot; over-cap players keep existing listings.
- Cap applies to `sell` only — swaps and buy orders unaffected.
- Skins: unowned skin cannot be equipped; skins never alter price or slot count.
- List cooldown: purchase inside 3 seconds rejected, outside allowed.

Placement discovery, the SurfaceGui grid, the `+` slot, and skin mounting are
verified by screenshot in Studio.

## Out of scope

- Auction board.
- Booth-only stock that never reaches the Market.
- Cross-server booth search — the Market tab already does this, and there is no
  teleport-to-server flow because there is one plaza.
- Trading slot vouchers between players — arrives on its own when products become
  tradeable; nothing here blocks it.
- Renaming Syndicate to Group — tracked separately.
