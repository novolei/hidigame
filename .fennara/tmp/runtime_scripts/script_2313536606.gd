extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root=null")
		return

	ctx.log("root=%s class=%s" % [String(root.name), root.get_class()])
	if root.has_method("_on_match_intro_started"):
		root.call("_on_match_intro_started", 3.0)
	else:
		ctx.log("missing _on_match_intro_started")

	await ctx.wait(0.25)

	var hud: Node = root.get_node_or_null("HUDCanvas")
	var overlay: Node = null
	if hud != null:
		var children: Array[Node] = hud.get_children()
		for child: Node in children:
			if String(child.name) == "MatchIntroOverlay":
				overlay = child
				break

	var visible_text: String = "false"
	if overlay != null:
		visible_text = str(bool(overlay.get("visible")))
	ctx.log("state=%s intro_remaining=%.2f overlay_exists=%s overlay_visible=%s" % [str(root.get("game_state")), float(root.get("match_intro_remaining")), str(overlay != null), visible_text])
	await ctx.capture("match_intro_overlay")
