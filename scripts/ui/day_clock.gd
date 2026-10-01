class_name DayClock
extends Control
## Steam day dial (top-right of the HUD): a half-circle split into the six
## day slots (เช้า..ค่ำ) with a hand carrying a sun (or moon at dusk/night).
## The hand sweeps when time passes so the cost of a room change / delivery
## is visible (owner 2026-10-01: "no sense of time").

const SLOT_COLORS := [
	Color(0.98, 0.62, 0.35),
	Color(0.98, 0.82, 0.45),
	Color(1.0, 0.93, 0.55),
	Color(0.98, 0.78, 0.42),
	Color(0.93, 0.48, 0.3),
	Color(0.5, 0.42, 0.75),
]
const RADIUS := 120.0
const THICK := 20.0

## Tick shown by the hand; tweened towards GameState.tick.
var shown_tick := 0.0:
	set(v):
		shown_tick = v
		queue_redraw()
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown_tick = GameState.tick
	GameState.time_changed.connect(_on_time)


func _on_time(_day: int, tick: int) -> void:
	if _tween:
		_tween.kill()
	if tick < shown_tick:
		shown_tick = tick  # new day: jump back to dawn
		return
	_tween = create_tween()
	_tween.tween_property(self, "shown_tick", float(tick), 0.9).set_trans(Tween.TRANS_SINE)


func _center() -> Vector2:
	return Vector2(size.x * 0.5, RADIUS + THICK + 8.0)


## 0..DAY_TICKS -> angle on the upper half circle (left = dawn, right = dusk).
static func tick_angle(tick: float) -> float:
	return PI + PI * clampf(tick / GameState.DAY_TICKS, 0.0, 1.0)


func _draw() -> void:
	var c := _center()
	var slots := GameState.SLOT_NAMES.size()
	var current := GameState.slot()
	var night := GameState.is_night()
	# plate
	draw_circle(c, RADIUS + THICK, Color(0.1, 0.08, 0.07, 0.75))
	draw_arc(c, RADIUS + THICK, PI, TAU, 48, Color(0.85, 0.68, 0.35), 4.0, true)
	for i in slots:
		var a0 := PI + PI * i / slots
		var a1 := PI + PI * (i + 1) / slots
		var col: Color = SLOT_COLORS[i]
		if i < current or night:
			col = col.darkened(0.6)
		elif i > current:
			col = col.darkened(0.25)
		draw_arc(
			c, RADIUS, a0 + 0.02, a1 - 0.02, 12, col, THICK if i != current else THICK + 8, true
		)
	# hand + sun / moon
	var a := tick_angle(shown_tick)
	var tip := c + Vector2.from_angle(a) * RADIUS
	draw_line(c, tip, Color(0.85, 0.68, 0.35), 5.0, true)
	draw_circle(c, 9.0, Color(0.85, 0.68, 0.35))
	if night or current >= slots - 1:
		draw_circle(tip, 17.0, Color(0.9, 0.92, 1.0))
		draw_circle(tip + Vector2(7, -5), 14.0, Color(0.1, 0.08, 0.07))
	else:
		draw_circle(tip, 18.0, Color(1.0, 0.85, 0.3))
		draw_arc(tip, 24.0, 0, TAU, 20, Color(1.0, 0.85, 0.3, 0.6), 3.0, true)
	# labels
	var font := get_theme_default_font()
	var label: String = "กลางคืน" if night else GameState.slot_name()
	var w := size.x
	draw_string(
		font, Vector2(0, c.y + 48), label, HORIZONTAL_ALIGNMENT_CENTER, w, 44, Color(1, 0.92, 0.7)
	)
	draw_string(
		font,
		Vector2(0, c.y + 84),
		"วันที่ %d" % GameState.day,
		HORIZONTAL_ALIGNMENT_CENTER,
		w,
		28,
		Color(0.85, 0.9, 1)
	)
