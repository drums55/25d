extends GutTest
## Bag, using and combining things (DESIGN 11.5), the puzzle data's integrity,
## travel, the tide, hints, and a walkthrough of all of chapter 1:
## home -> pier -> noodle boat -> stilts -> boat garage -> old gate -> station.

var _main: Node
var _player: Player
var _hud: Hud


func before_each():
	TestHelpers.start_in("home")
	Settings.skip_ride = true
	Puzzles.rng.seed = 1
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)
	_player = get_tree().get_first_node_in_group("player")
	_hud = get_tree().get_first_node_in_group("hud")


func after_each():
	Settings.skip_ride = false
	TestHelpers.finish_dialog()
	_hud.hide_overlay()
	GameState.delete_save(0)
	GameState.new_game()


func _room() -> AdventureRoom:
	return _player.get_parent().get_parent() as AdventureRoom


## The Interactable of the room thing with this thing_id (prop, person, item).
func _thing(id: String) -> Interactable:
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Interactable and n.thing_id == id and n.is_inside_tree():
			return n
	return null


func _tap(id: String) -> void:
	var t := _thing(id)
	assert_not_null(t, "thing %s is in the room" % id)
	if t:
		t.interact(_player)
	TestHelpers.finish_dialog()


func _go(room: String, spawn := "default") -> void:
	_main.go_room(room, spawn)
	await wait_seconds(0.8)
	assert_eq(_room().room_id, room)


func _all_lines() -> Array:
	var out: Array = []
	var dlg := DialogData.load_file(Dialog.DIALOG_PATH)
	for id in dlg:
		var e = dlg[id]
		out.append_array(e if e is Array else e.get("lines", []))
	for u in Puzzles.data["uses"] + Puzzles.data["combos"]:
		out.append_array(u.get("lines", []))
	return out


func test_every_item_reference_is_known_and_obtainable():
	var items: Dictionary = Puzzles.data["items"]
	var obtainable := {}
	for i in GameState.START_ITEMS:
		obtainable[i] = true
	for id in Rooms.ROOMS:
		for p in Rooms.ROOMS[id].get("pickups", []):
			obtainable[p["item"]] = true
	for c in Puzzles.data["combos"]:
		obtainable[c["result"]] = true
	for line in _all_lines():
		if line is Dictionary and not str(line.get("give_item", "")).is_empty():
			obtainable[line["give_item"]] = true
	for i in obtainable:
		assert_true(items.has(i), "item %s has a name/desc" % i)
	for u in Puzzles.data["uses"]:
		assert_true(obtainable.has(u["item"]), "used item %s can be found" % u["item"])
	for c in Puzzles.data["combos"]:
		assert_true(obtainable.has(c["a"]) and obtainable.has(c["b"]), "combo %s" % c["result"])


func test_every_use_target_and_dialog_exists_in_a_room():
	var things := {}
	for id in Rooms.ROOMS:
		var r: Dictionary = Rooms.ROOMS[id]
		for p in r.get("props", []):
			things[p["id"]] = true
			for key in ["dialog", "locked_dialog"]:
				if p.has(key):
					assert_true(Dialog.has_dialog(p[key]), "%s: %s" % [id, p[key]])
		for n in r.get("npcs", []):
			things[n["id"]] = true
			assert_true(Dialog.has_dialog(n["dialog"]), "%s: %s" % [id, n["dialog"]])
		for b in r.get("bots", []):
			things[b["id"]] = true
			for key in ["catch_dialog", "talk_dialog"]:
				assert_true(Dialog.has_dialog(b[key]), "%s: %s" % [id, b[key]])
		for e in r.get("exits", []):
			assert_true(Rooms.ROOMS.has(e["to"]), "%s exit to %s" % [id, e["to"]])
		if r.has("enter"):
			assert_true(Dialog.has_dialog(r["enter"]["dialog"]), "%s enter dialog" % id)
	for id in Rooms.TRAVEL:
		assert_true(Rooms.ROOMS.has(id), "travel to %s" % id)
		assert_true(Rooms.ROOMS[id]["spawns"].has("from_bike"), "%s has a bike spawn" % id)
	for u in Puzzles.data["uses"]:
		assert_true(things.has(u["target"]), "use target %s is in a room" % u["target"])


func test_bag_taps_hold_look_and_combine():
	GameState.give_item("hanger")
	_hud.tap_item("hanger")
	assert_eq(GameState.held_item, "hanger")
	_hud.tap_item("hanger")
	assert_eq(GameState.held_item, "", "second tap = look, put back")
	assert_true(Dialog.is_active(), "looking shows the description")
	TestHelpers.finish_dialog()
	_hud.tap_item("hanger")
	_hud.tap_item("gum")
	TestHelpers.finish_dialog()
	assert_true(GameState.has_item("hook"))
	assert_false(GameState.has_item("hanger"))
	assert_false(GameState.has_item("gum"))


func test_wrong_combine_and_use_just_talk():
	GameState.give_item("hanger")
	assert_false(Puzzles.combine("hanger", "debt_book"))
	assert_true(Dialog.is_active())
	TestHelpers.finish_dialog()
	assert_true(GameState.has_item("hanger"), "nothing lost")
	GameState.held_item = "debt_book"
	_tap("floor_gap")
	assert_true(GameState.has_item("debt_book"))
	assert_eq(GameState.held_item, "", "the item went back to the bag")


func test_tapping_floor_puts_the_held_item_back():
	GameState.held_item = "gum"
	_player.click_at(_player.global_position + Vector2(-80, 30))
	assert_eq(GameState.held_item, "")


func test_pickup_leaves_the_room_for_good():
	_tap("hanger")
	assert_true(GameState.has_item("hanger"))
	assert_true(GameState.has_flag("got_hanger"))
	await wait_physics_frames(2)
	assert_null(_thing("hanger"))


func _ride_to(room: String) -> void:
	_tap("float_bike")
	assert_true(GameState.ui_open, "the trip menu is open")
	_main.travel(room)
	await wait_seconds(0.8)
	assert_eq(_room().room_id, room)


func test_walkthrough_chapter_one():
	# home: the key fell through the floor
	_tap("hanger")
	_tap("air_remote")
	_tap("letter")
	assert_false(GameState.has_flag("got_float_key"))
	_hud.tap_item("hanger")
	_hud.tap_item("gum")
	TestHelpers.finish_dialog()
	GameState.held_item = "hook"
	_tap("floor_gap")
	assert_true(GameState.has_item("float_key"))
	# pier: the collector, the radio, the bike
	await _go("pier", "from_home")
	var collector := _room().get_world().get_node("Collector") as PatrolBot
	assert_ne(collector.state, PatrolBot.State.OFF)
	_tap("float_bike")
	assert_false(GameState.ui_open, "no key in the bike yet")
	GameState.held_item = "air_remote"
	_tap("radio")
	assert_true(GameState.has_flag("radio_on"))
	assert_eq(collector.state, PatrolBot.State.OFF, "พี่หนวด dances")
	GameState.held_item = "float_key"
	_tap("float_bike")
	assert_true(GameState.has_flag("bike_ready"))
	await _ride_to("noodle_boat")
	# noodle boat: ป้านก cannot hear, so write it down
	_tap("pa_nok")
	assert_false(GameState.has_item("brass_box"))
	_tap("lung_table3")
	assert_true(GameState.has_item("sauce_packs"))
	GameState.held_item = "debt_book"
	_tap("pa_nok")
	assert_true(GameState.has_item("brass_box"))
	assert_true(GameState.has_item("debt_book"), "the debt book stays (sadly)")
	_tap("pa_nok")
	assert_true(GameState.has_flag("know_stilts"))
	# stilts: ป้าจุ๋ม trades what she knows for gossip
	await _ride_to("stilts")
	_tap("jum")
	assert_false(GameState.has_flag("jum_friend"))
	GameState.held_item = "letter"
	_tap("jum")
	assert_true(GameState.has_flag("jum_friend"))
	assert_true(GameState.has_flag("know_garage") and GameState.has_flag("know_gate"))
	# boat garage: pull the robot's fuse, ช่างแดง comes out
	await _ride_to("boat_garage")
	assert_null(_thing("chang_daeng"), "hiding under the boat")
	var robot := _room().get_world().get_node("No9") as PatrolBot
	robot.facing = Vector2.RIGHT
	_player.global_position = robot.global_position + Vector2(-70, 0)
	robot.tamper(_player)
	TestHelpers.finish_dialog()
	assert_true(GameState.has_flag("no9_fused"))
	await _go("boat_garage", "from_bike")
	_tap("chang_daeng")
	assert_true(GameState.has_item("broken_crank"))
	_tap("tape")
	_hud.tap_item("broken_crank")
	_hud.tap_item("tape")
	TestHelpers.finish_dialog()
	assert_true(GameState.has_item("crank"))
	# old gate: under water until the tide turns
	await _ride_to("old_gate")
	assert_eq(GameState.tide, "high")
	GameState.held_item = "crank"
	_tap("sluice_gate")
	assert_false(GameState.has_flag("gate_open"), "the gate is under water")
	_tap("bench")
	await wait_seconds(0.8)
	assert_eq(GameState.tide, "low")
	GameState.held_item = "crank"
	_tap("sluice_gate")
	assert_true(GameState.has_flag("gate_open"))
	await _go("old_gate", "default")
	_tap("exit_station")
	await wait_seconds(0.8)
	assert_eq(_room().room_id, "station")
	TestHelpers.finish_dialog()
	assert_true(GameState.has_flag("seen_station"))
	GameState.held_item = "brass_box"
	_tap("zero_plate")
	await wait_physics_frames(2)
	assert_true(GameState.has_flag("chapter1_done"))
	assert_true(GameState.ui_open, "chapter card is up")


func test_hints_follow_the_story():
	var flags := {}
	assert_string_contains(Puzzles.hint_text(Puzzles.data, flags), "กุญแจ")
	flags["got_float_key"] = true
	assert_string_contains(Puzzles.hint_text(Puzzles.data, flags), "พี่หนวด")
	Puzzles.hint()
	assert_true(Dialog.is_active())


func test_long_press_pings_tappable_things():
	assert_gt(_player.highlight_things(), 3)
	assert_gt(get_tree().get_nodes_in_group("pickable").size(), 3)


func test_boat_track_and_ride():
	var a := BoatTrack.generate(5)
	assert_eq(a, BoatTrack.generate(5), "deterministic")
	assert_gt(a["obstacles"].size(), 3)
	Settings.skip_ride = false
	GameState.set_flag("bike_ready")
	await _go("pier", "from_home")
	_main.travel("noodle_boat")
	await wait_seconds(0.8)
	var ride: BoatRide = get_tree().get_first_node_in_group("ride")
	assert_not_null(ride)
	ride.track["obstacles"] = [{"kind": "crate", "x": 3.0, "lane": 0}]
	for i in 60:
		ride.step(0.05)
	assert_has(ride.hits, "bump")
	ride.travelled = ride.track["length"]
	ride.step(0.05)
	await wait_seconds(0.8)
	assert_eq(_room().room_id, "noodle_boat")


func test_collector_catch_pushes_and_talks():
	await _go("pier", "from_home")
	var collector := _room().get_world().get_node("Collector") as PatrolBot
	collector.patrol = PackedVector2Array()
	collector.facing = Vector2.LEFT
	_player.global_position = collector.global_position + Vector2(-140, 0)
	await wait_physics_frames(60)
	assert_true(Dialog.is_active() or collector.state == PatrolBot.State.CHASE)
