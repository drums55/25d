extends Node
## Game scene: owns the persistent player + HUD and swaps the room
## (AdventureRoom) underneath. Exits call go_room(); the floating bike opens
## the trip menu (open_travel) and rides the canal (BoatRide -> arrive());
## arrival autosaves. Also: waiting for the tide, room entry scenes and the
## chapter card.
##
## Arrive here from the main menu after GameState.new_game() or load_game().

const BOAT_SCENE := "res://scenes/ride/boat_ride.tscn"
## Story beat that ends chapter 1 (DESIGN 11.8): the box reached บ้านเลขที่ 0.
const CHAPTER_END_FLAG := "chapter1_done"

var _end_pending := false
var _reload_after_dialog := false

@onready var _room_holder: Node2D = $RoomHolder
@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD


func _ready() -> void:
	add_to_group("main")
	SceneRouter.register_host(self)
	GameState.flag_changed.connect(_on_flag)
	Dialog.finished.connect(_on_dialog_finished)
	Dialog.event.connect(_on_dialog_event)
	SceneRouter.go_to(GameState.ROOM_SCENE, GameState.spawn, false)
	if not GameState.has_flag("intro_done"):
		Dialog.start("intro")


## Exits (Interactable.exit_to) walk the rider into another room.
func go_room(room_id: String, spawn_id := "default") -> void:
	GameState.room = room_id
	GameState.spawn = spawn_id
	SceneRouter.go_to(GameState.ROOM_SCENE, spawn_id)


## The floating bike: pick a known place to ride to.
func open_travel() -> void:
	var choices: Array = []
	for id in Rooms.TRAVEL:
		var place: Dictionary = Rooms.TRAVEL[id]
		var need := str(place["flag"])
		if id == GameState.room or (not need.is_empty() and not GameState.has_flag(need)):
			continue
		choices.append([place["name"], travel.bind(id)])
	_hud.show_choices("ขับรถลอยน้ำไปไหนดี", choices)


## Ride the canal to `dest` (or arrive at once with Settings.skip_ride).
func travel(dest: String) -> void:
	_hud.hide_overlay()
	if Settings.skip_ride:
		arrive(dest)
		return
	var seed := hash([GameState.room, dest, GameState.day, GameState.flags.size()])
	BoatRide.pending = {
		"dest": dest,
		"name": Rooms.TRAVEL.get(dest, {}).get("name", dest),
		"track": BoatTrack.generate(seed),
	}
	SceneRouter.go_to(BOAT_SCENE, "")


## End of a ride (or a skipped one): into the destination room.
func arrive(dest: String, bumps := 0) -> void:
	go_room(dest, "from_bike")
	if bumps >= 4:
		GameState.notice.emit("ชนมา %d ครั้ง ... กล่องในกระเป๋าบ่นเป็นเสียงฟู่" % bumps)


func load_room(room_path: String, spawn_id: String) -> bool:
	var packed := load(room_path) as PackedScene
	if packed == null:
		push_error("Main: cannot load room %s" % room_path)
		return false
	var node := packed.instantiate()
	if _player.get_parent():
		_player.get_parent().remove_child(_player)
	for old in _room_holder.get_children():
		_room_holder.remove_child(old)
		old.queue_free()
	if node is BoatRide:
		_room_holder.add_child(node)
		_hud.set_riding(true)
		return true
	var room := node as IsoRoom
	if room == null:
		push_error("Main: %s root is not an IsoRoom" % room_path)
		node.free()
		return false
	_hud.set_riding(false)
	_room_holder.add_child(room)
	room.get_world().add_child(_player)
	_player.global_position = room.get_spawn_position(spawn_id)
	_player.cancel_order()
	_player.camera.make_current()
	_fit_camera(room)
	_hud.show_title(room.room_title)
	var enter: Dictionary = Rooms.get_room(GameState.room).get("enter", {})
	if not enter.is_empty() and not GameState.has_flag(enter["flag"]):
		GameState.set_flag(enter["flag"])
		Dialog.start.call_deferred(enter["dialog"])
	return true


func _on_flag(flag: String, value: bool) -> void:
	if value and flag == CHAPTER_END_FLAG:
		_end_pending = true


## Dialog line events the game reacts to.
func _on_dialog_event(event_name: String) -> void:
	if event_name == "wait_tide":
		# the bench: two hours pass, the tide turns, the room comes back the
		# other way round once the dialog ends
		GameState.set_tide("low" if GameState.tide == "high" else "high")
		_reload_after_dialog = true


func _on_dialog_finished(_id: String) -> void:
	if _reload_after_dialog:
		_reload_after_dialog = false
		go_room(GameState.room, "default")
	if not _end_pending:
		return
	_end_pending = false
	var body := (
		"กล่องทองเหลืองถึงบ้านเลขที่ 0 แล้ว ... แต่บ้านหลังนี้ไม่มีคนอยู่ มีแต่เครื่องสูบน้ำ"
		+ "ที่ใครบางคนปิดไว้เมื่อสามสิบปีก่อน กับเสียงผู้หญิงในกล่องที่บอกว่า 'อย่าเพิ่ง'\n\n"
		+ "(บทที่ 2 ยังไม่ได้สร้าง — ขอบคุณที่เล่นถึงตรงนี้)"
	)
	_hud.show_overlay(
		"จบบทที่ 1", body, [["เดินเล่นต่อ", _hud.hide_overlay], ["หน้าแรก", go_title]]
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
