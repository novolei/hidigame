@tool
extends RefCounted

func run(ctx) -> void:
	var scene: PackedScene = load("res://assets/characters/party_monster/party_monster_skin.tscn") as PackedScene
	if scene == null:
		ctx.error("Party Monster scene failed to load")
		return
	var skin: Node3D = scene.instantiate() as Node3D
	if skin == null:
		ctx.error("Party Monster scene did not instantiate")
		return
	skin.name = "LowestMeshProbe"
	if skin.has_method("set_character_model_id"):
		skin.call("set_character_model_id", "party_monster_c01")
	if skin.has_method("_build_skin"):
		skin.call("_build_skin")
	if skin.has_method("idle"):
		skin.call("idle")
	_advance_animation_players(skin, 0.18)
	var rows: Array[Dictionary] = []
	_collect_mesh_bottoms(skin, Transform3D.IDENTITY, rows)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("bottom", 0.0)) < float(b.get("bottom", 0.0))
	)
	var limit: int = mini(18, rows.size())
	for i: int in range(limit):
		var row: Dictionary = rows[i]
		ctx.log("rank=%02d name=%s bottom=%.4f height=%.4f center_z=%.4f" % [i + 1, str(row.get("name", "")), float(row.get("bottom", 0.0)), float(row.get("height", 0.0)), float(row.get("center_z", 0.0))])
	skin.free()

func _advance_animation_players(node: Node, seconds: float) -> void:
	if node is AnimationPlayer:
		var player: AnimationPlayer = node as AnimationPlayer
		player.advance(seconds)
	for child: Node in node.get_children():
		_advance_animation_players(child, seconds)

func _collect_mesh_bottoms(node: Node, parent_transform: Transform3D, rows: Array[Dictionary]) -> void:
	var node_transform: Transform3D = parent_transform
	if node is Node3D:
		var spatial: Node3D = node as Node3D
		node_transform = parent_transform * spatial.transform
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node.visible and mesh_node.mesh:
			var box: AABB = _transform_aabb(mesh_node.mesh.get_aabb(), node_transform)
			rows.append({
				"name": String(mesh_node.name),
				"bottom": box.position.y,
				"height": box.size.y,
				"center_z": box.get_center().z,
			})
	for child: Node in node.get_children():
		_collect_mesh_bottoms(child, node_transform, rows)

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
