extends RefCounted
class_name RemoteVisualPolicy

const DEFAULT_REMOTE_LOD_BIAS := 0.65


static func apply_to_remote(root: Node, is_local_authority: bool, lod_bias: float = DEFAULT_REMOTE_LOD_BIAS) -> void:
	if root == null or is_local_authority:
		return
	_apply_recursive(root, lod_bias)


static func apply_to_any(root: Node, lod_bias: float = DEFAULT_REMOTE_LOD_BIAS) -> void:
	if root == null:
		return
	_apply_recursive(root, lod_bias)


static func _apply_recursive(node: Node, lod_bias: float) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		geometry.lod_bias = minf(geometry.lod_bias, lod_bias)
	for child in node.get_children():
		if child is Node:
			_apply_recursive(child as Node, lod_bias)


# --- Latency-adaptive smoothing for remote players ---------------------------------------
# A fixed amount of interpolation delay + smoothing is wrong for everyone: on a low-latency
# link the buffering only adds sluggishness (landings look slow, walking slides/lurches as the
# visuals trail authoritative state for no reason). These pure functions scale the smoothing to
# the live RTT/jitter estimate, so callers stay thin and this is the single tuning point.
# All inputs are seconds.

# Half-RTT + jitter: the one-way visual latency the remote view contends with.
static func visual_latency_sec(rtt_sec: float, jitter_sec: float) -> float:
	return maxf(rtt_sec, 0.0) * 0.5 + maxf(jitter_sec, 0.0)


# Blend rate for the remote velocity low-pass (velocity-fallback animation only). Snappy at
# ~0 latency so action thresholds react immediately; heavier smoothing as latency rises.
static func velocity_smooth_rate(rtt_sec: float, jitter_sec: float) -> float:
	return clampf(30.0 - visual_latency_sec(rtt_sec, jitter_sec) * 180.0, 9.0, 30.0)


# Render lerp speed for the remote root position (higher = snappier, less trailing).
static func position_lerp_speed(rtt_sec: float, jitter_sec: float) -> float:
	return clampf(140.0 - visual_latency_sec(rtt_sec, jitter_sec) * 700.0, 36.0, 140.0)


# How long an authoritative visual-state sample stays "fresh" before falling back to the
# velocity guess. Tight on a fast link, wider on a slow one to bridge sparse packets.
static func state_freshness_msec(rtt_sec: float, jitter_sec: float) -> int:
	return int(clampf(150.0 + visual_latency_sec(rtt_sec, jitter_sec) * 1000.0 * 2.2, 150.0, 480.0))


# Hysteresis hold after movement input stops. Short on a fast link (snap to idle), longer on
# a slow link (bridge packet gaps so locomotion doesn't flicker to idle).
static func move_hold_sec(rtt_sec: float, jitter_sec: float) -> float:
	return clampf(0.06 + visual_latency_sec(rtt_sec, jitter_sec) * 1.2, 0.06, 0.24)
