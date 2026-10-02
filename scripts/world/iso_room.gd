@tool
class_name IsoRoom
extends Node2D
## One isometric room. Placeholder floor/back walls are drawn procedurally;
## later an AI-painted floor image (Sprite2D under "Backdrop") replaces them —
## set `draw_placeholder` off when that happens.
##
## Expected children:
##   Backdrop (Node2D, optional)  painted floor/walls, not y-sorted
##   World    (Node2D, y_sort_enabled)  props, NPCs, doors; the player is moved in here
##   Spawns   (Node2D)  Marker2D per arrival point, named by spawn id
##
## At runtime it also builds the floor boundary collision and a navigation
## mesh (floor diamond minus the collision footprints of StaticBody2D props in
## World) for point & click pathfinding.

## Navmesh is shrunk by this much from walls/props (player feet radius + margin).
const NAV_AGENT_RADIUS := 28.0
## Circle collision shapes become polygons with this many sides.
const CIRCLE_SIDES := 12
## Navmesh edges shorter than the navigation map cell size (1 px) break edge
## merging ("Attempted to merge a navigation mesh polygon edge..."). Happens
## when two obstacles almost touch; move one so they overlap or leave a gap.
const NAV_MIN_EDGE := 1.0

@export var room_title := ""
@export var grid_size := Vector2i(12, 12):
	set(v):
		grid_size = v
		queue_redraw()
## PNG name under assets/art/rooms/ (default: node name in snake_case).
@export var art_name := ""
@export var draw_placeholder := true:
	set(v):
		draw_placeholder = v
		queue_redraw()
@export var wall_height := 240.0
@export var floor_color_a := Color(0.33, 0.29, 0.36)
@export var floor_color_b := Color(0.29, 0.25, 0.32)
@export var wall_color := Color(0.19, 0.16, 0.22)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_boundary()
	_build_navigation()
	apply_art()
	# the placeholder floor (this node's _draw) goes under floor overlays such
	# as patrol vision cones (z -1); World is lifted back to z 0
	z_index = -20
	get_world().z_index = 20


## Uses assets/art/rooms/<art_name>.png as backdrop when present. The image
## must be painted over the placeholder layout: its top-left corner maps to
## (-grid_w*64, -wall_height) in room space, i.e. the backdrop rect below.
func get_backdrop_rect() -> Rect2:
	var c := get_corners()
	return Rect2(c[3].x, c[0].y - wall_height, c[1].x - c[3].x, c[2].y - c[0].y + wall_height)


func apply_art() -> bool:
	var tex := ArtLibrary.room(art_name if not art_name.is_empty() else name.to_snake_case())
	if tex == null:
		return false
	var sprite := Sprite2D.new()
	sprite.name = "Backdrop"
	sprite.texture = tex
	sprite.centered = false
	# below floor-level overlays (patrol bot vision cones use z -1)
	sprite.z_index = -10
	var rect := get_backdrop_rect()
	sprite.position = rect.position
	sprite.scale = rect.size / tex.get_size()
	add_child(sprite)
	move_child(sprite, 0)
	draw_placeholder = false
	for child in get_world().get_children():
		if "show_panel" in child:
			child.show_panel = false
	return true


func get_world() -> Node2D:
	return $World


func get_spawn_position(spawn_id: String) -> Vector2:
	var spawns := get_node_or_null("Spawns")
	if spawns:
		for id in [spawn_id, "default"]:
			var m := spawns.get_node_or_null(NodePath(id))
			if m is Node2D:
				return m.global_position
	return to_global(Iso.grid_to_world(Vector2(grid_size) * 0.5))


func get_corners() -> PackedVector2Array:
	var g := Vector2(grid_size)
	return PackedVector2Array(
		[
			Iso.grid_to_world(Vector2.ZERO),
			Iso.grid_to_world(Vector2(g.x, 0)),
			Iso.grid_to_world(g),
			Iso.grid_to_world(Vector2(0, g.y)),
		]
	)


## World-space rect the camera zooms to fill: the painted backdrop when there
## is one (it covers its whole rect), else the floor + walls + margin.
func get_view_rect() -> Rect2:
	if has_node("Backdrop"):
		var r := get_backdrop_rect()
		return Rect2(to_global(r.position), r.size)
	return get_camera_rect()


## World-space rect the camera may show (floor + back walls + margin).
func get_camera_rect(margin := 160.0) -> Rect2:
	var c := get_corners()
	var rect := Rect2(c[0], Vector2.ZERO)
	for p in c:
		rect = rect.expand(p)
	rect = rect.expand(c[0] - Vector2(0, wall_height))
	return Rect2(to_global(rect.position), rect.size).grow(margin)


func _build_boundary() -> void:
	var body := StaticBody2D.new()
	body.name = "Boundary"
	body.collision_layer = 1
	body.collision_mask = 0
	var poly := CollisionPolygon2D.new()
	poly.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	var c := get_corners()
	c.append(c[0])
	poly.polygon = c
	body.add_child(poly)
	add_child(body)


func _build_navigation() -> void:
	var geo := NavigationMeshSourceGeometryData2D.new()
	geo.add_traversable_outline(get_corners())
	for outline in get_obstacle_outlines():
		geo.add_obstruction_outline(outline)
	var nav := NavigationPolygon.new()
	nav.agent_radius = NAV_AGENT_RADIUS
	NavigationServer2D.bake_from_source_geometry_data(nav, geo)
	var min_edge := shortest_nav_edge(nav)
	if min_edge < NAV_MIN_EDGE:
		push_warning(
			(
				"IsoRoom %s: navmesh edge %.2f px < %.1f at cell %s; two obstacles nearly touch"
				% [name, min_edge, NAV_MIN_EDGE, Iso.world_to_grid(shortest_nav_edge_at(nav))]
			)
		)
	var region := NavigationRegion2D.new()
	region.name = "Navigation"
	region.navigation_polygon = nav
	add_child(region)


## Where the shortest edge sits (to find the two things that nearly touch).
static func shortest_nav_edge_at(nav: NavigationPolygon) -> Vector2:
	var verts := nav.get_vertices()
	var shortest := INF
	var at := Vector2.ZERO
	for i in nav.get_polygon_count():
		var poly := nav.get_polygon(i)
		for k in poly.size():
			var a := verts[poly[k]]
			var b := verts[poly[(k + 1) % poly.size()]]
			if a.distance_to(b) < shortest:
				shortest = a.distance_to(b)
				at = (a + b) * 0.5
	return at


static func shortest_nav_edge(nav: NavigationPolygon) -> float:
	var verts := nav.get_vertices()
	var shortest := INF
	for i in nav.get_polygon_count():
		var poly := nav.get_polygon(i)
		for k in poly.size():
			var a := verts[poly[k]]
			var b := verts[poly[(k + 1) % poly.size()]]
			shortest = minf(shortest, a.distance_to(b))
	return shortest


## Collision footprints (room-local) of StaticBody2D children of World.
func get_obstacle_outlines() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var to_room := global_transform.affine_inverse()
	for body in get_world().get_children():
		if not body is StaticBody2D:
			continue
		for shape in body.get_children():
			var pts := PackedVector2Array()
			if shape is CollisionPolygon2D:
				pts = shape.polygon
			elif shape is CollisionShape2D and shape.shape is CircleShape2D:
				var r: float = shape.shape.radius
				for i in CIRCLE_SIDES:
					pts.append(Vector2.RIGHT.rotated(TAU * i / CIRCLE_SIDES) * r)
			if pts.size() >= 3:
				out.append((to_room * shape.global_transform) * pts)
	return out


func _draw() -> void:
	if not draw_placeholder:
		return
	var c := get_corners()
	var up := Vector2(0, -wall_height)
	# Back walls (left edge 0->3, right edge 0->1); the front stays open.
	draw_colored_polygon(PackedVector2Array([c[3], c[0], c[0] + up, c[3] + up]), wall_color)
	draw_colored_polygon(
		PackedVector2Array([c[0], c[1], c[1] + up, c[0] + up]), wall_color.lightened(0.12)
	)
	for x in grid_size.x:
		for y in grid_size.y:
			var col := floor_color_a if (x + y) % 2 == 0 else floor_color_b
			var cell := PackedVector2Array(
				[
					Iso.grid_to_world(Vector2(x, y)),
					Iso.grid_to_world(Vector2(x + 1, y)),
					Iso.grid_to_world(Vector2(x + 1, y + 1)),
					Iso.grid_to_world(Vector2(x, y + 1)),
				]
			)
			draw_colored_polygon(cell, col)
