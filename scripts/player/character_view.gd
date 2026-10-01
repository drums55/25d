class_name CharacterView
extends Node2D
## Visual of a character, origin = feet (Y-sort point). Same API as CutoutRig:
## set_facing(dir), set_walk(amount), play_attack(), is_attacking().
##
## Uses the 8-direction sprite sheets under
## assets/art/characters/<character_name>/sprites/ when present (one row per
## Iso.Dir, nothing is mirrored); otherwise falls back to the CutoutRig
## placeholder so unknown characters still show something.

signal attack_finished

const CUTOUT_RIG := preload("res://scenes/characters/cutout_rig.tscn")
const WALK_THRESHOLD := 0.05

@export var character_name := ""

var facing: int = Iso.Dir.S
var _walk := 0.0
var _attacking := false
var _sprite: AnimatedSprite2D
var _rig: CutoutRig


func _ready() -> void:
	var data := {} if character_name.is_empty() else ArtLibrary.sprite_set(character_name)
	if data.is_empty():
		_rig = CUTOUT_RIG.instantiate()
		_rig.character_name = character_name
		add_child(_rig)
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = ArtLibrary.build_sprite_frames(data)
	# centered=true draws the frame around the node; shift so the pivot
	# (feet, in frame pixels) lands on the origin, then scale to game size.
	_sprite.offset = data["frame_size"] * 0.5 - data["pivot"]
	_sprite.scale = Vector2.ONE / ArtLibrary.ART_SCALE
	_sprite.animation_finished.connect(_on_animation_finished)
	add_child(_sprite)
	_play_state()


func has_sprites() -> bool:
	return _sprite != null


func set_facing(dir: int) -> void:
	if dir < 0:
		return
	facing = dir
	if _rig:
		_rig.set_facing(dir)
	else:
		_play_state()


## 0..1 movement amount: > WALK_THRESHOLD plays walk, otherwise idle.
func set_walk(amount: float) -> void:
	_walk = clampf(amount, 0.0, 1.0)
	if _rig:
		_rig.set_walk(_walk)
	elif not _attacking:
		_play_state()


func play_attack() -> void:
	if _rig:
		_rig.play_attack()
		return
	if not _has_anim("attack"):
		return
	_attacking = true
	_sprite.play("attack_%d" % facing)


func is_attacking() -> bool:
	if _rig:
		return _rig.is_attacking()
	return _attacking


## Seconds one attack animation takes (0 when the character cannot attack).
func attack_duration() -> float:
	if _rig:
		return CutoutRig.ATTACK_TIME
	if not _has_anim("attack"):
		return 0.0
	var anim := "attack_%d" % facing
	var frames := _sprite.sprite_frames
	return frames.get_frame_count(anim) / frames.get_animation_speed(anim)


func _has_anim(anim: String) -> bool:
	return _sprite != null and _sprite.sprite_frames.has_animation("%s_%d" % [anim, facing])


func _play_state() -> void:
	if _sprite == null:
		return
	if _attacking:
		_sprite.play("attack_%d" % facing)
		return
	var anim := "walk" if _walk > WALK_THRESHOLD else "idle"
	if not _has_anim(anim):
		anim = "idle"
	var name := "%s_%d" % [anim, facing]
	if _sprite.animation != name:
		# Keep the frame when only the direction changes so walking looks continuous.
		var frame := _sprite.frame if _sprite.animation.begins_with(anim) else 0
		_sprite.play(name)
		_sprite.frame = mini(frame, _sprite.sprite_frames.get_frame_count(name) - 1)


func _on_animation_finished() -> void:
	if _attacking:
		_attacking = false
		attack_finished.emit()
		_play_state()
