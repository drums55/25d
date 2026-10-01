extends GutTest
## Rider loop (P0): offers, accept, ride, pick up, deliver, rating, money,
## rain / floods, the day slip and the endings.

var _main: Node


func before_each():
	TestHelpers.start_at("restaurant")
	Orders.rng.seed = 11
	City.rng.seed = 5
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)


func after_each():
	TestHelpers.finish_dialog()
	for slot in range(0, GameState.SAVE_SLOTS + 1):
		GameState.delete_save(slot)
	GameState.new_game()


## Puts a hand-made order in the app (deterministic).
func _order(kind: String, pickup: int, dropoff: int, extra := {}) -> Dictionary:
	var o := {
		"id": GameState.next_order_id,
		"kind": kind,
		"item": "ของทดสอบ",
		"pickup": pickup,
		"dropoff": dropoff,
		"customer": "คุณบี",
		"fee": 50,
		"tip": 0,
		"cod": 0,
		"size": 1,
		"offered_at": GameState.minute,
		"expires_at": GameState.minute + 10,
		"ready_at": GameState.minute,
		"deadline": GameState.minute + 120,
		"sign_name": "",
		"status": "offered",
	}
	o.merge(extra, true)
	GameState.next_order_id += 1
	GameState.orders.append(o)
	return o


func _first(type: String) -> int:
	return CityGen.nodes_of_type(City.get_city(), type)[0]["id"]


func test_offers_appear_and_expire():
	GameState.orders.clear()
	Orders._next_offer_at = 0.0
	Orders.tick(GameState.minute)
	assert_eq(Orders.offers().size(), 1, "first offer straight away")
	var o: Dictionary = Orders.offers()[0]
	GameState.advance_minutes(float(o["expires_at"]) - GameState.minute + 1.0)
	assert_true(Orders.get_order(int(o["id"])).is_empty() or o["status"] != "offered")


func test_full_food_delivery_pays_and_rates():
	var here := GameState.location
	var condo := _first("house")  # condo residents wait upstairs (P1)
	var o := _order("food", here, condo, {"ready_at": GameState.minute + 5})
	assert_true(Orders.accept(int(o["id"])))
	assert_eq(GameState.acceptance(), 1.0)
	assert_true(Orders.on_interact("merchant"), "merchant hands over the food")
	assert_eq(o["status"], "picked")
	assert_gte(GameState.minute, float(o["ready_at"]), "waited for the kitchen")
	TestHelpers.finish_dialog()
	var fuel := GameState.fuel
	assert_true(City.travel(condo))
	await wait_seconds(0.8)
	assert_eq(GameState.location, condo)
	assert_lt(GameState.fuel, fuel, "riding burns fuel")
	var room: IsoRoom = get_tree().get_first_node_in_group("player").get_parent().get_parent()
	assert_not_null(
		room.get_world().get_node_or_null("Customer%d" % int(o["id"])), "customer waits"
	)
	var money := GameState.money
	var n := GameState.ratings.size()
	assert_true(Orders.on_interact("customer_%d" % int(o["id"])))
	assert_eq(GameState.money, money + 50)
	assert_eq(GameState.ratings.size(), n + 1)
	assert_true(Orders.active().is_empty())


func test_bag_space_and_cod():
	var here := GameState.location
	var house := _first("house")
	var big := _order("parcel", here, house, {"size": 2, "cod": 200})
	var big2 := _order("parcel", here, house, {"size": 2})
	assert_true(Orders.accept(int(big["id"])))
	assert_false(Orders.accept(int(big2["id"])), "bag full (2+2 > 3)")
	var money := GameState.money
	Orders.on_interact("merchant")
	assert_eq(GameState.money, money - 200, "rider pays COD up front")
	GameState.location = house
	Orders.on_interact("customer_%d" % int(big["id"]))
	assert_eq(GameState.money, money - 200 + 200 + 50, "COD back + fee")


func test_cold_and_late_food_cost_stars():
	var here := GameState.location
	var o := _order("food", here, _first("house"), {"deadline": GameState.minute + 10})
	Orders.accept(int(o["id"]))
	Orders.on_interact("merchant")
	GameState.advance_minutes(90)
	GameState.location = int(o["dropoff"])
	Orders.rng.seed = 2
	var stars := []
	Orders.delivered.connect(func(_o, s, _r): stars.append(s))
	Orders.on_interact("customer_%d" % int(o["id"]))
	assert_lte(stars[0], 2)


func test_rain_floods_roads_and_slows_riding():
	var dry := City.route_to(_first("house"))
	City._forecast = {"showers": [[GameState.DAY_START - 60, GameState.DAY_START + 300, true]]}
	City._forecast_day = GameState.day
	assert_eq(City.rain_now(), Weather.HEAVY)
	assert_false(City.water_now().is_empty(), "heavy rain floods the flood-prone roads")
	var wet := City.route_to(_first("house"))
	if not wet.is_empty():
		assert_gt(wet["minutes"], dry["minutes"])


func test_sleep_charges_rent_and_interest_and_fails_open_orders():
	var o := _order("food", GameState.location, _first("house"))
	Orders.accept(int(o["id"]))
	GameState.money = 1000
	var n := GameState.ratings.size()
	_main.sleep()
	assert_eq(GameState.day, 2)
	assert_eq(GameState.minute, float(GameState.DAY_START))
	assert_eq(GameState.money, 1000 - GameState.BIKE_RENT - GameState.DEBT_INTEREST)
	assert_eq(GameState.ratings.size(), n + 1, "undelivered order = 1 star")
	assert_true(Orders.active().is_empty(), "yesterday's orders are gone")


func test_three_unpaid_mornings_lose_the_bike():
	GameState.money = 0
	for i in 3:
		GameState.start_new_day()
	assert_eq(GameState.check_game_over(), "lose_bike")


func test_low_rating_suspends_account():
	for i in 40:
		GameState.add_rating(1)
	assert_eq(GameState.check_game_over(), "suspended")


func test_debt_payment_and_last_day_ending():
	GameState.money = 5000
	GameState.pay_debt(GameState.debt)
	assert_eq(GameState.debt, 0)
	GameState.day = GameState.LAST_DAY
	_main.sleep()
	assert_eq(GameState.finished, "paid_off")


func test_refuel_at_gas_station():
	GameState.fuel = 1.0
	var money := GameState.money
	var paid := GameState.refuel()
	assert_gt(paid, 0)
	assert_eq(GameState.money, money - paid)
	assert_almost_eq(GameState.fuel, GameState.FUEL_TANK, 0.05)
