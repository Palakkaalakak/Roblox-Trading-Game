# Obsidian West dragon: runtime rig

Code: `src/shared/Dragon/{DragonJoints,DragonRig,DragonConfig}.luau`, `src/server/DragonService.server.luau`, `src/client/DragonClient.client.luau`. Untested in Studio.

1. Import `Obsidian_West_asset_pack/parts/*.obj` (Studio 3D Importer). Put the 45 MeshParts, named exactly as in `joints.json`, in `ReplicatedStorage.DragonWestModel`. Without it, green placeholder blocks are used so the rig still runs.
2. Upload `Dragon_Color.png`; paste the id into `DragonConfig.TEXTURE_ID` (leave MeshPart Color white).
3. Rig is built at runtime: Motor6Ds from the manifest pivots, 180-degree Y flip (+Z asset to Roblox -Z), welded to HumanoidRootPart, character hidden.
4. Transform: `DragonRemotes.Transform:FireServer(true/false)`, or the existing `DragonWestTransformEvent` (toggles after `TRANSFORM_DELAY`).
5. Controls: double-tap Space = fly (WASD relative to camera, Space up, Shift down, double-tap or land to exit); R = fireball (1 s cooldown, server damage 35 in 16 studs, caster excluded).
6. Not done: glowing fissures (Dragon_Emission.png needs Neon overlays), finger/membrane animation (rigid; kept static).
