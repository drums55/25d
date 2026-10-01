extends GutTest

const PATH := "user://test_save.json"


func after_each():
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_dict_round_trip():
	var s := SaveData.new()
	s.room_path = "res://scenes/rooms/steam_market.tscn"
	s.spawn_id = "from_soi"
	s.flags = {"met_pradit": true}
	var back := SaveData.from_dict(s.to_dict())
	assert_eq(back.room_path, s.room_path)
	assert_eq(back.spawn_id, s.spawn_id)
	assert_eq(back.flags, s.flags)


func test_from_dict_defaults_on_missing_or_bad_fields():
	var s := SaveData.from_dict({"flags": "not a dict"})
	assert_eq(s.room_path, "")
	assert_eq(s.spawn_id, "default")
	assert_eq(s.flags, {})


func test_file_round_trip():
	var s := SaveData.new()
	s.room_path = "res://x.tscn"
	s.flags = {"a": true}
	assert_eq(s.write(PATH), OK)
	var back := SaveData.read(PATH)
	assert_not_null(back)
	assert_eq(back.room_path, "res://x.tscn")
	assert_eq(back.flags, {"a": true})


func test_read_missing_or_corrupt_returns_null():
	assert_null(SaveData.read("user://does_not_exist.json"))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_null(SaveData.read(PATH))


func test_game_state_save_load_and_bad_room_fallback():
	GameState.new_game()
	GameState.set_flag("met_pradit")
	GameState.room_path = "res://scenes/rooms/steam_market.tscn"
	GameState.spawn_id = "from_soi"
	assert_true(GameState.save_game(PATH))
	GameState.new_game()
	assert_false(GameState.has_flag("met_pradit"))
	assert_true(GameState.load_game(PATH))
	assert_true(GameState.has_flag("met_pradit"))
	assert_eq(GameState.room_path, "res://scenes/rooms/steam_market.tscn")
	assert_eq(GameState.spawn_id, "from_soi")
	# A save pointing at a deleted room falls back to the start room.
	var s := SaveData.new()
	s.room_path = "res://scenes/rooms/gone.tscn"
	s.write(PATH)
	GameState.load_game(PATH)
	assert_eq(GameState.room_path, GameState.START_ROOM)
	GameState.new_game()
