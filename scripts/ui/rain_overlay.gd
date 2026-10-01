class_name RainOverlay
extends Control
## Screen-space rain streaks (level 1 rain, 2 heavy) over the room, under the
## HUD widgets. Purely visual; riding effects live in City/Weather.

const DROPS := {1: 90, 2: 220}

var level := 0:
	set(v):
		if v != level:
			level = v
			_seed_drops()
		visible = level > 0
var _drops: PackedVector3Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _seed_drops() -> void:
	_drops.clear()
	for i in DROPS.get(level, 0):
		_drops.append(Vector3(randf(), randf(), randf_range(0.6, 1.0)))


func _process(delta: float) -> void:
	if not visible:
		return
	var speed := 1.4 if level == 2 else 1.0
	for i in _drops.size():
		var d := _drops[i]
		d.y += delta * speed * d.z
		d.x -= delta * 0.12 * speed
		if d.y > 1.0:
			d = Vector3(randf() * 1.1, 0.0, d.z)
		_drops[i] = d
	queue_redraw()


func _draw() -> void:
	var tint := Color(0.75, 0.85, 1.0, 0.35 if level == 1 else 0.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.15, 0.25, 0.12 * level))
	var len := 40.0 if level == 1 else 64.0
	for d in _drops:
		var p := Vector2(d.x * size.x, d.y * size.y)
		draw_line(p, p + Vector2(-len * 0.25, len) * d.z, tint, 2.0)
