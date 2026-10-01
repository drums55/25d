extends Node
## Global progress: current room, arrival spawn, story flags. Save/load to user://.

signal flag_changed(flag: String, value: bool)

const START_ROOM := "res://scenes/rooms/soi_brass.tscn"
const SAVE_PATH := "user://save_0.json"

var room_path := START_ROOM
var spawn_id := "default"
var flags := {}
## Blocks player input (scene transitions, cutscenes). Dialog blocks separately.
var input_locked := false


func set_flag(flag: String, value := true) -> void:
	if flag.is_empty():
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func new_game() -> void:
	room_path = START_ROOM
	spawn_id = "default"
	flags = {}


func to_save_data() -> SaveData:
	var s := SaveData.new()
	s.room_path = room_path
	s.spawn_id = spawn_id
	s.flags = flags.duplicate(true)
	return s


func apply_save_data(s: SaveData) -> void:
	room_path = s.room_path if ResourceLoader.exists(s.room_path) else START_ROOM
	spawn_id = s.spawn_id
	flags = s.flags.duplicate(true)


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
