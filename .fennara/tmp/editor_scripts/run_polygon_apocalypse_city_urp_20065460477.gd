@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var generated: Node = root.get_node_or_null("GeneratedPolygonApocalypseMap")
	if generated == null:
		ctx.error("Generated map was not present before ready; this inspection needs runtime build")
		return
	ctx.log("generated_present=true")
