extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	for model in CharacterSkinCatalog.all():
		var model_id := str(model.get("id", ""))
		var scene_path := str(model.get("scene", ""))
		if scene_path.is_empty():
			continue
		var scene := load(scene_path)
		if not scene is PackedScene:
			failures.append("Model %s did not load as PackedScene: %s" % [model_id, scene_path])
			continue
		var node := (scene as PackedScene).instantiate()
		if not node is Node3D:
			failures.append("Model %s did not instantiate as Node3D" % model_id)
		if model_id == "gingerbread" and node:
			if scene_path != "res://assets/characters/gingerbread/gingerbread_animated_skin.tscn":
				failures.append("Gingerbread should use the animated skin wrapper scene")
			var gingerbread_skin_source := FileAccess.get_file_as_string("res://assets/characters/gingerbread/gingerbread_animated_skin.gd")
			if not gingerbread_skin_source.contains("res://assets/characters/gingerbread/gingerbread_meshy_rigged_animated.glb"):
				failures.append("Gingerbread skin should load the rigged 6K Meshy GLB requested for brush painting")
			if not FileAccess.file_exists("res://assets/characters/gingerbread/gingerbread_meshy_rigged_animated.glb"):
				failures.append("Gingerbread rigged 6K Meshy GLB should exist for painting")
			var gingerbread_runtime_import_source := FileAccess.get_file_as_string("res://assets/characters/gingerbread/gingerbread_meshy_rigged_animated.glb.import")
			if gingerbread_runtime_import_source.contains("meshes/generate_lods=true"):
				failures.append("Gingerbread rigged 6K Meshy GLB import should not auto-generate LODs because brush projection needs stable surfaces")
			if node.has_method("_build_skin"):
				node.call("_build_skin")
			if not (node as Node3D).has_node("GingerbreadVisual"):
				failures.append("Gingerbread skin did not instantiate its animated GLB visual")
			for method_name in ["idle", "move", "run", "jump", "fall", "crouch", "prone"]:
				if not node.has_method(method_name):
					failures.append("Gingerbread skin is missing action method: %s" % method_name)
			for action_name in ["idle", "walk", "run", "jump", "fall", "crouch", "prone"]:
				if node.has_method("has_action") and not node.call("has_action", action_name):
					failures.append("Gingerbread skin should expose gameplay-compatible action: %s" % action_name)
			var gingerbread_triangle_count := _count_triangles(node)
			if gingerbread_triangle_count <= 0:
				failures.append("Gingerbread rigged 6K Meshy GLB should expose a paintable mesh")
			elif gingerbread_triangle_count > 8000:
				failures.append("Gingerbread rigged 6K Meshy GLB should stay near the requested 6K triangle budget; got %d" % gingerbread_triangle_count)
		if node:
			node.free()

	if failures.is_empty():
		print("[CharacterSkinCatalogTest] PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("[CharacterSkinCatalogTest] " + failure)
		quit(1)


func _count_triangles(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh:
			for surface in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(surface)
				if arrays.size() <= Mesh.ARRAY_INDEX:
					continue
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				if not indices.is_empty():
					total += int(indices.size() / 3)
				else:
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					total += int(vertices.size() / 3)
	for child in node.get_children():
		total += _count_triangles(child)
	return total
