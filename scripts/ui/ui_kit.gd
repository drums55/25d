class_name UiKit
extends RefCounted
## Small builders so the code-built UI (phone app, menus) looks consistent.

const ACCENT := Color(0.13, 0.75, 0.42)
const ACCENT_DARK := Color(0.08, 0.45, 0.26)
const WARN := Color(0.95, 0.45, 0.3)
const TEXT := Color(0.96, 0.95, 0.92)
const MUTED := Color(0.7, 0.72, 0.75)
const PANEL := Color(0.09, 0.1, 0.12, 0.97)


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
