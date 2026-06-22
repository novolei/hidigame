extends Node3D

const MAP_SCENE := "res://scenes/level/maps/japanese_town_street.tscn"
const PROBE_Y_TOP := 10.0
const PROBE_Y_BOTTOM := -50.0
const SPAWN_POINTS := [
	Vector3.ZERO,
	Vector3(10.0, 0.0, 0.0),
	Vector3(-10.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 10.0),
	Vector3(0.0, 0.0, -10.0),
	Vector3(7.071, 0.0, 7.071),
	Vector3(-7.071, 0.0, 7.071),
	Vector3(7.071, 0.0, -7.071),
	Vector3(-7.071, 0.0, -7.071),
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var packed := load(MAP_SCENE)
	if not packed is PackedScene:
		push_error("[JapaneseTownAlignmentTest] Map did not load")
		get_tree().quit(1)
		return

	var map := (packed as PackedScene).instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var visual_root := map.get_node_or_null("JapaneseTownStreet") as Node3D
	if not visual_root:
		failures.append("Japanese Town visual root is missing")
	else:
		var bounds := _calculate_bounds(visual_root)
		if bounds.size.x < 35.0 or bounds.size.x > 90.0:
			failures.append("Japanese Town width should be gameplay-sized, got " + str(bounds.size.x))
		if bounds.size.z < 50.0 or bounds.size.z > 120.0:
			failures.append("Japanese Town depth should be gameplay-sized, got " + str(bounds.size.z))

	var collision_root := map.get_node_or_null("ImportedCollisionRoot")
	if not collision_root:
		failures.append("Japanese Town collision root is missing")
	else:
		var shape_count := _count_collision_shapes(collision_root)
		if shape_count <= 0:
			failures.append("Japanese Town should generate gameplay collision")
		elif shape_count > 8:
			failures.append("Japanese Town should use simplified collision, got " + str(shape_count) + " shapes")
		if not collision_root.get_node_or_null("ImportedFlatGameplayFloor"):
			failures.append("Japanese Town should include a flat gameplay floor to prevent snagging")

	var space := get_world_3d().direct_space_state
	var heights: Array[float] = []
	for spawn in SPAWN_POINTS:
		var from := Vector3(spawn.x, PROBE_Y_TOP, spawn.z)
		var to := Vector3(spawn.x, PROBE_Y_BOTTOM, spawn.z)
		var query := PhysicsRayQueryParameters3D.create(from, to, 2)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			failures.append("No walkable collision under spawn probe " + str(spawn))
			continue
		var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
		heights.append(hit_position.y)
		if absf(hit_position.y) > 10.0:
			failures.append("Spawn probe " + str(spawn) + " hits y=" + str(hit_position.y) + ", expected within playable spawn snap range")

	if failures.is_empty():
		print("[JapaneseTownAlignmentTest] PASS heights=", heights)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[JapaneseTownAlignmentTest] " + failure)
		get_tree().quit(1)


func _calculate_bounds(root: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		var transformed := _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = transformed
			has_bounds = true
		else:
			bounds = bounds.merge(transformed)
	return bounds if has_bounds else AABB()


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, result)


func _transform_aabb(transform: Transform3D, box: AABB) -> AABB:
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var point := box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed := transform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)


func _count_collision_shapes(node: Node) -> int:
	var count := 0
	if node is CollisionShape3D and (node as CollisionShape3D).shape:
		count += 1
	for child in node.get_children():
		count += _count_collision_shapes(child)
	return count
