@tool
extends RefCounted

func run(ctx) -> void:
	var source_scene: PackedScene = load(PartyMonsterSkin.MODEL_SCENE_PATH) as PackedScene
	if source_scene == null:
		ctx.error("source model could not load")
		return
	var source_root: Node = source_scene.instantiate()
	if source_root == null:
		ctx.error("source model did not instantiate")
		return
	var names: Array[String] = []
	_collect_mesh_names(source_root, names)
	names.sort()
	ctx.log("mesh_count=%d" % names.size())
	var index: int = 0
	for item: String in names:
		if index >= 200:
			ctx.log("...truncated")
			break
		ctx.log(item)
		index += 1
	source_root.free()


func _collect_mesh_names(node: Node, names: Array[String]) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var parent_name: String = ""
		if mesh_instance.get_parent() != null:
			parent_name = String(mesh_instance.get_parent().name)
		names.append("%s parent=%s visible=%s surfaces=%d" % [String(mesh_instance.name), parent_name, str(mesh_instance.visible), mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0])
	for child in node.get_children():
		_collect_mesh_names(child, names)
