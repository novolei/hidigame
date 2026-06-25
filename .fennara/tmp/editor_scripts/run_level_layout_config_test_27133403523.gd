@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "LevelLayoutConfigTest"
		ctx.set_scene_root(new_root)
		root = new_root
		ctx.log("Created test scene root")
	if not root is Node3D:
		ctx.error("Test scene root must be Node3D")
		return
	var script_resource: Resource = load("res://tests/level_layout_config_test.gd")
	if script_resource == null:
		ctx.error("Failed to load level layout config test script")
		return
	root.set_script(script_resource)
	ctx.log("Attached level layout config test script")
	ctx.mark_modified()
