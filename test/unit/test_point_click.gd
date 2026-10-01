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
	var pillar := _world("WaterTank")
	var a := pillar.global_position + Vector2(0, -120)
	var b := pillar.global_position + Vector2(0, 120)
	# The map syncs on a later physics frame; earlier tests swapped rooms, so
	# wait until a path exists instead of assuming it is ready.
	var map := region.get_navigation_map()
	var path := NavigationServer2D.map_get_path(map, a, b, true)
	for i in 30:
		if path.size() > 0:
			break
		await wait_physics_frames(1)
		path = NavigationServer2D.map_get_path(map, a, b, true)
	assert_gt(path.size(), 2, "path bends around the pillar")
	var foot := Iso.footprint(pillar.footprint_cells)
	for p in path:
		assert_false(
			Geometry2D.is_point_in_polygon(p - pillar.global_position, foot), "path avoids pillar"
		)


func test_pick_prefers_targets_and_ignores_floor():
	var npc := _world("LungPradit/Interactable")
	var nodes := get_tree().get_nodes_in_group("pickable")
	assert_eq(Player.pick(nodes, npc.global_position + Vector2(0, -120)), npc, "tap head")
	assert_null(Player.pick(nodes, _player.global_position + Vector2(0, -90)), "tap floor")


func test_pick_uses_drawn_pixels_not_rects():
	# NPC standing just in front of a prop: tapping the prop where the NPC is
	# not drawn must pick the prop, even though the NPC's old rect covered it.
	var nodes := get_tree().get_nodes_in_group("pickable")
	var npc := _world("LungPradit/Interactable")
	var prop := _world("JobBoard/Interactable") as Node2D
	var hits := {}
	for x in range(-200, 201, 8):
		for y in range(-300, 1, 8):
			var p := prop.global_position + Vector2(x, y)
			var on_prop := PickTest.visual_hit(prop.get_parent(), p, 0.0) == 1
			var on_npc := PickTest.visual_hit(npc.get_parent(), p, 0.0) == 1
			if on_prop and not on_npc:
				hits[Player.pick(nodes, p)] = true
	assert_eq(hits.keys().size(), 1, "every opaque prop pixel picks one node")
	assert_true(hits.has(prop), "and it is the prop")
	# transparent corner of the NPC frame (inside its old 140x280 rect)
	var corner := npc.global_position + Vector2(-66, -240)
	assert_ne(Player.pick(nodes, corner), npc, "empty part of the frame is not the NPC")


func test_click_floor_walks_there():
	var dest := _player.global_position + Vector2(120, -60)
	_player.click_at(dest)
	await wait_physics_frames(90)
	assert_lt(_player.global_position.distance_to(dest), 20.0)
	assert_eq(_player.order, Player.Order.NONE)


func test_click_bot_walks_up_and_tampers():
	SceneRouter.go_to("res://scenes/rooms/steam_market.tscn", "from_soi", false)
	await wait_physics_frames(5)
	var bot: PatrolBot = _player.get_parent().get_node("MarketGuard")
	bot.patrol = PackedVector2Array()
	bot.facing = Vector2(1, 0)  # looking away from the rider (who comes from the left)
	_player.global_position = bot.global_position + Vector2(-260, 0)
	_player.click_at(bot.global_position + Vector2(0, -100))
	assert_eq(_player.order, Player.Order.TAMPER)
	await wait_physics_frames(90)
	assert_eq(bot.state, PatrolBot.State.OFF, "fuse pulled from behind")


func test_click_npc_starts_dialog_and_taps_advance():
	var npc := _world("LungPradit")
	_player.click_at(npc.global_position + Vector2(0, -100))
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
