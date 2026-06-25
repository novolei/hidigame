extends RefCounted

func _world_aabb(mesh_instance: MeshInstance3D) -> AABB:
	var local_box: AABB = mesh_instance.get_aabb()
	var origin: Vector3 = local_box.position
	var size: Vector3 = local_box.size
	var points: Array[Vector3] = [origin, origin + Vector3(size.x, 0.0, 0.0), origin + Vector3(0.0, size.y, 0.0), origin + Vector3(0.0, 0.0, size.z), origin + Vector3(size.x, size.y, 0.0), origin + Vector3(size.x, 0.0, size.z), origin + Vector3(0.0, size.y, size.z), origin + size]
	var first_world: Vector3 = mesh_instance.global_transform * points[0]
	var result: AABB = AABB(first_world, Vector3.ZERO)
	for i: int in range(1, points.size()):
		result = result.expand(mesh_instance.global_transform * points[i])
	return result

func _collect_mesh_bounds(layout: Node) -> Dictionary:
	var stack: Array[Node] = [layout]
	var has_bounds: bool = false
	var bounds: AABB = AABB()
	var mesh_count: int = 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			if mesh_instance.mesh != null:
				mesh_count += 1
				var box: AABB = _world_aabb(mesh_instance)
				bounds = box if not has_bounds else bounds.merge(box)
				has_bounds = true
		for child: Node in node.get_children():
			stack.push_back(child)
	return {"bounds": bounds, "mesh_count": mesh_count, "has_bounds": has_bounds}

func _count_lights(node: Node) -> int:
	var count: int = 0
	if node is Light3D:
		count += 1
	for child: Node in node.get_children():
		count += _count_lights(child)
	return count

func _retune(root: Node, center: Vector3, offset: Vector3, energy: float, exposure: float, ambient_multiplier: float) -> void:
	var env_node: WorldEnvironment = root.find_child("PolygonApocalypseEnvironment", true, false) as WorldEnvironment
	if env_node != null and env_node.environment != null:
		env_node.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env_node.environment.tonemap_exposure = exposure
		env_node.environment.ambient_light_energy *= ambient_multiplier
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is DirectionalLight3D:
			var light: DirectionalLight3D = node as DirectionalLight3D
			light.light_energy = energy
			light.light_color = Color(1.0, 0.84, 0.58, 1.0)
			light.look_at_from_position(center + offset, center, Vector3.UP)
		for child: Node in node.get_children():
			stack.push_back(child)

func run(ctx: Variant) -> void:
	await ctx.wait(1.0)
	var root: Node = ctx.get_scene_root()
	var layout: Node = root.find_child("PolygonApocalypseLayout", true, false)
	if layout == null:
		ctx.log("layout_present=false")
		ctx.close_scene()
		return
	var info: Dictionary = _collect_mesh_bounds(layout)
	if not bool(info["has_bounds"]):
		ctx.log("no_bounds")
		ctx.close_scene()
		return
	var bounds: AABB = info["bounds"] as AABB
	var center: Vector3 = bounds.get_center()
	var size_vec: Vector3 = bounds.size
	var max_size: float = maxf(size_vec.x, maxf(size_vec.y, size_vec.z))
	var camera: Camera3D = Camera3D.new()
	camera.name = "CodexLightingVariantCamera"
	camera.fov = 45.0
	camera.near = 0.01
	camera.far = 5000.0
	root.add_child(camera)
	camera.look_at_from_position(center + Vector3(0.85, 0.55, 0.85).normalized() * max_size * 1.35, center, Vector3.UP)
	camera.current = true
	ctx.log("variant_probe mesh_instances=%d lights=%d center=%s size=%s" % [int(info["mesh_count"]), _count_lights(root), str(center), str(size_vec)])
	_retune(root, center, Vector3(max_size * 0.75, max_size * 1.7, max_size * 0.75), 1.8, 1.15, 1.0)
	await ctx.wait(0.3)
	await ctx.capture("city_urp_variant_sun_ppp")
	_retune(root, center, Vector3(-max_size * 0.75, max_size * 1.7, -max_size * 0.75), 1.8, 1.15, 1.0)
	await ctx.wait(0.3)
	await ctx.capture("city_urp_variant_sun_nnn")
	_retune(root, center, Vector3(max_size * 0.25, max_size * 2.0, -max_size * 0.9), 2.2, 1.25, 1.15)
	await ctx.wait(0.3)
	await ctx.capture("city_urp_variant_warm_high")
	ctx.close_scene()
