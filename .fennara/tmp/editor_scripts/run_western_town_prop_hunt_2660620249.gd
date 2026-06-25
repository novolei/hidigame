@tool
extends RefCounted

const VISUAL_ROOT_PATH: String = "WesternMaterializedVisuals"
const DECOR_ROOT_PATH: String = "WesternTankDecor"

func _load_mat(path: String) -> Material:
	var res: Resource = ResourceLoader.load(path)
	if res is Material:
		return res as Material
	return null

func _xform_aabb(xf: Transform3D, aabb: AABB) -> AABB:
	var corners: Array[Vector3] = [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
		aabb.position + Vector3(0.0, aabb.size.y, 0.0),
		aabb.position + Vector3(0.0, 0.0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
		aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
		aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size
	]
	var out: AABB = AABB(xf * corners[0], Vector3.ZERO)
	for i: int in range(1, corners.size()):
		out = out.expand(xf * corners[i])
	return out

func _merge_aabb(current: AABB, has_current: bool, next: AABB) -> AABB:
	if not has_current:
		return next
	var merged: AABB = current
	merged = merged.merge(next)
	return merged

func _collect_meshes(node: Node, parent_xf: Transform3D, out: Array[Dictionary]) -> void:
	var local_xf: Transform3D = parent_xf
	if node is Node3D:
		local_xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null:
			out.append({"name": String(mi.name), "mesh": mi.mesh, "transform": local_xf})
	for child: Node in node.get_children():
		_collect_meshes(child, local_xf, out)

func _measure_entries(entries: Array[Dictionary]) -> AABB:
	var has_bounds: bool = false
	var bounds: AABB = AABB()
	for entry: Dictionary in entries:
		var mesh: Mesh = entry["mesh"] as Mesh
		var xf: Transform3D = entry["transform"] as Transform3D
		if mesh == null:
			continue
		var part_bounds: AABB = _xform_aabb(xf, mesh.get_aabb())
		bounds = _merge_aabb(bounds, has_bounds, part_bounds)
		has_bounds = true
	return bounds

func _measure_nodes(root: Node, paths: Array[String]) -> AABB:
	var has_bounds: bool = false
	var bounds: AABB = AABB()
	for path: String in paths:
		var n: Node = root.get_node_or_null(NodePath(path))
		if n == null or not (n is MeshInstance3D):
			continue
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var part_bounds: AABB = _xform_aabb(mi.transform, mi.mesh.get_aabb())
		bounds = _merge_aabb(bounds, has_bounds, part_bounds)
		has_bounds = true
	return bounds

func _scale_mesh_group_to_length(root: Node, paths: Array[String], target_longest: float) -> float:
	var bounds: AABB = _measure_nodes(root, paths)
	var longest: float = max(bounds.size.x, bounds.size.z)
	if longest <= 0.01:
		return 1.0
	var factor: float = target_longest / longest
	for path: String in paths:
		var n: Node = root.get_node_or_null(NodePath(path))
		if n == null or not (n is MeshInstance3D):
			continue
		var mi: MeshInstance3D = n as MeshInstance3D
		var xf: Transform3D = mi.transform
		var b: Basis = xf.basis
		b.x = b.x * factor
		b.y = b.y * factor
		b.z = b.z * factor
		xf.basis = b
		mi.transform = xf
	return factor

func _set_existing_tank_materials(root: Node, mats: Dictionary) -> int:
	var changed: int = 0
	var busted_paths: Array[String] = [
		"WesternMaterializedVisuals/BustedTank_Mat924"
	]
	for path: String in busted_paths:
		var n: Node = root.get_node_or_null(NodePath(path))
		if n == null or not (n is MeshInstance3D):
			continue
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i: int in range(mi.mesh.get_surface_count()):
			mi.set_surface_override_material(i, mats["damage"] as Material)
			changed += 1
	return changed

func _choose_tank_material(surface_name: String, variant: String, mats: Dictionary) -> Material:
	var s: String = surface_name.to_lower()
	if variant == "damaged":
		if s.contains("light") or s.contains("window"):
			return mats["damage"] as Material
		if s.contains("track") or s.contains("grey") or s.contains("wheel"):
			return mats["oil"] as Material
		return mats["damage"] as Material
	if s.contains("track") or s.contains("grey") or s.contains("wheel"):
		return mats["grey"] as Material
	if s.contains("light") or s.contains("window"):
		return mats["lights"] as Material
	if variant == "heavy":
		return mats["green"] as Material
	if variant == "utv":
		return mats["blue"] as Material
	if variant == "shark":
		return mats["grey"] as Material
	return mats["red"] as Material

func _basis_from_yaw_and_scale(yaw: float, scale_value: float) -> Basis:
	var b: Basis = Basis(Vector3.UP, yaw)
	b.x = b.x * scale_value
	b.y = b.y * scale_value
	b.z = b.z * scale_value
	return b

func _remove_child_if_exists(ctx: Variant, root_path: String, child_name: String) -> void:
	var node_path: String = "%s/%s" % [root_path, child_name]
	if ctx.get_node_or_null(node_path) != null:
		ctx.remove_node(node_path)

func _add_collision(ctx: Variant, decor_root: Node, name: String, position: Vector3, yaw: float, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name + "Collision"
	body.transform = Transform3D(_basis_from_yaw_and_scale(yaw, 1.0), Vector3(position.x, size.y * 0.5, position.z))
	decor_root.add_child(body)
	ctx.own(body)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = name + "CollisionShape"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	ctx.own(shape)

func _add_tank_variant(ctx: Variant, visual_root: Node, decor_root: Node, source_path: String, source_name: String, visual_prefix: String, variant: String, position: Vector3, yaw: float, target_longest: float, collision_size: Vector3, mats: Dictionary) -> int:
	_remove_child_if_exists(ctx, DECOR_ROOT_PATH, source_name)
	_remove_child_if_exists(ctx, DECOR_ROOT_PATH, source_name + "Collision")
	for child: Node in visual_root.get_children():
		var child_name: String = String(child.name)
		if child_name.begins_with(visual_prefix):
			ctx.remove_node("%s/%s" % [VISUAL_ROOT_PATH, child_name])
	var source_instance: Node = ctx.instance_scene(decor_root, source_path, source_name)
	if source_instance is Node3D:
		(source_instance as Node3D).transform = Transform3D(_basis_from_yaw_and_scale(yaw, 1.0), position)
	var packed: PackedScene = ResourceLoader.load(source_path) as PackedScene
	if packed == null:
		ctx.log("missing packed source %s" % source_path)
		return 0
	var temp_root: Node = packed.instantiate()
	var entries: Array[Dictionary] = []
	_collect_meshes(temp_root, Transform3D.IDENTITY, entries)
	var local_bounds: AABB = _measure_entries(entries)
	var source_longest: float = max(local_bounds.size.x, local_bounds.size.z)
	var scale_value: float = 1.0
	if source_longest > 0.01:
		scale_value = target_longest / source_longest
	var root_xf: Transform3D = Transform3D(_basis_from_yaw_and_scale(yaw, scale_value), position)
	var created: int = 0
	for entry: Dictionary in entries:
		var mesh: Mesh = entry["mesh"] as Mesh
		var local_xf: Transform3D = entry["transform"] as Transform3D
		if mesh == null:
			continue
		var clone: MeshInstance3D = MeshInstance3D.new()
		clone.name = "%s_%s_%03d" % [visual_prefix, String(entry["name"]), created]
		clone.mesh = mesh
		clone.transform = root_xf * local_xf
		var surface_count: int = mesh.get_surface_count()
		for i: int in range(surface_count):
			var surface_name: String = mesh.surface_get_name(i)
			var mat: Material = _choose_tank_material(surface_name, variant, mats)
			if mat != null:
				clone.set_surface_override_material(i, mat)
		visual_root.add_child(clone)
		ctx.own(clone)
		created += 1
	temp_root.free()
	_add_collision(ctx, decor_root, source_name, position, yaw, collision_size)
	return created

func _resize_existing_collision(root: Node, collision_path: String, size: Vector3, y: float) -> void:
	var body: Node = root.get_node_or_null(NodePath(collision_path))
	if body is Node3D:
		var n3: Node3D = body as Node3D
		var xf: Transform3D = n3.transform
		xf.origin.y = y
		n3.transform = xf
	var shape_node: Node = root.get_node_or_null(NodePath(collision_path + "/" + collision_path.get_file() + "Shape"))
	if shape_node == null:
		for child: Node in body.get_children() if body != null else []:
			if child is CollisionShape3D:
				shape_node = child
				break
	if shape_node is CollisionShape3D:
		var cs: CollisionShape3D = shape_node as CollisionShape3D
		var box: BoxShape3D = cs.shape as BoxShape3D
		if box == null:
			box = BoxShape3D.new()
			cs.shape = box
		box.size = size

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var visual_root: Node = root.get_node_or_null(NodePath(VISUAL_ROOT_PATH))
	var decor_root: Node = root.get_node_or_null(NodePath(DECOR_ROOT_PATH))
	if visual_root == null or decor_root == null:
		ctx.error("Western tank roots missing")
		return
	var mats: Dictionary = {
		"red": _load_mat("res://Materials/M_tank_demo_tank_color.tres"),
		"blue": _load_mat("res://Materials/M_tank_demo_tank_blue.tres"),
		"grey": _load_mat("res://Materials/M_tank_demo_tank_grey.tres"),
		"lights": _load_mat("res://Materials/M_tank_demo_tank_lights.tres"),
		"green": _load_mat("res://Materials/M_tank_demo_green_dark.tres"),
		"damage": _load_mat("res://Materials/M_tank_demo_brown.tres"),
		"oil": _load_mat("res://Materials/M_tank_demo_oil.tres")
	}
	var sheriff_paths: Array[String] = [
		"WesternMaterializedVisuals/TankTurret_Mat920",
		"WesternMaterializedVisuals/TankTracksLeft_Mat921",
		"WesternMaterializedVisuals/TankTracksRight_Mat922",
		"WesternMaterializedVisuals/TankChassis_Mat923"
	]
	var light_paths: Array[String] = [
		"WesternMaterializedVisuals/TankFastChassis_Mat925",
		"WesternMaterializedVisuals/TankFastTracksLeft_Mat926",
		"WesternMaterializedVisuals/TankFastTracksRight_Mat927",
		"WesternMaterializedVisuals/TankTurret_002_Mat928"
	]
	var sheriff_factor: float = _scale_mesh_group_to_length(root, sheriff_paths, 5.8)
	var light_factor: float = _scale_mesh_group_to_length(root, light_paths, 5.8)
	var damaged_surfaces: int = _set_existing_tank_materials(root, mats)
	_resize_existing_collision(root, "WesternTankDecor/DecorTankSheriffGateCollision", Vector3(5.8, 2.6, 6.2), 1.3)
	_resize_existing_collision(root, "WesternTankDecor/DecorTankCanyonWreckCollision", Vector3(7.8, 2.4, 7.6), 1.2)
	_resize_existing_collision(root, "WesternTankDecor/DecorTankWaterTowerLaneCollision", Vector3(5.5, 2.4, 5.8), 1.2)
	var created: int = 0
	created += _add_tank_variant(ctx, visual_root, decor_root, "res://assets/unity_migrated/tanks_complete/Art/Models/Tanks/Tank_Heavy_Model.glb", "DecorTankHeavyBank", "DecorHeavyTank", "heavy", Vector3(-18.0, 0.35, 7.0), 0.95, 7.2, Vector3(6.6, 2.8, 7.2), mats)
	created += _add_tank_variant(ctx, visual_root, decor_root, "res://assets/unity_migrated/tanks_complete/Art/Models/Tanks/Tank_UTV_Model.glb", "DecorTankUTVCorral", "DecorUTVTank", "utv", Vector3(15.5, 0.35, -10.2), -0.75, 5.7, Vector3(5.2, 2.3, 5.8), mats)
	created += _add_tank_variant(ctx, visual_root, decor_root, "res://assets/unity_migrated/tanks_complete/Art/Models/Tanks/Tank_Shark_Model.glb", "DecorTankSharkCanyon", "DecorSharkTank", "shark", Vector3(-5.5, 0.35, 13.2), 2.75, 6.4, Vector3(5.8, 2.5, 6.5), mats)
	created += _add_tank_variant(ctx, visual_root, decor_root, "res://assets/unity_migrated/tanks_complete/Art/Models/Environment/BustedTank.glb", "DecorBustedTankBackLot", "DecorBustedTank", "damaged", Vector3(18.0, 0.3, 3.0), -0.2, 7.2, Vector3(7.4, 2.3, 7.2), mats)
	ctx.log("scaled_sheriff_factor=%.3f" % sheriff_factor)
	ctx.log("scaled_light_factor=%.3f" % light_factor)
	ctx.log("damaged_surfaces=%d" % damaged_surfaces)
	ctx.log("new_tank_visual_meshes=%d" % created)
	ctx.mark_modified()
