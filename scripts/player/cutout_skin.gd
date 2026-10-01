class_name CutoutSkin
extends Resource
## Art for a cut-out rig: one texture per body part (AI-generated, separate PNGs).
## `pivots` is the texture-space point that sits on the bone joint (e.g. the
## shoulder of an arm image). Optional `*_back` parts are used when the
## character faces away from the camera.
##
## Part names: head, torso, arm_l, arm_r, leg_l, leg_r (+ head_back, torso_back).

@export var textures: Dictionary = {}
@export var pivots: Dictionary = {}


func get_texture(part: String, back := false) -> Texture2D:
	if back and textures.has(part + "_back"):
		return textures[part + "_back"]
	return textures.get(part)


func get_pivot(part: String) -> Vector2:
	return pivots.get(part, Vector2.ZERO)
