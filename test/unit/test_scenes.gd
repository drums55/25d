extends GutTest
## Smoke test: every scene in res://scenes loads and instantiates, and the
## rooms satisfy the IsoRoom contract (World, spawns, door targets exist).


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


func test_rooms_contract():
	for p in _scene_paths("res://scenes/rooms"):
		var room := (load(p) as PackedScene).instantiate() as IsoRoom
		assert_not_null(room, "%s root is IsoRoom" % p)
		if room == null:
			continue
		add_child_autofree(room)
		assert_true(room.get_world().y_sort_enabled, "%s World is y-sorted" % p)
		var nav := (room.get_node("Navigation") as NavigationRegion2D).navigation_polygon
		assert_gt(nav.get_polygon_count(), 0, "%s has a navmesh" % p)
		assert_gte(
			IsoRoom.shortest_nav_edge(nav),
			IsoRoom.NAV_MIN_EDGE,
			"%s navmesh has no sliver edges" % p
		)
		assert_not_null(room.get_node_or_null("Spawns/default"), "%s has default spawn" % p)
		for child in room.get_world().get_children():
			if child.get("target_room") == null:
				continue
			assert_true(ResourceLoader.exists(child.target_room), "%s door target exists" % p)
			var target := (load(child.target_room) as PackedScene).instantiate()
			var spawn: String = "Spawns/" + child.target_spawn
			assert_not_null(target.get_node_or_null(spawn), "%s -> %s" % [p, spawn])
			target.free()
		# Arrival points must not sit on top of a character/prop.
		for spawn in room.get_node("Spawns").get_children():
			for body in room.get_world().get_children():
				if body is StaticBody2D:
					var d: float = spawn.global_position.distance_to(body.global_position)
					assert_gt(d, 90.0, "%s spawn %s clear of %s" % [p, spawn.name, body.name])


func test_main_boots_into_start_room():
	GameState.delete_save()
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_physics_frames(3)
	var player := get_tree().get_first_node_in_group("player") as Player
	assert_not_null(player)
	assert_true(player.get_parent().get_parent() is IsoRoom, "player lives in room World")
	assert_eq(GameState.room_path, GameState.START_ROOM)
	GameState.delete_save()
