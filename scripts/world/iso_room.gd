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

@export var room_title := ""
@export var grid_size := Vector2i(12, 12):
	set(v):
		grid_size = v
		queue_redraw()
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
	var region := NavigationRegion2D.new()
	region.name = "Navigation"
	region.navigation_polygon = nav
	add_child(region)


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
