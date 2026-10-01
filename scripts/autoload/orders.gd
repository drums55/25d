# gdlint: disable=max-public-methods
extends Node
## Rider app orders (DESIGN 10.4, P0). Offers pop up while the clock runs and
## expire if not taken; accepted orders are picked up from the place's
## merchant NPC (npc_id "merchant") and handed to the customer NPC spawned at
## the drop-off place (npc_id "customer_<id>"). State lives in
## GameState.orders so it is saved.
##
## Behaviour by kind: food is cooked by `ready_at` (arriving early = waiting),
## cools over time and can spill; parcels take bag space and may be COD (rider
## pays the shop at pickup, collects at drop-off); documents must be signed
## by the named person before the hard deadline.

signal orders_changed
signal offer_added(order: Dictionary)
signal delivered(order: Dictionary, stars: int, review: String)

const MAX_OFFERS := 2
## Minutes between new offers (dry, rain).
const GAP_DRY := Vector2i(6, 14)
const GAP_RAIN := Vector2i(3, 8)

var rng := RandomNumberGenerator.new()
var _next_offer_at := 0.0
var _day := -1


func _ready() -> void:
	rng.randomize()
	GameState.time_changed.connect(_on_time)


func _on_time(_day: int, minute: float) -> void:
	tick(minute)


## Expire old offers and maybe add a new one.
func tick(minute: float) -> void:
	if GameState.day != _day or minute + 1.0 < _next_offer_at - 60.0:
		# new day / new game / loaded save: offer right away
		_day = GameState.day
		_next_offer_at = 0.0
	var changed := false
	for o in GameState.orders.duplicate():
		if o["status"] == "offered" and minute > float(o["expires_at"]):
			GameState.orders.erase(o)
			changed = true
	if not GameState.is_closing() and GameState.finished.is_empty():
		if offers().size() < MAX_OFFERS and minute >= _next_offer_at:
			_add_offer(minute)
			changed = true
	if changed:
		orders_changed.emit()


func _add_offer(minute: float) -> void:
	var rain := City.rain_now()
	var o := OrderGen.make(rng, City.get_city(), minute, rain, GameState.next_order_id)
	var to_pick := City.route_to(int(o["pickup"]))
	var trip := City.route_between(int(o["pickup"]), int(o["dropoff"]))
	OrderGen.set_deadline(
		o, minute, float(to_pick.get("minutes", 20.0)), float(trip.get("minutes", 25.0))
	)
	GameState.next_order_id += 1
	GameState.orders.append(o)
	GameState.offered += 1
	var gap := GAP_RAIN if rain > 0 else GAP_DRY
	_next_offer_at = minute + rng.randi_range(gap.x, gap.y)
	offer_added.emit(o)
	GameState.stats_changed.emit()


func get_order(id: int) -> Dictionary:
	for o in GameState.orders:
		if int(o["id"]) == id:
			return o
	return {}


func offers() -> Array:
	return GameState.orders.filter(func(o): return o["status"] == "offered")


func active() -> Array:
	return GameState.orders.filter(func(o): return o["status"] != "offered")


func bag_used() -> int:
	var used := 0
	for o in active():
		used += int(o["size"])
	return used


func can_accept(o: Dictionary) -> bool:
	return bag_used() + int(o["size"]) <= GameState.BAG_SLOTS


func carrying_cargo() -> bool:
	for o in GameState.orders:
		if o["status"] == "picked":
			return true
	return false


func accept(id: int) -> bool:
	var o := get_order(id)
	if o.is_empty() or o["status"] != "offered" or not can_accept(o):
		return false
	o["status"] = "accepted"
	GameState.accepted += 1
	GameState.notice.emit("รับงาน: %s" % o["item"])
	GameState.stats_changed.emit()
	orders_changed.emit()
	return true


func decline(id: int) -> void:
	var o := get_order(id)
	if o.is_empty() or o["status"] != "offered":
		return
	GameState.orders.erase(o)
	orders_changed.emit()


## Cancelling an accepted job before pickup: the platform counts it against
## you (as if you never accepted) and the customer is told "ไรเดอร์ยกเลิก".
func cancel(id: int) -> void:
	var o := get_order(id)
	if o.is_empty() or o["status"] != "accepted":
		return
	GameState.orders.erase(o)
	GameState.accepted = maxi(GameState.accepted - 1, 0)
	GameState.notice.emit("ยกเลิกงานแล้ว อัตรารับงานลดลง")
	GameState.stats_changed.emit()
	orders_changed.emit()


## Orders to pick up / hand over at a place.
func pickups_at(node_id: int) -> Array:
	return GameState.orders.filter(
		func(o): return o["status"] == "accepted" and int(o["pickup"]) == node_id
	)


## Where the customer really is (a wrong pin points next door).
static func real_dropoff(o: Dictionary) -> int:
	return int(o.get("true_dropoff", o["dropoff"]))


## Where the app shows the pin: the wrong one until the rider finds out.
static func shown_dropoff(o: Dictionary) -> int:
	if o.get("pin_wrong", false) and not o.get("pin_found", false):
		return int(o["dropoff"])
	return real_dropoff(o)


func dropoffs_at(node_id: int) -> Array:
	return GameState.orders.filter(
		func(o): return o["status"] == "picked" and real_dropoff(o) == node_id
	)


## Customers who are standing at this place right now (not the no-shows;
## condo residents only once the guard called them down).
func waiting_customers(node_id: int) -> Array:
	var condo: bool = City.node(node_id)["type"] == "condo"
	return GameState.orders.filter(
		func(o):
			return (
				o["status"] != "offered"
				and real_dropoff(o) == node_id
				and not o.get("no_show", false)
				and (not condo or o.get("called_down", false))
			)
	)


## Picked orders whose wrong pin points here (a local can tell where to go).
func misled_here(node_id: int) -> Array:
	return GameState.orders.filter(
		func(o):
			return (
				o["status"] == "picked"
				and o.get("pin_wrong", false)
				and not o.get("pin_found", false)
				and int(o["dropoff"]) == node_id
			)
	)


## Picked COD parcels for a customer who is not home, at this place.
func no_shows_here(node_id: int) -> Array:
	return dropoffs_at(node_id).filter(func(o): return o.get("no_show", false))


## Called by Interactable before its dialog. True when an order used the tap.
func on_interact(npc_id: String) -> bool:
	if npc_id == "merchant":
		return _pick_up_here() or _call_down_here()
	if npc_id.begins_with("customer_"):
		return _deliver(int(npc_id.trim_prefix("customer_")))
	if npc_id.begins_with("local_"):
		return _ask_local(int(npc_id.trim_prefix("local_")))
	if npc_id.begins_with("door_"):
		return _ring_door(int(npc_id.trim_prefix("door_")))
	return false


## A local at the wrongly pinned place knows where the customer really is.
func _ask_local(id: int) -> bool:
	var o := get_order(id)
	if o.is_empty() or not o.get("pin_wrong", false):
		return false
	o["pin_found"] = true
	var where := City.node_name(real_dropoff(o))
	(
		Dialog
		. start_lines(
			[
				{"speaker": "คนแถวนี้", "text": "%s เหรอ ไม่ใช่ที่นี่หรอก" % o["customer"]},
				{
					"speaker": "คนแถวนี้",
					"text": "อยู่ %s โน่น หมุดเขาชอบปักกลางซอยแบบนี้ประจำ" % where
				},
				"(แอปอัปเดตหมุดใหม่ให้แล้ว ... ส่วนเวลาที่เสียไป แอปไม่อัปเดตให้)",
			],
			"local"
		)
	)
	orders_changed.emit()
	return true


func _ring_door(id: int) -> bool:
	var o := get_order(id)
	if o.is_empty():
		return false
	GameState.advance_minutes(2)
	(
		Dialog
		. start_lines(
			[
				"กดกริ่ง ... เงียบ กดอีกที ... หมาบ้านข้างๆ เห่า",
				'(ในแอปมีปุ่ม "รอลูกค้า" กับ "ตีกลับ" ที่งานนี้)',
			],
			"door"
		)
	)
	return true


## Phone button: ring the customer. Busy half the time; otherwise the call
## fixes a wrong pin, calls a condo resident down, or confirms a no-show.
func call_customer(id: int) -> String:
	var o := get_order(id)
	if o.is_empty():
		return ""
	GameState.advance_minutes(2)
	var text := ""
	if rng.randf() < 0.45:
		text = "ตู๊ด ... ตู๊ด ... ลูกค้าไม่รับสาย"
	elif o.get("pin_wrong", false) and not o.get("pin_found", false):
		o["pin_found"] = true
		text = (
			"%s: อยู่ตรงข้ามเซเว่นค่ะ (แถวนั้นมีเซเว่นห้าร้าน) ... อ๋อ %s ค่ะ"
			% [o["customer"], City.node_name(real_dropoff(o))]
		)
	elif o.get("no_show", false):
		text = "%s: ไม่อยู่บ้านค่ะ ฝากไว้ไม่ได้ด้วยนะคะ เดี๋ยวของหาย" % o["customer"]
	elif City.node(real_dropoff(o))["type"] == "condo":
		o["called_down"] = true
		text = "%s: กำลังลงไปค่ะ (ลิฟต์ชั้น 27 ... รอนิดนึงนะคะ)" % o["customer"]
	else:
		text = "%s: ค่ะๆ รออยู่หน้าบ้านค่ะ" % o["customer"]
	GameState.notice.emit(text)
	orders_changed.emit()
	return text


## Phone button at a no-show: wait 10 minutes hoping the customer turns up.
func wait_for_customer(id: int) -> bool:
	var o := get_order(id)
	if o.is_empty() or not o.get("no_show", false):
		return false
	GameState.advance_minutes(10)
	if rng.randf() < 0.35:
		o["no_show"] = false
		GameState.notice.emit("%s กลับมาพอดี ถือถุงหมูปิ้งมาด้วย" % o["customer"])
		orders_changed.emit()
		return true
	GameState.notice.emit("รอ 10 นาที ... ยังไม่มีใคร")
	return false


## Phone button at a no-show: give up and return the parcel. The rider
## already paid the shop; the platform promises half back tomorrow.
func return_parcel(id: int) -> void:
	var o := get_order(id)
	if o.is_empty():
		return
	GameState.orders.erase(o)
	var back := int(o["cod"]) / 2
	GameState.pending_refund += back
	GameState.log_today["cod_lost"] = (
		int(GameState.log_today.get("cod_lost", 0)) + int(o["cod"]) - back
	)
	GameState.notice.emit(
		"ตีกลับพัสดุ ... แพลตฟอร์มจะคืนเงินให้ %d บาท (ครึ่งเดียว) พรุ่งนี้" % back
	)
	orders_changed.emit()


## After a ride: a cash food order may be cancelled once the rider has paid
## for the food. The money is gone; the food is the rider's dinner now.
func check_cancellations() -> void:
	for o in GameState.orders.duplicate():
		if o["status"] == "picked" and o.get("will_cancel", false):
			GameState.orders.erase(o)
			GameState.log_today["cod_lost"] = (
				int(GameState.log_today.get("cod_lost", 0)) + int(o["cod"])
			)
			(
				Dialog
				. start_lines(
					[
						'แอปเด้ง: "ลูกค้ายกเลิกออเดอร์ %s"' % o["item"],
						(
							'ค่าอาหาร %d บาทที่สำรองจ่ายไป ... แพลตฟอร์ม: "ขออภัยในความไม่สะดวก"'
							% int(o["cod"])
						),
						{"speaker": "ไรเดอร์", "text": "งั้นมื้อเย็นวันนี้ ... %s" % o["item"]},
					],
					"cancelled"
				)
			)
			orders_changed.emit()
			return


func _pick_up_here() -> bool:
	var list := pickups_at(GameState.location)
	if list.is_empty():
		return false
	var lines: Array = []
	var wait := 0.0
	for o in list:
		wait = maxf(wait, float(o["ready_at"]) - GameState.minute)
	if wait > 0.0:
		GameState.advance_minutes(ceilf(wait))
		lines.append(
			"รอร้านทำอาหาร %d นาที ... ยืนดูแม่ครัวทอดไข่ช้าๆ เหมือนสโลว์โมชัน" % ceili(wait)
		)
	for o in list:
		if int(o["cod"]) > 0:
			if GameState.money < int(o["cod"]):
				lines.append(
					(
						"ร้าน: ออเดอร์ %s เก็บเงินปลายทาง ต้องสำรองจ่าย %d บาทก่อนนะ ... เงินไม่พอ"
						% [o["item"], o["cod"]]
					)
				)
				continue
			GameState.add_money(-int(o["cod"]), "cod_out")
		o["status"] = "picked"
		o["picked_at"] = GameState.minute
		lines.append(
			(
				"รับของแล้ว: %s → ส่ง %s ที่ %s"
				% [o["item"], o["customer"], City.node_name(shown_dropoff(o))]
			)
		)
	Dialog.start_lines(lines, "pickup")
	orders_changed.emit()
	return true


## Condo guard: phones the residents waiting for a delivery; they come down
## after a few minutes (riders may not go up — unless they sneak the lift).
func _call_down_here() -> bool:
	if City.here()["type"] != "condo":
		return false
	var waiting := dropoffs_at(GameState.location).filter(
		func(o): return not o.get("called_down", false) and not o.get("no_show", false)
	)
	if waiting.is_empty():
		return false
	var wait := rng.randi_range(4, 12)
	for o in waiting:
		o["called_down"] = true
	GameState.advance_minutes(wait)
	(
		Dialog
		. start_lines(
			[
				{"speaker": "รปภ.", "text": "ไรเดอร์ห้ามขึ้นนะครับ เดี๋ยวผมโทรขึ้นห้องให้"},
				"(รอ %d นาที ... ลูกค้าเดินลงมาในชุดนอน)" % wait,
			],
			"call_down"
		)
	)
	SceneRouter.go_to(GameState.LOCATION_SCENE, "arrival", false)
	orders_changed.emit()
	return true


## Lift: sneak past the lift guard and deliver at the door (tip +10 each).
## `seen` = a guard bot saw the rider at the lift.
func sneak_lift(seen: bool) -> void:
	if seen:
		GameState.advance_minutes(3)
		Dialog.start_lines(
			[{"speaker": "รปภ.", "text": "เฮ้ย! ไรเดอร์ห้ามใช้ลิฟต์ ไปรอที่ล็อบบี้โน่น"}],
			"lift_caught"
		)
		return
	var here := dropoffs_at(GameState.location).filter(func(o): return not o.get("no_show", false))
	if here.is_empty():
		Dialog.start_lines(["ขึ้นลิฟต์ไปทำไม ... ไม่มีของต้องส่งที่นี่"], "lift_empty")
		return
	for o in here:
		o["tip"] = int(o["tip"]) + 10
		o["called_down"] = true
		Dialog.end_now()
		_deliver(int(o["id"]))


func _deliver(id: int) -> bool:
	var o := get_order(id)
	if o.is_empty() or o["status"] != "picked" or real_dropoff(o) != GameState.location:
		return false
	var result := OrderGen.rate(rng, o, GameState.minute)
	var stars: int = result["stars"]
	if result.get("unfair", false):
		GameState.appeals.append(
			{
				"id": int(o["id"]),
				"item": o["item"],
				"review": result["review"],
				"index": GameState.ratings.size(),
				"open": true
			}
		)
	GameState.orders.erase(o)
	GameState.add_money(int(o["fee"]), "fees")
	if int(o["tip"]) > 0 and stars >= 4:
		GameState.add_money(int(o["tip"]), "tips")
	if int(o["cod"]) > 0:
		GameState.add_money(int(o["cod"]), "cod_in")
	GameState.add_rating(stars)
	GameState.log_today["delivered"] = int(GameState.log_today.get("delivered", 0)) + 1
	GameState.advance_minutes(2)
	var who: String = o["customer"]
	var lines: Array = []
	if o["kind"] == "doc":
		lines.append(
			{"speaker": who, "text": "เซ็นตรงนี้ใช่ไหม ... (เซ็นชื่อยาวเหมือนลายเซ็นดารา)"}
		)
	elif o["kind"] == "food":
		lines.append(
			{
				"speaker": who,
				"text": "ได้แล้วค่า (%s)" % OrderGen.heat_text(OrderGen.heat(o, GameState.minute))
			}
		)
	else:
		lines.append({"speaker": who, "text": "วางไว้ตรงนั้นแหละ"})
	lines.append('รีวิว %s  "%s"' % ["★".repeat(stars) + "☆".repeat(5 - stars), result["review"]])
	Dialog.start_lines(lines, "dropoff")
	delivered.emit(o, stars, result["review"])
	orders_changed.emit()
	GameState.check_game_over()
	return true


## A patrol (PatrolBot) caught the rider: food carried gets knocked about.
func on_player_caught() -> void:
	for o in GameState.orders:
		if o["status"] == "picked" and o["kind"] == "food":
			o["spilled"] = true
	orders_changed.emit()


## Night: unfinished orders fail (1 star each, COD money already paid is
## lost with the parcel). Returns the day's slip.
func end_day() -> Dictionary:
	var failed := 0
	for o in GameState.orders.duplicate():
		if o["status"] != "offered":
			failed += 1
			GameState.add_rating(1)
		GameState.orders.erase(o)
	var slip := GameState.log_today.duplicate()
	slip["failed"] = failed
	slip["day"] = GameState.day
	orders_changed.emit()
	_next_offer_at = 0.0
	return slip
