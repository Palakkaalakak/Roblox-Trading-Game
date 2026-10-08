--!strict
return {
	SCALE = 2, -- multiplier on the imported size (1 = as imported)
	VFX_SCALE = 2, -- minimum; the driver raises it so the sphere always swallows the dragon
	DRAGON_EXTENT = 12, -- farthest point of the dragon from its centre, design units (wing tip / tail)
	SPHERE_MARGIN = 1.35, -- sphere radius must be at least this x the dragon reach at the blast -- transformation VFX (DragonWestVFXCore) size multiplier
	REVERSE_SPHERE_SPEED = 2.5, -- revert: sphere part of the reversed VFX plays this much faster
	DRAGON_ZOOM = 44, -- camera distance right after transforming
	TRANSFORM_ZOOM = 132, -- camera distance during the (scaled) transform VFX
	DRAGON_WALKSPEED = 28,
	-- Upload Obsidian_West_asset_pack/Dragon_Color.png and paste the rbxassetid here (optional if imported textures survive).
	TEXTURE_ID = "",
	SWAP_T = 2.5, -- VFX module time (s) of the blast: character <-> dragon swap happens here (mirrored on revert)
	SCAN = true, -- Studio only: print a workspace/dragon structure scan to Output on start
	SELF_TEST = true, -- Studio only: print a report to Output after the first transform; set false when done
	FLY_SPEED = 100,
	FLY_VERTICAL = 55,
	DOUBLE_TAP = 0.3,
	DRAGON_HIT_BODY = 6, -- extra hit reach (studs) on players in dragon form (their dragon is non-collidable)
	FIREBALL = {
		-- Tap R = base shot. Hold R up to MAX_CHARGE s: scales linearly to
		-- size x2, speed x1.5, damage x3 (auto-fires at max).
		COOLDOWN = 1,
		MAX_CHARGE = 3,
		BALL_D = 9, -- projectile diameter (studs) at no charge
		SPEED = 180,
		RANGE = 700,
		RADIUS = 28, -- explosion damage radius at no charge
		DAMAGE = 30,
	},
}
