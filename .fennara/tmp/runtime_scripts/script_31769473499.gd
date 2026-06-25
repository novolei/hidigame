extends RefCounted

const LevelLayout := preload("res://scripts/level_layout_config.gd")

func run(ctx: Variant) -> void:
	await ctx.wait(0.2)
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root_missing")
		ctx.close_scene()
		return
	Network.lobby_config["map"] = "Polygon Apocalypse City: Quarantine Crossing"
	if root.has_method("_apply_selected_map_scene"):
		root.call("_apply_selected_map_scene")
	await ctx.wait(0.5)
	var mounted: Node3D = root.get_node_or_null("Environment/TankDemoMapRoot") as Node3D
	if mounted == null:
		ctx.log("mounted_missing")
		ctx.close_scene()
		return
	var generated: Node3D = mounted.get_node_or_null("GeneratedPolygonApocalypseMap") as Node3D
	var support: StaticBody3D = mounted.get_node_or_null("GeneratedPolygonApocalypseMap/PolygonApocalypseGameplaySupport") as StaticBody3D
	if generated == null or support == null:
		ctx.log("generated_or_support_missing generated=%s support=%s" % [str(generated), str(support)])
		ctx.close_scene()
		return
	var shape_node: CollisionShape3D = support.get_node_or_null("GameplaySupportShape") as CollisionShape3D
	if shape_node == null or not shape_node.shape is BoxShape3D:
		ctx.log("support_shape_missing")
		ctx.close_scene()
		return
	var shape: BoxShape3D = shape_node.shape as BoxShape3D
	ctx.log("mounted_support_global=%s size=%s layer=%d" % [str(support.global_position), str(shape.size), int(support.collision_layer)])
	var sample_points: Array[Vector3] = []
	var prop_ids: Array = [101, 102, 103, 104, 105, 106]
	for prop_id in prop_ids:
		sample_points.append(LevelLayout.prop_spawn_point(int(prop_id), prop_ids))
	for release_index in range(6):
		sample_points.append(LevelLayout.hunter_release_point(release_index, 6))
	var miss_count: int = 0
	var outside_count: int = 0
	for point in sample_points:
		if not _inside_support(point, support, shape):
			outside_count += 1
		var hit_y: float = _ray_hit_y(root as Node3D, point)
		if hit_y < -999.0:
			miss_count += 1
			ctx.log("ray_miss_at=%s" % str(point))
		else:
			ctx.log("ray_hit_at=%s y=%.3f" % [str(point), hit_y])
	ctx.log("support_outside_count=%d ray_miss_count=%d" % [outside_count, miss_count])
	ctx.close_scene()

func _inside_support(point: Vector3, support: StaticBody3D, shape: BoxShape3D) -> bool:
	var half_x: float = shape.size.x * 0.5
	var half_z: float = shape.size.z * 0.5
	return point.x >= support.global_position.x - half_x and point.x <= support.global_position.x + half_x and point.z >= support.global_position.z - half_z and point.z <= support.global_position.z + half_z

func _ray_hit_y(root: Node3D, point: Vector3) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 20.0, point + Vector3.DOWN * 20.0, 2)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1000.0
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	return hit_position.y
