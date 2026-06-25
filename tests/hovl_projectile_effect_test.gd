extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var ids := HovlProjectileEffect.effect_ids()
	if ids.size() != 25:
		failures.append("Hovl projectile catalog should expose 25 projectile presets, got %d" % ids.size())

	var seen_source_prefabs := {}
	for effect_id in ids:
		var preset: Dictionary = HovlProjectileEffect.preset_for(effect_id)
		var source_prefab := str(preset.get("source_prefab", ""))
		if source_prefab.is_empty():
			failures.append("%s is missing source_prefab provenance" % effect_id)
		seen_source_prefabs[source_prefab] = true
		for texture_name_value in preset.get("textures", []):
			var texture_name := str(texture_name_value)
			if texture_name.ends_with(".png") and not FileAccess.file_exists("res://assets/effects/hovl_projectiles/textures/%s" % texture_name):
				failures.append("%s references missing texture %s" % [effect_id, texture_name])

		var effect := HovlProjectileEffect.new()
		effect.configure(effect_id, 3.0, 0.2)
		var summary: Dictionary = effect.source_summary()
		if str(summary.get("source_prefab", "")) != source_prefab:
			failures.append("%s source_summary did not preserve source prefab" % effect_id)
		if effect.get_child_count() <= 0:
			failures.append("%s did not build runtime visual children" % effect_id)
		effect.free()

	if seen_source_prefabs.size() != 25:
		failures.append("Hovl projectile catalog should map to 25 distinct source prefab names, got %d" % seen_source_prefabs.size())

	for scene_path in [
		"res://scenes/effects/hovl_projectile_effect.tscn",
		"res://scenes/effects/hovl_projectile_effect_gallery.tscn",
	]:
		var scene := load(scene_path)
		if not scene is PackedScene:
			failures.append("Hovl effect scene did not load as PackedScene: %s" % scene_path)
			continue
		var node := (scene as PackedScene).instantiate()
		if not node is Node3D:
			failures.append("Hovl effect scene did not instantiate as Node3D: %s" % scene_path)
		if node:
			node.free()

	if failures.is_empty():
		print("[HovlProjectileEffectTest] PASS")
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	quit(0)
