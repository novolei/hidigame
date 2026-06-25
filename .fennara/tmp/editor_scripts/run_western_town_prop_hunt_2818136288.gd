@tool
extends RefCounted

const WORLD_LAYER: int = 2
const PLAYER_MASK: int = 1

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root_class=%s" % root.get_class())
	ctx.log("root_name=%s" % String(root.get_name()))

	_remove_child_if_present(ctx, root, "WesternVerticalRoutes")
	_remove_child_if_present(ctx, root, "WesternAssetSetDressing")

	var wood: StandardMaterial3D = _mat("Upper warm timber", Color(0.66, 0.31, 0.12, 1.0), 0.72)
	var dark_wood: StandardMaterial3D = _mat("Dark rail timber", Color(0.34, 0.15, 0.06, 1.0), 0.82)
	var pale_wood: StandardMaterial3D = _mat("Sun bleached plank", Color(0.86, 0.57, 0.25, 1.0), 0.74)
	var red_rock: StandardMaterial3D = _mat("Painted canyon rock", Color(0.78, 0.30, 0.12, 1.0), 0.9)
	var sand: StandardMaterial3D = _mat("Packed step sand", Color(0.83, 0.59, 0.31, 1.0), 0.95)
	var hay: StandardMaterial3D = _mat("Dry hay", Color(0.95, 0.72, 0.23, 1.0), 0.88)

	var routes: Node3D = Node3D.new()
	routes.name = "WesternVerticalRoutes"
	root.add_child(routes)
	ctx.own(routes)

	var dressing: Node3D = Node3D.new()
	dressing.name = "WesternAssetSetDressing"
	root.add_child(dressing)
	ctx.own(dressing)

	_add_upper_walkway(ctx, routes, "LeftUpperBoardwalk", Vector3(-13.5, 4.1, 0.0), wood, dark_wood)
	_add_upper_walkway(ctx, routes, "RightUpperBoardwalk", Vector3(13.5, 4.1, 0.0), wood, dark_wood)
	_add_cross_bridge(ctx, routes, "MarshalCrossBridge", Vector3(0.0, 4.25, -3.0), pale_wood, dark_wood)
	_add_cross_bridge(ctx, routes, "WaterTowerCrossBridge", Vector3(0.0, 4.65, 19.0), wood, dark_wood)
	_add_staircase(ctx, routes, "LeftSaloonStairs", Vector3(-18.2, 0.0, -29.0), 1.0, wood, dark_wood)
	_add_staircase(ctx, routes, "RightTheatreStairs", Vector3(18.2, 0.0, 29.0), -1.0, wood, dark_wood)
	_add_staircase(ctx, routes, "CenterMarketStairs", Vector3(-5.0, 0.0, 4.0), 1.0, pale_wood, dark_wood)
	_add_roof_deck(ctx, routes, "SheriffRoofHideout", Vector3(-22.0, 7.95, -28.0), Vector3(10.0, 0.3, 7.5), wood, dark_wood)
	_add_roof_deck(ctx, routes, "HotelRoofHideout", Vector3(-22.0, 8.35, 10.0), Vector3(9.0, 0.3, 9.5), pale_wood, dark_wood)
	_add_roof_deck(ctx, routes, "TheatreRoofHideout", Vector3(22.5, 8.1, 9.0), Vector3(10.0, 0.3, 8.0), wood, dark_wood)
	_add_roof_deck(ctx, routes, "BarnRoofHideout", Vector3(22.0, 7.7, -28.0), Vector3(11.0, 0.3, 7.0), wood, dark_wood)
	_add_canyon_tier(ctx, routes, "NorthMesaLedge", Vector3(-4.0, 2.2, -39.0), Vector3(30.0, 0.5, 6.0), red_rock, sand)
	_add_canyon_tier(ctx, routes, "SouthMesaLedge", Vector3(5.0, 2.0, 39.0), Vector3(28.0, 0.5, 6.5), red_rock, sand)
	_add_canyon_tier(ctx, routes, "WestRockShelf", Vector3(-39.0, 1.7, 8.0), Vector3(7.0, 0.5, 26.0), red_rock, sand)
	_add_canyon_tier(ctx, routes, "EastRockShelf", Vector3(39.0, 1.7, -8.0), Vector3(7.0, 0.5, 26.0), red_rock, sand)

	_add_upper_cover(ctx, routes, wood, dark_wood, hay)
	_add_asset_dressing(ctx, dressing)
	ctx.mark_modified()
	ctx.log("Added layered western traversal: 2 elevated boardwalks, 2 bridges, 3 staircases, 4 roof decks, 4 canyon shelves, and existing asset dressing")

func _remove_child_if_present(ctx, root: Node, child_name: String) -> void:
	var existing: Node = root.get_node_or_null(NodePath(child_name))
	if existing == null:
		ctx.log("No existing node named %s to remove" % child_name)
		return
	if ctx.remove_node(child_name):
		ctx.log("Removed previous node %s" % child_name)

func _mat(label: String, color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = label
	material.albedo_color = color
	material.roughness = roughness
	return material

func _add_box(ctx, parent: Node, name: String, position: Vector3, size: Vector3, material: StandardMaterial3D, collide: bool, groups: PackedStringArray, rotation_degrees: Vector3 = Vector3.ZERO) -> Node3D:
	var node: Node3D
	if collide:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = WORLD_LAYER
		body.collision_mask = PLAYER_MASK
		node = body
	else:
		node = Node3D.new()
	node.name = name
	node.position = position
	node.rotation_degrees = rotation_degrees
	parent.add_child(node)
	ctx.own(node)
	for group_name: String in groups:
		node.add_to_group(StringName(group_name), true)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = name + "Mesh"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	node.add_child(mesh_instance)
	ctx.own(mesh_instance)

	if collide:
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		shape_node.name = name + "Collision"
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		node.add_child(shape_node)
		ctx.own(shape_node)
	return node

func _add_upper_walkway(ctx, parent: Node, name: String, base: Vector3, deck_material: StandardMaterial3D, rail_material: StandardMaterial3D) -> void:
	_add_box(ctx, parent, name + "Deck", base, Vector3(3.2, 0.35, 62.0), deck_material, true, PackedStringArray(["stalker_shadow_caster"]))
	_add_box(ctx, parent, name + "InnerRail", base + Vector3(0.0, 0.9, -31.2), Vector3(3.4, 1.4, 0.22), rail_material, true, PackedStringArray(["stalker_shadow_caster"]))
	_add_box(ctx, parent, name + "OuterRail", base + Vector3(0.0, 0.9, 31.2), Vector3(3.4, 1.4, 0.22), rail_material, true, PackedStringArray(["stalker_shadow_caster"]))
	for index: int in range(7):
		var z: float = -27.0 + float(index) * 9.0
		_add_box(ctx, parent, name + "Post%02dA" % index, Vector3(base.x - 1.45, 2.0, z), Vector3(0.32, 4.2, 0.32), rail_material, true, PackedStringArray(["stalker_shadow_caster"]))
		_add_box(ctx, parent, name + "Post%02dB" % index, Vector3(base.x + 1.45, 2.0, z), Vector3(0.32, 4.2, 0.32), rail_material, true, PackedStringArray(["stalker_shadow_caster"]))

func _add_cross_bridge(ctx, parent: Node, name: String, base: Vector3, deck_material: StandardMaterial3D, rail_material: StandardMaterial3D) -> void:
	_add_box(ctx, parent, name + "Deck", base, Vector3(28.0, 0.35, 3.0), deck_material, true, PackedStringArray(["stalker_shadow_caster", "stalker_shadow_zone"]))
	_add_box(ctx, parent, name + "NorthRail", base + Vector3(0.0, 0.85, -1.55), Vector3(28.2, 1.25, 0.22), rail_material, true, PackedStringArray(["stalker_shadow_caster"]))
	_add_box(ctx, parent, name + "SouthRail", base + Vector3(0.0, 0.85, 1.55), Vector3(28.2, 1.25, 0.22), rail_material, true, PackedStringArray(["stalker_shadow_caster"]))
	_add_box(ctx, parent, name + "HangingSign", base + Vector3(0.0, -1.0, 0.0), Vector3(5.8, 1.0, 0.18), deck_material, false, PackedStringArray([]))

func _add_staircase(ctx, parent: Node, name: String, origin: Vector3, direction_z: float, tread_material: StandardMaterial3D, rail_material: StandardMaterial3D) -> void:
	var step_count: int = 12
	var step_depth: float = 0.78
	var step_height: float = 0.35
	var width: float = 3.0
	for index: int in range(step_count):
		var height: float = step_height * float(index + 1)
		var z: float = origin.z + direction_z * (float(index) * step_depth)
		var position: Vector3 = Vector3(origin.x, origin.y + height * 0.5, z)
		_add_box(ctx, parent, name + "Step%02d" % index, position, Vector3(width, height, step_depth), tread_material, true, PackedStringArray(["stalker_shadow_caster"]))
	var rail_z: float = origin.z + direction_z * (float(step_count) * step_depth * 0.5)
	var rail_y: float = origin.y + 2.7
	_add_box(ctx, parent, name + "LeftRail", Vector3(origin.x - width * 0.58, rail_y, rail_z), Vector3(0.24, 1.2, step_depth * float(step_count)), rail_material, true, PackedStringArray(["stalker_shadow_caster"]))
	_add_box(ctx, parent, name + "RightRail", Vector3(origin.x + width * 0.58, rail_y, rail_z), Vector3(0.24, 1.2, step_depth * float(step_count)), rail_material, true, PackedStringArray(["stalker_shadow_caster"]))

func _add_roof_deck(ctx, parent: Node, name: String, base: Vector3, size: Vector3, deck_material: StandardMaterial3D, rail_material: StandardMaterial3D) -> void:
	_add_box(ctx, parent, name + "Deck", base, size, deck_material, true, PackedStringArray(["stalker_shadow_caster", "stalker_shadow_zone"]))
	_add_box(ctx, parent, name + "FrontRail", base + Vector3(0.0, 0.8, size.z * 0.5), Vector3(size.x, 1.2, 0.22), rail_material, true, PackedStringArray(["stalker_shadow_caster"]))
	_add_box(ctx, parent, name + "BackRail", base + Vector3(0.0, 0.8, -size.z * 0.5), Vector3(size.x, 1.2, 0.22), rail_material, true, PackedStringArray(["stalker_shadow_caster"]))
	_add_box(ctx, parent, name + "LeftRail", base + Vector3(-size.x * 0.5, 0.8, 0.0), Vector3(0.22, 1.2, size.z), rail_material, true, PackedStringArray(["stalker_shadow_caster"]))
	_add_box(ctx, parent, name + "RightRail", base + Vector3(size.x * 0.5, 0.8, 0.0), Vector3(0.22, 1.2, size.z), rail_material, true, PackedStringArray(["stalker_shadow_caster"]))

func _add_canyon_tier(ctx, parent: Node, name: String, base: Vector3, size: Vector3, rock_material: StandardMaterial3D, sand_material: StandardMaterial3D) -> void:
	_add_box(ctx, parent, name + "RockMass", base + Vector3(0.0, -0.8, 0.0), Vector3(size.x, 1.8, size.z), rock_material, true, PackedStringArray(["stalker_shadow_caster"]))
	_add_box(ctx, parent, name + "WalkableTop", base + Vector3(0.0, 0.02, 0.0), size, sand_material, true, PackedStringArray(["stalker_shadow_zone"]))
	_add_box(ctx, parent, name + "LowCoverA", base + Vector3(size.x * 0.25, 0.65, -size.z * 0.2), Vector3(3.4, 1.1, 1.1), rock_material, true, PackedStringArray(["stalker_shadow_caster"]))
	_add_box(ctx, parent, name + "LowCoverB", base + Vector3(-size.x * 0.25, 0.65, size.z * 0.18), Vector3(3.0, 1.0, 1.0), rock_material, true, PackedStringArray(["stalker_shadow_caster"]))

func _add_upper_cover(ctx, parent: Node, wood: StandardMaterial3D, dark_wood: StandardMaterial3D, hay: StandardMaterial3D) -> void:
	var cover_positions: Array[Vector3] = [
		Vector3(-13.4, 4.65, -22.0), Vector3(-13.7, 4.65, -7.0), Vector3(-13.6, 4.65, 13.0), Vector3(-13.4, 4.65, 27.0),
		Vector3(13.4, 4.65, -25.0), Vector3(13.7, 4.65, -10.0), Vector3(13.6, 4.65, 8.0), Vector3(13.4, 4.65, 24.0),
		Vector3(-2.0, 4.85, -3.2), Vector3(5.2, 5.25, 19.0), Vector3(-22.0, 8.55, -28.0), Vector3(22.5, 8.7, 9.0)
	]
	for index: int in range(cover_positions.size()):
		var material: StandardMaterial3D = wood
		var size: Vector3 = Vector3(1.5, 1.2, 1.5)
		if index % 3 == 1:
			material = dark_wood
			size = Vector3(1.2, 1.5, 1.2)
		elif index % 3 == 2:
			material = hay
			size = Vector3(2.0, 1.0, 1.3)
		_add_box(ctx, parent, "UpperHideCover%02d" % index, cover_positions[index], size, material, true, PackedStringArray(["stalker_shadow_caster"]))

func _add_asset_dressing(ctx, parent: Node) -> void:
	_instance_asset(ctx, parent, "res://assets/camouflage_props/kaykit_resource_bits/Pallet_Wood.gltf", "PalletStackNorth", Vector3(-30.0, 0.06, -18.0), Vector3(1.3, 1.3, 1.3), Vector3(0.0, 22.0, 0.0))
	_instance_asset(ctx, parent, "res://assets/camouflage_props/kaykit_resource_bits/Pallet_Wood.gltf", "PalletStackSouth", Vector3(29.5, 0.06, 18.0), Vector3(1.2, 1.2, 1.2), Vector3(0.0, -18.0, 0.0))
	_instance_asset(ctx, parent, "res://assets/camouflage_props/kaykit_resource_bits/Fuel_A_Barrel.gltf", "OilBarrelBySheriff", Vector3(-18.5, 0.05, -20.0), Vector3(1.1, 1.1, 1.1), Vector3.ZERO)
	_instance_asset(ctx, parent, "res://assets/camouflage_props/kaykit_resource_bits/Fuel_B_Barrel.gltf", "OilBarrelByTheatre", Vector3(18.5, 0.05, 16.5), Vector3(1.1, 1.1, 1.1), Vector3.ZERO)
	_instance_asset(ctx, parent, "res://assets/camouflage_props/kaykit_rpg_tools/lantern.gltf", "LanternBridgeLeft", Vector3(-6.5, 4.05, -4.7), Vector3(1.0, 1.0, 1.0), Vector3.ZERO)
	_instance_asset(ctx, parent, "res://assets/camouflage_props/kaykit_rpg_tools/lantern.gltf", "LanternBridgeRight", Vector3(6.5, 4.05, -4.7), Vector3(1.0, 1.0, 1.0), Vector3.ZERO)
	_instance_asset(ctx, parent, "res://assets/camouflage_props/kaykit_rpg_tools/rope_bundle_A.gltf", "RopeBundleUpper", Vector3(-13.5, 4.7, 10.5), Vector3(1.25, 1.25, 1.25), Vector3.ZERO)
	_instance_asset(ctx, parent, "res://assets/camouflage_props/kaykit_rpg_tools/bucket_metal.gltf", "WaterBucketUpper", Vector3(13.4, 4.7, -11.5), Vector3(1.15, 1.15, 1.15), Vector3.ZERO)
	for index: int in range(8):
		var angle: float = float(index) * 0.785398
		var radius: float = 34.0 + float(index % 2) * 3.0
		var pos: Vector3 = Vector3(cos(angle) * radius, 0.05, sin(angle) * radius)
		_instance_asset(ctx, parent, "res://assets/camouflage_props/tiny_treats_plants/cactus_A.gltf", "AssetCactus%02d" % index, pos, Vector3(1.2, 1.2, 1.2), Vector3(0.0, rad_to_deg(angle), 0.0))
	for index: int in range(6):
		var x: float = -32.0 + float(index) * 12.0
		var z: float = 33.0 if index % 2 == 0 else -33.0
		_instance_asset(ctx, parent, "res://assets/camouflage_props/stones_fbx/MediumStone (3).fbx", "ImportedMesaStone%02d" % index, Vector3(x, 0.02, z), Vector3(0.8, 0.8, 0.8), Vector3(0.0, float(index) * 27.0, 0.0))

func _instance_asset(ctx, parent: Node, scene_path: String, desired_name: String, position: Vector3, scale: Vector3, rotation_degrees: Vector3) -> void:
	var instance: Node3D = ctx.instance_scene(parent, scene_path, desired_name) as Node3D
	if instance == null:
		ctx.log("Skipped asset %s from %s" % [desired_name, scene_path])
		return
	instance.position = position
	instance.scale = scale
	instance.rotation_degrees = rotation_degrees
	ctx.log("Instanced asset %s" % desired_name)
