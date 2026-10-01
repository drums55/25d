# Art pipeline (AI-generated)

All art is AI-generated; nothing here is hand-drawn. Until real art lands the
game uses procedural placeholders (coloured polygons), so every slot below is
optional and can be filled one at a time.

## Characters = cut-out parts (not sprite sheets)

AI cannot keep a character consistent across many animation frames, so each
character is ONE design split into separate PNGs that a Skeleton2D rig moves
(`scenes/characters/cutout_rig.tscn`, `scripts/player/cutout_rig.gd`).

Per character, folder `assets/art/characters/<name>/`:

| file | content | joint (pivot) |
|---|---|---|
| `head.png` | head, facing camera / 3-4 view right | neck (bottom centre) |
| `torso.png` | chest + hips | hips (bottom centre) |
| `arm_l.png`, `arm_r.png` | whole arm incl. hand | shoulder (top centre) |
| `leg_l.png`, `leg_r.png` | whole leg incl. foot | hip joint (top centre) |
| `head_back.png`, `torso_back.png` | optional back views | same |

Rules for prompts / output:
- Transparent background PNG, same light direction (top-left) for all parts.
- Character faces **right / 3-4 right**; left is mirrored in code.
- Scale: whole character ~ 150-180 px tall at 1920x1200 (feet to top of head).
- Overlap at joints (draw a bit of extra shoulder/hip) so rotation shows no gaps.

Wire-up: create a `CutoutSkin` resource (textures + pivots per part) and set it
on the rig's `skin`; placeholders hide automatically.

## Rooms and props = still images

- Room floor + back walls: one painted image per room, isometric 2:1 (tile
  128x64 px), placed under the room's `Backdrop` node; then set
  `draw_placeholder = false` on the IsoRoom.
- Props (pillar, crate...): one PNG each, origin at the footprint centre
  (where it touches the floor) so Y-sort works; keep the placeholder
  footprint for collision.
