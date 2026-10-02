extends Node
## Game scene: owns the persistent player + HUD and swaps the room
## (AdventureRoom) underneath. Exits call go_room(); the floating bike opens
## the trip menu (open_travel) and rides the canal (BoatRide -> arrive());
## arrival autosaves. Also: waiting for the tide, room entry scenes and the
## chapter card.
##
## Arrive here from the main menu after GameState.new_game() or load_game().

const BOAT_SCENE := "res://scenes/ride/boat_ride.tscn"
## Flag that ends each chapter -> [title, card text, next chapter or 0].
const CHAPTERS := {
	"chapter1_done":
	[
		"จบบทที่ 1",
		(
			"กล่องทองเหลืองถึงบ้านเลขที่ 0 แล้ว ... แต่บ้านหลังนี้ไม่มีคนอยู่ มีแต่เครื่องสูบน้ำ"
			+ "ที่ใครบางคนปิดไว้เมื่อสามสิบปีก่อน กับเสียงผู้หญิงในกล่องที่บอกว่า 'อย่าเพิ่ง'"
		),
		2,
	],
	"chapter2_done":
	[
		"จบบทที่ 2",
		(
			"หนี้ของทั้งซอยถูกซื้อโดยบริษัทที่คุมเครื่องสูบน้ำ ซอยส่งไวคือแก้มลิงลับ"
			+ " และกุญแจในกล่องคือทางเดียวที่จะเปลี่ยนทิศน้ำ ... ถ้ากล้าให้ซอยจมหนึ่งคืน\n\n"
			+ "บทที่ 3: คืนตีสาม"
		),
		3,
	],
}
## Spoken when a chapter starts.
const CHAPTER_INTROS := {2: "intro_ch2", 3: "intro_ch3"}
## Chapter 3 happens at night.
const NIGHT_TINT := Color(0.62, 0.66, 0.92)

var _card_pending := ""
var _reload_after_dialog := false
## "sell" / "valve": the big choice card waiting for the dialog to end.
var _choice_after_dialog := ""
var _dialog_after_load := ""

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
	# a save from between chapters: show the card again
	for flag in CHAPTERS:
		var next: int = CHAPTERS[flag][2]
		if GameState.has_flag(flag) and next > 0 and GameState.chapter < next:
			_show_card(flag)


## Next chapter: new day, tide high, wake up at home.
func start_chapter(n: int) -> void:
	_hud.hide_overlay()
	GameState.chapter = n
	GameState.day = n
	GameState.set_flag("ch%d" % n)
	GameState.set_tide("high")
	_dialog_after_load = CHAPTER_INTROS.get(n, "")
	go_room("home", "default")


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
	_hud.show_choices("ขี่เรือเตอร์ไซค์ไปไหนดี", choices)


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
	room.modulate = NIGHT_TINT if GameState.chapter >= 3 else Color.WHITE
	_room_holder.add_child(room)
	room.get_world().add_child(_player)
	_player.global_position = room.get_spawn_position(spawn_id)
	_player.cancel_order()
	_player.camera.make_current()
	_fit_camera(room)
	_hud.show_title(room.room_title)
	var enter: Dictionary = Rooms.get_room(GameState.room).get("enter", {})
	if not _dialog_after_load.is_empty():
		Dialog.start.call_deferred(_dialog_after_load)
		_dialog_after_load = ""
	elif not enter.is_empty() and not GameState.has_flag(enter["flag"]):
		GameState.set_flag(enter["flag"])
		Dialog.start.call_deferred(enter["dialog"])
	return true


func _on_flag(flag: String, value: bool) -> void:
	if value and CHAPTERS.has(flag):
		_card_pending = flag


## Dialog line events the game reacts to.
func _on_dialog_event(event_name: String) -> void:
	if event_name == "wait_tide":
		# the bench: two hours pass, the tide turns, the room comes back the
		# other way round once the dialog ends
		GameState.set_tide("low" if GameState.tide == "high" else "high")
		_reload_after_dialog = true
	elif event_name == "offer_sell":
		_choice_after_dialog = "sell"
	elif event_name == "open_valve":
		_choice_after_dialog = "valve"


func _on_dialog_finished(_id: String) -> void:
	if _reload_after_dialog:
		_reload_after_dialog = false
		go_room(GameState.room, "default")
	if not _choice_after_dialog.is_empty():
		var choice := _choice_after_dialog
		_choice_after_dialog = ""
		if choice == "sell":
			_offer_sell()
		else:
			_offer_valve()
		return
	if _card_pending.is_empty():
		return
	var flag := _card_pending
	_card_pending = ""
	_show_card(flag)


func _show_card(flag: String) -> void:
	var c: Array = CHAPTERS[flag]
	var next: int = c[2]
	var buttons: Array = [["หน้าแรก", go_title]]
	if next > 0:
		buttons.push_front(["ไปบทที่ %d" % next, start_chapter.bind(next)])
	else:
		buttons.push_front(["เดินเล่นต่อ", _hud.hide_overlay])
	_hud.show_overlay(c[0], c[1], buttons)


## เจ๊เกียว relays the company's offer: the box for the debt.
func _offer_sell() -> void:
	(
		_hud
		. show_overlay(
			"ขายกล่องให้บริษัท?",
			(
				"บริษัทป้องกันภัยยื่นข้อเสนอผ่านเจ๊เกียว: ส่งกล่องทองเหลืองคืน แลกกับหนี้ทั้งหมดของคุณ\n"
				+ "ซอยจะเป็นแก้มลิงต่อไป ... แต่คุณจะไม่ต้องกลัวหุ่นทวงหนี้อีกเลย"
			),
			[["ขาย (จบเกม)", end_game.bind("sold")], ["ไม่ขาย", _hud.hide_overlay]]
		)
	)


## The master valve: who is ready, then open it or wait.
func _offer_valve() -> void:
	var have := Endings.allies(GameState.flags)
	var lines: Array[String] = []
	for f in Endings.ALLIES:
		lines.append(("✓ " if have.has(f) else "· ") + str(Endings.ALLIES[f]))
	var body := (
		"เปิดวาล์วหลักตอนตีสาม น้ำจะไหลผ่านซอยก่อนหนึ่งคืน\nคนที่พร้อมช่วยตอนนี้ %d/%d:\n%s"
		% [have.size(), Endings.ALLIES.size(), "\n".join(lines)]
	)
	_hud.show_overlay(
		"เปิดวาล์ว?",
		body,
		[["เปิดเลย (จบเกม)", _open_valve], ["ยังก่อน ไปหาคนช่วย", _hud.hide_overlay]]
	)


func _open_valve() -> void:
	end_game(Endings.for_valve(Endings.allies(GameState.flags).size()))


## The end of the story: the ending card, then a new game or the title.
func end_game(ending: String) -> void:
	GameState.set_flag("ending_" + ending)
	GameState.save_game(0)
	var t: Array = Endings.TEXT[ending]
	_hud.show_overlay(t[0], t[1], [["เล่นใหม่", _new_game], ["หน้าแรก", go_title]])


func _new_game() -> void:
	_hud.hide_overlay()
	GameState.new_game()
	_dialog_after_load = "intro"
	go_room("home", "default")


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
