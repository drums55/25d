class_name RideScene
extends Node2D
## The ride between two places (City.travel -> here -> City.finish_ride): an
## iso road scrolling toward the lower right, three lanes, the rider on the
## scooter. Tap above / below the bike (or W/S, A/D) to change lane; dodge
## cars, buses, parked scooters, vendor carts, soi dogs, potholes, manholes,
## flooded puddles and police checkpoints; pick a branch at the fork. Hits
## shake the food (steadiness meter), cost time, or stop the bike. Game time
## runs with the ride, so a clean ride is also a fast one.

const VIEW_AHEAD := 24.0
const VIEW_BEHIND := 8.0
const LANE_MOVE := 3.5  # lanes per second (smooth glide, not a snap)
## Seconds to reach cruising speed at the start (a breath before the traffic).
const RAMP := 2.0
const ROAD_HALF := 1.5
const DECOR_GAP := 2.2
const SIGN_LEAD := 10.0

var track := {}
var dest := -1
var route := {}
var travelled := 0.0
var t := 0.0
var lane := 0.0
var target_lane := 0
var branch := ""
var steadiness := 100.0
var hits: Array[String] = []
var delay_minutes := 0.0
var done := false
## Rider fatigue at the start of the ride (P2): slower steering, nodding off.
var fatigue := 0.0
## A crash turned into a real accident (City.finish_ride bills the clinic).
var accident := false
var _stopped := 0.0
var _slow_reason := ""
var _hit := {}
var _nodes := {}
var _decor: Array[Node2D] = []
var _minute_acc := 0.0
var _last_change := -10.0
var _world: Node2D
var _road: RideRoad
var _rider: Node2D
var _bike_art: Node2D
var _cam: Camera2D
var _ui: CanvasLayer
var _progress: ProgressBar
var _steady: ProgressBar
var _toast: Label
var _hint: Label
var _signs: Array[Node2D] = []
var _rng := RandomNumberGenerator.new()
var _nod_at := 0.0


func _ready() -> void:
	add_to_group("ride")
	var pending: Dictionary = City.pending_ride
	if pending.is_empty():
		push_error("RideScene: no pending ride")
		return
	dest = int(pending["dest"])
	route = pending["route"]
	track = pending["track"]
	fatigue = GameState.fatigue
	_rng.seed = hash([GameState.city_seed, GameState.day, int(GameState.minute), dest, "ride"])
	_nod_at = _rng.randf_range(3.0, 6.0)
	_road = RideRoad.new()
	_road.ride = self
	_road.z_index = -20
	add_child(_road)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	_build_rider()
	_build_decor()
	_build_signs()
	_cam = Camera2D.new()
	# rider left of centre with most of the screen showing the road ahead
	_cam.position = Iso.grid_to_world(Vector2(4.0, 0.0)) + Vector2(0, -150)
	add_child(_cam)
	_cam.make_current()
	_build_ui()


func is_ride() -> bool:
	return true


func carrying_food() -> bool:
	for o in GameState.orders:
		if o["status"] == "picked" and o["kind"] == "food":
			return true
	return false


func end_x() -> float:
	return float(track["length"][branch])


# --- building -----------------------------------------------------------
func _build_rider() -> void:
	_rider = Node2D.new()
	_rider.name = "Rider"
	var tex := ArtLibrary.prop("rider_bike")
	if tex:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + ArtLibrary.PROP_FOOT_MARGIN)
		s.scale = Vector2.ONE / ArtLibrary.ART_SCALE
		_rider.add_child(s)
		_bike_art = s
	var who := (load("res://scenes/characters/character_view.tscn") as PackedScene).instantiate()
	who.character_name = "rider"
	who.position = Vector2(-6, -38)
	_rider.add_child(who)
	who.set_facing(Iso.Dir.SE)
	_world.add_child(_rider)


func _build_decor() -> void:
	var far := ["shophouse", "shophouse", "minimart", "shophouse"]
	var near := ["power_pole", "trash_bin", "bus_stop", "plant_pots"]
	var n := int((VIEW_AHEAD + VIEW_BEHIND) / DECOR_GAP) + 2
	for i in n:
		for side in [-1, 1]:
			if side > 0 and i % 2 == 1:
				continue  # near side: sparser, it is closer to the camera
			var art: String = (far if side < 0 else near)[(i / (1 if side < 0 else 2)) % 4]
			var tex := ArtLibrary.prop(art)
			if tex == null:
				continue
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.offset = Vector2(
				-tex.get_width() * 0.5, -tex.get_height() + ArtLibrary.PROP_FOOT_MARGIN
			)
			s.scale = Vector2.ONE / ArtLibrary.ART_SCALE
			s.set_meta("x", -VIEW_BEHIND + i * DECOR_GAP)
			s.set_meta("gy", -3.4 if side < 0 else 2.6)
			s.set_meta("wrap", n * DECOR_GAP)
			_world.add_child(s)
			_decor.append(s)


func _build_signs() -> void:
	var fork: Dictionary = track.get("fork", {})
	if fork.is_empty():
		return
	for side in [-1, 1]:
		var key := "A" if side < 0 else "B"
		var l := Label.new()
		l.text = ("เลนซ้าย: " if side < 0 else "เลนขวา: ") + String(fork[key]["label"])
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", Color(1, 1, 1))
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.25, 0.12))
		l.add_theme_constant_override("outline_size", 10)
		l.add_theme_stylebox_override(
			"normal",
			UiKit.panel_style(Color(0.08, 0.5, 0.28) if side < 0 else Color(0.15, 0.3, 0.6), 10)
		)
		l.position = Vector2(-230, -260 if side < 0 else -120)
		l.size = Vector2(460, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var holder := Node2D.new()
		holder.set_meta("gy", -1.6 if side < 0 else 1.6)
		holder.add_child(l)
		_world.add_child(holder)
		_signs.append(holder)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var box := VBoxContainer.new()
	box.position = Vector2(40, 880)
	box.custom_minimum_size = Vector2(560, 0)
	_ui.add_child(box)
	box.add_child(UiKit.label("กำลังขี่ไป %s" % City.node_name(dest), 30, UiKit.ACCENT))
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(560, 26)
	_progress.show_percentage = false
	box.add_child(_progress)
	box.add_child(UiKit.label("ความนิ่งของของในกล่อง", 24, UiKit.MUTED))
	_steady = ProgressBar.new()
	_steady.custom_minimum_size = Vector2(560, 26)
	_steady.show_percentage = false
	_steady.value = 100
	box.add_child(_steady)
	_toast = UiKit.label("", 40, Color(1, 0.9, 0.6))
	_toast.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.position = Vector2(460, 300)
	_toast.size = Vector2(1000, 120)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(_toast)
	_hint = UiKit.label("แตะเหนือรถ = เลนซ้าย · แตะใต้รถ = เลนขวา", 26, UiKit.MUTED)
	_hint.position = Vector2(40, 1110)
	_hint.size = Vector2(1000, 50)
	_ui.add_child(_hint)


# --- input ----------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	var touch := event as InputEventScreenTouch
	if touch and touch.pressed:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.blocks_point(touch.position):
			return
		var world := get_canvas_transform().affine_inverse() * touch.position
		var g := Iso.world_to_grid(world)
		steer(-1 if g.y < lane else 1)
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
		steer(-1)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
		steer(1)


## Move one lane toward `dir` (-1 left = up-left on screen, +1 right).
func steer(dir: int) -> void:
	var to := clampi(target_lane + dir, -1, 1)
	if to == target_lane:
		return
	target_lane = to
	# quick zig-zags slosh the soup more than one calm lane change
	steadiness -= 5.0 if t - _last_change < 0.5 else 1.5
	_last_change = t


# --- simulation -------------------------------------------------------------
func _process(delta: float) -> void:
	if done or track.is_empty():
		return
	if GameState.input_locked or Dialog.is_active():
		return
	step(delta)
	_layout()


## Advances the ride by `delta` seconds (tests call this directly).
func step(delta: float) -> void:
	t += delta
	lane = move_toward(lane, float(target_lane), LANE_MOVE * steer_factor(fatigue) * delta)
	if fatigue >= GameState.EXHAUSTED and t >= _nod_at:
		# nodding off: the bike drifts a lane on its own
		_nod_at = t + _rng.randf_range(4.0, 7.0)
		var drift := -1 if _rng.randf() < 0.5 else 1
		if target_lane + drift < -1 or target_lane + drift > 1:
			drift = -drift
		target_lane += drift
		_say("สัปหงก! รถส่ายเอง")
	var speed: float = track["speed"]
	_slow_reason = ""
	speed *= clampf(t / RAMP, 0.15, 1.0)
	if _stopped > 0.0:
		_stopped -= delta
		speed = 0.0
	_check_hits()
	if _slow_reason == "jam":
		speed *= 0.35
	elif _slow_reason == "wade":
		speed *= 0.55
	travelled += speed * delta
	# game time runs with the ride: a full clean ride = the map's estimate
	var clean_seconds := float(track["length"][""]) / float(track["speed"])
	_minute_acc += delta * float(track["base_minutes"]) / maxf(clean_seconds, 0.1)
	if _minute_acc >= 1.0:
		var whole := floorf(_minute_acc)
		_minute_acc -= whole
		GameState.advance_minutes(whole)
	var fork: Dictionary = track.get("fork", {})
	if branch.is_empty() and not fork.is_empty() and travelled >= float(fork["x"]) - SIGN_LEAD:
		branch = "A" if target_lane < 0 else "B"
		_say("เลี้ยวเข้า%s" % ("ซอยลัด" if branch == "A" else "ถนนใหญ่"))
	steadiness = clampf(steadiness, 0.0, 100.0)
	if travelled >= end_x():
		_finish()


## Lane-change speed multiplier: tired riders steer late.
static func steer_factor(f: float) -> float:
	return lerpf(1.0, 0.6, clampf((f - GameState.TIRED) / 60.0, 0.0, 1.0))


func _visible(o: Dictionary) -> bool:
	var b: String = o["branch"]
	return b.is_empty() or b == branch


func _check_hits() -> void:
	var obs: Array = track["obstacles"]
	for i in obs.size():
		var o: Dictionary = obs[i]
		if not _visible(o):
			continue
		if float(o["x"]) - travelled > 6.0:
			break
		if not RideTrack.hits(o, t, travelled, lane):
			continue
		var effect: String = RideTrack.KINDS[o["kind"]]["hit"]
		if effect == "jam" or effect == "wade":
			_slow_reason = effect
		if _hit.has(i):
			continue
		_hit[i] = true
		_apply(effect)


func _apply(effect: String) -> void:
	if effect == "dog" and GameState.has_flag("dog_friend"):
		# fed ข้าวตัง once: every soi dog in the district knows the bike now
		_say("หมาซอยวิ่งมาดม ... หางกระดิก (เพื่อนข้าวตัง)")
		return
	hits.append(effect)
	steadiness -= float(RideTrack.SHAKE.get(effect, 0.0)) * (1.3 if track["rain"] > 0 else 1.0)
	delay_minutes += float(RideTrack.DELAY.get(effect, 0.0))
	match effect:
		"crash":
			_stopped = 1.1
			GameState.add_fatigue(4.0)
			if not accident and _rng.randf() < City.accident_chance(fatigue, int(track["rain"])):
				accident = true
				_stopped = 3.0
				steadiness -= 40.0
				_say("อุบัติเหตุ! ล้มหนัก ... ต้องแวะคลินิก")
			else:
				_say("โครม! ล้มแล้วลุก ... เสียเวลา 3 นาที")
			_flash(Color(1, 0.4, 0.4))
		"dog":
			_say("หมาซอยไล่! เบรกตัวโก่ง")
		"bump":
			_say("ตกหลุม! ของในกล่องกระดอน")
		"slip":
			_say("ฝาท่อลื่น!")
		"wade":
			_say("ลุยน้ำขัง ... รองเท้าเปียก")
		"police":
			_stopped = 2.0
			_say("ด่านตรวจ! ขอดูใบขับขี่ เสียเวลา 5 นาที")
		"jam":
			_say("รถติด! คลานไปทีละนิด")


func _flash(col: Color) -> void:
	if _bike_art == null:
		return
	var tween := create_tween()
	_rider.modulate = col
	tween.tween_property(_rider, "modulate", Color.WHITE, 0.4)


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
	var result := {
		"dest": dest,
		"route": route,
		"steadiness": steadiness,
		"hits": hits,
		"delay": delay_minutes,
		"branch": branch,
		"accident": accident,
	}
	City.finish_ride(result)


# --- drawing --------------------------------------------------------------
func _at(x: float, gy: float) -> Vector2:
	return Iso.grid_to_world(Vector2(x - travelled, gy))


func _layout() -> void:
	_rider.position = _at(travelled, lane)
	_rider.position.y += sin(t * 8.0) * 1.0 if _stopped <= 0.0 else 0.0
	var obs: Array = track["obstacles"]
	for i in obs.size():
		var o: Dictionary = obs[i]
		var pos := RideTrack.obstacle_pos(o, t)
		var rel := pos.x - travelled
		var show := _visible(o) and rel > -VIEW_BEHIND and rel < VIEW_AHEAD
		if not show:
			if _nodes.has(i):
				_nodes[i].queue_free()
				_nodes.erase(i)
			continue
		if not _nodes.has(i):
			_nodes[i] = _make_obstacle(o)
			_world.add_child(_nodes[i])
		var center := pos.x + RideTrack.kind_len(o["kind"]) * 0.5
		var node: Node2D = _nodes[i]
		node.position = _at(center, 0.0 if o.get("all_lanes", false) else pos.y)
	for d in _decor:
		var x: float = d.get_meta("x")
		while x - travelled < -VIEW_BEHIND:
			x += float(d.get_meta("wrap"))
		d.set_meta("x", x)
		d.position = _at(x, d.get_meta("gy"))
	var fork: Dictionary = track.get("fork", {})
	for s in _signs:
		s.visible = branch.is_empty()
		s.position = _at(float(fork["x"]) - SIGN_LEAD + 1.0, s.get_meta("gy"))
	_progress.value = 100.0 * travelled / maxf(end_x(), 0.1)
	_steady.value = steadiness
	_steady.modulate = Color(1, 0.4, 0.3) if steadiness < 50.0 else Color.WHITE
	_road.queue_redraw()


func _make_obstacle(o: Dictionary) -> Node2D:
	var k: Dictionary = RideTrack.KINDS[o["kind"]]
	var art: String = k["art"]
	var tex := ArtLibrary.prop(art) if not art.is_empty() else null
	if tex:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + ArtLibrary.PROP_FOOT_MARGIN)
		s.scale = Vector2.ONE / ArtLibrary.ART_SCALE * float(k.get("scale", 1.0))
		return s
	var p := Polygon2D.new()
	p.z_index = -5
	var half := RideTrack.kind_len(o["kind"]) * 0.5
	var w := 0.4
	match o["kind"]:
		"pothole":
			p.color = Color(0.06, 0.05, 0.05, 0.95)
		"manhole":
			p.color = Color(0.45, 0.47, 0.5)
		"puddle":
			p.color = Color(0.35, 0.55, 0.8, 0.6)
			w = 0.48
		"jam":
			p.color = Color(1.0, 0.5, 0.2, 0.18)
			w = ROAD_HALF
	var pts := PackedVector2Array()
	for k2 in 20:
		var a := TAU * k2 / 20.0
		pts.append(Iso.grid_to_world(Vector2(cos(a) * half, sin(a) * w)))
	p.polygon = pts
	if o["kind"] == "jam":
		var l := Label.new()
		l.text = "รถติด"
		l.add_theme_font_size_override("font_size", 40)
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
		l.add_theme_constant_override("outline_size", 10)
		l.position = Vector2(-60, -60)
		p.add_child(l)
	return p
