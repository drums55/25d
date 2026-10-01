class_name Player
extends CharacterBody2D
## Player controller: analog 8-way movement in screen space (Hades-style),
## facing snapped to 8 directions, interact with the nearest Interactable,
## melee attack hitting anything with take_hit() in the facing direction.
## Input comes only from InputMap actions; the touch HUD presses those actions.

@export var speed := 460.0
@export var attack_cooldown := 0.35
@export var hitbox_distance := 70.0

var facing: int = Iso.Dir.S
var _cooldown := 0.0

@onready var rig: CutoutRig = $Rig
@onready var camera: Camera2D = $Camera2D
@onready var _interact_area: Area2D = $InteractArea
@onready var _hitbox: Area2D = $Hitbox


func _ready() -> void:
	add_to_group("player")
	_update_hitbox()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var busy := GameState.input_locked or Dialog.is_active()
	var dir := (
		Vector2.ZERO
		if busy
		else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	)
	velocity = dir * speed
	move_and_slide()
	rig.set_walk(dir.length())
	if dir.length() > 0.3:
		facing = Iso.dir8(dir)
		rig.set_facing(facing)
		_update_hitbox()
	if GameState.input_locked:
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
	_cooldown = attack_cooldown
	rig.play_attack()
	for body in _hitbox.get_overlapping_bodies():
		if body != self and body.has_method("take_hit"):
			body.take_hit(1, global_position)


func _update_hitbox() -> void:
	# Iso-squash the forward offset so the hitbox lies on the floor plane.
	_hitbox.position = Iso.dir8_vector(facing) * Vector2(1.0, 0.6) * hitbox_distance
