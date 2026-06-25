@tool
extends RefCounted

const WORLD_LAYER: int = 2
const PLAYER_MASK: int = 1

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.clear_children(root)
	root.name = "WesternTownMapRoot"

	var visuals: Node3D = Node3D.new()
	visuals.name = "ExistingAssetWesternTown"
	root.add_child(visuals)
	ctx.own(visuals)

	var collision: Node3D = Node3D.new()
	collision.name = "WesternGameplayCollision"
	root.add_child(collision)
	ctx.own(collision)

	var markers: Node3D = Node3D.new()
	markers.name = "WesternGameplayMarkers"
	root.add_child(markers)
	ctx.own(markers)

	_add_lighting(ctx, root)
	_add_existing_asset_layout(ctx, visuals)
	_add_collision_layout(ctx, collision)
	_add_gameplay_markers(ctx, markers)
	_add_preview_camera(ctx, root)

	ctx.mark_modified()
	ctx.log("Rebuilt WesternTownMapRoot using existing assets as visible geometry. Custom nodes are limited to collision, lighting, camera, and gameplay markers.")

func _add_lighting(ctx, root: Node) -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WesternSunsetWorldEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.77, 0.88, 1.0, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.72, 0.45, 1.0)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.22
	world.environment = env
	root.add_child(world)
	ctx.own(world)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "WesternLowSun"
	sun.rotation_degrees = Vector3(-38.0, -42.0, 0.0)
	sun.light_energy = 2.5
	sun.light_color = Color(1.0, 0.68, 0.38, 1.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	ctx.own(sun)

	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "WesternBlueFill"
	fill.rotation_degrees = Vector3(-25.0, 135.0, 0.0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.58, 0.74, 1.0, 1.0)
	root.add_child(fill)
	ctx.own(fill)

func _add_existing_asset_layout(ctx, parent: Node) -> void:
	_instance_asset(ctx, parent, "res://assets/Map/Map.gltf", "AssetVillageCore", Vector3(0.0, 0.0, 0.0), Vector3(0.12, 0.12, 0.12), Vector3(0.0, 90.0, 0.0))
	_instance_asset(ctx, parent, "res://assets/Map/Map.gltf", "AssetVillageBacklot", Vector3(21.0, 0.0, -19.0), Vector3(0.08, 0.08, 0.08), Vector3(0.0, -28.0, 0.0))
	_instance_asset(ctx, parent, "res://assets/Map/Map.gltf", "AssetVillageSideLot", Vector3(-23.0, 0.0, 18.0), Vector3(0.075, 0.075, 0.075), Vector3(0.0, 148.0, 0.0))

	_instance_asset(ctx, parent, "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Building01.glb", "AssetLeftStorefrontA", Vector3(-25.0, 0.0, -24.0), Vector3(1.8, 1.8, 1.8), Vector3(0.0, 90.0, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Building02.glb", "AssetLeftStorefrontB", Vector3(-25.0, 0.0, 5.0), Vector3(1.65, 1.65, 1.65), Vector3(0.0, 90.0, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Building01.glb", "AssetRightStorefrontA", Vector3(25.0, 0.0, -4.0), Vector3(1.8, 1.8, 1.8), Vector3(0.0, -90.0, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Building02.glb", "AssetRightStorefrontB", Vector3(25.0, 0.0, 25.0), Vector3(1.65, 1.65, 1.65), Vector3(0.0, -90.0, 0.0))

	_add_asset_cluster(ctx, parent, "NorthCanyon", Vector3(0.0, 0.0, -42.0), 0.0)
	_add_asset_cluster(ctx, parent, "SouthCanyon", Vector3(4.0, 0.0, 42.0), 180.0)
	_add_asset_cluster(ctx, parent, "WestCanyon", Vector3(-42.0, 0.0, 2.0), 90.0)
	_add_asset_cluster(ctx, parent, "EastCanyon", Vector3(42.0, 0.0, -2.0), -90.0)

	_add_existing_upper_route(ctx, parent, "LeftUpperRoute", Vector3(-12.0, 3.9, -10.0), 0.0)
	_add_existing_upper_route(ctx, parent, "RightUpperRoute", Vector3(12.0, 3.9, 13.0), 180.0)
	_add_existing_upper_bridge(ctx, parent, "TownCrossBridgeA", Vector3(0.0, 4.25, -6.0), 90.0)
	_add_existing_upper_bridge(ctx, parent, "TownCrossBridgeB", Vector3(0.0, 4.5, 21.0), 90.0)

	_add_existing_cover_props(ctx, parent)

func _add_asset_cluster(ctx, parent: Node, prefix: String, base: Vector3, yaw: float) -> void:
	_instance_asset(ctx, parent, "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Cliff.glb", prefix + "CliffA", base, Vector3(2.6, 2.2, 2.6), Vector3(0.0, yaw, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Rocks01.glb", prefix + "RocksA", base + Vector3(-8.0, 0.0, 2.5), Vector3(1.8, 1.8, 1.8), Vector3(0.0, yaw + 35.0, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Rocks02.glb", prefix + "RocksB", base + Vector3(8.0, 0.0, -2.5), Vector3(1.65, 1.65, 1.65), Vector3(0.0, yaw - 25.0, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Dunes01.glb", prefix + "DunesA", base + Vector3(0.0, -0.08, 8.0), Vector3(2.8, 1.0, 2.8), Vector3(0.0, yaw, 0.0))

func _add_existing_upper_route(ctx, parent: Node, prefix: String, base: Vector3, yaw: float) -> void:
	_instance_asset(ctx, parent, "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Bld_Bunker_Wood_Floor_Raised_x2_01.glb", prefix + "RaisedFloorA", base, Vector3(1.25, 1.25, 1.25), Vector3(0.0, yaw, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Bld_Bunker_Wood_Floor_Raised_x2_01.glb", prefix + "RaisedFloorB", base + Vector3(0.0, 0.0, 8.0), Vector3(1.25, 1.25, 1.25), Vector3(0.0, yaw, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/synty/PolygonStarter/Models/SM_PolygonPrototype_Buildings_Stairs_1x3_01P.fbx", prefix + "AssetStairsA", base + Vector3(-4.0, -1.85, -7.0), Vector3(2.1, 2.1, 2.1), Vector3(0.0, yaw, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/synty/PolygonStarter/Models/SM_PolygonPrototype_Buildings_Stairs_1x3_01P.fbx", prefix + "AssetStairsB", base + Vector3(4.0, -1.85, 15.0), Vector3(2.1, 2.1, 2.1), Vector3(0.0, yaw + 180.0, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Bld_Industrial_Beam_Fence_01.glb", prefix + "RailA", base + Vector3(-3.0, 0.8, 0.0), Vector3(0.9, 0.9, 0.9), Vector3(0.0, yaw, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Bld_Industrial_Beam_Fence_02.glb", prefix + "RailB", base + Vector3(3.0, 0.8, 8.0), Vector3(0.9, 0.9, 0.9), Vector3(0.0, yaw + 180.0, 0.0))

func _add_existing_upper_bridge(ctx, parent: Node, prefix: String, base: Vector3, yaw: float) -> void:
	_instance_asset(ctx, parent, "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Bld_Bunker_Floor_Wood_02.glb", prefix + "WoodSpanA", base, Vector3(1.8, 1.8, 1.8), Vector3(0.0, yaw, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Bld_Bunker_Floor_Wood_01.glb", prefix + "WoodSpanB", base + Vector3(8.0, 0.0, 0.0), Vector3(1.8, 1.8, 1.8), Vector3(0.0, yaw, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Bld_Bunker_Floor_Wood_01.glb", prefix + "WoodSpanC", base + Vector3(-8.0, 0.0, 0.0), Vector3(1.8, 1.8, 1.8), Vector3(0.0, yaw, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Bld_Industrial_Beam_Fence_01.glb", prefix + "BridgeRailNorth", base + Vector3(0.0, 0.65, -1.8), Vector3(1.1, 1.1, 1.1), Vector3(0.0, yaw, 0.0))
	_instance_asset(ctx, parent, "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Bld_Industrial_Beam_Fence_01.glb", prefix + "BridgeRailSouth", base + Vector3(0.0, 0.65, 1.8), Vector3(1.1, 1.1, 1.1), Vector3(0.0, yaw, 0.0))

func _add_existing_cover_props(ctx, parent: Node) -> void:
	var crate_path: String = "res://assets/unity_migrated/synty/PolygonStarter/Models/SM_PolygonPrototype_Prop_Crate_03.fbx"
	var barrel_a: String = "res://assets/camouflage_props/kaykit_resource_bits/Fuel_A_Barrel.gltf"
	var barrel_b: String = "res://assets/camouflage_props/kaykit_resource_bits/Fuel_B_Barrel.gltf"
	var cactus_path: String = "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Cactus.glb"
	var cow_path: String = "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Cow.glb"
	var pallet_path: String = "res://assets/camouflage_props/kaykit_resource_bits/Pallet_Wood.gltf"
	var rope_path: String = "res://assets/camouflage_props/kaykit_rpg_tools/rope_bundle_A.gltf"
	var lantern_path: String = "res://assets/camouflage_props/kaykit_rpg_tools/lantern.gltf"
	var bucket_path: String = "res://assets/camouflage_props/kaykit_rpg_tools/bucket_metal.gltf"
	var anvil_path: String = "res://assets/camouflage_props/kaykit_rpg_tools/anvil.gltf"
	var saw_path: String = "res://assets/camouflage_props/kaykit_rpg_tools/saw.gltf"
	var pot_cactus_path: String = "res://assets/camouflage_props/tiny_treats_plants/cacti_plant_pot_large.gltf"
	var positions: Array[Vector3] = [
		Vector3(-14.0, 0.0, -30.0), Vector3(-8.0, 0.0, -22.0), Vector3(9.0, 0.0, -25.0), Vector3(16.0, 0.0, -16.0),
		Vector3(-18.0, 0.0, 3.0), Vector3(-6.0, 0.0, 7.0), Vector3(7.0, 0.0, 5.0), Vector3(18.0, 0.0, 8.0),
		Vector3(-15.0, 0.0, 27.0), Vector3(-4.0, 0.0, 28.0), Vector3(8.0, 0.0, 29.0), Vector3(20.0, 0.0, 24.0)
	]
	for index: int in range(positions.size()):
		var path: String = crate_path
		if index % 4 == 1:
			path = barrel_a
		elif index % 4 == 2:
			path = barrel_b
		elif index % 4 == 3:
			path = pallet_path
		_instance_asset(ctx, parent, path, "AssetHideProp%02d" % index, positions[index], Vector3(1.35, 1.35, 1.35), Vector3(0.0, float(index) * 31.0, 0.0))
		_add_asset_shadow_collider(ctx, parent, "AssetHideProp%02dCollision" % index, positions[index] + Vector3(0.0, 0.7, 0.0), Vector3(1.6, 1.4, 1.6))

	for index: int in range(16):
		var angle: float = float(index) * TAU / 16.0
		var radius: float = 32.0 + float(index % 3) * 4.0
		var pos: Vector3 = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_instance_asset(ctx, parent, cactus_path, "AssetPerimeterCactus%02d" % index, pos, Vector3(1.25, 1.25, 1.25), Vector3(0.0, rad_to_deg(angle), 0.0))
		_add_asset_shadow_collider(ctx, parent, "AssetPerimeterCactus%02dCollision" % index, pos + Vector3(0.0, 1.25, 0.0), Vector3(1.2, 2.5, 1.2))

	_instance_asset(ctx, parent, cow_path, "AssetCowNearCorral", Vector3(30.0, 0.0, -12.0), Vector3(1.35, 1.35, 1.35), Vector3(0.0, -115.0, 0.0))
	_instance_asset(ctx, parent, rope_path, "AssetRopeOnUpperWalk", Vector3(-12.5, 4.3, -4.0), Vector3(1.4, 1.4, 1.4), Vector3.ZERO)
	_instance_asset(ctx, parent, lantern_path, "AssetLanternUpperA", Vector3(-1.5, 4.9, -7.0), Vector3(1.2, 1.2, 1.2), Vector3.ZERO)
	_instance_asset(ctx, parent, lantern_path, "AssetLanternUpperB", Vector3(2.0, 5.1, 20.0), Vector3(1.2, 1.2, 1.2), Vector3.ZERO)
	_instance_asset(ctx, parent, bucket_path, "AssetBucketByWell", Vector3(3.0, 0.0, -2.0), Vector3(1.2, 1.2, 1.2), Vector3.ZERO)
	_instance_asset(ctx, parent, anvil_path, "AssetBlacksmithAnvil", Vector3(-20.0, 0.0, 16.0), Vector3(1.35, 1.35, 1.35), Vector3.ZERO)
	_instance_asset(ctx, parent, saw_path, "AssetWorkshopSaw", Vector3(-18.5, 0.0, 18.0), Vector3(1.1, 1.1, 1.1), Vector3.ZERO)
	_instance_asset(ctx, parent, pot_cactus_path, "AssetPottedCactusPorch", Vector3(19.5, 0.0, -4.0), Vector3(1.5, 1.5, 1.5), Vector3.ZERO)

func _add_collision_layout(ctx, parent: Node) -> void:
	_add_collider(ctx, parent, "WesternTownGameplaySupportFloor", Vector3(0.0, -0.08, 0.0), Vector3(92.0, 0.16, 92.0), PackedStringArray([]))
	_add_collider(ctx, parent, "LeftBuildingBlockerA", Vector3(-25.0, 2.0, -24.0), Vector3(9.0, 4.0, 10.0), PackedStringArray(["stalker_shadow_caster"]))
	_add_collider(ctx, parent, "LeftBuildingBlockerB", Vector3(-25.0, 2.0, 5.0), Vector3(9.0, 4.0, 10.0), PackedStringArray(["stalker_shadow_caster"]))
	_add_collider(ctx, parent, "RightBuildingBlockerA", Vector3(25.0, 2.0, -4.0), Vector3(9.0, 4.0, 10.0), PackedStringArray(["stalker_shadow_caster"]))
	_add_collider(ctx, parent, "RightBuildingBlockerB", Vector3(25.0, 2.0, 25.0), Vector3(9.0, 4.0, 10.0), PackedStringArray(["stalker_shadow_caster"]))
	_add_collider(ctx, parent, "LeftUpperWalkableA", Vector3(-12.0, 4.0, -6.0), Vector3(8.0, 0.35, 22.0), PackedStringArray(["stalker_shadow_zone"]))
	_add_collider(ctx, parent, "RightUpperWalkableA", Vector3(12.0, 4.0, 17.0), Vector3(8.0, 0.35, 22.0), PackedStringArray(["stalker_shadow_zone"]))
	_add_collider(ctx, parent, "CrossBridgeWalkableA", Vector3(0.0, 4.32, -6.0), Vector3(26.0, 0.35, 3.6), PackedStringArray(["stalker_shadow_zone"]))
	_add_collider(ctx, parent, "CrossBridgeWalkableB", Vector3(0.0, 4.57, 21.0), Vector3(26.0, 0.35, 3.6), PackedStringArray(["stalker_shadow_zone"]))
	_add_stair_colliders(ctx, parent, "LeftUpperSteps", Vector3(-16.0, 0.0, -17.0), 1.0)
	_add_stair_colliders(ctx, parent, "RightUpperSteps", Vector3(16.0, 0.0, 30.0), -1.0)
	_add_collider(ctx, parent, "NorthCanyonCollision", Vector3(0.0, 2.0, -43.0), Vector3(52.0, 4.0, 7.0), PackedStringArray(["stalker_shadow_caster"]))
	_add_collider(ctx, parent, "SouthCanyonCollision", Vector3(0.0, 2.0, 43.0), Vector3(52.0, 4.0, 7.0), PackedStringArray(["stalker_shadow_caster"]))
	_add_collider(ctx, parent, "WestCanyonCollision", Vector3(-43.0, 2.0, 0.0), Vector3(7.0, 4.0, 52.0), PackedStringArray(["stalker_shadow_caster"]))
	_add_collider(ctx, parent, "EastCanyonCollision", Vector3(43.0, 2.0, 0.0), Vector3(7.0, 4.0, 52.0), PackedStringArray(["stalker_shadow_caster"]))

func _add_stair_colliders(ctx, parent: Node, prefix: String, origin: Vector3, direction_z: float) -> void:
	for index: int in range(12):
		var height: float = 0.35 * float(index + 1)
		var z: float = origin.z + direction_z * float(index) * 0.78
		_add_collider(ctx, parent, prefix + "Step%02d" % index, Vector3(origin.x, origin.y + height * 0.5, z), Vector3(3.0, height, 0.78), PackedStringArray([]))

func _add_gameplay_markers(ctx, parent: Node) -> void:
	var points: Array[Vector3] = [
		Vector3(-30.0, 0.2, -30.0), Vector3(-15.0, 0.2, -34.0), Vector3(0.0, 0.2, -34.0), Vector3(15.0, 0.2, -34.0), Vector3(30.0, 0.2, -30.0), Vector3(34.0, 0.2, -15.0),
		Vector3(34.0, 0.2, 0.0), Vector3(34.0, 0.2, 15.0), Vector3(30.0, 0.2, 30.0), Vector3(15.0, 0.2, 34.0), Vector3(0.0, 0.2, 34.0), Vector3(-15.0, 0.2, 34.0),
		Vector3(-30.0, 0.2, 30.0), Vector3(-34.0, 0.2, 15.0), Vector3(-34.0, 0.2, 0.0), Vector3(-34.0, 0.2, -15.0), Vector3(-10.0, 4.5, -6.0), Vector3(10.0, 4.5, -6.0),
		Vector3(-10.0, 4.7, 21.0), Vector3(10.0, 4.7, 21.0), Vector3(-12.0, 4.3, 2.0), Vector3(12.0, 4.3, 15.0), Vector3(-3.0, 0.2, -5.0), Vector3(4.0, 0.2, 8.0)
	]
	for index: int in range(points.size()):
		var marker: Node3D = Node3D.new()
		marker.name = "WesternSpawnHint%02d" % index
		marker.position = points[index]
		marker.add_to_group(StringName("western_spawn_hint"), true)
		parent.add_child(marker)
		ctx.own(marker)

func _add_preview_camera(ctx, root: Node) -> void:
	var camera: Camera3D = Camera3D.new()
	camera.name = "WesternTownPreviewCamera"
	camera.position = Vector3(36.0, 26.0, 52.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 2.0, 0.0), Vector3.UP)
	camera.fov = 48.0
	root.add_child(camera)
	ctx.own(camera)

func _instance_asset(ctx, parent: Node, scene_path: String, desired_name: String, position: Vector3, scale: Vector3, rotation_degrees: Vector3) -> void:
	var instance: Node3D = ctx.instance_scene(parent, scene_path, desired_name) as Node3D
	if instance == null:
		ctx.log("Skipped asset %s from %s" % [desired_name, scene_path])
		return
	instance.position = position
	instance.scale = scale
	instance.rotation_degrees = rotation_degrees
	ctx.log("Instanced existing asset %s from %s" % [desired_name, scene_path])

func _add_collider(ctx, parent: Node, name: String, position: Vector3, size: Vector3, groups: PackedStringArray) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name
	body.position = position
	body.collision_layer = WORLD_LAYER
	body.collision_mask = PLAYER_MASK
	for group_name: String in groups:
		body.add_to_group(StringName(group_name), true)
	parent.add_child(body)
	ctx.own(body)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = name + "Collision"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	ctx.own(shape_node)
	return body

func _add_asset_shadow_collider(ctx, parent: Node, name: String, position: Vector3, size: Vector3) -> void:
	_add_collider(ctx, parent, name, position, size, PackedStringArray(["stalker_shadow_caster"]))
