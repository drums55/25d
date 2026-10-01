extends GutTest
## Enemy and player HP rules (kept from the chapter-1 tests).

var _main: Node
var _player: Player


func before_each():
	GameState.delete_save()
	GameState.new_game()
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child_autofree(_main)
	await wait_physics_frames(3)
	_player = get_tree().get_first_node_in_group("player")


func after_each():
	GameState.delete_save()
	GameState.new_game()


func test_enemy_chases_hits_and_dies():
	SceneRouter.go_to("res://scenes/rooms/steam_market.tscn", "from_soi", false)
	await wait_physics_frames(5)
	var guard: Enemy = _player.get_parent().get_node("MarketGuard")
	assert_true(guard.alive)
	assert_true(guard.is_in_group("pickable"))
	await wait_physics_frames(10)
	assert_eq(GameState.hp, GameState.MAX_HP)
	_player.global_position = guard.global_position + Vector2(50, 0)
	await wait_physics_frames(30)
	assert_lt(GameState.hp, GameState.MAX_HP, "guard hit the player")
	var hp_after_first := GameState.hp
	await wait_physics_frames(6)
	assert_eq(GameState.hp, hp_after_first, "invulnerability window")
	for i in guard.max_hp:
		guard.take_hit(1, _player.global_position)
	assert_false(guard.alive)
	assert_false(guard.is_in_group("pickable"))
	assert_true(GameState.has_flag("market_guard_down"))
	var hp_dead := GameState.hp
	await wait_physics_frames(80)
	assert_eq(GameState.hp, hp_dead, "dead guard no longer hits")


func test_defeated_guard_stays_scrap_after_reload():
	GameState.set_flag("market_guard_down")
	SceneRouter.go_to("res://scenes/rooms/steam_market.tscn", "from_soi", false)
	await wait_physics_frames(5)
	var guard: Enemy = _player.get_parent().get_node("MarketGuard")
	assert_false(guard.alive)


func test_player_knocked_out_blacks_out_and_respawns():
	var room: IsoRoom = _player.get_parent().get_parent()
	_player.global_position = room.get_spawn_position("default") + Vector2(300, 0)
	for i in GameState.MAX_HP:
		_player._invuln = 0.0
		_player.take_hit(1, _player.global_position + Vector2(10, 0))
	assert_eq(GameState.hp, 0)
	assert_true(GameState.input_locked, "blackout locks input")
	await wait_seconds(2.5)
	assert_eq(GameState.hp, GameState.MAX_HP)
	assert_false(GameState.input_locked)
	assert_lt(_player.global_position.distance_to(room.get_spawn_position("default")), 1.0)


func test_garage_door_round_trip():
	var soi: IsoRoom = _player.get_parent().get_parent()
	var door := soi.get_world().get_node("DoorToGarage")
	SceneRouter.go_to(door.target_room, door.target_spawn, false)
	await wait_physics_frames(5)
	var garage: IsoRoom = _player.get_parent().get_parent()
	assert_eq(garage.room_title, "อู่ไอน้ำเฮียเป้ง")
	assert_eq(garage.get_world().get_node("DoorToSoi").target_spawn, "from_garage")
