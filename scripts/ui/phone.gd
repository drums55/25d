class_name Phone
extends PanelContainer
## The rider app (replaces the job board): tabs งาน (offers + active orders),
## แผนที่ (city map, pick a place, ride), เงิน (wallet, debt, today's numbers),
## เมนู (save / load / settings / title). Built in code; HUD owns it.

signal sleep_requested
signal title_requested
signal visibility_toggled(open: bool)

const TABS := {"orders": "งาน", "map": "แผนที่", "wallet": "เงิน", "menu": "เมนู"}

var tab := "orders"
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tabs: HBoxContainer
var _map: CityMapView
var _map_info: VBoxContainer
var _menu_page := "save"
var _last_minute := -1


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL, 28, Color(0.3, 0.32, 0.36)))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var top := HBoxContainer.new()
	var title := UiKit.label("ไรเดอร์ห้าดาว", 36, UiKit.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UiKit.button("ปิด", close, 28, 64))
	root.add_child(top)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	_scroll.add_child(_body)
	_map = CityMapView.new()
	_map.custom_minimum_size = Vector2(0, 560)
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.place_selected.connect(_on_place)
	_map_info = VBoxContainer.new()
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	for key in TABS:
		var b := UiKit.button(TABS[key], show_tab.bind(key), 30, 80)
		b.name = key
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs.add_child(b)
	root.add_child(_tabs)
	Orders.orders_changed.connect(_refresh_if_live)
	GameState.stats_changed.connect(_refresh_if_live)
	GameState.time_changed.connect(_on_time)
	hide()


func is_open() -> bool:
	return visible


func open(which := "orders") -> void:
	show()
	visibility_toggled.emit(true)
	GameState.ui_open = true
	show_tab(which)


func close() -> void:
	hide()
	visibility_toggled.emit(false)
	GameState.ui_open = false
	GameState.clock_paused = false


func show_tab(which: String) -> void:
	tab = which
	GameState.clock_paused = which == "menu"
	for b in _tabs.get_children():
		(b as Button).button_pressed = b.name == which
	refresh()


func _on_time(_day: int, minute: float) -> void:
	if visible and int(minute) != _last_minute and tab != "menu":
		_last_minute = int(minute)
		refresh()


func _refresh_if_live() -> void:
	if visible and tab != "menu":
		refresh()


func refresh() -> void:
	if _map.get_parent():
		_map.get_parent().remove_child(_map)
	if _map_info.get_parent():
		_map_info.get_parent().remove_child(_map_info)
	UiKit.clear(_body)
	match tab:
		"orders":
			_build_orders()
		"map":
			_build_map()
		"wallet":
			_build_wallet()
		"menu":
			_build_menu()


# --- งาน --------------------------------------------------------------
func _build_orders() -> void:
	var status := (
		"%s · ★ %.2f · รับงาน %d%% · กระเป๋า %d/%d"
		% [
			"ปิดรับงานแล้ว" if GameState.is_closing() else "ออนไลน์",
			GameState.rating(),
			roundi(GameState.acceptance() * 100),
			Orders.bag_used(),
			GameState.BAG_SLOTS
		]
	)
	_body.add_child(UiKit.label(status, 26, UiKit.MUTED))
	_body.add_child(UiKit.label(Weather.summary(City.forecast()), 24, Color(0.6, 0.8, 1.0)))
	var offers := Orders.offers()
	_body.add_child(UiKit.label("งานเข้า", 32, UiKit.ACCENT))
	if offers.is_empty():
		_body.add_child(
			UiKit.label("รองานเด้ง ... (เวลาเดินไปงานใหม่จะเข้ามาเอง)", 26, UiKit.MUTED)
		)
	for o in offers:
		_body.add_child(_offer_card(o))
	_body.add_child(UiKit.label("งานที่รับไว้", 32, UiKit.ACCENT))
	var act := Orders.active()
	if act.is_empty():
		_body.add_child(UiKit.label("ยังไม่มี", 26, UiKit.MUTED))
	for o in act:
		_body.add_child(_active_card(o))
	var sleep_text := "เลิกงาน กลับไปนอน (จบวันที่ %d)" % GameState.day
	_body.add_child(UiKit.button(sleep_text, func(): sleep_requested.emit(), 28, 80))


func _offer_card(o: Dictionary) -> Control:
	var left := int(float(o["expires_at"]) - GameState.minute)
	var head := UiKit.label(
		(
			"[%s] %s · %d บาท%s"
			% [
				OrderGen.KIND_NAMES[o["kind"]],
				o["item"],
				int(o["fee"]),
				(" +ทิป %d" % int(o["tip"])) if int(o["tip"]) > 0 else ""
			]
		),
		28
	)
	var lines := [
		head,
		UiKit.label(_trip_text(o), 24, UiKit.MUTED),
		UiKit.label(_extra_text(o), 24, Color(1, 0.85, 0.5)),
	]
	var accept := UiKit.button(
		"รับงาน (หมดใน %d นาที)" % maxi(left, 0), _accept.bind(int(o["id"])), 28
	)
	accept.disabled = not Orders.can_accept(o) or GameState.is_closing()
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skip := UiKit.button("ข้าม", func(): Orders.decline(int(o["id"])), 28)
	lines.append(UiKit.row([accept, skip]))
	return UiKit.card(lines)


func _accept(id: int) -> void:
	if not Orders.accept(id):
		GameState.notice.emit("กระเป๋าเต็ม รับไม่ไหว")


func _trip_text(o: Dictionary) -> String:
	var to_pick := City.route_to(int(o["pickup"]))
	var pick_min := "?" if to_pick.is_empty() else "%d นาที" % roundi(to_pick["minutes"])
	return (
		"รับ: %s (ห่างคุณ %s)\nส่ง: %s → %s"
		% [City.node_name(o["pickup"]), pick_min, o["customer"], City.node_name(o["dropoff"])]
	)


func _extra_text(o: Dictionary) -> String:
	var parts: Array[String] = ["ส่งภายใน %s" % Weather.clock_text(o["deadline"])]
	if o["kind"] == "food":
		parts.append("อาหารเสร็จ %s" % Weather.clock_text(o["ready_at"]))
	if int(o["cod"]) > 0:
		parts.append("เก็บเงินปลายทาง %d (ต้องสำรองจ่าย)" % int(o["cod"]))
	if int(o["size"]) > 1:
		parts.append("ของใหญ่ กิน 2 ช่อง")
	if o["kind"] == "doc":
		parts.append("ต้องให้ %s เซ็นรับเท่านั้น" % o["sign_name"])
	return " · ".join(parts)


func _active_card(o: Dictionary) -> Control:
	var picked: bool = o["status"] == "picked"
	var where: int = o["dropoff"] if picked else o["pickup"]
	var verb := "ไปส่ง" if picked else "ไปรับ"
	var state := "%s ที่ %s" % [verb, City.node_name(where)]
	if picked and o["kind"] == "food":
		state += " · " + OrderGen.heat_text(OrderGen.heat(o, GameState.minute))
		if o.get("spilled", false):
			state += " · หก!"
	var left := int(float(o["deadline"]) - GameState.minute)
	var due := "สายแล้ว %d นาที" % -left if left < 0 else "เหลือ %d นาที" % left
	var items := [
		UiKit.label(
			"[%s] %s · %d บาท" % [OrderGen.KIND_NAMES[o["kind"]], o["item"], int(o["fee"])], 26
		),
		UiKit.label("%s · %s" % [state, due], 24, UiKit.WARN if left < 0 else UiKit.MUTED),
	]
	var go := UiKit.button("นำทาง", _navigate.bind(where), 26, 64)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := [go]
	if not picked:
		row.append(UiKit.button("ยกเลิก", func(): Orders.cancel(int(o["id"])), 26, 64))
	items.append(UiKit.row(row))
	return UiKit.card(items)


func _navigate(node_id: int) -> void:
	show_tab("map")
	_map.select(node_id)


# --- แผนที่ -------------------------------------------------------------
func _build_map() -> void:
	_body.add_child(_map)
	_body.add_child(_map_info)
	if _map.selected < 0:
		_map.select(GameState.location)
	else:
		_on_place(_map.selected)


func _on_place(id: int) -> void:
	UiKit.clear(_map_info)
	var n := City.node(id)
	_map_info.add_child(
		UiKit.label("%s (%s) · %s" % [n["name"], CityGen.TYPES[n["type"]], n["area"]], 28)
	)
	var rain := City.rain_now()
	if rain > 0:
		_map_info.add_child(
			UiKit.label(
				"%s — ขี่ช้าลง ถนนบางเส้นน้ำท่วม" % Weather.describe(rain), 24, Color(0.6, 0.8, 1)
			)
		)
	if id == GameState.location:
		_map_info.add_child(UiKit.label("คุณอยู่ที่นี่", 26, UiKit.ACCENT))
		return
	var r: Dictionary = _map.route
	if r.is_empty():
		_map_info.add_child(
			UiKit.label("ไปไม่ได้ตอนนี้ — น้ำท่วมปิดทุกเส้นทาง รอน้ำลดก่อน", 26, UiKit.WARN)
		)
		return
	var litres: float = r["km"] / GameState.KM_PER_LITRE
	var info := "%d นาที · %.1f กม. · ใช้น้ำมัน %.2f ลิตร" % [roundi(r["minutes"]), r["km"], litres]
	_map_info.add_child(UiKit.label(info, 26))
	if r["wade"]:
		_map_info.add_child(UiKit.label("ต้องลุยน้ำท่วม: ช้า อาหารอาจหก", 24, UiKit.WARN))
	if litres > GameState.fuel:
		_map_info.add_child(UiKit.label("น้ำมันไม่พอ! จะต้องเข็นรถช่วงท้าย", 24, UiKit.WARN))
	_map_info.add_child(UiKit.button("ขี่ไป %s" % n["name"], _ride.bind(id), 30, 84))


func _ride(id: int) -> void:
	var r: Dictionary = _map.route
	close()
	City.travel(id, r)
	_map.selected = -1


# --- เงิน --------------------------------------------------------------
func _build_wallet() -> void:
	var g := GameState
	_body.add_child(UiKit.label("เงินสด %d บาท" % g.money, 36, UiKit.ACCENT))
	_body.add_child(
		UiKit.label(
			(
				(
					"หนี้นอกระบบ (ดอกลอย): เงินต้น %d · ดอกทุกเช้า %d · ค่าเช่ารถเฮียเป้ง %d/วัน\n"
					+ "เตือนจากเจ้าหนี้ %d/%d ครั้ง (ครบ = รถโดนยึด)"
				)
				% [g.debt, g.DEBT_INTEREST, g.BIKE_RENT, g.missed_payments, g.MISSES_TO_LOSE_BIKE]
			),
			26
		)
	)
	var pay := UiKit.row(
		[
			UiKit.button("จ่ายต้น 100", func(): g.pay_debt(100), 26, 70),
			UiKit.button("จ่ายต้น 500", func(): g.pay_debt(500), 26, 70),
			UiKit.button("จ่ายเท่าที่มี", func(): g.pay_debt(g.money), 26, 70),
		]
	)
	_body.add_child(pay)
	(
		_body
		. add_child(
			(
				UiKit
				. label(
					(
						"น้ำมัน %.2f / %.0f ลิตร (เติมได้ที่ปั๊ม) · เรตติ้ง ★ %.2f (ต่ำกว่า %.1f = ปิดบัญชี)"
						% [g.fuel, g.FUEL_TANK, g.rating(), g.MIN_RATING]
					),
					26
				)
			)
		)
	)
	_body.add_child(UiKit.label("วันนี้", 32, UiKit.ACCENT))
	_body.add_child(UiKit.label(slip_text(g.log_today), 26))


static func slip_text(log: Dictionary) -> String:
	return (
		(
			"ส่งสำเร็จ %d งาน\nค่ารอบ %d · ทิป %d\nน้ำมันใช้ไป %.2f ลิตร · จ่ายค่าน้ำมัน %d\n"
			+ "สำรองจ่าย COD %d · เก็บคืน %d\nจ่ายหนี้เงินต้น %d"
		)
		% [
			int(log.get("delivered", 0)),
			int(log.get("fees", 0)),
			int(log.get("tips", 0)),
			float(log.get("fuel_l", 0.0)),
			-int(log.get("fuel", 0)),
			-int(log.get("cod_out", 0)),
			int(log.get("cod_in", 0)),
			-int(log.get("debt", 0)),
		]
	)


# --- เมนู --------------------------------------------------------------
func _build_menu() -> void:
	var pages := {"save": "บันทึก", "load": "โหลด", "settings": "ตั้งค่า"}
	var bar := HBoxContainer.new()
	for key in pages:
		var b := UiKit.button(pages[key], _menu.bind(key), 28, 70)
		b.toggle_mode = true
		b.button_pressed = key == _menu_page
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(b)
	bar.add_child(UiKit.button("หน้าแรก", func(): title_requested.emit(), 28, 70))
	_body.add_child(bar)
	match _menu_page:
		"save":
			_body.add_child(SaveSlots.new("save"))
		"load":
			var slots := SaveSlots.new("load")
			slots.loaded.connect(_on_loaded)
			_body.add_child(slots)
		"settings":
			_body.add_child(SettingsPanel.new())


func _menu(page: String) -> void:
	_menu_page = page
	refresh()


func _on_loaded(_slot: int) -> void:
	close()
	SceneRouter.go_to(GameState.LOCATION_SCENE, "arrival")
