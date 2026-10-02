extends Node
## Game scene: owns the persistent player + HUD and swaps the room
## (AdventureRoom) underneath. Exits call go_room(); arrival autosaves.
##
## Arrive here from the main menu after GameState.new_game() or load_game().

## Story beat that ends the A1 slice (DESIGN 11.8): the brass box in hand.
const SLICE_END_FLAG := "got_box"

var _end_pending := false

@onready var _room_holder: Node2D = $RoomHolder
@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD


func _ready() -> void:
	add_to_group("main")
	SceneRouter.register_host(self)
	GameState.flag_changed.connect(_on_flag)
	Dialog.finished.connect(_on_dialog_finished)
	SceneRouter.go_to(GameState.ROOM_SCENE, GameState.spawn, false)
	if not GameState.has_flag("intro_done"):
		Dialog.start("intro")


## Exits (Interactable.exit_to) walk the rider into another room.
func go_room(room_id: String, spawn_id := "default") -> void:
	GameState.room = room_id
	GameState.spawn = spawn_id
	SceneRouter.go_to(GameState.ROOM_SCENE, spawn_id)


func load_room(room_path: String, spawn_id: String) -> bool:
	var packed := load(room_path) as PackedScene
	if packed == null:
		push_error("Main: cannot load room %s" % room_path)
		return false
	var room := packed.instantiate() as IsoRoom
	if room == null:
		push_error("Main: %s root is not an IsoRoom" % room_path)
		return false
	if _player.get_parent():
		_player.get_parent().remove_child(_player)
	for old in _room_holder.get_children():
		_room_holder.remove_child(old)
		old.queue_free()
	_room_holder.add_child(room)
	room.get_world().add_child(_player)
	_player.global_position = room.get_spawn_position(spawn_id)
	_player.cancel_order()
	_player.camera.make_current()
	_fit_camera(room)
	_hud.show_title(room.room_title)
	return true


func _on_flag(flag: String, value: bool) -> void:
	if value and flag == SLICE_END_FLAG:
		_end_pending = true


func _on_dialog_finished(_id: String) -> void:
	if not _end_pending:
		return
	_end_pending = false
	(
		_hud
		. show_overlay(
			"จบตอนทดลอง",
			(
				'ได้กล่องทองเหลืองมาแล้ว ... มันอุ่น มันเต้น และมันต้องไป "บ้านเลขที่ 0"\n'
				+ "ที่ไม่มีอยู่ในแผนที่ไหนเลย\n\n(บทที่ 1 ยังมีต่อ — ขอบคุณที่ลองเล่น)"
			),
			[["เดินเล่นต่อ", _hud.hide_overlay], ["หน้าแรก", go_title]],
		)
	)


func go_title() -> void:
	GameState.ui_open = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _fit_camera(room: IsoRoom) -> void:
	var cam := _player.camera
	var view := get_viewport().get_visible_rect().size / cam.zoom
	var r := Iso.fit_camera_rect(room.get_camera_rect(), view)
	cam.limit_left = floori(r.position.x)
	cam.limit_top = floori(r.position.y)
	cam.limit_right = ceili(r.end.x)
	cam.limit_bottom = ceili(r.end.y)
	cam.reset_smoothing()
