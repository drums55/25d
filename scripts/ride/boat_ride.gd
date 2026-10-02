class_name BoatRide
extends Node2D
## Riding the floating bike along a canal to another place (DESIGN 11.5).
## Main.travel() sets `pending` and loads this scene; tap above / below the
## bike (W/S on PC) to change lane, dodge boats, crates, jars and the
## collector robot on its raft; water hyacinth slows you. At the end
## Main.arrive() loads the destination room.

const VIEW_AHEAD := 24.0
const VIEW_BEHIND := 8.0
const LANE_MOVE := 3.5
const RAMP := 1.5
const WATER_HALF := 1.7
const BANK := 1.2
const DECOR_GAP := 2.6
const BUMP_STOP := 0.8
const LINES := {
	"bump":
	[
		"โป๊ก! ... ขอโทษครับ",
		"ชนเบาๆ กล่องทองเหลืองกระแทกหลัง อุ่นขึ้นนิดนึง",
		"เรือลอยน้ำไม่มีเบรก"
	],
	"slow": ["ผักตบชวาพันใบพัด!", "ผักตบชวา ... ศัตรูถาวรของคลองกรุงเทพฯ"],
	"robot":
	[
		'หุ่นทวงหนี้บนแพ! "ตรวจพบลูกหนี้ ... ขออภัย แพเอียง"',
		"หุ่นทวงหนี้โบกมือ ... หรือมันเล็งอยู่"
	],
}

## Set by Main.travel(): {"dest": room id, "name": shown name, "track": BoatTrack}.
static var pending := {}

var dest := ""
var track := {}
var travelled := 0.0
var t := 0.0
var lane := 0.0
var target_lane := 0
var hits: Array[String] = []
var done := false
var _stopped := 0.0
var _slow := 0.0
var _hit := {}
var _nodes := {}
var _decor: Array[Node2D] = []
var _rng := RandomNumberGenerator.new()
var _world: Node2D
var _canal: Node2D
var _rider: Node2D
var _cam: Camera2D
var _ui: CanvasLayer
var _progress: ProgressBar
var _toast: Label


func _ready() -> void:
	add_to_group("ride")
	if pending.is_empty():
		push_error("BoatRide: no pending trip")
		return
	dest = pending["dest"]
	track = pending["track"]
	_rng.seed = hash([dest, "lines"])
	_canal = Node2D.new()
	_canal.z_index = -20
	_canal.draw.connect(_draw_canal)
	add_child(_canal)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	_build_rider()
	_build_decor()
	_cam = Camera2D.new()
	_cam.position = Iso.grid_to_world(Vector2(4.0, 0.0)) + Vector2(0, -120)
	add_child(_cam)
	_cam.make_current()
	_build_ui(str(pending.get("name", dest)))
	_layout()


func _sprite(art: String, scale_k := 1.0) -> Sprite2D:
	var tex := ArtLibrary.prop(art)
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + ArtLibrary.PROP_FOOT_MARGIN)
	s.scale = Vector2.ONE / ArtLibrary.ART_SCALE * scale_k
	return s


func _build_rider() -> void:
	_rider = Node2D.new()
	_rider.name = "Rider"
	var bike := _sprite("steam_bike")
	if bike:
		_rider.add_child(bike)
	var who := (load("res://scenes/characters/character_view.tscn") as PackedScene).instantiate()
	who.character_name = "rider"
	who.position = Vector2(-6, -38)
	_rider.add_child(who)
	who.set_facing(Iso.Dir.SE)
	_world.add_child(_rider)


## Stilt houses and poles drift past on both banks.
func _build_decor() -> void:
	var far := ["water_tank", "spirit_house", "water_tank", "power_pole"]
	var near := ["tide_gauge", "plant_pots", "tire_planter", "wait_bench"]
	var n := int((VIEW_AHEAD + VIEW_BEHIND) / DECOR_GAP) + 2
	for i in n:
		for side in [-1, 1]:
			var art: String = (far if side < 0 else near)[i % 4]
			var s := _sprite(art)
			if s == null:
				continue
			s.set_meta("x", -VIEW_BEHIND + i * DECOR_GAP + (0.0 if side < 0 else 1.3))
			s.set_meta("gy", -(WATER_HALF + 0.6) if side < 0 else WATER_HALF + 0.6)
			s.set_meta("wrap", n * DECOR_GAP)
			_world.add_child(s)
			_decor.append(s)


func _build_ui(place: String) -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var box := VBoxContainer.new()
	box.position = Vector2(40, 960)
	box.custom_minimum_size = Vector2(600, 0)
	_ui.add_child(box)
	box.add_child(UiKit.label("ขี่มอไซไป %s" % place, 30, UiKit.ACCENT))
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(600, 26)
	_progress.show_percentage = false
	box.add_child(_progress)
	box.add_child(UiKit.label("แตะเหนือรถ = เลนซ้าย · แตะใต้รถ = เลนขวา", 24, UiKit.MUTED))
	_toast = UiKit.label("", 40, Color(1, 0.9, 0.6))
	_toast.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.position = Vector2(460, 260)
	_toast.size = Vector2(1000, 120)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(_toast)


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	var touch := event as InputEventScreenTouch
	if touch and touch.pressed:
		var world := get_canvas_transform().affine_inverse() * touch.position
		steer(-1 if Iso.world_to_grid(world).y < lane else 1)
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
		steer(-1)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
		steer(1)


func steer(dir: int) -> void:
	target_lane = clampi(target_lane + dir, -1, 1)


func _process(delta: float) -> void:
	if done or track.is_empty() or GameState.input_locked:
		return
	step(delta)
	_layout()


## Advances the ride by `delta` seconds (tests call this directly).
func step(delta: float) -> void:
	t += delta
	lane = move_toward(lane, float(target_lane), LANE_MOVE * delta)
	var speed: float = float(track["speed"]) * clampf(t / RAMP, 0.2, 1.0)
	if _stopped > 0.0:
		_stopped -= delta
		speed = 0.0
	_slow = maxf(_slow - delta, 0.0)
	if _slow > 0.0:
		speed *= 0.4
	_check_hits()
	travelled += speed * delta
	if travelled >= float(track["length"]):
		_finish()


func _check_hits() -> void:
	var obs: Array = track["obstacles"]
	for i in obs.size():
		var o: Dictionary = obs[i]
		if float(o["x"]) - travelled > 6.0:
			break
		if _hit.has(i) or not BoatTrack.hits(o, t, travelled, lane):
			continue
		_hit[i] = true
		var effect: String = BoatTrack.KINDS[o["kind"]]["hit"]
		hits.append(effect)
		if effect == "slow":
			_slow = 1.5
		else:
			_stopped = BUMP_STOP
		var pool: Array = LINES[effect]
		_say(pool[_rng.randi() % pool.size()])


func _say(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _finish() -> void:
	done = true
	pending = {}
	get_tree().call_group("main", "arrive", dest, hits.size())


func _at(x: float, gy: float) -> Vector2:
	return Iso.grid_to_world(Vector2(x - travelled, gy))


func _layout() -> void:
	_rider.position = _at(travelled, lane) + Vector2(0, sin(t * 3.0) * 3.0)
	var obs: Array = track["obstacles"]
	for i in obs.size():
		var o: Dictionary = obs[i]
		var pos := BoatTrack.obstacle_pos(o, t)
		var rel := pos.x - travelled
		if rel < -VIEW_BEHIND or rel > VIEW_AHEAD:
			if _nodes.has(i):
				_nodes[i].queue_free()
				_nodes.erase(i)
			continue
		if not _nodes.has(i):
			_nodes[i] = _make_obstacle(o)
			_world.add_child(_nodes[i])
		var node: Node2D = _nodes[i]
		node.position = _at(pos.x + BoatTrack.kind_len(o["kind"]) * 0.5, pos.y)
		node.position.y += sin(t * 2.0 + i) * 3.0
	for d in _decor:
		var x: float = d.get_meta("x")
		while x - travelled < -VIEW_BEHIND:
			x += float(d.get_meta("wrap"))
		d.set_meta("x", x)
		d.position = _at(x, d.get_meta("gy"))
	if _progress:
		_progress.value = 100.0 * travelled / maxf(float(track["length"]), 0.1)
	_canal.queue_redraw()


func _make_obstacle(o: Dictionary) -> Node2D:
	var art: String = BoatTrack.KINDS[o["kind"]]["art"]
	if not art.is_empty():
		var s := _sprite(art, 0.8 if o["kind"] == "longtail" else 1.0)
		if s:
			return s
	# water hyacinth: a green floating mat
	var p := Polygon2D.new()
	p.z_index = -5
	p.color = Color(0.3, 0.55, 0.25, 0.9)
	var pts := PackedVector2Array()
	var half := BoatTrack.kind_len(o["kind"]) * 0.5
	for k in 18:
		var a := TAU * k / 18.0
		var r := 1.0 + 0.15 * sin(a * 5.0)
		pts.append(Iso.grid_to_world(Vector2(cos(a) * half * r, sin(a) * 0.42 * r)))
	p.polygon = pts
	return p


func _quad(x0: float, x1: float, g0: float, g1: float, col: Color) -> void:
	_canal.draw_colored_polygon(
		PackedVector2Array([_at(x0, g0), _at(x1, g0), _at(x1, g1), _at(x0, g1)]), col
	)


func _draw_canal() -> void:
	var x0 := travelled - VIEW_BEHIND - 4.0
	var x1 := travelled + VIEW_AHEAD + 4.0
	var far := WATER_HALF + BANK + 6.0
	_quad(x0, x1, -far, far, Color(0.14, 0.24, 0.28))
	_quad(x0, x1, -WATER_HALF - BANK, -WATER_HALF, Color(0.42, 0.33, 0.24))
	_quad(x0, x1, WATER_HALF, WATER_HALF + BANK, Color(0.42, 0.33, 0.24))
	_quad(x0, x1, -WATER_HALF, WATER_HALF, Color(0.24, 0.45, 0.5))
	# drifting ripples
	var step := 1.6
	var start := floorf(x0 / step) * step
	var i := 0
	var x := start
	while x < x1:
		for g in [-1.0, 0.0, 1.0]:
			var off := fmod(x * 7.3 + g * 3.1, 1.0)
			var a := _at(x + off, g + 0.3 * sin(x + t))
			var b := _at(x + off + 0.6, g + 0.3 * sin(x + t))
			_canal.draw_line(a, b, Color(0.6, 0.85, 0.88, 0.35), 3.0)
		x += step
		i += 1
