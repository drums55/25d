class_name JobBoard
extends PanelContainer
## The job board at the win (motorcycle-taxi stand): lists jobs on offer with
## accept buttons, active jobs with status, and the "sleep" button that ends
## the day. Opened by HUD.open_job_board(); closing re-enables the world.

@onready var _offers: VBoxContainer = %Offers
@onready var _active: VBoxContainer = %Active
@onready var _cargo: Label = %Cargo
@onready var _sleep: Button = %Sleep
@onready var _close: Button = %Close


func _ready() -> void:
	hide()
	_close.pressed.connect(close)
	_sleep.pressed.connect(_on_sleep)
	# Method callables (not lambdas): they disconnect when this node is freed.
	Jobs.jobs_changed.connect(refresh)
	GameState.time_changed.connect(_on_time_changed)


func _on_time_changed(_day: int, _tick: int) -> void:
	refresh()


func open() -> void:
	GameState.input_locked = true
	refresh()
	show()


func close() -> void:
	hide()
	GameState.input_locked = false


func refresh() -> void:
	if not is_inside_tree():
		return
	for child in _offers.get_children():
		child.queue_free()
	for child in _active.get_children():
		child.queue_free()
	_cargo.text = (
		"ช่องเก็บของ %d/%d · วันที่ %d (%s)"
		% [
			GameState.active_jobs.size(),
			GameState.cargo_slots,
			GameState.day,
			GameState.slot_name()
		]
	)
	var offers := Jobs.available()
	if offers.is_empty():
		_offers.add_child(_label("วันนี้ไม่มีงานใหม่แล้ว"))
	for job in offers:
		_offers.add_child(_offer_row(job))
	var active := Jobs.active_jobs()
	if active.is_empty():
		_active.add_child(_label("ยังไม่ได้รับงาน"))
	for job in active:
		_active.add_child(_active_row(job))
	_sleep.text = "นอน (จบวันที่ %d)" % GameState.day


func _label(text: String, size := 26) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	return l


func _offer_row(job: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_label("%s — %s" % [job["title"], job.get("from", "")], 30))
	text.add_child(
		_label(
			(
				"%s\nรับที่ %s → ส่งที่ %s · %d บาท · ภายใน %d ช่วง"
				% [
					job.get("desc", ""),
					job["pickup"].get("where", "?"),
					job["dropoff"].get("where", "?"),
					int(job.get("reward", 0)),
					int(job.get("deadline_slots", 6))
				]
			),
			22
		)
	)
	row.add_child(text)
	var btn := Button.new()
	btn.text = "รับงาน"
	btn.custom_minimum_size = Vector2(180, 80)
	btn.add_theme_font_size_override("font_size", 30)
	btn.disabled = Jobs.cargo_free() <= 0
	btn.pressed.connect(func(): Jobs.accept(job["id"]))
	row.add_child(btn)
	return row


func _active_row(job: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var status := "ไปรับที่ %s" % job["pickup"].get("where", "?")
	if job.get("picked", false):
		status = "ถือของอยู่ → ส่งที่ %s" % job["dropoff"].get("where", "?")
	var left := int(job.get("due_tick", 0)) - GameState.tick
	var due := (
		"สายแล้ว" if left < 0 else "เหลือ %d ช่วง" % ceili(left / float(GameState.TICKS_PER_SLOT))
	)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_label("%s · %s · %s" % [job["title"], status, due], 26))
	row.add_child(text)
	var btn := Button.new()
	btn.text = "ทิ้งงาน"
	btn.custom_minimum_size = Vector2(160, 70)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(func(): Jobs.abandon(job["id"]))
	row.add_child(btn)
	return row


func _on_sleep() -> void:
	Jobs.sleep()
	close()
	GameState.save_game()
