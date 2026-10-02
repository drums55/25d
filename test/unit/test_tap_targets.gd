extends GutTest
## Every tappable thing in every room must actually be tappable (owner
## 2026-10-02: "หยิบรีโมทยากมาก เพราะจะไปโดนเตียงตลอด"): items lying around,
## exits and people at their visual centre; props somewhere on their art.
## Checked with the chapter-1, -2 and -3 flag sets so every variant spawns.

const CH2_FLAGS := ["ch2", "got_debt_list", "nok_love", "no9_fused", "gate_open"]
## Chapter 3 at night: the ring in the mud and the company robot, then เก้า at the gate.
const CH3_FLAGS := [
	"ch2", "got_debt_list", "nok_love", "no9_fused", "gate_open", "ch3", "lung_ring_told"
]
const CH3_LATE := [
	"ch2",
	"got_debt_list",
	"nok_love",
	"no9_fused",
	"gate_open",
	"ch3",
	"ally_nine",
	"ally_nok",
	"ally_jum",
	"ending_five_stars"
]
## A prop is fine when at least this share of its opaque art picks it.
const MIN_PROP_SHARE := 0.35


func _room(id: String, flags: Array, tide: String) -> AdventureRoom:
	GameState.new_game()
	for f in flags:
		GameState.set_flag(f)
	GameState.tide = tide
	var room := (load(GameState.ROOM_SCENE) as PackedScene).instantiate() as AdventureRoom
	room.room_override = id
	add_child(room)
	return room


func _pickables(room: AdventureRoom) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("pickable"):
		if room.is_ancestor_of(n):
			out.append(n)
	return out


func _sprite(n: Node) -> Sprite2D:
	var root := Player._visual_root(n)
	for c in root.get_children():
		if c is Sprite2D:
			return c
	return null


## Problems for one room: "<thing>: reason".
func _audit(room: AdventureRoom) -> Array:
	var bad: Array = []
	var nodes := _pickables(room)
	for n in nodes:
		var parent: Node = n.get_parent()
		var label: String = "%s/%s" % [room.room_id, parent.name if n is Interactable else n.name]
		var center := Vector2.INF
		if parent is MarkerSpot:
			center = (
				n.global_position + (Vector2(0, -56) if parent.kind == "item" else Vector2(0, -20))
			)
		elif parent.has_node("Rig") or n is PatrolBot and n.character_name != "":
			center = (n as Node2D).global_position + Vector2(0, -100)
		if center != Vector2.INF:
			var got: Node2D = Player.pick(nodes, center)
			if got != n:
				bad.append(
					"%s: tap on it picks %s" % [label, got.get_parent().name if got else "floor"]
				)
			continue
		var s := _sprite(n)
		if s == null:
			continue
		var rect := Rect2(s.global_position + s.offset * s.scale, s.texture.get_size() * s.scale)
		var opaque := 0
		var mine := 0
		for ix in 16:
			for iy in 16:
				var p := rect.position + rect.size * Vector2((ix + 0.5) / 16.0, (iy + 0.5) / 16.0)
				if PickTest.visual_hit(Player._visual_root(n), p, 0.0) != 1:
					continue
				opaque += 1
				if Player.pick(nodes, p) == n:
					mine += 1
		if opaque > 0 and float(mine) / opaque < MIN_PROP_SHARE:
			bad.append("%s: only %d/%d of its art picks it" % [label, mine, opaque])
	return bad


func test_everything_is_tappable():
	var bad: Array = []
	for flags in [[], CH2_FLAGS, CH3_FLAGS, CH3_LATE]:
		for tide in ["high", "low"]:
			for id in Rooms.ROOMS:
				var room := _room(id, flags, tide)
				await wait_physics_frames(1)
				for b in _audit(room):
					if not bad.has(b):
						bad.append(b)
				room.free()
	for b in bad:
		gut.p("TAP: " + b)
	assert_eq(bad, [], "every tappable thing can be tapped")
	GameState.new_game()
