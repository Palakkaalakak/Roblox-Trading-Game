--!strict
return {
	SCALE = 4, -- dragon only (2x the previous 2); the transform VFX is scaled separately by VFX_SCALE -- multiplier on the imported size (1 = as imported)
	VFX_SCALE = 2, -- transform effect size multiplier (fixed; independent of the dragon size)
	DRAGON_EXTENT = 12, -- farthest point of the dragon from its centre, design units (wing tip / tail)
	REVERSE_SPHERE_SPEED = 2.5, -- revert: sphere part of the reversed VFX plays this much faster
	DRAGON_ZOOM = 88, -- camera distance right after transforming
	TRANSFORM_ZOOM = 132, -- minimum camera distance during the transform VFX (grows with the sphere)
	DRAGON_WALKSPEED = 40,
	-- Upload Obsidian_West_asset_pack/Dragon_Color.png and paste the rbxassetid here (optional if imported textures survive).
	TEXTURE_ID = "",
	SWAP_T = 2.5, -- VFX module time (s) of the blast: character <-> dragon swap happens here (mirrored on revert)
	SCAN = true, -- Studio only: print a workspace/dragon structure scan to Output on start
	SELF_TEST = true, -- Studio only: print a report to Output after the first transform; set false when done
	FLY_SPEED = 150,
	FLY_VERTICAL = 80,
	DOUBLE_TAP = 0.3,
	DRAGON_HIT_BODY = 12, -- extra hit reach (studs) on players in dragon form (their dragon is non-collidable)
	FIREBALL = {
		-- Tap = small shot. Hold to charge up to MAX_CHARGE s (holds at max until released):
		-- size grows fast (ease-out) from MIN_SIZE to 1, speed x1..x1.5, damage x1..x3 (linear).
		COOLDOWN = 1,
		MAX_CHARGE = 3,
		MAX_D_HEAD = 1.8, -- fully charged ball diameter = this x the dragon head's largest dimension
		MIN_SIZE = 0.2, -- tap size as a fraction of the fully charged size
		VISUAL_SIZE = 0.7, -- drawn ball/orb size multiplier only (hitbox, blast radius, damage unchanged)
		BLAST_PER_D = 3.1, -- explosion damage/visual radius = this x ball diameter
		SPEED = 180,
		RANGE = 900,
		DAMAGE = 30,
	},
	-- Custom fireball textures (assets/dragon_fx/*.png, made by tools/dragon_fx/make_textures.py).
	-- Upload them (Studio: Asset Manager > Bulk Import, or Creator Hub) and paste each image id here
	-- (plain number or rbxassetid://...). Empty = that textured layer is skipped.
	TEXTURES = {
		flame_orange_4x4 = "",
		flame_violet_4x4 = "",
		flame_crimson_4x4 = "",
		explosion_orange_4x4 = "",
		explosion_violet_4x4 = "",
		explosion_crimson_4x4 = "",
		smoke_2x2 = "",
		spark_star = "",
		shock_ring = "",
		slash_arc = "",
		beam_lightning = "",
		beam_flame_orange = "",
		beam_flame_violet = "",
		crack_burst = "",
		sigil = "",
		lava_rock = "",
	},
	-- Fire moves: each has its own VFX design. Flashier = more damage, slower, longer cooldown.
	MOVES = {
		R = { name = "Fire Blast", damage = 1, size = 1, speed = 1, cooldown = 1 },
		Q = { name = "Violet Serpent", damage = 1.6, size = 1, speed = 1.2, cooldown = 2.5 },
		F = { name = "Inferno Meteor", damage = 2.4, size = 1.3, speed = 0.75, cooldown = 5 },
	},
}
