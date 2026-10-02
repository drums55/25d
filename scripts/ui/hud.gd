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
const SLOT_SIZE := Vector2(170, 130)

var _title_tween: Tween
var _notices: Array[String] = []
var _notice_busy := false
var _bag: PanelContainer
var _slots: HBoxContainer
var _held_label: Label
var _menu_button: Button
var _menu: PanelContainer
var _menu_body: VBoxContainer
var _overlay: PanelContainer

@onready var _title: Label = %RoomTitle
@onready var _notice: Label = %Notice


func _ready() -> void:
	add_to_group("hud")
	_build_bag()
	_build_menu_button()
	GameState.notice.connect(_on_notice)
	GameState.inventory_changed.connect(func(_inv): _refresh_bag())
	GameState.held_changed.connect(func(_item): _refresh_bag())
	Dialog.started.connect(func(_id): _bag.hide())
	Dialog.finished.connect(func(_id): _refresh_bag.call_deferred())
	_notice.modulate.a = 0.0
	_refresh_bag()


func _build_bag() -> void:
	_bag = PanelContainer.new()
	_bag.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.08, 0.07, 0.06, 0.85), 22))
	_bag.anchor_left = 0.5
	_bag.anchor_right = 0.5
	_bag.anchor_top = 1.0
	_bag.anchor_bottom = 1.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_held_label = UiKit.label("", 24, UiKit.ACCENT)
	_held_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(_held_label)
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 10)
	v.add_child(_slots)
	_bag.add_child(v)
	add_child(_bag)


func _build_menu_button() -> void:
	_menu_button = UiKit.button("เมนู", toggle_menu, 30, 80)
	_menu_button.anchor_left = 1.0
	_menu_button.anchor_right = 1.0
	_menu_button.offset_left = -200
	_menu_button.offset_right = -30
	_menu_button.offset_top = 30
	_menu_button.offset_bottom = 110
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
	_bag.visible = not GameState.inventory.is_empty() and not Dialog.is_active()
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
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", UiKit.TEXT)
	var held := GameState.held_item == item
	var base := Puzzles.item_color(item).darkened(0.45)
	var style := UiKit.panel_style(base, 16, UiKit.ACCENT if held else base.lightened(0.3))
	style.set_border_width_all(6 if held else 2)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, style)
	b.pressed.connect(tap_item.bind(item))
	return b


## Bag slot tapped (see class doc).
func tap_item(item: String) -> void:
	if Dialog.is_active() or GameState.input_locked:
		return
	var held := GameState.held_item
	if held.is_empty():
		GameState.held_item = item
	elif held == item:
		GameState.held_item = ""
		Puzzles.look(item)
	else:
		GameState.held_item = ""
		Puzzles.combine(held, item)


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
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override(
		"panel", UiKit.panel_style(UiKit.PANEL, 24, UiKit.ACCENT_DARK)
	)
	_menu.anchor_left = 0.5
	_menu.anchor_top = 0.5
	_menu.anchor_right = 0.5
	_menu.anchor_bottom = 0.5
	_menu.offset_left = -560
	_menu.offset_right = 560
	_menu.offset_top = -470
	_menu.offset_bottom = 470
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	for page in [["บันทึก", "save"], ["โหลด", "load"], ["ตั้งค่า", "settings"]]:
		var b := UiKit.button(page[0], _menu_page.bind(page[1]), 28, 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(b)
	bar.add_child(
		UiKit.button("หน้าแรก", func(): get_tree().call_group("main", "go_title"), 28, 70)
	)
	bar.add_child(UiKit.button("ปิด", close_menu, 28, 70))
	v.add_child(bar)
	_menu_body = VBoxContainer.new()
	_menu_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_menu_body)
	_menu.add_child(v)
	add_child(_menu)
	_menu_page("save")


func _menu_page(page: String) -> void:
	UiKit.clear(_menu_body)
	match page:
		"save":
			_menu_body.add_child(SaveSlots.new("save"))
		"load":
			var slots := SaveSlots.new("load")
			slots.loaded.connect(_on_loaded)
			_menu_body.add_child(slots)
		"settings":
			_menu_body.add_child(SettingsPanel.new())


func _on_loaded(_slot: int) -> void:
	close_menu()
	get_tree().call_group("main", "go_room", GameState.room, GameState.spawn)


func close_menu() -> void:
	if _menu:
		_menu.queue_free()
		_menu = null
	GameState.ui_open = false


# --- cards & notices ----------------------------------------------------------
## Full-screen card (story beats, endings). `buttons` = [[text, callable], ...].
func show_overlay(title: String, body: String, buttons: Array) -> void:
	hide_overlay()
	GameState.ui_open = true
	_overlay = PanelContainer.new()
	_overlay.add_theme_stylebox_override(
		"panel", UiKit.panel_style(UiKit.PANEL, 24, UiKit.ACCENT_DARK)
	)
	_overlay.anchor_left = 0.5
	_overlay.anchor_top = 0.5
	_overlay.anchor_right = 0.5
	_overlay.anchor_bottom = 0.5
	_overlay.offset_left = -620
	_overlay.offset_right = 620
	_overlay.offset_top = -380
	_overlay.offset_bottom = 380
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.add_child(UiKit.label(title, 48, UiKit.ACCENT))
	var text := UiKit.label(body, 30)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	for b in buttons:
		var btn := UiKit.button(b[0], b[1], 32, 90)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
	v.add_child(row)
	_overlay.add_child(v)
	add_child(_overlay)


func hide_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	GameState.ui_open = false


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
