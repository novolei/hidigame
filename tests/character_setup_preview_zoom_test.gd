extends Node

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay := CharacterSetupOverlay.new()
	add_child(overlay)
	overlay.show_setup(15.0)
	for i in range(8):
		await get_tree().process_frame

	_expect(absf(overlay.get_preview_default_scale_multiplier_for_test() - 1.4) < 0.001, "Preview default scale multiplier should be 1.4x")
	var initial_scale: Vector3 = overlay.get_preview_model_scale_for_test()
	_expect(initial_scale.length_squared() > 0.0001, "Preview model should have a valid fitted scale")
	var initial_error: Vector3 = overlay.get_preview_model_platform_anchor_error_for_test()
	_expect_anchor_near_platform(initial_error, "initial preview")
	var model_offset: Vector3 = overlay.get_preview_model_position_for_test()
	_expect(model_offset.z < -0.6, "Party Monster preview should compensate for the mesh origin being forward of visual center")
	_expect(absf(model_offset.y) < 0.02, "Party Monster preview should not need a root Y lift after mesh grounding")

	overlay.simulate_preview_wheel_for_test(MOUSE_BUTTON_WHEEL_UP)
	overlay.simulate_preview_wheel_for_test(MOUSE_BUTTON_WHEEL_DOWN)
	await get_tree().process_frame
	var wheel_scale: Vector3 = overlay.get_preview_model_scale_for_test()
	_expect(wheel_scale.distance_squared_to(initial_scale) < 0.0001, "Mouse wheel should not change preview scale")
	var wheel_error: Vector3 = overlay.get_preview_model_platform_anchor_error_for_test()
	_expect_anchor_near_platform(wheel_error, "wheel preview")

	overlay.rotate_preview_yaw_for_test(1.15)
	var rotated_error: Vector3 = overlay.get_preview_model_platform_anchor_error_for_test()
	_expect_anchor_near_platform(rotated_error, "rotated preview")
	_expect_pivot_near_platform_center(overlay.get_preview_pivot_position_for_test(), "rotated preview")

	var yaw_before_inertia: float = overlay.get_preview_turntable_yaw_for_test()
	overlay.release_preview_drag_with_velocity_for_test(3.0)
	await get_tree().process_frame
	var yaw_after_inertia: float = overlay.get_preview_turntable_yaw_for_test()
	var velocity_after_first_frame: float = overlay.get_preview_turntable_angular_velocity_for_test()
	_expect(yaw_after_inertia > yaw_before_inertia, "Turntable should keep rotating briefly after drag release")
	_expect(velocity_after_first_frame > 0.0 and velocity_after_first_frame < 3.0, "Turntable inertia should lose speed after release")

	for i in range(12):
		overlay.advance_preview_spin_for_test(0.1)
	_expect(absf(overlay.get_preview_turntable_angular_velocity_for_test()) <= 0.02, "Turntable inertia should decay to a stop")
	var inertia_error: Vector3 = overlay.get_preview_model_platform_anchor_error_for_test()
	_expect_anchor_near_platform(inertia_error, "inertia preview")
	_expect_pivot_near_platform_center(overlay.get_preview_pivot_position_for_test(), "inertia preview")

	overlay.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[CharacterSetupPreviewZoomTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[CharacterSetupPreviewZoomTest] " + failure)
		get_tree().quit(1)


func _expect_anchor_near_platform(error: Vector3, label: String) -> void:
	_expect(absf(error.x) < 0.02, "%s should keep visual X center on platform center" % label)
	_expect(absf(error.y) < 0.02, "%s should keep visual feet on platform surface" % label)
	_expect(absf(error.z) < 0.02, "%s should keep visual Z center on platform center" % label)


func _expect_pivot_near_platform_center(position: Vector3, label: String) -> void:
	_expect(absf(position.x) < 0.001, "%s pivot should stay on platform X center" % label)
	_expect(absf(position.y - 0.064) < 0.001, "%s pivot should stay on platform surface" % label)
	_expect(absf(position.z) < 0.001, "%s pivot should stay on platform Z center" % label)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
