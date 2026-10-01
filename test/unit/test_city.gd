extends GutTest
## Random city (CityGen), rain + floods (Weather), orders (OrderGen).


func test_city_is_deterministic_connected_and_has_every_type():
	var a := CityGen.generate(1234)
	var b := CityGen.generate(1234)
	assert_eq(a["nodes"].size(), CityGen.NODE_COUNT)
	for i in a["nodes"].size():
		assert_eq(a["nodes"][i]["name"], b["nodes"][i]["name"], "same seed same city")
	for t in CityGen.MIN_COUNT:
		assert_gte(CityGen.nodes_of_type(a, t).size(), int(CityGen.MIN_COUNT[t]), t)
	for to in a["nodes"].size():
		assert_false(CityGen.route(a, 0, to).is_empty(), "dry city connected to %d" % to)
	assert_ne(
		CityGen.generate(99)["nodes"][0]["name"] + CityGen.generate(98)["nodes"][1]["name"],
		a["nodes"][0]["name"] + a["nodes"][1]["name"],
		"different seeds differ"
	)


func test_route_avoids_deep_water_and_wades_shallow():
	var city := CityGen.generate(7)
	var r := CityGen.route(city, 0, 5)
	assert_false(r.is_empty())
	assert_eq(r["path"][0], 0)
	assert_eq(r["path"][-1], 5)
	var first_edge: int = r["edges"][0]
	var closed := CityGen.route(city, 0, 5, {first_edge: 2})
	if not closed.is_empty():
		assert_does_not_have(closed["edges"], first_edge, "deep road is closed")
	var wet := CityGen.route(city, 0, 5, {first_edge: 1}, 1.0, true)
	if not wet.is_empty() and wet["edges"].has(first_edge):
		assert_true(wet["wade"])
	var slow := CityGen.route(city, 0, 5, {}, 1.5)
	assert_gt(slow["minutes"], r["minutes"], "rain slows riding")


func test_weather_floods_after_heavy_rain_and_drains():
	var fc := {"showers": [[600, 660, true]]}
	assert_eq(Weather.rain_at(fc, 590), Weather.NONE)
	assert_eq(Weather.rain_at(fc, 620), Weather.HEAVY)
	assert_eq(Weather.water_level(fc, 610), 0, "not yet")
	assert_eq(Weather.water_level(fc, 650), 2, "40 heavy minutes = deep")
	assert_eq(Weather.water_level(fc, 900), 0, "drained")
	var city := {"edges": [{"flood": 0}, {"flood": 1}, {"flood": 2}]}
	var levels := Weather.edge_levels(city, fc, 650)
	assert_false(levels.has(0))
	assert_eq(levels[1], 1)
	assert_eq(levels[2], 2)
	var fc2 := Weather.forecast(5, 3)
	assert_eq(fc2, Weather.forecast(5, 3), "forecast deterministic")


func test_orders_by_kind():
	var city := CityGen.generate(42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var kinds := {}
	for i in 60:
		var o := OrderGen.make(rng, city, 600, 0, i)
		kinds[o["kind"]] = true
		assert_ne(o["pickup"], o["dropoff"])
		assert_gt(o["fee"], 0)
		assert_gt(o["expires_at"], 600)
		if o["kind"] == "doc":
			assert_false(o["sign_name"].is_empty())
		if o["kind"] == "food":
			assert_gte(o["ready_at"], 600.0)
	assert_eq(kinds.size(), 3, "food, parcel and documents all appear")
	var rain := OrderGen.make(rng, city, 600, 1, 99)
	assert_gt(rain["fee"], OrderGen.BASE_FEE[rain["kind"]], "rain surge")


func test_food_cools_and_late_costs_stars():
	var o := {"kind": "food", "ready_at": 600.0, "deadline": 640.0}
	assert_eq(OrderGen.heat(o, 610), 2)
	assert_eq(OrderGen.heat(o, 635), 1)
	assert_eq(OrderGen.heat(o, 660), 0)
	var rng := RandomNumberGenerator.new()
	var on_time := 0
	var late := 0
	for i in 50:
		rng.seed = i
		on_time += OrderGen.rate(rng, o, 615)["stars"]
		rng.seed = i
		late += OrderGen.rate(rng, o, 700)["stars"]
	assert_gt(on_time, late)


func test_deadline_covers_the_real_ride():
	var o := {"kind": "food", "ready_at": 610.0}
	OrderGen.set_deadline(o, 600.0, 20.0, 30.0)
	assert_almost_eq(
		float(o["deadline"]), 600.0 + 22.0 + 37.5 + 15.0, 1.0, "pickup ride + trip + slack"
	)
	var p := {"kind": "parcel", "ready_at": 600.0}
	OrderGen.set_deadline(p, 600.0, 10.0, 20.0)
	assert_gt(p["deadline"], o["deadline"], "parcels are relaxed")
