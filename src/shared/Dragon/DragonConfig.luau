--!strict
return {
	SCALE = 1, -- multiplier on the imported size (1 = as imported)
	-- Upload Obsidian_West_asset_pack/Dragon_Color.png and paste the rbxassetid here (optional if imported textures survive).
	TEXTURE_ID = "",
	SOURCE_MODEL_NAME = "DragonWestModel", -- ReplicatedStorage model holding imported MeshParts named like the joints
	TRANSFORM_DELAY = 2.5, -- s after DragonWestTransformEvent: matches VFX blast beat
	SELF_TEST = true, -- Studio only: auto-transform on spawn and print a report to Output; set false when done
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
