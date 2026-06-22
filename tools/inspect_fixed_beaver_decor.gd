extends SceneTree


const LEVEL_SCENE := "res://level/level.tscn"
const BEAVER_PATH := "Map/FixedDecorations/FixedDecor_CozyBeaver"


func _init() -> void:
	var scene := load(LEVEL_SCENE)
	if not scene is PackedScene:
		push_error("Could not load %s" % LEVEL_SCENE)
		quit(1)
		return

	var root := (scene as PackedScene).instantiate()
	var node := root.get_node_or_null(BEAVER_PATH)
	if not node:
		push_error("Missing fixed beaver decoration at %s" % BEAVER_PATH)
		root.free()
		quit(1)
		return

	print("[FixedBeaverDecorTest] found=%s parent=%s position=%s" % [node.name, node.get_parent().name, str((node as Node3D).position)])
	root.free()
	quit(0)
