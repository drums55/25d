extends CanvasLayer
## Touch controls + interact prompt. Shows the prompt of the interactable the
## player would use right now.

@onready var _interact_button: TouchActionButton = %InteractButton
@onready var _prompt: Label = %Prompt


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var target: Interactable = null
	if player and not Dialog.is_active():
		target = player.get_nearest_interactable()
	_prompt.visible = target != null
	if target:
		_prompt.text = target.prompt
	_interact_button.modulate.a = 1.0 if target or Dialog.is_active() else 0.45
