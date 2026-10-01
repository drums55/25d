class_name Weather
extends RefCounted
## Bangkok rain (DESIGN 10.5): per day 0-2 showers, deterministic from the city
## seed + day. Roads flood from accumulated rain and drain afterwards; each
## road floods at most to its own `flood` depth (CityGen).

const NONE := 0
const RAIN := 1
const HEAVY := 2
## Look-back window for flooding (minutes).
const FLOOD_WINDOW := 120
## Heavy-rain minutes in the window that flood roads fully.
const DEEP_AFTER := 30
## Any-rain minutes in the window that make roads wadeable.
const SHALLOW_AFTER := 40


## {"showers": [[start_min, end_min, heavy(bool)]]} for minutes of the day.
static func forecast(seed: int, day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, day, "rain"])
	var showers: Array = []
	if rng.randf() < 0.65:
		var n := 1 if rng.randf() < 0.6 else 2
		for i in n:
			var start := rng.randi_range(9 * 60, 20 * 60)
			var length := rng.randi_range(30, 140)
			showers.append([start, start + length, rng.randf() < 0.45])
	showers.sort_custom(func(a, b): return a[0] < b[0])
	return {"showers": showers}


static func rain_at(fc: Dictionary, minute: float) -> int:
	var out := NONE
	for s in fc.get("showers", []):
		if minute >= s[0] and minute < s[1]:
			out = maxi(out, HEAVY if s[2] else RAIN)
	return out


## 0 dry, 1 wadeable, 2 deep, for a road that can flood fully.
static func water_level(fc: Dictionary, minute: float) -> int:
	var heavy := 0.0
	var any := 0.0
	var w0 := minute - FLOOD_WINDOW
	for s in fc.get("showers", []):
		var overlap := maxf(0.0, minf(minute, s[1]) - maxf(w0, s[0]))
		any += overlap
		if s[2]:
			heavy += overlap
	if heavy >= DEEP_AFTER:
		return 2
	if any >= SHALLOW_AFTER:
		return 1
	return 0


## {edge_index: level} for roads that are wet right now (dry roads omitted).
static func edge_levels(city: Dictionary, fc: Dictionary, minute: float) -> Dictionary:
	var water := water_level(fc, minute)
	var out := {}
	if water == 0:
		return out
	var edges: Array = city["edges"]
	for i in edges.size():
		var level := mini(int(edges[i]["flood"]), water)
		if level > 0:
			out[i] = level
	return out


## Riding is slower in the rain.
static func rain_factor(rain: int) -> float:
	return [1.0, 1.25, 1.5][rain]


static func describe(rain: int) -> String:
	return ["ฟ้าโปร่ง", "ฝนตก", "ฝนตกหนัก"][rain]


## Short human forecast for the app, e.g. "ฝนหนักช่วง 14:10-15:30".
static func summary(fc: Dictionary) -> String:
	var parts: Array[String] = []
	for s in fc.get("showers", []):
		parts.append("%s %s-%s" % ["ฝนหนัก" if s[2] else "ฝน", clock_text(s[0]), clock_text(s[1])])
	return "วันนี้ฟ้าโปร่งทั้งวัน" if parts.is_empty() else "พยากรณ์: " + ", ".join(parts)


static func clock_text(minute: float) -> String:
	var m := int(minute)
	return "%02d:%02d" % [(m / 60) % 24, m % 60]
