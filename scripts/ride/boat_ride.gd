class_name BoatRide
extends Node2D
## Riding the floating bike along a canal to another place (DESIGN 11.5).
## Main.travel() sets `pending` and loads this scene. Normally a ~3 s
## cutscene (owner 2026-10-02: the playable ride was padding): the bike
## cruises down the middle lane past one canal gag with a line from the
## rider; a tap anywhere skips it. `pending.play` = the steerable runner
## (tap above / below the bike, W/S on PC, to change lane; hyacinth slows),
## kept for story set pieces. At the end Main.arrive() loads the room.
##
## `pending.convoy` (DESIGN 12.8 "ขบวนเรือตีสาม"): the one playable ride, not
## skippable. Every boat the rider got on side follows (Endings.convoy, the
## characters sitting aboard), the temple bell and firecrackers go all the
## way, a wall of water chases from the left edge. A hit = the next boat in
## the line stumbles and someone falls in: flag wet_<id> (their epilogue
## card changes), never the ending.

const CHARACTER_SCENE := preload("res://scenes/characters/character_view.tscn")
const VIEW_AHEAD := 24.0
const VIEW_BEHIND := 8.0
const LANE_MOVE := 3.5
const RAMP := 1.5
const WATER_HALF := 1.7
const BANK := 1.2
const DECOR_GAP := 2.6
const BUMP_STOP := 0.8
## Where the rider's feet go so that, sitting ("ride" pose), they land on the seat.
const RIDER_SEAT := Vector2(-6, -30)
## Cutscene length (s) and when the gag line shows.
const CUT_TIME := 3.4
const GAG_AT := 0.7
## The convoy: length (s), boat spacing (canal units), how far behind the
## rider the lane change reaches each boat (s per boat), the bell's beat.
const CONVOY_TIME := 60.0
const CONVOY_GAP := 1.6
const CONVOY_LAG := 0.4
const BELL_EVERY := 2.6
const FIRECRACKER_EVERY := 4.3
## The water wall rests this far behind the last boat, and closes to this
## share of it while the convoy is stopped or slowed.
const WALL_MARGIN := 2.0
const WALL_CLOSE := 0.55
## One of these drifts past on each trip: obstacle kind, x, lane, line.
## Lane 0 = right in the bike's way (it bumps / slows, which is the joke).
const GAGS := [
	["hyacinth", 6.0, 0, "ผักตบชวาพันใบพัด! ... ศัตรูถาวรของคลองกรุงเทพฯ"],
	["crate", 6.5, 0, "โป๊ก! ชนลังลอยน้ำ ... ขอโทษครับ ลังใครก็ไม่รู้"],
	["robot", 7.0, 1, "หุ่นทวงหนี้บนแพโบกมือ ... หรือมันเล็งอยู่"],
	["jar", 6.0, -1, "โอ่งมังกรลอยผ่าน มีปลาหมอนอนอยู่ข้างใน ไม่ต้องจ่ายค่าเช่า อิจฉา"],
	["bin", 6.0, 1, 'ถังขยะลอยผ่าน ยังติดสติกเกอร์ "แยกขยะ ชีวิตดีขึ้น"'],
	["longtail", 4.0, -1, "เรือหางยาวแซงไม่ได้ เพราะเรือเตอร์ไซค์มีเป็ดยางนำทาง"],
]
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
## Tests: arrive at once without loading the ride scene.
static var skip_all := false

var dest := ""
var play := false
var convoy := false
var gag_line := ""
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
var _wave: Node2D
var _rider: Node2D
var _cam: Camera2D
var _ui: CanvasLayer
var _progress: ProgressBar
var _toast: Label
var _boats: Array[Node2D] = []
var _lane_log: Array = []
var _next_bell := 0.0
var _next_cracker := FIRECRACKER_EVERY * 0.5
var _wall_x := -12.0


func _ready() -> void:
	add_to_group("ride")
	if pending.is_empty():
		push_error("BoatRide: no pending trip")
		return
	dest = pending["dest"]
	play = bool(pending.get("play", false))
	convoy = bool(pending.get("convoy", false))
	track = pending["track"] if play else cutscene_track(int(pending.get("seed", 0)))
	modulate = pending.get("tint", Color.WHITE)
	_rng.seed = hash([dest, "lines"])
	_canal = Node2D.new()
	_canal.z_index = -20
	_canal.draw.connect(_draw_canal)
	add_child(_canal)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	if convoy:
		# the wall of water rides over everything it has reached
		_wave = Node2D.new()
		_wave.z_index = 10
		_wave.draw.connect(_draw_wall)
		add_child(_wave)
	_build_rider()
	_build_decor()
	if convoy:
		_build_convoy()
	_cam = Camera2D.new()
	_cam.position = Iso.grid_to_world(Vector2(4.0, 0.0)) + Vector2(0, -120)
	add_child(_cam)
	_cam.make_current()
	_build_ui(str(pending.get("name", dest)))
	_layout()


## A short straight run with one gag (GAGS) placed from `seed`.
func cutscene_track(seed: int) -> Dictionary:
	var gag: Array = GAGS[posmod(seed, GAGS.size())]
	gag_line = gag[3]
	return {
		"speed": BoatTrack.SPEED,
		"length": BoatTrack.SPEED * (CUT_TIME - RAMP * 0.5),
		"obstacles": [{"kind": gag[0], "x": gag[1], "lane": gag[2]}],
	}


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
	var bike := _sprite("boat_bike")
	if bike:
		_rider.add_child(bike)
	var who := CHARACTER_SCENE.instantiate()
	who.character_name = "rider"
	who.position = RIDER_SEAT
	_rider.add_child(who)
	who.set_facing(Iso.Dir.SE)
	who.set_pose("ride")
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


## The boats that follow the rider, front to back, with their people aboard.
func _build_convoy() -> void:
	var i := 0
	for b in Endings.convoy(GameState.flags):
		var boat := Node2D.new()
		boat.name = "Boat_%s" % b["id"]
		boat.set_meta("id", b["id"])
		boat.set_meta("name", b["name"])
		boat.set_meta("back", CONVOY_GAP * (i + 1))
		var hull := _sprite(str(b["boat"]), 0.9)
		if hull:
			boat.add_child(hull)
		var who := CHARACTER_SCENE.instantiate()
		who.character_name = str(b["who"])
		who.position = Vector2(0, -26)
		boat.add_child(who)
		who.set_facing(Iso.Dir.SE)
		if not str(b["pose"]).is_empty():
			who.set_pose(str(b["pose"]))
		_world.add_child(boat)
		_boats.append(boat)
		i += 1


func _build_ui(place: String) -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var box := VBoxContainer.new()
	box.position = Vector2(40, 960)
	box.custom_minimum_size = Vector2(600, 0)
	_ui.add_child(box)
	_toast = UiKit.label("", 40, Color(1, 0.9, 0.6))
	_toast.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.position = Vector2(360, 230)
	_toast.size = Vector2(1200, 120)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui.add_child(_toast)
	if not play:
		# where we're going on a little tin sign, and how to skip
		var sign := Label.new()
		sign.text = "→ %s" % place
		sign.add_theme_font_override("font", UiKit.FONT_SIGN)
		sign.add_theme_font_size_override("font_size", 34)
		sign.add_theme_color_override("font_color", UiKit.SIGN_TEXT)
		sign.add_theme_stylebox_override("normal", UiKit.nine("sign", 30, Vector4(34, 18, 34, 16)))
		sign.position = Vector2(48, 40)
		_ui.add_child(sign)
		var skip := UiKit.label("แตะเพื่อข้าม", 26, Color(1, 1, 1, 0.55))
		skip.autowrap_mode = TextServer.AUTOWRAP_OFF
		_ui.add_child(skip)
		var screen := get_viewport().get_visible_rect().size
		skip.position = screen - skip.get_minimum_size() - Vector2(60, 40)
		return
	var title := (
		"ขบวนเรือตีสาม · นำทั้งซอยออกคลองใหญ่" if convoy else "ขี่เรือเตอร์ไซค์ไป %s" % place
	)
	box.add_child(UiKit.label(title, 30, UiKit.ACCENT))
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(600, 26)
	_progress.show_percentage = false
	box.add_child(_progress)
	var help := "แตะเหนือรถ = เลนซ้าย · แตะใต้รถ = เลนขวา"
	if convoy:
		help += " · ชนอะไร = เรือลำหลังสะดุด คนตกน้ำ"
	box.add_child(UiKit.label(help, 24, UiKit.MUTED))


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	var touch := event as InputEventScreenTouch
	if not play:
		if (touch and touch.pressed) or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			skip()
		return
	if touch and touch.pressed:
		var world := get_canvas_transform().affine_inverse() * touch.position
		steer(-1 if Iso.world_to_grid(world).y < lane else 1)
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
		steer(-1)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
		steer(1)


## Cut the trip short (a tap during the cutscene).
func skip() -> void:
	if not done and not SceneRouter.is_busy():
		_finish()


func steer(dir: int) -> void:
	target_lane = clampi(target_lane + dir, -1, 1)


func _process(delta: float) -> void:
	if done or track.is_empty() or GameState.input_locked:
		return
	step(delta)
	_layout()


## Advances the ride by `delta` seconds (tests call this directly).
func step(delta: float) -> void:
	if not play and not gag_line.is_empty() and t < GAG_AT and t + delta >= GAG_AT:
		_say(gag_line)
	t += delta
	if convoy:
		_convoy_step(delta)
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
		Audio.sfx("bump" if effect != "slow" else "tide", 0.1)
		if effect == "slow":
			_slow = 1.5
		else:
			_stopped = BUMP_STOP
		if convoy and not _boats.is_empty():
			_someone_falls_in()
		elif play:
			var pool: Array = LINES[effect]
			_say(pool[_rng.randi() % pool.size()])


## The bell keeps time, firecrackers from the bell tower, the water wall
## creeps up when the convoy stalls and falls back when it moves.
func _convoy_step(delta: float) -> void:
	_lane_log.append([t, lane])
	while _lane_log.size() > 2 and float(_lane_log[1][0]) < t - CONVOY_LAG * (_boats.size() + 1):
		_lane_log.pop_front()
	if t >= _next_bell:
		_next_bell = t + BELL_EVERY
		Audio.sfx("bell", 0.04)
	if t >= _next_cracker:
		_next_cracker = t + FIRECRACKER_EVERY
		Audio.sfx("firecracker", 0.1)
	var rest := -(CONVOY_GAP * (_boats.size() + 1) + WALL_MARGIN)
	var chase := rest if _stopped <= 0.0 and _slow <= 0.0 else rest * WALL_CLOSE
	_wall_x = move_toward(_wall_x, chase, delta * 2.5)


## The lane the rider held `ago` seconds back (the boats steer late).
func _lane_ago(ago: float) -> float:
	var want := t - ago
	for i in range(_lane_log.size() - 1, -1, -1):
		if float(_lane_log[i][0]) <= want:
			return float(_lane_log[i][1])
	return lane if _lane_log.is_empty() else float(_lane_log[0][1])


## A hit: the next boat in line stumbles and its person is wet for good.
func _someone_falls_in() -> void:
	var boat: Node2D = _boats[(hits.size() - 1) % _boats.size()]
	var id := str(boat.get_meta("id"))
	GameState.set_flag("wet_%s" % id)
	Audio.sfx("splash", 0.1)
	_say("%s สะดุด ... ตกน้ำ! (ขึ้นมาแล้ว เปียก)" % boat.get_meta("name"))
	var tw := boat.create_tween()
	tw.tween_property(boat, "rotation_degrees", -14.0, 0.12)
	tw.tween_property(boat, "rotation_degrees", 10.0, 0.18)
	tw.tween_property(boat, "rotation_degrees", 0.0, 0.3)


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
	for i in _boats.size():
		var boat := _boats[i]
		var back: float = boat.get_meta("back")
		var bl := _lane_ago(CONVOY_LAG * (i + 1))
		boat.position = _at(travelled - back, bl) + Vector2(0, sin(t * 3.0 + i) * 3.0)
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
	if _wave:
		_wave.queue_redraw()
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


## The wall of water the valve sent, chasing from the left edge: everything
## behind the crest is under pale water, the crest itself a tall ribbon of
## foam with spray, drawn over the boats it has caught up with.
func _draw_wall() -> void:
	var wx := travelled + _wall_x
	var x0 := travelled - VIEW_BEHIND - 12.0
	var far := WATER_HALF + BANK + 6.0
	_wave.draw_colored_polygon(
		PackedVector2Array([_at(x0, -far), _at(wx, -far), _at(wx, far), _at(x0, far)]),
		Color(0.62, 0.82, 0.92, 0.82)
	)
	var top := PackedVector2Array()
	var foot := PackedVector2Array()
	var n := 22
	for k in n + 1:
		var g := -far + (far * 2.0) * k / n
		var h := 170.0 + 40.0 * sin(t * 3.5 + k * 1.3) + 18.0 * sin(t * 7.0 - k * 2.1)
		foot.append(_at(wx, g))
		top.append(_at(wx - 0.5, g) + Vector2(0, -h))
	var crest := PackedVector2Array()
	crest.append_array(top)
	var back := foot.duplicate()
	back.reverse()
	crest.append_array(back)
	_wave.draw_colored_polygon(crest, Color(0.78, 0.92, 0.98, 0.92))
	_wave.draw_polyline(top, Color(1, 1, 1, 0.95), 7.0)
	for k in range(0, n + 1, 2):
		var a: Vector2 = top[k]
		var r := 9.0 + 5.0 * absf(sin(t * 5.0 + k))
		_wave.draw_circle(a + Vector2(0, -r - 6.0), r, Color(1, 1, 1, 0.85))
		_wave.draw_line(a, a + Vector2(14, -r * 4.0), Color(1, 1, 1, 0.5), 3.0)
