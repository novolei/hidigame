@tool
extends RefCounted

func _node_path_text(node: Node) -> String:
	var names: Array[String] = []
	var current: Node = node
	while current != null:
		names.push_front(String(current.name))
		current = current.get_parent()
	return "/".join(names)

func _is_interesting(name: String) -> bool:
	var lowered: String = name.to_lower()
	return lowered.contains("body") or lowered.contains("belly") or lowered.contains("arm") or lowered.contains("leg") or lowered.contains("thigh") or lowered.contains("hand") or lowered.contains("glove") or lowered.contains("main")

func _walk(ctx: Variant, node: Node, mesh_count: Array[int], interesting_count: Array[int]) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		mesh_count[0] += 1
		if mesh_node.visible:
			var node_name: String = String(mesh_node.name)
			if _is_interesting(node_name):
				interesting_count[0] += 1
				var surface_count: int = 0
				if mesh_node.mesh != null:
					surface_count = mesh_node.mesh.get_surface_count()
				ctx.log("visible_mesh name=%s path=%s surfaces=%d pos=%s scale=%s skeleton=%s" % [node_name, _node_path_text(mesh_node), surface_count, str(mesh_node.position), str(mesh_node.scale), str(mesh_node.skeleton)])
	var children: Array[Node] = node.get_children()
	for child: Node in children:
		_walk(ctx, child, mesh_count, interesting_count)

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root=%s class=%s" % [String(root.name), root.get_class()])
	if root.has_method("set_character_model_id"):
		root.call("set_character_model_id", "party_monster_c01")
	if root.has_method("idle"):
		root.call("idle")
	if root.has_method("apply_pose_now"):
		root.call("apply_pose_now", 0.0)
	if root.has_method("set_animation_paused"):
		root.call("set_animation_paused", true)
	var mesh_count: Array[int] = [0]
	var interesting_count: Array[int] = [0]
	_walk(ctx, root, mesh_count, interesting_count)
	ctx.log("mesh_total=%d interesting_visible=%d" % [mesh_count[0], interesting_count[0]])
