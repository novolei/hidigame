extends SceneTree
# Headless test for the Stalker grapple VFX + landing momentum work.
# Run: godot --headless tests/stalker_grapple_vfx_test.gd

const GrappleSystemScript := preload("res://scripts/stalker_grapple_system.gd")
const GrappleVisualScript := preload("res://scripts/effects/stalker_grapple_visual.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_exit_momentum_strong_fling()
	await _test_visual_builds_and_self_frees()
	_test_source_invariants()

	if failures.is_empty():
		print("[StalkerGrappleVfxTest] PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("[StalkerGrappleVfxTest] " + failure)
		quit(1)


func _test_exit_momentum_strong_fling() -> void:
	var stalker := CharacterBody3D.new()
	stalker.name = "Stalker"
	root.add_child(stalker)
	stalker.global_position = Vector3.ZERO

	var grapple := GrappleSystemScript.new()
	root.add_child(grapple)
	grapple.initialize(stalker, null)

	# Simulate a finished reel-in that traveled +X and slightly upward.
	grapple._pull_start = Vector3(0.0, 1.0, 0.0)
	grapple._pull_target = Vector3(8.0, 3.0, 0.0)
	stalker.velocity = Vector3.ZERO
	grapple._apply_exit_momentum()

	var v: Vector3 = stalker.velocity
	_expect(v.length() > 1.0, "Exit momentum should launch the stalker, got %s" % str(v))
	_expect(v.y > 0.0, "Exit momentum should add an upward boost, got y=%f" % v.y)
	var horizontal := Vector2(v.x, v.z).length()
	_expect(horizontal > 10.0, "Strong fling should carry strong horizontal speed, got %f" % horizontal)
	_expect(v.x > absf(v.z) and v.x > 0.0, "Exit velocity should follow the pull's +X travel direction")

	stalker.queue_free()
	grapple.queue_free()
	await process_frame


func _test_visual_builds_and_self_frees() -> void:
	var shooter := CharacterBody3D.new()
	shooter.name = "VisualShooter"
	root.add_child(shooter)
	shooter.global_position = Vector3.ZERO

	var anchor := Vector3(0.0, 2.0, -6.0)
	var visual = GrappleVisualScript.spawn(root, shooter, Vector3(0.0, 1.2, 0.0), anchor, 0.18)
	_expect(visual != null, "Grapple visual should spawn")
	await process_frame
	await process_frame

	if visual != null and is_instance_valid(visual):
		_expect(visual.get_node_or_null("Claw") != null, "Grapple visual should build an animated Claw")
		_expect(visual.get_node_or_null("Rope") is MeshInstance3D, "Grapple visual should build a Rope mesh")
		_expect(visual.get_node_or_null("Pulse") != null, "Grapple visual should build a reel-in Pulse mote")
		var rope := visual.get_node_or_null("Rope") as MeshInstance3D
		if rope and rope.mesh is CylinderMesh:
			_expect((rope.mesh as CylinderMesh).height > 0.5, "Rope length should span hand -> anchor")

	# total visual time = 0.06 + 0.18 + 0.14 = 0.38s; confirm it self-cleans.
	await create_timer(0.55).timeout
	_expect(not is_instance_valid(visual), "Grapple visual should self-free after the animation completes")

	shooter.queue_free()
	await process_frame


func _test_source_invariants() -> void:
	var grapple_src := FileAccess.get_file_as_string("res://scripts/stalker_grapple_system.gd")
	_expect(grapple_src.contains("_apply_exit_momentum()"), "Pull completion should apply exit momentum")
	_expect(grapple_src.contains("GrappleVisualScript.spawn"), "Grapple system should spawn the animated visual")
	_expect(grapple_src.contains("is_dedicated_public_server"), "Grapple visual spawn must be guarded off dedicated servers")
	# Regression guard: the netfox motor root-drives movement, so the grapple
	# must yield rollback drive while pulling or the body never leaves the spot.
	var player_src := FileAccess.get_file_as_string("res://scripts/player.gd")
	_expect(
		player_src.contains("stalker_grapple_system.is_grappling()"),
		"allows_rollback_movement_drive() must yield while grappling so the pull's position writes apply"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
