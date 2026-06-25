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
	await ctx.wait(0.25)
	var preview_model: Node3D = overlay.get("_preview_model") as Node3D
	if preview_model == null:
		ctx.log("preview_model=null")
		ctx.close_scene()
		return
	var base_position: Vector3 = preview_model.position
	ctx.log("base position=%s" % str(base_position))
	await ctx.capture("skin_platform_offset_000")
	preview_model.position = base_position + Vector3(0.0, -0.30, 0.0)
	ctx.log("offset -0.30 position=%s" % str(preview_model.position))
	await ctx.wait(0.10)
	await ctx.capture("skin_platform_offset_030")
	preview_model.position = base_position + Vector3(0.0, -0.48, 0.0)
	ctx.log("offset -0.48 position=%s" % str(preview_model.position))
	await ctx.wait(0.10)
	await ctx.capture("skin_platform_offset_048")
	ctx.close_scene()
