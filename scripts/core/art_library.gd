class_name ArtLibrary
## Drop-in art loader. Art is optional: every lookup returns null when the
## file is missing and the placeholder drawing stays. Just add PNGs under
## assets/art/ (then import: tools\run.ps1 does it) — no scene edits needed.
##
## Files may be .svg (vector, imported by Godot) or .png; .svg wins.
##   assets/art/props/<prop_name>.png          origin = (W/2, H - PROP_FOOT_MARGIN)
##   assets/art/rooms/<room_name>.png          floor + back walls backdrop
##   assets/art/characters/<name>/sprites/     8-direction sprite sheets (preferred):
##       sprites.json  {frame_size, pivot, directions, anims:{name:{frames,fps}}}
##       <anim>.png    rows = directions in Iso.Dir order, columns = frames
##   assets/art/characters/<name>/<part>.png   cut-out fallback: head, torso, arm_l, arm_r,
##                                             leg_l, leg_r (+ head_back, torso_back)
##   assets/art/characters/<name>/pivots.json  optional {"part": [x, y]} joint
##                                             point in image px; default =
##                                             bottom centre for head/torso,
##                                             top centre for arms/legs
##
## Art is authored at ART_SCALE x the in-game size so it stays sharp on the
## 2560x1600 tablet; sprites are scaled by 1/ART_SCALE when applied.

const ROOT := "res://assets/art"
## Author art at 2x: a 160 px tall character is a 320 px PNG.
const ART_SCALE := 2.0
## Prop images keep this many (2x) pixels below the floor-contact point so the
## front corners / wheels / shadow are not clipped: origin = (W/2, H - margin).
const PROP_FOOT_MARGIN := 160.0
const PARTS := ["head", "torso", "arm_l", "arm_r", "leg_l", "leg_r", "head_back", "torso_back"]
## Animations that loop; anything else (attack...) plays once.
const LOOPING_ANIMS := ["idle", "walk"]


## Reads <root>/characters/<name>/sprites/sprites.json (+ one sheet per anim).
## Returns {} when the character has no sprite set. Result keys: "frame_size"
## (Vector2), "pivot" (Vector2), "directions" (Array[String]),
## "anims" {name: {frames, fps, texture}}.
static func sprite_set(char_name: String, root := ROOT) -> Dictionary:
	var dir := "%s/characters/%s/sprites" % [root, char_name]
	var json_path := dir.path_join("sprites.json")
	if not FileAccess.file_exists(json_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not parsed is Dictionary or not parsed.get("anims") is Dictionary:
		push_warning("ArtLibrary: bad sprites.json for %s" % char_name)
		return {}
	var out := {
		"frame_size": _vec(parsed.get("frame_size", [320, 480])),
		"pivot": _vec(parsed.get("pivot", [160, 448])),
		"directions": Array(parsed.get("directions", ["E", "SE", "S", "SW", "W", "NW", "N", "NE"])),
		"anims": {},
	}
	for anim in parsed["anims"]:
		var spec = parsed["anims"][anim]
		var tex := load_texture(dir.path_join(anim + ".png"))
		if tex == null or not spec is Dictionary:
			push_warning("ArtLibrary: %s/%s sheet missing" % [char_name, anim])
			continue
		out["anims"][anim] = {
			"frames": int(spec.get("frames", 1)),
			"fps": float(spec.get("fps", 8)),
			"texture": tex,
		}
	return out if not out["anims"].is_empty() else {}


## SpriteFrames with one animation per (anim, direction): "<anim>_<dir index>".
static func build_sprite_frames(sprite_set_data: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var size: Vector2 = sprite_set_data["frame_size"]
	var dir_count: int = sprite_set_data["directions"].size()
	for anim in sprite_set_data["anims"]:
		var spec: Dictionary = sprite_set_data["anims"][anim]
		for d in dir_count:
			var anim_name := "%s_%d" % [anim, d]
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, spec["fps"])
			frames.set_animation_loop(anim_name, anim in LOOPING_ANIMS)
			for f in spec["frames"]:
				var atlas := AtlasTexture.new()
				atlas.atlas = spec["texture"]
				atlas.region = Rect2(Vector2(f, d) * size, size)
				frames.add_frame(anim_name, atlas)
	return frames


static func _vec(v) -> Vector2:
	if v is Array and v.size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


## Imported textures (res://, after Godot import) load as resources; raw PNGs
## (user://, or res:// before import) are read as images.
static func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


static func load_art(base_path: String) -> Texture2D:
	for ext in ["svg", "png"]:
		var tex := load_texture("%s.%s" % [base_path, ext])
		if tex:
			return tex
	return null


static func prop(prop_name: String) -> Texture2D:
	return load_art("%s/props/%s" % [ROOT, prop_name])


static func room(room_name: String) -> Texture2D:
	return load_art("%s/rooms/%s" % [ROOT, room_name])


## Builds a CutoutSkin from a character folder, or null when it has no parts.
static func character(char_name: String, root := ROOT) -> CutoutSkin:
	var dir := "%s/characters/%s" % [root, char_name]
	var skin := CutoutSkin.new()
	for part in PARTS:
		var tex := load_art("%s/%s" % [dir, part])
		if tex:
			skin.textures[part] = tex
	if skin.textures.is_empty():
		return null
	var custom := _read_pivots("%s/pivots.json" % dir)
	for part in skin.textures:
		var size: Vector2 = skin.textures[part].get_size()
		skin.pivots[part] = custom.get(part, default_pivot(part, size))
	return skin


## Joint point in image pixels: head/torso hang from their bottom (neck/hips
## sit at the bottom centre); limbs hang from their top (shoulder/hip joint).
static func default_pivot(part: String, size: Vector2) -> Vector2:
	if part.begins_with("head") or part.begins_with("torso"):
		return Vector2(size.x * 0.5, size.y)
	return Vector2(size.x * 0.5, 0.0)


static func _read_pivots(path: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path):
		return out
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("ArtLibrary: %s is not a JSON object" % path)
		return out
	for part in parsed:
		var v = parsed[part]
		if v is Array and v.size() == 2:
			out[part] = Vector2(float(v[0]), float(v[1]))
	return out
