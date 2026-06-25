@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Preview scene root was null")
		return
	var names: Array[String] = ["DefaultYellow", "MaskBlue", "MaskPink"]
	for name in names:
		var node: Node = root.get_node_or_null(name)
		if node is Node3D:
			var skin: Node3D = node as Node3D
			skin.rotation_degrees = Vector3.ZERO
			ctx.log("Facing preview skin forward: %s" % name)
	var camera_node: Node = root.get_node_or_null("PreviewCamera")
	if camera_node is Camera3D:
		var camera: Camera3D = camera_node as Camera3D
		camera.look_at_from_position(Vector3(0.0, 1.05, 4.35), Vector3(0.0, 0.72, 0.0), Vector3.UP)
		ctx.log("Reframed preview camera")
	ctx.mark_modified()
