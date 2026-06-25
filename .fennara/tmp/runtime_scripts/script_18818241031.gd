extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root=null")
		ctx.close_scene()
		return
	var overlay: Node = root.find_child("CharacterSetupOverlay", true, false)
	if overlay == null:
		ctx.log("overlay=missing")
		ctx.close_scene()
		return
	overlay.call("show_setup", 20.0)
	await ctx.wait(1.4)
	var subviewport_count: int = _count_class(overlay, "SubViewport")
	var texture_rect_count: int = _count_class(overlay, "TextureRect")
	var thumb_viewport: Node = overlay.find_child("ThumbViewport", true, false)
	var haze: Node = overlay.find_child("SetupHaze", true, false)
	var backdrop_node: Node = overlay.find_child("SetupBackdrop", true, false)
	var backdrop_color: String = "missing"
	if backdrop_node is ColorRect:
		var backdrop: ColorRect = backdrop_node as ColorRect
		backdrop_color = str(backdrop.color)
	ctx.log("overlay_visible=%s subviewports=%d texture_rects=%d thumb_viewport=%s haze=%s backdrop=%s" % [str(overlay.visible), subviewport_count, texture_rect_count, str(thumb_viewport != null), str(haze != null), backdrop_color])
	await ctx.capture("skin_setup_clean_light_blue")
	ctx.close_scene()


func _count_class(node: Node, target_class: String) -> int:
	var count: int = 0
	if node.get_class() == target_class:
		count += 1
	for child in node.get_children():
		var child_node: Node = child as Node
		if child_node != null:
			count += _count_class(child_node, target_class)
	return count
