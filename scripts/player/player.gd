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
## Seconds of invulnerability after a hit.
@export var invuln_time := 0.8

var facing: int = Iso.Dir.S
var order := Order.NONE
var order_target: Node2D = null
var _cooldown := 0.0
var _move_finger := -1
var _invuln := 0.0

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
	if _invuln > 0.0:
		_invuln = maxf(_invuln - delta, 0.0)
		rig.modulate.a = 0.45 if fmod(_invuln, 0.16) < 0.08 else 1.0
		if _invuln == 0.0:
			rig.modulate.a = 1.0
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


## Damage from enemies. Knocks back, flashes, and on 0 HP the player is
## revived at the room's default spawn with full HP (no game over yet).
func take_hit(amount: int, from: Vector2) -> void:
	if _invuln > 0.0 or GameState.input_locked:
		return
	_invuln = invuln_time
	GameState.hp -= amount
	Jobs.on_player_hit()
	cancel_order()
	var push := (global_position - from).normalized()
	if push.length_squared() > 0.0:
		velocity = push * 420.0
		move_and_slide()
	if GameState.hp <= 0:
		_knocked_out()


## Fade to black, revive at the room's default spawn with full HP. Enemies
## already defeated stay defeated; nothing else is lost.
func _knocked_out() -> void:
	GameState.input_locked = true
	cancel_order()
	velocity = Vector2.ZERO
	await SceneRouter.blackout("หมดแรง...", 1.2)
	GameState.hp = GameState.MAX_HP
	var room := get_parent().get_parent() as IsoRoom
	if room:
		global_position = room.get_spawn_position("default")
	_invuln = invuln_time * 2.0
	GameState.notice.emit("ตื่นขึ้นมาอีกครั้ง... ค่อยๆ ไปใหม่")
	GameState.input_locked = false


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
