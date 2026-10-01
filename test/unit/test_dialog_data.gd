extends GutTest

const DATA := {
	"plain": [{"speaker": "A", "text": "hi"}, "bare string"],
	"gated": {"if_flag": "met", "lines": [{"speaker": "A", "text": "again"}], "else": "plain"},
	"loop_a": {"if_flag": "x", "lines": [], "else": "loop_b"},
	"loop_b": {"if_flag": "x", "lines": [], "else": "loop_a"},
}


func test_plain_dialog_normalizes_lines():
	var lines := DialogData.resolve(DATA, "plain", {})
	assert_eq(lines.size(), 2)
	assert_eq(lines[0]["speaker"], "A")
	assert_eq(lines[1]["speaker"], "")
	assert_eq(lines[1]["text"], "bare string")


func test_flag_gate_picks_branch():
	assert_eq(DialogData.resolve(DATA, "gated", {})[0]["text"], "hi")
	assert_eq(DialogData.resolve(DATA, "gated", {"met": true})[0]["text"], "again")


func test_unknown_id_is_empty():
	assert_eq(DialogData.resolve(DATA, "nope", {}), [])


func test_redirect_loop_is_bounded():
	assert_eq(DialogData.resolve(DATA, "loop_a", {}), [])


func test_shipped_dialog_file_parses_and_ids_resolve():
	var data := DialogData.load_file(Dialog.DIALOG_PATH)
	assert_gt(data.size(), 0)
	for id in data:
		assert_gt(DialogData.resolve(data, id, {}).size(), 0, "dialog '%s' resolves" % id)


func test_dialog_runner_sets_flags_and_finishes():
	GameState.new_game()
	watch_signals(Dialog)
	assert_true(Dialog.start("lung_pradit"))
	assert_true(Dialog.is_active())
	for i in 20:
		Dialog.typing = false
		Dialog.advance()
	assert_false(Dialog.is_active())
	assert_signal_emitted(Dialog, "finished")
	assert_true(GameState.has_flag("met_pradit"))
	assert_true(GameState.has_flag("job1_accepted"))
	GameState.new_game()


func test_conditions_and_actions():
	var data := {
		"q":
		{
			"if_flag": "a",
			"if_not_flag": "b",
			"if_item": "gear",
			"if_not_item": "cash",
			"lines": [{"text": "ok", "give_item": "x", "take_item": "gear", "money": 80}],
			"else": "no"
		},
		"no": ["no"],
	}
	assert_eq(DialogData.resolve(data, "q", {"a": true}, ["gear"])[0]["text"], "ok")
	assert_eq(DialogData.resolve(data, "q", {"a": true}, [])[0]["text"], "no", "needs item")
	assert_eq(
		DialogData.resolve(data, "q", {"a": true, "b": true}, ["gear"])[0]["text"],
		"no",
		"blocked flag"
	)
	assert_eq(
		DialogData.resolve(data, "q", {"a": true}, ["gear", "cash"])[0]["text"],
		"no",
		"blocked item"
	)
	var line: Dictionary = DialogData.resolve(data, "q", {"a": true}, ["gear"])[0]
	assert_eq(line["give_item"], "x")
	assert_eq(line["take_item"], "gear")
	assert_eq(line["money"], 80)


func test_runner_applies_item_and_money_actions():
	GameState.new_game()
	GameState.set_flag("job1_accepted")
	GameState.give_item("brass_gear")
	assert_true(Dialog.start("lung_pradit"))
	for i in 20:
		Dialog.typing = false
		Dialog.advance()
	assert_false(GameState.has_item("brass_gear"), "gear handed over")
	assert_eq(GameState.money, 80)
	assert_true(GameState.has_flag("job1_done"))
	GameState.new_game()
