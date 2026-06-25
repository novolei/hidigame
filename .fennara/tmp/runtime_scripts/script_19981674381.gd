extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root=null")
		ctx.close_scene()
		return
	var target_skin: String = "party_monster_c02"
	if root.has_method("_on_host_pressed"):
		root.call("_on_host_pressed", "Host_1", "blue", 0, "ShaderProbe", "", target_skin)
		ctx.log("called_host_flow skin=%s" % target_skin)
	else:
		ctx.log("host_method=missing")
	await ctx.wait(0.8)
	if root.has_method("_ensure_player_nodes_from_network"):
		root.call("_ensure_player_nodes_from_network")
	await ctx.wait(0.4)
	var menu_value: Variant = root.get("main_menu")
	if menu_value is Node:
		var menu_node: Node = menu_value as Node
		if menu_node.has_method("hide_menu"):
			menu_node.call("hide_menu")
	if root.has_method("_set_hud_visible"):
		root.call("_set_hud_visible", true)
	var changed_players: int = _apply_skin_to_players(root, target_skin)
	var player_count: int = _count_nodes_with_method(root, "set_character_model")
	ctx.log("changed_players=%d player_method_nodes=%d network_players=%d" % [changed_players, player_count, Network.players.size()])
	await ctx.wait(1.2)
	await ctx.capture("party_monster_gameplay_host_shader_tune")
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

func _count_nodes_with_method(node: Node, method_name: String) -> int:
	var count: int = 0
	if node.has_method(method_name):
		count += 1
	for child in node.get_children():
		var child_node: Node = child as Node
		if child_node != null:
			count += _count_nodes_with_method(child_node, method_name)
	return count
