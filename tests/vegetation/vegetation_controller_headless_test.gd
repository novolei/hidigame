extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	await _validate_headless_collision_only(failures)

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
