@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root := Node3D.new()
		new_root.name = "HologramFlag"
		ctx.set_scene_root(new_root)
		root = new_root
	var script: Script = load("res://scripts/hologram_flag.gd") as Script
	if script == null:
		ctx.error("Missing hologram flag script")
		return
	root.set_script(script)
	ctx.log("Configured HologramFlag root with script")
	ctx.mark_modified()
