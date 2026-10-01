class_name AppealChat
extends VBoxContainer
## Phone: appeal an unfair 1-star review with the platform's chatbot
## "น้องส่งไว" (DESIGN 10.5: ratings favour customers, complaints go nowhere).
## Every message costs game time; the outcome is mostly "คงคะแนนเดิม".

signal closed

const MINUTES_PER_MESSAGE := 3.0
const BASE_CHANCE := 0.15

var appeal := {}
var chance := BASE_CHANCE
var rng := RandomNumberGenerator.new()
var _log: VBoxContainer
var _choices: VBoxContainer


func _init(a: Dictionary) -> void:
	appeal = a
	add_theme_constant_override("separation", 10)
	rng.randomize()


func _ready() -> void:
	add_child(UiKit.label("แชทกับ น้องส่งไว (บอทช่วยเหลือไรเดอร์)", 30, UiKit.ACCENT))
	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", 8)
	add_child(_log)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	add_child(_choices)
	_bot("สวัสดีค่ะ น้องส่งไวยินดีให้บริการตลอด 24 ชม. (ยกเว้นช่วงที่มีปัญหา)")
	_bot('เรื่องรีวิว "%s" (%s) ใช่ไหมคะ' % [appeal.get("review", ""), appeal.get("item", "")])
	_offer(
		[
			["ลูกค้าให้ 1 ดาวเพราะเรื่องที่ไม่ใช่ความผิดผม", _explain],
			["ขอคุยกับเจ้าหน้าที่ที่เป็นคน", _human],
			["ช่างมัน", _give_up],
		]
	)


func _bot(text: String) -> void:
	_bubble("น้องส่งไว: " + text, Color(0.2, 0.24, 0.3))


func _me(text: String) -> void:
	_bubble("คุณ: " + text, UiKit.ACCENT_DARK)
	GameState.advance_minutes(MINUTES_PER_MESSAGE)


func _bubble(text: String, col: Color) -> void:
	var l := UiKit.label(text, 24)
	_log.add_child(UiKit.card([l], col))


func _offer(options: Array) -> void:
	UiKit.clear(_choices)
	for o in options:
		_choices.add_child(UiKit.button(o[0], _pick.bind(o[0], o[1]), 24, 66))


func _pick(text: String, next: Callable) -> void:
	_me(text)
	next.call()


func _explain() -> void:
	_bot("เข้าใจความรู้สึกค่ะ ระบบรับเรื่องแล้ว กรุณาแนบหลักฐานประกอบการพิจารณานะคะ")
	_offer(
		[
			["ส่งรูปของที่ส่งตรงเวลา (มีเวลาในรูป)", _evidence.bind(0.3)],
			["พิมพ์อธิบายยาวสามหน้า", _evidence.bind(0.15, 10.0)],
			["ส่งสติกเกอร์ร้องไห้", _evidence.bind(0.02)],
		]
	)


func _human() -> void:
	GameState.advance_minutes(5)
	_bot("ขณะนี้เจ้าหน้าที่ทุกท่านไม่ว่าง คิวของคุณคือ 3,482 ... ระหว่างนี้น้องส่งไวช่วยได้นะคะ!")
	chance += 0.05
	_offer([["ลูกค้าให้ 1 ดาวเพราะเรื่องที่ไม่ใช่ความผิดผม", _explain], ["ช่างมัน", _give_up]])


func _evidence(bonus: float, extra_minutes := 0.0) -> void:
	GameState.advance_minutes(extra_minutes)
	chance += bonus
	_bot("ได้รับหลักฐานแล้วค่ะ ระบบกำลังพิจารณา (อาจใช้เวลา 7-15 วันทำการ ... หรือเดี๋ยวนี้เลย)")
	var ok := rng.randf() < chance
	if ok:
		var idx := int(appeal.get("index", -1))
		if idx >= 0 and idx < GameState.ratings.size():
			GameState.ratings[idx] = 5
		GameState.stats_changed.emit()
		_bot("ผลการพิจารณา: ลบรีวิวนี้แล้วค่ะ (ครั้งนี้เท่านั้นนะคะ) ดาวของคุณกลับมาแล้ว")
	else:
		_bot("ผลการพิจารณา: คงคะแนนเดิมค่ะ ขอบคุณที่เป็นส่วนหนึ่งของครอบครัวส่งไว <3")
	_close_appeal()


func _give_up() -> void:
	_bot("ขอบคุณที่เข้าใจระบบค่ะ ขอให้วันนี้เป็นวันที่ดีนะคะ")
	_close_appeal()


func _close_appeal() -> void:
	appeal["open"] = false
	_offer([["กลับ", func(): closed.emit()]])
