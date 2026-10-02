class_name PlatformPolicy
extends RefCounted
## The platform's rule of the day (DESIGN 10.5 / P2 "แพลตฟอร์มโหด"). Pure:
## picked from the city seed + day, announced the night before ("แจ้งล่วงหน้า
## วันเดียว") on the day slip and shown on top of the app's orders tab.
##
## Policy = {id, title, text, fee_delta (baht per job), surge (rain bonus),
## bundle (chance an offer comes as a forced pair), min_accept (below this
## acceptance rate offers pay ACCEPT_PENALTY less), selfie (lock the app every
## SELFIE_EVERY minutes until a selfie), sys_fee (baht taken per delivery),
## target + reward (the day's incentive: deliver `target` jobs, get `reward`)}.
##
## The incentive teases: one job short of the target the app goes quiet
## (Orders uses TEASE_GAP), like the real "job 20 never comes" bonus.

const BUNDLE_DEFAULT := 0.15
const ACCEPT_PENALTY := 0.75
const SELFIE_EVERY := 120.0
## Offer gap multiplier when the rider is one job short of the incentive.
const TEASE_GAP := 2.5

const BASE := {
	"id": "",
	"title": "",
	"text": "",
	"fee_delta": 0,
	"surge": OrderGen.RAIN_SURGE,
	"bundle": BUNDLE_DEFAULT,
	"min_accept": 0.0,
	"selfie": false,
	"sys_fee": 0,
	"target_add": 0,
	"reward_mult": 1.0,
}
const WELCOME := {
	"id": "welcome",
	"title": "ยินดีต้อนรับสู่ครอบครัวส่งไว!",
	"text": "วันแรกของคุณ ระบบจะมอบงานดีๆ ให้ (ตามความเหมาะสม)",
	"bundle": 0.0,
}
## Days 2+ draw from these without repeating.
const POLICIES := [
	{
		"id": "fee_cut",
		"title": "ปรับโครงสร้างค่ารอบเพื่อความยั่งยืน",
		"text": "ค่ารอบลดลง 6 บาทต่องาน มีผลทันที ขอบคุณที่เติบโตไปด้วยกัน",
		"fee_delta": -6,
	},
	{
		"id": "surge_cut",
		"title": "ค่ารอบพิเศษช่วงฝนปรับใหม่",
		"text": "ฝนตกได้เพิ่ม 2 บาท (จาก 10) เพื่อความเป็นธรรมกับลูกค้าที่ต้องรอ",
		"surge": 2,
	},
	{
		"id": "bundle_ai",
		"title": "ระบบจับคู่งานอัจฉริยะ AI",
		"text": "งานพ่วงมากขึ้น ประสิทธิภาพสูงสุด! (AI ไม่ได้ขี่รถเอง)",
		"bundle": 0.5,
	},
	{
		"id": "accept_rule",
		"title": "ส่งเสริมไรเดอร์ที่ทุ่มเท",
		"text": "อัตรารับงานต่ำกว่า 80% จะได้รับงานที่ 'เหมาะสมกับคุณ' (ค่ารอบ -25%)",
		"min_accept": 0.8,
	},
	{
		"id": "selfie",
		"title": "ยืนยันตัวตนเพื่อความปลอดภัย",
		"text": "ถ่ายเซลฟี่คู่กล่องทุก 2 ชั่วโมง ไม่ถ่าย = ไม่มีงานเข้า",
		"selfie": true,
	},
	{
		"id": "fee_up",
		"title": "ข่าวดี! ขึ้นค่ารอบ +2 บาท",
		"text": "(พร้อมค่าธรรมเนียมใช้ระบบ 3 บาท/งาน เพื่อพัฒนาแอปให้ดียิ่งขึ้น)",
		"fee_delta": 2,
		"sys_fee": 3,
	},
	{
		"id": "mega_quest",
		"title": "ภารกิจพิเศษ! โบนัสใหญ่ x1.5",
		"text": "เป้าวันนี้สูงกว่าปกตินิดหน่อย เพื่อรางวัลที่คุ้มค่า",
		"target_add": 3,
		"reward_mult": 1.5,
	},
]


## The policy in force on `day` for this city (deterministic).
static func for_day(seed: int, day: int) -> Dictionary:
	var p := BASE.duplicate()
	if day <= 1:
		p.merge(WELCOME, true)
	else:
		# shuffle once per city, then walk it: no repeats in a 7-day run
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed, "policy"])
		var order: Array = range(POLICIES.size())
		CityGen._shuffle(rng, order)
		p.merge(POLICIES[order[(day - 2) % order.size()]], true)
	var q := RandomNumberGenerator.new()
	q.seed = hash([seed, day, "quest"])
	p["target"] = 4 + int(day / 2) + q.randi_range(0, 1) + int(p["target_add"])
	p["reward"] = int(snappedf((100.0 + 25.0 * p["target"]) * float(p["reward_mult"]), 10.0))
	return p


static func quest_text(p: Dictionary, delivered: int, paid: bool) -> String:
	if paid:
		return "ภารกิจวันนี้สำเร็จ! ได้โบนัส %d บาทแล้ว" % int(p["reward"])
	var line := (
		"ภารกิจ: ส่งครบ %d งาน รับโบนัส %d บาท (ส่งแล้ว %d/%d)"
		% [p["target"], p["reward"], delivered, p["target"]]
	)
	if delivered == int(p["target"]) - 1:
		line += "\nอีกงานเดียว! ระบบกำลังหางานที่เหมาะกับคุณ ..."
	return line
