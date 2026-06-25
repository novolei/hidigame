@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root_class=%s" % root.get_class())
	ctx.log("root_name=%s" % String(root.name))
	if root.has_method("_build_skin"):
		root.call("_build_skin")
	if root.has_method("set_character_model_id"):
		root.call("set_character_model_id", "party_monster_c12")
	ctx.log("selected_model=%s" % str(root.get("character_model_id")))
	var visual: Node = root.get_node_or_null("PartyMonsterVisual")
	ctx.log("has_visual=%s" % str(visual != null))
	var player: AnimationPlayer = root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null:
		ctx.error("AnimationPlayer missing")
		return
	ctx.log("animations=%s" % ",".join(player.get_animation_list()))
	if not player.has_animation("Idle") or not player.has_animation("Run") or not player.has_animation("Jump"):
		ctx.error("Expected Party Monster gameplay animations are missing")
		return
	var visible_meshes: int = 0
	var hidden_meshes: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			if (node as MeshInstance3D).visible:
				visible_meshes += 1
			else:
				hidden_meshes += 1
		for child in node.get_children():
			stack.append(child)
	ctx.log("visible_meshes=%d hidden_meshes=%d" % [visible_meshes, hidden_meshes])
