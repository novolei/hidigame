extends Node3D
class_name SelfVoxelBody

const GRID_WIDTH := 32
const GRID_HEIGHT := 32
const GRID_DEPTH := 32
const VOXEL_SCALE := 0.0625
const BASIC_HUMAN_PLAYABLE_HEIGHT := 1.75
const GRID_MIN := Vector3(-1.0, 0.0, -1.0)
const GRID_MAX := Vector3(1.0, 2.0, 1.0)
const PREPARED_BASIC_HUMAN_CLONE_PROFILE := "res://assets/characters/basic/basic_human_solid_clone_profile.json"
const DEFAULT_COLOR := Color(0.78, 0.70, 0.58, 1.0)
const BASIC_HUMAN_COLOR := Color(0.72, 0.68, 1.0, 1.0)
const BASIC_HUMAN_SOURCE := "basic_humanoid_blender_remesh_solid_clone"
const BASIC_HUMAN_FALLBACK_SOURCE := "basic_humanoid_authored_capsule_sdf"
const RUNTIME_CHARACTER_SOURCE := "runtime_character_solid_sdf"
const AIR_SDF := 1.0
const SOLID_EPSILON := 0.0
const SOURCE_SURFACE_STAMP_RADIUS := VOXEL_SCALE * 0.82
const MIN_SCULPT_RADIUS := 0.08
const MAX_SCULPT_RADIUS := 0.46
const DEFAULT_SCULPT_RADIUS := 0.22
const VOLUME_FEEDBACK_DEADBAND_RATIO := 0.08
const VOLUME_FEEDBACK_BASE_STRENGTH := 0.30
const BEAUTIFY_FILL_SOLID_NEIGHBORS := 15
const BEAUTIFY_SPIKE_SOLID_NEIGHBORS := 3
const CHANNEL_SDF := 1
const VOXEL_DEPTH_32_BIT := 2
const COMPACT_BODY_VERSION := 1
const SNAPSHOT_SDF_SCALE := 1024.0

const TOOL_ADD := "add"
const TOOL_REMOVE := "remove"
const TOOL_SMOOTH := "smooth"
const TOOL_STRETCH := "stretch"
const TOOL_GRAB := "grab"
const TOOL_PUSH_PULL := "push_pull"
const TOOL_FLATTEN := "flatten"
const TOOL_SMART := "smart"

const FACE_NORMALS := [
	Vector3.RIGHT,
	Vector3.LEFT,
	Vector3.UP,
	Vector3.DOWN,
	Vector3.BACK,
	Vector3.FORWARD,
]

const FACE_CORNERS := [
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)],
	[Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	[Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)],
]

var voxel_buffer: Variant = null
var voxel_tool: Variant = null
var _voxel_mesher: Variant = null
var _initial_sdf := PackedFloat32Array()
var _voxel_colors := PackedColorArray()
var _last_stroke := {}
var _last_snapshot_apply_ok := false
var _solid_count := 0
var _source_mesh_summary := {}
var _render_mesh_summary := {}
var _shell_material: Material = null
var _base_clone_clean := false
var _rebuild_defer_depth := 0
var _rebuild_pending := false
var _rebuild_count := 0
var _last_rebuild_elapsed_msec := 0

@onready var body_mesh: MeshInstance3D = get_node_or_null("BodyMesh")

signal rebuilt


func _ready() -> void:
	_ensure_mesh_node()
	if not _voxel_runtime_available():
		_disable_voxel_runtime("voxel_extension_unavailable")
		return
	if not voxel_buffer:
		reset_to_default_shell()


func _voxel_runtime_available() -> bool:
	return ClassDB.class_exists("VoxelBuffer") and ClassDB.class_exists("VoxelMesherTransvoxel")


func _has_voxel_data() -> bool:
	return voxel_buffer != null and voxel_tool != null


func _disable_voxel_runtime(reason: String) -> void:
	voxel_buffer = null
	voxel_tool = null
	_voxel_mesher = null
	_initial_sdf = PackedFloat32Array()
	_voxel_colors = PackedColorArray()
	_solid_count = 0
	if body_mesh and is_instance_valid(body_mesh):
		body_mesh.mesh = ArrayMesh.new()
	_source_mesh_summary = {
		"used": false,
		"source": "voxel_runtime_unavailable",
		"reason": reason,
		"grid": [GRID_WIDTH, GRID_HEIGHT, GRID_DEPTH],
		"voxel_scale": VOXEL_SCALE,
	}
	_render_mesh_summary = {
		"mode": "disabled",
		"reason": reason,
		"surface_count": 0,
		"vertex_count": 0,
		"triangle_count": 0,
		"solid_count": 0,
	}


func reset_to_default_shell() -> void:
	reset_to_basic_human_shell()


func reset_to_basic_human_shell() -> void:
	_ensure_mesh_node()
	if _base_clone_clean and str(_source_mesh_summary.get("source", "")) == BASIC_HUMAN_SOURCE:
		return
	if _try_load_prepared_basic_human_clone():
		return
	_build_authored_basic_human_sdf()


func _build_authored_basic_human_sdf() -> void:
	if not _initialize_voxel_storage(BASIC_HUMAN_COLOR):
		return
	_source_mesh_summary = {
		"used": true,
		"source": BASIC_HUMAN_FALLBACK_SOURCE,
		"path": PREPARED_BASIC_HUMAN_CLONE_PROFILE,
		"mesh_count": 1,
		"triangle_count": 0,
		"mode": "solid_sdf_clay",
		"matched_scene_scale": false,
		"scale_reference": "authored_capsule_sdf_profile_fallback",
		"grid": [GRID_WIDTH, GRID_HEIGHT, GRID_DEPTH],
		"voxel_scale": VOXEL_SCALE,
	}
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				var index := _voxel_index(x, y, z)
				var local_position := _voxel_center_local(x, y, z)
				var sdf := _clamp_sdf_value(_basic_human_sdf(local_position) / VOXEL_SCALE)
				voxel_buffer.set_voxel_f(sdf, x, y, z, CHANNEL_SDF)
				_voxel_colors[index] = _basic_human_color(local_position)
	_enforce_edit_bounds()
	_protect_anchor_voxels()
	_capture_initial_sdf_from_buffer()
	rebuild_mesh()
	_source_mesh_summary["solid_count"] = _solid_count
	_base_clone_clean = true


func _try_load_prepared_basic_human_clone() -> bool:
	if not FileAccess.file_exists(PREPARED_BASIC_HUMAN_CLONE_PROFILE):
		return false
	var file := FileAccess.open(PREPARED_BASIC_HUMAN_CLONE_PROFILE, FileAccess.READ)
	if not file:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	var body: Dictionary = parsed.get("body", {})
	if body.is_empty():
		body = parsed
	if not _initialize_voxel_storage(BASIC_HUMAN_COLOR):
		return false
	if not apply_compact_body(body):
		return false
	_source_mesh_summary = {
		"used": true,
		"source": BASIC_HUMAN_SOURCE,
		"path": PREPARED_BASIC_HUMAN_CLONE_PROFILE,
		"mesh_count": 1,
		"triangle_count": 0,
		"mode": "solid_sdf_clay",
		"matched_scene_scale": true,
		"scale_reference": "prepared_basic_human_solid_clone_profile",
		"grid": [GRID_WIDTH, GRID_HEIGHT, GRID_DEPTH],
		"voxel_scale": VOXEL_SCALE,
		"solid_count": _solid_count,
		"profile_checksum": body.get("checksum", 0),
	}
	_capture_initial_sdf_from_buffer()
	_base_clone_clean = true
	return true


func reset_to_character_mesh_shell(source_meshes: Array) -> bool:
	_ensure_mesh_node()
	var triangles := _collect_source_triangles(source_meshes)
	if triangles.is_empty():
		reset_to_default_shell()
		return false
	_fit_source_triangles_to_edit_bounds(triangles)
	if not _initialize_voxel_storage():
		return false
	var surface_mask := PackedByteArray()
	surface_mask.resize(_voxel_count())
	for triangle in triangles:
		_stamp_source_triangle(triangle, surface_mask)
	var fill_x := _make_axis_fill_mask(surface_mask, 0)
	var fill_y := _make_axis_fill_mask(surface_mask, 1)
	var fill_z := _make_axis_fill_mask(surface_mask, 2)
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				var index := _voxel_index(x, y, z)
				var votes := int(fill_x[index]) + int(fill_y[index]) + int(fill_z[index])
				if int(surface_mask[index]) > 0 or votes >= 2:
					voxel_buffer.set_voxel_f(-0.45, x, y, z, CHANNEL_SDF)
	_enforce_edit_bounds()
	_protect_anchor_voxels()
	_capture_initial_sdf_from_buffer()
	rebuild_mesh()
	if _should_use_basic_human_fallback():
		reset_to_basic_human_shell()
		_source_mesh_summary["fallback_from_runtime_character"] = true
		_source_mesh_summary["fallback_reason"] = "runtime_voxelized_bounds_failed_playable_scale"
		_source_mesh_summary["matched_scene_scale"] = true
		_source_mesh_summary["scale_reference"] = "basic_human_solid_profile_playable_scale_fallback"
		return true
	_source_mesh_summary = {
		"used": true,
		"source": RUNTIME_CHARACTER_SOURCE,
		"path": "",
		"mesh_count": _count_valid_source_meshes(source_meshes),
		"triangle_count": triangles.size(),
		"solid_count": _solid_count,
		"mode": "solid_sdf_clay",
		"matched_scene_scale": true,
		"scale_reference": "runtime_source_mesh_height_matched_to_basic_human_playable_scale",
		"grid": [GRID_WIDTH, GRID_HEIGHT, GRID_DEPTH],
		"voxel_scale": VOXEL_SCALE,
	}
	return _solid_count > 0


func apply_sculpt_stroke_world(tool_name: String, world_position: Vector3, world_radius: float = DEFAULT_SCULPT_RADIUS, strength: float = 1.0) -> Dictionary:
	return apply_sculpt_stroke_local(tool_name, to_local(world_position), world_radius, strength)


func begin_sculpt_batch() -> void:
	_rebuild_defer_depth += 1


func end_sculpt_batch() -> void:
	_rebuild_defer_depth = maxi(0, _rebuild_defer_depth - 1)
	if _rebuild_defer_depth == 0 and _rebuild_pending:
		_flush_pending_rebuild()


func flush_pending_rebuild() -> void:
	_flush_pending_rebuild()


func get_performance_summary() -> Dictionary:
	return {
		"rebuild_count": _rebuild_count,
		"last_rebuild_elapsed_msec": _last_rebuild_elapsed_msec,
		"deferred_rebuild": _rebuild_defer_depth > 0,
		"pending_rebuild": _rebuild_pending,
		"vertex_count": get_vertex_count(),
		"triangle_count": get_triangle_count(),
	}


func apply_sculpt_stroke_local(tool_name: String, local_position: Vector3, world_radius: float = DEFAULT_SCULPT_RADIUS, strength: float = 1.0) -> Dictionary:
	return apply_sculpt_capsule_stroke_local(tool_name, local_position, local_position, world_radius, strength)


func apply_sculpt_capsule_stroke_world(tool_name: String, world_start: Vector3, world_end: Vector3, world_radius: float = DEFAULT_SCULPT_RADIUS, strength: float = 1.0) -> Dictionary:
	return apply_sculpt_capsule_stroke_local(tool_name, to_local(world_start), to_local(world_end), world_radius, strength)


func apply_sculpt_capsule_stroke_local(tool_name: String, local_start: Vector3, local_end: Vector3, world_radius: float = DEFAULT_SCULPT_RADIUS, strength: float = 1.0) -> Dictionary:
	_ensure_voxel_data()
	var edit_bounds := get_edit_bounds()
	var clamped_start := _clamp_point_to_aabb(local_start, edit_bounds)
	var clamped_end := _clamp_point_to_aabb(local_end, edit_bounds)
	var radius := clampf(world_radius, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS)
	var clean_tool := _normalize_tool_name(tool_name)
	var clean_strength := clampf(strength, 0.0, 2.0)
	var before_solid_count := _solid_count
	var feedback_normal := _sdf_gradient_normal_local(clamped_end)
	var changed := 0
	match clean_tool:
		TOOL_ADD:
			changed = _apply_sdf_capsule_brush(clamped_start, clamped_end, radius, clean_strength, true)
		TOOL_REMOVE:
			changed = _apply_sdf_capsule_brush(clamped_start, clamped_end, radius, clean_strength, false)
		TOOL_SMOOTH:
			changed = _smooth_sdf_capsule(clamped_start, clamped_end, radius, strength)
		TOOL_STRETCH:
			changed = _apply_sdf_stretch(clamped_end, radius, clean_strength)
		TOOL_FLATTEN:
			changed = _apply_sdf_flatten_capsule(clamped_start, clamped_end, feedback_normal, radius, clean_strength)
		TOOL_SMART:
			changed = _apply_smart_clay_stroke(clamped_start, clamped_end, radius, clean_strength, feedback_normal)
	changed += _apply_volume_feedback(clean_tool, clamped_start, clamped_end, radius, clean_strength, before_solid_count, feedback_normal)
	_enforce_edit_bounds()
	_protect_anchor_voxels()
	_request_rebuild()
	_mark_edited_if_changed(changed)
	_last_stroke = {
		"tool": clean_tool,
		"requested_tool": tool_name,
		"requested_local_position": local_end,
		"requested_local_start": local_start,
		"local_position": clamped_end,
		"local_start": clamped_start,
		"world_radius": radius,
		"radius": radius,
		"clamped": not local_start.is_equal_approx(clamped_start) or not local_end.is_equal_approx(clamped_end),
		"anchor_integrity": get_anchor_integrity(),
		"solid_count": _solid_count,
		"changed_voxels": changed,
		"changed_vertices": changed,
	}
	return _last_stroke.duplicate(true)


func apply_push_pull_stroke_local(
	local_position: Vector3,
	amount: float,
	radius: float,
	strength: float = 1.0,
	brush_normal: Vector3 = Vector3.ZERO,
	_component_id: int = -1,
	_relax_amount: float = 0.0
) -> Dictionary:
	var normal := brush_normal.normalized() if brush_normal.length_squared() > 0.0001 else _sdf_gradient_normal_local(local_position)
	var displacement := normal * amount * clampf(strength, 0.0, 2.0)
	return apply_grab_stroke_local(local_position, displacement, radius, 1.0)


func apply_smooth_stroke_local(local_position: Vector3, radius: float, strength: float = 1.0, _component_id: int = -1) -> Dictionary:
	return apply_sculpt_stroke_local(TOOL_SMOOTH, local_position, radius, strength)


func apply_flatten_stroke_local(local_position: Vector3, plane_normal: Vector3, radius: float, strength: float = 1.0, _component_id: int = -1) -> Dictionary:
	_ensure_voxel_data()
	var clamped_position := _clamp_point_to_aabb(local_position, get_edit_bounds())
	var clean_radius := clampf(radius, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS)
	var normal := plane_normal.normalized() if plane_normal.length_squared() > 0.0001 else _sdf_gradient_normal_local(clamped_position)
	var before_solid_count := _solid_count
	var changed := _apply_sdf_flatten(clamped_position, normal, clean_radius, strength)
	changed += _apply_volume_feedback(TOOL_FLATTEN, clamped_position, clamped_position, clean_radius, strength, before_solid_count, normal)
	_enforce_edit_bounds()
	_protect_anchor_voxels()
	_request_rebuild()
	_mark_edited_if_changed(changed)
	_last_stroke = _solid_stroke_summary(TOOL_FLATTEN, local_position, clamped_position, clean_radius, changed)
	return _last_stroke.duplicate(true)


func apply_grab_stroke_local(local_position: Vector3, local_delta: Vector3, radius: float, strength: float = 1.0, _component_id: int = -1) -> Dictionary:
	_ensure_voxel_data()
	var clamped_position := _clamp_point_to_aabb(local_position, get_edit_bounds())
	var clean_radius := clampf(radius, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS)
	var clean_strength := clampf(strength, 0.0, 2.0)
	var target := _clamp_point_to_aabb(clamped_position + local_delta * clean_strength, get_edit_bounds())
	var before_solid_count := _solid_count
	var changed := 0
	changed += _apply_sdf_sphere(target, clean_radius * 0.86, clean_strength, true)
	changed += _apply_sdf_sphere(clamped_position - local_delta * 0.25, clean_radius * 0.72, clean_strength * 0.55, false)
	_smooth_sdf_sphere((clamped_position + target) * 0.5, clean_radius * 1.05, 0.42)
	var feedback_normal := local_delta.normalized() if local_delta.length_squared() > 0.0001 else _sdf_gradient_normal_local(clamped_position)
	changed += _apply_volume_feedback(TOOL_GRAB, clamped_position, target, clean_radius, clean_strength, before_solid_count, feedback_normal)
	_enforce_edit_bounds()
	_protect_anchor_voxels()
	_request_rebuild()
	_mark_edited_if_changed(changed)
	_last_stroke = _solid_stroke_summary(TOOL_GRAB, local_position, clamped_position, clean_radius, changed)
	return _last_stroke.duplicate(true)


func apply_beautify_capsule_world(tool_name: String, world_start: Vector3, world_end: Vector3, world_radius: float = DEFAULT_SCULPT_RADIUS, strength: float = 1.0) -> Dictionary:
	return apply_beautify_capsule_local(tool_name, to_local(world_start), to_local(world_end), world_radius, strength)


func apply_beautify_capsule_local(tool_name: String, local_start: Vector3, local_end: Vector3, world_radius: float = DEFAULT_SCULPT_RADIUS, strength: float = 1.0) -> Dictionary:
	_ensure_voxel_data()
	var edit_bounds := get_edit_bounds()
	var clamped_start := _clamp_point_to_aabb(local_start, edit_bounds)
	var clamped_end := _clamp_point_to_aabb(local_end, edit_bounds)
	var radius := clampf(world_radius, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS)
	var clean_tool := _normalize_tool_name(tool_name)
	var clean_strength := clampf(strength, 0.0, 2.0)
	var before_solid_count := _solid_count
	var normal := _sdf_gradient_normal_local(clamped_end)
	var changed := 0
	var polish_radius := clampf(radius * 1.18, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS)
	changed += _smooth_sdf_capsule(clamped_start, clamped_end, polish_radius, 0.34 + clean_strength * 0.12)
	changed += _seal_small_holes_capsule(clamped_start, clamped_end, polish_radius)
	changed += _remove_spike_voxels_capsule(clamped_start, clamped_end, polish_radius)
	match clean_tool:
		TOOL_REMOVE:
			changed += _smooth_sdf_capsule(clamped_start, clamped_end, clampf(radius * 0.82, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS), 0.42)
		TOOL_FLATTEN:
			changed += _apply_sdf_flatten_capsule(clamped_start, clamped_end, normal, clampf(radius * 0.94, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS), 0.18)
		TOOL_SMART, TOOL_ADD, TOOL_STRETCH:
			changed += _smooth_sdf_capsule(clamped_start, clamped_end, clampf(radius * 1.34, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS), 0.18)
	changed += _apply_volume_feedback(TOOL_SMOOTH, clamped_start, clamped_end, radius, clean_strength * 0.55, before_solid_count, normal)
	_enforce_edit_bounds()
	_protect_anchor_voxels()
	_request_rebuild()
	_mark_edited_if_changed(changed)
	_last_stroke = _solid_stroke_summary("beautify", local_end, clamped_end, radius, changed)
	_last_stroke["source_tool"] = clean_tool
	_last_stroke["operations"] = ["round", "seal", "despike", "volume_feedback"]
	return _last_stroke.duplicate(true)


func paint_sphere_world(world_position: Vector3, world_radius: float, color: Color) -> Dictionary:
	return paint_sphere_local(to_local(world_position), world_radius, color)


func paint_sphere_local(local_position: Vector3, world_radius: float, color: Color) -> Dictionary:
	_ensure_voxel_data()
	color.a = 1.0
	var radius_sq := world_radius * world_radius
	var changed := 0
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				if not _is_solid(x, y, z):
					continue
				var center := _voxel_center_local(x, y, z)
				if center.distance_squared_to(local_position) <= radius_sq:
					_voxel_colors[_voxel_index(x, y, z)] = color
					changed += 1
	_request_rebuild()
	_mark_edited_if_changed(changed)
	_last_stroke = {
		"tool": "paint",
		"changed_voxels": changed,
		"changed_vertices": changed,
		"radius": world_radius,
	}
	return _last_stroke.duplicate(true)


func soft_reset_sphere_world(world_position: Vector3, world_radius: float, amount: float = 0.35) -> void:
	soft_reset_sphere_local(to_local(world_position), world_radius, amount)


func soft_reset_sphere_local(local_position: Vector3, world_radius: float, amount: float = 0.35) -> void:
	_ensure_voxel_data()
	var radius := clampf(world_radius, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS * 1.6)
	var blend := clampf(amount, 0.0, 1.0)
	var radius_sq := radius * radius
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				var center := _voxel_center_local(x, y, z)
				if center.distance_squared_to(local_position) > radius_sq:
					continue
				var index := _voxel_index(x, y, z)
				var current: float = float(voxel_buffer.get_voxel_f(x, y, z, CHANNEL_SDF))
				var target: float = _initial_sdf[index] if index < _initial_sdf.size() else current
				voxel_buffer.set_voxel_f(lerpf(current, target, blend), x, y, z, CHANNEL_SDF)
				if index < _voxel_colors.size():
					_voxel_colors[index] = _voxel_colors[index].lerp(DEFAULT_COLOR, blend)
	_enforce_edit_bounds()
	_protect_anchor_voxels()
	_request_rebuild()
	_base_clone_clean = false


func get_edit_bounds() -> AABB:
	return AABB(Vector3(-0.86, 0.04, -0.62), Vector3(1.72, 1.82, 1.24))


func get_last_stroke_summary() -> Dictionary:
	return _last_stroke.duplicate(true)


func get_anchor_integrity() -> Dictionary:
	var result := {}
	for anchor in _anchor_samples():
		var name := str(anchor.get("name", "anchor"))
		var local_position: Vector3 = anchor.get("position", Vector3.ZERO)
		var voxel := _local_to_voxel_index(local_position)
		result[name] = _is_valid_voxel(voxel.x, voxel.y, voxel.z) and _is_solid(voxel.x, voxel.y, voxel.z)
	return result


func anchors_intact() -> bool:
	for intact in get_anchor_integrity().values():
		if not bool(intact):
			return false
	return true


func get_solid_voxel_count() -> int:
	return _solid_count


func get_vertex_count() -> int:
	if _rebuild_pending:
		_flush_pending_rebuild()
	return int(_render_mesh_summary.get("vertex_count", 0))


func get_triangle_count() -> int:
	if _rebuild_pending:
		_flush_pending_rebuild()
	return int(_render_mesh_summary.get("triangle_count", 0))


func get_local_bounds() -> AABB:
	return get_solid_local_bounds()


func get_vertex_checksum() -> int:
	return get_sdf_checksum()


func get_source_mesh_summary() -> Dictionary:
	return _source_mesh_summary.duplicate(true)


func get_render_mesh_summary() -> Dictionary:
	if _rebuild_pending:
		_flush_pending_rebuild()
	return _render_mesh_summary.duplicate(true)


func get_surface_quality_summary() -> Dictionary:
	var max_edge := 0.0
	var total_edge := 0.0
	var edge_count := 0
	if body_mesh and body_mesh.mesh:
		var mesh := body_mesh.mesh
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			if arrays.size() <= Mesh.ARRAY_VERTEX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				continue
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var indices := PackedInt32Array()
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
				indices = arrays[Mesh.ARRAY_INDEX]
			var triangle_count := int(indices.size() / 3) if not indices.is_empty() else int(vertices.size() / 3)
			for triangle in range(triangle_count):
				var i0 := int(indices[triangle * 3]) if not indices.is_empty() else triangle * 3
				var i1 := int(indices[triangle * 3 + 1]) if not indices.is_empty() else triangle * 3 + 1
				var i2 := int(indices[triangle * 3 + 2]) if not indices.is_empty() else triangle * 3 + 2
				if i0 < 0 or i1 < 0 or i2 < 0 or i0 >= vertices.size() or i1 >= vertices.size() or i2 >= vertices.size():
					continue
				var e01 := vertices[i0].distance_to(vertices[i1])
				var e12 := vertices[i1].distance_to(vertices[i2])
				var e20 := vertices[i2].distance_to(vertices[i0])
				max_edge = maxf(max_edge, maxf(e01, maxf(e12, e20)))
				total_edge += e01 + e12 + e20
				edge_count += 3
	return {
		"mode": "solid_sdf_clay",
		"solid_count": _solid_count,
		"vertex_count": get_vertex_count(),
		"triangle_count": get_triangle_count(),
		"component_count": 1 if _solid_count > 0 else 0,
		"max_edge": max_edge,
		"average_edge": total_edge / float(maxi(edge_count, 1)),
		"surface_count": body_mesh.mesh.get_surface_count() if body_mesh and body_mesh.mesh else 0,
		"voxel_mesher": "VoxelMesherTransvoxel",
	}


func get_solid_local_bounds() -> AABB:
	_ensure_voxel_data()
	var has_solid := false
	var bounds := AABB()
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				if not _is_solid(x, y, z):
					continue
				var local_position := _voxel_center_local(x, y, z)
				if not has_solid:
					bounds = AABB(local_position, Vector3.ZERO)
					has_solid = true
				else:
					bounds = bounds.expand(local_position)
	return bounds


func _should_use_basic_human_fallback() -> bool:
	if _solid_count <= 0:
		return true
	var bounds := get_solid_local_bounds()
	if bounds.size.y <= 0.01:
		return true
	return absf(bounds.size.y - BASIC_HUMAN_PLAYABLE_HEIGHT) > 0.16


func has_solid_voxel_near(local_position: Vector3, radius: float) -> bool:
	_ensure_voxel_data()
	var radius_sq := radius * radius
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				if not _is_solid(x, y, z):
					continue
				if _voxel_center_local(x, y, z).distance_squared_to(local_position) <= radius_sq:
					return true
	return false


func count_solid_voxels_outside_edit_bounds() -> int:
	var count := 0
	var edit_bounds := get_edit_bounds()
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				if _is_solid(x, y, z) and not edit_bounds.has_point(_voxel_center_local(x, y, z)):
					count += 1
	return count


func get_sdf_checksum() -> int:
	return get_sdf_values_checksum(get_sdf_values())


func make_sculpt_snapshot() -> Dictionary:
	_ensure_voxel_data()
	var sdf := get_sdf_values()
	return {
		"sdf": sdf,
		"colors": _voxel_colors.duplicate(),
	}


func apply_sculpt_snapshot(snapshot: Dictionary) -> void:
	_last_snapshot_apply_ok = false
	if not _ensure_voxel_data():
		return
	var sdf := PackedFloat32Array()
	var raw_sdf = snapshot.get("sdf", PackedFloat32Array())
	if raw_sdf is PackedFloat32Array:
		sdf = raw_sdf
	elif raw_sdf is Array:
		for value in raw_sdf:
			sdf.append(float(value))
	var colors := PackedColorArray()
	var raw_colors = snapshot.get("colors", PackedColorArray())
	if raw_colors is PackedColorArray:
		colors = raw_colors
	elif raw_colors is Array:
		for value in raw_colors:
			if value is Color:
				colors.append(value)
	if sdf.size() != _voxel_count():
		return
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				voxel_buffer.set_voxel_f(sdf[_voxel_index(x, y, z)], x, y, z, CHANNEL_SDF)
	if colors.size() == _voxel_count():
		_voxel_colors = colors.duplicate()
	_enforce_edit_bounds()
	_protect_anchor_voxels()
	_request_rebuild()
	_last_snapshot_apply_ok = true
	_base_clone_clean = false


func was_last_snapshot_apply_ok() -> bool:
	return _last_snapshot_apply_ok


func intersect_ray_world(world_origin: Vector3, world_direction: Vector3, max_distance: float = 64.0) -> Dictionary:
	if _rebuild_pending:
		_flush_pending_rebuild()
	if not body_mesh or not body_mesh.mesh or world_direction.length_squared() <= 0.000001:
		return {}
	var local_origin := to_local(world_origin)
	var local_direction := (global_transform.basis.inverse() * world_direction).normalized()
	var max_local_distance := max_distance / maxf(global_transform.basis.get_scale().length() / sqrt(3.0), 0.001)
	var best_distance := INF
	var best_position := Vector3.ZERO
	var best_normal := Vector3.UP
	var mesh := body_mesh.mesh
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.size() <= Mesh.ARRAY_VERTEX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			continue
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := PackedVector3Array()
		if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			normals = arrays[Mesh.ARRAY_NORMAL]
		var indices := PackedInt32Array()
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX]
		var triangle_count := int(indices.size() / 3) if not indices.is_empty() else int(vertices.size() / 3)
		for triangle in range(triangle_count):
			var i0 := int(indices[triangle * 3]) if not indices.is_empty() else triangle * 3
			var i1 := int(indices[triangle * 3 + 1]) if not indices.is_empty() else triangle * 3 + 1
			var i2 := int(indices[triangle * 3 + 2]) if not indices.is_empty() else triangle * 3 + 2
			if i0 < 0 or i1 < 0 or i2 < 0 or i0 >= vertices.size() or i1 >= vertices.size() or i2 >= vertices.size():
				continue
			var hit := _ray_intersects_triangle(local_origin, local_direction, vertices[i0], vertices[i1], vertices[i2])
			if hit < 0.0 or hit > max_local_distance or hit >= best_distance:
				continue
			best_distance = hit
			best_position = local_origin + local_direction * hit
			if i0 < normals.size() and i1 < normals.size() and i2 < normals.size():
				best_normal = (normals[i0] + normals[i1] + normals[i2]).normalized()
			if best_normal.length_squared() <= 0.000001:
				best_normal = (vertices[i1] - vertices[i0]).cross(vertices[i2] - vertices[i0]).normalized()
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


func make_compact_body() -> Dictionary:
	var sdf_q := []
	var values := get_sdf_values()
	for value in values:
		sdf_q.append(clampi(int(round(value * SNAPSHOT_SDF_SCALE)), -32768, 32767))
	var palette := []
	var palette_lookup := {}
	var color_indices := []
	for color in _voxel_colors:
		var key := _color_to_html(color)
		if not palette_lookup.has(key):
			palette_lookup[key] = palette.size()
			palette.append(key)
		color_indices.append(int(palette_lookup[key]))
	return {
		"version": COMPACT_BODY_VERSION,
		"grid": [GRID_WIDTH, GRID_HEIGHT, GRID_DEPTH],
		"voxel_scale": VOXEL_SCALE,
		"sdf_scale": SNAPSHOT_SDF_SCALE,
		"sdf_q_rle": _encode_int_rle(sdf_q),
		"palette": palette,
		"color_indices_rle": _encode_int_rle(color_indices),
		"solid_count": _solid_count,
		"checksum": _compact_body_checksum(sdf_q, color_indices),
	}


func make_compact_profile() -> Dictionary:
	return make_compact_body()


func apply_compact_body(body: Dictionary) -> bool:
	if int(body.get("version", 0)) != COMPACT_BODY_VERSION:
		return false
	var grid: Array = body.get("grid", [])
	if grid.size() != 3 or int(grid[0]) != GRID_WIDTH or int(grid[1]) != GRID_HEIGHT or int(grid[2]) != GRID_DEPTH:
		return false
	var sdf_scale := float(body.get("sdf_scale", SNAPSHOT_SDF_SCALE))
	if sdf_scale <= 0.0:
		return false
	var sdf_q := _decode_int_rle(body.get("sdf_q_rle", []))
	if sdf_q.size() != _voxel_count():
		return false
	var snapshot_sdf := PackedFloat32Array()
	snapshot_sdf.resize(_voxel_count())
	for i in range(sdf_q.size()):
		snapshot_sdf[i] = float(sdf_q[i]) / sdf_scale
	var colors := PackedColorArray()
	var palette: Array = body.get("palette", [])
	var color_indices := _decode_int_rle(body.get("color_indices_rle", []))
	if color_indices.size() == _voxel_count() and not palette.is_empty():
		colors.resize(_voxel_count())
		for i in range(color_indices.size()):
			var palette_index := clampi(int(color_indices[i]), 0, palette.size() - 1)
			colors[i] = Color.html(str(palette[palette_index]))
	apply_sculpt_snapshot({
		"sdf": snapshot_sdf,
		"colors": colors,
	})
	return was_last_snapshot_apply_ok()


func apply_compact_profile(profile: Dictionary) -> bool:
	return apply_compact_body(profile)


func get_compact_body_estimated_bytes(body: Dictionary) -> int:
	return JSON.stringify(body).to_utf8_buffer().size()


func get_sdf_values() -> PackedFloat32Array:
	var sdf := PackedFloat32Array()
	if not _ensure_voxel_data():
		return sdf
	sdf.resize(_voxel_count())
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				sdf[_voxel_index(x, y, z)] = voxel_buffer.get_voxel_f(x, y, z, CHANNEL_SDF)
	return sdf


func get_sdf_values_checksum(values: PackedFloat32Array) -> int:
	var checksum := 17
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				var index := _voxel_index(x, y, z)
				var quantized := int(round(values[index] * 1000.0)) if index < values.size() else 0
				checksum = int((checksum * 131 + quantized + x * 17 + y * 31 + z * 43) & 0x7fffffff)
	return checksum


func _initialize_voxel_storage(fill_color: Color = DEFAULT_COLOR) -> bool:
	if not _voxel_runtime_available():
		_disable_voxel_runtime("voxel_extension_unavailable")
		return false
	voxel_buffer = ClassDB.instantiate("VoxelBuffer")
	if voxel_buffer == null:
		_disable_voxel_runtime("voxel_buffer_instantiate_failed")
		return false
	voxel_buffer.create(GRID_WIDTH, GRID_HEIGHT, GRID_DEPTH)
	voxel_buffer.set_channel_depth(CHANNEL_SDF, VOXEL_DEPTH_32_BIT)
	voxel_tool = voxel_buffer.get_voxel_tool()
	if voxel_tool == null:
		_disable_voxel_runtime("voxel_tool_unavailable")
		return false
	voxel_tool.set("channel", CHANNEL_SDF)
	_voxel_mesher = ClassDB.instantiate("VoxelMesherTransvoxel")
	if _voxel_mesher == null:
		_disable_voxel_runtime("voxel_mesher_instantiate_failed")
		return false
	_initial_sdf = PackedFloat32Array()
	_voxel_colors = PackedColorArray()
	_initial_sdf.resize(_voxel_count())
	_voxel_colors.resize(_voxel_count())
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				var index := _voxel_index(x, y, z)
				voxel_buffer.set_voxel_f(AIR_SDF, x, y, z, CHANNEL_SDF)
				_initial_sdf[index] = AIR_SDF
				_voxel_colors[index] = fill_color
	return true


func _capture_initial_sdf_from_buffer() -> void:
	_initial_sdf.resize(_voxel_count())
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				_initial_sdf[_voxel_index(x, y, z)] = voxel_buffer.get_voxel_f(x, y, z, CHANNEL_SDF)


func _collect_source_triangles(source_meshes: Array) -> Array[Dictionary]:
	var triangles: Array[Dictionary] = []
	var shell_inverse := global_transform.affine_inverse()
	for value in source_meshes:
		var mesh_instance := value as MeshInstance3D
		if not mesh_instance or not is_instance_valid(mesh_instance) or mesh_instance == body_mesh:
			continue
		if not mesh_instance.mesh:
			continue
		var source_mesh := _source_mesh_for_voxelization(mesh_instance)
		if not source_mesh:
			continue
		var mesh_to_shell := shell_inverse * mesh_instance.global_transform
		var surface_count := source_mesh.get_surface_count()
		for surface in range(surface_count):
			var arrays := CamouflageSystem._get_mesh_surface_arrays_static(source_mesh, surface)
			if arrays.size() <= Mesh.ARRAY_VERTEX:
				continue
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			if vertices.is_empty():
				continue
			var vertex_colors := PackedColorArray()
			if arrays.size() > Mesh.ARRAY_COLOR and arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
				vertex_colors = arrays[Mesh.ARRAY_COLOR]
			var indices := PackedInt32Array()
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
				indices = arrays[Mesh.ARRAY_INDEX]
			var fallback_color := _mesh_surface_color(mesh_instance, surface)
			if indices.is_empty():
				var triangle_count := int(vertices.size() / 3)
				for triangle_index in range(triangle_count):
					var vertex_index := triangle_index * 3
					_append_source_triangle(
						triangles,
						mesh_to_shell * vertices[vertex_index],
						mesh_to_shell * vertices[vertex_index + 1],
						mesh_to_shell * vertices[vertex_index + 2],
						_triangle_color(vertex_colors, vertex_index, vertex_index + 1, vertex_index + 2, fallback_color)
					)
			else:
				var triangle_count := int(indices.size() / 3)
				for triangle_index in range(triangle_count):
					var index_offset := triangle_index * 3
					var i0 := int(indices[index_offset])
					var i1 := int(indices[index_offset + 1])
					var i2 := int(indices[index_offset + 2])
					if i0 < 0 or i1 < 0 or i2 < 0 or i0 >= vertices.size() or i1 >= vertices.size() or i2 >= vertices.size():
						continue
					_append_source_triangle(
						triangles,
						mesh_to_shell * vertices[i0],
						mesh_to_shell * vertices[i1],
						mesh_to_shell * vertices[i2],
						_triangle_color(vertex_colors, i0, i1, i2, fallback_color)
					)
	return triangles


func _append_source_triangle(triangles: Array[Dictionary], a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).length_squared() <= 0.0000001:
		return
	var min_point := Vector3(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)), minf(a.z, minf(b.z, c.z)))
	var max_point := Vector3(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)), maxf(a.z, maxf(b.z, c.z)))
	triangles.append({
		"a": a,
		"b": b,
		"c": c,
		"color": color,
		"min": min_point,
		"max": max_point,
	})


func _fit_source_triangles_to_edit_bounds(triangles: Array[Dictionary]) -> void:
	if triangles.is_empty():
		return
	var min_point := Vector3(INF, INF, INF)
	var max_point := Vector3(-INF, -INF, -INF)
	for triangle in triangles:
		for key in ["a", "b", "c"]:
			var point: Vector3 = triangle.get(key, Vector3.ZERO)
			min_point = Vector3(minf(min_point.x, point.x), minf(min_point.y, point.y), minf(min_point.z, point.z))
			max_point = Vector3(maxf(max_point.x, point.x), maxf(max_point.y, point.y), maxf(max_point.z, point.z))
	var source_size := max_point - min_point
	if source_size.x <= 0.00001 or source_size.y <= 0.00001 or source_size.z <= 0.00001:
		return
	var target := get_edit_bounds()
	var target_size := target.size * 0.94
	var playable_height_scale := BASIC_HUMAN_PLAYABLE_HEIGHT / source_size.y
	var height_bounds_scale := target_size.y / source_size.y
	var scale := minf(playable_height_scale, height_bounds_scale)
	if scale <= 0.00001 or scale >= INF:
		return
	var source_center := (min_point + max_point) * 0.5
	var target_center := target.position + target.size * 0.5
	var target_bottom := target.position.y + target.size.y * 0.03
	for triangle in triangles:
		var fitted_points := []
		for key in ["a", "b", "c"]:
			var point: Vector3 = triangle.get(key, Vector3.ZERO)
			var fitted := Vector3(
				(point.x - source_center.x) * scale + target_center.x,
				(point.y - min_point.y) * scale + target_bottom,
				(point.z - source_center.z) * scale + target_center.z
			)
			triangle[key] = fitted
			fitted_points.append(fitted)
		var a: Vector3 = fitted_points[0]
		var b: Vector3 = fitted_points[1]
		var c: Vector3 = fitted_points[2]
		triangle["min"] = Vector3(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)), minf(a.z, minf(b.z, c.z)))
		triangle["max"] = Vector3(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)), maxf(a.z, maxf(b.z, c.z)))


func _source_mesh_for_voxelization(mesh_instance: MeshInstance3D) -> Mesh:
	var manual_baked := _manual_rest_skin_mesh(mesh_instance)
	if manual_baked:
		return manual_baked
	if mesh_instance.has_method("bake_mesh_from_current_skeleton_pose"):
		var skeleton := _find_source_skeleton(mesh_instance)
		var stored_poses := _store_skeleton_poses(skeleton)
		_reset_skeleton_to_rest(skeleton)
		var baked = mesh_instance.call("bake_mesh_from_current_skeleton_pose")
		_restore_skeleton_poses(skeleton, stored_poses)
		if baked is Mesh:
			return baked
	if mesh_instance.has_method("bake_mesh_from_current_blend_shape_mix"):
		var blend_baked = mesh_instance.call("bake_mesh_from_current_blend_shape_mix")
		if blend_baked is Mesh:
			return blend_baked
	return mesh_instance.mesh


func _manual_rest_skin_mesh(mesh_instance: MeshInstance3D) -> Mesh:
	if not mesh_instance or not mesh_instance.mesh or not mesh_instance.skin:
		return null
	var skeleton := _find_source_skeleton(mesh_instance)
	if not skeleton:
		return null
	var skin: Skin = mesh_instance.skin
	if skin.get_bind_count() <= 0:
		return null
	var baked := ArrayMesh.new()
	var used_skinning := false
	for surface in range(mesh_instance.mesh.get_surface_count()):
		var arrays := CamouflageSystem._get_mesh_surface_arrays_static(mesh_instance.mesh, surface)
		if arrays.size() <= Mesh.ARRAY_WEIGHTS:
			continue
		if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			continue
		if not arrays[Mesh.ARRAY_BONES] is PackedInt32Array or not arrays[Mesh.ARRAY_WEIGHTS] is PackedFloat32Array:
			continue
		var vertices := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
		var bones := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
		var weights := arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
		if vertices.is_empty() or bones.size() < vertices.size() or weights.size() != bones.size():
			continue
		var influences_per_vertex := maxi(1, int(bones.size() / vertices.size()))
		for vertex_index in range(vertices.size()):
			var source_vertex := vertices[vertex_index]
			var skinned := Vector3.ZERO
			var total_weight := 0.0
			for influence in range(influences_per_vertex):
				var influence_index := vertex_index * influences_per_vertex + influence
				if influence_index >= bones.size() or influence_index >= weights.size():
					continue
				var weight := float(weights[influence_index])
				if weight <= 0.00001:
					continue
				var bind_index := int(bones[influence_index])
				var bone_index := _bone_index_for_skin_bind(skin, skeleton, bind_index)
				if bone_index < 0:
					continue
				var bone_rest := _skeleton_bone_global_rest(skeleton, bone_index)
				var bind_pose := skin.get_bind_pose(bind_index) if bind_index >= 0 and bind_index < skin.get_bind_count() else Transform3D.IDENTITY
				skinned += (bone_rest * bind_pose * source_vertex) * weight
				total_weight += weight
			if total_weight > 0.00001:
				vertices[vertex_index] = mesh_instance.transform.affine_inverse() * (skinned / total_weight)
				used_skinning = true
		arrays[Mesh.ARRAY_VERTEX] = vertices
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if used_skinning and baked.get_surface_count() > 0:
		return baked
	return null


func _bone_index_for_skin_bind(skin: Skin, skeleton: Skeleton3D, bind_index: int) -> int:
	if bind_index < 0 or bind_index >= skin.get_bind_count():
		return -1
	var bone_index := -1
	if skin.has_method("get_bind_bone"):
		bone_index = int(skin.call("get_bind_bone", bind_index))
	if bone_index >= 0 and bone_index < skeleton.get_bone_count():
		return bone_index
	if skin.has_method("get_bind_name") and skeleton.has_method("find_bone"):
		var bone_name := str(skin.call("get_bind_name", bind_index))
		if not bone_name.is_empty():
			bone_index = int(skeleton.call("find_bone", bone_name))
	return bone_index if bone_index >= 0 and bone_index < skeleton.get_bone_count() else -1


func _skeleton_bone_global_rest(skeleton: Skeleton3D, bone_index: int) -> Transform3D:
	if skeleton.has_method("get_bone_global_rest"):
		var rest = skeleton.call("get_bone_global_rest", bone_index)
		if rest is Transform3D:
			return rest
	var chain: Array[int] = []
	var current := bone_index
	while current >= 0:
		chain.push_front(current)
		current = skeleton.get_bone_parent(current)
	var transform := Transform3D.IDENTITY
	for index in chain:
		transform *= skeleton.get_bone_rest(index)
	return transform


func _find_source_skeleton(mesh_instance: MeshInstance3D) -> Skeleton3D:
	var node: Node = mesh_instance
	while node:
		if node is Skeleton3D:
			return node as Skeleton3D
		node = node.get_parent()
	return null


func _store_skeleton_poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	if not skeleton:
		return poses
	for bone_index in range(skeleton.get_bone_count()):
		poses.append(skeleton.get_bone_pose(bone_index))
	return poses


func _reset_skeleton_to_rest(skeleton: Skeleton3D) -> void:
	if not skeleton:
		return
	if skeleton.has_method("reset_bone_poses"):
		skeleton.call("reset_bone_poses")
	else:
		for bone_index in range(skeleton.get_bone_count()):
			if skeleton.has_method("reset_bone_pose"):
				skeleton.call("reset_bone_pose", bone_index)
	if skeleton.has_method("force_update_all_bone_transforms"):
		skeleton.call("force_update_all_bone_transforms")


func _restore_skeleton_poses(skeleton: Skeleton3D, poses: Array[Transform3D]) -> void:
	if not skeleton:
		return
	for bone_index in range(mini(skeleton.get_bone_count(), poses.size())):
		skeleton.set_bone_pose(bone_index, poses[bone_index])
	if skeleton.has_method("force_update_all_bone_transforms"):
		skeleton.call("force_update_all_bone_transforms")


func _stamp_source_triangle(triangle: Dictionary, surface_mask: PackedByteArray) -> void:
	var a: Vector3 = triangle.get("a", Vector3.ZERO)
	var b: Vector3 = triangle.get("b", Vector3.ZERO)
	var c: Vector3 = triangle.get("c", Vector3.ZERO)
	var color: Color = triangle.get("color", DEFAULT_COLOR)
	var margin := SOURCE_SURFACE_STAMP_RADIUS
	var min_point: Vector3 = triangle.get("min", Vector3.ZERO) - Vector3.ONE * margin
	var max_point: Vector3 = triangle.get("max", Vector3.ZERO) + Vector3.ONE * margin
	var min_voxel := _local_to_voxel_index(min_point)
	var max_voxel := _local_to_voxel_index(max_point)
	var radius_sq := margin * margin
	for z in range(min_voxel.z, max_voxel.z + 1):
		for y in range(min_voxel.y, max_voxel.y + 1):
			for x in range(min_voxel.x, max_voxel.x + 1):
				var center := _voxel_center_local(x, y, z)
				if _point_triangle_distance_squared(center, a, b, c) > radius_sq:
					continue
				var index := _voxel_index(x, y, z)
				surface_mask[index] = 1
				_voxel_colors[index] = color


func _make_axis_fill_mask(surface_mask: PackedByteArray, axis: int) -> PackedByteArray:
	var fill_mask := PackedByteArray()
	fill_mask.resize(_voxel_count())
	match axis:
		0:
			for z in range(GRID_DEPTH):
				for y in range(GRID_HEIGHT):
					var line: Array[int] = []
					for x in range(GRID_WIDTH):
						line.append(_voxel_index(x, y, z))
					_fill_line_between_surface_runs(surface_mask, fill_mask, line)
		1:
			for z in range(GRID_DEPTH):
				for x in range(GRID_WIDTH):
					var line: Array[int] = []
					for y in range(GRID_HEIGHT):
						line.append(_voxel_index(x, y, z))
					_fill_line_between_surface_runs(surface_mask, fill_mask, line)
		2:
			for y in range(GRID_HEIGHT):
				for x in range(GRID_WIDTH):
					var line: Array[int] = []
					for z in range(GRID_DEPTH):
						line.append(_voxel_index(x, y, z))
					_fill_line_between_surface_runs(surface_mask, fill_mask, line)
	return fill_mask


func _fill_line_between_surface_runs(surface_mask: PackedByteArray, fill_mask: PackedByteArray, line: Array[int]) -> void:
	var runs: Array[Vector2i] = []
	var run_start := -1
	for i in range(line.size()):
		var is_surface := int(surface_mask[line[i]]) > 0
		if is_surface and run_start < 0:
			run_start = i
		elif not is_surface and run_start >= 0:
			runs.append(Vector2i(run_start, i - 1))
			run_start = -1
	if run_start >= 0:
		runs.append(Vector2i(run_start, line.size() - 1))
	if runs.is_empty():
		return
	if runs.size() == 1:
		for i in range(runs[0].x, runs[0].y + 1):
			fill_mask[line[i]] = 1
		return
	for run_index in range(0, runs.size() - 1, 2):
		var start := runs[run_index].x
		var end := runs[run_index + 1].y
		for i in range(start, end + 1):
			fill_mask[line[i]] = 1
	if runs.size() % 2 == 1:
		var last := runs[runs.size() - 1]
		for i in range(last.x, last.y + 1):
			fill_mask[line[i]] = 1


func _point_triangle_distance_squared(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := b - a
	var ac := c - a
	var ap := point - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return point.distance_squared_to(a)
	var bp := point - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return point.distance_squared_to(b)
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var v := d1 / (d1 - d3)
		return point.distance_squared_to(a + ab * v)
	var cp := point - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return point.distance_squared_to(c)
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var w := d2 / (d2 - d6)
		return point.distance_squared_to(a + ac * w)
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var w := (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return point.distance_squared_to(b + (c - b) * w)
	var normal := ab.cross(ac).normalized()
	var distance := absf((point - a).dot(normal))
	return distance * distance


func _triangle_color(vertex_colors: PackedColorArray, i0: int, i1: int, i2: int, fallback: Color) -> Color:
	if i0 >= 0 and i1 >= 0 and i2 >= 0 and i0 < vertex_colors.size() and i1 < vertex_colors.size() and i2 < vertex_colors.size():
		var c0 := vertex_colors[i0]
		var c1 := vertex_colors[i1]
		var c2 := vertex_colors[i2]
		var color := Color(
			(c0.r + c1.r + c2.r) / 3.0,
			(c0.g + c1.g + c2.g) / 3.0,
			(c0.b + c1.b + c2.b) / 3.0,
			1.0
		)
		color.a = 1.0
		return color
	return fallback


func _mesh_surface_color(mesh_instance: MeshInstance3D, surface: int) -> Color:
	var material: Material = mesh_instance.get_surface_override_material(surface)
	if not material and mesh_instance.mesh and surface >= 0 and surface < mesh_instance.mesh.get_surface_count():
		material = mesh_instance.mesh.surface_get_material(surface)
	if material is StandardMaterial3D:
		var color := (material as StandardMaterial3D).albedo_color
		color.a = 1.0
		return color
	if material is ShaderMaterial:
		for parameter in ["albedo_color", "base_color", "color", "tint"]:
			var value = (material as ShaderMaterial).get_shader_parameter(parameter)
			if value is Color:
				var shader_color := value as Color
				shader_color.a = 1.0
				return shader_color
	return DEFAULT_COLOR


func _count_valid_source_meshes(source_meshes: Array) -> int:
	var count := 0
	for value in source_meshes:
		var mesh_instance := value as MeshInstance3D
		if mesh_instance and is_instance_valid(mesh_instance) and mesh_instance.mesh:
			count += 1
	return count


func rebuild_mesh() -> void:
	var started := Time.get_ticks_msec()
	_ensure_mesh_node()
	if not _ensure_voxel_data():
		_rebuild_count += 1
		_last_rebuild_elapsed_msec = Time.get_ticks_msec() - started
		return
	_sanitize_sdf_buffer()
	_solid_count = _count_solid_voxels()
	var mesh := _build_smooth_sdf_mesh()
	body_mesh.mesh = mesh
	_rebuild_count += 1
	_last_rebuild_elapsed_msec = Time.get_ticks_msec() - started
	rebuilt.emit()


func _request_rebuild() -> void:
	if _rebuild_defer_depth > 0:
		_rebuild_pending = true
		return
	if _rebuild_pending:
		return
	_rebuild_pending = true
	if is_inside_tree():
		call_deferred("_flush_pending_rebuild")
	else:
		_flush_pending_rebuild()


func _flush_pending_rebuild() -> void:
	if _rebuild_defer_depth > 0 or not _rebuild_pending:
		return
	_rebuild_pending = false
	rebuild_mesh()


func _build_smooth_sdf_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.lightmap_size_hint = Vector2i(256, 256)
	if not _has_voxel_data():
		_render_mesh_summary = {
			"mode": "disabled",
			"reason": "voxel_data_unavailable",
			"surface_count": 0,
			"vertex_count": 0,
			"triangle_count": 0,
			"solid_count": 0,
		}
		return mesh
	if not _voxel_mesher:
		if not _voxel_runtime_available():
			_disable_voxel_runtime("voxel_extension_unavailable")
			return mesh
		_voxel_mesher = ClassDB.instantiate("VoxelMesherTransvoxel")
	if _voxel_mesher == null:
		_disable_voxel_runtime("voxel_mesher_instantiate_failed")
		return mesh
	var material := _make_shell_material()
	var raw_mesh: Mesh = _voxel_mesher.build_mesh(voxel_buffer, [material], {})
	if not raw_mesh:
		_render_mesh_summary = {
			"mode": "smooth_sdf",
			"surface_count": 0,
			"vertex_count": 0,
			"triangle_count": 0,
			"solid_count": _solid_count,
		}
		return mesh
	var total_vertices := 0
	var total_triangles := 0
	for surface in range(raw_mesh.get_surface_count()):
		var arrays := raw_mesh.surface_get_arrays(surface)
		if arrays.size() <= Mesh.ARRAY_VERTEX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			continue
		var raw_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if raw_vertices.is_empty():
			continue
		var raw_indices := PackedInt32Array()
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			raw_indices = arrays[Mesh.ARRAY_INDEX]
		var vertices := PackedVector3Array()
		vertices.resize(raw_vertices.size())
		for i in range(raw_vertices.size()):
			var local_vertex := _voxel_space_to_local(raw_vertices[i])
			vertices[i] = local_vertex
		var normals := PackedVector3Array()
		if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array and (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == raw_vertices.size():
			normals = arrays[Mesh.ARRAY_NORMAL]
		else:
			normals = _rebuild_surface_normals(vertices, raw_indices)
		var uvs := PackedVector2Array()
		var colors := PackedColorArray()
		uvs.resize(vertices.size())
		colors.resize(vertices.size())
		for i in range(vertices.size()):
			var local_vertex := vertices[i]
			uvs[i] = _shell_uv(local_vertex)
			colors[i] = _color_at_local_position(local_vertex)
		var clean_arrays := []
		clean_arrays.resize(Mesh.ARRAY_MAX)
		clean_arrays[Mesh.ARRAY_VERTEX] = vertices
		clean_arrays[Mesh.ARRAY_NORMAL] = normals
		clean_arrays[Mesh.ARRAY_TEX_UV] = uvs
		clean_arrays[Mesh.ARRAY_COLOR] = colors
		if not raw_indices.is_empty():
			clean_arrays[Mesh.ARRAY_INDEX] = raw_indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, clean_arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
		total_vertices += vertices.size()
		total_triangles += int(raw_indices.size() / 3) if not raw_indices.is_empty() else int(vertices.size() / 3)
	_render_mesh_summary = {
		"mode": "smooth_sdf",
		"surface_count": mesh.get_surface_count(),
		"vertex_count": total_vertices,
		"triangle_count": total_triangles,
		"solid_count": _solid_count,
		"voxel_mesher": "VoxelMesherTransvoxel",
	}
	return mesh


func _rebuild_surface_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	if vertices.size() < 3:
		return normals
	if indices.is_empty():
		for i in range(0, vertices.size() - 2, 3):
			_accumulate_triangle_normal(vertices, normals, i, i + 1, i + 2)
	else:
		for i in range(0, indices.size() - 2, 3):
			_accumulate_triangle_normal(vertices, normals, indices[i], indices[i + 1], indices[i + 2])
	for i in range(normals.size()):
		if normals[i].length_squared() > 0.000001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP
	return normals


func _accumulate_triangle_normal(vertices: PackedVector3Array, normals: PackedVector3Array, i0: int, i1: int, i2: int) -> void:
	if i0 < 0 or i1 < 0 or i2 < 0 or i0 >= vertices.size() or i1 >= vertices.size() or i2 >= vertices.size():
		return
	var normal := (vertices[i1] - vertices[i0]).cross(vertices[i2] - vertices[i0])
	if normal.length_squared() <= 0.000001:
		return
	normals[i0] += normal
	normals[i1] += normal
	normals[i2] += normal


func _make_shell_material() -> Material:
	if _shell_material:
		return _shell_material
	var shader := load("res://shaders/chameleon_clay_shell.gdshader") as Shader
	if shader:
		_shell_material = ShaderMaterial.new()
		(_shell_material as ShaderMaterial).shader = shader
		_shell_material.resource_local_to_scene = true
		return _shell_material
	_shell_material = StandardMaterial3D.new()
	(_shell_material as StandardMaterial3D).vertex_color_use_as_albedo = true
	(_shell_material as StandardMaterial3D).roughness = 0.86
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


func _ensure_voxel_data() -> bool:
	if _has_voxel_data():
		return true
	if not _voxel_runtime_available():
		_disable_voxel_runtime("voxel_extension_unavailable")
		return false
	reset_to_default_shell()
	return _has_voxel_data()


func _count_solid_voxels() -> int:
	var count := 0
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				if _is_solid(x, y, z):
					count += 1
	return count


func _voxel_count() -> int:
	return GRID_WIDTH * GRID_HEIGHT * GRID_DEPTH


func _voxel_index(x: int, y: int, z: int) -> int:
	return x + y * GRID_WIDTH + z * GRID_WIDTH * GRID_HEIGHT


func _voxel_center_local(x: int, y: int, z: int) -> Vector3:
	return GRID_MIN + (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * VOXEL_SCALE


func _grid_max_local() -> Vector3:
	return GRID_MIN + Vector3(GRID_WIDTH, GRID_HEIGHT, GRID_DEPTH) * VOXEL_SCALE


func _local_to_voxel_coord(local_position: Vector3) -> Vector3:
	var relative := (local_position - GRID_MIN) / VOXEL_SCALE
	return Vector3(
		clampf(relative.x, 0.0, float(GRID_WIDTH - 1)),
		clampf(relative.y, 0.0, float(GRID_HEIGHT - 1)),
		clampf(relative.z, 0.0, float(GRID_DEPTH - 1))
	)


func _local_to_voxel_index(local_position: Vector3) -> Vector3i:
	var coord := _local_to_voxel_coord(local_position)
	return Vector3i(
		clampi(int(round(coord.x)), 0, GRID_WIDTH - 1),
		clampi(int(round(coord.y)), 0, GRID_HEIGHT - 1),
		clampi(int(round(coord.z)), 0, GRID_DEPTH - 1)
	)


func _voxel_space_to_local(voxel_position: Vector3) -> Vector3:
	return GRID_MIN + voxel_position * VOXEL_SCALE


func _shell_uv(local_position: Vector3) -> Vector2:
	return Vector2(
		inverse_lerp(GRID_MIN.x, GRID_MAX.x, local_position.x),
		inverse_lerp(GRID_MIN.y, GRID_MAX.y, local_position.y)
	)


func _color_at_local_position(local_position: Vector3) -> Color:
	if _voxel_colors.size() != _voxel_count():
		return DEFAULT_COLOR
	var center := _local_to_voxel_index(local_position)
	var best_color := _voxel_colors[_voxel_index(center.x, center.y, center.z)]
	var best_distance := INF
	for radius in range(0, 3):
		for z in range(maxi(0, center.z - radius), mini(GRID_DEPTH, center.z + radius + 1)):
			for y in range(maxi(0, center.y - radius), mini(GRID_HEIGHT, center.y + radius + 1)):
				for x in range(maxi(0, center.x - radius), mini(GRID_WIDTH, center.x + radius + 1)):
					if not _is_solid(x, y, z):
						continue
					var distance := _voxel_center_local(x, y, z).distance_squared_to(local_position)
					if distance < best_distance:
						best_distance = distance
						best_color = _voxel_colors[_voxel_index(x, y, z)]
		if best_distance < INF:
			return best_color
	return best_color


func _is_valid_voxel(x: int, y: int, z: int) -> bool:
	return x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT and z >= 0 and z < GRID_DEPTH


func _is_solid(x: int, y: int, z: int) -> bool:
	return _is_valid_voxel(x, y, z) and voxel_buffer and voxel_buffer.get_voxel_f(x, y, z, CHANNEL_SDF) <= SOLID_EPSILON


func _normalize_tool_name(tool_name: String) -> String:
	match tool_name:
		TOOL_ADD, TOOL_REMOVE, TOOL_SMOOTH, TOOL_STRETCH, TOOL_FLATTEN, TOOL_SMART:
			return tool_name
		"auto", "polish", "shape":
			return TOOL_SMART
	return TOOL_SMART


func _clamp_point_to_aabb(point: Vector3, bounds: AABB) -> Vector3:
	return Vector3(
		clampf(point.x, bounds.position.x, bounds.position.x + bounds.size.x),
		clampf(point.y, bounds.position.y, bounds.position.y + bounds.size.y),
		clampf(point.z, bounds.position.z, bounds.position.z + bounds.size.z)
	)


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


func _enforce_edit_bounds() -> void:
	var edit_bounds := get_edit_bounds()
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				if not edit_bounds.has_point(_voxel_center_local(x, y, z)):
					voxel_buffer.set_voxel_f(maxf(AIR_SDF, voxel_buffer.get_voxel_f(x, y, z, CHANNEL_SDF)), x, y, z, CHANNEL_SDF)


func _sanitize_sdf_buffer() -> void:
	if not voxel_buffer:
		return
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				var value: float = float(voxel_buffer.get_voxel_f(x, y, z, CHANNEL_SDF))
				var clamped: float = _clamp_sdf_value(value)
				if value != clamped:
					voxel_buffer.set_voxel_f(clamped, x, y, z, CHANNEL_SDF)


func _clamp_sdf_value(value: float) -> float:
	if value != value or value > AIR_SDF:
		return AIR_SDF
	if value < -AIR_SDF:
		return -AIR_SDF
	return value


func _protect_anchor_voxels() -> void:
	for z in range(GRID_DEPTH):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				var local_position := _voxel_center_local(x, y, z)
				var anchor_sdf := _clamp_sdf_value(_anchor_sdf(local_position) / VOXEL_SCALE)
				if anchor_sdf < -0.05:
					var current: float = float(voxel_buffer.get_voxel_f(x, y, z, CHANNEL_SDF))
					voxel_buffer.set_voxel_f(minf(current, anchor_sdf), x, y, z, CHANNEL_SDF)
	for anchor in _anchor_samples():
		var voxel := _local_to_voxel_index(anchor.get("position", Vector3.ZERO))
		var current: float = float(voxel_buffer.get_voxel_f(voxel.x, voxel.y, voxel.z, CHANNEL_SDF))
		voxel_buffer.set_voxel_f(minf(current, -0.35), voxel.x, voxel.y, voxel.z, CHANNEL_SDF)


func _apply_sdf_sphere(local_center: Vector3, radius: float, strength: float, add_matter: bool) -> int:
	return _apply_sdf_capsule_brush(local_center, local_center, radius, strength, add_matter)


func _apply_sdf_stretch(local_center: Vector3, radius: float, strength: float) -> int:
	var normal := _sdf_gradient_normal_local(local_center)
	var target := _clamp_point_to_aabb(local_center + normal * radius * 0.92, get_edit_bounds())
	var capsule_radius := radius * clampf(0.42 + strength * 0.08, 0.38, 0.58)
	var changed := _apply_sdf_capsule(local_center, target, capsule_radius, strength)
	_smooth_sdf_sphere((local_center + target) * 0.5, radius * 1.12, 0.32 * strength)
	return changed


func _apply_sdf_capsule(start: Vector3, end: Vector3, radius: float, strength: float) -> int:
	return _apply_sdf_capsule_brush(start, end, radius, strength, true)


func _apply_sdf_capsule_brush(start: Vector3, end: Vector3, radius: float, strength: float, add_matter: bool) -> int:
	var changed := 0
	var blend := clampf(strength * 0.82, 0.0, 1.0)
	var min_point := Vector3(minf(start.x, end.x), minf(start.y, end.y), minf(start.z, end.z)) - Vector3.ONE * radius
	var max_point := Vector3(maxf(start.x, end.x), maxf(start.y, end.y), maxf(start.z, end.z)) + Vector3.ONE * radius
	var min_voxel := _local_to_voxel_index(min_point)
	var max_voxel := _local_to_voxel_index(max_point)
	for z in range(min_voxel.z, max_voxel.z + 1):
		for y in range(min_voxel.y, max_voxel.y + 1):
			for x in range(min_voxel.x, max_voxel.x + 1):
				var center := _voxel_center_local(x, y, z)
				var distance := _point_segment_distance(center, start, end)
				if distance > radius:
					continue
				var brush_sdf: float = (distance - radius) / VOXEL_SCALE
				var current: float = float(voxel_buffer.get_voxel_f(x, y, z, CHANNEL_SDF))
				var target: float = minf(current, brush_sdf) if add_matter else maxf(current, -brush_sdf)
				var falloff: float = _brush_falloff(distance, radius) * blend
				var next: float = lerpf(current, target, falloff)
				if absf(next - current) > 0.0001:
					voxel_buffer.set_voxel_f(_clamp_sdf_value(next), x, y, z, CHANNEL_SDF)
					changed += 1
	return changed


func _apply_sdf_flatten(local_center: Vector3, plane_normal: Vector3, radius: float, strength: float) -> int:
	return _apply_sdf_flatten_capsule(local_center, local_center, plane_normal, radius, strength)


func _apply_sdf_flatten_capsule(start: Vector3, end: Vector3, plane_normal: Vector3, radius: float, strength: float) -> int:
	var normal := plane_normal.normalized() if plane_normal.length_squared() > 0.0001 else Vector3.UP
	var changed := 0
	var blend := clampf(strength * 0.72, 0.0, 1.0)
	var min_point := Vector3(minf(start.x, end.x), minf(start.y, end.y), minf(start.z, end.z)) - Vector3.ONE * radius
	var max_point := Vector3(maxf(start.x, end.x), maxf(start.y, end.y), maxf(start.z, end.z)) + Vector3.ONE * radius
	var min_voxel := _local_to_voxel_index(min_point)
	var max_voxel := _local_to_voxel_index(max_point)
	for z in range(min_voxel.z, max_voxel.z + 1):
		for y in range(min_voxel.y, max_voxel.y + 1):
			for x in range(min_voxel.x, max_voxel.x + 1):
				var center := _voxel_center_local(x, y, z)
				var distance := _point_segment_distance(center, start, end)
				if distance > radius:
					continue
				var closest := _closest_point_on_segment(center, start, end)
				var plane_distance := (center - closest).dot(normal)
				if plane_distance <= -radius * 0.15:
					continue
				var current: float = float(voxel_buffer.get_voxel_f(x, y, z, CHANNEL_SDF))
				var plane_sdf: float = plane_distance / VOXEL_SCALE
				var target: float = maxf(current, plane_sdf)
				var falloff: float = _brush_falloff(distance, radius) * blend
				var next: float = lerpf(current, target, falloff)
				if absf(next - current) > 0.0001:
					voxel_buffer.set_voxel_f(_clamp_sdf_value(next), x, y, z, CHANNEL_SDF)
					changed += 1
	return changed


func _sdf_gradient_normal_local(local_position: Vector3) -> Vector3:
	var step := VOXEL_SCALE
	var dx := _sdf_value_nearest(local_position + Vector3(step, 0.0, 0.0)) - _sdf_value_nearest(local_position - Vector3(step, 0.0, 0.0))
	var dy := _sdf_value_nearest(local_position + Vector3(0.0, step, 0.0)) - _sdf_value_nearest(local_position - Vector3(0.0, step, 0.0))
	var dz := _sdf_value_nearest(local_position + Vector3(0.0, 0.0, step)) - _sdf_value_nearest(local_position - Vector3(0.0, 0.0, step))
	var normal := Vector3(dx, dy, dz)
	if normal.length_squared() > 0.0001:
		return normal.normalized()
	var bounds := get_solid_local_bounds()
	var fallback := local_position - bounds.get_center()
	return fallback.normalized() if fallback.length_squared() > 0.0001 else Vector3.UP


func _sdf_value_nearest(local_position: Vector3) -> float:
	var voxel := _local_to_voxel_index(local_position)
	return voxel_buffer.get_voxel_f(voxel.x, voxel.y, voxel.z, CHANNEL_SDF)


func _point_segment_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
	return point.distance_to(_closest_point_on_segment(point, a, b))


func _closest_point_on_segment(point: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq <= 0.000001:
		return a
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return a + ab * t


func _brush_falloff(distance: float, radius: float) -> float:
	var x := clampf(1.0 - distance / maxf(radius, 0.0001), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _count_voxels_in_sphere(local_center: Vector3, radius: float) -> int:
	var count := 0
	var min_voxel := _local_to_voxel_index(local_center - Vector3.ONE * radius)
	var max_voxel := _local_to_voxel_index(local_center + Vector3.ONE * radius)
	var radius_sq := radius * radius
	for z in range(min_voxel.z, max_voxel.z + 1):
		for y in range(min_voxel.y, max_voxel.y + 1):
			for x in range(min_voxel.x, max_voxel.x + 1):
				if _voxel_center_local(x, y, z).distance_squared_to(local_center) <= radius_sq:
					count += 1
	return count


func _count_voxels_in_capsule(start: Vector3, end: Vector3, radius: float) -> int:
	var count := 0
	var min_point := Vector3(minf(start.x, end.x), minf(start.y, end.y), minf(start.z, end.z)) - Vector3.ONE * radius
	var max_point := Vector3(maxf(start.x, end.x), maxf(start.y, end.y), maxf(start.z, end.z)) + Vector3.ONE * radius
	var min_voxel := _local_to_voxel_index(min_point)
	var max_voxel := _local_to_voxel_index(max_point)
	for z in range(min_voxel.z, max_voxel.z + 1):
		for y in range(min_voxel.y, max_voxel.y + 1):
			for x in range(min_voxel.x, max_voxel.x + 1):
				if _point_segment_distance(_voxel_center_local(x, y, z), start, end) <= radius:
					count += 1
	return count


func _apply_volume_feedback(tool_name: String, start: Vector3, end: Vector3, radius: float, strength: float, before_solid_count: int, surface_normal: Vector3) -> int:
	var brush_voxels := maxi(1, _count_voxels_in_capsule(start, end, radius))
	var deadband := maxi(3, int(round(float(brush_voxels) * VOLUME_FEEDBACK_DEADBAND_RATIO)))
	var after_solid_count := _count_solid_voxels()
	var delta := after_solid_count - before_solid_count
	var normal := surface_normal.normalized() if surface_normal.length_squared() > 0.0001 else _sdf_gradient_normal_local((start + end) * 0.5)
	var feedback_radius := clampf(radius * 0.58, MIN_SCULPT_RADIUS, MAX_SCULPT_RADIUS)
	var pressure := clampf(VOLUME_FEEDBACK_BASE_STRENGTH + absf(float(delta)) / float(brush_voxels), 0.12, 0.72) * clampf(strength, 0.0, 1.4)
	var back_start := _clamp_point_to_aabb(start - normal * radius * 0.55, get_edit_bounds())
	var back_end := _clamp_point_to_aabb(end - normal * radius * 0.55, get_edit_bounds())
	var front_start := _clamp_point_to_aabb(start + normal * radius * 0.24, get_edit_bounds())
	var front_end := _clamp_point_to_aabb(end + normal * radius * 0.24, get_edit_bounds())
	var changed := 0
	match tool_name:
		TOOL_SMOOTH, TOOL_FLATTEN, TOOL_GRAB, TOOL_PUSH_PULL:
			if delta <= deadband:
				changed += _apply_sdf_capsule_brush(back_start, back_end, feedback_radius, pressure * 0.42, true)
				changed += _apply_sdf_capsule_brush(front_start, front_end, feedback_radius * 0.72, pressure * 0.18, false)
			elif delta > deadband:
				changed += _apply_sdf_capsule_brush(front_start, front_end, feedback_radius * 0.76, pressure * 0.55, false)
			else:
				changed += _apply_sdf_capsule_brush(back_start, back_end, feedback_radius, pressure * 0.62, true)
		TOOL_STRETCH:
			if delta > deadband:
				changed += _apply_sdf_capsule_brush(start - normal * radius * 0.24, end - normal * radius * 0.24, feedback_radius * 0.72, pressure * 0.42, false)
			elif delta < -deadband:
				changed += _apply_sdf_capsule_brush(back_start, back_end, feedback_radius, pressure * 0.50, true)
		TOOL_ADD:
			if delta > deadband:
				changed += _apply_sdf_capsule_brush(start - normal * radius * 0.35, end - normal * radius * 0.35, feedback_radius * 0.68, pressure * 0.32, false)
		TOOL_REMOVE:
			if delta < -deadband:
				changed += _apply_sdf_capsule_brush(back_start, back_end, feedback_radius, pressure * 0.45, true)
	return changed


func _apply_smart_clay_stroke(start: Vector3, end: Vector3, radius: float, strength: float, surface_normal: Vector3) -> int:
	var normal := surface_normal.normalized() if surface_normal.length_squared() > 0.0001 else _sdf_gradient_normal_local(end)
	var push_start := _clamp_point_to_aabb(start + normal * radius * 0.16, get_edit_bounds())
	var push_end := _clamp_point_to_aabb(end + normal * radius * 0.16, get_edit_bounds())
	var changed := 0
	changed += _apply_sdf_capsule_brush(push_start, push_end, radius * 0.74, strength * 0.42, true)
	changed += _smooth_sdf_capsule(start, end, radius * 1.08, strength * 0.46)
	changed += _apply_sdf_flatten_capsule(start, end, normal, radius * 0.82, strength * 0.22)
	return changed


func _solid_stroke_summary(tool_name: String, requested_position: Vector3, local_position: Vector3, radius: float, changed: int) -> Dictionary:
	return {
		"tool": tool_name,
		"requested_tool": tool_name,
		"requested_local_position": requested_position,
		"local_position": local_position,
		"world_radius": radius,
		"radius": radius,
		"clamped": not requested_position.is_equal_approx(local_position),
		"anchor_integrity": get_anchor_integrity(),
		"solid_count": _solid_count,
		"changed_voxels": changed,
		"changed_vertices": changed,
	}


func _mark_edited_if_changed(changed: int) -> void:
	if changed > 0:
		_base_clone_clean = false


func _smooth_sdf_sphere(local_center: Vector3, radius: float, strength: float) -> void:
	_smooth_sdf_capsule(local_center, local_center, radius, strength)


func _smooth_sdf_capsule(start: Vector3, end: Vector3, radius: float, strength: float) -> int:
	var min_point := Vector3(minf(start.x, end.x), minf(start.y, end.y), minf(start.z, end.z)) - Vector3.ONE * (radius + VOXEL_SCALE)
	var max_point := Vector3(maxf(start.x, end.x), maxf(start.y, end.y), maxf(start.z, end.z)) + Vector3.ONE * (radius + VOXEL_SCALE)
	var min_voxel := _local_to_voxel_index(min_point)
	var max_voxel := _local_to_voxel_index(max_point)
	var before := {}
	for z in range(min_voxel.z, max_voxel.z + 1):
		for y in range(min_voxel.y, max_voxel.y + 1):
			for x in range(min_voxel.x, max_voxel.x + 1):
				before[_voxel_index(x, y, z)] = voxel_buffer.get_voxel_f(x, y, z, CHANNEL_SDF)
	var blend := clampf(strength * 0.45, 0.0, 0.85)
	var changed := 0
	for z in range(min_voxel.z, max_voxel.z + 1):
		for y in range(min_voxel.y, max_voxel.y + 1):
			for x in range(min_voxel.x, max_voxel.x + 1):
				var local_position := _voxel_center_local(x, y, z)
				if _point_segment_distance(local_position, start, end) > radius:
					continue
				var sum := 0.0
				var count := 0
				for nz in range(maxi(0, z - 1), mini(GRID_DEPTH, z + 2)):
					for ny in range(maxi(0, y - 1), mini(GRID_HEIGHT, y + 2)):
						for nx in range(maxi(0, x - 1), mini(GRID_WIDTH, x + 2)):
							var neighbor_index := _voxel_index(nx, ny, nz)
							sum += float(before.get(neighbor_index, voxel_buffer.get_voxel_f(nx, ny, nz, CHANNEL_SDF)))
							count += 1
				if count <= 0:
					continue
				var index := _voxel_index(x, y, z)
				var current := float(before.get(index, voxel_buffer.get_voxel_f(x, y, z, CHANNEL_SDF)))
				var average := sum / float(count)
				var next := lerpf(current, average, blend)
				if absf(next - current) > 0.0001:
					voxel_buffer.set_voxel_f(next, x, y, z, CHANNEL_SDF)
					changed += 1
	return changed


func _seal_small_holes_capsule(start: Vector3, end: Vector3, radius: float) -> int:
	var min_point := Vector3(minf(start.x, end.x), minf(start.y, end.y), minf(start.z, end.z)) - Vector3.ONE * (radius + VOXEL_SCALE)
	var max_point := Vector3(maxf(start.x, end.x), maxf(start.y, end.y), maxf(start.z, end.z)) + Vector3.ONE * (radius + VOXEL_SCALE)
	var min_voxel := _local_to_voxel_index(min_point)
	var max_voxel := _local_to_voxel_index(max_point)
	var fills: Array[Vector3i] = []
	for z in range(min_voxel.z, max_voxel.z + 1):
		for y in range(min_voxel.y, max_voxel.y + 1):
			for x in range(min_voxel.x, max_voxel.x + 1):
				var local_position := _voxel_center_local(x, y, z)
				if _point_segment_distance(local_position, start, end) > radius:
					continue
				if _is_solid(x, y, z):
					continue
				if _count_solid_neighbors(x, y, z) >= BEAUTIFY_FILL_SOLID_NEIGHBORS:
					fills.append(Vector3i(x, y, z))
	for voxel in fills:
		voxel_buffer.set_voxel_f(-0.08, voxel.x, voxel.y, voxel.z, CHANNEL_SDF)
	return fills.size()


func _remove_spike_voxels_capsule(start: Vector3, end: Vector3, radius: float) -> int:
	var min_point := Vector3(minf(start.x, end.x), minf(start.y, end.y), minf(start.z, end.z)) - Vector3.ONE * (radius + VOXEL_SCALE)
	var max_point := Vector3(maxf(start.x, end.x), maxf(start.y, end.y), maxf(start.z, end.z)) + Vector3.ONE * (radius + VOXEL_SCALE)
	var min_voxel := _local_to_voxel_index(min_point)
	var max_voxel := _local_to_voxel_index(max_point)
	var removals: Array[Vector3i] = []
	for z in range(min_voxel.z, max_voxel.z + 1):
		for y in range(min_voxel.y, max_voxel.y + 1):
			for x in range(min_voxel.x, max_voxel.x + 1):
				var local_position := _voxel_center_local(x, y, z)
				if _point_segment_distance(local_position, start, end) > radius:
					continue
				if not _is_solid(x, y, z):
					continue
				if _count_solid_neighbors(x, y, z) <= BEAUTIFY_SPIKE_SOLID_NEIGHBORS:
					removals.append(Vector3i(x, y, z))
	for voxel in removals:
		voxel_buffer.set_voxel_f(0.16, voxel.x, voxel.y, voxel.z, CHANNEL_SDF)
	return removals.size()


func _count_solid_neighbors(x: int, y: int, z: int) -> int:
	var count := 0
	for nz in range(maxi(0, z - 1), mini(GRID_DEPTH, z + 2)):
		for ny in range(maxi(0, y - 1), mini(GRID_HEIGHT, y + 2)):
			for nx in range(maxi(0, x - 1), mini(GRID_WIDTH, x + 2)):
				if nx == x and ny == y and nz == z:
					continue
				if _is_solid(nx, ny, nz):
					count += 1
	return count


func _initial_humanoid_sdf(p: Vector3) -> float:
	return _basic_human_sdf(p)


func _basic_human_sdf(p: Vector3) -> float:
	var sdf := INF
	sdf = _smooth_min(sdf, _sphere_sdf(p, Vector3(0.0, 1.50, 0.0), 0.30), 0.08)
	sdf = _smooth_min(sdf, _capsule_sdf(p, Vector3(0.0, 1.17, 0.0), Vector3(0.0, 1.31, 0.0), 0.12), 0.08)
	sdf = _smooth_min(sdf, _capsule_sdf(p, Vector3(-0.24, 1.07, 0.0), Vector3(0.24, 1.07, 0.0), 0.14), 0.08)
	sdf = _smooth_min(sdf, _capsule_sdf(p, Vector3(0.0, 0.58, 0.0), Vector3(0.0, 1.12, 0.0), 0.23), 0.12)
	sdf = _smooth_min(sdf, _capsule_sdf(p, Vector3(-0.18, 0.58, 0.0), Vector3(0.18, 0.58, 0.0), 0.16), 0.09)
	for side in [-1.0, 1.0]:
		var shoulder := Vector3(side * 0.31, 1.03, 0.0)
		var elbow := Vector3(side * 0.35, 0.75, 0.02)
		var wrist := Vector3(side * 0.30, 0.48, -0.01)
		sdf = _smooth_min(sdf, _capsule_sdf(p, shoulder, elbow, 0.086), 0.06)
		sdf = _smooth_min(sdf, _capsule_sdf(p, elbow, wrist, 0.088), 0.06)
		sdf = _smooth_min(sdf, _sphere_sdf(p, Vector3(side * 0.30, 0.42, -0.01), 0.092), 0.045)
		var hip := Vector3(side * 0.12, 0.52, 0.0)
		var knee := Vector3(side * 0.16, 0.29, 0.01)
		var ankle := Vector3(side * 0.20, 0.08, -0.01)
		sdf = _smooth_min(sdf, _capsule_sdf(p, hip, knee, 0.108), 0.065)
		sdf = _smooth_min(sdf, _capsule_sdf(p, knee, ankle, 0.098), 0.058)
		sdf = _smooth_min(sdf, _capsule_sdf(p, Vector3(side * 0.20, 0.04, -0.11), Vector3(side * 0.23, 0.04, 0.11), 0.062), 0.045)
	return sdf


func _anchor_sdf(p: Vector3) -> float:
	var sdf := INF
	sdf = minf(sdf, _sphere_sdf(p, Vector3(0.0, 1.49, 0.0), 0.16))
	sdf = minf(sdf, _capsule_sdf(p, Vector3(0.0, 0.62, 0.0), Vector3(0.0, 1.18, 0.0), 0.16))
	sdf = minf(sdf, _sphere_sdf(p, Vector3(-0.31, 0.68, 0.0), 0.07))
	sdf = minf(sdf, _sphere_sdf(p, Vector3(0.31, 0.68, 0.0), 0.07))
	sdf = minf(sdf, _sphere_sdf(p, Vector3(-0.20, 0.18, 0.0), 0.08))
	sdf = minf(sdf, _sphere_sdf(p, Vector3(0.20, 0.18, 0.0), 0.08))
	return sdf


func _anchor_samples() -> Array:
	return [
		{"name": "head", "position": Vector3(0.0, 1.49, 0.0)},
		{"name": "torso", "position": Vector3(0.0, 0.86, 0.0)},
		{"name": "neck_bridge", "position": Vector3(0.0, 1.24, 0.0)},
		{"name": "left_arm", "position": Vector3(-0.31, 0.68, 0.0)},
		{"name": "right_arm", "position": Vector3(0.31, 0.68, 0.0)},
		{"name": "left_leg", "position": Vector3(-0.20, 0.18, 0.0)},
		{"name": "right_leg", "position": Vector3(0.20, 0.18, 0.0)},
	]


func _basic_human_color(local_position: Vector3) -> Color:
	var vertical_shade := clampf(inverse_lerp(0.0, 1.8, local_position.y), 0.0, 1.0)
	return BASIC_HUMAN_COLOR.lerp(Color(0.82, 0.78, 1.0, 1.0), vertical_shade * 0.18)


func _sphere_sdf(p: Vector3, center: Vector3, radius: float) -> float:
	return p.distance_to(center) - radius


func _ellipsoid_sdf(p: Vector3, center: Vector3, radius: Vector3) -> float:
	var delta := p - center
	var q := Vector3(delta.x / radius.x, delta.y / radius.y, delta.z / radius.z)
	var q2 := Vector3(delta.x / (radius.x * radius.x), delta.y / (radius.y * radius.y), delta.z / (radius.z * radius.z))
	return q.length() * (q.length() - 1.0) / maxf(q2.length(), 0.0001)


func _capsule_sdf(p: Vector3, a: Vector3, b: Vector3, radius: float) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / maxf(ba.dot(ba), 0.0001), 0.0, 1.0)
	return (pa - ba * h).length() - radius


func _smooth_min(a: float, b: float, k: float) -> float:
	if a >= INF * 0.5:
		return b
	var h := clampf(0.5 + 0.5 * (b - a) / maxf(k, 0.0001), 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


func _encode_int_rle(values: Array) -> Array:
	var encoded := []
	if values.is_empty():
		return encoded
	var current := int(values[0])
	var count := 1
	for i in range(1, values.size()):
		var value := int(values[i])
		if value == current and count < 65535:
			count += 1
			continue
		encoded.append([current, count])
		current = value
		count = 1
	encoded.append([current, count])
	return encoded


func _decode_int_rle(encoded: Variant) -> Array:
	var values := []
	if not encoded is Array:
		return values
	for pair in encoded:
		if not pair is Array or pair.size() < 2:
			continue
		var value := int(pair[0])
		var count := maxi(0, int(pair[1]))
		for i in range(count):
			values.append(value)
	return values


func _compact_body_checksum(sdf_q: Array, color_indices: Array) -> int:
	var checksum := 29
	for i in range(sdf_q.size()):
		checksum = int((checksum * 131 + int(sdf_q[i]) + i * 17) & 0x7fffffff)
	for i in range(color_indices.size()):
		checksum = int((checksum * 131 + int(color_indices[i]) + i * 31) & 0x7fffffff)
	return checksum


func _color_to_html(color: Color) -> String:
	var clean := color
	clean.a = 1.0
	return clean.to_html(false)
