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
- Target: Redmi Pad Pro (2560×1600, 16:10, Android 16) + Samsung S24 FE; landscape; touch
- Dev loop = PC: `tools\update.ps1` (pull → headless export → adb install wireless → launch)
- **CI ห้าม build APK** (quota Actions 500 MB เคยเต็มใน repo blackbox) — CI = gdformat/gdlint + GUT เท่านั้น
- Godot Android editor บน tablet = ของแถม ไม่ใช่ทางหลัก

## โครงสร้าง
```
project.godot            viewport 1920x1200, stretch canvas_items/expand, sensor landscape
export_presets.cfg       preset "Android": arm64 only, non-gradle, package com.drums55.game25d
scenes/main.tscn         root: RoomHolder + Player (persistent) + HUD
scenes/rooms/*.tscn      IsoRoom: World (y-sort) + Spawns (Marker2D ชื่อ = spawn id)
scenes/characters/       cutout_rig.tscn (Skeleton2D: Hip > LegL/LegR/Torso > ArmL/ArmR/Head)
scenes/props/            prop_block, door, npc, interactable, training_dummy
scenes/ui/               hud (joystick + ATK/USE + prompt), dialog_box
scripts/autoload/        GameState (flags, save/load), Dialog (runner), SceneRouter (fade + room swap)
scripts/core/            Iso (math), SaveData, DialogData — pure logic, unit-tested
assets/dialog/dialog.json  dialog ทั้งหมด (format อยู่หัวไฟล์ scripts/core/dialog_data.gd)
test/unit/               GUT tests (test_scenes.gd = smoke test ทุก scene + สัญญาของห้อง)
tools/                   dev_setup.ps1, run.ps1 (เล่นบน PC), update.ps1/.sh, godot_path.ps1, run_tests.sh, fetch_gut.*
```

## Architecture / decisions
- **Input**: gameplay อ่านแค่ InputMap (`move_*`, `attack`, `interact`). Joystick/ปุ่มบนจอเรียก
  `Input.action_press` → คีย์บอร์ด/จอย/ทัช ใช้โค้ดเดียวกัน. Touch control จัดการใน `_input`
  (ไม่ใช่ gui_input) เพื่อรองรับ multi-touch, `mouse_filter = IGNORE`
- `emulate_touch_from_mouse=true` → ทดสอบ joystick ด้วยเมาส์บน PC ได้
- **การเดิน**: analog ใน screen space (แบบ Hades) + facing snap 8 ทิศ (`Iso.dir8`, 0=E หมุนตามเข็ม: E SE S SW W NW N NE)
- **Iso grid**: tile 128×64 (2:1). cell (0,0) = มุมบนของห้อง; `Iso.grid_to_world`
- **Y-sort**: origin ของทุก object = จุดที่แตะพื้น (เท้า / กลาง footprint). ห้องมี World เป็น y-sort node,
  Main ย้าย Player เข้า World ของห้องทุกครั้งที่เปลี่ยนห้อง (player persistent ไม่ instance ใหม่)
- **ห้อง**: floor/back wall วาด procedural ใน `IsoRoom._draw` (placeholder) + boundary collision
  สร้างตอน runtime จาก `grid_size`. ด้านหน้าเปิด (ไม่มีกำแพงบังตัวละคร)
- **Door**: Area2D แตะแล้ว `SceneRouter.go_to(target_room, target_spawn)`. Spawn ขาเข้าต้องอยู่หน้าประตู
  ไม่ทับ collision ประตู ไม่งั้นเด้งกลับ. test_scenes ตรวจว่า target/spawn มีจริง
- **Save**: JSON ที่ `user://save_0.json` (room, spawn, flags). autosave ทุกครั้งที่เปลี่ยนห้อง.
  save ที่ชี้ห้องที่ถูกลบ → กลับห้องเริ่มต้น
- **Dialog**: JSON-driven, `if_flag`/`else` สำหรับ branch, `set_flag` ต่อบรรทัด. แตะกล่อง/ATK/USE = next
  (ถ้ากำลังพิมพ์ = แสดงทั้งบรรทัด)
- **Cut-out rig**: animate แบบ procedural (walk swing, idle, attack) ใน `cutout_rig.gd`; rig ออกแบบหันขวา
  หันซ้าย = `scale.x = -1`; หันหลัง (NW/N/NE) = ซ่อนหน้า / สลับ texture `*_back`. ใส่ art ด้วย `CutoutSkin`
- **Attack**: Hitbox (Area2D mask layer 4) ขยับตาม facing; ตอนกดตี เรียก `take_hit(damage, from)`
  กับทุก body ที่ทับ. Physics layers: 1 world, 2 player, 3 interactable, 4 hittable

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
- ธีม/เรื่องย่อของเกม: ยังไม่ได้คุย (ชื่อห้อง/NPC ตอนนี้เป็น placeholder: Room 01/02, Elder)
- ยังไม่มี: ศัตรู/HP, inventory, เสียง, เมนู/new game (ลบ save = `adb shell run-as com.drums55.game25d rm files/save_0.json`)
