extends Node

const LevelLayout := preload("res://scripts/level_layout_config.gd")

const MAP_SCENES := {
	"Polygon Apocalypse Bunker": "res://scenes/level/maps/polygon_apocalypse_bunker.tscn",
	"Polygon Apocalypse Interior": "res://scenes/level/maps/polygon_apocalypse_building_interior_dressing.tscn",
	"Polygon Apocalypse City": "res://scenes/level/maps/polygon_apocalypse_city_standard.tscn",
	"Polygon Apocalypse City URP": "res://scenes/level/maps/polygon_apocalypse_city_urp.tscn",
	"Polygon Apocalypse City: Downtown Escape": "res://scenes/level/maps/polygon_apocalypse_city_downtown_escape.tscn",
	"Polygon Apocalypse City: Quarantine Crossing": "res://scenes/level/maps/polygon_apocalypse_city_quarantine_crossing.tscn",
	"Polygon Apocalypse City: Market Row": "res://scenes/level/maps/polygon_apocalypse_city_market_row.tscn",
	"Polygon Apocalypse City: Overpass Camp": "res://scenes/level/maps/polygon_apocalypse_city_overpass_camp.tscn",
	"Polygon Apocalypse City: Warehouse Ward": "res://scenes/level/maps/polygon_apocalypse_city_warehouse_ward.tscn",
	"Polygon Apocalypse City URP: Downtown Escape": "res://scenes/level/maps/polygon_apocalypse_city_urp_downtown_escape.tscn",
}
const CITY_SECTOR_EXPECTATIONS := {
	"Polygon Apocalypse City: Downtown Escape": {"sector": "downtown_core", "min": 3200, "max": 3600},
	"Polygon Apocalypse City: Quarantine Crossing": {"sector": "quarantine_crossing", "min": 1650, "max": 1950},
	"Polygon Apocalypse City: Market Row": {"sector": "market_row", "min": 1600, "max": 1900},
	"Polygon Apocalypse City: Overpass Camp": {"sector": "overpass_camp", "min": 1850, "max": 2150},
	"Polygon Apocalypse City: Warehouse Ward": {"sector": "warehouse_ward", "min": 2700, "max": 3000},
	"Polygon Apocalypse City URP: Downtown Escape": {"sector": "downtown_core", "min": 3200, "max": 3600},
}
const LAYOUTS := {
	"bunker": {"path": "res://assets/unity_migrated/polygon_apocalypse/layouts/bunker.json", "min_objects": 200},
	"building_interior_dressing": {"path": "res://assets/unity_migrated/polygon_apocalypse/layouts/building_interior_dressing.json", "min_objects": 1000},
	"city_standard": {"path": "res://assets/unity_migrated/polygon_apocalypse/layouts/city_standard.json", "min_objects": 7000},
	"city_urp": {"path": "res://assets/unity_migrated/polygon_apocalypse/layouts/city_urp.json", "min_objects": 7000},
}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_validate_layouts(failures)
	_validate_used_models(failures)
	await _validate_bunker_scene(failures)
	await _validate_city_placeholders(failures)
	await _validate_city_sector_scenes(failures)
	await _validate_main_level_mount(failures)

	if failures.is_empty():
		print("[PolygonApocalypseMapsTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[PolygonApocalypseMapsTest] " + failure)
		get_tree().quit(1)


func _validate_layouts(failures: Array[String]) -> void:
	for map_id in LAYOUTS.keys():
		var data: Dictionary = LAYOUTS[map_id]
		var path := str(data["path"])
		if not FileAccess.file_exists(path):
			failures.append(map_id + " layout is missing")
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			failures.append(map_id + " layout did not parse")
			continue
		var object_count := int((parsed as Dictionary).get("object_count", 0))
		if object_count < int(data["min_objects"]):
			failures.append("%s layout object count is too low: %d" % [map_id, object_count])
		var environment = (parsed as Dictionary).get("environment", {})
		if not environment is Dictionary or not (environment as Dictionary).has("ambient_sky_color"):
			failures.append(map_id + " layout is missing migrated Unity RenderSettings")
		var objects = (parsed as Dictionary).get("objects", [])
		if not objects is Array or (objects as Array).is_empty():
			failures.append(map_id + " layout has no object array")
			continue
		var first_object = (objects as Array)[0]
		if not first_object is Dictionary:
			failures.append(map_id + " first object is not a dictionary")
			continue
		var scene_path := str((first_object as Dictionary).get("scene", ""))
		if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
			failures.append(map_id + " first object scene is missing: " + scene_path)


func _validate_used_models(failures: Array[String]) -> void:
	var manifest_path := "res://assets/unity_migrated/polygon_apocalypse/used_models.json"
	if not FileAccess.file_exists(manifest_path):
		failures.append("used_models.json is missing")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		failures.append("used_models.json did not parse")
		return
	var models = (parsed as Dictionary).get("models", [])
	if not models is Array or (models as Array).size() < 900:
		failures.append("Polygon Apocalypse should reference at least 900 converted FBX models")
		return
	var missing_count := 0
	for model in models:
		if not model is Dictionary:
			continue
		var res_path := str((model as Dictionary).get("res", ""))
		if res_path.is_empty() or not FileAccess.file_exists(res_path):
			missing_count += 1
	if missing_count > 0:
		failures.append("Converted GLB files missing: %d" % missing_count)


func _validate_bunker_scene(failures: Array[String]) -> void:
	var packed := load(MAP_SCENES["Polygon Apocalypse Bunker"])
	if not packed is PackedScene:
		failures.append("Polygon Apocalypse Bunker did not load as PackedScene")
		return
	var map := (packed as PackedScene).instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	var root := map.get_node_or_null("GeneratedPolygonApocalypseMap")
	if not root:
		failures.append("Bunker scene did not generate map root")
	else:
		var layout := root.get_node_or_null("PolygonApocalypseLayout")
		if not layout:
			failures.append("Bunker scene is missing generated layout")
		elif _count_mesh_instances(layout) < 200:
			failures.append("Bunker scene did not instantiate enough meshes")
		else:
			var background := layout.get_node_or_null("Background") as MeshInstance3D
			if not background or not background.mesh is PlaneMesh:
				failures.append("Bunker background should instantiate Unity's built-in 10x10 plane")
			elif not (background.mesh as PlaneMesh).size.is_equal_approx(Vector2(10.0, 10.0)):
				failures.append("Bunker background plane should preserve Unity's built-in 10x10 size")
		_validate_gameplay_collisions("Polygon Apocalypse Bunker", root, failures)
		var lights := root.get_node_or_null("PolygonApocalypseLights")
		if not lights:
			failures.append("Bunker scene is missing migrated lights")
		var environment := root.get_node_or_null("PolygonApocalypseEnvironment") as WorldEnvironment
		if not environment or not environment.environment:
			failures.append("Bunker scene is missing migrated Unity environment lighting")
	map.queue_free()


func _validate_city_placeholders(failures: Array[String]) -> void:
	var packed := load(MAP_SCENES["Polygon Apocalypse City"])
	if not packed is PackedScene:
		failures.append("Polygon Apocalypse City did not load as PackedScene")
		return
	var map := (packed as PackedScene).instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	var root := map.get_node_or_null("GeneratedPolygonApocalypseMap")
	var layout := root.get_node_or_null("PolygonApocalypseLayout") if root else null
	if not layout:
		failures.append("City scene is missing generated layout")
	else:
		var renderable_bodies := 0
		var renderable_ropes := 0
		for child in layout.get_children():
			if not child is Node3D:
				continue
			var unity_name := str(child.get_meta("unity_name", child.name))
			if unity_name.begins_with("SM_Prop_DeadBody_Hanging_") and _has_renderable_bounds(child as Node3D):
				renderable_bodies += 1
			if unity_name.begins_with("SM_Prop_HangingRope_") and _has_renderable_bounds(child as Node3D):
				renderable_ropes += 1
		if renderable_bodies < 8:
			failures.append("City scene should render fallback hanging body meshes: %d" % renderable_bodies)
		if renderable_ropes < 8:
			failures.append("City scene should render fallback hanging rope meshes: %d" % renderable_ropes)
	map.queue_free()


func _validate_city_sector_scenes(failures: Array[String]) -> void:
	for map_name in CITY_SECTOR_EXPECTATIONS.keys():
		var packed := load(MAP_SCENES[map_name])
		if not packed is PackedScene:
			failures.append(map_name + " did not load as PackedScene")
			continue
		var map := (packed as PackedScene).instantiate()
		add_child(map)
		await get_tree().process_frame
		await get_tree().process_frame
		var root := map.get_node_or_null("GeneratedPolygonApocalypseMap")
		var layout := root.get_node_or_null("PolygonApocalypseLayout") if root else null
		if not layout:
			failures.append(map_name + " is missing generated layout")
			map.queue_free()
			continue
		var expected: Dictionary = CITY_SECTOR_EXPECTATIONS[map_name]
		var sector_id := str(layout.get_meta("sector_id", ""))
		if sector_id != str(expected["sector"]):
			failures.append("%s generated wrong sector id: %s" % [map_name, sector_id])
		var visual_object_count := _count_unity_layout_objects(layout)
		if visual_object_count < int(expected["min"]) or visual_object_count > int(expected["max"]):
			failures.append("%s sector object count out of range: %d" % [map_name, visual_object_count])
		if visual_object_count >= 7000:
			failures.append(map_name + " should be a playable city slice, not the full city")
		if str(layout.get_meta("sector_label", "")).is_empty():
			failures.append(map_name + " should expose a sector label for UI/debug tooling")
		var sector_bounds = layout.get_meta("sector_bounds", [])
		if not sector_bounds is Array or (sector_bounds as Array).size() != 4:
			failures.append(map_name + " should expose four sector bounds for focused audit captures")
		_validate_gameplay_support(map_name, root, failures)
		_validate_gameplay_collisions(map_name, root, failures)
		_validate_city_gameplay_lighting(map_name, root, failures)
		if map_name.contains("URP"):
			_validate_city_water_material(map_name, root, failures)
		map.queue_free()


func _validate_gameplay_support(map_name: String, root: Node, failures: Array[String]) -> void:
	if not root:
		failures.append(map_name + " cannot validate gameplay support without generated root")
		return
	var support := root.get_node_or_null("PolygonApocalypseGameplaySupport") as StaticBody3D
	if not support:
		failures.append(map_name + " is missing gameplay support collision floor")
		return
	if support.collision_layer != 2:
		failures.append(map_name + " gameplay support should be on world collision layer 2")
	var shape_node := support.get_node_or_null("GameplaySupportShape") as CollisionShape3D
	if not shape_node or not shape_node.shape is BoxShape3D:
		failures.append(map_name + " gameplay support is missing a box collision shape")
		return
	var shape := shape_node.shape as BoxShape3D
	if shape.size.x < 80.0 or shape.size.z < 80.0:
		failures.append(map_name + " gameplay support is too small for existing spawn radii: " + str(shape.size))
	var support_top := support.global_position.y + shape.size.y * 0.5
	var expected_top := float(support.get_meta("support_top_y", support_top))
	if absf(support_top - expected_top) > 0.03:
		failures.append(map_name + " gameplay support top should match declared support height, got " + str(support_top))
	if Vector2(support.global_position.x, support.global_position.z).length() > 0.5:
		failures.append(map_name + " gameplay support should be centered near the gameplay origin")


func _validate_gameplay_collisions(map_name: String, root: Node, failures: Array[String]) -> void:
	if not root:
		failures.append(map_name + " cannot validate generated collisions without generated root")
		return
	var walkable_count := _count_nodes_in_group_recursive(root, "polygon_apocalypse_walkable_collision")
	var blocker_count := _count_nodes_in_group_recursive(root, "polygon_apocalypse_blocker_collision")
	var min_walkable := 20 if map_name.contains("City") else 4
	var min_blockers := 6 if map_name.contains("City") else 2
	if walkable_count < min_walkable:
		failures.append("%s should generate mesh-based walkable collisions, got %d" % [map_name, walkable_count])
	if blocker_count < min_blockers:
		failures.append("%s should keep explicit blocker collisions, got %d" % [map_name, blocker_count])
	if blocker_count > walkable_count * 3 and map_name.contains("City"):
		failures.append("%s generated too many blockers compared with walkable terrain: %d blockers vs %d walkables" % [map_name, blocker_count, walkable_count])


func _validate_city_gameplay_lighting(map_name: String, root: Node, failures: Array[String]) -> void:
	if not root:
		failures.append(map_name + " cannot validate gameplay lighting without generated root")
		return
	var lighting := root.get_node_or_null("PolygonApocalypseGameplayLighting")
	if not lighting:
		failures.append(map_name + " is missing gameplay lighting for Stalker shadow routes")
		return
	var light_count := _count_omni_lights(lighting)
	if light_count < 4:
		failures.append("%s should add at least four gameplay light anchors, got %d" % [map_name, light_count])
	var shadow_zone_count := _count_nodes_in_group_recursive(root, "stalker_shadow_zone")
	if shadow_zone_count < 4:
		failures.append("%s should add Stalker shadow zones for stealth routing, got %d" % [map_name, shadow_zone_count])


func _validate_city_water_material(map_name: String, root: Node, failures: Array[String]) -> void:
	if not root:
		failures.append(map_name + " cannot validate water material without generated root")
		return
	var water_count := _count_water_shader_materials(root)
	if water_count <= 0:
		failures.append(map_name + " should apply the Polygon Apocalypse water shader to migrated water surfaces")


func _validate_main_level_mount(failures: Array[String]) -> void:
	Network.lobby_config["map"] = "Polygon Apocalypse City: Downtown Escape"
	var main_scene := load("res://scenes/level/level.tscn")
	if not main_scene is PackedScene:
		failures.append("Main level did not load")
		return
	var level := (main_scene as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var mounted := level.get_node_or_null("Environment/TankDemoMapRoot")
	if not mounted:
		failures.append("Main level did not mount the selected Polygon Apocalypse map")
	elif not mounted.get_node_or_null("GeneratedPolygonApocalypseMap"):
		failures.append("Mounted Polygon Apocalypse map did not generate content")
	elif not mounted.get_node_or_null("GeneratedPolygonApocalypseMap/PolygonApocalypseLayout"):
		failures.append("Mounted Polygon Apocalypse city sector did not generate a layout")
	var gdquest := level.get_node_or_null("Environment/GDQuestControllerArena") as Node3D
	if gdquest and gdquest.visible:
		failures.append("Default arena should be hidden while a Polygon Apocalypse map is selected")
	var floor_body := level.get_node_or_null("Environment/Floor") as CollisionObject3D
	if floor_body and (floor_body.visible or floor_body.collision_layer != 0):
		failures.append("Default floor should be hidden and collision-disabled while a Polygon Apocalypse map is selected")
	_validate_main_level_spawn_support(level, failures)
	level.queue_free()
	Network.lobby_config["map"] = "Warehouse"


func _validate_main_level_spawn_support(level: Node, failures: Array[String]) -> void:
	var support := level.get_node_or_null("Environment/TankDemoMapRoot/GeneratedPolygonApocalypseMap/PolygonApocalypseGameplaySupport") as StaticBody3D
	if not support:
		failures.append("Mounted Polygon Apocalypse map is missing gameplay support floor")
		return
	var shape_node := support.get_node_or_null("GameplaySupportShape") as CollisionShape3D
	if not shape_node or not shape_node.shape is BoxShape3D:
		failures.append("Mounted Polygon Apocalypse gameplay support is missing a box shape")
		return
	var shape := shape_node.shape as BoxShape3D
	var support_top := support.global_position.y + shape.size.y * 0.5
	var prop_ids: Array = [101, 102, 103, 104, 105, 106]
	for prop_id in prop_ids:
		var prop_spawn := LevelLayout.prop_spawn_point(int(prop_id), prop_ids)
		if not _point_inside_support_xz(prop_spawn, support, shape):
			failures.append("Polygon Apocalypse prop spawn is outside gameplay support: " + str(prop_spawn))
		_validate_grounded_spawn_y(level, prop_spawn, support_top, failures)
	for release_index in range(6):
		var hunter_release := LevelLayout.hunter_release_point(release_index, 6)
		if not _point_inside_support_xz(hunter_release, support, shape):
			failures.append("Polygon Apocalypse hunter release is outside gameplay support: " + str(hunter_release))
		_validate_grounded_spawn_y(level, hunter_release, support_top, failures)


func _validate_grounded_spawn_y(level: Node, point: Vector3, support_top: float, failures: Array[String]) -> void:
	if not level.has_method("get_grounded_spawn_position"):
		failures.append("Main level does not expose get_grounded_spawn_position")
		return
	var grounded_value: Variant = level.call("get_grounded_spawn_position", point)
	if not grounded_value is Vector3:
		failures.append("get_grounded_spawn_position did not return Vector3")
		return
	var grounded := grounded_value as Vector3
	if grounded.y < support_top - 0.05:
		failures.append("Polygon Apocalypse spawn should not fall below gameplay support floor, got " + str(grounded))


func _point_inside_support_xz(point: Vector3, support: StaticBody3D, shape: BoxShape3D) -> bool:
	var half_x := shape.size.x * 0.5
	var half_z := shape.size.z * 0.5
	return (
		point.x >= support.global_position.x - half_x
		and point.x <= support.global_position.x + half_x
		and point.z >= support.global_position.z - half_z
		and point.z <= support.global_position.z + half_z
	)


func _count_nodes_named(node: Node, fragment: String) -> int:
	var count := 0
	if node.name.contains(fragment):
		count += 1
	for child in node.get_children():
		count += _count_nodes_named(child, fragment)
	return count


func _count_nodes_in_group_recursive(node: Node, group_name: String) -> int:
	var count := 0
	if node.is_in_group(group_name):
		count += 1
	for child in node.get_children():
		count += _count_nodes_in_group_recursive(child, group_name)
	return count


func _count_omni_lights(node: Node) -> int:
	var count := 0
	if node is OmniLight3D:
		count += 1
	for child in node.get_children():
		count += _count_omni_lights(child)
	return count


func _count_water_shader_materials(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if _is_polygon_apocalypse_water_material(mesh_instance.material_override):
			count += 1
		var mesh := mesh_instance.mesh
		if mesh:
			for surface_index in range(mesh.get_surface_count()):
				var surface_material := mesh_instance.get_surface_override_material(surface_index)
				if surface_material == null:
					surface_material = mesh.surface_get_material(surface_index)
				if _is_polygon_apocalypse_water_material(surface_material):
					count += 1
	for child in node.get_children():
		count += _count_water_shader_materials(child)
	return count


func _is_polygon_apocalypse_water_material(material: Material) -> bool:
	if not material is ShaderMaterial:
		return false
	var shader_material := material as ShaderMaterial
	if shader_material.shader == null:
		return false
	return shader_material.shader.resource_path.ends_with("polygon_apocalypse_water.gdshader")


func _count_mesh_instances(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		count += 1
	for child in node.get_children():
		count += _count_mesh_instances(child)
	return count


func _count_unity_layout_objects(layout: Node) -> int:
	var count := 0
	for child in layout.get_children():
		if child.has_meta("unity_transform_id"):
			count += 1
	return count


func _has_renderable_bounds(node: Node3D) -> bool:
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(node, meshes)
	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue
		var box := mesh_instance.get_aabb()
		if box.size.x > 0.00001 or box.size.y > 0.00001 or box.size.z > 0.00001:
			return true
	return false


func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_meshes(child, result)
