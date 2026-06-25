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
	var panel: Control = hud.get_node_or_null("HuntPanel") as Control
	if panel == null:
		ctx.error("HuntPanel not found")
		return
	ctx.log("before hud_left=%s hud_right=%s" % [str(hud.offset_left), str(hud.offset_right)])
	hud.set("layout_mode", 0)
	hud.anchor_left = 0.0
	hud.anchor_right = 0.0
	hud.anchor_top = 0.0
	hud.anchor_bottom = 0.0
	hud.offset_left = 902.0
	hud.offset_top = 118.0
	hud.offset_right = 1262.0
	hud.offset_bottom = 296.0
	hud.visible = true
	hud.set("qa_preview_state", true)
	panel.set("layout_mode", 1)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.visible = true
	ctx.log("after hud_left=%s hud_right=%s panel_right_anchor=%s" % [str(hud.offset_left), str(hud.offset_right), str(panel.anchor_right)])
	ctx.mark_modified()
