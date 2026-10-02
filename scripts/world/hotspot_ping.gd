class_name HotspotPing
extends Node2D
## Long-press feedback (DESIGN 11.5: no pixel hunting): a ring that pulses
## around something tappable for LIFE seconds, then frees itself.

const LIFE := 1.6

var _t := 0.0


func _ready() -> void:
	z_index = 50


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var a := 1.0 - k
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, 40.0 + 30.0 * k, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, a), 5.0)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(0, -120), 10.0 * a, Color(1.0, 0.95, 0.6, a))
