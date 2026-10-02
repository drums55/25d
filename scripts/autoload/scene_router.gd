extends CanvasLayer
## Room transitions with a fade. Main registers itself as the room host; exits
## (Main.go_room) and save loading call go_to(). Each arrival autosaves (slot 0).

signal room_changed(room_path: String)

const FADE_TIME := 0.25

var _host: Node = null
var _busy := false
var _fade: ColorRect
var _label: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


## `host` must implement load_room(room_path: String, spawn_id: String) -> bool.
func register_host(host: Node) -> void:
	_host = host


func is_busy() -> bool:
	return _busy


func go_to(room_path: String, spawn_id := "default", fade := true) -> void:
	if _busy or _host == null:
		return
	_busy = true
	GameState.input_locked = true
	if fade:
		await _fade_to(1.0)
	if not is_instance_valid(_host):
		# the game scene went away mid-fade (back to the title, tests)
		_fade.modulate.a = 0.0
		GameState.input_locked = false
		_busy = false
		return
	if _host.load_room(room_path, spawn_id):
		GameState.save_game(0)
		room_changed.emit(room_path)
	if fade:
		await _fade_to(0.0)
	GameState.input_locked = false
	_busy = false


## Full-screen fade to black with a message, hold, then fade back (sleeping,
## new day); callers lock input themselves.
func blackout(message: String, hold := 1.0) -> void:
	if _label == null:
		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 64)
		_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.5))
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.add_child(_label)
	_label.text = message
	await _fade_to(1.0)
	await get_tree().create_timer(hold).timeout
	_label.text = ""
	await _fade_to(0.0)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, FADE_TIME)
	await tween.finished
