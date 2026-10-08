--!strict
return {
	SCALE = 6.8, -- dragon only (2x the previous 2); the transform VFX is scaled separately by VFX_SCALE -- multiplier on the imported size (1 = as imported)
	VFX_SCALE = 2, -- transform effect size multiplier (fixed; independent of the dragon size)
	DRAGON_EXTENT = 12, -- farthest point of the dragon from its centre, design units (wing tip / tail)
	REVERSE_SPHERE_SPEED = 2.5, -- revert: sphere part of the reversed VFX plays this much faster
	DRAGON_ZOOM = 150, -- camera distance right after transforming
	TRANSFORM_ZOOM = 132, -- minimum camera distance during the transform VFX (grows with the sphere)
	DRAGON_WALKSPEED = 40,
	-- Upload Obsidian_West_asset_pack/Dragon_Color.png and paste the rbxassetid here (optional if imported textures survive).
	TEXTURE_ID = "",
	SWAP_T = 2.5, -- VFX module time (s) of the blast: character <-> dragon swap happens here (mirrored on revert)
	TEST_J_FAIL = true, -- TESTING: pressing J triggers a random fire move's failure (backfire + "faileur!") on yourself; set false to disable
	DEBUG = true, -- prints [DragonDbg] lines for every transform step (client + server)
	COLLECT_TEXTURES = false, -- Studio only: Play prints a TEXTURES table built from Workspace.textures (DragonTextureCollector)
	SCAN = true, -- Studio only: print a workspace/dragon structure scan to Output on start
	SELF_TEST = true, -- Studio only: print a report to Output after the first transform; set false when done
	FLY_SPEED = 150,
	FLY_VERTICAL = 80,
	DOUBLE_TAP = 0.3,
	DRAGON_HIT_BODY = 20,
	-- Cursed player: this exact username's attacks backfire at CHANCE; only they are hurt and they turn charred.
	BACKFIRE = { NAME = "Cscgde", CHANCE = 1 / 3, CHAR_TIME = 10 },
	DRAGON_RESIST = 0.85, -- players in dragon form take 85% less damage (and cannot be one-shot)
	TRANSFORM_DAMAGE_PCT = 0.15, -- anyone inside the transformation blast loses this fraction of max health (ignores DRAGON_RESIST)
	TRANSFORM_BLAST_RADIUS = 51, -- studs (the black sphere's radius at VFX_SCALE 2)
	-- Self-hit boost: getting caught in your own explosion stacks a speed boost (walk + fly).
	SELF_BOOST = {
		PER_HIT = 0.25, -- +25% per hit, plus up to +25% more for a fully charged shot
		MAX = 1.5, -- cap: +150%
		DURATION = 6, -- seconds the boost holds after the last self-hit
		FADE = 2, -- then fades out over this many seconds
	}, -- extra hit reach (studs) on players in dragon form (their dragon is non-collidable)
	FIREBALL = {
		-- Tap = small shot. Hold to charge up to MAX_CHARGE s (holds at max until released):
		-- size grows fast (ease-out) from MIN_SIZE to 1, speed x1..x1.5, damage x1..x3 (linear).
		COOLDOWN = 1,
		MAX_CHARGE = 3,
		MAX_D_HEAD = 1.8, -- fully charged ball diameter = this x the dragon head's largest dimension
		MIN_SIZE = 0.2, -- tap size as a fraction of the fully charged size
		EXPLOSION_SCALE = 0.7, -- explosion VISUAL size multiplier (-30%); damage radius unchanged
		VISUAL_SIZE = 0.5, -- drawn ball/orb size multiplier only (hitbox, blast radius, damage unchanged)
		BLAST_PER_D = 3.1, -- explosion damage/visual radius = this x ball diameter
		SPEED = 180,
		RANGE = 200, -- max travel of every fire move (studs)
		DAMAGE = 30,
	},
	-- Custom fireball textures (assets/dragon_fx/*.png, made by tools/dragon_fx/make_textures.py).
	-- Upload them (Studio: Asset Manager > Bulk Import, or Creator Hub) and paste each image id here
	-- (plain number or rbxassetid://...). Empty = that textured layer is skipped.
	TEXTURES = {
		flame_orange_4x4 = "rbxassetid://137821304344895",
		flame_violet_4x4 = "rbxassetid://89476490955605",
		flame_crimson_4x4 = "rbxassetid://79830888140983",
		explosion_orange_4x4 = "rbxassetid://93482650527607",
		explosion_violet_4x4 = "rbxassetid://73280316368511",
		explosion_crimson_4x4 = "rbxassetid://77647476062850",
		smoke_2x2 = "rbxassetid://113072040891182",
		spark_star = "rbxassetid://96304942123030",
		shock_ring = "rbxassetid://139364684751345",
		slash_arc = "rbxassetid://107447310049129",
		beam_lightning = "rbxassetid://137708063479983",
		beam_flame_orange = "rbxassetid://106835369305715",
		beam_flame_violet = "rbxassetid://82976437993616",
		crack_burst = "rbxassetid://135447163814306",
		sigil = "rbxassetid://114041859733252",
		lava_rock = "rbxassetid://70770527420730",
	},
	-- Fire moves: each has its own VFX design. Flashier = more damage, slower, longer cooldown.
	MOVES = {
		R = { name = "Fire Blast", damage = 1, size = 1, speed = 1, cooldown = 1 },
		Q = { name = "Violet Serpent", damage = 1.6, size = 1, speed = 1.2, cooldown = 2.5 },
		F = { name = "Inferno Meteor", damage = 2.4, size = 1.3, speed = 0.75, cooldown = 5 },
	},
}
