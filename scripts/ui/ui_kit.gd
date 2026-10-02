class_name UiKit
extends RefCounted
## Small builders so the code-built UI (phone app, menus) looks consistent.

const ACCENT := Color(0.13, 0.75, 0.42)
const ACCENT_DARK := Color(0.08, 0.45, 0.26)
const WARN := Color(0.95, 0.45, 0.3)
const TEXT := Color(0.96, 0.95, 0.92)
const MUTED := Color(0.7, 0.72, 0.75)
const PANEL := Color(0.09, 0.1, 0.12, 0.97)
# painted UI (tools/art/png/ui_2090.py; owner 2026-10-02: "เหมือน powerpoint"):
## Ink on paper, hand-painted tin signs, the debt notebook.
const UI_DIR := "res://assets/art/ui/"
const FONT_HAND := preload("res://assets/fonts/Sriracha-Regular.ttf")
const FONT_SIGN := preload("res://assets/fonts/Mali-SemiBold.ttf")
const INK := Color(0.16, 0.12, 0.17)
const INK_FADED := Color(0.16, 0.12, 0.17, 0.45)
const RED_INK := Color(0.77, 0.16, 0.16)
const SIGN_TEXT := Color(0.55, 0.1, 0.08)
## 9-slice margins of the painted pieces (match ui_2090.py)
const SIGN_MARGIN := 30
const NOTE_MARGIN := 96
const DIM := Color(0.02, 0.03, 0.05, 0.62)


static func label(text: String, size := 28, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, callback: Callable, size := 30, min_h := 76.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(callback)
	return b


static func panel_style(color := PANEL, radius := 18, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(18)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(3)
	return sb


static func card(children: Array, color := Color(0.16, 0.17, 0.2)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(color, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	for c in children:
		v.add_child(c)
	p.add_child(v)
	return p


static func row(children: Array, sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	for c in children:
		h.add_child(c)
	return h


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


# --- painted UI ---------------------------------------------------------------


static func tex(name: String) -> Texture2D:
	return load(UI_DIR + name + ".png") as Texture2D


static func nine(name: String, margin: int, content: Vector4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


## The taped paper note behind story cards and pickers.
static func note_style() -> StyleBoxTexture:
	var sb := nine("note", NOTE_MARGIN, Vector4(80, 84, 80, 70))
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb


## A hand-painted tin sign button (ป้ายสังกะสี). `kind` "" = yellow, "teal".
static func sign_button(
	text: String, callback: Callable, size := 32, min_h := 96.0, kind := ""
) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_override("font", FONT_SIGN)
	b.add_theme_font_size_override("font_size", size)
	var face := "sign_teal" if kind == "teal" else "sign"
	var col := Color(0.97, 0.95, 0.88) if kind == "teal" else SIGN_TEXT
	var content := Vector4(34, 14, 34, 18)
	b.add_theme_stylebox_override("normal", nine(face, SIGN_MARGIN, content))
	b.add_theme_stylebox_override(
		"hover", nine(face if kind == "teal" else "sign_hover", SIGN_MARGIN, content)
	)
	b.add_theme_stylebox_override("pressed", nine("sign_pressed", SIGN_MARGIN, content))
	b.add_theme_stylebox_override("disabled", nine("sign_disabled", SIGN_MARGIN, content))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(state, col)
	b.add_theme_color_override("font_pressed_color", Color(0.95, 0.9, 0.8))
	b.add_theme_color_override("font_disabled_color", Color(0.35, 0.34, 0.32))
	b.pressed.connect(callback)
	b.pressed.connect(func(): Audio.sfx("sign", 0.06))
	juice(b)
	return b


## Words written in the notebook that act as a button (ink, red when pressed).
static func hand_button(text: String, callback: Callable, size := 40, color := INK) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", FONT_HAND)
	b.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_focus_color"]:
		b.add_theme_color_override(state, color)
	b.add_theme_color_override("font_hover_color", RED_INK)
	b.add_theme_color_override("font_pressed_color", RED_INK)
	b.add_theme_color_override("font_disabled_color", INK_FADED)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.pressed.connect(callback)
	b.pressed.connect(func(): Audio.sfx("pencil", 0.1))
	juice(b)
	return b


static func hand_label(text: String, size := 34, color := INK) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", FONT_HAND)
	return l


## A ticked/empty hand-drawn box with words (settings in the notebook).
static func hand_check(text: String, on: bool, callback: Callable, size := 34) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_override("font", FONT_HAND)
	c.add_theme_font_size_override("font_size", size)
	c.add_theme_icon_override("checked", tex("box_ticked"))
	c.add_theme_icon_override("unchecked", tex("box"))
	c.add_theme_constant_override("h_separation", 14)
	for state in ["font_color", "font_focus_color", "font_pressed_color"]:
		c.add_theme_color_override(state, INK)
	c.add_theme_color_override("font_hover_color", RED_INK)
	c.add_theme_color_override("font_hover_pressed_color", RED_INK)
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		c.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	c.toggled.connect(callback)
	c.toggled.connect(func(_on): Audio.sfx("pencil", 0.1))
	return c


## A slider drawn in ink with a red blot for the knob.
static func ink_slider(value: float, callback: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.1
	s.value = value
	s.custom_minimum_size = Vector2(0, 54)
	var line := StyleBoxLine.new()
	line.color = INK
	line.thickness = 4
	line.grow_begin = 0
	line.grow_end = 0
	var area := StyleBoxFlat.new()
	area.bg_color = RED_INK
	area.content_margin_top = 3
	area.content_margin_bottom = 3
	var bg := StyleBoxFlat.new()
	bg.bg_color = INK_FADED
	bg.content_margin_top = 3
	bg.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", bg)
	s.add_theme_stylebox_override("grabber_area", area)
	s.add_theme_stylebox_override("grabber_area_highlight", area)
	s.add_theme_icon_override("grabber", tex("ink_blot"))
	s.add_theme_icon_override("grabber_highlight", tex("ink_blot"))
	s.value_changed.connect(callback)
	return s


## Squash on press, spring back on release.
static func juice(b: BaseButton) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.button_down.connect(
		func():
			var t := b.create_tween()
			t.tween_property(b, "scale", Vector2(0.94, 0.94), 0.06)
	)
	b.button_up.connect(
		func():
			var t := b.create_tween()
			t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(b, "scale", Vector2.ONE, 0.22)
	)


## A darkened full-screen backdrop that eats taps (behind menus and cards).
static func dim(on_tap := Callable()) -> ColorRect:
	var r := ColorRect.new()
	r.color = DIM
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	if on_tap.is_valid():
		r.gui_input.connect(
			func(ev: InputEvent):
				# touches arrive here as emulated mouse clicks (one event per tap)
				var m := ev as InputEventMouseButton
				if m and m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
					on_tap.call()
		)
	return r


## Drop a card in: from a little above, rotated, settling with a bounce.
static func drop_in(c: Control, tilt := -1.2) -> void:
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2(1.06, 1.06)
	c.rotation_degrees = tilt * 3.0
	var t := c.create_tween().set_parallel()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 1.0, 0.15)
	t.tween_property(c, "scale", Vector2.ONE, 0.32)
	t.tween_property(c, "rotation_degrees", tilt, 0.32)
