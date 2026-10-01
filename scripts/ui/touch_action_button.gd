@tool
class_name TouchActionButton
extends Control
## Round on-screen button that presses an InputMap action while a finger is
## on it. Multi-touch safe (handles screen touches in _input) and marks its
## touches handled so the player does not also walk to that spot.

@export var action: StringName = &"attack"
@export var label := "ATK":
	set(v):
		label = v
		queue_redraw()
@export var color := Color(0.95, 0.45, 0.3, 0.55):
	set(v):
		color = v
		queue_redraw()
## Extra touch tolerance beyond the drawn circle, in pixels.
@export var touch_margin := 24.0

var _finger := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func get_radius() -> float:
	return minf(size.x, size.y) * 0.5


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	if not event is InputEventScreenTouch:
		return
	var center := global_position + size * 0.5
	if event.pressed and _finger < 0:
		if event.position.distance_to(center) <= get_radius() + touch_margin:
			_finger = event.index
			Input.action_press(action)
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif not event.pressed and event.index == _finger:
		_release()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _finger >= 0:
			_release()


func _release() -> void:
	_finger = -1
	Input.action_release(action)
	queue_redraw()


func _draw() -> void:
	var r := get_radius()
	var c := size * 0.5
	var pressed := _finger >= 0
	draw_circle(c, r, color.lightened(0.3) if pressed else color)
	draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 3.0)
	var font := get_theme_default_font()
	var fs := int(r * 0.45)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
