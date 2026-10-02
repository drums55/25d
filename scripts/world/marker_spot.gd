class_name MarkerSpot
extends Node2D
## Drawn marker for things without art: an exit (pulsing floor ring + bobbing
## arrow + label) or a small item lying around (glinting diamond in the item's
## colour + label). The Interactable child does the tapping.

@export var kind := "exit"
@export var label := ""
@export var color := Color(0.95, 0.78, 0.4)
## Item art drawn instead of the diamond (no Sprite2D on purpose: taps use
## the Interactable's generous pick_rect, not the small icon's pixels).
var icon: Texture2D

var _t := 0.0


func _ready() -> void:
	if label.is_empty():
		return
	var l := Label.new()
	l.text = label
	l.size = Vector2(320, 40)
	l.position = Vector2(-160, -165 if kind == "exit" else -110)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26 if kind == "exit" else 22)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 2.4)
	if kind == "exit":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 70.0, Color(color, 0.10 + 0.10 * pulse))
		draw_arc(
			Vector2.ZERO, 62.0 + 6.0 * pulse, 0.0, TAU, 40, Color(color, 0.4 + 0.3 * pulse), 3.0
		)
		draw_set_transform(Vector2.ZERO)
		var y := -70.0 - 8.0 * sin(_t * 3.0)
		draw_colored_polygon(
			PackedVector2Array([Vector2(-22, y - 34), Vector2(22, y - 34), Vector2(0, y - 4)]),
			Color(0.08, 0.06, 0.08)
		)
		draw_colored_polygon(
			PackedVector2Array([Vector2(-16, y - 30), Vector2(16, y - 30), Vector2(0, y - 8)]),
			color
		)
		draw_rect(Rect2(-9, y - 48, 18, 16), color)
		return
	# an item on the floor: shadow + diamond + glint
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	var bob := -6.0 * sin(_t * 2.0)
	if icon:
		var sz := Vector2(96, 96)
		draw_texture_rect(icon, Rect2(Vector2(-sz.x * 0.5, -sz.y - 8 + bob), sz), false)
		draw_circle(Vector2(26, -78 + bob), 2.0 + 3.0 * pulse, Color(1, 1, 1, 0.4 + 0.5 * pulse))
		return
	var d := PackedVector2Array(
		[
			Vector2(0, -60 + bob),
			Vector2(22, -36 + bob),
			Vector2(0, -12 + bob),
			Vector2(-22, -36 + bob)
		]
	)
	draw_colored_polygon(d, color)
	draw_polyline(d + PackedVector2Array([d[0]]), Color(0.1, 0.06, 0.04), 3.0)
	draw_circle(Vector2(8, -48 + bob), 3.0 + 3.0 * pulse, Color(1, 1, 1, 0.5 + 0.5 * pulse))
