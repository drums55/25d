extends GutTest
## ย่านส่งไว: the fixed hand-made district, its residents, and the little
## item quests whose rewards feed back into the rider's day.

var _main: Node


func before_each():
	TestHelpers.start_at("restaurant")
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)


func after_each():
	TestHelpers.finish_dialog()
	GameState.riding = false
	Settings.skip_ride = true
	GameState.delete_save(0)
	GameState.new_game()


func _talk(id: String) -> void:
	assert_true(Dialog.start(id), "dialog %s starts" % id)
	TestHelpers.finish_dialog()


func _go(key: String) -> LocationRoom:
	GameState.location = District.id_of(key)
	_main.load_room(GameState.LOCATION_SCENE, "arrival")
	await wait_physics_frames(3)
	return get_tree().get_first_node_in_group("player").get_parent().get_parent()


func test_district_is_fixed_and_connected():
	var a := District.city(1)
	var b := District.city(999)
	assert_eq(a["nodes"].size(), b["nodes"].size())
	assert_eq(a["edges"], b["edges"], "same map every game")
	for type in CityGen.TYPES:
		assert_false(CityGen.nodes_of_type(a, type).is_empty(), "has a %s" % type)
	for n in a["nodes"]:
		if n["id"] != 0:
			assert_false(CityGen.route(a, 0, n["id"], {}).is_empty(), "%s reachable" % n["name"])


func test_every_room_dialog_and_item_exists():
	var data := DialogData.load_file(Dialog.DIALOG_PATH)
	for key in PlaceRooms.ROOMS:
		var t := LocationTemplates.for_place({"key": key, "type": _type_of(key)})
		var ids: Array = []
		for p in t.get("props", []) + t.get("extras", []):
			if p.has("dialog"):
				ids.append(p["dialog"])
		for r in t.get("npcs", []):
			ids.append(r["dialog"])
		if t.has("merchant"):
			ids.append(t["merchant"].get("dialog", ""))
		for id in ids:
			assert_true(data.has(id), "%s: dialog %s exists" % [key, id])
	var text := FileAccess.get_file_as_string(Dialog.DIALOG_PATH)
	for item in GameState.ITEMS:
		assert_string_contains(text, '"%s"' % item, false)


func _type_of(key: String) -> String:
	return District.PLACES[District.id_of(key)]["type"]


func test_residents_stand_in_their_rooms():
	var room: LocationRoom = await _go("rom_yen")
	assert_not_null(room.get_world().get_node_or_null("Resident0"), "ป้าจุ๋ม is home")


func test_moo_ping_feeds_the_cat_for_a_forgotten_tip():
	_talk("talk_moo_ping")
	assert_true(GameState.has_item("moo_ping"))
	assert_eq(GameState.money, GameState.START_MONEY - 10)
	_talk("talk_somo")
	assert_true(GameState.has_flag("cat_fed"))
	assert_false(GameState.has_item("moo_ping"))
	assert_eq(GameState.money, GameState.START_MONEY - 10 + 100)


func test_lottery_makes_aunt_jum_reveal_wrong_pins():
	_talk("talk_lek")
	assert_true(GameState.has_item("lottery_69"))
	_talk("talk_jum")
	assert_true(GameState.has_flag("aunt_jum"))
	var pinned := District.id_of("rom_yen")
	var o := {
		"id": 77,
		"kind": "parcel",
		"item": "กล่อง",
		"pickup": 0,
		"dropoff": pinned,
		"true_dropoff": District.id_of("suk_san"),
		"pin_wrong": true,
		"customer": "คุณบี",
		"fee": 40,
		"tip": 0,
		"cod": 0,
		"size": 1,
		"ready_at": GameState.minute,
		"deadline": GameState.minute + 300,
		"status": "picked",
	}
	GameState.orders.append(o)
	var room: LocationRoom = await _go("rom_yen")
	assert_true(o.get("pin_found", false), "ป้าจุ๋ม sent a LINE")
	assert_null(room.get_world().get_node_or_null("Local77"), "no need to ask around")


func test_iced_coffee_befriends_the_condo_guard():
	_talk("talk_coffee_machine")
	assert_true(GameState.has_item("iced_coffee"))
	_talk("talk_sompong")
	assert_true(GameState.has_flag("guard_friend"))
	var room: LocationRoom = await _go("river_view")
	assert_null(room.get_world().get_node_or_null("LiftGuard"), "the lift guard 'sleeps'")


func test_fed_dog_means_soi_dogs_stop_chasing_on_rides():
	GameState.give_item("moo_ping")
	_talk("talk_khaotang")
	assert_true(GameState.has_flag("dog_friend"))
	Settings.skip_ride = false
	assert_true(City.travel(District.id_of("samakkhi")))
	await wait_seconds(0.8)
	var ride: RideScene = get_tree().get_first_node_in_group("ride")
	ride.track["obstacles"] = [{"kind": "dog", "x": 3.0, "lane": 0, "branch": ""}]
	for i in 80:
		ride.step(0.05)
	assert_does_not_have(ride.hits, "dog")
	assert_eq(ride.steadiness, 100.0)


func test_sauce_packs_win_a_daily_free_meal():
	_talk("talk_lung_table3")
	assert_true(GameState.has_item("sauce_packs"))
	_talk("talk_pa_nok")
	assert_true(GameState.has_flag("nok_friend"))
	GameState.fatigue = 60.0
	_talk("talk_pa_nok")
	assert_lt(GameState.fatigue, 40.0, "a bowl a day")
	var f := GameState.fatigue
	_talk("talk_pa_nok")
	assert_eq(GameState.fatigue, f, "only once a day")


func test_queue_ticket_to_umbrella_to_lobby_nap():
	_talk("talk_khet_queue")
	assert_true(GameState.has_item("queue_ticket"))
	_talk("talk_tonkla")
	assert_true(GameState.has_item("lost_umbrella"))
	_talk("talk_niti")
	assert_true(GameState.has_flag("niti_friend"))
	GameState.fatigue = 50.0
	_talk("talk_sofa")
	assert_lt(GameState.fatigue, 40.0)


func test_win_rider_tells_tomorrows_policy():
	var room: LocationRoom = await _go("pailin")
	var toi := room.get_world().get_node("Resident0").get_node("Interactable") as Interactable
	toi.interact(get_tree().get_first_node_in_group("player"))
	assert_true(Dialog.is_active())
