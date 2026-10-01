extends Node
## Global progress: current room, arrival spawn, story flags. Save/load to user://.

signal flag_changed(flag: String, value: bool)
signal money_changed(money: int)
signal inventory_changed(inventory: Array)
signal hp_changed(hp: int, max_hp: int)
## Short player-facing notice (item gained, money, quest update).
signal notice(text: String)
signal time_changed(day: int, tick: int)

const START_ROOM := "res://scenes/rooms/soi_brass.tscn"
const SAVE_PATH := "user://save_0.json"

const MAX_HP := 5
## Rent owed on the steam bike: the running goal of the job loop.
const RENT_DUE := 300
## Item id -> display name (Thai). Items are plain ids in `inventory`.
const ITEMS := {
	"brass_gear": "เฟืองทองเหลืองของลุง",
	"parts_box": "กล่องอะไหล่ของเจ๊หมวย",
	"pressure_valve": "วาล์วแรงดันจากตลาด",
	"hot_noodles": "ก๋วยเตี๋ยวร้อนๆ",
	"machine_oil": "น้ำมันเครื่อง",
	"red_soda": "น้ำแดงถวายศาล",
	"mackerel": "ปลาทูแม่กลอง",
	"boat_garland": "พวงมาลัยผูกหัวเรือ",
}
## Day clock: 6 slots of TICKS_PER_SLOT ticks. Changing rooms costs 1 tick,
## a delivery 2; past DAY_TICKS it is night and only sleeping starts a new day.
const SLOT_NAMES := ["เช้า", "สาย", "เที่ยง", "บ่าย", "เย็น", "ค่ำ"]
const TICKS_PER_SLOT := 2
const DAY_TICKS := 12
const ROOM_CHANGE_TICKS := 1
const DELIVERY_TICKS := 2
const DEFAULT_CARGO_SLOTS := 2

var room_path := START_ROOM
var spawn_id := "default"
var flags := {}
var money := 0:
	set(v):
		money = maxi(v, 0)
		money_changed.emit(money)
var inventory: Array = []
var hp := MAX_HP:
	set(v):
		hp = clampi(v, 0, MAX_HP)
		hp_changed.emit(hp, MAX_HP)
var day := 1
var tick := 0
var cargo_slots := DEFAULT_CARGO_SLOTS
## Entries {id, picked, due_tick}; the Jobs autoload owns the rules.
var active_jobs: Array = []
var done_jobs: Array = []
var failed_jobs: Array = []
## Blocks player input (scene transitions, cutscenes). Dialog blocks separately.
var input_locked := false


func set_flag(flag: String, value := true) -> void:
	if flag.is_empty():
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func has_item(item: String) -> bool:
	return inventory.has(item)


func give_item(item: String) -> void:
	if item.is_empty() or inventory.has(item):
		return
	inventory.append(item)
	inventory_changed.emit(inventory)
	notice.emit("ได้รับ: %s" % item_name(item))


func take_item(item: String) -> bool:
	if not inventory.has(item):
		return false
	inventory.erase(item)
	inventory_changed.emit(inventory)
	notice.emit("ส่งมอบ: %s" % item_name(item))
	return true


func add_money(amount: int) -> void:
	if amount == 0:
		return
	money += amount
	notice.emit(("+%d บาท" if amount > 0 else "%d บาท") % amount)


static func item_name(item: String) -> String:
	return ITEMS.get(item, item)


func slot() -> int:
	return mini(tick / TICKS_PER_SLOT, SLOT_NAMES.size() - 1)


func slot_name() -> String:
	return SLOT_NAMES[slot()]


func is_night() -> bool:
	return tick >= DAY_TICKS


func advance_time(ticks: int) -> void:
	if ticks <= 0:
		return
	var was_night := is_night()
	tick += ticks
	time_changed.emit(day, tick)
	if is_night() and not was_night:
		notice.emit("ค่ำแล้ว กลับไปนอนที่วินฯ ก่อนเริ่มวันใหม่")


func new_day() -> void:
	day += 1
	tick = 0
	hp = MAX_HP
	time_changed.emit(day, tick)
	notice.emit("วันที่ %d" % day)


func new_game() -> void:
	room_path = START_ROOM
	spawn_id = "default"
	flags = {}
	money = 0
	inventory = []
	hp = MAX_HP
	day = 1
	tick = 0
	cargo_slots = DEFAULT_CARGO_SLOTS
	active_jobs = []
	done_jobs = []
	failed_jobs = []
	time_changed.emit(day, tick)


func to_save_data() -> SaveData:
	var s := SaveData.new()
	s.room_path = room_path
	s.spawn_id = spawn_id
	s.flags = flags.duplicate(true)
	s.money = money
	s.inventory = inventory.duplicate()
	s.hp = hp
	s.day = day
	s.tick = tick
	s.cargo_slots = cargo_slots
	s.active_jobs = active_jobs.duplicate(true)
	s.done_jobs = done_jobs.duplicate()
	s.failed_jobs = failed_jobs.duplicate()
	return s


func apply_save_data(s: SaveData) -> void:
	room_path = s.room_path if ResourceLoader.exists(s.room_path) else START_ROOM
	spawn_id = s.spawn_id
	flags = s.flags.duplicate(true)
	money = s.money
	inventory = s.inventory.duplicate()
	inventory_changed.emit(inventory)
	hp = s.hp if s.hp > 0 else MAX_HP
	day = maxi(s.day, 1)
	tick = maxi(s.tick, 0)
	cargo_slots = maxi(s.cargo_slots, DEFAULT_CARGO_SLOTS)
	active_jobs = s.active_jobs.duplicate(true)
	done_jobs = s.done_jobs.duplicate()
	failed_jobs = s.failed_jobs.duplicate()
	time_changed.emit(day, tick)


func save_game(path := SAVE_PATH) -> bool:
	var err := to_save_data().write(path)
	if err != OK:
		push_error("GameState: save failed (%s)" % error_string(err))
	return err == OK


func load_game(path := SAVE_PATH) -> bool:
	var s := SaveData.read(path)
	if s == null:
		return false
	apply_save_data(s)
	return true


func delete_save(path := SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
