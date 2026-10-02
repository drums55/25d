extends GutTest
## 8-direction sprite sheets: sprites.json -> SpriteFrames, CharacterView
## placement (feet on origin) and state machine; cut-out fallback otherwise.

const VIEW := preload("res://scenes/characters/character_view.tscn")


func _view(name: String) -> CharacterView:
	var v := VIEW.instantiate() as CharacterView
	v.character_name = name
	add_child_autofree(v)
	return v


func test_sprite_set_reads_json_and_sheets():
	var data := ArtLibrary.sprite_set("rider")
	assert_eq(data["frame_size"], Vector2(320, 480))
	assert_eq(data["pivot"], Vector2(160, 448))
	assert_eq(data["directions"].size(), 8)
	assert_eq(data["anims"]["walk"]["frames"], 8)
	assert_eq(data["anims"]["attack"]["fps"], 18.0)
	var tex: Texture2D = data["anims"]["walk"]["texture"]
	assert_eq(tex.get_size(), Vector2(320 * 8, 480 * 8), "walk sheet = 8 frames x 8 rows")
	assert_eq(ArtLibrary.sprite_set("does_not_exist"), {})


func test_build_sprite_frames_names_loops_and_regions():
	var frames := ArtLibrary.build_sprite_frames(ArtLibrary.sprite_set("rider"))
	assert_eq(
		frames.get_animation_names().size(),
		8 * 8,
		"idle, walk, attack, ride + the endings: cheer, shrug, sit_sad, phone"
	)
	assert_true(frames.has_animation("walk_3"))
	assert_false(frames.has_animation("default"))
	assert_eq(frames.get_frame_count("walk_3"), 8)
	assert_eq(frames.get_animation_speed("walk_3"), 12.0)
	assert_true(frames.get_animation_loop("idle_0"))
	assert_true(frames.get_animation_loop("walk_0"))
	assert_false(frames.get_animation_loop("attack_0"))
	assert_true(frames.get_animation_loop("ride_1"), "held poses loop")
	var atlas := frames.get_frame_texture("walk_3", 2) as AtlasTexture
	assert_eq(atlas.region, Rect2(2 * 320, 3 * 480, 320, 480), "column = frame, row = direction")


func test_view_places_feet_on_origin_at_game_scale():
	var v := _view("rider")
	assert_true(v.has_sprites())
	var sprite := v.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		sprite.offset, Vector2(0, -208), "frame centre shifted so pivot (160,448) sits on origin"
	)
	var k := 0.5 * CharacterView.SIZE
	assert_almost_eq(sprite.scale.x, k, 0.0001, "half the 2x render, a bit smaller")
	# the frame top is 448 render px above the feet
	var top := (sprite.offset.y - 240) * sprite.scale.y
	assert_almost_eq(top, -448.0 * k, 0.01)


func test_view_state_machine_uses_direction_rows_without_mirroring():
	var v := _view("rider")
	var sprite := v.get_node("Sprite") as AnimatedSprite2D
	assert_eq(sprite.animation, "idle_2", "starts idle facing S")
	v.set_facing(Iso.Dir.W)
	assert_eq(sprite.animation, "idle_4")
	assert_gt(sprite.scale.x, 0.0, "never mirrored")
	v.set_walk(1.0)
	assert_eq(sprite.animation, "walk_4")
	v.set_walk(0.0)
	assert_eq(sprite.animation, "idle_4")
	v.play_attack()
	assert_true(v.is_attacking())
	assert_eq(sprite.animation, "attack_4")
	assert_almost_eq(v.attack_duration(), 6.0 / 18.0, 0.001)
	v.set_walk(1.0)
	assert_eq(sprite.animation, "attack_4", "attack is not interrupted by walking")
	await wait_for_signal(v.attack_finished, 1.0)
	assert_false(v.is_attacking())
	assert_eq(sprite.animation, "walk_4", "returns to the pending walk state")


func test_npc_without_attack_ignores_play_attack():
	var v := _view("lung_pradit")
	assert_true(v.has_sprites())
	v.play_attack()
	assert_false(v.is_attacking())
	assert_eq(v.attack_duration(), 0.0)


func test_unknown_character_falls_back_to_cutout_rig():
	var v := _view("does_not_exist")
	assert_false(v.has_sprites())
	var rig := v.get_child(0) as CutoutRig
	assert_not_null(rig)
	v.set_facing(Iso.Dir.W)
	assert_lt(rig.scale.x, 0.0, "cut-out fallback still mirrors")
	v.play_attack()
	assert_true(v.is_attacking())


func test_held_poses_ride_and_dance():
	var v := _view("rider")
	var sprite := v.get_node("Sprite") as AnimatedSprite2D
	v.set_facing(Iso.Dir.SE)
	assert_true(v.set_pose("ride"))
	assert_eq(sprite.animation, "ride_1")
	v.set_walk(1.0)
	assert_eq(sprite.animation, "ride_1", "a held pose beats walking")
	assert_false(v.set_pose("dance"), "the rider has no dance")
	v.set_pose("")
	assert_eq(sprite.animation, "walk_1")
	var nuad := _view("nuad")
	assert_true(nuad.set_pose("dance"), "พี่หนวด dances to the radio")


func test_every_npc_has_its_own_sheet():
	for n in ["nuad", "lung_table3", "pa_nok", "jum", "keng", "chang_daeng", "kiao", "wan"]:
		assert_false(ArtLibrary.sprite_set(n).is_empty(), n)
