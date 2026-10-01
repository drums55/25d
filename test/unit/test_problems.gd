extends GutTest
## P1 rider problems: wrong pin, COD no-show, cancel after pickup, condo
## guard + lift, debt collector, appealing an unfair 1-star review.

var _main: Node


func before_each():
	TestHelpers.start_at("restaurant")
	Orders.rng.seed = 7
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)


func after_each():
	TestHelpers.finish_dialog()
	LocationRoom.allow_collector = false
	GameState.delete_save(0)
	GameState.new_game()


func _first(type: String, n := 0) -> int:
	return CityGen.nodes_of_type(City.get_city(), type)[n]["id"]


func _picked(extra := {}) -> Dictionary:
	var o := {
		"id": GameState.next_order_id,
		"kind": "parcel",
		"item": "กล่อง",
		"pickup": GameState.location,
		"dropoff": _first("house"),
		"customer": "คุณบี",
		"fee": 50,
		"tip": 0,
		"cod": 0,
		"size": 1,
		"ready_at": GameState.minute,
		"deadline": GameState.minute + 300,
		"status": "picked",
	}
	o.merge(extra, true)
	GameState.next_order_id += 1
	GameState.orders.append(o)
	return o


func _go(node_id: int) -> LocationRoom:
	GameState.location = node_id
	_main.load_room(GameState.LOCATION_SCENE, "arrival")
	await wait_physics_frames(3)
	return get_tree().get_first_node_in_group("player").get_parent().get_parent()


func test_wrong_pin_local_points_to_the_real_place():
	var pinned := _first("house")
	var real := _first("condo")
	var o := _picked({"dropoff": pinned, "pin_wrong": true, "true_dropoff": real})
	assert_eq(Orders.shown_dropoff(o), pinned, "app shows the wrong pin")
	var room := await _go(pinned)
	assert_null(room.get_world().get_node_or_null("Customer%d" % o["id"]), "nobody at the pin")
	assert_not_null(room.get_world().get_node_or_null("Local%d" % o["id"]), "a local to ask")
	assert_false(Orders.on_interact("customer_%d" % o["id"]), "cannot deliver at the pin")
	assert_true(Orders.on_interact("local_%d" % o["id"]))
	assert_true(o["pin_found"])
	assert_eq(Orders.shown_dropoff(o), real)


func test_calling_can_fix_the_pin():
	var o := _picked({"pin_wrong": true, "true_dropoff": _first("house", 1)})
	for i in 10:
		Orders.call_customer(int(o["id"]))
		if o.get("pin_found", false):
			break
	assert_true(o.get("pin_found", false), "someone answers eventually")


func test_no_show_door_wait_or_return_with_half_refund():
	var house := _first("house")
	var o := _picked({"dropoff": house, "cod": 400, "no_show": true})
	var room := await _go(house)
	assert_null(room.get_world().get_node_or_null("Customer%d" % o["id"]))
	assert_not_null(room.get_world().get_node_or_null("Door%d" % o["id"]), "a door to ring")
	Orders.return_parcel(int(o["id"]))
	assert_true(Orders.get_order(int(o["id"])).is_empty())
	assert_eq(GameState.pending_refund, 200)
	GameState.money = 1000
	GameState.start_new_day()
	assert_eq(
		GameState.money,
		1000 + 200 - GameState.BIKE_RENT - GameState.DEBT_INTEREST,
		"half the COD comes back next morning"
	)


func test_cash_food_cancelled_after_pickup_loses_the_money():
	var o := _picked({"kind": "food", "cod": 150, "will_cancel": true})
	Orders.check_cancellations()
	assert_true(Orders.get_order(int(o["id"])).is_empty(), "order gone")
	assert_eq(int(GameState.log_today.get("cod_lost", 0)), 150)


func test_condo_guard_calls_residents_down():
	var condo := _first("condo")
	var o := _picked({"dropoff": condo})
	var room := await _go(condo)
	assert_null(room.get_world().get_node_or_null("Customer%d" % o["id"]), "residents stay up")
	var minute := GameState.minute
	assert_true(Orders.on_interact("merchant"), "guard phones up")
	assert_true(o["called_down"])
	assert_gt(GameState.minute, minute, "waiting takes time")
	await wait_seconds(0.5)
	TestHelpers.finish_dialog()
	room = get_tree().get_first_node_in_group("player").get_parent().get_parent()
	assert_not_null(room.get_world().get_node_or_null("Customer%d" % o["id"]), "came down")


func test_sneaking_the_lift():
	var condo := _first("condo")
	var o := _picked({"dropoff": condo})
	await _go(condo)
	var minute := GameState.minute
	Orders.sneak_lift(true)
	assert_false(Orders.get_order(int(o["id"])).is_empty(), "caught: not delivered")
	assert_gte(GameState.minute, minute + 3.0)
	TestHelpers.finish_dialog()
	var money := GameState.money
	Orders.sneak_lift(false)
	assert_true(Orders.get_order(int(o["id"])).is_empty(), "delivered at the door")
	assert_gte(GameState.money, money + 50 + 10, "fee + door tip (if the review allows)")


func test_condo_has_a_lift_guard_watching():
	var room := await _go(_first("condo"))
	var guard := room.get_world().get_node_or_null("LiftGuard") as PatrolBot
	assert_not_null(guard)
	assert_false(guard.chases, "only stares")
	assert_true(guard.is_in_group("guard"))


func test_debt_collector_takes_cash():
	GameState.money = 500
	GameState.missed_payments = 1
	LocationRoom.allow_collector = true
	var room := await _go(_first("market"))
	if room.get_world().get_node_or_null("Collector") == null:
		room._add_collector(room.get_world(), LocationTemplates.get_template("market"))
	var c := room.get_world().get_node("Collector") as PatrolBot
	var player := get_tree().get_first_node_in_group("player") as Node2D
	c.patrol = PackedVector2Array()
	c.facing = Vector2(-1, 1).normalized()  # ground space: toward +gy
	player.global_position = c.global_position + Iso.grid_to_world(Vector2(0.0, 1.6))
	for i in 90:
		await wait_physics_frames(1)
		if GameState.money < 500:
			break
	assert_lt(GameState.money, 500, "collector took money")
	assert_eq(GameState.missed_payments, 0, "counts as a payment")


func test_appeal_chat():
	GameState.add_rating(1)
	var a := {
		"id": 1,
		"item": "ข้าว",
		"review": "ไรเดอร์หน้าไม่ยิ้ม",
		"index": GameState.ratings.size() - 1,
		"open": true
	}
	GameState.appeals.append(a)
	var chat := AppealChat.new(a)
	add_child_autofree(chat)
	chat.chance = 1.0
	chat._explain()
	chat._evidence(0.0)
	assert_eq(int(GameState.ratings[a["index"]]), 5, "review removed")
	assert_false(a["open"])
	var b := {"id": 2, "item": "ข้าว", "review": "x", "index": 0, "open": true}
	var chat2 := AppealChat.new(b)
	add_child_autofree(chat2)
	chat2._give_up()
	assert_false(b["open"])
