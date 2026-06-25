@tool
extends RefCounted

const GROUND_TEXTURE := "res://assets/Map/ground037_alb_ht.png"
const GROUND_NORMAL := "res://assets/Map/ground037_nrm_rgh.png"
const CRATE := "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Prop_Crate_03.glb"
const CRATE_LARGE := "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Prop_Crate_Large_01.glb"
const CRATE_WALL := "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Prop_Crate_Wall_01.glb"
const BARREL_STACK := "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Prop_BarrelStack_01.glb"
const BARREL := "res://assets/camouflage_props/kaykit_resource_bits/Fuel_A_Barrel.gltf"
const PALLET := "res://assets/camouflage_props/kaykit_resource_bits/Pallet_Wood.gltf"
const CART := "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Prop_Cart_01.glb"
const CACTUS := "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Cactus.glb"
const POTTED_CACTUS := "res://assets/camouflage_props/tiny_treats_plants/cacti_plant_pot_large.gltf"
const ROCKS01 := "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Rocks01.glb"
const ROCKS02 := "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Rocks02.glb"
const DUNES := "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/Dunes01.glb"
const BUSH_A := "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Env_Bushes_01.glb"
const BUSH_B := "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Env_Bushes_03.glb"
const GRASS := "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Generic_Grass_Patch_01.glb"
const FENCE := "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Prop_Fence_White_Straight_01.glb"
const WOOD_FLOOR := "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Bld_Bunker_Floor_Wood_01.glb"
const WOOD_CEILING := "res://assets/unity_migrated/polygon_apocalypse/Models/SM_Bld_Bunker_Ceiling_Wood_01.glb"
const LANTERN := "res://assets/camouflage_props/kaykit_rpg_tools/lantern.gltf"
const BUCKET := "res://assets/camouflage_props/kaykit_rpg_tools/bucket_metal.gltf"

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root_name=%s" % String(root.get_name()))
	_safe_remove(ctx, root, "WesternTexturedGround")
	_safe_remove(ctx, root, "WesternDenseCoverPass")
	_safe_remove(ctx, root, "WesternShadowPocketVisuals")
	_safe_remove(ctx, root, "WesternExtraCoverCollision")

	var ground: Node3D = Node3D.new()
	ground.name = "WesternTexturedGround"
	root.add_child(ground)
	ctx.own(ground)
	_create_ground(ctx, ground)

	var cover: Node3D = Node3D.new()
	cover.name = "WesternDenseCoverPass"
	root.add_child(cover)
	ctx.own(cover)

	var shadow_visuals: Node3D = Node3D.new()
	shadow_visuals.name = "WesternShadowPocketVisuals"
	root.add_child(shadow_visuals)
	ctx.own(shadow_visuals)

	var collision_root: Node3D = Node3D.new()
	collision_root.name = "WesternExtraCoverCollision"
	root.add_child(collision_root)
	ctx.own(collision_root)

	var instance_count: int = 0
	var collision_count: int = 0
	var shade_count: int = 0

	# Main street clutter compresses long sightlines but leaves wagon-width lanes open.
	var cover_rows: Array[Dictionary] = [
		{"p": Vector3(-18.0, 0.05, -18.0), "r": 8.0, "s": 1.25, "kind": CRATE_LARGE, "c": Vector3(2.8, 2.0, 2.8)},
		{"p": Vector3(-13.0, 0.05, -15.0), "r": -18.0, "s": 1.05, "kind": BARREL_STACK, "c": Vector3(3.0, 2.2, 2.2)},
		{"p": Vector3(-7.5, 0.05, -18.5), "r": 23.0, "s": 1.15, "kind": CRATE_WALL, "c": Vector3(4.2, 2.2, 1.5)},
		{"p": Vector3(2.0, 0.05, -16.0), "r": -11.0, "s": 1.2, "kind": CART, "c": Vector3(4.0, 2.2, 2.4)},
		{"p": Vector3(8.0, 0.05, -19.0), "r": 14.0, "s": 1.1, "kind": CRATE_LARGE, "c": Vector3(2.8, 2.0, 2.8)},
		{"p": Vector3(15.0, 0.05, -15.0), "r": -26.0, "s": 1.05, "kind": BARREL_STACK, "c": Vector3(3.0, 2.2, 2.2)},
		{"p": Vector3(-20.0, 0.05, -3.0), "r": -12.0, "s": 1.1, "kind": CART, "c": Vector3(4.0, 2.2, 2.4)},
		{"p": Vector3(-11.0, 0.05, -1.0), "r": 26.0, "s": 1.2, "kind": CRATE_WALL, "c": Vector3(4.2, 2.2, 1.5)},
		{"p": Vector3(-3.0, 0.05, -4.0), "r": -33.0, "s": 1.0, "kind": BARREL_STACK, "c": Vector3(3.0, 2.2, 2.2)},
		{"p": Vector3(6.5, 0.05, -1.5), "r": 10.0, "s": 1.15, "kind": CRATE_LARGE, "c": Vector3(2.8, 2.0, 2.8)},
		{"p": Vector3(16.0, 0.05, -4.0), "r": -18.0, "s": 1.1, "kind": CRATE_WALL, "c": Vector3(4.2, 2.2, 1.5)},
		{"p": Vector3(-18.0, 0.05, 12.0), "r": 18.0, "s": 1.1, "kind": BARREL_STACK, "c": Vector3(3.0, 2.2, 2.2)},
		{"p": Vector3(-9.0, 0.05, 15.0), "r": -28.0, "s": 1.2, "kind": CART, "c": Vector3(4.0, 2.2, 2.4)},
		{"p": Vector3(0.0, 0.05, 11.5), "r": 4.0, "s": 1.25, "kind": CRATE_LARGE, "c": Vector3(2.8, 2.0, 2.8)},
		{"p": Vector3(8.5, 0.05, 15.0), "r": 30.0, "s": 1.05, "kind": CRATE_WALL, "c": Vector3(4.2, 2.2, 1.5)},
		{"p": Vector3(18.0, 0.05, 11.0), "r": -10.0, "s": 1.1, "kind": BARREL_STACK, "c": Vector3(3.0, 2.2, 2.2)}
	]
	for entry: Dictionary in cover_rows:
		var prop: Node3D = _instance_asset(ctx, cover, String(entry["kind"]), "StreetCover%02d" % instance_count, entry["p"] as Vector3, float(entry["r"]), Vector3.ONE * float(entry["s"]))
		if prop != null:
			instance_count += 1
			collision_count += _add_box(ctx, collision_root, "StreetCoverCollision%02d" % collision_count, entry["p"] as Vector3 + Vector3(0.0, 1.05, 0.0), entry["c"] as Vector3, float(entry["r"]), true)

	# Repeat small prop clusters around storefront shadows and between buildings.
	var small_positions: Array[Vector3] = [
		Vector3(-28.0, 0.05, -22.0), Vector3(-25.0, 0.05, -12.0), Vector3(-27.0, 0.05, 2.0), Vector3(-24.0, 0.05, 18.0),
		Vector3(24.0, 0.05, -22.0), Vector3(27.0, 0.05, -9.0), Vector3(25.0, 0.05, 4.5), Vector3(27.0, 0.05, 19.0),
		Vector3(-4.5, 0.05, -26.0), Vector3(5.0, 0.05, -26.5), Vector3(-5.5, 0.05, 24.0), Vector3(6.5, 0.05, 24.5)
	]
	for i: int in range(small_positions.size()):
		var p: Vector3 = small_positions[i]
		var barrel: Node3D = _instance_asset(ctx, cover, BARREL, "SmallBarrel%02d" % i, p, float((i * 37) % 360), Vector3.ONE * 1.15)
		if barrel != null:
			instance_count += 1
		var pallet: Node3D = _instance_asset(ctx, cover, PALLET, "SmallPallet%02d" % i, p + Vector3(1.15, 0.0, -0.7), float((i * 53 + 20) % 360), Vector3.ONE * 1.35)
		if pallet != null:
			instance_count += 1
		var tool_path: String = BUCKET if i % 2 == 0 else LANTERN
		var tool: Node3D = _instance_asset(ctx, cover, tool_path, "PorchDetail%02d" % i, p + Vector3(-0.9, 0.0, 0.8), float((i * 23) % 360), Vector3.ONE * 1.0)
		if tool != null:
			instance_count += 1
		collision_count += _add_box(ctx, collision_root, "SmallPropCollision%02d" % i, p + Vector3(0.3, 0.8, 0.0), Vector3(2.6, 1.6, 2.0), float((i * 37) % 360), true)

	# Natural cover fills the canyon rim and gives stalker pockets away from the main street.
	var natural_positions: Array[Dictionary] = [
		{"p": Vector3(-36.0, 0.05, -30.0), "kind": ROCKS01, "s": Vector3(1.8, 1.6, 1.8)},
		{"p": Vector3(-31.0, 0.05, -26.0), "kind": BUSH_A, "s": Vector3(1.7, 1.7, 1.7)},
		{"p": Vector3(-35.0, 0.05, -8.0), "kind": CACTUS, "s": Vector3(1.8, 1.8, 1.8)},
		{"p": Vector3(-34.0, 0.05, 10.0), "kind": ROCKS02, "s": Vector3(1.5, 1.5, 1.5)},
		{"p": Vector3(-30.0, 0.05, 29.0), "kind": BUSH_B, "s": Vector3(1.8, 1.8, 1.8)},
		{"p": Vector3(34.0, 0.05, -30.0), "kind": ROCKS02, "s": Vector3(1.5, 1.5, 1.5)},
		{"p": Vector3(30.0, 0.05, -25.0), "kind": BUSH_B, "s": Vector3(1.6, 1.6, 1.6)},
		{"p": Vector3(36.0, 0.05, -7.0), "kind": CACTUS, "s": Vector3(1.9, 1.9, 1.9)},
		{"p": Vector3(34.0, 0.05, 11.0), "kind": ROCKS01, "s": Vector3(1.7, 1.7, 1.7)},
		{"p": Vector3(31.0, 0.05, 27.0), "kind": BUSH_A, "s": Vector3(1.7, 1.7, 1.7)},
		{"p": Vector3(-14.0, 0.05, -33.0), "kind": DUNES, "s": Vector3(1.4, 1.0, 1.4)},
		{"p": Vector3(14.0, 0.05, -34.0), "kind": DUNES, "s": Vector3(1.4, 1.0, 1.4)},
		{"p": Vector3(-14.0, 0.05, 33.0), "kind": DUNES, "s": Vector3(1.4, 1.0, 1.4)},
		{"p": Vector3(14.0, 0.05, 34.0), "kind": DUNES, "s": Vector3(1.4, 1.0, 1.4)}
	]
	for i: int in range(natural_positions.size()):
		var n: Dictionary = natural_positions[i]
		var natural: Node3D = _instance_asset(ctx, cover, String(n["kind"]), "RimNaturalCover%02d" % i, n["p"] as Vector3, float((i * 41 + 15) % 360), n["s"] as Vector3)
		if natural != null:
			instance_count += 1
		collision_count += _add_box(ctx, collision_root, "NaturalCoverCollision%02d" % i, n["p"] as Vector3 + Vector3(0.0, 1.0, 0.0), Vector3(3.2, 2.0, 3.2), float((i * 41 + 15) % 360), true)

	# Fences break the open center into readable prop-hunt lanes without fully blocking rotations.
	for i: int in range(12):
		var side: float = -1.0 if i < 6 else 1.0
		var local_index: int = i if i < 6 else i - 6
		var fence_pos: Vector3 = Vector3(-18.0 + float(local_index) * 7.0, 0.05, side * 29.0)
		var fence: Node3D = _instance_asset(ctx, cover, FENCE, "LooseFence%02d" % i, fence_pos, 0.0, Vector3.ONE * 1.65)
		if fence != null:
			instance_count += 1
		collision_count += _add_box(ctx, collision_root, "LooseFenceCollision%02d" % i, fence_pos + Vector3(0.0, 0.75, 0.0), Vector3(4.2, 1.5, 0.45), 0.0, true)

	# A few porch roof/awning pieces make intentional dark pockets under the upper walkways.
	var awnings: Array[Dictionary] = [
		{"p": Vector3(-26.0, 3.15, -17.0), "r": 0.0, "s": Vector3(1.8, 0.8, 1.8), "shade": Vector3(-26.0, 0.04, -17.0)},
		{"p": Vector3(-25.5, 3.15, 7.0), "r": 0.0, "s": Vector3(1.8, 0.8, 1.8), "shade": Vector3(-25.5, 0.04, 7.0)},
		{"p": Vector3(25.0, 3.15, -16.0), "r": 180.0, "s": Vector3(1.8, 0.8, 1.8), "shade": Vector3(25.0, 0.04, -16.0)},
		{"p": Vector3(25.5, 3.15, 7.5), "r": 180.0, "s": Vector3(1.8, 0.8, 1.8), "shade": Vector3(25.5, 0.04, 7.5)},
		{"p": Vector3(-5.0, 3.05, -12.5), "r": 90.0, "s": Vector3(1.5, 0.8, 1.5), "shade": Vector3(-5.0, 0.04, -12.5)},
		{"p": Vector3(7.0, 3.05, 10.5), "r": -90.0, "s": Vector3(1.5, 0.8, 1.5), "shade": Vector3(7.0, 0.04, 10.5)}
	]
	for i: int in range(awnings.size()):
		var a: Dictionary = awnings[i]
		var roof: Node3D = _instance_asset(ctx, cover, WOOD_CEILING, "ShadowPorchRoof%02d" % i, a["p"] as Vector3, float(a["r"]), a["s"] as Vector3)
		if roof != null:
			instance_count += 1
		collision_count += _add_box(ctx, collision_root, "ShadowPorchRoofCollision%02d" % i, a["p"] as Vector3, Vector3(8.0, 0.5, 5.5), float(a["r"]), true)
		_create_shadow_patch(ctx, shadow_visuals, "ShadowPocket%02d" % i, a["shade"] as Vector3, Vector2(9.0, 6.5), float(a["r"]))
		shade_count += 1

	# Ground clutter and grass tufts add prop silhouettes at player scale.
	for i: int in range(28):
		var angle: float = float(i) * 0.73
		var radius: float = 10.0 + float(i % 7) * 3.1
		var p: Vector3 = Vector3(cos(angle) * radius, 0.05, sin(angle * 1.27) * radius)
		var asset_path: String = GRASS if i % 3 == 0 else POTTED_CACTUS
		var scale_value: float = 1.15 + float(i % 4) * 0.12
		var small_natural: Node3D = _instance_asset(ctx, cover, asset_path, "StreetMicroCover%02d" % i, p, float((i * 31) % 360), Vector3.ONE * scale_value)
		if small_natural != null:
			instance_count += 1

	# Tune sun to throw long shadows across the street instead of lighting everything flat.
	var sun: DirectionalLight3D = root.get_node_or_null("WesternLowSun") as DirectionalLight3D
	if sun != null:
		sun.rotation_degrees = Vector3(-28.0, -48.0, 0.0)
		sun.light_energy = 1.2
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 140.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		ctx.log("Updated low sun for longer stalker shadow pockets")

	var camera: Camera3D = root.get_node_or_null("WesternTownPreviewCamera") as Camera3D
	if camera != null:
		camera.position = Vector3(0.0, 38.0, 56.0)
		camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)
		camera.fov = 55.0

	ctx.log("Added textured ground, dense cover instances=%d collisions=%d shadow_patches=%d" % [instance_count, collision_count, shade_count])
	ctx.mark_modified()

func _safe_remove(ctx, root: Node, node_name: String) -> void:
	if root.get_node_or_null(node_name) != null:
		var removed: bool = ctx.remove_node(node_name)
		ctx.log("safe_remove %s=%s" % [node_name, str(removed)])
	else:
		ctx.log("safe_remove skipped missing %s" % node_name)

func _create_ground(ctx, parent: Node3D) -> void:
	var ground_mesh: PlaneMesh = PlaneMesh.new()
	ground_mesh.size = Vector2(104.0, 88.0)
	ground_mesh.subdivide_width = 64
	ground_mesh.subdivide_depth = 54
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.resource_name = "WesternRepeatedSandMaterial"
	mat.albedo_color = Color(0.93, 0.68, 0.38, 1.0)
	mat.roughness = 0.86
	mat.uv1_scale = Vector3(30.0, 30.0, 1.0)
	if ResourceLoader.exists(GROUND_TEXTURE):
		var albedo: Texture2D = load(GROUND_TEXTURE) as Texture2D
		mat.albedo_texture = albedo
		ctx.log("Ground albedo texture assigned")
	else:
		ctx.log("Ground albedo texture missing")
	if ResourceLoader.exists(GROUND_NORMAL):
		var normal: Texture2D = load(GROUND_NORMAL) as Texture2D
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = 0.55
		ctx.log("Ground normal texture assigned")
	ground_mesh.material = mat
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "WesternRepeatedSandPlane"
	ground.mesh = ground_mesh
	ground.position = Vector3(0.0, 0.0, 0.0)
	parent.add_child(ground)
	ctx.own(ground)

	var road_mat: StandardMaterial3D = StandardMaterial3D.new()
	road_mat.resource_name = "WesternPackedSandRoadMaterial"
	road_mat.albedo_color = Color(0.64, 0.39, 0.19, 1.0)
	road_mat.roughness = 0.94
	var road_shapes: Array[Dictionary] = [
		{"name": "MainStreetPackedSand", "pos": Vector3(0.0, 0.025, -2.0), "size": Vector2(18.0, 72.0), "rot": 0.0},
		{"name": "CrossStreetPackedSand", "pos": Vector3(0.0, 0.03, 4.0), "size": Vector2(66.0, 14.0), "rot": 0.0},
		{"name": "BackAlleyPackedSand", "pos": Vector3(0.0, 0.035, 24.0), "size": Vector2(58.0, 8.0), "rot": 0.0}
	]
	for entry: Dictionary in road_shapes:
		var road_mesh: PlaneMesh = PlaneMesh.new()
		road_mesh.size = entry["size"] as Vector2
		road_mesh.subdivide_width = 12
		road_mesh.subdivide_depth = 12
		road_mesh.material = road_mat
		var road: MeshInstance3D = MeshInstance3D.new()
		road.name = String(entry["name"])
		road.mesh = road_mesh
		road.position = entry["pos"] as Vector3
		road.rotation_degrees = Vector3(0.0, float(entry["rot"]), 0.0)
		parent.add_child(road)
		ctx.own(road)

func _instance_asset(ctx, parent: Node3D, scene_path: String, desired_name: String, position: Vector3, yaw_degrees: float, scale_value: Vector3) -> Node3D:
	if not ResourceLoader.exists(scene_path):
		ctx.log("Missing asset %s" % scene_path)
		return null
	var instanced: Node3D = ctx.instance_scene(parent, scene_path, desired_name) as Node3D
	if instanced == null:
		ctx.log("Failed instance %s" % scene_path)
		return null
	instanced.position = position
	instanced.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	instanced.scale = scale_value
	return instanced

func _add_box(ctx, parent: Node3D, box_name: String, position: Vector3, size: Vector3, yaw_degrees: float, shadow_caster: bool) -> int:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = box_name
	body.position = position
	body.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	if shadow_caster:
		body.add_to_group("stalker_shadow_caster")
	parent.add_child(body)
	ctx.own(body)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "%sShape" % box_name
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	ctx.own(shape)
	return 1

func _create_shadow_patch(ctx, parent: Node3D, patch_name: String, position: Vector3, size: Vector2, yaw_degrees: float) -> void:
	var patch_mesh: PlaneMesh = PlaneMesh.new()
	patch_mesh.size = size
	patch_mesh.subdivide_width = 4
	patch_mesh.subdivide_depth = 4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.resource_name = "%sMaterial" % patch_name
	mat.albedo_color = Color(0.16, 0.10, 0.07, 0.58)
	mat.roughness = 1.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	patch_mesh.material = mat
	var patch: MeshInstance3D = MeshInstance3D.new()
	patch.name = patch_name
	patch.mesh = patch_mesh
	patch.position = position
	patch.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	patch.add_to_group("stalker_shadow_zone")
	parent.add_child(patch)
	ctx.own(patch)
