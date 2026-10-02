extends Node
## The district of the current run (District; the seed drives weather + orders)
## plus riding between places: route, time, fuel, rain and floods.

signal arrived(node_id: int)

## Chance that soup / drinks spill when riding in rain or wading.
const SPILL_RAIN := 0.15
const SPILL_WADE := 0.5
const RIDE_SCENE := "res://scenes/ride/ride.tscn"
## Food spills when the ride ends with the steadiness meter below this.
const SPILL_STEADINESS := 50.0
## Running dry: the rest of the way is pushed at this many minutes per km.
const PUSH_MIN_PER_KM := 12.0
## Accidents (P2): chance a crash is a real accident, from fatigue + rain.
const ACCIDENT_BASE := 0.04
const ACCIDENT_PER_FATIGUE := 0.004
const ACCIDENT_RAIN := 0.05
const CLINIC_MINUTES := 40.0
const CLINIC_COST := Vector2i(300, 600)

var city := {}
## Set by travel() for RideScene: {"dest", "route", "track"}.
var pending_ride := {}
var rng := RandomNumberGenerator.new()
var _seed := -1
var _forecast_day := -1
var _forecast := {}


func has_city() -> bool:
	return not city.is_empty() and _seed == GameState.city_seed


func get_city() -> Dictionary:
	if _seed != GameState.city_seed or city.is_empty():
		_seed = GameState.city_seed
		city = District.city(_seed)
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


## Riding estimate between any two places under the current weather.
func route_between(from: int, to: int) -> Dictionary:
	return CityGen.route(get_city(), from, to, water_now(), Weather.rain_factor(rain_now()), true)


func route_to(dest: int, allow_wade := true) -> Dictionary:
	return CityGen.route(
		get_city(),
		GameState.location,
		dest,
		water_now(),
		Weather.rain_factor(rain_now()),
		allow_wade
	)


## Ride to `dest` along `r` (from route_to). Normally this starts the playable
## ride (RideScene, which calls finish_ride); with Settings.skip_ride the trip
## resolves at once (time, fuel, spill chance) and the place loads.
## Returns false when there is no way there.
func travel(dest: int, r := {}) -> bool:
	if r.is_empty():
		r = route_to(dest)
	if r.is_empty() or dest == GameState.location:
		return false
	if not Settings.skip_ride:
		start_ride(dest, r)
		return true
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
	if (
		GameState.fatigue >= GameState.TIRED
		and rng.randf() < accident_chance(GameState.fatigue, rain) * 0.5
	):
		accident()
	GameState.location = dest
	SceneRouter.go_to(GameState.LOCATION_SCENE, "arrival")
	arrived.emit(dest)
	Orders.check_cancellations()
	return true


## Map roads of a route as RideTrack segments (kind, km, water now).
func ride_segments(r: Dictionary) -> Array:
	var water := water_now()
	var out: Array = []
	for i in r.get("edges", []):
		var e: Dictionary = get_city()["edges"][i]
		out.append({"kind": e["kind"], "km": e["km"], "water": int(water.get(i, 0))})
	return out


func start_ride(dest: int, r: Dictionary) -> void:
	var seed := hash([GameState.city_seed, GameState.day, int(GameState.minute), dest])
	pending_ride = {
		"dest": dest,
		"route": r,
		"track":
		RideTrack.generate(
			seed, ride_segments(r), r["minutes"], rain_now(), Settings.ride_speed_factor()
		),
	}
	GameState.riding = true
	SceneRouter.go_to(RIDE_SCENE, "")


## RideScene is done: fuel, extra delay, food steadiness -> spills, arrive.
func finish_ride(result: Dictionary) -> void:
	var dest := int(result["dest"])
	var r: Dictionary = result["route"]
	var km: float = r["km"]
	if result.get("branch", "") == "A":
		km *= RideTrack.BRANCH_FACTOR["A"]
	var need := km / GameState.KM_PER_LITRE
	if need > GameState.fuel:
		var dry_km := (need - GameState.fuel) * GameState.KM_PER_LITRE
		GameState.notice.emit("น้ำมันหมดกลางทาง! เข็นรถไปอีก %.1f กม." % dry_km)
		GameState.advance_minutes(dry_km * PUSH_MIN_PER_KM)
		GameState.use_fuel(GameState.fuel)
	else:
		GameState.use_fuel(need)
	GameState.advance_minutes(float(result.get("delay", 0.0)))
	if result.get("accident", false):
		accident()
	var steady := float(result.get("steadiness", 100.0))
	for o in GameState.orders:
		if o["status"] == "picked" and o["kind"] == "food" and steady < SPILL_STEADINESS:
			o["spilled"] = true
			GameState.notice.emit("ของในกล่องหก! (%s)" % o["item"])
	GameState.location = dest
	GameState.riding = false
	pending_ride = {}
	SceneRouter.go_to(GameState.LOCATION_SCENE, "arrival")
	arrived.emit(dest)
	Orders.check_cancellations()


static func accident_chance(fatigue: float, rain: int) -> float:
	return (
		ACCIDENT_BASE
		+ maxf(0.0, fatigue - 30.0) * ACCIDENT_PER_FATIGUE
		+ (ACCIDENT_RAIN if rain > 0 else 0.0)
	)


## A real accident: clinic time + bill. The platform insurance only covers
## "ระหว่างส่งงาน" and pays after 14 working days (= never, in a 7-day run);
## what the wallet cannot pay is borrowed from the loan shark.
func accident() -> int:
	var cost := rng.randi_range(CLINIC_COST.x / 10, CLINIC_COST.y / 10) * 10
	var carrying := Orders.carrying_cargo()
	for o in GameState.orders:
		if o["status"] == "picked" and o["kind"] == "food":
			o["spilled"] = true
	GameState.advance_minutes(CLINIC_MINUTES)
	GameState.add_fatigue(10.0)
	var paid := mini(cost, GameState.money)
	GameState.add_money(-paid, "medical")
	var short := cost - paid
	if short > 0:
		GameState.debt += short
		GameState.log_today["medical_debt"] = (
			int(GameState.log_today.get("medical_debt", 0)) + short
		)
	GameState.notice.emit(
		"อุบัติเหตุ! คลินิกเย็บแผล ทำแผล %d บาท (เสียเวลา %d นาที)" % [cost, CLINIC_MINUTES]
	)
	if carrying:
		GameState.notice.emit("ประกันแพลตฟอร์ม: รับเรื่องแล้ว จะพิจารณาภายใน 14 วันทำการ")
	else:
		GameState.notice.emit("ประกันแพลตฟอร์ม: ไม่คุ้มครอง (ไม่ได้อยู่ระหว่างส่งงาน)")
	if short > 0:
		GameState.notice.emit("เงินไม่พอ ยืมเจ้าหนี้มาจ่ายค่าหมอ %d บาท (หนี้เพิ่ม)" % short)
	GameState.stats_changed.emit()
	return cost
