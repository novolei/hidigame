extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root=null")
		ctx.close_scene()
		return
	var overlay: Node = root.find_child("CharacterSetupOverlay", true, false)
	if overlay == null:
		ctx.log("overlay=missing")
		ctx.close_scene()
		return
	overlay.call("show_setup", 20.0)
	await ctx.wait(0.2)
	if overlay.has_method("_select_skin"):
		overlay.call("_select_skin", "party_monster_c02", false)
	await ctx.wait(1.6)
	var subviewport_count: int = _count_class(overlay, "SubViewport")
	var thumb_viewport: Node = overlay.find_child("ThumbViewport", true, false)
	ctx.log("shader_probe overlay_visible=%s subviewports=%d thumb_viewport=%s" % [str(overlay.visible), subviewport_count, str(thumb_viewport != null)])
	await ctx.capture("party_monster_shader_volume_probe")
	ctx.close_scene()

func _count_class(node: Node, target_class: String) -> int:
	var count: int = 0
	if node.get_class() == target_class:
		count += 1
	for child in node.get_children():
		var child_node: Node = child as Node
		if child_node != null:
			count += _count_class(child_node, target_class)
	return count
