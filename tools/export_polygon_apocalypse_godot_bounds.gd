extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var options: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var scene_path: String = String(options.get("scene", ""))
	var out_path: String = String(options.get("out", ""))
	if scene_path.is_empty() or out_path.is_empty():
		push_error("Usage: godot --path . --script tools/export_polygon_apocalypse_godot_bounds.gd -- --scene=res://... --out=C:/bounds.json")
		quit(2)
		return

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load scene: %s" % scene_path)
		quit(3)
		return

	var scene: Node = packed.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var generated: Node = scene.get_node_or_null("GeneratedPolygonApocalypseMap")
	var layout: Node3D = generated.get_node_or_null("PolygonApocalypseLayout") as Node3D if generated != null else null
	if layout == null:
		push_error("Missing GeneratedPolygonApocalypseMap/PolygonApocalypseLayout in %s" % scene_path)
		quit(4)
		return

	var objects: Array[Dictionary] = []
	for child: Node in layout.get_children():
		if not child is Node3D:
			continue
		var node: Node3D = child as Node3D
		var bounds: AABB = _calculate_bounds(node)
		var unity_name: String = String(node.get_meta("unity_name", String(node.name)))
		objects.append({
			"name": String(node.name),
			"unity_name": unity_name,
			"unity_transform_id": String(node.get_meta("unity_transform_id", "")),
			"center": _vector_to_array(bounds.get_center()),
			"size": _vector_to_array(bounds.size),
			"min": _vector_to_array(bounds.position),
			"max": _vector_to_array(bounds.position + bounds.size),
			"materials": _collect_materials(node),
		})

	var payload: Dictionary = {
		"scene": scene_path,
		"object_count": objects.size(),
		"objects": objects,
	}
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open output: %s" % out_path)
		quit(5)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	print("saved=%s objects=%d" % [out_path, objects.size()])
	scene.queue_free()
	await process_frame
	quit(0)

func _parse_args(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for arg: String in args:
		if not arg.begins_with("--"):
			continue
		var body: String = arg.substr(2)
		var split_at: int = body.find("=")
		if split_at == -1:
			result[body] = "true"
		else:
			result[body.substr(0, split_at)] = body.substr(split_at + 1)
	return result

func _calculate_bounds(root_node: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(root_node, meshes)
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

func _collect_materials(root_node: Node3D) -> Array[Dictionary]:
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(root_node, meshes)
	var materials: Array[Dictionary] = []
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var material: Material = mesh_instance.get_surface_override_material(surface_index)
			if material == null:
				material = mesh_instance.mesh.surface_get_material(surface_index)
			materials.append(_material_to_dictionary(mesh_instance, surface_index, material))
	return materials

func _material_to_dictionary(mesh_instance: MeshInstance3D, surface_index: int, material: Material) -> Dictionary:
	var data: Dictionary = {
		"mesh_instance": String(mesh_instance.name),
		"surface_index": surface_index,
		"class": "null",
		"resource_name": "",
		"resource_path": "",
	}
	if material == null:
		return data
	data["class"] = material.get_class()
	data["resource_name"] = String(material.resource_name)
	data["resource_path"] = String(material.resource_path)
	if material is StandardMaterial3D:
		var standard: StandardMaterial3D = material as StandardMaterial3D
		data["albedo_color"] = _color_to_array(standard.albedo_color)
		data["transparency"] = standard.transparency
		data["blend_mode"] = standard.blend_mode
		data["depth_draw_mode"] = standard.depth_draw_mode
		data["cull_mode"] = standard.cull_mode
		data["disable_receive_shadows"] = standard.disable_receive_shadows
		data["roughness"] = standard.roughness
		data["metallic"] = standard.metallic
		data["render_priority"] = standard.render_priority
	return data

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

func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]

func _color_to_array(value: Color) -> Array[float]:
	return [value.r, value.g, value.b, value.a]
