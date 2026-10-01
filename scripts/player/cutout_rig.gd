@tool
class_name CutoutRig
extends Node2D
## Cut-out character: Skeleton2D + Bone2D per body part, animated procedurally
## (walk swing, idle breathing, attack swing). Each bone has a "Placeholder"
## Polygon2D; apply_skin() adds an "Art" Sprite2D per bone and hides the
## placeholders. Bones are authored facing right; left directions mirror.
##
## When real art arrives an AnimationPlayer can drive the same bones instead.

const PART_BONES := {
	"head": "Skeleton2D/Hip/Torso/Head",
	"torso": "Skeleton2D/Hip/Torso",
	"arm_l": "Skeleton2D/Hip/Torso/ArmL",
	"arm_r": "Skeleton2D/Hip/Torso/ArmR",
	"leg_l": "Skeleton2D/Hip/LegL",
	"leg_r": "Skeleton2D/Hip/LegR",
}
const ATTACK_TIME := 0.22

## Folder name under assets/art/characters/; its PNGs become the skin when
## present (see ArtLibrary). Leave empty to keep placeholders.
@export var character_name := ""
@export var skin: CutoutSkin:
	set(v):
		skin = v
		if is_inside_tree():
			apply_skin()
@export var tint := Color.WHITE:
	set(v):
		tint = v
		if is_inside_tree():
			_apply_tint()
## Placeholder weapon in the right hand (player only; NPCs hide it).
@export var show_weapon := true:
	set(v):
		show_weapon = v
		if is_inside_tree():
			$Skeleton2D/Hip/Torso/ArmR/Weapon.visible = v

var facing: int = Iso.Dir.S
var _walk := 0.0
var _phase := 0.0
var _attack_left := 0.0
var _hip_rest_y := 0.0

@onready var _hip: Bone2D = $Skeleton2D/Hip
@onready var _torso: Bone2D = $Skeleton2D/Hip/Torso
@onready var _leg_l: Bone2D = $Skeleton2D/Hip/LegL
@onready var _leg_r: Bone2D = $Skeleton2D/Hip/LegR
@onready var _arm_l: Bone2D = $Skeleton2D/Hip/Torso/ArmL
@onready var _arm_r: Bone2D = $Skeleton2D/Hip/Torso/ArmR
@onready var _face: Node2D = $Skeleton2D/Hip/Torso/Head/Face


func _ready() -> void:
	_hip_rest_y = _hip.position.y
	$Skeleton2D/Hip/Torso/ArmR/Weapon.visible = show_weapon
	_apply_tint()
	if skin == null and not character_name.is_empty() and not Engine.is_editor_hint():
		skin = ArtLibrary.character(character_name)
	apply_skin()


## 0..1 movement amount; drives the walk cycle.
func set_walk(amount: float) -> void:
	_walk = clampf(amount, 0.0, 1.0)


func set_facing(dir: int) -> void:
	if dir < 0:
		return
	facing = dir
	scale.x = -absf(scale.x) if Iso.is_left_facing(dir) else absf(scale.x)
	var back := Iso.is_back_facing(dir)
	_face.visible = not back
	if skin:
		_swap_textures(back)


func play_attack() -> void:
	_attack_left = ATTACK_TIME


func is_attacking() -> bool:
	return _attack_left > 0.0


func apply_skin() -> void:
	var has_skin := skin != null
	for part in PART_BONES:
		var bone := get_node(PART_BONES[part]) as Node2D
		bone.get_node("Placeholder").visible = not has_skin
		var art := bone.get_node_or_null("Art") as Sprite2D
		if not has_skin:
			if art:
				art.queue_free()
			continue
		if art == null:
			art = Sprite2D.new()
			art.name = "Art"
			art.centered = false
			bone.add_child(art)
		art.texture = skin.get_texture(part)
		art.offset = -skin.get_pivot(part)
		art.scale = Vector2.ONE / ArtLibrary.ART_SCALE
	if has_skin:
		_face.visible = false
		$Skeleton2D/Hip/Torso/ArmR/Weapon.visible = false


func _swap_textures(back: bool) -> void:
	for part in PART_BONES:
		var art := get_node(PART_BONES[part]).get_node_or_null("Art") as Sprite2D
		if art:
			art.texture = skin.get_texture(part, back)


func _apply_tint() -> void:
	for part in PART_BONES:
		get_node(PART_BONES[part]).get_node("Placeholder").self_modulate = tint


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var speed := lerpf(2.0, 11.0, _walk)
	_phase = fmod(_phase + delta * speed, TAU)
	var swing := sin(_phase) * 0.55 * _walk
	_leg_l.rotation = swing
	_leg_r.rotation = -swing
	_arm_l.rotation = -swing * 0.8
	_hip.position.y = _hip_rest_y - absf(cos(_phase)) * 5.0 * _walk + sin(_phase) * 1.2
	_torso.rotation = 0.06 * _walk
	if _attack_left > 0.0:
		_attack_left = maxf(_attack_left - delta, 0.0)
		var t := 1.0 - _attack_left / ATTACK_TIME
		_arm_r.rotation = lerpf(-2.6, 1.3, ease(t, 0.4))
	else:
		_arm_r.rotation = swing * 0.8
