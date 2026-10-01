extends Node
## Root scene: owns the persistent player + HUD and swaps rooms underneath.
## Rooms are plain IsoRoom scenes; the player is re-parented into the room's
## y-sorted World node so it sorts against props.

## Tint per day slot (เช้า..ค่ำ) and night.
const SLOT_TINTS := [
	Color(1.0, 0.96, 0.9),
	Color(1.0, 1.0, 0.98),
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.97, 0.92),
	Color(1.0, 0.86, 0.72),
	Color(0.72, 0.68, 0.82),
]
const NIGHT_TINT := Color(0.45, 0.48, 0.7)

@onready var _room_holder: Node2D = $RoomHolder
@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD


func _ready() -> void:
	SceneRouter.register_host(self)
	GameState.time_changed.connect(_on_time)
	_on_time(GameState.day, GameState.tick)
	if not GameState.load_game():
		GameState.new_game()
	SceneRouter.go_to(GameState.room_path, GameState.spawn_id, false)


func load_room(room_path: String, spawn_id: String) -> bool:
	var packed := load(room_path) as PackedScene
	if packed == null:
		push_error("Main: cannot load room %s" % room_path)
		return false
	var room := packed.instantiate() as IsoRoom
	if room == null:
		push_error("Main: %s root is not an IsoRoom" % room_path)
		return false
	_player.get_parent().remove_child(_player)
	for old in _room_holder.get_children():
		_room_holder.remove_child(old)
		old.queue_free()
	_room_holder.add_child(room)
	room.get_world().add_child(_player)
	_player.global_position = room.get_spawn_position(spawn_id)
	_fit_camera(room)
	_hud.show_title(room.room_title)
	return true


func _on_time(_day: int, _tick: int) -> void:
	var target: Color = NIGHT_TINT if GameState.is_night() else SLOT_TINTS[GameState.slot()]
	# Tint the whole room (backdrop, props, player) via modulate. A CanvasModulate
	# node crashed Godot under the GUT runner (signal 11), so it is not used.
	var tween := create_tween()
	tween.tween_property(_room_holder, "modulate", target, 0.8)


func _fit_camera(room: IsoRoom) -> void:
	var cam := _player.camera
	var view := get_viewport().get_visible_rect().size / cam.zoom
	var r := Iso.fit_camera_rect(room.get_camera_rect(), view)
	cam.limit_left = floori(r.position.x)
	cam.limit_top = floori(r.position.y)
	cam.limit_right = ceili(r.end.x)
	cam.limit_bottom = ceili(r.end.y)
	cam.reset_smoothing()
