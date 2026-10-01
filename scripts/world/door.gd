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


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	collision_mask = 2  # player
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Player and not target_room.is_empty():
		SceneRouter.go_to(target_room, target_spawn)


func _draw() -> void:
	var along := Iso.grid_to_world(
		Vector2(1, 0) if wall_axis == WallAxis.BACK_RIGHT else Vector2(0, 1)
	)
	along = along.normalized() * 56.0
	var up := Vector2(0, -door_height)
	var pts := PackedVector2Array([-along, along, along + up, -along + up])
	draw_colored_polygon(pts, Color(0.05, 0.04, 0.07))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.9, 0.7, 0.35), 4.0)
