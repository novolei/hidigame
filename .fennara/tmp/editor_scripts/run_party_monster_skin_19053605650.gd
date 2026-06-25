@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root_class=%s root_name=%s" % [root.get_class(), String(root.name)])
	if root.has_method("set_character_model_id"):
		root.call("set_character_model_id", "party_monster_c01")
	if root.has_method("_build_skin"):
		root.call("_build_skin")
	_log_mesh_material(ctx, root, "default", "MainBody01")
	_log_mesh_material(ctx, root, "default", "Glove01")
	if root.has_method("set_character_model_id"):
		root.call("set_character_model_id", "party_monster_masktint01")
	_log_mesh_material(ctx, root, "mask", "MainBody01")
	_log_mesh_material(ctx, root, "mask", "Glove01")

func _log_mesh_material(ctx, root: Node, label: String, mesh_name: String) -> void:
	var mesh_node: MeshInstance3D = _find_mesh(root, mesh_name)
	if mesh_node == null:
		ctx.log("%s.%s=missing_mesh" % [label, mesh_name])
		return
	var material: Material = mesh_node.get_surface_override_material(0)
	if material == null and mesh_node.mesh != null and mesh_node.mesh.get_surface_count() > 0:
		material = mesh_node.mesh.surface_get_material(0)
	if material == null:
		ctx.log("%s.%s=missing_material" % [label, mesh_name])
		return
	ctx.log("%s.%s.material=%s:%s" % [label, mesh_name, material.get_class(), material.resource_name])
	if not material is ShaderMaterial:
		return
	var shader_material: ShaderMaterial = material as ShaderMaterial
	var texture_value: Variant = shader_material.get_shader_parameter("albedo_texture")
	if texture_value is Texture2D:
		var texture: Texture2D = texture_value as Texture2D
		ctx.log("%s.%s.albedo=%s" % [label, mesh_name, texture.resource_path])
	for parameter_name in ["metallic_strength", "ao_strength", "roughness_floor", "albedo_boost", "ambient_fill"]:
		var value: Variant = shader_material.get_shader_parameter(parameter_name)
		ctx.log("%s.%s.%s=%s" % [label, mesh_name, parameter_name, str(value)])

func _find_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and String(node.name) == mesh_name:
		return node as MeshInstance3D
	var children: Array[Node] = node.get_children()
	for child: Node in children:
		var found: MeshInstance3D = _find_mesh(child, mesh_name)
		if found != null:
			return found
	return null
