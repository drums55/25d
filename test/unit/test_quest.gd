extends GutTest
## Job loop B: rent debt -> job from Lung Pradit -> pick up at Je Muay ->
## market guard fight -> deliver for money. Enemy and player HP rules.

const ENEMY := preload("res://scenes/props/enemy.tscn")

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


func _talk(npc_path: String) -> void:
	var npc: Node2D = _player.get_parent().get_node(npc_path)
	_player.click_at(npc.global_position + Vector2(0, -100))
	await wait_physics_frames(120)
	assert_true(Dialog.is_active(), "dialog with %s started" % npc_path)
	for i in 20:
		Dialog.typing = false
		Dialog.advance()


func test_full_job_loop():
	await _talk("LungPradit")
	assert_true(GameState.has_flag("job1_accepted"))
	assert_false(GameState.has_item("brass_gear"))
	SceneRouter.go_to("res://scenes/rooms/steam_market.tscn", "from_soi", false)
	await wait_physics_frames(5)
	await _talk("JeMuay")
	assert_true(GameState.has_item("brass_gear"))
	assert_true(GameState.has_flag("job1_pickup"))
	await _talk("JeMuay")
	assert_eq(GameState.inventory.size(), 1, "second talk does not duplicate the gear")
	SceneRouter.go_to(GameState.START_ROOM, "from_market", false)
	await wait_physics_frames(5)
	await _talk("LungPradit")
	assert_false(GameState.has_item("brass_gear"))
	assert_eq(GameState.money, 80)
	assert_true(GameState.has_flag("job1_done"))
	# progress survives save/load
	assert_true(GameState.save_game())
	GameState.new_game()
	assert_true(GameState.load_game())
	assert_eq(GameState.money, 80)
	assert_true(GameState.has_flag("job1_done"))


func test_enemy_chases_hits_and_dies():
	SceneRouter.go_to("res://scenes/rooms/steam_market.tscn", "from_soi", false)
	await wait_physics_frames(5)
	var guard: Enemy = _player.get_parent().get_node("MarketGuard")
	assert_true(guard.alive)
	assert_true(guard.is_in_group("pickable"))
	# far away: idle
	await wait_physics_frames(10)
	assert_eq(GameState.hp, GameState.MAX_HP)
	# stand next to it: it hits, player loses hp but never below 0
	_player.global_position = guard.global_position + Vector2(50, 0)
	await wait_physics_frames(30)
	assert_lt(GameState.hp, GameState.MAX_HP, "guard hit the player")
	var hp_after_first := GameState.hp
	await wait_physics_frames(6)
	assert_eq(GameState.hp, hp_after_first, "invulnerability window")
	# player kills it with max_hp hits
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


func test_player_knocked_out_respawns_with_full_hp():
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


func _go(room: String, spawn: String) -> void:
	SceneRouter.go_to(room, spawn, false)
	await wait_physics_frames(5)


func test_jobs_2_and_3_clear_the_rent():
	GameState.set_flag("job1_done")
	GameState.set_flag("job1_accepted")
	GameState.set_flag("job1_pickup")
	GameState.set_flag("market_guard_down")
	GameState.set_flag("garage_bot_down")
	GameState.money = 80
	await _go("res://scenes/rooms/steam_market.tscn", "from_soi")
	await _talk("JeMuay")
	assert_true(GameState.has_item("parts_box"))
	assert_true(GameState.has_flag("job2_accepted"))
	await _go("res://scenes/rooms/steam_garage.tscn", "from_soi")
	await _talk("HiaPeng")
	assert_false(GameState.has_item("parts_box"))
	assert_eq(GameState.money, 180)
	assert_true(GameState.has_flag("job3_accepted"))
	await _go("res://scenes/rooms/steam_market.tscn", "from_soi")
	await _talk("Boiler")
	assert_true(GameState.has_item("pressure_valve"))
	await _go("res://scenes/rooms/steam_garage.tscn", "from_soi")
	await _talk("HiaPeng")
	assert_eq(GameState.money, 300)
	assert_true(GameState.has_flag("job3_done"))
	assert_false(GameState.has_flag("rent_paid"), "paying is a separate talk")
	await _talk("HiaPeng")
	assert_eq(GameState.money, 0)
	assert_true(GameState.has_flag("rent_paid"))
	await _talk("HiaPeng")
	assert_eq(GameState.money, 0, "no double charge")


func test_garage_door_round_trip():
	var soi: IsoRoom = _player.get_parent().get_parent()
	var door := soi.get_world().get_node("DoorToGarage")
	assert_eq(door.target_room, "res://scenes/rooms/steam_garage.tscn")
	await _go(door.target_room, door.target_spawn)
	var garage: IsoRoom = _player.get_parent().get_parent()
	assert_eq(garage.room_title, "อู่ไอน้ำเฮียเป้ง")
	assert_not_null(garage.get_node("Navigation"))
	var back := garage.get_world().get_node("DoorToSoi")
	assert_eq(back.target_spawn, "from_garage")
