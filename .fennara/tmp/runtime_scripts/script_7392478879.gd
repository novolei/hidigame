extends RefCounted

func run(ctx: Variant) -> void:
	await ctx.wait(1.0)
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.close_scene()
		return
	var generated: Node = root.get_node_or_null("GeneratedPolygonApocalypseMap")
	var layout: Node3D = generated.get_node_or_null("PolygonApocalypseLayout") as Node3D if generated != null else null
	if layout == null:
		ctx.log("missing layout")
		ctx.close_scene()
		return
	var bounds: AABB = _calculate_bounds(layout)
	var center: Vector3 = bounds.get_center()
	var max_size: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if max_size <= 0.01:
		max_size = 10.0
	var camera: Camera3D = Camera3D.new()
	camera.name = "RuntimeAuditCameraQuadrants"
	camera.fov = 45.0
	camera.near = 0.01
	camera.far = 5000.0
	root.add_child(camera)
	camera.current = true
	var directions: Array[Vector3] = [
		Vector3(0.85, 0.55, 0.85).normalized(),
		Vector3(-0.85, 0.55, 0.85).normalized(),
		Vector3(0.85, 0.55, -0.85).normalized(),
		Vector3(-0.85, 0.55, -0.85).normalized()
	]
	var labels: Array[String] = ["bunker_dir_pp", "bunker_dir_np", "bunker_dir_pn", "bunker_dir_nn"]
	for i: int in range(directions.size()):
		var pos: Vector3 = center + directions[i] * max_size * 1.35
		camera.look_at_from_position(pos, center, Vector3.UP)
		await ctx.wait(0.15)
		await ctx.capture(labels[i])
		ctx.log("captured %s" % labels[i])
	ctx.close_scene()

func _calculate_bounds(root: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(root, meshes)
	var has_bounds: bool = false
	var bounds: AABB = AABB()
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		var box: AABB = _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = box
			has_bounds = true
		else:
			bounds = bounds.merge(box)
	return bounds if has_bounds else AABB()

func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_find_meshes(child, result)

func _transform_aabb(world_transform: Transform3D, box: AABB) -> AABB:
	var min_corner: Vector3 = Vector3(INF, INF, INF)
	var max_corner: Vector3 = Vector3(-INF, -INF, -INF)
	for x: float in [0.0, 1.0]:
		for y: float in [0.0, 1.0]:
			for z: float in [0.0, 1.0]:
				var point: Vector3 = box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed: Vector3 = world_transform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)
