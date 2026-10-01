class_name Enemy
extends CharacterBody2D
## Rogue brass automaton: idles until the player comes within `aggro_range`,
## then chases and hits on contact (with a cooldown). Takes player attacks via
## take_hit(); at 0 HP it powers down (stays as scrap) and sets `defeat_flag`
## so it does not come back after a room reload.

signal died

@export var max_hp := 3
@export var speed := 170.0
@export var aggro_range := 330.0
@export var damage := 1
@export var hit_cooldown := 1.1
@export var contact_range := 70.0
## Flag set when defeated; if already set on load the enemy spawns as scrap.
@export var defeat_flag := ""
## Art under assets/art/props/ (default brass_automaton, tinted red).
@export var art_name := "brass_automaton"
@export var pick_rect := Rect2(-50, -170, 100, 200)

var hp := 0
var alive := true
var _since_hit := 0.0
var _bob := 0.0

@onready var _body: Node2D = $Body


func _ready() -> void:
	hp = max_hp
	_since_hit = hit_cooldown - 0.3  # short wind-up before the first hit
	collision_layer = 1 | 8  # world + hittable
	collision_mask = 1 | 2  # world + player
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("pickable")
	add_to_group("enemy")
	_apply_art()
	if not defeat_flag.is_empty() and GameState.has_flag(defeat_flag):
		_power_down(false)


func _apply_art() -> void:
	var tex := ArtLibrary.prop(art_name)
	if tex == null:
		return
	for child in _body.get_children():
		child.visible = false
	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.texture = tex
	sprite.centered = false
	sprite.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + ArtLibrary.PROP_FOOT_MARGIN)
	sprite.scale = Vector2.ONE / ArtLibrary.ART_SCALE
	sprite.modulate = Color(1.0, 0.55, 0.45)
	_body.add_child(sprite)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_since_hit += delta
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or GameState.input_locked or Dialog.is_active():
		velocity = Vector2.ZERO
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist > aggro_range:
		velocity = Vector2.ZERO
		_body.position.y = 0.0
		return
	# angry hop while chasing
	_bob += delta * 14.0
	_body.position.y = -absf(sin(_bob)) * 10.0
	if dist > contact_range:
		velocity = to_player.normalized() * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		if _since_hit >= hit_cooldown:
			_since_hit = 0.0
			player.take_hit(damage, global_position)
			_lunge(to_player.normalized())


func _lunge(dir: Vector2) -> void:
	var tween := create_tween()
	_body.position = dir * 18.0
	tween.tween_property(_body, "position", Vector2.ZERO, 0.18)


func take_hit(amount: int, from: Vector2) -> void:
	if not alive:
		return
	hp -= amount
	var push := (global_position - from).normalized()
	global_position += push * 24.0
	var tween := create_tween()
	_body.modulate = Color(3, 1.2, 1.2)
	tween.tween_property(_body, "modulate", Color.WHITE, 0.2)
	_since_hit = minf(_since_hit, hit_cooldown - 0.4)  # staggered: short delay before it hits back
	if hp <= 0:
		_power_down(true)


func _power_down(animate: bool) -> void:
	alive = false
	hp = 0
	velocity = Vector2.ZERO
	collision_layer = 1  # stays solid scrap, no longer hittable
	remove_from_group("pickable")
	remove_from_group("enemy")
	if not defeat_flag.is_empty():
		GameState.set_flag(defeat_flag)
	var art := _body.get_node_or_null("Art") as Sprite2D
	var target := Color(0.45, 0.42, 0.4)
	if animate:
		var tween := create_tween()
		tween.tween_property(_body, "modulate", target, 0.5)
		tween.parallel().tween_property(_body, "rotation", 0.18, 0.5)
		if art:
			tween.parallel().tween_property(art, "modulate", Color(0.8, 0.8, 0.8), 0.5)
	else:
		_body.modulate = target
		_body.rotation = 0.18
		if art:
			art.modulate = Color(0.8, 0.8, 0.8)
	died.emit()
