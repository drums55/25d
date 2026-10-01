class_name SaveData
extends RefCounted
## Serializable game progress. Pure data so it can be unit-tested headless.

const VERSION := 4

var room_path := ""
var spawn_id := "default"
var flags := {}
var money := 0
var inventory: Array = []
var hp := -1
var day := 1
var tick := 0
var cargo_slots := 0
var active_jobs: Array = []
var done_jobs: Array = []
var failed_jobs: Array = []
var rep := {}


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"room_path": room_path,
		"spawn_id": spawn_id,
		"flags": flags.duplicate(true),
		"money": money,
		"inventory": inventory.duplicate(),
		"hp": hp,
		"day": day,
		"tick": tick,
		"cargo_slots": cargo_slots,
		"active_jobs": active_jobs.duplicate(true),
		"done_jobs": done_jobs.duplicate(),
		"failed_jobs": failed_jobs.duplicate(),
		"rep": rep.duplicate(),
	}


static func from_dict(d: Dictionary) -> SaveData:
	var s := SaveData.new()
	s.room_path = str(d.get("room_path", ""))
	s.spawn_id = str(d.get("spawn_id", "default"))
	var f = d.get("flags", {})
	if f is Dictionary:
		s.flags = f.duplicate(true)
	s.money = int(d.get("money", 0))
	var inv = d.get("inventory", [])
	if inv is Array:
		for item in inv:
			s.inventory.append(str(item))
	s.hp = int(d.get("hp", -1))
	s.day = int(d.get("day", 1))
	s.tick = int(d.get("tick", 0))
	s.cargo_slots = int(d.get("cargo_slots", 0))
	for key in ["active_jobs", "done_jobs", "failed_jobs"]:
		var arr = d.get(key, [])
		if arr is Array:
			s.set(key, arr.duplicate(true))
	var r = d.get("rep", {})
	if r is Dictionary:
		for faction in r:
			s.rep[str(faction)] = int(r[faction])
	for entry in s.active_jobs:
		if entry is Dictionary:
			entry["id"] = str(entry.get("id", ""))
			entry["picked"] = bool(entry.get("picked", false))
			entry["due_tick"] = int(entry.get("due_tick", 0))
	return s


func write(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return OK


## Returns null when the file is missing or unreadable.
static func read(path: String) -> SaveData:
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("SaveData: corrupt save at %s" % path)
		return null
	return from_dict(parsed)
