extends GutTest


func test_grid_world_round_trip():
	for cell in [Vector2.ZERO, Vector2(3, 7), Vector2(-2.5, 4.25), Vector2(11, 0)]:
		var back := Iso.world_to_grid(Iso.grid_to_world(cell))
		assert_almost_eq(back, cell, Vector2(0.0001, 0.0001))


func test_grid_axes_are_2_to_1_diamond():
	assert_eq(Iso.grid_to_world(Vector2(1, 0)), Vector2(64, 32))
	assert_eq(Iso.grid_to_world(Vector2(0, 1)), Vector2(-64, 32))


func test_dir8_snaps_screen_directions():
	assert_eq(Iso.dir8(Vector2.ZERO), -1)
	assert_eq(Iso.dir8(Vector2.RIGHT), Iso.Dir.E)
	assert_eq(Iso.dir8(Vector2.DOWN), Iso.Dir.S)
	assert_eq(Iso.dir8(Vector2.LEFT), Iso.Dir.W)
	assert_eq(Iso.dir8(Vector2.UP), Iso.Dir.N)
	assert_eq(Iso.dir8(Vector2(1, 1)), Iso.Dir.SE)
	assert_eq(Iso.dir8(Vector2(-1, -1)), Iso.Dir.NW)
	assert_eq(Iso.dir8(Vector2(1, -0.3)), Iso.Dir.E)


func test_dir8_vector_round_trip():
	for d in 8:
		assert_eq(Iso.dir8(Iso.dir8_vector(d)), d)


func test_facing_classification():
	assert_true(Iso.is_left_facing(Iso.Dir.W))
	assert_false(Iso.is_left_facing(Iso.Dir.N))
	assert_true(Iso.is_back_facing(Iso.Dir.NE))
	assert_false(Iso.is_back_facing(Iso.Dir.S))


func test_footprint_is_centred_diamond():
	var f := Iso.footprint(Vector2(2, 2))
	assert_eq(f.size(), 4)
	assert_eq(f[0], Vector2(0, -64))
	assert_eq(f[2], Vector2(0, 64))


func test_fit_camera_rect_grows_small_rooms_but_keeps_big_ones():
	var small := Rect2(0, 0, 1000, 600)
	var fitted := Iso.fit_camera_rect(small, Vector2(1920, 1200))
	assert_eq(fitted.size, Vector2(1920, 1200))
	assert_eq(fitted.get_center(), small.get_center())
	var big := Rect2(-100, -100, 4000, 3000)
	assert_eq(Iso.fit_camera_rect(big, Vector2(1920, 1200)), big)


func test_fill_zoom_covers_the_view_without_blurring():
	# a 12x9 room's painting (1344x912) on the 1920x1200 design screen
	assert_almost_eq(Iso.fill_zoom(Vector2(1344, 912), Vector2(1920, 1200)), 1.4286, 0.001)
	# never below 1 (a huge room scrolls) and never above 2 (art is 2x)
	assert_eq(Iso.fill_zoom(Vector2(4000, 3000), Vector2(1920, 1200)), 1.0)
	assert_eq(Iso.fill_zoom(Vector2(400, 300), Vector2(1920, 1200)), 2.0)
	# a wide phone picks the larger ratio so both axes are covered
	assert_almost_eq(Iso.fill_zoom(Vector2(1344, 912), Vector2(2600, 1200)), 1.9345, 0.001)
