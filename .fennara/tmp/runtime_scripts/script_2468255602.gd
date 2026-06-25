extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root=null")
		return

	if root.has_method("_on_match_intro_started"):
		root.call("_on_match_intro_started", 3.0)
	await ctx.wait(0.25)

	var hud: Node = root.get_node_or_null("HUDCanvas")
	var overlay: Control = null
	var title_label: Label = null
	var count_label: Label = null
	if hud != null:
		var children: Array[Node] = hud.get_children()
		for child: Node in children:
			if String(child.name) == "MatchIntroOverlay" and child is Control:
				overlay = child as Control
				break
	if overlay != null:
		title_label = overlay.find_child("Title", true, false) as Label
		count_label = overlay.find_child("CountdownNumber", true, false) as Label
		ctx.log("overlay_size=%s visible=%s title_size=%s count=%s count_size=%s" % [str(overlay.size), str(overlay.visible), str(title_label.size if title_label != null else Vector2.ZERO), str(count_label.text if count_label != null else ""), str(count_label.size if count_label != null else Vector2.ZERO)])
	ctx.log("state=%s intro_remaining=%.2f" % [str(root.get("game_state")), float(root.get("match_intro_remaining"))])
	await ctx.capture("match_intro_overlay_fixed")
