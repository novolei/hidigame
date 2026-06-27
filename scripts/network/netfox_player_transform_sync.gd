extends Node
class_name NetfoxPlayerTransformSync

@export var root_path: NodePath = NodePath("..")
@export_range(1, 8, 1) var send_every_ticks: int = 1
@export_range(1, 8, 1) var interpolation_delay_ticks: int = 4
@export_range(0, 6, 1) var max_extrapolation_ticks: int = 3
@export_range(2.0, 40.0, 0.5, "or_greater") var snap_distance: float = 7.5
@export_range(4, 32, 1, "or_greater") var max_snapshots: int = 18
@export_range(6.0, 60.0, 0.5, "or_greater") var render_lerp_speed: float = 24.0
@export_range(20.0, 160.0, 1.0, "or_greater") var max_velocity_mps: float = 80.0
@export_range(100.0, 10000.0, 10.0, "or_greater") var max_abs_position: float = 5000.0
@export_range(1, 30, 1) var idle_send_every_ticks: int = 6
@export_range(0.001, 1.0, 0.001, "or_greater") var min_position_delta: float = 0.025
@export_range(0.01, 5.0, 0.01, "or_greater") var min_velocity_delta: float = 0.10
@export_range(1, 60, 1) var force_send_every_ticks: int = 12

const TRANSFORM_SNAPSHOT_APPROX_BYTES: int = 56

var _root: CharacterBody3D = null
var _last_sent_tick: int = -1000000
var _last_received_tick: int = -1000000
var _snapshots: Array[Dictionary] = []
var _has_remote_state: bool = false
var _last_submitted_position: Vector3 = Vector3.ZERO
var _last_submitted_velocity: Vector3 = Vector3.ZERO
var _has_last_submitted_transform: bool = false


func _has_runtime_multiplayer_peer() -> bool:
	return RuntimeMode.has_multiplayer_peer(multiplayer)


func _is_runtime_multiplayer_server() -> bool:
	return RuntimeMode.is_multiplayer_server(multiplayer)


func _local_peer_id() -> int:
	if _has_runtime_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	if not NetworkTime.after_tick.is_connected(_after_network_tick):
		NetworkTime.after_tick.connect(_after_network_tick)


func _ready() -> void:
	_resolve_root()
	set_process(true)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if NetworkTime.after_tick.is_connected(_after_network_tick):
		NetworkTime.after_tick.disconnect(_after_network_tick)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _root == null or not is_instance_valid(_root):
		_resolve_root()
	if _root == null:
		return
	_refresh_root_interpolation_mode()
	if multiplayer.multiplayer_peer == null:
		return
	if _is_owner_authority():
		return
	if _is_runtime_multiplayer_server():
		return
	_process_remote_render_interpolation(delta)


func _after_network_tick(_delta: float, tick: int) -> void:
	if _root == null or not is_instance_valid(_root):
		_resolve_root()
	if _root == null:
		return
	_refresh_root_interpolation_mode()
	if multiplayer.multiplayer_peer == null:
		return
	if not _is_owner_authority():
		return
	if not _should_submit_current_transform(tick):
		Network.record_perf_event("player_transform.owner_idle_skip")
		return
	_submit_current_transform(tick)


func _resolve_root() -> void:
	var node: Node = get_node_or_null(root_path)
	if node is CharacterBody3D:
		_root = node as CharacterBody3D
		_refresh_root_interpolation_mode()
	else:
		_root = null


func _refresh_root_interpolation_mode() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	if _is_owner_authority():
		_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	else:
		_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _is_owner_authority() -> bool:
	return _root != null and is_instance_valid(_root) and _root.is_multiplayer_authority()


func _should_submit_current_transform(tick: int) -> bool:
	if tick - _last_sent_tick < send_every_ticks:
		return false
	var position: Vector3 = _root.global_position
	var velocity: Vector3 = _clamp_velocity(_root.velocity)
	if not _has_last_submitted_transform:
		return true
	var elapsed_ticks: int = tick - _last_sent_tick
	var position_changed: bool = position.distance_squared_to(_last_submitted_position) >= min_position_delta * min_position_delta
	var velocity_changed: bool = velocity.distance_squared_to(_last_submitted_velocity) >= min_velocity_delta * min_velocity_delta
	if position_changed or velocity_changed:
		return true
	if elapsed_ticks >= force_send_every_ticks:
		return true
	if elapsed_ticks >= idle_send_every_ticks and velocity.length_squared() >= min_velocity_delta * min_velocity_delta:
		return true
	return false


func _submit_current_transform(tick: int) -> void:
	var position: Vector3 = _root.global_position
	var velocity: Vector3 = _clamp_velocity(_root.velocity)
	if not _is_valid_position(position):
		Network.record_perf_event("player_transform.reject_owner_position")
		return
	_last_sent_tick = tick
	_has_last_submitted_transform = true
	_last_submitted_position = position
	_last_submitted_velocity = velocity
	if _is_runtime_multiplayer_server():
		_server_broadcast_transform(int(_root.name), tick, position, velocity, 0)
	else:
		Network.record_rpc_event("player_transform.owner_submit", 1, TRANSFORM_SNAPSHOT_APPROX_BYTES)
		_owner_submit_transform.rpc_id(1, tick, position, velocity)


@rpc("any_peer", "unreliable_ordered", "call_remote")
func _owner_submit_transform(tick: int, position: Vector3, velocity: Vector3) -> void:
	if not _is_runtime_multiplayer_server():
		Network.record_perf_event("player_transform.reject_not_server")
		return
	if _root == null or not is_instance_valid(_root):
		_resolve_root()
	if _root == null:
		Network.record_perf_event("player_transform.reject_missing_root")
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id <= 1:
		Network.record_perf_event("player_transform.reject_sender")
		return
	if _root.get_multiplayer_authority() != sender_id:
		Network.record_perf_event("player_transform.reject_authority")
		return
	if tick <= _last_received_tick:
		Network.record_perf_event("player_transform.snapshot_stale")
		return
	if not _is_valid_position(position):
		Network.record_perf_event("player_transform.reject_position")
		return
	var clean_velocity: Vector3 = _clamp_velocity(velocity)
	_last_received_tick = tick
	_record_snapshot(tick, position, clean_velocity)
	_apply_root_state(position, clean_velocity)
	_server_broadcast_transform(sender_id, tick, position, clean_velocity, sender_id)


func _server_broadcast_transform(source_peer_id: int, tick: int, position: Vector3, velocity: Vector3, excluded_peer_id: int) -> void:
	if not _is_runtime_multiplayer_server():
		return
	var peers: PackedInt32Array = multiplayer.get_peers()
	var recipient_count: int = 0
	for peer_id: int in peers:
		if peer_id == excluded_peer_id:
			continue
		recipient_count += 1
		_remote_apply_transform.rpc_id(peer_id, source_peer_id, tick, position, velocity)
	if recipient_count > 0:
		Network.record_rpc_event("player_transform.forward", recipient_count, TRANSFORM_SNAPSHOT_APPROX_BYTES)


@rpc("any_peer", "unreliable_ordered", "call_remote")
func _remote_apply_transform(source_peer_id: int, tick: int, position: Vector3, velocity: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		Network.record_perf_event("player_transform.remote_reject_sender")
		return
	if _root == null or not is_instance_valid(_root):
		_resolve_root()
	if _root == null:
		Network.record_perf_event("player_transform.remote_reject_missing_root")
		return
	if source_peer_id == _local_peer_id():
		Network.record_perf_event("player_transform.remote_reject_owner_echo")
		return
	if _root.get_multiplayer_authority() != source_peer_id:
		Network.record_perf_event("player_transform.remote_reject_authority")
		return
	if tick <= _last_received_tick:
		Network.record_perf_event("player_transform.remote_snapshot_stale")
		return
	if not _is_valid_position(position):
		Network.record_perf_event("player_transform.remote_reject_position")
		return
	var clean_velocity: Vector3 = _clamp_velocity(velocity)
	_last_received_tick = tick
	_record_snapshot(tick, position, clean_velocity)


func _record_snapshot(tick: int, position: Vector3, velocity: Vector3) -> void:
	_snapshots.append({
		"tick": tick,
		"position": position,
		"velocity": velocity,
	})
	while _snapshots.size() > max_snapshots:
		_snapshots.pop_front()
		Network.record_perf_event("player_transform.snapshot_overflow")


func _process_remote_render_interpolation(delta: float) -> void:
	if _snapshots.is_empty():
		return
	var target_tick: float = float(NetworkTime.tick - interpolation_delay_ticks) + NetworkTime.tick_factor
	var sampled_state: Dictionary = _sample_state(target_tick)
	if not bool(sampled_state.get("found", false)):
		Network.record_perf_event("player_transform.remote_sample_miss")
		return
	var sample_mode: String = str(sampled_state.get("mode", "unknown"))
	Network.record_perf_event("player_transform.remote_sample_" + sample_mode)
	var target_position: Vector3 = sampled_state.get("position", _root.global_position)
	var target_velocity: Vector3 = sampled_state.get("velocity", Vector3.ZERO)
	_apply_root_state(target_position, target_velocity, true, delta)


func _sample_state(target_tick: float) -> Dictionary:
	var first_snapshot: Dictionary = _snapshots[0]
	if target_tick <= float(first_snapshot.get("tick", 0)):
		return {
			"found": true,
			"mode": "hold_first",
			"position": first_snapshot.get("position", _root.global_position),
			"velocity": first_snapshot.get("velocity", Vector3.ZERO),
		}

	var last_snapshot: Dictionary = _snapshots[_snapshots.size() - 1]
	var last_tick: float = float(last_snapshot.get("tick", 0))
	if target_tick >= last_tick:
		var last_position: Vector3 = last_snapshot.get("position", _root.global_position)
		var last_velocity: Vector3 = last_snapshot.get("velocity", Vector3.ZERO)
		var raw_extrapolation_ticks: float = maxf(target_tick - last_tick, 0.0)
		var extrapolation_ticks: float = minf(raw_extrapolation_ticks, float(max_extrapolation_ticks))
		var mode: String = "extrapolate_clamped" if raw_extrapolation_ticks > float(max_extrapolation_ticks) else "extrapolate"
		return {
			"found": true,
			"mode": mode,
			"position": last_position + last_velocity * NetworkTime.ticktime * extrapolation_ticks,
			"velocity": last_velocity,
		}

	for index: int in range(_snapshots.size() - 1):
		var from_snapshot: Dictionary = _snapshots[index]
		var to_snapshot: Dictionary = _snapshots[index + 1]
		var from_tick: float = float(from_snapshot.get("tick", 0))
		var to_tick: float = float(to_snapshot.get("tick", 0))
		if target_tick < from_tick or target_tick > to_tick:
			continue
		var span: float = maxf(1.0, to_tick - from_tick)
		var amount: float = clampf((target_tick - from_tick) / span, 0.0, 1.0)
		var from_position: Vector3 = from_snapshot.get("position", _root.global_position)
		var to_position: Vector3 = to_snapshot.get("position", from_position)
		var from_velocity: Vector3 = from_snapshot.get("velocity", Vector3.ZERO)
		var to_velocity: Vector3 = to_snapshot.get("velocity", from_velocity)
		return {
			"found": true,
			"mode": "interpolate",
			"position": from_position.lerp(to_position, amount),
			"velocity": from_velocity.lerp(to_velocity, amount),
		}
	return {"found": false, "mode": "miss"}


func _apply_root_state(position: Vector3, velocity: Vector3, smooth_render: bool = false, delta: float = 0.0) -> void:
	if not _has_remote_state or _root.global_position.distance_to(position) > snap_distance:
		_root.global_position = position
		_root.velocity = velocity
		_root.reset_physics_interpolation()
		_has_remote_state = true
		return
	if smooth_render:
		var blend: float = clampf(1.0 - exp(-render_lerp_speed * maxf(delta, 0.0)), 0.0, 1.0)
		_root.global_position = _root.global_position.lerp(position, blend)
	else:
		_root.global_position = position
	_root.velocity = velocity


func _is_valid_position(position: Vector3) -> bool:
	if not is_finite(position.x) or not is_finite(position.y) or not is_finite(position.z):
		return false
	return absf(position.x) <= max_abs_position and absf(position.y) <= max_abs_position and absf(position.z) <= max_abs_position


func _clamp_velocity(velocity: Vector3) -> Vector3:
	if not is_finite(velocity.x) or not is_finite(velocity.y) or not is_finite(velocity.z):
		return Vector3.ZERO
	var length: float = velocity.length()
	if length > max_velocity_mps:
		return velocity.normalized() * max_velocity_mps
	return velocity
