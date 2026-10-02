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
	assert_true(Dialog.start("look_trash"))
	assert_true(Dialog.is_active())
	for i in 20:
		Dialog.typing = false
		Dialog.advance()
	assert_false(Dialog.is_active())
	assert_signal_emitted(Dialog, "finished")
	GameState.new_game()


func test_conditions_and_actions():
	var data := {
		"q":
		{
			"if_flag": "a",
			"if_not_flag": "b",
			"if_item": "gear",
			"if_not_item": "cash",
			"if_money_at_least": 50,
			"lines": [{"text": "ok", "give_item": "x", "take_item": "gear", "money": 80}],
			"else": "no"
		},
		"no": ["no"],
	}
	assert_eq(DialogData.resolve(data, "q", {"a": true}, ["gear"], 50)[0]["text"], "ok")
	assert_eq(
		DialogData.resolve(data, "q", {"a": true}, ["gear"], 49)[0]["text"], "no", "needs money"
	)
	assert_eq(DialogData.resolve(data, "q", {"a": true}, [], 50)[0]["text"], "no", "needs item")
	assert_eq(DialogData.resolve(data, "q", {"a": true, "b": true}, ["gear"], 50)[0]["text"], "no")
	assert_eq(DialogData.resolve(data, "q", {"a": true}, ["gear", "cash"], 50)[0]["text"], "no")
	var line: Dictionary = DialogData.resolve(data, "q", {"a": true}, ["gear"], 50)[0]
	assert_eq(line["give_item"], "x")
	assert_eq(line["take_item"], "gear")
	assert_eq(line["money"], 80)


func test_start_lines_plays_adhoc_lines_with_actions():
	GameState.new_game()
	assert_true(
		Dialog.start_lines([{"speaker": "x", "text": "hi", "give_item": "hanger"}, "bye"], "t")
	)
	assert_true(Dialog.is_active())
	assert_true(GameState.has_item("hanger"))
	for i in 5:
		Dialog.typing = false
		Dialog.advance()
	assert_false(Dialog.is_active())
	GameState.new_game()
