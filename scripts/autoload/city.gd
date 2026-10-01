extends Node
## The generated city of the current run (CityGen from GameState.city_seed)
## plus riding between places: route, time, fuel, rain and floods.

signal arrived(node_id: int)

## Chance that soup / drinks spill when riding in rain or wading.
const SPILL_RAIN := 0.15
const SPILL_WADE := 0.5
## Running dry: the rest of the way is pushed at this many minutes per km.
const PUSH_MIN_PER_KM := 12.0

var city := {}
var rng := RandomNumberGenerator.new()
var _seed := -1
var _forecast_day := -1
var _forecast := {}


func has_city() -> bool:
	return not city.is_empty() and _seed == GameState.city_seed


func get_city() -> Dictionary:
	if _seed != GameState.city_seed or city.is_empty():
		_seed = GameState.city_seed
		city = CityGen.generate(_seed)
		_forecast_day = -1
	return city


func node(id: int) -> Dictionary:
	return get_city()["nodes"][id]


func node_name(id: int) -> String:
	return str(node(id)["name"])


func here() -> Dictionary:
	return node(GameState.location)


func forecast() -> Dictionary:
	get_city()
	if _forecast_day != GameState.day:
		_forecast_day = GameState.day
		_forecast = Weather.forecast(GameState.city_seed, GameState.day)
	return _forecast


func rain_now() -> int:
	return Weather.rain_at(forecast(), GameState.minute)


func water_now() -> Dictionary:
	return Weather.edge_levels(get_city(), forecast(), GameState.minute)


func route_to(dest: int, allow_wade := true) -> Dictionary:
	return CityGen.route(
		get_city(),
		GameState.location,
		dest,
		water_now(),
		Weather.rain_factor(rain_now()),
		allow_wade
	)


## Ride to `dest` along `r` (from route_to). Applies time, fuel, spills, then
## loads the place. Returns false when there is no way there.
func travel(dest: int, r := {}) -> bool:
	if r.is_empty():
		r = route_to(dest)
	if r.is_empty() or dest == GameState.location:
		return false
	var km: float = r["km"]
	var minutes: float = r["minutes"]
	var need := km / GameState.KM_PER_LITRE
	if need > GameState.fuel:
		var dry_km := (need - GameState.fuel) * GameState.KM_PER_LITRE
		minutes += dry_km * PUSH_MIN_PER_KM
		GameState.notice.emit("น้ำมันหมดกลางทาง! เข็นรถไปอีก %.1f กม." % dry_km)
		GameState.use_fuel(GameState.fuel)
	else:
		GameState.use_fuel(need)
	var rain := rain_now()
	var spill_chance := SPILL_WADE if r["wade"] else (SPILL_RAIN if rain > 0 else 0.0)
	for o in GameState.orders:
		if o["status"] == "picked" and o["kind"] == "food" and rng.randf() < spill_chance:
			o["spilled"] = true
			GameState.notice.emit("น้ำซุปหกในกล่อง! (%s)" % o["item"])
	if r["wade"]:
		GameState.notice.emit("ลุยน้ำท่วม ... รองเท้าเปียกถึงตาตุ่ม")
	GameState.advance_minutes(minutes)
	GameState.location = dest
	SceneRouter.go_to(GameState.LOCATION_SCENE, "arrival")
	arrived.emit(dest)
	return true
