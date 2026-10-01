class_name Player
extends CharacterBody2D
## Player controller, point & click.
##
## Tap/click the floor to walk there (hold and drag to steer), tap something
## pickable to walk up to it and use it: Interactable -> interact, anything
## with take_hit() -> attack, Door -> walk into it. Paths come from the room's
## navigation mesh (NavigationAgent2D). Keyboard (WASD/E/J) still works on PC
## and cancels a click order. During dialog any tap advances the dialog.

enum Order { NONE, MOVE, INTERACT, ATTACK }

## Distance at which an attack order stops walking and swings.
const ATTACK_RANGE := 80.0

@export var speed := 460.0
@export var attack_cooldown := 0.35
@export var hitbox_distance := 70.0

var facing: int = Iso.Dir.S
var order := Order.NONE
var order_target: Node2D = null
var _cooldown := 0.0
var _move_finger := -1

@onready var rig: CharacterView = $Rig
@onready var camera: Camera2D = $Camera2D
@onready var _interact_area: Area2D = $InteractArea
@onready var _hitbox: Area2D = $Hitbox
@onready var _agent: NavigationAgent2D = $NavAgent
@onready var _marker: ClickMarker = $ClickMarker


func _ready() -> void:
	add_to_group("player")
	# Hitbox is only a shape holder; hits are an instant physics query
	# (get_hit_bodies) because area overlaps proved unreliable here.
	_hitbox.monitoring = false
	_update_hitbox()


## Topmost pickable (group "pickable", has `pick_rect` relative to its origin)
## under `world_pos`. Front-most (largest y) wins.
static func pick(nodes: Array, world_pos: Vector2) -> Node2D:
	var best: Node2D = null
	for n in nodes:
		if not n is Node2D or not n.is_visible_in_tree():
			continue
		var rect: Rect2 = n.get("pick_rect")
		if rect.has_point(world_pos - n.global_position):
			if best == null or n.global_position.y > best.global_position.y:
				best = n
	return best


## Point & click entry point (world coordinates).
func click_at(world_pos: Vector2) -> void:
	if GameState.input_locked:
		return
	if Dialog.is_active():
		Dialog.advance()
		return
	var target := pick(get_tree().get_nodes_in_group("pickable"), world_pos)
	order_target = target
	if target is Interactable:
		order = Order.INTERACT
	elif target and target.has_method("take_hit"):
		order = Order.ATTACK
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
			_move_finger = touch.index
			click_at(_to_world(touch.position))
			if order != Order.MOVE:
				_move_finger = -1
		elif touch.index == _move_finger:
			_move_finger = -1
		return
	var drag := event as InputEventScreenDrag
	if drag and drag.index == _move_finger and order == Order.MOVE:
		_agent.target_position = _to_world(drag.position)
		_marker.show_at(_agent.target_position)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var busy := GameState.input_locked or Dialog.is_active()
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
	elif Input.is_action_just_pressed("attack"):
		_on_attack()


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
		Order.ATTACK:
			var to_target := order_target.global_position - global_position
			if to_target.length() <= ATTACK_RANGE:
				_face(to_target)
				cancel_order()
				_on_attack()
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
	_update_hitbox()


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _on_interact() -> void:
	if Dialog.is_active():
		Dialog.advance()
		return
	var target := get_nearest_interactable()
	if target:
		target.interact(self)


func _on_attack() -> void:
	if Dialog.is_active():
		Dialog.advance()
		return
	if _cooldown > 0.0:
		return
	# Let a full attack animation play before the next swing.
	_cooldown = maxf(attack_cooldown, rig.attack_duration())
	rig.play_attack()
	for body in get_hit_bodies():
		body.take_hit(1, global_position)


## Bodies with take_hit() inside the hitbox shape right now (hittable layer).
func get_hit_bodies() -> Array:
	var q := PhysicsShapeQueryParameters2D.new()
	var shape_node := _hitbox.get_child(0) as CollisionShape2D
	q.shape = shape_node.shape
	q.transform = shape_node.global_transform
	q.collision_mask = _hitbox.collision_mask
	q.exclude = [get_rid()]
	var out: Array = []
	for hit in get_world_2d().direct_space_state.intersect_shape(q):
		var body = hit["collider"]
		if body and body.has_method("take_hit") and not out.has(body):
			out.append(body)
	return out


func _update_hitbox() -> void:
	# Iso-squash the forward offset so the hitbox lies on the floor plane.
	_hitbox.position = Iso.dir8_vector(facing) * Vector2(1.0, 0.6) * hitbox_distance
