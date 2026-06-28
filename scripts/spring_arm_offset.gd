extends Node3D
class_name SpringArmCharacter


const MOUSE_YAW_SENSIBILITY: float = 0.0068
const MOUSE_PITCH_SENSIBILITY: float = 0.0046
const PITCH_MIN: float = deg_to_rad(-68.0)
const PITCH_MAX: float = deg_to_rad(38.0)
const CAMERA_ZOOM_MIN: float = 3.6
const CAMERA_ZOOM_MAX: float = 7.0
const CAMERA_ZOOM_STEP: float = 0.45
const CAMOUFLAGE_CAMERA_ZOOM_MIN: float = 0.85
const CAMOUFLAGE_CAMERA_ZOOM_MAX: float = 8.5
const CAMOUFLAGE_CAMERA_ZOOM_STEP: float = 0.72
const CAMERA_ZOOM_SMOOTHING: float = 12.0
const FOV_SMOOTHING: float = 10.0

@export_category("Objects")
@export var _spring_arm: SpringArm3D = null

var _target_spring_length := 5.0
var _target_fov := 68.0
var _camera: Camera3D = null
var _camera_input_locked := false


func _ready() -> void:
	if _spring_arm:
		_target_spring_length = _spring_arm.spring_length
		_camera = _spring_arm.get_node_or_null("Camera3D") as Camera3D
		refresh_camera_collision_exclusions()
	_target_fov = GameSettings.camera_fov
	if _camera:
		_camera.fov = _target_fov
	_apply_camera_interpolation_policy()
	_refresh_camera_process_policy()
	if not GameSettings.fov_changed.is_connected(_on_fov_changed):
		GameSettings.fov_changed.connect(_on_fov_changed)
	call_deferred("refresh_camera_collision_exclusions")
	call_deferred("_refresh_camera_process_policy")


func _refresh_camera_process_policy() -> void:
	var authority: int = get_multiplayer_authority()
	if authority <= 0:
		set_process(true)
		return
	if not RuntimeMode.has_multiplayer_peer(multiplayer):
		set_process(authority == 1)
		return
	set_process(authority == multiplayer.get_unique_id())


func _apply_camera_interpolation_policy() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _spring_arm:
		_spring_arm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _camera:
		_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func refresh_camera_collision_exclusions() -> void:
	if not _spring_arm:
		return
	_spring_arm.clear_excluded_objects()
	var owner_collision := _find_camera_collision_owner()
	if owner_collision == null:
		return
	_spring_arm.add_excluded_object(owner_collision.get_rid())
	_add_camera_collision_child_exclusions(owner_collision, owner_collision)


func _find_camera_collision_owner() -> CollisionObject3D:
	var node: Node = get_parent()
	while node:
		if node is CollisionObject3D:
			return node as CollisionObject3D
		node = node.get_parent()
	return null


func _add_camera_collision_child_exclusions(root: Node, owner_collision: CollisionObject3D) -> void:
	for child in root.get_children():
		if child is CollisionObject3D and child != owner_collision:
			_spring_arm.add_excluded_object((child as CollisionObject3D).get_rid())
		_add_camera_collision_child_exclusions(child, owner_collision)


func _process(delta: float) -> void:
	if not _spring_arm:
		return
	var smoothing := 1.0 - exp(-CAMERA_ZOOM_SMOOTHING * delta)
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, _target_spring_length, smoothing)
	if _camera:
		var fov_smoothing := 1.0 - exp(-FOV_SMOOTHING * delta)
		_camera.fov = lerpf(_camera.fov, _target_fov, fov_smoothing)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or not _spring_arm:
		return
	if _camera_input_locked:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		orbit_camera((event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if not button_event.pressed:
			return
		# Plain wheel drives the livestream performance; Shift+wheel zooms the
		# camera (FOV) — the performance took over the bare wheel, so FOV moved
		# onto Shift+wheel.
		if button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if button_event.shift_pressed:
				zoom_camera(1.0)
			else:
				_request_owner_skin_performance_action("dance")
		elif button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if button_event.shift_pressed:
				zoom_camera(-1.0)
			else:
				_request_owner_skin_performance_action("victory")


func _request_owner_skin_performance_action(action: String) -> bool:
	var owner_node := get_parent()
	if owner_node and owner_node.has_method("request_skin_performance_action"):
		return bool(owner_node.call("request_skin_performance_action", action))
	return false


func _on_fov_changed(value: float) -> void:
	if _camera_input_locked:
		return
	_target_fov = value


func set_camera_input_locked(locked: bool) -> void:
	_camera_input_locked = locked


func capture_camera_rig_state() -> Dictionary:
	return {
		"offset_rotation": rotation,
		"spring_rotation": _spring_arm.rotation if _spring_arm else Vector3.ZERO,
		"spring_length": _spring_arm.spring_length if _spring_arm else _target_spring_length,
		"target_spring_length": _target_spring_length,
		"camera_fov": _camera.fov if _camera else _target_fov,
		"target_fov": _target_fov,
	}


func apply_camera_rig_state(state: Dictionary, immediate: bool = false) -> void:
	if state.is_empty():
		return
	rotation = state.get("offset_rotation", rotation)
	if _spring_arm:
		_spring_arm.rotation = state.get("spring_rotation", _spring_arm.rotation)
		_target_spring_length = float(state.get("target_spring_length", state.get("spring_length", _target_spring_length)))
		if immediate:
			_spring_arm.spring_length = float(state.get("spring_length", _target_spring_length))
	_target_fov = float(state.get("target_fov", GameSettings.camera_fov))
	if immediate and _camera:
		_camera.fov = float(state.get("camera_fov", _target_fov))


func set_camera_rig_pose(yaw: float, pitch: float, spring_length: float, fov: float, immediate: bool = false) -> void:
	rotation.y = yaw
	if _spring_arm:
		_spring_arm.rotation.x = clampf(pitch, PITCH_MIN, PITCH_MAX)
		_target_spring_length = spring_length
		if immediate:
			_spring_arm.spring_length = spring_length
	_target_fov = fov
	if immediate and _camera:
		_camera.fov = fov


func orbit_camera(relative: Vector2) -> void:
	if not _spring_arm:
		return
	rotate_y(-relative.x * MOUSE_YAW_SENSIBILITY)
	_spring_arm.rotate_x(-relative.y * MOUSE_PITCH_SENSIBILITY)
	_spring_arm.rotation.x = clampf(_spring_arm.rotation.x, PITCH_MIN, PITCH_MAX)


func zoom_camera(step_count: float) -> void:
	if not _spring_arm:
		return
	_zoom_camera_with_limits(step_count, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX, CAMERA_ZOOM_STEP)


func zoom_camera_for_camouflage(step_count: float) -> void:
	if not _spring_arm:
		return
	_zoom_camera_with_limits(step_count, CAMOUFLAGE_CAMERA_ZOOM_MIN, CAMOUFLAGE_CAMERA_ZOOM_MAX, CAMOUFLAGE_CAMERA_ZOOM_STEP)


func _zoom_camera_with_limits(step_count: float, min_length: float, max_length: float, step_size: float) -> void:
	_target_spring_length = clampf(
		_target_spring_length + step_count * step_size,
		min_length,
		max_length
	)
