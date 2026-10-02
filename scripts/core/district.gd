class_name District
extends RefCounted
## "ย่านส่งไว" — the hand-made neighbourhood (DESIGN 10.10, owner 2026-10-02:
## the fun of the first version was exploring rooms + funny talk and items,
## which a random city cannot give). Same shape as CityGen.generate() so the
## map, routes, weather and orders keep working; every place also has a `key`
## that LocationTemplates.PLACES uses for its hand-made room (residents,
## props, little quests). The seed still drives weather and orders.

const PLACES := [
	{
		"key": "jae_daeng",
		"type": "restaurant",
		"name": "ข้าวมันไก่เจ๊แดง",
		"area": "ปากซอยส่งไว",
		"pos": Vector2(180, 170)
	},
	{
		"key": "samakkhi",
		"type": "market",
		"name": "ตลาดสามัคคี",
		"area": "กลางซอยส่งไว",
		"pos": Vector2(470, 300)
	},
	{
		"key": "pa_nok",
		"type": "restaurant",
		"name": "ก๋วยเตี๋ยวเรือป้านก",
		"area": "ริมคลอง",
		"pos": Vector2(820, 150)
	},
	{
		"key": "rom_yen",
		"type": "house",
		"name": "หมู่บ้านร่มเย็น",
		"area": "ซอยส่งไว แยก 7",
		"pos": Vector2(140, 520)
	},
	{
		"key": "suk_san",
		"type": "house",
		"name": "ชุมชนสุขสันต์",
		"area": "หลังวัด",
		"pos": Vector2(450, 620)
	},
	{
		"key": "river_view",
		"type": "condo",
		"name": "เดอะ ริเวอร์วิว",
		"area": "ถนนใหญ่ (ไม่เห็นแม่น้ำ)",
		"pos": Vector2(880, 560)
	},
	{
		"key": "synergy",
		"type": "office",
		"name": "ซินเนอร์จี้ ทาวเวอร์",
		"area": "ถนนใหญ่",
		"pos": Vector2(700, 330)
	},
	{
		"key": "pailin",
		"type": "gas",
		"name": "ปั๊มไพลินออยล์",
		"area": "ตีนสะพาน",
		"pos": Vector2(420, 100)
	},
	{
		"key": "hia_peng",
		"type": "garage",
		"name": "อู่เฮียเป้ง",
		"area": "ใต้ทางด่วน",
		"pos": Vector2(260, 360)
	},
	{
		"key": "khet",
		"type": "office",
		"name": "สำนักงานเขตส่งไว",
		"area": "ข้างวัด",
		"pos": Vector2(640, 500)
	},
]
## [a, b, kind, flood]: flood 1 = wade in heavy rain, 2 = closed.
const ROADS := [
	[0, 7, "main", 0],
	[0, 1, "soi", 1],
	[0, 8, "soi", 0],
	[8, 3, "soi", 2],
	[8, 1, "soi", 0],
	[1, 7, "soi", 0],
	[1, 4, "soi", 1],
	[3, 4, "soi", 1],
	[1, 6, "main", 0],
	[7, 2, "main", 0],
	[2, 6, "main", 0],
	[6, 5, "main", 1],
	[6, 9, "main", 0],
	[9, 4, "soi", 1],
	[9, 5, "soi", 2],
]


static func city(seed: int) -> Dictionary:
	var nodes: Array = []
	for i in PLACES.size():
		var n: Dictionary = PLACES[i].duplicate()
		n["id"] = i
		nodes.append(n)
	var edges: Array = []
	for r in ROADS:
		var a: int = r[0]
		var b: int = r[1]
		var km := (nodes[a]["pos"] as Vector2).distance_to(nodes[b]["pos"]) / CityGen.UNITS_PER_KM
		(
			edges
			. append(
				{
					"a": mini(a, b),
					"b": maxi(a, b),
					"kind": r[2],
					"km": snappedf(km, 0.1),
					"minutes": snappedf(2.0 + km * CityGen.MIN_PER_KM[r[2]], 0.5),
					"flood": r[3],
				}
			)
		)
	return {"seed": seed, "nodes": nodes, "edges": edges}


static func id_of(key: String) -> int:
	for i in PLACES.size():
		if PLACES[i]["key"] == key:
			return i
	return -1
