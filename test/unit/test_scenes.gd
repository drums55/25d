extends GutTest
## Smoke test: every scene instantiates, and every place type builds a valid
## room for many random places (navmesh without slivers, arrival clear).


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


func test_every_place_builds_a_valid_room():
	var checked := 0
	for seed in [1, 2, 3, 4242]:
		GameState.new_game(seed)
		for n in City.get_city()["nodes"]:
			var room := (
				(load(GameState.LOCATION_SCENE) as PackedScene).instantiate() as LocationRoom
			)
			room.node_override = n["id"]
			add_child(room)
			var label := "%s seed %d (%s)" % [n["type"], seed, n["name"]]
			var nav := (room.get_node("Navigation") as NavigationRegion2D).navigation_polygon
			assert_gt(nav.get_polygon_count(), 0, "%s has a navmesh" % label)
			assert_gte(
				IsoRoom.shortest_nav_edge(nav), IsoRoom.NAV_MIN_EDGE, "%s no slivers" % label
			)
			var arrival := room.get_spawn_position("arrival")
			for body in room.get_world().get_children():
				if body is StaticBody2D:
					var d: float = arrival.distance_to(body.global_position)
					assert_gt(d, 80.0, "%s arrival clear of %s" % [label, body.name])
			assert_not_null(room.get_world().get_node_or_null("MyBike"), "%s has the bike" % label)
			room.free()
			checked += 1
	assert_gt(checked, 50)
	GameState.new_game()


func test_menu_boots_and_new_game_enters_a_place():
	GameState.delete_save(0)
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	TestHelpers.start_at("restaurant")
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await wait_physics_frames(3)
	var player := get_tree().get_first_node_in_group("player") as Player
	assert_true(player.get_parent().get_parent() is LocationRoom, "player lives in the place")
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


func test_templates_avoid_sliver_gaps():
	var bad := Vector2(0.85, 1.15)
	for type in LocationTemplates.T:
		var t: Dictionary = LocationTemplates.T[type]
		var items := []
		for p in t.get("props", []) + t.get("extras", []):
			items.append(
				[
					"%s%s" % [p.get("art", "block"), p["pos"]],
					Rect2(p["pos"] - p["foot"] * 0.5, p["foot"])
				]
			)
		var npc := Vector2(0.84, 0.84)
		if t.has("merchant"):
			items.append(["merchant", Rect2(t["merchant"]["pos"] - npc * 0.5, npc)])
		for c in t["customers"]:
			items.append(["customer%s" % c, Rect2(c - npc * 0.5, npc)])
		var bike_foot := LocationRoom.BIKE_FOOT
		items.append(["bike", Rect2(LocationRoom.bike_cell(t) - bike_foot * 0.5, bike_foot)])
		var g := Vector2(t["grid"])
		for it in items:
			var r: Rect2 = it[1]
			for w in [r.position.x, r.position.y, g.x - r.end.x, g.y - r.end.y]:
				assert_false(w > bad.x and w < bad.y, "%s %s wall gap %.2f" % [type, it[0], w])
		for i in items.size():
			for j in range(i + 1, items.size()):
				var d := _gap(items[i][1], items[j][1])
				assert_false(
					d > bad.x and d < bad.y,
					"%s %s ~ %s gap %.2f" % [type, items[i][0], items[j][0], d]
				)
