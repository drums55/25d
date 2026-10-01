class_name VirtualJoystick
extends Control
## Floating virtual joystick. Touch anywhere inside this control's rect to
## place the base there; dragging presses the move_* actions with analog
## strength, so gameplay only ever reads the InputMap. Uses _input (not
## gui_input) so it works alongside other fingers (multi-touch).

@export var radius := 130.0
## Where the idle (ghost) stick is drawn, relative to this control's size.
@export var rest_anchor := Vector2(0.3, 0.6)
@export var base_color := Color(1, 1, 1, 0.18)
@export var knob_color := Color(1, 1, 1, 0.45)

var output := Vector2.ZERO
var _finger := -1
var _base := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset()


## Converts a knob offset into a stick vector of length 0..1.
static func compute_output(offset: Vector2, max_radius: float, deadzone := 0.0) -> Vector2:
	var length := offset.length()
	if max_radius <= 0.0 or length <= deadzone * max_radius:
		return Vector2.ZERO
	var strength := (
		(minf(length, max_radius) - deadzone * max_radius) / (max_radius * (1.0 - deadzone))
	)
	return offset / length * strength


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger < 0 and get_global_rect().has_point(event.position):
			_finger = event.index
			_base = event.position - global_position
			_knob = _base
			_set_output(Vector2.ZERO)
		elif not event.pressed and event.index == _finger:
			_reset()
	elif event is InputEventScreenDrag and event.index == _finger:
		var offset: Vector2 = event.position - global_position - _base
		_knob = _base + offset.limit_length(radius)
		_set_output(compute_output(offset, radius))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _finger < 0:
		_reset()
	elif what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_finger = -1
		_set_output(Vector2.ZERO)


func _reset() -> void:
	_finger = -1
	_base = size * rest_anchor
	_knob = _base
	_set_output(Vector2.ZERO)


func _set_output(v: Vector2) -> void:
	output = v
	_press("move_right", maxf(v.x, 0.0))
	_press("move_left", maxf(-v.x, 0.0))
	_press("move_down", maxf(v.y, 0.0))
	_press("move_up", maxf(-v.y, 0.0))
	queue_redraw()


func _press(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _draw() -> void:
	var active := _finger >= 0
	var a := 1.0 if active else 0.6
	draw_circle(_base, radius, base_color * Color(1, 1, 1, a))
	draw_arc(_base, radius, 0.0, TAU, 48, knob_color * Color(1, 1, 1, a), 3.0)
	draw_circle(_knob, radius * 0.42, knob_color * Color(1, 1, 1, a))
