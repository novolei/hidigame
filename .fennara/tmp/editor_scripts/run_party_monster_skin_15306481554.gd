@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root_class=%s root_name=%s" % [root.get_class(), String(root.get_name())])
	_check_model(ctx, root, "party_monster_c01", {
		"MainBody01": "DefaultPBR01_Albedo.png",
		"Eye01": "DefaultPBR01_Albedo.png",
		"Mouth01": "DefaultPBR01_Albedo.png",
		"Glove01": "DefaultPBR02_Albedo.png",
		"Hat16": "DefaultPBR02_Albedo.png",
	})
	_check_model(ctx, root, "party_monster_masktint01", {
		"MainBody01": "MaskTintPBR/Albedo01.png",
		"Glove01": "MaskTintPBR/Albedo02.png",
	})

func _check_model(ctx: Variant, root: Node, model_id: String, expected: Dictionary) -> void:
	if not root.has_method("set_character_model_id") or not root.has_method("_build_skin"):
		ctx.error("Root does not expose PartyMonsterSkin build methods")
		return
	root.call("set_character_model_id", model_id)
	root.call("_build_skin")
	ctx.log("checking_model=%s" % model_id)
	for raw_mesh_name in expected.keys():
		var mesh_name: String = str(raw_mesh_name)
		var material: Material = _find_mesh_material(root, mesh_name)
		if material == null:
			ctx.error("missing material for mesh %s" % mesh_name)
			return
		if not material is ShaderMaterial:
			ctx.error("mesh %s material is %s, expected ShaderMaterial" % [mesh_name, material.get_class()])
			return
		var shader_material: ShaderMaterial = material as ShaderMaterial
		var texture_value: Variant = shader_material.get_shader_parameter("albedo_texture")
		if not texture_value is Texture2D:
			ctx.error("mesh %s has no albedo_texture Texture2D parameter" % mesh_name)
			return
		var texture: Texture2D = texture_value as Texture2D
		var texture_path: String = texture.resource_path
		var expected_fragment: String = str(expected[mesh_name])
		ctx.log("mesh=%s material=%s albedo=%s" % [mesh_name, material.resource_name, texture_path])
		if not texture_path.contains(expected_fragment):
			ctx.error("mesh %s expected %s but got %s" % [mesh_name, expected_fragment, texture_path])
			return

func _find_mesh_material(node: Node, mesh_name: String) -> Material:
	if node is MeshInstance3D and String(node.name) == mesh_name:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var override_material: Material = mesh_instance.get_surface_override_material(0)
		if override_material != null:
			return override_material
		if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			return mesh_instance.mesh.surface_get_material(0)
		return null
	for child in node.get_children():
		var found: Material = _find_mesh_material(child, mesh_name)
		if found != null:
			return found
	return null
