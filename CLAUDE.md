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
- **เกม = "ไรเดอร์ห้าดาว" (ทิศใหม่ 2026-10-01, DESIGN.md ข้อ 10)**: ไรเดอร์ส่งของในกรุงเทพฯ **ปัจจุบัน** (ไม่ใช่ steampunk แล้ว —
  เจ้าของ: "กทม. ปัจจุบันก็ได้") ที่**สุ่มเมืองใหม่ทุกเกม**, รับงานผ่าน**แอป** (ไม่มีบอร์ดงาน), ขี่ไปบน**แผนที่** (ไม่มีประตูระหว่างห้อง),
  ติดหนี้นอกระบบดอกลอย + ค่าเช่ารถรายวัน, ตัวร้าย = แพลตฟอร์ม, โทน serious × absurd. เกมสั้น 7 วัน.
  เวอร์ชันย่านตายตัว steampunk (ซอยทองเหลือง/ตลาด/อู่/ท่าเรือ, บอร์ดงาน, ชื่อเสียง 3 ฝ่าย, บริษัทไอน้ำ) **ลบแล้ว** — ดูได้ใน git ก่อน P0
- **ตัวเอก = ไรเดอร์** (หมวกกันน็อก แจ็กเก็ตส้ม; sprite rider เดิม). NPC ใช้ sprite je_muay/lung_pradit ย้อมสีไปก่อน
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
- **ฉาก/prop ลงสีด้วยโค้ด** (2026-10-01): `tools/art/png/room.py` (backdrop ทั้งห้อง, RoomCanvas crop ต่อ op), `props_th.py`
  (prop ไทย + `Canvas.text()` ป้ายไทยบนหน้า iso: หน้า +x ต้องให้ p0 อยู่ฝั่ง +gy). backdrop ห้องเดิม 4 ห้องลบไปพร้อมย่านเก่า;
  P0 ใช้พื้น/ผนัง placeholder สีตามประเภทสถานที่. **prop กทม. ปัจจุบัน** (2026-10-01) = `tools/art/png/props_bkk.py`
  (rider_bike กล่องเขียว "ส่งไว", parked_scooter, food_counter ตู้ข้าวมันไก่, steel_table + red_stool, market_stall ร่มส้ม,
  fruit_crates, house_gate, plant_pots, guard_desk, lift_door "ไรเดอร์ห้ามใช้", parcel_shelf, reception_desk, water_dispenser,
  sofa, fuel_pump(_green), tire_stack, trash_bin, tool_bench, minimart) ใช้ใน `LocationTemplates` แล้ว; ยังเหลือพื้น/ผนังต่อประเภท
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
- **2026-10-01 เจ้าของเปลี่ยนทิศ → DESIGN.md ข้อ 10 "ร่าง 2: rider vs platform vs ลูกค้า"** (เมืองสุ่ม, แอปแทนบอร์ด, แผนที่ BKK,
  งานซ้อน, อาหาร/เอกสาร/พัสดุต่าง behavior, หนี้นอกระบบ+เจ้าหนี้ตามหา, ปักหมุดผิด, รีวิว 1 ดาว, serious × absurd).
  **ยังรอเจ้าของยืนยัน + ตอบว่าคง steampunk หรือเป็นกรุงเทพฯ ปัจจุบัน** ก่อนเริ่ม P0 — อย่าเพิ่งทำดาดฟ้า/ห้องตายตัวเพิ่ม

## โครงสร้าง
```
project.godot            viewport 1920x1200, stretch canvas_items/expand, main scene = scenes/ui/main_menu.tscn
export_presets.cfg       preset "Android": arm64 only, non-gradle, package com.drums55.game25d
scenes/ui/main_menu.tscn เมนูหลัก; scenes/main.tscn = เกม: RoomHolder + Player (persistent) + HUD
scenes/rooms/location.tscn  สถานที่เดียวที่สร้างตามประเภท (LocationRoom + LocationTemplates)
scenes/characters/       character_view.tscn (sprite 8 ทิศ; ใช้จริง), cutout_rig.tscn (placeholder fallback)
scenes/props/            prop_block, npc, interactable, patrol_bot, steam_vent
scripts/autoload/        GameState (เงิน หนี้ น้ำมัน ดาว เวลา orders save slots), Dialog, SceneRouter, Settings, City, Orders
scripts/core/            Iso, SaveData, DialogData, ArtLibrary, PickTest, CityGen, District, Weather, OrderGen, RideTrack, PlatformPolicy — pure, unit-tested
scripts/ride/            ride_scene (ช่วงขี่), ride_road (วาดถนน); scenes/ride/ride.tscn
scripts/ui/              hud, phone, city_map_view, day_clock, rain_overlay, save_slots, settings_panel, main_menu, ui_kit, dialog_box
tools/art/               gen_svg.py (svg เก่า), png/ (paint.py room.py props_th.py ...), 3d/ (ตัวละคร)
assets/dialog/dialog.json  บทพูด NPC/ของในฉาก (talk_*); format อยู่หัวไฟล์ scripts/core/dialog_data.gd
test/unit/               GUT tests (test_helpers.gd = TestHelpers.start_at(type) เมือง seed คงที่)
tools/                   dev_setup.ps1, run.ps1 (เล่นบน PC), update.ps1/.sh, godot_path.ps1, run_tests.sh, fetch_gut.*
```

## Architecture / decisions
- **Input**: tap ถูกจัดการเป็น `InputEventScreenTouch` อย่างเดียวใน `Player._unhandled_input`
  (`emulate_touch_from_mouse=true` → คลิกเมาส์บน PC = แตะ). ไม่ใช้ mouse event (มือถือส่ง mouse จำลองซ้ำ).
  แตะโดน UI (แอป/ปุ่มแอป/แบนเนอร์/การ์ดสรุป) ไม่เดิน: Player ถาม `Hud.blocks_point(screen_pos)`; ตอนเปิด UI เต็มจอ
  `GameState.ui_open` = true → โลกไม่รับแตะ. DialogBox `mouse_filter = IGNORE` ทั้งหมด. คีย์ WASD/E ใช้ได้บน PC
- **Point & click**: `Player.click_at(world_pos)` → `Player.pick()` หา node ใน group `pickable`.
  **Hit test = พิกเซลจริงของภาพ** (`PickTest`, `scripts/core/pick_test.gd`, 2026-10-01 — เจ้าของ: "ของ/คนที่อยู่ใกล้กัน คลิกผิดบ่อย"
  เพราะเดิมใช้กรอบ 140×280 เท่ากันทุกชิ้นแล้วเลือกตัวหน้าสุด): แตะโดน Sprite2D/AnimatedSprite2D ของ node นั้นตรงที่ alpha ≥ 0.5
  (เงาพื้นที่อบในภาพจางกว่า ไม่นับ) เผื่อนิ้ว 14px; โดนหลายตัว = ตัวที่ y มากสุด (วาดทับอยู่บน). Interactable ใช้ภาพของ parent
  (prop/NPC). node ที่ไม่มี sprite (ประตู, prop placeholder) ใช้ `pick_rect` และชนะเฉพาะตอนไม่โดนภาพใคร (ใกล้ศูนย์กลาง rect สุด).
  mask อัลฟาสร้างครั้งแรกที่แตะต่อ texture (BitMap cache; AtlasTexture ใช้ sheet + region).
  Interactable → order INTERACT (หยุดเมื่อ InteractArea ทับ), มี `tamper` (PatrolBot) → TAMPER (หยุดที่ระยะ 80), อื่นๆ/พื้น → MOVE.
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
- **P0 loop (2026-10-01)** — เมนูหลัก `scenes/ui/main_menu.tscn` (run/main_scene): เล่นต่อ (เซฟล่าสุด) / เกมใหม่ / โหลด / ตั้งค่า / ออก →
  `scenes/main.tscn` (Main): นาฬิกาเดินเวลาจริง (`Settings.seconds_per_minute`, หยุดตอน dialog/เมนู/การ์ด), สีแสงตามชั่วโมง+ฝน,
  `sleep()` = จบวัน (สลิป + เช้าหักค่าเช่ารถ/ดอก), ตอนจบ (`ENDINGS`)
- **เมือง**: `CityGen.generate(seed)` (pure) = 15 จุด 7 ประเภท (restaurant market house condo office gas garage) ชื่อไทยสุ่ม +
  ถนน (MST + เพื่อนบ้านใกล้ 2 จุด, main/soi, km, นาที, `flood` 0-2) + `route()` Dijkstra (น้ำลึกปิด, น้ำตื้องลุยช้า ×1.6).
  save เก็บแค่ seed. autoload `City`: get_city/node/here/forecast/rain_now/water_now/route_to/**travel(dest)** (เวลา+น้ำมัน+ซุปหก+
  น้ำมันหมด=เข็น แล้ว `SceneRouter.go_to(LOCATION_SCENE)`)
- **ช่วงขี่เล่นได้ (2026-10-01, เจ้าของ: "ความสนุกลดลง เหมือนคลิกๆ ตาม map")**: `City.travel()` → `start_ride()` สร้าง
  `RideTrack.generate(seed, segments จาก route, minutes, rain)` (pure, `scripts/core/ride_track.gd`) → `scenes/ride/ride.tscn`
  (`RideScene` + `RideRoad`): ถนน iso วิ่งไปทางขวาล่าง 3 เลน ขอบทางแดงขาว ตึกแถว/ร้านสะดวกซื้อ/เสาไฟเลื่อนผ่าน, แตะเหนือรถ = เลนซ้าย
  ใต้รถ = เลนขวา (W/S A/D บน PC). สิ่งกีดขวาง `RideTrack.KINDS`: แท็กซี่ชมพู/รถเมล์ (ขับไปข้างหน้า), รถเข็น, มอไซค์จอด = ชน
  (หยุด 1.1 วิ +3 นาที), หมาซอย (เดินข้ามเลน), หลุม, ฝาท่อ, น้ำขัง (ช้าลง), ด่านตรวจ (+5 นาที, ต้องหาเลนว่าง), รถติด (ทุกเลน ช้า).
  ทางแยก: ป้ายเลนซ้าย = ซอยลัด (สั้น ×0.72 แต่หลุม/หมา/น้ำ), เลนขวา = ถนนใหญ่ (ไกล + รถติด) — ตัดสินตอนผ่านป้าย (`SIGN_LEAD`).
  มาตร "ความนิ่งของของในกล่อง" (ชน/หลุม/ส่ายเลนรัวๆ ลด; ฝนลดหนักขึ้น) จบแล้ว < 50 = อาหารหก. นาฬิกาเกมเดินตามการขี่ (ขี่เรียบ = เวลาตามแผนที่;
  หยุด/ช้า = เสียเวลาเพิ่ม). จบ → `City.finish_ride()` (น้ำมันตามกม. จริงของทาง, delay, หก) → โหลดสถานที่.
  ระหว่างขี่ `GameState.riding` = true: Main ไม่เดินนาฬิกาเอง, ไม่ autosave, ซ่อนปุ่มแอป/รายการงาน, ปิดแอป.
  ตั้งค่า "ข้ามช่วงขี่" (`Settings.skip_ride`) = ไปถึงทันทีแบบเดิม; **test ทุกตัวผ่าน `TestHelpers.start_at` ตั้ง skip_ride=true**
  (test_ride เปิดเอง). art รถ/สิ่งกีดขวาง: taxi, city_bus, soi_dog, police_check, shophouse ใน props_bkk.py.
  **จังหวะ (เจ้าของ 2026-10-01: "ตอนขับทุกอย่างเร็วจนไม่ enjoy")**: ความเร็วลดครึ่ง (`RideTrack.SPEED` 3.8/3.3/2.8 ช่อง/วิ),
  รถในถนนวิ่งช้าลง, ระยะห่างสิ่งกีดขวาง 4.5–8 ช่อง (~1.5–2 วิ), เปลี่ยนเลนแบบไหล (3.5 เลน/วิ), เร่งจากนิ่ง 2 วิตอนออกตัว,
  หมาเดินช้าลง, ข้อความค้าง 1.8 วิ. ตั้งค่า "ความเร็วช่วงขี่" ชิล ×0.75 / ปกติ / บิด ×1.4 (`Settings.ride_speed`)
- **ฝน/น้ำท่วม**: `Weather` (pure) ฝน 0-2 ช่วง/วันจาก seed+day; น้ำบนถนน = ฝนสะสม 120 นาที (หนัก ≥30 นาที = ลึก, ฝนรวม ≥40 = ตื้น)
  จำกัดด้วย `flood` ของถนน; ฝน = ขี่ช้า ×1.25/×1.5, ค่ารอบ +10, ซุปหก 15% (ลุยน้ำ 50%). แผนที่วาดถนนน้ำตื้น = ประฟ้า, ลึก = กากบาท
- **ออเดอร์**: `OrderGen` (pure) food/parcel/doc ต่าง behavior (อาหาร: ready_at รอร้าน, ร้อน→อุ่น→เย็น, หก; พัสดุ: size 1-2 ช่อง, COD
  สำรองจ่าย; เอกสาร: sign_name, deadline แข็ง) + `rate()` ดาว (สาย/เย็น/หก + รีวิว 1 ดาวไม่ยุติธรรม 8%). ค่ารอบจ่ายแค่ช่วงรับ→ส่ง.
  autoload `Orders`: offer เด้งตามเวลา (หมดอายุ), accept/decline/cancel, กระเป๋า 3 ช่อง, รับของ = แตะ NPC `npc_id "merchant"`,
  ส่ง = แตะลูกค้า `npc_id "customer_<id>"` (เกิดในห้องเมื่อมีออเดอร์ปลายทางนี้), `end_day()` งานค้าง = 1 ดาว
- **P1 ปัญหาไรเดอร์ (2026-10-01)** — ตัดสินตอนสร้างออเดอร์ (`OrderGen`, ผู้เล่นไม่รู้ล่วงหน้า), ทำงานใน `Orders` + `LocationRoom`:
  - **ปักหมุดผิด** (`pin_wrong` + `true_dropoff` = จุดข้างเคียงบนแผนที่, 25% ของบ้าน/คอนโด): แอป/แผนที่/HUD ใช้ `Orders.shown_dropoff()`,
    ส่งได้เฉพาะ `real_dropoff()`. ที่หมุดผิดมี NPC "คนแถวนี้ (ถามทาง)" (`npc_id local_<id>`) บอกที่จริง; หรือปุ่ม "โทรหาลูกค้า" (45% ไม่รับสาย, +2 นาที)
  - **COD ไม่มีคนรับ** (`no_show`, 30% ของพัสดุ COD): ที่ปลายทางไม่มีลูกค้า มีแต่ "กดกริ่ง" (`door_<id>`); การ์ดในแอปมี "รอลูกค้า 10 นาที"
    (35% กลับมา) / "ตีกลับ" (ได้คืนครึ่งเดียว `GameState.pending_refund` จ่ายเช้าวันถัดไป)
  - **ยกเลิกหลังซื้อ** (อาหารเงินสด 30% มี `cod` = ค่าอาหาร, 25% ในนั้น `will_cancel`): หลังขี่ถึงที่ไหนก็ได้ `Orders.check_cancellations()`
    → ออเดอร์หาย เงินที่สำรองจ่ายหาย (log `cod_lost`)
  - **คอนโด**: ลูกค้าไม่ลงมาเอง (`waiting_customers` ต้อง `called_down`) → คุยกับ รปภ. ที่โต๊ะ (merchant) = โทรขึ้นห้อง รอ 4–12 นาที
    แล้วห้องโหลดใหม่ให้ลูกค้าโผล่; หรือ**แอบขึ้นลิฟต์** (prop ลิฟต์ `action: sneak_lift`) ตอน รปภ.เฝ้าลิฟต์ (`LiftGuard` = PatrolBot คน, `chases=false`,
    group `guard`) มองไม่เห็น = ส่งถึงหน้าห้อง ทิป +10; เห็น = โดนไล่ +3 นาที
  - **เจ้าหนี้ตามหา**: `LocationRoom._collector_shows_up` (ค้างจ่าย 55% / มีหนี้ 10% ต่อการมาถึง, ไม่ใช่ตอนเริ่มเกม) → PatrolBot คน
    (`needs_cargo=false`, `catch_kind collect`) ไล่ทุกคน จับได้ = เอาเงิน ≤ 220 บาท นับเป็นจ่ายดอก (missed -1). แตะ = คำขู่ (`talk_collector`)
    test ปิดด้วย `LocationRoom.allow_collector = false` (TestHelpers)
  - **อุทธรณ์รีวิว 1 ดาวไม่ยุติธรรม**: `OrderGen.rate` ให้ `unfair` → `GameState.appeals`; แท็บเงินมีปุ่ม "อุทธรณ์กับแชทบอท" → `AppealChat`
    (บอท "น้องส่งไว": ทุกข้อความ +3 นาที, ขอคนจริง = คิว 3,482, หลักฐานเพิ่มโอกาส; สำเร็จ ~15–45% → ดาวนั้นกลายเป็น 5)
  - PatrolBot เพิ่ม `character_name` (sprite คน), `chases`, `needs_cargo`, `catch_kind`, `tamperable`, `talk_dialog`
  - IsoRoom ตั้ง z_index -20 (พื้น placeholder) + World +20 เพื่อให้กรวยสายตา (z -1) อยู่เหนือพื้น
- **P2 แพลตฟอร์มโหด (2026-10-02)**:
  - **นโยบายรายวัน** `PlatformPolicy.for_day(seed, day)` (pure, `scripts/core/platform_policy.gd`): วัน 1 = welcome, วัน 2–7 สุ่มไม่ซ้ำจาก
    fee_cut (−6/งาน), surge_cut (ฝน +2), bundle_ai (งานพ่วง 50%), accept_rule (รับงาน <80% = ค่ารอบ ×0.75), selfie (ต้องเซลฟี่ทุก 2 ชม.
    ไม่งั้นไม่มีงานเข้า, 25% หน้าไม่ตรง), fee_up (+2 แต่ค่าธรรมเนียมระบบ 3/งาน), mega_quest (เป้า +3 โบนัส ×1.5).
    ประกาศของพรุ่งนี้อยู่ท้ายสลิปตอนนอน ("แจ้งล่วงหน้าคืนเดียว"), ของวันนี้เป็นการ์ดบนสุดแท็บงาน. `OrderGen.make(..., policy)` ใช้ fee_delta/surge
  - **โบนัสหลอก**: ภารกิจรายวัน ส่งครบ `target` งาน รับ `reward` (log `bonus`); ขาดอีกงานเดียว = `Orders.teasing()` → ช่องว่างงานเข้า ×2.5
  - **งานพ่วง**: `OrderGen.make_bundle` = จุดรับเดียวกัน ปลายทางไกลสุดจากงานแรก ค่ารอบเหมา 15 บาท, `bundle` = id งานแรก; รับ/ข้าม/หมดอายุพร้อมกัน
    (`Orders.group_of`, `offer_groups` นับคู่เป็นหนึ่ง), ข้าม = นับปฏิเสธ 2 งาน. deadline คิดแบบ "แอปคิดเหมือนงานเดียว" (+ครึ่งขาเชื่อม)
  - **ปิดบัญชี**: เรตติ้ง < 4.3 ครั้งแรก = `GameState.suspended` (signal `account_suspended` → overlay; งานที่ยังไม่รับของโดนโอนไปคนอื่น,
    ไม่มีงานเข้า) → อุทธรณ์ AppealChat โหมด `{"kind": "suspension"}` ได้ครั้งเดียว (35%+หลักฐาน, สำเร็จ = `reinstate()` + ดูวิดีโอ 30 นาที)
    ไม่งั้นปลดล็อกเช้าวันถัดไป หักค่าอบรม 199. `reinstate()` เปลี่ยนดาวแย่สุดในหน้าต่างเป็น 5 จนเฉลี่ย ≥ 4.45. ครั้งที่สอง = จบ "suspended" (ปิดถาวร)
  - **ความล้า** `GameState.fatigue` 0–100: +0.05/นาที (ฝน ×1.3), ชน +4, นอน −12/ชม. (นอน 23:00 = 8 ชม. หายหมด, ตีสอง = 5 ชม.),
    กาแฟ 15 บาท (−10 หารจำนวนแก้ววันนั้น), งีบ 30 นาที. ≥40 เพลีย: เปลี่ยนเลนช้าลงถึง ×0.6 (`RideScene.steer_factor`); ≥70 ง่วงมาก: สัปหงก รถส่ายเลนเองทุก 4–7 วิ
  - **อุบัติเหตุ**: ชนในช่วงขี่ → โอกาส `City.accident_chance(fatigue, rain)` = 4% + 0.4%/แต้มล้าเกิน 30 + ฝน 5% → `City.accident()`:
    คลินิก 40 นาที 300–600 บาท อาหารหก ล้า +10, เงินไม่พอ = ยืมเจ้าหนี้ (หนี้เพิ่ม); ประกันแพลตฟอร์ม "พิจารณา 14 วันทำการ" / "ไม่คุ้มครอง". ข้ามช่วงขี่ = ครึ่งโอกาส เมื่อล้า ≥ 40
  - save เพิ่ม fatigue, coffees_today, suspended, suspensions, suspension_appealed, selfie_due (ยัง v5, ค่า default ถ้าไม่มี)
- **ย่านส่งไว ทำมือ (2026-10-02, DESIGN 10.10)** — เจ้าของ: P2 "เหมือนทำ app rider ... แบบแรกสนุกกว่า", ที่สนุก = "สำรวจห้อง แล้วบทสนทนา/ของมันฮาๆ":
  - `City.get_city()` = `District.city(seed)` (`scripts/core/district.gd`): 10 ที่ตายตัว (มี `key`) + ถนน 15 เส้นเขียนมือ; seed ใช้แค่ฝน/ออเดอร์.
    `CityGen.generate` ยังอยู่ (test_city ใช้) แต่เกมไม่ใช้. Save v6 (id สถานที่เปลี่ยนความหมาย → เซฟ v5 ถูกข้าม)
  - ห้องต่อที่ = `LocationTemplates.for_place(place)` = template ของประเภท + `PlaceRooms.ROOMS[key]` (`scripts/world/place_rooms.gd`):
    key ที่ให้แทนของประเภท, `merchant` merge (+ `name` = ป้ายชื่อ), extras วางครบทุกชิ้น, `npcs` = คนในย่าน {name,pos,character,tint,dialog,action}.
    กติกา gap/sliver ใช้กับทุก recipe (`LocationTemplates.all_recipes()` ใน test); NPC ห้ามชิดผนัง ~0.5 ช่องเพราะ navmesh sliver (เจอที่ปั๊ม/คอนโด)
  - เควสต์ = dialog.json ล้วน (flags + items + `if_money_at_least` + `money`) + `GameState.ITEMS`; HUD แสดง "ในกระเป๋า: ..." อีกครั้ง.
    รางวัลที่ผูกกับระบบ: `aunt_jum` → `Orders.neighbour_hints()` เปิดหมุดผิดตอนมาถึง; `guard_friend` → ไม่มี LiftGuard + เรียกลูกค้า 1 นาที;
    `dog_friend` → `RideScene._apply` ข้ามผล "dog"; `cat_fed` (+100); Dialog event `nok_meal` (ล้า −25 วันละครั้ง flag `nok_meal_d<day>`),
    `lobby_nap` (ล้า −15); `Interactable.action "rumor"` = พี่ต้อยเล่านโยบายพรุ่งนี้. ทดสอบใน `test/unit/test_district.gd`
- **ส่งไม่ทัน (เจ้าของ 2026-10-01: "ส่งช้าตลอด")**: deadline คิดจากเส้นทางจริง `OrderGen.set_deadline` = ขี่ไปจุดรับ + (รออาหาร) +
  ทางรับ→ส่ง ×1.25 + slack (อาหาร 15 / พัสดุ 90 / เอกสาร 30 นาที); อาหารร้อน <25 นาที อุ่น <50; นาฬิกาในสถานที่ช้าลง ปกติ 2 วิ/นาที
- **สถานที่**: `scenes/rooms/location.tscn` + `LocationRoom` (extends IsoRoom) สร้างจาก `LocationTemplates.T[type]` ตอน `_ready`
  ก่อน IsoRoom อบ navmesh: props + extras สุ่ม (seed = city seed + node id), merchant (`behind_counter` = ไม่มี collision กัน navmesh
  sliver ระหว่างเคาน์เตอร์-NPC-ผนัง), ลูกค้า (ป้ายชื่อบนหัว), รถตัวเองมุมหน้าขวา (`bike_cell`, แตะ = เปิดแผนที่), ชื่อร้านบนผนัง.
  `Interactable.action`: "open_map", "refuel" (เด็กปั๊ม). **กติกา template**: ระยะห่างของ↔ของ/ผนัง ห้ามอยู่ช่วง 0.85–1.15 ช่อง
  (= 2× agent radius → navmesh sliver) — `test_templates_avoid_sliver_gaps` ตรวจ + `test_every_place_builds_a_valid_room` (4 seed × ทุกจุด)
- **เงิน/หนี้/ตัวเลข** (`GameState`, consts ปรับ balance ที่นั่น): เริ่ม 300 บาท, หนี้ 3000 ดอก 60/วัน (ดอกลอย), ค่าเช่ารถ 150/วัน,
  ไม่พอจ่ายตอนเช้า 3 ครั้ง = รถโดนยึด, เรตติ้ง (เฉลี่ย 40 งานล่าสุด, เริ่ม 4.8) < 4.3 = บัญชีถูกระงับ, ครบวันที่ 7 = ตอนจบ
  (ปลดหนี้ / ยังติดหนี้), น้ำมัน 4 ลิตร 40 กม./ลิตร 38 บาท/ลิตร (เติมที่ปั๊ม), อัตรารับงาน = accepted/offered
- **Save v5**: `SaveData` = {version, meta, state} (state = `GameState.snapshot()`); slot 0 = ออโต้เซฟ (ทุกครั้งที่ถึงที่หมาย + ตอนนอน),
  slot 1–3 บันทึกเองจากแอป; save < v5 (เกมย่านเก่า) ถูกข้าม. **Settings** autoload → `user://settings.cfg` (ความเร็วนาฬิกา/ตัวหนังสือ,
  เสียง, คำแนะนำ). `config/name` = "Rider 5 Stars" (โฟลเดอร์ user:// บน PC เปลี่ยนตาม)
- **UI** (สร้างด้วยโค้ด, `UiKit`): HUD = เงิน·หนี้ / น้ำมัน·ดาว·รับงาน, หน้าปัด `DayClock` (07:00–23:00 + สภาพอากาศ), รายการงาน
  + เวลาเหลือ, ปุ่ม "แอปไรเดอร์" (ปุ่มเดียวบนจอ — ข้อยกเว้นกฎไม่มีปุ่ม เพราะแอปคือแกนเกม), แบนเนอร์งานใหม่, `RainOverlay`,
  `show_overlay()` (สลิป/ตอนจบ). `Phone` แท็บ งาน / แผนที่ (`CityMapView`) / เงิน / เมนู (`SaveSlots`, `SettingsPanel`, หน้าแรก)
- **Dialog**: JSON-driven; เงื่อนไขต่อ entry: `if_flag`/`if_not_flag`/`if_item`/`if_not_item` (+`else` chain);
  action ต่อบรรทัด: `set_flag`/`give_item`/`take_item`/`money` (ทำตอนบรรทัดโชว์ → HUD ขึ้น notice). แตะที่ไหนก็ได้ = next
  (ถ้ากำลังพิมพ์ = แสดงทั้งบรรทัด). Quest = flags + inventory ใน dialog.json ล้วนๆ ไม่มี quest system แยก
- **ไม่มีการต่อสู้ (เจ้าของ 2026-10-01: "ศัตรูตายแล้วไม่มีอะไรใหม่ งงๆ")** — ตีไม่ได้, ไม่มี HP. `PatrolBot` เก็บไว้ใช้ทำเจ้าหนี้/รปภ./หมา ใน P1 (ยังไม่ได้วางในฉากไหน);
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
- (ย่านเก่า แต่ใช้ต่อได้ถ้าวาด backdrop ใหม่) ประตูกับช่องในผนังไม่ตรงกัน (เจ้าของเจอ 2026-10-01 ที่ตลาด): (1) `RoomCanvas` เคยคิดความกว้างภาพเป็น gw*128 แต่
  backdrop rect จริงกว้าง (gw+gh)*64 และเริ่มที่ x=-gh*64 → ห้องไม่จัตุรัสเลื่อน/ยืด (ซอย 12×12 ไม่โดน); (2) Door node อยู่
  หน้าผนัง 22px และวาดแผ่นเอง → ตอนนี้ภาพผนังวาด doorway ขนาดเท่า Door (±56px, สูง 170) ที่ระนาบผนัง และ
  `IsoRoom.apply_art` ตั้ง `door.show_panel=false` (Door เหลือ trigger + exit marker: ลูกศรทองเหลืองเด้ง + วงแหวนกะพริบที่พื้น ใน `Door._draw_marker`).
  ประตูในภาพฉาก = ซุ้มทองเหลืองโค้ง + ทางเดินมีแสงส้มปลายทาง + โคม 2 ข้าง + แสงสาดลงพื้น (`doorway()` ใน room.py) — ช่องมืดเฉยๆ ดูไม่ออกว่าประตู (เจ้าของติ) ย้ายประตู = ต้องแก้ `door_u` ใน room.py แล้ว render ใหม่
- `git pull` บน PC ล้ม "untracked working tree files would be overwritten: *.import" เมื่อ cloud commit `.import`
  ที่ Godot บน PC สร้างไว้ก่อนแล้ว (เจ้าของเจอ 2026-10-01; เกมที่รันต่อเลยเป็นของเก่า) → `tools/pull.ps1` ลบ untracked
  `*.import` ก่อน pull (Godot สร้างใหม่เอง); `run.ps1` pull ให้เองทุกครั้ง (`-NoPull` ถ้าไม่ต้องการ), `update.ps1` ใช้ตัวเดียวกัน
- SceneRouter.go_to ที่ค้าง await fade อยู่ตอน Main ถูก free (กลับหน้าแรก / test จบกลางทาง) เคยทำ `_busy` ค้างตลอดไป
  → ตรวจ `is_instance_valid(_host)` หลัง fade แล้วรีเซ็ต. test ที่เขียน settings ต้องใช้ path ชั่วคราว (`save_settings(path)`)
  ไม่งั้นค่า skip_ride ของ test ไปติดใน `user://settings.cfg` จริง
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
- **ย่านส่งไว ทำมือ (2026-10-02)**: แผนที่ตายตัว 10 ที่, คนมีชื่อ 12 คน, ~60 บทพูดใหม่, เควสต์ของ 5 สาย (99 tests). รอเจ้าของลองเล่น
- **P2 เสร็จ (2026-10-02)**: นโยบายรายวัน, โบนัสหลอก, งานพ่วง, ปิดบัญชี+อุทธรณ์, ความล้า, อุบัติเหตุ (89 tests)
- **P1 เสร็จ (2026-10-01)**: ปักหมุดผิด, COD ไม่รับ, ยกเลิกหลังซื้อ, รปภ.คอนโด+ลิฟต์, เจ้าหนี้ตามหา, อุทธรณ์ 1 ดาว, deadline สมจริง
- **ช่วงขี่เล่นได้ เสร็จ (2026-10-01)** — เจ้าของ: "ดีขึ้นแล้ว" หลังลดความเร็ว
- **P0 เสร็จ (2026-10-01)**: เมนู/เซฟ 3 ช่อง+ออโต้/ตั้งค่า, เมืองสุ่ม+แผนที่+ขี่, ฝน/น้ำท่วม, แอป (งานเข้า/รับ/ข้าม/ยกเลิก/นำทาง),
  อาหาร/พัสดุ/เอกสาร, ดาว+รีวิว, เงิน/หนี้/ค่าเช่า/น้ำมัน/ปั๊ม, สลิปรายวัน, ตอนจบ 4 แบบ
- ต่อไป (DESIGN 10.10): แอปบางลง, คนในย่านพูดเรื่องใหม่ตามวัน, ปริศนาในฉากแทนปุ่มในแอป, ตอนจบ;
  **art กรุงเทพฯ ปัจจุบัน** (พื้น/ผนังต่อประเภท, prop: เซเว่น ตู้กดน้ำ โต๊ะสแตนเลส ป้อม รปภ. หัวจ่ายน้ำมัน ฯลฯ ด้วย paint.py)
- ยังไม่มี: เสียง, sprite จริงของ NPC แต่ละแบบ, balance (ตัวเลขใน GameState/OrderGen ยังเดา)
- ลบ save บนแท็บเล็ต = `adb shell run-as com.drums55.game25d rm files/save_0.json`
