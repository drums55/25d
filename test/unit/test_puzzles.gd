extends GutTest
## Bag, using and combining things (DESIGN 11.5), the puzzle data's integrity
## and a full walkthrough of the A1 slice: home -> pier -> noodle boat -> box.

var _main: Node
var _player: Player
var _hud: Hud


func before_each():
	TestHelpers.start_in("home")
	Puzzles.rng.seed = 1
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)
	_player = get_tree().get_first_node_in_group("player")
	_hud = get_tree().get_first_node_in_group("hud")


func after_each():
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


func test_walkthrough_home_to_the_brass_box():
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
	assert_eq(_room().room_id, "pier", "no key in the bike yet")
	GameState.held_item = "air_remote"
	_tap("radio")
	assert_true(GameState.has_flag("radio_on"))
	assert_eq(collector.state, PatrolBot.State.OFF, "พี่หนวด dances")
	GameState.held_item = "float_key"
	_tap("float_bike")
	assert_true(GameState.has_flag("bike_ready"))
	_tap("float_bike")
	await wait_seconds(0.8)
	assert_eq(_room().room_id, "noodle_boat")
	# noodle boat: ป้านก cannot hear, so write it down
	_tap("pa_nok")
	assert_false(GameState.has_item("brass_box"))
	_tap("lung_table3")
	assert_true(GameState.has_item("sauce_packs"))
	GameState.held_item = "debt_book"
	_tap("pa_nok")
	assert_true(GameState.has_item("brass_box"))
	assert_true(GameState.has_item("debt_book"), "the debt book stays (sadly)")
	await wait_physics_frames(2)
	assert_true(GameState.ui_open, "the slice's end card is up")


func test_collector_catch_pushes_and_talks():
	await _go("pier", "from_home")
	var collector := _room().get_world().get_node("Collector") as PatrolBot
	collector.patrol = PackedVector2Array()
	collector.facing = Vector2.LEFT
	_player.global_position = collector.global_position + Vector2(-140, 0)
	await wait_physics_frames(60)
	assert_true(Dialog.is_active() or collector.state == PatrolBot.State.CHASE)
