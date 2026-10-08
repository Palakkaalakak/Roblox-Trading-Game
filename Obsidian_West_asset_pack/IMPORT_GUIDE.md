# Obsidian West — asset pack

A procedural, reference-inspired western wyvern, NOT the original Blox Fruits model.
This is real geometry with separate rigid pieces. There is NO skin, skeleton, or animation.

## Files
- Obsidian_West.glb: neutral model with named meshes, nested joint transforms, material colors, and emissive accents.
- Obsidian_West_assembly.obj + materials.mtl: neutral world-positioned multipart OBJ. OBJ has no pivot or parent metadata.
- parts/*.obj + parts/materials.mtl: individual joint-local meshes. Every origin is the joint; axes are identical in the neutral pose.
- joints.json: hierarchy, parent-local/world pivots, bounding-box centers/sizes, axes, and triangle counts.
- Motor6D_setup.lua: UNTESTED Roblox Studio setup scaffold for individually imported local OBJ parts.
- Dragon_Color.png + Dragon_Emission.png: compact 384x384 swatch atlases; UVs are included in every mesh. Copies are included in parts/ for MTL resolution.

## Coordinates
Right-handed XYZ, +Y up, +Z forward; feet on Y=0. Uniform design units; one unit can equal one stud.
The GLB hierarchy has zero neutral rotations. All node positions are parent-local pivots.
The OBJ part vertices are joint-local and cannot preserve an origin after an importer recenters them.
The pivot manifest is therefore required for Roblox imports. Do not infer joints from part centers.

## Recommended editable workflow
1. Import the GLB into Blender. All names, separate meshes, node positions, UVs, and a shared atlas material should be present.
2. Inspect the neutral pose, normals, object origins, scale, and the front (+Z) direction.
3. Export FBX with the axis settings matching your Studio import workflow. Do not apply arbitrary axis rotations to individual objects.
4. Use Studio's 3D Importer. Verify that names and individual MeshParts survive. Studio importer behavior must be verified locally.
5. If you prefer direct individual mesh import, use parts/*.obj and the manifest to restore their placement.
6. BACK UP the imported model; select it in Studio and inspect Motor6D_setup.lua before running it in the Command Bar.
7. The scaffold assumes local part OBJ geometry, preserved XYZ orientation, and recenters each mesh using its known bounding box.
8. Confirm sizes/orientation first. The scaffold deliberately replaces size, CFrame and PivotOffset, disables collisions and anchors Torso.
9. Animate Motor6D.Transform. Confirm each joint manually; unanchor Torso only when a physics/game controller is ready.
10. Upload Dragon_Color.png to Roblox and assign its asset URI as TextureID on each MeshPart (or a SurfaceAppearance ColorMap) if not imported automatically. Use white MeshPart Color so it does not tint the texture.
11. Add simplified collision, game scripts, LODs, and animation as separate work.

## Material limitations
Exports use ONE shared UV color atlas material per part, rather than relying on multi-material MeshPart imports. No photographic texture is needed.
GLB embeds both color and emission maps. OBJ/MTL emission support varies.
The PNG color atlas can be assigned to Roblox MeshPart.TextureID or SurfaceAppearance.ColorMap after upload.
Roblox will not automatically reproduce the GLB emissive look; ordinary color textures do not create glow.
True glowing fissures would need a supported emissive workflow or separate Neon overlays in Studio. Such overlays are not supplied.
The shared material approximates the source's per-surface roughness. Verify texture orientation and lighting after import.

## Rigging limitations
This is a rigid-piece rigging layout, not a certified working Roblox rig. Studio was not available for testing.
Each wing bone and membrane is individually named. Membranes are rigid panels parented to corresponding fingers;
large independent finger movements can separate neighboring panels. Keep wing fingers mostly aligned or add skinning in Blender.
The neutral pose is wider and grounded compared with the flying reference. A flight study is only a browser preview, never an export.
The source image contains occluded details; silhouette and armor are approximations.
