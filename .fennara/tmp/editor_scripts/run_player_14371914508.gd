@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root_class=%s" % root.get_class())
	ctx.log("root_name=%s" % String(root.get_name()))

	var collision_node: Node = ctx.get_node_or_null("CollisionShape3D")
	var collision_bottom: float = 0.0
	if collision_node is CollisionShape3D:
		var cs: CollisionShape3D = collision_node as CollisionShape3D
		var capsule: CapsuleShape3D = cs.shape as CapsuleShape3D
		if capsule != null:
			collision_bottom = cs.position.y - (capsule.height * 0.5)
			ctx.log("collision_bottom_local=%.4f center_y=%.4f height=%.4f" % [collision_bottom, cs.position.y, capsule.height])
		else:
			ctx.log("collision shape was not a capsule")
	else:
		ctx.log("CollisionShape3D not found")

	var model_id: String = CharacterSkinCatalog.party_monster_default_id()
	var model: Dictionary = CharacterSkinCatalog.get_model(model_id)
	var scene_path: String = str(model.get("scene", ""))
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		ctx.error("Could not load Party Monster scene %s" % scene_path)
		return
	var skin: Node3D = packed.instantiate() as Node3D
	if skin == null:
		ctx.error("Could not instantiate Party Monster skin")
		return
	if skin.has_method("set_character_model_id"):
		skin.call("set_character_model_id", model_id)
	skin.scale = model.get("scale", Vector3.ONE)
	skin.position = model.get("offset", Vector3.ZERO)
	if skin.has_method("idle"):
		skin.call("idle")

	var bounds: Array = [false, AABB()]
	_accumulate_visual_bounds(skin, skin.transform, bounds)
	if bool(bounds[0]):
		var box: AABB = bounds[1] as AABB
		var visual_bottom: float = box.position.y
		ctx.log("party_model_id=%s" % model_id)
		ctx.log("party_catalog_offset=%s scale=%s" % [str(skin.position), str(skin.scale)])
		ctx.log("party_visual_bottom_local=%.4f visual_height=%.4f" % [visual_bottom, box.size.y])
		ctx.log("visual_minus_collision_bottom=%.4f" % (visual_bottom - collision_bottom))
	else:
		ctx.log("No visible Party Monster bounds found")
	skin.free()


func _accumulate_visual_bounds(node: Node, parent_transform: Transform3D, bounds: Array) -> void:
	var current_transform: Transform3D = parent_transform
	if node is VisualInstance3D:
		var visual: VisualInstance3D = node as VisualInstance3D
		if visual.visible:
			var local_aabb: AABB = visual.get_aabb()
			if local_aabb.size.length_squared() > 0.0001:
				var transformed: AABB = _transform_aabb(local_aabb, current_transform)
				if bool(bounds[0]):
					bounds[1] = (bounds[1] as AABB).merge(transformed)
				else:
					bounds[1] = transformed
					bounds[0] = true
	for child_node in node.get_children():
		var child_transform: Transform3D = current_transform
		if child_node is Node3D:
			var child_3d: Node3D = child_node as Node3D
			child_transform = current_transform * child_3d.transform
		_accumulate_visual_bounds(child_node, child_transform, bounds)


func _transform_aabb(box: AABB, xform: Transform3D) -> AABB:
	var base: Vector3 = box.position
	var size: Vector3 = box.size
	var points: Array[Vector3] = [
		base,
		base + Vector3(size.x, 0.0, 0.0),
		base + Vector3(0.0, size.y, 0.0),
		base + Vector3(0.0, 0.0, size.z),
		base + Vector3(size.x, size.y, 0.0),
		base + Vector3(size.x, 0.0, size.z),
		base + Vector3(0.0, size.y, size.z),
		base + size,
	]
	var first: Vector3 = xform * points[0]
	var min_point: Vector3 = first
	var max_point: Vector3 = first
	for index: int in range(1, points.size()):
		var point: Vector3 = xform * points[index]
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		min_point.z = minf(min_point.z, point.z)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
		max_point.z = maxf(max_point.z, point.z)
	return AABB(min_point, max_point - min_point)
