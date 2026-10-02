extends GutTest
## Bag, using and combining things (DESIGN 11.5), the puzzle data's integrity,
## travel, the tide, hints, and a walkthrough of all of chapter 1:
## home -> pier -> noodle boat -> stilts -> boat garage -> old gate -> station.

var _main: Node
var _player: Player
var _hud: Hud


func before_each():
	TestHelpers.start_in("home")
	BoatRide.skip_all = true
	Puzzles.rng.seed = 1
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)
	_player = get_tree().get_first_node_in_group("player")
	_hud = get_tree().get_first_node_in_group("hud")


func after_each():
	BoatRide.skip_all = false
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
		for p in r.get("props", []) + r.get("extra_props", []):
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
	TestHelpers.finish_dialog()
	GameState.held_item = "float_key"
	_tap("float_bike")
	assert_false(GameState.has_flag("bike_ready"), "พี่หนวด won't let the bike go")
	assert_true(GameState.has_item("float_key"))
	TestHelpers.finish_dialog()
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


func test_walkthrough_chapter_two():
	for f in [
		"got_float_key",
		"radio_on",
		"bike_ready",
		"got_box",
		"know_stilts",
		"jum_friend",
		"know_garage",
		"know_gate",
		"no9_fused",
		"got_broken_crank",
		"crank_fixed",
		"gate_open",
		"seen_station",
		"chapter1_done"
	]:
		GameState.set_flag(f)
	GameState.give_item("brass_box")
	TestHelpers.finish_dialog()
	_main.start_chapter(2)
	await wait_seconds(0.8)
	TestHelpers.finish_dialog()
	assert_eq(GameState.chapter, 2)
	assert_true(GameState.has_flag("know_kiao"), "เจ๊เกียว called")
	# เจ๊เกียว: the debt was sold, ask the robots
	await _go("pier", "from_home")
	assert_null(_room().get_world().get_node_or_null("Collector"), "พี่หนวด lost his job")
	assert_not_null(_thing("nuad"))
	await _ride_to("kiao_raft")
	TestHelpers.finish_dialog()
	_tap("kiao")
	assert_true(GameState.has_flag("met_kiao"))
	# เก้า: a name for a memory
	await _ride_to("boat_garage")
	assert_null(_room().get_world().get_node_or_null("No9"), "no patrol in chapter 2")
	GameState.held_item = "debt_book"
	_tap("no9_awake")
	assert_true(GameState.has_item("memory_chip"))
	# น้องเก่ง reads it
	await _ride_to("stilts")
	GameState.held_item = "memory_chip"
	_tap("keng")
	assert_true(GameState.has_item("debt_list"))
	# ป้าจุ๋ม almost sold her house for a lottery prize
	_tap("jum")
	GameState.held_item = "debt_list"
	_tap("jum")
	assert_true(GameState.has_flag("jum_saved"))
	assert_true(GameState.has_item("reading_glasses"))
	# ลุงโต๊ะสาม's thirty-year-old letter
	await _ride_to("noodle_boat")
	_tap("lung_table3")
	assert_true(GameState.has_item("love_letter"))
	GameState.held_item = "love_letter"
	_tap("pa_nok")
	assert_false(GameState.has_flag("nok_love"), "cannot read it without glasses")
	assert_true(GameState.has_item("love_letter"))
	GameState.held_item = "reading_glasses"
	_tap("pa_nok")
	GameState.held_item = "love_letter"
	_tap("pa_nok")
	assert_true(GameState.has_flag("nok_love"))
	# คุณนายวรรณ waits at บ้านเลขที่ 0
	await _ride_to("old_gate")
	_tap("bench")
	await wait_seconds(0.8)
	assert_eq(GameState.tide, "low")
	_tap("exit_station")
	await wait_seconds(0.8)
	assert_eq(_room().room_id, "station")
	_tap("wan")
	await wait_physics_frames(2)
	assert_true(GameState.has_flag("chapter2_done"))
	assert_true(GameState.ui_open, "chapter card is up")


## Everything up to the end of chapter 2, then the chapter-3 card's button.
func _start_chapter_three() -> void:
	for f in [
		"got_float_key",
		"radio_on",
		"bike_ready",
		"got_box",
		"know_stilts",
		"jum_friend",
		"know_garage",
		"know_gate",
		"know_kiao",
		"no9_fused",
		"got_broken_crank",
		"crank_fixed",
		"gate_open",
		"seen_station",
		"chapter1_done",
		"ch2",
		"seen_kiao",
		"met_kiao",
		"no9_named",
		"got_debt_list",
		"jum_saved",
		"nok_glasses",
		"got_love_letter",
		"nok_love",
		"chapter2_done"
	]:
		GameState.set_flag(f)
	for item in ["brass_box", "crank", "debt_list"]:
		GameState.give_item(item)
	GameState.chapter = 2
	TestHelpers.finish_dialog()
	_hud.hide_overlay()
	_main.start_chapter(3)
	await wait_seconds(0.8)
	TestHelpers.finish_dialog()
	assert_eq(GameState.chapter, 3)
	assert_true(GameState.has_flag("ch3_started"), "chapter 3 intro played")
	assert_eq(_room().modulate, _main.NIGHT_TINT, "chapter 3 is at night")


func test_walkthrough_chapter_three_best_ending():
	await _start_chapter_three()
	# พี่หนวด's debt megaphone wakes the soi, through ป้าจุ๋ม
	await _go("pier", "from_home")
	_tap("nuad")
	assert_true(GameState.has_item("megaphone"))
	await _ride_to("stilts")
	_tap("keng")
	assert_false(GameState.has_flag("ally_keng"), "not before the soi is up")
	GameState.held_item = "megaphone"
	_tap("jum")
	assert_true(GameState.has_flag("ally_jum"))
	_tap("keng")
	assert_true(GameState.has_flag("ally_keng"))
	# เก้า picks a side; ช่างแดง gets his crank back
	await _ride_to("boat_garage")
	_tap("no9_awake")
	assert_true(GameState.has_flag("ally_nine"))
	GameState.held_item = "crank"
	_tap("chang_daeng")
	assert_true(GameState.has_flag("ally_daeng"))
	# เจ๊เกียว is on the list too
	await _ride_to("kiao_raft")
	GameState.held_item = "debt_list"
	_tap("kiao")
	assert_true(GameState.has_flag("ally_kiao"))
	# ลุงโต๊ะสาม's ring in the mud at the old gate
	await _ride_to("noodle_boat")
	_tap("lung_table3")
	assert_true(GameState.has_flag("lung_ring_told"))
	await _ride_to("old_gate")
	assert_null(_thing("ring"), "the mud is under water at high tide")
	_tap("bench")
	await wait_seconds(0.8)
	assert_eq(GameState.tide, "low")
	var bot := _room().get_world().get_node_or_null("CompanyBot") as PatrolBot
	assert_not_null(bot, "the company robot guards the gate")
	assert_not_null(_thing("nine_gate"), "เก้า keeps it talking")
	_tap("ring")
	assert_true(GameState.has_item("ring"))
	await _ride_to("noodle_boat")
	GameState.held_item = "ring"
	_tap("lung_table3")
	assert_true(GameState.has_flag("ally_nok"))
	assert_eq(Endings.allies(GameState.flags).size(), Endings.ALLIES.size())
	# the key in the box, into the pump at บ้านเลขที่ 0
	await _ride_to("old_gate")
	_tap("exit_station")
	await wait_seconds(0.8)
	assert_eq(_room().room_id, "station")
	GameState.held_item = "brass_box"
	_tap("pump")
	await wait_physics_frames(2)
	assert_true(GameState.ui_open, "the valve card is up")
	_main._open_valve()
	assert_true(GameState.has_flag("ending_five_stars"))
	await wait_seconds(0.8)
	assert_eq(_room().room_id, "noodle_boat", "the wedding boat at dawn")
	assert_not_null(_thing("nuad"), "the whole soi came")
	assert_true(_player.rig.get_node("Sprite").animation.begins_with("cheer"))


func test_chapter_three_sell_the_box():
	await _start_chapter_three()
	await _go("pier", "from_home")
	await _ride_to("kiao_raft")
	_tap("kiao")
	GameState.held_item = "brass_box"
	_tap("kiao")
	await wait_physics_frames(2)
	assert_true(GameState.ui_open, "the offer card is up")
	_main.end_game("sold")
	assert_true(GameState.has_flag("ending_sold"))
	await wait_seconds(0.8)
	assert_eq(_room().room_id, "home", "the ending is staged at home")
	assert_true(
		_player.rig.get_node("Sprite").animation.begins_with("phone"), "staring at the phone"
	)
	await wait_seconds(_main.ENDING_HOLD + 0.5)
	assert_false(GameState.ui_open, "nothing covers the ending until a tap")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	_main._unhandled_input(tap)
	assert_true(GameState.ui_open, "then the ending card")


func test_room_updates_when_a_flag_changes_while_inside():
	# owner 2026-10-02: ช่างแดง only came out after riding away and back
	GameState.set_flag("know_garage")
	await _go("boat_garage")
	assert_null(_thing("chang_daeng"), "hiding under the boat")
	assert_true(Rooms.condition_flags(Rooms.get_room("boat_garage")).has("no9_fused"))
	_player.global_position += Vector2(30, 10)
	var spot := _player.global_position
	GameState.set_flag("no9_fused")
	await wait_physics_frames(3)
	assert_not_null(_thing("chang_daeng"), "out from under the boat at once")
	assert_eq(_room().room_id, "boat_garage")
	assert_almost_eq(_player.global_position, spot, Vector2(1, 1), "the rider stays put")


func test_special_poses_follow_flags():
	GameState.set_flag("know_stilts")
	await _go("stilts")
	var jum := _thing("jum").get_parent().get_node("Rig") as CharacterView
	var sprite := jum.get_node("Sprite") as AnimatedSprite2D
	assert_true(sprite.animation.begins_with("idle"))
	GameState.set_flag("ally_jum")
	assert_true(sprite.animation.begins_with("shout"), "ป้าจุ๋ม grabs the megaphone")


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
	BoatRide.skip_all = false
	GameState.set_flag("bike_ready")
	await _go("pier", "from_home")
	_main.travel("noodle_boat", true)
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


func test_trip_is_a_short_skippable_cutscene():
	BoatRide.skip_all = false
	GameState.set_flag("bike_ready")
	await _go("pier", "from_home")
	_main.travel("noodle_boat")
	await wait_seconds(0.8)
	var ride: BoatRide = get_tree().get_first_node_in_group("ride")
	assert_not_null(ride)
	assert_false(ride.play)
	assert_false(ride.gag_line.is_empty(), "one canal gag per trip")
	assert_eq(ride.track["obstacles"].size(), 1)
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	ride._unhandled_input(tap)
	assert_true(ride.done, "a tap skips the trip")
	await wait_seconds(0.8)
	assert_eq(_room().room_id, "noodle_boat")
	# left alone, every gag finishes within a few seconds
	for i in BoatRide.GAGS.size():
		var r := BoatRide.new()
		r.track = r.cutscene_track(i)
		var secs := 0.0
		while r.travelled < float(r.track["length"]) and secs < 10.0:
			r.t += 0.05
			secs += 0.05
			r.travelled += float(r.track["speed"]) * clampf(r.t / BoatRide.RAMP, 0.2, 1.0) * 0.05
		assert_lt(secs, 6.0, "gag %d" % i)
		r.free()


func test_collector_catch_pushes_and_talks():
	await _go("pier", "from_home")
	var collector := _room().get_world().get_node("Collector") as PatrolBot
	collector.patrol = PackedVector2Array()
	collector.facing = Vector2.LEFT
	_player.global_position = collector.global_position + Vector2(-140, 0)
	await wait_physics_frames(60)
	assert_true(Dialog.is_active() or collector.state == PatrolBot.State.CHASE)
