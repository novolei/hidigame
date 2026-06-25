@tool
extends RefCounted

const TANK_BODY_MATERIALS: Array[String] = [
	"res://Materials/M_tank_demo_tank_color.tres",
	"res://Materials/M_tank_demo_tank_blue.tres",
	"res://Materials/M_unity_tanks_red.tres"
]

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root_class=%s" % root.get_class())
	ctx.log("root_name=%s" % String(root.get_name()))

	var mats: Dictionary = _load_materials(ctx)
	if mats.is_empty():
		ctx.error("No western material resources could be loaded")
		return

	var existing_tank_decor: Node = root.get_node_or_null("WesternTankDecor")
	if existing_tank_decor != null:
		var removed: bool = ctx.remove_node("WesternTankDecor")
		ctx.log("removed_existing_WesternTankDecor=%s" % str(removed))

	var tank_root: Node3D = Node3D.new()
	tank_root.name = "WesternTankDecor"
	root.add_child(tank_root)
	ctx.own(tank_root)

	var added_tanks: int = _add_fixed_tanks(ctx, tank_root, mats)
	var material_result: Dictionary = _apply_western_materials(root, mats)
	ctx.log("added_fixed_tanks=%d" % added_tanks)
	ctx.log("materialized_meshes=%d" % int(material_result.get("mesh_count", 0)))
	ctx.log("materialized_surfaces=%d" % int(material_result.get("surface_count", 0)))
	ctx.log("tank_surfaces=%d" % int(material_result.get("tank_surfaces", 0)))
	ctx.mark_modified()


func _load_materials(ctx) -> Dictionary:
	var paths: Dictionary = {
		"sand": "res://Materials/M_tank_demo_desert_ground.tres",
		"wood": "res://Materials/M_unity_synty_wood.tres",
		"rock": "res://Materials/M_unity_synty_rock.tres",
		"stone": "res://Materials/M_tank_demo_stone.tres",
		"green": "res://Materials/M_tank_demo_green.tres",
		"green_dark": "res://Materials/M_tank_demo_green_dark.tres",
		"cactus": "res://Materials/M_unity_tanks_cactus.tres",
		"metal": "res://Materials/M_tank_demo_building_metal.tres",
		"building_white": "res://Materials/M_tank_demo_building_white.tres",
		"building_grey": "res://Materials/M_tank_demo_building_grey.tres",
		"building_glass": "res://Materials/M_tank_demo_building_glass.tres",
		"brown": "res://Materials/M_tank_demo_brown.tres",
		"oil": "res://Materials/M_tank_demo_oil.tres",
		"tank_body": "res://Materials/M_tank_demo_tank_color.tres",
		"tank_blue": "res://Materials/M_tank_demo_tank_blue.tres",
		"tank_red": "res://Materials/M_unity_tanks_red.tres",
		"tank_grey": "res://Materials/M_tank_demo_tank_grey.tres",
		"tank_lights": "res://Materials/M_tank_demo_tank_lights.tres",
		"yellow": "res://Materials/M_tank_demo_yellow_mid.tres"
	}
	var mats: Dictionary = {}
	for key: String in paths.keys():
		var path: String = String(paths[key])
		var loaded: Resource = load(path)
		if loaded is Material:
			mats[key] = loaded as Material
		else:
			ctx.log("missing_material=%s path=%s" % [key, path])
	return mats


func _add_fixed_tanks(ctx, tank_root: Node3D, mats: Dictionary) -> int:
	var tank_specs: Array[Dictionary] = [
		{
			"name": "DecorTankSheriffGate",
			"scene": "res://assets/unity_migrated/tanks_complete/Art/Models/Tanks/Tank_Original_Model.glb",
			"position": Vector3(-13.5, 0.35, -6.5),
			"rotation_y": deg_to_rad(22.0),
			"scale": Vector3(1.45, 1.45, 1.45),
			"body_key": "tank_body",
			"collision_size": Vector3(4.4, 2.0, 5.0)
		},
		{
			"name": "DecorTankCanyonWreck",
			"scene": "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/BustedTank.glb",
			"position": Vector3(12.0, 0.3, 8.0),
			"rotation_y": deg_to_rad(-36.0),
			"scale": Vector3(1.35, 1.35, 1.35),
			"body_key": "metal",
			"collision_size": Vector3(4.0, 1.8, 4.8)
		},
		{
			"name": "DecorTankWaterTowerLane",
			"scene": "res://assets/unity_migrated/tanks_complete/Art/Models/Tanks/Tank_Light_Model.glb",
			"position": Vector3(5.5, 0.35, -13.0),
			"rotation_y": deg_to_rad(145.0),
			"scale": Vector3(1.25, 1.25, 1.25),
			"body_key": "tank_blue",
			"collision_size": Vector3(3.6, 1.8, 4.2)
		}
	]

	var added_count: int = 0
	for spec: Dictionary in tank_specs:
		var tank_scene: String = String(spec["scene"])
		var tank_name: String = String(spec["name"])
		var tank: Node3D = ctx.instance_scene(tank_root, tank_scene, tank_name) as Node3D
		if tank == null:
			ctx.log("tank_instance_failed=%s" % tank_scene)
			continue
		tank.position = spec["position"] as Vector3
		tank.rotation.y = float(spec["rotation_y"])
		tank.scale = spec["scale"] as Vector3
		_apply_tank_materials(tank, mats, String(spec["body_key"]))
		_add_tank_collision(ctx, tank_root, tank_name, tank.position, tank.rotation.y, spec["collision_size"] as Vector3)
		added_count += 1
	return added_count


func _add_tank_collision(ctx, tank_root: Node3D, tank_name: String, pos: Vector3, yaw: float, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = tank_name + "Collision"
	body.position = pos + Vector3(0.0, size.y * 0.5, 0.0)
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("stalker_shadow_caster")
	tank_root.add_child(body)
	ctx.own(body)

	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = tank_name + "CollisionShape"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	ctx.own(shape)


func _apply_western_materials(root: Node, mats: Dictionary) -> Dictionary:
	var result: Dictionary = {"mesh_count": 0, "surface_count": 0, "tank_surfaces": 0}
	_apply_western_materials_recursive(root, mats, result)
	return result


func _apply_western_materials_recursive(node: Node, mats: Dictionary, result: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			var surface_count: int = mesh_instance.mesh.get_surface_count()
			var touched: bool = false
			for surface_index: int in range(surface_count):
				var material: Material = _choose_material(mesh_instance, surface_index, mats)
				if material != null:
					mesh_instance.set_surface_override_material(surface_index, material)
					result["surface_count"] = int(result["surface_count"]) + 1
					if _looks_like_tank(mesh_instance):
						result["tank_surfaces"] = int(result["tank_surfaces"]) + 1
					touched = true
			if touched:
				result["mesh_count"] = int(result["mesh_count"]) + 1
	for child: Node in node.get_children():
		_apply_western_materials_recursive(child, mats, result)


func _apply_tank_materials(node: Node, mats: Dictionary, body_key: String) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			var surface_count: int = mesh_instance.mesh.get_surface_count()
			for surface_index: int in range(surface_count):
				var material: Material = _choose_tank_surface_material(mesh_instance, surface_index, mats, body_key)
				if material != null:
					mesh_instance.set_surface_override_material(surface_index, material)
	for child: Node in node.get_children():
		_apply_tank_materials(child, mats, body_key)


func _choose_material(mesh_instance: MeshInstance3D, surface_index: int, mats: Dictionary) -> Material:
	var context: String = _node_context(mesh_instance)
	if _contains_any(context, ["tank", "bustedtank"]):
		return _choose_tank_surface_material(mesh_instance, surface_index, mats, "tank_body")
	if _contains_any(context, ["ground", "dune", "sand", "street", "lane", "alley"]):
		return _mat(mats, "sand")
	if _contains_any(context, ["cliff", "rock", "stone", "rubble", "boulder"]):
		return _mat(mats, "rock")
	if _contains_any(context, ["cactus", "plant", "grass", "bush", "tree", "flower"]):
		if _contains_any(context, ["tree", "bush", "grass"]):
			return _mat(mats, "green_dark")
		return _mat(mats, "cactus")
	if _contains_any(context, ["glass", "window"]):
		return _mat(mats, "building_glass")
	if _contains_any(context, ["oil", "fuel", "barrel", "metal", "rail", "beam", "column", "bucket", "anvil", "lantern"]):
		return _mat(mats, "metal")
	if _contains_any(context, ["wood", "floor", "fence", "pallet", "crate", "porch", "bridge", "stairs", "roof", "plank", "house", "village", "bld_bunker"]):
		return _mat(mats, "wood")
	if _contains_any(context, ["building", "barracks", "storefront", "big_", "mid_", "small_", "runic"]):
		if surface_index == 0:
			return _mat(mats, "building_white")
		if surface_index == 1:
			return _mat(mats, "wood")
		return _mat(mats, "building_grey")
	return null


func _choose_tank_surface_material(mesh_instance: MeshInstance3D, surface_index: int, mats: Dictionary, body_key: String) -> Material:
	var context: String = _node_context(mesh_instance)
	if _contains_any(context, ["track", "tread", "wheel", "gear", "base", "grey", "gray"]):
		return _mat(mats, "tank_grey")
	if _contains_any(context, ["light", "lamp"]):
		return _mat(mats, "tank_lights")
	if _contains_any(context, ["glass", "window"]):
		return _mat(mats, "building_glass")
	if _contains_any(context, ["busted", "wreck"]):
		if surface_index == 0:
			return _mat(mats, "metal")
		return _mat(mats, "tank_grey")
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 1:
		if surface_index == 1:
			return _mat(mats, "tank_grey")
		if surface_index >= 2:
			return _mat(mats, "tank_lights")
	return _mat(mats, body_key)


func _looks_like_tank(node: Node) -> bool:
	return _contains_any(_node_context(node), ["tank", "bustedtank"])


func _node_context(node: Node) -> String:
	var parts: Array[String] = []
	var cursor: Node = node
	var guard: int = 0
	while cursor != null and guard < 8:
		parts.append(String(cursor.name).to_lower())
		var scene_path: String = String(cursor.scene_file_path).to_lower()
		if not scene_path.is_empty():
			parts.append(scene_path.get_file().get_basename().to_lower())
		cursor = cursor.get_parent()
		guard += 1
	return " ".join(parts)


func _contains_any(haystack: String, needles: Array[String]) -> bool:
	for needle: String in needles:
		if haystack.contains(needle):
			return true
	return false


func _mat(mats: Dictionary, key: String) -> Material:
	if mats.has(key) and mats[key] is Material:
		return mats[key] as Material
	return null
