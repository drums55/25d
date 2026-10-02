class_name Interactable
extends Area2D
## Something the rider can tap (DESIGN 11.5): talk / look (`dialog_id`), pick
## up (`pickup_item`), walk out (`exit_to`), or have a bag item used on it
## (`thing_id`, see Puzzles.use). With an item on the finger, tapping this =
## "use item on thing"; otherwise its own behaviour runs.

signal interacted(by: Node)

@export var prompt := "ดู"
@export var dialog_id := ""
## Name of this thing for item uses / fail lines (Puzzles data "target").
@export var thing_id := ""
## Tapping picks this item up (the parent prop disappears) and sets
## "got_<item>" so the room does not spawn it again.
@export var pickup_item := ""
## Line shown when picking up (default: the item's description).
@export var pickup_text := ""
## Walking out: room id + spawn there. `exit_flag` = needed first, otherwise
## `locked_dialog` plays.
@export var exit_to := ""
@export var exit_spawn := "default"
@export var exit_flag := ""
@export var locked_dialog := ""
## Built-in behaviour instead of the dialog (none yet; kept for later rooms).
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
	if not GameState.held_item.is_empty():
		var item := GameState.held_item
		GameState.held_item = ""
		Puzzles.use(item, thing_id if not thing_id.is_empty() else name.to_snake_case())
		return
	if not pickup_item.is_empty():
		_pick_up()
		return
	if not exit_to.is_empty():
		if not exit_flag.is_empty() and not GameState.has_flag(exit_flag):
			if not locked_dialog.is_empty():
				Dialog.start(locked_dialog)
			return
		get_tree().call_group("main", "go_room", exit_to, exit_spawn)
		return
	if not dialog_id.is_empty():
		Dialog.start(dialog_id)


func _pick_up() -> void:
	var item := pickup_item
	GameState.set_flag("got_%s" % item)
	var text := pickup_text if not pickup_text.is_empty() else Puzzles.item_desc(item)
	Dialog.start_lines([{"text": text, "give_item": item}], "pickup")
	enabled = false
	var owner_node := get_parent()
	if owner_node and owner_node.name != "World":
		owner_node.queue_free()
	else:
		queue_free()
