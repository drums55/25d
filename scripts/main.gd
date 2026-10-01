extends Node
## Root scene: owns the persistent player + HUD and swaps rooms underneath.
## Rooms are plain IsoRoom scenes; the player is re-parented into the room's
## y-sorted World node so it sorts against props.

@onready var _room_holder: Node2D = $RoomHolder
@onready var _player: Player = $Player


func _ready() -> void:
	SceneRouter.register_host(self)
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
	return true


func _fit_camera(room: IsoRoom) -> void:
	var cam := _player.camera
	var view := get_viewport().get_visible_rect().size / cam.zoom
	var r := Iso.fit_camera_rect(room.get_camera_rect(), view)
	cam.limit_left = floori(r.position.x)
	cam.limit_top = floori(r.position.y)
	cam.limit_right = ceili(r.end.x)
	cam.limit_bottom = ceili(r.end.y)
	cam.reset_smoothing()
