class_name VegetationController
extends Node3D

const GENERATED_ROOT_NAME := "GeneratedVegetation"
const GRASS_SHADER_PATH := "res://shaders/vegetation/stylized_grass.gdshader"
const TREE_SHADER_PATH := "res://shaders/vegetation/stylized_tree_wind.gdshader"
const POLYGON_ROOT_NAME := "GeneratedPolygonApocalypseMap"
const POLYGON_SUPPORT_NAME := "PolygonApocalypseGameplaySupport"
const POLYGON_SUPPORT_SHAPE_NAME := "GameplaySupportShape"
const WORLD_COLLISION_LAYER: int = 2

@export var enabled: bool = true
@export var profile: VegetationProfile
@export_range(1, 120, 1) var install_wait_frames: int = 12

var _active_profile: VegetationProfile
var _support_center: Vector3 = Vector3.ZERO
var _support_size: Vector2 = Vector2(230.0, 220.0)
var _support_top_y: float = -8.0
var _generated_root: Node3D
var _grass_material: ShaderMaterial
var _tree_material: ShaderMaterial


func _ready() -> void:
	if not enabled:
		return
	call_deferred("_install_when_ready")


func _process(_delta: float) -> void:
	var now_seconds: float = float(Time.get_ticks_msec()) * 0.001
	if _grass_material != null:
		_grass_material.set_shader_parameter("veg_time", now_seconds)
	if _tree_material != null:
		_tree_material.set_shader_parameter("veg_time", now_seconds)


func rebuild() -> void:
	_clear_generated()
	_install_when_ready()


func _install_when_ready() -> void:
	_active_profile = _resolve_profile()
	if _active_profile == null:
		return

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

	_build_generated_content()


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
	if generated_map == null:
		return false
	var support := generated_map.get_node_or_null(POLYGON_SUPPORT_NAME) as StaticBody3D
	if support == null:
		return false
	var shape_node := support.get_node_or_null(POLYGON_SUPPORT_SHAPE_NAME) as CollisionShape3D
	if shape_node == null or not shape_node.shape is BoxShape3D:
		return false
	var shape := shape_node.shape as BoxShape3D
	_support_center = Vector3(support.global_position.x, 0.0, support.global_position.z)
	_support_size = support.get_meta("support_size_xz", Vector2(shape.size.x, shape.size.z))
	_support_top_y = float(support.get_meta("support_top_y", support.global_position.y + shape.size.y * 0.5))
	return true


func _build_generated_content() -> void:
	_clear_generated()
	var build_visuals: bool = _should_build_visuals()
	var needs_collision: bool = _active_profile.enable_trees and _active_profile.tree_collision_enabled
	if not build_visuals and not needs_collision:
		set_process(false)
		return

	_generated_root = Node3D.new()
	_generated_root.name = GENERATED_ROOT_NAME
	add_child(_generated_root)

	var grass_placements: Array[Dictionary] = []
	if _active_profile.enable_grass and build_visuals:
		grass_placements = VegetationPlanner.generate_grass(_active_profile, _support_center, _support_size, _support_top_y)
		_build_grass(grass_placements)

	var tree_placements: Array[Dictionary] = []
	if _active_profile.enable_trees:
		tree_placements = VegetationPlanner.generate_trees(_active_profile, _support_center, _support_size, _support_top_y)
		if build_visuals:
			_build_tree_visuals(tree_placements)
		if _active_profile.tree_collision_enabled:
			_build_tree_collisions(tree_placements)

	set_process(_grass_material != null or _tree_material != null)


func _should_build_visuals() -> bool:
	if _active_profile == null:
		return false
	if RuntimeMode.is_headless() and not _active_profile.build_visuals_in_headless:
		return false
	return true


func _clear_generated() -> void:
	for child in get_children():
		if child.name == GENERATED_ROOT_NAME:
			remove_child(child)
			child.free()
	_generated_root = null
	_grass_material = null
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
	for key in chunk_map.keys():
		var chunk_items: Array = chunk_map[key]
		_build_grass_chunk(grass_root, grass_mesh, str(key), chunk_items)
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
	var blade_count: int = 7
	for blade_index in blade_count:
		var angle: float = TAU * float(blade_index) / float(blade_count)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var right := Vector3(-direction.z, 0.0, direction.x)
		var center := direction * (0.035 * float((blade_index % 3) - 1))
		var base_width: float = 0.42 + 0.05 * float(blade_index % 2)
		var lean: Vector3 = direction * (0.10 + 0.025 * float(blade_index % 3))
		var base_left: Vector3 = center - right * base_width
		var base_right: Vector3 = center + right * base_width
		var tip: Vector3 = center + lean + Vector3.UP
		_add_grass_vertex(surface_tool, base_left, Vector2(0.0, 0.0), Color(0.0, 0.0, 0.0, 1.0))
		_add_grass_vertex(surface_tool, tip, Vector2(0.5, 1.0), Color(1.0, 1.0, 1.0, 1.0))
		_add_grass_vertex(surface_tool, base_right, Vector2(1.0, 0.0), Color(0.0, 0.0, 0.0, 1.0))
	surface_tool.generate_normals()
	var mesh: ArrayMesh = surface_tool.commit()
	mesh.custom_aabb = AABB(Vector3(-1.0, -0.1, -1.0), Vector3(2.0, 2.4, 2.0))
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
