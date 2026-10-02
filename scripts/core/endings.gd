class_name Endings
extends RefCounted
# gdlint: disable=max-line-length
## Chapter 3 "คืนตีสาม" (DESIGN 12.8): ONE ending, linear, the best one (owner
## 2026-10-02: "ทำ linear แต่จบดีที่สุดไปเลยก็ได้นะ"). Pure.
##
## The valve opens only when the PLAN is complete: wake the soi, carry it,
## somewhere to go, and time (the forecast board the company obeys). Then the
## convoy ride, and the soi comes up out of the water. What differs between
## plays is the EPILOGUES: one card per character, by the side plots done and
## by who fell in the canal during the convoy (wet_<id>).

## The four parts of the plan and the flags that fill them (all required).
const PLAN := [
	{
		"id": "wake",
		"title": "ปลุก",
		"flags":
		{
			"ally_jum": "ป้าจุ๋มกับโทรโข่งพี่หนวด",
			"ally_monk": "ระฆังวัดตอนตีสาม (หลวงพี่น้ำ)",
		},
	},
	{
		"id": "carry",
		"title": "พา",
		"flags":
		{
			"ally_ple": "วินเรือพี่เปิ้ลทั้งวิน",
			"ally_berm": "กองเรือมูลนิธิพี่เบิ้ม (ไลฟ์สด)",
		},
	},
	{
		"id": "shelter",
		"title": "ที่ไป",
		"flags":
		{
			"ally_nok": "งานแต่งลุงโต๊ะสามกับป้านกบนเรือ",
			"ally_beam": "คุณบีมเปิดประตูกำแพงกันทะเล",
		},
	},
	{
		"id": "time",
		"title": "เวลา",
		"flags": {"forecast_rigged": "ป้ายพยากรณ์บอกบริษัทว่า ตีสี่"},
	},
]
## Not required, but named on the card and in the epilogues.
const HELPERS := {
	"ally_keng": "น้องเก่งเฝ้าเข็มวัดแรงดัน",
	"ally_nine": "เก้าคุยหุ่นบริษัทที่ประตูน้ำจนลืมหน้าที่",
	"ally_daeng": "ช่างแดงเปิดวาล์วข้าง",
	"ally_kiao": "เจ๊เกียวสัญญาเผาสมุดหนี้ทั้งซอย",
}
const ENDING := "five_stars"

const TEXT := {
	"five_stars":
	[
		"ตอนจบ: ไรเดอร์ห้าดาว",
		(
			"ตีสี่ตรง หุ่นบริษัทเปิดท่อตามป้ายพยากรณ์ ... ช้าไปหนึ่งชั่วโมง ทั้งซอยอยู่บนเรือแล้ว\n"
			+ "น้ำไหลกลับไปหาตึกที่ส่งมันมา ซอยส่งไวโผล่พ้นน้ำเป็นครั้งแรกในรอบสิบปี\n"
			+ 'เช้านั้นที่ท่าเรือมีป้ายไม้เขียนมือแผ่นใหม่: "ไรเดอร์ห้าดาว ★★★★★ — ป้าจุ๋มให้"\n'
			+ 'คะแนนแรกในชีวิตไรเดอร์ที่มาจากคนจริงๆ ... แอปส่งไวให้หนึ่งดาว ข้อหา "ส่งช้า (ตีสี่)"'
		),
	],
}

## One card per character: who (character sheet, or "prop:<art>"), name,
## variants tried in order (first whose if/if_not pass; the last is the
## default). wet_<id> = fell in the canal during the convoy.
const EPILOGUES := [
	{
		"who": "jum",
		"name": "ป้าจุ๋ม",
		"variants":
		[
			{
				"if": ["wet_jum"],
				"text":
				'ตกน้ำกลางขบวน แต่ยังตะโกนต่อใต้น้ำ ... ขึ้นมาเปิดสำนักข่าว "ซอยส่งไวนิวส์" ข่าวแรก: เรื่องผัวเก่าป้า ทั้งเรื่อง',
			},
			{
				"text":
				'เปิดสำนักข่าว "ซอยส่งไวนิวส์" ออกอากาศทางโทรโข่ง ... ข่าวแรก: เรื่องผัวเก่าป้า ทั้งเรื่อง ทั้งซอยฟังจนจบ',
			},
		],
	},
	{
		"who": "nuad",
		"name": "พี่หนวด",
		"variants":
		[
			{
				"if": ["wet_nuad"],
				"text":
				'พายเรือตกน้ำ แต่ยังพายต่อใต้น้ำ ... ได้ชื่อใหม่ว่า "พี่หนวดดำน้ำ" และได้งานใหม่: ประกาศเสียงตามสายของซอย',
			},
			{
				"text":
				'ได้งานใหม่: ประกาศเสียงตามสายของซอย "ดอกวันนี้!" เปลี่ยนเป็น "น้ำวันนี้!" ... ทั้งซอยยังสะดุ้งเหมือนเดิม',
			},
		],
	},
	{
		"who": "luang_pee",
		"name": "หลวงพี่น้ำ",
		"variants":
		[
			{
				"text":
				'ยังตีระฆังตีสามทุกคืน ขีดบนเสาหอระฆังต่ำลงทุกคืนเป็นครั้งแรกในสามสิบปี ... ท่านจดต่อ "เผื่อมีคนไม่เชื่อ"',
			},
		],
	},
	{
		"who": "ple",
		"name": "พี่เปิ้ล",
		"variants":
		[
			{
				"if": ["wet_ple"],
				"text":
				'วินเรือเบอร์ 1 ตกน้ำกลางขบวน ลุกขึ้นมาตะโกน "น้องแอป ขับไม่เป็นเหรอ!" ... เช้าวันรุ่งขึ้นเปิดสายวินใหม่: วินส่งของ ค่าโดยสารตามระดับน้ำ',
			},
			{
				"text":
				"เปิดสายวินใหม่: วินส่งของ แข่งกับแอป ... ค่าโดยสารตามระดับน้ำ ตอนนี้น้ำลด เลยถูกกว่าแอปครั้งแรกในชีวิต",
			},
		],
	},
	{
		"who": "ton",
		"name": "น้องต้น",
		"variants":
		[
			{
				"if": ["ton_home"],
				"text":
				"กลับบ้านในชุดยาม ขับวินเบอร์ 13 ของแม่ ... ลูกค้าคิดว่าเป็นวินของบริษัท ยอมจ่ายแพงกว่าสองเท่า แม่ไม่แก้ความเข้าใจผิด",
			},
			{
				"text":
				'ยังอยู่ในตู้ยาม ชั้น 12 ที่ไม่มีอยู่จริง ... ส่งโน้ตให้แม่ทุกสัปดาห์ผ่านไรเดอร์ "ไม่ได้กลับเพราะกะ"',
			},
		],
	},
	{
		"who": "berm",
		"name": "พี่เบิ้ม จอมบุญ",
		"variants":
		[
			{
				"if": ["wet_berm"],
				"text":
				'ตกน้ำกลางไลฟ์ ยอดวิวสามล้าน ... ยอดโอนพอซื้อเรือใหม่หกลำ ซื้อห้า เก็บหนึ่ง "ค่าบริหาร" ... แล้วก็ซื้อลำที่หกให้ซอยจริงๆ ตอนไม่มีกล้อง',
			},
			{
				"text":
				'ไลฟ์การอพยพยอดวิวล้านสอง บริษัทป้องกันภัยมอบโล่ "คนดีแห่งปี" ... เขารับ แล้วไลฟ์ตอนรับ แล้วเอาโล่ไปขายซื้อข้าวสารให้ซอย ตอนไม่มีกล้อง',
			},
		],
	},
	{
		"who": "beam",
		"name": "คุณบีม",
		"variants":
		[
			{
				"if": ["ally_beam"],
				"text":
				"ถูกย้ายไปแผนกลูกค้าสัมพันธ์ชั้นใต้ดิน (ที่เป็นสระว่ายน้ำ) ... ยื่นใบลาออกพร้อมแบบสอบถามให้บริษัทกรอก: หนึ่งดาว ขอบคุณที่เป็นแก้มลิง",
			},
			{"text": "ยังยิ้มอยู่ที่ป้อมยาม แบบสอบถามปึกเดิม ... ปุ่ม 5 สึกจนเรียบ"},
		],
	},
	{
		"who": "lung_mor_nam",
		"name": "ลุงหมอน้ำ",
		"variants":
		[
			{
				"if": ["forecast_rigged"],
				"text":
				'พยากรณ์ถูกครั้งแรกในชีวิต ในคืนที่ไม่ได้เขียนเอง ... เช้าวันรุ่งขึ้นลุงพยากรณ์ว่า "ลุงจะพยากรณ์ถูกอีก" ทั้งซอยโล่งใจ',
			},
			{"text": "ยังพยากรณ์ทุกเช้า ผิดทุกเช้า ... คนยังเชื่อทุกเช้า"},
		],
	},
	{
		"who": "pa_nok",
		"name": "ป้านกกับลุงโต๊ะสาม",
		"variants":
		[
			{
				"if": ["wet_nok"],
				"text":
				"เรือก๋วยเตี๋ยวเอียงกลางขบวน น้ำซุปหกลงคลอง ปลาทั้งคลองอร่อยขึ้นหนึ่งคืน ... งานแต่งจัดต่อบนเรือเปียกๆ ลุงย้ายไปนั่งโต๊ะหนึ่ง ข้างหม้อ",
			},
			{
				"text":
				"ลุงย้ายไปนั่งโต๊ะหนึ่ง ข้างหม้อ ป้านกคิดเงินเขาทุกชาม ... เขาจ่ายทุกชาม พร้อมดอก ป้าบอกว่าเป็นคู่ที่ดีที่สุดในซอย",
			},
		],
	},
	{
		"who": "keng",
		"name": "น้องเก่ง",
		"variants":
		[
			{
				"if": ["ally_keng"],
				"text":
				"ออกจากบ้านตอนกลางคืนเป็นครั้งแรก ... ตอนนี้ออกทุกคืน แม่เริ่มคิดถึงสมัยที่เขาติดเกม",
			},
			{"text": 'ดูการอพยพผ่านไลฟ์พี่เบิ้ม ให้สี่ดาว "กราฟิกดี บทไม่สมจริง"'},
		],
	},
	{
		"who": "prop:brass_automaton",
		"name": "เก้า",
		"variants":
		[
			{
				"if": ["ally_nine"],
				"text":
				'เล่าเรื่องให้หุ่นบริษัทฟังจนถึงเช้า หุ่นตัวนั้นลาออก ... ตอนนี้สองตัวจัดรายการวิทยุ 90.9 "คุยไม่หยุด" ลูกทุ่งเหลือวันละชั่วโมง',
			},
			{
				"text":
				'กลับไปทวงหนี้ แต่ทวงด้วยคำถาม "มนุษย์ตัดสินใจยังไงครับ" ... ไม่มีใครจ่าย ไม่มีใครตอบ'
			},
		],
	},
	{
		"who": "chang_daeng",
		"name": "ช่างแดง",
		"variants":
		[
			{
				"if": ["ally_daeng"],
				"text":
				"กลับไปเฝ้าสถานี ตำแหน่งเดิม เงินเดือนเดิม (ไม่มี) ... ซ่อนใต้เรือคว่ำเฉพาะวันหยุด",
			},
			{"text": 'ยังอยู่ใต้เรือคว่ำ น้ำกลับทิศแล้วก็ยังไม่ออกมา "เผื่อไว้"'},
		],
	},
	{
		"who": "kiao",
		"name": "เจ๊เกียว",
		"variants":
		[
			{
				"if": ["ally_kiao"],
				"text":
				'เผาสมุดหนี้ทั้งซอยในโอ่งมังกร ควันลอยไปถึงตึก ... เปลี่ยนป้ายร้าน "เงินด่วน" เป็น "ก๋วยเตี๋ยวด่วน" ดอกไม่ด่วนเหมือนเดิม',
			},
			{"text": 'เก็บสมุดหนี้ไว้ "เผื่อขายต่อ" ... ไม่มีใครซื้อ สมุดขึ้นรา เจ๊ขายราแทน'},
		],
	},
	{
		"who": "boy",
		"name": "น้องบอย",
		"variants":
		[
			{
				"if": ["boy_permit"],
				"text":
				'ติดป้าย "ระยะที่ 19: อพยพสำเร็จ" ได้ KPI เกินเป้า ... เขตให้งบเพิ่ม: งบป้าย',
			},
			{"text": 'ติดป้าย "ระยะที่ 18" ครบตามเป้า ... เขตให้งบเพิ่ม: งบป้าย'},
		],
	},
	{
		"who": "la_or",
		"name": "คุณหญิงลออ",
		"variants":
		[
			{
				"if": ["met_la_or"],
				"text":
				"ลิฟต์โผล่พ้นน้ำเป็นครั้งแรก กดลงไปชั้นใต้ดิน ... พบพุดเดิ้ลอีกสามตัวที่ไม่เคยรู้ว่ามี และของจากแอปอีกสี่ปี",
			},
			{
				"text":
				"ยังสั่งของจากแอปทุกวัน ... ไรเดอร์คนเดียวที่มาถึงยังมาถึง ตอนนี้ไม่ต้องว่ายน้ำ"
			},
		],
	},
	{
		"who": "prop:cat_som_o",
		"name": "แมวส้มโอ",
		"variants":
		[
			{
				"if": ["cat_lured"],
				"text":
				"ย้ายกองสมบัติลงมาที่ท่าเรือ (หลังคาแห้งแล้ว ไม่สนุก) ... ของในซอยยังหายทุกวัน แต่ตอนนี้ทุกคนรู้ว่าไปหาที่ไหน",
			},
			{"text": "ยังอยู่บนหลังคาสังกะสี กองสมบัติใหญ่ขึ้นทุกคืน ... ไม่มีใครรู้ว่ามีแมว"},
		],
	},
	{
		"who": "wan",
		"name": "คุณนายวรรณ",
		"variants":
		[
			{
				"text":
				"ยื่นใบลาออกพร้อมหลักฐานทั้งหมด ที่พิมพ์เอง ทุกชื่อ ทุกคืน ... บริษัทไม่รับใบลาออก เพราะไม่มีแผนกรับ เธอเลยไปนั่งที่บ้านเลขที่ 0 แทน",
			},
		],
	},
	{
		"who": "rider",
		"name": "ไรเดอร์",
		"variants":
		[
			{
				"text":
				'ยังติดหนี้ แต่ไม่มีใครรู้ว่าต้องจ่ายใคร ... ป้ายไม้ที่ท่าเรือเขียนว่า "ไรเดอร์ห้าดาว" และกล่องทองเหลืองที่ว่างแล้ว ใช้ใส่น้ำจิ้มไก่สี่สิบซอง',
			},
		],
	},
]


## Required flags not yet set: [{part, title, flag, label}], in plan order.
static func missing(flags: Dictionary) -> Array:
	var out: Array = []
	for part in PLAN:
		for f in part["flags"]:
			if not flags.get(f, false):
				out.append(
					{
						"part": part["id"],
						"title": part["title"],
						"flag": f,
						"label": part["flags"][f]
					}
				)
	return out


static func ready(flags: Dictionary) -> bool:
	return missing(flags).is_empty()


## Every flag the plan or the helpers name.
static func all_flags() -> Array:
	var out: Array = []
	for part in PLAN:
		out.append_array(part["flags"].keys())
	out.append_array(HELPERS.keys())
	return out


## Helper flags that are set.
static func helpers(flags: Dictionary) -> Array:
	var out: Array = []
	for f in HELPERS:
		if flags.get(f, false):
			out.append(f)
	return out


## The plan as a check list for the valve card.
static func checklist(flags: Dictionary) -> String:
	var lines: Array[String] = []
	for part in PLAN:
		var bits: Array[String] = []
		for f in part["flags"]:
			bits.append(("✓ " if flags.get(f, false) else "· ") + str(part["flags"][f]))
		lines.append("%s — %s" % [part["title"], " / ".join(bits)])
	var extra: Array[String] = []
	for f in helpers(flags):
		extra.append("✓ " + str(HELPERS[f]))
	if not extra.is_empty():
		lines.append("ช่วยอีก: " + ", ".join(extra))
	return "\n".join(lines)


## The epilogue cards for this play: [{who, name, text}].
static func epilogues(flags: Dictionary) -> Array:
	var out: Array = []
	for e in EPILOGUES:
		var text := ""
		for v in e["variants"]:
			if _passes(v, flags):
				text = str(v["text"])
				break
		if text.is_empty():
			continue
		out.append({"who": e["who"], "name": e["name"], "text": text})
	return out


static func _passes(v: Dictionary, flags: Dictionary) -> bool:
	for f in v.get("if", []):
		if not flags.get(f, false):
			return false
	for f in v.get("if_not", []):
		if flags.get(f, false):
			return false
	return true


## Boats that follow the rider in the convoy (DESIGN 12.8), front to back:
## {id, name, boat (prop art), who (character sheet), pose}. Who falls in
## when the convoy bumps = wet_<id>.
static func convoy(flags: Dictionary) -> Array:
	var out: Array = [
		{
			"id": "nok",
			"name": "เรือก๋วยเตี๋ยวป้านก",
			"boat": "boat_noodle_stall",
			"who": "pa_nok",
			"pose": "wai"
		},
		{"id": "nuad", "name": "พี่หนวด", "boat": "longtail_boat", "who": "nuad", "pose": ""},
		{"id": "jum", "name": "ป้าจุ๋ม", "boat": "longtail_boat", "who": "jum", "pose": "shout"},
		{"id": "ple", "name": "วินเรือพี่เปิ้ล", "boat": "longtail_boat", "who": "ple", "pose": ""},
		{"id": "berm", "name": "เรือไลฟ์พี่เบิ้ม", "boat": "live_boat", "who": "berm", "pose": ""},
		{
			"id": "monk",
			"name": "หลวงพี่น้ำ",
			"boat": "longtail_boat",
			"who": "luang_pee",
			"pose": ""
		},
	]
	if flags.get("ally_keng", false):
		out.append(
			{"id": "keng", "name": "น้องเก่ง", "boat": "longtail_boat", "who": "keng", "pose": ""}
		)
	if flags.get("ally_kiao", false):
		out.append(
			{"id": "kiao", "name": "เจ๊เกียว", "boat": "longtail_boat", "who": "kiao", "pose": ""}
		)
	if flags.get("ally_daeng", false):
		out.append(
			{
				"id": "daeng",
				"name": "ช่างแดง",
				"boat": "longtail_boat",
				"who": "chang_daeng",
				"pose": ""
			}
		)
	return out
