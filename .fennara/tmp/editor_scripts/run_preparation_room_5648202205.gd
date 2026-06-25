@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var camera: Camera3D = ctx.get_node_or_null("HunterHomePreviewCamera") as Camera3D
	if camera == null:
		ctx.error("HunterHomePreviewCamera not found")
		return
	camera.position = Vector3(0.0, 8.6, 23.5)
	camera.look_at_from_position(camera.position, Vector3(0.0, 3.7, 0.0), Vector3.UP)
	camera.fov = 72.0
	camera.current = true
	ctx.log("Adjusted HunterHomePreviewCamera for arena scoreboard framing")
	ctx.mark_modified()
