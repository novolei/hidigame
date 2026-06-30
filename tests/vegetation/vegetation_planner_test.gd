extends Node

const TEST_CENTER := Vector3.ZERO
const OFFSET_CENTER := Vector3(42.0, 0.0, -37.0)
const TEST_SIZE := Vector2(230.0, 220.0)
const TEST_TOP_Y := -8.0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_validate_warehouse_profile(failures)
	_validate_grass_determinism(failures)
	_validate_tree_determinism(failures)
	_validate_tree_offset_center_determinism(failures)

	if failures.is_empty():
		print("[VegetationPlannerTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[VegetationPlannerTest] " + failure)
		get_tree().quit(1)


func _validate_warehouse_profile(failures: Array[String]) -> void:
	var profile := VegetationProfile.for_polygon_warehouse("city_urp", "warehouse_ward")
	if profile.generation_seed == 0:
		failures.append("warehouse profile should have a stable non-zero seed")
	if profile.grass_instance_count < 10000:
		failures.append("URP warehouse profile should use a dense grass budget")
	if profile.tree_count < 20:
		failures.append("URP warehouse profile should include perimeter trees")
	if profile.tree_collision_enabled:
		failures.append("tree collision should default off so visual rollout does not change gameplay authority")


func _validate_grass_determinism(failures: Array[String]) -> void:
	var profile := VegetationProfile.for_polygon_warehouse("city_urp", "warehouse_ward")
	profile.grass_instance_count = 512
	var first: Array[Dictionary] = VegetationPlanner.generate_grass(profile, TEST_CENTER, TEST_SIZE, TEST_TOP_Y)
	var second: Array[Dictionary] = VegetationPlanner.generate_grass(profile, TEST_CENTER, TEST_SIZE, TEST_TOP_Y)
	if first.size() != profile.grass_instance_count:
		failures.append("grass planner returned %d placements, expected %d" % [first.size(), profile.grass_instance_count])
	if VegetationPlanner.placement_digest(first) != VegetationPlanner.placement_digest(second):
		failures.append("grass planner should be deterministic for the same profile and support")
	_validate_bounds("grass", first, failures)


func _validate_tree_determinism(failures: Array[String]) -> void:
	var profile := VegetationProfile.for_polygon_warehouse("city_urp", "warehouse_ward")
	profile.tree_count = 18
	var first: Array[Dictionary] = VegetationPlanner.generate_trees(profile, TEST_CENTER, TEST_SIZE, TEST_TOP_Y)
	var second: Array[Dictionary] = VegetationPlanner.generate_trees(profile, TEST_CENTER, TEST_SIZE, TEST_TOP_Y)
	if first.size() != profile.tree_count:
		failures.append("tree planner returned %d placements, expected %d" % [first.size(), profile.tree_count])
	if VegetationPlanner.placement_digest(first) != VegetationPlanner.placement_digest(second):
		failures.append("tree planner should be deterministic for the same profile and support")
	_validate_bounds("tree", first, failures)
	for item in first:
		var prototype: int = int(item.get("prototype", -1))
		if prototype < 0 or prototype >= profile.tree_scene_paths.size():
			failures.append("tree prototype index should be within configured tree scene paths")
			break


func _validate_tree_offset_center_determinism(failures: Array[String]) -> void:
	var profile := VegetationProfile.for_polygon_warehouse("city_urp", "warehouse_ward")
	profile.tree_count = 18
	var first: Array[Dictionary] = VegetationPlanner.generate_trees(profile, OFFSET_CENTER, TEST_SIZE, TEST_TOP_Y)
	var second: Array[Dictionary] = VegetationPlanner.generate_trees(profile, OFFSET_CENTER, TEST_SIZE, TEST_TOP_Y)
	if VegetationPlanner.placement_digest(first) != VegetationPlanner.placement_digest(second):
		failures.append("tree planner should remain deterministic with a non-zero support center")
	for item in first:
		if not item.has("local_position"):
			failures.append("tree placement should keep local_position for center-independent spacing")
			return
		var local_position: Vector2 = item.get("local_position", Vector2.ZERO)
		var item_position: Vector3 = item.get("position", Vector3.ZERO)
		if absf(item_position.x - (OFFSET_CENTER.x + local_position.x)) > 0.001:
			failures.append("tree world x should equal support center plus local x")
			return
		if absf(item_position.z - (OFFSET_CENTER.z + local_position.y)) > 0.001:
			failures.append("tree world z should equal support center plus local z")
			return
	_validate_bounds_for_center("offset tree", first, OFFSET_CENTER, failures)


func _validate_bounds(label: String, placements: Array[Dictionary], failures: Array[String]) -> void:
	_validate_bounds_for_center(label, placements, TEST_CENTER, failures)


func _validate_bounds_for_center(label: String, placements: Array[Dictionary], center: Vector3, failures: Array[String]) -> void:
	var half_x: float = TEST_SIZE.x * 0.5 + 0.05
	var half_z: float = TEST_SIZE.y * 0.5 + 0.05
	for item in placements:
		var item_position: Vector3 = item.get("position", Vector3.ZERO)
		if absf(item_position.x - center.x) > half_x or absf(item_position.z - center.z) > half_z:
			failures.append(label + " placement should stay inside the support bounds: " + str(item_position))
			return
		if absf(item_position.y - TEST_TOP_Y) > 0.1 and label.contains("tree"):
			failures.append("tree placement should use the support top y")
			return
		if item_position.y < TEST_TOP_Y - 0.1:
			failures.append(label + " placement should not spawn below support top")
			return
