extends GutTest
## Chapter 3's endings (DESIGN 11.8): which ending the valve gives for how
## many of the soi's people are on side.


func test_allies_are_the_set_flags():
	assert_eq(Endings.allies({}), [])
	assert_eq(Endings.allies({"ally_jum": true, "ally_nok": false, "x": true}), ["ally_jum"])


func test_valve_ending_by_allies():
	assert_eq(Endings.for_valve(0), "sunk")
	assert_eq(Endings.for_valve(Endings.OKAY - 1), "sunk")
	assert_eq(Endings.for_valve(Endings.OKAY), "wet")
	assert_eq(Endings.for_valve(Endings.BEST - 1), "wet")
	assert_eq(Endings.for_valve(Endings.ALLIES.size()), "five_stars")


func test_every_ending_has_a_card():
	for id in ["sold", "sunk", "wet", "five_stars"]:
		assert_true(Endings.TEXT.has(id), id)
		assert_eq((Endings.TEXT[id] as Array).size(), 2)


func test_every_ally_flag_is_set_by_the_story():
	var text := FileAccess.get_file_as_string(Dialog.DIALOG_PATH)
	text += FileAccess.get_file_as_string(Puzzles.DATA_PATH)
	for f in Endings.ALLIES:
		assert_string_contains(text, '"set_flag": "%s"' % f)
