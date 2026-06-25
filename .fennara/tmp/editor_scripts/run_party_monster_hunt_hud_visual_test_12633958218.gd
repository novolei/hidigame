@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var backdrop: Control = root.get_node_or_null("Backdrop") as Control
	var hud: Control = root.get_node_or_null("MarkedHuntHUD") as Control
	if backdrop == null or hud == null:
		ctx.error("Required visual nodes were not found")
		return
	var panel: Control = hud.get_node_or_null("HuntPanel") as Control
	if panel == null:
		ctx.error("HuntPanel was not found")
		return
	ctx.log("before hud_layout=%s panel_layout=%s" % [str(hud.get("layout_mode")), str(panel.get("layout_mode"))])
	backdrop.set("layout_mode", 1)
	hud.set("layout_mode", 1)
	panel.set("layout_mode", 1)
	hud.visible = true
	panel.visible = true
	hud.set("qa_preview_state", true)
	ctx.log("after hud_layout=%s panel_layout=%s hud_visible=%s panel_visible=%s" % [str(hud.get("layout_mode")), str(panel.get("layout_mode")), str(hud.visible), str(panel.visible)])
	ctx.mark_modified()
