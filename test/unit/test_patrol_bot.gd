extends GutTest
## PatrolBot (kept for P1 collectors / guards / dogs): vision cone, chase
## when carrying, catch costs time and spills food, fuse from behind, valve.

var _main: Node
var _player: Player
var _bot: PatrolBot


func before_each():
	TestHelpers.start_at("market")
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)
	_player = get_tree().get_first_node_in_group("player")
	_bot = (load("res://scenes/props/patrol_bot.tscn") as PackedScene).instantiate()
	_bot.bot_id = "test_bot"
	_bot.position = _player.position + Vector2(-260, -60)
	_player.get_parent().add_child(_bot)
	await wait_physics_frames(2)


func after_each():
	TestHelpers.finish_dialog()
	GameState.delete_save(0)
	GameState.new_game()


func _carry() -> void:
	(
		GameState
		. orders
		. append(
			{
				"id": 99,
				"kind": "food",
				"item": "ข้าว",
				"status": "picked",
				"size": 1,
				"pickup": 0,
				"dropoff": 1,
				"ready_at": GameState.minute,
				"deadline": GameState.minute + 60,
				"fee": 30,
				"tip": 0,
				"cod": 0,
				"customer": "คุณบี",
			}
		)
	)


func test_no_combat():
	assert_false(_player.has_method("take_hit"))
	assert_false(_bot.has_method("take_hit"))
	assert_true(_bot.is_in_group("pickable"))


func test_cone_front_not_back():
	_bot.facing = Vector2.RIGHT
	assert_true(_bot.in_cone(_bot.global_position + Vector2(120, 0)))
	assert_false(_bot.in_cone(_bot.global_position + Vector2(-120, 0)))


func test_seen_with_cargo_is_chased_and_caught():
	_carry()
	_bot.patrol = PackedVector2Array()
	_bot.facing = Vector2.RIGHT
	var minute := GameState.minute
	_player.global_position = _bot.global_position + Vector2(140, 0)
	await wait_physics_frames(2)
	assert_eq(_bot.state, PatrolBot.State.CHASE)
	await wait_physics_frames(40)
	assert_gte(GameState.minute, minute + 10.0, "inspection costs time")
	assert_true(Orders.get_order(99).get("spilled", false), "food knocked about")


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
