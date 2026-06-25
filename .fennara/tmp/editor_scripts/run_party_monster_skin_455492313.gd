@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root=%s class=%s" % [String(root.name), root.get_class()])
	_log_shader_source(ctx, "default", "res://assets/characters/party_monster/party_monster_default_pbr.gdshader")
	_log_shader_source(ctx, "mask", "res://assets/characters/party_monster/party_monster_mask_tint.gdshader")
	if root.has_method("set_character_model_id"):
		root.call("set_character_model_id", "party_monster_c01")
	if root.has_method("_build_skin"):
		root.call("_build_skin")
	_log_material(ctx, root, "default", "MainBody01")
	_log_material(ctx, root, "default", "Glove01")
	if root.has_method("set_character_model_id"):
		root.call("set_character_model_id", "party_monster_masktint01")
	_log_material(ctx, root, "mask", "MainBody01")
	_log_material(ctx, root, "mask", "Glove01")

func _log_shader_source(ctx, label: String, shader_path: String) -> void:
	var source: String = FileAccess.get_file_as_string(shader_path)
	ctx.log("%s.source_has_cull_disabled=%s" % [label, str(source.contains("cull_disabled"))])
	ctx.log("%s.source_has_cull_back=%s" % [label, str(source.contains("cull_back"))])

func _log_material(ctx, root: Node, label: String, mesh_name: String) -> void:
	var mesh_node: MeshInstance3D = _find_mesh(root, mesh_name)
	if mesh_node == null:
		ctx.log("%s.%s=missing_mesh" % [label, mesh_name])
		return
	var material: Material = mesh_node.get_surface_override_material(0)
	if material == null:
		ctx.log("%s.%s=missing_override" % [label, mesh_name])
		return
	ctx.log("%s.%s.material=%s:%s" % [label, mesh_name, material.get_class(), material.resource_name])
	if material is ShaderMaterial:
		var shader_material: ShaderMaterial = material as ShaderMaterial
		var shader: Shader = shader_material.shader
		ctx.log("%s.%s.shader_path=%s" % [label, mesh_name, shader.resource_path if shader != null else ""])

func _find_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and String(node.name) == mesh_name:
		return node as MeshInstance3D
	var children: Array[Node] = node.get_children()
	for child: Node in children:
		var found: MeshInstance3D = _find_mesh(child, mesh_name)
		if found != null:
			return found
	return null
