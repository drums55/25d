extends GutTest
## The travel map (MapView): pins only on the places the rider knows, the boat
## where they are, tapping a pin sails there; the spots in Rooms.TRAVEL match
## the painting (tools/art/png/map_2090.py).

var _main: Node
var _hud: Hud


func before_each():
	TestHelpers.start_in("pier")
	BoatRide.skip_all = true
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)
	_hud = get_tree().get_first_node_in_group("hud")


func after_each():
	BoatRide.skip_all = false
	_hud.hide_overlay()
	GameState.delete_save(0)
	GameState.new_game()


func _map() -> MapView:
	return _hud._overlay as MapView


func test_travel_spots_match_the_painting():
	var src := FileAccess.get_file_as_string("res://tools/art/png/map_2090.py")
	var re := RegEx.create_from_string('"(\\w+)": \\((\\d\\.\\d+), (\\d\\.\\d+)\\)')
	var painted := {}
	for m in re.search_all(src):
		painted[m.get_string(1)] = Vector2(float(m.get_string(2)), float(m.get_string(3)))
	assert_gte(painted.size(), 15, "the whole soi is on the sheet")
	for id in Rooms.TRAVEL:
		assert_true(painted.has(id), "%s is painted on the map" % id)
		var at: Vector2 = Rooms.TRAVEL[id]["map"]
		assert_almost_eq(at, painted.get(id, Vector2.ZERO), Vector2(0.001, 0.001), id)
		assert_true(at.x > 0.0 and at.x < 1.0 and at.y > 0.0 and at.y < 1.0, id)


func test_map_shows_only_known_places():
	_main.open_travel()
	assert_true(GameState.ui_open)
	var map := _map()
	assert_not_null(map, "the trip menu is the map")
	assert_true(map._pins.has("noodle_boat"))
	assert_false(map._pins.has("pier"), "no pin where the boat already is")
	assert_false(map._pins.has("stilts"), "not known yet")
	assert_false(map._pins.has("kiao_raft"), "not known yet")
	_hud.hide_overlay()
	GameState.set_flag("know_stilts")
	_main.open_travel()
	assert_true(_map()._pins.has("stilts"), "known now")


func test_tapping_a_pin_sails_there():
	_main.open_travel()
	var map := _map()
	(map._pins["noodle_boat"] as Button).pressed.emit()
	assert_true(map.busy, "the boat is sailing")
	map.close()
	assert_true(GameState.ui_open, "cannot close mid-sail")
	await wait_seconds(MapView.SAIL_TIME + 0.9)
	assert_eq(GameState.room, "noodle_boat")
	assert_false(GameState.ui_open)
	assert_null(_hud._overlay)


func test_closing_the_map():
	_main.open_travel()
	_map().close()
	assert_false(GameState.ui_open)
	assert_null(_hud._overlay)


func test_map_is_dark_at_night():
	GameState.chapter = 3
	_main.open_travel()
	assert_eq(_map()._sheet.get_node("Art").modulate, _main.NIGHT_TINT)
