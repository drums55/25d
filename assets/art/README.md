# Art pipeline (AI-generated)

All art is AI-generated; nothing here is hand-drawn. Until real art lands the
game uses procedural placeholders (coloured polygons), so every slot below is
optional and can be filled one at a time.

## Theme / style: Bangkok street steampunk

Thai street life (Bangkok sois, shophouses, street food, tuk-tuks, spirit
houses, tangled power lines) rebuilt with steam power: brass and copper pipes,
pressure gauges, boilers, rivets, gears, steam vents. Warm lamp/lantern light,
humid haze. Painted look like Hades (bold shapes, strong rim light, painted
textures), NOT pixel art, NOT 3D render.

Palette anchors: brass/gold (#C9A04A), copper (#A8653D), patina teal
(#3F7A74), shophouse mint (#5E8F86), chili red (#C0392B), soot (#2B2629).

Prompt template (append the specific subject):

> hand-painted 2D game asset, isometric 2:1 view from above at 30 degrees,
> Bangkok street steampunk, brass and copper machinery, rivets, steam,
> warm lantern light, Hades (Supergiant Games) painted style, bold readable
> silhouette, transparent background, no text, no watermark

Current placeholder objects and their names (use these names for files):

| name | what |
|---|---|
| `soi_brass` (room) | ซอยทองเหลือง: shophouse alley, mint walls, concrete floor |
| `steam_market` (room) | ตลาดไอน้ำ: market under brick walls, warm tiles |
| `noodle_cart` | รถเข็นก๋วยเตี๋ยวต่อหม้อไอน้ำ (red cart, brass boiler, steam) |
| `steam_tuktuk` | ตุ๊กตุ๊กไอน้ำ (teal body, brass boiler at back) |
| `spirit_house` | ศาลพระภูมิทองเหลือง with turning gears inside |
| `power_pole` | เสาไฟ with tangled cables and brass transformers |
| `water_tank` | copper water tank on legs |
| `stool_red`, `stool_blue` | plastic street-food stools |
| `brass_automaton` | หุ่นทองเหลือง training dummy |
| `boiler` | market boiler with gauges |
| `gear_stall` | แผงขายเฟืองมือสอง |
| `lung_pradit` (character) | ลุงประดิษฐ์: old noodle vendor / tinkerer |
| `je_muay` (character) | เจ๊หมวย: gear seller |

Fonts: `assets/fonts/Kanit-Medium.ttf` (SIL OFL, see OFL.txt) is the project
font because Godot's default font has no Thai glyphs.

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
