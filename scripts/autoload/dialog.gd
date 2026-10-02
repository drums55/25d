extends Node
## Runs one dialog at a time. UI (DialogBox) listens to the signals; gameplay
## code only calls start()/advance()/is_active().

signal started(id: String)
signal line_shown(speaker: String, text: String)
signal skip_typing_requested
signal finished(id: String)
## Line action `"event": "<name>"`: world objects react (e.g. "steam_valve"
## freezes steam-powered patrol bots).
signal event(name: String)

const DIALOG_PATH := "res://assets/dialog/dialog.json"

## Set by the dialog box while the typewriter effect is running.
var typing := false

var _data := {}
var _id := ""
var _lines: Array = []
var _index := -1


func _ready() -> void:
	_data = DialogData.load_file(DIALOG_PATH)


## Dialog ids known to the game (tests check every reference resolves).
func has_dialog(id: String) -> bool:
	return _data.has(id)


func is_active() -> bool:
	return _index >= 0


func start(id: String) -> bool:
	if is_active():
		return false
	_lines = DialogData.resolve(_data, id, GameState.flags, GameState.inventory)
	if _lines.is_empty():
		push_warning("Dialog: unknown or empty dialog '%s'" % id)
		return false
	_id = id
	_index = 0
	started.emit(id)
	_show_current()
	return true


## Plays lines that are not in dialog.json (puzzle results, built-in lines).
func start_lines(lines: Array, id := "adhoc") -> bool:
	if is_active():
		return false
	_lines = DialogData.normalize(lines)
	if _lines.is_empty():
		return false
	_id = id
	_index = 0
	started.emit(id)
	_show_current()
	return true


## Drops the current dialog at once.
func end_now() -> void:
	if not is_active():
		return
	var done_id := _id
	_index = -1
	_lines = []
	_id = ""
	finished.emit(done_id)


func advance() -> void:
	if not is_active():
		return
	if typing:
		skip_typing_requested.emit()
		return
	_index += 1
	if _index >= _lines.size():
		var done_id := _id
		_index = -1
		_lines = []
		_id = ""
		finished.emit(done_id)
		return
	_show_current()


func _show_current() -> void:
	var line: Dictionary = _lines[_index]
	line_shown.emit(line["speaker"], line["text"])
	# Actions after the line is on screen so notices stack above it.
	GameState.set_flag(line.get("set_flag", ""))
	GameState.give_item(line.get("give_item", ""))
	GameState.take_item(line.get("take_item", ""))
	if not str(line.get("event", "")).is_empty():
		event.emit(str(line["event"]))
