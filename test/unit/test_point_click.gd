extends GutTest
## Point & click: navmesh, picking, and walking orders end-to-end in Main.

var _main: Node
var _player: Player


func before_each():
	GameState.delete_save()
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)
	_player = get_tree().get_first_node_in_group("player")


func after_each():
	GameState.delete_save()
	GameState.new_game()


func _room() -> IsoRoom:
	return _player.get_parent().get_parent() as IsoRoom


func _world(path: String) -> Node2D:
	return _room().get_world().get_node(path)


func test_navmesh_built_and_routes_around_pillar():
	var room := _room()
	var region := room.get_node("Navigation") as NavigationRegion2D
	assert_gt(region.navigation_polygon.get_polygon_count(), 0)
	var pillar := _world("PillarA")
	var a := pillar.global_position + Vector2(0, -120)
	var b := pillar.global_position + Vector2(0, 120)
	var path := NavigationServer2D.map_get_path(region.get_navigation_map(), a, b, true)
	assert_gt(path.size(), 2, "path bends around the pillar")
	var foot := Iso.footprint(Vector2.ONE)
	for p in path:
		assert_false(
			Geometry2D.is_point_in_polygon(p - pillar.global_position, foot), "path avoids pillar"
		)


func test_pick_prefers_targets_and_ignores_floor():
	var elder := _world("Elder/Interactable")
	var nodes := get_tree().get_nodes_in_group("pickable")
	assert_eq(Player.pick(nodes, elder.global_position + Vector2(0, -120)), elder, "tap head")
	assert_null(Player.pick(nodes, _player.global_position + Vector2(-300, 0)), "tap floor")


func test_click_floor_walks_there():
	var dest := _player.global_position + Vector2(200, 60)
	_player.click_at(dest)
	await wait_physics_frames(90)
	assert_lt(_player.global_position.distance_to(dest), 20.0)
	assert_eq(_player.order, Player.Order.NONE)


func test_click_dummy_walks_up_and_hits_it():
	var dummy := _world("TrainingDummy")
	_player.click_at(dummy.global_position + Vector2(0, -100))
	assert_eq(_player.order, Player.Order.ATTACK)
	await wait_physics_frames(90)
	assert_eq(dummy.hits, 1)


func test_click_npc_starts_dialog_and_taps_advance():
	var elder := _world("Elder")
	_player.click_at(elder.global_position + Vector2(0, -100))
	await wait_physics_frames(90)
	assert_true(Dialog.is_active(), "dialog started")
	for i in 10:
		Dialog.typing = false
		_player.click_at(Vector2.ZERO)
	assert_false(Dialog.is_active(), "taps advanced to the end")


func test_screen_tap_converts_to_world():
	var dest := _player.global_position + Vector2(-150, 80)
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = _player.get_canvas_transform() * dest
	_player._unhandled_input(ev)
	await wait_physics_frames(90)
	assert_lt(_player.global_position.distance_to(dest), 20.0)
