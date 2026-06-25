extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root_null")
		ctx.close_scene()
		return
	var hud: Node = root.get_node_or_null("HUDCanvas")
	if hud == null:
		var canvas := CanvasLayer.new()
		canvas.name = "VisualProbeHUD"
		root.add_child(canvas)
		hud = canvas
	var overlay_script: Script = load("res://scripts/character_setup_overlay.gd") as Script
	if overlay_script == null:
		ctx.log("overlay_script_missing")
		ctx.close_scene()
		return
	var overlay: Control = overlay_script.new() as Control
	if overlay == null:
		ctx.log("overlay_create_failed")
		ctx.close_scene()
		return
	overlay.name = "CharacterSetupOverlayVisualProbe"
	hud.add_child(overlay)
	overlay.call("show_setup", 20.0)
	overlay.call("_select_skin", CharacterSkinCatalog.party_monster_default_id(), false)
	overlay.call("_fit_to_viewport")
	await ctx.wait(2.0)
	await ctx.capture("skin_config_grounded_platform")
	ctx.log("capture_done")
	ctx.close_scene()
