class_name RideTrack
extends RefCounted
## One ride between two places as a playable lane runner (owner 2026-10-01:
## "clicking along the map is not fun"). Pure logic: builds the track from the
## map route and checks hits; RideScene draws and drives it.
##
## Track space: `x` = cells along the road (rider starts at 0, ends at
## `length`), `lane` in {-1, 0, 1} (iso gy across the road). Obstacles move
## with their own forward speed (cars) or sideways (dogs). A fork splits the
## rest of the ride into branch "A" (soi shortcut: shorter, dogs, potholes,
## floods) or "B" (main road: longer, traffic, jams); obstacles carry the
## branch they belong to ("" = before the fork).

const LANES := [-1, 0, 1]
const SPEED := [7.0, 5.8, 4.8]  # cells/s by rain level
const RIDER_LEN := 0.9
## Obstacle kinds: length (cells), forward speed, what a hit does.
const KINDS := {
	"car": {"len": 1.6, "speed": 2.6, "hit": "crash", "art": "taxi"},
	"bus": {"len": 3.2, "speed": 2.0, "hit": "crash", "art": "city_bus"},
	"vendor": {"len": 1.6, "speed": 0.0, "hit": "crash", "art": "noodle_cart"},
	"scooter": {"len": 1.2, "speed": 0.0, "hit": "crash", "art": "parked_scooter"},
	"dog": {"len": 0.5, "speed": 0.0, "hit": "dog", "art": "soi_dog", "scale": 1.6},
	"pothole": {"len": 0.7, "speed": 0.0, "hit": "bump", "art": ""},
	"manhole": {"len": 0.6, "speed": 0.0, "hit": "slip", "art": ""},
	"puddle": {"len": 2.2, "speed": 0.0, "hit": "wade", "art": ""},
	"police": {"len": 0.8, "speed": 0.0, "hit": "police", "art": "police_check"},
	"jam": {"len": 6.0, "speed": 0.0, "hit": "jam", "art": ""},
}
## Food steadiness lost per hit kind (0..100 meter).
const SHAKE := {"crash": 35.0, "dog": 12.0, "bump": 22.0, "slip": 10.0, "wade": 14.0, "police": 0.0}
## Extra game minutes per hit kind (crash = picking the bike up, police = checkpoint).
const DELAY := {"crash": 3.0, "police": 5.0}
const BRANCH_FACTOR := {"A": 0.72, "B": 1.0}


## `segments`: [{"kind": "main"|"soi", "km": float, "water": 0..2}] along the
## map route; `minutes`: the map's estimate; `rain`: 0..2.
static func generate(seed: int, segments: Array, minutes: float, rain: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var duration := clampf(10.0 + minutes * 0.6, 14.0, 40.0)
	var speed: float = SPEED[clampi(rain, 0, 2)]
	var length := duration * speed
	var track := {
		"speed": speed,
		"base_minutes": minutes,
		"rain": rain,
		"obstacles": [],
		"fork": {},
	}
	var total_km := 0.0
	for s in segments:
		total_km += float(s["km"])
	total_km = maxf(total_km, 0.1)
	# where each map road starts along the track
	var marks: Array = []
	var acc := 0.0
	for s in segments:
		marks.append([acc / total_km * length, s])
		acc += float(s["km"])
	var fork_x := -1.0
	if minutes >= 8.0 and length > 50.0:
		fork_x = snappedf(length * rng.randf_range(0.35, 0.5), 0.1)
		track["fork"] = {
			"x": fork_x,
			"A": {"label": "ซอยลัด (สั้นกว่า แต่หลุม/หมา/น้ำขัง)"},
			"B": {"label": "ถนนใหญ่ (ไกลกว่า รถติด)"},
		}
	var end_a := length
	var end_b := length
	if fork_x > 0.0:
		end_a = fork_x + (length - fork_x) * BRANCH_FACTOR["A"]
		end_b = length
	track["length"] = {"": length, "A": end_a, "B": end_b}
	var obs: Array = track["obstacles"]
	var start := 12.0
	var stop_x := (fork_x - 4.0) if fork_x > 0.0 else length - 5.0
	_fill(rng, obs, start, stop_x, marks, "", rain)
	if fork_x > 0.0:
		_fill(
			rng,
			obs,
			fork_x + 6.0,
			end_a - 5.0,
			[[0.0, {"kind": "soi", "water": maxi(rain, 0)}]],
			"A",
			rain
		)
		_fill(rng, obs, fork_x + 6.0, end_b - 5.0, [[0.0, {"kind": "main", "water": 0}]], "B", rain)
		obs.append(
			{
				"kind": "jam",
				"x": fork_x + (end_b - fork_x) * 0.5,
				"lane": 0,
				"branch": "B",
				"all_lanes": true
			}
		)
	if rng.randf() < 0.3 and stop_x - start > 20.0:
		var px := rng.randf_range(start + 6.0, stop_x - 6.0)
		var free: int = LANES[rng.randi() % 3]
		var cop: int = LANES[(LANES.find(free) + 1) % 3]
		obs.append({"kind": "police", "x": px, "lane": cop, "branch": ""})
		for l in LANES:
			if l != free and l != cop:
				obs.append({"kind": "scooter", "x": px + 0.2, "lane": l, "branch": ""})
	obs.sort_custom(func(a, b): return a["x"] < b["x"])
	return track


static func _segment_at(marks: Array, x: float) -> Dictionary:
	var cur: Dictionary = marks[0][1]
	for m in marks:
		if x >= m[0]:
			cur = m[1]
	return cur


## Obstacles between `from` and `to`, never blocking all three lanes at once.
static func _fill(
	rng: RandomNumberGenerator,
	obs: Array,
	from: float,
	to: float,
	marks: Array,
	branch: String,
	rain: int
) -> void:
	var x := from
	while x < to:
		var seg := _segment_at(marks, x)
		var soi: bool = seg.get("kind", "main") == "soi"
		var water := int(seg.get("water", 0))
		var count := 1 if rng.randf() < 0.65 else 2
		var lanes := LANES.duplicate()
		CityGen._shuffle(rng, lanes)
		for i in count:
			var kind := _pick_kind(rng, soi, water, rain)
			obs.append({"kind": kind, "x": snappedf(x, 0.1), "lane": lanes[i], "branch": branch})
		x += rng.randf_range(3.2, 5.5) if soi else rng.randf_range(3.8, 6.5)


static func _pick_kind(rng: RandomNumberGenerator, soi: bool, water: int, rain: int) -> String:
	var r := rng.randf()
	if water > 0 and r < 0.35:
		return "puddle"
	r = rng.randf()
	if soi:
		if r < 0.28:
			return "dog"
		if r < 0.55:
			return "pothole"
		if r < 0.72:
			return "vendor"
		if r < 0.85:
			return "scooter"
		return "manhole"
	if r < 0.45:
		return "car"
	if r < 0.6:
		return "bus"
	if r < 0.75:
		return "pothole"
	if r < 0.88 or rain == 0:
		return "manhole"
	return "puddle"


static func kind_len(kind: String) -> float:
	return float(KINDS[kind]["len"])


## Where an obstacle is after `t` seconds (cars drive forward; dogs wander
## across the lanes).
static func obstacle_pos(o: Dictionary, t: float) -> Vector2:
	var k: Dictionary = KINDS[o["kind"]]
	var x: float = o["x"] + float(k["speed"]) * t
	var lane := float(o["lane"])
	if o["kind"] == "dog":
		lane = clampf(lane + sin(t * 1.3 + float(o["x"])) * 1.2, -1.2, 1.2)
	return Vector2(x, lane)


## Does the rider at track position `x`, lateral `lane`, touch obstacle `o`?
static func hits(o: Dictionary, t: float, x: float, lane: float) -> bool:
	var pos := obstacle_pos(o, t)
	if not o.get("all_lanes", false) and absf(pos.y - lane) > 0.45:
		return false
	return x + RIDER_LEN > pos.x and x < pos.x + kind_len(o["kind"])
