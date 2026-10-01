@tool
extends StaticBody2D
## Hit target for testing the attack. Anything with take_hit() on layer 4
## ("hittable") receives player attacks.

signal hit(total: int)

## Tap area relative to the origin (feet).
@export var pick_rect := Rect2(-50, -170, 100, 200)

var hits := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 1 | 8  # world + hittable
	add_to_group("pickable")
	var tex := ArtLibrary.prop(name.to_snake_case())
	if tex:
		for child in $Body.get_children():
			child.visible = false
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.offset = Vector2(
			-tex.get_width() * 0.5, -tex.get_height() + ArtLibrary.PROP_FOOT_MARGIN
		)
		sprite.scale = Vector2.ONE / ArtLibrary.ART_SCALE
		$Body.add_child(sprite)
		var top := (tex.get_height() - ArtLibrary.PROP_FOOT_MARGIN) / ArtLibrary.ART_SCALE
		$Hits.position.y = -top - 40


func take_hit(_damage: int, from: Vector2) -> void:
	hits += 1
	hit.emit(hits)
	var body := $Body as Node2D
	var push := (global_position - from).normalized() * 10.0
	var tween := create_tween()
	body.modulate = Color(2, 0.6, 0.6)
	body.position = push
	tween.tween_property(body, "modulate", Color.WHITE, 0.2)
	tween.parallel().tween_property(body, "position", Vector2.ZERO, 0.2)
	$Hits.text = str(hits)
