--!strict
-- DigConfig: Relic Dig proof of concept (Area 1 minigame). See
-- docs/design-area1-relic-dig.md. Every number marked PLACEHOLDER is untuned:
-- the research found no published figure for it, so set it from playtests.
--
-- Skill only decides the reward LEVEL (how much of the relic was uncovered).
-- Chance only picks the item inside that level. Pays items, never gems.

local DigConfig = {
	PromptName = "DigPrompt", -- ProximityPrompt on every dig plot opens the minigame

	-- One dig plot: a pit sunk into the field's ground, filled flush with a few
	-- stacked layers of sand (no gaps). Digging lowers the sand level: each tap
	-- shaves the top off, the layers go away top first, and the buried chest
	-- comes up out of it. Shared by the server field builder (DigFieldService)
	-- and the client dig; nothing about digging replicates, each player digs
	-- their OWN local copy, so any number of players can dig the same plot.
	Site = {
		cols = 13,
		rows = 8,
		tile = 1, -- studs per grid cell (used to place the chest)
		groundH = 1.8, -- field ground height above the baseplate
		floorH = 0.2, -- pit floor slab thickness (the sand starts on top of it)
		-- sand layers, bottom to top: darker, damper sand deep down, pale at the surface
		layers = {
			Color3.fromRGB(150, 110, 70),
			Color3.fromRGB(184, 140, 90),
			Color3.fromRGB(214, 174, 118),
			Color3.fromRGB(238, 210, 156),
		},
	},

	-- The dig field: a raised sandy yard with plotsX * plotsZ plots. PLACEHOLDER
	-- origin; move it wherever the Area 1 map wants it.
	Field = {
		origin = Vector3.new(-125, 0, 30), -- centre of the field on the baseplate
		plotsX = 4,
		plotsZ = 3,
		gapX = 5, -- walkway between plots (studs)
		gapZ = 6,
		margin = 9, -- sand beyond the outer plots
		ramp = 7, -- length of the ramp up onto the field
	},

	-- Pro Sound Effects library (Roblox-licensed, public). PLACEHOLDER picks.
	Sounds = {
		Strike = "rbxassetid://9117739443", -- dig into dirt
		Brush = "rbxassetid://9113596014", -- brush scrub
		Crumble = "rbxassetid://9114110290", -- dirt debris (final collapse)
		Creak = "rbxassetid://9120881682", -- wood chest creak
		Ping = "rbxasset://sounds/electronicpingshort.wav",
	},

	-- The whole chest must be uncovered (no brush limit). Skill = doing it in the
	-- fewest taps. PLACEHOLDER: the most taps that still earns each level.
	TapPar = { Perfect = 7, Great = 10, Good = 14 },

	-- PLACEHOLDER: drawn with RollService.pick through a pseudo tier. The level
	-- picks the rarity window; the item inside it is chosen by supply weight.
	LevelOrder = { "Floor", "Good", "Great", "Perfect" },
	Levels = {
		Floor = {
			window = { "Common", "Rare" },
			odds = { Common = 97, Rare = 3 },
		},
		Good = {
			window = { "Common", "Rare", "Legendary" },
			odds = { Common = 84, Rare = 14, Legendary = 2 },
		},
		Great = {
			window = { "Common", "Rare", "Legendary", "Mythical" },
			odds = { Common = 62, Rare = 28, Legendary = 8, Mythical = 2 },
		},
		Perfect = {
			window = { "Rare", "Legendary", "Mythical", "Godly" },
			odds = { Rare = 66, Legendary = 25, Mythical = 7.5, Godly = 1.5 },
		},
	},

	-- First run of a session pays at least Good (guaranteed good start).
	FirstRunMinLevel = "Good",

	-- Bad-luck meter: after this many runs below Good, the next run is
	-- upgraded one level. Guarantees a LEVEL, never a specific item.
	-- PLACEHOLDER (session-only in this proof of concept, not saved).
	LuckRuns = 3,

	-- Dig mastery (saved in Lifetime.digXp). Repeating the minigame pays off with
	-- a wider green zone (easier perfect taps). PLACEHOLDER numbers.
	XpFor = { Floor = 1, Good = 3, Great = 5, Perfect = 8 },
	Progression = {
		{ xp = 0, zone = 0.32 },
		{ xp = 12, zone = 0.32 },
		{ xp = 30, zone = 0.36 },
		{ xp = 60, zone = 0.36 },
		{ xp = 110, zone = 0.40 },
		{ xp = 180, zone = 0.40 },
	},

	-- wheel
	ReelTiles = 36,
	ReelWinnerIndex = 30,
}

function DigConfig.levelIndex(level: string): number
	for i, name in DigConfig.LevelOrder do
		if name == level then
			return i
		end
	end
	return 1
end

-- Height of the sand stack (ground level minus the pit floor).
function DigConfig.blockH(): number
	return DigConfig.Site.groundH - DigConfig.Site.floorH
end

-- Offset of cell (c, r) from the plot centre, in plot space.
-- Row 1 is the back of the plot, the last row the front (camera side, +Z).
function DigConfig.cellOffset(c: number, r: number): Vector3
	local S = DigConfig.Site
	return Vector3.new((c - 0.5 - S.cols / 2) * S.tile, 0, (r - 0.5 - S.rows / 2) * S.tile)
end

-- Centre of plot (i, j) on the field, in world space (Y = baseplate top).
function DigConfig.plotCenter(i: number, j: number): Vector3
	local S, F = DigConfig.Site, DigConfig.Field
	local strideX, strideZ = S.cols * S.tile + F.gapX, S.rows * S.tile + F.gapZ
	return F.origin + Vector3.new((i - 0.5 - F.plotsX / 2) * strideX, 0, (j - 0.5 - F.plotsZ / 2) * strideZ)
end

-- Reward level for finishing the chest in `taps` taps, before first-run / luck bumps.
function DigConfig.levelForTaps(taps: number): string
	local par = DigConfig.TapPar
	if taps <= par.Perfect then
		return "Perfect"
	elseif taps <= par.Great then
		return "Great"
	elseif taps <= par.Good then
		return "Good"
	end
	return "Floor"
end

-- Dig level (1-based) for an xp total, plus that level's perks and the xp the
-- next level needs (nil at the top).
function DigConfig.progressionFor(xp: number): (number, any, number?)
	local idx = 1
	for i, p in DigConfig.Progression do
		if xp >= p.xp then
			idx = i
		end
	end
	local nextEntry = DigConfig.Progression[idx + 1]
	return idx, DigConfig.Progression[idx], nextEntry and nextEntry.xp or nil
end

return DigConfig
