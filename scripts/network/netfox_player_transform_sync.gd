extends Node
class_name NetfoxPlayerTransformSync

@export var root_path: NodePath = NodePath("..")
@export_range(1, 8, 1) var send_every_ticks: int = 1
@export_range(1, 8, 1) var interpolation_delay_ticks: int = 1
@export_range(0, 8, 1) var max_extrapolation_ticks: int = 5
@export_range(2.0, 40.0, 0.5, "or_greater") var snap_distance: float = 7.5
@export_range(4, 32, 1, "or_greater") var max_snapshots: int = 24
@export_range(6.0, 96.0, 0.5, "or_greater") var render_lerp_speed: float = 72.0
@export_range(0, 6, 1) var adaptive_latency_extra_ticks: int = 1
@export_range(0.0, 1.0, 0.05) var adaptive_rtt_delay_weight: float = 0.10
@export_range(0.0, 3.0, 0.05) var adaptive_jitter_delay_weight: float = 0.75
@export_range(20.0, 160.0, 1.0, "or_greater") var max_velocity_mps: float = 80.0
@export_range(100.0, 10000.0, 10.0, "or_greater") var max_abs_position: float = 5000.0
@export_range(1, 30, 1) var idle_send_every_ticks: int = 4
@export_range(0.001, 1.0, 0.001, "or_greater") var min_position_delta: float = 0.025
@export_range(0.01, 5.0, 0.01, "or_greater") var min_velocity_delta: float = 0.10
@export_range(1, 60, 1) var force_send_every_ticks: int = 8

const TRANSFORM_SNAPSHOT_APPROX_BYTES: int = 128
const VISUAL_STATE_ACTION_MAX_LENGTH: int = 32
const VISUAL_SAMPLE_DEFAULT_MAX_AGE_MSEC: int = 250
const HERMITE_MIN_DEVIATION_GUARD_METERS: float = 0.35
const HERMITE_SEGMENT_DEVIATION_RATIO: float = 0.75
const HERMITE_SNAP_DISTANCE_RATIO: float = 0.5
# Below this authoritative speed the player is (nearly) stopped, so settle the rendered
# position to the target very fast — otherwise the interpolation lag reads as the body
# gliding to a stop after the owner already released input and the idle animation plays.
const STOP_SETTLE_VELOCITY: float = 0.6
const STOP_SETTLE_LERP_SPEED: float = 240.0

var _root: CharacterBody3D = null
var _last_sent_tick: int = -1000000
var _last_received_tick: int = -1000000
var _snapshots: Array[Dictionary] = []
var _has_remote_state: bool = false
var _last_submitted_position: Vector3 = Vector3.ZERO
var _last_submitted_velocity: Vector3 = Vector3.ZERO
var _last_submitted_visual_signature: String = ""
var _has_last_submitted_transform: bool = false
var _last_visual_position: Vector3 = Vector3.ZERO
var _last_visual_velocity: Vector3 = Vector3.ZERO
var _last_visual_sample_mode: String = ""
var _last_visual_sample_tick: float = -1.0
var _last_visual_sample_msec: int = 0


func _has_runtime_multiplayer_peer() -> bool:
	return RuntimeMode.has_multiplayer_peer(multiplayer)


func _is_runtime_multiplayer_server() -> bool:
	return RuntimeMode.is_multiplayer_server(multiplayer)


func _local_peer_id() -> int:
	if _has_runtime_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1


func _root_authority_peer_id() -> int:
	if _root == null or not is_instance_valid(_root):
		return _local_peer_id()
	var authority: int = _root.get_multiplayer_authority()
	if authority > 0:
		return authority
	var name_peer_id: int = int(str(_root.name))
	return name_peer_id if name_peer_id > 0 else _local_peer_id()


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	if not NetworkTime.after_tick.is_connected(_after_network_tick):
		NetworkTime.after_tick.connect(_after_network_tick)


func _ready() -> void:
	_resolve_root()
	_refresh_processing_policy()


func _refresh_processing_policy() -> void:
	var should_process: bool = false
	if _root != null and is_instance_valid(_root) and _has_runtime_multiplayer_peer():
		should_process = not _is_owner_authority() and not _is_runtime_multiplayer_server()
	set_process(should_process)


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
	_refresh_processing_policy()
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
	_refresh_processing_policy()
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
	_refresh_processing_policy()


func _refresh_root_interpolation_mode() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	if _is_owner_authority():
		_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	else:
		_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _is_owner_authority() -> bool:
	if _root == null or not is_instance_valid(_root):
		return false
	if _has_runtime_multiplayer_peer():
		return _root.is_multiplayer_authority()
	var authority: int = _root.get_multiplayer_authority()
	return authority <= 0 or authority == 1


func _should_submit_current_transform(tick: int) -> bool:
	if tick - _last_sent_tick < send_every_ticks:
		return false
	var position: Vector3 = _root.global_position
	var velocity: Vector3 = _clamp_velocity(_root.velocity)
	var visual_state: Dictionary = _collect_root_visual_state()
	var visual_signature: String = _visual_state_signature(visual_state)
	if not _has_last_submitted_transform:
		return true
	var elapsed_ticks: int = tick - _last_sent_tick
	var position_changed: bool = position.distance_squared_to(_last_submitted_position) >= min_position_delta * min_position_delta
	var velocity_changed: bool = velocity.distance_squared_to(_last_submitted_velocity) >= min_velocity_delta * min_velocity_delta
	var visual_changed: bool = visual_signature != _last_submitted_visual_signature
	if position_changed or velocity_changed or visual_changed:
		return true
	if elapsed_ticks >= force_send_every_ticks:
		return true
	if elapsed_ticks >= idle_send_every_ticks and velocity.length_squared() >= min_velocity_delta * min_velocity_delta:
		return true
	return false


func _submit_current_transform(tick: int) -> void:
	var position: Vector3 = _root.global_position
	var velocity: Vector3 = _clamp_velocity(_root.velocity)
	var visual_state: Dictionary = _collect_root_visual_state()
	if not _is_valid_position(position):
		Network.record_perf_event("player_transform.reject_owner_position")
		return
	_last_sent_tick = tick
	_has_last_submitted_transform = true
	_last_submitted_position = position
	_last_submitted_velocity = velocity
	_last_submitted_visual_signature = _visual_state_signature(visual_state)
	if _is_runtime_multiplayer_server():
		_server_broadcast_transform(_root_authority_peer_id(), tick, position, velocity, 0, visual_state)
	else:
		Network.record_rpc_event("player_transform.owner_submit", 1, TRANSFORM_SNAPSHOT_APPROX_BYTES)
		_owner_submit_transform.rpc_id(1, tick, position, velocity, visual_state)


@rpc("any_peer", "unreliable_ordered", "call_remote")
func _owner_submit_transform(tick: int, position: Vector3, velocity: Vector3, visual_state: Dictionary = {}) -> void:
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
	var clean_visual_state: Dictionary = _sanitize_visual_state(visual_state)
	_last_received_tick = tick
	_record_snapshot(tick, position, clean_velocity)
	_apply_root_state(position, clean_velocity)
	_apply_root_visual_state(clean_visual_state)
	_server_broadcast_transform(sender_id, tick, position, clean_velocity, sender_id, clean_visual_state)


func _server_broadcast_transform(source_peer_id: int, tick: int, position: Vector3, velocity: Vector3, excluded_peer_id: int, visual_state: Dictionary = {}) -> void:
	if not _is_runtime_multiplayer_server():
		return
	var peers: PackedInt32Array = multiplayer.get_peers()
	var recipient_count: int = 0
	for peer_id: int in peers:
		if peer_id == excluded_peer_id:
			continue
		recipient_count += 1
		_remote_apply_transform.rpc_id(peer_id, source_peer_id, tick, position, velocity, visual_state)
	if recipient_count > 0:
		Network.record_rpc_event("player_transform.forward", recipient_count, TRANSFORM_SNAPSHOT_APPROX_BYTES)


@rpc("any_peer", "unreliable_ordered", "call_remote")
func _remote_apply_transform(source_peer_id: int, tick: int, position: Vector3, velocity: Vector3, visual_state: Dictionary = {}) -> void:
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
	var clean_visual_state: Dictionary = _sanitize_visual_state(visual_state)
	_last_received_tick = tick
	_record_snapshot(tick, position, clean_velocity)
	_apply_root_visual_state(clean_visual_state)


func _collect_root_visual_state() -> Dictionary:
	if _root == null or not is_instance_valid(_root):
		return {}
	if not _root.has_method("get_network_visual_state"):
		return {}
	var raw_state: Variant = _root.call("get_network_visual_state")
	if raw_state is Dictionary:
		return _sanitize_visual_state(raw_state as Dictionary)
	return {}


func _sanitize_visual_state(state: Dictionary) -> Dictionary:
	var action: String = str(state.get("action", "")).strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if action.length() > VISUAL_STATE_ACTION_MAX_LENGTH:
		action = action.substr(0, VISUAL_STATE_ACTION_MAX_LENGTH)
	var action_seq: int = max(0, int(state.get("action_seq", 0)))
	var action_tick: int = max(0, int(state.get("action_tick", 0)))
	var yaw: float = wrapf(_variant_to_finite_float(state.get("yaw", 0.0), 0.0), -PI, PI)
	var move_speed: float = clampf(_variant_to_finite_float(state.get("move_speed", 0.0), 0.0), 0.0, max_velocity_mps)
	var move_x: float = clampf(_variant_to_finite_float(state.get("move_x", 0.0), 0.0), -1.0, 1.0)
	var move_z: float = clampf(_variant_to_finite_float(state.get("move_z", 0.0), 0.0), -1.0, 1.0)
	return {
		"action": action,
		"action_seq": action_seq,
		"action_tick": action_tick,
		"yaw": yaw,
		"grounded": bool(state.get("grounded", false)),
		"move_speed": move_speed,
		"move_x": move_x,
		"move_z": move_z,
		"sprinting": bool(state.get("sprinting", false)),
	}


func _variant_to_finite_float(value: Variant, fallback: float = 0.0) -> float:
	var value_type: int = typeof(value)
	if value_type != TYPE_FLOAT and value_type != TYPE_INT:
		return fallback
	var result: float = float(value)
	return result if is_finite(result) else fallback


func _visual_state_signature(state: Dictionary) -> String:
	if state.is_empty():
		return ""
	return "%s|%d|%d|%.3f|%d|%.2f|%.2f|%.2f|%d" % [
		str(state.get("action", "")),
		int(state.get("action_seq", 0)),
		int(state.get("action_tick", 0)),
		_variant_to_finite_float(state.get("yaw", 0.0), 0.0),
		1 if bool(state.get("grounded", false)) else 0,
		_variant_to_finite_float(state.get("move_speed", 0.0), 0.0),
		_variant_to_finite_float(state.get("move_x", 0.0), 0.0),
		_variant_to_finite_float(state.get("move_z", 0.0), 0.0),
		1 if bool(state.get("sprinting", false)) else 0,
	]


func _apply_root_visual_state(visual_state: Dictionary) -> void:
	if visual_state.is_empty():
		return
	if _root == null or not is_instance_valid(_root):
		return
	if _root.has_method("apply_network_visual_state"):
		_root.call("apply_network_visual_state", visual_state)


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
	var delay_ticks: int = _remote_interpolation_delay_ticks()
	if delay_ticks > interpolation_delay_ticks:
		Network.record_perf_event("player_transform.remote_adaptive_delay")
	var target_tick: float = float(NetworkTime.tick - delay_ticks) + NetworkTime.tick_factor
	var sampled_state: Dictionary = _sample_state(target_tick)
	if not bool(sampled_state.get("found", false)):
		Network.record_perf_event("player_transform.remote_sample_miss")
		return
	var sample_mode: String = str(sampled_state.get("mode", "unknown"))
	Network.record_perf_event("player_transform.remote_sample_" + sample_mode)
	var target_position: Vector3 = sampled_state.get("position", _root.global_position)
	var target_velocity: Vector3 = sampled_state.get("velocity", Vector3.ZERO)
	_store_visual_sample(target_tick, target_position, target_velocity, sample_mode)
	_apply_root_state(target_position, target_velocity, true, delta)


func _store_visual_sample(tick: float, position: Vector3, velocity: Vector3, mode: String) -> void:
	_last_visual_position = position
	_last_visual_velocity = _clamp_velocity(velocity)
	_last_visual_sample_mode = mode
	_last_visual_sample_tick = tick
	_last_visual_sample_msec = Time.get_ticks_msec()


func has_fresh_remote_visual_sample(max_age_msec: int = VISUAL_SAMPLE_DEFAULT_MAX_AGE_MSEC) -> bool:
	if _last_visual_sample_msec <= 0:
		return false
	if max_age_msec <= 0:
		return true
	return Time.get_ticks_msec() - _last_visual_sample_msec <= max_age_msec


func get_remote_visual_velocity(max_age_msec: int = VISUAL_SAMPLE_DEFAULT_MAX_AGE_MSEC) -> Vector3:
	if not has_fresh_remote_visual_sample(max_age_msec):
		return Vector3.ZERO
	return _last_visual_velocity


func get_remote_visual_position(max_age_msec: int = VISUAL_SAMPLE_DEFAULT_MAX_AGE_MSEC) -> Vector3:
	if not has_fresh_remote_visual_sample(max_age_msec):
		return Vector3.ZERO
	return _last_visual_position


func get_remote_visual_sample_mode() -> String:
	return _last_visual_sample_mode


func get_remote_visual_sample_tick() -> float:
	return _last_visual_sample_tick


func _remote_interpolation_delay_ticks() -> int:
	return _adaptive_remote_interpolation_delay_ticks(
		NetworkTime.remote_rtt,
		NetworkTimeSynchronizer.rtt_jitter,
		NetworkTime.ticktime
	)


func _adaptive_remote_interpolation_delay_ticks(rtt_seconds: float, jitter_seconds: float, ticktime: float) -> int:
	var base_delay: int = maxi(1, interpolation_delay_ticks)
	if adaptive_latency_extra_ticks <= 0:
		return base_delay
	var safe_ticktime: float = maxf(ticktime, 0.001)
	var weighted_delay_seconds: float = maxf(rtt_seconds, 0.0) * adaptive_rtt_delay_weight \
		+ maxf(jitter_seconds, 0.0) * adaptive_jitter_delay_weight
	if weighted_delay_seconds <= 0.0:
		return base_delay
	var suggested_delay: int = int(ceil(weighted_delay_seconds / safe_ticktime))
	var max_delay: int = base_delay + maxi(0, adaptive_latency_extra_ticks)
	return clampi(maxi(base_delay, suggested_delay), base_delay, max_delay)


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
		var is_clamped := raw_extrapolation_ticks > float(max_extrapolation_ticks)
		var mode: String = "extrapolate_clamped" if is_clamped else "extrapolate"
		return {
			"found": true,
			"mode": mode,
			"position": last_position + last_velocity * NetworkTime.ticktime * extrapolation_ticks,
			"velocity": Vector3.ZERO if is_clamped else last_velocity,
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
		var position_sample: Dictionary = _interpolate_snapshot_position(from_position, from_velocity, to_position, to_velocity, span, amount)
		return {
			"found": true,
			"mode": "interpolate",
			"curve": str(position_sample.get("curve", "linear")),
			"position": position_sample.get("position", from_position.lerp(to_position, amount)),
			"velocity": from_velocity.lerp(to_velocity, amount),
		}
	return {"found": false, "mode": "miss"}


func _interpolate_snapshot_position(
	from_position: Vector3,
	from_velocity: Vector3,
	to_position: Vector3,
	to_velocity: Vector3,
	span_ticks: float,
	amount: float
) -> Dictionary:
	var linear_position: Vector3 = from_position.lerp(to_position, amount)
	var duration: float = maxf(span_ticks * NetworkTime.ticktime, 0.001)
	var hermite_position: Vector3 = _hermite_position(from_position, from_velocity, to_position, to_velocity, duration, amount)
	var segment_distance: float = from_position.distance_to(to_position)
	var max_deviation: float = maxf(
		HERMITE_MIN_DEVIATION_GUARD_METERS,
		minf(snap_distance * HERMITE_SNAP_DISTANCE_RATIO, segment_distance * HERMITE_SEGMENT_DEVIATION_RATIO)
	)
	if hermite_position.distance_to(linear_position) > max_deviation:
		return {"position": linear_position, "curve": "linear_fallback"}
	return {"position": hermite_position, "curve": "hermite"}


func _hermite_position(
	from_position: Vector3,
	from_velocity: Vector3,
	to_position: Vector3,
	to_velocity: Vector3,
	duration: float,
	amount: float
) -> Vector3:
	var t: float = clampf(amount, 0.0, 1.0)
	var t2: float = t * t
	var t3: float = t2 * t
	var h00: float = 2.0 * t3 - 3.0 * t2 + 1.0
	var h10: float = t3 - 2.0 * t2 + t
	var h01: float = -2.0 * t3 + 3.0 * t2
	var h11: float = t3 - t2
	return from_position * h00 + from_velocity * duration * h10 + to_position * h01 + to_velocity * duration * h11


func _apply_root_state(position: Vector3, velocity: Vector3, smooth_render: bool = false, delta: float = 0.0) -> void:
	if not _has_remote_state or _root.global_position.distance_to(position) > snap_distance:
		_root.global_position = position
		_root.velocity = velocity
		_root.reset_physics_interpolation()
		_has_remote_state = true
		return
	if smooth_render:
		# Latency-adaptive: near real-time on a fast link (no sluggish trailing / slow-looking
		# landings), softer only when RTT/jitter actually warrant it. Industry entity-interpolation
		# practice — the visual follows replicated state, tightened to the real network conditions.
		var lerp_speed: float = RemoteVisualPolicy.position_lerp_speed(
			NetworkTime.remote_rtt, NetworkTimeSynchronizer.rtt_jitter)
		# Stopped/stopping: settle to the authoritative position fast so the body lands with the
		# idle animation instead of gliding the last stretch in (interpolation lag catch-up).
		if velocity.length_squared() < STOP_SETTLE_VELOCITY * STOP_SETTLE_VELOCITY:
			lerp_speed = maxf(lerp_speed, STOP_SETTLE_LERP_SPEED)
		var blend: float = clampf(1.0 - exp(-lerp_speed * maxf(delta, 0.0)), 0.0, 1.0)
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
