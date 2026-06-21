extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	for model in CharacterSkinCatalog.all():
		var model_id := str(model.get("id", ""))
		var scene_path := str(model.get("scene", ""))
		if scene_path.is_empty():
			continue
		var scene := load(scene_path)
		if not scene is PackedScene:
			failures.append("Model %s did not load as PackedScene: %s" % [model_id, scene_path])
			continue
		var node := (scene as PackedScene).instantiate()
		if not node is Node3D:
			failures.append("Model %s did not instantiate as Node3D" % model_id)
		if node:
			node.free()

	if failures.is_empty():
		print("[CharacterSkinCatalogTest] PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("[CharacterSkinCatalogTest] " + failure)
		quit(1)
