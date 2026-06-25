@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root=%s class=%s" % [String(root.name), root.get_class()])
	var floor: Node = ctx.get_node_or_null("Environment/Floor")
	if floor != null:
		ctx.log("floor=%s class=%s" % [String(floor.name), floor.get_class()])
		var shape_node: CollisionShape3D = floor.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			var box: BoxShape3D = shape_node.shape as BoxShape3D
			ctx.log("floor_collision_size=%s" % str(box.size))
		var mesh_node: MeshInstance3D = floor.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh_node != null and mesh_node.mesh is PlaneMesh:
			var plane: PlaneMesh = mesh_node.mesh as PlaneMesh
			ctx.log("floor_plane_size=%s" % str(plane.size))
	var map_root: Node3D = ctx.get_node_or_null("Environment/GDQuestControllerArena/Map") as Node3D
	if map_root == null:
		ctx.log("map_root_missing")
		return
	var bounds: AABB = _bounds_for(map_root)
	ctx.log("map_bounds_pos=%s size=%s" % [str(bounds.position), str(bounds.size)])
	var names: Array[String] = []
	_collect_named_meshes(map_root, names, 36)
	ctx.log("sample_meshes=%s" % str(names))

func _bounds_for(root: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	var has_bounds: bool = false
	var result: AABB = AABB()
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null or not mesh.visible:
			continue
		var local_box: AABB = mesh.get_aabb()
		if local_box.size.length_squared() <= 0.0001:
			continue
		var world_box: AABB = _transform_aabb(mesh.global_transform, local_box)
		if not has_bounds:
			result = world_box
			has_bounds = true
		else:
			result = result.merge(world_box)
	return result

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, result)

func _collect_named_meshes(node: Node, names: Array[String], limit: int) -> void:
	if names.size() >= limit:
		return
	if node is MeshInstance3D:
		names.append(String(node.name))
	for child: Node in node.get_children():
		_collect_named_meshes(child, names, limit)
		if names.size() >= limit:
			return

func _transform_aabb(transform: Transform3D, box: AABB) -> AABB:
	var min_corner: Vector3 = Vector3(INF, INF, INF)
	var max_corner: Vector3 = Vector3(-INF, -INF, -INF)
	for x: float in [0.0, 1.0]:
		for y: float in [0.0, 1.0]:
			for z: float in [0.0, 1.0]:
				var point: Vector3 = box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed: Vector3 = transform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)
