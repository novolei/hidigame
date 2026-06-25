@tool
extends RefCounted

const TARGETS: Array[String] = ["DefaultC01", "MaskTint01"]

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	for target_name: String in TARGETS:
		var target: Node = root.get_node_or_null(target_name)
		if target == null:
			ctx.log("target_missing=%s" % target_name)
			continue
		if target.has_method("set_character_model_id"):
			var model_id: String = "party_monster_c01" if target_name == "DefaultC01" else "party_monster_masktint01"
			target.call("set_character_model_id", model_id)
		if target.has_method("_build_skin"):
			target.call("_build_skin")
		var samples: Array[String] = []
		var stats: Dictionary = _scan_winding(target, String(target.name), samples)
		ctx.log("target=%s triangles=%d agree=%d oppose=%d flat_or_unknown=%d negative_basis=%d" % [target_name, int(stats.get("triangles", 0)), int(stats.get("agree", 0)), int(stats.get("oppose", 0)), int(stats.get("unknown", 0)), int(stats.get("negative_basis", 0))])
		for sample: String in samples:
			ctx.log(sample)

func _scan_winding(node: Node, label: String, samples: Array[String]) -> Dictionary:
	var triangles: int = 0
	var agree: int = 0
	var oppose: int = 0
	var unknown: int = 0
	var negative_basis: int = 0
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh != null:
			var determinant: float = mesh_instance.transform.basis.determinant()
			if determinant < 0.0:
				negative_basis += 1
			var mesh_stats: Dictionary = _mesh_winding_stats(mesh_instance.mesh)
			triangles += int(mesh_stats.get("triangles", 0))
			agree += int(mesh_stats.get("agree", 0))
			oppose += int(mesh_stats.get("oppose", 0))
			unknown += int(mesh_stats.get("unknown", 0))
			if samples.size() < 8:
				samples.append("mesh=%s determinant=%.3f triangles=%d agree=%d oppose=%d unknown=%d" % [label, determinant, int(mesh_stats.get("triangles", 0)), int(mesh_stats.get("agree", 0)), int(mesh_stats.get("oppose", 0)), int(mesh_stats.get("unknown", 0))])
	for child: Node in node.get_children():
		var child_label: String = "%s/%s" % [label, String(child.name)]
		var child_stats: Dictionary = _scan_winding(child, child_label, samples)
		triangles += int(child_stats.get("triangles", 0))
		agree += int(child_stats.get("agree", 0))
		oppose += int(child_stats.get("oppose", 0))
		unknown += int(child_stats.get("unknown", 0))
		negative_basis += int(child_stats.get("negative_basis", 0))
	return {"triangles": triangles, "agree": agree, "oppose": oppose, "unknown": unknown, "negative_basis": negative_basis}

func _mesh_winding_stats(mesh: Mesh) -> Dictionary:
	var triangles: int = 0
	var agree: int = 0
	var oppose: int = 0
	var unknown: int = 0
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays.size() <= Mesh.ARRAY_VERTEX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			continue
		if arrays.size() <= Mesh.ARRAY_NORMAL or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = PackedInt32Array()
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX]
		if not indices.is_empty():
			for i: int in range(0, indices.size() - 2, 3):
				var i0: int = indices[i]
				var i1: int = indices[i + 1]
				var i2: int = indices[i + 2]
				var comparison: int = _compare_triangle(vertices, normals, i0, i1, i2)
				triangles += 1
				if comparison > 0:
					agree += 1
				elif comparison < 0:
					oppose += 1
				else:
					unknown += 1
		else:
			for i: int in range(0, vertices.size() - 2, 3):
				var comparison: int = _compare_triangle(vertices, normals, i, i + 1, i + 2)
				triangles += 1
				if comparison > 0:
					agree += 1
				elif comparison < 0:
					oppose += 1
				else:
					unknown += 1
	return {"triangles": triangles, "agree": agree, "oppose": oppose, "unknown": unknown}

func _compare_triangle(vertices: PackedVector3Array, normals: PackedVector3Array, i0: int, i1: int, i2: int) -> int:
	if i0 < 0 or i1 < 0 or i2 < 0 or i0 >= vertices.size() or i1 >= vertices.size() or i2 >= vertices.size():
		return 0
	if i0 >= normals.size() or i1 >= normals.size() or i2 >= normals.size():
		return 0
	var edge_a: Vector3 = vertices[i1] - vertices[i0]
	var edge_b: Vector3 = vertices[i2] - vertices[i0]
	var face_normal: Vector3 = edge_a.cross(edge_b)
	if face_normal.length() < 0.0001:
		return 0
	face_normal = face_normal.normalized()
	var avg_normal: Vector3 = (normals[i0] + normals[i1] + normals[i2]) / 3.0
	if avg_normal.length() < 0.0001:
		return 0
	avg_normal = avg_normal.normalized()
	var dot_value: float = face_normal.dot(avg_normal)
	if dot_value > 0.25:
		return 1
	if dot_value < -0.25:
		return -1
	return 0
