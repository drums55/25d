class_name AdventureRoom
extends IsoRoom
## The room the rider is in (GameState.room), built from its Rooms recipe at
## runtime before IsoRoom bakes the navmesh: props (placeholder blocks when no
## art), items lying around (and the ones seized for the debt, recipe
## "seized" = spots on เจ๊เกียว's raft), named people, exits and the living
## gates (collectors).
## Entries can depend on flags and the tide (Rooms.present_now).

const PROP_SCENE := preload("res://scenes/props/prop_block.tscn")
const NPC_SCENE := preload("res://scenes/props/npc.tscn")
const INT_SCENE := preload("res://scenes/props/interactable.tscn")
const BOT_SCENE := preload("res://scenes/props/patrol_bot.tscn")
const JE_DEFAULT := "je_muay"

## Set by tests to build a given room without moving the rider.
var room_override := ""
var room_id := ""
## [CharacterView, {flag: anim}] of people with special poses (recipe "poses").
var _posers: Array = []


func _ready() -> void:
	if Engine.is_editor_hint():
		super._ready()
		return
	room_id = room_override if not room_override.is_empty() else GameState.room
	art_name = room_id
	_build(Rooms.get_room(room_id))
	super._ready()
	GameState.flag_changed.connect(_on_flag)
	_apply_poses()


func _build(r: Dictionary) -> void:
	grid_size = r["grid"]
	floor_color_a = r["floor"][0]
	floor_color_b = r["floor"][1]
	wall_color = r["wall"]
	room_title = r.get("title", room_id)
	var world := get_world()
	var flags := GameState.flags
	var tide := GameState.tide
	var i := 0
	for p in r.get("props", []) + r.get("extra_props", []):
		if Rooms.present_now(p, flags, tide):
			_add_prop(world, p, "Prop%d" % i)
		i += 1
	i = 0
	for p in r.get("pickups", []):
		if Rooms.present_now(p, flags, tide):
			_add_pickup(world, p, "Pickup%d" % i)
		i += 1
	i = 0
	for cell in r.get("seized", []):
		var item := _seized_at(i, flags)
		if not item.is_empty():
			_add_pickup(world, {"item": item, "pos": cell, "label": "ของยึด"}, "Seized%d" % i, true)
		i += 1
	for n in r.get("npcs", []):
		if Rooms.present_now(n, flags, tide):
			_add_npc(world, n)
	i = 0
	for e in r.get("exits", []):
		if Rooms.present_now(e, flags, tide):
			_add_exit(world, e, "Exit%d" % i)
		i += 1
	for b in r.get("bots", []):
		if Rooms.present_now(b, flags, tide):
			_add_bot(world, b)
	var spawns := get_node("Spawns")
	var cells: Dictionary = r.get("spawns", {})
	for id in cells:
		var m := Marker2D.new()
		m.name = id
		m.position = Iso.grid_to_world(cells[id])
		spawns.add_child(m)


func _add_prop(world: Node, p: Dictionary, node_name: String) -> void:
	var prop := PROP_SCENE.instantiate()
	prop.name = node_name
	prop.art_name = p.get("art", "_none")
	prop.footprint_cells = p["foot"]
	prop.height = p.get("h", 80.0)
	prop.color = p.get("color", Color(0.55, 0.45, 0.35))
	prop.position = Iso.grid_to_world(p["pos"])
	var it := INT_SCENE.instantiate() as Interactable
	it.name = "Interactable"
	it.thing_id = p.get("id", "")
	it.dialog_id = p.get("dialog", "")
	it.prompt = p.get("prompt", "ดู")
	it.exit_to = p.get("exit_to", "")
	it.exit_spawn = p.get("exit_spawn", "default")
	it.exit_flag = p.get("exit_flag", "")
	it.locked_dialog = p.get("locked_dialog", "")
	it.action = p.get("action", "")
	prop.add_child(it)
	world.add_child(prop)


## The i-th item เจ๊เกียว's collectors took "for the debt" (flags seized_<item>).
func _seized_at(i: int, flags: Dictionary) -> String:
	var items: Array = []
	for f in flags:
		if flags[f] and str(f).begins_with("seized_"):
			items.append(str(f).trim_prefix("seized_"))
	items.sort()
	return items[i] if i < items.size() else ""


func _add_pickup(world: Node, p: Dictionary, node_name: String, seized := false) -> void:
	var spot := MarkerSpot.new()
	spot.name = node_name
	spot.kind = "item"
	spot.label = p.get("label", "")
	spot.color = Puzzles.item_color(p["item"])
	spot.icon = ArtLibrary.item(p["item"])
	spot.position = Iso.grid_to_world(p["pos"])
	var it := INT_SCENE.instantiate() as Interactable
	it.name = "Interactable"
	it.thing_id = p["item"]
	it.pickup_item = p["item"]
	it.seized = seized
	it.pickup_text = p.get("text", "")
	it.prompt = "เก็บ"
	# the icon is drawn 96 px tall above the spot; a little slack around it
	it.pick_rect = Rect2(-60, -116, 120, 132)
	spot.add_child(it)
	world.add_child(spot)


func _add_npc(world: Node, n: Dictionary) -> void:
	var npc := NPC_SCENE.instantiate() as Node2D
	npc.name = n["id"].to_pascal_case()
	npc.position = Iso.grid_to_world(n["pos"])
	var rig := npc.get_node("Rig")
	rig.character_name = n.get("character", JE_DEFAULT)
	rig.modulate = n.get("tint", Color.WHITE)
	if n.has("poses"):
		_posers.append([rig, n["poses"]])
	var it := npc.get_node("Interactable") as Interactable
	it.thing_id = n["id"]
	it.dialog_id = n.get("dialog", "")
	it.prompt = "คุย"
	world.add_child(npc)
	_name_tag(npc, n.get("name", ""))


func _on_flag(flag: String, _value: bool) -> void:
	_apply_poses()
	if Rooms.condition_flags(Rooms.get_room(room_id)).has(flag) and room_override.is_empty():
		# someone/something should appear or go (owner 2026-10-02: ช่างแดง only came
		# out after leaving and coming back)
		get_tree().call_group("main", "refresh_room")


## Special animations whose flag is set (live: ป้าจุ๋ม grabs the megaphone mid-talk).
func _apply_poses() -> void:
	for p in _posers:
		var view = p[0]
		if not is_instance_valid(view) or not view.has_method("set_pose"):
			continue
		var pose := ""
		for flag in p[1]:
			if GameState.has_flag(flag):
				pose = p[1][flag]
		view.set_pose(pose)


func _add_exit(world: Node, e: Dictionary, node_name: String) -> void:
	var spot := MarkerSpot.new()
	spot.name = node_name
	spot.kind = "exit"
	spot.label = e.get("label", "")
	spot.position = Iso.grid_to_world(e["pos"])
	var it := INT_SCENE.instantiate() as Interactable
	it.name = "Interactable"
	it.thing_id = "exit_%s" % e["to"]
	it.exit_to = e["to"]
	it.exit_spawn = e.get("spawn", "default")
	it.prompt = "ไป"
	# ring on the floor + the bobbing arrow (not the whole column above it,
	# or it would steal taps meant for props behind it)
	it.pick_rect = Rect2(-80, -130, 160, 165)
	spot.add_child(it)
	world.add_child(spot)


func _add_bot(world: Node, b: Dictionary) -> void:
	var bot := BOT_SCENE.instantiate() as PatrolBot
	bot.name = b["id"].to_pascal_case()
	bot.bot_id = b["id"]
	bot.character_name = b.get("character", "")
	bot.art_name = b.get("art", "brass_automaton")
	bot.tint = b.get("tint", Color.WHITE)
	var robot: bool = b.get("character", "") == ""
	bot.tamperable = b.get("tamperable", false)
	bot.tracks_player = b.get("tracks_player", robot)
	bot.turns_to_noise = b.get("turns_to_noise", robot)
	bot.noise_dir = b.get("noise_dir", Vector2(-1, 0))
	bot.zone_range = b.get("zone_range", 150.0)
	bot.zone_angle_deg = b.get("zone_angle", 200.0 if robot else 360.0)
	bot.seizes = b.get("seizes", true)
	bot.catch_dialog = b.get("catch_dialog", "")
	bot.talk_dialog = b.get("talk_dialog", "")
	bot.distract_flag = b.get("distract_flag", "")
	bot.distract_dir = b.get("distract_dir", Vector2(1, 0))
	bot.distract_mark = b.get("distract_mark", "~ เต้น ~")
	bot.speed = b.get("speed", 70.0)
	bot.position = Iso.grid_to_world(b["pos"])
	var path := PackedVector2Array()
	for cell in b.get("patrol", []):
		path.append(Iso.grid_to_world(cell))
	bot.patrol = path
	bot.start_facing = b.get("facing", Vector2(1, 0.5))
	world.add_child(bot)
	_name_tag(bot, b.get("name", ""))


func _name_tag(node: Node2D, text: String) -> void:
	if text.is_empty():
		return
	var label := Label.new()
	label.name = "NameTag"
	label.text = text
	label.position = Vector2(-140, -222)
	label.size = Vector2(280, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(label)
