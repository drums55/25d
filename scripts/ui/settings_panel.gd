class_name SettingsPanel
extends VBoxContainer
## Settings written in the notebook: text speed, volume, hints, skipping the
## canal ride (Settings autoload).


func _init() -> void:
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	refresh()


func refresh() -> void:
	UiKit.clear(self)
	add_child(UiKit.hand_label("ตั้งค่า", 46, UiKit.RED_INK))
	add_child(UiKit.hand_label("ความเร็วตัวหนังสือ", 30, UiKit.INK_FADED))
	add_child(_choices(Settings.TEXT_SPEEDS.keys(), Settings.text_speed, _set_text))
	add_child(UiKit.hand_label("เสียง %d%%" % roundi(Settings.volume * 100), 30, UiKit.INK_FADED))
	add_child(UiKit.ink_slider(Settings.volume, _set_volume))
	add_child(UiKit.hand_check("แสดงคำแนะนำ", Settings.show_hints, _set_hints))
	add_child(UiKit.hand_check("ข้ามช่วงขี่มอไซ", Settings.skip_ride, _set_skip))


## Options in a row; the chosen one is ticked in red.
func _choices(keys: Array, current: String, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	for k in keys:
		var on: bool = str(k) == current
		var b := UiKit.hand_button(
			("✓ " if on else "") + str(k), cb.bind(str(k)), 34, UiKit.RED_INK if on else UiKit.INK
		)
		h.add_child(b)
	return h


func _set_text(v: String) -> void:
	Settings.text_speed = v
	Settings.save_settings()
	refresh()


func _set_volume(v: float) -> void:
	Settings.volume = v
	Settings.save_settings()
	(get_child(3) as Label).text = "เสียง %d%%" % roundi(v * 100)


func _set_hints(on: bool) -> void:
	Settings.show_hints = on
	Settings.save_settings()


func _set_skip(on: bool) -> void:
	Settings.skip_ride = on
	Settings.save_settings()
