class_name MenuBook
extends Control
## The in-game menu = the rider's debt notebook lying open (owner 2026-10-02:
## the old menu "looked like PowerPoint"). Left page: what's written in it
## (hint, save, load, settings, back to the title), the open page circled in
## red pen. Right page: that page. Tapping outside the book or "ปิดสมุด" closes.
## Art: assets/art/ui/notebook.png (tools/art/png/ui_2090.py).

signal closed
signal title_requested

const BOOK_SIZE := Vector2(1520, 1000)
## Page boxes in notebook coordinates (ruled lines every 64 px from y 150).
const LEFT := Rect2(150, 52, 580, 880)
const RIGHT := Rect2(862, 52, 580, 880)
const PAGES := [
	["คำใบ้", "hint"],
	["บันทึกเกม", "save"],
	["โหลดเกม", "load"],
	["ตั้งค่า", "settings"],
]

var page := ""
var _book: Control
var _right: VBoxContainer
var _circle: TextureRect
var _items := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dim(close))
	_book = Control.new()
	_book.size = BOOK_SIZE
	_book.custom_minimum_size = BOOK_SIZE
	_book.set_anchors_preset(Control.PRESET_CENTER)
	_book.offset_left = -BOOK_SIZE.x * 0.5
	_book.offset_top = -BOOK_SIZE.y * 0.5
	_book.offset_right = BOOK_SIZE.x * 0.5
	_book.offset_bottom = BOOK_SIZE.y * 0.5
	_book.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_book)
	var art := TextureRect.new()
	art.texture = UiKit.tex("notebook")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.size = BOOK_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(art)
	_build_left()
	_right = VBoxContainer.new()
	_right.position = RIGHT.position
	_right.size = RIGHT.size
	_right.add_theme_constant_override("separation", 6)
	_book.add_child(_right)
	open_page("save")
	Audio.sfx("book_open")
	_book.pivot_offset = BOOK_SIZE * 0.5
	_book.scale = Vector2(0.9, 0.9)
	_book.rotation_degrees = -3.0
	modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.12)
	t.tween_property(_book, "scale", Vector2.ONE, 0.3)
	t.tween_property(_book, "rotation_degrees", -0.6, 0.3)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_left() -> void:
	var head := UiKit.hand_label("สมุดหนี้ของไรเดอร์", 50, UiKit.RED_INK)
	head.position = LEFT.position + Vector2(0, 8)
	head.size = Vector2(LEFT.size.x, 70)
	_book.add_child(head)
	var tide := "น้ำขึ้น" if GameState.tide == "high" else "น้ำลง"
	var where := UiKit.hand_label(
		"บทที่ %d · วันที่ %d · %s" % [GameState.chapter, GameState.day, tide], 28, UiKit.INK_FADED
	)
	where.position = LEFT.position + Vector2(4, 98)
	where.size = Vector2(LEFT.size.x, 40)
	_book.add_child(where)
	_circle = TextureRect.new()
	_circle.texture = UiKit.tex("pen_circle")
	_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_circle)
	var y := 196.0
	for p in PAGES:
		var b := UiKit.hand_button(p[0], open_page.bind(p[1]), 46)
		b.name = "Page_%s" % p[1]
		b.position = Vector2(LEFT.position.x + 20, y)
		b.size = Vector2(LEFT.size.x - 40, 84)
		_book.add_child(b)
		_items[p[1]] = b
		y += 128.0
	var home := UiKit.hand_button(
		"กลับหน้าแรก", func(): title_requested.emit(), 36, UiKit.INK_FADED
	)
	home.position = Vector2(LEFT.position.x + 20, 732)
	home.size = Vector2(300, 64)
	_book.add_child(home)
	var shut := UiKit.hand_button("ปิดสมุด ✕", close, 40, UiKit.RED_INK)
	shut.name = "Close"
	shut.position = Vector2(LEFT.position.x + 20, 800)
	shut.size = Vector2(300, 70)
	_book.add_child(shut)


func open_page(id: String) -> void:
	page = id
	var item: Control = _items[id]
	_circle.position = item.position + Vector2(-34, -6)
	_circle.size = Vector2(item.get_minimum_size().x + 70, 96)
	_circle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_circle.stretch_mode = TextureRect.STRETCH_SCALE
	UiKit.clear(_right)
	match id:
		"hint":
			_page_hint()
		"save":
			_right.add_child(SaveSlots.new("save"))
		"load":
			var slots := SaveSlots.new("load")
			slots.loaded.connect(_on_loaded)
			_right.add_child(slots)
		"settings":
			_right.add_child(SettingsPanel.new())
	_right.modulate.a = 0.0
	create_tween().tween_property(_right, "modulate:a", 1.0, 0.18)


## The hint, written in the book (ป้าจุ๋ม's voice once she is a friend).
func _page_hint() -> void:
	var friend := GameState.has_flag("jum_friend")
	_right.add_child(UiKit.hand_label("คำใบ้", 46, UiKit.RED_INK))
	var who := "ป้าจุ๋มโทรมาบอกว่า ..." if friend else "จดไว้กันลืม ..."
	_right.add_child(UiKit.hand_label(who, 30, UiKit.INK_FADED))
	var text := UiKit.hand_label(Puzzles.hint_text(Puzzles.data, GameState.flags), 38)
	text.custom_minimum_size = Vector2(RIGHT.size.x, 0)
	_right.add_child(text)


func _on_loaded(_slot: int) -> void:
	close()
	get_tree().call_group("main", "go_room", GameState.room, GameState.spawn)


func close() -> void:
	if is_queued_for_deletion():
		return
	Audio.sfx("book_close")
	closed.emit()
	queue_free()
