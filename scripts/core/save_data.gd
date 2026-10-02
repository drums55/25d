class_name SaveData
extends RefCounted
## Serializable game progress (v5, rider game P0). The game state is one
## dictionary (GameState.snapshot()); `meta` is what the save-slot list shows.
## Saves older than v5 belong to the old fixed-district game and are ignored.

const VERSION := 6

var state := {}
var meta := {}


func to_dict() -> Dictionary:
	return {"version": VERSION, "meta": meta.duplicate(true), "state": state.duplicate(true)}


static func from_dict(d: Dictionary) -> SaveData:
	if int(d.get("version", 0)) < VERSION:
		return null
	var s := SaveData.new()
	var st = d.get("state", {})
	var m = d.get("meta", {})
	s.state = st if st is Dictionary else {}
	s.meta = m if m is Dictionary else {}
	return s


func write(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return OK


## Returns null when the file is missing, unreadable or from an old version.
static func read(path: String) -> SaveData:
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("SaveData: corrupt save at %s" % path)
		return null
	return from_dict(parsed)
