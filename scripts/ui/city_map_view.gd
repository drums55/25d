class_name CityMapView
extends Control
## Map tab of the rider app: the generated city as a road graph. Main roads
## thick, sois thin; flooded roads blue (dashed = wade, X = closed); order pins
## (green = pick up, orange = deliver); tap a place to select it and see the
## route the bike would take.

signal place_selected(id: int)

const TYPE_COLORS := {
	"restaurant": Color(0.95, 0.55, 0.25),
	"market": Color(0.9, 0.75, 0.3),
	"house": Color(0.45, 0.75, 0.4),
	"condo": Color(0.45, 0.65, 0.95),
	"office": Color(0.7, 0.7, 0.8),
	"gas": Color(0.95, 0.3, 0.3),
	"garage": Color(0.6, 0.55, 0.5),
}
const PICK_RADIUS := 40.0

var selected := -1
var route := {}
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func to_view(p: Vector2) -> Vector2:
	var s := minf(size.x / CityGen.MAP_SIZE.x, size.y / CityGen.MAP_SIZE.y)
	var off := (size - CityGen.MAP_SIZE * s) * 0.5
	return off + p * s


func node_at(view_pos: Vector2) -> int:
	var best := -1
	var best_d := PICK_RADIUS
	for n in City.get_city()["nodes"]:
		var d := to_view(n["pos"]).distance_to(view_pos)
		if d < best_d:
			best_d = d
			best = n["id"]
	return best


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var id := node_at(mb.position)
		if id >= 0:
			select(id)
			accept_event()


func select(id: int) -> void:
	selected = id
	route = {} if id == GameState.location else City.route_to(id)
	place_selected.emit(id)
	queue_redraw()


func _draw() -> void:
	var city := City.get_city()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.15, 0.17))
	var water := City.water_now()
	var edges: Array = city["edges"]
	for i in edges.size():
		var e: Dictionary = edges[i]
		var a := to_view(city["nodes"][e["a"]]["pos"])
		var b := to_view(city["nodes"][e["b"]]["pos"])
		var main: bool = e["kind"] == "main"
		draw_line(
			a,
			b,
			Color(0.55, 0.57, 0.6) if main else Color(0.38, 0.4, 0.43),
			9.0 if main else 4.0,
			true
		)
		var level := int(water.get(i, 0))
		if level == 1:
			draw_dashed_line(a, b, Color(0.3, 0.6, 1.0), 7.0, 14.0)
		elif level == 2:
			draw_line(a, b, Color(0.15, 0.35, 0.85), 9.0, true)
			var m := (a + b) * 0.5
			draw_line(m + Vector2(-12, -12), m + Vector2(12, 12), Color(1, 0.3, 0.3), 5.0)
			draw_line(m + Vector2(-12, 12), m + Vector2(12, -12), Color(1, 0.3, 0.3), 5.0)
	if not route.is_empty():
		for i in route["edges"]:
			var e: Dictionary = edges[i]
			draw_line(
				to_view(city["nodes"][e["a"]]["pos"]),
				to_view(city["nodes"][e["b"]]["pos"]),
				Color(1.0, 0.65, 0.2, 0.9),
				7.0,
				true
			)
	var pins := _pins()
	var font := get_theme_default_font()
	for n in city["nodes"]:
		var p := to_view(n["pos"])
		var col: Color = TYPE_COLORS.get(n["type"], Color.WHITE)
		draw_circle(p, 15.0, col)
		draw_arc(p, 15.0, 0, TAU, 24, Color(0.05, 0.05, 0.05), 3.0, true)
		if n["id"] == selected:
			draw_arc(p, 24.0, 0, TAU, 32, Color(1, 1, 1), 4.0, true)
		if n["id"] == GameState.location:
			draw_arc(p, 26.0 + 6.0 * sin(_t * 4.0), 0, TAU, 32, UiKit.ACCENT, 5.0, true)
		var tag: String = pins.get(n["id"], "")
		if not tag.is_empty():
			var pc := Color(0.2, 0.85, 0.4) if tag.begins_with("รับ") else Color(1.0, 0.6, 0.2)
			draw_rect(Rect2(p + Vector2(10, -48), Vector2(64, 34)), pc)
			draw_string(
				font, p + Vector2(14, -22), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.BLACK
			)
		draw_string(
			font,
			p + Vector2(-90, 40),
			CityGen.TYPES[n["type"]],
			HORIZONTAL_ALIGNMENT_CENTER,
			180,
			20,
			UiKit.MUTED
		)


## node id -> "รับ" / "ส่ง" for orders in progress.
func _pins() -> Dictionary:
	var out := {}
	for o in Orders.active():
		if o["status"] == "accepted":
			out[int(o["pickup"])] = "รับ"
		else:
			out[int(o["dropoff"])] = "ส่ง"
	return out
