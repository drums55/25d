extends GutTest
## Smoke test: every scene instantiates, every room builds a valid navmesh
## (no slivers, spawns clear of props) and keeps the gap rule.

const MAIN_SCENE := "res://scenes/main.tscn"


func _scene_paths(dir := "res://scenes") -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scene_paths(dir.path_join(d)))
	return out


func test_every_scene_instantiates():
	var paths := _scene_paths()
	assert_gt(paths.size(), 5)
	for p in paths:
		var packed := load(p) as PackedScene
		assert_not_null(packed, p)
		if packed:
			var node := packed.instantiate()
			assert_not_null(node, p)
			if node:
				node.free()


func test_every_room_builds_valid():
	for id in Rooms.ROOMS:
		GameState.new_game()
		var room := (load(GameState.ROOM_SCENE) as PackedScene).instantiate() as AdventureRoom
		room.room_override = id
		add_child(room)
		var nav := (room.get_node("Navigation") as NavigationRegion2D).navigation_polygon
		assert_gt(nav.get_polygon_count(), 0, "%s has a navmesh" % id)
		assert_gte(IsoRoom.shortest_nav_edge(nav), IsoRoom.NAV_MIN_EDGE, "%s no slivers" % id)
		var cells: Dictionary = Rooms.ROOMS[id].get("spawns", {})
		for spawn in cells:
			var at := room.get_spawn_position(spawn)
			for body in room.get_world().get_children():
				if body is StaticBody2D:
					var d: float = at.distance_to(body.global_position)
					assert_gt(d, 80.0, "%s spawn %s clear of %s" % [id, spawn, body.name])
		room.free()


func test_menu_boots_and_new_game_enters_a_place():
	GameState.delete_save(0)
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	TestHelpers.start_in("home")
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_physics_frames(3)
	var player := get_tree().get_first_node_in_group("player") as Player
	assert_true(player.get_parent().get_parent() is AdventureRoom, "player lives in the room")
	assert_true(FileAccess.file_exists(GameState.slot_path(0)), "arrival autosaved")
	GameState.delete_save(0)


## Gap (cells) between two footprints; ~1 cell (2 x nav agent radius) makes
## navmesh slivers, so templates must keep clear of GAP_BAD.
func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
	var dy := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
	if dx > 0.0 and dy > 0.0:
		return Vector2(dx, dy).length()
	return maxf(dx, dy)


func test_rooms_avoid_sliver_gaps():
	var bad := Vector2(0.85, 1.15)
	var npc := Vector2(0.84, 0.84)
	for id in Rooms.ROOMS:
		var r: Dictionary = Rooms.ROOMS[id]
		var items := []
		for p in r.get("props", []) + r.get("extra_props", []):
			items.append(
				["%s%s" % [p["id"], p["pos"]], Rect2(p["pos"] - p["foot"] * 0.5, p["foot"])]
			)
		for n in r.get("npcs", []):
			items.append([n["id"], Rect2(n["pos"] - npc * 0.5, npc)])
		var g := Vector2(r["grid"])
		for it in items:
			var rect: Rect2 = it[1]
			for w in [rect.position.x, rect.position.y, g.x - rect.end.x, g.y - rect.end.y]:
				assert_false(w > bad.x and w < bad.y, "%s %s wall gap %.2f" % [id, it[0], w])
		for i in items.size():
			for j in range(i + 1, items.size()):
				var d := _gap(items[i][1], items[j][1])
				assert_false(
					d > bad.x and d < bad.y,
					"%s %s ~ %s gap %.2f" % [id, items[i][0], items[j][0], d]
				)


func test_camera_zooms_each_room_to_fill_the_screen():
	TestHelpers.start_in("pier")
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_physics_frames(3)
	var player: Player = get_tree().get_first_node_in_group("player")
	var room := player.get_parent().get_parent() as IsoRoom
	var view := get_viewport().get_visible_rect().size
	var want := Iso.fill_zoom(room.get_view_rect().size, view)
	assert_almost_eq(player.camera.zoom.x, want, 0.001)
	assert_gt(want, 1.3, "the pier's painting is zoomed in")
	# the camera never leaves the painting
	var r := room.get_view_rect()
	assert_eq(player.camera.limit_left, floori(r.position.x))
	assert_eq(player.camera.limit_right, ceili(r.end.x))
	assert_true(player.camera.limit_bottom - player.camera.limit_top >= view.y / want - 1.0)
	GameState.new_game()
