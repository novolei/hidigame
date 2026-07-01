extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	await _validate_headless_collision_only(failures)
	await _validate_tree_ground_projection(failures)

	if failures.is_empty():
		print("[VegetationControllerHeadlessTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[VegetationControllerHeadlessTest] " + failure)
		get_tree().quit(1)


func _validate_headless_collision_only(failures: Array[String]) -> void:
	var controller := VegetationController.new()
	controller.name = "VegetationControllerUnderTest"
	var test_profile := VegetationProfile.for_polygon_warehouse("city_urp", "warehouse_ward")
	test_profile.grass_instance_count = 128
	test_profile.tree_count = 7
	test_profile.tree_collision_enabled = true
	test_profile.build_visuals_in_headless = false
	test_profile.fallback_support_center = Vector3(12.0, 0.0, -9.0)
	test_profile.fallback_support_size = Vector2(80.0, 72.0)
	test_profile.fallback_support_top_y = -8.0
	controller.profile = test_profile
	controller.install_wait_frames = 2
	add_child(controller)

	for _frame in 8:
		await get_tree().process_frame

	var generated := controller.get_node_or_null("GeneratedVegetation")
	if generated == null:
		failures.append("headless collision mode should create GeneratedVegetation when tree collisions are enabled")
		return
	if generated.get_node_or_null("Grass") != null:
		failures.append("headless collision mode should not create visual grass")
	if generated.get_node_or_null("Trees") != null:
		failures.append("headless collision mode should not create visual trees")

	var collisions := generated.get_node_or_null("TreeCollisions")
	if collisions == null:
		failures.append("headless collision mode should create TreeCollisions")
		return
	if collisions.get_child_count() != test_profile.tree_count:
		failures.append("TreeCollisions count should equal deterministic tree count: %d != %d" % [collisions.get_child_count(), test_profile.tree_count])
		return

	for child in collisions.get_children():
		var body := child as StaticBody3D
		if body == null:
			failures.append("tree collision child should be StaticBody3D")
			return
		if body.collision_layer != VegetationController.WORLD_COLLISION_LAYER:
			failures.append("tree collision should use the configured world collision layer")
			return
		if body.collision_mask != 0:
			failures.append("tree collision mask should not query other bodies")
			return
		if not body.is_in_group("vegetation_tree_collision"):
			failures.append("tree collision should be tagged for inspection")
			return
		var shape_node := body.get_node_or_null("TreeTrunkShape") as CollisionShape3D
		if shape_node == null or shape_node.shape == null:
			failures.append("tree collision should own a trunk collision shape")
			return


func _validate_tree_ground_projection(failures: Array[String]) -> void:
	var host := Node3D.new()
	host.name = "VegetationProjectionHost"
	add_child(host)

	var generated_map := Node3D.new()
	generated_map.name = "GeneratedPolygonApocalypseMap"
	host.add_child(generated_map)
	_add_support_floor(generated_map, Vector2(42.0, 42.0), -8.0)
	_add_walkable_floor(generated_map, Vector3(46.0, 0.2, 46.0), 4.0)

	var controller := VegetationController.new()
	controller.name = "VegetationProjectionController"
	var test_profile := VegetationProfile.for_polygon_warehouse("city_urp", "warehouse_ward")
	test_profile.grass_instance_count = 0
	test_profile.tree_count = 5
	test_profile.tree_collision_enabled = true
	test_profile.build_visuals_in_headless = false
	test_profile.tree_min_scale = 1.0
	test_profile.tree_max_scale = 1.0
	controller.profile = test_profile
	controller.install_wait_frames = 2
	host.add_child(controller)

	for _frame in 16:
		await get_tree().process_frame

	var generated := controller.get_node_or_null("GeneratedVegetation")
	if generated == null:
		failures.append("ground projection should still create generated tree collisions")
		return
	var collisions := generated.get_node_or_null("TreeCollisions")
	if collisions == null:
		failures.append("ground projection should create TreeCollisions")
		return
	if collisions.get_child_count() != test_profile.tree_count:
		failures.append("ground projection should keep every tree on the covering walkable floor")
		return

	for child in collisions.get_children():
		var body := child as StaticBody3D
		if body == null:
			failures.append("projected tree collision child should be StaticBody3D")
			return
		var shape_node := body.get_node_or_null("TreeTrunkShape") as CollisionShape3D
		if shape_node == null or not shape_node.shape is CylinderShape3D:
			failures.append("projected tree collision should own a cylinder trunk shape")
			return
		var shape := shape_node.shape as CylinderShape3D
		var trunk_base_y: float = body.global_position.y - shape.height * 0.5
		if absf(trunk_base_y - 4.0) > 0.06:
			failures.append("projected tree should sit on walkable floor y=4.0, got %.3f" % trunk_base_y)
			return

	host.queue_free()


func _add_support_floor(parent: Node3D, size_xz: Vector2, top_y: float) -> void:
	var body := StaticBody3D.new()
	body.name = "PolygonApocalypseGameplaySupport"
	body.collision_layer = VegetationController.WORLD_COLLISION_LAYER
	body.collision_mask = 0
	body.set_meta("support_size_xz", size_xz)
	body.set_meta("support_top_y", top_y)
	parent.add_child(body)
	body.global_position = Vector3(0.0, top_y - 0.09, 0.0)

	var shape_node := CollisionShape3D.new()
	shape_node.name = "GameplaySupportShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(size_xz.x, 0.18, size_xz.y)
	shape_node.shape = shape
	body.add_child(shape_node)


func _add_walkable_floor(parent: Node3D, size: Vector3, top_y: float) -> void:
	var body := StaticBody3D.new()
	body.name = "SyntheticWalkableFloor"
	body.collision_layer = VegetationController.WORLD_COLLISION_LAYER
	body.collision_mask = 0
	body.add_to_group("polygon_apocalypse_walkable_collision")
	parent.add_child(body)
	body.global_position = Vector3(0.0, top_y - size.y * 0.5, 0.0)

	var shape_node := CollisionShape3D.new()
	shape_node.name = "WalkableShape"
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
