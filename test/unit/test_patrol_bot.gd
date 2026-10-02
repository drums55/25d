extends GutTest
## PatrolBot (debt collectors / collector robots): vision cone, chase, catch
## dialog + push, distraction flag, fuse from behind, valve.

var _main: Node
var _player: Player
var _bot: PatrolBot


func before_each():
	TestHelpers.start_in("noodle_boat")
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)
	_player = get_tree().get_first_node_in_group("player")
	_bot = (load("res://scenes/props/patrol_bot.tscn") as PackedScene).instantiate()
	_bot.bot_id = "test_bot"
	_bot.position = Iso.grid_to_world(Vector2(6.5, 2.5))  # open deck
	_player.get_parent().add_child(_bot)
	await wait_physics_frames(2)


func after_each():
	TestHelpers.finish_dialog()
	GameState.delete_save(0)
	GameState.new_game()


func test_no_combat():
	assert_false(_player.has_method("take_hit"))
	assert_false(_bot.has_method("take_hit"))
	assert_true(_bot.is_in_group("pickable"))


func test_cone_front_not_back():
	_bot.facing = Vector2.RIGHT
	assert_true(_bot.in_cone(_bot.global_position + Vector2(120, 0)))
	assert_false(_bot.in_cone(_bot.global_position + Vector2(-120, 0)))


func test_seen_is_chased_and_caught():
	_bot.patrol = PackedVector2Array()
	_bot.facing = Vector2.RIGHT
	_bot.catch_dialog = "catch_nuad"
	watch_signals(_bot)
	_player.global_position = _bot.global_position + Vector2(140, 0)
	await wait_physics_frames(2)
	assert_eq(_bot.state, PatrolBot.State.CHASE)
	await wait_physics_frames(40)
	assert_signal_emitted(_bot, "caught_player")
	assert_true(Dialog.is_active(), "the collector has words")


func test_distract_flag_stops_it():
	_bot.distract_flag = "radio_on"
	GameState.set_flag("radio_on")
	assert_eq(_bot.state, PatrolBot.State.OFF)
	_player.global_position = _bot.global_position + Vector2(140, 0)
	_bot.facing = Vector2.RIGHT
	await wait_physics_frames(5)
	assert_eq(_bot.state, PatrolBot.State.OFF, "dancing, does not chase")


func test_tamper_from_behind_switches_off():
	_bot.facing = Vector2.RIGHT
	_player.global_position = _bot.global_position + Vector2(-70, 0)
	_bot.tamper(_player)
	assert_eq(_bot.state, PatrolBot.State.OFF)
	assert_true(GameState.has_flag(_bot.off_flag()))


func test_tamper_from_front_is_noticed():
	_bot.facing = Vector2.RIGHT
	_player.global_position = _bot.global_position + Vector2(70, 0)
	_bot.tamper(_player)
	assert_ne(_bot.state, PatrolBot.State.OFF)


func test_valve_event_freezes():
	Dialog.start_lines([{"text": "ฟู่", "event": "steam_valve"}], "t")
	assert_eq(_bot.state, PatrolBot.State.STUNNED)
