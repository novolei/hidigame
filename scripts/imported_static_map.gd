extends Node3D
class_name ImportedStaticMap

const WORLD_LAYER := 2

@export var generate_collision := true
@export var collision_root_name := "ImportedCollisionRoot"
@export var max_collision_meshes := 512
@export var collision_include_name_tokens: Array[String] = []
@export var collision_exclude_name_tokens: Array[String] = []
@export var add_flat_gameplay_floor := false
@export var flat_gameplay_floor_size := Vector2(90.0, 90.0)
@export var flat_gameplay_floor_thickness := 0.12
@export var align_bottom_to_world_ground := true
@export var ground_y := 0.0
@export var visual_root_path: NodePath = NodePath(".")
@export var align_spawn_surface_to_world_ground := false
@export var spawn_surface_probe_points: Array[Vector3] = [
	Vector3.ZERO,
	Vector3(10.0, 0.0, 0.0),
	Vector3(-10.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 10.0),
	Vector3(0.0, 0.0, -10.0),
	Vector3(7.071, 0.0, 7.071),
	Vector3(-7.071, 0.0, 7.071),
	Vector3(7.071, 0.0, -7.071),
	Vector3(-7.071, 0.0, -7.071),
]
@export var spawn_surface_probe_top := 1200.0
@export var spawn_surface_probe_bottom := -1200.0

var _collision_generated := false
var _spawn_surface_aligned := false


func _ready() -> void:
	call_deferred("_prepare_imported_map")


func _prepare_imported_map() -> void:
	if align_bottom_to_world_ground:
		_align_visual_root_to_ground()
	if generate_collision:
		_ensure_static_collision()
	if align_spawn_surface_to_world_ground:
		call_deferred("_align_spawn_surface_to_ground")


func _ensure_static_collision() -> void:
	if _collision_generated or get_node_or_null(collision_root_name):
		return
	_collision_generated = true

	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)

	var collision_root := Node3D.new()
	collision_root.name = collision_root_name
	add_child(collision_root, true)
	if add_flat_gameplay_floor:
		_add_flat_gameplay_floor(collision_root)

	var created := 1 if add_flat_gameplay_floor else 0
	for mesh_instance in meshes:
		if created >= max_collision_meshes:
			break
		if not _mesh_should_collide(mesh_instance):
			continue
		var shape := mesh_instance.mesh.create_trimesh_shape()
		if not shape:
			continue
		var body := StaticBody3D.new()
		body.name = _collision_name(mesh_instance)
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		collision_root.add_child(body, true)
		body.global_transform = mesh_instance.global_transform

		var shape_node := CollisionShape3D.new()
		shape_node.name = "Shape"
		shape_node.shape = shape
		body.add_child(shape_node)
		created += 1

	if created == 0:
		_add_fallback_ground(collision_root)


func _add_flat_gameplay_floor(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "ImportedFlatGameplayFloor"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	parent.add_child(body, true)
	body.global_position = Vector3(0.0, ground_y - flat_gameplay_floor_thickness * 0.5, 0.0)

	var shape_node := CollisionShape3D.new()
	shape_node.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(flat_gameplay_floor_size.x, flat_gameplay_floor_thickness, flat_gameplay_floor_size.y)
	shape_node.shape = shape
	body.add_child(shape_node)


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, result)


func _align_visual_root_to_ground() -> void:
	var visual_root := get_node_or_null(visual_root_path) as Node3D
	if not visual_root:
		visual_root = self
	var bounds := _calculate_bounds(visual_root)
	if bounds.size == Vector3.ZERO:
		return
	visual_root.global_position.y += ground_y - bounds.position.y


func _align_spawn_surface_to_ground() -> void:
	if _spawn_surface_aligned:
		return
	_spawn_surface_aligned = true
	await get_tree().physics_frame

	var heights: Array[float] = []
	var space := get_world_3d().direct_space_state
	for point in spawn_surface_probe_points:
		var from := Vector3(point.x, spawn_surface_probe_top, point.z)
		var to := Vector3(point.x, spawn_surface_probe_bottom, point.z)
		var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
		heights.append(hit_position.y)

	if heights.is_empty():
		return

	heights.sort()
	var median_index := heights.size() / 2
	var surface_y := heights[median_index]
	if heights.size() % 2 == 0:
		surface_y = (heights[median_index - 1] + heights[median_index]) * 0.5

	var delta_y := ground_y - surface_y
	if is_zero_approx(delta_y):
		return
	var visual_root := get_node_or_null(visual_root_path) as Node3D
	if not visual_root:
		visual_root = self
	visual_root.global_position.y += delta_y
	var collision_root := get_node_or_null(collision_root_name) as Node3D
	if collision_root:
		collision_root.global_position.y += delta_y


func _calculate_bounds(root: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if not _mesh_should_collide(mesh_instance):
			continue
		var transformed := _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = transformed
			has_bounds = true
		else:
			bounds = bounds.merge(transformed)
	return bounds if has_bounds else AABB()


func _transform_aabb(transform: Transform3D, box: AABB) -> AABB:
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var point := box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed := transform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)


func _mesh_should_collide(mesh_instance: MeshInstance3D) -> bool:
	if not mesh_instance.mesh or not mesh_instance.visible:
		return false
	var bounds := mesh_instance.get_aabb()
	if bounds.size.length_squared() <= 0.0001:
		return false
	if not collision_include_name_tokens.is_empty() and not _node_or_ancestor_name_matches(mesh_instance, collision_include_name_tokens):
		return false
	if not collision_exclude_name_tokens.is_empty() and _node_or_ancestor_name_matches(mesh_instance, collision_exclude_name_tokens):
		return false
	return true


func _node_or_ancestor_name_matches(node: Node, tokens: Array[String]) -> bool:
	var current: Node = node
	while current and current != self:
		var current_name := String(current.name).to_lower()
		for token in tokens:
			var clean_token := token.to_lower()
			if not clean_token.is_empty() and current_name.contains(clean_token):
				return true
		current = current.get_parent()
	return false


func _collision_name(mesh_instance: MeshInstance3D) -> String:
	var clean_name := String(mesh_instance.name).replace("@", "").replace(":", "_")
	if clean_name.is_empty():
		clean_name = "Mesh"
	return clean_name + "_Collision"


func _add_fallback_ground(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "ImportedFallbackGround"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	parent.add_child(body, true)

	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(120.0, 0.2, 120.0)
	shape_node.shape = shape
	shape_node.position.y = -0.1
	body.add_child(shape_node)
