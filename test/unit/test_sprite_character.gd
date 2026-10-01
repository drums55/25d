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
	assert_eq(frames.get_animation_names().size(), 3 * 8)
	assert_true(frames.has_animation("walk_3"))
	assert_false(frames.has_animation("default"))
	assert_eq(frames.get_frame_count("walk_3"), 8)
	assert_eq(frames.get_animation_speed("walk_3"), 12.0)
	assert_true(frames.get_animation_loop("idle_0"))
	assert_true(frames.get_animation_loop("walk_0"))
	assert_false(frames.get_animation_loop("attack_0"))
	var atlas := frames.get_frame_texture("walk_3", 2) as AtlasTexture
	assert_eq(atlas.region, Rect2(2 * 320, 3 * 480, 320, 480), "column = frame, row = direction")


func test_view_places_feet_on_origin_at_game_scale():
	var v := _view("rider")
	assert_true(v.has_sprites())
	var sprite := v.get_node("Sprite") as AnimatedSprite2D
	assert_eq(
		sprite.offset, Vector2(0, -208), "frame centre shifted so pivot (160,448) sits on origin"
	)
	assert_eq(sprite.scale, Vector2(0.5, 0.5))
	# bottom of the frame ends 32 px (2x) = 16 px below the feet; top is 224 px above
	var top := (sprite.offset.y - 240) * sprite.scale.y
	assert_eq(top, -224.0)


func test_view_state_machine_uses_direction_rows_without_mirroring():
	var v := _view("rider")
	var sprite := v.get_node("Sprite") as AnimatedSprite2D
	assert_eq(sprite.animation, "idle_2", "starts idle facing S")
	v.set_facing(Iso.Dir.W)
	assert_eq(sprite.animation, "idle_4")
	assert_eq(sprite.scale.x, 0.5, "never mirrored")
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
