class_name Interactable
extends Area2D
## Something the player can use with the interact button. Plays `dialog_id`
## if set, and always emits `interacted` so scenes can add custom behaviour.

signal interacted(by: Node)

@export var prompt := "Talk"
@export var dialog_id := ""
## Identity for the order system: "merchant" (pickups) or "customer_<id>".
@export var npc_id := ""
## Built-in action instead of / before the dialog: "open_map" (the parked
## bike), "refuel" (gas station attendant).
@export var action := ""
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
	if Orders.on_interact(npc_id):
		return
	match action:
		"open_map":
			get_tree().call_group("hud", "open_phone", "map")
			return
		"refuel":
			var cost := GameState.refuel()
			var line := (
				"เติมเต็มถัง %d บาท ... ราคาน้ำมันขึ้นอีกแล้ว" % cost
				if cost > 0
				else "ถังเต็มอยู่แล้ว (หรือเงินไม่พอ)"
			)
			Dialog.start_lines([{"speaker": "เด็กปั๊ม", "text": line}], "refuel")
			return
	if not dialog_id.is_empty():
		Dialog.start(dialog_id)
