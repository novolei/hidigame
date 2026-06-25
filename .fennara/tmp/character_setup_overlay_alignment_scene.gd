extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay := CharacterSetupOverlay.new()
	add_child(overlay)
	overlay.show_setup(15.0)
	for i in range(10):
		await get_tree().process_frame
	var offset: Vector3 = overlay.get_preview_model_position_for_test()
	var scale: Vector3 = overlay.get_preview_model_scale_for_test()
	var error: Vector3 = overlay.get_preview_model_platform_anchor_error_for_test()
	print("[CharacterSetupOverlayAlignmentProbe] model_position=%s" % offset)
	print("[CharacterSetupOverlayAlignmentProbe] model_scale=%s" % scale)
	print("[CharacterSetupOverlayAlignmentProbe] anchor_error=%s" % error)
	_expect(absf(error.x) < 0.02, "Preview visual center X should be on turntable center")
	_expect(absf(error.y) < 0.02, "Preview visual feet should sit on turntable surface")
	_expect(absf(error.z) < 0.02, "Preview visual center Z should be on turntable center")
	_expect(offset.z < -0.6, "Preview should compensate Party Monster mesh Z origin")
	if failures.is_empty():
		print("[CharacterSetupOverlayAlignmentProbe] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[CharacterSetupOverlayAlignmentProbe] " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
