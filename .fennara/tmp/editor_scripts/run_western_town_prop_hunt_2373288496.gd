@tool
extends RefCounted

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
		var part_bounds: AABB = _xform_aabb(mi.transform, mi.mesh.get_aabb())
		bounds = _merge_aabb(bounds, has_bounds, part_bounds)
		has_bounds = true
	if has_bounds:
		ctx.log("%s size=%s center=%s" % [label, str(bounds.size), str(bounds.get_center())])
	else:
		ctx.log("%s missing" % label)

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	_measure_group(ctx, root, "sheriff_tank", [
		"WesternMaterializedVisuals/TankTurret_Mat920",
		"WesternMaterializedVisuals/TankTracksLeft_Mat921",
		"WesternMaterializedVisuals/TankTracksRight_Mat922",
		"WesternMaterializedVisuals/TankChassis_Mat923"
	])
	_measure_group(ctx, root, "busted_tank", ["WesternMaterializedVisuals/BustedTank_Mat924"])
	_measure_group(ctx, root, "light_tank", [
		"WesternMaterializedVisuals/TankFastChassis_Mat925",
		"WesternMaterializedVisuals/TankFastTracksLeft_Mat926",
		"WesternMaterializedVisuals/TankFastTracksRight_Mat927",
		"WesternMaterializedVisuals/TankTurret_002_Mat928"
	])
