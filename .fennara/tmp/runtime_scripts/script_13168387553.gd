extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root=null")
		ctx.close_scene()
		return
	var overlay_script: Script = load("res://scripts/character_setup_overlay.gd") as Script
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "SkinOverlayProbeLayer"
	layer.layer = 90
	root.add_child(layer)
	var overlay: Control = overlay_script.new() as Control
	overlay.name = "CharacterSetupOverlayProbe"
	layer.add_child(overlay)
	await ctx.wait(0.45)
	overlay.call("show_setup", 17.0)
	await ctx.wait(0.90)
	overlay.call("_fit_to_viewport")
	await ctx.wait(0.45)
	var preview_model: Node3D = overlay.get("_preview_model") as Node3D
	if preview_model != null:
		ctx.log("preview_model position=%s scale=%s" % [str(preview_model.position), str(preview_model.scale)])
	await ctx.capture("skin_config_platform_stand_fix")
	ctx.close_scene()
