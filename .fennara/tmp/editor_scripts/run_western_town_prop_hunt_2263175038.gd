@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var paths: Array[String] = [
		"WesternMaterializedVisuals/TankTurret_Mat920",
		"WesternMaterializedVisuals/TankTracksLeft_Mat921",
		"WesternMaterializedVisuals/TankTracksRight_Mat922",
		"WesternMaterializedVisuals/TankChassis_Mat923",
		"WesternMaterializedVisuals/BustedTank_Mat924",
		"WesternMaterializedVisuals/TankFastChassis_Mat925"
	]
	for node_path: String in paths:
		var n: Node = root.get_node_or_null(NodePath(node_path))
		if n == null or not (n is MeshInstance3D):
			ctx.log("missing_or_not_mesh=%s" % node_path)
			continue
		var mi: MeshInstance3D = n as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh == null:
			ctx.log("no_mesh=%s" % node_path)
			continue
		var parts: Array[String] = []
		var surface_count: int = mesh.get_surface_count()
		for i: int in range(surface_count):
			var name: String = mesh.surface_get_name(i)
			var override_mat: Material = mi.get_surface_override_material(i)
			var mat_name: String = "none"
			if override_mat != null:
				mat_name = String(override_mat.resource_path)
			parts.append("%d:%s=>%s" % [i, name, mat_name])
		ctx.log("%s surfaces=%s" % [node_path, "; ".join(parts)])
