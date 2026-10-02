class_name PlaceRooms
extends RefCounted
## Hand-made rooms of ย่านส่งไว (District), keyed by place key. Each recipe
## overrides its type's LocationTemplates recipe: any key given replaces the
## type's (props / extras / customers), "merchant" is merged into the type's
## merchant, every extra is placed (no random pick), and "npcs" adds named
## residents: {name, pos, character, tint?, dialog, action?, prompt?}.
## Talk lives in assets/dialog/dialog.json; items in GameState.ITEMS.
## Gap rule as for templates (test_templates_avoid_sliver_gaps checks these).

const LUNG := "lung_pradit"
const JE := "je_muay"

const ROOMS := {
	"jae_daeng":
	{
		"merchant": {"name": "เจ๊แดง", "dialog": "talk_jae_daeng"},
		"props":
		[
			{
				"art": "food_counter",
				"pos": Vector2(4.5, 1.6),
				"foot": Vector2(2.6, 0.7),
				"h": 90.0,
				"dialog": "talk_jd_counter"
			},
			{
				"art": "noodle_cart",
				"pos": Vector2(8.6, 1.2),
				"foot": Vector2(1.6, 0.9),
				"h": 90.0,
				"dialog": "talk_jd_cart"
			},
		],
		"extras":
		[
			{
				"art": "steel_table",
				"pos": Vector2(2.2, 4.4),
				"foot": Vector2(1.0, 1.0),
				"h": 55.0,
				"dialog": "talk_jd_table"
			},
			{
				"art": "steel_table",
				"pos": Vector2(5.0, 4.6),
				"foot": Vector2(1.0, 1.0),
				"h": 55.0,
				"dialog": "talk_jd_table3"
			},
			{"art": "red_stool", "pos": Vector2(3.0, 5.9), "foot": Vector2(0.4, 0.4), "h": 30.0},
			{"art": "red_stool", "pos": Vector2(0.8, 5.4), "foot": Vector2(0.4, 0.4), "h": 30.0},
			{
				"art": "shop_cat",
				"pos": Vector2(0.7, 1.6),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "talk_somo",
				"prompt": "ส้มโอ"
			},
			{
				"art": "trash_bin",
				"pos": Vector2(0.9, 3.0),
				"foot": Vector2(0.8, 0.8),
				"h": 60.0,
				"dialog": "talk_jd_trash"
			},
		],
		"npcs":
		[
			{
				"name": "ลุงโต๊ะสาม",
				"pos": Vector2(7.6, 3.4),
				"character": LUNG,
				"tint": Color(1, 0.92, 0.8),
				"dialog": "talk_lung_table3"
			},
		],
	},
	"pa_nok":
	{
		"merchant": {"name": "ป้านก", "dialog": "talk_pa_nok"},
		"props":
		[
			{
				"art": "food_counter",
				"pos": Vector2(4.5, 1.6),
				"foot": Vector2(2.6, 0.7),
				"h": 90.0,
				"color": Color(0.6, 0.35, 0.25)
			},
			{
				"art": "noodle_cart",
				"pos": Vector2(8.6, 1.2),
				"foot": Vector2(1.6, 0.9),
				"h": 90.0,
				"dialog": "talk_nok_pot"
			},
		],
		"extras":
		[
			{
				"art": "steel_table",
				"pos": Vector2(2.2, 4.4),
				"foot": Vector2(1.0, 1.0),
				"h": 55.0,
				"dialog": "talk_nok_table"
			},
			{"art": "steel_table", "pos": Vector2(5.0, 4.6), "foot": Vector2(1.0, 1.0), "h": 55.0},
			{"art": "red_stool", "pos": Vector2(3.0, 5.9), "foot": Vector2(0.4, 0.4), "h": 30.0},
			{"art": "red_stool", "pos": Vector2(0.8, 5.4), "foot": Vector2(0.4, 0.4), "h": 30.0},
			{"art": "trash_bin", "pos": Vector2(0.9, 3.0), "foot": Vector2(0.8, 0.8), "h": 60.0},
		],
		"npcs":
		[
			{
				"name": "น้องเก่ง (ลูกป้านก)",
				"pos": Vector2(0.9, 1.7),
				"character": JE,
				"tint": Color(0.85, 0.95, 1),
				"dialog": "talk_keng"
			},
		],
	},
	"samakkhi":
	{
		"merchant": {"name": "แม่ค้าผลไม้", "dialog": "talk_market"},
		"extras":
		[
			{
				"art": "moo_ping_cart",
				"pos": Vector2(9.0, 2.0),
				"foot": Vector2(1.0, 0.6),
				"h": 90.0,
				"dialog": "talk_moo_ping",
				"prompt": "หมูปิ้ง"
			},
			{"art": "noodle_cart", "pos": Vector2(2.2, 4.0), "foot": Vector2(1.6, 0.9), "h": 90.0},
			{"art": "fruit_crates", "pos": Vector2(8.0, 5.5), "foot": Vector2(0.9, 0.9), "h": 60.0},
			{
				"art": "market_stall",
				"pos": Vector2(5.5, 6.0),
				"foot": Vector2(1.6, 0.9),
				"h": 70.0,
				"color": Color(0.3, 0.55, 0.4),
				"dialog": "talk_stall"
			},
			{
				"art": "sign",
				"pos": Vector2(10.5, 6.0),
				"foot": Vector2(0.5, 0.3),
				"h": 110.0,
				"dialog": "talk_market_sign"
			},
		],
		"npcs":
		[
			{
				"name": "ป้าเล็ก (ลอตเตอรี่)",
				"pos": Vector2(1.6, 6.8),
				"character": JE,
				"tint": Color(1, 0.85, 0.85),
				"dialog": "talk_lek"
			},
		],
	},
	"rom_yen":
	{
		"extras":
		[
			{
				"art": "plant_pots",
				"pos": Vector2(5.0, 0.9),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "talk_planter"
			},
			{
				"art": "water_tank",
				"pos": Vector2(8.0, 1.0),
				"foot": Vector2(1.0, 1.0),
				"h": 190.0,
				"dialog": "talk_ry_tank"
			},
			{
				"art": "house_gate",
				"pos": Vector2(8.0, 6.5),
				"foot": Vector2(1.2, 0.6),
				"h": 50.0,
				"color": Color(0.5, 0.36, 0.25),
				"dialog": "talk_ry_gate"
			},
		],
		"npcs":
		[
			{
				"name": "ป้าจุ๋ม",
				"pos": Vector2(1.6, 6.0),
				"character": JE,
				"tint": Color(1, 0.8, 0.95),
				"dialog": "talk_jum"
			},
		],
	},
	"suk_san":
	{
		"extras":
		[
			{
				"art": "plant_pots",
				"pos": Vector2(5.0, 0.9),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "talk_ss_pots"
			},
			{
				"art": "soi_dog",
				"pos": Vector2(4.5, 5.5),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "talk_khaotang",
				"prompt": "ข้าวตัง"
			},
			{
				"art": "house_gate",
				"pos": Vector2(8.0, 6.5),
				"foot": Vector2(1.2, 0.6),
				"h": 50.0,
				"color": Color(0.45, 0.4, 0.3),
				"dialog": "talk_house_gate"
			},
		],
		"npcs":
		[
			{
				"name": "น้องต้นกล้า",
				"pos": Vector2(1.6, 6.0),
				"character": JE,
				"tint": Color(0.9, 1, 0.85),
				"dialog": "talk_tonkla"
			},
		],
	},
	"river_view":
	{
		"merchant": {"name": "ลุงสมพงษ์ รปภ.", "dialog": "talk_sompong"},
		"extras":
		[
			{
				"art": "sofa",
				"pos": Vector2(7.6, 3.6),
				"foot": Vector2(1.6, 0.8),
				"h": 45.0,
				"color": Color(0.35, 0.4, 0.55),
				"dialog": "talk_sofa"
			},
			{
				"art": "plant_pots",
				"pos": Vector2(1.0, 5.5),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "talk_rv_plant"
			},
			{
				"art": "parcel_shelf",
				"pos": Vector2(9.1, 6.0),
				"foot": Vector2(0.8, 0.8),
				"h": 60.0,
				"dialog": "talk_parcel_pile"
			},
		],
		"npcs":
		[
			{
				"name": "คุณนิติ",
				"pos": Vector2(1.9, 8.0),
				"character": JE,
				"tint": Color(0.85, 0.85, 1),
				"dialog": "talk_niti"
			},
		],
	},
	"synergy":
	{
		"merchant": {"name": "คุณแพร (รีเซปชัน)", "dialog": "talk_office"},
		"extras":
		[
			{
				"art": "water_dispenser",
				"pos": Vector2(9.0, 0.9),
				"foot": Vector2(1.0, 1.0),
				"h": 190.0,
				"dialog": "talk_water"
			},
			{"art": "plant_pots", "pos": Vector2(0.8, 0.8), "foot": Vector2(0.6, 0.6), "h": 60.0},
			{
				"art": "sofa",
				"pos": Vector2(2.0, 5.0),
				"foot": Vector2(1.6, 0.8),
				"h": 45.0,
				"color": Color(0.25, 0.3, 0.4),
				"dialog": "talk_syn_sofa"
			},
		],
		"npcs":
		[
			{
				"name": "คุณบอส (ติดประชุม)",
				"pos": Vector2(7.6, 3.6),
				"character": LUNG,
				"tint": Color(0.85, 0.9, 1),
				"dialog": "talk_boss"
			},
		],
	},
	"khet":
	{
		"merchant": {"name": "เจ้าหน้าที่เขต", "dialog": "talk_khet"},
		"extras":
		[
			{
				"art": "water_dispenser",
				"pos": Vector2(9.0, 0.9),
				"foot": Vector2(1.0, 1.0),
				"h": 190.0,
				"dialog": "talk_khet_water"
			},
			{"art": "plant_pots", "pos": Vector2(0.8, 0.8), "foot": Vector2(0.6, 0.6), "h": 60.0},
			{
				"art": "sofa",
				"pos": Vector2(2.0, 5.0),
				"foot": Vector2(1.6, 0.8),
				"h": 45.0,
				"color": Color(0.4, 0.35, 0.3),
				"dialog": "talk_khet_queue"
			},
			{
				"art": "payphone",
				"pos": Vector2(9.2, 5.4),
				"foot": Vector2(0.55, 0.55),
				"h": 170.0,
				"dialog": "talk_khet_phone"
			},
		],
	},
	"pailin":
	{
		"extras":
		[
			{
				"art": "payphone",
				"pos": Vector2(0.8, 0.8),
				"foot": Vector2(0.55, 0.55),
				"h": 170.0,
				"dialog": "talk_pl_phone"
			},
			{
				"art": "win_stand",
				"pos": Vector2(7.6, 0.8),
				"foot": Vector2(1.6, 0.6),
				"h": 150.0,
				"dialog": "talk_rider_rest"
			},
			{
				"art": "water_dispenser",
				"pos": Vector2(1.2, 3.0),
				"foot": Vector2(1.0, 1.0),
				"h": 190.0,
				"dialog": "talk_coffee_machine",
				"prompt": "ตู้กาแฟ"
			},
			{"art": "trash_bin", "pos": Vector2(0.9, 5.8), "foot": Vector2(0.8, 0.8), "h": 60.0},
		],
		"npcs":
		[
			{
				"name": "พี่ต้อย (วินฯ)",
				"pos": Vector2(6.2, 2.0),
				"character": LUNG,
				"tint": Color(1, 0.75, 0.5),
				"dialog": "talk_toi",
				"action": "rumor"
			},
		],
	},
	"hia_peng":
	{
		"merchant": {"name": "เฮียเป้ง"},
		"props":
		[
			{
				"art": "tool_bench",
				"pos": Vector2(7.0, 2.0),
				"foot": Vector2(1.5, 1.0),
				"h": 70.0,
				"dialog": "talk_hp_bench"
			},
			{
				"art": "parked_scooter",
				"pos": Vector2(3.5, 2.0),
				"foot": Vector2(1.4, 0.7),
				"h": 70.0,
				"dialog": "talk_chang_daeng",
				"prompt": "ขาใต้รถ"
			},
		],
		"extras":
		[
			{
				"art": "tire_stack",
				"pos": Vector2(0.8, 4.5),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "talk_hp_tires"
			},
			{"art": "crate", "pos": Vector2(1.0, 7.0), "foot": Vector2(0.9, 0.9), "h": 60.0},
			{
				"art": "water_tank",
				"pos": Vector2(8.8, 4.5),
				"foot": Vector2(1.0, 1.0),
				"h": 190.0,
				"dialog": "talk_hp_fridge",
				"prompt": "ตู้เย็นเฮีย"
			},
		],
	},
}
