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
	assert_true(Dialog.start("elder"))
	assert_true(Dialog.is_active())
	Dialog.typing = false
	for i in 3:
		Dialog.advance()
		Dialog.typing = false
	assert_false(Dialog.is_active())
	assert_signal_emitted(Dialog, "finished")
	assert_true(GameState.has_flag("met_elder"))
	GameState.new_game()
