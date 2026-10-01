extends GutTest
## Job board rules (M1): availability, cargo limit, pickup/dropoff via npc
## ids, lateness, day clock, sleeping fails undelivered jobs, save v3.

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
	_finish_dialog()
	GameState.delete_save()
	GameState.new_game()


func _finish_dialog() -> void:
	for i in 20:
		Dialog.typing = false
		Dialog.advance()


func test_jobs_file_loads_and_day1_offers_are_gated_by_flags():
	assert_gt(Jobs.all_ids().size(), 4)
	var ids: Array[String] = []
	for job in Jobs.available():
		ids.append(job["id"])
	assert_has(ids, "gear_for_lung")
	assert_has(ids, "noodles_for_hia")
	assert_has(ids, "parts_box")
	assert_does_not_have(ids, "pressure_valve", "needs job2_done")
	GameState.set_flag("job2_done")
	ids.clear()
	for job in Jobs.available():
		ids.append(job["id"])
	assert_has(ids, "pressure_valve")


func test_accept_respects_cargo_slots():
	assert_eq(Jobs.cargo_free(), 2)
	assert_true(Jobs.accept("gear_for_lung"))
	assert_true(Jobs.accept("noodles_for_hia"))
	assert_false(Jobs.accept("parts_box"), "cargo full")
	assert_false(Jobs.accept("gear_for_lung"), "already active")
	assert_eq(Jobs.cargo_free(), 0)
	assert_does_not_have(Jobs.available().map(func(j): return j["id"]), "gear_for_lung")


func test_pickup_and_dropoff_by_npc_id_pay_on_time():
	assert_true(Jobs.accept("gear_for_lung"))
	assert_false(Jobs.on_interact("lung_pradit"), "nothing to drop yet, falls to dialog")
	assert_true(Jobs.on_interact("je_muay"))
	assert_true(GameState.has_item("brass_gear"))
	assert_true(Dialog.is_active(), "pickup lines play")
	_finish_dialog()
	assert_true(Jobs.on_interact("lung_pradit"))
	assert_false(GameState.has_item("brass_gear"))
	assert_eq(GameState.money, 80)
	assert_true(GameState.has_flag("job1_done"))
	assert_has(GameState.done_jobs, "gear_for_lung")
	assert_eq(GameState.tick, GameState.DELIVERY_TICKS, "delivery costs time")


func test_late_delivery_pays_less():
	assert_true(Jobs.accept("noodles_for_hia"))
	Jobs.on_interact("lung_pradit")
	_finish_dialog()
	GameState.advance_time(2 * GameState.TICKS_PER_SLOT + 1)
	assert_true(Jobs.on_interact("hia_peng"))
	assert_eq(GameState.money, 10, "late reward")


func test_room_change_costs_a_tick_and_night_comes():
	assert_eq(GameState.tick, 0)
	SceneRouter.go_to("res://scenes/rooms/steam_market.tscn", "from_soi", false)
	await wait_physics_frames(5)
	assert_eq(GameState.tick, 1)
	SceneRouter.go_to("res://scenes/rooms/steam_market.tscn", "default", false)
	await wait_physics_frames(5)
	assert_eq(GameState.tick, 1, "same room again is free")
	GameState.advance_time(GameState.DAY_TICKS)
	assert_true(GameState.is_night())
	assert_eq(GameState.slot_name(), "ค่ำ")


func test_sleep_fails_undelivered_jobs_and_starts_new_day():
	Jobs.accept("gear_for_lung")
	Jobs.on_interact("je_muay")
	_finish_dialog()
	GameState.hp = 2
	Jobs.sleep()
	assert_eq(GameState.day, 2)
	assert_eq(GameState.tick, 0)
	assert_eq(GameState.hp, GameState.MAX_HP)
	assert_eq(GameState.active_jobs.size(), 0)
	assert_has(GameState.failed_jobs, "gear_for_lung")
	assert_false(GameState.has_item("brass_gear"), "undelivered item is gone")
	assert_has(
		Jobs.available().map(func(j): return j["id"]), "gear_for_lung", "offered again next day"
	)


func test_save_round_trip_keeps_jobs_and_clock():
	Jobs.accept("parts_box")
	Jobs.on_interact("je_muay")
	_finish_dialog()
	GameState.advance_time(3)
	assert_true(GameState.save_game())
	GameState.new_game()
	assert_true(GameState.load_game())
	assert_eq(GameState.tick, 3)
	assert_eq(GameState.active_jobs.size(), 1)
	assert_true(Jobs.active_jobs()[0]["picked"])
	assert_true(GameState.has_item("parts_box"))


func test_board_prop_opens_ui_and_rent_pays_with_money_condition():
	var board := _player.get_parent().get_node("JobBoard/Interactable") as Interactable
	assert_true(board.opens_job_board)
	board.interact(_player)
	var ui: JobBoard = _main.get_node("HUD").get_node("%JobBoard")
	assert_true(ui.visible)
	assert_true(GameState.input_locked)
	ui.close()
	assert_false(GameState.input_locked)
	GameState.money = 299
	assert_true(Dialog.start("hia_peng"))
	_finish_dialog()
	assert_false(GameState.has_flag("rent_paid"))
	GameState.money = 300
	assert_true(Dialog.start("hia_peng"))
	_finish_dialog()
	assert_true(GameState.has_flag("rent_paid"))
	assert_eq(GameState.money, 0)


func _ids(jobs: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for job in jobs:
		out.append(str(job["id"]))
	return out


func test_from_day_gates_offers():
	assert_does_not_have(_ids(Jobs.available()), "croc_egg", "day 2 job")
	GameState.new_day()
	assert_has(_ids(Jobs.available()), "croc_egg")


func test_fragile_cargo_breaks_when_player_is_hit():
	assert_true(Jobs.accept("eggs_for_lung"))
	_player.take_hit(1, _player.global_position + Vector2(50, 0))
	assert_true(Jobs.is_active("eggs_for_lung"), "not picked yet: nothing to break")
	assert_true(Jobs.on_interact("je_muay"))
	_finish_dialog()
	await wait_seconds(1.0)  # invulnerability window
	_player.take_hit(1, _player.global_position + Vector2(50, 0))
	assert_false(Jobs.is_active("eggs_for_lung"), "eggs broke")
	assert_false(GameState.has_item("eggs"))
	assert_has(GameState.failed_jobs, "eggs_for_lung")


func test_redirect_chain_moves_the_receiver():
	assert_true(Jobs.accept("parcel_somchai"))
	Jobs.on_interact("boatman")
	_finish_dialog()
	assert_true(Jobs.on_interact("lung_pradit"), "lung redirects")
	_finish_dialog()
	assert_true(GameState.has_item("somchai_parcel"), "still carrying")
	assert_eq(Jobs.active_jobs()[0]["target_where"], "ตลาดไอน้ำ (ถามเจ๊หมวย)")
	assert_false(Jobs.on_interact("lung_pradit"), "lung is no longer the receiver")
	assert_true(Jobs.on_interact("je_muay"))
	_finish_dialog()
	assert_true(Jobs.on_interact("hia_peng"), "delivered to the real Somchai")
	assert_has(GameState.done_jobs, "parcel_somchai")
	assert_eq(GameState.money, 70)


func test_needs_blocks_delivery_until_item_found():
	GameState.new_day()
	assert_true(Jobs.accept("cake_for_boiler"))
	Jobs.on_interact("lung_pradit")
	_finish_dialog()
	assert_true(Jobs.on_interact("market_boiler"), "refusal plays")
	_finish_dialog()
	assert_true(Jobs.is_active("cake_for_boiler"), "no candle, no delivery")
	var data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/dialog/dialog.json")
	)
	var lines := DialogData.resolve(data, "spirit_house", GameState.flags, GameState.inventory)
	assert_eq(lines[-1].get("give_item", ""), "incense", "shrine hands out incense")
	GameState.give_item("incense")
	assert_true(Jobs.on_interact("market_boiler"))
	assert_has(GameState.done_jobs, "cake_for_boiler")
	assert_false(GameState.has_item("incense"), "incense used up")


func test_reputation_moves_with_jobs_and_tips_pay():
	assert_true(Jobs.accept("gear_for_lung"))
	Jobs.on_interact("je_muay")
	_finish_dialog()
	Jobs.on_interact("lung_pradit")
	assert_eq(GameState.get_rep("folk"), 1, "folk employer +1 on time")
	assert_eq(GameState.money, 80, "no tip at rep 0")
	_finish_dialog()
	# company job pays well but costs the folk
	assert_true(Jobs.accept("meter_for_boiler"))
	Jobs.on_interact("khun_wan")
	_finish_dialog()
	Jobs.on_interact("market_boiler")
	_finish_dialog()
	assert_eq(GameState.get_rep("company"), 1)
	assert_eq(GameState.get_rep("folk"), -1)
	assert_eq(GameState.money, 80 + 150)
	# folk tip: rep 2 -> +20
	GameState.add_rep("folk", 3)
	assert_eq(Jobs.tip(Jobs.get_job("mackerel_for_lung")), 20)


func test_failed_job_costs_employer_rep_and_rep_gates_offers():
	assert_does_not_have(_ids(Jobs.available()), "notice_for_lung", "needs company 1")
	assert_true(Jobs.accept("parts_box"))
	Jobs.abandon("parts_box")
	assert_eq(GameState.get_rep("garage"), -1)
	GameState.add_rep("company", 1)
	assert_has(_ids(Jobs.available()), "notice_for_lung")


func test_reputation_saved():
	GameState.add_rep("company", -3)
	GameState.save_game()
	GameState.new_game()
	assert_eq(GameState.get_rep("company"), 0)
	assert_true(GameState.load_game())
	assert_eq(GameState.get_rep("company"), -3)


func test_rep_branches_dialog_and_discounts_rent():
	var data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/dialog/dialog.json")
	)
	var f := {}
	var lines := DialogData.resolve(data, "hia_peng", f, [], 260, {"garage": 3})
	assert_eq(int(lines[1].get("money", 0)), -250, "garage friends pay 250")
	lines = DialogData.resolve(data, "hia_peng", f, [], 260, {"garage": 0})
	assert_ne(int(lines[1].get("money", 0)), -250, "others still owe 300")
	lines = DialogData.resolve(data, "khun_wan", {"met_wan": true}, [], 0, {"company": -2})
	assert_string_contains(lines[0]["text"], "รอยฟัน", "Wan remembers the cat bite")
