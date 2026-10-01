class_name CityGen
extends RefCounted
## Random Bangkok for one playthrough (DESIGN 10.3). Pure logic: the whole
## city is rebuilt from `seed`, so a save only stores the seed.
##
## City = {"seed", "nodes": [{id, type, name, area, pos: Vector2}], "edges":
## [{a, b, kind: "main"|"soi", km, minutes, flood: 0|1|2}]}. `flood` is how
## deep the road can get in heavy rain (1 = wade through, 2 = impassable);
## Weather decides the current water level.

const TYPES := {
	"restaurant": "ร้านอาหาร",
	"market": "ตลาด",
	"house": "หมู่บ้าน",
	"condo": "คอนโด",
	"office": "ออฟฟิศ",
	"gas": "ปั๊มน้ำมัน",
	"garage": "อู่ซ่อมรถ",
}
## Guaranteed minimum of each type; the rest is drawn by FILL_WEIGHTS.
const MIN_COUNT := {
	"restaurant": 3, "market": 1, "house": 2, "condo": 2, "office": 2, "gas": 1, "garage": 1
}
const FILL_WEIGHTS := {"restaurant": 4, "house": 3, "condo": 3, "office": 2, "market": 1}
const NODE_COUNT := 15
const MAP_SIZE := Vector2(1000, 700)
const MIN_GAP := 150.0
## Map units per km.
const UNITS_PER_KM := 100.0
## Riding minutes per km (+ fixed 2 min to park / start).
const MIN_PER_KM := {"main": 2.2, "soi": 3.2}
## Wading through a shallow flood is slower.
const WADE_FACTOR := 1.6

const ROADS := [
	"ลาดพร้าว",
	"สุขุมวิท",
	"รามคำแหง",
	"พระราม 9",
	"ประชาอุทิศ",
	"จรัญสนิทวงศ์",
	"วิภาวดี",
	"พหลโยธิน",
	"เพชรบุรี",
	"บางนา",
	"อ่อนนุช",
	"ประดิพัทธ์",
]
const PEOPLE := ["แดง", "ต้อย", "หมวย", "อ้วน", "แจ๋ว", "ตุ๋ย", "เล็ก", "จุ๋ม", "ป้อม", "นก"]
const FOOD := [
	"ข้าวมันไก่เจ๊%s",
	"ก๋วยเตี๋ยวเรือป้า%s",
	"ส้มตำ%sแซ่บ",
	"หมูกระทะลุง%s",
	"ชาไข่มุก %s ทีไทม์",
	"ข้าวขาหมูเฮีย%s",
	"โจ๊กเจ้า%s",
]
const PLACES := ["ทองหล่อ", "สามัคคี", "ร่มเย็น", "ศรีสุข", "เจริญผล", "บุญมี", "ไพลิน", "นิรันดร์"]


static func generate(seed: int, count := NODE_COUNT) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var types: Array[String] = []
	for t in MIN_COUNT:
		for i in MIN_COUNT[t]:
			types.append(t)
	while types.size() < count:
		types.append(_weighted(rng, FILL_WEIGHTS))
	_shuffle(rng, types)
	var nodes: Array = []
	var used_names := {}
	for i in types.size():
		var pos := _free_spot(rng, nodes)
		var name := _name_for(rng, types[i])
		while used_names.has(name):
			name = _name_for(rng, types[i])
		used_names[name] = true
		(
			nodes
			. append(
				{
					"id": i,
					"type": types[i],
					"name": name,
					"area":
					"ซ.%s %d" % [ROADS[rng.randi() % ROADS.size()], rng.randi_range(1, 120)],
					"pos": pos,
				}
			)
		)
	return {"seed": seed, "nodes": nodes, "edges": _roads(rng, nodes)}


static func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var r := rng.randi_range(1, total)
	for k in weights:
		r -= int(weights[k])
		if r <= 0:
			return k
	return weights.keys()[0]


static func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _free_spot(rng: RandomNumberGenerator, nodes: Array) -> Vector2:
	var margin := 60.0
	var best := Vector2.ZERO
	var best_gap := -1.0
	for _try in 60:
		var p := Vector2(
			rng.randf_range(margin, MAP_SIZE.x - margin),
			rng.randf_range(margin, MAP_SIZE.y - margin)
		)
		var gap := INF
		for n in nodes:
			gap = minf(gap, p.distance_to(n["pos"]))
		if gap >= MIN_GAP:
			return p
		if gap > best_gap:
			best_gap = gap
			best = p
	return best


static func _name_for(rng: RandomNumberGenerator, type: String) -> String:
	var who: String = PEOPLE[rng.randi() % PEOPLE.size()]
	var place: String = PLACES[rng.randi() % PLACES.size()]
	match type:
		"restaurant":
			return (FOOD[rng.randi() % FOOD.size()] as String) % who
		"market":
			return "ตลาด%s" % place
		"house":
			return "หมู่บ้าน%sวิลล์" % place
		"condo":
			return "เดอะ %s คอนโด" % place
		"office":
			return "อาคาร%sทาวเวอร์" % place
		"gas":
			return "ปั๊ม%sออยล์" % place
		"garage":
			return "อู่%sยางยนต์" % who
	return place


## Minimum spanning tree (always connected) + each node's nearest extra
## neighbour, so there is usually more than one way around a flood.
static func _roads(rng: RandomNumberGenerator, nodes: Array) -> Array:
	var pairs: Array = []
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			pairs.append([(nodes[i]["pos"] as Vector2).distance_to(nodes[j]["pos"]), i, j])
	pairs.sort_custom(func(x, y): return x[0] < y[0])
	var parent: Array = range(nodes.size())
	var chosen := {}
	for p in pairs:
		var ra := _find(parent, p[1])
		var rb := _find(parent, p[2])
		if ra != rb:
			parent[ra] = rb
			chosen["%d-%d" % [p[1], p[2]]] = true
	# extra loops: for each node, its 2 nearest neighbours
	for i in nodes.size():
		var near: Array = []
		for p in pairs:
			if p[1] == i or p[2] == i:
				near.append(p)
		for k in mini(2, near.size()):
			chosen["%d-%d" % [near[k][1], near[k][2]]] = true
	var edges: Array = []
	for key in chosen:
		var ab: PackedStringArray = (key as String).split("-")
		var a := int(ab[0])
		var b := int(ab[1])
		var km := (nodes[a]["pos"] as Vector2).distance_to(nodes[b]["pos"]) / UNITS_PER_KM
		var kind := "main" if km > 2.4 or rng.randf() < 0.35 else "soi"
		var flood := 0
		var r := rng.randf()
		if kind == "soi":
			flood = 2 if r < 0.18 else (1 if r < 0.45 else 0)
		else:
			flood = 1 if r < 0.15 else 0
		(
			edges
			. append(
				{
					"a": a,
					"b": b,
					"kind": kind,
					"km": snappedf(km, 0.1),
					"minutes": snappedf(2.0 + km * MIN_PER_KM[kind], 0.5),
					"flood": flood,
				}
			)
		)
	edges.sort_custom(func(x, y): return x["a"] * 100 + x["b"] < y["a"] * 100 + y["b"])
	return edges


static func _find(parent: Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func nodes_of_type(city: Dictionary, type: String) -> Array:
	var out: Array = []
	for n in city["nodes"]:
		if n["type"] == type:
			out.append(n)
	return out


## Cheapest ride from `from` to `to`. `water` = {edge_index: level 0..2} from
## Weather.edge_levels(); level 2 roads are closed, level 1 roads are waded
## (slower, risky). `rain_factor` slows every road. Returns {} if no way.
## Result: {"path": [node ids], "edges": [edge idx], "minutes", "km", "wade"}.
static func route(
	city: Dictionary, from: int, to: int, water := {}, rain_factor := 1.0, allow_wade := true
) -> Dictionary:
	if from == to:
		return {"path": [from], "edges": [], "minutes": 0.0, "km": 0.0, "wade": false}
	var adj := {}
	var edges: Array = city["edges"]
	for i in edges.size():
		var e: Dictionary = edges[i]
		var level := int(water.get(i, 0))
		if level >= 2 or (level == 1 and not allow_wade):
			continue
		var cost: float = e["minutes"] * rain_factor * (WADE_FACTOR if level == 1 else 1.0)
		for pair in [[e["a"], e["b"]], [e["b"], e["a"]]]:
			if not adj.has(pair[0]):
				adj[pair[0]] = []
			adj[pair[0]].append([pair[1], cost, i])
	var dist := {from: 0.0}
	var prev := {}
	var open := [from]
	var done := {}
	while not open.is_empty():
		var best_i := 0
		for k in open.size():
			if dist[open[k]] < dist[open[best_i]]:
				best_i = k
		var u: int = open[best_i]
		open.remove_at(best_i)
		if done.has(u):
			continue
		done[u] = true
		if u == to:
			break
		for link in adj.get(u, []):
			var v: int = link[0]
			var nd: float = dist[u] + link[1]
			if not dist.has(v) or nd < dist[v]:
				dist[v] = nd
				prev[v] = [u, link[2]]
				open.append(v)
	if not dist.has(to):
		return {}
	var path: Array = [to]
	var used: Array = []
	var km := 0.0
	var wade := false
	var cur := to
	while cur != from:
		var p: Array = prev[cur]
		used.push_front(p[1])
		km += edges[p[1]]["km"]
		wade = wade or int(water.get(p[1], 0)) == 1
		cur = p[0]
		path.push_front(cur)
	return {
		"path": path,
		"edges": used,
		"minutes": snappedf(dist[to], 0.5),
		"km": snappedf(km, 0.1),
		"wade": wade
	}
