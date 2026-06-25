extends RefCounted

func run(ctx: Variant) -> void:
	await ctx.wait(1.0)
	var root: Node = ctx.get_scene_root()
	var generated: Node = root.get_node_or_null("GeneratedPolygonApocalypseMap")
	if generated == null:
		ctx.log("generated=false")
	else:
		var meshes: int = 0
		var blockers: int = 0
		var stack: Array[Node] = [generated]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			if node is MeshInstance3D:
				meshes += 1
			if node.name.contains("Blocker"):
				blockers += 1
			for child in node.get_children():
				stack.append(child)
		ctx.log("generated=true meshes=%d blockers=%d" % [meshes, blockers])
		await ctx.capture("polygon_apocalypse_bunker_runtime")
	ctx.close_scene()
