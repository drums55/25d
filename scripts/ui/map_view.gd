class_name MapView
extends Control
## The trip menu as the rider's hand-drawn map of ซอยส่งไว (owner 2026-10-02:
## "หน้าเลือกที่ไป = แผนที่แบบ Monkey Island" instead of a list of signs).
## Art: assets/art/ui/map.png (tools/art/png/map_2090.py) draws every place of
## the soi with no names; this lays red pins + hand-written names only on the
## places the rider knows (Rooms.TRAVEL flags), the เรือเตอร์ไซค์ where they
## are now. Tap a pin = the little boat sails there along the sheet, then the
## usual canal cutscene (Main.travel). Tap off the sheet / "ไม่ไปแล้ว" = close.
##
## setup(current_at, places, on_pick, on_close, tint) — places =
## [{id, name, at (fraction of the sheet)}], current_at = fraction too.

## The sheet is the 1920x1200 design space (the painting is 2560x1600 of it).
const SHEET := Vector2(1920, 1200)
## How long the boat takes to sail between pins.
const SAIL_TIME := 0.9
## The boat's size on the sheet (the prop is painted at 2x).
const BOAT_SCALE := 0.36
## Where the pin's needle meets the paper, in the pin picture (56x72).
const PIN_TIP := Vector2(28, 70)

var busy := false

var _sheet: Control
var _boat: Node2D
var _on_pick: Callable
var _on_close: Callable
var _pins := {}


func setup(
	current_at: Vector2, places: Array, on_pick: Callable, on_close: Callable, tint := Color.WHITE
) -> void:
	_on_pick = on_pick
	_on_close = on_close
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dim(close))
	_sheet = Control.new()
	_sheet.name = "Sheet"
	_sheet.size = SHEET
	_sheet.set_anchors_preset(Control.PRESET_CENTER)
	_sheet.offset_left = -SHEET.x * 0.5
	_sheet.offset_top = -SHEET.y * 0.5
	_sheet.offset_right = SHEET.x * 0.5
	_sheet.offset_bottom = SHEET.y * 0.5
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)
	# chapter 3: the sheet is read by lamp light (the pins stay legible)
	var art := TextureRect.new()
	art.name = "Art"
	art.modulate = tint
	art.texture = UiKit.tex("map")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = SHEET
	art.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.add_child(art)
	for p in places:
		if (p["at"] as Vector2).distance_to(current_at) < 0.001:
			continue
		_add_pin(p)
	_add_boat(current_at)
	var back := UiKit.hand_button("ไม่ไปแล้ว ✕", close, 38, UiKit.RED_INK)
	back.position = Vector2(SHEET.x * 0.5 - 120, SHEET.y - 92)
	_sheet.add_child(back)
	if _pins.is_empty():
		var none := UiKit.hand_label("ยังไม่รู้จักที่อื่นให้ไป", 36, UiKit.INK_FADED)
		none.position = Vector2(SHEET.x * 0.5 - 200, SHEET.y - 150)
		_sheet.add_child(none)
	_sheet.pivot_offset = SHEET * 0.5
	UiKit.drop_in(_sheet, -0.6)
	Audio.sfx("book_open")


## A red pin with the place's name written under it; tapping sails there.
func _add_pin(place: Dictionary) -> void:
	var at := (place["at"] as Vector2) * SHEET
	var b := Button.new()
	b.name = "Pin_%s" % place["id"]
	b.flat = true
	b.custom_minimum_size = Vector2(260, 150)
	b.position = at - Vector2(130, 70)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var pin := TextureRect.new()
	pin.texture = UiKit.tex("map_pin")
	pin.position = Vector2(130, 70) - PIN_TIP
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pin)
	var l := UiKit.hand_label(str(place["name"]), 30, UiKit.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(260, 40)
	l.position = Vector2(0, 76)
	l.add_theme_color_override("font_outline_color", Color(0.93, 0.88, 0.77, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	b.pressed.connect(_sail.bind(str(place["id"]), at))
	UiKit.juice(b)
	_sheet.add_child(b)
	_pins[str(place["id"])] = b


## The เรือเตอร์ไซค์ with the rider aboard, where they are now.
func _add_boat(current_at: Vector2) -> void:
	_boat = Node2D.new()
	_boat.name = "Boat"
	_boat.position = current_at * SHEET
	_boat.scale = Vector2.ONE * BOAT_SCALE
	var tex := ArtLibrary.prop("boat_bike")
	if tex:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + ArtLibrary.PROP_FOOT_MARGIN)
		s.scale = Vector2.ONE / ArtLibrary.ART_SCALE
		_boat.add_child(s)
	var who := (load("res://scenes/characters/character_view.tscn") as PackedScene).instantiate()
	who.character_name = "rider"
	who.position = BoatRide.RIDER_SEAT
	_boat.add_child(who)
	who.set_facing(Iso.Dir.SE)
	who.set_pose("ride")
	_sheet.add_child(_boat)
	var here := UiKit.hand_label("อยู่ตรงนี้", 26, UiKit.RED_INK)
	here.autowrap_mode = TextServer.AUTOWRAP_OFF
	here.position = Vector2(-120, 85)
	here.scale = Vector2.ONE / BOAT_SCALE
	_boat.add_child(here)
	var bob := _boat.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	bob.tween_property(_boat, "rotation_degrees", 2.0, 0.9)
	bob.tween_property(_boat, "rotation_degrees", -2.0, 0.9)


## Sail the little boat to the pin along a gentle curve, then go for real.
func _sail(dest: String, to: Vector2) -> void:
	if busy:
		return
	busy = true
	Audio.sfx("bike_start")
	var from := _boat.position
	var mid := (from + to) * 0.5 + (to - from).orthogonal().normalized() * 60.0
	_boat.scale.x = BOAT_SCALE * (1.0 if to.x >= from.x else -1.0)
	for id in _pins:
		(_pins[id] as Button).disabled = id != dest
	var t := create_tween()
	(
		t
		. tween_method(
			func(u: float):
				var a := from.lerp(mid, u)
				var b := mid.lerp(to, u)
				_boat.position = a.lerp(b, u),
			0.0,
			1.0,
			SAIL_TIME
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	t.tween_callback(func(): _on_pick.call(dest))


func close() -> void:
	if busy:
		return
	if _on_close.is_valid():
		_on_close.call()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
