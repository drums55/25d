class_name Interactable
extends Area2D
## Something the player can use with the interact button. Plays `dialog_id`
## if set, and always emits `interacted` so scenes can add custom behaviour.

signal interacted(by: Node)

@export var prompt := "Talk"
@export var dialog_id := ""
## Identity for the job system (pickup/dropoff target), e.g. "lung_pradit".
@export var npc_id := ""
## Opens the job board UI instead of a dialog.
@export var opens_job_board := false
@export var enabled := true
## Tap area relative to this node's origin (feet), covers the visual above it.
@export var pick_rect := Rect2(-70, -250, 140, 280)


func _ready() -> void:
	collision_layer = 4  # layer 3 "interactable"
	collision_mask = 0
	monitoring = false
	add_to_group("interactable")
	add_to_group("pickable")


func interact(by: Node) -> void:
	if not enabled:
		return
	interacted.emit(by)
	if Jobs.on_interact(npc_id):
		return
	if opens_job_board:
		get_tree().call_group("hud", "open_job_board")
		return
	if not dialog_id.is_empty():
		Dialog.start(dialog_id)
