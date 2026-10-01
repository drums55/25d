@tool
extends StaticBody2D
## Hit target for testing the attack. Anything with take_hit() on layer 4
## ("hittable") receives player attacks.

signal hit(total: int)

var hits := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 1 | 8  # world + hittable


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
