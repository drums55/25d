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
##   npcs     [{id, name, pos, character, tint?, dialog, poses?}]
##            poses {flag: anim} = special animation once the flag is set
##            (ป้าจุ๋ม shouting, the wedding wai)
##   exits    [{to, spawn, pos, label}]
##   bots     [{id, name, pos, patrol [cells, offsets], character, tint,
##              catch_dialog, talk_dialog, distract_flag?, distract_dir?,
##              art?, tamperable?, distract_mark?, zone_range?, zone_angle?,
##              noise_dir?, seizes?}]  the living gates (PatrolBot): robots
##              (no character) face the rider and turn to a "noise" event
##   seized   [cells]  where items taken "for the debt" lie (เจ๊เกียว's raft)
##   enter    {dialog, flag}  played once on arrival (flag marks it seen)
## Any entry may carry "if_flag" / "if_not_flag" / "if_flags" [all] / "if_not_flags"
## [none] / "if_tide"
## (spawn only then). Chapter 2 people/things use "if_flag": "ch2".
## Places the bike can ride to are in TRAVEL (spawn "from_bike" there, a spot
## on the map).
## A painted backdrop drops in as assets/art/rooms/<room id>.png.
## Gap rule as before: nothing 0.85-1.15 cells from a wall or another solid
## thing (navmesh slivers) — test_rooms checks every recipe.

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
			# off the collector's zone: arriving by boat used to land inside it
			"from_bike": Vector2(7.6, 6.4)
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
				"id": "project_sign",
				"art": "project_sign_14",
				"pos": Vector2(4.2, 0.15),
				"foot": Vector2(0.5, 0.3),
				"h": 320.0,
				"dialog": "look_project_sign_14"
			},
			{
				"id": "radio",
				"art": "steam_radio",
				"pos": Vector2(1.6, 6.0),
				"foot": Vector2(0.8, 0.6),
				"h": 240.0,
				"color": Color(0.25, 0.55, 0.55),
				"dialog": "look_radio",
				"prompt": "วิทยุ"
			},
			# one crate, away from the radio (owner: boxes beside it made the radio read as a box)
			{
				"id": "crate",
				"art": "crate",
				"pos": Vector2(4.4, 2.2),
				"foot": Vector2(0.9, 0.9),
				"h": 60.0,
				"dialog": "look_pier_crate"
			},
			# chapter 2: พี่เบิ้ม จอมบุญ streams from the pier
			{
				"id": "live_boat",
				"art": "live_boat",
				"pos": Vector2(8.2, 3.4),
				"foot": Vector2(2.0, 0.8),
				"h": 230.0,
				"dialog": "look_live_boat",
				"prompt": "เรือไลฟ์สด",
				"if_flag": "ch2"
			},
			{
				"id": "drone",
				"art": "drone",
				"pos": Vector2(9.8, 5.3),
				"foot": Vector2(0.3, 0.3),
				"h": 300.0,
				"dialog": "look_drone",
				"prompt": "โดรน",
				"if_flag": "ch2"
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
				"character": "nuad",
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
				"character": "nuad",
				"dialog": "talk_nuad_ch3",
				"if_flag": "ch2"
			},
			{
				"id": "berm",
				"name": "พี่เบิ้ม จอมบุญ (ไลฟ์อยู่)",
				"pos": Vector2(3.0, 5.0),
				"character": "berm",
				"dialog": "talk_berm",
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
		"pickups":
		[{"item": "charcoal", "pos": Vector2(2.6, 2.6), "label": "ถ่านไม้", "if_flag": "ch2"}],
		"npcs":
		[
			{
				"id": "pa_nok",
				"name": "ป้านก",
				"pos": Vector2(4.5, 2.0),
				"character": "pa_nok",
				"dialog": "talk_pa_nok_ch3",
				"poses": {"ally_nok": "wai"}
			},
			{
				"id": "lung_table3",
				"name": "ลุงโต๊ะสาม",
				"pos": Vector2(3.0, 4.8),
				"character": "lung_table3",
				"dialog": "talk_lung_ch3",
				"if_not_flag": "ally_nok"
			},
			# ไรเดอร์ห้าดาว: the whole soi came to the wedding (the ending tableau)
			{
				"id": "nuad",
				"name": "พี่หนวด",
				"pos": Vector2(7.0, 1.6),
				"character": "nuad",
				"dialog": "talk_nuad_ch3",
				"if_flag": "ending_five_stars",
				"poses": {"ending_five_stars": "dance"}
			},
			{
				"id": "jum",
				"name": "ป้าจุ๋ม",
				"pos": Vector2(2.0, 3.4),
				"character": "jum",
				"dialog": "talk_jum_ch3",
				"if_flag": "ending_five_stars",
				"poses": {"ending_five_stars": "shout"}
			},
			{
				"id": "keng",
				"name": "น้องเก่ง",
				"pos": Vector2(2.4, 5.0),
				"character": "keng",
				"dialog": "talk_keng_ch3",
				"if_flag": "ending_five_stars"
			},
			# the wedding: ลุงโต๊ะสาม finally leaves table three to stand by ป้านก
			{
				"id": "lung_table3",
				"name": "ลุงโต๊ะสาม (เจ้าบ่าว)",
				"pos": Vector2(3.2, 2.0),
				"character": "lung_table3",
				"dialog": "talk_lung_ch3",
				"if_flag": "ally_nok",
				"poses": {"ally_nok": "wai"}
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
				"character": "jum",
				"dialog": "talk_jum_ch3",
				"poses": {"ally_jum": "shout"}
			},
			{
				"id": "keng",
				"name": "น้องเก่ง",
				"pos": Vector2(2.4, 6.0),
				"character": "keng",
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
				"character": "chang_daeng",
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
				"facing": Vector2(1, 0.5),
				# the spare-parts crate is screen-left of it: a kick turns it that way
				"noise_dir": Vector2(-1, 0),
				"tint": Color(1, 0.6, 0.45),
				"tamperable": true,
				"catch_dialog": "catch_no9",
				"talk_dialog": "catch_no9",
				"distract_flag": "no9_fused",
				"distract_mark": "zz",
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
				"pos": Vector2(2.8, 5.4),
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
		# chapter 1: the company's old model stands on the sluice at low tide;
		[
			# it follows ลุงหมอน้ำ's board, not the water (DESIGN 12.6)
			{
				"id": "gate_bot",
				"name": "หุ่นบริษัท (รุ่นเก่า)",
				"art": "brass_automaton",
				"pos": Vector2(6.0, 2.4),
				"facing": Vector2(0, 1),
				# covers both ends of the sluice and the way in, not the bench
				"zone_range": 210.0,
				"turns_to_noise": false,
				"tint": Color(0.75, 0.8, 0.9),
				"catch_dialog": "catch_gate_bot",
				"talk_dialog": "catch_gate_bot",
				"if_not_flags": ["ch2", "forecast_high"],
				"if_tide": "low"
			},
			{
				"id": "company_bot",
				"name": "หุ่นบริษัท ป้องกันภัย",
				"art": "brass_automaton",
				"pos": Vector2(4.0, 4.5),
				"facing": Vector2(-1, 0.5),
				# wide enough to cover the ring in the mud, not the bench or the way in
				"zone_range": 240.0,
				"turns_to_noise": false,
				"tint": Color(0.7, 0.85, 1.0),
				"catch_dialog": "catch_company",
				"talk_dialog": "catch_company",
				"distract_flag": "ally_nine",
				"distract_dir": Vector2(-1, 0),
				"distract_mark": "~ ฟังเก้าเล่า ~",
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
		"seized": [Vector2(7.6, 1.8), Vector2(8.6, 2.2), Vector2(6.6, 2.2), Vector2(7.6, 2.8)],
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
				"art": "red_sofa",
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
				"character": "kiao",
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
				"character": "wan",
				"dialog": "talk_wan_ch3",
				"if_flags": ["ch2", "got_debt_list", "evidence_pipe", "got_brochure"]
			},
		],
	},
	"hall":
	{
		"title": "ศาลาพยากรณ์น้ำ · ที่ทำการชุมชนซอยส่งไว",
		"grid": Vector2i(10, 8),
		"floor": [Color(0.62, 0.6, 0.55), Color(0.58, 0.56, 0.5)],
		"wall": Color(0.5, 0.6, 0.43),
		"spawns": {"default": Vector2(6.0, 5.5), "from_bike": Vector2(6.0, 5.5)},
		"enter": {"dialog": "enter_hall", "flag": "seen_hall"},
		"props":
		[
			{
				"id": "forecast_board",
				"art": "forecast_board",
				"pos": Vector2(2.0, 0.15),
				"foot": Vector2(0.5, 0.3),
				"h": 300.0,
				"dialog": "look_forecast_board",
				"prompt": "ป้ายพยากรณ์"
			},
			{
				"id": "goldfish_jar",
				"art": "goldfish_jar",
				"pos": Vector2(4.4, 0.6),
				"foot": Vector2(0.5, 0.5),
				"h": 200.0,
				"dialog": "look_goldfish_jar",
				"prompt": "โหลปลาทอง"
			},
			{
				"id": "project_sign",
				"art": "project_sign_15",
				"pos": Vector2(7.5, 0.15),
				"foot": Vector2(0.5, 0.3),
				"h": 320.0,
				"dialog": "look_project_sign_15"
			},
			{
				"id": "transistor",
				"art": "transistor_radio",
				"pos": Vector2(0.6, 3.0),
				"foot": Vector2(0.5, 0.5),
				"h": 150.0,
				"dialog": "look_transistor"
			},
			{
				"id": "hearing_notice",
				"art": "hearing_notice",
				"pos": Vector2(9.4, 2.0),
				"foot": Vector2(0.4, 0.3),
				"h": 290.0,
				"dialog": "look_hearing_notice"
			},
			{
				"id": "plant",
				"art": "plant_pots",
				"pos": Vector2(0.6, 6.5),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "look_hall_plant"
			},
			{
				"id": "float_bike",
				"art": "boat_bike",
				"pos": Vector2(8.6, 6.4),
				"foot": Vector2(1.4, 0.7),
				"h": 90.0,
				"prompt": "เรือเตอร์ไซค์",
				"action": "travel"
			},
		],
		"npcs":
		[
			{
				"id": "lung_mor_nam",
				"name": "ลุงหมอน้ำ",
				"pos": Vector2(3.2, 3.2),
				"character": "lung_mor_nam",
				"dialog": "talk_mor_nam"
			},
		],
	},
	"roof_market":
	{
		"title": "ตลาดน้ำบนดาดฟ้าตึกแถว",
		"grid": Vector2i(12, 9),
		"floor": [Color(0.66, 0.62, 0.56), Color(0.6, 0.56, 0.5)],
		"wall": Color(0.6, 0.42, 0.33),
		"spawns": {"default": Vector2(8.4, 5.8), "from_bike": Vector2(8.4, 5.8)},
		"enter": {"dialog": "enter_market", "flag": "seen_market"},
		"props":
		[
			{
				"id": "dry_goods",
				"art": "dry_goods_stall",
				"pos": Vector2(2.0, 0.6),
				"foot": Vector2(1.2, 0.7),
				"h": 300.0,
				"dialog": "look_dry_goods"
			},
			{
				"id": "fish_grill",
				"art": "fish_grill",
				"pos": Vector2(5.5, 0.7),
				"foot": Vector2(1.0, 0.6),
				"h": 100.0,
				"dialog": "look_fish_grill",
				"prompt": "เตาย่าง"
			},
			{
				"id": "lottery_stand",
				"art": "lottery_stand",
				"pos": Vector2(8.5, 0.5),
				"foot": Vector2(0.6, 0.4),
				"h": 250.0,
				"dialog": "look_lottery_stand"
			},
			{
				"id": "lottery_robot",
				"art": "brass_automaton",
				"pos": Vector2(9.6, 1.0),
				"foot": Vector2(0.6, 0.6),
				"h": 150.0,
				"dialog": "look_lottery_robot",
				"prompt": "หุ่นขายลอตเตอรี่"
			},
			{
				"id": "market_stall",
				"art": "market_stall",
				"pos": Vector2(2.5, 4.0),
				"foot": Vector2(1.2, 1.0),
				"h": 200.0,
				"dialog": "look_market_stall"
			},
			{
				"id": "fruit_crates",
				"art": "fruit_crates",
				"pos": Vector2(5.6, 4.4),
				"foot": Vector2(0.9, 0.7),
				"h": 80.0,
				"dialog": "look_fruit_crates"
			},
			{
				"id": "no_parking",
				"art": "no_parking_sign",
				"pos": Vector2(11.85, 3.0),
				"foot": Vector2(0.3, 0.3),
				"h": 300.0,
				"dialog": "look_no_parking"
			},
			{
				"id": "project_sign",
				"art": "project_sign_16",
				"pos": Vector2(0.6, 7.2),
				"foot": Vector2(0.5, 0.3),
				"h": 320.0,
				"dialog": "look_project_sign_16"
			},
			{
				"id": "float_bike",
				"art": "boat_bike",
				"pos": Vector2(10.0, 7.3),
				"foot": Vector2(1.4, 0.7),
				"h": 90.0,
				"prompt": "เรือเตอร์ไซค์",
				"action": "travel"
			},
		],
		"pickups":
		[
			{"item": "parking_ticket", "pos": Vector2(8.0, 3.6), "label": "ใบสั่ง"},
			{
				"item": "lottery_ticket",
				"pos": Vector2(9.0, 2.8),
				"label": "ลอตเตอรี่",
				"if_flag": "ch2"
			},
		],
		"npcs":
		[
			{
				"id": "lung_platu",
				"name": "ลุงปลาทู",
				"pos": Vector2(5.5, 2.0),
				"character": "lung_pradit",
				"dialog": "talk_platu"
			},
			{
				"id": "je_muay",
				"name": "เจ๊หมวย",
				"pos": Vector2(4.2, 2.6),
				"character": "je_muay",
				"dialog": "talk_muay"
			},
		],
	},
	"temple":
	{
		"title": "วัดหอระฆัง · โบสถ์จมแล้ว เหลือแต่หอ",
		"grid": Vector2i(10, 8),
		"floor": [Color(0.55, 0.42, 0.3), Color(0.5, 0.38, 0.27)],
		"wall": Color(0.85, 0.82, 0.75),
		"spawns": {"default": Vector2(7.0, 5.8), "from_bike": Vector2(7.0, 5.8)},
		"enter": {"dialog": "enter_temple", "flag": "seen_temple"},
		"props":
		[
			{
				"id": "bell_tower",
				"art": "bell_tower",
				"pos": Vector2(3.0, 2.6),
				"foot": Vector2(1.2, 1.2),
				"h": 600.0,
				"dialog": "look_bell_tower",
				"prompt": "หอระฆัง"
			},
			{
				"id": "wetland_sign",
				"art": "wetland_sign",
				"pos": Vector2(6.5, 0.15),
				"foot": Vector2(0.5, 0.3),
				"h": 320.0,
				"dialog": "look_wetland_sign"
			},
			{
				"id": "project_sign",
				"art": "project_sign_17",
				"pos": Vector2(9.0, 0.15),
				"foot": Vector2(0.5, 0.3),
				"h": 320.0,
				"dialog": "look_project_sign_17"
			},
			{
				"id": "incense_pot",
				"art": "incense_pot",
				"pos": Vector2(3.0, 4.8),
				"foot": Vector2(0.4, 0.4),
				"h": 160.0,
				"dialog": "look_incense_pot"
			},
			{
				"id": "alms_boat",
				"art": "alms_boat",
				"pos": Vector2(8.4, 2.6),
				"foot": Vector2(1.8, 0.5),
				"h": 60.0,
				"dialog": "look_alms_boat"
			},
			{
				"id": "float_bike",
				"art": "boat_bike",
				"pos": Vector2(8.6, 6.4),
				"foot": Vector2(1.4, 0.7),
				"h": 90.0,
				"prompt": "เรือเตอร์ไซค์",
				"action": "travel"
			},
		],
		"extra_props":
		[
			{
				"id": "sign_stack",
				"art": "sign_stack",
				"pos": Vector2(8.2, 4.4),
				"foot": Vector2(0.9, 0.6),
				"h": 60.0,
				"dialog": "look_sign_stack",
				"if_flag": "ch2"
			},
		],
		"npcs":
		[
			{
				"id": "luang_pee",
				"name": "หลวงพี่น้ำ",
				"pos": Vector2(5.4, 3.8),
				"character": "luang_pee",
				"dialog": "talk_luang_pee"
			},
			{
				"id": "boy",
				"name": "น้องบอย (ฝ่ายป้าย)",
				"pos": Vector2(6.0, 5.0),
				"character": "boy",
				"dialog": "talk_boy",
				"if_flag": "ch2"
			},
		],
	},
	"boat_rank":
	{
		"title": "วินเรือซอยส่งไว · เดิมคือวินมอเตอร์ไซค์",
		"grid": Vector2i(10, 7),
		"floor": [Color(0.46, 0.36, 0.26), Color(0.42, 0.33, 0.24)],
		"wall": Color(0.58, 0.6, 0.62),
		"spawns": {"default": Vector2(7.0, 5.0), "from_bike": Vector2(7.0, 5.0)},
		"enter": {"dialog": "enter_rank", "flag": "seen_rank"},
		"props":
		[
			{
				"id": "rank_sign",
				"art": "rank_sign",
				"pos": Vector2(2.0, 0.15),
				"foot": Vector2(0.5, 0.3),
				"h": 330.0,
				"dialog": "look_rank_sign"
			},
			{
				"id": "vest_rack",
				"art": "vest_rack",
				"pos": Vector2(4.6, 0.5),
				"foot": Vector2(0.9, 0.3),
				"h": 260.0,
				"dialog": "look_vest_rack"
			},
			{
				"id": "longtail",
				"art": "longtail_boat",
				"pos": Vector2(7.9, 0.7),
				"foot": Vector2(2.6, 0.8),
				"h": 80.0,
				"dialog": "look_rank_boat"
			},
			{
				"id": "fuel",
				"art": "fuel_pump",
				"pos": Vector2(0.6, 2.8),
				"foot": Vector2(0.5, 0.5),
				"h": 170.0,
				"dialog": "look_rank_fuel"
			},
			{
				"id": "stool",
				"art": "red_stool",
				"pos": Vector2(3.0, 3.2),
				"foot": Vector2(0.4, 0.4),
				"h": 30.0,
				"dialog": "look_rank_stool"
			},
			{
				"id": "trash",
				"art": "trash_bin",
				"pos": Vector2(0.8, 6.3),
				"foot": Vector2(0.8, 0.8),
				"h": 60.0,
				"dialog": "look_rank_trash"
			},
			{
				"id": "float_bike",
				"art": "boat_bike",
				"pos": Vector2(8.6, 5.4),
				"foot": Vector2(1.4, 0.7),
				"h": 90.0,
				"prompt": "เรือเตอร์ไซค์",
				"action": "travel"
			},
		],
		"pickups": [{"item": "rope", "pos": Vector2(5.2, 3.4), "label": "เชือกผูกเรือ"}],
		"npcs":
		[
			{
				"id": "ple",
				"name": "พี่เปิ้ล (วินเรือ เบอร์ 1)",
				"pos": Vector2(4.2, 2.4),
				"character": "ple",
				"dialog": "talk_ple"
			},
		],
	},
	"cat_roof":
	{
		"title": "หลังคาสังกะสีหลังตลาด · ที่ของแมวส้มโอ",
		"grid": Vector2i(8, 6),
		"floor": [Color(0.62, 0.64, 0.62), Color(0.56, 0.58, 0.56)],
		"wall": Color(0.5, 0.52, 0.52),
		"spawns": {"default": Vector2(4.4, 4.8), "from_bike": Vector2(4.4, 4.8)},
		"enter": {"dialog": "enter_cat_roof", "flag": "seen_cat_roof"},
		"props":
		[
			{
				"id": "roof_vent",
				"art": "roof_vent",
				"pos": Vector2(0.6, 0.6),
				"foot": Vector2(0.5, 0.5),
				"h": 130.0,
				"dialog": "look_roof_vent"
			},
			{
				"id": "cat",
				"art": "cat_som_o",
				"pos": Vector2(1.8, 1.4),
				"foot": Vector2(0.6, 0.5),
				"h": 140.0,
				"dialog": "look_cat",
				"prompt": "แมวส้มโอ"
			},
			{
				"id": "hoard",
				"art": "hoard",
				"pos": Vector2(2.4, 2.6),
				"foot": Vector2(1.0, 0.8),
				"h": 60.0,
				"dialog": "look_hoard",
				"prompt": "กองสมบัติ"
			},
			{
				"id": "tv_antenna",
				"art": "tv_antenna",
				"pos": Vector2(5.6, 0.15),
				"foot": Vector2(0.3, 0.3),
				"h": 320.0,
				"dialog": "look_tv_antenna"
			},
			{
				"id": "water_tank",
				"art": "water_tank",
				"pos": Vector2(7.2, 2.8),
				"foot": Vector2(1.0, 1.0),
				"h": 190.0,
				"dialog": "look_roof_tank"
			},
			{
				"id": "float_bike",
				"art": "boat_bike",
				"pos": Vector2(6.6, 5.0),
				"foot": Vector2(1.4, 0.7),
				"h": 90.0,
				"prompt": "เรือเตอร์ไซค์",
				"action": "travel"
			},
		],
		# the hoard opens once the cat is busy with the fish
		"pickups":
		[
			{
				"item": "curler",
				"pos": Vector2(3.6, 3.6),
				"label": "ที่ม้วนผม",
				"if_flag": "cat_lured"
			},
			{
				"item": "goldfish",
				"pos": Vector2(1.2, 3.8),
				"label": "ถุงปลาทอง",
				"if_flag": "cat_lured"
			},
			{
				"item": "amulet",
				"pos": Vector2(2.6, 4.6),
				"label": "พระเครื่อง",
				"if_flag": "cat_lured"
			},
		],
	},
	"guard_post":
	{
		"title": "ป้อมยามกำแพงกันทะเล · บจ.ป้องกันภัย",
		"grid": Vector2i(10, 7),
		"floor": [Color(0.7, 0.72, 0.7), Color(0.64, 0.66, 0.64)],
		"wall": Color(0.37, 0.48, 0.63),
		"spawns": {"default": Vector2(6.6, 5.0), "from_bike": Vector2(6.6, 5.0)},
		"enter": {"dialog": "enter_guard_post", "flag": "seen_guard_post"},
		"props":
		[
			{
				"id": "guard_booth",
				"art": "guard_booth",
				"pos": Vector2(3.0, 0.8),
				"foot": Vector2(1.2, 1.0),
				"h": 380.0,
				"dialog": "look_guard_booth",
				"prompt": "ตู้ยาม"
			},
			{
				"id": "barrier",
				"art": "barrier_arm",
				"pos": Vector2(6.8, 0.9),
				"foot": Vector2(1.6, 0.3),
				"h": 120.0,
				"dialog": "look_barrier"
			},
			{
				"id": "company_bot_a",
				"art": "brass_automaton",
				"pos": Vector2(1.6, 1.0),
				"foot": Vector2(0.6, 0.6),
				"h": 150.0,
				"dialog": "look_company_bots",
				"prompt": "หุ่นบริษัท"
			},
			{
				"id": "company_bot_b",
				"art": "brass_automaton",
				"pos": Vector2(8.2, 0.6),
				"foot": Vector2(0.6, 0.6),
				"h": 150.0,
				"dialog": "look_company_bots",
				"prompt": "หุ่นบริษัท"
			},
			{
				"id": "survey_kiosk",
				"art": "survey_kiosk",
				"pos": Vector2(9.3, 2.4),
				"foot": Vector2(0.4, 0.4),
				"h": 290.0,
				"dialog": "look_survey_kiosk",
				"prompt": "ตู้แบบสอบถาม"
			},
			{
				"id": "atm",
				"art": "company_atm",
				"pos": Vector2(0.6, 3.2),
				"foot": Vector2(0.6, 0.5),
				"h": 260.0,
				"dialog": "look_atm"
			},
			{
				"id": "brochure_stand",
				"art": "brochure_stand",
				"pos": Vector2(5.0, 3.6),
				"foot": Vector2(0.5, 0.3),
				"h": 230.0,
				"dialog": "look_brochure_stand"
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
				"id": "beam",
				"name": "คุณบีม (ลูกค้าสัมพันธ์)",
				"pos": Vector2(5.2, 2.8),
				"character": "beam",
				"dialog": "talk_beam"
			},
			{
				"id": "ton",
				"name": "น้องต้น (ยาม)",
				"pos": Vector2(2.6, 2.2),
				"character": "ton",
				"dialog": "talk_ton"
			},
		],
	},
	"condo":
	{
		"title": "คอนโดริมกำแพง · เข้าทางชั้น 3",
		"grid": Vector2i(10, 8),
		"floor": [Color(0.84, 0.8, 0.74), Color(0.78, 0.74, 0.68)],
		"wall": Color(0.9, 0.86, 0.8),
		"spawns": {"default": Vector2(6.0, 5.6), "from_bike": Vector2(6.0, 5.6)},
		"enter": {"dialog": "enter_condo", "flag": "seen_condo"},
		"props":
		[
			{
				"id": "lift",
				"art": "lift_door",
				"pos": Vector2(2.0, 0.5),
				"foot": Vector2(1.0, 0.4),
				"h": 240.0,
				"dialog": "look_condo_lift"
			},
			{
				"id": "condo_window",
				"art": "condo_window",
				"pos": Vector2(6.0, 0.15),
				"foot": Vector2(1.2, 0.3),
				"h": 330.0,
				"dialog": "look_condo_window"
			},
			{
				"id": "shelter_sign",
				"art": "shelter_sign",
				"pos": Vector2(9.0, 0.15),
				"foot": Vector2(0.5, 0.3),
				"h": 300.0,
				"dialog": "look_shelter_sign"
			},
			{
				"id": "condo_sofa",
				"art": "sofa",
				"pos": Vector2(2.8, 3.4),
				"foot": Vector2(1.6, 0.8),
				"h": 60.0,
				"dialog": "look_condo_sofa"
			},
			{
				"id": "parcels",
				"art": "parcel_pile",
				"pos": Vector2(8.0, 3.0),
				"foot": Vector2(1.0, 0.8),
				"h": 120.0,
				"dialog": "look_parcel_pile",
				"prompt": "กองพัสดุ"
			},
			{
				"id": "poodle",
				"art": "poodle_float",
				"pos": Vector2(5.0, 6.4),
				"foot": Vector2(0.8, 0.6),
				"h": 80.0,
				"dialog": "look_poodle",
				"prompt": "พุดเดิ้ล"
			},
			{
				"id": "float_bike",
				"art": "boat_bike",
				"pos": Vector2(8.0, 6.4),
				"foot": Vector2(1.4, 0.7),
				"h": 90.0,
				"prompt": "เรือเตอร์ไซค์",
				"action": "travel"
			},
		],
		"npcs":
		[
			{
				"id": "la_or",
				"name": "คุณหญิงลออ",
				"pos": Vector2(5.4, 3.0),
				"character": "la_or",
				"dialog": "talk_la_or"
			},
		],
	},
}

## Where the floating bike can go: room id -> {name, flag needed, map}.
## `map` = where the place sits on the hand-drawn map (fraction of the sheet);
## `tide` + `closed` = only reachable at that tide (the pin says why otherwise);
## the same numbers as PLACES in tools/art/png/map_2090.py (test_map_view).
const TRAVEL := {
	"pier": {"name": "ท่าเรือหน้าซอย", "flag": "", "map": Vector2(0.26, 0.835)},
	"noodle_boat": {"name": "เรือก๋วยเตี๋ยวป้านก", "flag": "", "map": Vector2(0.45, 0.62)},
	"stilts": {"name": "ชุมชนยกเสา (ป้าจุ๋ม)", "flag": "know_stilts", "map": Vector2(0.22, 0.46)},
	"boat_garage": {"name": "อู่เรือช่างแดง", "flag": "know_garage", "map": Vector2(0.55, 0.42)},
	"old_gate":
	{"name": "ประตูระบายน้ำเก่าใต้สะพาน", "flag": "know_gate", "map": Vector2(0.68, 0.27)},
	"kiao_raft": {"name": "เรือนแพเจ๊เกียว", "flag": "know_kiao", "map": Vector2(0.86, 0.80)},
	"boat_rank": {"name": "วินเรือ", "flag": "", "map": Vector2(0.37, 0.90)},
	"hall": {"name": "ศาลาพยากรณ์น้ำ", "flag": "know_hall", "map": Vector2(0.42, 0.21)},
	"roof_market": {"name": "ตลาดดาดฟ้า", "flag": "know_market", "map": Vector2(0.60, 0.76)},
	"temple": {"name": "วัดหอระฆัง", "flag": "know_temple", "map": Vector2(0.78, 0.56)},
	"guard_post":
	{"name": "ป้อมยามกำแพงกันทะเล", "flag": "know_guard_post", "map": Vector2(0.52, 0.12)},
	"condo": {"name": "คอนโดชั้น 3", "flag": "know_condo", "map": Vector2(0.89, 0.37)},
	# the boat only reaches the roof when the water is up
	"cat_roof":
	{
		"name": "หลังคาแมวส้มโอ",
		"flag": "know_cat_roof",
		"map": Vector2(0.31, 0.32),
		"tide": "high",
		"closed": "น้ำลง เรือลอยไม่ถึงหลังคา"
	},
}


static func get_room(id: String) -> Dictionary:
	return ROOMS.get(id, ROOMS[GameState.START_ROOM])


static func title(id: String) -> String:
	return str(get_room(id).get("title", id))


## Every flag a room's entries depend on: setting one while the rider is in
## the room rebuilds it (ช่างแดง comes out from under the boat right away).
static func condition_flags(room: Dictionary) -> Dictionary:
	var out := {}
	for key in ["props", "extra_props", "pickups", "npcs", "exits", "bots"]:
		for e in room.get(key, []):
			for k in ["if_flag", "if_not_flag"]:
				if e.has(k):
					out[str(e[k])] = true
			for f in e.get("if_flags", []) + e.get("if_not_flags", []):
				out[str(f)] = true
	return out


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
	for f in entry.get("if_not_flags", []):
		if flags.get(f, false):
			return false
	return true


## present() + the tide condition.
static func present_now(entry: Dictionary, flags: Dictionary, tide: String) -> bool:
	var need_tide := str(entry.get("if_tide", ""))
	if not need_tide.is_empty() and need_tide != tide:
		return false
	return present(entry, flags)
