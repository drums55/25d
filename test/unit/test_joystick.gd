extends GutTest


func test_zero_and_deadzone():
	assert_eq(VirtualJoystick.compute_output(Vector2.ZERO, 100.0), Vector2.ZERO)
	assert_eq(VirtualJoystick.compute_output(Vector2(10, 0), 100.0, 0.2), Vector2.ZERO)


func test_scales_and_clamps_to_unit_length():
	assert_almost_eq(
		VirtualJoystick.compute_output(Vector2(50, 0), 100.0), Vector2(0.5, 0), Vector2.ONE * 0.001
	)
	var far := VirtualJoystick.compute_output(Vector2(300, 400), 100.0)
	assert_almost_eq(far.length(), 1.0, 0.001)
	assert_almost_eq(far.normalized(), Vector2(0.6, 0.8), Vector2.ONE * 0.001)


func test_deadzone_rescales_from_edge():
	var v := VirtualJoystick.compute_output(Vector2(60, 0), 100.0, 0.2)
	assert_almost_eq(v.x, 0.5, 0.001)
