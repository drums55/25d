# gdlint: disable=max-public-methods
extends Node
## Rider game state (DESIGN 10, P0): money, debt, fuel, rating, the day clock
## (minutes), where the rider is in the generated city, and the orders list
## (rules in the Orders autoload). Saves to slots (0 = autosave).

signal flag_changed(flag: String, value: bool)
signal money_changed(money: int)
signal inventory_changed(inventory: Array)
## Short player-facing notice.
signal notice(text: String)
signal time_changed(day: int, minute: float)
## Fuel, rating, debt or acceptance changed.
signal stats_changed
signal game_over(reason: String)

const LOCATION_SCENE := "res://scenes/rooms/location.tscn"
const SAVE_SLOTS := 3

## Day runs 07:00 - 23:00 in game minutes; after DAY_END the app stops offering.
const DAY_START := 7 * 60
const DAY_END := 23 * 60
## Short game: the run ends after this many days (DESIGN 10.2).
const LAST_DAY := 7

const START_MONEY := 300
const BIKE_RENT := 150
const DEBT_PRINCIPAL := 3000
## Loan-shark "floating interest": paid every morning, principal never shrinks
## unless paid on top.
const DEBT_INTEREST := 60
const MISSES_TO_LOSE_BIKE := 3
const FUEL_TANK := 4.0
const KM_PER_LITRE := 40.0
const FUEL_PRICE := 38.0
## Bag capacity in slots (food/doc 1, big parcels 2).
const BAG_SLOTS := 3
## The platform suspends the account below this average.
const MIN_RATING := 4.3
const RATING_WINDOW := 40

## Item id -> display name for dialog items (kept from the dialog system).
const ITEMS := {}

var flags := {}
var inventory: Array = []
var money := START_MONEY:
	set(v):
		money = maxi(v, 0)
		money_changed.emit(money)
var day := 1
var minute := float(DAY_START)
var city_seed := 0
## Node id in the city where the rider is.
var location := 0
var fuel := FUEL_TANK
var ratings: Array = []
var offered := 0
var accepted := 0
var debt := DEBT_PRINCIPAL
var missed_payments := 0
## All live orders (offered / accepted / picked); see Orders.
var orders: Array = []
var next_order_id := 1
## Today's numbers for the evening slip.
var log_today := {}
var finished := ""
## Blocks player input (scene transitions). Dialog blocks separately.
var input_locked := false
## A full-screen UI (phone app, slip) is open: taps go to it, not the world.
var ui_open := false
## The game clock does not run (phone menu tab, slips, endings).
var clock_paused := false


func set_flag(flag: String, value := true) -> void:
	if flag.is_empty():
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func has_item(item: String) -> bool:
	return inventory.has(item)


func give_item(item: String) -> void:
	if item.is_empty() or inventory.has(item):
		return
	inventory.append(item)
	inventory_changed.emit(inventory)
	notice.emit("ได้รับ: %s" % item_name(item))


func take_item(item: String) -> bool:
	if not inventory.has(item):
		return false
	inventory.erase(item)
	inventory_changed.emit(inventory)
	return true


static func item_name(item: String) -> String:
	return ITEMS.get(item, item)


func add_money(amount: int, log_key := "") -> void:
	if amount == 0:
		return
	money += amount
	if not log_key.is_empty():
		log_today[log_key] = int(log_today.get(log_key, 0)) + amount
	notice.emit(("+%d บาท" if amount > 0 else "%d บาท") % amount)


func rating() -> float:
	if ratings.is_empty():
		return 5.0
	var total := 0.0
	var recent := ratings.slice(maxi(0, ratings.size() - RATING_WINDOW))
	for r in recent:
		total += float(r)
	return total / recent.size()


func add_rating(stars: int) -> void:
	ratings.append(stars)
	stats_changed.emit()


func acceptance() -> float:
	return 1.0 if offered == 0 else float(accepted) / offered


func clock_text() -> String:
	return Weather.clock_text(minute)


func advance_minutes(m: float) -> void:
	if m <= 0.0:
		return
	minute += m
	time_changed.emit(day, minute)


func is_closing() -> bool:
	return minute >= DAY_END


func use_fuel(litres: float) -> void:
	fuel = maxf(fuel - litres, 0.0)
	log_today["fuel_l"] = float(log_today.get("fuel_l", 0.0)) + litres
	stats_changed.emit()


## Fill the tank (only at a gas station). Returns baht paid.
func refuel() -> int:
	var litres := FUEL_TANK - fuel
	var cost := ceili(litres * FUEL_PRICE)
	cost = mini(cost, money)
	if cost <= 0:
		return 0
	fuel = minf(FUEL_TANK, fuel + cost / FUEL_PRICE)
	add_money(-cost, "fuel")
	stats_changed.emit()
	return cost


func pay_debt(amount: int) -> int:
	var paid := mini(mini(amount, money), debt)
	if paid <= 0:
		return 0
	add_money(-paid, "debt")
	debt -= paid
	stats_changed.emit()
	notice.emit("จ่ายเงินต้นเจ้าหนี้ %d (เหลือ %d)" % [paid, debt])
	return paid


## Morning: bike rent + loan interest. Unpaid = a strike with the creditor.
## Returns the charges for the slip.
func morning_charges() -> Dictionary:
	var due := BIKE_RENT + (DEBT_INTEREST if debt > 0 else 0)
	var paid := mini(due, money)
	money -= paid
	var short := due - paid
	if short > 0:
		missed_payments += 1
		notice.emit(
			"เงินไม่พอจ่ายค่าเช่ารถ+ดอก ขาด %d บาท (เตือนครั้งที่ %d)" % [short, missed_payments]
		)
	stats_changed.emit()
	return {"rent": BIKE_RENT, "interest": DEBT_INTEREST if debt > 0 else 0, "short": short}


## Checks the losing conditions; returns the reason ("" = still playing).
func check_game_over() -> String:
	if not finished.is_empty():
		return finished
	if missed_payments >= MISSES_TO_LOSE_BIKE:
		return _finish("lose_bike")
	if ratings.size() >= 10 and rating() < MIN_RATING:
		return _finish("suspended")
	return ""


func _finish(reason: String) -> String:
	finished = reason
	game_over.emit(reason)
	return reason


func end_run() -> String:
	return _finish("paid_off" if debt <= 0 else "still_owing")


func start_new_day() -> Dictionary:
	day += 1
	minute = DAY_START
	log_today = {}
	var charges := morning_charges()
	time_changed.emit(day, minute)
	notice.emit("วันที่ %d" % day)
	return charges


func new_game(seed := -1) -> void:
	flags = {}
	inventory = []
	money = START_MONEY
	day = 1
	minute = DAY_START
	city_seed = seed if seed >= 0 else randi() % 1000000
	location = 0
	fuel = FUEL_TANK
	# a fresh account starts with some history: 4.8 stars
	ratings = []
	for i in 20:
		ratings.append(5 if i % 5 else 4)
	offered = 0
	accepted = 0
	debt = DEBT_PRINCIPAL
	missed_payments = 0
	orders = []
	next_order_id = 1
	log_today = {}
	finished = ""
	input_locked = false
	ui_open = false
	clock_paused = false
	inventory_changed.emit(inventory)
	stats_changed.emit()
	time_changed.emit(day, minute)


func snapshot() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"inventory": inventory.duplicate(),
		"money": money,
		"day": day,
		"minute": minute,
		"city_seed": city_seed,
		"location": location,
		"fuel": fuel,
		"ratings": ratings.duplicate(),
		"offered": offered,
		"accepted": accepted,
		"debt": debt,
		"missed_payments": missed_payments,
		"orders": orders.duplicate(true),
		"next_order_id": next_order_id,
		"log_today": log_today.duplicate(true),
		"finished": finished,
	}


func restore(d: Dictionary) -> void:
	new_game(int(d.get("city_seed", 0)))
	flags = d.get("flags", {})
	inventory = d.get("inventory", [])
	money = int(d.get("money", START_MONEY))
	day = int(d.get("day", 1))
	minute = float(d.get("minute", DAY_START))
	location = int(d.get("location", 0))
	fuel = float(d.get("fuel", FUEL_TANK))
	ratings = d.get("ratings", ratings)
	offered = int(d.get("offered", 0))
	accepted = int(d.get("accepted", 0))
	debt = int(d.get("debt", DEBT_PRINCIPAL))
	missed_payments = int(d.get("missed_payments", 0))
	orders = d.get("orders", [])
	for o in orders:
		# JSON numbers come back as float
		for key in ["id", "pickup", "dropoff", "fee", "tip", "cod", "size"]:
			if o.has(key):
				o[key] = int(o[key])
	next_order_id = int(d.get("next_order_id", 1))
	log_today = d.get("log_today", {})
	finished = str(d.get("finished", ""))
	inventory_changed.emit(inventory)
	stats_changed.emit()
	time_changed.emit(day, minute)


static func slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot


func save_game(slot := 0, path := "") -> bool:
	var s := SaveData.new()
	s.state = snapshot()
	s.meta = {
		"day": day,
		"clock": clock_text(),
		"money": money,
		"debt": debt,
		"place": City.node_name(location) if City.has_city() else "",
		"saved_at": Time.get_datetime_string_from_system(false, true),
	}
	var err := s.write(path if not path.is_empty() else slot_path(slot))
	if err != OK:
		push_error("GameState: save failed (%s)" % error_string(err))
	return err == OK


func load_game(slot := 0, path := "") -> bool:
	var s := SaveData.read(path if not path.is_empty() else slot_path(slot))
	if s == null:
		return false
	restore(s.state)
	return true


## {slot: meta} for slots that hold a valid save.
func list_saves() -> Dictionary:
	var out := {}
	for slot in range(0, SAVE_SLOTS + 1):
		var s := SaveData.read(slot_path(slot))
		if s:
			out[slot] = s.meta
	return out


func has_any_save() -> bool:
	return not list_saves().is_empty()


## Most recently written save slot, or -1.
func latest_slot() -> int:
	var best := -1
	var best_time := ""
	var saves := list_saves()
	for slot in saves:
		var t := str(saves[slot].get("saved_at", ""))
		if best == -1 or t > best_time:
			best = slot
			best_time = t
	return best


func delete_save(slot := 0, path := "") -> void:
	var p := path if not path.is_empty() else slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
