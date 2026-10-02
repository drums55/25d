extends GutTest
## Sound: what plays where (Audio.pick) and that every sound the code asks
## for exists in assets/audio (made by tools/audio/gen_audio.py).


func test_music_follows_chapter_radio_and_ending():
	assert_eq(Audio.pick("home", 1, {}), ["day", "day"])
	assert_eq(Audio.pick("pier", 1, {}), ["day", "day"])
	assert_eq(Audio.pick("pier", 1, {"radio_on": true}), ["radio", "day"], "the pier radio")
	assert_eq(Audio.pick("stilts", 1, {"radio_on": true}), ["day", "day"])
	assert_eq(Audio.pick("pier", 3, {"radio_on": true}), ["night", "night"], "chapter 3 = night")
	assert_eq(Audio.pick("noodle_boat", 3, {}, "five_stars"), ["wedding", "day"])
	assert_eq(Audio.pick("home", 3, {}, "sold"), ["night", "night"])
	for e in Endings.TEXT:
		assert_eq(Audio.pick("home", 3, {}, e).size(), 2, e)


func test_every_sound_the_code_names_exists():
	var calls := RegEx.create_from_string('Audio\\.(sfx|music|ambience|sting)\\("([a-z_]+)"')
	# dialog / puzzle lines may name a sound too ("sfx": "meow")
	var json_sfx := RegEx.create_from_string('"sfx": "([a-z_]+)"')
	for path in [Dialog.DIALOG_PATH, Puzzles.DATA_PATH]:
		for m in json_sfx.search_all(FileAccess.get_file_as_string(path)):
			assert_true(
				FileAccess.file_exists("res://assets/audio/sfx/%s.ogg" % m.get_string(1)),
				"%s names sfx %s" % [path, m.get_string(1)]
			)
	var found := 0
	for path in _scripts("res://scripts"):
		var text := FileAccess.get_file_as_string(path)
		for m in calls.search_all(text):
			var kind := m.get_string(1)
			var folder: String = {
				"sfx": "sfx", "music": "music", "sting": "music", "ambience": "ambience"
			}[kind]
			var file := "res://assets/audio/%s/%s.ogg" % [folder, m.get_string(2)]
			assert_true(ResourceLoader.exists(file), "%s (%s)" % [file, path])
			found += 1
	assert_gt(found, 15)
	for name in ["sting_good", "sting_sad", "sting_chapter"]:
		assert_true(ResourceLoader.exists("res://assets/audio/music/%s.ogg" % name))
	for e in Endings.TEXT:
		var p := Audio.pick("home", 3, {}, e)
		assert_true(ResourceLoader.exists("res://assets/audio/music/%s.ogg" % p[0]), e)
		assert_true(ResourceLoader.exists("res://assets/audio/ambience/%s.ogg" % p[1]), e)


func test_loops_loop_and_sfx_play():
	Audio.music("day")
	assert_eq(Audio.music_name, "day")
	var s := load("res://assets/audio/music/day.ogg") as AudioStreamOggVorbis
	assert_true(s.loop, "music loops")
	Audio.sfx("pickup")
	Audio.sting("sting_chapter")
	Audio.music("")
	Audio.ambience("")


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
