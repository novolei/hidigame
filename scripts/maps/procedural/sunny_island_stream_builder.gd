class_name SunnyIslandStreamBuilder
extends RefCounted


static func make_exclusion_segments(terrain_radius: float) -> Array[Vector4]:
	var segments: Array[Vector4] = []
	var stream_paths: Array = _make_stream_paths(terrain_radius)
	for control_points in stream_paths:
		var samples: Array[Vector2] = _sample_stream_path(control_points, 10)
		for sample_index in range(samples.size() - 1):
			var from_point: Vector2 = samples[sample_index]
			var to_point: Vector2 = samples[sample_index + 1]
			segments.append(Vector4(from_point.x, from_point.y, to_point.x, to_point.y))
	return segments


static func stream_clearance_radius(terrain_radius: float) -> float:
	var base_width: float = clampf(terrain_radius * 0.050, 2.45, 4.15)
	return base_width * 0.5 + 1.45


static func stream_bed_depth(terrain_radius: float) -> float:
	return clampf(terrain_radius * 0.0105, 0.56, 1.02)


static func stream_water_depth(terrain_radius: float) -> float:
	return stream_bed_depth(terrain_radius) * 0.64 + 0.12


static func stream_depth_at(point: Vector2, terrain_radius: float) -> float:
	var distance: float = _closest_distance_to_streams(point, terrain_radius)
	var carve_radius: float = stream_clearance_radius(terrain_radius) + 0.62
	var flat_radius: float = carve_radius * 0.34
	var channel: float = 1.0 - smoothstep(flat_radius, carve_radius, distance)
	var center_bias: float = 1.0 - smoothstep(0.0, flat_radius, distance)
	return clampf(channel * 0.88 + center_bias * 0.12, 0.0, 1.0)


static func build(parent: Node3D, terrain_radius: float, generation_seed: int, shader_path: String, sand_material: Material, rock_scenes: Array[String], terrain_point_callable: Callable, spawn_asset_callable: Callable) -> ShaderMaterial:
	if parent == null or not terrain_point_callable.is_valid():
		return null

	var stream_material: ShaderMaterial = _create_stream_material(shader_path, terrain_radius)
	if stream_material == null:
		return null

	var stream_root: Node3D = Node3D.new()
	stream_root.name = "IslandStreamChannels"
	parent.add_child(stream_root)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(generation_seed) + int(terrain_radius * 131.0)
	var stream_paths: Array = _make_stream_paths(terrain_radius)
	var base_width: float = clampf(terrain_radius * 0.050, 2.45, 4.15)
	var bank_margin: float = maxf(1.35, base_width * 0.48)
	var water_depth: float = stream_water_depth(terrain_radius)
	for path_index in range(stream_paths.size()):
		var control_points: Array = stream_paths[path_index]
		var samples: Array[Vector2] = _sample_stream_path(control_points, 10)
		if samples.size() < 2:
			continue
		var water_width: float = base_width * lerpf(0.88, 1.12, _value_noise_2d(float(path_index) * 2.7, 3.5, generation_seed + 606))
		var bed_mesh: ArrayMesh = _create_stream_bed_mesh(samples, water_width, bank_margin, float(path_index) * 2.0, terrain_radius, terrain_point_callable)
		var bed: MeshInstance3D = MeshInstance3D.new()
		bed.name = "StreamBed_%02d" % path_index
		bed.mesh = bed_mesh
		bed.material_override = sand_material
		bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bed.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		stream_root.add_child(bed)

		var water_mesh: ArrayMesh = _create_stream_water_mesh(samples, water_width, water_depth, float(path_index) * 3.17, terrain_radius, terrain_point_callable)
		var water: MeshInstance3D = MeshInstance3D.new()
		water.name = "StreamWater_%02d" % path_index
		water.mesh = water_mesh
		water.material_override = stream_material
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		stream_root.add_child(water)
		_decorate_stream_banks(stream_root, samples, water_width, path_index, rng, rock_scenes, spawn_asset_callable)

	var ripple_sampler: WaterRippleSampler = WaterRippleSampler.new()
	ripple_sampler.name = "StreamRippleSampler"
	ripple_sampler.configure(stream_material, 2.55, 8, 0.26)
	stream_root.add_child(ripple_sampler)
	return stream_material


static func _create_stream_material(shader_path: String, terrain_radius: float) -> ShaderMaterial:
	var shader: Shader = load(shader_path) as Shader
	if shader == null:
		return null
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_name = "SunnyIslandStreamMaterial"
	material.shader = shader
	material.set_shader_parameter("shallow_color", Color(0.10, 0.88, 0.78, 0.76))
	material.set_shader_parameter("deep_color", Color(0.02, 0.34, 0.60, 0.92))
	material.set_shader_parameter("underwater_color", Color(0.03, 0.66, 0.76, 0.62))
	material.set_shader_parameter("highlight_color", Color(0.86, 1.0, 0.95, 0.72))
	material.set_shader_parameter("foam_color", Color(0.90, 1.0, 0.94, 0.76))
	material.set_shader_parameter("max_depth", maxf(1.15, stream_bed_depth(terrain_radius) * 2.60))
	material.set_shader_parameter("depth_fade", 0.70)
	material.set_shader_parameter("refraction_strength", 0.034)
	material.set_shader_parameter("normal_strength", 0.42)
	material.set_shader_parameter("glint_strength", 0.72)
	material.set_shader_parameter("shore_foam_width", 0.38)
	material.set_shader_parameter("wave_height", 0.072)
	material.set_shader_parameter("wave_speed", 0.94)
	material.set_shader_parameter("flow_scale", 14.6)
	material.set_shader_parameter("ripple_height", 0.13)
	material.set_shader_parameter("ripple_speed", 2.9)
	material.set_shader_parameter("ripple_width", 0.24)
	material.set_shader_parameter("ripple_decay", 1.95)
	return material


static func _make_stream_paths(radius: float) -> Array:
	var paths: Array = []
	paths.append([
		Vector2(-radius * 0.62, radius * 0.30),
		Vector2(-radius * 0.42, radius * 0.18),
		Vector2(-radius * 0.18, radius * 0.22),
		Vector2(radius * 0.08, radius * 0.09),
		Vector2(radius * 0.36, radius * 0.18),
		Vector2(radius * 0.61, radius * 0.08),
	])
	paths.append([
		Vector2(-radius * 0.50, -radius * 0.34),
		Vector2(-radius * 0.26, -radius * 0.22),
		Vector2(-radius * 0.05, -radius * 0.32),
		Vector2(radius * 0.22, -radius * 0.22),
		Vector2(radius * 0.50, -radius * 0.34),
	])
	if radius >= 60.0:
		paths.append([
			Vector2(-radius * 0.24, radius * 0.54),
			Vector2(-radius * 0.08, radius * 0.38),
			Vector2(radius * 0.14, radius * 0.42),
			Vector2(radius * 0.34, radius * 0.30),
			Vector2(radius * 0.56, radius * 0.42),
		])
	return paths


static func _sample_stream_path(control_points: Array, subdivisions: int) -> Array[Vector2]:
	var sampled_points: Array[Vector2] = []
	if control_points.size() < 2:
		return sampled_points
	var safe_subdivisions: int = maxi(subdivisions, 2)
	for point_index in range(control_points.size() - 1):
		var p0: Vector2 = control_points[maxi(point_index - 1, 0)]
		var p1: Vector2 = control_points[point_index]
		var p2: Vector2 = control_points[point_index + 1]
		var p3: Vector2 = control_points[mini(point_index + 2, control_points.size() - 1)]
		for subdivision in range(safe_subdivisions):
			var t: float = float(subdivision) / float(safe_subdivisions)
			var point: Vector2 = _catmull_rom(p0, p1, p2, p3, t)
			if sampled_points.is_empty() or sampled_points[-1].distance_to(point) > 0.08:
				sampled_points.append(point)
	var last_point: Vector2 = control_points[control_points.size() - 1]
	if sampled_points.is_empty() or sampled_points[-1].distance_to(last_point) > 0.08:
		sampled_points.append(last_point)
	return sampled_points


static func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return (p1 * 2.0 + (p2 - p0) * t + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2 + (p0 * -1.0 + p1 * 3.0 - p2 * 3.0 + p3) * t3) * 0.5


static func _closest_distance_to_streams(point: Vector2, terrain_radius: float) -> float:
	var closest: float = 1000000.0
	var stream_paths: Array = _make_stream_paths(terrain_radius)
	for control_points in stream_paths:
		var samples: Array[Vector2] = _sample_stream_path(control_points, 8)
		for sample_index in range(samples.size() - 1):
			closest = minf(closest, _distance_to_segment(point, samples[sample_index], samples[sample_index + 1]))
	return closest


static func _distance_to_segment(point: Vector2, from_point: Vector2, to_point: Vector2) -> float:
	var segment: Vector2 = to_point - from_point
	var length_squared: float = maxf(segment.length_squared(), 0.0001)
	var t: float = clampf((point - from_point).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(from_point + segment * t)


static func _create_stream_bed_mesh(samples: Array[Vector2], water_width: float, bank_margin: float, uv_offset: float, terrain_radius: float, terrain_point_callable: Callable) -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var water_half: float = water_width * 0.5
	var outer_half: float = water_half + bank_margin
	var lane_offsets: Array[float] = [-outer_half, -water_half - bank_margin * 0.34, -water_half * 0.52, 0.0, water_half * 0.52, water_half + bank_margin * 0.34, outer_half]
	var lane_uvs: Array[float] = [0.0, 0.18, 0.36, 0.5, 0.64, 0.82, 1.0]
	var lane_lifts: Array[float] = [0.078, 0.054, 0.036, 0.030, 0.036, 0.054, 0.078]
	var distance_along: float = 0.0
	for sample_index in range(samples.size() - 1):
		var current: Vector2 = samples[sample_index]
		var next: Vector2 = samples[sample_index + 1]
		var segment_length: float = current.distance_to(next)
		if segment_length < 0.01:
			continue
		var current_normal: Vector2 = _stream_normal_at(samples, sample_index)
		var next_normal: Vector2 = _stream_normal_at(samples, sample_index + 1)
		var uv_v0: float = distance_along * 0.12 + uv_offset
		var uv_v1: float = (distance_along + segment_length) * 0.12 + uv_offset
		for lane_index in range(lane_offsets.size() - 1):
			var current_a: Vector3 = _stream_surface_point(current + current_normal * lane_offsets[lane_index], lane_lifts[lane_index], terrain_radius, terrain_point_callable)
			var current_b: Vector3 = _stream_surface_point(current + current_normal * lane_offsets[lane_index + 1], lane_lifts[lane_index + 1], terrain_radius, terrain_point_callable)
			var next_a: Vector3 = _stream_surface_point(next + next_normal * lane_offsets[lane_index], lane_lifts[lane_index], terrain_radius, terrain_point_callable)
			var next_b: Vector3 = _stream_surface_point(next + next_normal * lane_offsets[lane_index + 1], lane_lifts[lane_index + 1], terrain_radius, terrain_point_callable)
			_add_stream_vertex(surface_tool, current_a, Vector2(lane_uvs[lane_index], uv_v0))
			_add_stream_vertex(surface_tool, current_b, Vector2(lane_uvs[lane_index + 1], uv_v0))
			_add_stream_vertex(surface_tool, next_b, Vector2(lane_uvs[lane_index + 1], uv_v1))
			_add_stream_vertex(surface_tool, current_a, Vector2(lane_uvs[lane_index], uv_v0))
			_add_stream_vertex(surface_tool, next_b, Vector2(lane_uvs[lane_index + 1], uv_v1))
			_add_stream_vertex(surface_tool, next_a, Vector2(lane_uvs[lane_index], uv_v1))
		distance_along += segment_length
	surface_tool.generate_normals()
	return surface_tool.commit()


static func _create_stream_water_mesh(samples: Array[Vector2], width: float, y_offset: float, uv_offset: float, terrain_radius: float, terrain_point_callable: Callable) -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width: float = width * 0.5
	var distance_along: float = 0.0
	for sample_index in range(samples.size() - 1):
		var current: Vector2 = samples[sample_index]
		var next: Vector2 = samples[sample_index + 1]
		var segment_length: float = current.distance_to(next)
		if segment_length < 0.01:
			continue
		var current_normal: Vector2 = _stream_normal_at(samples, sample_index)
		var next_normal: Vector2 = _stream_normal_at(samples, sample_index + 1)
		var current_center: Vector3 = _stream_surface_point(current, y_offset, terrain_radius, terrain_point_callable)
		var next_center: Vector3 = _stream_surface_point(next, y_offset, terrain_radius, terrain_point_callable)
		var left_current: Vector3 = Vector3(current.x + current_normal.x * half_width, current_center.y, current.y + current_normal.y * half_width)
		var right_current: Vector3 = Vector3(current.x - current_normal.x * half_width, current_center.y, current.y - current_normal.y * half_width)
		var left_next: Vector3 = Vector3(next.x + next_normal.x * half_width, next_center.y, next.y + next_normal.y * half_width)
		var right_next: Vector3 = Vector3(next.x - next_normal.x * half_width, next_center.y, next.y - next_normal.y * half_width)
		var uv_v0: float = distance_along * 0.12 + uv_offset
		var uv_v1: float = (distance_along + segment_length) * 0.12 + uv_offset
		_add_stream_vertex(surface_tool, left_current, Vector2(0.0, uv_v0))
		_add_stream_vertex(surface_tool, right_current, Vector2(1.0, uv_v0))
		_add_stream_vertex(surface_tool, right_next, Vector2(1.0, uv_v1))
		_add_stream_vertex(surface_tool, left_current, Vector2(0.0, uv_v0))
		_add_stream_vertex(surface_tool, right_next, Vector2(1.0, uv_v1))
		_add_stream_vertex(surface_tool, left_next, Vector2(0.0, uv_v1))
		distance_along += segment_length
	surface_tool.generate_normals()
	return surface_tool.commit()


static func _stream_surface_point(point: Vector2, y_offset: float, terrain_radius: float, terrain_point_callable: Callable) -> Vector3:
	var terrain_position: Vector3 = terrain_point_callable.call(point.x, point.y, terrain_radius)
	return terrain_position + Vector3.UP * y_offset


static func _stream_normal_at(samples: Array[Vector2], sample_index: int) -> Vector2:
	var previous_index: int = maxi(sample_index - 1, 0)
	var next_index: int = mini(sample_index + 1, samples.size() - 1)
	var tangent: Vector2 = samples[next_index] - samples[previous_index]
	if tangent.length() < 0.001:
		return Vector2.RIGHT
	var direction: Vector2 = tangent.normalized()
	return Vector2(-direction.y, direction.x)


static func _add_stream_vertex(surface_tool: SurfaceTool, vertex: Vector3, uv: Vector2) -> void:
	surface_tool.set_uv(uv)
	surface_tool.add_vertex(vertex)


static func _decorate_stream_banks(parent: Node3D, samples: Array[Vector2], width: float, path_index: int, rng: RandomNumberGenerator, rock_scenes: Array[String], spawn_asset_callable: Callable) -> void:
	if rock_scenes.is_empty() or samples.size() < 8 or not spawn_asset_callable.is_valid():
		return
	var step: int = maxi(8, int(floor(float(samples.size()) / 5.0)))
	for sample_index in range(step, samples.size() - step, step):
		if rng.randf() > 0.72:
			continue
		var bank_side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var normal: Vector2 = _stream_normal_at(samples, sample_index)
		var base_point: Vector2 = samples[sample_index]
		var offset: Vector2 = normal * bank_side * (width * 0.5 + rng.randf_range(1.25, 2.75))
		var asset_position: Vector3 = Vector3(base_point.x + offset.x, 0.0, base_point.y + offset.y)
		var scene_path: String = rock_scenes[(sample_index + path_index) % rock_scenes.size()]
		var rock_scale: float = rng.randf_range(0.62, 1.20)
		spawn_asset_callable.call(parent, scene_path, "StreamBankRock_%02d_%02d" % [path_index, sample_index], asset_position, rng.randf_range(-PI, PI), Vector3(rock_scale, rock_scale, rock_scale), true)


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


static func _mix_hash(a: int, b: int) -> int:
	var value: int = int(a) ^ int(b + 0x9e3779b9 + (int(a) << 6) + (int(a) >> 2))
	value = int((value ^ (value >> 16)) * 2246822519) & 0x7fffffff
	return max(value, 1)
