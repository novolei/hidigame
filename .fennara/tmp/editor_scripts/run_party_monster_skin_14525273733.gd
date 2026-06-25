@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root_class=%s root_name=%s" % [root.get_class(), String(root.get_name())])
	if root.has_method("set_character_model_id"):
		root.call("set_character_model_id", "party_monster_c01")
	if root.has_method("idle"):
		root.call("idle")
	var summary: Dictionary = {}
	_collect_mesh_materials(root, summary)
	var keys: Array = summary.keys()
	keys.sort()
	ctx.log("visible_mesh_count=%d" % keys.size())
	var index: int = 0
	for key in keys:
		if index >= 80:
			ctx.log("...truncated")
			break
		ctx.log(str(summary[key]))
		index += 1


func _collect_mesh_materials(node: Node, summary: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh != null:
			var surface_count: int = mesh_instance.mesh.get_surface_count()
			for surface: int in range(surface_count):
				var material: Material = mesh_instance.get_surface_override_material(surface)
				if material == null:
					material = mesh_instance.mesh.surface_get_material(surface)
				var material_name: String = "<none>"
				var material_class: String = "<none>"
				var albedo_path: String = ""
				var metallic_path: String = ""
				var roughness_path: String = ""
				var ao_path: String = ""
				var color_text: String = ""
				if material != null:
					material_name = String(material.resource_name)
					material_class = material.get_class()
					if material is StandardMaterial3D:
						var standard: StandardMaterial3D = material as StandardMaterial3D
						color_text = str(standard.albedo_color)
						if standard.albedo_texture != null:
							albedo_path = standard.albedo_texture.resource_path
						if standard.metallic_texture != null:
							metallic_path = standard.metallic_texture.resource_path
						if standard.roughness_texture != null:
							roughness_path = standard.roughness_texture.resource_path
						if standard.ao_texture != null:
							ao_path = standard.ao_texture.resource_path
				summary[String(mesh_instance.name) + ":" + str(surface)] = "%s surface=%d mat=%s class=%s color=%s albedo=%s metallic=%s roughness=%s ao=%s" % [String(mesh_instance.name), surface, material_name, material_class, color_text, albedo_path, metallic_path, roughness_path, ao_path]
	for child in node.get_children():
		_collect_mesh_materials(child, summary)
