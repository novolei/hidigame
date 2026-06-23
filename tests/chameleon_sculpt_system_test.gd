extends Node3D

const FREEFORM_CLAY_SHELL_SCENE := preload("res://scenes/effects/freeform_clay_shell.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var body: Node = FREEFORM_CLAY_SHELL_SCENE.instantiate()
	add_child(body)
	await get_tree().process_frame

	_expect(_vertex_count(body) > 400, "Initial clay shell should generate a usable continuous surface")
	var body_mesh := body.get("body_mesh") as MeshInstance3D
	_expect(body_mesh != null and body_mesh.mesh != null and body_mesh.mesh.get_surface_count() > 0, "Initial clay shell should build a render mesh")
	var render_summary: Dictionary = body.call("get_render_mesh_summary")
	_expect(str(render_summary.get("mode", "")) == "smooth_sdf", "Initial clay shell should render as a smooth solid SDF mesh: " + str(render_summary))
	_expect(int(render_summary.get("vertex_count", 0)) > 400, "Solid shell should expose enough surface vertices for smooth sculpting: " + str(render_summary))
	_expect(int(body.call("count_solid_voxels_outside_edit_bounds")) == 0, "Initial freeform shell should stay inside the sculpt edit AABB")
	var bounds: AABB = body.call("get_solid_local_bounds")
	_expect(bounds.size.y > 1.65 and bounds.size.y < 1.95, "Basic asset shell should match the playable body height: " + str(bounds))
	_expect(bounds.size.x > 0.65 and bounds.size.x < 1.30, "Basic solid shell should preserve the Blender-baked body span without edit-bound clipping: " + str(bounds))
	_expect(bounds.size.z > 0.40 and bounds.size.z < 0.95, "Basic asset shell should preserve the Blender-baked body depth: " + str(bounds))

	var removed: Dictionary = body.call("apply_sculpt_stroke_local", "remove", Vector3(0.0, 1.52, 0.0), 0.46, 1.0)
	_expect(int(removed.get("changed_vertices", 0)) > 0, "Remove/deflate should affect nearby surface vertices")
	var outside: Dictionary = body.call("apply_sculpt_stroke_local", "add", Vector3(20.0, 20.0, 20.0), 0.46, 1.0)
	_expect(bool(outside.get("clamped", false)), "Out-of-bounds sculpt strokes should be clamped into the edit AABB")
	_expect(int(body.call("count_solid_voxels_outside_edit_bounds")) == 0, "Boundary clamp should keep edited vertices inside the AABB")

	body.call("apply_sculpt_stroke_local", "smooth", Vector3(0.0, 0.95, 0.0), 0.32, 1.0)
	var stress_start := Time.get_ticks_msec()
	for index in range(50):
		var tool := "add"
		if index % 3 == 1:
			tool = "remove"
		elif index % 3 == 2:
			tool = "smooth"
		var offset := Vector3(sin(float(index) * 0.9) * 0.32, 0.65 + float(index % 7) * 0.11, cos(float(index) * 0.7) * 0.24)
		body.call("apply_sculpt_stroke_local", tool, offset, 0.18 + float(index % 3) * 0.035, 0.75)
	var stress_elapsed := Time.get_ticks_msec() - stress_start
	_expect(stress_elapsed < 5500, "Repeated solid SDF sculpt strokes should stay within the playable prototype budget; elapsed=%dms" % stress_elapsed)
	_expect(int(body.call("get_solid_voxel_count")) > 0, "Repeated solid SDF strokes should preserve filled clay volume")

	var modified_checksum := _checksum(body)
	body.call("soft_reset_sphere_local", Vector3(0.0, 0.95, 0.0), 0.42, 0.5)
	_expect(_checksum(body) != modified_checksum, "Counterplay soft reset should change edited vertices toward the base shell")
	var profile: Dictionary = body.call("make_compact_body")
	var replay: Node = FREEFORM_CLAY_SHELL_SCENE.instantiate()
	add_child(replay)
	await get_tree().process_frame
	_expect(bool(replay.call("apply_compact_body", profile)), "Compact solid SDF body should apply to the replay shell")
	var replay_profile: Dictionary = replay.call("make_compact_body")
	_expect(replay_profile.get("checksum", -1) == profile.get("checksum", -2), "Compact solid SDF body replay should be deterministic")

	var owner := CharacterBody3D.new()
	owner.name = "SculptOwner"
	add_child(owner)
	var camera := Camera3D.new()
	camera.name = "SculptCamera"
	add_child(camera)
	camera.current = true
	camera.global_position = Vector3(0.0, 0.95, 3.0)
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	var anchor_surface := StaticBody3D.new()
	anchor_surface.name = "PointerAnchorSurface"
	add_child(anchor_surface)
	anchor_surface.global_position = Vector3(0.0, 0.95, 0.0)
	var anchor_shape := CollisionShape3D.new()
	var anchor_box := BoxShape3D.new()
	anchor_box.size = Vector3(3.0, 3.0, 0.08)
	anchor_shape.shape = anchor_box
	anchor_surface.add_child(anchor_shape)
	await get_tree().physics_frame
	var system := ChameleonSculptSystem.new()
	owner.add_child(system)
	system.initialize(owner, camera)
	system.activate()
	_expect(system.is_shell_active(), "ChameleonSculptSystem should spawn and show a freeform clay shell on activation")
	_expect(str(system.shell.name) == "FreeformClayShell", "ChameleonSculptSystem should use the freeform shell scene")
	_expect(str(system.get_debug_summary().get("sculpt_tool", "")) == "smart", "ChameleonSculptSystem should default to the easy Smart sculpt tool")
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	system.call("_place_shell_at_pointer_or_owner", screen_center)
	_expect(absf(system.anchor_position.z) < 0.08 and absf(system.anchor_position.y - 0.95) < 0.08, "Clone shell should appear immediately at the mouse-pointer surface after entering the skill")
	var standing_contact: Vector3 = system.shell.global_transform * (system.call("_anchor_contact_point_local") as Vector3)
	_expect(standing_contact.distance_to(system.anchor_position + system.anchor_normal.normalized() * 0.05) < 0.02, "Clone shell contact point should follow the pointer anchor surface")
	system.set("anchor_normal", Vector3.RIGHT)
	system.set_anchor_snap_axis("x")
	system.call("_place_shell_at_anchor")
	_expect(absf(system.shell.global_transform.basis.x.normalized().dot(Vector3.RIGHT)) > 0.98, "Anchor snap axis X should align the clone shell X axis to the target surface normal")
	system.set_anchor_snap_axis("z")
	system.call("_place_shell_at_anchor")
	_expect(absf(system.shell.global_transform.basis.z.normalized().dot(Vector3.RIGHT)) > 0.98, "Anchor snap axis Z should align the clone shell Z axis to the target surface normal")
	var rotated_basis := system.shell.global_transform.basis
	system.rotate_anchor_shell(Vector2(80.0, 20.0), false)
	_expect(system.shell.global_transform.basis != rotated_basis, "Right-drag anchor rotation should change the clone shell orientation while keeping the selected snap axis active")
	system.set("anchor_normal", Vector3.UP)
	system.set_anchor_pose("standing")
	system.handle_skill_input(_mouse_button_event(MOUSE_BUTTON_RIGHT, true, screen_center))
	system.handle_skill_input(_mouse_button_event(MOUSE_BUTTON_RIGHT, false, screen_center))
	_expect(str(system.get_debug_summary().get("anchor_pose", "")) == "prone", "Right-click should cycle the clone from standing to prone belly-down placement")
	_expect((system.shell.global_transform.basis * Vector3.FORWARD).normalized().dot(Vector3.UP) > 0.98, "Prone anchor pose should place the clone's body-depth axis against the surface normal")
	var prone_contact: Vector3 = system.shell.global_transform * (system.call("_anchor_contact_point_local") as Vector3)
	_expect(prone_contact.distance_to(system.anchor_position + system.anchor_normal.normalized() * 0.05) < 0.02, "Prone anchor pose should keep the body-center contact point on the selected surface")
	system.handle_skill_input(_mouse_button_event(MOUSE_BUTTON_RIGHT, true, screen_center))
	system.handle_skill_input(_mouse_button_event(MOUSE_BUTTON_RIGHT, false, screen_center))
	_expect(str(system.get_debug_summary().get("anchor_pose", "")) == "side", "Second right-click should cycle the clone into side-shoulder placement")
	_expect((system.shell.global_transform.basis * Vector3.LEFT).normalized().dot(Vector3.UP) > 0.98, "Side anchor pose should place the clone's shoulder axis against the surface normal")
	system.set("anchor_normal", Vector3.UP)
	system.set_anchor_snap_axis("y")
	system.call("_place_shell_at_owner")
	var screen_hit: Dictionary = system.call("_raycast_shell_screen", screen_center)
	_expect(not screen_hit.is_empty(), "ChameleonSculptSystem should raycast the freeform shell mesh for sculpt input")
	var tool_surface: Dictionary = system.get_tool_surface_at_screen(screen_center)
	_expect(not tool_surface.is_empty() and tool_surface.has("normal"), "ChameleonSculptSystem should expose a shell-locked sculpt tool surface for the 3D brush head")
	system.set_sculpt_tool("smart")
	var queued_stroke_before := int(system.shell.call("get_vertex_checksum"))
	system.handle_skill_input(_mouse_button_event(MOUSE_BUTTON_LEFT, true, screen_center))
	system.handle_skill_input(_mouse_motion_event(screen_center + Vector2(4.0, 0.0), Vector2(4.0, 0.0)))
	var queued_summary: Dictionary = system.get_debug_summary().get("clay_command_queue", {})
	_expect(int(queued_summary.get("pending", 0)) > 0, "Held-left-button sculpting should queue ClayCommands instead of baking SDF immediately")
	_expect(int(queued_summary.get("preview_instances", 0)) > 0, "Queued ClayCommands should show lightweight realtime clay proxy previews")
	_expect(int(system.shell.call("get_vertex_checksum")) == queued_stroke_before, "Realtime clay proxy preview should not rebuild or deform the SDF mesh while the mouse is held")
	system.handle_skill_input(_mouse_button_event(MOUSE_BUTTON_LEFT, false, screen_center + Vector2(4.0, 0.0)))
	_expect(int(system.shell.call("get_vertex_checksum")) != queued_stroke_before, "Releasing left mouse should bake queued ClayCommands into the SDF shell")
	var release_summary: Dictionary = system.get_debug_summary().get("clay_command_queue", {})
	_expect(int(release_summary.get("pending", -1)) == 0, "ClayCommand queue should be empty after release bake")
	var screen_stroke_before := int(system.shell.call("get_vertex_checksum"))
	system.call("_request_sculpt_at_screen", screen_center, true)
	_expect(int(system.shell.call("get_vertex_checksum")) != screen_stroke_before, "Screen sculpt request should deform the freeform shell without a physics collision body")
	system.set_sculpt_tool("add")
	var stroke_position := system.shell.global_transform * Vector3(0.0, 0.95, 0.0)
	_expect(system.validate_sculpt_stroke_batch(
		PackedStringArray(["smart", "stretch", "flatten"]),
		PackedVector3Array([stroke_position, stroke_position, stroke_position]),
		PackedFloat32Array([0.22, 0.22, 0.22])
	), "ChameleonSculptSystem should accept Smart, Stretch, and Flatten sculpt tools for replicated batches")
	system.apply_sculpt_stroke_batch(
		PackedStringArray(["add", "stretch", "flatten"]),
		PackedVector3Array([stroke_position, stroke_position, stroke_position]),
		PackedFloat32Array([0.22, 0.22, 0.22]),
		PackedFloat32Array([1.0, 0.8, 0.8])
	)
	system.apply_sculpt_stroke_batch(
		PackedStringArray(["add", "add"]),
		PackedVector3Array([stroke_position, stroke_position + Vector3(0.16, 0.0, 0.0)]),
		PackedFloat32Array([0.20, 0.20]),
		PackedFloat32Array([0.7, 0.7])
	)
	var stroke_log: Array = system.get("stroke_log")
	_expect(not stroke_log.is_empty() and str((stroke_log[stroke_log.size() - 1] as Dictionary).get("stroke_shape", "")) == "capsule", "Held-left-button sculpting should be applied as a continuous rounded capsule stroke")
	_expect(bool((stroke_log[stroke_log.size() - 1] as Dictionary).get("auto_completion", false)), "Sculpt strokes should generate a lightweight auto-completion polish pass")
	system.set_sculpt_tool("stretch")
	_expect(str(system.get_debug_summary().get("sculpt_tool", "")) == "smart", "Legacy Stretch input should collapse into the easier Smart Shape player tool")
	system.set_sculpt_tool("flatten")
	_expect(str(system.get_debug_summary().get("sculpt_tool", "")) == "flatten", "Sculpt system should expose Flatten as a selectable player tool")
	system.set_sculpt_tool("erase")
	_expect(str(system.get_debug_summary().get("sculpt_tool", "")) == "remove", "Erase/Cut aliases should map to the simple Cut player tool")
	var summary: Dictionary = system.get_debug_summary()
	_expect(str(summary.get("shell_kind", "")) == "solid_sdf_clay", "Sculpt system debug summary should report the solid SDF clay shell")
	var assist: Dictionary = summary.get("tool_assist", {})
	_expect((assist.get("visible_tools", []) as Array).size() == 3, "Sculpt UI should collapse to Smart Shape, Flatten, and Cut tools")
	var queue_summary: Dictionary = summary.get("clay_command_queue", {})
	var last_commit: Dictionary = queue_summary.get("last_commit", {})
	_expect(int(last_commit.get("auto_beautify_passes", 0)) > 0, "Release bake should run automatic clay beautifier passes")
	_expect(int(summary.get("stroke_count", 0)) >= 2, "Screen sculpt request and local sculpt batch should both be applied and logged")
	_expect(system.commit_current_shape(), "Committing the current freeform shape should succeed")
	_expect(system.get_shape_commit_cooldown_remaining() > 1.0, "Committing a sculpted shape should start a short cooldown")
	_expect(not system.commit_current_shape(), "Shape commit should be rejected while the cooldown is active")

	body.queue_free()
	replay.queue_free()
	anchor_surface.queue_free()
	owner.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[ChameleonSculptSystemTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[ChameleonSculptSystemTest] " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _vertex_count(shell: Node) -> int:
	return int(shell.call("get_vertex_count"))


func _checksum(shell: Node) -> int:
	return int(shell.call("get_vertex_checksum"))


func _mouse_button_event(button_index: MouseButton, pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = position
	return event


func _mouse_motion_event(position: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	return event
