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

@onready var _title: Label = %RoomTitle
@onready var _hearts: Label = %Hearts
@onready var _money: Label = %Money
@onready var _items: Label = %Items
@onready var _notice: Label = %Notice
@onready var _clock: Label = %Clock
@onready var _board: JobBoard = %JobBoard


func _ready() -> void:
	GameState.hp_changed.connect(_on_hp)
	GameState.money_changed.connect(_on_money)
	GameState.inventory_changed.connect(_on_inventory)
	GameState.notice.connect(_on_notice)
	GameState.time_changed.connect(_on_time)
	_on_time(GameState.day, GameState.tick)
	add_to_group("hud")
	_on_hp(GameState.hp, GameState.MAX_HP)
	_on_money(GameState.money)
	_on_inventory(GameState.inventory)
	_notice.modulate.a = 0.0


func _on_time(day: int, _tick: int) -> void:
	_clock.text = "วันที่ %d · %s" % [day, GameState.slot_name()]


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
