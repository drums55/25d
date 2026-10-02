extends Node
## Items, combining and using things (DESIGN 11.5-11.6: Monkey Island, simple).
## All data lives in assets/data/puzzles.json:
##
## {
##   "items":  {"<id>": {"name", "desc", "color"}},
##   "combos": [{"a", "b", "result", "lines": [...]}],      # a + b -> result
##   "uses":   [{"item", "target", "lines": [...], "consume": bool,
##               "if_flag"?, "if_not_flag"?, "if_tide"?}],   # item on a thing
##   "hints":  [{"if_not_flag"?, "if_flag"?, "text": [nudge, clearer, answer]}]
##             # first that holds; one level at a time (owner 2026-10-02: a
##             # hint that gives the answer straight away "isn't fun")
##   "fail":   {"<target or item id>" | "combine" | "*": [line, ...]}
## }
##
## `lines` are dialog lines (same actions as dialog.json: set_flag, give_item,
## take_item, event). A combo takes both ingredients and gives `result`; a use
## takes the item when `consume` is true. Anything else gets a funny "no" from
## `fail` (target first, then item, then "*"), never a punishment.

const DATA_PATH := "res://assets/data/puzzles.json"

var data := {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	data = load_data(DATA_PATH)


static func load_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Puzzles: missing %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func item_name(id: String) -> String:
	return str(data.get("items", {}).get(id, {}).get("name", id))


func item_desc(id: String) -> String:
	return str(data.get("items", {}).get(id, {}).get("desc", ""))


func item_color(id: String) -> Color:
	return Color(str(data.get("items", {}).get(id, {}).get("color", "#b08850")))


## The combo for two items in either order, or {}.
static func find_combo(d: Dictionary, a: String, b: String) -> Dictionary:
	for c in d.get("combos", []):
		if (c["a"] == a and c["b"] == b) or (c["a"] == b and c["b"] == a):
			return c
	return {}


## The use of `item` on `target` whose conditions hold, or {}.
static func find_use(
	d: Dictionary, item: String, target: String, flags: Dictionary, tide := ""
) -> Dictionary:
	for u in d.get("uses", []):
		if u["item"] != item or u["target"] != target:
			continue
		var need := str(u.get("if_flag", ""))
		var never := str(u.get("if_not_flag", ""))
		if not need.is_empty() and not flags.get(need, false):
			continue
		if not never.is_empty() and flags.get(never, false):
			continue
		if u.has("if_tide") and u["if_tide"] != tide:
			continue
		return u
	return {}


## Looking at an item in the bag.
func look(id: String) -> void:
	Dialog.start_lines([{"speaker": item_name(id), "text": item_desc(id)}], "look")


## Item A on item B in the bag. True when they made something.
func combine(a: String, b: String) -> bool:
	if a == b:
		look(a)
		return false
	var c := find_combo(data, a, b)
	if c.is_empty():
		_fail(["combine", b, a])
		return false
	Audio.sfx("combine")
	GameState.take_item(a)
	GameState.take_item(b)
	GameState.give_item(str(c["result"]))
	Dialog.start_lines(c.get("lines", []), "combine")
	return true


## Item on a thing in the room (Interactable.thing_id). True when it worked.
func use(item: String, target: String) -> bool:
	var u := find_use(data, item, target, GameState.flags, GameState.tide)
	if u.is_empty():
		_fail([target, item])
		return false
	Audio.sfx(str(u.get("sfx", "use_ok")))
	if u.get("consume", false):
		GameState.take_item(item)
	Dialog.start_lines(u.get("lines", []), "use_%s_%s" % [item, target])
	return true


func _fail(keys: Array) -> void:
	Audio.sfx("fail", 0.08)
	var fail: Dictionary = data.get("fail", {})
	var pool: Array = []
	for k in keys:
		if fail.has(k):
			pool = fail[k]
			break
	if pool.is_empty():
		pool = fail.get("*", ["ไม่น่าใช่"])
	var line = pool[rng.randi() % pool.size()]
	if line is String:
		line = {"speaker": "ไรเดอร์", "text": line}
	Dialog.start_lines([line], "fail")


## The levels of the first hint whose flags hold: a nudge, then clearer, then
## the answer (a plain string = one level).
static func hint_levels(d: Dictionary, flags: Dictionary) -> Array:
	for h in d.get("hints", []):
		var need := str(h.get("if_flag", ""))
		var never := str(h.get("if_not_flag", ""))
		if not need.is_empty() and not flags.get(need, false):
			continue
		if not never.is_empty() and flags.get(never, false):
			continue
		var t = h["text"]
		return t if t is Array else [str(t)]
	return []


static func hint_text(d: Dictionary, flags: Dictionary, level := 0) -> String:
	var levels := hint_levels(d, flags)
	if levels.is_empty():
		return ""
	return str(levels[clampi(level, 0, levels.size() - 1)])


## The nudge as a line of dialogue (DESIGN 11.5: ป้าจุ๋ม on the phone once she
## is a friend, otherwise the rider thinking out loud).
func hint() -> void:
	var text := hint_text(data, GameState.flags)
	if GameState.has_flag("jum_friend"):
		(
			Dialog
			. start_lines(
				[
					{"speaker": "ป้าจุ๋ม (โทรมา)", "text": "ว่าไงลูก ติดอะไรอยู่ ป้ารู้หมดแหละ"},
					{"speaker": "ป้าจุ๋ม (โทรมา)", "text": text},
				],
				"hint"
			)
		)
	else:
		Dialog.start_lines([{"speaker": "ไรเดอร์ (คิดในใจ)", "text": text}], "hint")
