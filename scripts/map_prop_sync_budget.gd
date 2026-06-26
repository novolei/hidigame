class_name MapPropSyncBudget
extends RefCounted

const DEFAULT_MOTION_FLUSH_INTERVAL: float = 0.125

var motion_flush_interval: float = DEFAULT_MOTION_FLUSH_INTERVAL
var _pending_motion: Dictionary = {}
var _elapsed: float = 0.0


func _init(flush_interval: float = DEFAULT_MOTION_FLUSH_INTERVAL) -> void:
	motion_flush_interval = maxf(flush_interval, 0.001)


func reset() -> void:
	_pending_motion.clear()
	_elapsed = 0.0


func has_pending() -> bool:
	return not _pending_motion.is_empty()


func pending_count() -> int:
	return _pending_motion.size()


func queue_motion(prop_name: String, next_transform: Transform3D, next_linear_velocity: Vector3, next_angular_velocity: Vector3, next_sleeping: bool) -> void:
	if prop_name.is_empty():
		return
	_pending_motion[prop_name] = {
		"prop_name": prop_name,
		"transform": next_transform,
		"linear_velocity": next_linear_velocity,
		"angular_velocity": next_angular_velocity,
		"sleeping": next_sleeping,
	}


func clear_motion(prop_name: String) -> void:
	_pending_motion.erase(prop_name)


func tick(delta: float) -> Array[Dictionary]:
	if _pending_motion.is_empty():
		return []
	_elapsed += maxf(delta, 0.0)
	if _elapsed < motion_flush_interval:
		return []
	_elapsed = 0.0
	return drain()


func drain() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for raw_prop_name in _pending_motion.keys():
		var prop_name: String = str(raw_prop_name)
		var state: Dictionary = _pending_motion.get(raw_prop_name, {})
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
	_pending_motion.clear()
	return states
