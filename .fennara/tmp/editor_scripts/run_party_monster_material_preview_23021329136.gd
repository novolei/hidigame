@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var camera: Camera3D = ctx.get_node_or_null("PreviewCamera") as Camera3D
	var key: DirectionalLight3D = ctx.get_node_or_null("PreviewKeyLight") as DirectionalLight3D
	var fill: OmniLight3D = ctx.get_node_or_null("PreviewFillLight") as OmniLight3D
	if camera != null:
		camera.position = Vector3(0.0, 2.8, -8.0)
		camera.look_at_from_position(camera.position, Vector3(0.0, 1.65, 0.0), Vector3.UP)
		camera.fov = 43.0
		camera.current = true
		ctx.log("camera moved to opposite side for face view")
	if key != null:
		key.rotation_degrees = Vector3(-35.0, 205.0, 0.0)
		key.light_energy = 1.35
		ctx.log("key light moved with face view")
	if fill != null:
		fill.position = Vector3(0.0, 2.35, -4.0)
		fill.light_energy = 0.65
		ctx.log("fill light moved with face view")
	ctx.mark_modified()
