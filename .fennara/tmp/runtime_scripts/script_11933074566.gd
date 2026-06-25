extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root_null")
		ctx.close_scene()
		return
	ctx.log("root=%s class=%s" % [String(root.name), root.get_class()])

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

	var overlay_variant: Variant = overlay_script.new()
	var overlay: Control = overlay_variant as Control
	if overlay == null:
		ctx.log("overlay_create_failed")
		ctx.close_scene()
		return
	overlay.name = "CharacterSetupOverlayVisualProbe"
	hud.add_child(overlay)

	overlay.call("set_remaining", 20.0)
	overlay.visible = true
	overlay.set_process(true)
	overlay.call("_fit_to_viewport")
	overlay.call("_populate_skins")
	overlay.call("_select_skin", CharacterSkinCatalog.party_monster_default_id(), false)
	overlay.call("_update_text")

	await ctx.wait(1.0)
	await ctx.capture("skin_config_refined_ui")
	ctx.log("capture_done")
	ctx.close_scene()
