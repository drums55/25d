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


func dropoffs_at(node_id: int) -> Array:
	return GameState.orders.filter(
		func(o): return o["status"] == "picked" and int(o["dropoff"]) == node_id
	)


## Called by Interactable before its dialog. True when an order used the tap.
func on_interact(npc_id: String) -> bool:
	if npc_id == "merchant":
		return _pick_up_here()
	if npc_id.begins_with("customer_"):
		return _deliver(int(npc_id.trim_prefix("customer_")))
	return false


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
				% [o["item"], o["customer"], City.node_name(o["dropoff"])]
			)
		)
	Dialog.start_lines(lines, "pickup")
	orders_changed.emit()
	return true


func _deliver(id: int) -> bool:
	var o := get_order(id)
	if o.is_empty() or o["status"] != "picked" or int(o["dropoff"]) != GameState.location:
		return false
	var result := OrderGen.rate(rng, o, GameState.minute)
	var stars: int = result["stars"]
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
