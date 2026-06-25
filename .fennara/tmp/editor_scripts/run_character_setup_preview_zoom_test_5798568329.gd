@tool
extends RefCounted

func run(ctx) -> void:
	var packed: PackedScene = load("res://assets/characters/party_monster/party_monster_skin.tscn") as PackedScene
	if packed == null:
		ctx.error("missing party monster skin scene")
		return
	var model: Node3D = packed.instantiate() as Node3D
	if model == null:
		ctx.error("could not instantiate party monster skin")
		return
	if model.has_method("set_character_model_id"):
		model.call("set_character_model_id", "party_monster_c01")
	if model.has_method("idle"):
		model.call("idle")
	if model.has_method("set_animation_paused"):
		model.call("set_animation_paused", true)
	var samples: Array[String] = []
	var min_y: float = 999999.0
	var max_y: float = -999999.0
	_collect_visual_bounds(model, model, samples, min_y, max_y)
	ctx.log("model_bounds_y min=%s max=%s samples=%s" % [str(min_y), str(max_y), str(samples)])
	model.free()

func _collect_visual_bounds(root_model: Node3D, node: Node, samples: Array[String], min_y: float, max_y: float) -> void:
	if node is VisualInstance3D:
		var visual: VisualInstance3D = node as VisualInstance3D
		if visual.visible:
			var box: AABB = visual.get_aabb()
			if box.size.length_squared() > 0.0001:
				var relative_transform: Transform3D = root_model.global_transform.affine_inverse() * visual.global_transform
				var transformed: AABB = _transform_aabb(box, relative_transform)
				if transformed.position.y < min_y:
					min_y = transformed.position.y
				if transformed.position.y + transformed.size.y > max_y:
					max_y = transformed.position.y + transformed.size.y
				if samples.size() < 12:
					samples.append("%s y=%s..%s" % [String(visual.name), str(transformed.position.y), str(transformed.position.y + transformed.size.y)])
	for child: Node in node.get_children():
		_collect_visual_bounds(root_model, child, samples, min_y, max_y)

func _transform_aabb(box: AABB, xform: Transform3D) -> AABB:
	var base: Vector3 = box.position
	var box_size: Vector3 = box.size
	var points: Array[Vector3] = [
		base,
		base + Vector3(box_size.x, 0.0, 0.0),
		base + Vector3(0.0, box_size.y, 0.0),
		base + Vector3(0.0, 0.0, box_size.z),
		base + Vector3(box_size.x, box_size.y, 0.0),
		base + Vector3(box_size.x, 0.0, box_size.z),
		base + Vector3(0.0, box_size.y, box_size.z),
		base + box_size,
	]
	var min_point: Vector3 = xform * points[0]
	var max_point: Vector3 = min_point
	for i: int in range(1, points.size()):
		var point: Vector3 = xform * points[i]
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		min_point.z = minf(min_point.z, point.z)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
		max_point.z = maxf(max_point.z, point.z)
	return AABB(min_point, max_point - min_point)
