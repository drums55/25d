extends GutTest
## The playable ride between places: track generation, lanes, hits, fork,
## clock, arrival and spills.

var _main: Node


func before_each():
	TestHelpers.start_at("restaurant")
	Settings.skip_ride = false
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)


func after_each():
	Settings.skip_ride = true
	GameState.riding = false
	TestHelpers.finish_dialog()
	GameState.delete_save(0)
	GameState.new_game()


func _segments() -> Array:
	return [{"kind": "main", "km": 2.0, "water": 0}, {"kind": "soi", "km": 1.0, "water": 1}]


func test_track_is_deterministic_and_never_blocks_all_lanes():
	var a := RideTrack.generate(5, _segments(), 20.0, 1)
	var b := RideTrack.generate(5, _segments(), 20.0, 1)
	assert_eq(a["obstacles"].size(), b["obstacles"].size())
	assert_gt(a["obstacles"].size(), 5)
	assert_false(a["fork"].is_empty(), "long rides have a fork")
	assert_lt(a["length"]["A"], a["length"]["B"], "the soi shortcut is shorter")
	# group by x: at most two lanes blocked by solid things at the same spot
	var by_x := {}
	for o in a["obstacles"]:
		if o.get("all_lanes", false):
			continue
		var key := "%s@%d" % [o["branch"], int(o["x"])]
		by_x[key] = by_x.get(key, 0) + 1
	for k in by_x:
		assert_lte(by_x[k], 2, "lane left free at %s" % k)


func test_hits_need_same_lane_and_overlap():
	var o := {"kind": "pothole", "x": 10.0, "lane": 0, "branch": ""}
	assert_true(RideTrack.hits(o, 0.0, 9.8, 0.0))
	assert_false(RideTrack.hits(o, 0.0, 9.8, 1.0), "other lane")
	assert_false(RideTrack.hits(o, 0.0, 5.0, 0.0), "not there yet")
	var car := {"kind": "car", "x": 10.0, "lane": 1, "branch": ""}
	assert_gt(RideTrack.obstacle_pos(car, 2.0).x, 10.0, "cars drive forward")


func _start_ride() -> RideScene:
	var dest: int = CityGen.nodes_of_type(City.get_city(), "condo")[0]["id"]
	assert_true(City.travel(dest))
	await wait_seconds(0.8)
	return get_tree().get_first_node_in_group("ride") as RideScene


func test_travel_starts_a_ride_and_arrives():
	var o := {
		"id": 900,
		"kind": "food",
		"item": "ข้าว",
		"status": "picked",
		"size": 1,
		"pickup": GameState.location,
		"dropoff": 0,
		"ready_at": GameState.minute,
		"deadline": GameState.minute + 200,
		"fee": 30,
		"tip": 0,
		"cod": 0,
		"customer": "คุณบี",
	}
	GameState.orders.append(o)
	var ride := await _start_ride()
	assert_not_null(ride, "ride scene loaded")
	assert_true(GameState.riding)
	var minute := GameState.minute
	var fuel := GameState.fuel
	# smooth ride: clear the obstacles out of the way and drive to the end
	ride.track["obstacles"] = []
	for i in 2000:
		if ride.done:
			break
		ride.step(0.05)
	assert_true(ride.done)
	assert_gt(GameState.minute, minute, "time passed on the road")
	await wait_seconds(0.8)
	assert_false(GameState.riding)
	assert_lt(GameState.fuel, fuel)
	var dest: int = CityGen.nodes_of_type(City.get_city(), "condo")[0]["id"]
	assert_eq(GameState.location, dest)
	assert_false(o.get("spilled", false), "steady ride keeps the soup in the box")


func test_crash_stops_and_shakes_the_food():
	var ride := await _start_ride()
	ride.track["obstacles"] = [{"kind": "car", "x": 3.0, "lane": 0, "branch": ""}]
	for i in 80:
		ride.step(0.05)
	assert_has(ride.hits, "crash")
	assert_lt(ride.steadiness, 70.0)
	assert_gte(ride.delay_minutes, 3.0)
	GameState.riding = false


func test_changing_lane_dodges():
	var ride := await _start_ride()
	ride.track["obstacles"] = [{"kind": "pothole", "x": 4.0, "lane": 0, "branch": ""}]
	ride.steer(1)
	for i in 80:
		ride.step(0.05)
	assert_does_not_have(ride.hits, "bump", "dodged into the right lane")
	assert_eq(ride.target_lane, 1)


func test_fork_picks_branch_by_lane():
	var ride := await _start_ride()
	ride.track["obstacles"] = []
	ride.track["fork"] = {"x": 15.0, "A": {"label": "a"}, "B": {"label": "b"}}
	ride.track["length"] = {"": 80.0, "A": 40.0, "B": 80.0}
	ride.steer(-1)
	for i in 80:
		ride.step(0.05)
	assert_eq(ride.branch, "A", "left lane at the sign = soi shortcut")
	assert_eq(ride.end_x(), 40.0)


func test_low_steadiness_spills_food_on_arrival():
	var o := {
		"id": 901,
		"kind": "food",
		"item": "ซุป",
		"status": "picked",
		"size": 1,
		"pickup": 0,
		"dropoff": 0,
		"ready_at": GameState.minute,
		"deadline": GameState.minute + 200,
		"fee": 30,
		"tip": 0,
		"cod": 0,
		"customer": "คุณบี",
	}
	GameState.orders.append(o)
	var ride := await _start_ride()
	ride.track["obstacles"] = []
	ride.steadiness = 20.0
	for i in 2000:
		if ride.done:
			break
		ride.step(0.05)
	assert_true(o.get("spilled", false))
	await wait_seconds(0.8)
