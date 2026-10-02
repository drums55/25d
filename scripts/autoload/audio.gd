extends Node
## Music, ambience and sound effects. Every file is synthesized by
## tools/audio/gen_audio.py into assets/audio/{music,ambience,sfx}/<name>.ogg
## (ranad / khim / ching in Thai 7-TET, a luk-thung radio, canal water,
## night insects, the bike's engine). Volume = Settings.volume on Master.
##
## What plays in a room comes from pick() (pure, tested); Main calls
## for_room() whenever a room loads. Loops are set looping at runtime so no
## .import file needs editing.

const DIR := "res://assets/audio/"
const MUSIC_DB := -7.0
const AMBIENCE_DB := -13.0
const SFX_DB := -5.0
const FADE := 1.2
const SFX_VOICES := 8
## Per-file level tweaks (dB).
const LEVELS := {
	"radio": -4.0,
	"line": -9.0,
	"pencil": -3.0,
	"tag": -2.0,
	"engine": 2.0,
	"wedding": 1.0,
}

var music_name := ""
var ambience_name := ""
var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _amb: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _cache := {}
var _duck: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	_amb = AudioStreamPlayer.new()
	add_child(_amb)
	_sting = AudioStreamPlayer.new()
	add_child(_sting)
	for i in SFX_VOICES:
		var s := AudioStreamPlayer.new()
		add_child(s)
		_sfx.append(s)
	Dialog.line_shown.connect(func(_s, _t): sfx("line", 0.12))
	GameState.tide_changed.connect(func(_t): sfx("tide"))


func _stream(path: String, loop: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	_cache[path] = s
	return s


func _level(name: String, base: float) -> float:
	return base + float(LEVELS.get(name, 0.0))


## Crossfade to a music loop ("" = silence). Same name = keep playing.
func music(name: String) -> void:
	if name == music_name:
		return
	music_name = name
	var old := _music[_active]
	_active = 1 - _active
	var cur := _music[_active]
	var t := create_tween().set_parallel()
	t.tween_property(old, "volume_db", -80.0, FADE)
	t.chain().tween_callback(old.stop)
	if name.is_empty():
		return
	cur.stream = _stream(DIR + "music/%s.ogg" % name, true)
	if cur.stream == null:
		return
	cur.volume_db = -40.0
	cur.play()
	create_tween().tween_property(cur, "volume_db", _level(name, MUSIC_DB), FADE)


## The background bed under the music ("" = none).
func ambience(name: String) -> void:
	if name == ambience_name:
		return
	ambience_name = name
	if name.is_empty():
		create_tween().tween_property(_amb, "volume_db", -80.0, FADE)
		return
	_amb.stream = _stream(DIR + "ambience/%s.ogg" % name, true)
	if _amb.stream == null:
		return
	_amb.volume_db = -40.0
	_amb.play()
	create_tween().tween_property(_amb, "volume_db", _level(name, AMBIENCE_DB), FADE)


## A one-shot; `vary` = random pitch spread (0.1 = +-10%).
func sfx(name: String, vary := 0.0) -> void:
	var s := _stream(DIR + "sfx/%s.ogg" % name, false)
	if s == null:
		return
	var p := _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx.size()
	p.stream = s
	p.volume_db = _level(name, SFX_DB)
	p.pitch_scale = 1.0 + randf_range(-vary, vary)
	p.play()


## A musical stinger (chapter card, endings) over the music, which ducks.
func sting(name: String) -> void:
	var s := _stream(DIR + "music/%s.ogg" % name, false)
	if s == null:
		return
	_sting.stream = s
	_sting.volume_db = _level(name, MUSIC_DB + 2.0)
	_sting.play()
	var m := _music[_active]
	if _duck:
		_duck.kill()
	_duck = create_tween()
	_duck.tween_property(m, "volume_db", _level(music_name, MUSIC_DB) - 14.0, 0.3)
	_duck.tween_interval(maxf(s.get_length() - 1.5, 0.5))
	_duck.tween_property(m, "volume_db", _level(music_name, MUSIC_DB), 1.5)


## [music, ambience] for a room: by chapter, the pier radio, the ending.
static func pick(room: String, chapter: int, flags: Dictionary, ending := "") -> Array:
	match ending:
		"five_stars":
			return ["wedding", "day"]
		"wet":
			return ["title", "day"]
		"sunk", "sold":
			return ["night", "night"]
	if chapter >= 3:
		return ["night", "night"]
	if room == "pier" and flags.get("radio_on", false):
		return ["radio", "day"]
	return ["day", "day"]


func for_room(room: String, ending := "") -> void:
	var p := pick(room, GameState.chapter, GameState.flags, ending)
	music(p[0])
	ambience(p[1])
