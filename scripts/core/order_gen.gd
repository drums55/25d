class_name OrderGen
extends RefCounted
## Makes delivery orders for the rider app (DESIGN 10.4). Pure logic.
##
## Order = {id, kind: "food"|"parcel"|"doc", item, pickup, dropoff (node ids),
## customer, fee, tip, cod, size (bag slots), offered_at, expires_at,
## ready_at (food is cooked by then), deadline, sign_name (doc), status}.
## Fees only pay pickup -> dropoff distance; the ride to the pickup is free
## labour, like the real apps.

const KIND_WEIGHTS := {"food": 6, "parcel": 3, "doc": 1}
const KIND_NAMES := {"food": "อาหาร", "parcel": "พัสดุ", "doc": "เอกสาร"}
## Base fee + per km by kind (the platform can change these: P2 policies).
const BASE_FEE := {"food": 28, "parcel": 32, "doc": 40}
const PER_KM := {"food": 5, "parcel": 5, "doc": 7}
const RAIN_SURGE := 10
## Minutes an offer stays on screen before it goes to another rider.
const OFFER_MINUTES := Vector2i(6, 12)

const FOOD_ITEMS := [
	"ข้าวมันไก่ 3 ห่อ (ไม่เอาหนัง)",
	"ก๋วยเตี๋ยวเรือ 2 ชาม + น้ำแข็งแยก",
	"ชาไข่มุก หวาน 200% x4",
	"ส้มตำปูปลาร้า เผ็ด 10 เม็ด",
	"ข้าวขาหมู พิเศษ ขาหมูล้วน",
	"สุกี้น้ำ ห้ามหก",
	"โจ๊กหมูใส่ไข่ (ไข่ต้องไม่แตก)",
	"ข้าวผัดกะเพรา 'ไม่ใส่กะเพรา'",
]
const PARCEL_ITEMS := [
	"กล่องรองเท้า (เบา)",
	"ต้นไม้ในกระถาง",
	"ลังน้ำดื่ม 2 แพ็ก",
	"พัดลมตั้งพื้น",
	"กล่องที่เขียนว่า 'ของเหลว อย่าเขย่า'",
	"ไม้กวาดทางมะพร้าว 3 อัน",
]
const DOC_ITEMS := ["สัญญาเช่า ต้องเซ็น", "เอกสารยื่นธนาคาร", "ใบเสนอราคา", "สำเนาบัตร 40 แผ่น"]
const CUSTOMERS := [
	"คุณบี", "คุณเอ็ม", "คุณแนน", "คุณต้น", "คุณพลอย", "คุณบอส", "คุณมายด์", "คุณเจ"
]
const PICKUP_TYPES := {
	"food": ["restaurant", "restaurant", "market"],
	"parcel": ["market", "office", "garage", "condo"],
	"doc": ["office"],
}
const UNFAIR_REVIEWS := [
	"อาหารไม่อร่อย (ร้านทำ) 1 ดาวนะ",
	"ไรเดอร์หน้าไม่ยิ้ม",
	"ฝนตก ไม่ชอบ",
	"ให้ 1 ดาวเพราะกดผิด ขี้เกียจแก้",
	"สั่งผิดเมนูเอง แต่โมโห",
	"ช้า (ส่งก่อนเวลา 10 นาที)",
]
const DROPOFF_TYPES := {
	"food": ["house", "condo", "office"],
	"parcel": ["house", "condo", "office"],
	"doc": ["office", "condo"],
}


static func make(
	rng: RandomNumberGenerator, city: Dictionary, minute: float, rain: int, id: int
) -> Dictionary:
	var kind := CityGen._weighted(rng, KIND_WEIGHTS)
	var pickup := _pick_node(rng, city, PICKUP_TYPES[kind], -1)
	var dropoff := _pick_node(rng, city, DROPOFF_TYPES[kind], pickup)
	var a: Dictionary = city["nodes"][pickup]
	var b: Dictionary = city["nodes"][dropoff]
	var km: float = (a["pos"] as Vector2).distance_to(b["pos"]) / CityGen.UNITS_PER_KM
	var fee := int(BASE_FEE[kind] + PER_KM[kind] * km) + (RAIN_SURGE if rain > 0 else 0)
	var order := {
		"id": id,
		"kind": kind,
		"pickup": pickup,
		"dropoff": dropoff,
		"customer": CUSTOMERS[rng.randi() % CUSTOMERS.size()],
		"fee": fee,
		"tip": [0, 0, 0, 10, 20][rng.randi() % 5],
		"cod": 0,
		"size": 1,
		"offered_at": minute,
		"expires_at": minute + rng.randi_range(OFFER_MINUTES.x, OFFER_MINUTES.y),
		"ready_at": minute,
		"deadline": minute + 120,
		"sign_name": "",
		"status": "offered",
	}
	match kind:
		"food":
			order["item"] = FOOD_ITEMS[rng.randi() % FOOD_ITEMS.size()]
			order["ready_at"] = minute + rng.randi_range(5, 25)
			order["deadline"] = order["ready_at"] + 30 + km * 4.0
		"parcel":
			order["item"] = PARCEL_ITEMS[rng.randi() % PARCEL_ITEMS.size()]
			order["size"] = 2 if rng.randf() < 0.3 else 1
			if rng.randf() < 0.35:
				order["cod"] = rng.randi_range(3, 12) * 50
			order["deadline"] = minute + 180
		"doc":
			order["item"] = DOC_ITEMS[rng.randi() % DOC_ITEMS.size()]
			order["sign_name"] = order["customer"]
			order["deadline"] = minute + 75 + km * 4.0
	order["deadline"] = snappedf(order["deadline"], 1.0)
	return order


static func _pick_node(
	rng: RandomNumberGenerator, city: Dictionary, types: Array, avoid: int
) -> int:
	var type: String = types[rng.randi() % types.size()]
	var pool: Array = []
	for n in city["nodes"]:
		if n["id"] != avoid and n["type"] == type:
			pool.append(n["id"])
	if pool.is_empty():
		for n in city["nodes"]:
			if n["id"] != avoid:
				pool.append(n["id"])
	return pool[rng.randi() % pool.size()]


## Food heat: 2 hot, 1 warm, 0 cold, from minutes since it was ready.
static func heat(order: Dictionary, minute: float) -> int:
	if order["kind"] != "food":
		return 2
	var age := minute - float(order["ready_at"])
	return 2 if age < 20.0 else (1 if age < 40.0 else 0)


static func heat_text(h: int) -> String:
	return ["เย็นชืด", "อุ่นๆ", "ร้อน"][h]


## Customer stars (1-5) and the review line. `rng` adds the unfair 1-star
## reviews riders get for things they cannot control.
static func rate(rng: RandomNumberGenerator, order: Dictionary, minute: float) -> Dictionary:
	var stars := 5
	var notes: Array[String] = []
	var late := minute - float(order["deadline"])
	if late > 0:
		stars -= mini(3, 1 + int(late / 15.0))
		notes.append("มาช้า")
	if heat(order, minute) == 0:
		stars -= 1
		notes.append("อาหารเย็น")
	if order.get("spilled", false):
		stars -= 1
		notes.append("น้ำซุปหก")
	if rng.randf() < 0.08:
		return {"stars": 1, "review": UNFAIR_REVIEWS[rng.randi() % UNFAIR_REVIEWS.size()]}
	stars = clampi(stars, 1, 5)
	var review := "ขอบคุณค่ะ" if notes.is_empty() else ", ".join(notes)
	return {"stars": stars, "review": review}
