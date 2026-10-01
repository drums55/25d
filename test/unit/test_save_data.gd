extends GutTest
## Save v5: slots, state round trip, old saves ignored.

const PATH := "user://test_save.json"


func after_each():
	GameState.delete_save(0, PATH)
	for slot in range(0, GameState.SAVE_SLOTS + 1):
		GameState.delete_save(slot)
	GameState.new_game()


func test_state_round_trips_through_a_slot():
	TestHelpers.start_at("market")
	GameState.money = 777
	GameState.debt = 1500
	GameState.fuel = 1.5
	GameState.add_rating(1)
	Orders.rng.seed = 1
	Orders.tick(GameState.minute + 30)
	var order_count := GameState.orders.size()
	var where := GameState.location
	assert_true(GameState.save_game(2))
	GameState.new_game()
	assert_true(GameState.load_game(2))
	assert_eq(GameState.money, 777)
	assert_eq(GameState.debt, 1500)
	assert_almost_eq(GameState.fuel, 1.5, 0.001)
	assert_eq(GameState.location, where)
	assert_eq(GameState.city_seed, TestHelpers.SEED)
	assert_eq(GameState.orders.size(), order_count)
	assert_eq(GameState.ratings[-1], 1.0)
	var saves := GameState.list_saves()
	assert_true(saves.has(2))
	assert_eq(int(saves[2]["money"]), 777)
	assert_eq(GameState.latest_slot(), 2)


func test_old_and_corrupt_saves_are_ignored():
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 3, "room_path": "res://x.tscn"}))
	f.close()
	assert_null(SaveData.read(PATH), "pre-v5 save is the old game")
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_null(SaveData.read(PATH))
	assert_null(SaveData.read("user://nope.json"))


func test_settings_persist():
	var path := "user://test_settings.cfg"
	var old := Settings.clock_speed
	Settings.clock_speed = "เร็ว"
	Settings.save_settings(path)
	Settings.clock_speed = "ปกติ"
	Settings.load_settings(path)
	assert_eq(Settings.clock_speed, "เร็ว")
	assert_almost_eq(Settings.seconds_per_minute(), 1.2, 0.001)
	Settings.clock_speed = old
	DirAccess.remove_absolute(path)
