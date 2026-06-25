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
	var size: Vector3 = bounds.size
	var camera: Camera3D = Camera3D.new()
	camera.name = "CodexAuditCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(maxf(size.x, size.z), size.y) * 1.25
	var distance: float = maxf(maxf(size.x, size.y), size.z) * 1.15 + 8.0
	var camera_pos: Vector3 = center + Vector3(distance * 0.55, distance * 0.45, distance * 0.75)
	root.add_child(camera)
	camera.look_at_from_position(camera_pos, center, Vector3.UP)
	camera.current = true
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "CodexAuditLight"
	light.light_energy = 2.0
	root.add_child(light)
	light.look_at_from_position(center + Vector3(10.0, 20.0, 10.0), center, Vector3.UP)
	ctx.log("layout_present=true mesh_instances=%d background_meshes=%d bounds_center=%s bounds_size=%s camera_size=%.2f" % [mesh_count, background_count, str(center), str(size), camera.size])
	await ctx.wait(0.5)
	await ctx.capture("polygon_apocalypse_bunker_framed_after_quad_fix")
	ctx.close_scene()
