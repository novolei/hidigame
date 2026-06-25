extends RefCounted

func _merge_aabb(current: AABB, next_box: AABB, has_box: bool) -> AABB:
	if not has_box:
		return next_box
	return current.merge(next_box)

func _world_aabb(mesh_instance: MeshInstance3D) -> AABB:
	var local_box: AABB = mesh_instance.get_aabb()
	var points: Array[Vector3] = []
	var origin: Vector3 = local_box.position
	var size: Vector3 = local_box.size
	points.append(origin)
	points.append(origin + Vector3(size.x, 0.0, 0.0))
	points.append(origin + Vector3(0.0, size.y, 0.0))
	points.append(origin + Vector3(0.0, 0.0, size.z))
	points.append(origin + Vector3(size.x, size.y, 0.0))
	points.append(origin + Vector3(size.x, 0.0, size.z))
	points.append(origin + Vector3(0.0, size.y, size.z))
	points.append(origin + size)
	var first_world: Vector3 = mesh_instance.global_transform * points[0]
	var result: AABB = AABB(first_world, Vector3.ZERO)
	for i: int in range(1, points.size()):
		var world_point: Vector3 = mesh_instance.global_transform * points[i]
		result = result.expand(world_point)
	return result

func run(ctx: Variant) -> void:
	await ctx.wait(1.0)
	var root: Node = ctx.get_scene_root()
	var layout: Node = root.find_child("PolygonApocalypseLayout", true, false)
	if layout == null:
		ctx.log("layout_present=false")
		ctx.close_scene()
		return
	var stack: Array[Node] = [layout]
	var mesh_count: int = 0
	var background_count: int = 0
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			if mesh_instance.mesh != null:
				mesh_count += 1
				if String(mesh_instance.name).to_lower().contains("background"):
					background_count += 1
				var box: AABB = _world_aabb(mesh_instance)
				bounds = _merge_aabb(bounds, box, has_bounds)
				has_bounds = true
		for child: Node in node.get_children():
			stack.push_back(child)
	if not has_bounds:
		ctx.log("no_bounds mesh_instances=%d" % mesh_count)
		ctx.close_scene()
		return
	var center: Vector3 = bounds.get_center()
	var size_vec: Vector3 = bounds.size
	var max_size: float = maxf(size_vec.x, maxf(size_vec.y, size_vec.z))
	if max_size <= 0.01:
		max_size = 10.0
	var camera: Camera3D = Camera3D.new()
	camera.name = "CodexUnityLikeAuditCamera"
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 45.0
	camera.near = 0.01
	camera.far = 5000.0
	var direction: Vector3 = Vector3(0.85, 0.55, 0.85).normalized()
	var camera_pos: Vector3 = center + direction * max_size * 1.35
	root.add_child(camera)
	camera.look_at_from_position(camera_pos, center, Vector3.UP)
	camera.current = true
	if _count_lights(root) == 0:
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.name = "CodexAuditSun"
		light.light_energy = 1.2
		root.add_child(light)
		light.look_at_from_position(center + Vector3(10.0, 20.0, 10.0), center, Vector3.UP)
	var map_label: String = root.scene_file_path.get_file().get_basename()
	ctx.log("layout_present=true map=%s mesh_instances=%d background_meshes=%d bounds_center=%s bounds_size=%s max_size=%.3f" % [map_label, mesh_count, background_count, str(center), str(size_vec), max_size])
	await ctx.wait(0.5)
	await ctx.capture(map_label + "_unity_like_audit")
	ctx.close_scene()

func _count_lights(node: Node) -> int:
	var count: int = 0
	if node is Light3D:
		count += 1
	for child: Node in node.get_children():
		count += _count_lights(child)
	return count
