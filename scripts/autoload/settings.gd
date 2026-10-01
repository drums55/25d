extends Node
## Player settings (user://settings.cfg), separate from save slots.

signal changed

const PATH := "user://settings.cfg"
## Real seconds per game minute while standing in a place.
## (slowed 2026-10-01: walking around a place ate too many game minutes)
const CLOCK_SPEEDS := {"ช้า": 3.0, "ปกติ": 2.0, "เร็ว": 1.2}
## Ride (lane runner) speed multiplier.
const RIDE_SPEEDS := {"ชิล": 0.75, "ปกติ": 1.0, "บิด": 1.4}
const TEXT_SPEEDS := {"ช้า": 25.0, "ปกติ": 45.0, "เร็ว": 90.0, "ทันที": 10000.0}

var clock_speed := "ปกติ"
var text_speed := "ปกติ"
var volume := 0.8
var show_hints := true
var ride_speed := "ปกติ"
## Skip the playable ride: trips resolve instantly (accessibility / tests).
var skip_ride := false


func _ready() -> void:
	load_settings()


func seconds_per_minute() -> float:
	return CLOCK_SPEEDS.get(clock_speed, 2.0)


func ride_speed_factor() -> float:
	return RIDE_SPEEDS.get(ride_speed, 1.0)


func chars_per_second() -> float:
	return TEXT_SPEEDS.get(text_speed, 45.0)


func load_settings(path := PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	clock_speed = str(cfg.get_value("game", "clock_speed", clock_speed))
	text_speed = str(cfg.get_value("game", "text_speed", text_speed))
	volume = float(cfg.get_value("audio", "volume", volume))
	show_hints = bool(cfg.get_value("game", "show_hints", show_hints))
	skip_ride = bool(cfg.get_value("game", "skip_ride", skip_ride))
	ride_speed = str(cfg.get_value("game", "ride_speed", ride_speed))
	_apply()


func save_settings(path := PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "clock_speed", clock_speed)
	cfg.set_value("game", "text_speed", text_speed)
	cfg.set_value("game", "show_hints", show_hints)
	cfg.set_value("game", "skip_ride", skip_ride)
	cfg.set_value("game", "ride_speed", ride_speed)
	cfg.set_value("audio", "volume", volume)
	cfg.save(path)
	_apply()


func _apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	changed.emit()
