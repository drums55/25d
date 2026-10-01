extends Node
## Game scene: owns the persistent player + HUD, swaps the place (LocationRoom)
## underneath, runs the day clock in real time, tints the light by time and
## rain, and handles sleeping (day slip) and the endings.
##
## Arrive here from the main menu after GameState.new_game() or load_game().

## Tint by hour of the day (07..23) and rain.
const HOUR_TINTS := {
	7: Color(1.0, 0.9, 0.8),
	10: Color(1.0, 1.0, 1.0),
	16: Color(1.0, 0.94, 0.84),
	18: Color(1.0, 0.75, 0.56),
	19: Color(0.66, 0.62, 0.84),
	21: Color(0.42, 0.45, 0.7),
}
const RAIN_TINT := Color(0.78, 0.84, 0.95)
const ENDINGS := {
	"lose_bike":
	[
		"รถโดนยึด",
		(
			"ค้างค่าเช่ารถกับดอกเจ้าหนี้ครบสามครั้ง เฮียเป้งกับเจ้าหนี้มายืนรอที่ปั๊ม\n"
			+ "รถถูกเข็นกลับอู่ ... ไรเดอร์กลายเป็นคนเดินเท้าที่ยังติดหนี้อยู่"
		),
	],
	"suspended":
	[
		"บัญชีถูกระงับ",
		(
			'"บัญชีของคุณถูกระงับชั่วคราว เนื่องจากคะแนนต่ำกว่ามาตรฐานของแพลตฟอร์ม\n'
			+ 'หากมีข้อสงสัย กรุณาติดต่อแชทบอท (ตอบกลับภายใน 7-15 วันทำการ)"'
		),
	],
	"paid_off":
	[
		"ปลดหนี้!",
		(
			"ครบเจ็ดวัน หนี้นอกระบบหมด เจ้าหนี้ยิ้มครั้งแรก\n"
			+ 'แอปเด้งแจ้งเตือน: "ข่าวดี! เราปรับโครงสร้างค่ารอบใหม่ (ลดลง 2 บาท)"'
		),
	],
	"still_owing":
	[
		"ครบ 7 วัน ... หนี้ยังอยู่",
		"ดอกยังเดินทุกเช้า เงินต้นยังเหลือ %d บาท\nพรุ่งนี้ก็ต้องออนไลน์ใหม่ เหมือนเดิม เหมือนทุกวัน",
	],
}
## Riding past this late and the rider falls asleep on the bike.
const FORCE_SLEEP := 26 * 60

var _clock_acc := 0.0

@onready var _room_holder: Node2D = $RoomHolder
@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD


func _ready() -> void:
	add_to_group("main")
	SceneRouter.register_host(self)
	GameState.time_changed.connect(_on_time)
	GameState.game_over.connect(_on_game_over)
	_on_time(GameState.day, GameState.minute)
	SceneRouter.go_to(GameState.LOCATION_SCENE, "arrival", false)
	if Settings.show_hints and GameState.day == 1 and GameState.minute <= GameState.DAY_START + 1:
		GameState.notice.emit(
			'เปิด "แอปไรเดอร์" มุมขวาล่างเพื่อรับงาน · แตะรถตัวเองเพื่อดูแผนที่และขี่ไป'
		)


func _process(delta: float) -> void:
	if (
		GameState.clock_paused
		or GameState.input_locked
		or Dialog.is_active()
		or not GameState.finished.is_empty()
	):
		return
	_clock_acc += delta
	var spm := Settings.seconds_per_minute()
	if _clock_acc >= spm:
		var whole := floorf(_clock_acc / spm)
		_clock_acc -= whole * spm
		GameState.advance_minutes(whole)
	if GameState.minute >= FORCE_SLEEP:
		GameState.notice.emit("ตีสองแล้ว ... หลับคาเบาะรถ")
		sleep()


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
	_player.cancel_order()
	_fit_camera(room)
	_hud.show_title(room.room_title)
	return true


static func hour_tint(minute: float) -> Color:
	var hour := int(minute / 60.0) % 24
	if hour < 7:
		return HOUR_TINTS[21]
	var best := 7
	for h in HOUR_TINTS:
		if h <= hour:
			best = maxi(best, h)
	return HOUR_TINTS[best]


func _on_time(_day: int, minute: float) -> void:
	var target := hour_tint(minute)
	if City.has_city() and City.rain_now() > 0:
		target *= RAIN_TINT
	# Tint the whole room via modulate. A CanvasModulate node crashed Godot
	# under the GUT runner (signal 11), so it is not used.
	if not _room_holder.modulate.is_equal_approx(target):
		var tween := create_tween()
		tween.tween_property(_room_holder, "modulate", target, 0.8)


## End the day: unfinished orders fail, the slip shows today and tomorrow
## morning's charges (rent + interest); the last day ends the run.
func sleep() -> void:
	_hud.phone.close()
	var slip := Orders.end_day()
	var body := Phone.slip_text(slip)
	if int(slip.get("failed", 0)) > 0:
		body += "\nงานที่ไม่ได้ส่ง %d งาน (โดน 1 ดาวทุกงาน)" % int(slip["failed"])
	if GameState.check_game_over().is_empty() and GameState.day >= GameState.LAST_DAY:
		GameState.end_run()
		return
	if not GameState.finished.is_empty():
		return
	var charges := GameState.start_new_day()
	body += (
		"\n\nเช้าวันที่ %d: ค่าเช่ารถ %d · ดอกเจ้าหนี้ %d%s\nเหลือเงิน %d บาท · หนี้ %d"
		% [
			GameState.day,
			charges["rent"],
			charges["interest"],
			(" · ขาด %d!" % charges["short"]) if charges["short"] > 0 else "",
			GameState.money,
			GameState.debt
		]
	)
	GameState.save_game(0)
	if not GameState.check_game_over().is_empty():
		return
	_hud.show_overlay("สรุปวันที่ %d" % int(slip["day"]), body, [["ออนไลน์ต่อ", _hud.hide_overlay]])


func _on_game_over(reason: String) -> void:
	_hud.phone.close()
	var e: Array = ENDINGS.get(reason, ["จบ", ""])
	var body: String = e[1]
	if reason == "still_owing":
		body = body % GameState.debt
	(
		_hud
		. show_overlay(
			e[0],
			body,
			[["เริ่มใหม่", _restart], ["หน้าแรก", go_title]],
		)
	)


func _restart() -> void:
	GameState.new_game()
	_hud.hide_overlay()
	SceneRouter.go_to(GameState.LOCATION_SCENE, "arrival")


func go_title() -> void:
	GameState.ui_open = false
	GameState.clock_paused = false
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
