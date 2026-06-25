extends SceneTree

var _initialized := false
var _bounds := AABB()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://assets/characters/party_monster/party_monster_skin.tscn") as PackedScene
	if scene == null:
		push_error("Party Monster scene did not load")
		quit(1)
		return
	var skin: Node3D = scene.instantiate() as Node3D
	if skin == null:
		push_error("Party Monster scene did not instantiate as Node3D")
		quit(1)
		return
	root.add_child(skin)
	if skin.has_method("set_character_model_id"):
		skin.call("set_character_model_id", "party_monster_c01")
	print("[PartyMonsterOriginProbe] before_build child_count=%d bounds=%s" % [skin.get_child_count(), _bounds_text(skin)])
	if skin.has_method("apply_pose_now"):
		skin.call("apply_pose_now", 0.0)
	else:
		if skin.has_method("idle"):
			skin.call("idle")
	await process_frame
	print("[PartyMonsterOriginProbe] after_build child_count=%d bounds=%s" % [skin.get_child_count(), _bounds_text(skin)])
	for child in skin.get_children():
		if child is Node3D:
			var child3d: Node3D = child as Node3D
			print("[PartyMonsterOriginProbe] child %s position=%s scale=%s" % [child3d.name, child3d.position, child3d.scale])
	quit(0)


func _bounds_text(root_node: Node3D) -> String:
	_initialized = false
	_bounds = AABB()
	_accumulate(root_node, root_node, Transform3D.IDENTITY)
	if not _initialized:
		return "none"
	var center: Vector3 = _bounds.position + (_bounds.size * 0.5)
	return "pos=%s size=%s center=%s bottom=%.4f" % [_bounds.position, _bounds.size, center, _bounds.position.y]


func _accumulate(root_node: Node3D, node: Node, parent_transform: Transform3D) -> void:
	var local_transform: Transform3D = parent_transform
	if node is Node3D and node != root_node:
		local_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.visible:
			var box: AABB = _transform_aabb(mesh_instance.mesh.get_aabb(), local_transform)
			if _initialized:
				_bounds = _bounds.merge(box)
			else:
				_bounds = box
				_initialized = true
	for child in node.get_children():
		_accumulate(root_node, child, local_transform)


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
	for i in range(1, points.size()):
		var point: Vector3 = xform * points[i]
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		min_point.z = minf(min_point.z, point.z)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
		max_point.z = maxf(max_point.z, point.z)
	return AABB(min_point, max_point - min_point)
