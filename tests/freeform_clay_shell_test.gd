extends Node3D

const FREEFORM_CLAY_SHELL_SCENE := preload("res://scenes/effects/freeform_clay_shell.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var shell: Node = FREEFORM_CLAY_SHELL_SCENE.instantiate()
	add_child(shell)
	await get_tree().process_frame

	var initial_vertex_count := _vertex_count(shell)
	var initial_triangle_count := _triangle_count(shell)
	var initial_checksum := _checksum(shell)
	var initial_solid_count := int(shell.call("get_solid_voxel_count"))
	var body_mesh := shell.get("body_mesh") as MeshInstance3D
	_expect(initial_solid_count > 1000, "Solid clay shell should initialize as a filled SDF volume")
	_expect(initial_vertex_count > 400, "Solid clay shell should generate a usable smooth render surface")
	_expect(initial_triangle_count > 700, "Solid clay shell should generate enough triangles for smooth clay deformation")
	_expect(body_mesh != null and body_mesh.mesh != null and body_mesh.mesh.get_surface_count() == 1, "Solid clay shell should expose one renderable mesh surface")
	var source_summary: Dictionary = shell.call("get_source_mesh_summary")
	_expect(str(source_summary.get("source", "")) == "basic_humanoid_blender_remesh_solid_clone", "Default shell should load the Blender-baked Basic Human solid clone profile: " + str(source_summary))
	_expect(str(source_summary.get("path", "")).ends_with("basic_human_solid_clone_profile.json"), "Default shell should come from the prepared clone body asset: " + str(source_summary))
	var bounds: AABB = shell.call("get_local_bounds")
	_expect(bounds.size.x > 0.65 and bounds.size.x < 1.30, "Default solid shell should preserve the Blender-baked Basic Human body span: " + str(bounds))
	_expect(bounds.size.y > 1.65 and bounds.size.y < 1.90, "Default shell should keep the Basic Human asset height in playable scale: " + str(bounds))
	_expect(bounds.size.z > 0.40 and bounds.size.z < 0.95, "Default shell should preserve the Blender-baked Basic Human body depth: " + str(bounds))
	var initial_quality: Dictionary = shell.call("get_surface_quality_summary")
	_expect(str(initial_quality.get("mode", "")) == "solid_sdf_clay", "Solid clay shell should report SDF quality metrics: " + str(initial_quality))
	var ray_hit: Dictionary = shell.call("intersect_ray_world", Vector3(0.0, 0.9, 3.0), Vector3(0.0, 0.0, -1.0), 8.0)
	_expect(not ray_hit.is_empty(), "Solid clay shell should support direct mesh ray hits for sculpt tools without a physics collision body")

	var grab: Dictionary = shell.call("apply_grab_stroke_local", Vector3(0.25, 0.9, 0.0), Vector3(0.18, 0.08, 0.0), 0.38, 1.0)
	_expect(int(grab.get("changed_voxels", 0)) > 0, "Grab should move nearby solid clay volume")
	_expect(int(shell.call("get_solid_voxel_count")) > 0, "Grab should keep a valid solid volume")
	_expect(_checksum(shell) != initial_checksum, "Grab should deform the surface")

	var after_grab_checksum := _checksum(shell)
	var push_solid_before := int(shell.call("get_solid_voxel_count"))
	var push: Dictionary = shell.call("apply_push_pull_stroke_local", Vector3(0.0, 0.9, 0.28), 0.12, 0.34, 1.0)
	_expect(int(push.get("changed_voxels", 0)) > 0, "Push/Pull should add nearby solid clay")
	_expect(_checksum(shell) != after_grab_checksum, "Push/Pull should change vertex positions")
	_expect(abs(int(shell.call("get_solid_voxel_count")) - push_solid_before) < 320, "Push/Pull should keep clay volume within a believable local feedback range")

	var sculpt_add: Dictionary = shell.call("apply_sculpt_stroke_local", "add", Vector3(0.0, 0.95, 0.26), 0.30, 1.0)
	_expect(int(sculpt_add.get("changed_voxels", 0)) > 0, "Add should union solid clay into the SDF volume")
	_expect(str(sculpt_add.get("tool", "")) == "add", "Add sculpt summary should keep the player-facing tool name")

	var capsule_sweep: Dictionary = shell.call("apply_sculpt_capsule_stroke_local", "add", Vector3(-0.18, 0.95, 0.22), Vector3(0.18, 0.95, 0.22), 0.24, 0.75)
	_expect(int(capsule_sweep.get("changed_voxels", 0)) > 0, "Held-left-button sculpting should apply a continuous rounded capsule sweep")

	var perf_before: Dictionary = shell.call("get_performance_summary")
	shell.call("begin_sculpt_batch")
	var smart: Dictionary = shell.call("apply_sculpt_capsule_stroke_local", "smart", Vector3(-0.16, 0.82, -0.18), Vector3(0.16, 0.84, -0.16), 0.22, 0.65)
	var batch_flatten: Dictionary = shell.call("apply_sculpt_capsule_stroke_local", "flatten", Vector3(-0.12, 0.88, -0.22), Vector3(0.12, 0.88, -0.22), 0.20, 0.45)
	var perf_mid: Dictionary = shell.call("get_performance_summary")
	_expect(int(smart.get("changed_voxels", 0)) > 0, "Smart sculpt should provide an easy default clay-shaping stroke")
	_expect(int(batch_flatten.get("changed_voxels", 0)) > 0, "Batched sculpt strokes should still edit the clay volume")
	_expect(bool(perf_mid.get("pending_rebuild", false)), "Batched sculpt strokes should defer expensive mesh rebuilds until the batch ends")
	_expect(int(perf_mid.get("rebuild_count", -1)) == int(perf_before.get("rebuild_count", -2)), "Batched sculpt strokes should not rebuild the mesh for each sub-stroke")
	shell.call("end_sculpt_batch")
	var perf_after: Dictionary = shell.call("get_performance_summary")
	_expect(int(perf_after.get("rebuild_count", 0)) == int(perf_before.get("rebuild_count", 0)) + 1, "Ending a sculpt batch should rebuild the mesh once")

	var sculpt_remove: Dictionary = shell.call("apply_sculpt_stroke_local", "remove", Vector3(0.0, 0.95, 0.26), 0.30, 1.0)
	_expect(int(sculpt_remove.get("changed_voxels", 0)) > 0, "Remove should subtract solid clay from the SDF volume")

	var stretch: Dictionary = shell.call("apply_sculpt_stroke_local", "stretch", Vector3(0.25, 0.85, 0.18), 0.32, 1.0)
	_expect(int(stretch.get("changed_voxels", 0)) > 0, "Stretch should extend the solid clay volume as a smooth capsule")

	var flattened: Dictionary = shell.call("apply_flatten_stroke_local", Vector3(0.0, 0.9, -0.26), Vector3.FORWARD, 0.45, 0.8)
	_expect(int(flattened.get("changed_voxels", 0)) > 0, "Flatten should affect solid voxels near the anchor plane")

	var sculpt_flatten: Dictionary = shell.call("apply_sculpt_stroke_local", "flatten", Vector3(0.0, 0.9, -0.24), 0.36, 0.8)
	_expect(int(sculpt_flatten.get("changed_voxels", 0)) > 0, "Flatten sculpt tool should use the SDF surface normal and affect nearby voxels")
	var beautify_before := _checksum(shell)
	var beautify: Dictionary = shell.call("apply_beautify_capsule_local", "smart", Vector3(-0.15, 0.88, 0.22), Vector3(0.15, 0.92, 0.22), 0.30, 0.8)
	_expect(int(beautify.get("changed_voxels", 0)) > 0, "Automatic beautifier should round, seal, and clean the local clay volume")
	_expect(_checksum(shell) != beautify_before, "Automatic beautifier should bake a visible SDF refinement")

	var smooth_solid_before := int(shell.call("get_solid_voxel_count"))
	var smooth: Dictionary = shell.call("apply_smooth_stroke_local", Vector3(0.0, 0.9, 0.0), 0.55, 0.5)
	_expect(int(smooth.get("changed_voxels", 0)) > 0, "Smooth should relax nearby SDF voxels")
	_expect(abs(int(shell.call("get_solid_voxel_count")) - smooth_solid_before) < 360, "Smooth should displace clay locally instead of deleting or creating too much volume")

	var paint: Dictionary = shell.call("paint_sphere_local", Vector3(0.0, 0.9, 0.0), 0.45, Color(0.1, 0.8, 0.3, 1.0))
	_expect(int(paint.get("changed_voxels", 0)) > 0, "Paint should affect nearby solid voxel colors")

	var profile: Dictionary = shell.call("make_compact_profile")
	var replay: Node = FREEFORM_CLAY_SHELL_SCENE.instantiate()
	add_child(replay)
	await get_tree().process_frame
	_expect(bool(replay.call("apply_compact_profile", profile)), "Compact freeform profile should apply to a fresh shell")
	var replay_profile: Dictionary = replay.call("make_compact_profile")
	var first_delta_mismatch := _first_delta_mismatch(profile, replay_profile)
	_expect(replay_profile.get("checksum", -1) == profile.get("checksum", -2), "Compact freeform profile replay should be deterministic: original=%s replay=%s mismatch=%s" % [profile.get("checksum", -2), replay_profile.get("checksum", -1), first_delta_mismatch])

	var stress_start := Time.get_ticks_msec()
	for i in range(50):
		var angle := float(i) * 0.31
		var center := Vector3(cos(angle) * 0.24, 0.35 + float(i % 8) * 0.15, sin(angle) * 0.20)
		if i % 4 == 0:
			shell.call("apply_grab_stroke_local", center, Vector3(0.02, 0.0, 0.015), 0.28, 0.5)
		elif i % 4 == 1:
			shell.call("apply_push_pull_stroke_local", center, 0.035, 0.26, 0.7)
		elif i % 4 == 2:
			shell.call("apply_flatten_stroke_local", center, Vector3.UP, 0.30, 0.35)
		else:
			shell.call("apply_smooth_stroke_local", center, 0.30, 0.35)
	var stress_elapsed := Time.get_ticks_msec() - stress_start
	_expect(stress_elapsed < 5500, "Solid SDF sculpt strokes should stay within the playable prototype budget; elapsed=%dms" % stress_elapsed)
	_expect(int(shell.call("get_solid_voxel_count")) > initial_solid_count / 3, "Stress strokes should keep enough solid clay volume")
	var quality: Dictionary = shell.call("get_surface_quality_summary")
	_expect(float(quality.get("max_edge", 999.0)) < 0.35, "Repeated solid SDF sculpt strokes should not create long spike-sheet triangles: " + str(quality))
	_expect(int(quality.get("solid_count", 0)) > 0, "Repeated solid SDF sculpt strokes should leave a closed solid volume: " + str(quality))

	shell.queue_free()
	replay.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[FreeformClayShellTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[FreeformClayShellTest] " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _vertex_count(shell: Node) -> int:
	return int(shell.call("get_vertex_count"))


func _triangle_count(shell: Node) -> int:
	return int(shell.call("get_triangle_count"))


func _checksum(shell: Node) -> int:
	return int(shell.call("get_vertex_checksum"))


func _first_delta_mismatch(a: Dictionary, b: Dictionary) -> String:
	var left: Array = a.get("delta_q", [])
	var right: Array = b.get("delta_q", [])
	var count := mini(left.size(), right.size())
	for i in range(count):
		if int(left[i]) != int(right[i]):
			return "index=%d left=%s right=%s" % [i, left[i], right[i]]
	if left.size() != right.size():
		return "size=%d/%d" % [left.size(), right.size()]
	return "none"
