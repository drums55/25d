class_name TestHelpers
extends RefCounted
## Shared setup for scene tests: a fixed city and a chosen kind of place.

const SEED := 4242


## Fresh game on the fixed city with the rider at the first place of `type`.
## Trips resolve instantly unless a test turns the ride back on.
static func start_at(type: String) -> int:
	Settings.skip_ride = true
	LocationRoom.allow_collector = false
	GameState.new_game(SEED)
	var id: int = CityGen.nodes_of_type(City.get_city(), type)[0]["id"]
	GameState.location = id
	return id


static func finish_dialog() -> void:
	for i in 30:
		Dialog.typing = false
		Dialog.advance()
