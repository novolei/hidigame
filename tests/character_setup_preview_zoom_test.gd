extends Node

## Carousel behaviour test for the redesigned CharacterSetupOverlay.
## Verifies: warm-up pool builds, the wheel/step switches the centered skin,
## rapid duplicate inputs are debounced to a single step, drag-release inertia
## spins then damps to rest, and the countdown enters its urgency state below 8s.

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay := CharacterSetupOverlay.new()
	add_child(overlay)
	overlay.show_setup(20.0)
	overlay.force_full_warmup_for_test()
	for i in range(6):
		await get_tree().process_frame

	_expect(overlay.is_warmup_complete_for_test(), "Carousel warm-up should complete")
	var center := overlay.get_center_skin_id_for_test()
	_expect(center.begins_with("party_monster_"), "Centered slot should hold a Party Monster skin")
	_expect(overlay.get_visible_slot_count_for_test() >= 3, "Center plus both neighbours should be visible")

	# Wheel down should slide the carousel to an adjacent skin.
	var before := overlay.get_center_skin_id_for_test()
	overlay.simulate_preview_wheel_for_test(MOUSE_BUTTON_WHEEL_DOWN)
	for i in range(48):
		await get_tree().process_frame
	var after := overlay.get_center_skin_id_for_test()
	_expect(after != before, "Wheel down should switch the centered skin")

	# Debounce: two wheel ticks fired in the same frame must count as a single step.
	for i in range(30):
		await get_tree().process_frame
	var scroll_before := roundi(overlay.get_carousel_scroll_for_test())
	overlay.simulate_preview_wheel_for_test(MOUSE_BUTTON_WHEEL_DOWN)
	overlay.simulate_preview_wheel_for_test(MOUSE_BUTTON_WHEEL_DOWN)
	for i in range(48):
		await get_tree().process_frame
	var scroll_after := roundi(overlay.get_carousel_scroll_for_test())
	_expect(scroll_after - scroll_before == 1, "Rapid duplicate wheel ticks should debounce to one step")

	# Drag-release inertia: keeps rotating, loses speed, then decays to rest.
	for i in range(24):
		await get_tree().process_frame
	var yaw_before := overlay.get_center_yaw_for_test()
	overlay.release_center_drag_with_velocity_for_test(3.0)
	await get_tree().process_frame
	var yaw_after := overlay.get_center_yaw_for_test()
	var velocity_after := overlay.get_center_angular_velocity_for_test()
	_expect(yaw_after > yaw_before, "Center model should keep spinning briefly after drag release")
	_expect(velocity_after > 0.0 and velocity_after < 3.0, "Spin inertia should lose speed after release")
	for i in range(150):
		await get_tree().process_frame
	_expect(absf(overlay.get_center_angular_velocity_for_test()) <= 0.05, "Spin inertia should damp to a stop")

	# Countdown urgency threshold (8s).
	overlay.set_remaining(5.0)
	_expect(overlay.get_countdown_urgency_for_test() > 0.0, "Below 8s should raise countdown urgency")
	overlay.set_remaining(15.0)
	_expect(overlay.get_countdown_urgency_for_test() == 0.0, "Above 8s should keep the countdown calm")

	overlay.hide_setup()
	overlay.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[CharacterSetupCarouselTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[CharacterSetupCarouselTest] " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
