extends PanelContainer
## Bottom-of-screen dialog box with a typewriter effect. It ignores input:
## the player advances dialog with any tap (Player.click_at) or E/J, and a
## tap while typing shows the full line.

var _tween: Tween

@onready var _speaker: Label = %Speaker
@onready var _text: Label = %Text
@onready var _hint: Label = %Hint


func _ready() -> void:
	# a strip of paper with the speaker's name on a little tin sign (ui_2090.py)
	add_theme_stylebox_override("panel", UiKit.nine("speech", 44, Vector4(58, 30, 58, 26)))
	_speaker.add_theme_font_override("font", UiKit.FONT_SIGN)
	_speaker.add_theme_font_size_override("font_size", 26)
	_speaker.add_theme_color_override("font_color", UiKit.SIGN_TEXT)
	_speaker.add_theme_stylebox_override("normal", UiKit.nine("sign", 30, Vector4(26, 18, 26, 14)))
	_speaker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_text.add_theme_color_override("font_color", UiKit.INK)
	_hint.add_theme_color_override("font_color", UiKit.RED_INK)
	_hint.add_theme_font_size_override("font_size", 34)
	# the "next" arrow breathes (it sits in a container, so no moving it)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_hint, "modulate:a", 0.35, 0.45)
	pulse.tween_property(_hint, "modulate:a", 1.0, 0.45)
	hide()
	Dialog.started.connect(_on_started)
	Dialog.finished.connect(_on_finished)
	Dialog.line_shown.connect(_on_line)
	Dialog.skip_typing_requested.connect(_finish_typing)


func _on_started(_id: String) -> void:
	show()


func _on_finished(_id: String) -> void:
	hide()


func _on_line(speaker: String, text: String) -> void:
	_speaker.text = speaker
	_speaker.visible = not speaker.is_empty()
	_text.text = text
	_text.visible_ratio = 0.0
	_hint.hide()
	if _tween:
		_tween.kill()
	Dialog.typing = true
	_tween = create_tween()
	_tween.tween_property(
		_text, "visible_ratio", 1.0, maxf(text.length() / Settings.chars_per_second(), 0.05)
	)
	_tween.finished.connect(_finish_typing)


func _finish_typing() -> void:
	if _tween:
		_tween.kill()
	_text.visible_ratio = 1.0
	Dialog.typing = false
	_hint.show()
