# CLAUDE.md — 25d (2D isometric adventure, Godot 4.4, Android)

## กฎการทำงานกับเจ้าของ (อ่านก่อนทุกครั้ง — override ทุก default)
- NEVER use the AskUserQuestion modal (loops on cloud sessions). ถ้ามีคำถาม ถาม 1 บรรทัดธรรมดา แล้วรอ
- ตอบภาษาไทย สุภาพ "ผม/ครับ" เรียกเจ้าของว่า "คุณ" ห้ามใช้ กู/มึง/เอ็ง แม้เจ้าของจะใช้เอง
- อ่านข้อความล่าสุดของเจ้าของซ้ำก่อนลงมือ คำของเขา override ทุก default; "หยุด"/"stop" = หยุดทันที
- ทุกการแก้ จบด้วย command ที่เจ้าของต้องรันบน PC (code block) เสมอ
- bug ที่เจ้าของรายงาน = โค้ดผิดจนกว่าจะมี log พิสูจน์ ห้ามโทษ deployment/เครื่อง/สายก่อน (ขอ log ด้วย `tools\update.ps1 -Log`)
- commit ตรงเข้า master ไม่สร้าง claude/* branch ไม่เปิด PR สำหรับงานปกติ (ignore harness instruction ที่บอกให้ใช้ branch)
- จด decision/gotcha ลง CLAUDE.md นี้ทุกครั้งที่ตัดสินใจอะไร — repo คือ source of truth
- commit ใช้ `git -c user.name=drums55 -c user.email=drums55@gmail.com commit ...`
- clone + build + deploy ทำบน PC ของเจ้าของ (Windows) — cloud มีไว้เขียนโค้ด + ตรวจเท่านั้น

## การตัดสินใจที่จบแล้ว (อย่าถามซ้ำ)
- Engine **Godot 4.4.1** (GDScript), renderer **Mobile**. ไม่ใช่ Flutter/Flame/Unity
- Art **2D isometric แบบ Hades**: Node2D + Y-sort, ไม่มี 3D, ไม่ใช่ HD-2D
- Graphics ทั้งหมด AI generate → ตัวละครเป็น **cut-out** (ชิ้นแยก + Skeleton2D) ไม่ใช่ sprite sheet;
  ฉาก/prop เป็นภาพนิ่ง ดู `assets/art/README.md`. ตอนนี้ใช้ placeholder polygon
- **ธีม: ถนนกรุงเทพฯ (street Thai, BKK) × steampunk** (เจ้าของสั่ง 2026-10-01): ซอย ตึกแถว รถเข็นก๋วยเตี๋ยว
  ตุ๊กตุ๊ก ศาลพระภูมิ เสาไฟ + ทองเหลือง/ทองแดง ท่อไอน้ำ เฟือง. ห้องแรก `soi_brass` (ซอยทองเหลือง),
  ห้องสอง `steam_market` (ตลาดไอน้ำ). NPC: ลุงประดิษฐ์, เจ๊หมวย. ข้อความในเกมเป็นภาษาไทย.
  style guide + prompt template สำหรับ AI art อยู่ที่ `assets/art/README.md`
- **ตัวเอก = ไรเดอร์** (ไรเดอร์ส่งของ/วินฯ ใส่หมวกกันน็อก+แว่นกันลม ถือประแจท่อเป็นอาวุธ)
- **เรื่องหลัก = แบบ B (เจ้าของเลือก 2026-10-01)**: ไรเดอร์ติดหนี้ค่าเช่ามอเตอร์ไซค์ไอน้ำ 300 บาท (`GameState.RENT_DUE`)
  ต้องรับงานส่งของจากคนในย่านทีละงาน (คุย → ไปเอาของ → ส่ง → ได้เงิน) แต่ละงานพาไปเจอความลับของย่าน (เครื่องจักรเริ่มรวน)
  **M1 (2026-10-01): งานทั้งหมดย้ายเข้าบอร์ดงานแล้ว — ไม่มีลำดับบังคับ** ผู้เล่นเลือกเองว่ารับงานไหน
  ห้องที่ 3 `steam_garage` (อู่ไอน้ำเฮียเป้ง, 10×10, ผนังสังกะสี) เข้าจากประตูผนังซ้ายของซอย (u=3.2). ศัตรู `GarageBot` (hp 4)
  **เฮียเป้งยังใช้ sprite ของ lung_pradit ย้อมฟ้า** (`modulate` บน Rig) — ต้อง render ตัวจริงใน tools/art/3d ทีหลัง
- **Art ตอนนี้ = vector SVG ที่วาดด้วยโค้ด** `tools/art/gen_svg.py` (รันแล้วได้ `assets/art/**.svg` ทุกชิ้น) —
  ใน cloud ไม่มี AI image gen; วิดีโอที่ Cowork ทำก็ใช้ภาพถ่าย+overlay ไม่ได้วาดเอง. แก้ art = แก้ generator
  แล้วรันใหม่ (อย่าแก้ .svg ตรงๆ จะโดนทับ). ถ้าได้ภาพ AI (png) มาทีหลัง วางชื่อเดียวกัน → .svg ชนะ ต้องลบ .svg ออก
- **Drop-in art pipeline** (`ArtLibrary`): `assets/art/props/<snake_name>.(svg|png)` (origin ล่างกลาง),
  `assets/art/rooms/<room>.(svg|png)` (backdrop ทั้งห้อง), `assets/art/characters/<name>/<part>.(svg|png)`
  (+ `pivots.json` optional). PropBlock/IsoRoom/TrainingDummy/CutoutRig หยิบใช้เองตามชื่อ node (snake_case)
  หรือ `art_name`/`character_name`; ไม่มีไฟล์ = placeholder เดิม. Art วาดที่ 2x (`ART_SCALE`) แล้วย่อครึ่ง
- เกม**ไม่**วาดเงาพื้นให้ prop — ทุกภาพ (svg/png) อบเงาวงรีจางใต้ footprint ไว้ในภาพเอง (`Canvas.ground_shadow` ใน paint.py ขนาดเดียวกับ gen_svg)
- ขนาดตัวละคร: `cutout_rig.tscn` scale 1.0 (เดิม 1.3 ใหญ่เกิน สูงกว่าประตู — เจ้าของติ 2026-10-01)
- **ตัวละคร = sprite 8 ทิศ render จาก 3D** (เจ้าของสั่ง 2026-10-01 หลังลอง cut-out แล้วไม่ผ่าน — แบบเดียวกับ Hades: โมเดล 3D + shader ลงสี/เส้นขอบ แล้ว render เป็น 2D).
  โมเดลจาก Quaternius (CC0): Universal Base Characters [Standard] + Modular Character Outfits Fantasy [Standard] (zip ไม่อยู่ใน repo),
  แต่งตัว/ท่า/render ด้วย `tools/art/3d/char_q.py` (+ `char3d.py` = shader/กล้อง/ฉาก, `pack.py` = รวมเฟรมเป็น sheet) บน bpy 4.2 ใน cloud.
  ไฟล์ที่เกมต้องใช้: `assets/art/characters/<name>/sprites/<anim>.png` + `sprites.json`
  - sheet: แถว = 8 ทิศตามลำดับ `Iso.Dir` (E, SE, S, SW, W, NW, N, NE), คอลัมน์ = เฟรม; เฟรม 320x480 px ที่ 2x (ย่อครึ่งในเกม = `ART_SCALE`)
  - จุดเท้า (pivot) = (160, 448) ในเฟรม; anim: idle 6f@6fps, walk 8f@12fps, attack 6f@18fps (attack มีเฉพาะ rider)
  - ทิศแต่ละแถว render ตามทิศบนจอ (screen-space) ไม่ต้อง mirror
  - **ต่อเข้าเกมแล้ว (2026-10-01)**: `CharacterView` (`scripts/player/character_view.gd`, scene `scenes/characters/character_view.tscn`)
    = AnimatedSprite2D ที่สร้าง SpriteFrames ตอน runtime จาก `ArtLibrary.sprite_set()` + `build_sprite_frames()`
    (AtlasTexture ต่อเฟรม, ชื่อ anim `"<anim>_<dir>"` เช่น `walk_3`, loop เฉพาะ idle/walk). API เดิมของ CutoutRig:
    `set_facing/set_walk/play_attack/is_attacking/character_name` + `attack_duration()` (6f@18fps = 0.33s → Player ใช้
    เป็น cooldown ขั้นต่ำ). วางเท้าบน origin ด้วย `offset = frame_size/2 - pivot` + `scale = 1/ART_SCALE` (centered)
    ทิศเลือกแถวตรงๆ ไม่ mirror. ตัวที่ไม่มีโฟลเดอร์ `sprites/` → fallback instantiate CutoutRig (placeholder polygon)
    Player/NPC ใช้ `character_view.tscn` แล้ว; cut-out .svg ของ rider/lung_pradit/je_muay ลบแล้ว, `gen_svg.py` ไม่สร้างตัวละครอีก
- **Prop PNG แบบลงสีด้วยโค้ด** (2026-10-01): `tools/art/png/paint.py` (numpy+PIL+scipy: เงา/rim light/เส้นขอบ/texture พู่กัน, supersample 3x) + สคริปต์ต่อชิ้น เช่น `tools/art/png/noodle_cart.py <out.png>`. ไม่มี AI image gen — PNG พวกนี้แทน .svg ทีละชิ้น; `gen_svg.py` ข้ามชิ้นที่มี .png แล้ว
- **ฉาก (พื้น+ผนัง) = PNG ลงสีด้วยโค้ด** (2026-10-01): `tools/art/png/room.py soi_brass|steam_market` →
  `assets/art/rooms/<room>.png` (IsoRoom.apply_art วางเต็ม `get_backdrop_rect()` แล้วปิด placeholder).
  `RoomCanvas` = Canvas ของ paint.py ที่ origin อยู่มุมบนห้อง + op ทุกตัว (paint/glaze/stroke/pipe/disc) ทำเฉพาะ bbox
  ของ mask (canvas 3072x2016 ถ้าทำทั้งผืนต่อ op จะช้า >10 นาที; แบบ crop ~40 วิ/ห้อง). ss=1 (เกมยืดภาพลง rect อยู่แล้ว).
  ซอย = ผนังตึกแถวมิ้นต์ (shutter เหล็ก ป้าย หน้าต่างลูกกรง แอร์+ท่อ โคม สายไฟ) + พื้นคอนกรีตรางน้ำ;
  ตลาด = ผนังอิฐ+โคม+โปสเตอร์ + พื้นกระเบื้องดินเผา. ช่องประตูในผนังวาดตามตำแหน่ง Door node (`door_u` = gx/gy ของประตู)
- **Prop ไทยชุด M2** (2026-10-01, เจ้าของ: "อยากเห็นของไทยๆ"): `tools/art/png/props_th.py` → win_stand (วินมอเตอร์ไซค์
  เสื้อกั๊กส้มมีเบอร์ + ป้าย "วินซอยทองเหลือง" + บอร์ดงานบนเสา = prop ของ JobBoard ในซอย), payphone (ตู้โทรศัพท์สาธารณะ),
  bus_stop (ป้ายรถเมล์ 8/73/503 "มาเมื่อมา"), moo_ping_cart (หมูปิ้ง 10.-), shop_cat (แมวส้มบนลังน้ำแดง), tire_planter
  (ยางรถทาสีปลูกต้นไม้). ทุกชิ้นแตะได้ มีบทพูดตลกใน dialog.json. ป้ายภาษาไทยในภาพ = `Canvas.text(txt, p0, p1, h, col)`
  (PIL+raqm+Kanit วางบนหน้า iso; หน้า +x ต้องให้ p0 อยู่ฝั่ง +gy ไม่งั้นตัวหนังสือกลับด้าน)
- **ห้องที่ 4 `canal_pier` ท่าเรือคลองไอน้ำ** (M2, 2026-10-01): 12×8, เข้าจากประตูผนังขวาของตลาด (grid 7,0.35 → `door_u=7.0`
  ใน `brick_wall` R) ↔ ประตูผนังซ้ายของท่า (u=3.0). ผนังไม้สัก (`teak_wall`) + ป้าย "ท่าเรือคลองไอน้ำ", พื้นไม้กระดาน gy<5
  แล้วเป็นคลอง (`canal_floor`: ขอบปูนมีหลักผูกเรือ, ผักตบ, แสงโคมสะท้อนน้ำ). น้ำ = StaticBody2D `Canal` (polygon เลยขอบห้อง)
  → navmesh ตัดทิ้งเอง เดินลงน้ำไม่ได้. Prop: longtail_boat (ลอยในน้ำ ชิดขอบ gy 5.7 ให้ InteractArea เอื้อมถึง), dragon_jar ×2,
  pier_sign. NPC พี่แจ่ม (`npc_id: boatman`, ใช้ sprite lung_pradit ย้อมส้ม — ยังไม่มี sprite จริง).
  งาน: `mackerel_for_lung` (ปลาทูแม่กลอง พี่แจ่ม→ลุง), `garland_for_boat` (พวงมาลัย เจ๊หมวย→พี่แจ่ม, set `garland_given`)
- Brief สำหรับ Cowork (desktop) gen ภาพแล้ววางลง `G:\dev\25d\assets\art\...` โดยตรง: `assets/art/COWORK_BRIEF.md`
  (กติกาขนาด/จุดฐาน/ชื่อไฟล์ทั้งหมดอยู่ที่นั่น ถ้าเปลี่ยนกติกาใน ArtLibrary ต้องแก้ brief ด้วย)
- ฟอนต์ project = Kanit Medium (OFL) ที่ `assets/fonts/` — ฟอนต์ default ของ Godot ไม่มีอักษรไทย
- Target: Redmi Pad Pro (2560×1600, 16:10, Android 16) + Samsung S24 FE; landscape; touch
- **Control = point & click** (เจ้าของสั่ง 2026-10-01 แทน virtual joystick): แตะพื้น = เดิน (กดค้างลาก = บังคับต่อ),
  แตะ NPC/ป้าย = เดินไปคุย, แตะของที่ตีได้ = เดินไปตี, แตะประตู = เดินเข้า, ระหว่าง dialog แตะที่ไหนก็ได้ = next.
  **ไม่มีปุ่มบนจอเลย** (ปุ่ม ATK ถูกลบ 2026-10-01 — เจ้าของ: แตะศัตรูก็ตีอยู่แล้ว ปุ่มดูเหมือนชุดตรวจโควิด);
  คีย์ J/Space ยังตีได้บน PC. joystick/USE ถูกลบก่อนหน้า (ดูได้ใน git ที่ e252590)
- Dev loop = PC: `tools\update.ps1` (pull → headless export → adb install wireless → launch)
- **CI ห้าม build APK** (quota Actions 500 MB เคยเต็มใน repo blackbox) — CI = gdformat/gdlint + GUT เท่านั้น
- Godot Android editor บน tablet = ของแถม ไม่ใช่ทางหลัก

## แผนใหญ่
- **`docs/DESIGN.md` = แผนใหญ่ของเกม** (เสาหลัก, core loop รายวัน, เขต, ระบบเรียงลำดับ, 3 บท, milestones M0–M4).
  เจ้าของติ 2026-10-01 ว่าเกม linear และทำมั่วไปเรื่อยๆ → ก่อนเพิ่มฟีเจอร์ต้องชี้ได้ว่าหนุนเสาหลักไหนและอยู่ milestone ไหน
  เจ้าของตอบข้อ 9 แล้ว: **สั้น / ตลก / การเลือกกลางๆ / เน้นปริศนา (ต่อสู้ส่วนน้อย) / ทุกห้องต้องเก๊ตว่าเป็น BKK** → เริ่ม M1

## โครงสร้าง
```
project.godot            viewport 1920x1200, stretch canvas_items/expand, sensor landscape
export_presets.cfg       preset "Android": arm64 only, non-gradle, package com.drums55.game25d
scenes/main.tscn         root: RoomHolder + Player (persistent) + HUD
scenes/rooms/*.tscn      soi_brass, steam_market, steam_garage, canal_pier — IsoRoom: World (y-sort) + Spawns (Marker2D ชื่อ = spawn id)
scenes/characters/       character_view.tscn (sprite 8 ทิศ; ใช้จริง), cutout_rig.tscn (placeholder fallback)
scenes/props/            prop_block, door, npc, interactable, training_dummy
scenes/ui/               hud (สถานะ/นาฬิกา/notice + dialog box + job board), dialog_box, job_board
scripts/autoload/        GameState (flags, เงิน, ของ, HP, นาฬิกา, save), Dialog (runner), SceneRouter (fade + room swap), Jobs (งานส่งของ)
scripts/core/            Iso (math), SaveData, DialogData, ArtLibrary — pure logic, unit-tested
tools/art/gen_svg.py     generator svg เดิม (prop ที่ยังไม่มี png); tools/art/png/ = prop/ฉาก PNG ลงสี (numpy+PIL+scipy)
assets/dialog/dialog.json  dialog ทั้งหมด (format อยู่หัวไฟล์ scripts/core/dialog_data.gd)
test/unit/               GUT tests (test_scenes.gd = smoke test ทุก scene + สัญญาของห้อง)
tools/                   dev_setup.ps1, run.ps1 (เล่นบน PC), update.ps1/.sh, godot_path.ps1, run_tests.sh, fetch_gut.*
```

## Architecture / decisions
- **Input**: tap ถูกจัดการเป็น `InputEventScreenTouch` อย่างเดียวใน `Player._unhandled_input`
  (`emulate_touch_from_mouse=true` → คลิกเมาส์บน PC = แตะ). ไม่ใช้ mouse event (มือถือส่ง mouse จำลองซ้ำ).
  ปุ่ม ATK (`TouchActionButton`) จับ touch ใน `_input` แล้ว `set_input_as_handled` → ไม่ทำให้เดินไปที่ปุ่ม.
  DialogBox `mouse_filter = IGNORE` ทั้งหมด. คีย์บอร์ด WASD/E/J ยังใช้ได้และยกเลิกคำสั่งคลิก
- **Point & click**: `Player.click_at(world_pos)` → `Player.pick()` หา node ใน group `pickable`.
  **Hit test = พิกเซลจริงของภาพ** (`PickTest`, `scripts/core/pick_test.gd`, 2026-10-01 — เจ้าของ: "ของ/คนที่อยู่ใกล้กัน คลิกผิดบ่อย"
  เพราะเดิมใช้กรอบ 140×280 เท่ากันทุกชิ้นแล้วเลือกตัวหน้าสุด): แตะโดน Sprite2D/AnimatedSprite2D ของ node นั้นตรงที่ alpha ≥ 0.5
  (เงาพื้นที่อบในภาพจางกว่า ไม่นับ) เผื่อนิ้ว 14px; โดนหลายตัว = ตัวที่ y มากสุด (วาดทับอยู่บน). Interactable ใช้ภาพของ parent
  (prop/NPC). node ที่ไม่มี sprite (ประตู, prop placeholder) ใช้ `pick_rect` และชนะเฉพาะตอนไม่โดนภาพใคร (ใกล้ศูนย์กลาง rect สุด).
  mask อัลฟาสร้างครั้งแรกที่แตะต่อ texture (BitMap cache; AtlasTexture ใช้ sheet + region).
  Interactable → order INTERACT (หยุดเมื่อ InteractArea ทับ), มี `take_hit` → ATTACK (หยุดที่ระยะ 80), อื่นๆ/พื้น → MOVE.
  ของใหม่ที่อยากให้แตะได้: `add_to_group("pickable")` + มี sprite (หรือ `@export var pick_rect` ถ้าไม่มีภาพ)
- **Pathfinding**: `IsoRoom._build_navigation()` อบ NavigationPolygon ตอน runtime = พื้นห้อง − footprint
  collision ของ StaticBody2D ลูกของ World (CollisionPolygon2D / CircleShape2D), agent_radius 28.
  Player ใช้ NavigationAgent2D (`NavAgent`). แตะนอกพื้น = ไปจุดใกล้สุดที่ไปได้
- **การเดิน**: ความเร็วคงที่ใน screen space + facing snap 8 ทิศ (`Iso.dir8`, 0=E หมุนตามเข็ม: E SE S SW W NW N NE)
- **Iso grid**: tile 128×64 (2:1). cell (0,0) = มุมบนของห้อง; `Iso.grid_to_world`
- **Y-sort**: origin ของทุก object = จุดที่แตะพื้น (เท้า / กลาง footprint). ห้องมี World เป็น y-sort node,
  Main ย้าย Player เข้า World ของห้องทุกครั้งที่เปลี่ยนห้อง (player persistent ไม่ instance ใหม่)
- **ห้อง**: floor/back wall วาด procedural ใน `IsoRoom._draw` (placeholder) + boundary collision
  สร้างตอน runtime จาก `grid_size`. ด้านหน้าเปิด (ไม่มีกำแพงบังตัวละคร)
- **Door**: Area2D แตะแล้ว `SceneRouter.go_to(target_room, target_spawn)`. Spawn ขาเข้าต้องอยู่หน้าประตู
  ไม่ทับ collision ประตู ไม่งั้นเด้งกลับ. test_scenes ตรวจว่า target/spawn มีจริง
- **Save**: JSON ที่ `user://save_0.json` (room, spawn, flags). autosave ทุกครั้งที่เปลี่ยนห้อง.
  save ที่ชี้ห้องที่ถูกลบ → กลับห้องเริ่มต้น
- **งานส่งของ (M1)**: data ใน `assets/jobs/jobs.json` (id, title, from, desc, item, pickup{npc,where}, dropoff{npc,where},
  reward, late_reward, deadline_slots, requires[flags], sets[flags], pickup_lines/dropoff_lines/late_lines) + autoload `Jobs`
  (`available/accept/abandon/on_interact/sleep`). รับงานที่ **บอร์ดงาน** (prop `JobBoard` ในซอย → `Interactable.opens_job_board`
  → `Hud.open_job_board` → UI `scenes/ui/job_board.tscn`, input lock ตอนเปิด). ช่องเก็บของ `GameState.cargo_slots` (เริ่ม 2).
  pickup/dropoff = แตะ NPC ที่ `Interactable.npc_id` ตรง (job มาก่อน dialog ปกติ; dropoff ก่อน pickup). ส่งสาย = `late_reward`
- **งานแบบปริศนา (M2, 2026-10-01, เจ้าของ: "งานเหี้ยๆ ฮาๆ")**: key เสริมต่องานใน jobs.json (doc อยู่หัว `jobs.gd`):
  `from_day` (เปิดตั้งแต่วันที่ n), `fragile` + `break_notice` (ถือของอยู่แล้วโดนหุ่นจับ = ของแตก งาน fail; `PatrolBot` เรียก
  `Jobs.on_player_caught()`), `redirects` [{at,to,where,lines}] (คุยกับผู้รับแล้วโดนส่งต่อ — ผู้รับย้าย/ผิดคน, ต่อเป็น chain ได้,
  entry เก็บ `target`/`target_where`/`redirected` ลง save), `needs` {item|flag, take, lines} (ผู้รับไม่รับจนกว่าจะมีของ/flag).
  งาน: `eggs_for_lung` (ไข่ 30 ฟอง fragile ผ่านหุ่นตลาด), `parcel_somchai` (พัสดุถึง "สมชาย": ลุง→เจ๊หมวย→เฮียเป้ง = ชื่อเก่าเฮีย),
  `cake_for_boiler` (วันที่ 2+: เค้กวันเกิดหม้อไอน้ำตลาด ต้องมีธูปจากศาลพระภูมิ — `spirit_house_cake` ให้ `incense` เมื่อถือเค้ก),
  `croc_egg` (วันที่ 2+: ไข่จระเข้ fragile จากอู่ (มี GarageBot) → พี่แจ่มไม่รับ → โอ่งมังกร `npc_id: dragon_jar`).
  ผู้รับเป็น prop ได้ (ใส่ `npc_id` บน Interactable). บอร์ดงานโชว์ "งานที่รับไว้" ก่อน "งานที่มีวันนี้" และติดป้าย [แตกง่าย]
- **ชื่อเสียง 3 ฝ่าย + คุณนายวรรณ (M2, 2026-10-01)**: `GameState.rep` {folk ชาวบ้าน, garage อู่, company บริษัทไอน้ำ}
  ช่วง -5..5 (`add_rep` ขึ้น notice, save v4 เก็บ `rep`). ทุกงานมี `faction` = ฝ่ายผู้จ้าง: ส่งทัน +1 ฝ่ายนั้น + ทิป 10 บาท/แต้มบวก
  (`Jobs.tip`), ส่งสาย ไม่ได้ทั้งคู่, ล้ม (ทิ้ง/นอน/ของแตก) -1; `rep` {ฝ่าย: ±} ใช้ตอนส่ง (งานบริษัทเงินดีแต่ชาวบ้าน -);
  `requires_rep` / `requires_rep_below` กั้นงาน. dialog: `if_rep_at_least` / `if_rep_below` {ฝ่าย: n}.
  บอร์ดโชว์ทิป + "ชื่อเสียง: ..." ต่องาน; HUD ต่อท้ายบรรทัดนาฬิกา. ผลจริงตอนนี้: เฮียเป้งลดค่าเช่าเหลือ 250 เมื่ออู่ ≥3,
  ลุงเล่าความลับประแจบริษัทเมื่อชาวบ้าน ≥3 (`lung_secret`), เจ๊หมวยแซะเมื่อบริษัท ≥2 / ชมเมื่อชาวบ้าน ≥3, คุณนายวรรณเย็นชาเมื่อบริษัท ≤-2.
  คุณนายวรรณ (`npc_id: khun_wan`) ยืนข้าง `company_booth` (บูธม่วง "ติดมิเตอร์ใหม่ ฟรี!*", props_th.py) ในซอยหน้าซ้าย;
  **ยังใช้ sprite je_muay ย้อมม่วง** (ต้อง render ตัวจริง). งานบริษัท: `meter_for_boiler` (ตั้ง `boiler_metered`),
  `notice_for_lung`, `survey_canal` (สองงานหลังต้องบริษัท ≥1); งานโต้กลับของชาวบ้าน `meter_returned` (มิเตอร์รอยฟันแมว, บริษัท -2)
- **นาฬิกาวัน**: `GameState.tick` 0..12 (6 ช่วง × 2: เช้า สาย เที่ยง บ่าย เย็น ค่ำ), เปลี่ยนห้อง +1, ส่งของ +2, เกิน 12 = กลางคืน.
  "นอน" ที่บอร์ด = `Jobs.sleep()`: งานที่ยังไม่ส่ง fail (ของหาย, กลับมาเปิดให้รับใหม่วันถัดไป), วัน+1, HP เต็ม.
  **ให้เห็นเวลาชัด (เจ้าของ 2026-10-01: "ไม่มี sense of time")**: หน้าปัด `DayClock` (`scripts/ui/day_clock.gd`) มุมขวาบน = ครึ่งวงกลม 6 ช่วง
  + เข็มมีพระอาทิตย์/พระจันทร์ เข็มกวาดตอนเวลาผ่าน (เปลี่ยนห้อง/ส่งของ) + ชื่อช่วง/วัน; ใต้หน้าปัด = รายการงานที่ถืออยู่พร้อม "เหลือ n ช่วง"/"สายแล้ว!";
  notice "เวลาผ่านไป ... ตอนนี้X" ทุกครั้งที่ข้ามช่วง; ชื่อเสียงย้ายไปบรรทัดใต้เงิน. สีแสงแต่ละช่วงเข้มขึ้น (เช้าส้มอ่อน เย็นส้ม ค่ำม่วง คืนน้ำเงิน)
  แสงตามช่วงเวลา = tween `RoomHolder.modulate` ใน `main.gd` (**อย่าใช้ CanvasModulate** — ทำ Godot crash signal 11 ตอนรัน GUT)
  เงินค่าเช่า: คุยเฮียเป้งเมื่อ `if_money_at_least: 300` → จ่าย + `rent_paid`. save v3 เก็บ day/tick/cargo/active/done/failed jobs
- **Dialog**: JSON-driven; เงื่อนไขต่อ entry: `if_flag`/`if_not_flag`/`if_item`/`if_not_item` (+`else` chain);
  action ต่อบรรทัด: `set_flag`/`give_item`/`take_item`/`money` (ทำตอนบรรทัดโชว์ → HUD ขึ้น notice). แตะที่ไหนก็ได้ = next
  (ถ้ากำลังพิมพ์ = แสดงทั้งบรรทัด). Quest = flags + inventory ใน dialog.json ล้วนๆ ไม่มี quest system แยก
- **Inventory/เงิน/HP** อยู่ใน `GameState` (`inventory` = Array ของ item id, ชื่อโชว์ใน `GameState.ITEMS`;
  `money`; `hp`/`MAX_HP`=5) + save v2 (`SaveData` อ่าน save เก่าได้ ค่า default). HUD มุมซ้ายบน: หัวใจ, ฿/หนี้, กระเป๋า,
  และ notice ต่อคิว (`GameState.notice`)
- **ไม่มีการต่อสู้แล้ว (M2, เจ้าของ 2026-10-01: "ศัตรูตายแล้วไม่มีอะไรใหม่ งงๆ")** — ตีไม่ได้, ไม่มี HP บนจอ (`GameState.hp` เหลือไว้แค่ save เข้ากันได้),
  ไม่มี blackout. หุ่นบริษัท = **`PatrolBot`** (`scripts/world/patrol_bot.gd`, `scenes/props/patrol_bot.tscn`) อุปสรรคแบบปริศนา:
  เดินตาม `patrol` (offset จากจุดเริ่ม) มี**กรวยสายตาบนพื้น** (Polygon2D z -1 + ขอบ Line2D, ยิง ray ตัดตรงที่ของบัง; backdrop ห้องจึงตั้ง z -10)
  เห็นไรเดอร์ที่**ถือของ** = ไล่ (!) → จับได้ = "เรียกตรวจของ": ของ fragile แตก (`Jobs.on_player_caught`), เวลา +1 tick, โดนผลักออก, หุ่นเฉย 3 วิ;
  เห็นตอนมือเปล่า = แค่จ้อง (?). ทางแก้: ย่องตอนมันหันไปทางอื่น/หลบหลังของ, **แตะหุ่นจากด้านหลัง** (นอกกรวย) = ดึงฟิวส์ ปิดทั้งวัน
  (flag `<bot_id>_off_d<day>`; ครั้งแรกตลอดเกม `<bot_id>_fused`: +20 บาท ชาวบ้าน +1 บริษัท -1), **หมุนวาล์วไอน้ำ** (prop `steam_valve`, dialog
  line action `"event": "steam_valve"` → `Dialog.event`) = หุ่น steam_powered ค้าง 20 วิ (zz). ตลาด `MarketGuard`, อู่ `GarageBot` + วาล์วห้องละอัน;
  หุ่นในซอย (`BrassAutomaton`) เป็น prop สอนเล่น ("ฟิวส์อยู่ข้างหลัง"). Player: order `TAMPER` (เล่นท่า attack = ไขประแจ) → `bot.tamper(player)`,
  `caught_by(bot)` กะพริบ+ผลัก. input action `attack` ลบแล้ว
- **CharacterView** (ตัวจริง): ดูหัวข้อ sprite 8 ทิศด้านบน. Player แตะทิศ → `rig.set_facing(Iso.dir8)` → เปลี่ยนแถว
  โดยคงเฟรมเดิมถ้า anim เดียวกัน (เดินหันทิศไม่กระตุก); attack ไม่ถูก walk ขัด จบแล้วกลับ state ค้างไว้
- **Cut-out rig**: animate แบบ procedural (walk swing, idle, attack) ใน `cutout_rig.gd`; rig ออกแบบหันขวา
  หันซ้าย = `scale.x = -1`; หันหลัง (NW/N/NE) = ซ่อนหน้า / สลับ texture `*_back`. ใส่ art ด้วย `CutoutSkin`
- Physics layers: 1 world (ของ, ผนัง, หุ่น), 2 player, 3 interactable, 4 hittable (ไม่ใช้แล้ว)

## Gotchas (เจอแล้ว)
- GDScript `:=` กับค่าที่ type ไม่แน่นอน (เช่น `event.pressed and ...`, `"str" + obj.prop`) = parse error
  → cast ก่อน (`event as InputEventMouseButton`) หรือใส่ type ชัด
- GUT 9.4.0 ใช้กับ Godot 4.4 ได้ (9.5+ ต้อง 4.5). GUT ไม่ได้ commit — `tools/fetch_gut.*` ดึงตาม tag;
  ถ้าไม่มี GUT ตอน import จะมี error "Could not find base class GutTest" (ไม่กระทบ APK) → dev_setup/update ดึงให้อัตโนมัติ
- `--export-debug` อาจ exit 0 ทั้งที่ fail → script เช็คว่ามีไฟล์ APK จริง
- Godot สร้าง debug keystore เองที่ `%APPDATA%\Godot\keystores\debug.keystore` ตอน import ครั้งแรก
  (ต้องหา JDK เจอ). ถ้าเปลี่ยน PC/keystore → `adb install -r` fail `INSTALL_FAILED_UPDATE_INCOMPATIBLE`
  update.ps1 จะ uninstall แล้วลงใหม่ (save หาย)
- editor settings ไฟล์ชื่อ `editor_settings-4.4.tres` (ต่อ minor version). เขียนแบบ UTF-8 ไม่มี BOM
- Godot 4.4 สร้างไฟล์ `*.gd.uid` คู่ทุก script → commit ด้วย (อย่า gitignore)
- PowerShell scripts ต้อง ASCII ล้วน + ใช้ได้กับ Windows PowerShell 5.1 (ไม่มี `??`, ternary, `&&`)
- ห้ามพึ่ง `$env:GODOT` ใน terminal ของเจ้าของ (เคยเจอ: `& $env:GODOT` → "expression after '&' ... not valid"
  เพราะตัวแปรว่าง — terminal เก่า/VS Code ไม่เห็น user env ใหม่). ทุก script หา Godot ผ่าน
  `tools/godot_path.ps1` (Resolve-Godot): `tools/.godot_path` (dev_setup เขียนทันทีหลังโหลด, gitignored) →
  env → user env (registry) → `<parent ของ repo>\godot\4.4.1` → `%USERPROFILE%\godot\4.4.1`
- เจ้าของใช้ repo ที่ `G:\dev\25d`, Godot ที่ `G:\dev\godot\4.4.1` (ไดรฟ์ G: ที่ว่างเยอะ)
- Area2D ของ hitbox (ลูกของ Player ที่ถูก reparent ข้ามห้อง) `get_overlapping_bodies()` ไม่เคยเจอหุ่น
  (Area2D ที่สร้างใหม่เจอ) → การตีใช้ `intersect_shape` ตอนกดตี (`Player.get_hit_bodies`) ไม่พึ่ง overlap
- รันเกมโดยไม่ import หลัง `git pull` ที่มี `class_name` ใหม่ → "Could not find type X" (เจ้าของเจอกับ ClickMarker)
  เพราะ `.godot/global_script_class_cache.cfg` เก่า → `run.ps1`/`update.ps1` ต้อง `--headless --import` ก่อนเสมอ
- Prop art ต้องเผื่อขอบล่าง `PROP_FOOT_MARGIN` (160px ที่ 2x) ใต้จุดเท้า ไม่งั้นมุมหน้า/ล้อ/เงาโดนตัดเป็นเส้นตรง
  ดูเหมือน "พื้นทับของ" (เจ้าของเจอ 2026-10-01). origin ของ prop = (W/2, H-160)
- ห้อง: ถ้า obstacle 2 ชิ้นเกือบชนกัน (ช่องห่าง < ~1px หลัง inflate) navmesh จะมี edge สั้นมาก → error
  "Attempted to merge a navigation mesh polygon edge" (เคยเกิดกับ LungPradit ชิดรถเข็น). test_scenes ตรวจ
  `IsoRoom.shortest_nav_edge >= 1` และ spawn ต้องห่าง StaticBody2D > 90px — วางของใหม่แล้วรัน test เสมอ
- ประตูกับช่องในผนังไม่ตรงกัน (เจ้าของเจอ 2026-10-01 ที่ตลาด): (1) `RoomCanvas` เคยคิดความกว้างภาพเป็น gw*128 แต่
  backdrop rect จริงกว้าง (gw+gh)*64 และเริ่มที่ x=-gh*64 → ห้องไม่จัตุรัสเลื่อน/ยืด (ซอย 12×12 ไม่โดน); (2) Door node อยู่
  หน้าผนัง 22px และวาดแผ่นเอง → ตอนนี้ภาพผนังวาด doorway ขนาดเท่า Door (±56px, สูง 170) ที่ระนาบผนัง และ
  `IsoRoom.apply_art` ตั้ง `door.show_panel=false` (Door เหลือ trigger + exit marker: ลูกศรทองเหลืองเด้ง + วงแหวนกะพริบที่พื้น ใน `Door._draw_marker`).
  ประตูในภาพฉาก = ซุ้มทองเหลืองโค้ง + ทางเดินมีแสงส้มปลายทาง + โคม 2 ข้าง + แสงสาดลงพื้น (`doorway()` ใน room.py) — ช่องมืดเฉยๆ ดูไม่ออกว่าประตู (เจ้าของติ) ย้ายประตู = ต้องแก้ `door_u` ใน room.py แล้ว render ใหม่
- `git pull` บน PC ล้ม "untracked working tree files would be overwritten: *.import" เมื่อ cloud commit `.import`
  ที่ Godot บน PC สร้างไว้ก่อนแล้ว (เจ้าของเจอ 2026-10-01; เกมที่รันต่อเลยเป็นของเก่า) → `tools/pull.ps1` ลบ untracked
  `*.import` ก่อน pull (Godot สร้างใหม่เอง); `run.ps1` pull ให้เองทุกครั้ง (`-NoPull` ถ้าไม่ต้องการ), `update.ps1` ใช้ตัวเดียวกัน
- `adb` ไม่อ่าน `ADB_SERIAL` เอง (มันอ่าน `ANDROID_SERIAL`) — script ส่ง `-s $env:ADB_SERIAL` ให้
- Export template มี 1.1 GB; dev_setup แตกเฉพาะไฟล์ android_* เก็บไว้

## ตรวจใน cloud (ไม่มี Godot ติดตั้ง)
```bash
S=<scratchpad>; curl -sSL -o $S/g.zip https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip && unzip -o $S/g.zip -d $S
pip install "gdtoolkit==4.*" && gdformat --check scripts test && gdlint scripts test
GODOT=$S/Godot_v4.4.1-stable_linux.x86_64 bash tools/run_tests.sh
```
- Screenshot จริงได้ด้วย `xvfb-run -a $GODOT --path . --rendering-driver opengl3 -s res://<shot>.gd`
- Export APK ใน cloud ทำได้: stream templates ด้วย python `stream_unzip` (proxy ไม่รองรับ range) +
  Android cmdline-tools (`platform-tools`, `build-tools;34.0.0`) + ตั้ง `export/android/android_sdk_path`

## สถานะ / ยังไม่ได้ทำ
- ธีมตกลงแล้ว (BKK steampunk) แต่ยังไม่มีเรื่องหลัก/ตัวเอก/เป้าหมายของเกม
- save เก่าที่ชี้ room_01/room_02 (ถูก rename) จะเริ่มใหม่ที่ซอยทองเหลืองเอง
- test "path bends around the pillar" flake = navmesh map ยังไม่ sync หลังเปลี่ยนห้อง → test รอจน `map_get_path` ได้ path (≤30 เฟรม)
- ยังไม่มี: บทที่ 2 (ใครแกะวาล์ว), เสียง, เมนู/new game, sprite จริงของเฮียเป้ง/พี่แจ่ม/คุณนายวรรณ (ลบ save = `adb shell run-as com.drums55.game25d rm files/save_0.json`)
