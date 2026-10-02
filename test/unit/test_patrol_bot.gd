extends GutTest
## PatrolBot as a living gate (DESIGN 12.3): a zone on the floor instead of a
## vision cone, caught = words + push + the held item seized to เจ๊เกียว's
## raft, distraction flag, robots face the rider and turn to a noise, fuse
## from behind only.

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
	_bot.catch_dialog = "catch_nuad"
	_bot.position = Iso.grid_to_world(Vector2(6.5, 2.5))  # open deck
	_player.get_parent().add_child(_bot)
	await wait_physics_frames(2)


func after_each():
	TestHelpers.finish_dialog()
	GameState.delete_save(0)
	GameState.new_game()


func test_no_combat_no_cone():
	assert_false(_player.has_method("take_hit"))
	assert_false(_bot.has_method("can_see"), "no vision cone any more")
	assert_true(_bot.is_in_group("pickable"))


func test_zone_all_around_for_people():
	_bot.zone_angle_deg = 360.0
	_bot.facing = Vector2.RIGHT
	assert_true(_bot.in_zone(_bot.global_position + Vector2(120, 0)))
	assert_true(_bot.in_zone(_bot.global_position + Vector2(-120, 0)))
	assert_false(_bot.in_zone(_bot.global_position + Vector2(400, 0)))


func test_zone_in_front_for_robots():
	_bot.zone_angle_deg = 200.0
	_bot.facing = Vector2.RIGHT
	assert_true(_bot.in_zone(_bot.global_position + Vector2(120, 0)))
	assert_false(_bot.in_zone(_bot.global_position + Vector2(-120, 0)), "its back is free")


func test_walking_into_the_zone_is_caught():
	watch_signals(_bot)
	_player.global_position = _bot.global_position + Vector2(100, 0)
	await wait_physics_frames(3)
	assert_signal_emitted(_bot, "caught_player")
	assert_true(Dialog.is_active(), "the collector has words")
	assert_gt(_player.global_position.distance_to(_bot.global_position), 100.0, "pushed back")


func test_the_zone_stays_solid_while_it_calms_down():
	# owner 2026-10-02: "มีหุ่นนะ แต่ไขประตูแล้วเข้าได้" — one could be caught,
	# then walk through during the calm seconds
	_player.global_position = _bot.global_position + Vector2(100, 0)
	await wait_physics_frames(3)
	TestHelpers.finish_dialog()
	assert_false(_bot.in_zone(_player.global_position), "shoved right out of the zone")
	_player.global_position = _bot.global_position + Vector2(60, 0)
	_player.order = Player.Order.MOVE
	await wait_physics_frames(3)
	assert_false(Dialog.is_active(), "no second speech while calming down")
	assert_false(_bot.in_zone(_player.global_position), "but still no way through")
	assert_eq(_player.order, Player.Order.NONE)


func test_caught_with_an_item_held_seizes_it_to_the_raft():
	GameState.give_item("hanger")
	GameState.held_item = "hanger"
	_player.global_position = _bot.global_position + Vector2(100, 0)
	await wait_physics_frames(3)
	assert_false(GameState.has_item("hanger"), "taken for the debt")
	assert_eq(GameState.held_item, "")
	assert_true(GameState.has_flag("seized_hanger"))
	assert_true(GameState.has_flag("know_kiao"), "the raft is on the map now")


func test_seized_item_waits_on_the_raft():
	GameState.set_flag("seized_hanger")
	GameState.set_flag("know_kiao")
	_main.go_room("kiao_raft", "default")
	await wait_seconds(0.8)
	TestHelpers.finish_dialog()
	var spot: Interactable = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Interactable and n.pickup_item == "hanger":
			spot = n
	assert_not_null(spot, "the hanger lies on the raft")
	spot.interact(_player)
	TestHelpers.finish_dialog()
	assert_true(GameState.has_item("hanger"))
	assert_false(GameState.has_flag("seized_hanger"))


func test_distract_flag_stops_it():
	_bot.distract_flag = "radio_on"
	GameState.set_flag("radio_on")
	assert_eq(_bot.state, PatrolBot.State.OFF)
	watch_signals(_bot)
	_player.global_position = _bot.global_position + Vector2(100, 0)
	await wait_physics_frames(5)
	assert_signal_not_emitted(_bot, "caught_player", "dancing, does not catch")


func test_robot_faces_the_rider_until_a_noise():
	_bot.tracks_player = true
	_bot.turns_to_noise = true
	_bot.noise_dir = Vector2(-1, 0)
	_bot.zone_angle_deg = 200.0
	_player.global_position = _bot.global_position + Vector2(300, 0)
	await wait_physics_frames(2)
	assert_gt(_bot.facing.x, 0.9, "turned to the rider")
	Dialog.start_lines([{"text": "ปัง!", "event": "noise"}], "t")
	TestHelpers.finish_dialog()
	await wait_physics_frames(2)
	assert_lt(_bot.facing.x, -0.9, "turned to the noise and stays")


func test_tamper_from_behind_switches_off():
	_bot.facing = Vector2.RIGHT
	_bot.zone_angle_deg = 200.0
	_player.global_position = _bot.global_position + Vector2(-70, 0)
	_bot.tamper(_player)
	assert_eq(_bot.state, PatrolBot.State.OFF)
	assert_true(GameState.has_flag(_bot.off_flag()))
	assert_true(GameState.has_flag("test_bot_fused"))


func test_tamper_from_the_front_is_caught():
	_bot.facing = Vector2.RIGHT
	_bot.zone_angle_deg = 200.0
	watch_signals(_bot)
	_player.global_position = _bot.global_position + Vector2(70, 0)
	_bot.tamper(_player)
	assert_ne(_bot.state, PatrolBot.State.OFF)
	assert_signal_emitted(_bot, "caught_player")
