@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "HologramFlagTest"
		ctx.set_scene_root(new_root)
		root = new_root
		ctx.log("Created HologramFlagTest root")
	var script_resource: Script = load("res://tests/hologram_flag_test.gd") as Script
	if script_resource == null:
		ctx.error("Could not load hologram flag test script")
		return
	root.set_script(script_resource)
	ctx.log("Attached hologram flag test script")
	ctx.mark_modified()
