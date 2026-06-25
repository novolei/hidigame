@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root=%s class=%s" % [String(root.name), root.get_class()])
	var ids: Array[String] = ["party_monster_c01", "party_monster_masktint01", "party_monster_c07"]
	for model_id: String in ids:
		if root.has_method("set_character_model_id"):
			root.call("set_character_model_id", model_id)
		if root.has_method("_build_skin"):
			root.call("_build_skin")
		var visible_meshes: Array[String] = []
		var hidden_controlled: Array[String] = []
		var total_visible_tris: int = _collect_meshes(root, visible_meshes, hidden_controlled)
		visible_meshes.sort()
		hidden_controlled.sort()
		ctx.log("id=%s visible_mesh_count=%d visible_tris=%d" % [model_id, visible_meshes.size(), total_visible_tris])
		ctx.log("id=%s visible_meshes=%s" % [model_id, ",".join(visible_meshes)])
		var hidden_sample: Array[String] = []
		for index: int in range(mini(30, hidden_controlled.size())):
			hidden_sample.append(hidden_controlled[index])
		ctx.log("id=%s hidden_controlled_sample=%s" % [model_id, ",".join(hidden_sample)])

func _collect_meshes(node: Node, visible_meshes: Array[String], hidden_controlled: Array[String]) -> int:
	var total: int = 0
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.visible:
			visible_meshes.append(String(mi.name))
			total += _count_mesh_tris(mi)
		elif _is_controlled_part_name(String(mi.name)):
			hidden_controlled.append(String(mi.name))
	for child: Node in node.get_children():
		total += _collect_meshes(child, visible_meshes, hidden_controlled)
	return total

func _count_mesh_tris(mi: MeshInstance3D) -> int:
	if mi.mesh == null:
		return 0
	var total: int = 0
	for surface: int in range(mi.mesh.get_surface_count()):
		var arrays: Array = mi.mesh.surface_get_arrays(surface)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var indices: PackedInt32Array = PackedInt32Array()
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX]
		if not indices.is_empty():
			total += floori(float(indices.size()) / 3.0)
		elif arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += floori(float(vertices.size()) / 3.0)
	return total

func _is_controlled_part_name(node_name: String) -> bool:
	var prefixes: Array[String] = ["MainBody", "Bodypart", "Tail", "Glove", "Eye", "Mouth", "Nose", "Hair", "Ear", "Hat", "Horn", "Comb", "Grass"]
	for prefix: String in prefixes:
		if node_name.begins_with(prefix):
			return true
	return false
