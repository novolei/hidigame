@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var existing: Node = root.get_node_or_null("HologramFlagContainer")
	if existing != null:
		ctx.log("HologramFlagContainer already exists")
		return
	var container: Node3D = Node3D.new()
	container.name = "HologramFlagContainer"
	root.add_child(container)
	ctx.own(container)
	ctx.log("Added HologramFlagContainer to level root")
	ctx.mark_modified()
