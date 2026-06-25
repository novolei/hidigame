extends SceneTree

const EFFECT_SCRIPT := preload("res://scripts/hovl_projectile_effect.gd")


func _init() -> void:
	var errors: Array[String] = []
	_save_single_effect_scene(errors)
	_save_gallery_scene(errors)
	if errors.is_empty():
		print("[HovlProjectileSceneBuilder] PASS")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		quit(1)


func _save_single_effect_scene(errors: Array[String]) -> void:
	var effect := EFFECT_SCRIPT.new() as HovlProjectileEffect
	effect.name = "HovlProjectileEffect"
	effect.effect_id = HovlProjectileEffect.DEFAULT_EFFECT_ID
	effect.travel_distance = 6.0
	effect.travel_seconds = 0.65
	effect.autoplay = true
	effect.loop_preview = true
	effect.rebuild()
	_own_descendants(effect, effect)
	_save_scene(effect, "res://scenes/effects/hovl_projectile_effect.tscn", errors)


func _save_gallery_scene(errors: Array[String]) -> void:
	var scene_root := Node3D.new()
	scene_root.name = "HovlProjectileEffectGallery"

	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.light_energy = 2.2
	light.rotation_degrees = Vector3(-48.0, 36.0, 0.0)
	scene_root.add_child(light)
	light.owner = scene_root

	var camera := Camera3D.new()
	camera.name = "GalleryCamera"
	camera.position = Vector3(0.0, 7.8, 12.0)
	camera.rotation_degrees = Vector3(-34.0, 0.0, 0.0)
	camera.current = true
	scene_root.add_child(camera)
	camera.owner = scene_root

	var ids := HovlProjectileEffect.effect_ids()
	for index in range(ids.size()):
		var effect := EFFECT_SCRIPT.new() as HovlProjectileEffect
		effect.name = "Effect_%02d_%s" % [index + 1, ids[index].replace("projectile_", "")]
		effect.effect_id = ids[index]
		effect.travel_distance = 2.2
		effect.travel_seconds = 0.8
		effect.autoplay = true
		effect.loop_preview = true
		var column := index % 5
		var row := floori(float(index) / 5.0)
		effect.position = Vector3(float(column - 2) * 2.4, float(2 - row) * 1.5, 0.0)
		scene_root.add_child(effect)
		effect.owner = scene_root
		effect.rebuild()
		_own_descendants(effect, scene_root)

	_save_scene(scene_root, "res://scenes/effects/hovl_projectile_effect_gallery.tscn", errors)


func _own_descendants(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		_own_descendants(child, scene_owner)


func _save_scene(scene_root: Node, path: String, errors: Array[String]) -> void:
	var packed := PackedScene.new()
	var pack_error := packed.pack(scene_root)
	if pack_error != OK:
		errors.append("Could not pack %s: %s" % [path, error_string(pack_error)])
		return
	var save_error := ResourceSaver.save(packed, path)
	if save_error != OK:
		errors.append("Could not save %s: %s" % [path, error_string(save_error)])
