@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root=%s class=%s" % [String(root.name), root.get_class()])
	var hud: Node = root.get_node_or_null("MarkedHuntHUD")
	if hud == null:
		ctx.error("MarkedHuntHUD not found")
		return
	var before_value: Variant = hud.get("qa_preview_state")
	ctx.log("before_qa_preview_state=%s" % str(before_value))
	hud.set("qa_preview_state", true)
	var after_value: Variant = hud.get("qa_preview_state")
	ctx.log("after_qa_preview_state=%s" % str(after_value))
	ctx.mark_modified()
