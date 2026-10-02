class_name BoatTrack
extends RefCounted
## One trip on the floating bike along a canal (DESIGN 11.5): a short 3-lane
## runner between places. Pure logic; BoatRide draws and drives it.
##
## Track space: `x` = cells along the canal (start 0, end `length`), `lane`
## in {-1, 0, 1}. Some things drift forward (longtail boats) or bob across
## lanes (the collector robot on its raft). Hits only bump the bike and make
## the rider say something — the story has no meters.

const LANES := [-1, 0, 1]
const SPEED := 3.4
const RIDER_LEN := 0.9
## len (cells), forward speed, what a hit does, art.
const KINDS := {
	"longtail": {"len": 2.6, "speed": 1.0, "hit": "bump", "art": "longtail_boat"},
	"crate": {"len": 0.9, "speed": 0.0, "hit": "bump", "art": "crate"},
	"bin": {"len": 0.7, "speed": 0.0, "hit": "bump", "art": "trash_bin"},
	"jar": {"len": 0.8, "speed": 0.0, "hit": "bump", "art": "dragon_jar"},
	"hyacinth": {"len": 2.2, "speed": 0.0, "hit": "slow", "art": ""},
	"robot": {"len": 0.8, "speed": 0.4, "hit": "robot", "art": "brass_automaton"},
}


static func generate(seed: int, duration := 16.0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var length := duration * SPEED
	var obs: Array = []
	var x := 9.0
	while x < length - 5.0:
		var count := 1 if rng.randf() < 0.6 else 2
		var lanes := LANES.duplicate()
		for i in range(lanes.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = lanes[i]
			lanes[i] = lanes[j]
			lanes[j] = tmp
		for i in count:
			obs.append({"kind": _pick(rng), "x": snappedf(x, 0.1), "lane": lanes[i]})
		x += rng.randf_range(4.5, 7.5)
	return {"speed": SPEED, "length": length, "obstacles": obs}


static func _pick(rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	if r < 0.25:
		return "hyacinth"
	if r < 0.45:
		return "crate"
	if r < 0.6:
		return "longtail"
	if r < 0.75:
		return "bin"
	if r < 0.9:
		return "jar"
	return "robot"


static func kind_len(kind: String) -> float:
	return float(KINDS[kind]["len"])


## Where an obstacle is after `t` seconds.
static func obstacle_pos(o: Dictionary, t: float) -> Vector2:
	var k: Dictionary = KINDS[o["kind"]]
	var x: float = o["x"] + float(k["speed"]) * t
	var lane := float(o["lane"])
	if o["kind"] == "robot":
		lane = clampf(lane + sin(t * 0.8 + float(o["x"])) * 1.1, -1.1, 1.1)
	return Vector2(x, lane)


## Does the rider at `x`, lateral `lane`, touch obstacle `o` at time `t`?
static func hits(o: Dictionary, t: float, x: float, lane: float) -> bool:
	var pos := obstacle_pos(o, t)
	if absf(pos.y - lane) > 0.45:
		return false
	return x + RIDER_LEN > pos.x and x < pos.x + kind_len(o["kind"])
