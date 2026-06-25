@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	root.set("auto_build", true)
	root.set("character_model_id", "party_monster_c01")
	root.set("skin_color", 2)
	root.set("player_height", 2.0)
	if not root.has_method("rebuild"):
		ctx.error("HologramFlag root does not expose rebuild")
		return
	root.call("rebuild")
	ctx.log("generated_child_count=%d" % root.get_child_count())
	ctx.mark_modified()
