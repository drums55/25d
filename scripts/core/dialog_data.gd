class_name DialogData
## Dialog JSON parsing. File format (assets/dialog/*.json):
##
## {
##   "npc_hello": [ {"speaker": "Name", "text": "...", "set_flag": "optional"} ],
##   "npc_again": { "if_flag": "met_npc", "lines": [...], "else": "npc_hello" }
## }
##
## A plain array is an unconditional dialog. An object entry plays `lines` when
## `if_flag` is set (or when it has no `if_flag`), otherwise falls through to
## the dialog id named in `else`.

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


## Resolves a dialog id to its lines given the current flags. Returns [] if unknown.
static func resolve(data: Dictionary, id: String, flags: Dictionary) -> Array:
	var current := id
	for _i in MAX_REDIRECTS:
		var entry = data.get(current)
		if entry is Array:
			return _normalize(entry)
		if not entry is Dictionary:
			return []
		var flag := str(entry.get("if_flag", ""))
		if flag.is_empty() or flags.get(flag, false):
			return _normalize(entry.get("lines", []))
		current = str(entry.get("else", ""))
	push_error("DialogData: redirect loop at '%s'" % id)
	return []


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
					}
				)
			)
	return out
