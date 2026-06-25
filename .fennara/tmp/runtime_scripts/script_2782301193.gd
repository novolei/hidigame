extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root=null")
		return
	if root.has_method("_on_match_intro_started"):
		root.call("_on_match_intro_started", 3.0)
	await ctx.wait(0.08)
	var hud: Node = root.get_node_or_null("HUDCanvas")
	var overlay: Control = null
	if hud != null:
		var children: Array[Node] = hud.get_children()
		for child: Node in children:
			if String(child.name) == "MatchIntroOverlay" and child is Control:
				overlay = child as Control
				break
	if overlay == null:
		ctx.log("overlay_missing")
		return
	var title_label: Label = overlay.find_child("Title", true, false) as Label
	var count_label: Label = overlay.find_child("CountdownNumber", true, false) as Label
	var sfx_player: AudioStreamPlayer = overlay.find_child("MatchIntroCountdownSfx", true, false) as AudioStreamPlayer
	var title_font: Font = title_label.get_theme_font("font") if title_label != null else null
	var count_font: Font = count_label.get_theme_font("font") if count_label != null else null
	ctx.log("overlay_size=%s visible=%s" % [str(overlay.size), str(overlay.visible)])
	ctx.log("title_font=%s count_font=%s" % [title_font.resource_path if title_font != null else "", count_font.resource_path if count_font != null else ""])
	ctx.log("sfx_exists=%s sfx_playing=%s sfx_stream=%s pitch=%.2f" % [str(sfx_player != null), str(sfx_player != null and sfx_player.playing), str(sfx_player.stream.get_class() if sfx_player != null and sfx_player.stream != null else ""), float(sfx_player.pitch_scale if sfx_player != null else 0.0)])
	await ctx.capture("match_intro_overlay_saira_sfx")
	await ctx.wait(1.05)
	ctx.log("after_1s_count=%s sfx_playing=%s pitch=%.2f" % [str(count_label.text if count_label != null else ""), str(sfx_player != null and sfx_player.playing), float(sfx_player.pitch_scale if sfx_player != null else 0.0)])
