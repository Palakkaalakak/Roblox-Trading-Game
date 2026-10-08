# Dragon (reworked) VFX reference

Personal reference for recreating the reworked Dragon fruit look in Studio. Local study material only; do not publish.

Sources (YouTube):
- A: "NEW Dragon Fruit FULL SHOWCASE!" (credit: GamerRobot), 5:25 - Hybrid + East transforms.
- B: "Eastern And Western dragon ... Showcase along with hybrid form" (XO3j1vVj7vo), 9:32 - labeled sections (HYBRID, EASTERN from ~4:05, WESTERN from ~6:40). Source of the verified West transform.

## Clips (`clips/`)
| File | Source | Time | What it shows |
|---|---|---|---|
| transform_hybrid.mp4 | A | 1:44-1:54 | Hybrid transform: white-out flash, black splat, flame burst, pink/orange fire |
| transform_full_dragon.mp4 | A | 2:01-2:16 | EAST-style transform: pink-flame charge, red pillar of light, giant red ring in sky, serpent coils out |
| transform_west_REAL.mp4 | B | 6:43-6:59 | WEST transform (verified, see below) |

## West transform beat sheet (B, ~6:52-6:55, about 2.7s)
0. Idle: Fury bar cycles colors while the character stands still, then a yellow-orange starburst of shards flashes at the character.
1. (0.0-1.0s) A black hemisphere dome appears and grows from small to huge. Orange/yellow glowing ring bands orbit it horizontally. Magenta/pink wisps and thin orange streak lines sweep around it.
2. (1.0-1.7s) Rings fade. The dome surface cracks with orange lava lines and turns dark red. Thick yellow light-ray spikes shoot upward and outward from it.
3. (1.7-2.7s) White-out flash with black ink splat, then an orange fireball explosion. Black debris chunks fly out, embers and a ring of fire spread along the ground. The winged dragon is revealed standing in fire.

## West transform, full effect inventory (8fps analysis of source B, 6:51-6:56)
1. Camera punch-in + huge red/orange/yellow shard flash, white triangular shard.
2. Ground bullseye half-disc (red outer, yellow ring, black dot) + orange lightning lines on the ground.
3. Wide orange ribbon tendrils spiraling around the dome the whole time; magenta wisps; purple diamond shards.
4. Matte black dome, 2-3 thick yellow bands (orange edges) + halo ring on top; pink/purple swirl at base.
5. Thin diagonal orange/pink lines across the dome; red vertical streaks.
6. Black spiky shards flying.
7. Dome crackle: orange embers, jagged lava cracks growing, flame wisps hugging the surface.
8. Thick yellow cone rays with orange outlines.
9. Dome flashes solid yellow.
10. Explosion: white-out + black smoke chunks, cel orange/yellow fire, black spiky shards, dark navy debris cubes.
11. Red-orange lava fire ring on the ground with yellow flame tongues; dragon appears inside.
12. Tail (~2s): debris cubes, embers, pink sparks.
Colors: yellow (255,214,20), orange (255,118,0), red (235,35,15), pink (255,40,190).

## Frame sheets (`frames/`)
- `west_transform_6fps_1-3.jpg`: B, 6:47-6:55, one tile per 1/6s, 4x4, row-major. Sheet 3 is the actual burst.
- `east_transform_8fps_1-4.jpg`: A, 2:06-2:14, one tile per 0.125s.
- `overview_1fps_1-4.jpg`: A, 1:36-2:40, one tile per 1s.
- `west_form_4fps_1-4.jpg`: A, 4:03-4:19. NOT a transformation: East dragon flying, a fireball blast, then a lava-cracked West-form dragon.
- `sheet_1-4.jpg`: A whole video, one tile per 6s.

## Known gaps
- Frames are stills. Timing is inferred from tile spacing, not live playback.
- Exact flipbook textures and mesh shapes of the dome are not extractable; they will be rebuilt, not copied.
