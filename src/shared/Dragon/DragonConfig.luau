--!strict
return {
	SCALE = 1.5, -- studs per design unit (wingspan ~19 units)
	-- Upload Obsidian_West_asset_pack/Dragon_Color.png and paste the rbxassetid here (optional if imported textures survive).
	TEXTURE_ID = "",
	SOURCE_MODEL_NAME = "DragonWestModel", -- ReplicatedStorage model holding imported MeshParts named like the joints
	TRANSFORM_DELAY = 2.5, -- s after DragonWestTransformEvent: matches VFX blast beat
	FLY_SPEED = 75,
	FLY_VERTICAL = 45,
	DOUBLE_TAP = 0.3,
	FIREBALL = {
		COOLDOWN = 1,
		SPEED = 120,
		RANGE = 350,
		RADIUS = 16,
		DAMAGE = 35,
	},
}
