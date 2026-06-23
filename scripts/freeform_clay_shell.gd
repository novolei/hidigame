extends Node3D
class_name FreeformClayShell

const PROFILE_VERSION := 1
const DEFAULT_HEIGHT := 1.75
const DEFAULT_RADIUS_X := 0.42
const DEFAULT_RADIUS_Z := 0.34
const SEGMENTS := 18
const ELLIPSOID_RINGS := 12
const CAPSULE_RINGS := 14
const DEFAULT_COLOR := Color(0.72, 0.68, 1.0, 1.0)
const DELTA_QUANTIZATION := 10000.0
const BASIC_HUMAN_MESH_PATH := "res://assets/characters/basic/BaseModel.obj"
const BASIC_HUMAN_SOURCE := "basic_humanoid_asset_mesh"
const PROCEDURAL_HUMAN_SOURCE := "freeform_basic_human_surface"
const DEFAULT_SCULPT_RADIUS := 0.22
const EDIT_BOUNDS_POSITION := Vector3(-1.18, -0.08, -0.85)
const EDIT_BOUNDS_SIZE := Vector3(2.36, 2.45, 1.70)
const MAX_VOLUME_DRIFT_RATIO := 0.12
const VOLUME_CORRECTION_GAIN := 0.34
const VOLUME_CORRECTION_MAX_STEP := 0.025
const MIN_TRUSTED_RUNTIME_SOURCE_HEIGHT := 1.0
const WELD_POSITION_QUANTIZATION := 10000.0
const CLAY_ADD_STEP_RATIO := 0.13
const CLAY_REMOVE_STEP_RATIO := 0.11
const CLAY_STRETCH_STEP_RATIO := 0.18
const CLAY_RELAX_ADD := 0.42
const CLAY_RELAX_FLATTEN := 0.26
const CLAY_RELAX_STRETCH := 0.48
const CLAY_SPIKE_DAMPING := 0.38
const CLAY_SPIKE_EDGE_MULTIPLIER := 2.35
const CLAY_SPIKE_MIN_DEVIATION_RATIO := 0.16

const TOOL_ADD := "add"
const TOOL_REMOVE := "remove"
const TOOL_STRETCH := "stretch"
const TOOL_GRAB := "grab"
const TOOL_PUSH_PULL := "push_pull"
const TOOL_FLATTEN := "flatten"
const TOOL_SMOOTH := "smooth"

var _rest_vertices := PackedVector3Array()
var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _neighbors: Array = []
var _weld_groups: Array = []
var _component_ids := PackedInt32Array()
var _last_stroke := {}
var _last_snapshot_apply_ok := false
var _rest_volume := 0.0
var _last_volume_drift_ratio := 0.0
var _source_name := BASIC_HUMAN_SOURCE
var _source_path := BASIC_HUMAN_MESH_PATH
var _source_mesh_count := 1
var _matched_scene_scale := false
var _scale_reference := "asset_default_playable_scale"
var _shell_material: StandardMaterial3D = null

@onready var body_mesh: MeshInstance3D = get_node_or_null("BodyMesh")

signal rebuilt


func _ready() -> void:
	_ensure_mesh_node()
	if _vertices.is_empty():
		reset_to_default_shell()


func reset_to_default_shell() -> void:
	reset_to_basic_human_shell()


func reset_to_basic_human_shell() -> void:
	_ensure_mesh_node()
	if not _build_basic_human_asset_surface():
		_build_default_surface()
	rebuild_mesh()


func reset_to_character_mesh_shell(source_meshes: Array) -> void:
	reset_to_basic_human_shell()
	if _match_rest_surface_to_source_mesh_bounds(source_meshes):
		rebuild_mesh()


func apply_sculpt_stroke_world(tool_name: String, world_position: Vector3, world_radius: float = DEFAULT_SCULPT_RADIUS, strength: float = 1.0) -> Dictionary:
	var local_position := to_local(world_position)
	var local_radius := _world_radius_to_local_radius(world_radius)
	return apply_sculpt_stroke_local(tool_name, local_position, local_radius, strength)


func apply_sculpt_stroke_local(tool_name: String, local_position: Vector3, radius: float = DEFAULT_SCULPT_RADIUS, strength: float = 1.0) -> Dictionary:
	var bounds := get_edit_bounds()
	var clamped_position := _clamp_point_to_aabb(local_position, bounds)
	var was_clamped := clamped_position.distance_squared_to(local_position) > 0.000001
	var clean_radius := clampf(radius, 0.01, maxf(EDIT_BOUNDS_SIZE.x, maxf(EDIT_BOUNDS_SIZE.y, EDIT_BOUNDS_SIZE.z)))
	var component_id := _nearest_component_id(clamped_position)
	var brush_normal := _surface_normal_near_local(clamped_position, clean_radius, component_id)
	var summary := {}
	match tool_name:
		TOOL_ADD:
			summary = apply_push_pull_stroke_local(clamped_position, clean_radius * CLAY_ADD_STEP_RATIO, clean_radius, strength, brush_normal, component_id, CLAY_RELAX_ADD)
		TOOL_REMOVE:
			summary = apply_push_pull_stroke_local(clamped_position, -clean_radius * CLAY_REMOVE_STEP_RATIO, clean_radius, strength, brush_normal, component_id, CLAY_RELAX_ADD)
		TOOL_SMOOTH:
			summary = apply_smooth_stroke_local(clamped_position, clean_radius, strength, component_id)
		TOOL_STRETCH:
			summary = apply_push_pull_stroke_local(clamped_position, clean_radius * CLAY_STRETCH_STEP_RATIO, clean_radius * 1.22, strength, brush_normal, component_id, CLAY_RELAX_STRETCH)
		TOOL_FLATTEN:
			summary = apply_flatten_stroke_local(clamped_position, brush_normal, clean_radius, strength, component_id)
		_:
			summary = apply_push_pull_stroke_local(clamped_position, clean_radius * CLAY_ADD_STEP_RATIO, clean_radius, strength, brush_normal, component_id, CLAY_RELAX_ADD)
	summary["requested_tool"] = tool_name
	summary["operation_tool"] = summary.get("tool", tool_name)
	summary["tool"] = tool_name
	summary["clamped"] = was_clamped
	return summary


func apply_grab_stroke_local(local_position: Vector3, local_delta: Vector3, radius: float, strength: float = 1.0, component_id: int = -1) -> Dictionary:
	var clean_radius := maxf(radius, 0.01)
	var clean_strength := clampf(strength, 0.0, 2.0)
	var filter_component := component_id if component_id >= 0 else _nearest_component_id(local_position)
	var changed := 0
	for i in range(_vertices.size()):
		if not _vertex_matches_component(i, filter_component):
			continue
		var distance := _vertices[i].distance_to(local_position)
		if distance > clean_radius:
			continue
		var falloff := _brush_falloff(distance, clean_radius) * clean_strength
		_vertices[i] += local_delta * falloff
		changed += 1
	_finalize_clay_geometry_edit(local_position, clean_radius, filter_component, 0.18 * clean_strength, 0.30)
	rebuild_mesh()
	_last_stroke = _stroke_summary(TOOL_GRAB, changed, clean_radius)
	return _last_stroke.duplicate(true)


func apply_push_pull_stroke_local(
	local_position: Vector3,
	amount: float,
	radius: float,
	strength: float = 1.0,
	brush_normal: Vector3 = Vector3.ZERO,
	component_id: int = -1,
	relax_amount: float = CLAY_RELAX_ADD
) -> Dictionary:
	var clean_radius := maxf(radius, 0.01)
	var clean_strength := clampf(strength, 0.0, 1.35)
	var filter_component := component_id if component_id >= 0 else _nearest_component_id(local_position)
	var normal := brush_normal.normalized() if brush_normal.length_squared() > 0.0001 else _surface_normal_near_local(local_position, clean_radius, filter_component)
	var changed := 0
	var capped_amount := clampf(amount, -clean_radius * CLAY_STRETCH_STEP_RATIO, clean_radius * CLAY_STRETCH_STEP_RATIO)
	for i in range(_vertices.size()):
		if not _vertex_matches_component(i, filter_component):
			continue
		var distance := _vertices[i].distance_to(local_position)
		if distance > clean_radius:
			continue
		var falloff := _brush_falloff(distance, clean_radius) * clean_strength
		var plane_distance := (_vertices[i] - local_position).dot(normal)
		var buildup_damping := clampf(1.0 - maxf(plane_distance, 0.0) / maxf(clean_radius * 0.72, 0.001), 0.35, 1.0)
		_vertices[i] += normal * capped_amount * falloff * buildup_damping
		changed += 1
	_finalize_clay_geometry_edit(local_position, clean_radius * 1.12, filter_component, relax_amount * clean_strength, CLAY_SPIKE_DAMPING)
	rebuild_mesh()
	_last_stroke = _stroke_summary(TOOL_PUSH_PULL, changed, clean_radius)
	return _last_stroke.duplicate(true)


func apply_flatten_stroke_local(local_position: Vector3, plane_normal: Vector3, radius: float, strength: float = 1.0, component_id: int = -1) -> Dictionary:
	var clean_radius := maxf(radius, 0.01)
	var clean_strength := clampf(strength, 0.0, 1.0)
	var filter_component := component_id if component_id >= 0 else _nearest_component_id(local_position)
	var normal := plane_normal.normalized() if plane_normal.length_squared() > 0.0001 else Vector3.UP
	var changed := 0
	for i in range(_vertices.size()):
		if not _vertex_matches_component(i, filter_component):
			continue
		var distance := _vertices[i].distance_to(local_position)
		if distance > clean_radius:
			continue
		var plane_distance := (_vertices[i] - local_position).dot(normal)
		var falloff := _brush_falloff(distance, clean_radius) * clean_strength
		_vertices[i] -= normal * plane_distance * falloff
		changed += 1
	_finalize_clay_geometry_edit(local_position, clean_radius, filter_component, CLAY_RELAX_FLATTEN * clean_strength, 0.24)
	rebuild_mesh()
	_last_stroke = _stroke_summary(TOOL_FLATTEN, changed, clean_radius)
	return _last_stroke.duplicate(true)


func apply_smooth_stroke_local(local_position: Vector3, radius: float, strength: float = 1.0, component_id: int = -1) -> Dictionary:
	var clean_radius := maxf(radius, 0.01)
	var clean_strength := clampf(strength, 0.0, 1.0)
	var filter_component := component_id if component_id >= 0 else _nearest_component_id(local_position)
	var before := _vertices.duplicate()
	var changed := 0
	for i in range(_vertices.size()):
		if not _vertex_matches_component(i, filter_component):
			continue
		var distance := before[i].distance_to(local_position)
		if distance > clean_radius:
			continue
		var neighbor_indices: Array = _neighbors[i] if i < _neighbors.size() else []
		if neighbor_indices.is_empty():
			continue
		var average := Vector3.ZERO
		for neighbor_index in neighbor_indices:
			average += before[int(neighbor_index)]
		average /= float(neighbor_indices.size())
		var falloff := _brush_falloff(distance, clean_radius) * clean_strength
		_vertices[i] = before[i].lerp(average, falloff)
		changed += 1
	_finalize_clay_geometry_edit(local_position, clean_radius, filter_component, 0.0, 0.20)
	rebuild_mesh()
	_last_stroke = _stroke_summary(TOOL_SMOOTH, changed, clean_radius)
	return _last_stroke.duplicate(true)


func paint_sphere_local(local_position: Vector3, radius: float, color: Color) -> Dictionary:
	var clean_radius := maxf(radius, 0.01)
	var clean_color := color
	clean_color.a = 1.0
	var changed := 0
	for i in range(_vertices.size()):
		var distance := _vertices[i].distance_to(local_position)
		if distance > clean_radius:
			continue
		var falloff := _brush_falloff(distance, clean_radius)
		_colors[i] = _colors[i].lerp(clean_color, falloff)
		changed += 1
	rebuild_mesh()
	_last_stroke = _stroke_summary("paint", changed, clean_radius)
	return _last_stroke.duplicate(true)


func paint_sphere_world(world_position: Vector3, world_radius: float, color: Color) -> Dictionary:
	return paint_sphere_local(to_local(world_position), _world_radius_to_local_radius(world_radius), color)


func intersect_ray_world(world_origin: Vector3, world_direction: Vector3, max_distance: float = 64.0) -> Dictionary:
	if _vertices.is_empty() or _indices.is_empty() or world_direction.length_squared() <= 0.000001:
		return {}
	var local_origin := to_local(world_origin)
	var local_direction := (global_transform.basis.inverse() * world_direction).normalized()
	var max_local_distance := _world_radius_to_local_radius(max_distance)
	var best_distance := INF
	var best_position := Vector3.ZERO
	var best_normal := Vector3.UP
	for i in range(0, _indices.size(), 3):
		var i0 := _indices[i]
		var i1 := _indices[i + 1]
		var i2 := _indices[i + 2]
		var hit := _ray_intersects_triangle(local_origin, local_direction, _vertices[i0], _vertices[i1], _vertices[i2])
		if hit < 0.0 or hit > max_local_distance or hit >= best_distance:
			continue
		best_distance = hit
		best_position = local_origin + local_direction * hit
		var n0 := _normals[i0] if i0 < _normals.size() else Vector3.UP
		var n1 := _normals[i1] if i1 < _normals.size() else Vector3.UP
		var n2 := _normals[i2] if i2 < _normals.size() else Vector3.UP
		best_normal = (n0 + n1 + n2).normalized()
		if best_normal.length_squared() <= 0.000001:
			best_normal = (_vertices[i1] - _vertices[i0]).cross(_vertices[i2] - _vertices[i0]).normalized()
	if best_distance == INF:
		return {}
	var world_position := global_transform * best_position
	return {
		"position": world_position,
		"normal": (global_transform.basis * best_normal).normalized(),
		"local_position": best_position,
		"distance": world_origin.distance_to(world_position),
		"collider": self,
		"mesh_path": body_mesh.get_path() if body_mesh and body_mesh.is_inside_tree() else NodePath(""),
	}


func soft_reset_sphere_world(world_position: Vector3, world_radius: float, amount: float = 0.35) -> Dictionary:
	return soft_reset_sphere_local(to_local(world_position), _world_radius_to_local_radius(world_radius), amount)


func soft_reset_sphere_local(local_position: Vector3, radius: float, amount: float = 0.35) -> Dictionary:
	var clean_radius := maxf(radius, 0.01)
	var clean_amount := clampf(amount, 0.0, 1.0)
	var changed := 0
	for i in range(_vertices.size()):
		var distance := _vertices[i].distance_to(local_position)
		if distance > clean_radius:
			continue
		var falloff := _brush_falloff(distance, clean_radius) * clean_amount
		_vertices[i] = _vertices[i].lerp(_rest_vertices[i], falloff)
		changed += 1
	_finalize_clay_geometry_edit(local_position, clean_radius, -1, 0.12 * clean_amount, 0.18)
	rebuild_mesh()
	_last_stroke = _stroke_summary("soft_reset", changed, clean_radius)
	return _last_stroke.duplicate(true)


func rebuild_mesh() -> void:
	_ensure_mesh_node()
	_rebuild_normals()
	var mesh := ArrayMesh.new()
	if not _vertices.is_empty() and not _indices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vertices
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_TEX_UV] = _uvs
		arrays[Mesh.ARRAY_COLOR] = _colors
		arrays[Mesh.ARRAY_INDEX] = _indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _make_material())
	body_mesh.mesh = mesh
	body_mesh.visible = true
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body_mesh.layers = 1
	rebuilt.emit()


func get_vertex_count() -> int:
	return _vertices.size()


func get_triangle_count() -> int:
	return _indices.size() / 3


func get_last_stroke() -> Dictionary:
	return _last_stroke.duplicate(true)


func get_local_bounds() -> AABB:
	if _vertices.is_empty():
		return AABB()
	var bounds := AABB(_vertices[0], Vector3.ZERO)
	for vertex in _vertices:
		bounds = bounds.expand(vertex)
	return bounds


func get_edit_bounds() -> AABB:
	return AABB(EDIT_BOUNDS_POSITION, EDIT_BOUNDS_SIZE)


func get_solid_local_bounds() -> AABB:
	return get_local_bounds()


func get_solid_voxel_count() -> int:
	return get_vertex_count()


func get_anchor_integrity() -> Dictionary:
	return {
		"mode": "unconstrained_freeform",
		"intact": true,
	}


func anchors_intact() -> bool:
	return true


func count_solid_voxels_outside_edit_bounds() -> int:
	var bounds := get_edit_bounds()
	var outside := 0
	for vertex in _vertices:
		if not bounds.has_point(vertex):
			outside += 1
	return outside


func has_solid_voxel_near(local_position: Vector3, radius: float) -> bool:
	for vertex in _vertices:
		if vertex.distance_to(local_position) <= radius:
			return true
	return false


func get_render_mesh_summary() -> Dictionary:
	return {
		"mode": "freeform_surface",
		"vertex_count": get_vertex_count(),
		"triangle_count": get_triangle_count(),
		"surface_count": body_mesh.mesh.get_surface_count() if body_mesh and body_mesh.mesh else 0,
	}


func get_surface_quality_summary() -> Dictionary:
	var max_edge := 0.0
	var total_edge := 0.0
	var edge_count := 0
	for i in range(0, _indices.size(), 3):
		var i0 := _indices[i]
		var i1 := _indices[i + 1]
		var i2 := _indices[i + 2]
		var edge01 := _vertices[i0].distance_to(_vertices[i1])
		var edge12 := _vertices[i1].distance_to(_vertices[i2])
		var edge20 := _vertices[i2].distance_to(_vertices[i0])
		max_edge = maxf(max_edge, maxf(edge01, maxf(edge12, edge20)))
		total_edge += edge01 + edge12 + edge20
		edge_count += 3
	return {
		"vertex_count": get_vertex_count(),
		"triangle_count": get_triangle_count(),
		"component_count": _get_component_count(),
		"max_edge": max_edge,
		"average_edge": total_edge / float(maxi(edge_count, 1)),
		"weld_group_count": _weld_groups.size(),
		"max_weld_separation": _max_weld_group_separation(),
		"rest_volume": _rest_volume,
		"volume": _calculate_mesh_volume(_vertices),
		"volume_drift_ratio": _last_volume_drift_ratio,
	}


func get_source_mesh_summary() -> Dictionary:
	return {
		"used": true,
		"source": _source_name,
		"path": _source_path,
		"mesh_count": _source_mesh_count,
		"mode": "unconstrained_freeform",
		"matched_scene_scale": _matched_scene_scale,
		"scale_reference": _scale_reference,
	}


func get_vertex_checksum() -> int:
	var checksum := 17
	for i in range(_vertices.size()):
		var vertex := _vertices[i]
		checksum = int((checksum * 131 + int(round(vertex.x * 1000.0)) + int(round(vertex.y * 1000.0)) * 3 + int(round(vertex.z * 1000.0)) * 7 + i * 11) & 0x7fffffff)
	return checksum


func get_sdf_checksum() -> int:
	return get_vertex_checksum()


func make_compact_profile() -> Dictionary:
	_sync_welded_vertices()
	var deltas := _make_quantized_deltas()
	_apply_quantized_deltas_to_vertices(deltas)
	_sync_welded_vertices()
	deltas = _make_quantized_deltas()
	var palette := []
	for color in _colors:
		palette.append(color.to_html(false))
	return {
		"version": PROFILE_VERSION,
		"schema": "freeform_clay_surface_v1",
		"base_shell": "freeform_clay_v1",
		"vertex_count": _vertices.size(),
		"delta_q": deltas,
		"delta_scale": DELTA_QUANTIZATION,
		"colors": palette,
		"checksum": _compact_delta_checksum(deltas),
	}


func _make_quantized_deltas() -> Array:
	var deltas := []
	for i in range(_vertices.size()):
		var delta := _vertices[i] - _rest_vertices[i]
		deltas.append(_quantize_delta_component(delta.x))
		deltas.append(_quantize_delta_component(delta.y))
		deltas.append(_quantize_delta_component(delta.z))
	return deltas


func _apply_quantized_deltas_to_vertices(deltas: Array) -> void:
	if deltas.size() != _vertices.size() * 3:
		return
	for i in range(_vertices.size()):
		_vertices[i] = _rest_vertices[i] + Vector3(
			float(deltas[i * 3]) / DELTA_QUANTIZATION,
			float(deltas[i * 3 + 1]) / DELTA_QUANTIZATION,
			float(deltas[i * 3 + 2]) / DELTA_QUANTIZATION
		)


func apply_compact_profile(profile: Dictionary) -> bool:
	if int(profile.get("version", 0)) != PROFILE_VERSION:
		return false
	if int(profile.get("vertex_count", -1)) != _vertices.size():
		return false
	var delta_scale := float(profile.get("delta_scale", DELTA_QUANTIZATION))
	var deltas: Array = profile.get("delta_q", [])
	if delta_scale <= 0.0 or deltas.size() != _vertices.size() * 3:
		return false
	if is_equal_approx(delta_scale, DELTA_QUANTIZATION):
		_apply_quantized_deltas_to_vertices(deltas)
	else:
		for i in range(_vertices.size()):
			_vertices[i] = _rest_vertices[i] + Vector3(
				float(deltas[i * 3]) / delta_scale,
				float(deltas[i * 3 + 1]) / delta_scale,
				float(deltas[i * 3 + 2]) / delta_scale
			)
	var raw_colors: Array = profile.get("colors", [])
	if raw_colors.size() == _colors.size():
		for i in range(raw_colors.size()):
			_colors[i] = Color.html(str(raw_colors[i]))
	_sync_welded_vertices()
	_enforce_edit_bounds()
	_last_volume_drift_ratio = (_calculate_mesh_volume(_vertices) - _rest_volume) / _rest_volume if _rest_volume > 0.0001 else 0.0
	rebuild_mesh()
	return true


func make_compact_body() -> Dictionary:
	return make_compact_profile()


func apply_compact_body(body: Dictionary) -> bool:
	return apply_compact_profile(body)


func make_sculpt_snapshot() -> Dictionary:
	return make_compact_profile()


func apply_sculpt_snapshot(snapshot: Dictionary) -> void:
	_last_snapshot_apply_ok = apply_compact_profile(snapshot)


func was_last_snapshot_apply_ok() -> bool:
	return bool(_last_snapshot_apply_ok)


func _world_radius_to_local_radius(world_radius: float) -> float:
	var scale := global_transform.basis.get_scale()
	var dominant_scale := maxf(absf(scale.x), maxf(absf(scale.y), absf(scale.z)))
	return world_radius / maxf(dominant_scale, 0.001)


func _clamp_point_to_aabb(point: Vector3, bounds: AABB) -> Vector3:
	return Vector3(
		clampf(point.x, bounds.position.x, bounds.position.x + bounds.size.x),
		clampf(point.y, bounds.position.y, bounds.position.y + bounds.size.y),
		clampf(point.z, bounds.position.z, bounds.position.z + bounds.size.z)
	)


func _enforce_edit_bounds() -> void:
	var bounds := get_edit_bounds()
	for i in range(_vertices.size()):
		_vertices[i] = _clamp_point_to_aabb(_vertices[i], bounds)


func _ray_intersects_triangle(origin: Vector3, direction: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var edge1 := b - a
	var edge2 := c - a
	var h := direction.cross(edge2)
	var det := edge1.dot(h)
	if absf(det) < 0.0000001:
		return -1.0
	var inv_det := 1.0 / det
	var s := origin - a
	var u := inv_det * s.dot(h)
	if u < 0.0 or u > 1.0:
		return -1.0
	var q := s.cross(edge1)
	var v := inv_det * direction.dot(q)
	if v < 0.0 or u + v > 1.0:
		return -1.0
	var t := inv_det * edge2.dot(q)
	return t if t > 0.00001 else -1.0


func _build_default_surface() -> void:
	_rest_vertices = PackedVector3Array()
	_vertices = PackedVector3Array()
	_uvs = PackedVector2Array()
	_colors = PackedColorArray()
	_indices = PackedInt32Array()
	_append_ellipsoid(Vector3(0.0, 0.86, 0.0), Vector3(0.33, 0.48, 0.23), ELLIPSOID_RINGS, SEGMENTS)
	_append_ellipsoid(Vector3(0.0, 0.43, 0.0), Vector3(0.28, 0.23, 0.21), ELLIPSOID_RINGS, SEGMENTS)
	_append_capsule(Vector3(0.0, 1.18, 0.0), Vector3(0.0, 1.36, 0.0), 0.10, CAPSULE_RINGS, SEGMENTS)
	_append_ellipsoid(Vector3(0.0, 1.53, 0.0), Vector3(0.24, 0.27, 0.23), ELLIPSOID_RINGS, SEGMENTS)
	_append_capsule(Vector3(-0.26, 1.07, 0.0), Vector3(-0.43, 0.48, 0.03), 0.085, CAPSULE_RINGS, SEGMENTS)
	_append_capsule(Vector3(0.26, 1.07, 0.0), Vector3(0.43, 0.48, 0.03), 0.085, CAPSULE_RINGS, SEGMENTS)
	_append_ellipsoid(Vector3(-0.45, 0.42, 0.03), Vector3(0.09, 0.075, 0.075), 8, SEGMENTS)
	_append_ellipsoid(Vector3(0.45, 0.42, 0.03), Vector3(0.09, 0.075, 0.075), 8, SEGMENTS)
	_append_capsule(Vector3(-0.14, 0.34, 0.0), Vector3(-0.18, 0.08, 0.02), 0.105, CAPSULE_RINGS, SEGMENTS)
	_append_capsule(Vector3(0.14, 0.34, 0.0), Vector3(0.18, 0.08, 0.02), 0.105, CAPSULE_RINGS, SEGMENTS)
	_append_ellipsoid(Vector3(-0.20, 0.02, 0.07), Vector3(0.12, 0.055, 0.15), 8, SEGMENTS)
	_append_ellipsoid(Vector3(0.20, 0.02, 0.07), Vector3(0.12, 0.055, 0.15), 8, SEGMENTS)
	_build_neighbors()
	_rest_volume = _calculate_mesh_volume(_rest_vertices)
	_last_volume_drift_ratio = 0.0
	_source_name = PROCEDURAL_HUMAN_SOURCE
	_source_path = ""
	_source_mesh_count = 1
	_matched_scene_scale = false
	_scale_reference = "procedural_default"


func _build_basic_human_asset_surface() -> bool:
	var mesh_resource := load(BASIC_HUMAN_MESH_PATH)
	if not mesh_resource is Mesh:
		push_warning("Basic humanoid clone mesh could not be loaded: %s" % BASIC_HUMAN_MESH_PATH)
		return false
	var mesh := mesh_resource as Mesh
	if mesh.get_surface_count() <= 0:
		return false

	_rest_vertices = PackedVector3Array()
	_vertices = PackedVector3Array()
	_uvs = PackedVector2Array()
	_colors = PackedColorArray()
	_indices = PackedInt32Array()

	for surface_index in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var raw_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if raw_vertices.is_empty():
			continue
		var raw_uvs := PackedVector2Array()
		if arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
			raw_uvs = arrays[Mesh.ARRAY_TEX_UV]
		var raw_indices := PackedInt32Array()
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			raw_indices = arrays[Mesh.ARRAY_INDEX]
		var vertex_offset := _vertices.size()
		for i in range(raw_vertices.size()):
			var converted_vertex := _convert_basic_human_asset_vertex(raw_vertices[i])
			_vertices.append(converted_vertex)
			_rest_vertices.append(converted_vertex)
			_uvs.append(raw_uvs[i] if i < raw_uvs.size() else _fallback_asset_uv(converted_vertex))
			_colors.append(DEFAULT_COLOR)
		if raw_indices.is_empty():
			for i in range(raw_vertices.size()):
				_indices.append(vertex_offset + i)
		else:
			for raw_index in raw_indices:
				_indices.append(vertex_offset + int(raw_index))

	if _vertices.is_empty() or _indices.size() < 3:
		return false
	_normalize_asset_surface_to_default_scale()
	_build_neighbors()
	_rest_vertices = _vertices.duplicate()
	_rest_volume = _calculate_mesh_volume(_rest_vertices)
	_last_volume_drift_ratio = 0.0
	_source_name = BASIC_HUMAN_SOURCE
	_source_path = BASIC_HUMAN_MESH_PATH
	_source_mesh_count = mesh.get_surface_count()
	_matched_scene_scale = false
	_scale_reference = "asset_default_playable_scale"
	return true


func _convert_basic_human_asset_vertex(vertex: Vector3) -> Vector3:
	return Vector3(vertex.x, -vertex.z, vertex.y)


func _fallback_asset_uv(vertex: Vector3) -> Vector2:
	var bounds := get_edit_bounds()
	return Vector2(
		inverse_lerp(bounds.position.x, bounds.position.x + bounds.size.x, vertex.x),
		inverse_lerp(bounds.position.y, bounds.position.y + bounds.size.y, vertex.y)
	)


func _normalize_asset_surface_to_default_scale() -> void:
	var bounds := get_local_bounds()
	if bounds.size.y <= 0.0001:
		return
	var scale := DEFAULT_HEIGHT / bounds.size.y
	var center := bounds.get_center()
	var bottom_anchor := Vector3(center.x, bounds.position.y, center.z)
	var target_anchor := Vector3.ZERO
	for i in range(_vertices.size()):
		_vertices[i] = target_anchor + (_vertices[i] - bottom_anchor) * scale
	_rest_vertices = _vertices.duplicate()
	_enforce_edit_bounds()


func _match_rest_surface_to_source_mesh_bounds(source_meshes: Array) -> bool:
	var source_bounds := _calculate_source_meshes_shell_bounds(source_meshes)
	if source_bounds.size == Vector3.ZERO:
		return false
	if source_bounds.size.y < MIN_TRUSTED_RUNTIME_SOURCE_HEIGHT:
		_scale_reference = "asset_default_playable_scale_runtime_bounds_rejected"
		return false
	var current_bounds := get_local_bounds()
	if current_bounds.size.y <= 0.0001:
		return false
	var scale := source_bounds.size.y / current_bounds.size.y
	var current_anchor := Vector3(current_bounds.get_center().x, current_bounds.position.y, current_bounds.get_center().z)
	var source_anchor := Vector3(source_bounds.get_center().x, source_bounds.position.y, source_bounds.get_center().z)
	for i in range(_vertices.size()):
		_vertices[i] = source_anchor + (_vertices[i] - current_anchor) * scale
	_rest_vertices = _vertices.duplicate()
	_enforce_edit_bounds()
	_build_neighbors()
	_rest_volume = _calculate_mesh_volume(_rest_vertices)
	_last_volume_drift_ratio = 0.0
	_matched_scene_scale = true
	_scale_reference = "runtime_source_mesh_bounds"
	return true


func _calculate_source_meshes_shell_bounds(source_meshes: Array) -> AABB:
	var has_bounds := false
	var bounds := AABB()
	for value in source_meshes:
		var mesh_instance := value as MeshInstance3D
		if not mesh_instance or not is_instance_valid(mesh_instance) or not mesh_instance.mesh:
			continue
		var local_bounds := _transform_aabb(global_transform.affine_inverse() * mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = local_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(local_bounds)
	return bounds if has_bounds else AABB()


func _transform_aabb(transform: Transform3D, box: AABB) -> AABB:
	var points := [
		box.position,
		box.position + Vector3(box.size.x, 0.0, 0.0),
		box.position + Vector3(0.0, box.size.y, 0.0),
		box.position + Vector3(0.0, 0.0, box.size.z),
		box.position + Vector3(box.size.x, box.size.y, 0.0),
		box.position + Vector3(box.size.x, 0.0, box.size.z),
		box.position + Vector3(0.0, box.size.y, box.size.z),
		box.position + box.size,
	]
	var result := AABB(transform * points[0], Vector3.ZERO)
	for i in range(1, points.size()):
		result = result.expand(transform * points[i])
	return result


func _append_ellipsoid(center: Vector3, radii: Vector3, rings: int, segments: int) -> void:
	var start_index := _vertices.size()
	for ring in range(rings + 1):
		var v := float(ring) / float(rings)
		var theta := PI * v
		var y := cos(theta) * radii.y
		var ring_radius := maxf(sin(theta), 0.001)
		for segment in range(segments):
			var u := float(segment) / float(segments)
			var angle := TAU * u
			var vertex := center + Vector3(cos(angle) * radii.x * ring_radius, y, sin(angle) * radii.z * ring_radius)
			_append_vertex(vertex, Vector2(u, v))
	_append_lathed_indices(start_index, rings, segments)


func _append_capsule(start: Vector3, end: Vector3, radius: float, rings: int, segments: int) -> void:
	var axis := end - start
	if axis.length_squared() <= 0.000001:
		_append_ellipsoid(start, Vector3.ONE * radius, rings, segments)
		return
	var length := axis.length()
	var y_axis := axis.normalized()
	var reference := Vector3.UP if absf(y_axis.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
	var x_axis := reference.cross(y_axis).normalized()
	var z_axis := y_axis.cross(x_axis).normalized()
	var half_length := length * 0.5
	var center := (start + end) * 0.5
	var total_half := half_length + radius
	var start_index := _vertices.size()
	for ring in range(rings + 1):
		var v := float(ring) / float(rings)
		var local_y := lerpf(-total_half, total_half, v)
		var ring_radius := radius
		if local_y < -half_length:
			var dy_bottom := local_y + half_length
			ring_radius = sqrt(maxf(0.0, radius * radius - dy_bottom * dy_bottom))
		elif local_y > half_length:
			var dy_top := local_y - half_length
			ring_radius = sqrt(maxf(0.0, radius * radius - dy_top * dy_top))
		ring_radius = maxf(ring_radius, 0.001)
		for segment in range(segments):
			var u := float(segment) / float(segments)
			var angle := TAU * u
			var vertex := center + y_axis * local_y + x_axis * (cos(angle) * ring_radius) + z_axis * (sin(angle) * ring_radius)
			_append_vertex(vertex, Vector2(u, v))
	_append_lathed_indices(start_index, rings, segments)


func _append_vertex(vertex: Vector3, uv: Vector2) -> void:
	_rest_vertices.append(vertex)
	_vertices.append(vertex)
	_uvs.append(uv)
	_colors.append(DEFAULT_COLOR)


func _append_lathed_indices(start_index: int, rings: int, segments: int) -> void:
	for ring in range(rings):
		for segment in range(segments):
			var next_segment := (segment + 1) % segments
			var a := start_index + ring * segments + segment
			var b := start_index + ring * segments + next_segment
			var c := start_index + (ring + 1) * segments + segment
			var d := start_index + (ring + 1) * segments + next_segment
			_indices.append_array(PackedInt32Array([a, c, b, b, c, d]))


func _compact_delta_checksum(deltas: Array) -> int:
	var checksum := 23
	for i in range(deltas.size()):
		checksum = int((checksum * 131 + int(deltas[i]) + i * 17) & 0x7fffffff)
	return checksum


func _quantize_delta_component(value: float) -> int:
	var scaled := value * DELTA_QUANTIZATION
	if scaled >= 0.0:
		return int(floor(scaled + 0.5001))
	return -int(floor(absf(scaled) + 0.5001))


func _build_neighbors() -> void:
	_neighbors.clear()
	for i in range(_vertices.size()):
		_neighbors.append([])
	for i in range(0, _indices.size(), 3):
		_add_neighbor(_indices[i], _indices[i + 1])
		_add_neighbor(_indices[i + 1], _indices[i + 2])
		_add_neighbor(_indices[i + 2], _indices[i])
	_build_weld_groups()
	_add_weld_neighbors()
	_sync_welded_rest_vertices()
	_sync_welded_vertices()
	_build_components()


func _add_neighbor(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= _neighbors.size() or b >= _neighbors.size():
		return
	if not (_neighbors[a] as Array).has(b):
		(_neighbors[a] as Array).append(b)
	if not (_neighbors[b] as Array).has(a):
		(_neighbors[b] as Array).append(a)


func _build_weld_groups() -> void:
	_weld_groups.clear()
	var buckets := {}
	for i in range(_vertices.size()):
		var key := _weld_key(_vertices[i])
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(i)
	for key in buckets.keys():
		var group: Array = buckets[key]
		if group.size() > 1:
			_weld_groups.append(group)


func _add_weld_neighbors() -> void:
	for group in _weld_groups:
		var indices: Array = group
		for i in range(indices.size()):
			for j in range(i + 1, indices.size()):
				_add_neighbor(int(indices[i]), int(indices[j]))


func _weld_key(vertex: Vector3) -> String:
	return "%d:%d:%d" % [
		int(round(vertex.x * WELD_POSITION_QUANTIZATION)),
		int(round(vertex.y * WELD_POSITION_QUANTIZATION)),
		int(round(vertex.z * WELD_POSITION_QUANTIZATION)),
	]


func _build_components() -> void:
	_component_ids = PackedInt32Array()
	_component_ids.resize(_vertices.size())
	for i in range(_component_ids.size()):
		_component_ids[i] = -1
	var component_id := 0
	for start in range(_vertices.size()):
		if _component_ids[start] >= 0:
			continue
		var stack: Array[int] = [start]
		_component_ids[start] = component_id
		while not stack.is_empty():
			var current := int(stack.pop_back())
			var neighbor_indices: Array = _neighbors[current] if current < _neighbors.size() else []
			for neighbor_index in neighbor_indices:
				var typed_neighbor := int(neighbor_index)
				if typed_neighbor < 0 or typed_neighbor >= _component_ids.size():
					continue
				if _component_ids[typed_neighbor] >= 0:
					continue
				_component_ids[typed_neighbor] = component_id
				stack.append(typed_neighbor)
		component_id += 1


func _get_component_count() -> int:
	var max_component := -1
	for component_id in _component_ids:
		max_component = maxi(max_component, int(component_id))
	return max_component + 1


func _vertex_matches_component(index: int, component_id: int) -> bool:
	if component_id < 0:
		return true
	if index < 0 or index >= _component_ids.size():
		return false
	return _component_ids[index] == component_id


func _nearest_component_id(local_position: Vector3) -> int:
	if _vertices.is_empty() or _component_ids.size() != _vertices.size():
		return -1
	var best_distance := INF
	var best_component := -1
	for i in range(_vertices.size()):
		var distance := _vertices[i].distance_squared_to(local_position)
		if distance >= best_distance:
			continue
		best_distance = distance
		best_component = _component_ids[i]
	return best_component


func _surface_normal_near_local(local_position: Vector3, radius: float, component_id: int = -1) -> Vector3:
	var clean_radius := maxf(radius, 0.01)
	var weighted_normal := Vector3.ZERO
	var weight_sum := 0.0
	var nearest_index := -1
	var nearest_distance := INF
	for i in range(_vertices.size()):
		if not _vertex_matches_component(i, component_id):
			continue
		var distance := _vertices[i].distance_to(local_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i
		if distance > clean_radius:
			continue
		var falloff := _brush_falloff(distance, clean_radius)
		if i < _normals.size():
			weighted_normal += _normals[i] * falloff
			weight_sum += falloff
	if weight_sum > 0.0001 and weighted_normal.length_squared() > 0.000001:
		var outward := local_position - get_local_bounds().get_center()
		if outward.length_squared() > 0.0001 and weighted_normal.dot(outward) < 0.0:
			weighted_normal = -weighted_normal
		return weighted_normal.normalized()
	if nearest_index >= 0 and nearest_index < _normals.size() and _normals[nearest_index].length_squared() > 0.000001:
		var nearest_normal := _normals[nearest_index]
		var nearest_outward := local_position - get_local_bounds().get_center()
		if nearest_outward.length_squared() > 0.0001 and nearest_normal.dot(nearest_outward) < 0.0:
			nearest_normal = -nearest_normal
		return nearest_normal.normalized()
	var fallback := local_position - get_local_bounds().get_center()
	return fallback.normalized() if fallback.length_squared() > 0.000001 else Vector3.UP


func _relax_vertices_local(local_position: Vector3, radius: float, amount: float, component_id: int = -1) -> int:
	var clean_radius := maxf(radius, 0.01)
	var clean_amount := clampf(amount, 0.0, 1.0)
	if clean_amount <= 0.0:
		return 0
	var before := _vertices.duplicate()
	var changed := 0
	for i in range(_vertices.size()):
		if not _vertex_matches_component(i, component_id):
			continue
		var distance := before[i].distance_to(local_position)
		if distance > clean_radius:
			continue
		var neighbor_indices: Array = _neighbors[i] if i < _neighbors.size() else []
		if neighbor_indices.is_empty():
			continue
		var average := Vector3.ZERO
		var neighbor_count := 0
		for neighbor_index in neighbor_indices:
			var typed_neighbor := int(neighbor_index)
			if not _vertex_matches_component(typed_neighbor, component_id):
				continue
			average += before[typed_neighbor]
			neighbor_count += 1
		if neighbor_count <= 0:
			continue
		average /= float(neighbor_count)
		var falloff := _brush_falloff(distance, clean_radius) * clean_amount
		_vertices[i] = before[i].lerp(average, falloff)
		changed += 1
	return changed


func _finalize_clay_geometry_edit(local_position: Vector3, radius: float, component_id: int, relax_amount: float, spike_damping: float) -> void:
	if relax_amount > 0.001:
		_relax_vertices_local(local_position, radius, relax_amount, component_id)
	_sync_welded_vertices()
	if spike_damping > 0.001:
		_dampen_spikes_local(local_position, radius * 1.08, spike_damping, component_id)
	_sync_welded_vertices()
	_stabilize_volume_budget()
	_sync_welded_vertices()
	_enforce_edit_bounds()
	_sync_welded_vertices()


func _sync_welded_vertices() -> int:
	var changed := 0
	for group in _weld_groups:
		var indices: Array = group
		if indices.size() < 2:
			continue
		var average := Vector3.ZERO
		var valid_count := 0
		for raw_index in indices:
			var index := int(raw_index)
			if index < 0 or index >= _vertices.size():
				continue
			average += _vertices[index]
			valid_count += 1
		if valid_count <= 0:
			continue
		average /= float(valid_count)
		for raw_index in indices:
			var index := int(raw_index)
			if index < 0 or index >= _vertices.size():
				continue
			if _vertices[index].distance_squared_to(average) > 0.00000001:
				_vertices[index] = average
				changed += 1
	return changed


func _sync_welded_rest_vertices() -> int:
	var changed := 0
	for group in _weld_groups:
		var indices: Array = group
		if indices.size() < 2:
			continue
		var average := Vector3.ZERO
		var valid_count := 0
		for raw_index in indices:
			var index := int(raw_index)
			if index < 0 or index >= _rest_vertices.size():
				continue
			average += _rest_vertices[index]
			valid_count += 1
		if valid_count <= 0:
			continue
		average /= float(valid_count)
		for raw_index in indices:
			var index := int(raw_index)
			if index < 0 or index >= _rest_vertices.size():
				continue
			if _rest_vertices[index].distance_squared_to(average) > 0.00000001:
				_rest_vertices[index] = average
				changed += 1
	return changed


func _max_weld_group_separation() -> float:
	var max_separation := 0.0
	for group in _weld_groups:
		var indices: Array = group
		for i in range(indices.size()):
			var a := int(indices[i])
			if a < 0 or a >= _vertices.size():
				continue
			for j in range(i + 1, indices.size()):
				var b := int(indices[j])
				if b < 0 or b >= _vertices.size():
					continue
				max_separation = maxf(max_separation, _vertices[a].distance_to(_vertices[b]))
	return max_separation


func _dampen_spikes_local(local_position: Vector3, radius: float, amount: float, component_id: int = -1) -> int:
	var clean_radius := maxf(radius, 0.01)
	var clean_amount := clampf(amount, 0.0, 1.0)
	if clean_amount <= 0.0:
		return 0
	var before := _vertices.duplicate()
	var changed := 0
	for i in range(_vertices.size()):
		if not _vertex_matches_component(i, component_id):
			continue
		var distance := before[i].distance_to(local_position)
		if distance > clean_radius:
			continue
		var neighbor_indices: Array = _neighbors[i] if i < _neighbors.size() else []
		if neighbor_indices.is_empty():
			continue
		var average := Vector3.ZERO
		var average_edge := 0.0
		var neighbor_count := 0
		for neighbor_index in neighbor_indices:
			var typed_neighbor := int(neighbor_index)
			if not _vertex_matches_component(typed_neighbor, component_id):
				continue
			average += before[typed_neighbor]
			average_edge += before[i].distance_to(before[typed_neighbor])
			neighbor_count += 1
		if neighbor_count <= 0:
			continue
		average /= float(neighbor_count)
		average_edge /= float(neighbor_count)
		var deviation := before[i].distance_to(average)
		var allowed_deviation := maxf(average_edge * CLAY_SPIKE_EDGE_MULTIPLIER, clean_radius * CLAY_SPIKE_MIN_DEVIATION_RATIO)
		if deviation <= allowed_deviation or deviation <= 0.0001:
			continue
		var excess_ratio := clampf((deviation - allowed_deviation) / deviation, 0.0, 1.0)
		var falloff := _brush_falloff(distance, clean_radius) * clean_amount * excess_ratio
		_vertices[i] = _vertices[i].lerp(average, falloff)
		changed += 1
	return changed


func _rebuild_normals() -> void:
	_normals = PackedVector3Array()
	_normals.resize(_vertices.size())
	var center := get_local_bounds().get_center()
	for i in range(0, _indices.size(), 3):
		var i0 := _indices[i]
		var i1 := _indices[i + 1]
		var i2 := _indices[i + 2]
		var normal := (_vertices[i1] - _vertices[i0]).cross(_vertices[i2] - _vertices[i0])
		if normal.length_squared() <= 0.000001:
			continue
		_normals[i0] += normal
		_normals[i1] += normal
		_normals[i2] += normal
	for i in range(_normals.size()):
		if _normals[i].length_squared() > 0.000001:
			var normal := _normals[i].normalized()
			var outward := _vertices[i] - center
			if outward.length_squared() > 0.0001 and normal.dot(outward) < 0.0:
				normal = -normal
			_normals[i] = normal
		else:
			_normals[i] = Vector3.UP


func _calculate_mesh_volume(vertices: PackedVector3Array) -> float:
	if vertices.is_empty() or _indices.is_empty():
		return 0.0
	var signed_volume := 0.0
	for i in range(0, _indices.size(), 3):
		var a := vertices[_indices[i]]
		var b := vertices[_indices[i + 1]]
		var c := vertices[_indices[i + 2]]
		signed_volume += a.dot(b.cross(c)) / 6.0
	return absf(signed_volume)


func _calculate_surface_area(vertices: PackedVector3Array) -> float:
	if vertices.is_empty() or _indices.is_empty():
		return 0.0
	var area := 0.0
	for i in range(0, _indices.size(), 3):
		var a := vertices[_indices[i]]
		var b := vertices[_indices[i + 1]]
		var c := vertices[_indices[i + 2]]
		area += (b - a).cross(c - a).length() * 0.5
	return area


func _stabilize_volume_budget() -> void:
	if _rest_volume <= 0.0001 or _vertices.is_empty():
		_last_volume_drift_ratio = 0.0
		return
	var current_volume := _calculate_mesh_volume(_vertices)
	var drift_ratio := (current_volume - _rest_volume) / _rest_volume
	_last_volume_drift_ratio = drift_ratio
	if absf(drift_ratio) <= MAX_VOLUME_DRIFT_RATIO:
		return
	var target_volume := _rest_volume * (1.0 + signf(drift_ratio) * MAX_VOLUME_DRIFT_RATIO)
	var excess_volume := current_volume - target_volume
	var surface_area := _calculate_surface_area(_vertices)
	if surface_area <= 0.0001:
		return
	_rebuild_normals()
	var correction := clampf(
		-excess_volume / surface_area * VOLUME_CORRECTION_GAIN,
		-VOLUME_CORRECTION_MAX_STEP,
		VOLUME_CORRECTION_MAX_STEP
	)
	for i in range(_vertices.size()):
		_vertices[i] += _normals[i] * correction
	_last_volume_drift_ratio = (_calculate_mesh_volume(_vertices) - _rest_volume) / _rest_volume


func _profile_width_multiplier(v: float) -> float:
	var waist := 1.0 - 0.16 * exp(-pow((v - 0.52) / 0.18, 2.0))
	var shoulder := 1.0 + 0.12 * exp(-pow((v - 0.34) / 0.12, 2.0))
	var base := 0.92 + 0.08 * sin(v * PI)
	return base * waist * shoulder


func _brush_falloff(distance: float, radius: float) -> float:
	var x := clampf(1.0 - distance / maxf(radius, 0.0001), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _stroke_summary(tool_name: String, changed: int, radius: float) -> Dictionary:
	return {
		"tool": tool_name,
		"changed_vertices": changed,
		"radius": radius,
		"vertex_count": _vertices.size(),
		"checksum": get_vertex_checksum(),
		"volume_drift_ratio": _last_volume_drift_ratio,
	}


func _make_material() -> Material:
	if _shell_material:
		return _shell_material
	_shell_material = StandardMaterial3D.new()
	_shell_material.albedo_color = DEFAULT_COLOR
	_shell_material.vertex_color_use_as_albedo = true
	_shell_material.roughness = 0.86
	_shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _shell_material


func _ensure_mesh_node() -> void:
	if body_mesh and is_instance_valid(body_mesh):
		return
	body_mesh = get_node_or_null("BodyMesh") as MeshInstance3D
	if body_mesh:
		return
	body_mesh = MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	add_child(body_mesh)
