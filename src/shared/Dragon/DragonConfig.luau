--!strict
return {
	SCALE = 1, -- multiplier on the imported size (1 = as imported)
	-- Upload Obsidian_West_asset_pack/Dragon_Color.png and paste the rbxassetid here (optional if imported textures survive).
	TEXTURE_ID = "",
	SOURCE_MODEL_NAME = "DragonWestModel", -- ReplicatedStorage model holding imported MeshParts named like the joints
	SWAP_T = 2.5, -- VFX module time (s) of the blast: character <-> dragon swap happens here (mirrored on revert)
	SCAN = true, -- Studio only: print a workspace/dragon structure scan to Output on start
	SELF_TEST = true, -- Studio only: print a report to Output after the first transform; set false when done
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
