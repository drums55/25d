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
## PNG name under assets/art/props/ (default: this node's name in snake_case).
## When the file exists it replaces the placeholder block automatically.
@export var art_name := ""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := CollisionPolygon2D.new()
	shape.polygon = Iso.footprint(footprint_cells)
	add_child(shape)
	apply_art()


func get_art_name() -> String:
	return art_name if not art_name.is_empty() else name.to_snake_case()


## Uses assets/art/props/<art_name>.png when present: bottom-centre on origin.
func apply_art() -> bool:
	var tex := ArtLibrary.prop(get_art_name())
	if tex == null:
		return false
	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.texture = tex
	sprite.centered = false
	sprite.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + ArtLibrary.PROP_FOOT_MARGIN)
	sprite.scale = Vector2.ONE / ArtLibrary.ART_SCALE
	add_child(sprite)
	draw_placeholder = false
	return true


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
