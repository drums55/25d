class_name RideRoad
extends Node2D
## Draws the scrolling road under RideScene: verge, red-white Bangkok kerbs,
## sidewalks, asphalt (darker and shiny in rain), lane dashes, edge lines.

const FROM := -12.0
const TO := 30.0

var ride: RideScene


func _quad(x0: float, x1: float, g0: float, g1: float, col: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array(
			[
				Iso.grid_to_world(Vector2(x0, g0)),
				Iso.grid_to_world(Vector2(x1, g0)),
				Iso.grid_to_world(Vector2(x1, g1)),
				Iso.grid_to_world(Vector2(x0, g1)),
			]
		),
		col
	)


func _draw() -> void:
	if ride == null:
		return
	var rain := int(ride.track.get("rain", 0))
	var soi := ride.branch == "A"
	var off := fmod(ride.travelled, 2.0)
	_quad(FROM, TO, -9.0, 9.0, Color(0.32, 0.36, 0.3))
	_quad(FROM, TO, -2.6, -1.5, Color(0.62, 0.6, 0.56))
	_quad(FROM, TO, 1.5, 2.4, Color(0.62, 0.6, 0.56))
	var asphalt := Color(0.3, 0.3, 0.32) if soi else Color(0.22, 0.23, 0.25)
	if rain > 0:
		asphalt = asphalt.darkened(0.25)
	_quad(FROM, TO, -1.5, 1.5, asphalt)
	# kerb stones, red and white
	var k := FROM - off
	var i := 0
	while k < TO:
		var col := Color(0.8, 0.18, 0.15) if i % 2 == 0 else Color(0.92, 0.92, 0.9)
		_quad(k, k + 1.0, -1.62, -1.5, col)
		_quad(k, k + 1.0, 1.5, 1.62, col)
		k += 1.0
		i += 1
	# lane dashes
	var x := FROM - off
	while x < TO:
		for g in [-0.5, 0.5]:
			_quad(x, x + 0.9, g - 0.03, g + 0.03, Color(0.95, 0.95, 0.9, 0.85))
		x += 2.0
	if rain > 0:
		var y := FROM - fmod(ride.travelled, 3.0)
		while y < TO:
			_quad(y, y + 0.6, -1.2, -1.1, Color(0.7, 0.8, 1.0, 0.25))
			_quad(y + 1.4, y + 2.2, 0.6, 0.7, Color(0.7, 0.8, 1.0, 0.25))
			y += 3.0
