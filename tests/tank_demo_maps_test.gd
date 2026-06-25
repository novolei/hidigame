extends Node


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

	Network.lobby_config["map"] = "Tank Demo Desert"
	var main_scene := load("res://scenes/level/level.tscn")
	if not main_scene is PackedScene:
		failures.append("Main level did not load")
	else:
		var level := (main_scene as PackedScene).instantiate()
		add_child(level)
		await get_tree().process_frame
		if not level.get_node_or_null("Environment/TankDemoMapRoot"):
			failures.append("Main level did not mount the selected Tank Demo map")
		var gdquest := level.get_node_or_null("Environment/GDQuestControllerArena") as Node3D
		if gdquest and gdquest.visible:
			failures.append("Default arena should be hidden while a Tank Demo map is selected")
		var floor := level.get_node_or_null("Environment/Floor") as CollisionObject3D
		if floor and (floor.visible or floor.collision_layer != 0):
			failures.append("Default floor should be hidden and collision-disabled while a Tank Demo map is selected")
		level.queue_free()

	Network.lobby_config["map"] = "garden"
	if main_scene is PackedScene:
		var garden_level := (main_scene as PackedScene).instantiate()
		add_child(garden_level)
		await get_tree().process_frame
		await get_tree().process_frame
		var mounted_garden := garden_level.get_node_or_null("Environment/TankDemoMapRoot")
		if not mounted_garden:
			failures.append("Main level did not mount the selected garden map")
		else:
			if not mounted_garden.get_node_or_null("Map"):
				failures.append("Mounted garden map should include the imported Map.gltf scene")
			if not mounted_garden.get_node_or_null("GardenCollisionRoot"):
				failures.append("Mounted garden map should include generated collision")
		garden_level.queue_free()

	Network.lobby_config["map"] = "Japanese Town Street"
	if main_scene is PackedScene:
		var japanese_town_level := (main_scene as PackedScene).instantiate()
		add_child(japanese_town_level)
		await get_tree().process_frame
		await get_tree().process_frame
		var mounted_japanese_town := japanese_town_level.get_node_or_null("Environment/TankDemoMapRoot")
		if not mounted_japanese_town:
			failures.append("Main level did not mount the selected Japanese Town Street map")
		else:
			if not mounted_japanese_town.get_node_or_null("JapaneseTownStreet"):
				failures.append("Mounted Japanese Town Street map should include the imported GLB scene")
			if not mounted_japanese_town.get_node_or_null("ImportedCollisionRoot"):
				failures.append("Mounted Japanese Town Street map should include generated collision")
		japanese_town_level.queue_free()

	Network.lobby_config["map"] = "Western Town Prop Hunt"
	if main_scene is PackedScene:
		var western_level := (main_scene as PackedScene).instantiate()
		add_child(western_level)
		await get_tree().process_frame
		await get_tree().process_frame
		var mounted_western := western_level.get_node_or_null("Environment/TankDemoMapRoot")
		if not mounted_western:
			failures.append("Main level did not mount the selected Western Town Prop Hunt map")
		else:
			if not mounted_western.get_node_or_null("ExistingAssetWesternTown"):
				failures.append("Mounted Western Town Prop Hunt map should include existing asset scenery")
			if not mounted_western.get_node_or_null("WesternGameplayCollision"):
				failures.append("Mounted Western Town Prop Hunt map should include gameplay collision")
		western_level.queue_free()
	Network.lobby_config["map"] = "Warehouse"

	if failures.is_empty():
		print("[TankDemoMapsTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[TankDemoMapsTest] " + failure)
		get_tree().quit(1)


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
