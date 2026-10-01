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

## Set by tests to build a given place without moving the rider.
var node_override := -1
var place := {}


func _ready() -> void:
	if Engine.is_editor_hint():
		super._ready()
		return
	var id := node_override if node_override >= 0 else GameState.location
	place = City.node(id)
	_build(LocationTemplates.get_template(place["type"]), id)
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
	var spots: Array = t.get("customers", [])
	var n := 0
	for o in Orders.dropoffs_at(id) + _accepted_drops(id):
		var spot: Vector2 = spots[n % spots.size()] + Vector2(0.9, 0.0) * int(n / spots.size())
		var c := _add_npc(world, "Customer%d" % int(o["id"]), spot, "je_muay", Color(1, 0.85, 0.9))
		var cit := c.get_node("Interactable") as Interactable
		cit.npc_id = "customer_%d" % int(o["id"])
		cit.dialog_id = "talk_customer_waiting"
		_name_tag(c, str(o["customer"]))
		n += 1
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


## Customers wait for orders that are on the way too (accepted, not picked),
## so arriving with the food finds them already there.
func _accepted_drops(id: int) -> Array:
	return GameState.orders.filter(
		func(o): return o["status"] == "accepted" and int(o["dropoff"]) == id
	)


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
	label.position = Iso.grid_to_world(Vector2(g.x * 0.5, 0)) + Vector2(-280, -wall_height * 0.78)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
