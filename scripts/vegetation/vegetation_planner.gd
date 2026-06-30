class_name VegetationPlanner
extends RefCounted

const HASH_LIMIT: int = 2147483647


static func generate_grass(profile: VegetationProfile, support_center: Vector3, support_size: Vector2, support_top_y: float) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if profile == null or profile.grass_instance_count <= 0:
		return placements

	var rng := RandomNumberGenerator.new()
	rng.seed = _combined_seed(profile, "grass")
	var attempts_limit: int = max(profile.grass_instance_count * 10, profile.grass_instance_count)
	var attempts: int = 0
	while placements.size() < profile.grass_instance_count and attempts < attempts_limit:
		attempts += 1
		var local_x: float = rng.randf_range(-support_size.x * 0.5, support_size.x * 0.5)
		var local_z: float = rng.randf_range(-support_size.y * 0.5, support_size.y * 0.5)
		if not _accept_grass_point(profile, local_x, local_z, support_size, rng):
			continue
		placements.append(_make_grass_item(profile, support_center, support_top_y, local_x, local_z, rng))

	while placements.size() < profile.grass_instance_count:
		var edge_item: Dictionary = _make_edge_grass_item(profile, support_center, support_size, support_top_y, rng)
		placements.append(edge_item)

	return placements


static func generate_trees(profile: VegetationProfile, support_center: Vector3, support_size: Vector2, support_top_y: float) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if profile == null or profile.tree_count <= 0 or profile.tree_scene_paths.is_empty():
		return placements

	var rng := RandomNumberGenerator.new()
	rng.seed = _combined_seed(profile, "trees")
	var attempts_limit: int = max(profile.tree_count * 12, profile.tree_count)
	var attempts: int = 0
	while placements.size() < profile.tree_count and attempts < attempts_limit:
		attempts += 1
		var local_position: Vector2 = _edge_position(profile, support_size, rng)
		if not _accept_tree_point(local_position, support_size, placements):
			continue
		placements.append(_make_tree_item(profile, support_center, support_top_y, local_position, rng))

	while placements.size() < profile.tree_count:
		var fallback_position: Vector2 = _edge_position(profile, support_size, rng)
		placements.append(_make_tree_item(profile, support_center, support_top_y, fallback_position, rng))

	return placements


static func placement_digest(placements: Array[Dictionary]) -> int:
	var digest: int = 1469598103
	for item in placements:
		var position: Vector3 = item.get("position", Vector3.ZERO)
		var yaw: float = float(item.get("yaw", 0.0))
		var scale: Vector3 = item.get("scale", Vector3.ONE)
		digest = _mix_hash(digest, int(round(position.x * 100.0)))
		digest = _mix_hash(digest, int(round(position.y * 100.0)))
		digest = _mix_hash(digest, int(round(position.z * 100.0)))
		digest = _mix_hash(digest, int(round(yaw * 10000.0)))
		digest = _mix_hash(digest, int(round(scale.x * 1000.0)))
		digest = _mix_hash(digest, int(round(scale.y * 1000.0)))
		digest = _mix_hash(digest, int(round(scale.z * 1000.0)))
		digest = _mix_hash(digest, int(item.get("prototype", 0)))
	return digest


static func stable_hash_text(text: String) -> int:
	return VegetationProfile.stable_seed(text)


static func _make_grass_item(profile: VegetationProfile, support_center: Vector3, support_top_y: float, local_x: float, local_z: float, rng: RandomNumberGenerator) -> Dictionary:
	var patch_value: float = _value_noise_2d(local_x * profile.grass_patch_frequency, local_z * profile.grass_patch_frequency, profile.generation_seed)
	var height: float = rng.randf_range(profile.grass_min_height, profile.grass_max_height) * lerpf(0.84, 1.18, patch_value)
	var width: float = rng.randf_range(profile.grass_min_width, profile.grass_max_width)
	var position := Vector3(support_center.x + local_x, support_top_y + 0.035, support_center.z + local_z)
	var scale := Vector3(width, height, width)
	return {
		"position": position,
		"yaw": rng.randf_range(-PI, PI),
		"scale": scale,
		"stiffness": rng.randf_range(0.68, 1.18),
		"phase": rng.randf(),
		"color_bias": clampf((patch_value - 0.5) * 1.4 + rng.randf_range(-0.18, 0.18), -1.0, 1.0),
	}


static func _make_edge_grass_item(profile: VegetationProfile, support_center: Vector3, support_size: Vector2, support_top_y: float, rng: RandomNumberGenerator) -> Dictionary:
	var local_position: Vector2 = _edge_position(profile, support_size, rng)
	return _make_grass_item(profile, support_center, support_top_y, local_position.x, local_position.y, rng)


static func _make_tree_item(profile: VegetationProfile, support_center: Vector3, support_top_y: float, local_position: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var uniform_scale: float = rng.randf_range(profile.tree_min_scale, profile.tree_max_scale)
	return {
		"position": Vector3(support_center.x + local_position.x, support_top_y, support_center.z + local_position.y),
		"local_position": local_position,
		"yaw": rng.randf_range(-PI, PI),
		"scale": Vector3(uniform_scale, uniform_scale, uniform_scale),
		"prototype": rng.randi_range(0, profile.tree_scene_paths.size() - 1),
		"phase": rng.randf(),
	}


static func _accept_grass_point(profile: VegetationProfile, local_x: float, local_z: float, support_size: Vector2, rng: RandomNumberGenerator) -> bool:
	var half_x: float = maxf(support_size.x * 0.5, 1.0)
	var half_z: float = maxf(support_size.y * 0.5, 1.0)
	var edge_amount: float = maxf(absf(local_x) / half_x, absf(local_z) / half_z)
	var patch_value: float = _value_noise_2d(local_x * profile.grass_patch_frequency, local_z * profile.grass_patch_frequency, profile.generation_seed)
	var in_service_lane: bool = absf(local_x) < half_x * 0.18 or absf(local_z) < half_z * 0.12
	var density: float = patch_value * 0.64 + edge_amount * profile.grass_edge_bias
	if in_service_lane:
		density -= 0.22
	return density > 0.46 or rng.randf() < clampf(density * 0.22, 0.0, 0.22)


static func _accept_tree_point(local_position: Vector2, support_size: Vector2, existing: Array[Dictionary]) -> bool:
	var half_x: float = maxf(support_size.x * 0.5, 1.0)
	var half_z: float = maxf(support_size.y * 0.5, 1.0)
	if absf(local_position.x) < half_x * 0.36 and absf(local_position.y) < half_z * 0.34:
		return false
	for item in existing:
		var fallback_world_position: Vector3 = item.get("position", Vector3.ZERO)
		var other_local: Vector2 = item.get("local_position", Vector2(fallback_world_position.x, fallback_world_position.z))
		if other_local.distance_to(local_position) < 9.0:
			return false
	return true


static func _edge_position(profile: VegetationProfile, support_size: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var half_x: float = support_size.x * 0.5
	var half_z: float = support_size.y * 0.5
	var margin_x: float = half_x * clampf(profile.tree_edge_margin, 0.02, 0.45)
	var margin_z: float = half_z * clampf(profile.tree_edge_margin, 0.02, 0.45)
	var side: int = rng.randi_range(0, 3)
	match side:
		0:
			return Vector2(rng.randf_range(-half_x, half_x), rng.randf_range(-half_z, -half_z + margin_z))
		1:
			return Vector2(rng.randf_range(-half_x, half_x), rng.randf_range(half_z - margin_z, half_z))
		2:
			return Vector2(rng.randf_range(-half_x, -half_x + margin_x), rng.randf_range(-half_z, half_z))
		_:
			return Vector2(rng.randf_range(half_x - margin_x, half_x), rng.randf_range(-half_z, half_z))


static func _value_noise_2d(x: float, y: float, seed_value: int) -> float:
	var xi: int = int(floor(x))
	var yi: int = int(floor(y))
	var xf: float = x - float(xi)
	var yf: float = y - float(yi)
	var sx: float = xf * xf * (3.0 - 2.0 * xf)
	var sy: float = yf * yf * (3.0 - 2.0 * yf)
	var a: float = _hash01(xi, yi, seed_value)
	var b: float = _hash01(xi + 1, yi, seed_value)
	var c: float = _hash01(xi, yi + 1, seed_value)
	var d: float = _hash01(xi + 1, yi + 1, seed_value)
	return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)


static func _hash01(x: int, y: int, seed_value: int) -> float:
	var value: int = _mix_hash(seed_value, x * 374761393 + y * 668265263)
	return float(value % 1000003) / 1000003.0


static func _combined_seed(profile: VegetationProfile, stream_name: String) -> int:
	return _mix_hash(profile.generation_seed, VegetationProfile.stable_seed(stream_name))


static func _mix_hash(a: int, b: int) -> int:
	var value: int = int(a) ^ int(b + 0x9e3779b9 + (int(a) << 6) + (int(a) >> 2))
	value = int((value ^ (value >> 16)) * 2246822519) & 0x7fffffff
	return max(value % HASH_LIMIT, 1)
