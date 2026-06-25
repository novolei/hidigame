extends RefCounted

func run(ctx: Variant) -> void:
	await ctx.wait(1.0)
	var root: Node = ctx.get_scene_root()
	var generated: Node3D = root.get_node_or_null("GeneratedPolygonApocalypseMap") as Node3D
	if generated == null:
		ctx.log("generated=false")
		ctx.close_scene()
		return
	var meshes: int = 0
	var blockers: int = 0
	var has_bounds: bool = false
	var bounds: AABB = AABB()
	var stack: Array[Node] = [generated]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			meshes += 1
			if mesh_instance.mesh != null:
				var box: AABB = _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
				bounds = box if not has_bounds else bounds.merge(box)
				has_bounds = true
		if node.name.contains("Blocker"):
			blockers += 1
		for child in node.get_children():
			stack.append(child)
	ctx.log("generated=true meshes=%d blockers=%d bounds=%s" % [meshes, blockers, str(bounds)])
	var center: Vector3 = bounds.get_center()
	var extent: float = maxf(maxf(bounds.size.x, bounds.size.y), bounds.size.z)
	var camera: Camera3D = Camera3D.new()
	camera.name = "RuntimeCaptureCamera"
	root.add_child(camera)
	camera.global_position = center + Vector3(extent * 0.85, extent * 0.55, extent * 0.85)
	camera.look_at(center, Vector3.UP)
	camera.fov = 45.0
	camera.current = true
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "RuntimeCaptureSun"
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 1.2
	await ctx.wait(0.25)
	await ctx.capture("polygon_apocalypse_bunker_framed")
	ctx.close_scene()

func _transform_aabb(world_transform: Transform3D, box: AABB) -> AABB:
	var min_corner: Vector3 = Vector3(INF, INF, INF)
	var max_corner: Vector3 = Vector3(-INF, -INF, -INF)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var point: Vector3 = box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed: Vector3 = world_transform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)
