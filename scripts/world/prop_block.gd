@tool
extends StaticBody2D
## Placeholder iso block (pillar, crate, table...). Origin = footprint centre,
## which is also the Y-sort point. Swap the drawing for a Sprite2D child with
## AI art later; keep the footprint for collision.

@export var footprint_cells := Vector2(1, 1):
	set(v):
		footprint_cells = v
		queue_redraw()
@export var height := 96.0:
	set(v):
		height = v
		queue_redraw()
@export var color := Color(0.55, 0.45, 0.35):
	set(v):
		color = v
		queue_redraw()
@export var draw_placeholder := true:
	set(v):
		draw_placeholder = v
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := CollisionPolygon2D.new()
	shape.polygon = Iso.footprint(footprint_cells)
	add_child(shape)


func _draw() -> void:
	if not draw_placeholder:
		return
	var f := Iso.footprint(footprint_cells)
	var up := Vector2(0, -height)
	draw_colored_polygon(
		PackedVector2Array([f[3], f[2], f[2] + up, f[3] + up]), color.darkened(0.25)
	)
	draw_colored_polygon(
		PackedVector2Array([f[2], f[1], f[1] + up, f[2] + up]), color.darkened(0.45)
	)
	var top := PackedVector2Array()
	for p in f:
		top.append(p + up)
	draw_colored_polygon(top, color)
