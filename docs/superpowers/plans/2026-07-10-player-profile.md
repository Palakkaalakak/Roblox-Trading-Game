# Player Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Blox-Fruits-style Player Profile — a curated public face (identity, ≤6-item showcase, aggregate portfolio value, ≤4 stat chips, free-text status) viewable for online AND offline players, with per-player privacy toggles, opened via a HUD button (self) or a Server/Global player browser (others).

**Architecture:** Each player's home server writes a lock-free public snapshot (`PublicProfile_v1` DataStore, keyed userId) holding only public data; any viewer reads it with a plain `GetAsync`. Hidden sections are omitted at write time, so private data never enters the public key. A pure projection module turns a private profile + an economy resolver into the public snapshot; `ProfileService` wraps it with the store, debounced writes, and remotes. Two new lifetime counters (`gemsEarned`, `trades`) are incremented at the existing `InventoryService.applyDelta` chokepoint.

**Tech Stack:** Roblox Luau, Rojo, MemoryStore/DataStore via `StoreAdapters`, custom `Net` remote layer, custom assert-based `TestRunner`, `GuiBuilder` (single-source UI construction).

## Global Constraints

- Full inventory must NEVER leave the server. Only showcase + aggregate total are public.
- Privacy is enforced by OMISSION AT WRITE TIME — the client never filters private data; hidden sections are physically absent from the snapshot (not nulled).
- Status text MUST pass `TextService:FilterStringAsync` before storage (Roblox ToS for user text shown to others). Length-capped at 60 chars pre-filter.
- Scarcity = **circulating** supply, ascending (fewest in existence first). Circulating for an item = `EconomyService.snapshot(itemId).supply.value`.
- Showcase ≤6 items; stat chips ≤4. Both `Set*` remotes validate these caps server-side.
- Portfolio value = sum of item Est. Values only. Gems are never folded in (they are a separate `gems` chip).
- All new remotes are rate-limited via `TradeConfig.RateLimits` token buckets.
- New persisted fields go through the existing `DataService` schema migration pattern (v1 → v2). Never mutate existing fields' meaning.
- UI is built once in `GuiBuilder`; runtime client scripts only `WaitForChild` named nodes and wire events — never rebuild/restyle (project rule).
- Tests are ModuleScripts under `src/server/Tests/` returning `{ name, tests = { [desc] = fn } }`; `TestRunner.run()` auto-discovers them. Run tests in Studio (Edit mode) via `require(TestRunner).run()`.

---

## File Structure

**Create:**
- `src/shared/Util/ProfileProjection.luau` — pure: private profile + economy resolver → public snapshot. All privacy/showcase/chip logic. Unit-tested.
- `src/server/Services/ProfileService.luau` — snapshot store read/write, debounced writes, `GetProfile` + `Set*` remotes, status filtering.
- `src/server/Tests/ProfileTests.luau` — unit suite for `ProfileProjection`.
- `src/client/Controllers/ProfileController.luau` — client mirror: fetch/cache viewed profile, own-profile edit state, `Set*` calls.
- `src/client/UI/ProfileScreen.luau` — runtime wiring for the `ProfilePanel` + player browser (Server/Global tabs).

**Modify:**
- `src/shared/Types.luau` — extend `Profile` type (v2 fields) + add `PublicProfile` / `ItemView` types.
- `src/shared/Enums.luau` — add remote names: `GetProfile`, `SetShowcase`, `SetStatus`, `SetStatChips`, `SetPrivacy`.
- `src/shared/Config/TradeConfig.luau` — add rate-limit buckets for the 5 new remotes.
- `src/server/Services/DataService.luau` — template defaults for v2 fields + `migrations[1]`; increment `trades` on mailbox claim of a trade entry.
- `src/server/Services/InventoryService.luau` — increment `gemsEarned` + `trades` in `applyDelta` keyed on `source`.
- `src/server/init.server.luau` — register `ProfileService` (Init + Start).
- `src/shared/GuiBuilder.luau` — build `ProfilePanel` + Server/Global browser + HUD "Profile" button.
- `src/client/init.client.luau` — start `ProfileController` + `ProfileScreen`.

---

## Task 1: Schema v2 — private profile fields + migration

**Files:**
- Modify: `src/shared/Types.luau:89-98`
- Modify: `src/server/Services/DataService.luau:34-56`

**Interfaces:**
- Produces: `Profile.Showcase: {string}`, `Profile.StatChips: {string}`, `Profile.Status: string`, `Profile.Privacy: { hideValue: boolean, hideShowcase: boolean }`, `Profile.Lifetime: { gemsEarned: number, trades: number }`. `SCHEMA_VERSION == 2`.

- [ ] **Step 1: Extend the `Profile` type.** In `src/shared/Types.luau`, replace the `Profile` export body with:

```lua
export type Profile = {
	SchemaVersion: number,
	Gems: number,
	Inventory: { [string]: number },
	StarterGranted: boolean,
	StarterGrantId: string,
	ClaimedIds: { [string]: boolean },
	Meta: { firstJoin: number, lastLogin: number, joins: number },
	-- v2: player profile (public-facing, opt-out privacy)
	Showcase: { string }, -- <=6 itemIds, player-ordered; {} => default scarcest-6
	StatChips: { string }, -- <=4 stat keys; {} => default set
	Status: string, -- filtered "looking for" text
	Privacy: { hideValue: boolean, hideShowcase: boolean },
	Lifetime: { gemsEarned: number, trades: number },
}
```

- [ ] **Step 2: Bump `SCHEMA_VERSION` + template defaults.** In `src/server/Services/DataService.luau`, find `local SCHEMA_VERSION = 1` and set it to `2`. In the `template` table (currently ends around line 44 with `Meta = {...}`), add the v2 fields:

```lua
	Showcase = {},
	StatChips = {},
	Status = "",
	Privacy = { hideValue = false, hideShowcase = false },
	Lifetime = { gemsEarned = 0, trades = 0 },
```

- [ ] **Step 3: Add the v1→v2 migration.** In the `migrations` table (around line 49), add:

```lua
	[1] = function(data)
		data.Showcase = data.Showcase or {}
		data.StatChips = data.StatChips or {}
		data.Status = data.Status or ""
		data.Privacy = data.Privacy or { hideValue = false, hideShowcase = false }
		data.Lifetime = data.Lifetime or { gemsEarned = 0, trades = 0 }
		data.SchemaVersion = 2
		return data
	end,
```

- [ ] **Step 4: Sync to Studio + smoke-check.** Build and load (see the "Studio sync" appendix at the end). In Studio Edit mode run:

```lua
local T = require(game.ReplicatedStorage.Shared.Types) -- just confirms it compiles
print("Types compile OK")
```

Expected: `Types compile OK` (no red compile error in Output).

- [ ] **Step 5: Commit.**

```bash
git add src/shared/Types.luau src/server/Services/DataService.luau
git commit -m "feat(profile): schema v2 fields + v1->v2 migration"
```

---

## Task 2: Lifetime counters at the inventory chokepoint

**Files:**
- Modify: `src/server/Services/InventoryService.luau:47-84`
- Modify: `src/server/Services/DataService.luau` (mailbox claim — trades on offline delivery)
- Test: `src/server/Tests/ProfileTests.luau` (create; the earned-source helper test)

**Interfaces:**
- Consumes: `Profile.Lifetime` (Task 1), `Enums.GrantSource` (existing: `Trade = "trade"`, `Board = "board"`, `Refund`, `Debug`/`"debug"`, `Starter`).
- Produces: `ProfileProjection.isEarnedSource(source: string): boolean` (pure helper, shared so both the counter hook and tests use one definition).

- [ ] **Step 1: Write the failing test for the earned-source rule.** Create `src/server/Tests/ProfileTests.luau`:

```lua
--!strict
-- Unit tests: ProfileProjection pure logic.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PP = require(ReplicatedStorage.Shared.Util.ProfileProjection)

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

return {
	name = "Profile",
	tests = {
		["earned source: trade + board count, debug/refund/starter do not"] = function()
			eq(PP.isEarnedSource("trade"), true, "trade")
			eq(PP.isEarnedSource("board"), true, "board")
			eq(PP.isEarnedSource("debug"), false, "debug")
			eq(PP.isEarnedSource("refund"), false, "refund")
			eq(PP.isEarnedSource("starter"), false, "starter")
		end,
	},
}
```

- [ ] **Step 2: Run it — expect failure.** In Studio Edit run `print(require(game.ServerScriptService.Server.Tests.TestRunner).run())`. Expected: `FAIL Profile / earned source... — ...ProfileProjection is not a valid member` (module doesn't exist yet).

- [ ] **Step 3: Create `ProfileProjection` with the helper.** Create `src/shared/Util/ProfileProjection.luau`:

```lua
--!strict
-- Pure projection: private profile + an economy resolver -> the public
-- snapshot. No services, no yielding, no DataStore — unit-testable.
local ProfileProjection = {}

local EARNED = { trade = true, board = true }

-- Gem inflows that count toward Lifetime.gemsEarned. Refund = your own gems
-- back; debug = fake faucet; starter = grant. Only real trading counts.
function ProfileProjection.isEarnedSource(source: string): boolean
	return EARNED[source] == true
end

return ProfileProjection
```

- [ ] **Step 4: Run it — expect pass.** Re-run the TestRunner line. Expected: `PASS Profile / earned source...` in the output, `0 failed`.

- [ ] **Step 5: Hook the counters into `applyDelta`.** In `src/server/Services/InventoryService.luau`, add the require near the top (with the other requires):

```lua
local ProfileProjection = require(ReplicatedStorage.Shared.Util.ProfileProjection)
```

Then in `applyDelta`, immediately AFTER the `if idempotencyKey then profile.ClaimedIds[idempotencyKey] = true end` block (line ~73) and BEFORE the `AnalyticsService.log(...)` call, insert:

```lua
	-- Lifetime counters (idempotent: we only reach here on first application
	-- of a claimId'd delta; the early-return above no-ops repeats).
	if delta.gems and delta.gems > 0 and ProfileProjection.isEarnedSource(source) then
		profile.Lifetime.gemsEarned += delta.gems
	end
	if source == "trade" and idempotencyKey ~= nil then
		profile.Lifetime.trades += 1
	end
```

Note: online trade credit AND offline mailbox claim both flow through `applyDelta` with `source == "trade"` and a `claimId`, so this single hook covers both. Board settlements use `source == "board"` and are NOT counted as P2P trades (only `gemsEarned`).

- [ ] **Step 6: Guard mailbox-claim path is covered (no code if already through applyDelta).** Open `src/server/Services/DataService.luau` `mailboxClaim` (line ~95). Confirm each mailbox entry is applied via `InventoryService.applyDelta(player, {items=..., gems=...}, entry.source, entry.claimId)`. If it applies deltas through `applyDelta` with the entry's `source` and `claimId`, NO extra code is needed — Step 5 already counts it. If (and only if) it writes `profile.Inventory`/`profile.Gems` directly instead, add after a successful trade-entry apply:

```lua
		if entry.source == "trade" then
			profile.Lifetime.trades += 1
		end
```

(Read the function first; prefer the `applyDelta` path. Do not double-count — pick exactly one site.)

- [ ] **Step 7: Commit.**

```bash
git add src/shared/Util/ProfileProjection.luau src/server/Tests/ProfileTests.luau src/server/Services/InventoryService.luau src/server/Services/DataService.luau
git commit -m "feat(profile): lifetime gemsEarned + trades counters at inventory chokepoint"
```

---

## Task 3: Pure projection — showcase, portfolio value, chips, privacy

**Files:**
- Modify: `src/shared/Util/ProfileProjection.luau`
- Modify: `src/shared/Types.luau` (add `ItemView`, `PublicProfile`)
- Test: `src/server/Tests/ProfileTests.luau`

**Interfaces:**
- Consumes: nothing external (pure). Callers inject a resolver.
- Produces:
  - `type ItemView = { itemId: string, name: string, rarity: string, imageId: string, estValue: number, circulating: number }`
  - `type Resolver = (itemId: string) -> ItemView?`
  - `ProfileProjection.defaultShowcase(inv: {[string]:number}, resolve: Resolver, limit: number): {string}`
  - `ProfileProjection.resolveShowcase(ids: {string}, inv: {[string]:number}, resolve: Resolver): { ItemView }`
  - `ProfileProjection.portfolioValue(inv: {[string]:number}, resolve: Resolver): number`
  - `ProfileProjection.resolveChip(key: string, ctx): { key: string, label: string, value: number }?`
  - `ProfileProjection.project(args): PublicProfile`

- [ ] **Step 1: Add the public types.** In `src/shared/Types.luau`, before `return nil`, add:

```lua
export type ItemView = {
	itemId: string,
	name: string,
	rarity: string,
	imageId: string,
	estValue: number,
	circulating: number,
}

export type PublicProfile = {
	userId: number,
	name: string,
	displayName: string,
	firstJoin: number,
	portfolioValue: number?, -- absent if hidden
	showcase: { ItemView }?, -- absent if hidden
	statChips: { { key: string, label: string, value: number } },
	status: string,
	updatedAt: number,
}
```

- [ ] **Step 2: Write failing tests for showcase + portfolio + chips + privacy.** Append these to the `tests` table in `src/server/Tests/ProfileTests.luau`:

```lua
		["defaultShowcase: scarcest-first (ascending circulating), capped"] = function()
			local resolve = function(id)
				local circ = ({ a = 50, b = 10, c = 30, d = 5 })[id]
				if not circ then return nil end
				return { itemId = id, name = id, rarity = "Common", imageId = "", estValue = 1, circulating = circ }
			end
			local inv = { a = 1, b = 2, c = 1, d = 9 }
			local sc = PP.defaultShowcase(inv, resolve, 3)
			eq(#sc, 3, "cap")
			eq(sc[1], "d", "5 circ scarcest")
			eq(sc[2], "b", "10 circ next")
			eq(sc[3], "c", "30 circ third")
		end,

		["resolveShowcase: drops items no longer owned or unresolvable"] = function()
			local resolve = function(id)
				if id == "gone" then return nil end
				return { itemId = id, name = id, rarity = "Common", imageId = "", estValue = 2, circulating = 1 }
			end
			local inv = { keep = 1, sold = 0 } -- sold has count 0 (== not owned)
			local out = PP.resolveShowcase({ "keep", "sold", "gone" }, inv, resolve)
			eq(#out, 1, "only keep survives")
			eq(out[1].itemId, "keep")
		end,

		["portfolioValue: sum of estValue * count over owned"] = function()
			local resolve = function(id)
				return { itemId = id, name = id, rarity = "Common", imageId = "", estValue = ({ x = 10, y = 3 })[id] or 0, circulating = 1 }
			end
			eq(PP.portfolioValue({ x = 2, y = 4 }, resolve), 10 * 2 + 3 * 4)
		end,

		["resolveChip: mythicals counts only mythical-rarity owned"] = function()
			local resolve = function(id)
				return { itemId = id, name = id, rarity = (id == "m") and "Mythical" or "Common", imageId = "", estValue = 1, circulating = 1 }
			end
			local ctx = { inventory = { m = 3, c = 1 }, resolve = resolve, gems = 0, lifetime = { gemsEarned = 0, trades = 0 }, firstJoin = 0, now = 0 }
			local chip = PP.resolveChip("mythicals", ctx)
			eq(chip and chip.value, 1, "one distinct mythical")
		end,

		["project: hideValue drops aggregate AND portfolioValue chip"] = function()
			local resolve = function(id)
				return { itemId = id, name = id, rarity = "Common", imageId = "", estValue = 5, circulating = 1 }
			end
			local pub = PP.project({
				userId = 1, name = "n", displayName = "d", firstJoin = 0, now = 100,
				inventory = { a = 1 }, gems = 7,
				showcase = {}, statChips = { "portfolioValue", "gems" }, status = "hi",
				privacy = { hideValue = true, hideShowcase = false },
				lifetime = { gemsEarned = 0, trades = 0 }, resolve = resolve,
			})
			eq(pub.portfolioValue, nil, "aggregate hidden")
			local hasPv = false
			for _, c in pub.statChips do if c.key == "portfolioValue" then hasPv = true end end
			eq(hasPv, false, "portfolioValue chip dropped")
			eq(pub.showcase ~= nil, true, "showcase still present")
		end,

		["project: hideShowcase omits showcase, keeps value"] = function()
			local resolve = function(id)
				return { itemId = id, name = id, rarity = "Common", imageId = "", estValue = 5, circulating = 1 }
			end
			local pub = PP.project({
				userId = 1, name = "n", displayName = "d", firstJoin = 0, now = 100,
				inventory = { a = 1 }, gems = 0,
				showcase = {}, statChips = {}, status = "",
				privacy = { hideValue = false, hideShowcase = true },
				lifetime = { gemsEarned = 0, trades = 0 }, resolve = resolve,
			})
			eq(pub.showcase, nil, "showcase omitted")
			eq(pub.portfolioValue, 5, "value present")
		end,
```

- [ ] **Step 3: Run — expect failures.** Run the TestRunner line. Expected: multiple `FAIL Profile / ...` (`defaultShowcase is not a valid member` etc.).

- [ ] **Step 4: Implement the projection.** Replace the body of `src/shared/Util/ProfileProjection.luau` (keep the header + `isEarnedSource`) with the full module:

```lua
--!strict
-- Pure projection: private profile + an economy resolver -> the public
-- snapshot. No services, no yielding, no DataStore — unit-testable.
local ProfileProjection = {}

export type ItemView = {
	itemId: string, name: string, rarity: string, imageId: string,
	estValue: number, circulating: number,
}
type Resolver = (itemId: string) -> ItemView?

local EARNED = { trade = true, board = true }
function ProfileProjection.isEarnedSource(source: string): boolean
	return EARNED[source] == true
end

local SHOWCASE_MAX = 6
local CHIP_MAX = 4
local DEFAULT_CHIPS = { "portfolioValue", "trades", "mythicals", "accountAge" }

local CHIP_LABELS = {
	portfolioValue = "Portfolio Value",
	trades = "Trades",
	gemsEarned = "Gems Earned",
	mythicals = "Mythicals Owned",
	accountAge = "Account Age",
	distinctItems = "Distinct Items",
	gems = "Gems",
}

-- owned (count>=1) + resolvable itemIds, ascending circulating; ties by itemId
-- (determinism). Returns up to `limit` ids.
function ProfileProjection.defaultShowcase(inv: { [string]: number }, resolve: Resolver, limit: number): { string }
	local owned: { ItemView } = {}
	for itemId, count in inv do
		if count >= 1 then
			local v = resolve(itemId)
			if v then
				table.insert(owned, v)
			end
		end
	end
	table.sort(owned, function(a, b)
		if a.circulating ~= b.circulating then
			return a.circulating < b.circulating
		end
		return a.itemId < b.itemId
	end)
	local out: { string } = {}
	for i = 1, math.min(limit, #owned) do
		out[i] = owned[i].itemId
	end
	return out
end

-- filter to still-owned + resolvable, preserve order, map to ItemView.
function ProfileProjection.resolveShowcase(ids: { string }, inv: { [string]: number }, resolve: Resolver): { ItemView }
	local out: { ItemView } = {}
	for _, itemId in ids do
		if (inv[itemId] or 0) >= 1 then
			local v = resolve(itemId)
			if v then
				table.insert(out, v)
			end
		end
	end
	return out
end

function ProfileProjection.portfolioValue(inv: { [string]: number }, resolve: Resolver): number
	local total = 0
	for itemId, count in inv do
		if count >= 1 then
			local v = resolve(itemId)
			if v then
				total += v.estValue * count
			end
		end
	end
	return math.floor(total + 0.5)
end

function ProfileProjection.resolveChip(key: string, ctx: any): { key: string, label: string, value: number }?
	local label = CHIP_LABELS[key]
	if label == nil then
		return nil
	end
	local value: number
	if key == "portfolioValue" then
		value = ProfileProjection.portfolioValue(ctx.inventory, ctx.resolve)
	elseif key == "trades" then
		value = ctx.lifetime.trades
	elseif key == "gemsEarned" then
		value = ctx.lifetime.gemsEarned
	elseif key == "gems" then
		value = ctx.gems
	elseif key == "accountAge" then
		value = math.max(0, ctx.now - ctx.firstJoin)
	elseif key == "distinctItems" then
		local n = 0
		for _, c in ctx.inventory do
			if c >= 1 then n += 1 end
		end
		value = n
	elseif key == "mythicals" then
		local n = 0
		for itemId, c in ctx.inventory do
			if c >= 1 then
				local v = ctx.resolve(itemId)
				if v and v.rarity == "Mythical" then n += 1 end
			end
		end
		value = n
	else
		return nil
	end
	return { key = key, label = label, value = value }
end

function ProfileProjection.project(args: any): any
	local privacy = args.privacy or { hideValue = false, hideShowcase = false }
	local ctx = {
		inventory = args.inventory, resolve = args.resolve, gems = args.gems,
		lifetime = args.lifetime, firstJoin = args.firstJoin, now = args.now,
	}

	-- showcase
	local showcase: { ItemView }? = nil
	if not privacy.hideShowcase then
		local ids = args.showcase
		if ids == nil or #ids == 0 then
			ids = ProfileProjection.defaultShowcase(args.inventory, args.resolve, SHOWCASE_MAX)
		end
		showcase = ProfileProjection.resolveShowcase(ids, args.inventory, args.resolve)
	end

	-- portfolio value
	local portfolioValue: number? = nil
	if not privacy.hideValue then
		portfolioValue = ProfileProjection.portfolioValue(args.inventory, args.resolve)
	end

	-- chips (default set if unpinned; drop portfolioValue chip when value hidden; cap)
	local keys = args.statChips
	if keys == nil or #keys == 0 then
		keys = DEFAULT_CHIPS
	end
	local chips = {}
	for _, key in keys do
		if #chips >= CHIP_MAX then break end
		if not (key == "portfolioValue" and privacy.hideValue) then
			local chip = ProfileProjection.resolveChip(key, ctx)
			if chip then
				table.insert(chips, chip)
			end
		end
	end

	return {
		userId = args.userId, name = args.name, displayName = args.displayName,
		firstJoin = args.firstJoin,
		portfolioValue = portfolioValue,
		showcase = showcase,
		statChips = chips,
		status = args.status or "",
		updatedAt = args.now,
	}
end

return ProfileProjection
```

- [ ] **Step 5: Run — expect pass.** Run the TestRunner line. Expected: all `Profile / ...` lines `PASS`, `0 failed`.

- [ ] **Step 6: Commit.**

```bash
git add src/shared/Util/ProfileProjection.luau src/shared/Types.luau src/server/Tests/ProfileTests.luau
git commit -m "feat(profile): pure public-snapshot projection (showcase/value/chips/privacy)"
```

---

## Task 4: ProfileService — snapshot store, remotes, debounced writes

**Files:**
- Create: `src/server/Services/ProfileService.luau`
- Modify: `src/shared/Enums.luau` (remote names)
- Modify: `src/shared/Config/TradeConfig.luau` (rate limits)
- Modify: `src/server/init.server.luau` (register service)

**Interfaces:**
- Consumes: `ProfileProjection.project` (Task 3), `EconomyService.snapshot` (`{ name, rarity, imageId, supply = {value=circulating}, value = {value=estValue} }`), `DataService.getProfile`, `DataService.ProfileLoaded`/`ProfileReleased` signals, `DataService.searchPlayers`, `InventoryService` `InventoryChanged` cadence, `StoreAdapters.dataStore`, `RateLimitService.check`, `Net.bindFunction`/`fireClient`.
- Produces remotes: `GetProfile(userId) -> { ok, profile: PublicProfile? }`, `SetShowcase(itemIds) -> {ok,err}`, `SetStatus(text) -> {ok,err}`, `SetStatChips(keys) -> {ok,err}`, `SetPrivacy({hideValue,hideShowcase}) -> {ok,err}`.

- [ ] **Step 1: Add remote names.** In `src/shared/Enums.luau`, in the remote-names list (the array containing `"SearchPlayers"`, `"DebugGiveGems"`, etc.), add:

```lua
		"GetProfile", -- (userId) -> {ok, profile}
		"SetShowcase", -- (itemIds) -> {ok, err}
		"SetStatus", -- (text) -> {ok, err}
		"SetStatChips", -- (keys) -> {ok, err}
		"SetPrivacy", -- ({hideValue, hideShowcase}) -> {ok, err}
```

- [ ] **Step 2: Add rate-limit buckets.** In `src/shared/Config/TradeConfig.luau`, inside `RateLimits`, add:

```lua
		GetProfile = { 60, 20 },
		SetShowcase = { 12, 6 },
		SetStatus = { 12, 6 },
		SetStatChips = { 12, 6 },
		SetPrivacy = { 12, 6 },
```

- [ ] **Step 3: Create `ProfileService`.** Create `src/server/Services/ProfileService.luau`:

```lua
--!strict
-- ProfileService: writes each player's lock-free PUBLIC snapshot and serves
-- profile reads for anyone (online or offline). The snapshot holds only public
-- data; privacy toggles are applied at WRITE time so private data never enters
-- the public key. Reads are plain GetAsync + a short cache.
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimitService = require(script.Parent.RateLimitService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local StoreAdapters = require(script.Parent.Parent.Stores.StoreAdapters)
local ProfileProjection = require(ReplicatedStorage.Shared.Util.ProfileProjection)

local STATUS_MAX = 60
local READ_CACHE_TTL = 30 -- seconds
local WRITE_DEBOUNCE = 4 -- seconds after an inventory/gems change

local ProfileService = {}
local publicStore -- DataStore "PublicProfile_v1"
local readCache: { [number]: { at: number, profile: any } } = {}
local dirty: { [number]: boolean } = {} -- userIds pending a debounced write

-- Build an ItemView resolver from live economy state.
local function resolver(itemId: string)
	local snap = EconomyService.snapshot(itemId)
	if snap == nil then
		return nil
	end
	return {
		itemId = itemId,
		name = snap.name,
		rarity = snap.rarity,
		imageId = snap.imageId,
		estValue = (snap.value and snap.value.value) or 0,
		circulating = (snap.supply and snap.supply.value) or 0,
	}
end

-- Project a loaded player's private profile into the public snapshot.
local function build(player: Player): any?
	local profile = DataService.getProfile(player)
	if profile == nil then
		return nil
	end
	return ProfileProjection.project({
		userId = player.UserId,
		name = player.Name,
		displayName = player.DisplayName,
		firstJoin = profile.Meta.firstJoin,
		now = os.time(),
		inventory = profile.Inventory,
		gems = profile.Gems,
		showcase = profile.Showcase,
		statChips = profile.StatChips,
		status = profile.Status,
		privacy = profile.Privacy,
		lifetime = profile.Lifetime,
		resolve = resolver,
	})
end

-- Write a player's snapshot now (own key only — lock-free, single-writer).
local function writeNow(player: Player)
	local snap = build(player)
	if snap == nil then
		return
	end
	local userId = player.UserId
	readCache[userId] = { at = os.clock(), profile = snap } -- self-consistency
	task.spawn(function()
		pcall(function()
			publicStore:SetAsync(tostring(userId), snap)
		end)
	end)
end

-- Mark dirty; a single debounced writer coalesces bursts (trades mutate the
-- inventory rapidly — never write per mutation).
function ProfileService.markDirty(player: Player)
	local userId = player.UserId
	if dirty[userId] then
		return
	end
	dirty[userId] = true
	task.delay(WRITE_DEBOUNCE, function()
		dirty[userId] = nil
		local p = Players:GetPlayerByUserId(userId)
		if p and DataService.isLoaded(p) then
			writeNow(p)
		end
	end)
end

-- Read anyone's public snapshot (online or offline). Cached briefly.
local function readProfile(userId: number): any?
	-- online + on this server: freshest is the live self-consistent cache/build
	local p = Players:GetPlayerByUserId(userId)
	if p and DataService.isLoaded(p) then
		local snap = build(p)
		if snap then
			return snap
		end
	end
	local cached = readCache[userId]
	if cached and os.clock() - cached.at < READ_CACHE_TTL then
		return cached.profile
	end
	local ok, data = pcall(function()
		return publicStore:GetAsync(tostring(userId))
	end)
	if ok and data then
		readCache[userId] = { at = os.clock(), profile = data }
		return data
	end
	return nil
end

function ProfileService.Init()
	publicStore = StoreAdapters.dataStore("PublicProfile_v1")
end

function ProfileService.Start()
	-- initial write on load; final write on release
	DataService.ProfileLoaded:Connect(function(player)
		writeNow(player)
	end)
	DataService.ProfileReleased:Connect(function(player)
		writeNow(player) -- final flush of the freshest state
	end)
	-- inventory/gems changes -> debounced rewrite
	Net.onServer and nil -- (no-op; see InventoryChanged hook note below)

	Net.bindFunction("GetProfile", function(player, userId)
		if not RateLimitService.check(player, "GetProfile") then
			return { ok = false, err = "rate_limited" }
		end
		if type(userId) ~= "number" then
			return { ok = false, err = "bad_userId" }
		end
		return { ok = true, profile = readProfile(userId) }
	end)

	Net.bindFunction("SetShowcase", function(player, itemIds)
		if not RateLimitService.check(player, "SetShowcase") then
			return { ok = false, err = "rate_limited" }
		end
		local profile = DataService.getProfile(player)
		if profile == nil then
			return { ok = false, err = "loading" }
		end
		if type(itemIds) ~= "table" then
			return { ok = false, err = "bad_input" }
		end
		local clean = {}
		for _, itemId in itemIds do
			if type(itemId) == "string" and (profile.Inventory[itemId] or 0) >= 1 then
				table.insert(clean, itemId)
				if #clean >= 6 then break end
			end
		end
		profile.Showcase = clean
		writeNow(player)
		return { ok = true }
	end)

	Net.bindFunction("SetStatus", function(player, text)
		if not RateLimitService.check(player, "SetStatus") then
			return { ok = false, err = "rate_limited" }
		end
		local profile = DataService.getProfile(player)
		if profile == nil then
			return { ok = false, err = "loading" }
		end
		if type(text) ~= "string" then
			return { ok = false, err = "bad_input" }
		end
		text = text:sub(1, STATUS_MAX)
		local ok, filtered = pcall(function()
			local res = TextService:FilterStringAsync(text, player.UserId)
			return res:GetNonChatStringForBroadcastAsync()
		end)
		profile.Status = ok and filtered or ""
		writeNow(player)
		return { ok = ok, err = (not ok) and "filter_failed" or nil }
	end)

	Net.bindFunction("SetStatChips", function(player, keys)
		if not RateLimitService.check(player, "SetStatChips") then
			return { ok = false, err = "rate_limited" }
		end
		local profile = DataService.getProfile(player)
		if profile == nil then
			return { ok = false, err = "loading" }
		end
		if type(keys) ~= "table" then
			return { ok = false, err = "bad_input" }
		end
		local allowed = { portfolioValue = true, trades = true, gemsEarned = true, mythicals = true, accountAge = true, distinctItems = true, gems = true }
		local clean = {}
		for _, key in keys do
			if type(key) == "string" and allowed[key] then
				table.insert(clean, key)
				if #clean >= 4 then break end
			end
		end
		profile.StatChips = clean
		writeNow(player)
		return { ok = true }
	end)

	Net.bindFunction("SetPrivacy", function(player, toggles)
		if not RateLimitService.check(player, "SetPrivacy") then
			return { ok = false, err = "rate_limited" }
		end
		local profile = DataService.getProfile(player)
		if profile == nil then
			return { ok = false, err = "loading" }
		end
		if type(toggles) ~= "table" then
			return { ok = false, err = "bad_input" }
		end
		profile.Privacy = {
			hideValue = toggles.hideValue == true,
			hideShowcase = toggles.hideShowcase == true,
		}
		writeNow(player)
		return { ok = true }
	end)

	AnalyticsService.log("profile_service_started", {})
end

return ProfileService
```

- [ ] **Step 4: Wire the debounced write to inventory changes.** In `src/server/Services/InventoryService.luau` `pushState` (line ~104, which fires `InventoryChanged`), add — after the `Net.fireClient(...)` line — a call to mark the profile dirty:

```lua
	local ProfileService = require(script.Parent.ProfileService) :: any
	ProfileService.markDirty(player)
```

(Require inside the function to avoid a circular require at module load — `ProfileService` requires `EconomyService`, not `InventoryService`, so a top-level require would also be fine, but function-local keeps load order simple.)

- [ ] **Step 5: Register the service.** In `src/server/init.server.luau`, add `ProfileService` to the Init/Start sequence, AFTER `EconomyService` and `InventoryService` are started (it reads both). Match the existing registration style, e.g.:

```lua
local ProfileService = require(script.Services.ProfileService)
-- ...in the Init phase:
ProfileService.Init()
-- ...in the Start phase:
ProfileService.Start()
```

(Read the file first and mirror how sibling services are listed — do not reorder existing services.)

- [ ] **Step 6: Remove the stray no-op line.** In `ProfileService.Start` delete the placeholder line `Net.onServer and nil -- (no-op; ...)` — it exists only to mark where the InventoryChanged hook lives (Step 4 wires it from InventoryService instead). Confirm the file has no reference to `Net.onServer`.

- [ ] **Step 7: Sync + smoke test in Studio.** Build/load. In Edit run:

```lua
local ok = pcall(function()
	require(game.ServerScriptService.Server.Services.ProfileService)
end)
print("ProfileService requires OK:", ok)
```

Expected: `ProfileService requires OK: true`.

- [ ] **Step 8: Commit.**

```bash
git add src/server/Services/ProfileService.luau src/shared/Enums.luau src/shared/Config/TradeConfig.luau src/server/Services/InventoryService.luau src/server/init.server.luau
git commit -m "feat(profile): ProfileService — public snapshot store, remotes, debounced writes"
```

---

## Task 5: GuiBuilder — ProfilePanel, player browser, HUD button

**Files:**
- Modify: `src/shared/GuiBuilder.luau`

**Interfaces:**
- Produces named GUI nodes the client controller (Task 6) will `WaitForChild`:
  - HUD button: `ScreenGui "HUD" > ... > TextButton "ProfileButton"` (mirror the existing HUD button pattern, e.g. the Store/Board buttons).
  - `ScreenGui "ProfileGui"` (Enabled=false) containing:
    - `Frame "Browser"` with `Frame "Tabs" > TextButton "ServerTab" / TextButton "GlobalTab"`, a `TextBox "SearchBox"` (used by Global), and a `ScrollingFrame "PlayerList"` holding a `Frame "RowTemplate"` (Visible=false) with children `ImageLabel "Avatar"`, `TextLabel "DisplayName"`, `TextLabel "Username"`.
    - `Frame "Profile"` (the profile view) with: `ImageLabel "Avatar"`, `TextLabel "DisplayName"`, `TextLabel "Username"`, `TextLabel "JoinDate"`, `TextLabel "PortfolioValue"`, `Frame "Showcase"` holding a `Frame "SlotTemplate"` (Visible=false) with `ImageLabel "Icon"` + `TextLabel "ItemName"` + `TextLabel "Rarity"` + `TextLabel "ItemValue"`, `Frame "Chips"` holding `Frame "ChipTemplate"` (Visible=false) with `TextLabel "ChipLabel"` + `TextLabel "ChipValue"`, `TextLabel "Status"`, `TextButton "TradeButton"`, and an edit sub-frame `Frame "Edit"` (Visible=false) with `TextBox "StatusInput"`, `TextButton "EditShowcase"`, `TextButton "EditChips"`, `TextButton "ToggleHideValue"`, `TextButton "ToggleHideShowcase"`, `TextButton "SaveButton"`.

- [ ] **Step 1: Read a sibling panel builder for the exact idiom.** Open `src/shared/GuiBuilder.luau` and locate the function that builds an existing panel with a scrolling list + row template (e.g. the Board or Store panel, or the search list). Copy its construction idiom (helper `New`/`make` calls, `Theme` usage, template + `Visible=false` pattern). Do NOT invent a new style.

- [ ] **Step 2: Build the HUD "Profile" button.** In the HUD-building section, add a `TextButton` named `ProfileButton` alongside the existing HUD buttons, using the same size/anchor/theme helpers. Text = `"Profile"`.

- [ ] **Step 3: Build `ProfileGui`.** Add a builder that constructs the `ProfileGui` ScreenGui with the `Browser` and `Profile` frames and all named descendants listed in Interfaces above. Use `Visible=false` templates for `RowTemplate`, `SlotTemplate`, `ChipTemplate`. Set `ProfileGui.Enabled = false`. Reuse `Theme` colors/fonts exactly as sibling panels do. Keep it structural — the runtime controller fills text/images.

- [ ] **Step 4: Ensure the builder is invoked.** Confirm the top-level `GuiBuilder.build()` calls your new builder (mirror how sibling panels are invoked in `build()`).

- [ ] **Step 5: Rebuild GUI into StarterGui in Studio.** In Edit mode run the project's established GUI-rebuild call:

```lua
require(game.ReplicatedStorage.Shared.GuiBuilder).build()
```

Then verify the nodes exist:

```lua
local sg = game:GetService("StarterGui")
print(sg:FindFirstChild("ProfileGui") ~= nil, sg.ProfileGui.Profile.Showcase:FindFirstChild("SlotTemplate") ~= nil)
```

Expected: `true true`.

- [ ] **Step 6: Commit.**

```bash
git add src/shared/GuiBuilder.luau
git commit -m "feat(profile): GuiBuilder ProfilePanel, player browser, HUD button"
```

---

## Task 6: Client — ProfileController + ProfileScreen wiring

**Files:**
- Create: `src/client/Controllers/ProfileController.luau`
- Create: `src/client/UI/ProfileScreen.luau`
- Modify: `src/client/init.client.luau`

**Interfaces:**
- Consumes: `Net.invoke("GetProfile"/"SetShowcase"/"SetStatus"/"SetStatChips"/"SetPrivacy", ...)`, `InventoryController.inventory` (for the self showcase/chips picker), the existing trade-initiation entry (`TradeController.requestTrade(userId)` or the existing search→trade flow), `Players` for the Server tab list + avatar thumbnails (`Players:GetUserThumbnailAsync`).
- Produces: `ProfileController.openSelf()`, `ProfileController.openUser(userId)`.

- [ ] **Step 1: Create `ProfileController`.** Create `src/client/Controllers/ProfileController.luau`:

```lua
--!strict
-- ProfileController: fetch/cache the viewed profile + drive own-profile edits.
-- Server is authoritative; this only requests + reflects.
local Players = game:GetService("Players")
local State = require(game.ReplicatedStorage.Shared.Util.State)
local Net = require(script.Parent.Parent.Net)

local ProfileController = {}
ProfileController.viewed = State.Value(nil :: any) -- PublicProfile or nil
ProfileController.viewingSelf = State.Value(false)

local localUserId = Players.LocalPlayer.UserId

local function fetch(userId: number)
	task.spawn(function()
		local res = Net.invoke("GetProfile", userId)
		if res.ok then
			ProfileController.viewed:set(res.profile, true)
		end
	end)
end

function ProfileController.openUser(userId: number)
	ProfileController.viewingSelf:set(userId == localUserId)
	ProfileController.viewed:set(nil)
	fetch(userId)
end

function ProfileController.openSelf()
	ProfileController.openUser(localUserId)
end

function ProfileController.setShowcase(itemIds: { string })
	task.spawn(function()
		Net.invoke("SetShowcase", itemIds)
		fetch(localUserId)
	end)
end

function ProfileController.setStatus(text: string)
	task.spawn(function()
		Net.invoke("SetStatus", text)
		fetch(localUserId)
	end)
end

function ProfileController.setStatChips(keys: { string })
	task.spawn(function()
		Net.invoke("SetStatChips", keys)
		fetch(localUserId)
	end)
end

function ProfileController.setPrivacy(hideValue: boolean, hideShowcase: boolean)
	task.spawn(function()
		Net.invoke("SetPrivacy", { hideValue = hideValue, hideShowcase = hideShowcase })
		fetch(localUserId)
	end)
end

function ProfileController.Init() end
function ProfileController.Start() end

return ProfileController
```

- [ ] **Step 2: Create `ProfileScreen`.** Create `src/client/UI/ProfileScreen.luau`. It `WaitForChild`s the `ProfileGui` nodes (Task 5), wires:
  - HUD `ProfileButton.Activated` → `ProfileController.openSelf()` + show `ProfileGui`, show `Profile` frame.
  - `ServerTab.Activated` → populate `PlayerList` from `Players:GetPlayers()` (clone `RowTemplate` per player, fill Avatar via `Players:GetUserThumbnailAsync`, DisplayName, Username; row click → `ProfileController.openUser(row.userId)`).
  - `GlobalTab.Activated` + `SearchBox` → call `Net.invoke("SearchPlayers", query)` and populate rows the same way.
  - Render `ProfileController.viewed` via `State.Observe`: fill Avatar/DisplayName/Username/JoinDate; `PortfolioValue` → number or `"Hidden"` when `profile.portfolioValue == nil`; clone `SlotTemplate` per `showcase` entry (or show an empty/"Hidden" state when `showcase == nil`); clone `ChipTemplate` per `statChips`; `Status` text.
  - `TradeButton`: visible only when NOT self AND the target is currently online (`Players:GetPlayerByUserId(userId) ~= nil`); `Activated` → existing trade-initiation entry for that userId.
  - Edit mode (`viewingSelf == true`): show `Edit` frame; `StatusInput` → `setStatus`; `EditShowcase`/`EditChips` open pickers sourced from `InventoryController.inventory` and the allowed chip keys; toggles → `setPrivacy`; `SaveButton` closes edit.

  Follow the existing `TradeScreen.luau`/`BoardScreen.luau` runtime idiom (WaitForChild + `State.Observe` + template-clone). Use `Components.luau` helpers for item icons/rarity where applicable.

- [ ] **Step 3: Start the controller + screen.** In `src/client/init.client.luau`, add `ProfileController` to the controller Init/Start list and require/start `ProfileScreen` alongside the other UI screens (mirror how `TradeScreen`/`BoardScreen` are started).

- [ ] **Step 4: Sync + manual play-test.** Build/load, rebuild GUI (`GuiBuilder.build()`), then Play. Verify: HUD Profile button opens your own profile; default showcase shows your scarcest ≤6; edit status → persists on reopen; toggle Hide Value → aggregate shows "Hidden" from another viewpoint; Server tab lists players; clicking a player opens their profile with a Trade button.

- [ ] **Step 5: Commit.**

```bash
git add src/client/Controllers/ProfileController.luau src/client/UI/ProfileScreen.luau src/client/init.client.luau
git commit -m "feat(profile): client ProfileController + ProfileScreen wiring"
```

---

## Task 7: Integration verification + privacy audit

**Files:**
- Test: manual Studio integration (Team Test for offline/cross-server where possible) + one added unit guard.

- [ ] **Step 1: Unit — status length cap + empty projection.** Add to `src/server/Tests/ProfileTests.luau`:

```lua
		["project: empty inventory yields empty showcase + zero value"] = function()
			local resolve = function(_) return nil end
			local pub = PP.project({
				userId = 1, name = "n", displayName = "d", firstJoin = 0, now = 0,
				inventory = {}, gems = 0, showcase = {}, statChips = { "portfolioValue" },
				status = "", privacy = { hideValue = false, hideShowcase = false },
				lifetime = { gemsEarned = 0, trades = 0 }, resolve = resolve,
			})
			eq(pub.portfolioValue, 0, "zero value")
			eq(#pub.showcase, 0, "empty showcase")
		end,
```

Run TestRunner — expect all `Profile / *` PASS.

- [ ] **Step 2: Privacy audit — hidden data absent from the wire.** In a play session, as player A set Hide Value + Hide Showcase. From player B (or a second client), run in the client console:

```lua
local res = game.ReplicatedStorage:FindFirstChild("Net") -- use the project's Net invoke path
```

Then invoke `GetProfile(A.UserId)` and print the returned table. Confirm: `profile.portfolioValue == nil`, `profile.showcase == nil`, and there is NO inventory field anywhere in the payload. (Absence, not `"Hidden"` string — the UI renders "Hidden"; the payload omits the key.)

- [ ] **Step 3: Showcase staleness — traded-away item drops.** A showcases item X, then trades X away. Within the debounce window (~4s) re-fetch A's profile from B and confirm X is gone from `showcase` (filter-to-owned at write).

- [ ] **Step 4: Offline profile.** Note A's userId, have A leave. From B, `GetProfile(A.UserId)` → confirm a snapshot still returns (identity + last public state) with no errors. (Requires the leave-time `writeNow` from Task 4.)

- [ ] **Step 5: Counters.** Complete a P2P trade between A and B; confirm each side's `trades` chip increments by 1 and any gems received add to `gemsEarned` (view via their profile's chips if pinned, or read the private profile in Edit).

- [ ] **Step 6: Rate limits.** Spam `GetProfile` past the bucket (60/min) and confirm `{ ok = false, err = "rate_limited" }`.

- [ ] **Step 7: Commit.**

```bash
git add src/server/Tests/ProfileTests.luau
git commit -m "test(profile): projection edge cases + integration audit notes"
```

---

## Appendix: Studio sync (per-task after edits)

The project syncs via a built `rbxm` copied into the running Studio's content cache (Studio's `rbxasset://` cache can serve stale files otherwise). Per task, after editing `src/`:

1. `rojo build -o sync.rbxm sync.project.json`
2. Copy `sync.rbxm` → `<runningStudioContentDir>/trading_sync_<timestamp>.rbxm` (find the running Studio exe dir via `Get-Process RobloxStudioBeta`).
3. In Studio Edit, load + splice via `game:GetObjects("rbxasset://trading_sync_<timestamp>.rbxm")`, replacing `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayerScripts.Client` children (the established splice snippet).
4. Verify with `script_grep` / a `require` smoke check before trusting the sync.
5. For GUI structure changes, additionally run `require(game.ReplicatedStorage.Shared.GuiBuilder).build()` to rebuild into StarterGui.

---

## Self-Review

- **Spec coverage:** Two tabs (Task 5/6) ✓; identity+trade count+showcase+aggregate+chips+status (Tasks 3–6) ✓; opt-out toggles (Task 3 projection + Task 4 SetPrivacy) ✓; offline viewable (Task 4 snapshot + leave-write, Task 7 Step 4) ✓; showcase re-validate-at-render (Task 3 resolveShowcase + Task 4 debounced write, Task 7 Step 3) ✓; server-computed public subset, client never filters (Task 4 build/project, Task 7 Step 2 audit) ✓; rate limits (Task 4) ✓; global search resolves offline (reuses `SearchPlayers` + `SeenPlayers_v1`) ✓; schema migration (Task 1) ✓; scarcity = circulating (Task 3 defaultShowcase, resolver in Task 4) ✓; new counters (Task 2) ✓; FilterStringAsync (Task 4 SetStatus) ✓; portfolio value excludes gems (Task 3) ✓; default best-6 (Task 3) + default chips (Task 3 DEFAULT_CHIPS) ✓; HUD button (Task 5/6) ✓.
- **Placeholder scan:** No TBD/TODO; the one intentional no-op line in the ProfileService draft is explicitly deleted in Task 4 Step 6.
- **Type consistency:** `ItemView` shape identical in Types, ProfileProjection, and the Task 4 `resolver`. Remote names identical across Enums (Task 4 Step 1), server binds (Task 4 Step 3), client invokes (Task 6). `resolveChip`/`project` arg shape (`ctx`/`args`) consistent between Task 3 tests and implementation. Chip allowed-key set matches between `SetStatChips` (Task 4) and `CHIP_LABELS`/`resolveChip` (Task 3).
