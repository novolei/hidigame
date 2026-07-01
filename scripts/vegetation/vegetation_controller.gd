class_name VegetationController
extends Node3D

const GENERATED_ROOT_NAME := "GeneratedVegetation"
const GRASS_SHADER_PATH := "res://shaders/vegetation/stylized_grass.gdshader"
const FLOWER_SHADER_PATH := "res://shaders/vegetation/stylized_flower.gdshader"
const TREE_SHADER_PATH := "res://shaders/vegetation/stylized_tree_wind.gdshader"
const POLYGON_ROOT_NAME := "GeneratedPolygonApocalypseMap"
const POLYGON_SUPPORT_NAME := "PolygonApocalypseGameplaySupport"
const POLYGON_SUPPORT_SHAPE_NAME := "GameplaySupportShape"
const MAP_SUPPORT_BODY_NAME := "MapGameplaySupport"
const MAP_SUPPORT_GROUP_NAME := "map_gameplay_support"
const WALKABLE_COLLISION_GROUP_NAME := "polygon_apocalypse_walkable_collision"
const WORLD_COLLISION_LAYER: int = 2
const GROUND_RAY_UP: float = 90.0
const GROUND_RAY_DOWN: float = 180.0
const WALKABLE_NORMAL_MIN_Y: float = 0.42

signal build_finished(total_instances: int)

@export var enabled: bool = true
@export var profile: VegetationProfile
@export_range(1, 120, 1) var install_wait_frames: int = 12

@export_group("Build Budget")
@export var async_build_enabled: bool = true
@export_range(64, 4096, 64) var projection_batch_size: int = 768
@export_range(1, 64, 1) var chunk_builds_per_frame: int = 6

var build_started: bool = false
var build_complete: bool = false
var is_building: bool = false
var generated_instance_count: int = 0

var _active_profile: VegetationProfile
var _support_center: Vector3 = Vector3.ZERO
var _support_size: Vector2 = Vector2(230.0, 220.0)
var _support_top_y: float = -8.0
var _support_body: StaticBody3D
var _requires_walkable_ground: bool = false
var _generated_root: Node3D
var _grass_material: ShaderMaterial
var _flower_material: ShaderMaterial
var _tree_material: ShaderMaterial


func _ready() -> void:
	if not enabled:
		return
	call_deferred("_install_when_ready")


func _process(_delta: float) -> void:
	var now_seconds: float = float(Time.get_ticks_msec()) * 0.001
	if _grass_material != null:
		_grass_material.set_shader_parameter("veg_time", now_seconds)
	if _flower_material != null:
		_flower_material.set_shader_parameter("veg_time", now_seconds)
	if _tree_material != null:
		_tree_material.set_shader_parameter("veg_time", now_seconds)


func rebuild() -> void:
	_clear_generated()
	build_started = false
	build_complete = false
	is_building = false
	call_deferred("_install_when_ready")


func _install_when_ready() -> void:
	build_started = true
	build_complete = false
	is_building = true
	generated_instance_count = 0
	_active_profile = _resolve_profile()
	if _active_profile == null:
		_mark_build_complete()
		return

	_support_body = null
	_requires_walkable_ground = false
	var found_support: bool = false
	for _frame in install_wait_frames:
		found_support = _resolve_polygon_support()
		if found_support:
			break
		await get_tree().process_frame

	if not found_support:
		_support_center = _active_profile.fallback_support_center
		_support_size = _active_profile.fallback_support_size
		_support_top_y = _active_profile.fallback_support_top_y

	_requires_walkable_ground = _has_walkable_ground_collisions()
	await get_tree().physics_frame
	await _build_generated_content()


func wait_until_build_complete(max_seconds: float = 8.0) -> bool:
	var deadline_msec: int = Time.get_ticks_msec() + roundi(max_seconds * 1000.0)
	while is_inside_tree() and not build_complete and Time.get_ticks_msec() < deadline_msec:
		await get_tree().process_frame
	return build_complete


func _mark_build_complete() -> void:
	is_building = false
	build_complete = true
	build_finished.emit(generated_instance_count)


func _should_yield_build() -> bool:
	return async_build_enabled and is_inside_tree() and not RuntimeMode.is_headless()


func _yield_build_frame() -> void:
	if _should_yield_build():
		await get_tree().process_frame


func _resolve_profile() -> VegetationProfile:
	if profile != null:
		return profile
	var parent_node: Node = get_parent()
	var map_id: String = "city_urp"
	var sector_id: String = "warehouse_ward"
	if parent_node != null:
		var map_value: Variant = parent_node.get("map_id")
		var sector_value: Variant = parent_node.get("sector_id")
		if map_value != null and not str(map_value).is_empty():
			map_id = str(map_value)
		if sector_value != null and not str(sector_value).is_empty():
			sector_id = str(sector_value)
	return VegetationProfile.for_polygon_warehouse(map_id, sector_id)


func _resolve_polygon_support() -> bool:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return false
	var generated_map: Node = parent_node.get_node_or_null(POLYGON_ROOT_NAME)
	if generated_map != null:
		var polygon_support := generated_map.get_node_or_null(POLYGON_SUPPORT_NAME) as StaticBody3D
		if _configure_support_from_body(polygon_support):
			return true
	var map_support := parent_node.find_child(String(MAP_SUPPORT_BODY_NAME), true, false) as StaticBody3D
	return _configure_support_from_body(map_support)


func _configure_support_from_body(support: StaticBody3D) -> bool:
	if support == null:
		return false
	var shape_node := support.get_node_or_null(POLYGON_SUPPORT_SHAPE_NAME) as CollisionShape3D
	if shape_node == null or not shape_node.shape is BoxShape3D:
		return false
	var shape := shape_node.shape as BoxShape3D
	_support_body = support
	_support_center = Vector3(support.global_position.x, 0.0, support.global_position.z)
	_support_size = support.get_meta("support_size_xz", Vector2(shape.size.x, shape.size.z))
	_support_top_y = float(support.get_meta("support_top_y", support.global_position.y + shape.size.y * 0.5))
	return true


func _build_generated_content() -> void:
	_clear_generated()
	generated_instance_count = 0
	var build_visuals: bool = _should_build_visuals()
	var needs_collision: bool = _active_profile.enable_trees and _active_profile.tree_collision_enabled
	if not build_visuals and not needs_collision:
		set_process(false)
		_mark_build_complete()
		return

	_generated_root = Node3D.new()
	_generated_root.name = GENERATED_ROOT_NAME
	add_child(_generated_root)

	if _active_profile.use_prebaked_vegetation:
		var prebaked_loaded: bool = await _build_prebaked_content(build_visuals)
		if prebaked_loaded:
			set_process(_grass_material != null or _flower_material != null or _tree_material != null)
			_mark_build_complete()
			return

	var grass_placements: Array[Dictionary] = []
	if _active_profile.enable_grass and build_visuals:
		if _should_yield_build():
			grass_placements = await VegetationPlanner.generate_grass_budgeted(_active_profile, _support_center, _support_size, _support_top_y, self, projection_batch_size)
		else:
			grass_placements = VegetationPlanner.generate_grass(_active_profile, _support_center, _support_size, _support_top_y)
		await _yield_build_frame()
		grass_placements = await _project_placements_to_ground_budgeted(grass_placements, 0.035)
		await _build_grass(grass_placements)
		generated_instance_count += grass_placements.size()

	var flower_placements: Array[Dictionary] = []
	if _active_profile.enable_flowers and build_visuals:
		flower_placements = VegetationPlanner.generate_flowers(_active_profile, _support_center, _support_size, _support_top_y)
		await _yield_build_frame()
		flower_placements = await _project_placements_to_ground_budgeted(flower_placements, 0.045)
		await _build_flowers(flower_placements)
		generated_instance_count += flower_placements.size()

	var tree_placements: Array[Dictionary] = []
	if _active_profile.enable_trees:
		tree_placements = VegetationPlanner.generate_trees(_active_profile, _support_center, _support_size, _support_top_y)
		await _yield_build_frame()
		tree_placements = await _project_placements_to_ground_budgeted(tree_placements, 0.0)
		if build_visuals:
			await _build_tree_visuals(tree_placements)
		if _active_profile.tree_collision_enabled:
			_build_tree_collisions(tree_placements)
		generated_instance_count += tree_placements.size()

	set_process(_grass_material != null or _flower_material != null or _tree_material != null)
	_mark_build_complete()


func _build_prebaked_content(build_visuals: bool) -> bool:
	var bake_data: VegetationBakeData = _load_prebaked_data()
	if bake_data == null:
		return false
	var loaded_count: int = 0

	if build_visuals and _active_profile.enable_grass and not bake_data.grass_chunks.is_empty():
		_grass_material = _create_grass_material(_active_profile)
		if _grass_material != null:
			var grass_root := Node3D.new()
			grass_root.name = "Grass"
			_generated_root.add_child(grass_root)
			loaded_count += await _build_prebaked_multimesh_chunks(grass_root, bake_data.grass_chunks, _grass_material, "GrassChunk")
			var grass_sampler := VegetationTouchSampler.new()
			grass_sampler.name = "GrassTouchSampler"
			_generated_root.add_child(grass_sampler)
			grass_sampler.configure(_grass_material, _active_profile)

	if build_visuals and _active_profile.enable_flowers and not bake_data.flower_chunks.is_empty():
		_flower_material = _create_flower_material(_active_profile)
		if _flower_material != null:
			var flower_root := Node3D.new()
			flower_root.name = "WildFlowers"
			_generated_root.add_child(flower_root)
			loaded_count += await _build_prebaked_multimesh_chunks(flower_root, bake_data.flower_chunks, _flower_material, "FlowerChunk")
			var flower_sampler := VegetationTouchSampler.new()
			flower_sampler.name = "FlowerTouchSampler"
			_generated_root.add_child(flower_sampler)
			flower_sampler.configure(_flower_material, _active_profile)

	if _active_profile.enable_trees and not bake_data.tree_placements.is_empty():
		if build_visuals:
			await _build_tree_visuals(bake_data.tree_placements)
		if _active_profile.tree_collision_enabled:
			_build_tree_collisions(bake_data.tree_placements)
		loaded_count += bake_data.tree_placements.size()

	generated_instance_count = loaded_count
	return loaded_count > 0


func _load_prebaked_data() -> VegetationBakeData:
	if _active_profile == null or _active_profile.prebaked_vegetation_path.is_empty():
		return null
	if not ResourceLoader.exists(_active_profile.prebaked_vegetation_path):
		push_warning("Vegetation bake is missing: " + _active_profile.prebaked_vegetation_path)
		return null
	var resource: Resource = load(_active_profile.prebaked_vegetation_path) as Resource
	var bake_data := resource as VegetationBakeData
	if bake_data == null:
		push_warning("Vegetation bake has unexpected resource type: " + _active_profile.prebaked_vegetation_path)
		return null
	if not bake_data.can_use_for(_active_profile.profile_id):
		push_warning("Vegetation bake profile mismatch: " + _active_profile.prebaked_vegetation_path)
		return null
	return bake_data


func _build_prebaked_multimesh_chunks(parent: Node3D, chunks: Array[Dictionary], material: ShaderMaterial, chunk_prefix: String) -> int:
	var loaded_count: int = 0
	var chunks_built_this_frame: int = 0
	for chunk in chunks:
		var multimesh_path: String = str(chunk.get("multimesh_path", ""))
		if multimesh_path.is_empty() or not ResourceLoader.exists(multimesh_path):
			continue
		var multimesh := load(multimesh_path) as MultiMesh
		if multimesh == null:
			continue
		var chunk_key: String = str(chunk.get("key", "%03d" % loaded_count))
		var instance := MultiMeshInstance3D.new()
		instance.name = "%s_%s" % [chunk_prefix, chunk_key.replace(":", "_")]
		instance.position = chunk.get("origin", Vector3.ZERO)
		instance.multimesh = multimesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		parent.add_child(instance)
		loaded_count += int(chunk.get("instance_count", multimesh.instance_count))
		chunks_built_this_frame += 1
		if _should_yield_build() and chunks_built_this_frame >= chunk_builds_per_frame:
			chunks_built_this_frame = 0
			await get_tree().process_frame
	return loaded_count


func _should_build_visuals() -> bool:
	if _active_profile == null:
		return false
	if RuntimeMode.is_headless() and not _active_profile.build_visuals_in_headless:
		return false
	return true


func _project_placements_to_ground(placements: Array[Dictionary], surface_offset: float) -> Array[Dictionary]:
	if placements.is_empty():
		return placements
	if not is_inside_tree() or get_world_3d() == null:
		return placements

	var projected: Array[Dictionary] = []
	var keep_unresolved: bool = _support_body == null
	for raw_item in placements:
		var item: Dictionary = raw_item.duplicate(true)
		var item_position: Vector3 = item.get("position", Vector3.ZERO)
		var ground_hit: Dictionary = _sample_ground_hit(item_position)
		if ground_hit.is_empty():
			if keep_unresolved:
				projected.append(item)
			continue
		var hit_position: Vector3 = ground_hit.get("position", item_position)
		item_position.y = hit_position.y + surface_offset
		item["position"] = item_position
		projected.append(item)
	return projected


func _project_placements_to_ground_budgeted(placements: Array[Dictionary], surface_offset: float) -> Array[Dictionary]:
	if placements.is_empty():
		return placements
	if not _should_yield_build():
		return _project_placements_to_ground(placements, surface_offset)
	if not is_inside_tree() or get_world_3d() == null:
		return placements

	var projected: Array[Dictionary] = []
	var keep_unresolved: bool = _support_body == null
	var processed_since_yield: int = 0
	var batch_size: int = maxi(projection_batch_size, 1)
	for raw_item in placements:
		var item: Dictionary = raw_item.duplicate(true)
		var item_position: Vector3 = item.get("position", Vector3.ZERO)
		var ground_hit: Dictionary = _sample_ground_hit(item_position)
		if ground_hit.is_empty():
			if keep_unresolved:
				projected.append(item)
		else:
			var hit_position: Vector3 = ground_hit.get("position", item_position)
			item_position.y = hit_position.y + surface_offset
			item["position"] = item_position
			projected.append(item)
		processed_since_yield += 1
		if processed_since_yield >= batch_size:
			processed_since_yield = 0
			await get_tree().process_frame
	return projected


func _sample_ground_hit(sample_position: Vector3) -> Dictionary:
	var from: Vector3 = Vector3(sample_position.x, sample_position.y + GROUND_RAY_UP, sample_position.z)
	var to: Vector3 = Vector3(sample_position.x, sample_position.y - GROUND_RAY_DOWN, sample_position.z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WORLD_COLLISION_LAYER)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if _support_body != null and is_instance_valid(_support_body):
		query.exclude = [_support_body.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider: Object = hit.get("collider", null) as Object
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	if not _accept_ground_hit(collider, normal):
		return {}
	return hit


func _accept_ground_hit(collider: Object, normal: Vector3) -> bool:
	if normal.y < WALKABLE_NORMAL_MIN_Y:
		return false
	if collider is Node:
		var node := collider as Node
		if _is_support_collider(node):
			return false
		if _requires_walkable_ground and not node.is_in_group(WALKABLE_COLLISION_GROUP_NAME):
			return false
	return true


func _is_support_collider(node: Node) -> bool:
	if _support_body != null and is_instance_valid(_support_body) and node == _support_body:
		return true
	return node.name == POLYGON_SUPPORT_NAME or node.name == MAP_SUPPORT_BODY_NAME or node.is_in_group(MAP_SUPPORT_GROUP_NAME)


func _has_walkable_ground_collisions() -> bool:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return false
	var bodies: Array[Node] = parent_node.find_children("*", "StaticBody3D", true, false)
	for body in bodies:
		if body.is_in_group(WALKABLE_COLLISION_GROUP_NAME):
			return true
	return false


func _clear_generated() -> void:
	for child in get_children():
		if child.name == GENERATED_ROOT_NAME:
			remove_child(child)
			child.free()
	_generated_root = null
	_grass_material = null
	_flower_material = null
	_tree_material = null


func _build_grass(placements: Array[Dictionary]) -> void:
	if placements.is_empty() or _generated_root == null:
		return
	_grass_material = _create_grass_material(_active_profile)
	if _grass_material == null:
		return
	var grass_root := Node3D.new()
	grass_root.name = "Grass"
	_generated_root.add_child(grass_root)
	var grass_mesh: ArrayMesh = _create_grass_cluster_mesh()
	var chunk_map: Dictionary = _group_grass_by_chunk(placements, _active_profile.grass_chunk_size)
	var chunks_built_this_frame: int = 0
	for key in chunk_map.keys():
		var chunk_items: Array = chunk_map[key]
		_build_grass_chunk(grass_root, grass_mesh, str(key), chunk_items)
		chunks_built_this_frame += 1
		if _should_yield_build() and chunks_built_this_frame >= chunk_builds_per_frame:
			chunks_built_this_frame = 0
			await get_tree().process_frame
	var sampler := VegetationTouchSampler.new()
	sampler.name = "GrassTouchSampler"
	_generated_root.add_child(sampler)
	sampler.configure(_grass_material, _active_profile)


func _group_grass_by_chunk(placements: Array[Dictionary], chunk_size: float) -> Dictionary:
	var chunk_map: Dictionary = {}
	var safe_chunk_size: float = maxf(chunk_size, 1.0)
	for item in placements:
		var item_position: Vector3 = item.get("position", Vector3.ZERO)
		var chunk_x: int = int(floor(item_position.x / safe_chunk_size))
		var chunk_z: int = int(floor(item_position.z / safe_chunk_size))
		var key: String = "%d:%d" % [chunk_x, chunk_z]
		var bucket: Array = chunk_map.get(key, [])
		bucket.append(item)
		chunk_map[key] = bucket
	return chunk_map


func _build_grass_chunk(parent: Node3D, grass_mesh: ArrayMesh, key: String, chunk_items: Array) -> void:
	if chunk_items.is_empty():
		return
	var chunk_size: float = maxf(_active_profile.grass_chunk_size, 1.0)
	var parts: PackedStringArray = key.split(":")
	var chunk_x: int = int(parts[0])
	var chunk_z: int = int(parts[1])
	var chunk_origin := Vector3((float(chunk_x) + 0.5) * chunk_size, 0.0, (float(chunk_z) + 0.5) * chunk_size)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = grass_mesh
	multimesh.instance_count = chunk_items.size()
	multimesh.visible_instance_count = chunk_items.size()
	multimesh.custom_aabb = AABB(Vector3(-chunk_size * 0.7, -0.5, -chunk_size * 0.7), Vector3(chunk_size * 1.4, _active_profile.grass_max_height * 2.4 + 1.0, chunk_size * 1.4))

	for index in chunk_items.size():
		var item: Dictionary = chunk_items[index]
		var item_position: Vector3 = item.get("position", Vector3.ZERO)
		var yaw: float = float(item.get("yaw", 0.0))
		var item_scale: Vector3 = item.get("scale", Vector3.ONE)
		var instance_transform := Transform3D(_basis_from_yaw_scale(yaw, item_scale), item_position - chunk_origin)
		multimesh.set_instance_transform(index, instance_transform)
		multimesh.set_instance_color(index, Color.WHITE)
		multimesh.set_instance_custom_data(index, Color(float(item.get("stiffness", 1.0)), float(item.get("phase", 0.0)), float(item.get("color_bias", 0.0)), 1.0))

	var instance := MultiMeshInstance3D.new()
	instance.name = "GrassChunk_%s" % key.replace(":", "_")
	instance.position = chunk_origin
	instance.multimesh = multimesh
	instance.material_override = _grass_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)


func _create_grass_cluster_mesh() -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade_count: int = 2
	var golden_angle: float = 2.3999632
	for blade_index in blade_count:
		var angle: float = fmod(float(blade_index) * golden_angle + 0.17 * float(blade_index % 3), TAU)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var right := Vector3(-direction.z, 0.0, direction.x)
		var ring_value: float = float((blade_index * 5) % 7) / 6.0
		var center := direction * (0.03 + ring_value * 0.09) + right * (0.012 * float((blade_index % 3) - 1))
		var blade_height: float = 0.86 + 0.045 * float((blade_index * 3) % 5)
		var base_width: float = 0.042 + 0.010 * float((blade_index + 1) % 3)
		var lower_width: float = base_width * 0.76
		var upper_width: float = base_width * 0.38
		var lean: Vector3 = direction * (0.035 + ring_value * 0.064)
		var bend_side: Vector3 = right * (0.013 * float((blade_index % 5) - 2))
		var base_left: Vector3 = center - right * base_width
		var base_right: Vector3 = center + right * base_width
		var lower_center: Vector3 = center + lean * 0.20 + bend_side * 0.28 + Vector3.UP * blade_height * 0.34
		var upper_center: Vector3 = center + lean * 0.58 + bend_side * 0.90 + Vector3.UP * blade_height * 0.68
		var lower_left: Vector3 = lower_center - right * lower_width
		var lower_right: Vector3 = lower_center + right * lower_width
		var upper_left: Vector3 = upper_center - right * upper_width
		var upper_right: Vector3 = upper_center + right * upper_width
		var tip: Vector3 = center + lean + bend_side * 1.75 + Vector3.UP * blade_height
		_add_grass_vertex(surface_tool, base_left, Vector2(0.0, 0.0), Color(0.0, 0.0, 0.0, 1.0))
		_add_grass_vertex(surface_tool, lower_left, Vector2(0.12, 0.34), Color(0.32, 0.32, 0.32, 1.0))
		_add_grass_vertex(surface_tool, base_right, Vector2(1.0, 0.0), Color(0.0, 0.0, 0.0, 1.0))
		_add_grass_vertex(surface_tool, base_right, Vector2(1.0, 0.0), Color(0.0, 0.0, 0.0, 1.0))
		_add_grass_vertex(surface_tool, lower_left, Vector2(0.12, 0.34), Color(0.32, 0.32, 0.32, 1.0))
		_add_grass_vertex(surface_tool, lower_right, Vector2(0.88, 0.34), Color(0.32, 0.32, 0.32, 1.0))
		_add_grass_vertex(surface_tool, lower_left, Vector2(0.12, 0.34), Color(0.32, 0.32, 0.32, 1.0))
		_add_grass_vertex(surface_tool, upper_left, Vector2(0.28, 0.68), Color(0.68, 0.68, 0.68, 1.0))
		_add_grass_vertex(surface_tool, lower_right, Vector2(0.88, 0.34), Color(0.32, 0.32, 0.32, 1.0))
		_add_grass_vertex(surface_tool, lower_right, Vector2(0.88, 0.34), Color(0.32, 0.32, 0.32, 1.0))
		_add_grass_vertex(surface_tool, upper_left, Vector2(0.28, 0.68), Color(0.68, 0.68, 0.68, 1.0))
		_add_grass_vertex(surface_tool, upper_right, Vector2(0.72, 0.68), Color(0.68, 0.68, 0.68, 1.0))
		_add_grass_vertex(surface_tool, upper_left, Vector2(0.28, 0.68), Color(0.68, 0.68, 0.68, 1.0))
		_add_grass_vertex(surface_tool, tip, Vector2(0.5, 1.0), Color(1.0, 1.0, 1.0, 1.0))
		_add_grass_vertex(surface_tool, upper_right, Vector2(0.72, 0.68), Color(0.68, 0.68, 0.68, 1.0))
	surface_tool.generate_normals()
	var mesh: ArrayMesh = surface_tool.commit()
	mesh.custom_aabb = AABB(Vector3(-0.24, -0.08, -0.24), Vector3(0.48, 1.32, 0.48))
	return mesh


func _add_grass_vertex(surface_tool: SurfaceTool, vertex: Vector3, uv: Vector2, color: Color) -> void:
	surface_tool.set_color(color)
	surface_tool.set_uv(uv)
	surface_tool.add_vertex(vertex)


func _create_grass_material(active_profile: VegetationProfile) -> ShaderMaterial:
	var shader := load(GRASS_SHADER_PATH) as Shader
	if shader == null:
		push_warning("Vegetation grass shader is missing: " + GRASS_SHADER_PATH)
		return null
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_color", active_profile.grass_base_color)
	material.set_shader_parameter("tip_color", active_profile.grass_tip_color)
	material.set_shader_parameter("shadow_color", active_profile.grass_shadow_color)
	material.set_shader_parameter("wind_direction", active_profile.wind_direction.normalized())
	material.set_shader_parameter("wind_strength", active_profile.grass_wind_strength)
	material.set_shader_parameter("wind_speed", active_profile.wind_speed)
	material.set_shader_parameter("wind_noise_scale", active_profile.wind_noise_scale)
	material.set_shader_parameter("gust_strength", active_profile.gust_strength)
	material.set_shader_parameter("touch_push_strength", active_profile.touch_push_strength)
	material.set_shader_parameter("touch_crush_strength", active_profile.touch_crush_strength)
	material.set_shader_parameter("touch_recovery", active_profile.touch_recovery_speed)
	return material


func _build_flowers(placements: Array[Dictionary]) -> void:
	if placements.is_empty() or _generated_root == null:
		return
	_flower_material = _create_flower_material(_active_profile)
	if _flower_material == null:
		return
	var flower_root := Node3D.new()
	flower_root.name = "WildFlowers"
	_generated_root.add_child(flower_root)
	var flower_mesh: ArrayMesh = _create_flower_cluster_mesh(_active_profile)
	var chunk_map: Dictionary = _group_grass_by_chunk(placements, _active_profile.flower_chunk_size)
	var chunks_built_this_frame: int = 0
	for key in chunk_map.keys():
		var chunk_items: Array = chunk_map[key]
		_build_flower_chunk(flower_root, flower_mesh, str(key), chunk_items)
		chunks_built_this_frame += 1
		if _should_yield_build() and chunks_built_this_frame >= chunk_builds_per_frame:
			chunks_built_this_frame = 0
			await get_tree().process_frame
	var sampler := VegetationTouchSampler.new()
	sampler.name = "FlowerTouchSampler"
	_generated_root.add_child(sampler)
	sampler.configure(_flower_material, _active_profile)


func _build_flower_chunk(parent: Node3D, flower_mesh: ArrayMesh, key: String, chunk_items: Array) -> void:
	if chunk_items.is_empty():
		return
	var chunk_size: float = maxf(_active_profile.flower_chunk_size, 1.0)
	var parts: PackedStringArray = key.split(":")
	var chunk_x: int = int(parts[0])
	var chunk_z: int = int(parts[1])
	var chunk_origin := Vector3((float(chunk_x) + 0.5) * chunk_size, 0.0, (float(chunk_z) + 0.5) * chunk_size)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = flower_mesh
	multimesh.instance_count = chunk_items.size()
	multimesh.visible_instance_count = chunk_items.size()
	multimesh.custom_aabb = AABB(Vector3(-chunk_size * 0.7, -0.5, -chunk_size * 0.7), Vector3(chunk_size * 1.4, _active_profile.flower_max_height * 2.6 + 1.0, chunk_size * 1.4))

	for index in chunk_items.size():
		var item: Dictionary = chunk_items[index]
		var item_position: Vector3 = item.get("position", Vector3.ZERO)
		var yaw: float = float(item.get("yaw", 0.0))
		var item_scale: Vector3 = item.get("scale", Vector3.ONE)
		var instance_transform := Transform3D(_basis_from_yaw_scale(yaw, item_scale), item_position - chunk_origin)
		multimesh.set_instance_transform(index, instance_transform)
		multimesh.set_instance_color(index, Color.WHITE)
		multimesh.set_instance_custom_data(index, Color(float(item.get("stiffness", 0.42)), float(item.get("phase", 0.0)), float(item.get("color_bias", 0.0)), float(item.get("palette", 0.0))))

	var instance := MultiMeshInstance3D.new()
	instance.name = "FlowerChunk_%s" % key.replace(":", "_")
	instance.position = chunk_origin
	instance.multimesh = multimesh
	instance.material_override = _flower_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)


func _create_flower_cluster_mesh(active_profile: VegetationProfile = null) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flower_count: int = 6
	var shape_variety: float = 1.0
	if active_profile != null:
		flower_count = clampi(active_profile.flower_heads_per_instance, 3, 10)
		shape_variety = clampf(active_profile.flower_shape_variety, 0.0, 1.0)
	var golden_angle: float = 2.3999632
	for flower_index in flower_count:
		var shape_variant: int = 0
		if shape_variety > 0.05:
			shape_variant = (flower_index * 3 + 1) % 5
		var variant_tint: float = float(shape_variant) / 4.0
		var angle: float = fmod(float(flower_index) * golden_angle + 0.31, TAU)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var right := Vector3(-direction.z, 0.0, direction.x)
		var cluster_ring: float = float((flower_index * 7) % 9) / 8.0
		var base_center := direction * (0.04 + cluster_ring * 0.17) + right * (0.03 * float((flower_index % 3) - 1))
		var stem_height: float = 0.68 + 0.08 * float((flower_index * 5) % 4)
		var stem_width: float = 0.014 + 0.004 * float((flower_index + 1) % 3)
		var petal_segments: int = 6
		var petal_radius: float = 0.135 + 0.018 * float(flower_index % 3)
		var center_radius_factor: float = 0.26
		var petal_lift: float = 0.018
		var petal_stretch: float = 1.0
		match shape_variant:
			0:
				petal_segments = 7
				petal_radius *= 0.94
				center_radius_factor = 0.24
			1:
				petal_segments = 5
				petal_radius *= 1.16
				center_radius_factor = 0.22
				stem_height *= 0.94
			2:
				petal_segments = 4
				petal_radius *= 0.88
				center_radius_factor = 0.20
				stem_height *= 0.88
			3:
				petal_segments = 3
				petal_radius *= 1.08
				center_radius_factor = 0.18
				petal_lift = 0.006
				petal_stretch = 1.36
				stem_height *= 1.12
			4:
				petal_segments = 8
				petal_radius *= 0.78
				center_radius_factor = 0.34
				stem_width *= 0.88
		var lean := direction * (0.045 + cluster_ring * 0.045) + right * (0.012 * float((flower_index % 5) - 2))
		var top_center := base_center + Vector3.UP * stem_height + lean
		var base_left: Vector3 = base_center - right * stem_width
		var base_right: Vector3 = base_center + right * stem_width
		var top_left: Vector3 = top_center - right * (stem_width * 0.58)
		var top_right: Vector3 = top_center + right * (stem_width * 0.58)
		_add_flower_vertex(surface_tool, base_left, Vector2(0.0, 0.0), Color(0.0, 0.0, 0.0, 1.0))
		_add_flower_vertex(surface_tool, top_left, Vector2(0.1, 0.88), Color(0.0, 0.0, 0.0, 1.0))
		_add_flower_vertex(surface_tool, base_right, Vector2(1.0, 0.0), Color(0.0, 0.0, 0.0, 1.0))
		_add_flower_vertex(surface_tool, base_right, Vector2(1.0, 0.0), Color(0.0, 0.0, 0.0, 1.0))
		_add_flower_vertex(surface_tool, top_left, Vector2(0.1, 0.88), Color(0.0, 0.0, 0.0, 1.0))
		_add_flower_vertex(surface_tool, top_right, Vector2(0.9, 0.88), Color(0.0, 0.0, 0.0, 1.0))

		if shape_variant != 4:
			var leaf_center: Vector3 = base_center + Vector3.UP * (stem_height * 0.38) + lean * 0.28
			var leaf_left: Vector3 = leaf_center - right * 0.10 + direction * 0.035
			var leaf_right: Vector3 = leaf_center + right * 0.10 + direction * 0.035
			var leaf_tip: Vector3 = leaf_center + direction * (0.15 + 0.03 * shape_variety) + Vector3.UP * 0.018
			_add_flower_vertex(surface_tool, leaf_left, Vector2(0.12, 0.34), Color(0.0, 0.0, 0.0, 1.0))
			_add_flower_vertex(surface_tool, leaf_tip, Vector2(0.5, 0.56), Color(0.0, 0.0, 0.0, 1.0))
			_add_flower_vertex(surface_tool, leaf_right, Vector2(0.88, 0.34), Color(0.0, 0.0, 0.0, 1.0))

		var petal_center: Vector3 = top_center + Vector3.UP * 0.025
		var center_radius: float = petal_radius * center_radius_factor
		for petal_index in petal_segments:
			var a0: float = TAU * float(petal_index) / float(petal_segments)
			var a1: float = TAU * float(petal_index + 1) / float(petal_segments)
			var amid: float = (a0 + a1) * 0.5
			var axis0 := right * cos(a0) + direction * sin(a0)
			var axis1 := right * cos(a1) + direction * sin(a1)
			var axis_mid := right * cos(amid) + direction * sin(amid)
			var inner0: Vector3 = petal_center + axis0 * center_radius
			var inner1: Vector3 = petal_center + axis1 * center_radius
			var outer: Vector3 = petal_center + axis_mid * (petal_radius * petal_stretch) + Vector3.UP * petal_lift
			if shape_variant == 3:
				outer -= Vector3.UP * 0.025
			_add_flower_vertex(surface_tool, inner0, Vector2(0.5, 1.0), Color(1.0, 0.0, variant_tint, 1.0))
			_add_flower_vertex(surface_tool, outer, Vector2(0.5, 1.0), Color(1.0, 0.0, variant_tint, 1.0))
			_add_flower_vertex(surface_tool, inner1, Vector2(0.5, 1.0), Color(1.0, 0.0, variant_tint, 1.0))
			_add_flower_vertex(surface_tool, petal_center, Vector2(0.5, 1.0), Color(0.0, 1.0, variant_tint, 1.0))
			_add_flower_vertex(surface_tool, inner1, Vector2(0.5, 1.0), Color(0.0, 1.0, variant_tint, 1.0))
			_add_flower_vertex(surface_tool, inner0, Vector2(0.5, 1.0), Color(0.0, 1.0, variant_tint, 1.0))
	surface_tool.generate_normals()
	var mesh: ArrayMesh = surface_tool.commit()
	mesh.custom_aabb = AABB(Vector3(-0.56, -0.08, -0.56), Vector3(1.12, 1.42, 1.12))
	return mesh


func _add_flower_vertex(surface_tool: SurfaceTool, vertex: Vector3, uv: Vector2, color: Color) -> void:
	surface_tool.set_color(color)
	surface_tool.set_uv(uv)
	surface_tool.add_vertex(vertex)


func _create_flower_material(active_profile: VegetationProfile) -> ShaderMaterial:
	var shader := load(FLOWER_SHADER_PATH) as Shader
	if shader == null:
		push_warning("Vegetation flower shader is missing: " + FLOWER_SHADER_PATH)
		return null
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("stem_color", active_profile.flower_stem_color)
	material.set_shader_parameter("stem_shadow_color", active_profile.flower_stem_shadow_color)
	material.set_shader_parameter("petal_color_a", active_profile.flower_petal_color_a)
	material.set_shader_parameter("petal_color_b", active_profile.flower_petal_color_b)
	material.set_shader_parameter("petal_color_c", active_profile.flower_petal_color_c)
	material.set_shader_parameter("petal_color_d", active_profile.flower_petal_color_d)
	material.set_shader_parameter("petal_color_e", active_profile.flower_petal_color_e)
	material.set_shader_parameter("center_color", active_profile.flower_center_color)
	material.set_shader_parameter("wind_direction", active_profile.wind_direction.normalized())
	material.set_shader_parameter("wind_strength", active_profile.grass_wind_strength * 0.78)
	material.set_shader_parameter("wind_speed", active_profile.wind_speed)
	material.set_shader_parameter("wind_noise_scale", active_profile.wind_noise_scale)
	material.set_shader_parameter("gust_strength", active_profile.gust_strength)
	material.set_shader_parameter("touch_push_strength", active_profile.touch_push_strength * 0.78)
	material.set_shader_parameter("touch_crush_strength", active_profile.touch_crush_strength * 0.72)
	material.set_shader_parameter("touch_recovery", active_profile.touch_recovery_speed)
	return material


func _build_tree_visuals(placements: Array[Dictionary]) -> void:
	if placements.is_empty() or _generated_root == null:
		return
	_tree_material = _create_tree_material(_active_profile)
	if _tree_material == null:
		return
	var tree_root := Node3D.new()
	tree_root.name = "Trees"
	_generated_root.add_child(tree_root)
	var index: int = 0
	var trees_built_this_frame: int = 0
	for item in placements:
		var prototype: int = int(item.get("prototype", 0))
		if prototype < 0 or prototype >= _active_profile.tree_scene_paths.size():
			continue
		var scene_path: String = _active_profile.tree_scene_paths[prototype]
		if not ResourceLoader.exists(scene_path):
			continue
		var packed_scene := load(scene_path) as PackedScene
		if packed_scene == null:
			continue
		var tree_instance := packed_scene.instantiate() as Node3D
		if tree_instance == null:
			continue
		tree_instance.name = "Tree_%03d" % index
		tree_instance.transform = Transform3D(_basis_from_yaw_scale(float(item.get("yaw", 0.0)), item.get("scale", Vector3.ONE)), item.get("position", Vector3.ZERO))
		tree_root.add_child(tree_instance)
		_apply_tree_material_recursive(tree_instance)
		index += 1
		trees_built_this_frame += 1
		if _should_yield_build() and trees_built_this_frame >= chunk_builds_per_frame:
			trees_built_this_frame = 0
			await get_tree().process_frame


func _create_tree_material(active_profile: VegetationProfile) -> ShaderMaterial:
	var shader := load(TREE_SHADER_PATH) as Shader
	if shader == null:
		push_warning("Vegetation tree shader is missing: " + TREE_SHADER_PATH)
		return null
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("trunk_color", active_profile.tree_trunk_color)
	material.set_shader_parameter("leaf_color", active_profile.tree_leaf_color)
	material.set_shader_parameter("leaf_tip_color", active_profile.tree_leaf_tip_color)
	material.set_shader_parameter("wind_direction", active_profile.wind_direction.normalized())
	material.set_shader_parameter("wind_strength", active_profile.tree_wind_strength)
	material.set_shader_parameter("wind_speed", active_profile.wind_speed)
	material.set_shader_parameter("wind_noise_scale", active_profile.wind_noise_scale)
	material.set_shader_parameter("gust_strength", active_profile.gust_strength)
	return material


func _apply_tree_material_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = _tree_material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for child in node.get_children():
		_apply_tree_material_recursive(child)


func _build_tree_collisions(placements: Array[Dictionary]) -> void:
	if placements.is_empty() or _generated_root == null:
		return
	var collision_root := Node3D.new()
	collision_root.name = "TreeCollisions"
	_generated_root.add_child(collision_root)
	var index: int = 0
	for item in placements:
		var item_scale: Vector3 = item.get("scale", Vector3.ONE)
		var body := StaticBody3D.new()
		body.name = "TreeCollision_%03d" % index
		body.collision_layer = WORLD_COLLISION_LAYER
		body.collision_mask = 0
		body.add_to_group("vegetation_tree_collision")
		var height: float = _active_profile.tree_trunk_height * item_scale.y
		var radius: float = _active_profile.tree_trunk_radius * maxf(item_scale.x, item_scale.z)
		body.position = item.get("position", Vector3.ZERO) + Vector3.UP * (height * 0.5)
		collision_root.add_child(body)
		var shape_node := CollisionShape3D.new()
		shape_node.name = "TreeTrunkShape"
		var shape := CylinderShape3D.new()
		shape.height = height
		shape.radius = radius
		shape_node.shape = shape
		body.add_child(shape_node)
		index += 1


func _basis_from_yaw_scale(yaw: float, item_scale: Vector3) -> Basis:
	var result_basis := Basis(Vector3.UP, yaw)
	result_basis = result_basis.scaled(item_scale)
	return result_basis
