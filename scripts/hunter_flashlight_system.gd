extends Node3D
class_name HunterFlashlightSystem

const DURATION := 15.0
const COOLDOWN := 45.0
const RECOVERY_RATE := 0.5
const REVEAL_SECONDS := 3.5
const RANGE := 22.0
const SPOT_ANGLE := 42.0
const LIGHT_ENERGY := 5.8
const POSE_SYNC_INTERVAL := 0.12
const POSE_FORCE_SYNC_INTERVAL := 0.35
const POSE_SYNC_MIN_POSITION_DELTA := 0.08
const POSE_SYNC_MIN_DIRECTION_DOT := 0.9975
const HEAD_HEIGHT := 1.45
const HEAD_FORWARD_OFFSET := 0.35
const POSE_VISUAL_RELEVANCE_RADIUS := 30.0
const NetworkInterestScript := preload("res://scripts/network_interest.gd")

var hunter_owner: CharacterBody3D = null
var owner_camera: Camera3D = null
var owner_peer_id := 1
var active := false
var remaining := DURATION
var cooldown_remaining := 0.0
var _pose_sync_elapsed := 0.0
var _pose_force_sync_elapsed := 0.0
var _last_origin := Vector3.ZERO
var _last_direction := Vector3.FORWARD
var _last_sent_origin := Vector3.ZERO
var _last_sent_direction := Vector3.FORWARD
var _has_sent_pose := false
var _light: SpotLight3D = null


func _ready() -> void:
	set_multiplayer_authority(1)
	add_to_group("hunter_flashlights")
	_ensure_light()
	_set_light_enabled(false)


func initialize(owner_node: CharacterBody3D, camera_node: Camera3D = null) -> void:
	hunter_owner = owner_node
	owner_camera = camera_node
	if hunter_owner and hunter_owner.has_method("get_multiplayer_authority"):
		owner_peer_id = hunter_owner.get_multiplayer_authority()
	_update_pose_from_owner()


func _process(delta: float) -> void:
	if active:
		remaining = maxf(0.0, remaining - delta)
		if multiplayer.is_server() and remaining <= 0.0:
			_start_flashlight_cooldown()
		elif not multiplayer.is_server() and remaining <= 0.0:
			_apply_flashlight_state(false, 0.0, maxf(cooldown_remaining, COOLDOWN))
	elif cooldown_remaining > 0.0:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
		if cooldown_remaining <= 0.0:
			if multiplayer.is_server():
				Network.record_rpc_event("flashlight.state", maxi(multiplayer.get_peers().size(), 1), 24)
				_sync_flashlight_state.rpc(false, DURATION, 0.0)
			else:
				_apply_flashlight_state(false, DURATION, 0.0)
	elif remaining < DURATION:
		remaining = minf(DURATION, remaining + RECOVERY_RATE * delta)

	if not active:
		return

	if _is_local_owner():
		_update_pose_from_owner()
		_pose_sync_elapsed += delta
		_pose_force_sync_elapsed += delta
		if _pose_sync_elapsed >= POSE_SYNC_INTERVAL and _should_publish_pose_update():
			_publish_pose_update()


func _should_publish_pose_update() -> bool:
	if not _has_sent_pose:
		return true
	if _pose_force_sync_elapsed >= POSE_FORCE_SYNC_INTERVAL:
		return true
	if _last_origin.distance_to(_last_sent_origin) >= POSE_SYNC_MIN_POSITION_DELTA:
		return true
	var clean_direction := _last_direction.normalized() if _last_direction.length_squared() > 0.0001 else Vector3.FORWARD
	var previous_direction := _last_sent_direction.normalized() if _last_sent_direction.length_squared() > 0.0001 else Vector3.FORWARD
	return clean_direction.dot(previous_direction) <= POSE_SYNC_MIN_DIRECTION_DOT


func _publish_pose_update() -> void:
	_pose_sync_elapsed = 0.0
	_pose_force_sync_elapsed = 0.0
	_has_sent_pose = true
	_last_sent_origin = _last_origin
	_last_sent_direction = _last_direction.normalized() if _last_direction.length_squared() > 0.0001 else Vector3.FORWARD
	if multiplayer.is_server():
		_server_update_flashlight_pose(owner_peer_id, _last_origin, _last_direction)
	else:
		Network.record_rpc_event("flashlight.pose_request", 1, 48)
		_request_flashlight_pose.rpc_id(1, _last_origin, _last_direction)


func request_toggle() -> void:
	_update_pose_from_owner()
	_has_sent_pose = false
	_pose_sync_elapsed = POSE_SYNC_INTERVAL
	_pose_force_sync_elapsed = POSE_FORCE_SYNC_INTERVAL
	if multiplayer.is_server():
		_server_toggle_flashlight(owner_peer_id, _last_origin, _last_direction)
	else:
		Network.record_rpc_event("flashlight.toggle_request", 1, 48)
		_request_flashlight_toggle.rpc_id(1, _last_origin, _last_direction)


func is_flashlight_active() -> bool:
	return active


func get_flashlight_origin() -> Vector3:
	return _last_origin


func get_flashlight_direction() -> Vector3:
	return _last_direction.normalized()


func get_flashlight_range() -> float:
	return RANGE


func get_flashlight_half_angle_degrees() -> float:
	return SPOT_ANGLE * 0.5


func get_pose_sync_interval_for_test() -> float:
	return POSE_SYNC_INTERVAL


func get_reveal_seconds() -> float:
	return REVEAL_SECONDS


func get_battery_remaining() -> float:
	return remaining


func get_cooldown_remaining() -> float:
	return cooldown_remaining


@rpc("any_peer", "call_local", "reliable")
func _request_flashlight_toggle(origin: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_server_toggle_flashlight(sender_id, origin, direction)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _request_flashlight_pose(origin: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_server_update_flashlight_pose(sender_id, origin, direction)


func _server_toggle_flashlight(sender_id: int, origin: Vector3, direction: Vector3) -> void:
	if sender_id != owner_peer_id:
		return
	if active:
		Network.record_rpc_event("flashlight.state", maxi(multiplayer.get_peers().size(), 1), 24)
		_sync_flashlight_state.rpc(false, remaining, cooldown_remaining)
		return
	if cooldown_remaining > 0.0:
		return
	if remaining <= 0.0:
		_start_flashlight_cooldown()
		return
	Network.record_rpc_event("flashlight.state", maxi(multiplayer.get_peers().size(), 1), 24)
	_sync_flashlight_state.rpc(true, remaining, cooldown_remaining)
	_server_update_flashlight_pose(sender_id, origin, direction)


func _server_update_flashlight_pose(sender_id: int, origin: Vector3, direction: Vector3) -> void:
	if sender_id != owner_peer_id or not active:
		return
	var clean_direction: Vector3 = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	_sync_flashlight_pose_to_recipients(origin, clean_direction, remaining)


func _sync_flashlight_pose_to_recipients(origin: Vector3, direction: Vector3, server_remaining: float) -> void:
	var segment_end: Vector3 = origin + direction * RANGE
	var recipients: PackedInt32Array = _flashlight_pose_recipient_ids(origin, segment_end, owner_peer_id)
	if recipients.is_empty():
		return
	Network.record_rpc_event("flashlight.pose", recipients.size(), 52)
	for peer_id: int in recipients:
		if peer_id == 1:
			_sync_flashlight_pose(origin, direction, server_remaining)
		else:
			_sync_flashlight_pose.rpc_id(peer_id, origin, direction, server_remaining)


func _flashlight_pose_recipient_ids(segment_start: Vector3, segment_end: Vector3, always_peer_id: int) -> PackedInt32Array:
	var recipients: PackedInt32Array = PackedInt32Array()
	if multiplayer.multiplayer_peer == null:
		NetworkInterestScript.append_unique_peer_id(recipients, 1)
		return recipients

	if not _should_skip_visual_light() and (always_peer_id == 1 or NetworkInterestScript.is_peer_relevant_to_segment(_interest_tree(), _interest_scene(), 1, segment_start, segment_end, POSE_VISUAL_RELEVANCE_RADIUS)):
		NetworkInterestScript.append_unique_peer_id(recipients, 1)

	for peer_id: int in multiplayer.get_peers():
		if peer_id == always_peer_id or NetworkInterestScript.is_peer_relevant_to_segment(_interest_tree(), _interest_scene(), peer_id, segment_start, segment_end, POSE_VISUAL_RELEVANCE_RADIUS):
			NetworkInterestScript.append_unique_peer_id(recipients, peer_id)
	return recipients


func _interest_tree() -> SceneTree:
	return get_tree() if is_inside_tree() else null


func _interest_scene() -> Node:
	var tree: SceneTree = _interest_tree()
	return tree.get_current_scene() if tree else null


@rpc("authority", "call_local", "reliable")
func _set_flashlight_active(next_active: bool, next_remaining: float) -> void:
	_apply_flashlight_state(next_active, next_remaining, 0.0)


@rpc("authority", "call_local", "reliable")
func _sync_flashlight_state(next_active: bool, next_remaining: float, next_cooldown_remaining: float) -> void:
	_apply_flashlight_state(next_active, next_remaining, next_cooldown_remaining)


@rpc("authority", "call_local", "unreliable_ordered")
func _sync_flashlight_pose(origin: Vector3, direction: Vector3, server_remaining: float) -> void:
	remaining = server_remaining
	_apply_flashlight_pose(origin, direction)


func _update_pose_from_owner() -> void:
	if not hunter_owner:
		return
	var owner_basis := owner_camera.global_transform.basis if owner_camera else hunter_owner.global_transform.basis
	var direction := -owner_basis.z.normalized()
	var origin := hunter_owner.global_position + Vector3.UP * HEAD_HEIGHT + direction * HEAD_FORWARD_OFFSET
	if owner_camera:
		origin = hunter_owner.global_position + Vector3.UP * HEAD_HEIGHT + direction * HEAD_FORWARD_OFFSET
	_apply_flashlight_pose(origin, direction)


func _apply_flashlight_pose(origin: Vector3, direction: Vector3) -> void:
	_last_origin = origin
	_last_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	if not _light:
		_ensure_light()
	if _light:
		_light.global_position = _last_origin
		_light.look_at(_last_origin + _last_direction, Vector3.UP)


func _should_skip_visual_light() -> bool:
	return RuntimeMode.is_dedicated_public_server(multiplayer, Network.lobby_config)


func _ensure_light() -> void:
	if _light and is_instance_valid(_light):
		return
	if _should_skip_visual_light():
		return
	_light = SpotLight3D.new()
	_light.name = "HunterFlashlight"
	_light.light_color = Color(0.82, 0.90, 1.0, 1.0)
	_light.light_energy = LIGHT_ENERGY
	_light.spot_range = RANGE
	_light.spot_angle = SPOT_ANGLE
	_light.spot_attenuation = 1.15
	_light.shadow_enabled = true
	_light.shadow_blur = 0.35
	_light.add_to_group("hunter_flashlight_lights")
	add_child(_light)


func _set_light_enabled(enabled: bool) -> void:
	if _light:
		_light.visible = enabled
		_light.light_energy = LIGHT_ENERGY if enabled else 0.0


func _start_flashlight_cooldown() -> void:
	Network.record_rpc_event("flashlight.state", maxi(multiplayer.get_peers().size(), 1), 24)
	_sync_flashlight_state.rpc(false, 0.0, COOLDOWN)


func _apply_flashlight_state(next_active: bool, next_remaining: float, next_cooldown_remaining: float) -> void:
	active = next_active
	remaining = clampf(next_remaining, 0.0, DURATION)
	cooldown_remaining = maxf(next_cooldown_remaining, 0.0)
	_ensure_light()
	_set_light_enabled(active)
	if active:
		_update_pose_from_owner()


func _is_local_owner() -> bool:
	return hunter_owner and hunter_owner.is_multiplayer_authority()
