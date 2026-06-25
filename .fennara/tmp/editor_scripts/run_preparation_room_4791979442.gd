@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return

	var body_font: Font = load("res://assets/fonts/SairaCondensed-Bold.woff2") as Font
	var label_names: Array[String] = ["HunterHomeChinese", "HunterHomeEnglish", "HunterHomeSubtitle"]
	for node_name: String in label_names:
		var label: Label3D = root.get_node_or_null("HunterHomeDecor/" + node_name) as Label3D
		if label == null:
			ctx.error("Missing label " + node_name)
			return
		label.rotation_degrees = Vector3(0.0, 0.0, 0.0)
		label.no_depth_test = true
		label.double_sided = true
		label.shaded = false
		label.fixed_size = false
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.86)
		label.render_priority = 18
		label.outline_render_priority = 17
		var current_position: Vector3 = label.position
		label.position = Vector3(current_position.x, current_position.y, -14.16)
		if node_name == "HunterHomeChinese":
			label.font = null
			label.font_size = 112
			label.pixel_size = 0.010
			label.modulate = Color(1.0, 0.98, 0.82, 1.0)
			label.outline_size = 12
		elif node_name == "HunterHomeEnglish":
			label.font = body_font
			label.font_size = 58
			label.pixel_size = 0.011
			label.modulate = Color(0.56, 0.90, 1.0, 1.0)
			label.outline_size = 7
		else:
			label.font = body_font
			label.font_size = 32
			label.pixel_size = 0.011
			label.modulate = Color(1.0, 0.75, 0.34, 1.0)
			label.outline_size = 4

	ctx.log("Updated HunterHome Label3D readability: fallback CJK font, depth-safe render, stronger sizing")
	ctx.mark_modified()
