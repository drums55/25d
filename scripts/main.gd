extends Node
## Game scene: owns the persistent player + HUD and swaps the room
## (AdventureRoom) underneath. Exits call go_room(); the floating bike opens
## the map (open_travel) and rides the canal (BoatRide -> arrive());
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
## Spawn id for rebuilding the room around the rider where they stand.
const KEEP_SPOT := "keep"
## Spoken when a chapter starts.
const CHAPTER_INTROS := {2: "intro_ch2", 3: "intro_ch3"}
## Chapter 3 happens at night.
const NIGHT_TINT := Color(0.62, 0.66, 0.92)
const DAWN_TINT := Color(1.0, 0.86, 0.74)
## Where each ending is staged, the rider's pose there and the tint
## (owner 2026-10-02: the endings get their own moves too).
const ENDING_SCENES := {
	"five_stars":
	{
		"room": "noodle_boat",
		"pose": "cheer",
		"tint": DAWN_TINT,
		"caption": "เช้าแรกที่ซอยส่งไวโผล่พ้นน้ำ"
	},
}
const ENDING_STINGS := {"five_stars": "sting_good"}
## Seconds the ending tableau plays (after the fade) before anything is written on it.
const ENDING_HOLD := 3.0
## The convoy ride (DESIGN 12.8): from the station to the wedding boat.
const CONVOY_DEST := "noodle_boat"

var _card_pending := ""
var _reload_after_dialog := false
var _kept_position := Vector2.ZERO
## "valve": the valve card waiting for the dialog to end.
var _choice_after_dialog := ""
## True while the convoy ride is on: arriving = the ending.
var _convoy := false
var _dialog_after_load := ""
## The ending being staged ("" while playing).
var _ending := ""
var _ending_waiting := false

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
## The bike opens the map: pins only on the places the rider knows
## (Rooms.TRAVEL flags), the boat where they are now.
func open_travel() -> void:
	var places: Array = []
	for id in Rooms.TRAVEL:
		var place: Dictionary = Rooms.TRAVEL[id]
		var need := str(place["flag"])
		if not need.is_empty() and not GameState.has_flag(need):
			continue
		var closed := ""
		if place.has("tide") and place["tide"] != GameState.tide:
			closed = str(place.get("closed", "ตอนนี้ไปไม่ได้"))
		places.append({"id": id, "name": place["name"], "at": place["map"], "closed": closed})
	var here: Vector2 = Rooms.TRAVEL.get(GameState.room, Rooms.TRAVEL["pier"])["map"]
	_hud.show_map(here, places, travel, NIGHT_TINT if GameState.chapter >= 3 else Color.WHITE)


## Ride the canal to `dest`: a short skippable cutscene (owner 2026-10-02:
## the playable ride "felt like padding" — hits never mattered). `play` =
## the steerable runner, kept for story set pieces.
func travel(dest: String, play := false) -> void:
	_hud.hide_overlay()
	Audio.sfx("bike_start")
	if BoatRide.skip_all:
		arrive(dest)
		return
	var seed := hash([GameState.room, dest, GameState.day, GameState.flags.size()])
	BoatRide.pending = {
		"dest": dest,
		"name": Rooms.TRAVEL.get(dest, {}).get("name", dest),
		"track": BoatTrack.generate(seed),
		"play": play,
		"seed": seed,
		"tint": NIGHT_TINT if GameState.chapter >= 3 else Color.WHITE,
	}
	SceneRouter.go_to(BOAT_SCENE, "")


## End of a ride (or a skipped one): into the destination room. After the
## convoy, that is the ending.
func arrive(dest: String, _bumps := 0) -> void:
	if _convoy:
		_convoy = false
		end_game(Endings.ENDING)
		return
	go_room(dest, "from_bike")


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
		Audio.ambience("engine")
		return true
	var room := node as IsoRoom
	if room == null:
		push_error("Main: %s root is not an IsoRoom" % room_path)
		node.free()
		return false
	_hud.set_riding(false)
	Audio.for_room(GameState.room, _ending)
	room.modulate = NIGHT_TINT if GameState.chapter >= 3 else Color.WHITE
	if not _ending.is_empty():
		room.modulate = ENDING_SCENES[_ending]["tint"]
	_room_holder.add_child(room)
	room.get_world().add_child(_player)
	if spawn_id == KEEP_SPOT:
		_player.global_position = _kept_position
	else:
		_player.global_position = room.get_spawn_position(spawn_id)
	_player.cancel_order()
	_player.camera.make_current()
	_fit_camera(room)
	_hud.show_title(room.room_title)
	var enter: Dictionary = Rooms.get_room(GameState.room).get("enter", {})
	if not _ending.is_empty():
		_stage_ending.call_deferred()
	elif not _dialog_after_load.is_empty():
		Dialog.start.call_deferred(_dialog_after_load)
		_dialog_after_load = ""
	elif not enter.is_empty() and not GameState.has_flag(enter["flag"]):
		GameState.set_flag(enter["flag"])
		Dialog.start.call_deferred(enter["dialog"])
	return true


## A flag changed what this room holds: rebuild it once the talking is over,
## the rider staying where they are.
func refresh_room() -> void:
	if Dialog.is_active():
		_reload_after_dialog = true
	else:
		_refresh_now.call_deferred()


func _refresh_now() -> void:
	if _room_holder.get_child_count() == 0 or not _room_holder.get_child(0) is AdventureRoom:
		return
	# GameState.spawn keeps the real door used, so a save loads somewhere sane
	_kept_position = _player.global_position
	SceneRouter.go_to(GameState.ROOM_SCENE, KEEP_SPOT, false)


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
	elif event_name == "reload_room":
		# the room changes after this scene (the wedding moves ลุงโต๊ะสาม)
		_reload_after_dialog = true
	elif event_name == "open_valve":
		_choice_after_dialog = "valve"


func _on_dialog_finished(_id: String) -> void:
	if _reload_after_dialog:
		_reload_after_dialog = false
		_refresh_now()
	if not _choice_after_dialog.is_empty():
		_choice_after_dialog = ""
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
	Audio.sting("sting_chapter")
	var buttons: Array = [["หน้าแรก", go_title]]
	if next > 0:
		buttons.push_front(["ไปบทที่ %d" % next, start_chapter.bind(next)])
	else:
		buttons.push_front(["เดินเล่นต่อ", _hud.hide_overlay])
	_hud.show_overlay(c[0], c[1], buttons)


## The master valve (DESIGN 12.8): the plan must be complete, else คุณนายวรรณ
## counts what is missing; complete = turn it and lead the convoy out.
func _offer_valve() -> void:
	var flags := GameState.flags
	if not Endings.ready(flags):
		_hud.show_overlay(
			"ซอยยังไม่พร้อม",
			(
				"คุณนายวรรณนับให้:\n%s\n\nเอากุญแจออกก่อน ... ไปตามให้ครบแล้วค่อยกลับมา"
				% Endings.checklist(flags)
			),
			[["ไปตามให้ครบก่อน", _hud.hide_overlay]]
		)
		return
	_hud.show_overlay(
		"เปิดวาล์ว",
		(
			(
				"%s\n\nครบแล้ว ทั้งซอยอยู่บนเรือ หุ่นบริษัทรอตีสี่\n"
				+ "บิดครึ่งรอบ แล้วรีบขึ้นเรือเตอร์ไซค์นำขบวนออกคลองใหญ่ก่อนน้ำมา"
			)
			% Endings.checklist(flags)
		),
		[["บิดเลย", _open_valve], ["ยังก่อน", _hud.hide_overlay]]
	)


## Turn it: the water turns, and the whole soi follows the rider down the
## big canal (BoatRide convoy; hits = someone gets wet, never the ending).
func _open_valve() -> void:
	_hud.hide_overlay()
	GameState.set_flag("valve_opened")
	GameState.save_game(0)
	_convoy = true
	Audio.sfx("bike_start")
	if BoatRide.skip_all:
		arrive(CONVOY_DEST)
		return
	var seed := hash(["convoy", GameState.flags.size()])
	BoatRide.pending = {
		"dest": CONVOY_DEST,
		"name": "ขบวนเรือตีสาม",
		"track": BoatTrack.generate(seed, BoatRide.CONVOY_TIME),
		"play": true,
		"convoy": true,
		"seed": seed,
		"tint": NIGHT_TINT,
	}
	SceneRouter.go_to(BOAT_SCENE, "")


## The end of the story: the ending card, then a new game or the title.
func end_game(ending: String) -> void:
	GameState.set_flag("ending_" + ending)
	GameState.save_game(0)
	_hud.hide_overlay()
	_ending = ending
	go_room(ENDING_SCENES[ending]["room"], "default")


## The ending tableau (owner 2026-10-02: "the text covered the ending before I
## could see it" - the hold used to start before the fade-in had even ended).
## Now: wait for the fade to finish, let the scene play with nothing on top,
## then the caption and "แตะเพื่อดูตอนจบ"; the card comes only on a tap.
func _stage_ending() -> void:
	var scene: Dictionary = ENDING_SCENES[_ending]
	var ending := _ending
	_player.cancel_order()
	_player.facing = Iso.Dir.S
	_player.rig.set_facing(Iso.Dir.S)
	_player.rig.set_pose(scene["pose"])
	while SceneRouter.is_busy():
		await get_tree().process_frame
	GameState.input_locked = true
	await get_tree().create_timer(ENDING_HOLD).timeout
	if not is_inside_tree() or _ending != ending:
		return
	_hud.show_title(scene["caption"])
	Audio.sting(ENDING_STINGS.get(ending, "sting_chapter"))
	GameState.notice.emit("แตะเพื่อดูตอนจบ")
	_ending_waiting = true


## The ending card, after the tableau (a tap while _ending_waiting).
func show_ending_card() -> void:
	if not _ending_waiting:
		return
	_ending_waiting = false
	var t: Array = Endings.TEXT[_ending]
	_hud.show_overlay(t[0], t[1], [["บทส่งท้าย ▶", _show_epilogue.bind(0)], ["หน้าแรก", go_title]])


## The epilogue cards, one per character (DESIGN 12.8 — the part of the
## ending that depends on the side plots and on who fell in the canal).
func _show_epilogue(i: int) -> void:
	var cards := Endings.epilogues(GameState.flags)
	if i >= cards.size():
		_hud.show_overlay(
			"จบ",
			"บ้านเลขที่ 0\n\nขอบคุณที่เป็นแก้มลิง",
			[["เล่นใหม่", _new_game], ["หน้าแรก", go_title]]
		)
		return
	var c: Dictionary = cards[i]
	var last := i == cards.size() - 1
	_hud.show_portrait_card(
		str(c["who"]),
		str(c["name"]),
		str(c["text"]),
		[["จบ" if last else "ต่อไป ▶", _show_epilogue.bind(i + 1)]],
		"%d / %d" % [i + 1, cards.size()]
	)


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if _ending_waiting and touch != null and touch.pressed:
		get_viewport().set_input_as_handled()
		show_ending_card()


func _new_game() -> void:
	_hud.hide_overlay()
	_ending = ""
	_ending_waiting = false
	_player.rig.set_pose("")
	GameState.input_locked = false
	GameState.new_game()
	_dialog_after_load = "intro"
	go_room("home", "default")


func go_title() -> void:
	GameState.ui_open = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


## Zoom so the room's painting fills the screen above the bag strip, then
## clamp the camera to it; the camera may run on below the painting by the
## strip's height, so the room's bottom edge can rise above the bag.
func _fit_camera(room: IsoRoom) -> void:
	var cam := _player.camera
	var rect := room.get_view_rect()
	var screen := get_viewport().get_visible_rect().size
	var bag := _hud.bottom_reserved()
	var zoom := Iso.fill_zoom(rect.size, screen - Vector2(0, bag))
	cam.zoom = Vector2(zoom, zoom)
	var view := screen / zoom
	var r := Iso.fit_camera_rect(rect, view)
	cam.limit_left = floori(r.position.x)
	cam.limit_top = floori(r.position.y)
	cam.limit_right = ceili(r.end.x)
	cam.limit_bottom = ceili(maxf(r.end.y, rect.end.y + bag / zoom))
	cam.reset_smoothing()
