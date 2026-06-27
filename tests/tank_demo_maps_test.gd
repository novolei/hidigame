extends Node

const LevelLayout := preload("res://scripts/level_layout_config.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var scenes := {
		"Tank Demo Desert": "res://scenes/level/maps/tank_demo_desert.tscn",
		"Tank Demo Jungle": "res://scenes/level/maps/tank_demo_jungle.tscn",
		"Tank Demo Moon": "res://scenes/level/maps/tank_demo_moon.tscn",
		"garden": "res://scenes/level/maps/garden.tscn",
		"Japanese Town Street": "res://scenes/level/maps/japanese_town_street.tscn",
		"Western Town Prop Hunt": "res://scenes/level/maps/western_town_prop_hunt.tscn",
		"TPS Demo Level": "res://scenes/level/maps/tps_demo_level.tscn",
	}

	for map_name in scenes.keys():
		var packed := load(str(scenes[map_name]))
		if not packed is PackedScene:
			failures.append(map_name + " did not load as PackedScene")
			continue
		var map := (packed as PackedScene).instantiate()
		add_child(map)
		await get_tree().process_frame
		await get_tree().process_frame
		if map_name == "garden":
			if map.name != "GardenMapRoot":
				failures.append("garden should expose a GardenMapRoot scene root")
			if not map.get_node_or_null("Map"):
				failures.append("garden should instance the imported Map.gltf scene")
			var garden_collision := map.get_node_or_null("GardenCollisionRoot")
			if not garden_collision:
				failures.append("garden should generate runtime collision")
			elif _count_collision_shapes(garden_collision) == 0:
				failures.append("garden runtime collision should include at least one shape")
			map.queue_free()
			continue
		if map_name == "Japanese Town Street":
			if map.name != "JapaneseTownStreetMapRoot":
				failures.append("Japanese Town Street should expose a JapaneseTownStreetMapRoot scene root")
			if not map.get_node_or_null("JapaneseTownStreet"):
				failures.append("Japanese Town Street should instance the imported GLB scene")
			var imported_collision := map.get_node_or_null("ImportedCollisionRoot")
			if not imported_collision:
				failures.append("Japanese Town Street should generate runtime collision")
			elif _count_collision_shapes(imported_collision) == 0:
				failures.append("Japanese Town Street runtime collision should include at least one shape")
			map.queue_free()
			continue
		if map_name == "Western Town Prop Hunt":
			if map.name != "WesternTownMapRoot":
				failures.append("Western Town Prop Hunt should expose a WesternTownMapRoot scene root")
			var asset_root := map.get_node_or_null("ExistingAssetWesternTown")
			if not asset_root:
				failures.append("Western Town Prop Hunt should use existing asset instances for visible scenery")
			elif _count_mesh_instances(asset_root) < 80:
				failures.append("Western Town Prop Hunt should include substantial existing asset mesh scenery")
			var western_collision := map.get_node_or_null("WesternGameplayCollision")
			if not western_collision:
				failures.append("Western Town Prop Hunt should provide gameplay collision")
			elif _count_collision_shapes(western_collision) < 20:
				failures.append("Western Town Prop Hunt gameplay collision should cover ground, blockers, and upper routes")
			if not map.get_node_or_null("WesternGameplayMarkers"):
				failures.append("Western Town Prop Hunt should provide 24 player spawn hint markers")
			if not map.get_node_or_null("WesternTownPreviewCamera"):
				failures.append("Western Town Prop Hunt should include a preview camera")
			var tank_decor := map.get_node_or_null("WesternTankDecor")
			if not tank_decor:
				failures.append("Western Town Prop Hunt should include fixed tank decor")
			elif _count_collision_shapes(tank_decor) < 7:
				failures.append("Western Town Prop Hunt tank decor should include gameplay collision")
			if _count_nodes_named(map, "DecorHeavyTank") == 0:
				failures.append("Western Town Prop Hunt should include materialized heavy tank scenery")
			if _count_nodes_named(map, "DecorUTVTank") == 0:
				failures.append("Western Town Prop Hunt should include materialized UTV tank scenery")
			if _count_nodes_named(map, "DecorSharkTank") == 0:
				failures.append("Western Town Prop Hunt should include materialized shark tank scenery")
			if _count_nodes_named(map, "DecorBustedTank") == 0:
				failures.append("Western Town Prop Hunt should include additional damaged tank scenery")
			if _count_materialized_surfaces(map) < 400:
				failures.append("Western Town Prop Hunt should persist material overrides for existing scenery")
			map.queue_free()
			continue
		if map_name == "TPS Demo Level":
			if map.name != "TpsDemoLevelMap":
				failures.append("TPS Demo Level should expose a TpsDemoLevelMap scene root")
			var tps_content := map.get_node_or_null("TpsDemoLevelContent")
			if not tps_content:
				failures.append("TPS Demo Level should instance the sanitized reference level content")
			else:
				if not tps_content.get_node_or_null("Core"):
					failures.append("TPS Demo Level should include the reference Core scene")
				if not tps_content.get_node_or_null("Structure"):
					failures.append("TPS Demo Level should include the reference Structure scene")
				if not tps_content.get_node_or_null("Props"):
					failures.append("TPS Demo Level should include the reference Props scene")
				if _count_mesh_instances(tps_content) < 500:
					failures.append("TPS Demo Level should include substantial reference mesh scenery")
				if _count_collision_shapes(tps_content) < 100:
					failures.append("TPS Demo Level should keep reference gameplay collision")
			if _count_audio_streams(map) != 0:
				failures.append("TPS Demo Level should not keep reference audio streams")
			map.queue_free()
			continue
		var root := map.get_node_or_null("GeneratedTankDemoMap")
		if not root:
			failures.append(map_name + " did not generate map root")
		else:
			if not root.get_node_or_null("TankDemoGround"):
				failures.append(map_name + " is missing generated ground")
			if root.get_tree().get_nodes_in_group("tank_demo_showcase").is_empty():
				failures.append(map_name + " is missing tank showcase nodes")
			elif _count_tank_material_variants(root) < 2:
				failures.append(map_name + " tank showcase should keep separate body/track/light materials")
			var prefab_layout := root.get_node_or_null("TankDemoPrefabLayout")
			if not prefab_layout:
				failures.append(map_name + " is missing Unity prefab layout scenery")
			elif _count_mesh_instances(prefab_layout) < 20:
				failures.append(map_name + " did not expand enough Unity prefab layout meshes")
			if _count_nodes_named(root, "Blocker") < 6:
				failures.append(map_name + " should generate static blockers for scenery")
			var audio := root.get_node_or_null("TankDemoAudio")
			if not audio:
				failures.append(map_name + " is missing migrated tank audio nodes")
			elif _count_audio_streams(audio) < 3:
				failures.append(map_name + " did not load expected SFX streams")
		map.queue_free()

	var main_scene := load("res://scenes/level/level.tscn")
	if not main_scene is PackedScene:
		failures.append("Main level did not load")
	else:
		var level: Node = await _instantiate_level_with_loaded_map(main_scene as PackedScene, "Tank Demo Desert", failures)
		var mounted_tank := level.get_node_or_null("Environment/TankDemoMapRoot")
		if not mounted_tank:
			failures.append("Main level did not mount the selected Tank Demo map after loading")
		var gdquest := level.get_node_or_null("Environment/GDQuestControllerArena") as Node3D
		if gdquest and gdquest.visible:
			failures.append("Default arena should be hidden after a Tank Demo map is loaded")
		var default_floor := level.get_node_or_null("Environment/Floor") as CollisionObject3D
		if default_floor and (default_floor.visible or default_floor.collision_layer != 0):
			failures.append("Default floor should be hidden and collision-disabled after a Tank Demo map is loaded")
		level.queue_free()
		await get_tree().process_frame

		var garden_level: Node = await _instantiate_level_with_loaded_map(main_scene as PackedScene, "garden", failures)
		var mounted_garden := garden_level.get_node_or_null("Environment/TankDemoMapRoot")
		if not mounted_garden:
			failures.append("Main level did not mount the selected garden map after loading")
		else:
			if not mounted_garden.get_node_or_null("Map"):
				failures.append("Mounted garden map should include the imported Map.gltf scene")
			if not mounted_garden.get_node_or_null("GardenCollisionRoot"):
				failures.append("Mounted garden map should include generated collision")
		garden_level.queue_free()
		await get_tree().process_frame

		var japanese_town_level: Node = await _instantiate_level_with_loaded_map(main_scene as PackedScene, "Japanese Town Street", failures)
		var mounted_japanese_town := japanese_town_level.get_node_or_null("Environment/TankDemoMapRoot")
		if not mounted_japanese_town:
			failures.append("Main level did not mount the selected Japanese Town Street map after loading")
		else:
			if not mounted_japanese_town.get_node_or_null("JapaneseTownStreet"):
				failures.append("Mounted Japanese Town Street map should include the imported GLB scene")
			if not mounted_japanese_town.get_node_or_null("ImportedCollisionRoot"):
				failures.append("Mounted Japanese Town Street map should include generated collision")
		japanese_town_level.queue_free()
		await get_tree().process_frame

		var western_level: Node = await _instantiate_level_with_loaded_map(main_scene as PackedScene, "Western Town Prop Hunt", failures)
		var mounted_western := western_level.get_node_or_null("Environment/TankDemoMapRoot")
		if not mounted_western:
			failures.append("Main level did not mount the selected Western Town Prop Hunt map after loading")
		else:
			if not mounted_western.get_node_or_null("ExistingAssetWesternTown"):
				failures.append("Mounted Western Town Prop Hunt map should include existing asset scenery")
			if not mounted_western.get_node_or_null("WesternGameplayCollision"):
				failures.append("Mounted Western Town Prop Hunt map should include gameplay collision")
		western_level.queue_free()
		await get_tree().process_frame

		var tps_level: Node = await _instantiate_level_with_loaded_map(main_scene as PackedScene, "TPS Demo Level", failures)
		var mounted_tps: Node = await _wait_for_node(tps_level, ^"Environment/TankDemoMapRoot", 12)
		if not mounted_tps:
			failures.append("Main level did not mount the selected TPS Demo Level map after loading")
		else:
			if not mounted_tps.get_node_or_null("TpsDemoLevelContent"):
				failures.append("Mounted TPS Demo Level should include sanitized reference content")
			if _count_audio_streams(mounted_tps) != 0:
				failures.append("Mounted TPS Demo Level should not keep reference audio streams")
			await get_tree().physics_frame
			_validate_tps_demo_world_collision(tps_level, mounted_tps, failures)
		tps_level.queue_free()
	Network.lobby_config["map"] = "Warehouse"

	if failures.is_empty():
		print("[TankDemoMapsTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[TankDemoMapsTest] " + failure)
		get_tree().quit(1)


func _instantiate_level_with_loaded_map(main_scene: PackedScene, map_name: String, failures: Array[String]) -> Node:
	Network.lobby_config["map"] = map_name
	var level := main_scene.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	if level.get_node_or_null("Environment/TankDemoMapRoot"):
		failures.append("Main level should not mount " + map_name + " before match loading")
	await level.call("_run_match_loading_sequence", map_name)
	await get_tree().process_frame
	if not level.get_node_or_null("MapLoadingOverlay"):
		failures.append("Main level should create the map loading overlay for " + map_name)
	return level


func _wait_for_node(root: Node, node_path: NodePath, max_frames: int = 8) -> Node:
	for _i in range(max_frames):
		var found := root.get_node_or_null(node_path)
		if found:
			return found
		await get_tree().process_frame
	return null


func _validate_tps_demo_world_collision(level: Node, mounted_tps: Node, failures: Array[String]) -> void:
	var adapted_count := int(mounted_tps.get_meta("world_collision_adapted_count", 0))
	if adapted_count < 100:
		failures.append("Mounted TPS Demo Level should adapt reference collision bodies to project world layer 2")
	var world_layer_count := 0
	var wrong_layer_samples: Array[String] = []
	var collision_nodes: Array[Node] = mounted_tps.find_children("*", "CollisionObject3D", true, false)
	for node in collision_nodes:
		var collision := node as CollisionObject3D
		if collision == null or collision is Area3D or collision.collision_layer == 0:
			continue
		if collision.collision_layer == 2:
			world_layer_count += 1
		elif wrong_layer_samples.size() < 5:
			wrong_layer_samples.append("%s:%d" % [String(collision.name), collision.collision_layer])
	if world_layer_count < 100:
		failures.append("Mounted TPS Demo Level should expose substantial world-layer collision for grounded spawns")
	if not wrong_layer_samples.is_empty():
		failures.append("Mounted TPS Demo Level left collision bodies outside world layer 2: " + str(wrong_layer_samples))

	var prop_ids: Array = [101, 102, 103, 104, 105, 106]
	for prop_id in prop_ids:
		var spawn_point: Vector3 = LevelLayout.prop_spawn_point(int(prop_id), prop_ids)
		_validate_tps_demo_ground_probe(level, spawn_point, failures)
	for release_index in range(3):
		var release_point: Vector3 = LevelLayout.hunter_release_point(release_index, 3)
		_validate_tps_demo_ground_probe(level, release_point, failures)


func _validate_tps_demo_ground_probe(level: Node, point: Vector3, failures: Array[String]) -> void:
	if not level.has_method("get_grounded_spawn_position"):
		failures.append("Main level does not expose get_grounded_spawn_position")
		return
	var world: World3D = level.get_world_3d()
	if world == null:
		failures.append("Mounted TPS Demo Level cannot validate grounded spawn without a World3D")
		return
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 80.0, point + Vector3.DOWN * 160.0, 2)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		failures.append("Mounted TPS Demo Level did not expose world-layer ground under spawn probe " + str(point))
		return
	var grounded_value: Variant = level.call("get_grounded_spawn_position", point)
	if not grounded_value is Vector3:
		failures.append("get_grounded_spawn_position did not return Vector3 for TPS Demo Level")
		return
	var grounded := grounded_value as Vector3
	var hit_position: Vector3 = hit.get("position", point)
	if absf(grounded.y - hit_position.y) > 0.05:
		failures.append("TPS Demo Level grounded spawn height should match world-layer floor hit, got %s expected %.3f" % [str(grounded), hit_position.y])


func _count_nodes_named(node: Node, fragment: String) -> int:
	var count := 0
	if node.name.contains(fragment):
		count += 1
	for child in node.get_children():
		count += _count_nodes_named(child, fragment)
	return count


func _count_audio_streams(node: Node) -> int:
	var count := 0
	if node is AudioStreamPlayer3D and (node as AudioStreamPlayer3D).stream:
		count += 1
	for child in node.get_children():
		count += _count_audio_streams(child)
	return count


func _count_mesh_instances(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		count += 1
	for child in node.get_children():
		count += _count_mesh_instances(child)
	return count


func _count_collision_shapes(node: Node) -> int:
	var count := 0
	if node is CollisionShape3D and (node as CollisionShape3D).shape:
		count += 1
	for child in node.get_children():
		count += _count_collision_shapes(child)
	return count


func _count_materialized_surfaces(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				if mesh_instance.get_surface_override_material(i):
					count += 1
	for child in node.get_children():
		count += _count_materialized_surfaces(child)
	return count


func _count_tank_material_variants(node: Node) -> int:
	var paths := {}
	for tank in node.get_tree().get_nodes_in_group("tank_demo_showcase"):
		_collect_material_paths(tank, paths)
	return paths.size()


func _collect_material_paths(node: Node, paths: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_surface_override_material(i)
				if material:
					paths[material.resource_path if not material.resource_path.is_empty() else material.resource_name] = true
	for child in node.get_children():
		_collect_material_paths(child, paths)
