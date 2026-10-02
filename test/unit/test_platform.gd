extends GutTest
## P2 "แพลตฟอร์มโหด": daily policy, teasing incentive, forced job pairs,
## suspension + appeal, fatigue, accidents.

var _main: Node


func before_each():
	TestHelpers.start_at("restaurant")
	Orders.rng.seed = 3
	City.rng.seed = 3
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)


func after_each():
	TestHelpers.finish_dialog()
	GameState.riding = false
	Settings.skip_ride = true
	GameState.delete_save(0)
	GameState.new_game()


func _first(type: String) -> int:
	return CityGen.nodes_of_type(City.get_city(), type)[0]["id"]


func _picked(dropoff: int) -> Dictionary:
	var o := {
		"id": GameState.next_order_id,
		"kind": "parcel",
		"item": "กล่อง",
		"pickup": GameState.location,
		"dropoff": dropoff,
		"customer": "คุณบี",
		"fee": 50,
		"tip": 0,
		"cod": 0,
		"size": 1,
		"ready_at": GameState.minute,
		"deadline": GameState.minute + 300,
		"status": "picked",
	}
	GameState.next_order_id += 1
	GameState.orders.append(o)
	return o


func test_policy_is_per_day_and_never_repeats():
	var a := PlatformPolicy.for_day(99, 3)
	assert_eq(a, PlatformPolicy.for_day(99, 3), "deterministic")
	assert_eq(PlatformPolicy.for_day(99, 1)["id"], "welcome")
	var seen := {}
	for d in range(2, GameState.LAST_DAY + 1):
		var p := PlatformPolicy.for_day(99, d)
		assert_false(seen.has(p["id"]), "day %d repeats %s" % [d, p["id"]])
		seen[p["id"]] = true
		assert_gt(int(p["target"]), 3)
		assert_gt(int(p["reward"]), 0)


func test_policy_changes_the_fee():
	var city := City.get_city()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var plain := OrderGen.make(rng, city, 600.0, 0, 1)
	rng.seed = 1
	var cut := OrderGen.make(rng, city, 600.0, 0, 1, {"fee_delta": -6})
	assert_eq(int(cut["fee"]), int(plain["fee"]) - 6)


func test_bundle_is_accepted_and_declined_together():
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var city := City.get_city()
	var a := OrderGen.make(rng, city, GameState.minute, 0, 500)
	a["size"] = 1
	var b := OrderGen.make_bundle(rng, city, a, 501)
	assert_eq(b["pickup"], a["pickup"])
	assert_eq(int(a["bundle"]), 500)
	assert_eq(int(b["bundle"]), 500)
	assert_eq(int(b["fee"]), OrderGen.BUNDLE_FEE)
	GameState.orders.append(a)
	GameState.orders.append(b)
	assert_eq(Orders.offer_groups(), 1, "a pair counts as one offer")
	assert_true(Orders.accept(500))
	assert_eq(Orders.get_order(501)["status"], "accepted", "the pair comes along")
	GameState.orders.clear()
	a["status"] = "offered"
	b["status"] = "offered"
	GameState.orders.append(a)
	GameState.orders.append(b)
	Orders.decline(501)
	assert_true(GameState.orders.is_empty(), "declining one drops both")


func test_incentive_pays_and_teases_one_short():
	var p := Orders.policy()
	var target := int(p["target"])
	GameState.log_today["delivered"] = target - 1
	assert_true(Orders.teasing(), "one short = the app goes quiet")
	GameState.orders.clear()
	Orders.tick(GameState.minute)
	assert_gte(Orders._next_offer_at - GameState.minute, 3.0 * PlatformPolicy.TEASE_GAP)
	GameState.orders.clear()
	var home := _first("house")
	var o := _picked(home)
	GameState.location = home
	var before := GameState.money
	assert_true(Orders.on_interact("customer_%d" % int(o["id"])))
	assert_true(Orders.quest_paid())
	assert_eq(GameState.money, before + 50 + int(p["reward"]))
	assert_false(Orders.teasing())


func test_suspension_clears_jobs_and_unlocks_next_morning():
	GameState.orders.clear()
	Orders.tick(GameState.minute)
	var bag := _picked(_first("house"))
	for i in 40:
		GameState.add_rating(1)
	GameState.check_game_over()
	assert_true(GameState.suspended)
	assert_eq(GameState.orders, [bag], "offers go to other riders, the bag stays")
	Orders._next_offer_at = 0.0
	Orders.tick(GameState.minute)
	assert_eq(Orders.offers().size(), 0, "no offers while suspended")
	GameState.money = 1000
	var charges := GameState.start_new_day()
	assert_false(GameState.suspended)
	assert_eq(int(charges["unlock"]), GameState.UNLOCK_FEE)
	assert_gte(GameState.rating(), GameState.MIN_RATING)


func test_suspension_appeal_can_reinstate():
	for i in 40:
		GameState.add_rating(1)
	GameState.check_game_over()
	var chat := AppealChat.new({"kind": "suspension"})
	add_child_autofree(chat)
	assert_true(GameState.suspension_appealed, "one try per suspension")
	var t := GameState.minute
	chat._evidence(1.0)
	assert_false(GameState.suspended)
	assert_gte(GameState.minute, t + AppealChat.TRAINING_MINUTES)


func test_fatigue_builds_and_sleep_or_coffee_helps():
	GameState.advance_minutes(600)
	assert_gt(GameState.fatigue, 25.0)
	var f := GameState.fatigue
	var money := GameState.money
	assert_true(GameState.drink_coffee())
	assert_lt(GameState.fatigue, f)
	assert_eq(GameState.money, money - GameState.COFFEE_PRICE)
	assert_eq(GameState.sleep_hours(23 * 60), 8.0)
	assert_eq(GameState.sleep_hours(26 * 60), 5.0)
	GameState.minute = 23 * 60
	GameState.start_new_day()
	assert_eq(GameState.fatigue, 0.0, "a full night clears it")


func test_accident_bills_the_rider_and_borrows_the_rest():
	assert_gt(City.accident_chance(90.0, 1), City.accident_chance(0.0, 0))
	GameState.money = 100
	var debt := GameState.debt
	var t := GameState.minute
	var cost := City.accident()
	assert_eq(GameState.money, 0)
	assert_eq(GameState.debt, debt + cost - 100, "the loan shark pays the clinic")
	assert_gte(GameState.minute, t + City.CLINIC_MINUTES)


func test_tired_rider_steers_slow_and_nods_off():
	assert_eq(RideScene.steer_factor(0.0), 1.0)
	assert_lt(RideScene.steer_factor(100.0), 0.7)
	Settings.skip_ride = false
	GameState.fatigue = 95.0
	assert_true(City.travel(_first("condo")))
	await wait_seconds(0.8)
	var ride: RideScene = get_tree().get_first_node_in_group("ride")
	ride.track["obstacles"] = []
	ride.track["fork"] = {}
	var lanes := {}
	for i in 200:
		ride.step(0.05)
		lanes[ride.target_lane] = true
	assert_gt(lanes.size(), 1, "the bike drifted lanes without input")
	GameState.riding = false


func test_selfie_day_locks_offers_until_selfie():
	var day := -1
	for d in range(2, GameState.LAST_DAY + 1):
		if PlatformPolicy.for_day(GameState.city_seed, d)["id"] == "selfie":
			day = d
	if day < 0:
		pass_test("no selfie day in this city")
		return
	GameState.day = day
	GameState.minute = GameState.selfie_due
	GameState.orders.clear()
	assert_true(Orders.selfie_needed())
	Orders.tick(GameState.minute)
	assert_eq(Orders.offers().size(), 0)
	for i in 10:
		if Orders.take_selfie():
			break
	assert_false(Orders.selfie_needed())


func test_new_state_survives_save():
	GameState.fatigue = 42.0
	GameState.suspended = true
	GameState.suspensions = 1
	var snap: Dictionary = JSON.parse_string(JSON.stringify(GameState.snapshot()))
	GameState.new_game()
	GameState.restore(snap)
	assert_eq(GameState.fatigue, 42.0)
	assert_true(GameState.suspended)
	assert_eq(GameState.suspensions, 1)
