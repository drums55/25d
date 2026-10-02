class_name Hud
extends CanvasLayer
## On-screen UI (DESIGN 11.5): the bag (inventory bar, bottom), what is held,
## notices, the room title, the dialog box, a menu button (save / load /
## settings / title) and full-screen cards. Player asks blocks_point() so taps
## on UI never walk the rider.
##
## Bag taps: nothing held -> hold it; the held item again -> look at it and
## put it back; another item -> combine the two (Puzzles.combine). With an
## item held, tapping a thing in the room uses it there (Interactable).

const TITLE_HOLD := 1.6
const TITLE_FADE := 0.6
const NOTICE_HOLD := 2.2
const SLOT_SIZE := Vector2(156, 200)

var _title_tween: Tween
var _notices: Array[String] = []
var _notice_busy := false
var _bag: PanelContainer
var _slots: HBoxContainer
var _held_label: Label
var _menu_button: Button
var _menu: MenuBook
var _overlay: Control
var _tide_label: Label
var _riding := false

@onready var _title: Label = %RoomTitle
@onready var _notice: Label = %Notice


func _ready() -> void:
	add_to_group("hud")
	_build_bag()
	_build_menu_button()
	_tide_label = UiKit.label("", 30, Color(0.62, 0.88, 1.0))
	_tide_label.add_theme_font_override("font", UiKit.FONT_SIGN)
	_tide_label.position = Vector2(40, 30)
	_tide_label.size = Vector2(400, 40)
	_tide_label.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.1))
	_tide_label.add_theme_constant_override("outline_size", 8)
	_tide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tide_label)
	GameState.tide_changed.connect(func(_t): _refresh_tide())
	_refresh_tide()
	GameState.notice.connect(_on_notice)
	GameState.inventory_changed.connect(func(_inv): _refresh_bag())
	GameState.held_changed.connect(func(_item): _refresh_bag())
	Dialog.started.connect(func(_id): _bag.hide())
	Dialog.finished.connect(func(_id): _refresh_bag.call_deferred())
	_notice.modulate.a = 0.0
	_refresh_bag()


func _build_bag() -> void:
	_bag = PanelContainer.new()
	# the rider's canvas satchel; items are paper luggage tags (ui_2090.py)
	_bag.add_theme_stylebox_override("panel", UiKit.nine("bag_strip", 48, Vector4(34, 20, 34, 24)))
	_bag.anchor_left = 0.5
	_bag.anchor_right = 0.5
	_bag.anchor_top = 1.0
	_bag.anchor_bottom = 1.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_held_label = UiKit.hand_label("", 26, Color(0.98, 0.94, 0.82))
	_held_label.add_theme_color_override("font_outline_color", Color(0.2, 0.15, 0.08))
	_held_label.add_theme_constant_override("outline_size", 6)
	_held_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(_held_label)
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 10)
	v.add_child(_slots)
	_bag.add_child(v)
	add_child(_bag)


## The menu button is the closed debt notebook (the menu is the open one).
func _build_menu_button() -> void:
	_menu_button = Button.new()
	_menu_button.name = "MenuButton"
	_menu_button.flat = true
	_menu_button.icon = UiKit.tex("menu_book")
	_menu_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	_menu_button.text = "เมนู"
	_menu_button.add_theme_font_override("font", UiKit.FONT_SIGN)
	_menu_button.add_theme_font_size_override("font_size", 28)
	_menu_button.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_menu_button.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.5))
	_menu_button.add_theme_color_override("font_pressed_color", Color(1, 0.85, 0.5))
	_menu_button.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	_menu_button.add_theme_constant_override("outline_size", 8)
	_menu_button.add_theme_constant_override("h_separation", 0)
	for state in ["normal", "hover", "pressed", "focus"]:
		_menu_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_menu_button.anchor_left = 1.0
	_menu_button.anchor_right = 1.0
	_menu_button.offset_left = -190
	_menu_button.offset_right = -24
	_menu_button.offset_top = 12
	_menu_button.offset_bottom = 190
	_menu_button.pressed.connect(toggle_menu)
	UiKit.juice(_menu_button)
	add_child(_menu_button)


func _refresh_bag() -> void:
	UiKit.clear(_slots)
	for item in GameState.inventory:
		_slots.add_child(_slot(item))
	var held := GameState.held_item
	_held_label.visible = not held.is_empty()
	_held_label.text = (
		"ถือ %s — แตะคนหรือของเพื่อใช้ · แตะของในกระเป๋าเพื่อผสม" % Puzzles.item_name(held)
	)
	_bag.visible = not GameState.inventory.is_empty() and not Dialog.is_active() and not _riding
	# keep the bar centred on the bottom edge as it grows
	_bag.reset_size()
	var sz := _bag.get_combined_minimum_size()
	_bag.offset_left = -sz.x * 0.5
	_bag.offset_right = sz.x * 0.5
	_bag.offset_top = -20 - sz.y
	_bag.offset_bottom = -20


func _slot(item: String) -> Button:
	var b := Button.new()
	b.name = "Slot_%s" % item
	b.custom_minimum_size = SLOT_SIZE
	b.text = Puzzles.item_name(item)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", UiKit.FONT_HAND)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_constant_override("line_spacing", -4)
	b.icon = ArtLibrary.item(item)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", 84)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, UiKit.INK)
	var held := GameState.held_item == item
	var content := Vector4(10, 38, 10, 10)
	var tag := UiKit.nine("tag_held" if held else "tag", 40, content)
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, tag)
	b.add_theme_stylebox_override("pressed", UiKit.nine("tag_held", 40, content))
	b.pressed.connect(tap_item.bind(item))
	UiKit.juice(b)
	if held:
		# the held tag is lifted off the bag and tilted
		b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
		b.rotation_degrees = -4.0
		b.scale = Vector2(1.06, 1.06)
	return b


## Bag slot tapped (see class doc).
func tap_item(item: String) -> void:
	if Dialog.is_active() or GameState.input_locked:
		return
	Audio.sfx("tag", 0.1)
	var held := GameState.held_item
	if held.is_empty():
		GameState.held_item = item
	elif held == item:
		GameState.held_item = ""
		Puzzles.look(item)
	else:
		GameState.held_item = ""
		Puzzles.combine(held, item)


func _refresh_tide() -> void:
	_tide_label.text = "น้ำขึ้น" if GameState.tide == "high" else "น้ำลง"


## On the canal (BoatRide): no bag, no menu.
func set_riding(on: bool) -> void:
	_riding = on
	_menu_button.visible = not on
	_tide_label.visible = not on
	GameState.held_item = ""
	_refresh_bag()


## True when a screen point is on a HUD control (the world must ignore it).
func blocks_point(screen_pos: Vector2) -> bool:
	for c in [_bag, _menu_button, _menu, _overlay]:
		if c and c.is_visible_in_tree() and (c as Control).get_global_rect().has_point(screen_pos):
			return true
	return false


# --- menu ------------------------------------------------------------------
func toggle_menu() -> void:
	if _menu:
		close_menu()
		return
	GameState.ui_open = true
	_menu = MenuBook.new()
	_menu.closed.connect(_on_menu_closed)
	_menu.title_requested.connect(func(): get_tree().call_group("main", "go_title"))
	add_child(_menu)


func _on_menu_closed() -> void:
	_menu = null
	GameState.ui_open = _overlay != null


func close_menu() -> void:
	if _menu:
		_menu.close()
	_menu = null
	GameState.ui_open = _overlay != null


# --- cards & notices ----------------------------------------------------------
## Full-screen card (story beats, endings): a taped paper note, the title in
## red marker, the choices as tin signs. `buttons` = [[text, callable], ...].
func show_overlay(title: String, body: String, buttons: Array) -> void:
	var v := _open_note(Vector2(1240, 0))
	var head := UiKit.label(title, 56, UiKit.RED_INK)
	head.add_theme_font_override("font", UiKit.FONT_SIGN)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var text := UiKit.label(body, 31, UiKit.INK)
	text.custom_minimum_size = Vector2(1060, 0)
	text.add_theme_constant_override("line_spacing", 6)
	v.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for b in buttons:
		var btn := UiKit.sign_button(b[0], b[1], 34, 100)
		btn.custom_minimum_size.x = 380
		row.add_child(btn)
	v.add_child(row)
	_settle_note()


## A list of choices (the bike's trip menu) as pier signs on a note; the
## "ไม่ไปแล้ว" scribble closes it. `choices` = [[text, callable], ...].
func show_choices(title: String, choices: Array) -> void:
	var v := _open_note(Vector2(900, 0))
	var head := UiKit.hand_label(title, 50, UiKit.RED_INK)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	for c in choices:
		v.add_child(UiKit.sign_button(c[0], c[1], 32, 96, "teal"))
	if choices.is_empty():
		v.add_child(UiKit.hand_label("ยังไม่รู้จักที่ไหนให้ไป", 34, UiKit.INK_FADED))
	var back := UiKit.hand_button("ไม่ไปแล้ว ✕", hide_overlay, 38, UiKit.RED_INK)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(back)
	_settle_note()


## The trip menu: the hand-drawn map (MapView). `places` = [{id, name, at}],
## `current_at` = where the rider's boat sits on it; `on_pick(dest)` after the
## little boat has sailed to the pin. Closing = tap off the sheet / ✕ / Esc.
func show_map(current_at: Vector2, places: Array, on_pick: Callable, tint := Color.WHITE) -> void:
	hide_overlay()
	GameState.ui_open = true
	var map := MapView.new()
	map.name = "Overlay"
	map.setup(current_at, places, on_pick, hide_overlay, tint)
	_overlay = map
	add_child(map)


## Dim the screen and put an empty paper note in the middle; returns its column.
func _open_note(min_size: Vector2) -> VBoxContainer:
	hide_overlay()
	GameState.ui_open = true
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(UiKit.dim())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	var card := PanelContainer.new()
	card.name = "Card"
	card.add_theme_stylebox_override("panel", UiKit.note_style())
	card.custom_minimum_size = min_size
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	card.add_child(v)
	add_child(_overlay)
	return v


func _settle_note() -> void:
	var card := _overlay.get_node("Center/Card") as Control
	card.resized.connect(func(): card.pivot_offset = card.size * 0.5)
	UiKit.drop_in(card, -0.8)


func hide_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	GameState.ui_open = _menu != null


func _on_notice(text: String) -> void:
	_notices.append(text)
	if not _notice_busy:
		_next_notice()


func _next_notice() -> void:
	if _notices.is_empty():
		_notice_busy = false
		return
	_notice_busy = true
	_notice.text = _notices.pop_front()
	_notice.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_notice, "modulate:a", 1.0, 0.2)
	tween.tween_interval(NOTICE_HOLD)
	tween.tween_property(_notice, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_next_notice)


func show_title(text: String) -> void:
	if _title_tween:
		_title_tween.kill()
	_title.text = text
	_title.modulate.a = 1.0
	_title_tween = create_tween()
	_title_tween.tween_interval(TITLE_HOLD)
	_title_tween.tween_property(_title, "modulate:a", 0.0, TITLE_FADE)
