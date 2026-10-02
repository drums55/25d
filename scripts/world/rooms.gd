# gdlint: disable=max-file-lines
class_name Rooms
extends RefCounted
## Hand-made rooms of กรุงเทพฯ 2090 (DESIGN 11), keyed by room id; built by
## AdventureRoom. Grid positions are cells (Iso.grid_to_world).
##
## Recipe keys:
##   title, grid, floor [a, b], wall, spawns {id: cell}
##   props    [{id, art?, pos, foot, h, color?, dialog?, prompt?, action?,
##              exit_to?, exit_spawn?, exit_flag?, locked_dialog?}]
##            action "travel" = the floating bike (opens the trip menu)
##            `id` = thing id for item uses; no art = placeholder block
##   pickups  [{item, pos, label, text?}]  gone once "got_<item>" is set
##   npcs     [{id, name, pos, character, tint?, dialog}]
##   exits    [{to, spawn, pos, label}]
##   bots     [{id, name, pos, patrol [cells, offsets], character, tint,
##              catch_dialog, talk_dialog, distract_flag?, distract_dir?,
##              art?, steam_powered?, tamperable?, distract_mark?}]
##   enter    {dialog, flag}  played once on arrival (flag marks it seen)
## Any entry may carry "if_flag" / "if_not_flag" / "if_flags" [all] / "if_tide"
## (spawn only then). Chapter 2 people/things use "if_flag": "ch2".
## Places the bike can ride to are in TRAVEL (spawn "from_bike" there).
## A painted backdrop drops in as assets/art/rooms/<room id>.png.
## Gap rule as before: nothing 0.85-1.15 cells from a wall or another solid
## thing (navmesh slivers) — test_rooms checks every recipe.

const LUNG := "lung_pradit"
const JE := "je_muay"

const ROOMS := {
	"home":
	{
		"title": "ห้องเช่าเหนือคลอง · ชั้นสอง (ชั้นหนึ่งเป็นคลองไปแล้ว)",
		"grid": Vector2i(10, 8),
		"floor": [Color(0.55, 0.42, 0.3), Color(0.5, 0.38, 0.27)],
		"wall": Color(0.42, 0.56, 0.52),
		"spawns": {"default": Vector2(4.0, 5.5), "from_pier": Vector2(8.0, 4.0)},
		"props":
		[
			{
				"id": "bed",
				"art": "rental_bed",
				"pos": Vector2(2.0, 0.6),
				"foot": Vector2(1.6, 0.8),
				"h": 45.0,
				"dialog": "look_bed",
				"prompt": "ที่นอน"
			},
			{
				"id": "wardrobe",
				"art": "wardrobe",
				"pos": Vector2(5.0, 0.5),
				"foot": Vector2(1.2, 0.6),
				"h": 200.0,
				"color": Color(0.45, 0.3, 0.2),
				"dialog": "look_wardrobe"
			},
			{
				"id": "debt_board",
				"art": "debt_board",
				"pos": Vector2(7.2, 0.15),
				"foot": Vector2(0.5, 0.3),
				"h": 110.0,
				"dialog": "look_debt_board"
			},
			{
				"id": "floor_gap",
				"art": "floor_gap",
				"pos": Vector2(4.6, 3.6),
				"foot": Vector2(1.0, 0.5),
				"h": 4.0,
				"color": Color(0.12, 0.1, 0.1),
				"dialog": "look_floor_gap",
				"prompt": "ร่องพื้น"
			},
			{
				"id": "plant",
				"art": "plant_pots",
				"pos": Vector2(0.6, 4.0),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "look_plant"
			},
			{
				"id": "trash",
				"art": "trash_bin",
				"pos": Vector2(0.8, 7.2),
				"foot": Vector2(0.8, 0.8),
				"h": 60.0,
				"dialog": "look_trash"
			},
		],
		"pickups":
		[
			{"item": "hanger", "pos": Vector2(5.6, 1.6), "label": "ไม้แขวนเสื้อ"},
			{"item": "air_remote", "pos": Vector2(2.6, 1.9), "label": "รีโมท"},
			{"item": "letter", "pos": Vector2(8.4, 5.8), "label": "จดหมาย"},
		],
		"exits":
		[{"to": "pier", "spawn": "from_home", "pos": Vector2(9.4, 4.0), "label": "ลงท่าเรือ"}],
	},
	"pier":
	{
		"title": "ท่าเรือหน้าซอยส่งไว",
		"grid": Vector2i(12, 9),
		"floor": [Color(0.46, 0.36, 0.26), Color(0.42, 0.33, 0.24)],
		"wall": Color(0.36, 0.42, 0.5),
		"spawns":
		{
			"default": Vector2(1.6, 2.6),
			"from_home": Vector2(1.6, 2.6),
			"from_bike": Vector2(8.0, 5.6)
		},
		"props":
		[
			{
				"id": "float_bike",
				"art": "boat_bike",
				"pos": Vector2(10.0, 7.0),
				"foot": Vector2(1.4, 0.7),
				"h": 90.0,
				"prompt": "เรือเตอร์ไซค์",
				"action": "travel",
				"exit_flag": "bike_ready",
				"locked_dialog": "look_bike_locked"
			},
			{
				"id": "longtail",
				"art": "longtail_boat",
				"pos": Vector2(6.5, 0.7),
				"foot": Vector2(2.6, 0.8),
				"h": 80.0,
				"dialog": "look_longtail"
			},
			{
				"id": "pier_sign",
				"art": "pier_sign",
				"pos": Vector2(2.2, 0.15),
				"foot": Vector2(0.5, 0.3),
				"h": 120.0,
				"dialog": "look_pier_sign"
			},
			{
				"id": "radio",
				"art": "steam_radio",
				"pos": Vector2(1.6, 6.0),
				"foot": Vector2(0.6, 0.5),
				"h": 40.0,
				"color": Color(0.25, 0.55, 0.55),
				"dialog": "look_radio",
				"prompt": "วิทยุ"
			},
			{
				"id": "crate",
				"art": "crate",
				"pos": Vector2(3.0, 4.2),
				"foot": Vector2(0.9, 0.9),
				"h": 60.0,
				"dialog": "look_pier_crate"
			},
			{
				"id": "crate",
				"art": "crate",
				"pos": Vector2(3.0, 5.4),
				"foot": Vector2(0.9, 0.9),
				"h": 60.0,
				"dialog": "look_pier_crate"
			},
			{
				"id": "jar",
				"art": "dragon_jar",
				"pos": Vector2(10.8, 2.0),
				"foot": Vector2(0.8, 0.8),
				"h": 90.0,
				"dialog": "look_jar"
			},
		],
		"exits":
		[{"to": "home", "spawn": "from_pier", "pos": Vector2(0.6, 2.4), "label": "ขึ้นห้อง"}],
		"bots":
		[
			{
				"id": "collector",
				"name": "พี่หนวด (คนทวงหนี้)",
				"pos": Vector2(7.0, 4.5),
				"patrol": [Vector2(-2.5, 0.0), Vector2(2.0, 0.0)],
				"character": LUNG,
				"tint": Color(0.8, 0.5, 0.45),
				"catch_dialog": "catch_nuad",
				"talk_dialog": "talk_nuad",
				"distract_flag": "radio_on",
				"distract_dir": Vector2(-1, 0.5),
				"if_not_flag": "ch2"
			},
		],
		"npcs":
		[
			{
				"id": "nuad",
				"name": "พี่หนวด (ตกงาน)",
				"pos": Vector2(5.6, 4.5),
				"character": LUNG,
				"tint": Color(0.8, 0.5, 0.45),
				"dialog": "talk_nuad_ch3",
				"if_flag": "ch2"
			},
		],
	},
	"noodle_boat":
	{
		"title": "เรือก๋วยเตี๋ยวป้านก · ลอยลำกลางคลอง",
		"grid": Vector2i(10, 7),
		"floor": [Color(0.6, 0.45, 0.3), Color(0.56, 0.42, 0.28)],
		"wall": Color(0.85, 0.45, 0.2),
		"spawns": {"default": Vector2(6.8, 6.3), "from_bike": Vector2(6.8, 6.3)},
		"props":
		[
			{
				"id": "noodle_pot",
				"art": "boat_noodle_stall",
				"pos": Vector2(4.5, 0.8),
				"foot": Vector2(1.6, 0.9),
				"h": 90.0,
				"dialog": "look_noodle_pot",
				"prompt": "หม้อก๋วยเตี๋ยว"
			},
			{
				"id": "boat_table",
				"art": "steel_table",
				"pos": Vector2(6.5, 3.8),
				"foot": Vector2(1.0, 1.0),
				"h": 55.0,
				"dialog": "look_boat_table"
			},
			{
				"id": "stool",
				"art": "red_stool",
				"pos": Vector2(5.4, 4.6),
				"foot": Vector2(0.4, 0.4),
				"h": 30.0,
				"dialog": "look_boat_stool"
			},
			{
				"id": "stool",
				"art": "red_stool",
				"pos": Vector2(7.4, 3.0),
				"foot": Vector2(0.4, 0.4),
				"h": 30.0,
				"dialog": "look_boat_stool"
			},
			{
				"id": "jar",
				"art": "dragon_jar",
				"pos": Vector2(1.0, 1.0),
				"foot": Vector2(0.8, 0.8),
				"h": 90.0,
				"dialog": "look_boat_jar"
			},
			{
				"id": "float_bike",
				"art": "boat_bike",
				"pos": Vector2(8.6, 5.9),
				"foot": Vector2(1.4, 0.7),
				"h": 90.0,
				"prompt": "เรือเตอร์ไซค์",
				"action": "travel"
			},
		],
		"npcs":
		[
			{
				"id": "pa_nok",
				"name": "ป้านก",
				"pos": Vector2(4.5, 2.0),
				"character": JE,
				"tint": Color(1, 0.9, 0.85),
				"dialog": "talk_pa_nok_ch3"
			},
			{
				"id": "lung_table3",
				"name": "ลุงโต๊ะสาม",
				"pos": Vector2(3.0, 4.8),
				"character": LUNG,
				"tint": Color(1, 0.92, 0.8),
				"dialog": "talk_lung_ch3"
			},
		],
	},
	"stilts":
	{
		"title": "ชุมชนยกเสา · ทางเดินไม้เหนือน้ำ",
		"grid": Vector2i(12, 9),
		"floor": [Color(0.5, 0.4, 0.3), Color(0.46, 0.37, 0.28)],
		"wall": Color(0.36, 0.55, 0.58),
		"spawns": {"default": Vector2(8.0, 5.6), "from_bike": Vector2(8.0, 5.6)},
		"props":
		[
			{
				"id": "water_tank",
				"art": "water_tank",
				"pos": Vector2(1.2, 1.2),
				"foot": Vector2(1.0, 1.0),
				"h": 190.0,
				"dialog": "look_stilt_tank"
			},
			{
				"id": "spirit_house",
				"art": "spirit_house",
				"pos": Vector2(3.6, 0.6),
				"foot": Vector2(0.7, 0.7),
				"h": 160.0,
				"dialog": "look_spirit_2090"
			},
			{
				"id": "plant",
				"art": "plant_pots",
				"pos": Vector2(6.0, 0.5),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "look_stilt_plant"
			},
			{
				"id": "stilt_gate",
				"art": "house_gate",
				"pos": Vector2(8.5, 0.5),
				"foot": Vector2(1.2, 0.6),
				"h": 50.0,
				"dialog": "look_stilt_gate"
			},
			{
				"id": "tire_planter",
				"art": "tire_planter",
				"pos": Vector2(11.0, 2.2),
				"foot": Vector2(0.7, 0.7),
				"h": 60.0,
				"dialog": "look_tire_planter"
			},
			{
				"id": "float_bike",
				"art": "boat_bike",
				"pos": Vector2(10.0, 7.0),
				"foot": Vector2(1.4, 0.7),
				"h": 90.0,
				"prompt": "เรือเตอร์ไซค์",
				"action": "travel"
			},
		],
		"npcs":
		[
			{
				"id": "jum",
				"name": "ป้าจุ๋ม",
				"pos": Vector2(5.0, 3.6),
				"character": JE,
				"tint": Color(1, 0.8, 0.95),
				"dialog": "talk_jum_ch3"
			},
			{
				"id": "keng",
				"name": "น้องเก่ง",
				"pos": Vector2(2.4, 6.0),
				"character": JE,
				"tint": Color(0.8, 0.9, 1),
				"dialog": "talk_keng_ch3"
			},
		],
	},
	"boat_garage":
	{
		"title": "อู่เรือช่างแดง · ใต้ทางด่วน",
		"grid": Vector2i(12, 9),
		"floor": [Color(0.4, 0.4, 0.42), Color(0.36, 0.36, 0.38)],
		"wall": Color(0.45, 0.47, 0.5),
		"spawns": {"default": Vector2(8.0, 5.6), "from_bike": Vector2(8.0, 5.6)},
		"props":
		[
			{
				"id": "upturned_boat",
				"art": "upturned_boat",
				"pos": Vector2(5.0, 2.6),
				"foot": Vector2(2.2, 0.8),
				"h": 90.0,
				"dialog": "look_upturned_boat",
				"prompt": "เรือคว่ำ"
			},
			{
				"id": "garage_bench",
				"art": "tool_bench",
				"pos": Vector2(9.0, 0.6),
				"foot": Vector2(1.5, 1.0),
				"h": 70.0,
				"dialog": "look_garage_bench"
			},
			{
				"id": "tires",
				"art": "tire_stack",
				"pos": Vector2(0.8, 4.5),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "look_garage_tires"
			},
			{
				"id": "crate",
				"art": "crate",
				"pos": Vector2(1.0, 7.0),
				"foot": Vector2(0.9, 0.9),
				"h": 60.0,
				"dialog": "look_garage_crate"
			},
			{
				"id": "float_bike",
				"art": "boat_bike",
				"pos": Vector2(10.0, 7.0),
				"foot": Vector2(1.4, 0.7),
				"h": 90.0,
				"prompt": "เรือเตอร์ไซค์",
				"action": "travel"
			},
		],
		"pickups": [{"item": "tape", "pos": Vector2(9.0, 2.0), "label": "เทปพันสายไฟ"}],
		"extra_props":
		[
			{
				"id": "no9_awake",
				"art": "brass_automaton",
				"pos": Vector2(3.5, 4.6),
				"foot": Vector2(0.6, 0.6),
				"h": 150.0,
				"dialog": "talk_nine_ch3",
				"prompt": "หุ่นเบอร์ 9",
				"if_flag": "ch2",
				"if_not_flag": "ally_nine"
			},
		],
		"npcs":
		[
			{
				"id": "chang_daeng",
				"name": "ช่างแดง",
				"pos": Vector2(7.0, 3.8),
				"character": LUNG,
				"tint": Color(1, 0.8, 0.7),
				"dialog": "talk_chang_daeng_ch3",
				"if_flag": "no9_fused"
			},
		],
		"bots":
		[
			{
				"id": "no9",
				"name": "หุ่นทวงหนี้เบอร์ 9",
				"art": "brass_automaton",
				"pos": Vector2(3.5, 4.6),
				"patrol": [Vector2(-1.5, 0.0), Vector2(2.0, 0.0)],
				"facing": Vector2(-1, -0.5),
				"view_range": 220.0,
				"tint": Color(1, 0.6, 0.45),
				"steam_powered": true,
				"tamperable": true,
				"catch_dialog": "catch_no9",
				"talk_dialog": "catch_no9",
				"distract_flag": "no9_fused",
				"distract_mark": "zz",
				"speed": 60.0,
				"if_not_flag": "ch2"
			},
		],
	},
	"old_gate":
	{
		"title": "ใต้สะพาน · ประตูระบายน้ำเก่า",
		"grid": Vector2i(12, 8),
		"floor": [Color(0.42, 0.44, 0.42), Color(0.38, 0.4, 0.38)],
		"wall": Color(0.3, 0.36, 0.4),
		"spawns":
		{
			"default": Vector2(8.0, 5.0),
			"from_bike": Vector2(8.0, 5.0),
			"from_station": Vector2(6.0, 2.6)
		},
		"props":
		[
			{
				"id": "sluice_gate",
				"art": "sluice_gate",
				"pos": Vector2(6.0, 0.6),
				"foot": Vector2(2.0, 0.6),
				"h": 300.0,
				"dialog": "look_gate_low",
				"if_tide": "low"
			},
			{
				"id": "sluice_gate",
				"art": "sluice_flooded",
				"pos": Vector2(6.0, 0.6),
				"foot": Vector2(2.0, 0.6),
				"h": 100.0,
				"dialog": "look_gate_high",
				"if_tide": "high"
			},
			{
				"id": "tide_gauge",
				"art": "tide_gauge",
				"pos": Vector2(9.6, 0.5),
				"foot": Vector2(0.3, 0.3),
				"h": 300.0,
				"dialog": "look_tide_gauge"
			},
			{
				"id": "bench",
				"art": "wait_bench",
				"pos": Vector2(3.0, 1.0),
				"foot": Vector2(1.2, 0.4),
				"h": 50.0,
				"dialog": "wait_tide",
				"prompt": "นั่งรอ"
			},
			{
				"id": "float_bike",
				"art": "boat_bike",
				"pos": Vector2(10.0, 6.2),
				"foot": Vector2(1.4, 0.7),
				"h": 90.0,
				"prompt": "เรือเตอร์ไซค์",
				"action": "travel"
			},
		],
		"exits":
		[
			{
				"to": "station",
				"spawn": "default",
				"pos": Vector2(6.0, 1.6),
				"label": "เข้าไป",
				"if_flag": "gate_open",
				"if_tide": "low"
			},
		],
		# chapter 3: ลุงโต๊ะสาม's ring in the mud, guarded by the company's robot
		# until เก้า comes to talk it to sleep
		"pickups":
		[
			{
				"item": "ring",
				"pos": Vector2(1.6, 2.6),
				"label": "แหวน",
				"text": 'ล้วงโคลนหน้าประตูน้ำ ... แหวนทองเล็กๆ ด้านในสลักว่า "นก 2060"',
				"if_flag": "lung_ring_told",
				"if_tide": "low"
			},
		],
		"extra_props":
		[
			{
				"id": "nine_gate",
				"art": "brass_automaton",
				"pos": Vector2(2.8, 5.2),
				"foot": Vector2(0.6, 0.6),
				"h": 150.0,
				"dialog": "talk_nine_gate",
				"prompt": "เก้า",
				"if_flag": "ally_nine"
			},
		],
		"bots":
		[
			{
				"id": "company_bot",
				"name": "หุ่นบริษัท ป้องกันภัย",
				"art": "brass_automaton",
				"pos": Vector2(4.0, 4.5),
				"patrol": [Vector2(0.0, -1.9), Vector2(0.0, 0.9)],
				"facing": Vector2(-1, 0.5),
				"view_range": 220.0,
				"tint": Color(0.7, 0.85, 1.0),
				"catch_dialog": "catch_company",
				"talk_dialog": "catch_company",
				"distract_flag": "ally_nine",
				"distract_dir": Vector2(-1, 0),
				"distract_mark": "~ ฟังเก้าเล่า ~",
				"speed": 65.0,
				"if_flag": "ch3"
			},
		],
	},
	"kiao_raft":
	{
		"title": "เรือนแพเจ๊เกียว · เงินด่วน ดอกไม่ด่วน",
		"grid": Vector2i(10, 8),
		"floor": [Color(0.42, 0.26, 0.2), Color(0.38, 0.23, 0.18)],
		"wall": Color(0.55, 0.18, 0.16),
		"spawns": {"default": Vector2(6.8, 6.0), "from_bike": Vector2(6.8, 6.0)},
		"enter": {"dialog": "enter_kiao", "flag": "seen_kiao"},
		"props":
		[
			{
				"id": "kiao_desk",
				"art": "kiao_desk",
				"pos": Vector2(5.0, 0.6),
				"foot": Vector2(2.4, 0.7),
				"h": 85.0,
				"dialog": "look_kiao_desk"
			},
			{
				"id": "kiao_files",
				"art": "parcel_shelf",
				"pos": Vector2(9.0, 0.6),
				"foot": Vector2(0.8, 0.8),
				"h": 60.0,
				"dialog": "look_kiao_files"
			},
			{
				"id": "kiao_sofa",
				"art": "sofa",
				"pos": Vector2(1.6, 4.5),
				"foot": Vector2(1.6, 0.8),
				"h": 45.0,
				"color": Color(0.6, 0.15, 0.15),
				"dialog": "look_kiao_sofa"
			},
			{
				"id": "rental_robot",
				"art": "brass_automaton",
				"pos": Vector2(2.0, 1.0),
				"foot": Vector2(0.6, 0.6),
				"h": 150.0,
				"dialog": "look_rental_robot"
			},
			{
				"id": "rental_robot",
				"art": "brass_automaton",
				"pos": Vector2(7.8, 2.8),
				"foot": Vector2(0.6, 0.6),
				"h": 150.0,
				"dialog": "look_rental_robot"
			},
			{
				"id": "jar",
				"art": "dragon_jar",
				"pos": Vector2(1.0, 7.0),
				"foot": Vector2(0.8, 0.8),
				"h": 90.0,
				"dialog": "look_kiao_jar"
			},
			{
				"id": "float_bike",
				"art": "boat_bike",
				"pos": Vector2(8.6, 6.9),
				"foot": Vector2(1.4, 0.7),
				"h": 90.0,
				"prompt": "เรือเตอร์ไซค์",
				"action": "travel"
			},
		],
		"npcs":
		[
			{
				"id": "kiao",
				"name": "เจ๊เกียว",
				"pos": Vector2(5.0, 2.0),
				"character": JE,
				"tint": Color(1, 0.85, 0.5),
				"dialog": "talk_kiao_ch3"
			},
		],
	},
	"station":
	{
		"title": "บ้านเลขที่ 0 · สถานีสูบน้ำใต้ซอย",
		"grid": Vector2i(10, 8),
		"floor": [Color(0.24, 0.26, 0.27), Color(0.21, 0.23, 0.24)],
		"wall": Color(0.18, 0.28, 0.3),
		"spawns": {"default": Vector2(5.5, 5.0)},
		"enter": {"dialog": "enter_station", "flag": "seen_station"},
		"props":
		[
			{
				"id": "pump",
				"art": "pump_engine",
				"pos": Vector2(3.0, 0.6),
				"foot": Vector2(1.8, 1.0),
				"h": 240.0,
				"dialog": "look_pump"
			},
			{
				"id": "zero_plate",
				"art": "house_zero_plate",
				"pos": Vector2(5.6, 0.3),
				"foot": Vector2(0.5, 0.3),
				"h": 170.0,
				"dialog": "look_zero_plate",
				"prompt": "ป้าย"
			},
			{
				"id": "station_valve",
				"art": "steam_valve",
				"pos": Vector2(8.0, 0.5),
				"foot": Vector2(0.5, 0.5),
				"h": 120.0,
				"dialog": "look_station_valve"
			},
		],
		"exits":
		[{"to": "old_gate", "spawn": "from_station", "pos": Vector2(9.2, 4.0), "label": "ออก"}],
		"npcs":
		[
			{
				"id": "wan",
				"name": "คุณนายวรรณ",
				"pos": Vector2(5.5, 3.0),
				"character": JE,
				"tint": Color(0.75, 0.8, 0.95),
				"dialog": "talk_wan_ch3",
				"if_flags": ["ch2", "got_debt_list", "nok_love"]
			},
		],
	},
}

## Where the floating bike can go: room id -> {name, flag needed}.
const TRAVEL := {
	"pier": {"name": "ท่าเรือหน้าซอย", "flag": ""},
	"noodle_boat": {"name": "เรือก๋วยเตี๋ยวป้านก", "flag": ""},
	"stilts": {"name": "ชุมชนยกเสา (ป้าจุ๋ม)", "flag": "know_stilts"},
	"boat_garage": {"name": "อู่เรือช่างแดง", "flag": "know_garage"},
	"old_gate": {"name": "ประตูระบายน้ำเก่าใต้สะพาน", "flag": "know_gate"},
	"kiao_raft": {"name": "เรือนแพเจ๊เกียว", "flag": "know_kiao"},
}


static func get_room(id: String) -> Dictionary:
	return ROOMS.get(id, ROOMS[GameState.START_ROOM])


static func title(id: String) -> String:
	return str(get_room(id).get("title", id))


## Spawn only when the entry's flag conditions hold.
static func present(entry: Dictionary, flags: Dictionary) -> bool:
	var need := str(entry.get("if_flag", ""))
	var never := str(entry.get("if_not_flag", ""))
	if not need.is_empty() and not flags.get(need, false):
		return false
	if not never.is_empty() and flags.get(never, false):
		return false
	if entry.has("item") and flags.get("got_%s" % entry["item"], false):
		return false
	for f in entry.get("if_flags", []):
		if not flags.get(f, false):
			return false
	return true


## present() + the tide condition.
static func present_now(entry: Dictionary, flags: Dictionary, tide: String) -> bool:
	var need_tide := str(entry.get("if_tide", ""))
	if not need_tide.is_empty() and need_tide != tide:
		return false
	return present(entry, flags)
