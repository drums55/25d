class_name Hud
extends CanvasLayer
## On-screen UI: money/debt, fuel/rating line, the day dial + weather, the
## orders in progress, notices, dialog box, and the rider app (Phone) with its
## button and the "new order" banner. Point & click elsewhere: Player asks
## blocks_point() so taps on UI never walk the rider.

const TITLE_HOLD := 1.6
const TITLE_FADE := 0.6
const NOTICE_HOLD := 2.2

var phone: Phone
var _title_tween: Tween
var _notices: Array[String] = []
var _notice_busy := false
var _phone_button: Button
var _banner: Button
var _overlay: PanelContainer
var _rain: RainOverlay

@onready var _title: Label = %RoomTitle
@onready var _money: Label = %Money
@onready var _stats: Label = %Clock
@onready var _items: Label = %Items
@onready var _notice: Label = %Notice
@onready var _deliveries: Label = %Deliveries
@onready var _day_clock: DayClock = %DayClock


func _ready() -> void:
	add_to_group("hud")
	_items.visible = false
	_rain = RainOverlay.new()
	_rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rain)
	move_child(_rain, 0)
	_build_phone()
	phone.sleep_requested.connect(func(): get_tree().call_group("main", "sleep"))
	phone.title_requested.connect(func(): get_tree().call_group("main", "go_title"))
	GameState.money_changed.connect(_on_money)
	GameState.notice.connect(_on_notice)
	GameState.time_changed.connect(_on_time)
	GameState.stats_changed.connect(_refresh_stats)
	Orders.orders_changed.connect(_refresh_orders)
	Orders.offer_added.connect(_on_offer)
	_on_money(GameState.money)
	_refresh_stats()
	_refresh_orders()
	_notice.modulate.a = 0.0


func _build_phone() -> void:
	phone = Phone.new()
	phone.anchor_left = 1.0
	phone.anchor_right = 1.0
	phone.anchor_bottom = 1.0
	phone.offset_left = -880
	phone.offset_right = -24
	phone.offset_top = 24
	phone.offset_bottom = -24
	add_child(phone)
	_phone_button = UiKit.button("แอปไรเดอร์", func(): open_phone("orders"), 34, 96)
	_phone_button.anchor_left = 1.0
	_phone_button.anchor_top = 1.0
	_phone_button.anchor_right = 1.0
	_phone_button.anchor_bottom = 1.0
	_phone_button.offset_left = -330
	_phone_button.offset_top = -130
	_phone_button.offset_right = -30
	_phone_button.offset_bottom = -30
	_phone_button.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.ACCENT_DARK, 24))
	add_child(_phone_button)
	phone.visibility_toggled.connect(func(open: bool): _phone_button.visible = not open)
	_banner = UiKit.button("", func(): open_phone("orders"), 30, 84)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -520
	_banner.offset_right = 520
	_banner.offset_top = 170
	_banner.offset_bottom = 254
	_banner.add_theme_stylebox_override("normal", UiKit.panel_style(UiKit.ACCENT_DARK, 20))
	_banner.hide()
	add_child(_banner)


## True when a screen point is on a HUD control (the world must ignore it).
func blocks_point(screen_pos: Vector2) -> bool:
	for c in [phone, _phone_button, _banner, _overlay]:
		if c and c.is_visible_in_tree() and (c as Control).get_global_rect().has_point(screen_pos):
			return true
	return false


func open_phone(tab := "orders") -> void:
	if not GameState.finished.is_empty():
		return
	_banner.hide()
	phone.open(tab)


func _on_offer(o: Dictionary) -> void:
	_phone_button.text = "แอปไรเดอร์ (%d)" % Orders.offers().size()
	if phone.is_open():
		return
	_banner.text = (
		"งานใหม่! [%s] %d บาท · %s — แตะเพื่อดู"
		% [OrderGen.KIND_NAMES[o["kind"]], int(o["fee"]), City.node_name(o["pickup"])]
	)
	_banner.show()
	var tween := create_tween()
	tween.tween_interval(6.0)
	tween.tween_callback(_banner.hide)


func _on_time(_day: int, _minute: float) -> void:
	_day_clock.queue_redraw()
	_refresh_orders()
	_rain.level = City.rain_now() if City.has_city() else 0


func _on_money(money: int) -> void:
	_money.text = "฿ %d · หนี้ %d" % [money, GameState.debt]


func _refresh_stats() -> void:
	_on_money(GameState.money)
	_stats.text = (
		"น้ำมัน %.1f ลิตร · ★ %.2f · รับงาน %d%%"
		% [GameState.fuel, GameState.rating(), roundi(GameState.acceptance() * 100)]
	)


## Orders in progress with countdowns, under the day dial.
func _refresh_orders() -> void:
	_phone_button.text = (
		"แอปไรเดอร์ (%d)" % Orders.offers().size() if Orders.offers().size() > 0 else "แอปไรเดอร์"
	)
	var rows: Array[String] = []
	for o in Orders.active():
		var picked: bool = o["status"] == "picked"
		var where: int = o["dropoff"] if picked else o["pickup"]
		var left := int(float(o.get("deadline", GameState.minute)) - GameState.minute)
		var due := "สายแล้ว!" if left < 0 else "เหลือ %d นาที" % left
		var heat := ""
		if picked and o["kind"] == "food":
			heat = " · " + OrderGen.heat_text(OrderGen.heat(o, GameState.minute))
		rows.append(
			(
				"[%s] %s %s%s · %s"
				% [
					OrderGen.KIND_NAMES[o["kind"]],
					"ส่ง" if picked else "รับ",
					City.node_name(where),
					heat,
					due
				]
			)
		)
	_deliveries.text = "\n".join(rows)


## Full-screen card (day slip, ending). `buttons` = [[text, callable], ...].
func show_overlay(title: String, body: String, buttons: Array) -> void:
	hide_overlay()
	GameState.ui_open = true
	GameState.clock_paused = true
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
	_overlay.offset_top = -430
	_overlay.offset_bottom = 430
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
	GameState.clock_paused = false


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
