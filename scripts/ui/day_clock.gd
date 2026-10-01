class_name DayClock
extends Control
## Day dial (top-right of the HUD): half circle from DAY_START to DAY_END in
## six coloured stretches, a hand with a sun (moon after 19:00), the clock
## time, the day and the weather now (owner: "no sense of time").

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _center() -> Vector2:
	return Vector2(size.x * 0.5, RADIUS + THICK + 8.0)


static func day_fraction(minute: float) -> float:
	var span := float(GameState.DAY_END - GameState.DAY_START)
	return clampf((minute - GameState.DAY_START) / span, 0.0, 1.0)


func _draw() -> void:
	var c := _center()
	var f := day_fraction(GameState.minute)
	var slots := SLOT_COLORS.size()
	var current := mini(int(f * slots), slots - 1)
	draw_circle(c, RADIUS + THICK, Color(0.1, 0.08, 0.07, 0.75))
	draw_arc(c, RADIUS + THICK, PI, TAU, 48, Color(0.85, 0.68, 0.35), 4.0, true)
	for i in slots:
		var a0 := PI + PI * i / slots
		var a1 := PI + PI * (i + 1) / slots
		var col: Color = SLOT_COLORS[i]
		if i < current:
			col = col.darkened(0.6)
		elif i > current:
			col = col.darkened(0.25)
		draw_arc(
			c, RADIUS, a0 + 0.02, a1 - 0.02, 12, col, THICK if i != current else THICK + 8, true
		)
	var tip := c + Vector2.from_angle(PI + PI * f) * RADIUS
	draw_line(c, tip, Color(0.85, 0.68, 0.35), 5.0, true)
	draw_circle(c, 9.0, Color(0.85, 0.68, 0.35))
	if GameState.minute >= 19 * 60:
		draw_circle(tip, 17.0, Color(0.9, 0.92, 1.0))
		draw_circle(tip + Vector2(7, -5), 14.0, Color(0.1, 0.08, 0.07))
	else:
		draw_circle(tip, 18.0, Color(1.0, 0.85, 0.3))
		draw_arc(tip, 24.0, 0, TAU, 20, Color(1.0, 0.85, 0.3, 0.6), 3.0, true)
	var font := get_theme_default_font()
	var w := size.x
	draw_string(
		font,
		Vector2(0, c.y + 50),
		GameState.clock_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		w,
		48,
		Color(1, 0.92, 0.7)
	)
	var weather := Weather.describe(City.rain_now()) if City.has_city() else ""
	draw_string(
		font,
		Vector2(0, c.y + 86),
		"วันที่ %d/%d · %s" % [GameState.day, GameState.LAST_DAY, weather],
		HORIZONTAL_ALIGNMENT_CENTER,
		w,
		26,
		Color(0.85, 0.9, 1)
	)
