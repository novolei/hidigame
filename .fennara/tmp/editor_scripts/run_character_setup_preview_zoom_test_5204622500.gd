@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = Node.new()
	root.name = "CharacterSetupPreviewZoomTest"
	var script: Script = load("res://tests/character_setup_preview_zoom_test.gd") as Script
	if script == null:
		ctx.error("Missing character setup preview zoom test script")
		return
	root.set_script(script)
	ctx.set_scene_root(root)
	ctx.mark_modified()
	ctx.log("Created character setup preview zoom test scene")
