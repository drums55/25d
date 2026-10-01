class_name ArtLibrary
## Drop-in art loader. Art is optional: every lookup returns null when the
## file is missing and the placeholder drawing stays. Just add PNGs under
## assets/art/ (then import: tools\run.ps1 does it) — no scene edits needed.
##
## Files may be .svg (vector, imported by Godot) or .png; .svg wins.
##   assets/art/props/<prop_name>.png          origin = bottom centre (feet)
##   assets/art/rooms/<room_name>.png          floor + back walls backdrop
##   assets/art/characters/<name>/<part>.png   head, torso, arm_l, arm_r,
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
const PARTS := ["head", "torso", "arm_l", "arm_r", "leg_l", "leg_r", "head_back", "torso_back"]


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
