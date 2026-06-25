@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var hud: Control = root.get_node_or_null("MarkedHuntHUD") as Control
	if hud == null:
		ctx.error("MarkedHuntHUD not found")
		return
	ctx.log("before size=%s bottom=%s" % [str(hud.custom_minimum_size), str(hud.offset_bottom)])
	hud.custom_minimum_size = Vector2(360.0, 218.0)
	hud.offset_left = 902.0
	hud.offset_top = 118.0
	hud.offset_right = 1262.0
	hud.offset_bottom = 336.0
	hud.visible = true
	hud.set("qa_preview_state", true)
	ctx.log("after size=%s bottom=%s" % [str(hud.custom_minimum_size), str(hud.offset_bottom)])
	ctx.mark_modified()
