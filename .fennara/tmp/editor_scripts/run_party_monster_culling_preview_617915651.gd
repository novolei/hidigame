@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "PartyMonsterCullingPreview"
		ctx.set_scene_root(new_root)
		root = new_root
		ctx.log("Created preview root")
	else:
		ctx.clear_children(root)
		ctx.log("Cleared existing preview root")

	var node_root: Node3D = root as Node3D
	if node_root == null:
		ctx.error("Preview root was not Node3D")
		return

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "KeyLight"
	light.light_energy = 3.0
	light.shadow_enabled = false
	light.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(32.0), 0.0)
	node_root.add_child(light)
	ctx.own(light)

	var camera: Camera3D = Camera3D.new()
	camera.name = "PreviewCamera"
	camera.fov = 42.0
	camera.position = Vector3(0.0, 1.3, 5.2)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.85, 0.0), Vector3.UP)
	node_root.add_child(camera)
	ctx.own(camera)

	var default_skin: Node3D = ctx.instance_scene(node_root, "res://assets/characters/party_monster/party_monster_skin.tscn", "DefaultC01") as Node3D
	if default_skin != null:
		default_skin.position = Vector3(-0.85, 0.0, 0.0)
		default_skin.rotation = Vector3(0.0, deg_to_rad(155.0), 0.0)
		if default_skin.has_method("set_character_model_id"):
			default_skin.call("set_character_model_id", "party_monster_c01")
		ctx.log("Instanced default Party Monster")

	var mask_skin: Node3D = ctx.instance_scene(node_root, "res://assets/characters/party_monster/party_monster_skin.tscn", "MaskTint01") as Node3D
	if mask_skin != null:
		mask_skin.position = Vector3(0.85, 0.0, 0.0)
		mask_skin.rotation = Vector3(0.0, deg_to_rad(155.0), 0.0)
		if mask_skin.has_method("set_character_model_id"):
			mask_skin.call("set_character_model_id", "party_monster_masktint01")
		ctx.log("Instanced mask tint Party Monster")

	ctx.mark_modified()
