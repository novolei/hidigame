@tool
extends RefCounted

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

func _measure_group(ctx: Variant, root: Node, label: String, paths: Array[String]) -> void:
	var has_bounds: bool = false
	var bounds: AABB = AABB()
	for path: String in paths:
		var n: Node = root.get_node_or_null(NodePath(path))
		if n == null or not (n is MeshInstance3D):
			continue
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var part: AABB = _xform_aabb(mi.transform, mi.mesh.get_aabb())
		if has_bounds:
			bounds = bounds.merge(part)
		else:
			bounds = part
			has_bounds = true
	if has_bounds:
		ctx.log("%s size=%s" % [label, str(bounds.size)])

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var blue: Material = _load_mat("res://Materials/M_tank_demo_tank_blue.tres")
	var grey: Material = _load_mat("res://Materials/M_tank_demo_tank_grey.tres")
	var lights: Material = _load_mat("res://Materials/M_tank_demo_tank_lights.tres")
	var oil: Material = _load_mat("res://Materials/M_tank_demo_oil.tres")
	var brown: Material = _load_mat("res://Materials/M_tank_demo_brown.tres")
	var light_chassis: Node = root.get_node_or_null(NodePath("WesternMaterializedVisuals/TankFastChassis_Mat925"))
	if light_chassis is MeshInstance3D:
		var mi: MeshInstance3D = light_chassis as MeshInstance3D
		if mi.mesh != null and mi.mesh.get_surface_count() >= 4:
			mi.set_surface_override_material(0, blue)
			mi.set_surface_override_material(1, lights)
			mi.set_surface_override_material(2, lights)
			mi.set_surface_override_material(3, grey)
			ctx.log("fixed_light_tank_chassis_materials")
	var busted: Node = root.get_node_or_null(NodePath("WesternMaterializedVisuals/BustedTank_Mat924"))
	if busted is MeshInstance3D:
		var busted_mi: MeshInstance3D = busted as MeshInstance3D
		if busted_mi.mesh != null:
			for i: int in range(busted_mi.mesh.get_surface_count()):
				var damaged_mat: Material = oil
				if i % 2 != 0:
					damaged_mat = brown
				busted_mi.set_surface_override_material(i, damaged_mat)
			ctx.log("fixed_original_busted_tank_materials")
	_measure_group(ctx, root, "sheriff_tank", ["WesternMaterializedVisuals/TankTurret_Mat920", "WesternMaterializedVisuals/TankTracksLeft_Mat921", "WesternMaterializedVisuals/TankTracksRight_Mat922", "WesternMaterializedVisuals/TankChassis_Mat923"])
	_measure_group(ctx, root, "light_tank", ["WesternMaterializedVisuals/TankFastChassis_Mat925", "WesternMaterializedVisuals/TankFastTracksLeft_Mat926", "WesternMaterializedVisuals/TankFastTracksRight_Mat927", "WesternMaterializedVisuals/TankTurret_002_Mat928"])
	ctx.mark_modified()
