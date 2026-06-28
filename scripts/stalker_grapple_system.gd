extends Node3D
class_name StalkerGrappleSystem

const RANGE := 45.0
const COOLDOWN := 45.0
const PULL_DURATION := 0.28
const TARGET_BACKOFF := 0.95
const TARGET_UP_OFFSET := 0.18
const VISUAL_DURATION := 0.24
const GRAPPLE_REQUEST_APPROX_BYTES := 72
const HOOK_SCENE: PackedScene = preload("res://scenes/effects/stalker_grapple_hook.tscn")
const ROPE_SCENE: PackedScene = preload("res://scenes/effects/stalker_grapple_rope.tscn")

var stalker_owner: CharacterBody3D = null
var owner_camera: Camera3D = null
var cooldown_remaining := 0.0
var pulling := false

var _pull_elapsed := 0.0
var _pull_start := Vector3.ZERO
var _pull_target := Vector3.ZERO
var _hook_visual: Node3D = null
var _rope_visual: Node3D = null


func initialize(owner_node: CharacterBody3D, camera_node: Camera3D = null) -> void:
	stalker_owner = owner_node
	owner_camera = camera_node
	set_multiplayer_authority(stalker_owner.get_multiplayer_authority() if stalker_owner else 1)


func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)


func _physics_process(delta: float) -> void:
	if not pulling or not stalker_owner or not stalker_owner.is_multiplayer_authority():
		return
	_pull_elapsed = minf(PULL_DURATION, _pull_elapsed + delta)
	var ratio := clampf(_pull_elapsed / PULL_DURATION, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - ratio, 3.0)
	stalker_owner.global_position = _pull_start.lerp(_pull_target, eased)
	stalker_owner.velocity = Vector3.ZERO
	if ratio >= 1.0:
		pulling = false
		stalker_owner.global_position = _pull_target


func request_grapple() -> bool:
	if not stalker_owner or not stalker_owner.is_multiplayer_authority():
		return false
	if cooldown_remaining > 0.0 or pulling:
		return false
	var origin: Vector3 = _ray_origin()
	var direction: Vector3 = _ray_direction()
	var query_tick: int = _grapple_query_tick()
	var hit: Dictionary = _find_grapple_hit_from(origin, direction, query_tick, _owner_peer_id())
	if hit.is_empty():
		return false
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	var target: Vector3 = _pull_target_from_hit(origin, hit)
	_start_pull(target)
	_show_grapple_effect(origin, hit_position)
	cooldown_remaining = COOLDOWN
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_broadcast_grapple_effect_to_peers(origin, hit_position)
		else:
			Network.record_rpc_event("grapple.request", 1, GRAPPLE_REQUEST_APPROX_BYTES)
			_request_grapple.rpc_id(1, origin, direction, query_tick)
	return true


func get_cooldown_remaining() -> float:
	return cooldown_remaining


func is_grappling() -> bool:
	return pulling


func _find_grapple_hit() -> Dictionary:
	return _find_grapple_hit_from(_ray_origin(), _ray_direction(), _grapple_query_tick(), _owner_peer_id())


func _find_grapple_hit_from(origin: Vector3, direction: Vector3, query_tick: int, excluded_peer_id: int = 0) -> Dictionary:
	if not stalker_owner or not stalker_owner.get_world_3d():
		return {}
	if direction.length_squared() <= 0.0001:
		return {}
	var clean_direction: Vector3 = direction.normalized()
	var space: PhysicsDirectSpaceState3D = stalker_owner.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + clean_direction * RANGE)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [stalker_owner.get_rid()]
	query.collision_mask = 0x7FFFFFFF
	var world_hit: Dictionary = space.intersect_ray(query)
	if not world_hit.is_empty() and world_hit.get("collider", null) == stalker_owner:
		world_hit = {}
	var rewind_hit: Dictionary = {}
	var history: NetworkRewindHistory = NetworkRewindHistory.find_in_tree(get_tree())
	if history != null:
		rewind_hit = history.find_player_hit_on_segment(origin, clean_direction, RANGE, query_tick, excluded_peer_id)
	if rewind_hit.is_empty():
		return world_hit
	if world_hit.is_empty():
		return rewind_hit
	var world_distance: float = origin.distance_to(world_hit.get("position", origin))
	var rewind_distance: float = float(rewind_hit.get("distance", INF))
	return rewind_hit if rewind_distance < world_distance else world_hit


func _pull_target_from_hit(origin: Vector3, hit: Dictionary) -> Vector3:
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
	var direction: Vector3 = (hit_position - origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = _ray_direction()
	return hit_position - direction * TARGET_BACKOFF + hit_normal.normalized() * TARGET_UP_OFFSET


func _owner_peer_id() -> int:
	if stalker_owner and stalker_owner.has_method("get_multiplayer_authority"):
		return int(stalker_owner.call("get_multiplayer_authority"))
	return 1


func _grapple_query_tick() -> int:
	if stalker_owner and stalker_owner.has_method("get_network_input_tick"):
		return int(stalker_owner.call("get_network_input_tick"))
	return NetworkTime.tick


@rpc("any_peer", "call_local", "reliable")
func _request_grapple(origin: Vector3, direction: Vector3, query_tick: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != _owner_peer_id():
		return
	_server_accept_grapple(sender_id, origin, direction, query_tick)


func _server_accept_grapple(sender_id: int, origin: Vector3, direction: Vector3, query_tick: int) -> void:
	if sender_id != _owner_peer_id():
		return
	if cooldown_remaining > 0.0:
		_reject_grapple.rpc_id(sender_id)
		return
	var hit: Dictionary = _find_grapple_hit_from(origin, direction, query_tick, sender_id)
	if hit.is_empty():
		_reject_grapple.rpc_id(sender_id)
		return
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	var target: Vector3 = _pull_target_from_hit(origin, hit)
	cooldown_remaining = COOLDOWN
	_show_grapple_effect(origin, hit_position)
	_broadcast_grapple_effect_to_peers(origin, hit_position)
	_apply_grapple_correction.rpc_id(sender_id, target)


func _broadcast_grapple_effect_to_peers(origin: Vector3, hit_position: Vector3) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	var peers: PackedInt32Array = multiplayer.get_peers()
	if peers.is_empty():
		return
	Network.record_rpc_event("grapple.effect", peers.size(), 48)
	for peer_id: int in peers:
		_show_grapple_effect.rpc_id(peer_id, origin, hit_position)


@rpc("any_peer", "call_remote", "reliable")
func _apply_grapple_correction(target: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() != 1:
		return
	if not stalker_owner or not stalker_owner.is_multiplayer_authority():
		return
	_start_pull(target)
	cooldown_remaining = COOLDOWN


@rpc("any_peer", "call_remote", "reliable")
func _reject_grapple() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() != 1:
		return
	pulling = false


func _start_pull(target: Vector3) -> void:
	pulling = true
	_pull_elapsed = 0.0
	_pull_start = stalker_owner.global_position
	_pull_target = target
	stalker_owner.velocity = Vector3.ZERO
	if stalker_owner.has_method("_play_body_jump"):
		stalker_owner.call("_play_body_jump", "Jump")


func _ray_origin() -> Vector3:
	if owner_camera:
		return owner_camera.global_position
	if stalker_owner:
		return stalker_owner.global_position + Vector3.UP * 1.35
	return global_position


func _ray_direction() -> Vector3:
	if owner_camera:
		return -owner_camera.global_transform.basis.z.normalized()
	if stalker_owner:
		return -stalker_owner.global_transform.basis.z.normalized()
	return -global_transform.basis.z.normalized()


@rpc("any_peer", "call_local", "reliable")
func _show_grapple_effect(origin: Vector3, target: Vector3) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender_id: int = multiplayer.get_remote_sender_id()
		if sender_id != 0 and sender_id != 1:
			return
	_clear_visuals()
	_hook_visual = HOOK_SCENE.instantiate()
	_rope_visual = ROPE_SCENE.instantiate()
	add_child(_hook_visual)
	add_child(_rope_visual)
	_hook_visual.global_position = target
	var dir := (target - origin).normalized()
	if dir.length_squared() > 0.001:
		_hook_visual.look_at(target + dir, Vector3.UP)
	_place_rope(origin, target)
	var tween := create_tween()
	tween.tween_interval(VISUAL_DURATION)
	tween.tween_callback(_clear_visuals)


func _place_rope(origin: Vector3, target: Vector3) -> void:
	if not _rope_visual:
		return
	var midpoint := origin.lerp(target, 0.5)
	var delta := target - origin
	var length := maxf(delta.length(), 0.01)
	_rope_visual.global_position = midpoint
	_rope_visual.scale = Vector3(1.0, length, 1.0)
	_rope_visual.look_at(target, Vector3.UP)
	_rope_visual.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func _clear_visuals() -> void:
	if _hook_visual and is_instance_valid(_hook_visual):
		_hook_visual.queue_free()
	if _rope_visual and is_instance_valid(_rope_visual):
		_rope_visual.queue_free()
	_hook_visual = null
	_rope_visual = null
