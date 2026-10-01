class_name ClickMarker
extends Node2D
## Fading ring on the floor where the player was sent. top_level so it stays
## in world space while being a child of the player.

const LIFE := 0.5

var _left := 0.0


func _ready() -> void:
	top_level = true
	visible = false


func show_at(world_pos: Vector2) -> void:
	global_position = world_pos
	_left = LIFE
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		visible = false
	queue_redraw()


func _draw() -> void:
	var t := clampf(_left / LIFE, 0.0, 1.0)
	var r := lerpf(34.0, 18.0, t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1, 0.85, 0.4, t), 4.0)
	draw_set_transform(Vector2.ZERO)
