extends Node
class_name ChameleonSculptSystem

const FREEFORM_CLAY_SHELL_SCENE := preload("res://scenes/effects/freeform_clay_shell.tscn")
const MODE_PAINT := "paint"
const MODE_SCULPT := "sculpt"
const STATE_INACTIVE := "inactive"
const STATE_ANCHOR_PICK := "anchor_pick"
const STATE_SHELL_ACTIVE := "shell_active"
const WORLD_RAY_LENGTH := 36.0
const SCULPT_COOLDOWN := 0.05
const CONTINUOUS_STROKE_MAX_GAP_MSEC := 180
const CONTINUOUS_STROKE_MAX_SEGMENT := 1.15
const AUTO_COMPLETION_STRENGTH := 0.22
const AUTO_COMPLETION_INTERVAL := 2
const AUTO_BEAUTIFY_MAX_PASSES := 3
const CLAY_COMMAND_MAX_PENDING := 48
const CLAY_COMMAND_COMMIT_MAX := 16
const CLAY_COMMAND_MIN_SPACING_RATIO := 0.24
const CLAY_PREVIEW_MAX_INSTANCES := 6
const CLAY_PREVIEW_UPDATE_INTERVAL := 2
const SHAPE_COMMIT_COOLDOWN := 1.2
const ANCHOR_ROTATE_SENSITIVITY := 0.008
const ANCHOR_CLICK_DRAG_THRESHOLD := 6.0
const ANCHOR_POSE_STANDING := "standing"
const ANCHOR_POSE_PRONE := "prone"
const ANCHOR_POSE_SIDE := "side"
const ANCHOR_POSE_MANUAL := "manual"
const ANCHOR_POSE_SEQUENCE := [ANCHOR_POSE_STANDING, ANCHOR_POSE_PRONE, ANCHOR_POSE_SIDE]
const TOOL_ADD := "add"
const TOOL_REMOVE := "remove"
const TOOL_SMOOTH := "smooth"
const TOOL_STRETCH := "stretch"
const TOOL_FLATTEN := "flatten"
const TOOL_SMART := "smart"
const MIN_SCULPT_RADIUS := 0.08
const MAX_SCULPT_RADIUS := 0.46
const DEFAULT_SCULPT_RADIUS := 0.22

var sculpt_owner: CharacterBody3D = null
var camera: Camera3D = null
var shell: Node3D = null
var active := false
var state := STATE_INACTIVE
var edit_mode := MODE_PAINT
var sculpt_tool := TOOL_SMART
var brush_radius := DEFAULT_SCULPT_RADIUS
var anchor_position := Vector3.ZERO
var anchor_normal := Vector3.UP
var anchor_collider_path := NodePath("")
var anchor_snap_axis := "y"
var anchor_pose := ANCHOR_POSE_STANDING
var stroke_log: Array[Dictionary] = []
var last_committed_body := {}

var _sculpting := false
var _rotating_anchor_shell := false
var _anchor_right_drag_distance := 0.0
var _cooldown_remaining := 0.0
var _shape_commit_cooldown_remaining := 0.0
var _anchor_user_rotation := Basis.IDENTITY
var _has_last_sculpt_point := false
var _last_sculpt_world_point := Vector3.ZERO
var _last_sculpt_tool := ""
var _last_sculpt_radius := 0.0
var _last_sculpt_msec := 0
var _pending_clay_commands: Array[Dictionary] = []
var _last_clay_command_commit := {}
var _preview_root: Node3D = null
var _preview_instances: Array[MeshInstance3D] = []
var _preview_sphere_mesh: SphereMesh = null
var _preview_materials: Dictionary = {}


func initialize(owner_node: CharacterBody3D, owner_camera: Camera3D) -> void:
	sculpt_owner = owner_node
	camera = owner_camera


func _process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if _shape_commit_cooldown_remaining > 0.0:
		_shape_commit_cooldown_remaining = maxf(0.0, _shape_commit_cooldown_remaining - delta)


func activate() -> void:
	if active:
		return
	active = true
	state = STATE_ANCHOR_PICK
	edit_mode = MODE_PAINT
	sculpt_tool = TOOL_SMART
	anchor_pose = ANCHOR_POSE_STANDING
	anchor_snap_axis = "y"
	_sculpting = false
	_rotating_anchor_shell = false
	_anchor_right_drag_distance = 0.0
	_anchor_user_rotation = Basis.IDENTITY
	_reset_continuous_sculpt_stroke()
	_discard_pending_clay_commands()
	_ensure_shell()
	_place_shell_at_owner()
	_reset_shell_from_owner_visual()
	_place_shell_at_pointer_or_owner()
	if shell:
		shell.visible = true
		_log_shell_spawn_summary()
	if sculpt_owner and sculpt_owner.has_method("set_chameleon_sculpt_shell_active"):
		sculpt_owner.call("set_chameleon_sculpt_shell_active", true, shell.global_transform)


func deactivate(should_restore_real_body: bool = true) -> void:
	if not active and not shell:
		return
	if should_restore_real_body:
		restore_real_body()
	else:
		_hide_shell()
	active = false
	state = STATE_INACTIVE
	_sculpting = false
	_rotating_anchor_shell = false
	_anchor_right_drag_distance = 0.0
	_reset_continuous_sculpt_stroke()
	_discard_pending_clay_commands()


func restore_real_body() -> void:
	var restore_transform: Transform3D = shell.global_transform if shell and is_instance_valid(shell) else Transform3D.IDENTITY
	if sculpt_owner and sculpt_owner.has_method("set_chameleon_sculpt_shell_active"):
		sculpt_owner.call("set_chameleon_sculpt_shell_active", false, restore_transform)
	_hide_shell()
	active = false
	state = STATE_INACTIVE
	_sculpting = false
	_rotating_anchor_shell = false
	_anchor_right_drag_distance = 0.0
	_reset_continuous_sculpt_stroke()
	_discard_pending_clay_commands()


func handle_skill_input(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				toggle_edit_mode()
				return true
			KEY_Q, KEY_0:
				set_sculpt_tool(TOOL_SMART)
				return true
			KEY_X:
				if state == STATE_ANCHOR_PICK:
					set_anchor_snap_axis("x")
					return true
			KEY_Y:
				if state == STATE_ANCHOR_PICK:
					set_anchor_snap_axis("y")
					return true
			KEY_Z:
				if state == STATE_ANCHOR_PICK:
					set_anchor_snap_axis("z")
					return true
			KEY_1:
				set_sculpt_tool(TOOL_SMART)
				return true
			KEY_2:
				set_sculpt_tool(TOOL_FLATTEN)
				return true
			KEY_3:
				set_sculpt_tool(TOOL_REMOVE)
				return true
			KEY_4:
				set_sculpt_tool(TOOL_SMART)
				return true
			KEY_5:
				set_sculpt_tool(TOOL_FLATTEN)
				return true
			KEY_E:
				state = STATE_ANCHOR_PICK
				return true
			KEY_R:
				if sculpt_owner and sculpt_owner.has_method("deactivate_camouflage_skill"):
					sculpt_owner.call("deactivate_camouflage_skill")
				else:
					restore_real_body()
				return true
			KEY_ENTER, KEY_KP_ENTER:
				commit_current_shape()
				return true
	if state == STATE_ANCHOR_PICK:
		return _handle_anchor_input(event)
	if edit_mode != MODE_SCULPT:
		return false
	return _handle_sculpt_input(event)


func blocks_camouflage_paint_tick() -> bool:
	return active and (state == STATE_ANCHOR_PICK or edit_mode == MODE_SCULPT)


func is_shell_active() -> bool:
	return active and shell and is_instance_valid(shell) and shell.visible


func is_paint_mode() -> bool:
	return edit_mode == MODE_PAINT and state == STATE_SHELL_ACTIVE


func toggle_edit_mode() -> void:
	if edit_mode == MODE_SCULPT:
		_commit_pending_clay_commands()
	edit_mode = MODE_SCULPT if edit_mode == MODE_PAINT else MODE_PAINT
	if state == STATE_ANCHOR_PICK:
		state = STATE_SHELL_ACTIVE


func set_sculpt_tool(tool_name: String) -> void:
	_commit_pending_clay_commands()
	sculpt_tool = _normalize_player_tool_name(tool_name)
	_reset_continuous_sculpt_stroke()
	edit_mode = MODE_SCULPT
	if state == STATE_ANCHOR_PICK:
		state = STATE_SHELL_ACTIVE


func set_brush_radius(radius: float) -> void:
	brush_radius = clampf(radius, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS)
	_reset_continuous_sculpt_stroke()


func set_anchor_snap_axis(axis_name: String) -> void:
	match axis_name.to_lower():
		"x", "y", "z":
			anchor_snap_axis = axis_name.to_lower()
			anchor_pose = ANCHOR_POSE_MANUAL
	if state == STATE_ANCHOR_PICK:
		_place_shell_at_anchor()


func set_anchor_pose(pose_name: String) -> void:
	match pose_name:
		ANCHOR_POSE_STANDING, ANCHOR_POSE_PRONE, ANCHOR_POSE_SIDE:
			anchor_pose = pose_name
			anchor_snap_axis = _axis_name_for_anchor_pose(anchor_pose)
			_anchor_user_rotation = Basis.IDENTITY
		_:
			return
	if state == STATE_ANCHOR_PICK:
		_place_shell_at_anchor()


func cycle_anchor_pose() -> void:
	var current_index := ANCHOR_POSE_SEQUENCE.find(anchor_pose)
	if current_index < 0:
		current_index = 0
	set_anchor_pose(str(ANCHOR_POSE_SEQUENCE[(current_index + 1) % ANCHOR_POSE_SEQUENCE.size()]))


func rotate_anchor_shell(relative: Vector2, roll_only: bool = false) -> void:
	if relative.length_squared() <= 0.0001:
		return
	var yaw_basis := Basis.IDENTITY
	var pitch_basis := Basis.IDENTITY
	var roll_basis := Basis.IDENTITY
	if roll_only:
		roll_basis = Basis(_snap_axis_vector(), -relative.x * ANCHOR_ROTATE_SENSITIVITY)
	else:
		yaw_basis = Basis(Vector3.UP, -relative.x * ANCHOR_ROTATE_SENSITIVITY)
		pitch_basis = Basis(Vector3.RIGHT, -relative.y * ANCHOR_ROTATE_SENSITIVITY)
	_anchor_user_rotation = (yaw_basis * pitch_basis * roll_basis * _anchor_user_rotation).orthonormalized()
	_place_shell_at_anchor()


func commit_current_shape() -> bool:
	_commit_pending_clay_commands()
	if _shape_commit_cooldown_remaining > 0.0:
		return false
	if not shell or not is_instance_valid(shell) or not shell.has_method("make_compact_body"):
		return false
	last_committed_body = shell.call("make_compact_body")
	_shape_commit_cooldown_remaining = SHAPE_COMMIT_COOLDOWN
	return true


func get_shape_commit_cooldown_remaining() -> float:
	return _shape_commit_cooldown_remaining


func get_tool_surface_at_screen(screen_position: Vector2) -> Dictionary:
	if not active or state == STATE_INACTIVE:
		return {}
	var hit := _raycast_shell_screen(screen_position)
	if not hit.is_empty():
		hit["screen"] = screen_position
	return hit


func apply_sculpt_stroke_batch(
	tool_names: PackedStringArray,
	world_positions: PackedVector3Array,
	radii: PackedFloat32Array,
	strengths: PackedFloat32Array = PackedFloat32Array()
) -> void:
	_ensure_shell()
	if not active:
		active = true
		state = STATE_SHELL_ACTIVE
		edit_mode = MODE_SCULPT
		shell.visible = true
	var count := mini(tool_names.size(), world_positions.size())
	if count <= 0:
		return
	if shell.has_method("begin_sculpt_batch"):
		shell.call("begin_sculpt_batch")
	var beautify_passes := 0
	for i in range(count):
		var radius: float = brush_radius
		if i < radii.size():
			radius = radii[i]
		var strength := 1.0
		if i < strengths.size():
			strength = strengths[i]
		var requested_tool_name := str(tool_names[i])
		var tool_name := _normalize_player_tool_name(requested_tool_name)
		var end_position := world_positions[i]
		var start_position := _continuous_sculpt_start(tool_name, end_position, radius)
		var summary: Dictionary = {}
		if shell.has_method("apply_sculpt_capsule_stroke_world"):
			summary = shell.call("apply_sculpt_capsule_stroke_world", tool_name, start_position, end_position, radius, strength)
		else:
			summary = shell.call("apply_sculpt_stroke_world", tool_name, end_position, radius, strength)
		var should_complete := i == 0 or i == count - 1 or i % AUTO_COMPLETION_INTERVAL == 0
		var completion := _apply_auto_completion(tool_name, start_position, end_position, radius, strength) if should_complete else {}
		_remember_continuous_sculpt_point(tool_name, end_position, radius)
		stroke_log.append({
			"tool": summary.get("tool", tool_name),
			"requested_tool": requested_tool_name,
			"world_position": end_position,
			"world_start": start_position,
			"radius": radius,
			"strength": strength,
			"stroke_shape": "capsule",
			"auto_completion": not completion.is_empty(),
			"completion_tool": completion.get("tool", ""),
		})
	beautify_passes = _apply_auto_beautify(tool_names, world_positions, radii, strengths, count)
	if shell.has_method("end_sculpt_batch"):
		shell.call("end_sculpt_batch")
	_cache_current_shape_body()
	_last_clay_command_commit = {
		"pipeline": "clay_command_queue",
		"baked_commands": count,
		"auto_beautify_passes": beautify_passes,
		"mesh_bake": "solid_sdf_batch",
		"synced": true,
		"cached_body": not last_committed_body.is_empty(),
	}


func _continuous_sculpt_start(tool_name: String, end_position: Vector3, radius: float) -> Vector3:
	var now := Time.get_ticks_msec()
	if not _has_last_sculpt_point:
		return end_position
	if tool_name != _last_sculpt_tool:
		return end_position
	if absf(radius - _last_sculpt_radius) > maxf(0.03, radius * 0.35):
		return end_position
	if now - _last_sculpt_msec > CONTINUOUS_STROKE_MAX_GAP_MSEC:
		return end_position
	if _last_sculpt_world_point.distance_to(end_position) > CONTINUOUS_STROKE_MAX_SEGMENT:
		return end_position
	return _last_sculpt_world_point


func _remember_continuous_sculpt_point(tool_name: String, end_position: Vector3, radius: float) -> void:
	_has_last_sculpt_point = true
	_last_sculpt_world_point = end_position
	_last_sculpt_tool = tool_name
	_last_sculpt_radius = radius
	_last_sculpt_msec = Time.get_ticks_msec()


func _reset_continuous_sculpt_stroke() -> void:
	_has_last_sculpt_point = false
	_last_sculpt_world_point = Vector3.ZERO
	_last_sculpt_tool = ""
	_last_sculpt_radius = 0.0
	_last_sculpt_msec = 0


func _apply_auto_completion(tool_name: String, start_position: Vector3, end_position: Vector3, radius: float, strength: float) -> Dictionary:
	if not shell or not is_instance_valid(shell) or not shell.has_method("apply_sculpt_capsule_stroke_world"):
		return {}
	var clean_tool := _normalize_player_tool_name(tool_name)
	if clean_tool == TOOL_SMOOTH:
		return {}
	var completion_radius := clampf(radius * (0.72 if clean_tool == TOOL_SMART else 0.88), MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS)
	var completion_strength := clampf(AUTO_COMPLETION_STRENGTH * strength * (0.55 if clean_tool == TOOL_SMART else 1.0), 0.0, 0.5)
	if completion_strength <= 0.001:
		return {}
	return shell.call("apply_sculpt_capsule_stroke_world", TOOL_SMOOTH, start_position, end_position, completion_radius, completion_strength)


func _apply_auto_beautify(
	tool_names: PackedStringArray,
	world_positions: PackedVector3Array,
	radii: PackedFloat32Array,
	strengths: PackedFloat32Array,
	count: int
) -> int:
	if count <= 1 or not shell or not is_instance_valid(shell) or not shell.has_method("apply_sculpt_capsule_stroke_world"):
		return 0
	var step := maxi(1, ceili(float(count) / float(AUTO_BEAUTIFY_MAX_PASSES)))
	var applied := 0
	for i in range(0, count, step):
		if applied >= AUTO_BEAUTIFY_MAX_PASSES:
			break
		var tool_name := _normalize_player_tool_name(str(tool_names[i]))
		if tool_name == TOOL_SMOOTH:
			continue
		var radius: float = radii[i] if i < radii.size() else brush_radius
		var strength: float = strengths[i] if i < strengths.size() else 1.0
		var end_position := world_positions[i]
		var start_position := world_positions[maxi(0, i - 1)]
		if shell.has_method("apply_beautify_capsule_world"):
			shell.call("apply_beautify_capsule_world", tool_name, start_position, end_position, radius, strength)
		else:
			var polish_radius := clampf(radius * 1.18, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS)
			var polish_strength := clampf(0.10 + strength * 0.08, 0.08, 0.22)
			shell.call("apply_sculpt_capsule_stroke_world", TOOL_SMOOTH, start_position, end_position, polish_radius, polish_strength)
		applied += 1
	return applied


func validate_sculpt_stroke_batch(tool_names: PackedStringArray, world_positions: PackedVector3Array, radii: PackedFloat32Array) -> bool:
	if tool_names.is_empty() or world_positions.is_empty() or tool_names.size() != world_positions.size():
		return false
	if tool_names.size() > 16:
		return false
	for i in range(tool_names.size()):
		if not _is_supported_tool_alias(str(tool_names[i])):
			return false
		var radius: float = radii[i] if i < radii.size() else brush_radius
		if radius < MIN_SCULPT_RADIUS or radius > MAX_SCULPT_RADIUS:
			return false
		if shell and is_instance_valid(shell) and shell.has_method("_clamp_point_to_aabb") and shell.has_method("get_edit_bounds"):
			var local: Vector3 = shell.to_local(world_positions[i])
			var clamped: Vector3 = shell.call("_clamp_point_to_aabb", local, shell.call("get_edit_bounds"))
			if local.distance_to(clamped) > radius + 0.35:
				return false
	return true


func get_debug_summary() -> Dictionary:
	return {
		"active": active,
		"state": state,
		"edit_mode": edit_mode,
		"sculpt_tool": sculpt_tool,
		"brush_radius": brush_radius,
		"anchor_position": anchor_position,
		"anchor_normal": anchor_normal,
		"anchor_snap_axis": anchor_snap_axis,
		"anchor_pose": anchor_pose,
		"shell_kind": _shell_kind(),
		"solid_count": int(shell.call("get_vertex_count")) if shell and shell.has_method("get_vertex_count") else 0,
		"surface_vertices": int(shell.call("get_vertex_count")) if shell and shell.has_method("get_vertex_count") else 0,
		"surface_triangles": int(shell.call("get_triangle_count")) if shell and shell.has_method("get_triangle_count") else 0,
		"shell_visible": bool(shell.visible) if shell and is_instance_valid(shell) else false,
		"shell_global_position": shell.global_position if shell and is_instance_valid(shell) else Vector3.ZERO,
		"shell_bounds": shell.call("get_local_bounds") if shell and shell.has_method("get_local_bounds") else AABB(),
		"source_mesh": shell.call("get_source_mesh_summary") if shell and shell.has_method("get_source_mesh_summary") else {},
		"anchors": shell.call("get_anchor_integrity") if shell and shell.has_method("get_anchor_integrity") else {},
		"performance": shell.call("get_performance_summary") if shell and shell.has_method("get_performance_summary") else {},
		"tool_assist": _tool_assist_summary(),
		"stroke_count": stroke_log.size(),
		"clay_command_queue": _clay_command_queue_summary(),
		"shape_commit_cooldown": _shape_commit_cooldown_remaining,
		"has_committed_body": not last_committed_body.is_empty(),
	}


func _tool_assist_summary() -> Dictionary:
	return {
		"default_tool": TOOL_SMART,
		"active_tool": sculpt_tool,
		"display_tool": _display_tool_name(sculpt_tool),
		"visible_tools": ["Smart Shape", "Flatten", "Cut"],
		"auto_completion": sculpt_tool != TOOL_REMOVE,
		"auto_beautify": ["round", "seal", "despike", "volume"],
		"continuous_capsule_stroke": true,
		"recommended_radius": clampf(brush_radius, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS),
	}


func _clay_command_queue_summary() -> Dictionary:
	return {
		"pending": _pending_clay_commands.size(),
		"preview_instances": _visible_preview_instance_count(),
		"commit_max": CLAY_COMMAND_COMMIT_MAX,
		"last_commit": _last_clay_command_commit.duplicate(true),
	}


func _shell_kind() -> String:
	if shell and shell.has_method("get_render_mesh_summary"):
		var render_summary: Dictionary = shell.call("get_render_mesh_summary")
		if str(render_summary.get("mode", "")) == "smooth_sdf":
			return "solid_sdf_clay"
	return "freeform_clay_surface"


func apply_counterplay_soft_reset(world_position: Vector3, world_radius: float, amount: float = 0.35) -> void:
	if not shell or not is_instance_valid(shell):
		return
	if shell.has_method("soft_reset_sphere_world"):
		shell.call("soft_reset_sphere_world", world_position, world_radius, amount)


func _handle_anchor_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if _rotating_anchor_shell and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			var relative := (event as InputEventMouseMotion).relative
			_anchor_right_drag_distance += relative.length()
			if _anchor_right_drag_distance > ANCHOR_CLICK_DRAG_THRESHOLD:
				rotate_anchor_shell(relative, Input.is_key_pressed(KEY_SHIFT))
			return true
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			return false
		_update_anchor_from_screen((event as InputEventMouseMotion).position, false)
		return true
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_update_anchor_from_screen(mouse_button.position, true)
			state = STATE_SHELL_ACTIVE
			return true
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_button.pressed:
				_rotating_anchor_shell = true
				_anchor_right_drag_distance = 0.0
			else:
				if _rotating_anchor_shell and _anchor_right_drag_distance <= ANCHOR_CLICK_DRAG_THRESHOLD:
					cycle_anchor_pose()
				_rotating_anchor_shell = false
			return true
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			return false
	return true


func _handle_sculpt_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		match mouse_button.button_index:
			MOUSE_BUTTON_LEFT:
				_sculpting = mouse_button.pressed
				if mouse_button.pressed:
					_reset_continuous_sculpt_stroke()
					_begin_clay_command_stroke()
					_request_sculpt_at_screen(mouse_button.position, true)
				else:
					_request_sculpt_at_screen(mouse_button.position, true)
					_commit_pending_clay_commands()
					_reset_continuous_sculpt_stroke()
				return true
			MOUSE_BUTTON_RIGHT:
				return false
			MOUSE_BUTTON_MIDDLE:
				return false
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				return false
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			return false
		if _sculpting and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_request_sculpt_at_screen(motion.position)
			return true
		return true
	return false


func _request_sculpt_at_screen(screen_position: Vector2, force_sample: bool = false) -> bool:
	if not force_sample and _cooldown_remaining > 0.0:
		return false
	var hit := _raycast_shell_screen(screen_position)
	if hit.is_empty():
		return false
	var accepted := _queue_clay_command(hit)
	if not accepted:
		return false
	if _should_refresh_clay_preview(force_sample):
		_sync_clay_command_preview()
	if not _sculpting:
		_commit_pending_clay_commands()
	_cooldown_remaining = SCULPT_COOLDOWN
	return true


func _submit_sculpt_command_batch(commands: Array[Dictionary]) -> void:
	if commands.is_empty():
		return
	var tools := PackedStringArray()
	var positions := PackedVector3Array()
	var radii := PackedFloat32Array()
	var strengths := PackedFloat32Array()
	for command in commands:
		tools.append(str(command.get("tool", sculpt_tool)))
		positions.append(command.get("position", Vector3.ZERO) as Vector3)
		radii.append(float(command.get("radius", brush_radius)))
		strengths.append(float(command.get("strength", 1.0)))
	if sculpt_owner and sculpt_owner.has_method("submit_sculpt_stroke_batch"):
		sculpt_owner.call("submit_sculpt_stroke_batch", tools, positions, radii, strengths)
	else:
		apply_sculpt_stroke_batch(tools, positions, radii, strengths)


func _begin_clay_command_stroke() -> void:
	_pending_clay_commands.clear()
	_clear_clay_command_preview()


func _queue_clay_command(hit: Dictionary) -> bool:
	var position: Vector3 = hit.get("position", Vector3.ZERO)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	if normal.length_squared() <= 0.0001:
		normal = Vector3.UP
	normal = normal.normalized()
	var clean_tool := _normalize_player_tool_name(sculpt_tool)
	var clean_radius := clampf(brush_radius, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS)
	if not _should_accept_clay_command(position, clean_tool, clean_radius):
		return false
	var command := {
		"tool": clean_tool,
		"position": position,
		"normal": normal,
		"radius": clean_radius,
		"strength": 1.0,
		"time_msec": Time.get_ticks_msec(),
	}
	_pending_clay_commands.append(command)
	if _pending_clay_commands.size() > CLAY_COMMAND_MAX_PENDING:
		_pending_clay_commands.remove_at(1 if _pending_clay_commands.size() > 2 else 0)
	return true


func _should_refresh_clay_preview(force_sample: bool) -> bool:
	return force_sample or _pending_clay_commands.size() <= 1 or _pending_clay_commands.size() % CLAY_PREVIEW_UPDATE_INTERVAL == 0


func _should_accept_clay_command(position: Vector3, tool_name: String, radius: float) -> bool:
	if _pending_clay_commands.is_empty():
		return true
	var last: Dictionary = _pending_clay_commands[_pending_clay_commands.size() - 1]
	if str(last.get("tool", "")) != tool_name:
		return true
	if absf(float(last.get("radius", radius)) - radius) > maxf(0.02, radius * 0.2):
		return true
	var last_position: Vector3 = last.get("position", Vector3.ZERO)
	var min_spacing := maxf(0.025, radius * CLAY_COMMAND_MIN_SPACING_RATIO)
	return last_position.distance_to(position) >= min_spacing


func _commit_pending_clay_commands() -> bool:
	if _pending_clay_commands.is_empty():
		_clear_clay_command_preview()
		return false
	var queued_count := _pending_clay_commands.size()
	var commands := _compact_clay_commands(_pending_clay_commands)
	_last_clay_command_commit = {
		"pipeline": "clay_command_queue",
		"queued_commands": queued_count,
		"submitted_commands": commands.size(),
		"mesh_bake": "release_deferred_sdf_batch",
		"preview_instances": _visible_preview_instance_count(),
		"synced": sculpt_owner != null and sculpt_owner.has_method("submit_sculpt_stroke_batch"),
	}
	_pending_clay_commands.clear()
	_clear_clay_command_preview()
	_reset_continuous_sculpt_stroke()
	_submit_sculpt_command_batch(commands)
	return true


func _compact_clay_commands(commands: Array[Dictionary]) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for command in commands:
		if filtered.is_empty():
			filtered.append(command.duplicate(true))
			continue
		var previous: Dictionary = filtered[filtered.size() - 1]
		var previous_position: Vector3 = previous.get("position", Vector3.ZERO)
		var position: Vector3 = command.get("position", Vector3.ZERO)
		var radius := float(command.get("radius", brush_radius))
		if previous_position.distance_to(position) >= maxf(0.025, radius * CLAY_COMMAND_MIN_SPACING_RATIO) or str(previous.get("tool", "")) != str(command.get("tool", "")):
			filtered.append(command.duplicate(true))
	if filtered.size() <= CLAY_COMMAND_COMMIT_MAX:
		return filtered
	var compact: Array[Dictionary] = []
	var last_source_index := -1
	for i in range(CLAY_COMMAND_COMMIT_MAX):
		var t := float(i) / float(maxi(1, CLAY_COMMAND_COMMIT_MAX - 1))
		var source_index := clampi(roundi(t * float(filtered.size() - 1)), 0, filtered.size() - 1)
		if source_index == last_source_index and source_index < filtered.size() - 1:
			source_index += 1
		compact.append((filtered[source_index] as Dictionary).duplicate(true))
		last_source_index = source_index
	return compact


func _discard_pending_clay_commands() -> void:
	_pending_clay_commands.clear()
	_clear_clay_command_preview()


func _cache_current_shape_body() -> void:
	if shell and is_instance_valid(shell) and shell.has_method("make_compact_body"):
		last_committed_body = shell.call("make_compact_body")


func _sync_clay_command_preview() -> void:
	_ensure_preview_root()
	var preview_count := mini(_pending_clay_commands.size(), CLAY_PREVIEW_MAX_INSTANCES)
	var first_command := maxi(0, _pending_clay_commands.size() - preview_count)
	for i in range(preview_count):
		var command: Dictionary = _pending_clay_commands[first_command + i]
		var instance := _ensure_preview_instance(i)
		var tool_name := str(command.get("tool", TOOL_SMART))
		var radius := float(command.get("radius", brush_radius))
		var position: Vector3 = command.get("position", Vector3.ZERO)
		var normal: Vector3 = command.get("normal", Vector3.UP)
		if normal.length_squared() <= 0.0001:
			normal = Vector3.UP
		var scale := Vector3.ONE * radius
		if tool_name == TOOL_FLATTEN:
			scale = Vector3(radius, maxf(0.012, radius * 0.10), radius)
		elif tool_name == TOOL_STRETCH:
			scale = Vector3(radius * 0.82, radius * 1.16, radius * 0.82)
		elif tool_name == TOOL_REMOVE:
			scale = Vector3.ONE * radius * 0.92
		var basis := Basis(Quaternion(Vector3.UP, normal.normalized())).orthonormalized()
		instance.global_transform = Transform3D(basis, position)
		instance.scale = scale
		instance.visible = true
		instance.material_override = _preview_material_for_tool(tool_name)
	for i in range(preview_count, _preview_instances.size()):
		_preview_instances[i].visible = false


func _ensure_preview_root() -> void:
	if _preview_root and is_instance_valid(_preview_root):
		return
	_preview_root = Node3D.new()
	_preview_root.name = "ClayCommandPreview"
	if sculpt_owner:
		sculpt_owner.add_child(_preview_root)
	else:
		add_child(_preview_root)
	_preview_root.top_level = true


func _ensure_preview_instance(index: int) -> MeshInstance3D:
	_ensure_preview_root()
	while _preview_instances.size() <= index:
		var instance := MeshInstance3D.new()
		instance.name = "ClayPreview%02d" % _preview_instances.size()
		instance.mesh = _preview_mesh()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_preview_root.add_child(instance)
		_preview_instances.append(instance)
	return _preview_instances[index]


func _preview_mesh() -> SphereMesh:
	if _preview_sphere_mesh:
		return _preview_sphere_mesh
	_preview_sphere_mesh = SphereMesh.new()
	_preview_sphere_mesh.radius = 1.0
	_preview_sphere_mesh.height = 2.0
	_preview_sphere_mesh.radial_segments = 8
	_preview_sphere_mesh.rings = 4
	return _preview_sphere_mesh


func _preview_material_for_tool(tool_name: String) -> Material:
	var clean_tool := _normalize_player_tool_name(tool_name)
	if _preview_materials.has(clean_tool):
		return _preview_materials[clean_tool]
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match clean_tool:
		TOOL_REMOVE:
			material.albedo_color = Color(0.95, 0.36, 0.30, 0.36)
		TOOL_FLATTEN:
			material.albedo_color = Color(0.80, 0.92, 1.0, 0.34)
		TOOL_STRETCH:
			material.albedo_color = Color(0.75, 0.68, 1.0, 0.36)
		TOOL_SMOOTH:
			material.albedo_color = Color(0.68, 1.0, 0.86, 0.30)
		_:
			material.albedo_color = Color(1.0, 0.82, 0.56, 0.38)
	_preview_materials[clean_tool] = material
	return material


func _clear_clay_command_preview() -> void:
	for instance in _preview_instances:
		if instance and is_instance_valid(instance):
			instance.visible = false


func _visible_preview_instance_count() -> int:
	var count := 0
	for instance in _preview_instances:
		if instance and is_instance_valid(instance) and instance.visible:
			count += 1
	return count


func _raycast_shell_screen(screen_position: Vector2) -> Dictionary:
	if not camera or not shell or not is_instance_valid(shell) or not shell.visible:
		return {}
	if not shell.has_method("intersect_ray_world"):
		return {}
	var from := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position).normalized()
	return shell.call("intersect_ray_world", from, direction, WORLD_RAY_LENGTH)


func _update_anchor_from_screen(screen_position: Vector2, commit: bool) -> void:
	var hit := _raycast_screen(screen_position)
	if hit.is_empty():
		return
	anchor_position = hit.get("position", anchor_position)
	anchor_normal = (hit.get("normal", Vector3.UP) as Vector3).normalized()
	var collider := hit.get("collider", null) as Node
	anchor_collider_path = collider.get_path() if collider and collider.is_inside_tree() else NodePath("")
	_ensure_shell()
	_place_shell_at_anchor()
	if commit and sculpt_owner and sculpt_owner.has_method("submit_chameleon_sculpt_shell_state"):
		sculpt_owner.call("submit_chameleon_sculpt_shell_state", true, anchor_position, anchor_normal)


func _raycast_screen(screen_position: Vector2) -> Dictionary:
	if not camera:
		return {}
	var world := camera.get_world_3d()
	if not world:
		return {}
	var from := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position).normalized()
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * WORLD_RAY_LENGTH)
	if sculpt_owner:
		query.exclude = [sculpt_owner.get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return world.direct_space_state.intersect_ray(query)


func _ensure_shell() -> void:
	if shell and is_instance_valid(shell):
		return
	shell = FREEFORM_CLAY_SHELL_SCENE.instantiate() as Node3D
	shell.name = "FreeformClayShell"
	if sculpt_owner:
		sculpt_owner.add_child(shell)
	else:
		add_child(shell)
	shell.top_level = true


func _reset_shell_from_owner_visual() -> void:
	if not shell or not is_instance_valid(shell):
		return
	if shell.has_method("reset_to_basic_human_shell"):
		shell.call("reset_to_basic_human_shell")
	elif shell.has_method("reset_to_default_shell"):
		shell.call("reset_to_default_shell")


func _owner_character_model_id() -> String:
	if not sculpt_owner:
		return CharacterSkinCatalog.BASIC_HUMANOID_ID
	if sculpt_owner.has_method("get_chameleon_sculpt_model_id"):
		return CharacterSkinCatalog.normalize(str(sculpt_owner.call("get_chameleon_sculpt_model_id")))
	var raw_model = sculpt_owner.get("character_model_id")
	if raw_model != null:
		return CharacterSkinCatalog.normalize(str(raw_model))
	return CharacterSkinCatalog.BASIC_HUMANOID_ID


func _place_shell_at_owner() -> void:
	if not sculpt_owner or not shell:
		return
	var transform := sculpt_owner.global_transform
	transform.origin.y = sculpt_owner.global_position.y
	shell.global_transform = transform
	anchor_position = shell.global_position
	anchor_normal = Vector3.UP


func _place_shell_at_pointer_or_owner(screen_position: Vector2 = Vector2(-INF, -INF)) -> void:
	if not shell:
		return
	var resolved_position := screen_position
	if resolved_position.x <= -INF or resolved_position.y <= -INF:
		var viewport := camera.get_viewport() if camera else get_viewport()
		resolved_position = viewport.get_mouse_position() if viewport else Vector2.ZERO
	var hit := _raycast_screen(resolved_position)
	if hit.is_empty():
		anchor_position = _fallback_anchor_from_pointer(resolved_position)
		anchor_normal = Vector3.UP
		anchor_collider_path = NodePath("")
		_place_shell_at_anchor()
		return
	anchor_position = hit.get("position", anchor_position)
	anchor_normal = (hit.get("normal", Vector3.UP) as Vector3).normalized()
	var collider := hit.get("collider", null) as Node
	anchor_collider_path = collider.get_path() if collider and collider.is_inside_tree() else NodePath("")
	_place_shell_at_anchor()


func _fallback_anchor_from_pointer(screen_position: Vector2) -> Vector3:
	if not camera:
		return sculpt_owner.global_position if sculpt_owner else Vector3.ZERO
	var from := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position).normalized()
	var target_y := sculpt_owner.global_position.y if sculpt_owner else 0.0
	if absf(direction.y) > 0.001:
		var plane_distance := (target_y - from.y) / direction.y
		if plane_distance > 0.2 and plane_distance < WORLD_RAY_LENGTH:
			return from + direction * plane_distance
	var owner_distance := from.distance_to(sculpt_owner.global_position) if sculpt_owner else 3.0
	return from + direction * clampf(owner_distance, 1.5, 6.0)


func _place_shell_at_anchor() -> void:
	if not shell:
		return
	var basis := _anchored_shell_basis()
	var contact_point := _anchor_contact_point_local()
	var transform := Transform3D(basis, anchor_position + anchor_normal * 0.05 - basis * contact_point)
	shell.global_transform = transform
	shell.visible = true


func _hide_shell() -> void:
	if shell and is_instance_valid(shell):
		shell.visible = false


func _log_shell_spawn_summary() -> void:
	if not shell or not is_instance_valid(shell):
		return
	var source_summary: Dictionary = shell.call("get_source_mesh_summary") if shell.has_method("get_source_mesh_summary") else {}
	var bounds: AABB = shell.call("get_local_bounds") if shell.has_method("get_local_bounds") else AABB()
	var vertex_count := int(shell.call("get_vertex_count")) if shell.has_method("get_vertex_count") else 0
	var triangle_count := int(shell.call("get_triangle_count")) if shell.has_method("get_triangle_count") else 0
	print(
		"[ChameleonSculpt] spawned clone source=", source_summary,
		" vertices=", vertex_count,
		" triangles=", triangle_count,
		" bounds=", bounds,
		" global=", shell.global_position,
		" visible=", shell.visible
	)


func _anchored_shell_basis() -> Basis:
	var base_basis: Basis = sculpt_owner.global_transform.basis if sculpt_owner else shell.global_transform.basis
	base_basis = base_basis.orthonormalized()
	var rotated_basis := (base_basis * _anchor_user_rotation).orthonormalized()
	var snapped_axis := (rotated_basis * _snap_axis_vector()).normalized()
	var clean_normal := anchor_normal.normalized() if anchor_normal.length_squared() > 0.0001 else Vector3.UP
	if snapped_axis.length_squared() <= 0.0001:
		return rotated_basis
	var correction := Basis(Quaternion(snapped_axis, clean_normal))
	return (correction * rotated_basis).orthonormalized()


func _snap_axis_vector() -> Vector3:
	match anchor_pose:
		ANCHOR_POSE_STANDING:
			return Vector3.UP
		ANCHOR_POSE_PRONE:
			return Vector3.FORWARD
		ANCHOR_POSE_SIDE:
			return Vector3.LEFT
	match anchor_snap_axis:
		"x":
			return Vector3.RIGHT
		"z":
			return Vector3.FORWARD
	return Vector3.UP


func _axis_name_for_anchor_pose(pose_name: String) -> String:
	match pose_name:
		ANCHOR_POSE_PRONE:
			return "z"
		ANCHOR_POSE_SIDE:
			return "x"
	return "y"


func _anchor_contact_point_local() -> Vector3:
	if not shell or not is_instance_valid(shell) or not shell.has_method("get_local_bounds"):
		return Vector3.ZERO
	var bounds: AABB = shell.call("get_local_bounds")
	if bounds.size == Vector3.ZERO:
		return Vector3.ZERO
	var axis := _snap_axis_vector().normalized()
	var center := bounds.get_center()
	var contact := center
	if absf(axis.x) >= absf(axis.y) and absf(axis.x) >= absf(axis.z):
		contact.x = bounds.position.x if axis.x > 0.0 else bounds.position.x + bounds.size.x
	elif absf(axis.y) >= absf(axis.z):
		contact.y = bounds.position.y if axis.y > 0.0 else bounds.position.y + bounds.size.y
	else:
		contact.z = bounds.position.z if axis.z > 0.0 else bounds.position.z + bounds.size.z
	return contact


func _normalize_tool_name(tool_name: String) -> String:
	match tool_name:
		TOOL_ADD, TOOL_REMOVE, TOOL_SMOOTH, TOOL_STRETCH, TOOL_FLATTEN, TOOL_SMART:
			return tool_name
		"auto", "polish", "shape":
			return TOOL_SMART
		"erase", "cut":
			return TOOL_REMOVE
	return TOOL_SMART


func _normalize_player_tool_name(tool_name: String) -> String:
	match str(tool_name).to_lower():
		TOOL_FLATTEN, "flat", "press", "plane":
			return TOOL_FLATTEN
		TOOL_REMOVE, "erase", "cut", "carve":
			return TOOL_REMOVE
		TOOL_SMART, TOOL_ADD, TOOL_STRETCH, TOOL_SMOOTH, "auto", "polish", "shape", "push", "pull", "grab":
			return TOOL_SMART
	return TOOL_SMART


func _is_supported_tool_alias(tool_name: String) -> bool:
	match str(tool_name).to_lower():
		TOOL_SMART, TOOL_ADD, TOOL_STRETCH, TOOL_SMOOTH, TOOL_FLATTEN, TOOL_REMOVE, "auto", "polish", "shape", "push", "pull", "grab", "flat", "press", "plane", "erase", "cut", "carve":
			return true
	return false


func _display_tool_name(tool_name: String) -> String:
	match _normalize_player_tool_name(tool_name):
		TOOL_FLATTEN:
			return "Flatten"
		TOOL_REMOVE:
			return "Cut"
	return "Smart Shape"
