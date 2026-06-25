@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root=%s" % String(root.get_name()))
	var default_preview: Node3D = ctx.get_node_or_null("DefaultPBRPreview") as Node3D
	var mask_preview: Node3D = ctx.get_node_or_null("MaskTintPreview") as Node3D
	var camera: Camera3D = ctx.get_node_or_null("PreviewCamera") as Camera3D
	var key: DirectionalLight3D = ctx.get_node_or_null("PreviewKeyLight") as DirectionalLight3D
	var fill: OmniLight3D = ctx.get_node_or_null("PreviewFillLight") as OmniLight3D
	if default_preview != null:
		default_preview.rotation = Vector3(0.0, PI, 0.0)
		default_preview.position = Vector3(-2.25, 1.35, 0.0)
		ctx.log("rotated DefaultPBRPreview front-facing")
	if mask_preview != null:
		mask_preview.rotation = Vector3(0.0, PI, 0.0)
		mask_preview.position = Vector3(2.25, 1.35, 0.0)
		ctx.log("rotated MaskTintPreview front-facing")
	if camera != null:
		camera.position = Vector3(0.0, 2.8, 8.0)
		camera.look_at_from_position(camera.position, Vector3(0.0, 1.7, 0.0), Vector3.UP)
		camera.fov = 43.0
		camera.current = true
		ctx.log("camera repositioned")
	if key != null:
		key.rotation_degrees = Vector3(-38.0, -24.0, 0.0)
		key.light_energy = 1.25
		key.shadow_enabled = true
		ctx.log("key light adjusted")
	if fill != null:
		fill.position = Vector3(0.0, 2.4, 4.0)
		fill.light_energy = 0.55
		fill.omni_range = 7.5
		ctx.log("fill light adjusted")
	ctx.mark_modified()
