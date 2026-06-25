@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "PartyMonsterAccessorySystemTest"
		var test_script: Script = load("res://tests/party_monster_accessory_system_test.gd") as Script
		if test_script == null:
			ctx.error("Test script failed to load")
			return
		new_root.set_script(test_script)
		ctx.set_scene_root(new_root)
		ctx.log("Created PartyMonsterAccessorySystemTest root")
		ctx.mark_modified()
		return
	ctx.log("Scene already has root: %s" % String(root.name))