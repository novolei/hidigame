@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root=%s class=%s" % [String(root.name), root.get_class()])
	if root.has_method("set_character_model_id"):
		root.call("set_character_model_id", "party_monster_c01")
	if root.has_method("_build_skin"):
		root.call("_build_skin")
	var mesh_count: int = 0
	var surface_count: int = 0
	var normal_surfaces: int = 0
	var indexed_surfaces: int = 0
	var sample_count: int = 0
	_scan(root, ctx, mesh_count, surface_count, normal_surfaces, indexed_surfaces, sample_count)
	ctx.log("summary meshes=%d surfaces=%d normal_surfaces=%d indexed_surfaces=%d" % [mesh_count, surface_count, normal_surfaces, indexed_surfaces])

func _scan(node: Node, ctx: Variant, mesh_count: int, surface_count: int, normal_surfaces: int, indexed_surfaces: int, sample_count: int) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			mesh_count += 1
			var mesh: Mesh = mesh_instance.mesh
			for surface_index: int in range(mesh.get_surface_count()):
				surface_count += 1
				var arrays: Array = mesh.surface_get_arrays(surface_index)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
				if not normals.is_empty():
					normal_surfaces += 1
				if not indices.is_empty():
					indexed_surfaces += 1
				if sample_count < 10:
					var material: Material = mesh.surface_get_material(surface_index)
					var material_name: String = "null" if material == null else String(material.resource_name)
					ctx.log("mesh=%s surface=%d vertices=%d normals=%d indices=%d material=%s" % [String(mesh_instance.name), surface_index, vertices.size(), normals.size(), indices.size(), material_name])
					sample_count += 1
	for child: Node in node.get_children():
		_scan(child, ctx, mesh_count, surface_count, normal_surfaces, indexed_surfaces, sample_count)
