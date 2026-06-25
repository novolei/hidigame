@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = Node.new()
	root.name = "CharacterSetupOverlayAlignmentProbe"
	var script_resource: Resource = load("res://.fennara/tmp/character_setup_overlay_alignment_scene.gd")
	if script_resource == null:
		ctx.error("Alignment scene script did not load")
		return
	root.set_script(script_resource)
	ctx.set_scene_root(root)
	ctx.log("Created overlay alignment runtime probe scene")
	ctx.mark_modified()
