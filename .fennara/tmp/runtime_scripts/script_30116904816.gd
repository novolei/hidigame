extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root_missing")
		ctx.close_scene()
		return
	await ctx.wait(0.2)
	if root.has_method("_server_spawn_ammo_packs"):
		root.call("_server_spawn_ammo_packs")
	else:
		ctx.log("spawn_method_missing")
		ctx.close_scene()
		return
	await ctx.wait(0.3)
	var container: Node = root.get_node_or_null("AmmoPackContainer")
	var count: int = 0
	if container != null:
		count = container.get_child_count()
	ctx.log("ammo_spawn_probe count=%d" % count)
	ctx.close_scene()
