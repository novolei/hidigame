@tool
extends RefCounted

func run(ctx) -> void:
	var scene: PackedScene = load("res://assets/characters/party_monster/party_monster_skin.tscn") as PackedScene
	if scene == null:
		ctx.error("Party Monster skin scene failed to load")
		return
	var skin: Node3D = scene.instantiate() as Node3D
	if skin == null:
		ctx.error("Party Monster skin did not instantiate as Node3D")
		return
	skin.name = "MeasuredPartyMonsterSkin"
	if skin.has_method("set_character_model_id"):
		skin.call("set_character_model_id", "party_monster_c01")
	_log_bounds(ctx, skin, "after_set_model")
	var actions: Array[String] = ["idle", "move", "run", "jump"]
	for action_name: String in actions:
		if skin.has_method(action_name):
			skin.call(action_name)
			_advance_animation_players(skin, 0.18)
			_log_bounds(ctx, skin, action_name)
	skin.free()

func _log_bounds(ctx, root: Node3D, label: String) -> void:
	var bounds_data: Array = [false, AABB()]
	_accumulate_visible_bounds(root, Transform3D.IDENTITY, bounds_data)
	if not bool(bounds_data[0]):
		ctx.log("%s no_visible_bounds" % label)
		return
	var bounds: AABB = bounds_data[1] as AABB
	ctx.log("%s bottom=%.4f height=%.4f center=(%.4f, %.4f, %.4f)" % [label, bounds.position.y, bounds.size.y, bounds.get_center().x, bounds.get_center().y, bounds.get_center().z])

func _advance_animation_players(node: Node, seconds: float) -> void:
	if node is AnimationPlayer:
		var player: AnimationPlayer = node as AnimationPlayer
		player.advance(seconds)
	for child: Node in node.get_children():
		_advance_animation_players(child, seconds)

func _accumulate_visible_bounds(node: Node, parent_transform: Transform3D, bounds_data: Array) -> void:
	var node_transform: Transform3D = parent_transform
	if node is Node3D:
		var spatial: Node3D = node as Node3D
		node_transform = parent_transform * spatial.transform
	if node is VisualInstance3D and node is Node3D:
		var visual: VisualInstance3D = node as VisualInstance3D
		var visible_node: Node3D = node as Node3D
		if visible_node.visible:
			var local_aabb: AABB = visual.get_aabb()
			if local_aabb.size.length_squared() > 0.0001:
				var transformed: AABB = _transform_aabb(local_aabb, node_transform)
				if bool(bounds_data[0]):
					bounds_data[1] = (bounds_data[1] as AABB).merge(transformed)
				else:
					bounds_data[1] = transformed
					bounds_data[0] = true
	for child: Node in node.get_children():
		_accumulate_visible_bounds(child, node_transform, bounds_data)

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
	var first_point: Vector3 = xform * points[0]
	var min_point: Vector3 = first_point
	var max_point: Vector3 = first_point
	for i: int in range(1, points.size()):
		var point: Vector3 = xform * points[i]
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		min_point.z = minf(min_point.z, point.z)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
		max_point.z = maxf(max_point.z, point.z)
	return AABB(min_point, max_point - min_point)
