extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root=null")
		ctx.close_scene()
		return
	ctx.log("root=%s/%s" % [root.get_class(), String(root.name)])
	if root.has_method("_ensure_character_setup_overlay"):
		root.call("_ensure_character_setup_overlay")
	await ctx.wait(0.30)
	var hud: Node = root.get_node_or_null("HUDCanvas")
	if hud == null:
		ctx.log("hud=missing")
		ctx.close_scene()
		return
	var overlay: Control = hud.get_node_or_null("CharacterSetupOverlay") as Control
	if overlay == null:
		ctx.log("overlay=missing")
		ctx.close_scene()
		return
	overlay.call("show_setup", 17.0)
	await ctx.wait(0.80)
	overlay.call("_fit_to_viewport")
	await ctx.wait(0.30)
	var viewport_size: Vector2 = overlay.get_viewport_rect().size
	var overlay_size: Vector2 = overlay.size
	var left_rail: Control = overlay.find_child("SkinRail", true, false) as Control
	var preview: Control = overlay.find_child("PreviewContainer", true, false) as Control
	var card_count: int = 0
	var grid: GridContainer = overlay.find_child("SkinGrid", true, false) as GridContainer
	if grid != null:
		card_count = grid.get_child_count()
	ctx.log("viewport=%s overlay_size=%s cards=%d" % [str(viewport_size), str(overlay_size), card_count])
	if left_rail != null:
		ctx.log("left_rail pos=%s size=%s" % [str(left_rail.position), str(left_rail.size)])
	if preview != null:
		ctx.log("preview pos=%s size=%s" % [str(preview.position), str(preview.size)])
	await ctx.capture("skin_config_responsive_final")
	ctx.close_scene()
