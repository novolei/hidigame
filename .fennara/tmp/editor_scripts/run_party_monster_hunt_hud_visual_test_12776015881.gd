@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var label: Label = root.get_node_or_null("MarkedHuntHUD/HuntPanel/ContentMargin/HuntStack/LoadoutLabel") as Label
	var escape_label: Label = root.get_node_or_null("MarkedHuntHUD/HuntPanel/ContentMargin/HuntStack/EscapeLabel") as Label
	if label == null or escape_label == null:
		ctx.error("Expected labels were not found")
		return
	ctx.log("before loadout_visible=%s text=%s min=%s" % [str(label.visible), label.text, str(label.custom_minimum_size)])
	label.visible = true
	label.text = "Traits  Eyes 02 / Mouth 05 / Nose 01 / +2"
	label.custom_minimum_size = Vector2(318.0, 24.0)
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.42, 1.0))
	escape_label.visible = true
	ctx.log("after loadout_visible=%s text=%s min=%s" % [str(label.visible), label.text, str(label.custom_minimum_size)])
	ctx.mark_modified()
