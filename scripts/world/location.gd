class_name LocationRoom
extends IsoRoom
## The place the rider is at (GameState.location), built at runtime from its
## type's LocationTemplates recipe: props (random extras seeded per place),
## the merchant for pickups, a customer NPC for every order dropped here, the
## parked bike (tap = open the map), and the place name on the back wall.

const PROP_SCENE := preload("res://scenes/props/prop_block.tscn")
const NPC_SCENE := preload("res://scenes/props/npc.tscn")
const INT_SCENE := preload("res://scenes/props/interactable.tscn")
const BIKE_FOOT := Vector2(1.2, 0.6)
const BOT_SCENE := preload("res://scenes/props/patrol_bot.tscn")
## Chance a debt collector waits at a place (missed a payment / just in debt).
const COLLECTOR_CHANCE := {"missed": 0.55, "debt": 0.1}

## Tests turn the random debt collector off (and on for its own test).
static var allow_collector := true

## Set by tests to build a given place without moving the rider.
var node_override := -1
var place := {}


func _ready() -> void:
	if Engine.is_editor_hint():
		super._ready()
		return
	var id := node_override if node_override >= 0 else GameState.location
	place = City.node(id)
	_build(LocationTemplates.for_place(place), id)
	super._ready()


func _build(t: Dictionary, id: int) -> void:
	grid_size = t["grid"]
	floor_color_a = t["floor"][0]
	floor_color_b = t["floor"][1]
	wall_color = t["wall"]
	room_title = "%s · %s" % [place["name"], place["area"]]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.city_seed, id])
	var world := get_world()
	var i := 0
	for p in t.get("props", []):
		_add_prop(world, p, "Prop%d" % i)
		i += 1
	var extras: Array = t.get("extras", []).duplicate()
	CityGen._shuffle(rng, extras)
	for k in mini(int(t.get("extra_count", 0)), extras.size()):
		_add_prop(world, extras[k], "Extra%d" % k)
	if t.has("merchant"):
		var m: Dictionary = t["merchant"]
		var npc := _add_npc(
			world,
			"Merchant",
			m["pos"],
			m["character"],
			m.get("tint", Color.WHITE),
			m.get("behind_counter", false)
		)
		var it := npc.get_node("Interactable") as Interactable
		it.npc_id = "merchant"
		it.dialog_id = m.get("dialog", "")
		it.action = m.get("action", "")
		it.prompt = m.get("prompt", "คุย")
		if m.has("name"):
			_name_tag(npc, m["name"])
	var r := 0
	for res in t.get("npcs", []):
		var rn := _add_npc(
			world, "Resident%d" % r, res["pos"], res["character"], res.get("tint", Color.WHITE)
		)
		var rit := rn.get_node("Interactable") as Interactable
		rit.dialog_id = res.get("dialog", "")
		rit.action = res.get("action", "")
		rit.prompt = res.get("prompt", "คุย")
		_name_tag(rn, res["name"])
		r += 1
	var spots: Array = t.get("customers", [])
	var n := 0
	for o in Orders.waiting_customers(id):
		var c := _add_npc(
			world, "Customer%d" % int(o["id"]), _spot(spots, n), "je_muay", Color(1, 0.85, 0.9)
		)
		var cit := c.get_node("Interactable") as Interactable
		cit.npc_id = "customer_%d" % int(o["id"])
		cit.dialog_id = "talk_customer_waiting"
		_name_tag(c, str(o["customer"]))
		n += 1
	Orders.neighbour_hints(id)
	# wrong pin: a local who knows where the customer really lives
	for o in Orders.misled_here(id):
		var l := _add_npc(
			world, "Local%d" % int(o["id"]), _spot(spots, n), "lung_pradit", Color(0.9, 1, 0.85)
		)
		var lit := l.get_node("Interactable") as Interactable
		lit.npc_id = "local_%d" % int(o["id"])
		_name_tag(l, "คนแถวนี้ (ถามทาง)")
		n += 1
	# COD no-show: just a door to ring
	for o in Orders.no_shows_here(id):
		var door := INT_SCENE.instantiate() as Interactable
		door.name = "Door%d" % int(o["id"])
		door.npc_id = "door_%d" % int(o["id"])
		door.pick_rect = Rect2(-90, -120, 180, 140)
		door.position = Iso.grid_to_world(_spot(spots, n))
		var tag := Label.new()
		tag.text = "ห้อง/บ้าน %s\n(กดกริ่ง)" % o["customer"]
		tag.position = Vector2(-110, -110)
		tag.size = Vector2(220, 80)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 24)
		tag.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
		tag.add_theme_constant_override("outline_size", 8)
		door.add_child(tag)
		world.add_child(door)
		n += 1
	if place["type"] == "condo" and not GameState.has_flag("guard_friend"):
		_add_lift_guard(world)
	if allow_collector and _collector_shows_up(id):
		_add_collector(world, t)
	var bike := PROP_SCENE.instantiate()
	bike.name = "MyBike"
	bike.art_name = "rider_bike"
	bike.footprint_cells = BIKE_FOOT
	bike.position = Iso.grid_to_world(bike_cell(t))
	var bit := INT_SCENE.instantiate() as Interactable
	bit.action = "open_map"
	bit.prompt = "ขี่ต่อ"
	bike.add_child(bit)
	world.add_child(bike)
	var spawns := get_node("Spawns")
	var arrival := Marker2D.new()
	arrival.name = "arrival"
	arrival.position = Iso.grid_to_world(bike_cell(t) + Vector2(-1.7, -0.5))
	spawns.add_child(arrival)
	var default := Marker2D.new()
	default.name = "default"
	default.position = arrival.position
	spawns.add_child(default)
	_wall_sign(t)


## The bike is always parked in the front-right corner of the floor.
static func bike_cell(t: Dictionary) -> Vector2:
	var g := Vector2(t["grid"])
	return g - Vector2(1.4, 1.1)


static func _spot(spots: Array, n: int) -> Vector2:
	return spots[n % spots.size()] + Vector2(0.9, 0.0) * int(n / spots.size())


## Condo: a second guard paces in front of the lift (stares, never chases).
## Sneaking up the lift unseen = delivery at the door (Orders.sneak_lift).
func _add_lift_guard(world: Node) -> void:
	var g := BOT_SCENE.instantiate() as PatrolBot
	g.name = "LiftGuard"
	g.bot_id = "lift_guard"
	g.character_name = "lung_pradit"
	g.tint = Color(0.7, 0.75, 1.0)
	g.chases = false
	g.tamperable = false
	g.talk_dialog = "talk_lift_guard"
	g.steam_powered = false
	g.speed = 55.0
	g.view_range = 300.0
	g.position = Iso.grid_to_world(Vector2(5.0, 1.7))
	g.patrol = PackedVector2Array([Vector2.ZERO, Iso.grid_to_world(Vector2(2.4, 0.0))])
	g.start_facing = Vector2(1, 0.5)
	g.add_to_group("guard")
	world.add_child(g)
	_name_tag(g, "รปภ. เฝ้าลิฟต์")


func _collector_shows_up(id: int) -> bool:
	if GameState.debt <= 0 or GameState.minute <= GameState.DAY_START + 1.0:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.city_seed, GameState.day, int(GameState.minute), id, "debt"])
	var chance: float = COLLECTOR_CHANCE["missed" if GameState.missed_payments > 0 else "debt"]
	return rng.randf() < chance


## The loan shark's man waits here: chases anyone, takes cash on a catch.
func _add_collector(world: Node, t: Dictionary) -> void:
	var g := Vector2(t["grid"])
	var c := BOT_SCENE.instantiate() as PatrolBot
	c.name = "Collector"
	c.bot_id = "collector"
	c.character_name = "lung_pradit"
	c.tint = Color(0.75, 0.45, 0.45)
	c.chases = true
	c.needs_cargo = false
	c.catch_kind = "collect"
	c.tamperable = false
	c.talk_dialog = "talk_collector"
	c.steam_powered = false
	c.speed = 70.0
	c.chase_speed = 200.0
	c.position = Iso.grid_to_world(Vector2(g.x * 0.3, g.y * 0.5))
	c.patrol = PackedVector2Array([Vector2.ZERO, Iso.grid_to_world(Vector2(g.x * 0.4, 0.0))])
	c.start_facing = Vector2(0, 1)
	world.add_child(c)
	_name_tag(c, "เจ้าหนี้")
	GameState.notice.emit("ระวัง! ลูกน้องเจ้าหนี้มายืนรออยู่แถวนี้")


func _add_prop(world: Node, p: Dictionary, node_name: String) -> void:
	var prop := PROP_SCENE.instantiate()
	prop.name = node_name
	prop.art_name = p.get("art", "_none")
	prop.footprint_cells = p["foot"]
	prop.height = p.get("h", 80.0)
	prop.color = p.get("color", Color(0.55, 0.45, 0.35))
	prop.position = Iso.grid_to_world(p["pos"])
	if p.has("dialog"):
		var it := INT_SCENE.instantiate() as Interactable
		it.dialog_id = p["dialog"]
		it.prompt = p.get("prompt", "ดู")
		it.action = p.get("action", "")
		prop.add_child(it)
	world.add_child(prop)


## `behind_counter`: the NPC stands in the strip between a counter and the
## wall, which nobody can reach anyway; without its own collision the navmesh
## does not get slivers from the counter + NPC + wall squeeze.
func _add_npc(
	world: Node,
	node_name: String,
	pos: Vector2,
	character: String,
	tint: Color,
	behind_counter := false
) -> Node2D:
	var npc := NPC_SCENE.instantiate() as Node2D
	if behind_counter:
		npc.get_node("CollisionShape2D").free()
	npc.name = node_name
	npc.position = Iso.grid_to_world(pos)
	var rig := npc.get_node("Rig")
	rig.character_name = character
	rig.modulate = tint
	world.add_child(npc)
	return npc


func _name_tag(npc: Node2D, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(-120, -250)
	label.size = Vector2(240, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	npc.add_child(label)


## Shop-front sign on the back-right wall with the place's name.
func _wall_sign(t: Dictionary) -> void:
	var g: Vector2i = t["grid"]
	var label := Label.new()
	label.name = "WallSign"
	label.text = place["name"]
	label.size = Vector2(560, 70)
	label.position = Iso.grid_to_world(Vector2(g.x * 0.5, 0)) + Vector2(-280, -wall_height * 0.95)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
