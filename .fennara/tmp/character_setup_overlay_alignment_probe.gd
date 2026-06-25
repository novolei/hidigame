extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay := CharacterSetupOverlay.new()
	root.add_child(overlay)
	overlay.show_setup(15.0)
	for i in range(10):
		await process_frame
	var offset: Vector3 = overlay.get_preview_model_position_for_test()
	var scale: Vector3 = overlay.get_preview_model_scale_for_test()
	var error: Vector3 = overlay.get_preview_model_platform_anchor_error_for_test()
	print("[CharacterSetupOverlayAlignmentProbe] model_position=%s" % offset)
	print("[CharacterSetupOverlayAlignmentProbe] model_scale=%s" % scale)
	print("[CharacterSetupOverlayAlignmentProbe] anchor_error=%s" % error)
	if absf(error.x) >= 0.02 or absf(error.y) >= 0.02 or absf(error.z) >= 0.02:
		push_error("Preview anchor error exceeded tolerance: %s" % error)
		quit(1)
		return
	if offset.z >= -0.6:
		push_error("Preview did not compensate Party Monster Z origin: %s" % offset)
		quit(1)
		return
	quit(0)
