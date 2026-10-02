class_name AdventureRoom
extends IsoRoom
## The room the rider is in (GameState.room), built from its Rooms recipe at
## runtime before IsoRoom bakes the navmesh: props (placeholder blocks when no
## art), items lying around, named people, exits and patrolling collectors.
## Entries can depend on flags and the tide (Rooms.present_now).

const PROP_SCENE := preload("res://scenes/props/prop_block.tscn")
const NPC_SCENE := preload("res://scenes/props/npc.tscn")
const INT_SCENE := preload("res://scenes/props/interactable.tscn")
const BOT_SCENE := preload("res://scenes/props/patrol_bot.tscn")
const JE_DEFAULT := "je_muay"

## Set by tests to build a given room without moving the rider.
var room_override := ""
var room_id := ""


func _ready() -> void:
	if Engine.is_editor_hint():
		super._ready()
		return
	room_id = room_override if not room_override.is_empty() else GameState.room
	art_name = room_id
	_build(Rooms.get_room(room_id))
	super._ready()


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
	for p in r.get("props", []):
		if Rooms.present_now(p, flags, tide):
			_add_prop(world, p, "Prop%d" % i)
		i += 1
	i = 0
	for p in r.get("pickups", []):
		if Rooms.present_now(p, flags, tide):
			_add_pickup(world, p, "Pickup%d" % i)
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


func _add_pickup(world: Node, p: Dictionary, node_name: String) -> void:
	var spot := MarkerSpot.new()
	spot.name = node_name
	spot.kind = "item"
	spot.label = p.get("label", "")
	spot.color = Puzzles.item_color(p["item"])
	spot.position = Iso.grid_to_world(p["pos"])
	var it := INT_SCENE.instantiate() as Interactable
	it.name = "Interactable"
	it.thing_id = p["item"]
	it.pickup_item = p["item"]
	it.pickup_text = p.get("text", "")
	it.prompt = "เก็บ"
	it.pick_rect = Rect2(-50, -90, 100, 110)
	spot.add_child(it)
	world.add_child(spot)


func _add_npc(world: Node, n: Dictionary) -> void:
	var npc := NPC_SCENE.instantiate() as Node2D
	npc.name = n["id"].to_pascal_case()
	npc.position = Iso.grid_to_world(n["pos"])
	var rig := npc.get_node("Rig")
	rig.character_name = n.get("character", JE_DEFAULT)
	rig.modulate = n.get("tint", Color.WHITE)
	var it := npc.get_node("Interactable") as Interactable
	it.thing_id = n["id"]
	it.dialog_id = n.get("dialog", "")
	it.prompt = "คุย"
	world.add_child(npc)
	_name_tag(npc, n.get("name", ""))


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
	it.pick_rect = Rect2(-80, -200, 160, 240)
	spot.add_child(it)
	world.add_child(spot)


func _add_bot(world: Node, b: Dictionary) -> void:
	var bot := BOT_SCENE.instantiate() as PatrolBot
	bot.name = b["id"].to_pascal_case()
	bot.bot_id = b["id"]
	bot.character_name = b.get("character", "")
	bot.art_name = b.get("art", "brass_automaton")
	bot.tint = b.get("tint", Color.WHITE)
	bot.chases = b.get("chases", true)
	bot.tamperable = b.get("tamperable", false)
	bot.steam_powered = b.get("steam_powered", false)
	bot.catch_dialog = b.get("catch_dialog", "")
	bot.talk_dialog = b.get("talk_dialog", "")
	bot.distract_flag = b.get("distract_flag", "")
	bot.distract_dir = b.get("distract_dir", Vector2(1, 0))
	bot.distract_mark = b.get("distract_mark", "~ เต้น ~")
	bot.speed = b.get("speed", 70.0)
	bot.chase_speed = b.get("chase_speed", 210.0)
	bot.view_range = b.get("view_range", 300.0)
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
	label.text = text
	label.position = Vector2(-140, -250)
	label.size = Vector2(280, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(label)
