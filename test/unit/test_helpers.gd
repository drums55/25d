class_name TestHelpers
extends RefCounted
## Shared setup for scene tests: a fresh adventure in a chosen room.


## New game with the rider in `room` (intro already seen).
static func start_in(room: String) -> void:
	GameState.new_game()
	GameState.set_flag("intro_done")
	GameState.room = room
	GameState.spawn = "default"


static func finish_dialog() -> void:
	for i in 30:
		Dialog.typing = false
		Dialog.advance()
