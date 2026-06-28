class_name MapPropSyncBudget
extends RefCounted

const DEFAULT_MOTION_FLUSH_INTERVAL: float = 1.0 / 8.0
const DEFAULT_MAX_MOTION_STATES_PER_FLUSH: int = 4
const DEFAULT_REST_FLUSH_INTERVAL: float = 1.0 / 10.0
const DEFAULT_MAX_REST_STATES_PER_FLUSH: int = 8

var motion_flush_interval: float = DEFAULT_MOTION_FLUSH_INTERVAL
var max_motion_states_per_flush: int = DEFAULT_MAX_MOTION_STATES_PER_FLUSH
var rest_flush_interval: float = DEFAULT_REST_FLUSH_INTERVAL
var max_rest_states_per_flush: int = DEFAULT_MAX_REST_STATES_PER_FLUSH
var _pending_motion: Dictionary = {}
var _pending_rest: Dictionary = {}
var _elapsed: float = 0.0
var _rest_elapsed: float = 0.0


func _init(
	flush_interval: float = DEFAULT_MOTION_FLUSH_INTERVAL,
	max_states_per_flush: int = DEFAULT_MAX_MOTION_STATES_PER_FLUSH,
	rest_interval: float = DEFAULT_REST_FLUSH_INTERVAL,
	max_rest_states_per_flush_value: int = DEFAULT_MAX_REST_STATES_PER_FLUSH
) -> void:
	motion_flush_interval = maxf(flush_interval, 0.001)
	max_motion_states_per_flush = maxi(max_states_per_flush, 1)
	rest_flush_interval = maxf(rest_interval, 0.001)
	max_rest_states_per_flush = maxi(max_rest_states_per_flush_value, 1)


func reset() -> void:
	_pending_motion.clear()
	_pending_rest.clear()
	_elapsed = 0.0
	_rest_elapsed = 0.0


func has_pending() -> bool:
	return not _pending_motion.is_empty() or not _pending_rest.is_empty()


func pending_count() -> int:
	return _pending_motion.size()


func pending_rest_count() -> int:
	return _pending_rest.size()


func queue_motion(prop_name: String, next_transform: Transform3D, next_linear_velocity: Vector3, next_angular_velocity: Vector3, next_sleeping: bool) -> void:
	if prop_name.is_empty():
		return
	_pending_rest.erase(prop_name)
	_pending_motion[prop_name] = {
		"prop_name": prop_name,
		"transform": next_transform,
		"linear_velocity": next_linear_velocity,
		"angular_velocity": next_angular_velocity,
		"sleeping": next_sleeping,
	}


func queue_rest(prop_name: String, next_transform: Transform3D, next_linear_velocity: Vector3, next_angular_velocity: Vector3, next_sleeping: bool) -> void:
	if prop_name.is_empty():
		return
	_pending_motion.erase(prop_name)
	_pending_rest[prop_name] = {
		"prop_name": prop_name,
		"transform": next_transform,
		"linear_velocity": next_linear_velocity,
		"angular_velocity": next_angular_velocity,
		"sleeping": next_sleeping,
	}


func clear_motion(prop_name: String) -> void:
	_pending_motion.erase(prop_name)


func clear_rest(prop_name: String) -> void:
	_pending_rest.erase(prop_name)


func tick(delta: float) -> Array[Dictionary]:
	if _pending_motion.is_empty():
		return []
	_elapsed += maxf(delta, 0.0)
	if _elapsed < motion_flush_interval:
		return []
	_elapsed = 0.0
	return drain(max_motion_states_per_flush)


func tick_rest(delta: float) -> Array[Dictionary]:
	if _pending_rest.is_empty():
		return []
	_rest_elapsed += maxf(delta, 0.0)
	if _rest_elapsed < rest_flush_interval:
		return []
	_rest_elapsed = 0.0
	return drain_rest(max_rest_states_per_flush)


func drain(max_states: int = -1) -> Array[Dictionary]:
	return _drain_states(_pending_motion, max_states)


func drain_rest(max_states: int = -1) -> Array[Dictionary]:
	return _drain_states(_pending_rest, max_states)


func _drain_states(pending: Dictionary, max_states: int = -1) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var pending_keys: Array = pending.keys()
	var limit: int = pending_keys.size() if max_states <= 0 else mini(max_states, pending_keys.size())
	var drained_keys: Array = []
	for raw_prop_name in pending_keys:
		if states.size() >= limit:
			break
		var prop_name: String = str(raw_prop_name)
		var state: Dictionary = pending.get(raw_prop_name, {})
		var next_transform: Transform3D = state.get("transform", Transform3D.IDENTITY)
		var next_linear_velocity: Vector3 = state.get("linear_velocity", Vector3.ZERO)
		var next_angular_velocity: Vector3 = state.get("angular_velocity", Vector3.ZERO)
		var next_sleeping: bool = bool(state.get("sleeping", false))
		states.append({
			"prop_name": prop_name,
			"transform": next_transform,
			"linear_velocity": next_linear_velocity,
			"angular_velocity": next_angular_velocity,
			"sleeping": next_sleeping,
		})
		drained_keys.append(raw_prop_name)
	for raw_prop_name in drained_keys:
		pending.erase(raw_prop_name)
	return states
