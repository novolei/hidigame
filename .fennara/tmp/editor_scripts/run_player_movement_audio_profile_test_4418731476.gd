@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node = Node.new()
		new_root.name = "PlayerMovementAudioProfileTest"
		ctx.set_scene_root(new_root)
		root = new_root
	root.set_script(load("res://tests/player_movement_audio_profile_test.gd"))
	ctx.log("Attached player_movement_audio_profile_test.gd to root")
	ctx.mark_modified()
