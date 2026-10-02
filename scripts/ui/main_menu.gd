extends Control
## Title screen: continue (latest save), new game, load, settings, quit.

const GAME_SCENE := "res://scenes/main.tscn"

var _side: PanelContainer
var _continue: Button


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var left := VBoxContainer.new()
	left.position = Vector2(120, 140)
	left.custom_minimum_size = Vector2(760, 0)
	left.add_theme_constant_override("separation", 18)
	add_child(left)
	left.add_child(UiKit.label("ไรเดอร์ห้าดาว", 96, UiKit.ACCENT))
	left.add_child(UiKit.label("กรุงเทพฯ 2090 จมไปครึ่งเมือง ... หนี้ยังไม่จม", 32, UiKit.MUTED))
	left.add_child(Control.new())
	_continue = UiKit.button("เล่นต่อ", _on_continue, 40, 100)
	_continue.disabled = GameState.latest_slot() < 0
	left.add_child(_continue)
	left.add_child(UiKit.button("เกมใหม่", _on_new, 40, 100))
	left.add_child(UiKit.button("โหลดเกม", _show_load, 40, 100))
	left.add_child(UiKit.button("ตั้งค่า", _show_settings, 40, 100))
	left.add_child(UiKit.button("ออกจากเกม", func(): get_tree().quit(), 40, 100))
	_side = PanelContainer.new()
	_side.add_theme_stylebox_override("panel", UiKit.panel_style())
	_side.position = Vector2(920, 140)
	_side.custom_minimum_size = Vector2(880, 900)
	_side.hide()
	add_child(_side)


func _on_continue() -> void:
	var slot := GameState.latest_slot()
	if slot >= 0 and GameState.load_game(slot):
		get_tree().change_scene_to_file(GAME_SCENE)


func _on_new() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _show_load() -> void:
	UiKit.clear(_side)
	var slots := SaveSlots.new("load")
	slots.loaded.connect(func(_s): get_tree().change_scene_to_file(GAME_SCENE))
	_side.add_child(slots)
	_side.show()


func _show_settings() -> void:
	UiKit.clear(_side)
	_side.add_child(SettingsPanel.new())
	_side.show()
