extends RefCounted

func run(ctx: Variant) -> void:
	await ctx.wait(1.0)
	var root: Node = ctx.get_scene_root()
	var layout: Node = root.find_child("PolygonApocalypseLayout", true, false)
	var mesh_count: int = 0
	var background_count: int = 0
	var blockers: int = 0
	if layout != null:
		var stack: Array[Node] = [layout]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is MeshInstance3D:
				mesh_count += 1
				if String(node.name).to_lower().contains("background"):
					background_count += 1
			if node is StaticBody3D:
				blockers += 1
			for child: Node in node.get_children():
				stack.push_back(child)
	ctx.log("layout_present=%s mesh_instances=%d background_meshes=%d blockers=%d" % [str(layout != null), mesh_count, background_count, blockers])
	await ctx.capture("polygon_apocalypse_bunker_after_builtin_quad_fix")
	ctx.close_scene()
