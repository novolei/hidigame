extends Node3D
class_name HunterFlashlightSystem

const DURATION := 15.0
const COOLDOWN := 45.0
const RECOVERY_RATE := 0.5
const REVEAL_SECONDS := 3.5
const RANGE := 22.0
const SPOT_ANGLE := 42.0
const LIGHT_ENERGY := 5.8
const POSE_SYNC_INTERVAL := 0.05
const POSE_FORCE_SYNC_INTERVAL := 0.16
const POSE_SYNC_MIN_POSITION_DELTA := 0.04
const POSE_SYNC_MIN_DIRECTION_DOT := 0.9992
const HEAD_HEIGHT := 1.45
const HEAD_FORWARD_OFFSET := 0.35
const POSE_VISUAL_RELEVANCE_RADIUS := 30.0
const WORLD_OCCLUSION_MASK := 3
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
	var query_tick: int = _flashlight_query_tick()
	if multiplayer.is_server():
		_server_update_flashlight_pose(owner_peer_id, _last_origin, _last_direction, query_tick)
	else:
		Network.record_rpc_event("flashlight.pose_request", 1, 56)
		_request_flashlight_pose.rpc_id(1, _last_origin, _last_direction, query_tick)


func request_toggle() -> void:
	_update_pose_from_owner()
	_has_sent_pose = false
	_pose_sync_elapsed = POSE_SYNC_INTERVAL
	_pose_force_sync_elapsed = POSE_FORCE_SYNC_INTERVAL
	var query_tick: int = _flashlight_query_tick()
	if multiplayer.is_server():
		_server_toggle_flashlight(owner_peer_id, _last_origin, _last_direction, query_tick)
	else:
		Network.record_rpc_event("flashlight.toggle_request", 1, 56)
		_request_flashlight_toggle.rpc_id(1, _last_origin, _last_direction, query_tick)


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


func _flashlight_query_tick() -> int:
	if hunter_owner and hunter_owner.has_method("get_network_input_tick"):
		return int(hunter_owner.call("get_network_input_tick"))
	return NetworkTime.tick


@rpc("any_peer", "call_local", "reliable")
func _request_flashlight_toggle(origin: Vector3, direction: Vector3, query_tick: int = -1) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_server_toggle_flashlight(sender_id, origin, direction, query_tick)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _request_flashlight_pose(origin: Vector3, direction: Vector3, query_tick: int = -1) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_server_update_flashlight_pose(sender_id, origin, direction, query_tick)


func _server_toggle_flashlight(sender_id: int, origin: Vector3, direction: Vector3, query_tick: int = -1) -> void:
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
	_server_update_flashlight_pose(sender_id, origin, direction, query_tick)


func _server_update_flashlight_pose(sender_id: int, origin: Vector3, direction: Vector3, query_tick: int = -1) -> void:
	if sender_id != owner_peer_id or not active:
		return
	var clean_direction: Vector3 = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	_sync_flashlight_pose_to_recipients(origin, clean_direction, remaining)
	_server_apply_rewind_flashlight_exposure(sender_id, origin, clean_direction, query_tick)


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


func _server_apply_rewind_flashlight_exposure(sender_id: int, origin: Vector3, direction: Vector3, query_tick: int) -> void:
	if not multiplayer.is_server() or query_tick < 0:
		return
	var history: NetworkRewindHistory = NetworkRewindHistory.find_in_tree(get_tree()) if is_inside_tree() else null
	var hits: Array[Dictionary] = []
	if history != null:
		hits = history.find_players_in_cone(origin, direction, RANGE, SPOT_ANGLE * 0.5, query_tick, sender_id)
	else:
		hits = _current_players_in_flashlight_cone(origin, direction, sender_id)
	if hits.is_empty():
		return
	var sent_count: int = 0
	var sample_seconds: float = clampf(POSE_SYNC_INTERVAL, 0.0, 0.25)
	for hit: Dictionary in hits:
		var target_peer_id: int = int(hit.get("peer_id", 0))
		if target_peer_id <= 0 or target_peer_id == sender_id:
			continue
		var target: Node3D = _find_player_node_by_peer_id(target_peer_id)
		if target == null or not _is_stalker_target(target_peer_id, target):
			continue
		var center: Vector3 = hit.get("center", target.global_position + Vector3.UP * HEAD_HEIGHT)
		if not _server_has_flashlight_line_of_sight(origin, center, target):
			continue
		_send_rewind_flashlight_exposure(target_peer_id, sample_seconds)
		sent_count += 1
	if sent_count > 0:
		Network.record_rpc_event("flashlight.rewind_exposure", sent_count, 32)


func _current_players_in_flashlight_cone(origin: Vector3, direction: Vector3, excluded_peer_id: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not is_inside_tree() or direction.length_squared() <= 0.0001:
		return results
	var clean_direction: Vector3 = direction.normalized()
	var cos_half_angle: float = cos(deg_to_rad(SPOT_ANGLE * 0.5))
	for raw_player: Node in get_tree().get_nodes_in_group("players"):
		if not raw_player is Node3D:
			continue
		var player: Node3D = raw_player as Node3D
		var peer_id: int = _peer_id_for_player_node(player)
		if peer_id <= 0 or peer_id == excluded_peer_id:
			continue
		var center: Vector3 = player.global_position + Vector3.UP * HEAD_HEIGHT
		var to_center: Vector3 = center - origin
		var distance: float = to_center.length()
		if distance <= 0.001 or distance > RANGE:
			continue
		if clean_direction.dot(to_center.normalized()) < cos_half_angle:
			continue
		results.append({
			"peer_id": peer_id,
			"target": player,
			"center": center,
			"distance": distance,
		})
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("distance", INF)) < float(b.get("distance", INF)))
	return results


func _send_rewind_flashlight_exposure(target_peer_id: int, sample_seconds: float) -> void:
	var event_tick: int = NetworkTime.tick
	if target_peer_id == 1:
		_apply_rewind_flashlight_exposure(target_peer_id, sample_seconds, owner_peer_id, event_tick)
	else:
		_apply_rewind_flashlight_exposure.rpc_id(target_peer_id, target_peer_id, sample_seconds, owner_peer_id, event_tick)


@rpc("authority", "call_local", "unreliable_ordered")
func _apply_rewind_flashlight_exposure(target_peer_id: int, sample_seconds: float, source_peer_id: int, event_tick: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != 1:
		return
	var target: Node3D = _find_player_node_by_peer_id(target_peer_id)
	if target == null or not target.has_method("apply_network_action_event"):
		return
	target.call("apply_network_action_event", {
		"source_peer_id": source_peer_id,
		"tick": event_tick,
		"sequence": event_tick,
		"action": "flashlight_exposure",
		"payload": {"sample_seconds": sample_seconds},
	})


func _find_player_node_by_peer_id(peer_id: int) -> Node3D:
	if not is_inside_tree():
		return null
	var scene: Node = get_tree().get_current_scene()
	if scene != null:
		var container: Node = scene.get_node_or_null("PlayersContainer")
		if container != null:
			var by_name: Node = container.get_node_or_null(str(peer_id))
			if by_name is Node3D:
				return by_name as Node3D
	for raw_player: Node in get_tree().get_nodes_in_group("players"):
		if raw_player is Node3D and _peer_id_for_player_node(raw_player as Node3D) == peer_id:
			return raw_player as Node3D
	return null


func _peer_id_for_player_node(player: Node3D) -> int:
	var parsed_id: int = int(str(player.name))
	if parsed_id > 0:
		return parsed_id
	if player.has_method("get_multiplayer_authority"):
		return int(player.call("get_multiplayer_authority"))
	return 0


func _is_stalker_target(peer_id: int, target: Node3D) -> bool:
	if Network.players.has(peer_id):
		return int(Network.players[peer_id].get("role", Network.Role.NONE)) == Network.Role.STALKER
	if Network.players.has(str(peer_id)):
		return int(Network.players[str(peer_id)].get("role", Network.Role.NONE)) == Network.Role.STALKER
	return target.has_method("is_stalker") and bool(target.call("is_stalker"))


func _server_has_flashlight_line_of_sight(origin: Vector3, center: Vector3, target: Node3D) -> bool:
	var world: World3D = get_world_3d()
	if world == null:
		return true
	var exclude: Array[RID] = []
	if hunter_owner is CollisionObject3D:
		exclude.append((hunter_owner as CollisionObject3D).get_rid())
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, center, WORLD_OCCLUSION_MASK, exclude)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.direct_space_state.intersect_ray(query).is_empty()


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
