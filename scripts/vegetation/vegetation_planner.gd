class_name VegetationPlanner
extends RefCounted

const HASH_LIMIT: int = 2147483647
const GRASS_CANDIDATE_MULTIPLIER: float = 1.42
const FLOWER_CANDIDATE_MULTIPLIER: float = 24.0
const FLOWER_CLUSTER_ATTEMPT_MULTIPLIER: int = 60


static func generate_grass(profile: VegetationProfile, support_center: Vector3, support_size: Vector2, support_top_y: float) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if profile == null or profile.grass_instance_count <= 0:
		return placements

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _combined_seed(profile, "grass")
	var target_count: int = profile.grass_instance_count
	var half_x: float = support_size.x * 0.5
	var half_z: float = support_size.y * 0.5
	var support_area: float = maxf(support_size.x * support_size.y, 1.0)
	var candidate_count: float = maxf(float(target_count) * GRASS_CANDIDATE_MULTIPLIER, 1.0)
	var cell_size: float = clampf(sqrt(support_area / candidate_count), 0.42, 2.35)
	var cell_count_x: int = maxi(int(ceil(support_size.x / cell_size)), 1)
	var cell_count_z: int = maxi(int(ceil(support_size.y / cell_size)), 1)
	var primary_items: Array[Dictionary] = []
	var reserve_items: Array[Dictionary] = []

	for z_index in range(cell_count_z):
		for x_index in range(cell_count_x):
			var local_x: float = -half_x + (float(x_index) + rng.randf()) * cell_size
			var local_z: float = -half_z + (float(z_index) + rng.randf()) * cell_size
			if local_x < -half_x or local_x > half_x or local_z < -half_z or local_z > half_z:
				continue
			var density: float = _grass_density_field(profile, local_x, local_z, support_size)
			if density <= 0.015:
				continue
			var item: Dictionary = _make_grass_item(profile, support_center, support_top_y, local_x, local_z, rng, density)
			var acceptance: float = clampf(0.16 + density * 0.92, 0.0, 0.98)
			if rng.randf() <= acceptance:
				primary_items.append(item)
			elif density > 0.28:
				reserve_items.append(item)

	_shuffle_items(primary_items, rng)
	_append_until(placements, primary_items, target_count)
	if placements.size() < target_count:
		_shuffle_items(reserve_items, rng)
		_append_until(placements, reserve_items, target_count)

	var attempts_limit: int = max(target_count * 3, 256)
	var attempts: int = 0
	while placements.size() < target_count and attempts < attempts_limit:
		attempts += 1
		var local_x: float = rng.randf_range(-half_x, half_x)
		var local_z: float = rng.randf_range(-half_z, half_z)
		var density: float = _grass_density_field(profile, local_x, local_z, support_size)
		if density < 0.14:
			continue
		placements.append(_make_grass_item(profile, support_center, support_top_y, local_x, local_z, rng, density))

	return placements


static func generate_grass_budgeted(profile: VegetationProfile, support_center: Vector3, support_size: Vector2, support_top_y: float, frame_owner: Node, batch_size: int = 1024) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if profile == null or profile.grass_instance_count <= 0:
		return placements

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _combined_seed(profile, "grass")
	var target_count: int = profile.grass_instance_count
	var half_x: float = support_size.x * 0.5
	var half_z: float = support_size.y * 0.5
	var support_area: float = maxf(support_size.x * support_size.y, 1.0)
	var candidate_count: float = maxf(float(target_count) * GRASS_CANDIDATE_MULTIPLIER, 1.0)
	var cell_size: float = clampf(sqrt(support_area / candidate_count), 0.42, 2.35)
	var cell_count_x: int = maxi(int(ceil(support_size.x / cell_size)), 1)
	var cell_count_z: int = maxi(int(ceil(support_size.y / cell_size)), 1)
	var primary_items: Array[Dictionary] = []
	var reserve_items: Array[Dictionary] = []
	var processed_since_yield: int = 0
	var safe_batch_size: int = maxi(batch_size, 1)

	for z_index in range(cell_count_z):
		for x_index in range(cell_count_x):
			var local_x: float = -half_x + (float(x_index) + rng.randf()) * cell_size
			var local_z: float = -half_z + (float(z_index) + rng.randf()) * cell_size
			if local_x >= -half_x and local_x <= half_x and local_z >= -half_z and local_z <= half_z:
				var density: float = _grass_density_field(profile, local_x, local_z, support_size)
				if density > 0.015:
					var item: Dictionary = _make_grass_item(profile, support_center, support_top_y, local_x, local_z, rng, density)
					var acceptance: float = clampf(0.16 + density * 0.92, 0.0, 0.98)
					if rng.randf() <= acceptance:
						primary_items.append(item)
					elif density > 0.28:
						reserve_items.append(item)
			processed_since_yield += 1
			if processed_since_yield >= safe_batch_size:
				processed_since_yield = 0
				await _yield_budget_frame(frame_owner)

	_shuffle_items(primary_items, rng)
	_append_until(placements, primary_items, target_count)
	await _yield_budget_frame(frame_owner)
	if placements.size() < target_count:
		_shuffle_items(reserve_items, rng)
		_append_until(placements, reserve_items, target_count)
		await _yield_budget_frame(frame_owner)

	var attempts_limit: int = max(target_count * 3, 256)
	var attempts: int = 0
	processed_since_yield = 0
	while placements.size() < target_count and attempts < attempts_limit:
		attempts += 1
		var local_x: float = rng.randf_range(-half_x, half_x)
		var local_z: float = rng.randf_range(-half_z, half_z)
		var density: float = _grass_density_field(profile, local_x, local_z, support_size)
		if density >= 0.14:
			placements.append(_make_grass_item(profile, support_center, support_top_y, local_x, local_z, rng, density))
		processed_since_yield += 1
		if processed_since_yield >= safe_batch_size:
			processed_since_yield = 0
			await _yield_budget_frame(frame_owner)

	return placements


static func _yield_budget_frame(frame_owner: Node) -> void:
	if frame_owner != null and frame_owner.is_inside_tree() and not RuntimeMode.is_headless():
		await frame_owner.get_tree().process_frame


static func generate_flowers(profile: VegetationProfile, support_center: Vector3, support_size: Vector2, support_top_y: float) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if profile == null or not profile.enable_flowers or profile.flower_instance_count <= 0:
		return placements

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _combined_seed(profile, "flowers")
	var target_count: int = profile.flower_instance_count
	var half_x: float = support_size.x * 0.5
	var half_z: float = support_size.y * 0.5
	var min_flowers: int = clampi(profile.flower_cluster_min_flowers, 2, maxi(profile.flower_cluster_max_flowers, 2))
	var max_flowers: int = maxi(profile.flower_cluster_max_flowers, min_flowers)
	var cluster_target: int = profile.flower_cluster_count
	if cluster_target <= 0:
		cluster_target = maxi(int(ceil(float(target_count) / maxf(float(max_flowers) * 0.72, 1.0))), 1)
	cluster_target = clampi(cluster_target, 1, target_count)
	var cluster_centers: Array[Dictionary] = []
	var attempts_limit: int = maxi(cluster_target * FLOWER_CLUSTER_ATTEMPT_MULTIPLIER, 256)
	var attempts: int = 0
	while cluster_centers.size() < cluster_target and attempts < attempts_limit:
		attempts += 1
		var local_x: float = rng.randf_range(-half_x, half_x)
		var local_z: float = rng.randf_range(-half_z, half_z)
		var density: float = _flower_density_field(profile, local_x, local_z, support_size)
		if density <= 0.05 or rng.randf() > density:
			continue
		var center: Vector2 = Vector2(local_x, local_z)
		if not _accept_flower_cluster(center, cluster_centers, profile.flower_cluster_min_spacing):
			continue
		cluster_centers.append({
			"position": center,
			"density": density,
			"radius": rng.randf_range(profile.flower_cluster_min_radius, profile.flower_cluster_max_radius),
			"height_factor": rng.randf_range(1.0 - profile.flower_cluster_height_variation, 1.0 + profile.flower_cluster_height_variation),
			"palette_anchor": rng.randf(),
		})

	attempts = 0
	while cluster_centers.size() < cluster_target and attempts < attempts_limit:
		attempts += 1
		var local_x: float = rng.randf_range(-half_x, half_x)
		var local_z: float = rng.randf_range(-half_z, half_z)
		var density: float = _flower_density_field(profile, local_x, local_z, support_size)
		if density <= 0.04 or rng.randf() > density * 1.25:
			continue
		var center: Vector2 = Vector2(local_x, local_z)
		if not _accept_flower_cluster(center, cluster_centers, profile.flower_cluster_min_spacing * 0.58):
			continue
		cluster_centers.append({
			"position": center,
			"density": density,
			"radius": rng.randf_range(profile.flower_cluster_min_radius, profile.flower_cluster_max_radius),
			"height_factor": rng.randf_range(1.0 - profile.flower_cluster_height_variation, 1.0 + profile.flower_cluster_height_variation),
			"palette_anchor": rng.randf(),
		})

	_shuffle_items(cluster_centers, rng)
	for cluster in cluster_centers:
		if placements.size() >= target_count:
			break
		var center: Vector2 = cluster.get("position", Vector2.ZERO)
		var cluster_density: float = float(cluster.get("density", 0.5))
		var cluster_radius: float = float(cluster.get("radius", 1.4))
		var height_factor: float = float(cluster.get("height_factor", 1.0))
		var palette_anchor: float = float(cluster.get("palette_anchor", rng.randf()))
		var count: int = rng.randi_range(min_flowers, max_flowers)
		count = mini(count, target_count - placements.size())
		var accepted: int = 0
		var cluster_attempts: int = 0
		var cluster_attempt_limit: int = maxi(count * 5, count)
		while accepted < count and cluster_attempts < cluster_attempt_limit:
			cluster_attempts += 1
			var angle: float = rng.randf_range(-PI, PI)
			var distance: float = sqrt(rng.randf()) * cluster_radius
			var offset: Vector2 = Vector2(cos(angle), sin(angle)) * distance
			var local_position: Vector2 = center + offset
			if absf(local_position.x) > half_x or absf(local_position.y) > half_z:
				continue
			var density: float = maxf(_flower_density_field(profile, local_position.x, local_position.y, support_size), cluster_density * 0.58)
			placements.append(_make_flower_item(profile, support_center, support_top_y, local_position.x, local_position.y, rng, density, height_factor, palette_anchor))
			accepted += 1
			if placements.size() >= target_count:
				break

	return placements


static func generate_trees(profile: VegetationProfile, support_center: Vector3, support_size: Vector2, support_top_y: float) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if profile == null or profile.tree_count <= 0 or profile.tree_scene_paths.is_empty():
		return placements

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
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


static func _make_grass_item(profile: VegetationProfile, support_center: Vector3, support_top_y: float, local_x: float, local_z: float, rng: RandomNumberGenerator, density: float = -1.0) -> Dictionary:
	var density_value: float = clampf(density, 0.0, 1.0)
	if density < 0.0:
		density_value = _grass_density_field(profile, local_x, local_z, profile.fallback_support_size)
	var patch_value: float = _value_noise_2d(local_x * profile.grass_patch_frequency, local_z * profile.grass_patch_frequency, profile.generation_seed)
	var detail_value: float = _value_noise_2d(local_x * profile.grass_patch_frequency * 5.7 + 13.0, local_z * profile.grass_patch_frequency * 5.7 - 29.0, profile.generation_seed + 311)
	var height: float = rng.randf_range(profile.grass_min_height, profile.grass_max_height)
	var height_jitter: float = clampf(profile.grass_height_detail_jitter, 0.0, 0.5)
	var density_height: float = lerpf(1.0 - height_jitter, 1.0 + height_jitter * 0.72, density_value)
	var detail_height: float = lerpf(1.0 - height_jitter * 0.46, 1.0 + height_jitter * 0.36, detail_value)
	height = clampf(height * density_height * detail_height, profile.grass_min_height, profile.grass_max_height)
	var width: float = rng.randf_range(profile.grass_min_width, profile.grass_max_width)
	width *= lerpf(0.86, 1.12, density_value) * lerpf(0.94, 1.04, patch_value)
	var position: Vector3 = Vector3(support_center.x + local_x, support_top_y + 0.035, support_center.z + local_z)
	var scale: Vector3 = Vector3(width, height, width)
	return {
		"position": position,
		"yaw": rng.randf_range(-PI, PI),
		"scale": scale,
		"stiffness": rng.randf_range(0.34, 0.78),
		"phase": rng.randf(),
		"color_bias": clampf((density_value - 0.5) * 0.34 + (patch_value - 0.5) * 0.24 + rng.randf_range(-0.08, 0.08), -0.55, 0.65),
	}


static func _make_flower_item(profile: VegetationProfile, support_center: Vector3, support_top_y: float, local_x: float, local_z: float, rng: RandomNumberGenerator, density: float, cluster_height_factor: float = 1.0, cluster_palette: float = 0.0) -> Dictionary:
	var density_value: float = clampf(density, 0.0, 1.0)
	var patch_value: float = _value_noise_2d(local_x * profile.flower_patch_frequency + 41.0, local_z * profile.flower_patch_frequency - 17.0, profile.generation_seed + 719)
	var height: float = rng.randf_range(profile.flower_min_height, profile.flower_max_height)
	height *= cluster_height_factor * lerpf(0.92, 1.12, density_value) * lerpf(0.94, 1.08, patch_value)
	height = clampf(height, profile.flower_min_height, profile.flower_max_height * 1.18)
	var width: float = rng.randf_range(profile.flower_min_width, profile.flower_max_width)
	width *= lerpf(0.88, 1.16, patch_value) * lerpf(0.94, 1.10, cluster_height_factor)
	var palette: float = fposmod(cluster_palette + rng.randf_range(-0.16, 0.18) + patch_value * 0.11, 1.0)
	var position: Vector3 = Vector3(support_center.x + local_x, support_top_y + 0.045, support_center.z + local_z)
	var scale: Vector3 = Vector3(width, height, width)
	return {
		"position": position,
		"yaw": rng.randf_range(-PI, PI),
		"scale": scale,
		"stiffness": rng.randf_range(0.24, 0.54),
		"phase": rng.randf(),
		"color_bias": rng.randf_range(-0.08, 0.10),
		"palette": palette,
	}


static func _make_edge_grass_item(profile: VegetationProfile, support_center: Vector3, support_size: Vector2, support_top_y: float, rng: RandomNumberGenerator) -> Dictionary:
	var local_position: Vector2 = _edge_position(profile, support_size, rng)
	var density: float = _grass_density_field(profile, local_position.x, local_position.y, support_size)
	return _make_grass_item(profile, support_center, support_top_y, local_position.x, local_position.y, rng, density)


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
	var density: float = _grass_density_field(profile, local_x, local_z, support_size)
	return rng.randf() <= density


static func _accept_flower_cluster(center: Vector2, existing_clusters: Array[Dictionary], min_spacing: float) -> bool:
	var safe_spacing: float = maxf(min_spacing, 0.1)
	for item in existing_clusters:
		var other_center: Vector2 = item.get("position", Vector2.ZERO)
		var other_radius: float = float(item.get("radius", 0.0))
		if center.distance_to(other_center) < safe_spacing + other_radius * 0.42:
			return false
	return true


static func _flower_density_field(profile: VegetationProfile, local_x: float, local_z: float, support_size: Vector2) -> float:
	var grass_density: float = _grass_density_field(profile, local_x, local_z, support_size)
	if grass_density <= 0.02:
		return 0.0
	var frequency: float = maxf(profile.flower_patch_frequency, 0.0005)
	var broad: float = _value_noise_2d(local_x * frequency + 29.0, local_z * frequency - 43.0, profile.generation_seed + 503)
	var middle: float = _value_noise_2d((local_x - 13.0) * frequency * 2.9, (local_z + 7.0) * frequency * 2.9, profile.generation_seed + 911)
	var flower_patch: float = smoothstep(0.34, 0.92, broad * 0.72 + middle * 0.28)
	var density: float = grass_density * flower_patch * clampf(profile.flower_density, 0.0, 1.0) * 3.8
	return clampf(density, 0.0, 0.92)


static func _grass_density_field(profile: VegetationProfile, local_x: float, local_z: float, support_size: Vector2) -> float:
	var half_x: float = maxf(support_size.x * 0.5, 1.0)
	var half_z: float = maxf(support_size.y * 0.5, 1.0)
	var edge_amount: float = maxf(absf(local_x) / half_x, absf(local_z) / half_z)
	var frequency: float = maxf(profile.grass_patch_frequency, 0.0005)
	var broad: float = _value_noise_2d(local_x * frequency, local_z * frequency, profile.generation_seed)
	var middle: float = _value_noise_2d((local_x + 37.0) * frequency * 2.55, (local_z - 19.0) * frequency * 2.55, profile.generation_seed + 101)
	var fine: float = _value_noise_2d((local_x - 11.0) * frequency * 6.20, (local_z + 23.0) * frequency * 6.20, profile.generation_seed + 227)
	var blended: float = broad * 0.52 + middle * 0.31 + fine * 0.17
	var density: float = smoothstep(0.18, 0.93, blended)
	density = density * 0.82 + 0.18
	var edge_fade: float = 1.0 - smoothstep(0.88, 1.02, edge_amount)
	density *= edge_fade
	density += edge_amount * profile.grass_edge_bias * 0.16
	var lane_clearance: float = clampf(profile.grass_lane_clearance, 0.0, 1.0)
	if lane_clearance > 0.001:
		var in_service_lane: bool = absf(local_x) < half_x * 0.18 or absf(local_z) < half_z * 0.12
		if in_service_lane:
			density *= 1.0 - lane_clearance * 0.72
	density *= _vegetation_exclusion_scale(profile, local_x, local_z)
	return clampf(density, 0.0, 1.0)


static func _vegetation_exclusion_scale(profile: VegetationProfile, local_x: float, local_z: float) -> float:
	var radius: float = maxf(profile.vegetation_exclusion_radius, 0.0)
	if radius <= 0.001 or profile.vegetation_exclusion_segments.is_empty():
		return 1.0
	var point: Vector2 = Vector2(local_x, local_z)
	var closest_distance: float = 1000000.0
	for packed_segment in profile.vegetation_exclusion_segments:
		var segment: Vector4 = packed_segment
		var from_point: Vector2 = Vector2(segment.x, segment.y)
		var to_point: Vector2 = Vector2(segment.z, segment.w)
		closest_distance = minf(closest_distance, _distance_to_segment(point, from_point, to_point))
	var feather_start: float = maxf(radius * 0.58, 0.08)
	var feather: float = smoothstep(feather_start, radius, closest_distance)
	return lerpf(clampf(profile.vegetation_exclusion_center_density, 0.0, 1.0), 1.0, feather)


static func _distance_to_segment(point: Vector2, from_point: Vector2, to_point: Vector2) -> float:
	var segment: Vector2 = to_point - from_point
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(from_point)
	var t: float = clampf((point - from_point).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(from_point + segment * t)


static func _append_until(target: Array[Dictionary], source: Array[Dictionary], target_count: int) -> void:
	for item in source:
		if target.size() >= target_count:
			return
		target.append(item)


static func _shuffle_items(items: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: Dictionary = items[index]
		items[index] = items[swap_index]
		items[swap_index] = temporary


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
