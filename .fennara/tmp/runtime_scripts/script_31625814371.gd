extends RefCounted

const LevelLayout := preload("res://scripts/level_layout_config.gd")

func run(ctx: Variant) -> void:
	await ctx.wait(0.2)
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root_missing")
		ctx.close_scene()
		return
	ctx.log("root_name=%s class=%s" % [String(root.name), root.get_class()])
	var generated: Node3D = root.get_node_or_null("GeneratedPolygonApocalypseMap") as Node3D
	if generated == null:
		ctx.log("generated_missing")
		ctx.close_scene()
		return
	var layout: Node3D = generated.get_node_or_null("PolygonApocalypseLayout") as Node3D
	var support: StaticBody3D = generated.get_node_or_null("PolygonApocalypseGameplaySupport") as StaticBody3D
	if layout == null:
		ctx.log("layout_missing")
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
	if layout != null:
		ctx.log("layout_global=%s child_count=%d" % [str(layout.global_position), layout.get_child_count()])
	ctx.log("support_global=%s size=%s layer=%d" % [str(support.global_position), str(shape.size), int(support.collision_layer)])
	var outside: int = 0
	var prop_ids: Array = [101, 102, 103, 104, 105, 106]
	for prop_id in prop_ids:
		var prop_spawn: Vector3 = LevelLayout.prop_spawn_point(int(prop_id), prop_ids)
		if not _inside_support(prop_spawn, support, shape):
			outside += 1
			ctx.log("outside_prop_spawn=%s" % str(prop_spawn))
	for release_index in range(6):
		var hunter_release: Vector3 = LevelLayout.hunter_release_point(release_index, 6)
		if not _inside_support(hunter_release, support, shape):
			outside += 1
			ctx.log("outside_hunter_release=%s" % str(hunter_release))
	ctx.log("spawn_support_outside_count=%d" % outside)
	ctx.close_scene()

func _inside_support(point: Vector3, support: StaticBody3D, shape: BoxShape3D) -> bool:
	var half_x: float = shape.size.x * 0.5
	var half_z: float = shape.size.z * 0.5
	return point.x >= support.global_position.x - half_x and point.x <= support.global_position.x + half_x and point.z >= support.global_position.z - half_z and point.z <= support.global_position.z + half_z
