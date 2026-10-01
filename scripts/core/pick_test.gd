class_name PickTest
extends RefCounted
## Pixel-accurate tap test for point & click: a tap hits a pickable only where
## its sprite is actually drawn (alpha >= ALPHA), not anywhere inside a loose
## rectangle. Rectangles made props/NPCs that stand close together steal each
## other's taps (owner report 2026-10-01). Baked ground shadows are faint, so
## they do not count as a hit.

const ALPHA := 0.5
## Touch slack in world px: the tap counts if any sample within this radius
## lands on an opaque pixel (fingers are not pixel-precise).
const SLACK := 14.0

static var _masks := {}  # Texture2D -> BitMap


## 1 = hit, 0 = miss, -1 = `root` has no sprite to test (caller falls back to
## its pick_rect).
static func visual_hit(root: Node, world_pos: Vector2, slack := SLACK) -> int:
	var sprites: Array[Node2D] = []
	_collect(root, sprites)
	if sprites.is_empty():
		return -1
	var samples: Array[Vector2] = [world_pos]
	for i in 8:
		samples.append(world_pos + Vector2.from_angle(i * TAU / 8.0) * slack)
	for s in sprites:
		for p in samples:
			if _opaque_at(s, p):
				return 1
	return 0


static func _collect(node: Node, out: Array[Node2D]) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Sprite2D or node is AnimatedSprite2D:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


static func _opaque_at(sprite: Node2D, world_pos: Vector2) -> bool:
	var tex: Texture2D = null
	var region := Rect2()
	var centered := false
	var offset := Vector2.ZERO
	if sprite is Sprite2D:
		var s := sprite as Sprite2D
		tex = s.texture
		centered = s.centered
		offset = s.offset
	elif sprite is AnimatedSprite2D:
		var a := sprite as AnimatedSprite2D
		if a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
			return false
		tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		centered = a.centered
		offset = a.offset
	if tex == null:
		return false
	var size := tex.get_size()
	var p := sprite.to_local(world_pos) - offset
	if centered:
		p += size * 0.5
	if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y:
		return false
	var source := tex
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		source = at.atlas
		p += at.region.position
	var mask := _mask(source)
	if mask == null:
		return false
	var ip := Vector2i(p)
	var ms := mask.get_size()
	if ip.x >= ms.x or ip.y >= ms.y:
		return false
	return mask.get_bitv(ip)


static func _mask(tex: Texture2D) -> BitMap:
	if _masks.has(tex):
		return _masks[tex]
	var mask: BitMap = null
	var img := tex.get_image() if tex else null
	if img:
		if img.is_compressed():
			img.decompress()
		mask = BitMap.new()
		mask.create_from_image_alpha(img, ALPHA)
	_masks[tex] = mask
	return mask
