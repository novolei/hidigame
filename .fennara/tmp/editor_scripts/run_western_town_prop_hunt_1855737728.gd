@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var counts: Dictionary = {"meshes": 0, "override_surfaces": 0, "material_override_meshes": 0, "tank_decor": 0}
	_count(root, counts)
	var tank_decor: Node = root.get_node_or_null("WesternTankDecor")
	if tank_decor != null:
		counts["tank_decor"] = 1
	ctx.log("meshes=%d" % int(counts["meshes"]))
	ctx.log("override_surfaces=%d" % int(counts["override_surfaces"]))
	ctx.log("material_override_meshes=%d" % int(counts["material_override_meshes"]))
	ctx.log("has_tank_decor=%d" % int(counts["tank_decor"]))

func _count(node: Node, counts: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		counts["meshes"] = int(counts["meshes"]) + 1
		var material_override_value: Variant = mi.get("material_override")
		if material_override_value is Material:
			counts["material_override_meshes"] = int(counts["material_override_meshes"]) + 1
		if mi.mesh != null:
			for i: int in range(mi.mesh.get_surface_count()):
				if mi.get_surface_override_material(i) != null:
					counts["override_surfaces"] = int(counts["override_surfaces"]) + 1
	for child: Node in node.get_children():
		_count(child, counts)
