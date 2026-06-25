@tool
extends RefCounted

func run(ctx) -> void:
	var scene: PackedScene = load("res://scenes/level/player.tscn") as PackedScene
	if scene == null:
		ctx.error("Player scene failed to load")
		return
	var player: Node3D = scene.instantiate() as Node3D
	if player == null:
		ctx.error("Player scene did not instantiate as Node3D")
		return
	player.name = "MeasuredPlayer"
	var body: Node3D = player.get_node_or_null("3DGodotRobot") as Node3D
	var collision: CollisionShape3D = player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision.shape as CapsuleShape3D
		var capsule_bottom: float = collision.position.y - capsule.height * 0.5
		ctx.log("collision bottom=%.4f center_y=%.4f height=%.4f" % [capsule_bottom, collision.position.y, capsule.height])
	if body != null:
		_log_bounds(ctx, body, "default_body_visual_in_player")
	var custom: Node3D = null
	if body != null:
		var skin_scene: PackedScene = load("res://assets/characters/party_monster/party_monster_skin.tscn") as PackedScene
		if skin_scene != null:
			custom = skin_scene.instantiate() as Node3D
			if custom != null:
				custom.name = "CustomCharacterSkin"
				if custom.has_method("set_character_model_id"):
					custom.call("set_character_model_id", "party_monster_c01")
				if custom.has_method("_build_skin"):
					custom.call("_build_skin")
				if custom.has_method("idle"):
					custom.call("idle")
				_advance_animation_players(custom, 0.18)
				var catalog_model := CharacterSkinCatalog.get_model("party_monster_c01")
				custom.scale = catalog_model.get("scale", Vector3(0.82, 0.82, 0.82))
				custom.position = catalog_model.get("offset", Vector3.ZERO)
				body.add_child(custom)
	if custom != null:
		_log_bounds(ctx, custom, "custom_skin_local")
		_log_bounds(ctx, body, "body_with_custom_skin")
		ctx.log("custom local position=%s scale=%s" % [str(custom.position), str(custom.scale)])
	else:
		ctx.log("custom skin missing")
	player.free()

func _advance_animation_players(node: Node, seconds: float) -> void:
	if node is AnimationPlayer:
		var player: AnimationPlayer = node as AnimationPlayer
		player.advance(seconds)
	for child: Node in node.get_children():
		_advance_animation_players(child, seconds)

func _log_bounds(ctx, root: Node3D, label: String) -> void:
	var bounds_data: Array = [false, AABB()]
	_accumulate_visible_bounds(root, Transform3D.IDENTITY, bounds_data)
	if not bool(bounds_data[0]):
		ctx.log("%s no_visible_bounds" % label)
		return
	var bounds: AABB = bounds_data[1] as AABB
	ctx.log("%s bottom=%.4f height=%.4f center_y=%.4f center_z=%.4f" % [label, bounds.position.y, bounds.size.y, bounds.get_center().y, bounds.get_center().z])

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
