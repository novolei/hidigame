@tool
extends RefCounted

const LevelLayout := preload("res://scripts/level_layout_config.gd")

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root_name=%s class=%s" % [String(root.name), root.get_class()])
	if root.has_method("build"):
		root.call("build")
	var generated: Node3D = root.get_node_or_null("GeneratedPolygonApocalypseMap") as Node3D
	if generated == null:
		ctx.error("GeneratedPolygonApocalypseMap missing")
		return
	var layout: Node3D = generated.get_node_or_null("PolygonApocalypseLayout") as Node3D
	if layout == null:
		ctx.error("PolygonApocalypseLayout missing")
		return
	var support: StaticBody3D = generated.get_node_or_null("PolygonApocalypseGameplaySupport") as StaticBody3D
	if support == null:
		ctx.error("PolygonApocalypseGameplaySupport missing")
		return
	var shape_node: CollisionShape3D = support.get_node_or_null("GameplaySupportShape") as CollisionShape3D
	if shape_node == null or not shape_node.shape is BoxShape3D:
		ctx.error("GameplaySupportShape missing or not BoxShape3D")
		return
	var shape: BoxShape3D = shape_node.shape as BoxShape3D
	ctx.log("layout_global=%s" % str(layout.global_position))
	ctx.log("support_global=%s size=%s layer=%d" % [str(support.global_position), str(shape.size), int(support.collision_layer)])
	var prop_ids: Array = [101, 102, 103, 104, 105, 106]
	var outside: int = 0
	for prop_id in prop_ids:
		var point: Vector3 = LevelLayout.prop_spawn_point(int(prop_id), prop_ids)
		if not _inside_support(point, support, shape):
			outside += 1
			ctx.log("outside_prop_spawn=%s" % str(point))
	for release_index in range(6):
		var release_point: Vector3 = LevelLayout.hunter_release_point(release_index, 6)
		if not _inside_support(release_point, support, shape):
			outside += 1
			ctx.log("outside_hunter_release=%s" % str(release_point))
	ctx.log("spawn_support_outside_count=%d" % outside)

func _inside_support(point: Vector3, support: StaticBody3D, shape: BoxShape3D) -> bool:
	var half_x: float = shape.size.x * 0.5
	var half_z: float = shape.size.z * 0.5
	return point.x >= support.global_position.x - half_x and point.x <= support.global_position.x + half_x and point.z >= support.global_position.z - half_z and point.z <= support.global_position.z + half_z
