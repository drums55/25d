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
- **ทิศล่าสุด (2026-10-02) = `docs/DESIGN.md` ข้อ 11 "กรุงเทพฯ 2090"**: เกมผจญภัยตลกมีตอนจบ แนว Monkey Island แต่ simple
  (กระเป๋า + ใช้ของ + ผสมของ + ปริศนา), ไรเดอร์ติดหนี้นอกระบบ หนีคนทวง/หุ่นทวง, กทม. อนาคตจมน้ำ หน้าตาย้อนยุคไอน้ำ,
  plot ใหญ่ + plot ย่อย. **เลิกจำลองอาชีพไรเดอร์** (เจ้าของ: "การจำลองปัญหา rider มันไม่สนุก") — ถอดออกแล้วใน A0
  (ข้อความเก่าเรื่อง steampunk/ย่าน/บอร์ดงาน/ไรเดอร์ห้าดาว P0–P2 ด้านล่าง = ประวัติ ดูโค้ดใน git)
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
- **ตัวละครแต่ละคนแต่งตัวต่างกัน + ท่าพิเศษ + ย่อขนาด (2026-10-02, เจ้าของ: "ทำท่านั่งขี่ / ควรลดขนาดทุก characters ไหม / แต่ละคนแต่งตัวต่างกัน / ท่า achievement อย่างพี่หนวดเต้น")**:
  - NPC ทุกคนมีชีตของตัวเอง (`assets/art/characters/<npc id>/sprites`): nuad, lung_table3, pa_nok, jum, keng, chang_daeng, kiao, wan —
    สเปกอยู่ใน `NPCS` ของ `char_q.py` (เพศ, ผม, สีผิว, แขนกุด/สั้น/ยาว, ขายาว/ขาสั้น/ผ้าถุง, รองเท้า, scale (น้องเก่ง 0.78), palette)
    + ของประจำตัวใน `npc_accessories` (หนวด+แว่นดำ+สร้อยทอง, แว่น+ผ้าเช็ดหน้า+พุง, ผ้ากันเปื้อน+ที่คาดผม, ที่ม้วนผม+ดอกไม้+มือถือ,
    หูฟังเกมมิ่ง, หมวกกลับหลัง+แว่นช่าง+ผ้าเช็ดมือ, สร้อย+กำไลทอง, ปกเสื้อ+บัตรพนักงาน). rooms.gd ใช้ `"character": "<id>"` ไม่ย้อมสีแล้ว
  - ท่าพิเศษ = anim เสริมในชีต: rider `ride` (นั่งขี่ 4f@8, ถอดกล่องหลัง+ประแจตอน render), nuad `dance` (รำวง 8f@8).
    `CharacterView.set_pose(anim)` ค้างท่า (loop, ชนะ walk; ตั้งก่อน _ready ได้). BoatRide ใช้ `ride` ที่ `RIDER_SEAT`,
    PatrolBot ที่ถูก distract เล่น `distract_pose` (default "dance") ถ้าตัวนั้นมี. ท่าใหม่ = เพิ่ม kind ใน `pose_frame` + ใส่ชื่อใน `LOOPING_ANIMS`
  - ท่าพิเศษเพิ่ม (2026-10-02): jum `shout` (โทรโข่งติดกระดูก Head + มือเท้าสะเอว), pa_nok/lung_table3 `wai` (งานแต่ง: พวงมาลัย + มงคลแฝด),
    nuad `dance` แก้ใหม่ (เจ้าของ: "เหมือนโหนบาร์ ขาลอย") = แบมือรำวง ศอกต่ำ + ย่อเข่าทีละข้าง + `feet_z()` ล็อกเท้าติดพื้น.
    `EXTRA_ANIMS` ใน char_q.py; ของที่โผล่เฉพาะท่าตั้งชื่อ `Only<anim>_...` (ซ่อนท่าอื่น) / `Not<anim>_...` (ซ่อนเฉพาะท่านั้น).
    render ท่าเดียว: `ONLY=<anim>` แล้ว merge `anims` เข้า sprites.json เดิม. ห้อง: npc `"poses": {flag: anim}` → `AdventureRoom._apply_poses`
    (สดๆ ตอน flag เปลี่ยน). งานแต่ง = ลุงโต๊ะสามมี 2 entry (ที่โต๊ะสาม `if_not_flag ally_nok` / ข้างป้านก `if_flag ally_nok`)
  - **ฉากตอนจบ (2026-10-02, เจ้าของ: "ทำท่าพิเศษตอนจบด้วย")**: `Main.end_game(id)` → `go_room` ไปห้องของตอนจบ (`ENDING_SCENES`:
    five_stars = เรือป้านกตอนรุ่งเช้า ไรเดอร์ `cheer` + แขกงานแต่ง (npc `if_flag ending_five_stars`: พี่หนวดเต้น ป้าจุ๋มตะโกน น้องเก่ง);
    wet = ชุมชนยกเสาเช้า `shrug`; sunk = ชุมชนยกเสากลางคืน `sit_sad`; sold = ห้องเช่ากลางคืน `phone` (ห้าดาวบนมือถือ)) →
    `_stage_ending` ล็อก input, ตั้งท่า + หัวข้อ, รอ `ENDING_HOLD` 3.5 วิ แล้วค่อยขึ้นการ์ด. rider ซ่อนประแจในท่า phone/sit_sad/shrug (`put_away`)
  - ขนาด: `CharacterView.SIZE = 0.84` (เดิมคนสูงกว่าประตู); ป้ายชื่อ NPC -222, เครื่องหมายหุ่น (! ? ~เต้น~) -300
  - render: `pip install bpy==4.2.0` + `python3 tools/art/3d/fetch_quaternius.py <QDIR>` (โหลดชุดฟรีจาก itch.io) แล้ว
    `QDIR=<QDIR> python3 char_q.py <name> <out>` + `pack.py <out>` (~2 นาที/ตัว, segfault ตอนปิด bpy ไม่เป็นไร)
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
scenes/rooms/adventure_room.tscn  ห้องเดียวที่สร้างจาก Rooms.ROOMS[GameState.room]
scenes/characters/       character_view.tscn (sprite 8 ทิศ; ใช้จริง), cutout_rig.tscn (placeholder fallback)
scenes/props/            prop_block, npc, interactable, patrol_bot, steam_vent
scripts/autoload/        GameState (flags กระเป๋า บท วัน น้ำ ห้อง เซฟ), Dialog, SceneRouter, Settings, Puzzles (ของ/ผสม/ใช้)
scripts/core/            Iso, SaveData, DialogData, ArtLibrary, PickTest — pure, unit-tested
scripts/world/           adventure_room, rooms (ข้อมูลห้อง), interactable, marker_spot, patrol_bot, prop_block, iso_room
scripts/ui/              hud (กระเป๋า+เมนู), save_slots, settings_panel, main_menu, ui_kit, dialog_box
assets/data/puzzles.json ของ สูตรผสม การใช้ของ คำตอบเมื่อผิด
tools/art/               gen_svg.py (svg เก่า), png/ (paint.py room.py props_th.py ...), 3d/ (ตัวละคร)
assets/dialog/dialog.json  บทพูด/ดูของ (intro, look_*, talk_*, catch_*); format อยู่หัวไฟล์ scripts/core/dialog_data.gd
test/unit/               GUT tests (test_helpers.gd = TestHelpers.start_in(room))
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
- **ระบบจำลองอาชีพไรเดอร์ถูกถอดออกแล้ว (A0, 2026-10-02)** — แอป/ออเดอร์/เมืองสุ่ม/ย่านส่งไว/ฝน/ช่วงขี่/นโยบาย/ความล้า/เงิน
  อยู่ใน git ที่ commit `aad5f57` (ก่อน A0): `City`, `Orders`, `CityGen`, `District`, `Weather`, `OrderGen`, `RideTrack`/`RideScene`
  (ช่วงขี่ 3 เลน — จะเอากลับมาเป็นขับเรือใน A2), `PlatformPolicy`, `LocationRoom`/`PlaceRooms`, `Phone`, `AppealChat`, `CityMapView`
- **GameState (A0)**: flags, `inventory` (เริ่มด้วย `START_ITEMS` = debt_book, gum), chapter, day, `tide` ("low"/"high"),
  `room` (Rooms id) + `spawn`, `held_item` (ของติดนิ้ว ไม่เซฟ), input_locked/ui_open. ไม่มีเงิน/นาฬิกา (หนี้ = เรื่อง ไม่ใช่มาตรวัด).
  **Save v7** {chapter, day, place, saved_at}; slot 0 = ออโต้เซฟทุกครั้งที่เข้าห้อง (SceneRouter), 1–3 จากเมนู
- **ห้อง (A1)**: `scenes/rooms/adventure_room.tscn` + `AdventureRoom` (extends IsoRoom) สร้างจาก `Rooms.ROOMS[GameState.room]`
  (`scripts/world/rooms.gd`, format อยู่หัวไฟล์): props (`id` = thing id สำหรับใช้ของ; ไม่มี art = กล่อง placeholder; exit_to/exit_flag
  = prop ที่เป็นทางออก เช่น รถลอยน้ำ), pickups (`MarkerSpot` เพชรสีตามของ + ป้าย, หายเมื่อ flag `got_<item>`), npcs (มีป้ายชื่อ),
  exits (`MarkerSpot` วงแหวน+ลูกศร), bots (PatrolBot คนทวงหนี้). ทุก entry มี `if_flag`/`if_not_flag`. backdrop วาดใส่ทีหลังได้ที่
  `assets/art/rooms/<room id>.png`. Main.`go_room(id, spawn)` = ย้ายห้อง (fade + autosave). กติกา gap 0.85–1.15 + navmesh
  (`test_rooms_avoid_sliver_gaps`, `test_every_room_builds_valid`); **ป้าย/ของบางชิดผนังต้องห่าง ≥ ~1.5 ช่องจากมุม หรือแนบผนัง (y 0.15)**
  ไม่งั้น navmesh sliver (เจอกับ sign ที่ y 0.4–0.6)
- **ปริศนา (A1)**: autoload `Puzzles` + `assets/data/puzzles.json` (format หัวไฟล์ puzzles.gd): `items` {name, desc, color},
  `combos` a+b→result, `uses` item+target (+if_flag/if_not_flag, consume), `fail` คำตอบฮาเมื่อผิด (target → item → "combine"/"*").
  lines ใช้ action เดียวกับ dialog.json. HUD แถบกระเป๋าล่างจอ: แตะของ = ถือ, แตะซ้ำ = ดู (คืนกระเป๋า), แตะของอื่น = ผสม;
  ถือของแล้วแตะคน/ของในฉาก = `Interactable.interact` → `Puzzles.use(held, thing_id)`; แตะพื้น = เก็บของคืน.
  `Interactable`: dialog_id / pickup_item / exit_to(+exit_flag, locked_dialog) / thing_id. ปุ่ม "เมนู" มุมขวาบน (บันทึก/โหลด/ตั้งค่า/หน้าแรก).
  test: `test_puzzles.gd` ตรวจว่าของทุกชิ้นหาได้, target ทุกตัวมีในห้อง, dialog id มีจริง + walkthrough ทั้ง slice
- **A1 slice (บทเปิด)**: ห้องเช่า (ไม้แขวนเสื้อ+หมากฝรั่ง = ไม้ตกของ → ร่องพื้น → กุญแจรถลอยน้ำ; รีโมท; จดหมายไม่ลงชื่อ) →
  ท่าเรือ (พี่หนวดคนทวงหนี้เดินตรวจ, ถ่านจากรีโมท → วิทยุ → `radio_on` → พี่หนวดเต้น (`PatrolBot.distract_flag`); กุญแจ → รถ → `bike_ready`)
  → เรือป้านก (ป้านกหูไม่ดี → ใช้สมุดหนี้เขียน → กล่องทองเหลือง `got_box` → การ์ดจบตอนทดลองใน Main; ลุงโต๊ะสามฝากน้ำจิ้มไก่ = plot ย่อย)
- **A2 (2026-10-02) บท 1 ครบ**: ห้องเพิ่ม stilts (ป้าจุ๋ม, น้องเก่ง), boat_garage (ช่างแดงใต้เรือคว่ำ + หุ่นทวงหนี้เบอร์ 9),
  old_gate (ประตูระบายน้ำ: โผล่เฉพาะน้ำลง), station (บ้านเลขที่ 0 — ใส่กล่องในช่องใต้ป้าย = `chapter1_done` → การ์ดจบบท 1 ใน Main).
  - **เรือเตอร์ไซค์** (ชื่อที่เจ้าของตั้ง 2026-10-02 แทน "รถลอยน้ำ" ที่ "ชื่อไม่เท่" — มอเตอร์ไซค์ที่ลอยน้ำได้; ใช้คำนี้ทุกที่ในเกม; art = `boat_bike` ใน props_2090.py: มอไซถอดล้อ ผูกบนถังพลาสติกน้ำเงินสองใบ ใบพัดหางยาว ปล่องไอน้ำ เป็ดยางหัวเรือ — `steam_bike` เก่าลบแล้ว) = prop `action: "travel"` (+exit_flag bike_ready) → `Main.open_travel()` → `Hud.show_choices` รายการ `Rooms.TRAVEL`
    (ปลดล็อกด้วย flag `know_<...>`) → `Main.travel(dest)` → `BoatRide` (`scripts/ride/boat_ride.gd` + pure `BoatTrack`; 3 เลนในคลอง
    เรือหางยาว ลัง โอ่ง ถังขยะ ผักตบชวา(ช้า) หุ่นบนแพ — ชน = แค่สะดุด + มุก ไม่มีบทลงโทษ) → `Main.arrive(dest)` = `go_room(dest, "from_bike")`.
    ทุกห้องที่ไปได้ต้องมี spawn `from_bike`. ตั้งค่า "ข้ามช่วงขับเรือ" (`Settings.skip_ride`, test ตั้ง true เอง)
  - **น้ำขึ้นลง**: `GameState.tide` เริ่ม "high"; entry ในห้อง/use มี `if_tide`; ม้านั่ง (dialog line `event: "wait_tide"`) สลับน้ำแล้ว
    Main โหลดห้องใหม่หลัง dialog จบ. HUD มุมซ้ายบนบอก น้ำขึ้น/น้ำลง
  - ห้องมี `enter: {dialog, flag}` = ฉากตอนเข้าห้องครั้งแรก (Main.load_room)
  - **คำใบ้**: puzzles.json `hints` (อันแรกที่ flag ผ่าน) → เมนู > "คำใบ้"; เป็นป้าจุ๋มโทรมาเมื่อ `jum_friend` ไม่งั้นไรเดอร์คิดในใจ
  - **กดค้าง 0.45 วิ** (ไม่ลาก) = `Player.highlight_things()` วาง `HotspotPing` รอบของที่แตะได้ทุกชิ้น
  - PatrolBot ที่ถูกดึงฟิวส์ตั้ง flag `<bot_id>_fused` (ถาวร) — ใช้คู่ `distract_flag` ให้หลับข้ามวัน/ข้ามการโหลดห้อง
  - art ใหม่ `tools/art/png/props_2090.py`: steam_radio, wardrobe, floor_gap, upturned_boat, sluice_gate, sluice_flooded, tide_gauge,
    wait_bench, house_zero_plate, pump_engine
  - **ระวัง spawn ในกรวยสายตา**: หุ่นเบอร์ 9 เคยเห็นผู้เล่นทันทีที่ลงรถ → วาง patrol ให้ไกล spawn + `facing`/`view_range` ใน recipe
- **A3 (2026-10-02) บท 2 + plot ย่อย**: `Main.CHAPTERS` {flag จบบท: [หัว, ข้อความ, บทถัดไป]} → การ์ดมีปุ่ม "ไปบทที่ N" →
  `Main.start_chapter(n)` (chapter/day = n, flag `ch<n>`, น้ำขึ้น, ตื่นที่บ้าน + `CHAPTER_INTROS`); เซฟที่ค้างระหว่างบทเปิดการ์ดซ้ำตอนโหลด.
  คนในบท 2 ใช้ `if_flag: "ch2"` (พี่หนวดตกงานแทนหุ่นเฝ้าท่า, หุ่นเบอร์ 9 ตื่นเป็น prop `no9_awake` ใน `extra_props`), dialog ใช้ chain
  `talk_x` → (ch2 / flag) → `talk_x_ch1`. ห้องใหม่ `kiao_raft` (เจ๊เกียว). `if_flags` = ต้องครบทุก flag (คุณนายวรรณ).
  เส้นเรื่อง: เจ๊เกียว "ขายหนี้ทั้งซอยไปแล้ว ถามหุ่น" → ตั้งชื่อหุ่น "เก้า" ด้วยสมุดหนี้ → ชิปความจำ → น้องเก่งแฮ็กด้วยจอยเกม → รายชื่อลูกหนี้
  (ผู้ซื้อ: บจ.ป้องกันภัย, ชื่อไรเดอร์อันดับแรก) → ป้าจุ๋มเกือบเซ็น "ใบรับรางวัลลอตเตอรี่" ที่คือใบขายบ้าน → ได้แว่น → ป้านกอ่านจดหมายรัก
  30 ปีของลุงโต๊ะสาม (ป.ล. ตีสามบริษัทเปิดท่อเข้าซอย) → คุณนายวรรณที่บ้านเลขที่ 0 เฉลย (แก้มลิงลับ, หนี้ถูกซื้อ, กุญแจกลับทิศน้ำแต่ซอยจมหนึ่งคืน)
  → `chapter2_done`. test `test_walkthrough_chapter_two`
- **A4 (2026-10-02) บท 3 "คืนตีสาม" + ตอนจบ**: `start_chapter(3)` (การ์ดจบบท 2 มีปุ่มไปบท 3) → `intro_ch3`, ทุกห้องย้อมกลางคืน
  (`Main.NIGHT_TINT` เมื่อ chapter ≥ 3). ชวนพวก 6 คน = flag `ally_*` (`Endings.ALLIES`, `scripts/core/endings.gd` pure):
  พี่หนวดให้โทรโข่ง → ป้าจุ๋ม (`ally_jum`) → น้องเก่งยอมออกจากบ้าน (`ally_keng`); คุยเก้าที่อู่ (`ally_nine`, เก้าย้ายไปยืนคุยกับ
  หุ่นบริษัทที่ประตูน้ำ = `distract_flag`); มือหมุน → ช่างแดง (`ally_daeng`); รายชื่อลูกหนี้ → เจ๊เกียว (`ally_kiao`);
  ลุงโต๊ะสามเล่าเรื่องแหวน (`lung_ring_told`) → แหวนในโคลนหน้าประตูน้ำตอนน้ำลง (หุ่นบริษัทเดินเฝ้า) → ให้ลุง = ขอป้านกแต่งงาน (`ally_nok`).
  ทางเลือกสุดท้าย: กล่อง → เจ๊เกียว (line `event: "offer_sell"`) หรือ กล่อง → เครื่องสูบที่สถานี (`event: "open_valve"`);
  Main ตั้ง `_choice_after_dialog` แล้วเปิดการ์ดหลัง dialog จบ. `end_game(id)` = flag `ending_<id>` + ออโต้เซฟ + การ์ด (เล่นใหม่/หน้าแรก).
  ตอนจบ: sold / sunk (<3) / wet (3–5) / five_stars (ครบ 6). dialog บท 3 ใช้หัว chain ใหม่ `talk_x_ch3` → else หัวเดิม (rooms.gd ชี้หัวใหม่).
  test: `test_walkthrough_chapter_three_best_ending`, `test_chapter_three_sell_the_box`, `test_endings.gd`, tap audit มีชุด flag บท 3
- **ใบ้ในเกม**: ยื่นของผิดให้คนที่เป็นด่านสำคัญ ให้มี use เฉพาะที่พูดใบ้ (เช่น จดหมาย → ป้านก = "เขียนตัวโตๆ ใส่สมุดมา") — เจ้าของติดตรงกล่องป้านก 2026-10-02
- **ฉาก + ภาพของ (2026-10-02, เจ้าของ: "ทำฉากให้เรียบร้อย ก่อนไป A4 / ทำ item ที่ตกให้เป็นภาพ และ item ใน inventory ด้วย")**:
  - backdrop ทุกห้อง = `tools/art/png/rooms_2090.py all` → `assets/art/rooms/<room id>.png` (ใช้ helper ของ room.py: teak_wall,
    zinc_wall, brick_wall, concrete_floor, tile_floor + ของใหม่ plaster_wall (หน้าต่างเห็นตึกหลังกำแพงกันทะเล), plank_floor,
    flood_line (คราบน้ำท่วมบนผนัง), flood_surround (มุมนอกพื้น = น้ำคลอง + ผักตบ + ขอบพื้นยกสูง)). render ทั้งหมด ~7 นาที
    เพิ่มห้องใหม่ = เพิ่มฟังก์ชันใน ROOMS ของไฟล์นี้ (ขนาด grid ต้องตรงกับ rooms.gd). สี floor/wall ใน recipe ใช้แค่ตอนไม่มี backdrop
  - ไอคอนของ = `tools/art/png/items.py all assets/art/items` (192×192, ตัดขอบ+จัดกลาง) → `ArtLibrary.item(id)`;
    `MarkerSpot` วาดไอคอนด้วย `draw_texture_rect` (ไม่ใช้ Sprite2D เพื่อให้แตะด้วย pick_rect กว้างๆ), ปุ่มกระเป๋า `icon` + ชื่อ.
    ของใหม่ต้องเพิ่มฟังก์ชันใน `ITEMS` ของ items.py
- **แตะของไม่โดน (2026-10-02, เจ้าของ: "หยิบรีโมทยากมาก เพราะจะไปโดนเตียงตลอด")**: ของบนพื้น/ทางออกไม่มี Sprite2D ใช้ `pick_rect`
  แต่ `Player.pick` เดิมให้ภาพ sprite ชนะ rect เสมอ → ของเล็กข้างหน้าโดนของใหญ่ข้างหลังแย่งแตะ (รีโมท/เตียง, ไม้แขวน/ตู้, เทป/โต๊ะช่าง).
  แก้: node แบบ rect ชนะ sprite ที่โดน ถ้ามันอยู่หน้ากว่า (y ≥). pick_rect ของ item = รอบไอคอน (-60,-116,120,132),
  ทางออก = วงแหวน+ลูกศร (-80,-130,160,165) ไม่สูงทั้งเสา (ไม่งั้นแย่งแตะ prop ข้างหลัง).
  **`test/unit/test_tap_targets.gd`** ตรวจทุกห้อง × flag บท 1/บท 2 × น้ำขึ้น/ลง: แตะกลางของ/คน/ทางออกต้องได้ตัวมันเอง,
  prop ต้องมี ≥ 35% ของภาพที่แตะแล้วได้ตัวมัน — **วางของใหม่แล้วรัน test นี้เสมอ**. prop ทุกชิ้นต้องมี dialog (ไม่มีแตะแล้วเงียบ)
  art ที่ใช้ผิดชิ้นถูกแทนแล้ว: rental_bed (เดิมโซฟา), debt_board (เดิมป้ายเสา steampunk), boat_noodle_stall (เดิมรถเข็นมีร่ม),
  kiao_desk (เดิมโต๊ะ RECEPTION ภาษาอังกฤษ) ใน props_2090.py
- **UI แบบของในโลกเกม (2026-10-02, เจ้าของ: "เมนูเหมือน powerpoint ไม่เหมือนเกม")**: art = `tools/art/png/ui_2090.py` → `assets/art/ui/`
  (PIL+numpy, ~30 วิ). **เมนูในเกม = สมุดหนี้เปิดอยู่** (`MenuBook`, `scripts/ui/menu_book.gd`: หน้าซ้าย = รายการเขียนมือ + วงปากกาแดงรอบหน้าที่เปิด,
  หน้าขวา = คำใบ้ (เขียนลงสมุด ไม่เปิด dialog) / บันทึก / โหลด / ตั้งค่า; แตะนอกสมุด/ปิดสมุด/Esc = ปิด). ปุ่มเมนูมุมขวาบน = สมุดหนี้ปิด.
  **ปุ่ม = ป้ายสังกะสีเขียนมือ** (`UiKit.sign_button`, 9-slice `sign*.png` margin 30; "teal" = ป้ายท่าเรือในเมนูรถลอยน้ำ),
  **การ์ดเรื่อง/ตอนจบ/ตัวเลือก = กระดาษโน้ตแปะเทป** (`UiKit.note_style`, 9-slice margin 96 + tile — เทปต้องอยู่ในมุม 96px ไม่งั้นซ้ำตามขอบ)
  บนพื้นมืด (`UiKit.dim`) + `drop_in` (เอียงนิดๆ เด้ง). ในสมุด/กระดาษใช้ `hand_label/hand_button/hand_check/ink_slider` (หมึก).
  ฟอนต์: **Sriracha** = ลายมือ, **Mali SemiBold** = ตัวเขียนป้าย (OFL ทั้งคู่, `assets/fonts/OFL-*.txt`), Kanit = เนื้อความยาว.
  `UiKit.juice()` = ยุบตอนกด เด้งตอนปล่อย. ยังไม่ได้ขัด: แถบกระเป๋า, กล่อง dialog, หน้าแรก (ใช้ป้าย/กระดาษแล้วแต่ยังไม่มีฉากหลัง)
- `internationalization/locale/include_text_server_data=true` (ตัดคำไทยบน APK ต้องใช้ข้อมูล ICU)
- **ห้องอัปเดตทันทีเมื่อ flag เปลี่ยน (2026-10-02, เจ้าของ: "ช่างแดงไม่ออกมาจากเรือ ทั้งที่ดึงฟิวส์แล้ว — ออกมาหลังไปที่อื่น")**:
  เดิมห้องสร้างครั้งเดียวตอนเข้า → อะไรที่ `if_flag`/`if_not_flag`/`if_flags` ผูกกับ flag ที่ตั้งในห้องเดียวกันไม่โผล่/ไม่หาย
  (ช่างแดง, ทางเข้าสถานีหลังหมุนประตูน้ำ, งานแต่ง). ตอนนี้ `AdventureRoom._on_flag` → ถ้า flag อยู่ใน `Rooms.condition_flags(room)` →
  `Main.refresh_room()` (รอ dialog จบก่อน) → โหลดห้องใหม่ไม่ fade ที่ spawn `"keep"` (ไรเดอร์อยู่ที่เดิม; `GameState.spawn` ไม่เปลี่ยน
  เซฟยังโหลดที่ประตูจริง). การรอน้ำ (ม้านั่ง) ก็ใช้ทางนี้. test `test_room_updates_when_a_flag_changes_while_inside`
- ข้อความไทยที่วาดลง PNG (PIL) ต้องเผื่อที่ด้านบนให้วรรณยุกต์ — ป้าย "หนี้" บนไอคอนสมุดเคยเหลือ "หนี" (ใช้ anchor "ms" + กรอบสูง)
- **PatrolBot** (A0): ไล่ถ้า `chases` (ไม่มีเงื่อนไขถือของแล้ว), จับได้ = `catch_dialog` + ผลัก, `distract_flag`/`distract_dir`/`distract_mark`
  = หยุดถาวรเมื่อ flag ถูกตั้ง (เช็คตอน `_ready` + `GameState.flag_changed`)
- Gotcha: script ที่รันด้วย `godot -s` (shot/tool) ห้ามอ้าง class ที่อ้าง autoload ตอน compile (เช่น `Rooms` → `GameState` → `Puzzles`)
  → "Identifier not found" — ใช้ `load("res://...")` ตอน runtime แทน
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
- **adb wireless (2026-10-02)**: เจ้าของใช้ **Tailscale** และเครื่อง build อยู่คนละที่กับแท็บเล็ต → `update.ps1 -Device 190:40011`
  (สั้น = หา peer ใน `tailscale status` ที่ IP ลงท้าย .190 ก่อน ไม่เจอค่อยใช้ prefix LAN ของ PC; IP เต็ม/ชื่อ MagicDNS ก็ได้) → `adb connect`
  → จำไว้ใน `tools/.adb_device` (gitignored) รอบหน้าไม่ต้องใส่. พอร์ต wireless debugging เปลี่ยนทุกครั้งที่เปิดใหม่ → ใส่ -Device ใหม่
  ครั้งแรกจาก PC เครื่องไหน ต้อง `-Pair <พอร์ตจับคู่>:<รหัส 6 หลัก>` (หน้า "Pair device with pairing code"; คนละพอร์ตกับ connect).
  connect ล้มเหลว → สคริปต์ ping + เช็คพอร์ต แล้วบอกว่าเป็นที่ Tailscale / พอร์ตเปลี่ยน / ยังไม่ได้ pair
  Redmi Pad Pro ใน Tailscale = `100.90.8.123` (ใช้ `-Device 100.90.8.123:<พอร์ตจากหน้า Wireless debugging>` หรือสั้นๆ `123:<พอร์ต>`)
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
- **A0–A4 เสร็จ (2026-10-02)**: เกมเล่นจบได้ 3 บท 8 ห้อง ตอนจบ 4 แบบ, plot ย่อย 3 สาย (ลุงโต๊ะสาม×ป้านก → งานแต่ง, ลอตเตอรี่ป้าจุ๋ม, หุ่นเก้า), 66 tests
- UI: เมนูในเกม + การ์ด + ตัวเลือก + ปุ่มหน้าแรก ขัดแล้ว (2026-10-02); เหลือแถบกระเป๋า, กล่อง dialog, ฉากหลังหน้าแรก
- ยังไม่มี: เสียง
- ลบ save บนแท็บเล็ต = `adb shell run-as com.drums55.game25d rm files/save_0.json`
