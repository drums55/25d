class_name SettingsPanel
extends VBoxContainer
## Settings: clock speed, text speed, volume, hints (Settings autoload).


func _init() -> void:
	add_theme_constant_override("separation", 10)


func _ready() -> void:
	refresh()


func refresh() -> void:
	UiKit.clear(self)
	add_child(UiKit.label("ตั้งค่า", 34, UiKit.ACCENT))
	add_child(UiKit.label("ความเร็วนาฬิกาในเกม", 26, UiKit.MUTED))
	add_child(_choices(Settings.CLOCK_SPEEDS.keys(), Settings.clock_speed, _set_clock))
	add_child(UiKit.label("ความเร็วช่วงขี่", 26, UiKit.MUTED))
	add_child(_choices(Settings.RIDE_SPEEDS.keys(), Settings.ride_speed, _set_ride))
	add_child(UiKit.label("ความเร็วตัวหนังสือ", 26, UiKit.MUTED))
	add_child(_choices(Settings.TEXT_SPEEDS.keys(), Settings.text_speed, _set_text))
	add_child(UiKit.label("เสียง %d%%" % roundi(Settings.volume * 100), 26, UiKit.MUTED))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.1
	vol.value = Settings.volume
	vol.custom_minimum_size = Vector2(0, 50)
	vol.value_changed.connect(_set_volume)
	add_child(vol)
	var hints := CheckButton.new()
	hints.text = "แสดงคำแนะนำ"
	hints.button_pressed = Settings.show_hints
	hints.add_theme_font_size_override("font_size", 28)
	hints.toggled.connect(_set_hints)
	add_child(hints)
	var skip := CheckButton.new()
	skip.text = "ข้ามช่วงขี่ (ถึงที่หมายทันที)"
	skip.button_pressed = Settings.skip_ride
	skip.add_theme_font_size_override("font_size", 28)
	skip.toggled.connect(_set_skip)
	add_child(skip)


func _choices(keys: Array, current: String, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for k in keys:
		var b := UiKit.button(str(k), cb.bind(str(k)), 26, 64)
		b.toggle_mode = true
		b.button_pressed = k == current
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	return h


func _set_clock(v: String) -> void:
	Settings.clock_speed = v
	Settings.save_settings()
	refresh()


func _set_text(v: String) -> void:
	Settings.text_speed = v
	Settings.save_settings()
	refresh()


func _set_volume(v: float) -> void:
	Settings.volume = v
	Settings.save_settings()


func _set_hints(on: bool) -> void:
	Settings.show_hints = on
	Settings.save_settings()


func _set_skip(on: bool) -> void:
	Settings.skip_ride = on
	Settings.save_settings()


func _set_ride(v: String) -> void:
	Settings.ride_speed = v
	Settings.save_settings()
	refresh()
