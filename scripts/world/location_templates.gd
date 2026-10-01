class_name LocationTemplates
extends RefCounted
## Scene recipes per place type (DESIGN 10.3). LocationRoom builds a room from
## one of these + a per-place random pick of the optional props, so every
## restaurant shares a layout language but no two look the same.
##
## Grid positions are cells (Iso.grid_to_world). "props": always placed;
## "extras": `extra_count` of them chosen per place. A prop entry:
## {art?, pos, foot, h, color?, dialog?, prompt?}. Props without art draw the
## coloured placeholder block. "merchant": NPC that hands over pickups
## (npc_id "merchant"; "behind_counter" = no collision of its own);
## "customers": spots where drop-off customers wait. The rider's bike is
## parked front-right (LocationRoom.bike_cell).

const T := {
	"restaurant":
	{
		"grid": Vector2i(10, 8),
		"floor": [Color(0.62, 0.52, 0.42), Color(0.58, 0.48, 0.39)],
		"wall": Color(0.75, 0.42, 0.3),
		"props":
		[
			{
				"art": "food_counter",
				"pos": Vector2(4.5, 1.6),
				"foot": Vector2(2.6, 0.7),
				"h": 90.0,
				"color": Color(0.9, 0.88, 0.82)
			},
			{"art": "noodle_cart", "pos": Vector2(8.6, 1.2), "foot": Vector2(1.6, 0.9), "h": 90.0},
		],
		"extras":
		[
			{
				"art": "steel_table",
				"pos": Vector2(2.2, 4.4),
				"foot": Vector2(1.0, 1.0),
				"h": 55.0,
				"color": Color(0.55, 0.35, 0.25),
				"dialog": "talk_table"
			},
			{
				"art": "steel_table",
				"pos": Vector2(5.0, 4.6),
				"foot": Vector2(1.0, 1.0),
				"h": 55.0,
				"color": Color(0.55, 0.35, 0.25),
				"dialog": "talk_table"
			},
			{"art": "red_stool", "pos": Vector2(3.0, 5.9), "foot": Vector2(0.4, 0.4), "h": 30.0},
			{"art": "red_stool", "pos": Vector2(0.8, 5.4), "foot": Vector2(0.4, 0.4), "h": 30.0},
			{
				"art": "shop_cat",
				"pos": Vector2(0.7, 1.6),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "talk_cat"
			},
			{"art": "trash_bin", "pos": Vector2(0.9, 3.0), "foot": Vector2(0.8, 0.8), "h": 60.0},
		],
		"extra_count": 4,
		"merchant":
		{
			"pos": Vector2(4.5, 0.7),
			"behind_counter": true,
			"character": "je_muay",
			"tint": Color(1, 1, 1),
			"dialog": "talk_restaurant"
		},
		"customers": [Vector2(6.5, 5.0), Vector2(3.0, 6.8)],
	},
	"market":
	{
		"grid": Vector2i(12, 10),
		"floor": [Color(0.45, 0.43, 0.4), Color(0.41, 0.39, 0.37)],
		"wall": Color(0.36, 0.42, 0.5),
		"props":
		[
			{"art": "market_stall", "pos": Vector2(5.0, 1.8), "foot": Vector2(1.5, 1.0), "h": 70.0},
		],
		"extras":
		[
			{
				"art": "moo_ping_cart",
				"pos": Vector2(9.0, 2.0),
				"foot": Vector2(1.0, 0.6),
				"h": 90.0,
				"dialog": "talk_moo_ping"
			},
			{"art": "noodle_cart", "pos": Vector2(2.2, 4.0), "foot": Vector2(1.6, 0.9), "h": 90.0},
			{"art": "fruit_crates", "pos": Vector2(8.0, 5.5), "foot": Vector2(0.9, 0.9), "h": 60.0},
			{
				"art": "shop_cat",
				"pos": Vector2(1.5, 7.5),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "talk_cat"
			},
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
		"extra_count": 4,
		"merchant":
		{
			"pos": Vector2(5.0, 0.9),
			"behind_counter": true,
			"character": "je_muay",
			"tint": Color(0.95, 1, 0.9),
			"dialog": "talk_market"
		},
		"customers": [Vector2(7.0, 8.0), Vector2(3.5, 8.8)],
	},
	"house":
	{
		"grid": Vector2i(12, 10),
		"floor": [Color(0.42, 0.5, 0.36), Color(0.39, 0.47, 0.34)],
		"wall": Color(0.82, 0.78, 0.68),
		"props":
		[
			{
				"art": "spirit_house",
				"pos": Vector2(2.0, 1.6),
				"foot": Vector2(0.7, 0.7),
				"h": 160.0,
				"dialog": "talk_spirit_house"
			},
			{
				"art": "power_pole",
				"pos": Vector2(10.4, 2.0),
				"foot": Vector2(0.35, 0.35),
				"h": 300.0
			},
		],
		"extras":
		[
			{
				"art": "plant_pots",
				"pos": Vector2(5.0, 0.9),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "talk_planter"
			},
			{"art": "water_tank", "pos": Vector2(8.0, 1.0), "foot": Vector2(1.0, 1.0), "h": 190.0},
			{
				"art": "steam_tuk_tuk",
				"pos": Vector2(4.5, 5.5),
				"foot": Vector2(1.0, 1.8),
				"h": 120.0
			},
			{
				"art": "shop_cat",
				"pos": Vector2(1.5, 6.0),
				"foot": Vector2(0.6, 0.6),
				"h": 60.0,
				"dialog": "talk_cat"
			},
			{
				"art": "house_gate",
				"pos": Vector2(8.0, 6.5),
				"foot": Vector2(1.2, 0.6),
				"h": 50.0,
				"color": Color(0.5, 0.36, 0.25),
				"dialog": "talk_house_gate"
			},
		],
		"extra_count": 3,
		"customers": [Vector2(6.5, 3.0), Vector2(2.8, 4.0), Vector2(9.5, 4.5)],
	},
	"condo":
	{
		"grid": Vector2i(10, 10),
		"floor": [Color(0.78, 0.78, 0.76), Color(0.72, 0.72, 0.71)],
		"wall": Color(0.55, 0.6, 0.66),
		"props":
		[
			{
				"art": "guard_desk",
				"pos": Vector2(2.2, 2.2),
				"foot": Vector2(1.6, 0.7),
				"h": 80.0,
				"color": Color(0.3, 0.3, 0.34),
				"dialog": "talk_guard_desk"
			},
			{
				"art": "lift_door",
				"pos": Vector2(6.0, 0.3),
				"foot": Vector2(1.4, 0.6),
				"h": 170.0,
				"color": Color(0.7, 0.72, 0.75),
				"dialog": "talk_lift"
			},
		],
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
			{"art": "plant_pots", "pos": Vector2(1.0, 5.5), "foot": Vector2(0.6, 0.6), "h": 60.0},
			{
				"art": "parcel_shelf",
				"pos": Vector2(9.1, 6.0),
				"foot": Vector2(0.8, 0.8),
				"h": 60.0,
				"dialog": "talk_parcel_pile"
			},
		],
		"extra_count": 2,
		"merchant":
		{
			# the guard keeps parcels for residents (pickups) and blocks the lift
			"pos": Vector2(2.2, 1.0),
			"behind_counter": true,
			"character": "lung_pradit",
			"tint": Color(0.75, 0.8, 1),
			"dialog": "talk_condo_guard"
		},
		"customers": [Vector2(5.0, 3.5), Vector2(3.5, 5.5)],
	},
	"office":
	{
		"grid": Vector2i(10, 10),
		"floor": [Color(0.5, 0.52, 0.56), Color(0.47, 0.49, 0.53)],
		"wall": Color(0.85, 0.85, 0.82),
		"props":
		[
			{
				"art": "reception_desk",
				"pos": Vector2(5.0, 1.8),
				"foot": Vector2(2.4, 0.7),
				"h": 85.0,
				"color": Color(0.6, 0.45, 0.3)
			},
		],
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
				"dialog": "talk_sofa"
			},
			{"art": "payphone", "pos": Vector2(9.2, 5.4), "foot": Vector2(0.55, 0.55), "h": 170.0},
		],
		"extra_count": 3,
		"merchant":
		{
			"pos": Vector2(5.0, 0.9),
			"behind_counter": true,
			"character": "je_muay",
			"tint": Color(0.85, 0.9, 1),
			"dialog": "talk_office"
		},
		"customers": [Vector2(5.5, 4.5), Vector2(3.8, 7.0)],
	},
	"gas":
	{
		"grid": Vector2i(10, 8),
		"floor": [Color(0.4, 0.4, 0.42), Color(0.37, 0.37, 0.39)],
		"wall": Color(0.85, 0.3, 0.25),
		"props":
		[
			{
				"art": "fuel_pump",
				"pos": Vector2(4.0, 3.5),
				"foot": Vector2(0.6, 0.6),
				"h": 120.0,
				"color": Color(0.85, 0.25, 0.2),
				"dialog": "talk_pump"
			},
			{
				"art": "fuel_pump_green",
				"pos": Vector2(6.5, 3.5),
				"foot": Vector2(0.6, 0.6),
				"h": 120.0,
				"color": Color(0.2, 0.6, 0.3),
				"dialog": "talk_pump"
			},
		],
		"extras":
		[
			{"art": "payphone", "pos": Vector2(0.8, 0.8), "foot": Vector2(0.55, 0.55), "h": 170.0},
			{
				"art": "win_stand",
				"pos": Vector2(7.6, 0.8),
				"foot": Vector2(1.6, 0.6),
				"h": 150.0,
				"dialog": "talk_rider_rest"
			},
			{"art": "trash_bin", "pos": Vector2(0.9, 5.8), "foot": Vector2(0.8, 0.8), "h": 60.0},
		],
		"extra_count": 2,
		"merchant":
		{
			"pos": Vector2(5.2, 5.4),
			"character": "lung_pradit",
			"tint": Color(1, 0.9, 0.8),
			"dialog": "talk_gas",
			"action": "refuel",
			"prompt": "เติมน้ำมัน"
		},
		"customers": [Vector2(2.5, 3.5)],
	},
	"garage":
	{
		"grid": Vector2i(10, 10),
		"floor": [Color(0.3, 0.3, 0.32), Color(0.27, 0.27, 0.29)],
		"wall": Color(0.45, 0.47, 0.5),
		"props":
		[
			{"art": "tool_bench", "pos": Vector2(7.0, 2.0), "foot": Vector2(1.5, 1.0), "h": 70.0},
			{
				"art": "parked_scooter",
				"pos": Vector2(3.5, 2.0),
				"foot": Vector2(1.4, 0.7),
				"h": 70.0,
				"dialog": "talk_repair_bike"
			},
		],
		"extras":
		[
			{"art": "tire_stack", "pos": Vector2(0.8, 4.5), "foot": Vector2(0.6, 0.6), "h": 60.0},
			{"art": "crate", "pos": Vector2(1.0, 7.0), "foot": Vector2(0.9, 0.9), "h": 60.0},
			{"art": "water_tank", "pos": Vector2(8.8, 4.5), "foot": Vector2(1.0, 1.0), "h": 190.0},
		],
		"extra_count": 2,
		"merchant":
		{
			"pos": Vector2(5.4, 4.0),
			"character": "lung_pradit",
			"tint": Color(0.78, 0.86, 1),
			"dialog": "talk_garage"
		},
		"customers": [Vector2(4.0, 6.5)],
	},
}


static func get_template(type: String) -> Dictionary:
	return T.get(type, T["house"])
