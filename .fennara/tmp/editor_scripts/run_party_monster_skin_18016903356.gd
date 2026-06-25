@tool
extends RefCounted

const MODEL_SCENE_PATH := "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Mesh/DefaultCharacterMesh.fbx"

func run(ctx) -> void:
	var scene: Variant = load(MODEL_SCENE_PATH)
	if not scene is PackedScene:
		ctx.error("model scene failed to load")
		return
	var root: Node = (scene as PackedScene).instantiate()
	if root == null:
		ctx.error("model scene failed to instantiate")
		return
	var names: Array[String] = ["MainBody01", "Glove01", "Hat16", "Eye01", "Mouth01"]
	for mesh_name: String in names:
		var mesh_instance: MeshInstance3D = _find_mesh(root, mesh_name)
		if mesh_instance == null:
			ctx.log("mesh_missing=%s" % mesh_name)
			continue
		var material: Material = null
		if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			material = mesh_instance.mesh.surface_get_material(0)
		if material == null:
			ctx.log("mesh=%s material=null" % mesh_name)
		elif material is BaseMaterial3D:
			var base_material: BaseMaterial3D = material as BaseMaterial3D
			ctx.log("mesh=%s material=%s class=%s cull_mode=%d transparency=%d albedo=%s" % [mesh_name, material.resource_name, material.get_class(), base_material.cull_mode, base_material.transparency, str(base_material.albedo_texture)])
		else:
			ctx.log("mesh=%s material=%s class=%s" % [mesh_name, material.resource_name, material.get_class()])
	root.free()

func _find_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and String(node.name) == mesh_name:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh(child, mesh_name)
		if found != null:
			return found
	return null
