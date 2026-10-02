extends GutTest
## Chapter 3's one ending (DESIGN 12.8): the valve waits for the whole plan
## (wake / carry / shelter / time), then the epilogue cards differ by the
## side plots and by who fell in the canal.


func _all_required() -> Dictionary:
	var flags := {}
	for part in Endings.PLAN:
		for f in part["flags"]:
			flags[f] = true
	return flags


func test_the_plan_lists_what_is_missing_in_order():
	var m := Endings.missing({})
	assert_eq(m.size(), 7, "two ways to wake, carry and shelter, one clock")
	assert_eq(m[0]["flag"], "ally_jum")
	assert_eq(m[0]["title"], "ปลุก")
	assert_eq(m[-1]["flag"], "forecast_rigged")
	assert_false(Endings.ready({}))
	assert_false(Endings.ready({"ally_jum": true, "ally_monk": true}))
	assert_true(Endings.ready(_all_required()))
	assert_eq(Endings.missing(_all_required()), [])


func test_helpers_are_optional():
	var flags := _all_required()
	assert_true(Endings.ready(flags), "no helper needed")
	assert_eq(Endings.helpers(flags), [])
	flags["ally_keng"] = true
	assert_eq(Endings.helpers(flags), ["ally_keng"])
	assert_string_contains(Endings.checklist(flags), "✓ น้องเก่ง")
	assert_string_contains(Endings.checklist({}), "· ป้าจุ๋ม")


func test_one_ending_with_a_card():
	assert_eq(Endings.ENDING, "five_stars")
	assert_true(Endings.TEXT.has(Endings.ENDING))
	assert_eq((Endings.TEXT[Endings.ENDING] as Array).size(), 2)
	assert_false(Endings.TEXT.has("sold"), "the box is not for sale any more")


func test_every_plan_flag_is_set_by_the_story():
	var text := FileAccess.get_file_as_string(Dialog.DIALOG_PATH)
	text += FileAccess.get_file_as_string(Puzzles.DATA_PATH)
	for f in Endings.all_flags():
		assert_string_contains(text, '"set_flag": "%s"' % f)


func test_epilogues_one_card_per_character_and_they_change():
	var dry := Endings.epilogues({})
	assert_eq(dry.size(), Endings.EPILOGUES.size(), "everyone gets a card")
	var wet := Endings.epilogues({"wet_jum": true, "ally_kiao": true, "ton_home": true})
	assert_eq(wet.size(), dry.size())
	assert_ne(wet[0]["text"], dry[0]["text"], "ป้าจุ๋ม fell in")
	for i in dry.size():
		var c: Dictionary = dry[i]
		assert_false(str(c["text"]).is_empty(), str(c["name"]))
		var who := str(c["who"])
		if who.begins_with("prop:"):
			assert_not_null(ArtLibrary.prop(who.trim_prefix("prop:")), who)
		else:
			assert_false(ArtLibrary.sprite_set(who).is_empty(), "%s has a sheet" % who)


func test_every_wet_flag_names_a_convoy_boat():
	var ids := {}
	for b in Endings.convoy({"ally_keng": true, "ally_kiao": true, "ally_daeng": true}):
		ids[b["id"]] = true
		assert_not_null(ArtLibrary.prop(b["boat"]), str(b["boat"]))
		assert_false(ArtLibrary.sprite_set(b["who"]).is_empty(), str(b["who"]))
	assert_eq(Endings.convoy({}).size(), 6, "the required boats always come")
	for e in Endings.EPILOGUES:
		for v in e["variants"]:
			for f in v.get("if", []):
				if str(f).begins_with("wet_"):
					assert_true(ids.has(str(f).trim_prefix("wet_")), str(f))
