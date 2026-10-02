class_name PatrolBot
extends CharacterBody2D
## A living gate (DESIGN 12.3): a debt collector or a collector robot that
## stands or paces at a chokepoint. No vision cone, no chase, no sneaking
## (owner 2026-10-02: the real-time stealth "ไม่ค่อยมีผลกับเกม ... แปลกแยก" in
## a point-and-click): everything about it is predictable.
##
## - Walk into its zone (the ring on the floor) = caught, every time:
##   `catch_dialog` (which hints at its weakness), a push back, and whatever
##   is on the finger is seized "for the debt" and lands on เจ๊เกียว's raft
##   (flag seized_<item>, know_kiao) — a story consequence, not a penalty.
## - Past it only by a puzzle: `distract_flag` set by one (the radio) stops it
##   for good, facing `distract_dir`; robots turn toward any noise (dialog line
##   action `"event": "noise"` -> face `noise_dir`) and only then show their
##   back: tapping a robot from behind pulls its fuse (off for the day,
##   flags `<id>_off_d<day>` + `<id>_fused`). A robot otherwise always faces
##   the rider (`tracks_player`), so its back can never be reached by walking.

signal caught_player
signal switched_off

enum State { GUARD, OFF }

## After a catch it ignores the rider for this long (time to walk away).
const CALM_TIME := 3.0
const WAIT_TIME := 1.3
const ZONE_RAYS := 20

## Unique per bot; day flags "<id>_off_d<day>" and "<id>_fused" use it.
@export var bot_id := ""
## Waypoints as offsets from the start position (world px). Empty = stands
## guard. Ignored while tracking the rider.
@export var patrol := PackedVector2Array()
@export var speed := 70.0
## The catch zone in ground space (screen y doubled, so it is round on the
## floor): radius and the angle it covers in front (360 = all around).
@export var zone_range := 150.0
@export var zone_angle_deg := 360.0
## Robots turn to keep the rider in front; people just look where they walk.
@export var tracks_player := false
## Robots turn toward a noise (dialog event "noise") and stay turned.
@export var turns_to_noise := false
@export var noise_dir := Vector2(-1, 0)
@export var start_facing := Vector2(1, 1)
@export var art_name := "brass_automaton"
@export var tint := Color(1.0, 0.55, 0.45)
@export var pick_rect := Rect2(-50, -170, 100, 200)
## People instead of automatons: a CharacterView sprite.
@export var character_name := ""
## Dialog played when it catches the rider.
@export var catch_dialog := ""
## Catching the rider with an item on the finger takes it to เจ๊เกียว's raft.
@export var seizes := true
## Story flag that distracts it for good (see class doc), the way it then
## faces (screen) and the mark over its head.
@export var distract_flag := ""
@export var distract_dir := Vector2(1, 0)
@export var distract_mark := "~ เต้น ~"
## Special animation a person plays once distracted (if their sheet has it).
@export var distract_pose := "dance"
## Can its fuse be pulled from behind (machines only)?
@export var tamperable := true
## Dialog when tapped while not tamperable.
@export var talk_dialog := ""

var state := State.GUARD
## Facing in ground space.
var facing := Vector2.RIGHT
## Turned toward a noise: facing is locked (and the back is exposed).
var heard_noise := false
var _home := Vector2.ZERO
var _wp := 0
var _timer := 0.0
var _calm := 0.0
var _t := 0.0
var _rig: CharacterView

@onready var _body: Node2D = $Body
@onready var _zone: Polygon2D = $Zone
@onready var _mark: Label = $Mark
@onready var _edge: Line2D = $Zone/Edge


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
	GameState.flag_changed.connect(_on_flag)
	_update_marks()
	if GameState.has_flag(off_flag()):
		_switch_off(false)
	elif not distract_flag.is_empty() and GameState.has_flag(distract_flag):
		_distract()
	_update_zone()


func _on_flag(flag: String, value: bool) -> void:
	if value and flag == distract_flag and state != State.OFF:
		_distract()


## Stops for good, looking at whatever distracted it.
func _distract() -> void:
	velocity = Vector2.ZERO
	facing = _ground(distract_dir).normalized()
	_set_state(State.OFF)
	if _mark:
		_mark.text = distract_mark
		_mark.modulate = Color(0.7, 1.0, 0.8)
	if _rig:
		_rig.set_facing(Iso.dir8(distract_dir))
		_rig.set_walk(0.0)
		_rig.set_pose(distract_pose)
	_update_zone()


func off_flag() -> String:
	return "%s_off_d%d" % [bot_id, GameState.day]


func _apply_art() -> void:
	if not character_name.is_empty():
		for child in _body.get_children():
			child.visible = false
		_rig = (load("res://scenes/characters/character_view.tscn") as PackedScene).instantiate()
		_rig.character_name = character_name
		_rig.modulate = tint
		_body.add_child(_rig)
		return
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


## True when `world_pos` is inside the catch zone (the ring on the floor).
func in_zone(world_pos: Vector2) -> bool:
	var g := _ground(world_pos - global_position)
	if g.length() > zone_range:
		return false
	return in_front(world_pos) or zone_angle_deg >= 360.0


## True when `world_pos` is on the side it faces (its back is the other half).
func in_front(world_pos: Vector2) -> bool:
	var g := _ground(world_pos - global_position)
	var half := deg_to_rad(minf(zone_angle_deg, 360.0)) * 0.5
	return absf(facing.angle_to(g)) <= half


func _physics_process(delta: float) -> void:
	_t += delta
	if state == State.OFF:
		return
	if GameState.input_locked or Dialog.is_active():
		velocity = Vector2.ZERO
		_update_zone()
		return
	var was_hot := _calm > 0.0
	_calm = maxf(_calm - delta, 0.0)
	if was_hot and _calm == 0.0:
		_update_marks()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and tracks_player and not heard_noise:
		var to_player := _ground(player.global_position - global_position)
		if to_player.length() > 1.0:
			facing = to_player.normalized()
	if _timer > 0.0:
		_timer -= delta
		velocity = Vector2.ZERO
		if _timer <= 0.0:
			_wp = (_wp + 1) % maxi(patrol.size(), 1)
	elif tracks_player or heard_noise:
		velocity = Vector2.ZERO
	else:
		_patrol_step()
	if player and in_zone(player.global_position):
		if _calm == 0.0:
			_catch(player)
		elif player.has_method("shoved_by"):
			# still a wall while it calms down: no words, just no way through
			player.shoved_by(self)
	if _rig:
		_rig.set_facing(Iso.dir8(_screen(facing)))
		_rig.set_walk(1.0 if velocity.length() > 1.0 else 0.0)
	else:
		_body.position.y = -absf(sin(_t * 9.0)) * 6.0 if velocity.length() > 1.0 else 0.0
	_update_zone()


func _patrol_step() -> void:
	if patrol.is_empty():
		velocity = Vector2.ZERO
		return
	var target := _home + patrol[_wp % patrol.size()]
	if position.distance_to(target) < 8.0:
		velocity = Vector2.ZERO
		_timer = WAIT_TIME
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


## Caught: words, a push, and the thing on the finger goes "for the debt".
func _catch(player: Node2D) -> void:
	_calm = CALM_TIME
	velocity = Vector2.ZERO
	if player.has_method("caught_by"):
		player.caught_by(self)
	var seized := _seize()
	if not catch_dialog.is_empty():
		Dialog.start(catch_dialog)
	if not seized.is_empty():
		GameState.notice.emit("%s ยึด%s ... ฝากไว้ที่แพเจ๊เกียว" % [display_name(), seized])
	Audio.sfx("caught")
	_update_marks()
	caught_player.emit()


## Takes the held item to เจ๊เกียว's raft; returns its name ("" = nothing).
func _seize() -> String:
	var item := GameState.held_item
	if not seizes or item.is_empty() or not GameState.has_item(item):
		return ""
	GameState.held_item = ""
	GameState.take_item(item)
	GameState.set_flag("seized_%s" % item)
	GameState.set_flag("know_kiao")
	return GameState.item_name(item)


## The name over its head (the tag the room gave it), else its id.
func display_name() -> String:
	var tag := get_node_or_null("NameTag") as Label
	if tag and not tag.text.is_empty():
		return tag.text.get_slice(" (", 0)
	return bot_id


## Player tapped it and walked up. From behind = fuse pulled; from the front
## it sees the hand coming = caught.
func tamper(player: Node2D) -> void:
	if not tamperable:
		if not talk_dialog.is_empty():
			Dialog.start(talk_dialog)
		return
	if state == State.OFF:
		GameState.notice.emit("หุ่นปิดอยู่ ... ไว้ยุ่งกับมันพรุ่งนี้")
		return
	if in_front(player.global_position):
		_catch(player)
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
		Audio.sfx("spark")
		switched_off.emit()
		GameState.set_flag("%s_fused" % bot_id)
		GameState.notice.emit("ดึงฟิวส์หุ่นออก ... หลับปุ๋ย")
	else:
		_body.rotation = 0.2
		if art:
			art.modulate = grey
	_update_zone()


## A noise somewhere in the room: robots turn to it and keep looking.
func _on_dialog_event(event_name: String) -> void:
	if event_name == "noise" and turns_to_noise and state != State.OFF:
		heard_noise = true
		facing = _ground(noise_dir).normalized()
		velocity = Vector2.ZERO
		_update_marks()
		_update_zone()


func _set_state(s: State) -> void:
	state = s
	_update_marks()


func _update_marks() -> void:
	if _mark == null:
		return
	if state == State.OFF:
		_mark.text = "zz"
		_mark.modulate = Color(0.8, 0.85, 1.0)
	elif _calm > 0.0:
		_mark.text = "!"
		_mark.modulate = Color(1.0, 0.35, 0.3)
	elif heard_noise:
		_mark.text = "?"
		_mark.modulate = Color(1.0, 0.9, 0.5)
	else:
		_mark.text = ""


## The zone on the floor: a soft disc (or wedge) in front, so the player
## sees exactly where "too close" starts.
func _update_zone() -> void:
	if _zone == null:
		return
	if state == State.OFF:
		_zone.visible = false
		return
	_zone.visible = true
	var pts := PackedVector2Array()
	var full := zone_angle_deg >= 360.0
	if not full:
		pts.append(Vector2.ZERO)
	var half := deg_to_rad(minf(zone_angle_deg, 360.0)) * 0.5
	for i in ZONE_RAYS + 1:
		var a := -half + 2.0 * half * i / ZONE_RAYS
		pts.append(_screen(facing.rotated(a) * zone_range))
	_zone.polygon = pts
	var hot := _calm > 0.0
	_zone.color = Color(1.0, 0.3, 0.25, 0.3) if hot else Color(1.0, 0.97, 0.8, 0.18)
	if not full:
		pts.append(Vector2.ZERO)
	else:
		pts.append(pts[0])
	_edge.points = pts
	_edge.default_color = Color(1.0, 0.35, 0.3, 0.9) if hot else Color(1.0, 0.92, 0.6, 0.7)
