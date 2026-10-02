extends GutTest
## Save v5: slots, state round trip, old saves ignored.

const PATH := "user://test_save.json"


func after_each():
	GameState.delete_save(0, PATH)
	for slot in range(0, GameState.SAVE_SLOTS + 1):
		GameState.delete_save(slot)
	GameState.new_game()


func test_state_round_trips_through_a_slot():
	TestHelpers.start_in("pier")
	GameState.give_item("hanger")
	GameState.set_flag("radio_on")
	GameState.set_tide("high")
	GameState.chapter = 2
	assert_true(GameState.save_game(2))
	GameState.new_game()
	assert_true(GameState.load_game(2))
	assert_eq(GameState.room, "pier")
	assert_true(GameState.has_item("hanger"))
	assert_true(GameState.has_item("debt_book"), "start items kept")
	assert_true(GameState.has_flag("radio_on"))
	assert_eq(GameState.tide, "high")
	assert_eq(GameState.chapter, 2)
	var saves := GameState.list_saves()
	assert_eq(int(saves[2]["chapter"]), 2)
	assert_eq(GameState.latest_slot(), 2)


func test_old_and_corrupt_saves_are_ignored():
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 3, "room_path": "res://x.tscn"}))
	f.close()
	assert_null(SaveData.read(PATH), "saves from the rider-sim versions are ignored")
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_null(SaveData.read(PATH))
	assert_null(SaveData.read("user://nope.json"))


func test_settings_persist():
	var path := "user://test_settings.cfg"
	var old := Settings.text_speed
	Settings.text_speed = "เร็ว"
	Settings.save_settings(path)
	Settings.text_speed = "ปกติ"
	Settings.load_settings(path)
	assert_eq(Settings.text_speed, "เร็ว")
	assert_almost_eq(Settings.chars_per_second(), 90.0, 0.001)
	Settings.text_speed = old
	DirAccess.remove_absolute(path)
