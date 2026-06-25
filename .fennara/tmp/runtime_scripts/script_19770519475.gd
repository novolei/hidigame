extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root=null")
		ctx.close_scene()
		return
	var target_skin: String = "party_monster_c02"
	var overlay: Node = root.find_child("CharacterSetupOverlay", true, false)
	if overlay != null:
		overlay.call("show_setup", 20.0)
		await ctx.wait(0.2)
		if overlay.has_method("_select_skin"):
			overlay.call("_select_skin", target_skin, false)
		await ctx.wait(1.6)
		ctx.log("overlay_probe visible=%s subviewports=%d thumb_viewport=%s" % [str(overlay.visible), _count_class(overlay, "SubViewport"), str(overlay.find_child("ThumbViewport", true, false) != null)])
		await ctx.capture("party_monster_overlay_post_shader_tune")
		if overlay.has_method("hide_setup"):
			overlay.call("hide_setup")
	else:
		ctx.log("overlay=missing")
	var changed_players: int = _apply_skin_to_players(root, target_skin)
	ctx.log("changed_players=%d skin=%s" % [changed_players, target_skin])
	await ctx.wait(1.0)
	await ctx.capture("party_monster_gameplay_post_shader_tune")
	ctx.close_scene()

func _apply_skin_to_players(node: Node, model_id: String) -> int:
	var changed: int = 0
	if node.has_method("set_character_model"):
		node.call("set_character_model", model_id)
		changed += 1
	for child in node.get_children():
		var child_node: Node = child as Node
		if child_node != null:
			changed += _apply_skin_to_players(child_node, model_id)
	return changed

func _count_class(node: Node, target_class: String) -> int:
	var count: int = 0
	if node.get_class() == target_class:
		count += 1
	for child in node.get_children():
		var child_node: Node = child as Node
		if child_node != null:
			count += _count_class(child_node, target_class)
	return count
