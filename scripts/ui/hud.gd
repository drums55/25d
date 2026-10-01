class_name Hud
extends CanvasLayer
## On-screen UI: ATK button, dialog box, and the room title shown on entry.

const TITLE_HOLD := 1.6
const TITLE_FADE := 0.6

var _title_tween: Tween

@onready var _title: Label = %RoomTitle


func show_title(text: String) -> void:
	if _title_tween:
		_title_tween.kill()
	_title.text = text
	_title.modulate.a = 0.0
	if text.is_empty():
		return
	_title_tween = create_tween()
	_title_tween.tween_property(_title, "modulate:a", 1.0, TITLE_FADE)
	_title_tween.tween_interval(TITLE_HOLD)
	_title_tween.tween_property(_title, "modulate:a", 0.0, TITLE_FADE)
