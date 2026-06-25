@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root=%s class=%s" % [String(root.name), root.get_class()])
	if root.has_method("set_character_model_id"):
		root.call("set_character_model_id", "party_monster_c01")
	if root.has_method("apply_pose_now"):
		root.call("apply_pose_now", 0.15)
	var checked: int = 0
	_inspect_meshes(ctx, root, checked)

func _inspect_meshes(ctx, node: Node, checked: int) -> void:
	if checked >= 8:
		return
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			var material: Material = mesh_instance.get_active_material(0)
			if material is ShaderMaterial:
				var shader_material: ShaderMaterial = material as ShaderMaterial
				var tex_value: Variant = shader_material.get_shader_parameter("albedo_texture")
				var tex_path: String = "<null>"
				if tex_value is Texture2D:
					tex_path = String((tex_value as Texture2D).resource_path)
				ctx.log("mesh=%s mat=%s tex=%s shader=%s" % [String(mesh_instance.name), String(shader_material.resource_name), tex_path, String(shader_material.shader.resource_path if shader_material.shader != null else "<null>")])
				checked += 1
	for child in node.get_children():
		_inspect_meshes(ctx, child, checked)
