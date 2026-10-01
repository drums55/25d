extends PanelContainer
## Bottom-of-screen dialog box with a typewriter effect. Tap it (or press
## attack/interact) to advance; a tap while typing shows the full line.

@export var chars_per_second := 45.0

var _tween: Tween

@onready var _speaker: Label = %Speaker
@onready var _text: Label = %Text
@onready var _hint: Label = %Hint


func _ready() -> void:
	hide()
	Dialog.started.connect(func(_id): show())
	Dialog.finished.connect(func(_id): hide())
	Dialog.line_shown.connect(_on_line)
	Dialog.skip_typing_requested.connect(_finish_typing)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		Dialog.advance()
		accept_event()


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
	_tween.tween_property(_text, "visible_ratio", 1.0, maxf(text.length() / chars_per_second, 0.05))
	_tween.finished.connect(_finish_typing)


func _finish_typing() -> void:
	if _tween:
		_tween.kill()
	_text.visible_ratio = 1.0
	Dialog.typing = false
	_hint.show()
