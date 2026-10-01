@tool
extends Area2D
## Walk into it to change room. Place it against a back wall and put the
## matching arrival Marker2D (target_spawn) a little in front of the door in
## the target room, so the player does not land on the door again.

enum WallAxis { BACK_RIGHT, BACK_LEFT }

@export_file("*.tscn") var target_room := ""
@export var target_spawn := "default"
@export var wall_axis := WallAxis.BACK_RIGHT:
	set(v):
		wall_axis = v
		queue_redraw()
@export var door_height := 170.0
## Tap area relative to the origin; tapping the door walks the player into it.
@export var pick_rect := Rect2(-70, -190, 140, 220)
## IsoRoom turns this off when a painted backdrop (which includes the doorway
## at the wall plane) is present; the node then only keeps its trigger area
## and the exit marker (bobbing brass arrow + pulsing floor glow).
var show_panel := true:
	set(v):
		show_panel = v
		queue_redraw()

var _t := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = 2  # player
	body_entered.connect(_on_body_entered)
	add_to_group("pickable")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	queue_redraw()


## Exit marker drawn on top of whatever the wall shows.
func _draw_marker() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 2.4)
	# floor glow in front of the doorway (iso ellipse)
	var front := Iso.grid_to_world(
		Vector2(0, 1) if wall_axis == WallAxis.BACK_RIGHT else Vector2(1, 0)
	)
	front = front.normalized() * 50.0
	draw_set_transform(front, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 70.0, Color(1.0, 0.75, 0.35, 0.10 + 0.10 * pulse))
	draw_arc(
		Vector2.ZERO,
		62.0 + 6.0 * pulse,
		0.0,
		TAU,
		40,
		Color(1.0, 0.8, 0.4, 0.35 + 0.3 * pulse),
		3.0
	)
	draw_set_transform(Vector2.ZERO)
	# bobbing brass arrow above the arch
	var y := -door_height - 70.0 - 8.0 * sin(_t * 3.0)
	var arrow := PackedVector2Array([Vector2(-22, y - 34), Vector2(22, y - 34), Vector2(0, y - 4)])
	draw_colored_polygon(arrow, Color(0.08, 0.06, 0.08))
	draw_colored_polygon(
		PackedVector2Array([Vector2(-16, y - 30), Vector2(16, y - 30), Vector2(0, y - 8)]),
		Color(0.95, 0.78, 0.4)
	)
	draw_rect(Rect2(-9, y - 48, 18, 16), Color(0.95, 0.78, 0.4))
	draw_rect(Rect2(-9, y - 48, 18, 16), Color(0.08, 0.06, 0.08), false, 3.0)


func _on_body_entered(body: Node) -> void:
	if body is Player and not target_room.is_empty():
		SceneRouter.go_to(target_room, target_spawn)


func _draw() -> void:
	if not Engine.is_editor_hint():
		_draw_marker()
	if not show_panel:
		return
	var along := Iso.grid_to_world(
		Vector2(1, 0) if wall_axis == WallAxis.BACK_RIGHT else Vector2(0, 1)
	)
	along = along.normalized() * 56.0
	var up := Vector2(0, -door_height)
	var pts := PackedVector2Array([-along, along, along + up, -along + up])
	draw_colored_polygon(pts, Color(0.05, 0.04, 0.07))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.9, 0.7, 0.35), 4.0)
