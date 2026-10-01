class_name Hud
extends CanvasLayer
## On-screen UI: status (hearts/money/items), notices, dialog box, room title.
## No buttons: everything is point & click (tap an enemy to attack it).

const TITLE_HOLD := 1.6
const TITLE_FADE := 0.6
const NOTICE_HOLD := 2.2

var _title_tween: Tween
var _notices: Array[String] = []
var _notice_busy := false
var _last_slot := -1

@onready var _title: Label = %RoomTitle
@onready var _hearts: Label = %Hearts
@onready var _money: Label = %Money
@onready var _items: Label = %Items
@onready var _notice: Label = %Notice
@onready var _clock: Label = %Clock
@onready var _board: JobBoard = %JobBoard
@onready var _deliveries: Label = %Deliveries
@onready var _day_clock: DayClock = %DayClock


func _ready() -> void:
	GameState.hp_changed.connect(_on_hp)
	GameState.money_changed.connect(_on_money)
	GameState.inventory_changed.connect(_on_inventory)
	GameState.notice.connect(_on_notice)
	GameState.time_changed.connect(_on_time)
	GameState.rep_changed.connect(_on_rep)
	Jobs.jobs_changed.connect(_on_jobs)
	_on_time(GameState.day, GameState.tick)
	add_to_group("hud")
	_on_hp(GameState.hp, GameState.MAX_HP)
	_on_money(GameState.money)
	_on_inventory(GameState.inventory)
	_notice.modulate.a = 0.0


func _on_time(_day: int, _tick: int) -> void:
	_on_rep(GameState.rep)
	_on_jobs()
	_day_clock.queue_redraw()
	# 0..5 = day slots, 6 = night; announce each step forward
	var slot := GameState.SLOT_NAMES.size() if GameState.is_night() else GameState.slot()
	if _last_slot >= 0 and slot > _last_slot:
		var name: String = "กลางคืน" if GameState.is_night() else GameState.slot_name()
		_on_notice("เวลาผ่านไป ... ตอนนี้%s" % name)
	_last_slot = slot


## Active deliveries with their countdown, under the day dial.
func _on_jobs() -> void:
	var rows: Array[String] = []
	for job in Jobs.active_jobs():
		var left := int(job.get("due_tick", 0)) - GameState.tick
		var due := (
			"สายแล้ว!"
			if left < 0
			else "เหลือ %d ช่วง" % ceili(left / float(GameState.TICKS_PER_SLOT))
		)
		var where: String = (
			job.get("target_where", "?") if job.get("picked", false) else job["pickup"]["where"]
		)
		var verb := "ส่ง" if job.get("picked", false) else "รับ"
		rows.append("%s · %s %s · %s" % [job["title"], verb, where, due])
	_deliveries.text = "\n".join(rows)


## Reputation line under the money: "ชื่อเสียง  ชาวบ้าน +2 · อู่ +0 · บริษัท -1"
## (time itself is shown by the DayClock dial).
func _on_rep(rep: Dictionary) -> void:
	var parts: Array[String] = []
	for faction in GameState.FACTIONS:
		var name: String = GameState.FACTIONS[faction]
		parts.append("%s %+d" % [name.trim_suffix("ไอน้ำ"), int(rep.get(faction, 0))])
	_clock.text = "ชื่อเสียง  " + " · ".join(parts)


func open_job_board() -> void:
	_board.open()


func _on_hp(hp: int, max_hp: int) -> void:
	_hearts.text = "♥".repeat(hp) + "♡".repeat(max_hp - hp)


func _on_money(money: int) -> void:
	_money.text = "฿ %d / หนี้ค่าเช่า %d" % [money, GameState.RENT_DUE]


func _on_inventory(inventory: Array) -> void:
	var names: Array[String] = []
	for item in inventory:
		names.append(GameState.item_name(item))
	_items.text = "" if names.is_empty() else "กระเป๋า: " + ", ".join(names)


func _on_notice(text: String) -> void:
	_notices.append(text)
	if not _notice_busy:
		_next_notice()


func _next_notice() -> void:
	if _notices.is_empty():
		_notice_busy = false
		return
	_notice_busy = true
	_notice.text = _notices.pop_front()
	_notice.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_notice, "modulate:a", 1.0, 0.2)
	tween.tween_interval(NOTICE_HOLD)
	tween.tween_property(_notice, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_next_notice)


func show_title(text: String) -> void:
	if _title_tween:
		_title_tween.kill()
	_title.text = text
	_title.modulate.a = 0.0
	if text.is_empty():
		return
	_title_tween = create_tween()
	_title_tween.tween_property(_title, "modulate:a", 1.0, TITLE_FADE)
	_title_tween.tween_interval(TITLE_HOLD)
	_title_tween.tween_property(_title, "modulate:a", 0.0, TITLE_FADE)
