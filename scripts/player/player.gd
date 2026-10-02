class_name Player
extends CharacterBody2D
## Player controller, point & click.
##
## Tap/click the floor to walk there (hold and drag to steer), tap something
## pickable to walk up to it and use it: Interactable -> interact, anything
## with tamper() (patrol bots) -> walk up to it. With a bag item held
## (GameState.held_item) the Interactable gets the item used on it.
## No combat. Paths come from the room's navigation mesh
## (NavigationAgent2D). Keyboard (WASD/E) still works on PC and cancels a click
## order. During dialog any tap advances the dialog.

enum Order { NONE, MOVE, INTERACT, TAMPER }

## Distance at which a tamper order stops walking and reaches out.
const TAMPER_RANGE := 80.0
## Seconds of blinking after a patrol bot caught the rider.
const CAUGHT_BLINK := 0.8
## Hold a finger this long without dragging = show every tappable thing.
const LONG_PRESS_MS := 450
const LONG_PRESS_SLOP := 30.0

@export var speed := 460.0

var facing: int = Iso.Dir.S
var order := Order.NONE
var order_target: Node2D = null
var _move_finger := -1
var _press_ms := -1
var _press_pos := Vector2.ZERO
var _blink := 0.0

@onready var rig: CharacterView = $Rig
@onready var camera: Camera2D = $Camera2D
@onready var _interact_area: Area2D = $InteractArea
@onready var _agent: NavigationAgent2D = $NavAgent
@onready var _marker: ClickMarker = $ClickMarker


func _ready() -> void:
	add_to_group("player")


## Pickable (group "pickable") under `world_pos`. A node whose visuals are
## sprites is hit only where they are opaque (PickTest); the front-most (largest
## y) such hit wins, as that is the one drawn on top. Nodes without sprites
## (doors, placeholder props) use `pick_rect` around their origin and only win
## when no sprite was hit; then the nearest rect centre wins.
static func pick(nodes: Array, world_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var fallback: Node2D = null
	var fallback_d := INF
	for n in nodes:
		if not n is Node2D or not n.is_visible_in_tree():
			continue
		var hit := PickTest.visual_hit(_visual_root(n), world_pos)
		if hit == 1:
			if best == null or n.global_position.y > best.global_position.y:
				best = n
		elif hit == -1:
			var rect: Rect2 = n.get("pick_rect")
			var local: Vector2 = world_pos - n.global_position
			if rect.has_point(local):
				var d := local.distance_to(rect.get_center())
				if d < fallback_d:
					fallback = n
					fallback_d = d
	return best if best else fallback


## What a pickable looks like: an Interactable is a child of the prop / NPC
## that draws it; everything else draws itself.
static func _visual_root(n: Node) -> Node:
	var parent := n.get_parent()
	if n is Interactable and parent and parent.name != "World":
		return parent
	return n


## Point & click entry point (world coordinates).
func click_at(world_pos: Vector2) -> void:
	if GameState.input_locked or GameState.ui_open:
		return
	if Dialog.is_active():
		Dialog.advance()
		return
	var target := pick(get_tree().get_nodes_in_group("pickable"), world_pos)
	if target == null and not GameState.held_item.is_empty():
		# tapping the floor puts the held item back in the bag
		GameState.held_item = ""
	order_target = target
	if target is Interactable:
		order = Order.INTERACT
	elif target and target.has_method("tamper"):
		order = Order.TAMPER
	else:
		order = Order.MOVE
	var dest := target.global_position if target else world_pos
	_agent.target_position = dest
	_marker.show_at(dest)


func cancel_order() -> void:
	order = Order.NONE
	order_target = null


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.blocks_point(touch.position):
				return
			_move_finger = touch.index
			_press_ms = Time.get_ticks_msec()
			_press_pos = touch.position
			click_at(_to_world(touch.position))
			if order != Order.MOVE:
				_move_finger = -1
		else:
			_press_ms = -1
			if touch.index == _move_finger:
				_move_finger = -1
		return
	var drag := event as InputEventScreenDrag
	if drag and drag.position.distance_to(_press_pos) > LONG_PRESS_SLOP:
		_press_ms = -1
	if drag and drag.index == _move_finger and order == Order.MOVE:
		_agent.target_position = _to_world(drag.position)
		_marker.show_at(_agent.target_position)


func _physics_process(delta: float) -> void:
	if _blink > 0.0:
		_blink = maxf(_blink - delta, 0.0)
		rig.modulate.a = 0.45 if fmod(_blink, 0.16) < 0.08 else 1.0
		if _blink == 0.0:
			rig.modulate.a = 1.0
	var busy := GameState.input_locked or GameState.ui_open or Dialog.is_active()
	if _press_ms >= 0 and Time.get_ticks_msec() - _press_ms > LONG_PRESS_MS:
		_press_ms = -1
		if not busy:
			cancel_order()
			highlight_things()
	var keys := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector2.ZERO
	if busy:
		cancel_order()
	elif keys != Vector2.ZERO:
		cancel_order()
		dir = keys
	elif order != Order.NONE:
		dir = _follow_order()
	velocity = dir * speed
	move_and_slide()
	rig.set_walk(dir.length())
	if dir.length() > 0.3:
		_face(dir)
	if busy:
		return
	if Input.is_action_just_pressed("interact"):
		_on_interact()


func get_nearest_interactable() -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for area in _interact_area.get_overlapping_areas():
		if area is Interactable and area.enabled:
			var d := global_position.distance_squared_to(area.global_position)
			if d < best_d:
				best_d = d
				best = area
	return best


## Returns the walk direction for the current order and fires it on arrival.
func _follow_order() -> Vector2:
	if order != Order.MOVE and not is_instance_valid(order_target):
		cancel_order()
		return Vector2.ZERO
	match order:
		Order.INTERACT:
			if _interact_area.overlaps_area(order_target):
				var t := order_target as Interactable
				_face(t.global_position - global_position)
				cancel_order()
				t.interact(self)
				return Vector2.ZERO
		Order.TAMPER:
			var to_target := order_target.global_position - global_position
			if to_target.length() <= TAMPER_RANGE:
				var bot := order_target
				_face(to_target)
				cancel_order()
				rig.play_attack()  # wrench animation: fiddling with the fuse panel
				bot.tamper(self)
				return Vector2.ZERO
	if _agent.is_navigation_finished():
		if order == Order.MOVE:
			cancel_order()
		return Vector2.ZERO
	var step := _agent.get_next_path_position() - global_position
	return step.normalized() if step.length() > 1.0 else Vector2.ZERO


func _face(dir: Vector2) -> void:
	var d := Iso.dir8(dir)
	if d < 0:
		return
	facing = d
	rig.set_facing(facing)


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


## Long press: ping every tappable thing in the room (no pixel hunting).
func highlight_things() -> int:
	var count := 0
	for n in get_tree().get_nodes_in_group("pickable"):
		if not n is Node2D or not n.is_visible_in_tree() or n == self:
			continue
		var ping := HotspotPing.new()
		get_parent().add_child(ping)
		ping.global_position = (n as Node2D).global_position
		count += 1
	return count


## A patrol bot caught the rider (PatrolBot._catch): pushed away, blinking.
func caught_by(bot: Node2D) -> void:
	cancel_order()
	_blink = CAUGHT_BLINK
	var push := (global_position - bot.global_position).normalized()
	if push.length_squared() > 0.0:
		velocity = push * 1600.0
		move_and_slide()


func _on_interact() -> void:
	if Dialog.is_active():
		Dialog.advance()
		return
	var target := get_nearest_interactable()
	if target:
		target.interact(self)
