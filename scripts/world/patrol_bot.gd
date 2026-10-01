class_name PatrolBot
extends CharacterBody2D
## Patrol obstacle with a vision cone (was the steam-company automaton; P1
## turns it into debt collectors, guards and soi dogs). A puzzle, not a fight
## (owner 2026-10-01: "killing it gives nothing"; the game is puzzle-first).
##
## Walks its `patrol` waypoints with a visible vision cone on the floor. A rider
## it sees while carrying cargo is chased; caught = "cargo inspection": food
## spills, 10 minutes are lost, the rider is pushed away. Ways around it:
## - sneak past while it looks away; props block its line of sight,
## - tap it from behind (outside the cone) to pull its fuse: off for the day
##   (first time ever: a scrap fuse to sell),
## - turn a steam valve (dialog line action `"event": "steam_valve"`): every
##   steam-powered bot in the room freezes for STUN_TIME seconds.

signal caught_player
signal switched_off

enum State { PATROL, WAIT, STARE, CHASE, STUNNED, OFF }

const STUN_TIME := 20.0
const CATCH_RANGE := 62.0
const WAIT_TIME := 1.3
const STARE_TIME := 1.4
const LOSE_TIME := 1.6
## After a catch it ignores the rider for this long (time to walk away).
const CALM_TIME := 3.0
const CONE_RAYS := 14

## Unique per bot; day flags "<id>_off_d<day>" and "<id>_fused" use it.
@export var bot_id := ""
## Waypoints as offsets from the start position (world px). Empty = stands guard.
@export var patrol := PackedVector2Array()
@export var speed := 110.0
@export var chase_speed := 235.0
## Vision in ground space (screen y doubled), so the cone is round on the floor.
@export var view_range := 330.0
@export var view_angle_deg := 70.0
@export var steam_powered := true
@export var start_facing := Vector2(1, 1)
@export var art_name := "brass_automaton"
@export var tint := Color(1.0, 0.55, 0.45)
@export var pick_rect := Rect2(-50, -170, 100, 200)

var state := State.PATROL
## Facing in ground space.
var facing := Vector2.RIGHT
var _home := Vector2.ZERO
var _wp := 0
var _timer := 0.0
var _lost := 0.0
var _calm := 0.0
var _t := 0.0

@onready var _body: Node2D = $Body
@onready var _cone: Polygon2D = $Cone
@onready var _mark: Label = $Mark
@onready var _edge: Line2D = $Cone/Edge


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("pickable")
	add_to_group("bot")
	_home = position
	facing = _ground(start_facing).normalized()
	_apply_art()
	Dialog.event.connect(_on_dialog_event)
	if GameState.has_flag(off_flag()):
		_switch_off(false)
	_update_marks()


func off_flag() -> String:
	return "%s_off_d%d" % [bot_id, GameState.day]


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
	sprite.modulate = tint
	_body.add_child(sprite)


static func _ground(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * 2.0)


static func _screen(g: Vector2) -> Vector2:
	return Vector2(g.x, g.y * 0.5)


## True when `world_pos` is inside the cone and not hidden behind a solid prop.
func can_see(world_pos: Vector2) -> bool:
	var g := _ground(world_pos - global_position)
	if g.length() > view_range:
		return false
	if not in_cone(world_pos):
		return false
	return _ray_end(global_position, world_pos).distance_to(world_pos) < 1.0


func in_cone(world_pos: Vector2) -> bool:
	var g := _ground(world_pos - global_position)
	return absf(facing.angle_to(g)) <= deg_to_rad(view_angle_deg) * 0.5


func _ray_end(from: Vector2, to: Vector2) -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(from, to, 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return hit["position"] if hit else to


func _physics_process(delta: float) -> void:
	_t += delta
	if state == State.OFF:
		return
	if state == State.STUNNED:
		_timer -= delta
		_body.position.x = sin(_t * 40.0) * 2.0
		if _timer <= 0.0:
			_body.position.x = 0.0
			_set_state(State.PATROL)
		_update_cone()
		return
	if GameState.input_locked or Dialog.is_active():
		velocity = Vector2.ZERO
		_update_cone()
		return
	_calm = maxf(_calm - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var sees := player != null and _calm == 0.0 and can_see(player.global_position)
	if sees and Orders.carrying_cargo():
		if state != State.CHASE:
			_lost = 0.0
			_set_state(State.CHASE)
	elif sees and (state == State.PATROL or state == State.WAIT):
		_timer = STARE_TIME
		_set_state(State.STARE)
	match state:
		State.PATROL:
			_patrol_step()
		State.WAIT:
			velocity = Vector2.ZERO
			_timer -= delta
			if _timer <= 0.0:
				_wp = (_wp + 1) % maxi(patrol.size(), 1)
				_set_state(State.PATROL)
		State.STARE:
			velocity = Vector2.ZERO
			if player:
				facing = _ground(player.global_position - global_position).normalized()
			_timer -= delta
			if _timer <= 0.0:
				_set_state(State.PATROL)
		State.CHASE:
			_lost = 0.0 if sees else _lost + delta
			if _lost > LOSE_TIME or player == null:
				_set_state(State.PATROL)
			else:
				_move_towards(player.global_position, chase_speed)
				if global_position.distance_to(player.global_position) < CATCH_RANGE:
					_catch(player)
	_body.position.y = -absf(sin(_t * 9.0)) * 6.0 if velocity.length() > 1.0 else 0.0
	_update_cone()


func _patrol_step() -> void:
	if patrol.is_empty():
		velocity = Vector2.ZERO
		return
	var target := _home + patrol[_wp % patrol.size()]
	if position.distance_to(target) < 8.0:
		velocity = Vector2.ZERO
		_timer = WAIT_TIME
		_set_state(State.WAIT)
		return
	_move_towards(get_parent().to_global(target), speed)


func _move_towards(world_target: Vector2, spd: float) -> void:
	var dir := world_target - global_position
	if dir.length() < 1.0:
		velocity = Vector2.ZERO
		return
	velocity = dir.normalized() * spd
	facing = _ground(dir).normalized()
	move_and_slide()


func _catch(player: Node2D) -> void:
	_calm = CALM_TIME
	_timer = WAIT_TIME
	_set_state(State.WAIT)
	if player.has_method("caught_by"):
		player.caught_by(self)
	Orders.on_player_caught()
	GameState.advance_minutes(10)
	GameState.notice.emit("โดนเรียกตรวจ! เสียเวลาไป 10 นาที")
	caught_player.emit()


## Player tapped it and walked up. From behind = fuse pulled; from the front
## it notices (and chases if the rider carries cargo).
func tamper(player: Node2D) -> void:
	if state == State.OFF:
		GameState.notice.emit("หุ่นปิดอยู่ ... ไว้ยุ่งกับมันพรุ่งนี้")
		return
	if state != State.STUNNED and in_cone(player.global_position):
		facing = _ground(player.global_position - global_position).normalized()
		GameState.notice.emit("หุ่นหันมาเห็นพอดี ... ต้องย่องเข้าทางด้านหลัง")
		if Orders.carrying_cargo():
			_set_state(State.CHASE)
		else:
			_timer = STARE_TIME
			_set_state(State.STARE)
		return
	_switch_off(true)


func _switch_off(by_player: bool) -> void:
	_set_state(State.OFF)
	velocity = Vector2.ZERO
	GameState.set_flag(off_flag())
	var art := _body.get_node_or_null("Art") as Sprite2D
	var grey := Color(0.55, 0.52, 0.5)
	if by_player:
		var tween := create_tween()
		tween.tween_property(_body, "rotation", 0.2, 0.4)
		if art:
			tween.parallel().tween_property(art, "modulate", grey, 0.4)
		switched_off.emit()
		var fused := "%s_fused" % bot_id
		if not GameState.has_flag(fused):
			GameState.set_flag(fused)
			GameState.add_money(20)
			(
				Dialog
				. start_lines(
					[
						"คุณย่องไปด้านหลัง เปิดฝาหลังหุ่น แล้วดึงฟิวส์ทองเหลืองออกมา ... หุ่นฟุบหลับคาที่",
						{"speaker": "ไรเดอร์", "text": "ฟิวส์ทองเหลืองแท้ ขายเจ๊หมวยได้ยี่สิบ"},
						"(พรุ่งนี้เช้าก็มีคนเปลี่ยนฟิวส์ใหม่ให้มันอยู่ดี)",
					],
					"bot_fuse"
				)
			)
		else:
			GameState.notice.emit("ดึงฟิวส์หุ่นออก ... หลับไปทั้งวัน")
	else:
		_body.rotation = 0.2
		if art:
			art.modulate = grey


func _on_dialog_event(event_name: String) -> void:
	if event_name == "steam_valve" and steam_powered and state != State.OFF:
		_timer = STUN_TIME
		_set_state(State.STUNNED)


func _set_state(s: State) -> void:
	state = s
	_update_marks()


func _update_marks() -> void:
	if _mark == null:
		return
	match state:
		State.CHASE:
			_mark.text = "!"
			_mark.modulate = Color(1.0, 0.35, 0.3)
		State.STARE:
			_mark.text = "?"
			_mark.modulate = Color(1.0, 0.9, 0.5)
		State.STUNNED, State.OFF:
			_mark.text = "zz"
			_mark.modulate = Color(0.8, 0.85, 1.0)
		_:
			_mark.text = ""


func _update_cone() -> void:
	if state == State.OFF or state == State.STUNNED:
		_cone.visible = false
		return
	_cone.visible = true
	var pts := PackedVector2Array([Vector2.ZERO])
	var half := deg_to_rad(view_angle_deg) * 0.5
	for i in CONE_RAYS + 1:
		var a := -half + 2.0 * half * i / CONE_RAYS
		var g := facing.rotated(a) * view_range
		var world_end := global_position + _screen(g)
		pts.append(to_local(_ray_end(global_position, world_end)))
	_cone.polygon = pts
	var chase := state == State.CHASE
	# light fill + bright rim: must read on the warm market tiles too
	_cone.color = Color(1.0, 0.3, 0.25, 0.3) if chase else Color(1.0, 0.97, 0.8, 0.22)
	pts.append(Vector2.ZERO)
	_edge.points = pts
	_edge.default_color = Color(1.0, 0.35, 0.3, 0.9) if chase else Color(1.0, 0.92, 0.6, 0.75)
