extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root=null")
		ctx.close_scene()
		return
	ctx.log("root=%s class=%s" % [String(root.name), root.get_class()])
	if Network.multiplayer.multiplayer_peer == null:
		var host_error: int = Network.start_host("VisualHost", "blue", Network.Role.CHAMELEON, "VISUAL", "", CharacterSkinCatalog.party_monster_default_id())
		ctx.log("start_host_error=%d" % host_error)
	Network.lobby_config["lobby_id"] = "VISUAL"
	Network.lobby_config["room_name"] = "Visual Check"
	Network.lobby_config["prep_duration_sec"] = 30
	Network.players = {
		1: {
			"id": 1,
			"nickname": "VisualHost",
			"skin": "blue",
			"role": Network.Role.CHAMELEON,
			"ready": true,
			"alive": true,
			"character_model": CharacterSkinCatalog.party_monster_default_id(),
		},
		2: {
			"id": 2,
			"nickname": "Hunter",
			"skin": "red",
			"role": Network.Role.HUNTER,
			"ready": true,
			"alive": true,
			"character_model": CharacterSkinCatalog.HUNTER_SHOOTER_ID,
		},
	}
	if root.has_method("_server_start_skin_config_phase"):
		root.call("_server_start_skin_config_phase")
	await ctx.wait(1.0)
	var overlay: Node = root.get_node_or_null("HUDCanvas/CharacterSetupOverlay")
	ctx.log("state=%s overlay_visible=%s players=%d" % [str(root.get("game_state")), str(overlay != null and (overlay as CanvasItem).visible), Network.players.size()])
	await ctx.capture("skin_config_overlay")
	await ctx.wait(0.2)
	ctx.close_scene()
