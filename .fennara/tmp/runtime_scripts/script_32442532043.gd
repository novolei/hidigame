extends RefCounted

const LevelLayout = preload("res://scripts/level_layout_config.gd")

func run(ctx: Variant) -> void:
	await ctx.wait(0.5)
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root_missing")
		ctx.close_scene()
		return
	var config_value: Variant = Network.get("lobby_config")
	if config_value is Dictionary:
		var config: Dictionary = config_value as Dictionary
		config["map"] = "Polygon Apocalypse City: Quarantine Crossing"
		Network.set("lobby_config", config)
		ctx.log("selected_map=%s" % String(config.get("map", "")))
	else:
		ctx.log("lobby_config_missing")
	if root.has_method("_apply_selected_map_scene"):
		root.call("_apply_selected_map_scene")
	else:
		ctx.log("apply_selected_map_missing")
	await ctx.wait(0.35)
	var support: StaticBody3D = root.get_node_or_null("Environment/TankDemoMapRoot/GeneratedPolygonApocalypseMap/PolygonApocalypseGameplaySupport") as StaticBody3D
	if support == null:
		ctx.log("support_missing")
		ctx.close_scene()
		return
	var shape_node: CollisionShape3D = support.get_node_or_null("GameplaySupportShape") as CollisionShape3D
	if shape_node == null or not shape_node.shape is BoxShape3D:
		ctx.log("support_shape_missing")
		ctx.close_scene()
		return
	var shape: BoxShape3D = shape_node.shape as BoxShape3D
	var support_top_y: float = support.global_position.y + shape.size.y * 0.5
	var support_min_x: float = support.global_position.x - shape.size.x * 0.5
	var support_max_x: float = support.global_position.x + shape.size.x * 0.5
	var support_min_z: float = support.global_position.z - shape.size.z * 0.5
	var support_max_z: float = support.global_position.z + shape.size.z * 0.5
	ctx.log("support_global=%s size=%s top_y=%.3f layer=%d" % [str(support.global_position), str(shape.size), support_top_y, support.collision_layer])
	var prop_ids: Array[int] = []
	for prop_id: int in range(1, 25):
		prop_ids.append(prop_id)
	var sample_points: Array[Vector3] = []
	for prop_id: int in prop_ids:
		sample_points.append(LevelLayout.prop_spawn_point(prop_id, prop_ids))
	for hunter_id: int in range(0, 8):
		sample_points.append(LevelLayout.hunter_release_point(hunter_id, 8))
	sample_points.append(LevelLayout.random_default_spawn_point())
	var outside_count: int = 0
	var bad_ground_count: int = 0
	var min_ground_y: float = 99999.0
	var max_ground_y: float = -99999.0
	var samples: Array[String] = []
	for index: int in range(sample_points.size()):
		var point: Vector3 = sample_points[index]
		var inside_x: bool = point.x >= support_min_x and point.x <= support_max_x
		var inside_z: bool = point.z >= support_min_z and point.z <= support_max_z
		if not inside_x or not inside_z:
			outside_count += 1
		var grounded: Vector3 = root.call("get_grounded_spawn_position", point) as Vector3
		min_ground_y = min(min_ground_y, grounded.y)
		max_ground_y = max(max_ground_y, grounded.y)
		if abs(grounded.y - support_top_y) > 0.05:
			bad_ground_count += 1
		if samples.size() < 8:
			samples.append("%d:%s->%s" % [index, str(point), str(grounded)])
	ctx.log("spawn_sample_count=%d outside_count=%d bad_ground_count=%d min_y=%.3f max_y=%.3f" % [sample_points.size(), outside_count, bad_ground_count, min_ground_y, max_ground_y])
	ctx.log("spawn_samples=%s" % " | ".join(samples))
	ctx.close_scene()
