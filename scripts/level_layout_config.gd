extends RefCounted
class_name LevelLayoutConfig

# Centralized layout knobs for the default prop-hunt arena.
# These constants keep spawn, prop clutter, decor, and ammo placement decoupled
# while still sharing one map-scale vocabulary.
const PLAYABLE_RADIUS: float = 42.0

const PROP_SPAWN_RADIUS: float = 22.0
const PROP_SPAWN_JITTER_RADIUS: float = 7.0
const HUNTER_RELEASE_RADIUS: float = 30.0

const MAP_PROP_COUNT_8: int = 52
const MAP_PROP_COUNT_24: int = 132
const MAP_PROP_MIN_DISTANCE: float = 2.8
const MAP_PROP_INNER_RADIUS: float = 5.0
const MAP_PROP_OUTER_RADIUS: float = 38.0

const UNITY_DECOR_COUNT_8: int = 18
const UNITY_DECOR_COUNT_24: int = 52
const UNITY_DECOR_MIN_DISTANCE: float = 4.8
const UNITY_DECOR_INNER_RADIUS: float = 8.0
const UNITY_DECOR_OUTER_RADIUS: float = 39.0

const AMMO_PACK_COUNT_SMALL_8: int = 8
const AMMO_PACK_COUNT_MEDIUM_8: int = 4
const AMMO_PACK_COUNT_LARGE_8: int = 2
const AMMO_PACK_COUNT_SMALL_24: int = 24
const AMMO_PACK_COUNT_MEDIUM_24: int = 12
const AMMO_PACK_COUNT_LARGE_24: int = 5
const AMMO_PACK_MIN_DISTANCE: float = 6.0
const AMMO_PACK_INNER_RADIUS: float = 10.0
const AMMO_PACK_OUTER_RADIUS: float = 39.0


static func map_prop_count(total_players: int) -> int:
	return _scaled_count(total_players, MAP_PROP_COUNT_8, MAP_PROP_COUNT_24)


static func unity_decor_count(total_players: int) -> int:
	return _scaled_count(total_players, UNITY_DECOR_COUNT_8, UNITY_DECOR_COUNT_24)


static func ammo_pack_counts(total_players: int) -> Dictionary:
	return {
		"small": _scaled_count(total_players, AMMO_PACK_COUNT_SMALL_8, AMMO_PACK_COUNT_SMALL_24),
		"medium": _scaled_count(total_players, AMMO_PACK_COUNT_MEDIUM_8, AMMO_PACK_COUNT_MEDIUM_24),
		"large": _scaled_count(total_players, AMMO_PACK_COUNT_LARGE_8, AMMO_PACK_COUNT_LARGE_24),
	}


static func prop_spawn_point(pid: int, prop_ids: Array) -> Vector3:
	var sorted_ids: Array = prop_ids.duplicate()
	sorted_ids.sort()
	var index: int = sorted_ids.find(pid)
	if index < 0:
		index = absi(pid)

	var centers: Array[Vector3] = _prop_spawn_centers()
	var center: Vector3 = centers[index % centers.size()]
	var rng: RandomNumberGenerator = _seeded_rng(pid, 2101)
	var angle: float = rng.randf() * TAU
	var jitter: float = rng.randf_range(0.0, PROP_SPAWN_JITTER_RADIUS)
	return _clamp_to_playable(center + Vector3(cos(angle) * jitter, 0.0, sin(angle) * jitter))


static func hunter_release_point(slot_index: int, total_hunters: int) -> Vector3:
	var safe_total: int = max(total_hunters, 1)
	var t: float = 0.5
	if safe_total > 1:
		t = float(slot_index) / float(safe_total - 1)
	var x: float = lerpf(-18.0, 18.0, t)
	var z: float = HUNTER_RELEASE_RADIUS
	return _clamp_to_playable(Vector3(x, 0.0, z))


static func random_default_spawn_point() -> Vector3:
	var angle: float = randf() * TAU
	var radius: float = randf_range(8.0, PROP_SPAWN_RADIUS)
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


static func random_map_prop_position(used: Array[Vector3], min_dist: float, rng: RandomNumberGenerator) -> Vector3:
	return _random_zone_point(_map_prop_centers(), used, min_dist, rng, MAP_PROP_INNER_RADIUS, MAP_PROP_OUTER_RADIUS, 0.08)


static func random_unity_decor_position(used: Array[Vector3], min_dist: float, rng: RandomNumberGenerator) -> Vector3:
	return _random_zone_point(_decor_centers(), used, min_dist, rng, UNITY_DECOR_INNER_RADIUS, UNITY_DECOR_OUTER_RADIUS, 0.08)


static func random_ammo_position(used: Array[Vector3], min_dist: float) -> Vector3:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return _random_zone_point(_ammo_route_centers(), used, min_dist, rng, AMMO_PACK_INNER_RADIUS, AMMO_PACK_OUTER_RADIUS, 0.5)


static func _scaled_count(total_players: int, count_8: int, count_24: int) -> int:
	if total_players <= 8:
		return count_8
	var ratio: float = clampf(float(total_players - 8) / 16.0, 0.0, 1.0)
	return int(round(lerpf(float(count_8), float(count_24), ratio)))


static func _random_zone_point(centers: Array[Vector3], used: Array[Vector3], min_dist: float, rng: RandomNumberGenerator, inner_radius: float, outer_radius: float, y: float) -> Vector3:
	for attempt: int in range(48):
		var center: Vector3 = centers[rng.randi_range(0, centers.size() - 1)]
		var angle: float = rng.randf() * TAU
		var local_radius: float = rng.randf_range(0.0, 10.5)
		var candidate: Vector3 = center + Vector3(cos(angle) * local_radius, 0.0, sin(angle) * local_radius)
		candidate = _clamp_to_ring(candidate, inner_radius, outer_radius)
		candidate.y = y
		if _is_far_enough(candidate, used, min_dist):
			return candidate

	var fallback_angle: float = rng.randf() * TAU
	var fallback_radius: float = rng.randf_range(inner_radius, outer_radius)
	return Vector3(cos(fallback_angle) * fallback_radius, y, sin(fallback_angle) * fallback_radius)


static func _is_far_enough(position: Vector3, used: Array[Vector3], min_dist: float) -> bool:
	for used_position: Vector3 in used:
		if position.distance_to(used_position) < min_dist:
			return false
	return true


static func _clamp_to_ring(position: Vector3, inner_radius: float, outer_radius: float) -> Vector3:
	var flat: Vector2 = Vector2(position.x, position.z)
	var length: float = flat.length()
	if length < 0.001:
		flat = Vector2.RIGHT * inner_radius
	else:
		flat = flat.normalized() * clampf(length, inner_radius, outer_radius)
	return Vector3(flat.x, position.y, flat.y)


static func _clamp_to_playable(position: Vector3) -> Vector3:
	return _clamp_to_ring(position, 0.0, PLAYABLE_RADIUS)


static func _seeded_rng(pid: int, salt: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(absi(pid) * 92821 + salt)
	return rng


static func _prop_spawn_centers() -> Array[Vector3]:
	var centers: Array[Vector3] = []
	centers.append(Vector3(-24.0, 0.0, -19.0))
	centers.append(Vector3(24.0, 0.0, -19.0))
	centers.append(Vector3(-27.0, 0.0, 15.0))
	centers.append(Vector3(27.0, 0.0, 15.0))
	centers.append(Vector3(0.0, 0.0, 28.0))
	centers.append(Vector3(0.0, 0.0, -29.0))
	return centers


static func _map_prop_centers() -> Array[Vector3]:
	var centers: Array[Vector3] = []
	centers.append(Vector3(0.0, 0.0, 0.0))
	centers.append(Vector3(-28.0, 0.0, -22.0))
	centers.append(Vector3(27.0, 0.0, -23.0))
	centers.append(Vector3(-30.0, 0.0, 18.0))
	centers.append(Vector3(30.0, 0.0, 18.0))
	centers.append(Vector3(0.0, 0.0, 32.0))
	return centers


static func _decor_centers() -> Array[Vector3]:
	var centers: Array[Vector3] = []
	centers.append(Vector3(-31.0, 0.0, -26.0))
	centers.append(Vector3(31.0, 0.0, -26.0))
	centers.append(Vector3(-34.0, 0.0, 21.0))
	centers.append(Vector3(34.0, 0.0, 21.0))
	centers.append(Vector3(0.0, 0.0, 34.0))
	return centers


static func _ammo_route_centers() -> Array[Vector3]:
	var centers: Array[Vector3] = []
	centers.append(Vector3(-35.0, 0.0, 0.0))
	centers.append(Vector3(-24.0, 0.0, 28.0))
	centers.append(Vector3(0.0, 0.0, 36.0))
	centers.append(Vector3(24.0, 0.0, 28.0))
	centers.append(Vector3(35.0, 0.0, 0.0))
	centers.append(Vector3(22.0, 0.0, -30.0))
	centers.append(Vector3(-22.0, 0.0, -30.0))
	return centers
