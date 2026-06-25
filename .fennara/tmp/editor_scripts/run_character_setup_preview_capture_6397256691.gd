@tool
extends RefCounted

func run(ctx) -> void:
	var root: Control = Control.new()
	root.name = "CharacterSetupPreviewCapture"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var script_resource: Resource = load("res://.fennara/tmp/character_setup_preview_capture.gd")
	if script_resource == null:
		ctx.error("Capture script did not load")
		return
	root.set_script(script_resource)
	ctx.set_scene_root(root)
	ctx.log("Created runtime capture scene for CharacterSetupOverlay")
	ctx.mark_modified()
