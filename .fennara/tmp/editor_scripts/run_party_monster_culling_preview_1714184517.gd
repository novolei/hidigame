@tool
extends RefCounted

const TARGETS: Array[String] = ["DefaultC01", "MaskTint01"]

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root=%s class=%s" % [String(root.name), root.get_class()])
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
		var mesh_count: int = 0
		var vertex_total: int = 0
		var zero_normals: int = 0
		var missing_normals: int = 0
		var missing_tangents: int = 0
		var samples: Array[String] = []
		var stats: Dictionary = _scan_meshes(target, String(target.name), samples)
		mesh_count = int(stats.get("mesh_count", 0))
		vertex_total = int(stats.get("vertex_total", 0))
		zero_normals = int(stats.get("zero_normals", 0))
		missing_normals = int(stats.get("missing_normals", 0))
		missing_tangents = int(stats.get("missing_tangents", 0))
		ctx.log("target=%s meshes=%d vertices=%d missing_normals=%d zero_normals=%d missing_tangents=%d" % [target_name, mesh_count, vertex_total, missing_normals, zero_normals, missing_tangents])
		for sample: String in samples:
			ctx.log(sample)

func _scan_meshes(node: Node, label: String, samples: Array[String]) -> Dictionary:
	var mesh_count: int = 0
	var vertex_total: int = 0
	var zero_normals: int = 0
	var missing_normals: int = 0
	var missing_tangents: int = 0
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh != null:
			var mesh: Mesh = mesh_instance.mesh
			var mesh_vertices: int = 0
			var mesh_zero_normals: int = 0
			var mesh_missing_normals: bool = false
			var mesh_missing_tangents: bool = false
			var normal_length_sum: float = 0.0
			var normal_count: int = 0
			for surface: int in range(mesh.get_surface_count()):
				var arrays: Array = mesh.surface_get_arrays(surface)
				if arrays.size() <= Mesh.ARRAY_VERTEX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
					continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				mesh_vertices += vertices.size()
				if arrays.size() <= Mesh.ARRAY_NORMAL or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
					mesh_missing_normals = true
				else:
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					for normal: Vector3 in normals:
						var length: float = normal.length()
						normal_length_sum += length
						normal_count += 1
						if length < 0.001:
							mesh_zero_normals += 1
				if arrays.size() <= Mesh.ARRAY_TANGENT or not arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
					mesh_missing_tangents = true
				else:
					var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
					if tangents.size() < vertices.size() * 4:
						mesh_missing_tangents = true
			mesh_count += 1
			vertex_total += mesh_vertices
			zero_normals += mesh_zero_normals
			if mesh_missing_normals:
				missing_normals += 1
			if mesh_missing_tangents:
				missing_tangents += 1
			if samples.size() < 8:
				var avg_normal: float = 0.0
				if normal_count > 0:
					avg_normal = normal_length_sum / float(normal_count)
				samples.append("mesh=%s verts=%d normal_avg=%.3f zero_normals=%d missing_normals=%s missing_tangents=%s" % [label, mesh_vertices, avg_normal, mesh_zero_normals, str(mesh_missing_normals), str(mesh_missing_tangents)])
	for child: Node in node.get_children():
		var child_label: String = "%s/%s" % [label, String(child.name)]
		var child_stats: Dictionary = _scan_meshes(child, child_label, samples)
		mesh_count += int(child_stats.get("mesh_count", 0))
		vertex_total += int(child_stats.get("vertex_total", 0))
		zero_normals += int(child_stats.get("zero_normals", 0))
		missing_normals += int(child_stats.get("missing_normals", 0))
		missing_tangents += int(child_stats.get("missing_tangents", 0))
	return {
		"mesh_count": mesh_count,
		"vertex_total": vertex_total,
		"zero_normals": zero_normals,
		"missing_normals": missing_normals,
		"missing_tangents": missing_tangents,
	}
