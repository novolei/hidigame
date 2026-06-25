extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root=null")
		ctx.close_scene()
		return
	var menu_value: Variant = root.get("main_menu")
	if menu_value is CanvasItem:
		var menu_canvas: CanvasItem = menu_value as CanvasItem
		menu_canvas.visible = false
		if menu_canvas.has_method("hide_menu"):
			menu_canvas.call("hide_menu")
	var model_id: String = "party_monster_c02"
	var scene_value: Variant = load("res://assets/characters/party_monster/party_monster_skin.tscn")
	if not scene_value is PackedScene:
		ctx.log("party_scene_load_failed")
		ctx.close_scene()
		return
	var model: Dictionary = CharacterSkinCatalog.get_model(model_id)
	var model_scale: Vector3 = model.get("scale", Vector3.ONE)
	var model_offset: Vector3 = model.get("offset", Vector3.ZERO)
	var base_position: Vector3 = Vector3(0.0, 8.0, 0.0)
	var skin_scene: PackedScene = scene_value as PackedScene
	var skin: Node3D = skin_scene.instantiate() as Node3D
	if skin == null:
		ctx.log("party_scene_instantiate_failed")
		ctx.close_scene()
		return
	skin.name = "RuntimePartyMonsterCloseup"
	if skin.has_method("set_character_model_id"):
		skin.call("set_character_model_id", model_id)
	if skin.has_method("_build_skin"):
		skin.call("_build_skin")
	skin.scale = model_scale
	skin.position = base_position + model_offset
	skin.rotation = Vector3(0.0, PI, 0.0)
	root.add_child(skin)
	var camera: Camera3D = Camera3D.new()
	camera.name = "RuntimePartyMonsterCloseupCamera"
	camera.fov = 30.0
	root.add_child(camera)
	var target: Vector3 = base_position + Vector3(0.0, 0.72, 0.0)
	camera.global_position = base_position + Vector3(0.0, 1.05, 2.45)
	camera.look_at_from_position(camera.global_position, target, Vector3.UP)
	camera.current = true
	await ctx.wait(1.0)
	ctx.log("closeup_ready menu_hidden=%s scale=%s offset=%s child_count=%d" % [str(menu_value is CanvasItem and not (menu_value as CanvasItem).visible), str(model_scale), str(model_offset), skin.get_child_count()])
	await ctx.capture("party_monster_closeup_scaled_level_lighting")
	ctx.close_scene()
