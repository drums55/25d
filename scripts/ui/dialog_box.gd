extends PanelContainer
## Bottom-of-screen dialog box with a typewriter effect. It ignores input:
## the player advances dialog with any tap (Player.click_at) or E/J, and a
## tap while typing shows the full line.

var _tween: Tween

@onready var _speaker: Label = %Speaker
@onready var _text: Label = %Text
@onready var _hint: Label = %Hint


func _ready() -> void:
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
