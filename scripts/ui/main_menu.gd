extends Control
## Title screen: continue (latest save), new game, load, settings, quit.

const GAME_SCENE := "res://scenes/main.tscn"
## Where the rider's boat floats on the key art (fraction of the screen) and how big.
const BOAT_AT := Vector2(0.6, 0.86)
const BOAT_SCALE := 1.7

var _side: PanelContainer
var _continue: Button


func _ready() -> void:
	Audio.music("title")
	Audio.ambience("day")
	# key art: กรุงเทพฯ 2090 at dusk (tools/art/png/title_2090.py), covering any aspect
	var bg := TextureRect.new()
	bg.texture = UiKit.tex("title_bg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_add_rider()
	var left := VBoxContainer.new()
	left.position = Vector2(120, 110)
	left.custom_minimum_size = Vector2(620, 0)
	left.add_theme_constant_override("separation", 16)
	add_child(left)
	var title := UiKit.label("บ้านเลขที่ 0", 112, Color(1.0, 0.82, 0.36))
	title.add_theme_font_override("font", UiKit.FONT_SIGN)
	title.add_theme_color_override("font_outline_color", Color(0.45, 0.08, 0.06))
	title.add_theme_constant_override("outline_size", 20)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.add_child(title)
	var sub := UiKit.label(
		"กรุงเทพฯ 2090 จมไปครึ่งเมือง ... หนี้ยังไม่จม", 32, Color(1.0, 0.9, 0.78)
	)
	sub.add_theme_font_override("font", UiKit.FONT_HAND)
	sub.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.1))
	sub.add_theme_constant_override("outline_size", 8)
	left.add_child(sub)
	left.add_child(Control.new())
	_continue = UiKit.sign_button("เล่นต่อ", _on_continue, 40, 100)
	_continue.disabled = GameState.latest_slot() < 0
	left.add_child(_continue)
	left.add_child(UiKit.sign_button("เกมใหม่", _on_new, 40, 100))
	left.add_child(UiKit.sign_button("โหลดเกม", _show_load, 40, 100))
	left.add_child(UiKit.sign_button("ตั้งค่า", _show_settings, 40, 100))
	left.add_child(UiKit.sign_button("ออกจากเกม", func(): get_tree().quit(), 40, 100))
	_side = PanelContainer.new()
	_side.add_theme_stylebox_override("panel", UiKit.note_style())
	_side.position = Vector2(860, 120)
	_side.custom_minimum_size = Vector2(880, 900)
	_side.hide()
	add_child(_side)
	# the title drops in like the story cards
	title.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(title, "modulate:a", 1.0, 0.6)


## The rider on the เรือเตอร์ไซค์, bobbing on the canal with steam puffing out.
func _add_rider() -> void:
	var holder := Control.new()
	holder.name = "Boat"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# anchored to the painting's water, right of the menu column
	holder.anchor_left = BOAT_AT.x
	holder.anchor_right = BOAT_AT.x
	holder.anchor_top = BOAT_AT.y
	holder.anchor_bottom = BOAT_AT.y
	add_child(holder)
	var boat := Node2D.new()
	boat.scale = Vector2.ONE * BOAT_SCALE
	holder.add_child(boat)
	var tex := ArtLibrary.prop("boat_bike")
	if tex:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + ArtLibrary.PROP_FOOT_MARGIN)
		s.scale = Vector2.ONE / ArtLibrary.ART_SCALE
		boat.add_child(s)
	var who := (load("res://scenes/characters/character_view.tscn") as PackedScene).instantiate()
	who.character_name = "rider"
	who.position = BoatRide.RIDER_SEAT
	boat.add_child(who)
	who.set_facing(Iso.Dir.SE)
	who.set_pose("ride")
	var puff := CPUParticles2D.new()
	puff.position = Vector2(-44, -150)
	puff.amount = 10
	puff.lifetime = 2.2
	puff.direction = Vector2(-0.4, -1)
	puff.spread = 18.0
	puff.gravity = Vector2(-10, -30)
	puff.initial_velocity_min = 30.0
	puff.initial_velocity_max = 50.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.75))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	puff.color_ramp = fade
	var dot := GradientTexture2D.new()
	dot.width = 16
	dot.height = 16
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = soft
	puff.texture = dot
	puff.scale_amount_min = 1.2
	puff.scale_amount_max = 2.4
	boat.add_child(puff)
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	bob.tween_property(boat, "position:y", 8.0, 1.3)
	bob.parallel().tween_property(boat, "rotation_degrees", 1.6, 1.3)
	bob.tween_property(boat, "position:y", -2.0, 1.3)
	bob.parallel().tween_property(boat, "rotation_degrees", -1.2, 1.3)


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
