extends GutTest
## Patrol bots (M2): no combat. Seen with cargo -> chased and "inspected";
## from behind -> fuse pulled for the day; steam valve -> frozen.

var _main: Node
var _player: Player


func before_each():
	GameState.delete_save()
	GameState.new_game()
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)
	_player = get_tree().get_first_node_in_group("player")
	SceneRouter.go_to("res://scenes/rooms/steam_market.tscn", "from_soi", false)
	await wait_physics_frames(5)


func after_each():
	for i in 20:
		Dialog.typing = false
		Dialog.advance()
	GameState.delete_save()
	GameState.new_game()


func _guard() -> PatrolBot:
	return _player.get_parent().get_node("MarketGuard")


func _carry() -> void:
	assert_true(Jobs.accept("parts_box"))
	Jobs.on_interact("je_muay")
	for i in 10:
		Dialog.typing = false
		Dialog.advance()


func test_no_combat_left():
	assert_false(_player.has_method("take_hit"))
	assert_false(_guard().has_method("take_hit"))
	assert_true(_guard().is_in_group("pickable"), "tap it to tamper")


func test_cone_sees_front_not_back():
	var g := _guard()
	g.state = PatrolBot.State.WAIT
	g.facing = Vector2.RIGHT
	assert_true(g.in_cone(g.global_position + Vector2(120, 0)))
	assert_false(g.in_cone(g.global_position + Vector2(-120, 0)))


func test_seen_with_cargo_is_chased_and_inspected():
	_carry()
	var g := _guard()
	var tick := GameState.tick
	g.patrol = PackedVector2Array()
	g.facing = Vector2.RIGHT
	_player.global_position = g.global_position + Vector2(140, 0)
	await wait_physics_frames(2)
	assert_eq(g.state, PatrolBot.State.CHASE)
	await wait_physics_frames(40)
	assert_gt(GameState.tick, tick, "inspection costs time")
	assert_gt(_player.global_position.distance_to(g.global_position), PatrolBot.CATCH_RANGE)


func test_without_cargo_it_only_stares():
	var g := _guard()
	g.patrol = PackedVector2Array()
	g.facing = Vector2.RIGHT
	var tick := GameState.tick
	_player.global_position = g.global_position + Vector2(140, 0)
	await wait_physics_frames(3)
	assert_eq(g.state, PatrolBot.State.STARE)
	await wait_physics_frames(30)
	assert_eq(GameState.tick, tick)


func test_tamper_from_behind_switches_off_for_the_day():
	var g := _guard()
	g.facing = Vector2.RIGHT
	_player.global_position = g.global_position + Vector2(-70, 0)
	g.tamper(_player)
	assert_eq(g.state, PatrolBot.State.OFF)
	assert_true(GameState.has_flag(g.off_flag()))
	assert_eq(GameState.money, 20, "fuse sold, first time only")
	assert_eq(GameState.get_rep("folk"), 1)


func test_tamper_from_front_is_noticed():
	var g := _guard()
	g.facing = Vector2.RIGHT
	_player.global_position = g.global_position + Vector2(70, 0)
	g.tamper(_player)
	assert_ne(g.state, PatrolBot.State.OFF)


func test_off_bot_stays_off_on_reload_but_wakes_next_day():
	GameState.set_flag("market_guard_off_d1")
	SceneRouter.go_to("res://scenes/rooms/steam_market.tscn", "from_soi", false)
	await wait_physics_frames(5)
	assert_eq(_guard().state, PatrolBot.State.OFF)
	GameState.new_day()
	SceneRouter.go_to("res://scenes/rooms/steam_market.tscn", "from_soi", false)
	await wait_physics_frames(5)
	assert_ne(_guard().state, PatrolBot.State.OFF)


func test_steam_valve_freezes_bot():
	var g := _guard()
	assert_true(Dialog.start("steam_valve"))
	for i in 5:
		Dialog.typing = false
		Dialog.advance()
	assert_eq(g.state, PatrolBot.State.STUNNED)


func test_garage_door_round_trip():
	SceneRouter.go_to("res://scenes/rooms/soi_brass.tscn", "from_market", false)
	await wait_physics_frames(5)
	var soi: IsoRoom = _player.get_parent().get_parent()
	var door := soi.get_world().get_node("DoorToGarage")
	SceneRouter.go_to(door.target_room, door.target_spawn, false)
	await wait_physics_frames(5)
	var garage: IsoRoom = _player.get_parent().get_parent()
	assert_eq(garage.room_title, "อู่ไอน้ำเฮียเป้ง")
	assert_true(garage.get_world().get_node("GarageBot") is PatrolBot)
