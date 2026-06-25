@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	if not root is Node3D:
		ctx.error("Scene root is not Node3D")
		return
	var root3d: Node3D = root as Node3D
	var mats: Dictionary = _load_materials(ctx)
	if mats.is_empty():
		ctx.error("No material resources loaded")
		return
	if root.get_node_or_null("WesternMaterializedVisuals") != null:
		var removed: bool = ctx.remove_node("WesternMaterializedVisuals")
		ctx.log("removed_existing_WesternMaterializedVisuals=%s" % str(removed))

	var materialized_root: Node3D = Node3D.new()
	materialized_root.name = "WesternMaterializedVisuals"
	root.add_child(materialized_root)
	ctx.own(materialized_root)

	var targets: Array[Node] = []
	_append_if_exists(root, targets, "ExistingAssetWesternTown")
	_append_if_exists(root, targets, "WesternDenseCoverPass")
	_append_if_exists(root, targets, "WesternTankDecor")

	var result: Dictionary = {"source_meshes": 0, "cloned_meshes": 0, "cloned_surfaces": 0, "missing_material": 0}
	var clone_index: int = 0
	for target: Node in targets:
		clone_index = _clone_visual_meshes(ctx, target, root3d, materialized_root, mats, clone_index, result)
		if target is Node3D:
			var target3d: Node3D = target as Node3D
			target3d.visible = false

	ctx.log("materialized_source_meshes=%d" % int(result["source_meshes"]))
	ctx.log("materialized_cloned_meshes=%d" % int(result["cloned_meshes"]))
	ctx.log("materialized_cloned_surfaces=%d" % int(result["cloned_surfaces"]))
	ctx.log("materialized_missing_material=%d" % int(result["missing_material"]))
	ctx.mark_modified()


func _append_if_exists(root: Node, targets: Array[Node], node_name: String) -> void:
	var node: Node = root.get_node_or_null(node_name)
	if node != null:
		targets.append(node)


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
			ctx.log("missing_material_resource=%s path=%s" % [key, path])
	return mats


func _clone_visual_meshes(ctx, node: Node, root3d: Node3D, materialized_root: Node3D, mats: Dictionary, clone_index: int, result: Dictionary) -> int:
	if node is MeshInstance3D:
		var source: MeshInstance3D = node as MeshInstance3D
		if source.mesh != null and source.visible:
			result["source_meshes"] = int(result["source_meshes"]) + 1
			var clone: MeshInstance3D = MeshInstance3D.new()
			clone.name = _clone_name(source, clone_index)
			clone.mesh = source.mesh
			clone.transform = _transform_relative_to_root(source, root3d)
			clone.visible = true
			clone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			materialized_root.add_child(clone)
			ctx.own(clone)
			var surface_count: int = source.mesh.get_surface_count()
			for surface_index: int in range(surface_count):
				var material: Material = _choose_material(source, surface_index, mats)
				if material == null:
					material = _fallback_material_for_source(source, mats)
				if material != null:
					clone.set_surface_override_material(surface_index, material)
					result["cloned_surfaces"] = int(result["cloned_surfaces"]) + 1
				else:
					result["missing_material"] = int(result["missing_material"]) + 1
			result["cloned_meshes"] = int(result["cloned_meshes"]) + 1
			clone_index += 1
	for child: Node in node.get_children():
		clone_index = _clone_visual_meshes(ctx, child, root3d, materialized_root, mats, clone_index, result)
	return clone_index


func _transform_relative_to_root(node: Node3D, root3d: Node3D) -> Transform3D:
	var chain: Array[Node3D] = []
	var cursor: Node = node
	while cursor != null and cursor != root3d:
		if cursor is Node3D:
			chain.push_front(cursor as Node3D)
		cursor = cursor.get_parent()
	var transform_accumulator: Transform3D = Transform3D.IDENTITY
	for item: Node3D in chain:
		transform_accumulator = transform_accumulator * item.transform
	return transform_accumulator


func _clone_name(source: MeshInstance3D, clone_index: int) -> String:
	var base_name: String = String(source.name)
	base_name = base_name.replace("@", "")
	if base_name.is_empty():
		base_name = "MaterializedMesh"
	return "%s_Mat%03d" % [base_name, clone_index]


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


func _fallback_material_for_source(mesh_instance: MeshInstance3D, mats: Dictionary) -> Material:
	var context: String = _node_context(mesh_instance)
	if _contains_any(context, ["existingassetwesterntown", "western dense", "western"]):
		return _mat(mats, "wood")
	return _mat(mats, "sand")


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
