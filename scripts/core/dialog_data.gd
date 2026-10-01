class_name DialogData
## Dialog JSON parsing. File format (assets/dialog/*.json):
##
## {
##   "npc_hello": [ {"speaker": "Name", "text": "...", "set_flag": "optional"} ],
##   "npc_again": { "if_flag": "met_npc", "lines": [...], "else": "npc_hello" }
## }
##
## A plain array is an unconditional dialog. An object entry plays `lines` when
## all of its conditions hold, otherwise falls through to the dialog id named
## in `else`. Conditions: `if_flag`, `if_not_flag`, `if_item` (in inventory),
## `if_not_item`. Line actions (applied when the line is shown): `set_flag`,
## `give_item`, `take_item`, `money` (int, +/-).

const MAX_REDIRECTS := 16


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DialogData: missing %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("DialogData: %s is not a JSON object" % path)
		return {}
	return parsed


## Resolves a dialog id to its lines given flags and inventory. Returns [] if unknown.
static func resolve(
	data: Dictionary, id: String, flags: Dictionary, inventory: Array = []
) -> Array:
	var current := id
	for _i in MAX_REDIRECTS:
		var entry = data.get(current)
		if entry is Array:
			return _normalize(entry)
		if not entry is Dictionary:
			return []
		if conditions_hold(entry, flags, inventory):
			return _normalize(entry.get("lines", []))
		current = str(entry.get("else", ""))
	push_error("DialogData: redirect loop at '%s'" % id)
	return []


static func conditions_hold(entry: Dictionary, flags: Dictionary, inventory: Array) -> bool:
	var flag := str(entry.get("if_flag", ""))
	if not flag.is_empty() and not flags.get(flag, false):
		return false
	var not_flag := str(entry.get("if_not_flag", ""))
	if not not_flag.is_empty() and flags.get(not_flag, false):
		return false
	var item := str(entry.get("if_item", ""))
	if not item.is_empty() and not inventory.has(item):
		return false
	var not_item := str(entry.get("if_not_item", ""))
	if not not_item.is_empty() and inventory.has(not_item):
		return false
	return true


static func _normalize(lines) -> Array:
	var out: Array = []
	if not lines is Array:
		return out
	for line in lines:
		if line is String:
			out.append({"speaker": "", "text": line})
		elif line is Dictionary:
			(
				out
				. append(
					{
						"speaker": str(line.get("speaker", "")),
						"text": str(line.get("text", "")),
						"set_flag": str(line.get("set_flag", "")),
						"give_item": str(line.get("give_item", "")),
						"take_item": str(line.get("take_item", "")),
						"money": int(line.get("money", 0)),
					}
				)
			)
	return out
