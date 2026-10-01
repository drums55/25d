extends CanvasLayer
## Room transitions with a fade. Main registers itself as the room host; doors
## and save loading call go_to(). Each completed transition autosaves.

signal room_changed(room_path: String)

const FADE_TIME := 0.25

var _host: Node = null
var _busy := false
var _fade: ColorRect


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
	if _host.load_room(room_path, spawn_id):
		GameState.room_path = room_path
		GameState.spawn_id = spawn_id
		GameState.save_game()
		room_changed.emit(room_path)
	if fade:
		await _fade_to(0.0)
	GameState.input_locked = false
	_busy = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, FADE_TIME)
	await tween.finished
