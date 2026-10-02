extends Node
## Adventure state (DESIGN 11): where the rider is, story flags, the bag
## (inventory), chapter / day and the tide. No money meters, no clock — the
## loan-shark debt is story, not a number to grind. Saves to slots (0 = auto).

signal flag_changed(flag: String, value: bool)
signal inventory_changed(inventory: Array)
## Short player-facing notice.
signal notice(text: String)
signal tide_changed(tide: String)
## The item "on the finger" (tap a bag item, then a thing to use it on).
signal held_changed(item: String)

const ROOM_SCENE := "res://scenes/rooms/adventure_room.tscn"
const SAVE_SLOTS := 3
const START_ROOM := "home"
## Items the rider starts with.
const START_ITEMS := ["debt_book", "gum"]
## The bag holds this many things at once (DESIGN 11.5: keep puzzles small).
const BAG_SIZE := 8

var flags := {}
var inventory: Array = []
var chapter := 1
var day := 1
## "low" / "high" — some ways in only exist at low tide (DESIGN 11.5).
var tide := "low"
## Room id (Rooms.ROOMS key) the rider is in, and the spawn used to get there.
var room := START_ROOM
var spawn := "default"
## Bag item picked up to use / combine ("" = none). Not saved.
var held_item := "":
	set(v):
		held_item = v
		held_changed.emit(v)
## Blocks player input (scene transitions). Dialog blocks separately.
var input_locked := false
## A full-screen UI (menu, end card) is open: taps go to it, not the world.
var ui_open := false


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
	notice.emit("ได้ของ: %s" % item_name(item))


func take_item(item: String) -> bool:
	if not inventory.has(item):
		return false
	if held_item == item:
		held_item = ""
	inventory.erase(item)
	inventory_changed.emit(inventory)
	return true


static func item_name(item: String) -> String:
	return Puzzles.item_name(item)


func set_tide(t: String) -> void:
	if t == tide:
		return
	tide = t
	tide_changed.emit(tide)
	notice.emit("น้ำขึ้นแล้ว" if tide == "high" else "น้ำลงแล้ว")


func new_game() -> void:
	flags = {}
	inventory = START_ITEMS.duplicate()
	chapter = 1
	day = 1
	tide = "low"
	room = START_ROOM
	spawn = "default"
	input_locked = false
	ui_open = false
	held_item = ""
	inventory_changed.emit(inventory)


func snapshot() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"inventory": inventory.duplicate(),
		"chapter": chapter,
		"day": day,
		"tide": tide,
		"room": room,
		"spawn": spawn,
	}


func restore(d: Dictionary) -> void:
	new_game()
	flags = d.get("flags", {})
	inventory = d.get("inventory", [])
	chapter = int(d.get("chapter", 1))
	day = int(d.get("day", 1))
	tide = str(d.get("tide", "low"))
	room = str(d.get("room", START_ROOM))
	spawn = str(d.get("spawn", "default"))
	inventory_changed.emit(inventory)


static func slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot


func save_game(slot := 0, path := "") -> bool:
	var s := SaveData.new()
	s.state = snapshot()
	s.meta = {
		"chapter": chapter,
		"day": day,
		"place": Rooms.title(room),
		"saved_at": Time.get_datetime_string_from_system(false, true),
	}
	var err := s.write(path if not path.is_empty() else slot_path(slot))
	if err != OK:
		push_error("GameState: save failed (%s)" % error_string(err))
	return err == OK


func load_game(slot := 0, path := "") -> bool:
	var s := SaveData.read(path if not path.is_empty() else slot_path(slot))
	if s == null:
		return false
	restore(s.state)
	return true


## {slot: meta} for slots that hold a valid save.
func list_saves() -> Dictionary:
	var out := {}
	for slot in range(0, SAVE_SLOTS + 1):
		var s := SaveData.read(slot_path(slot))
		if s:
			out[slot] = s.meta
	return out


func has_any_save() -> bool:
	return not list_saves().is_empty()


## Most recently written save slot, or -1.
func latest_slot() -> int:
	var best := -1
	var best_time := ""
	var saves := list_saves()
	for slot in saves:
		var t := str(saves[slot].get("saved_at", ""))
		if best == -1 or t > best_time:
			best = slot
			best_time = t
	return best


func delete_save(slot := 0, path := "") -> void:
	var p := path if not path.is_empty() else slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
