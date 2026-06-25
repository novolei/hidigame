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
	var scene_value: Variant = load("res://assets/characters/party_monster/party_monster_skin.tscn")
	if not scene_value is PackedScene:
		ctx.log("party_scene_load_failed")
		ctx.close_scene()
		return
	var skin_scene: PackedScene = scene_value as PackedScene
	var skin: Node3D = skin_scene.instantiate() as Node3D
	if skin == null:
		ctx.log("party_scene_instantiate_failed")
		ctx.close_scene()
		return
	skin.name = "RuntimePartyMonsterCloseup"
	if skin.has_method("set_character_model_id"):
		skin.call("set_character_model_id", "party_monster_c02")
	if skin.has_method("_build_skin"):
		skin.call("_build_skin")
	skin.position = Vector3(0.0, 0.0, 0.0)
	skin.rotation = Vector3(0.0, PI, 0.0)
	root.add_child(skin)
	var camera: Camera3D = Camera3D.new()
	camera.name = "RuntimePartyMonsterCloseupCamera"
	camera.fov = 30.0
	root.add_child(camera)
	camera.global_position = Vector3(0.0, 1.18, 3.15)
	camera.look_at_from_position(camera.global_position, Vector3(0.0, 0.82, 0.0), Vector3.UP)
	camera.current = true
	await ctx.wait(1.0)
	ctx.log("closeup_ready menu_hidden=%s child_count=%d" % [str(menu_value is CanvasItem and not (menu_value as CanvasItem).visible), skin.get_child_count()])
	await ctx.capture("party_monster_closeup_level_lighting_no_menu")
	ctx.close_scene()
