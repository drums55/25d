class_name Iso
## Isometric math helpers (2:1 diamond grid, Hades-style screen-space movement).
##
## Grid cell (0, 0) sits at world origin; +x goes down-right, +y goes down-left.
## Directions use screen space (y down): 0=E 1=SE 2=S 3=SW 4=W 5=NW 6=N 7=NE.

enum Dir { E, SE, S, SW, W, NW, N, NE }

const TILE_SIZE := Vector2(128, 64)


static func grid_to_world(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_SIZE.x * 0.5, (cell.x + cell.y) * TILE_SIZE.y * 0.5)


static func world_to_grid(pos: Vector2) -> Vector2:
	var hx := pos.x / (TILE_SIZE.x * 0.5)
	var hy := pos.y / (TILE_SIZE.y * 0.5)
	return Vector2((hx + hy) * 0.5, (hy - hx) * 0.5)


## Snaps a direction vector to one of 8 directions. Returns -1 for a zero vector.
static func dir8(v: Vector2) -> int:
	if v.length_squared() < 0.0001:
		return -1
	return wrapi(roundi(v.angle() / (PI / 4.0)), 0, 8)


static func dir8_vector(dir: int) -> Vector2:
	return Vector2.RIGHT.rotated(dir * PI / 4.0)


## True for directions that face away from the camera (show the character's back).
static func is_back_facing(dir: int) -> bool:
	return dir == Dir.NW or dir == Dir.N or dir == Dir.NE


## True for directions where a right-facing cut-out rig should be mirrored.
static func is_left_facing(dir: int) -> bool:
	return dir == Dir.SW or dir == Dir.W or dir == Dir.NW


## Corners of a diamond footprint centred on the origin, size in cells.
static func footprint(size_cells: Vector2) -> PackedVector2Array:
	var h := size_cells * 0.5
	return PackedVector2Array(
		[
			grid_to_world(Vector2(-h.x, -h.y)),
			grid_to_world(Vector2(h.x, -h.y)),
			grid_to_world(Vector2(h.x, h.y)),
			grid_to_world(Vector2(-h.x, h.y)),
		]
	)


## Grows `rect` (centred) so it is at least `view_size`, for Camera2D limits.
static func fit_camera_rect(rect: Rect2, view_size: Vector2) -> Rect2:
	var size := rect.size.max(view_size)
	return Rect2(rect.get_center() - size * 0.5, size)
