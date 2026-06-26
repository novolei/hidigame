class_name RemoteMotionSampler
extends RefCounted

const DEFAULT_MOVING_SAMPLE_INTERVAL: float = 0.05
const DEFAULT_IDLE_SAMPLE_INTERVAL: float = 0.10
const DEFAULT_IDLE_DISTANCE_EPSILON: float = 0.02

var moving_sample_interval: float = DEFAULT_MOVING_SAMPLE_INTERVAL
var idle_sample_interval: float = DEFAULT_IDLE_SAMPLE_INTERVAL
var idle_distance_epsilon: float = DEFAULT_IDLE_DISTANCE_EPSILON
var _initialized: bool = false
var _last_position: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0


func reset(position: Vector3 = Vector3.ZERO, initialized: bool = false) -> void:
	_last_position = position
	_initialized = initialized
	_elapsed = 0.0


func is_initialized() -> bool:
	return _initialized


func sample(position: Vector3, delta: float, move_hold_remaining: float = 0.0) -> Dictionary:
	if not _initialized:
		_initialized = true
		_last_position = position
		_elapsed = 0.0
		return {
			"ready": true,
			"initialized": true,
			"velocity": Vector3.ZERO,
			"position": position,
			"sample_delta": 0.0,
		}

	_elapsed += maxf(delta, 0.0)
	var distance_sq: float = position.distance_squared_to(_last_position)
	var idle_threshold_sq: float = idle_distance_epsilon * idle_distance_epsilon
	var target_interval: float = idle_sample_interval if distance_sq <= idle_threshold_sq and move_hold_remaining <= 0.0 else moving_sample_interval
	if _elapsed < target_interval:
		return {"ready": false}

	var sample_delta: float = maxf(_elapsed, 0.001)
	var velocity: Vector3 = (position - _last_position) / sample_delta
	_last_position = position
	_elapsed = 0.0
	return {
		"ready": true,
		"initialized": false,
		"velocity": velocity,
		"position": position,
		"sample_delta": sample_delta,
	}
