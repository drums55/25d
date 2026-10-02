extends GutTest
## Point & click in a room: navmesh, picking, walking, talking, UI taps not
## walking the rider.

var _main: Node
var _player: Player


func before_each():
	TestHelpers.start_in("noodle_boat")
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)
	_player = get_tree().get_first_node_in_group("player")


func after_each():
	TestHelpers.finish_dialog()
	GameState.delete_save(0)
	GameState.new_game()


func _room() -> IsoRoom:
	return _player.get_parent().get_parent() as IsoRoom


func _world(path: String) -> Node2D:
	return _room().get_world().get_node(path)


func test_navmesh_routes_around_the_pot():
	var room := _room()
	var region := room.get_node("Navigation") as NavigationRegion2D
	assert_gt(region.navigation_polygon.get_polygon_count(), 0)
	var stall := _world("Prop0")  # ป้านก's noodle pot
	var a := stall.global_position + Vector2(0, -90)
	var b := stall.global_position + Vector2(0, 110)
	var map := region.get_navigation_map()
	var path := NavigationServer2D.map_get_path(map, a, b, true)
	for i in 30:
		if path.size() > 0:
			break
		await wait_physics_frames(1)
		path = NavigationServer2D.map_get_path(map, a, b, true)
	assert_gt(path.size(), 2, "path bends around the pot")
	var foot := Iso.footprint(stall.footprint_cells)
	for p in path:
		assert_false(Geometry2D.is_point_in_polygon(p - stall.global_position, foot))


func test_pick_person_and_floor():
	var npc := _world("PaNok/Interactable")
	var nodes := get_tree().get_nodes_in_group("pickable")
	assert_eq(Player.pick(nodes, npc.global_position + Vector2(0, -120)), npc, "tap head")
	assert_null(Player.pick(nodes, _player.global_position + Vector2(-60, 40)), "tap floor")


func test_pick_uses_drawn_pixels_not_rects():
	var nodes := get_tree().get_nodes_in_group("pickable")
	var npc := _world("PaNok/Interactable")
	var corner := npc.global_position + Vector2(-66, -240)
	assert_ne(Player.pick(nodes, corner), npc, "empty part of the frame is not ป้านก")


func test_click_floor_walks_there():
	var dest := _player.global_position + Vector2(-120, -40)
	_player.click_at(dest)
	await wait_physics_frames(90)
	assert_lt(_player.global_position.distance_to(dest), 20.0)
	assert_eq(_player.order, Player.Order.NONE)


func test_click_person_talks_and_taps_advance():
	var npc := _world("PaNok")
	_player.click_at(npc.global_position + Vector2(0, -100))
	await wait_physics_frames(120)
	assert_true(Dialog.is_active(), "dialog started")
	for i in 10:
		Dialog.typing = false
		_player.click_at(Vector2.ZERO)
	assert_false(Dialog.is_active(), "taps advanced to the end")


func test_menu_blocks_world_taps():
	var hud: Hud = get_tree().get_first_node_in_group("hud")
	hud.toggle_menu()
	assert_true(GameState.ui_open)
	_player.click_at(_player.global_position + Vector2(100, 0))
	assert_eq(_player.order, Player.Order.NONE, "world ignores taps while the menu is open")
	hud.close_menu()
	assert_false(GameState.ui_open)


func test_screen_tap_on_ui_does_not_walk():
	var hud: Hud = get_tree().get_first_node_in_group("hud")
	var btn := hud._menu_button
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = btn.get_global_rect().get_center()
	_player._unhandled_input(ev)
	assert_eq(_player.order, Player.Order.NONE)


func test_screen_tap_converts_to_world():
	var dest := _player.global_position + Vector2(-150, -90)
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = _player.get_canvas_transform() * dest
	_player._unhandled_input(ev)
	await wait_physics_frames(90)
	assert_lt(_player.global_position.distance_to(dest), 20.0)
